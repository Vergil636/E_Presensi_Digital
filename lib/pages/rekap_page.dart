// lib/pages/rekap_page.dart
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

import '../services/supabase_service.dart';

class RekapPage extends StatefulWidget {
  const RekapPage({super.key});

  @override
  State<RekapPage> createState() => _RekapPageState();
}

class _RekapPageState extends State<RekapPage> {
  bool _loading = false;
  List<Map<String, dynamic>> _rows = [];
  DateTimeRange? _selectedRange;

  @override
  void initState() {
    super.initState();
    _loadDefault();
  }

  Future<void> _loadDefault() async {
    final today = DateTime.now();
    final start = today.subtract(const Duration(days: 7));
    _selectedRange = DateTimeRange(start: start, end: today);
    await _loadRekap();
  }

  Future<void> _loadRekap() async {
    if (_selectedRange == null) return;
    setState(() => _loading = true);
    try {
      final rows = await listAttendanceDaily(
        from: _startOfDay(_selectedRange!.start),
        to: _endOfDay(_selectedRange!.end),
      );
      setState(() => _rows = rows);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59);

  // ========================= PDF EXPORT =========================
  Future<void> _exportPdf() async {
    if (_rows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data untuk diekspor.')),
      );
      return;
    }

    final totalOvertime = _sumInt(_rows, 'total_overtime_minutes');
    final totalLate = _sumInt(_rows, 'total_minutes_late');

    final from = _selectedRange?.start ?? DateTime.now();
    final to = _selectedRange?.end ?? DateTime.now();
    final dfHeader = DateFormat('dd MMM yyyy', 'id_ID');

    // Build PDF
    final doc = pw.Document();

    // Header styles
    final titleStyle = pw.TextStyle(
      fontSize: 16,
      fontWeight: pw.FontWeight.bold,
    );
    final smallStyle = const pw.TextStyle(fontSize: 9);

    // Tabel header
    final tableHeaders = <String>[
      'Tanggal',
      'Nama',
      'Posisi',
      'Masuk',
      'Pulang',
      'Telat (m)',
      'Lembur (m)',
    ];

    // Tabel rows (format rapi)
    final tableData = _rows.map<List<String>>((r) {
      final tanggal = _safeDate(r['work_date'], onlyDate: true);
      final masuk = _safeDate(r['first_in_at']);
      final pulang = _safeDate(r['last_out_at']);
      final telat = _safeInt(r['total_minutes_late']).toString();
      final lembur = _safeInt(r['total_overtime_minutes']).toString();

      return [
        tanggal,
        (r['name'] ?? '-').toString(),
        (r['position'] ?? '-').toString(),
        masuk,
        pulang,
        telat,
        lembur,
      ];
    }).toList();

    // Halaman A4 portrait
    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 40),
          theme: pw.ThemeData.withFont(),
        ),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Rekap Absensi Harian', style: titleStyle),
            pw.SizedBox(height: 4),
            pw.Text(
              'Periode: ${dfHeader.format(_startOfDay(from))} s/d ${dfHeader.format(_endOfDay(to))}',
              style: smallStyle,
            ),
            pw.SizedBox(height: 8),
            pw.Container(height: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 8),
          ],
        ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Dibuat: ${DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(DateTime.now())}',
              style: smallStyle,
            ),
            pw.Text('Hal. ${ctx.pageNumber}/${ctx.pagesCount}', style: smallStyle),
          ],
        ),
        build: (ctx) => [
          // Ringkasan Box
          pw.Container(
            padding: const pw.EdgeInsets.all(8),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
              borderRadius: pw.BorderRadius.circular(6),
              color: PdfColors.grey100,
            ),
            child: pw.Row(
              children: [
                _summaryBox('Total Lembur', '$totalOvertime menit'),
                pw.SizedBox(width: 12),
                _summaryBox('Total Keterlambatan', '$totalLate menit'),
              ],
            ),
          ),
          pw.SizedBox(height: 12),

          // Tabel data
          pw.Table.fromTextArray(
            cellAlignment: pw.Alignment.centerLeft,
            headerAlignment: pw.Alignment.centerLeft,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.black,
              fontSize: 9.5,
            ),
            cellStyle: const pw.TextStyle(fontSize: 9),
            rowDecoration: const pw.BoxDecoration(),
            cellPadding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 6),
            border: pw.TableBorder.all(
              color: PdfColors.grey400,
              width: 0.4,
            ),
            headers: tableHeaders,
            data: tableData,
            columnWidths: {
              0: const pw.FixedColumnWidth(68),  // Tanggal
              1: const pw.FlexColumnWidth(2),    // Nama
              2: const pw.FlexColumnWidth(1.4),  // Posisi
              3: const pw.FixedColumnWidth(54),  // Masuk
              4: const pw.FixedColumnWidth(54),  // Pulang
              5: const pw.FixedColumnWidth(54),  // Telat
              6: const pw.FixedColumnWidth(60),  // Lembur
            },
          ),
        ],
      ),
    );

    final bytes = await doc.save();
    _downloadPdf(bytes, 'rekap_absensi_${DateFormat('yyyyMMdd').format(from)}-${DateFormat('yyyyMMdd').format(to)}.pdf');
  }

  pw.Widget _summaryBox(String label, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey400, width: 0.5),
          borderRadius: pw.BorderRadius.circular(6),
          color: PdfColors.white,
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _downloadPdf(Uint8List bytes, String filename) {
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    html.AnchorElement(href: url)
      ..download = filename
      ..click();
    html.Url.revokeObjectUrl(url);
  }
  // ======================= END PDF EXPORT =======================

  int _sumInt(List<Map<String, dynamic>> rows, String key) {
    return rows.fold<int>(0, (t, e) {
      final v = e[key];
      if (v is int) return t + v;
      if (v is String) return t + (int.tryParse(v) ?? 0);
      return t;
    });
  }

  String _safeDate(dynamic v, {bool onlyDate = false}) {
    if (v == null) return '-';
    if (v is DateTime) {
      return onlyDate
          ? DateFormat('dd MMM yyyy', 'id_ID').format(v)
          : DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(v);
    }
    // Supabase biasanya kirim string ISO
    final dt = DateTime.tryParse(v.toString());
    if (dt == null) return '-';
    return onlyDate
        ? DateFormat('dd MMM yyyy', 'id_ID').format(dt.toLocal())
        : DateFormat('dd MMM yyyy HH:mm', 'id_ID').format(dt.toLocal());
  }

  int _safeInt(dynamic v) {
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final totalOvertime = _sumInt(_rows, 'total_overtime_minutes');
    final totalLate = _sumInt(_rows, 'total_minutes_late');

    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        elevation: 1,
        title: const Text('Rekap Absensi Harian'),
        actions: [
          IconButton(
            tooltip: 'Pilih Rentang Tanggal',
            icon: const Icon(Icons.calendar_today),
            onPressed: () async {
              final now = DateTime.now();
              final picked = await showDateRangePicker(
                context: context,
                firstDate: DateTime(now.year - 1),
                lastDate: DateTime(now.year + 1),
                initialDateRange: _selectedRange,
              );
              if (picked != null) {
                setState(() => _selectedRange = picked);
                await _loadRekap();
              }
            },
          ),
          IconButton(
            tooltip: 'Export ke PDF',
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _exportPdf,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _rows.isEmpty
              ? const Center(
                  child: Text(
                    'Belum ada data absensi.',
                    style: TextStyle(fontSize: 16),
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _rows.length,
                        itemBuilder: (context, i) {
                          final r = _rows[i];
                          return Card(
                            elevation: 0.8,
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(Icons.person,
                                          color: Colors.teal, size: 22),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${r['name'] ?? '-'}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                      const Spacer(),
                                      Text(
                                        (r['position'] ?? '-').toString(),
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Tanggal: ${_safeDate(r['work_date'], onlyDate: true)}',
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.login,
                                          size: 18, color: Colors.green),
                                      const SizedBox(width: 4),
                                      Text('Masuk: ${_safeDate(r['first_in_at'])}'),
                                      const SizedBox(width: 16),
                                      const Icon(Icons.logout,
                                          size: 18, color: Colors.red),
                                      const SizedBox(width: 4),
                                      Text('Pulang: ${_safeDate(r['last_out_at'])}'),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text(
                                        'Telat: ${_safeInt(r['total_minutes_late'])} menit',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.orange.shade800,
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Text(
                                        'Lembur: ${_safeInt(r['total_overtime_minutes'])} menit',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.blue.shade800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Ringkasan total
                    Container(
                      width: double.infinity,
                      color: Colors.white,
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Divider(),
                          Text(
                            '📊 Ringkasan',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: _SummaryCard(
                                  icon: Icons.alarm_on_outlined,
                                  label: 'Total Lembur',
                                  value: '$totalOvertime menit',
                                  color: Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _SummaryCard(
                                  icon: Icons.timer_off_outlined,
                                  label: 'Total Keterlambatan',
                                  value: '$totalLate menit',
                                  color: Colors.orange,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }
}

// ================== UI WIDGETS ==================
class _SummaryCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _SummaryCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0.6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 26),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  Text(value,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: color,
                        fontSize: 15,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ================== (Fallback) RPC Lokal ==================
// Kalau kamu sudah memindahkan ke supabase_service.dart, hapus bagian ini.
Future<List<Map<String, dynamic>>> listAttendanceDaily({
  required DateTime from,
  required DateTime to,
}) async {
  final res = await supabase.rpc('list_attendance_daily', params: {
    // Tips: untuk Postgres DATE, bisa kirim "YYYY-MM-DD"
    'p_from': DateFormat('yyyy-MM-dd').format(from),
    'p_to': DateFormat('yyyy-MM-dd').format(to),
  });
  if (res is List) return res.cast<Map<String, dynamic>>();
  return [];
}
