// lib/pages/scan_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../services/supabase_service.dart';

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

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

  Future<void> _handleScan(String? value) async {
    final code = value?.trim();
    if (code == null || code.isEmpty) return;
    if (_busy) return;

    _setBusyShort();
    try {
      final res = await markAttendance(scannedValue: code, type: _atype);
      setState(() => _lastResult = res);
      _showSnack('Berhasil: ${_atype == 'IN' ? 'MASUK' : 'PULANG'} untuk $code');
    } catch (e) {
      _showSnack(e.toString());
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
        title: const Text('Scan QR (IN/OUT)'),
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
          // Selector IN / OUT
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

          // Scanner camera
          Card(
            elevation: 0,
            clipBehavior: Clip.antiAlias,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: scheme.outlineVariant),
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
                        color: scheme.surface.withOpacity(.8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _busy
                            ? 'Memproses...'
                            : 'Arahkan kamera ke QR (NIK/CODE)',
                        style: Theme.of(context)
                            .textTheme
                            .labelLarge
                            ?.copyWith(fontWeight: FontWeight.w700),
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
                        onPressed: _busy ? null : _submitManual,
                        icon: _busy
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send_rounded),
                        label: const Text('Kirim'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Hasil terakhir
          if (_lastResult != null) _LastResultCard(data: _lastResult!),
        ],
      ),
    );
  }
}

class _LastResultCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _LastResultCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    String atype = (data['atype'] ?? '').toString();
    String scanned = (data['scanned_value'] ?? '').toString();
    String localTs = (data['local_scanned_at'] ?? data['scanned_at'] ?? '').toString();
    bool isOT = (data['is_overtime'] ?? false) == true;
    int otMin = int.tryParse('${data['overtime_minutes'] ?? 0}') ?? 0;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHigh,
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
                _kv('Tipe', atype),
                _kv('QR', scanned),
                _kv('Waktu (lokal)', localTs),
                _kv('Lembur', isOT ? 'Ya' : 'Tidak'),
                if (isOT) _kv('Menit lembur', '$otMin'),
              ],
            ),
            const SizedBox(height: 12),
            if (atype == 'OUT')
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
