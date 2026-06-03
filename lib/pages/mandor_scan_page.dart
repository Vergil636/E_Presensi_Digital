// lib/pages/mandor_scan_page.dart
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../services/supabase_service.dart';
import '../services/location_service.dart';

/// Halaman scan QR untuk mandor
class MandorScanPage extends StatefulWidget {
  final Map<String, dynamic> mandorData;
  final bool isEmergency;
  final String scanType; // 'IN' atau 'OUT'

  const MandorScanPage({
    super.key,
    required this.mandorData,
    this.isEmergency = false,
    this.scanType = 'IN',
  });

  @override
  State<MandorScanPage> createState() => _MandorScanPageState();
}

class _MandorScanPageState extends State<MandorScanPage> {
  final MobileScannerController _scannerController = MobileScannerController();
  bool _isProcessing = false;
  String? _lastScanned;

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    final String? code = barcodes.first.rawValue;
    if (code == null || code.isEmpty) return;

    // Prevent duplicate scans
    if (_lastScanned == code) return;
    _lastScanned = code;

    setState(() => _isProcessing = true);

    try {
      // Get location
      String? locationAddress;
      double? latitude;
      double? longitude;
      double? accuracy;

      try {
        final locationData = await LocationService.getLocationWithAddress();
        locationAddress = locationData.address;
        latitude = locationData.latitude;
        longitude = locationData.longitude;
        accuracy = locationData.accuracy;
      } catch (e) {
        // Location error, continue without location
        debugPrint('Location error: $e');
      }

      // Determine attendance type
      final String atype = widget.scanType; // Use scanType from parameter

      // Mark attendance by mandor
      final result = await markAttendanceByMandor(
        mandorId: widget.mandorData['id'],
        scannedValue: code,
        atype: atype,
        mandorNotes: widget.isEmergency ? 'Pulang darurat' : null,
        latitude: latitude,
        longitude: longitude,
        locationAddress: locationAddress,
        locationAccuracy: accuracy,
      );

      if (!mounted) return;

      // Show success dialog
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade600, size: 28),
              const SizedBox(width: 12),
              const Text('Berhasil'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nama: ${result['employee_name']}'),
              Text('Posisi: ${result['position']}'),
              Text('Tipe: ${result['atype']}'),
              Text('Waktu: ${result['scanned_at']}'),
              if (locationAddress != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Lokasi: $locationAddress',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.supervisor_account,
                        size: 16, color: Colors.green.shade700),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Presensi oleh mandor',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context, true); // Return to dashboard
              },
              child: const Text('Selesai'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _isProcessing = false;
                  _lastScanned = null;
                });
              },
              child: const Text('Scan Lagi'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red.shade600, size: 28),
              const SizedBox(width: 12),
              const Text('Error'),
            ],
          ),
          content: Text(e.toString()),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                setState(() {
                  _isProcessing = false;
                  _lastScanned = null;
                });
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Determine title based on mode
    String title = 'Scan QR - Absensi';
    if (widget.isEmergency) {
      title = 'Scan QR - Pulang Darurat';
    } else if (widget.scanType == 'IN') {
      title = 'Scan QR - Masuk (IN)';
    } else if (widget.scanType == 'OUT') {
      title = 'Scan QR - Pulang (OUT)';
    }

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        children: [
          // Scanner
          MobileScanner(
            controller: _scannerController,
            onDetect: _onDetect,
          ),

          // Overlay
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Memproses...'),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // Instructions
          if (!_isProcessing)
            Positioned(
              bottom: 40,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.qr_code_scanner,
                        size: 40, color: Colors.green.shade700),
                    const SizedBox(height: 12),
                    Text(
                      widget.isEmergency
                          ? 'Arahkan kamera ke QR Code pegawai\nuntuk absen pulang darurat'
                          : widget.scanType == 'IN'
                              ? 'Arahkan kamera ke QR Code pegawai\nuntuk absen masuk (IN)'
                              : 'Arahkan kamera ke QR Code pegawai\nuntuk absen pulang (OUT)',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
