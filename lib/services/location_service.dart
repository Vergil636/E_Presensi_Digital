// lib/services/location_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

/// Service untuk mendapatkan lokasi GPS dan reverse geocoding
class LocationService {
  static const String _apiKey =
      '7t0bBS9rSfXtKQFsewtZ1gTafCMRt6BdCjLJgI83lFE9PmEKjfisCxnIz45EVVyr';

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

  /// Reverse geocoding menggunakan Distancematrix.ai
  /// Menggunakan http package (async) - bekerja di web dan mobile
  static Future<String> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final uri = Uri.parse(
        'https://api.distancematrix.ai/maps/api/geocode/json'
        '?latlng=$latitude,$longitude'
        '&key=$_apiKey',
      );

      final response = await http.get(uri, headers: {
        'Accept': 'application/json'
      }).timeout(const Duration(seconds: 15));

      if (response.statusCode != 200) {
        return _fallbackAddress(latitude, longitude);
      }

      final data = json.decode(response.body);

      // Cek status API
      if (data['status'] != 'OK') {
        return _fallbackAddress(latitude, longitude);
      }

      // Distancematrix.ai pakai key "result" (bukan "results")
      final results = data['result'] as List?;
      if (results == null || results.isEmpty) {
        return _fallbackAddress(latitude, longitude);
      }

      // Ambil formatted_address (paling lengkap)
      final formattedAddress =
          results[0]['formatted_address']?.toString() ?? '';
      if (formattedAddress.isNotEmpty) {
        return formattedAddress;
      }

      // Fallback: parse dari address_components
      final components = results[0]['address_components'] as List?;
      if (components != null && components.isNotEmpty) {
        return _parseAddressComponents(components);
      }

      return _fallbackAddress(latitude, longitude);
    } on TimeoutException {
      return _fallbackAddress(latitude, longitude);
    } catch (e) {
      return _fallbackAddress(latitude, longitude);
    }
  }

  /// Parse address_components menjadi string alamat
  static String _parseAddressComponents(List components) {
    String route = '';
    String sublocality = '';
    String locality = '';
    String adminArea2 = '';
    String adminArea1 = '';

    for (final comp in components) {
      final types =
          (comp['types'] as List?)?.map((e) => e.toString()).toList() ?? [];
      final longName = comp['long_name']?.toString() ?? '';

      if (types.contains('route')) route = longName;
      if (types.contains('sublocality') ||
          types.contains('sublocality_level_1')) {
        sublocality = longName;
      }
      if (types.contains('locality')) locality = longName;
      if (types.contains('administrative_area_level_2')) adminArea2 = longName;
      if (types.contains('administrative_area_level_1')) adminArea1 = longName;
    }

    final parts = <String>[];
    if (route.isNotEmpty) parts.add(route);
    if (sublocality.isNotEmpty) parts.add(sublocality);
    if (locality.isNotEmpty) parts.add(locality);
    if (adminArea2.isNotEmpty) parts.add(adminArea2);
    if (adminArea1.isNotEmpty) parts.add(adminArea1);

    return parts.isNotEmpty ? parts.join(', ') : 'Lokasi tidak dikenali';
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
