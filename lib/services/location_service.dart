// lib/services/location_service.dart
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Service untuk mendapatkan lokasi GPS dan reverse geocoding
class LocationService {
  /// Cek apakah location service aktif
  static Future<bool> isLocationServiceEnabled() async {
    return await Geolocator.isLocationServiceEnabled();
  }

  /// Cek dan request permission
  static Future<LocationPermission> checkPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission;
  }

  /// Dapatkan posisi saat ini
  static Future<Position> getCurrentPosition() async {
    bool serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location service tidak aktif. Mohon aktifkan GPS.');
    }

    LocationPermission permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      throw Exception('Permission lokasi ditolak.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Permission lokasi ditolak permanen. Mohon aktifkan di pengaturan aplikasi.',
      );
    }

    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }

  /// Reverse geocoding menggunakan OpenStreetMap Nominatim API
  /// Gratis, tanpa API key, support Bahasa Indonesia
  static Future<String> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse'
        '?format=json'
        '&lat=$latitude'
        '&lon=$longitude'
        '&zoom=16'
        '&addressdetails=1'
        '&accept-language=id',
      );

      final response = await http.get(
        uri,
        headers: {
          // Nominatim mensyaratkan User-Agent yang valid
          'User-Agent': 'EAbsensiCvTanjungAgung/1.0',
          'Accept-Language': 'id',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        // Ambil display_name (nama lengkap lokasi)
        final displayName = data['display_name']?.toString() ?? '';
        if (displayName.isNotEmpty) {
          // Format ulang: ambil komponen yang penting saja
          final address = data['address'] as Map<String, dynamic>?;
          if (address != null) {
            return _buildAddress(address);
          }
          return displayName;
        }

        return _fallbackAddress(latitude, longitude);
      }

      return _fallbackAddress(latitude, longitude);
    } catch (e) {
      return _fallbackAddress(latitude, longitude);
    }
  }

  /// Format address dari komponen Nominatim menjadi string yang rapi
  /// Contoh hasil: "Jl. Raya Bogor, Mulyamekar, Purwakarta, Jawa Barat"
  static String _buildAddress(Map<String, dynamic> address) {
    final parts = <String>[];

    // Nama jalan
    final road = address['road']?.toString() ??
        address['pedestrian']?.toString() ??
        address['path']?.toString() ??
        '';
    if (road.isNotEmpty) parts.add(road);

    // Desa / Kelurahan
    final village = address['village']?.toString() ??
        address['suburb']?.toString() ??
        address['neighbourhood']?.toString() ??
        address['hamlet']?.toString() ??
        '';
    if (village.isNotEmpty) parts.add(village);

    // Kecamatan
    final district = address['city_district']?.toString() ??
        address['district']?.toString() ??
        '';
    if (district.isNotEmpty) parts.add(district);

    // Kota / Kabupaten
    final city = address['city']?.toString() ??
        address['town']?.toString() ??
        address['county']?.toString() ??
        '';
    if (city.isNotEmpty) parts.add(city);

    // Provinsi
    final province = address['state']?.toString() ?? '';
    if (province.isNotEmpty) parts.add(province);

    if (parts.isEmpty) return 'Lokasi tidak dikenali';
    return parts.join(', ');
  }

  /// Fallback jika API gagal
  static String _fallbackAddress(double lat, double lng) {
    return 'Lat: ${lat.toStringAsFixed(6)}, Lng: ${lng.toStringAsFixed(6)}';
  }

  /// Dapatkan lokasi lengkap (koordinat + alamat)
  static Future<LocationData> getLocationWithAddress() async {
    final position = await getCurrentPosition();
    final address = await getAddressFromCoordinates(
      position.latitude,
      position.longitude,
    );

    return LocationData(
      latitude: position.latitude,
      longitude: position.longitude,
      accuracy: position.accuracy,
      address: address,
    );
  }

  /// Hitung jarak antara 2 koordinat (dalam meter)
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }
}

/// Model untuk data lokasi
class LocationData {
  final double latitude;
  final double longitude;
  final double accuracy;
  final String address;

  LocationData({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.address,
  });

  Map<String, dynamic> toJson() => {
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'address': address,
      };

  @override
  String toString() {
    return 'Lat: $latitude, Lon: $longitude\n$address';
  }
}
