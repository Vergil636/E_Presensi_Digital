// lib/pages/edit_gaji_page.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';

class EditGajiPage extends StatefulWidget {
  const EditGajiPage({super.key});

  @override
  State<EditGajiPage> createState() => _EditGajiPageState();
}

class _EditGajiPageState extends State<EditGajiPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _employees = [];
  List<Map<String, dynamic>> _filtered = [];
  final _searchCtrl = TextEditingController();

  // ── Warna tema ──────────────────────────────────────────────────
  static const _primary = Color(0xFF1565C0);
  static const _accent = Color(0xFF0D47A1);

  @override
  void initState() {
    super.initState();
    _loadData();
    _searchCtrl.addListener(() => _applyFilter(_searchCtrl.text));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final emps = await fetchEmployees();
      setState(() {
        _employees = emps;
        _filtered = emps;
      });
    } catch (e) {
      if (mounted) _showSnack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilter(String q) {
    final query = q.toLowerCase().trim();
    setState(() {
      _filtered = query.isEmpty
          ? _employees
          : _employees.where((e) {
              final name = (e['name'] ?? '').toString().toLowerCase();
              final pos = (e['position'] ?? '').toString().toLowerCase();
              final nik = (e['nik'] ?? '').toString().toLowerCase();
              return name.contains(query) ||
                  pos.contains(query) ||
                  nik.contains(query);
            }).toList();
    });
  }

  // ── Format Rupiah ───────────────────────────────────────────────
  String _rp(double v) {
    if (v == 0) return 'Rp 0';
    final s = v
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return 'Rp $s';
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        backgroundColor: isError ? Colors.red.shade700 : Colors.green.shade700,
      ),
    );
  }

  // ── Hitung upah lembur per jam ─────────────────────────────────
  // Rumus: gaji_pokok / 8 = upah lembur per jam
  double _upahLemburPerJam(double gajiPokok) => gajiPokok / 8;

  // ── Dialog Edit Gaji ────────────────────────────────────────────
  void _showEditDialog(Map<String, dynamic> emp) {
    final gajiSaatIni = double.tryParse('${emp['salary'] ?? 0}') ?? 0;
    final ctrl = TextEditingController(
      text: gajiSaatIni == 0 ? '' : gajiSaatIni.toStringAsFixed(0),
    );
    // State lokal untuk preview di dalam dialog
    double previewGaji = gajiSaatIni;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlgState) {
          final upahLembur = _upahLemburPerJam(previewGaji);
          return Dialog(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Container(
              width: 420,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                color: Colors.white,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Header gradient ──────────────────────────────
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_primary, _accent],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(20),
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          child: Text(
                            (emp['name'] ?? '?')
                                .toString()
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                (emp['name'] ?? '-').toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                (emp['position'] ?? '-').toString(),
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                              if ((emp['nik'] ?? '').toString().isNotEmpty)
                                Text(
                                  'NIK: ${emp['nik']}',
                                  style: const TextStyle(
                                    color: Colors.white60,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Body ────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Input gaji
                        const Text(
                          'Gaji Pokok',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: ctrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          onChanged: (v) {
                            setDlgState(() {
                              previewGaji = double.tryParse(v) ?? 0;
                            });
                          },
                          decoration: InputDecoration(
                            prefixText: 'Rp ',
                            hintText: 'Contoh: 3500000',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: _primary,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // ── Preview kalkulasi lembur ─────────────
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF0F4FF),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: _primary.withOpacity(0.25),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
                                  Icon(Icons.calculate_outlined,
                                      size: 16, color: _primary),
                                  SizedBox(width: 6),
                                  Text(
                                    'Kalkulasi Otomatis',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                      color: _primary,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              _previewRow(
                                'Gaji Pokok',
                                _rp(previewGaji),
                                bold: true,
                              ),
                              const Divider(height: 12),
                              _previewRow(
                                'Upah Lembur / Jam',
                                _rp(upahLembur),
                                highlight: true,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Formula: Gaji Pokok ÷ 8',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.blueGrey.shade400,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Action buttons ───────────────────────────────
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Batal'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: _primary,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.save_outlined, size: 18),
                            label: const Text(
                              'Simpan Gaji',
                              style: TextStyle(fontWeight: FontWeight.w700),
                            ),
                            onPressed: () async {
                              final val =
                                  double.tryParse(ctrl.text.trim());
                              if (val == null || val <= 0) {
                                _showSnack(
                                  'Masukkan nominal gaji yang valid.',
                                  isError: true,
                                );
                                return;
                              }
                              Navigator.pop(ctx);
                              await _saveSalary(
                                  emp['id'].toString(), val);
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _previewRow(String label, String value,
      {bool bold = false, bool highlight = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.black54,
            fontWeight: bold ? FontWeight.w700 : FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: highlight ? _primary : Colors.black87,
          ),
        ),
      ],
    );
  }

  Future<void> _saveSalary(String employeeId, double salary) async {
    try {
      await supabase
          .from('employees')
          .update({'salary': salary}).eq('id', employeeId);
      _showSnack('Gaji berhasil disimpan ✓');
      await _loadData();
    } catch (e) {
      _showSnack(e.toString(), isError: true);
    }
  }

  // ── Statistik ringkas ────────────────────────────────────────────
  int get _totalSet =>
      _employees.where((e) => (double.tryParse('${e['salary'] ?? 0}') ?? 0) > 0).length;
  int get _totalBelum =>
      _employees.length - _totalSet;
  double get _totalGaji => _employees.fold(
      0.0, (sum, e) => sum + (double.tryParse('${e['salary'] ?? 0}') ?? 0));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F6FB),
      appBar: AppBar(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Edit Gaji Pegawai',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        leading: const BackButton(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: _primary),
            )
          : Column(
              children: [
                // ── Banner biru ────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [_primary, Color(0xFF1976D2)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ── KPI chips ────────────────────────────────
                      LayoutBuilder(builder: (ctx, c) {
                        final cols = c.maxWidth >= 480 ? 3 : 1;
                        return GridView.count(
                          crossAxisCount: cols,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                          childAspectRatio: cols == 3 ? 2.5 : 4,
                          children: [
                            _kpiChip(
                                Icons.people, 'Total Pegawai',
                                '${_employees.length}'),
                            _kpiChip(
                                Icons.check_circle_outline, 'Gaji Diatur',
                                '$_totalSet'),
                            _kpiChip(
                                Icons.warning_amber_outlined, 'Belum Diatur',
                                '$_totalBelum',
                                warn: _totalBelum > 0),
                          ],
                        );
                      }),

                      const SizedBox(height: 12),

                      // ── Info formula lembur ───────────────────────
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.info_outline,
                                color: Colors.white70, size: 16),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Upah lembur/jam = Gaji Pokok ÷ 8  '
                                '(dihitung otomatis dari gaji pokok)',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Search bar ─────────────────────────────────────
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
                  child: TextField(
                    controller: _searchCtrl,
                    decoration: InputDecoration(
                      hintText: 'Cari nama, posisi, atau NIK...',
                      prefixIcon:
                          const Icon(Icons.search, color: Colors.black38),
                      suffixIcon: _searchCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () {
                                _searchCtrl.clear();
                                _applyFilter('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                    ),
                  ),
                ),

                // ── Daftar pegawai ─────────────────────────────────
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.search_off,
                                  size: 48, color: Colors.grey.shade400),
                              const SizedBox(height: 12),
                              Text(
                                'Pegawai tidak ditemukan',
                                style: TextStyle(color: Colors.grey.shade500),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                          itemCount: _filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 10),
                          itemBuilder: (_, i) => _buildEmployeeCard(i),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _kpiChip(IconData icon, String label, String value,
      {bool warn = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: warn ? Colors.orange.shade300 : Colors.white30,
        ),
      ),
      child: Row(
        children: [
          Icon(icon,
              color: warn ? Colors.orange.shade200 : Colors.white70,
              size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                      color: Colors.white70, fontSize: 11),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmployeeCard(int i) {
    final e = _filtered[i];
    final name = (e['name'] ?? '-').toString();
    final pos = (e['position'] ?? '-').toString();
    final nik = (e['nik'] ?? '').toString();
    final gajiPokok = double.tryParse('${e['salary'] ?? 0}') ?? 0;
    final upahLemburJam = _upahLemburPerJam(gajiPokok);
    final belumDiatur = gajiPokok == 0;

    // Warna avatar berdasarkan index
    final avatarColors = [
      const Color(0xFF1565C0),
      const Color(0xFF2E7D32),
      const Color(0xFFAD1457),
      const Color(0xFF6A1B9A),
      const Color(0xFF00695C),
      const Color(0xFFE65100),
    ];
    final avatarColor = avatarColors[i % avatarColors.length];

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      elevation: 0,
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showEditDialog(e),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: belumDiatur
                  ? Colors.orange.shade200
                  : Colors.grey.shade200,
              width: belumDiatur ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 24,
                backgroundColor: avatarColor,
                child: Text(
                  name.isNotEmpty ? name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Info pegawai
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pos,
                      style: const TextStyle(
                          fontSize: 12, color: Colors.black54),
                    ),
                    if (nik.isNotEmpty)
                      Text(
                        'NIK: $nik',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black38),
                      ),
                    const SizedBox(height: 8),
                    // Gaji + Lembur info
                    if (!belumDiatur) ...[
                      Row(
                        children: [
                          _infoTag(
                            Icons.payments_outlined,
                            _rp(gajiPokok),
                            const Color(0xFF1565C0),
                          ),
                          const SizedBox(width: 8),
                          _infoTag(
                            Icons.access_time,
                            '${_rp(upahLemburJam)}/jam',
                            Colors.teal.shade700,
                          ),
                        ],
                      ),
                    ] else ...[
                      _infoTag(
                        Icons.warning_amber_rounded,
                        'Gaji belum diatur',
                        Colors.orange.shade700,
                      ),
                    ],
                  ],
                ),
              ),

              // Tombol edit
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: belumDiatur
                      ? Colors.orange.shade50
                      : const Color(0xFFEEF2FF),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.edit_outlined,
                  size: 20,
                  color: belumDiatur ? Colors.orange.shade700 : _primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoTag(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
