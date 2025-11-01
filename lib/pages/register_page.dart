// lib/pages/register_page.dart
import 'dart:html' as html; // web interop
import 'dart:convert';
// removed unused dart:typed_data import

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../services/supabase_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();

  final _nameC = TextEditingController();
  final _nikC = TextEditingController();
  final _positionC = TextEditingController();
  final _codeC = TextEditingController();

  bool _loading = false;

  Map<String, dynamic>? _employee;
  String? _qrValue;

  @override
  void dispose() {
    _nameC.dispose();
    _nikC.dispose();
    _positionC.dispose();
    _codeC.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_loading) return;
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    setState(() => _loading = true);
    try {
      final res = await registerEmployee(
        name: _nameC.text.trim(),
        nik: _nikC.text.trim(),
        position: _positionC.text.trim(),
        code: _codeC.text.trim().isEmpty ? null : _codeC.text.trim(),
      );

      setState(() {
        _employee = res;
        _qrValue =
            (res['code'] as String?)?.trim().isNotEmpty == true ? res['code'] : res['nik'];
      });

      _showSnack('Registrasi berhasil.');
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _nameC.clear();
    _nikC.clear();
    _positionC.clear();
    _codeC.clear();
    setState(() {
      _employee = null;
      _qrValue = null;
    });
  }

  void _copyQR() {
    if (_qrValue == null) return;
    Clipboard.setData(ClipboardData(text: _qrValue!));
    _showSnack('QR value disalin: $_qrValue');
  }

  // ================== FIX CETAK WEB (pakai iframe) ==================
  Future<void> _printQR() async {
    if (_qrValue == null) return;
    try {
      // Render QR ke PNG (resolusi tinggi biar tajam saat dicetak)
      final painter = QrPainter(
        data: _qrValue!,
        version: QrVersions.auto,
        gapless: true,
        color: Colors.black,
        emptyColor: Colors.white,
      );
      final byteData = await painter.toImageData(1200);
      if (byteData == null) {
        _showSnack('Gagal menghasilkan gambar QR.');
        return;
      }
      final b64 = base64Encode(byteData.buffer.asUint8List());

      // HTML minimal untuk cetak — HANYA gambar QR
      final htmlContent = '''
<!doctype html>
<html>
  <head>
    <meta charset="utf-8">
    <title>Print QR</title>
    <style>
      @page { margin: 0; }
      html, body { height: 100%; margin: 0; background: #fff; }
      .wrap { height: 100%; display: flex; align-items: center; justify-content: center; }
      img { width: 6cm; height: 6cm; } /* ubah ukuran stiker di sini */
    </style>
  </head>
  <body>
    <div class="wrap">
      <img src="data:image/png;base64,$b64" />
    </div>
    <script>
      window.onload = function() {
        window.focus();
        window.print();
        setTimeout(function(){ window.close(); }, 300);
      };
    </script>
  </body>
</html>
''';

      // Buat Blob -> object URL -> muat di iframe tersembunyi -> print
      final blob = html.Blob([htmlContent], 'text/html');
      final url = html.Url.createObjectUrlFromBlob(blob);

      final iframe = html.IFrameElement()
        ..style.border = '0'
        ..style.width = '0'
        ..style.height = '0'
        ..style.position = 'fixed'
        ..style.left = '-9999px'
        ..src = url;

      // cleanup setelah selesai
      void cleanup() {
        iframe.remove();
        html.Url.revokeObjectUrl(url);
      }

      iframe.onLoad.listen((_) {
        final win = iframe.contentWindow;
        if (win != null) {
          (win as dynamic).focus();
          (win as dynamic).print();
        }
        Future.delayed(const Duration(seconds: 1), cleanup);
      });

      html.document.body?.append(iframe);
    } catch (e) {
      _showSnack('Gagal mencetak QR: $e');
    }
  }
  // ==================================================================

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
        title: const Text('Registrasi Pegawai'),
        actions: [
          TextButton.icon(
            onPressed: _resetForm,
            icon: const Icon(Icons.refresh),
            label: const Text('Reset'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: scheme.surfaceContainerHigh,
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.person_add_alt_1, color: scheme.primary),
                        const SizedBox(width: 8),
                        Text(
                          'Data Pegawai',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameC,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Nama Pegawai',
                        prefixIcon: Icon(Icons.badge_outlined),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Nama tidak boleh kosong';
                        if (v.trim().length < 2) return 'Nama terlalu pendek';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nikC,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'NIK / No Induk Pegawai',
                        prefixIcon: Icon(Icons.numbers),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'NIK tidak boleh kosong';
                        if (v.trim().length < 3) return 'NIK minimal 3 karakter';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _positionC,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Posisi / Jabatan',
                        prefixIcon: Icon(Icons.work_outline),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) return 'Posisi tidak boleh kosong';
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _codeC,
                      decoration: const InputDecoration(
                        labelText: 'CODE (opsional — default = NIK)',
                        prefixIcon: Icon(Icons.qr_code_2_outlined),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _submit,
                        icon: _loading
                            ? const SizedBox(
                                height: 18,
                                width: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.save_outlined),
                        label: const Text('Simpan & Buat QR'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_employee != null && _qrValue != null)
            Card(
              elevation: 0,
              color: scheme.surfaceContainerHighest,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _ResultWithQR(
                  employee: _employee!,
                  qrValue: _qrValue!,
                  onCopy: _copyQR,
                  onPrint: _printQR,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ResultWithQR extends StatelessWidget {
  final Map<String, dynamic> employee;
  final String qrValue;
  final VoidCallback onCopy;
  final Future<void> Function() onPrint;

  const _ResultWithQR({
    required this.employee,
    required this.qrValue,
    required this.onCopy,
    required this.onPrint,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pegawai terdaftar',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        Wrap(
          runSpacing: 8,
          spacing: 16,
          children: [
            _Info('Nama', (employee['name'] ?? '').toString()),
            _Info('NIK', (employee['nik'] ?? '').toString()),
            _Info('Posisi', (employee['position'] ?? '').toString()),
            _Info('CODE', (employee['code'] ?? '').toString()),
            _Info('Dibuat', (employee['created_at'] ?? '').toString()),
          ],
        ),
        const SizedBox(height: 16),
        Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              children: [
                QrImageView(data: qrValue, version: QrVersions.auto, size: 240, gapless: true),
                const SizedBox(height: 8),
                SelectableText(
                  qrValue,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onCopy,
                      icon: const Icon(Icons.copy_all_outlined),
                      label: const Text('Salin QR Value'),
                    ),
                    FilledButton.icon(
                      onPressed: onPrint,
                      icon: const Icon(Icons.print_outlined),
                      label: const Text('Cetak'),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Info extends StatelessWidget {
  final String label;
  final String value;
  const _Info(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    final styleLabel =
        Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w700);
    final styleValue = Theme.of(context).textTheme.labelMedium;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [Text('$label: ', style: styleLabel), Text(value, style: styleValue)],
    );
  }
}
