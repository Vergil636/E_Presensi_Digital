// lib/pages/scan_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/supabase_service.dart';
import '../services/location_service.dart';

/// Mode scan yang dipilih dari menu pemilihan
enum ScanMode {
  /// Absen normal — bisa toggle IN/OUT
  normal,

  /// Pulang darurat — langsung OUT, skip validasi waktu
  emergencyOut,
}

/// Halaman pemilihan mode scan QR.
/// Ditampilkan sebelum masuk ke scanner kamera.
class ScanMenuPage extends StatelessWidget {
  const ScanMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Pilih Mode Scan',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 24),

            // Title
            const Text(
              'Pilih Jenis Absensi',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Silakan pilih mode scan sesuai kebutuhan',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 36),

            // Option 1: Normal Scan
            _ScanModeCard(
              icon: Icons.qr_code_scanner,
              iconColor: Colors.deepPurple,
              gradientColors: const [Color(0xFF7C3AED), Color(0xFF5B21B6)],
              title: 'Absen Masuk / Pulang',
              subtitle:
                  'Scan QR untuk absen masuk (IN) atau pulang (OUT) sesuai aturan jam kerja yang berlaku.',
              badge: 'NORMAL',
              badgeColor: Colors.deepPurple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ScanPage(mode: ScanMode.normal),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Option 2: Presensi Manual
            _ScanModeCard(
              icon: Icons.edit_note_rounded,
              iconColor: Colors.teal,
              gradientColors: const [Color(0xFF0D9488), Color(0xFF115E59)],
              title: 'Presensi Manual',
              subtitle:
                  'Input absen masuk (IN) atau pulang (OUT) secara manual dengan memilih nama pegawai. Tanpa scan QR.',
              badge: 'MANUAL',
              badgeColor: Colors.teal,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ManualAttendancePage(),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),

            // Option 3: Emergency Out
            _ScanModeCard(
              icon: Icons.emergency,
              iconColor: Colors.red.shade700,
              gradientColors: [Colors.red.shade600, Colors.red.shade900],
              title: 'Pulang Darurat',
              subtitle:
                  'Scan QR untuk pulang darurat. Tidak mengikuti aturan jam pulang normal. Digunakan untuk keperluan mendesak.',
              badge: 'DARURAT',
              badgeColor: Colors.red.shade700,
              onTap: () {
                _showEmergencyConfirmation(context);
              },
            ),

            const Spacer(),

            // Info footer
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.amber.shade800, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Pulang Darurat hanya digunakan untuk situasi mendesak dan akan dicatat sebagai pulang darurat.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showEmergencyConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.red.shade700, size: 28),
            const SizedBox(width: 10),
            const Text(
              'Konfirmasi',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        content: const Text(
          'Anda akan menggunakan mode Pulang Darurat.\n\n'
          'Mode ini akan mencatat absen PULANG tanpa mengikuti aturan jam pulang normal. '
          'Lanjutkan?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red.shade700,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      const ScanPage(mode: ScanMode.emergencyOut),
                ),
              );
            },
            child: const Text('Ya, Lanjutkan'),
          ),
        ],
      ),
    );
  }
}

class _ScanModeCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final List<Color> gradientColors;
  final String title;
  final String subtitle;
  final String badge;
  final Color badgeColor;
  final VoidCallback onTap;

  const _ScanModeCard({
    required this.icon,
    required this.iconColor,
    required this.gradientColors,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.badgeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 1,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Row(
            children: [
              // Icon container with gradient
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors.first.withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: badgeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: badgeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Colors.black38, size: 24),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  SCAN PAGE (kamera + input manual) — sekarang menerima mode
// ═══════════════════════════════════════════════════════════════════

class ScanPage extends StatefulWidget {
  final ScanMode mode;

  const ScanPage({super.key, this.mode = ScanMode.normal});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  final MobileScannerController _controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  bool _torchOn = false;

  final TextEditingController _manualC = TextEditingController();

  String _atype = 'IN'; // 'IN' or 'OUT'
  bool _busy = false;   // lock while calling RPC
  Timer? _unlockTimer;  // small debounce lock

  Map<String, dynamic>? _lastResult;

  bool get _isEmergency => widget.mode == ScanMode.emergencyOut;

  @override
  void initState() {
    super.initState();
    // Kalau mode darurat, langsung force OUT
    if (_isEmergency) {
      _atype = 'OUT';
    }
  }

  @override
  void dispose() {
    _unlockTimer?.cancel();
    _controller.dispose();
    _manualC.dispose();
    super.dispose();
  }

  void _setBusyShort() {
    _unlockTimer?.cancel();
    setState(() => _busy = true);
    _unlockTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _busy = false);
    });
  }

  bool _msgHas(String message, String needle) {
    return message.toLowerCase().contains(needle.toLowerCase());
  }

  Future<void> _handleScan(String? value) async {
    final code = value?.trim();
    if (code == null || code.isEmpty) return;
    if (_busy) return;

    _setBusyShort();
    
    // Ambil lokasi GPS
    double? latitude;
    double? longitude;
    String? locationAddress;
    double? locationAccuracy;
    
    try {
      final location = await LocationService.getLocationWithAddress();
      latitude = location.latitude;
      longitude = location.longitude;
      locationAddress = location.address;
      locationAccuracy = location.accuracy;
    } catch (e) {
      // Jika gagal ambil lokasi, lanjutkan tanpa lokasi
      // Tidak throw error, biarkan absen tetap jalan tanpa lokasi
    }
    
    try {
      // Untuk mode darurat, selalu kirim 'OUT'
      final typeToSend = _isEmergency ? 'OUT' : _atype;

      // Panggil RPC sesuai tipe saat ini dengan data lokasi
      final res = await markAttendance(
        scannedValue: code,
        type: typeToSend,
        isEmergency: _isEmergency,
        latitude: latitude,
        longitude: longitude,
        locationAddress: locationAddress,
        locationAccuracy: locationAccuracy,
      );

      // Simpan hasil ke UI (nama/posisi jika dikembalikan RPC)
      setState(() => _lastResult = res);

      final empName = (res['employee_name'] ?? res['name'] ?? code).toString();
      final pos = (res['position'] ?? res['emp_position'] ?? '').toString();
      final posText = pos.isNotEmpty ? ' ($pos)' : '';

      if (_isEmergency) {
        _showSnack('Berhasil: PULANG DARURAT untuk $empName$posText');
      } else {
        final label = _atype == 'IN' ? 'MASUK' : 'PULANG';
        _showSnack('Berhasil: $label untuk $empName$posText');
      }
    } catch (e) {
      final msg = e.toString();

      // 🔐 Penting: blokir OUT jika belum IN (mengandalkan pesan dari SQL)
      if (!_isEmergency && _msgHas(msg, 'Belum absen MASUK hari ini')) {
        _showSnack('Gagal: belum absen MASUK hari ini. Dialihkan ke mode IN.');
        // Otomatis kembalikan pilihan ke IN agar user langsung scan MASUK
        if (mounted) setState(() => _atype = 'IN');
        return;
      }

      // Pesan error lain tetap ditampilkan apa adanya
      _showSnack(msg);
    }
  }

  Future<void> _submitManual() async {
    await _handleScan(_manualC.text);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEmergency ? 'Scan Pulang Darurat' : 'Scan QR (IN/OUT)'),
        backgroundColor: _isEmergency ? Colors.red.shade700 : null,
        foregroundColor: _isEmergency ? Colors.white : null,
        actions: [
          IconButton(
            tooltip: 'Switch kamera',
            onPressed: () => _controller.switchCamera(),
            icon: const Icon(Icons.cameraswitch),
          ),
          IconButton(
            tooltip: 'Torch',
            onPressed: () async {
              try {
                await _controller.toggleTorch();
              } catch (_) {}
              if (mounted) setState(() => _torchOn = !_torchOn);
            },
            icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Emergency banner
          if (_isEmergency) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.red.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.red.shade700, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Mode PULANG DARURAT aktif. Scan QR pegawai untuk mencatat pulang darurat.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade800,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Selector IN / OUT — hanya tampil di mode normal
          if (!_isEmergency) ...[
            Card(
              elevation: 0,
              color: scheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.rule, size: 20),
                    const SizedBox(width: 8),
                    Text('Pilih tipe absen:',
                        style: Theme.of(context).textTheme.titleSmall),
                    const SizedBox(width: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'IN', label: Text('IN')),
                        ButtonSegment(value: 'OUT', label: Text('OUT')),
                      ],
                      selected: {_atype},
                      showSelectedIcon: false,
                      onSelectionChanged: (s) {
                        if (s.isEmpty) return;
                        setState(() => _atype = s.first);
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Scanner camera
          Card(
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(
                color: _isEmergency
                    ? Colors.red.shade300
                    : scheme.outlineVariant,
                width: _isEmergency ? 2 : 1,
              ),
            ),
            child: AspectRatio(
              aspectRatio: 16 / 10,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _controller,
                    onDetect: (capture) {
                      final barcodes = capture.barcodes;
                      if (barcodes.isEmpty) return;
                      final val = barcodes.first.rawValue ?? '';
                      _handleScan(val);
                    },
                  ),
                  Align(
                    alignment: Alignment.topCenter,
                    child: Container(
                      margin: const EdgeInsets.all(12),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _isEmergency
                            ? Colors.red.shade700.withOpacity(.85)
                            : scheme.surface.withOpacity(.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _busy
                            ? 'Memproses...'
                            : _isEmergency
                                ? 'Arahkan kamera ke QR — PULANG DARURAT'
                                : 'Arahkan kamera ke QR (NIK/CODE)',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: _isEmergency ? Colors.white : null,
                            ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Input manual fallback
          Card(
            elevation: 0,
            color: scheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.keyboard, size: 20),
                      const SizedBox(width: 8),
                      Text('Input manual (jika kamera bermasalah)',
                          style: Theme.of(context).textTheme.titleSmall),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _manualC,
                          decoration: const InputDecoration(
                            hintText: 'Masukkan NIK atau CODE',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                          onSubmitted: (_) => _submitManual(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: _isEmergency
                            ? FilledButton.styleFrom(
                                backgroundColor: Colors.red.shade700,
                              )
                            : null,
                        onPressed: _busy ? null : _submitManual,
                        icon: _busy
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded),
                        label: Text(_isEmergency ? 'Pulang' : 'Kirim'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Hasil terakhir
          if (_lastResult != null)
            _LastResultCard(
              data: _lastResult!,
              isEmergency: _isEmergency,
            ),
        ],
      ),
    );
  }
}

class _LastResultCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final bool isEmergency;
  const _LastResultCard({required this.data, this.isEmergency = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    String atype = (data['atype'] ?? '').toString();
    String scanned = (data['scanned_value'] ?? '').toString();

    // tampilkan info yang (mungkin) dikirim RPC
    final empName = (data['employee_name'] ?? data['name'] ?? scanned).toString();
    final position = (data['position'] ?? data['emp_position'] ?? '').toString();

    String localTs = (data['local_scanned_at'] ?? data['scanned_at'] ?? '').toString();
    bool isOT = (data['is_overtime'] ?? false) == true;
    int otMin = int.tryParse('${data['overtime_minutes'] ?? 0}') ?? 0;

    // Ambil data lokasi
    final latitude = data['latitude'];
    final longitude = data['longitude'];
    final locationAddress = (data['location_address'] ?? '').toString();
    final hasLocation = latitude != null && longitude != null;

    return Card(
      elevation: 0,
      color: isEmergency ? Colors.red.shade50 : scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isEmergency
            ? BorderSide(color: Colors.red.shade200)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hasil terakhir',
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _kv('Nama', empName),
                if (position.isNotEmpty) _kv('Posisi', position),
                _kv('Tipe', isEmergency ? 'PULANG DARURAT' : atype),
                _kv('QR', scanned),
                _kv('Waktu (lokal)', localTs),
                if (!isEmergency) _kv('Lembur', isOT ? 'Ya' : 'Tidak'),
                if (!isEmergency && isOT) _kv('Menit lembur', '$otMin'),
              ],
            ),
            const SizedBox(height: 12),
            
            // Tampilkan lokasi jika ada
            if (hasLocation) ...[
              const Divider(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.location_on, 
                      color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lokasi Absen',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Colors.blue.shade900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        if (locationAddress.isNotEmpty) ...[
                          Text(
                            locationAddress,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.black87,
                              height: 1.4,
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],
                        Text(
                          'Koordinat: $latitude, $longitude',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey.shade600,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: () {
                            // Buka Google Maps
                            final url = 'https://www.google.com/maps?q=$latitude,$longitude';
                            // TODO: Implement URL launcher
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Maps URL: $url'),
                                action: SnackBarAction(
                                  label: 'Copy',
                                  onPressed: () {
                                    // TODO: Copy to clipboard
                                  },
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Colors.blue.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.map, 
                                    color: Colors.blue.shade700, size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  'Lihat di Maps',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 12),
            
            if (isEmergency)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emergency, color: Colors.red.shade700, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Status: PULANG DARURAT diterima.',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Colors.red.shade800,
                      ),
                    ),
                  ],
                ),
              )
            else if (atype == 'OUT')
              Text(
                isOT
                    ? 'Status: PULANG dengan lembur.'
                    : 'Status: PULANG normal.',
                style: Theme.of(context).textTheme.bodyMedium,
              )
            else
              Text(
                'Status: MASUK diterima.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$k: ',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        Text(v, style: const TextStyle(fontSize: 13)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
//  MANUAL ATTENDANCE PAGE
//  Input absen manual: pilih pegawai + toggle IN/OUT, tanpa kamera
// ═══════════════════════════════════════════════════════════════════

class ManualAttendancePage extends StatefulWidget {
  const ManualAttendancePage({super.key});

  @override
  State<ManualAttendancePage> createState() => _ManualAttendancePageState();
}

class _ManualAttendancePageState extends State<ManualAttendancePage> {
  // Data pegawai
  List<Map<String, dynamic>> _allEmployees = [];
  List<Map<String, dynamic>> _filtered = [];
  bool _loadingEmployees = true;

  // Multi-select
  final TextEditingController _searchC = TextEditingController();
  final Set<String> _selectedIds = {}; // kumpulan ID yang dipilih

  // Input manual
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _checkInC = TextEditingController(text: '08:00');
  final TextEditingController _checkOutC = TextEditingController(text: '17:00');
  final TextEditingController _overtimeC = TextEditingController(text: '0');
  final TextEditingController _notesC = TextEditingController();
  
  bool _includeCheckOut = true; // Toggle untuk input jam pulang

  // Submit state
  bool _busy = false;
  // Hasil submit per pegawai: {name, nik, status:'ok'|'error', msg}
  List<Map<String, dynamic>> _results = [];

  @override
  void initState() {
    super.initState();
    _loadEmployees();
    _searchC.addListener(_onSearch);
  }

  @override
  void dispose() {
    _searchC.removeListener(_onSearch);
    _searchC.dispose();
    _checkInC.dispose();
    _checkOutC.dispose();
    _overtimeC.dispose();
    _notesC.dispose();
    super.dispose();
  }

  Future<void> _loadEmployees() async {
    setState(() => _loadingEmployees = true);
    try {
      final data = await fetchEmployees();
      setState(() {
        _allEmployees = data;
        _filtered = data;
      });
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _loadingEmployees = false);
    }
  }

  void _onSearch() {
    final q = _searchC.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filtered = _allEmployees;
      } else {
        _filtered = _allEmployees.where((e) {
          final name = (e['name'] ?? '').toString().toLowerCase();
          final nik = (e['nik'] ?? '').toString().toLowerCase();
          final pos = (e['position'] ?? '').toString().toLowerCase();
          return name.contains(q) || nik.contains(q) || pos.contains(q);
        }).toList();
      }
    });
  }

  Future<void> _submit() async {
    if (_selectedIds.isEmpty) {
      _showSnack('Pilih minimal satu pegawai terlebih dahulu.');
      return;
    }
    if (_busy) return;

    // Validasi input
    final checkIn = _checkInC.text.trim();
    if (checkIn.isEmpty || !_isValidTime(checkIn)) {
      _showSnack('Format jam masuk tidak valid. Gunakan format HH:mm (contoh: 08:00)');
      return;
    }

    String? checkOut;
    if (_includeCheckOut) {
      checkOut = _checkOutC.text.trim();
      if (checkOut.isEmpty || !_isValidTime(checkOut)) {
        _showSnack('Format jam pulang tidak valid. Gunakan format HH:mm (contoh: 17:00)');
        return;
      }
    }

    final overtimeHours = double.tryParse(_overtimeC.text.trim()) ?? 0;
    if (overtimeHours < 0) {
      _showSnack('Jam lembur tidak boleh negatif.');
      return;
    }

    setState(() {
      _busy = true;
      _results = [];
    });

    // Proses setiap pegawai yang dipilih
    final selectedEmployees = _allEmployees
        .where((e) => _selectedIds.contains(e['id'].toString()))
        .toList();

    for (final emp in selectedEmployees) {
      final empId = (emp['id'] ?? '').toString();
      final name = (emp['name'] ?? '').toString();
      final nik = (emp['nik'] ?? '').toString();

      if (empId.isEmpty) {
        _results.add({
          'name': name,
          'nik': nik,
          'status': 'error',
          'msg': 'ID pegawai tidak valid',
        });
        continue;
      }

      try {
        final res = await manualAttendanceEntry(
          employeeId: empId,
          date: _selectedDate,
          checkInTime: checkIn,
          checkOutTime: checkOut,
          overtimeHours: overtimeHours,
          notes: _notesC.text.trim().isEmpty ? null : _notesC.text.trim(),
        );

        final empName = (res['employee_name'] ?? name).toString();
        final action = (res['action'] ?? 'created').toString();
        final actionText = action == 'updated' ? 'diperbarui' : 'dicatat';
        
        String successMsg = 'Berhasil $actionText';
        if (_includeCheckOut) {
          successMsg += ' (Masuk: $checkIn, Pulang: $checkOut)';
        } else {
          successMsg += ' (Masuk: $checkIn)';
        }
        
        if (overtimeHours > 0) {
          successMsg += ' • Lembur: ${overtimeHours}h';
        }

        _results.add({
          'name': empName,
          'nik': nik,
          'status': 'ok',
          'msg': successMsg,
          'overtime_hours': overtimeHours,
        });
      } catch (e) {
        final msg = e.toString();
        _results.add({
          'name': name,
          'nik': nik,
          'status': 'error',
          'msg': msg,
        });
      }
    }

    if (mounted) {
      setState(() => _busy = false);
      
      // Hitung berhasil dan gagal
      final success = _results.where((r) => r['status'] == 'ok').length;
      final failed = _results.where((r) => r['status'] == 'error').length;
      
      _showSnack('Selesai: $success berhasil, $failed gagal');

      // Reset pilihan setelah selesai
      setState(() {
        _selectedIds.clear();
      });
    }
  }

  bool _isValidTime(String time) {
    final regex = RegExp(r'^([0-1]?[0-9]|2[0-3]):[0-5][0-9]$');
    return regex.hasMatch(time);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Presensi Manual'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Info Card ─────────────────────────────────
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Input absensi manual untuk mengatasi lupa absen. Tanpa validasi aturan jam kerja.',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.blue.shade900,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // ── Pilih Tanggal ────────────────────────────
          Card(
            elevation: 0,
            color: scheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tanggal Absen',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime.now().add(const Duration(days: 1)),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: scheme.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              color: scheme.primary, size: 20),
                          const SizedBox(width: 12),
                          Text(
                            '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          Icon(Icons.arrow_drop_down,
                              color: Colors.grey.shade600),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Input Jam Masuk & Pulang ─────────────────
          Card(
            elevation: 0,
            color: scheme.surfaceContainerHigh,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Jam Kerja',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  
                  // Jam Masuk
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Jam Masuk',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade700,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _checkInC,
                              decoration: InputDecoration(
                                hintText: '08:00',
                                prefixIcon: const Icon(Icons.login_rounded, size: 20),
                                filled: true,
                                fillColor: scheme.surface,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              keyboardType: TextInputType.datetime,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      
                      // Jam Pulang
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  'Jam Pulang',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const Spacer(),
                                Transform.scale(
                                  scale: 0.8,
                                  child: Switch(
                                    value: _includeCheckOut,
                                    onChanged: (val) {
                                      setState(() => _includeCheckOut = val);
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _checkOutC,
                              enabled: _includeCheckOut,
                              decoration: InputDecoration(
                                hintText: '17:00',
                                prefixIcon: const Icon(Icons.logout_rounded, size: 20),
                                filled: true,
                                fillColor: _includeCheckOut
                                    ? scheme.surface
                                    : Colors.grey.shade200,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                              keyboardType: TextInputType.datetime,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Jam Lembur
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Jam Lembur (opsional)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _overtimeC,
                        decoration: InputDecoration(
                          hintText: '0',
                          prefixIcon: Icon(Icons.access_time,
                              size: 20, color: Colors.orange.shade700),
                          suffixText: 'jam',
                          filled: true,
                          fillColor: scheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Catatan
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Catatan (opsional)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _notesC,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Contoh: Lupa scan, koreksi data, dll',
                          prefixIcon: const Icon(Icons.note_alt_outlined, size: 20),
                          filled: true,
                          fillColor: scheme.surface,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Cari Pegawai ─────────────────────────────
          Card(
            elevation: 0,
            color: scheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pilih Pegawai',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),

                  // Search box
                  TextField(
                    controller: _searchC,
                    decoration: InputDecoration(
                      hintText: 'Cari nama, NIK, atau jabatan...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchC.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchC.clear();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: scheme.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Daftar pegawai
                  if (_loadingEmployees)
                    const Center(
                        child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ))
                  else if (_filtered.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Pegawai tidak ditemukan.',
                          style: TextStyle(color: Colors.black54)),
                    )
                  else
                    Column(
                      children: [
                        // Header dengan tombol pilih semua
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: scheme.surfaceContainerLow,
                            borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(10)),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '${_selectedIds.length} dari ${_filtered.length} dipilih',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black54,
                                ),
                              ),
                              const Spacer(),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    if (_selectedIds.length ==
                                        _filtered.length) {
                                      // Deselect all
                                      _selectedIds.clear();
                                    } else {
                                      // Select all
                                      _selectedIds.clear();
                                      for (final emp in _filtered) {
                                        _selectedIds
                                            .add(emp['id'].toString());
                                      }
                                    }
                                  });
                                },
                                icon: Icon(
                                  _selectedIds.length == _filtered.length
                                      ? Icons.deselect
                                      : Icons.select_all,
                                  size: 18,
                                ),
                                label: Text(
                                  _selectedIds.length == _filtered.length
                                      ? 'Batal Semua'
                                      : 'Pilih Semua',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                        ),
                        ClipRRect(
                          borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(10)),
                          child: ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: _filtered.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 1, indent: 54),
                            itemBuilder: (ctx, i) {
                              final emp = _filtered[i];
                              final empId = emp['id'].toString();
                              final isSelected = _selectedIds.contains(empId);
                              final name = (emp['name'] ?? '-').toString();
                              final nik = (emp['nik'] ?? '-').toString();
                              final pos = (emp['position'] ?? '-').toString();

                              return Material(
                                color: isSelected
                                    ? scheme.primaryContainer.withOpacity(0.5)
                                    : Colors.transparent,
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      if (isSelected) {
                                        _selectedIds.remove(empId);
                                      } else {
                                        _selectedIds.add(empId);
                                      }
                                    });
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 10),
                                    child: Row(
                                      children: [
                                        Checkbox(
                                          value: isSelected,
                                          onChanged: (val) {
                                            setState(() {
                                              if (val == true) {
                                                _selectedIds.add(empId);
                                              } else {
                                                _selectedIds.remove(empId);
                                              }
                                            });
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        CircleAvatar(
                                          radius: 18,
                                          backgroundColor: isSelected
                                              ? scheme.primary
                                              : Colors.grey.shade300,
                                          child: Text(
                                            name.isNotEmpty
                                                ? name[0].toUpperCase()
                                                : '?',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: isSelected
                                                  ? Colors.white
                                                  : Colors.black87,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 14,
                                                  color: isSelected
                                                      ? scheme
                                                          .onPrimaryContainer
                                                      : Colors.black87,
                                                ),
                                              ),
                                              Text(
                                                'NIK: $nik • $pos',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: isSelected
                                                      ? scheme
                                                          .onPrimaryContainer
                                                          .withOpacity(0.7)
                                                      : Colors.black45,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Tombol Submit ─────────────────────────────
          SizedBox(
            height: 52,
            child: FilledButton.icon(
              onPressed: (_busy || _selectedIds.isEmpty) ? null : _submit,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.deepPurple.shade700,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _busy
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(
                _busy
                    ? 'Memproses...'
                    : _selectedIds.isEmpty
                        ? 'Pilih pegawai dulu'
                        : 'Simpan Absensi (${_selectedIds.length})',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Hasil Batch Processing ────────────────────────────
          if (_results.isNotEmpty) ...[
            Card(
              elevation: 0,
              color: scheme.surfaceContainerHigh,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.receipt_long,
                            color: scheme.primary, size: 22),
                        const SizedBox(width: 8),
                        Text(
                          'Hasil Presensi',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${_results.length} pegawai',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1),
                    const SizedBox(height: 8),
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (ctx, i) {
                        final r = _results[i];
                        final isOk = r['status'] == 'ok';
                        final name = (r['name'] ?? '-').toString();
                        final nik = (r['nik'] ?? '-').toString();
                        final msg = (r['msg'] ?? '').toString();
                        final overtimeHours = (r['overtime_hours'] ?? 0) as num;
                        final hasOvertime = overtimeHours > 0;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isOk
                                ? Colors.green.shade50
                                : Colors.red.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isOk
                                  ? Colors.green.shade200
                                  : Colors.red.shade200,
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isOk
                                    ? Icons.check_circle
                                    : Icons.error,
                                color: isOk
                                    ? Colors.green.shade700
                                    : Colors.red.shade700,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                              color: isOk
                                                  ? Colors.green.shade900
                                                  : Colors.red.shade900,
                                            ),
                                          ),
                                        ),
                                        if (isOk && hasOvertime) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.orange.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                              border: Border.all(
                                                  color: Colors.orange.shade300),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.access_time,
                                                    size: 10,
                                                    color: Colors.orange.shade800),
                                                const SizedBox(width: 3),
                                                Text(
                                                  'LEMBUR',
                                                  style: TextStyle(
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.w700,
                                                    color: Colors.orange.shade800,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      'NIK: $nik',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: isOk
                                            ? Colors.green.shade700
                                            : Colors.red.shade700,
                                      ),
                                    ),
                                    if (msg.isNotEmpty) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        msg,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isOk
                                              ? Colors.green.shade600
                                              : Colors.red.shade600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
