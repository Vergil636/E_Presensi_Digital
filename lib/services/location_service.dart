// lib/services/location_service.dart
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

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
    // Cek service
    bool serviceEnabled = await isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location service tidak aktif. Mohon aktifkan GPS.');
    }

    // Cek permission
    LocationPermission permission = await checkPermission();
    if (permission == LocationPermission.denied) {
      throw Exception('Permission lokasi ditolak.');
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw Exception(
        'Permission lokasi ditolak permanen. Mohon aktifkan di pengaturan aplikasi.'
      );
    }

    // Dapatkan posisi dengan akurasi tinggi
    return await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }

  /// Reverse geocoding: Konversi koordinat ke alamat
  /// Format: Kecamatan, Kabupaten/Kota, Provinsi
  static Future<String> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        latitude,
        longitude,
      );

      if (placemarks.isEmpty) {
        return 'Lokasi tidak dikenali';
      }

      Placemark place = placemarks.first;
      
      // Format: Kecamatan, Kabupaten, Provinsi
      List<String> addressParts = [];
      
      // subLocality biasanya berisi Kelurahan/Desa
      if (place.subLocality != null && place.subLocality!.isNotEmpty) {
        addressParts.add(place.subLocality!);
      }
      
      // locality biasanya berisi Kecamatan
      if (place.locality != null && place.locality!.isNotEmpty) {
        addressParts.add(place.locality!);
      }
      
      // subAdministrativeArea biasanya berisi Kabupaten/Kota
      if (place.subAdministrativeArea != null && 
          place.subAdministrativeArea!.isNotEmpty) {
        addressParts.add(place.subAdministrativeArea!);
      }
      
      // administrativeArea berisi Provinsi
      if (place.administrativeArea != null && 
          place.administrativeArea!.isNotEmpty) {
        addressParts.add(place.administrativeArea!);
      }

      // Jika tidak ada bagian alamat yang terisi
      if (addressParts.isEmpty) {
        return 'Lokasi tidak dikenali';
      }

      return addressParts.join(', ');
    } catch (e) {
      // Return pesan yang lebih user-friendly tanpa detail error teknis
      return 'Lokasi tidak dikenali';
    }
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
