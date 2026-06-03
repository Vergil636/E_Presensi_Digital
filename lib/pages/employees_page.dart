// lib/pages/employees_page.dart
import 'dart:convert';
import 'dart:html' as html;
// removed unused dart:typed_data import
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:flutter/services.dart';

import '../services/supabase_service.dart';
import '../widgets/dashboard_back_button.dart';

class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key});

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  final _searchC = TextEditingController();
  bool _loading = false;
  List<Map<String, dynamic>> _rows = [];

  // indeks baris yang sedang “expanded” untuk menampilkan QR
  final Set<int> _expanded = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await fetchEmployees(); // dari supabase_service.dart
      setState(() => _rows = data);
      _expanded.clear();
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // ================== CETAK QR via IFRAME (stabil & tanpa error mouse tracker) ==================
  Future<void> _printQrValue(String value) async {
    try {
      // Render QR ke PNG (resolusi tinggi untuk cetak tajam)
      final painter = QrPainter(
        data: value,
        version: QrVersions.auto,
        gapless: true,
        color: Colors.black,
        emptyColor: Colors.white,
      );
      final byteData = await painter.toImageData(1200);
      if (byteData == null) {
        _snack('Gagal membuat gambar QR.');
        return;
      }
      final b64 = base64Encode(byteData.buffer.asUint8List());

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
      img { width: 6cm; height: 6cm; }
    </style>
  </head>
  <body>
    <div class="wrap"><img src="data:image/png;base64,$b64"/></div>
    <script>
      window.onload = function(){
        window.focus();
        window.print();
        setTimeout(function(){ window.close(); }, 300);
      };
    </script>
  </body>
</html>
''';

      final blob = html.Blob([htmlContent], 'text/html');
      final url = html.Url.createObjectUrlFromBlob(blob);

      final iframe = html.IFrameElement()
        ..style.border = '0'
        ..style.width = '1px'
        ..style.height = '1px'
        ..style.opacity = '0'
        ..style.position = 'fixed'
        ..style.left = '-9999px'
        ..style.pointerEvents = 'none'
        ..tabIndex = -1
        ..src = url;

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
      _snack('Gagal mencetak: $e');
    }
  }
  // =======================================================================

  Future<void> _confirmDeleteEmployee({
    required String id,
    required String name,
    required int listIndex,
  }) async {
    final scheme = Theme.of(context).colorScheme;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Pegawai'),
        content: Text(
          'Yakin ingin menghapus data pegawai:\n\n$name\n\n'
          'Tindakan ini tidak bisa dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await deleteEmployee(id); // <-- fungsi di supabase_service.dart
      _snack('Pegawai "$name" berhasil dihapus.');
      // Hapus dari list lokal agar terasa instan
      setState(() {
        _rows.removeAt(listIndex);
        _expanded.remove(listIndex);
      });
    } catch (e) {
      _snack(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final filtered = _rows.where((r) {
      final q = _searchC.text.trim().toLowerCase();
      if (q.isEmpty) return true;
      final name = (r['name'] ?? '').toString().toLowerCase();
      final nik = (r['nik'] ?? '').toString().toLowerCase();
      final pos = (r['position'] ?? '').toString().toLowerCase();
      final code = (r['code'] ?? '').toString().toLowerCase();
      return name.contains(q) || nik.contains(q) || pos.contains(q) || code.contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daftar Pegawai'),
        actions: [
          const DashboardBackButton(),
          IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _searchC,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Cari nama / NIK / posisi...',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      final r = filtered[i];
                      final id = (r['id'] ?? '').toString();
                      final name = (r['name'] ?? '').toString();
                      final nik = (r['nik'] ?? '').toString();
                      final pos = (r['position'] ?? '').toString();
                      final codeRaw = (r['code'] ?? '').toString();
                      final code = codeRaw.trim().isEmpty ? nik : codeRaw;

                      final isOpen = _expanded.contains(i);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Material(
                            color: scheme.surfaceContainerHigh,
                            borderRadius: BorderRadius.circular(12),
                            child: ListTile(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              leading: CircleAvatar(
                                backgroundColor: scheme.secondaryContainer,
                                child: Text(
                                  name.isNotEmpty ? name.characters.first.toUpperCase() : '?',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              title: Text(name, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Wrap(
                                  runSpacing: 4,
                                  spacing: 16,
                                  children: [
                                    _Info('NIK', nik),
                                    _Info('Posisi', pos),
                                    _Info('CODE', code),
                                    _Info('Dibuat', (r['created_at'] ?? '').toString()),
                                  ],
                                ),
                              ),
                              trailing: PopupMenuButton<String>(
                                tooltip: 'Aksi',
                                onSelected: (value) {
                                  if (value == 'toggle_qr') {
                                    setState(() {
                                      if (isOpen) {
                                        _expanded.remove(i);
                                      } else {
                                        _expanded.add(i);
                                      }
                                    });
                                  } else if (value == 'delete') {
                                    _confirmDeleteEmployee(
                                      id: id,
                                      name: name,
                                      listIndex: i,
                                    );
                                  }
                                },
                                itemBuilder: (_) => [
                                  PopupMenuItem<String>(
                                    value: 'toggle_qr',
                                    child: Row(
                                      children: [
                                        Icon(isOpen ? Icons.close : Icons.qr_code_2_outlined),
                                        const SizedBox(width: 8),
                                        Text(isOpen ? 'Sembunyikan QR' : 'Tampilkan QR'),
                                      ],
                                    ),
                                  ),
                                  const PopupMenuDivider(),
                                  PopupMenuItem<String>(
                                    value: 'delete',
                                    child: Row(
                                      children: const [
                                        Icon(Icons.delete_outline, color: Colors.red),
                                        SizedBox(width: 8),
                                        Text(
                                          'Hapus pegawai',
                                          style: TextStyle(color: Colors.red),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Bagian QR yang langsung muncul di bawah item saat ikon diklik
                          if (isOpen)
                            Container(
                              margin: const EdgeInsets.only(top: 8),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: scheme.surface,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: scheme.outlineVariant),
                              ),
                              child: Column(
                                children: [
                                  QrImageView(
                                    data: code,
                                    version: QrVersions.auto,
                                    size: 240,
                                    gapless: true,
                                  ),
                                  const SizedBox(height: 8),
                                  SelectableText(
                                    code,
                                    textAlign: TextAlign.center,
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          Clipboard.setData(ClipboardData(text: code));
                                          _snack('QR value disalin');
                                        },
                                        icon: const Icon(Icons.copy_all_outlined),
                                        label: const Text('Salin'),
                                      ),
                                      FilledButton.icon(
                                        onPressed: () => _printQrValue(code),
                                        icon: const Icon(Icons.print_outlined),
                                        label: const Text('Cetak'),
                                      ),
                                    ],
                                  )
                                ],
                              ),
                            ),
                        ],
                      );
                    },
                  ),
          ),
        ],
      ),
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
      children: [
        Text('$label: ', style: styleLabel),
        Text(value, style: styleValue),
      ],
    );
  }
}
