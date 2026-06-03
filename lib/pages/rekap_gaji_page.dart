// lib/pages/rekap_gaji_page.dart
import 'dart:html' as html;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/supabase_service.dart';
import '../services/slip_gaji_service.dart';

class RekapGajiPage extends StatefulWidget {
  const RekapGajiPage({super.key});

  @override
  State<RekapGajiPage> createState() => _RekapGajiPageState();
}

class _RekapGajiPageState extends State<RekapGajiPage> {
  bool _loading = true;
  List<_RowData> _allRows = [];
  List<_RowData> _filteredRows = [];
  final _searchCtrl = TextEditingController();

  // Rentang tanggal periode rekap
  DateTimeRange? _selectedRange;

  // Realtime
  RealtimeChannel? _channel;
  bool _liveUpdate = false; // animasi indikator

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Default 1 minggu terakhir
    final start = now.subtract(const Duration(days: 7));
    _selectedRange = DateTimeRange(start: start, end: now);
    _loadData();
    _subscribeRealtime();
  }

  // ── Supabase Realtime: dengarkan tabel attendance & salary_deductions ─────────────────
  void _subscribeRealtime() {
    // Listen to attendance changes
    _channel = supabase
        .channel('rekap_gaji_attendance')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'attendance',
          callback: (payload) {
            // Tampilkan indikator sebentar lalu reload
            if (!mounted) return;
            setState(() => _liveUpdate = true);
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) setState(() => _liveUpdate = false);
            });
            _loadData();
          },
        )
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'salary_deductions',
          callback: (payload) {
            // Tampilkan indikator sebentar lalu reload
            if (!mounted) return;
            setState(() => _liveUpdate = true);
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) setState(() => _liveUpdate = false);
            });
            _loadData();
          },
        )
        .subscribe();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _channel?.unsubscribe();
    super.dispose();
  }

  // ── Format Rp ─────────────────────────────────────────────────────
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

  // ── Load data ─────────────────────────────────────────────────────
  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // Rentang tanggal yang dipilih
      final from = DateTime(_selectedRange!.start.year, _selectedRange!.start.month, _selectedRange!.start.day);
      final to = DateTime(_selectedRange!.end.year, _selectedRange!.end.month, _selectedRange!.end.day, 23, 59, 59);

      // Ambil semua rekap absensi periode ini
      final rows = await listAttendanceDaily(from: from, to: to, limit: 500);

      // Ambil semua pegawai (untuk salary & nama lengkap)
      final emps = await fetchEmployees();
      final empMap = <String, Map<String, dynamic>>{};
      for (final e in emps) {
        empMap[(e['id'] ?? '').toString()] = e;
      }

      // Ambil semua potongan untuk periode ini
      final fromDate = DateFormat('yyyy-MM-dd').format(from);
      final toDate = DateFormat('yyyy-MM-dd').format(to);
      final deductions = await supabase
          .from('salary_deductions')
          .select('employee_id, amount, status')
          .gte('deduction_date', fromDate)
          .lte('deduction_date', toDate)
          .eq('status', 'active'); // Hanya potongan yang aktif

      // Agregasi potongan per employee
      final deductionMap = <String, double>{};
      for (final d in deductions) {
        final empId = (d['employee_id'] ?? '').toString();
        final amount = double.tryParse('${d['amount'] ?? 0}') ?? 0;
        deductionMap[empId] = (deductionMap[empId] ?? 0) + amount;
      }

      // Agregasi per employee
      final agg = <String, _Aggregate>{};
      for (final r in rows) {
        final empId = (r['employee_id'] ?? '').toString();
        final name = (r['name'] ?? (empMap[empId]?['name']) ?? '-').toString();
        final position =
            (r['position'] ?? (empMap[empId]?['position']) ?? '-').toString();
        final nik = (empMap[empId]?['nik'] ?? '').toString();

        final hadir = (r['first_in_at'] ?? '') != '' ? 1 : 0;
        final lembur =
            int.tryParse('${r['total_overtime_minutes'] ?? 0}') ?? 0;

        agg.putIfAbsent(
          empId,
          () => _Aggregate(
            empId: empId,
            name: name,
            position: position,
            nik: nik,
          ),
        );
        agg[empId]!.hadir += hadir;
        agg[empId]!.lemburMenit += lembur;
      }

      // Tambahkan pegawai yang tidak hadir sama sekali
      for (final e in emps) {
        final id = (e['id'] ?? '').toString();
        agg.putIfAbsent(
          id,
          () => _Aggregate(
            empId: id,
            name: (e['name'] ?? '-').toString(),
            position: (e['position'] ?? '-').toString(),
            nik: (e['nik'] ?? '').toString(),
          ),
        );
      }

      // Bangun RowData
      final result = <_RowData>[];
      int no = 1;
      for (final agg_ in agg.values) {
        final emp = empMap[agg_.empId];
        final gajiPokok =
            double.tryParse('${emp?['salary'] ?? 0}') ?? 0;
        
        // Ambil total potongan dari salary_deductions (bukan dari field kasbon lama)
        final totalPotongan = deductionMap[agg_.empId] ?? 0;

        // Upah lembur: gaji_pokok / 8 = upah lembur per jam
        // lembur dalam menit → konversi ke jam: lemburMenit / 60
        final upahPerJam = gajiPokok / 8;
        final gajiLembur = upahPerJam * (agg_.lemburMenit / 60);
        final totalLembur = gajiLembur; // alias kolom
        
        // PERBAIKAN: Jumlah = (Gaji Pokok × Hari Hadir) + Total Lembur - Total Potongan
        final totalGajiPokok = gajiPokok * agg_.hadir;
        final jumlah = agg_.hadir == 0 ? 0.0 : (totalGajiPokok + gajiLembur - totalPotongan);

        result.add(_RowData(
          no: no++,
          name: agg_.name,
          position: agg_.position,
          nik: agg_.nik,
          hadir: agg_.hadir,
          gajiPokok: gajiPokok,
          gajiLembur: gajiLembur,
          lemburMenit: agg_.lemburMenit,
          kasbon: totalPotongan, // Ganti kasbon dengan total potongan
          totalLembur: totalLembur,
          jumlah: jumlah,
        ));
      }

      setState(() {
        _allRows = result;
        _filteredRows = result;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.toString()),
              behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applySearch(String q) {
    final query = q.toLowerCase().trim();
    setState(() {
      _filteredRows = query.isEmpty
          ? _allRows
          : _allRows.where((r) {
              return r.name.toLowerCase().contains(query) ||
                  r.nik.toLowerCase().contains(query) ||
                  r.position.toLowerCase().contains(query);
            }).toList();
    });
  }

  // ── Nama bulan ────────────────────────────────────────────────────
  static const _bulan = [
    '', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'
  ];

  // ========================= PDF EXPORT =========================
  Future<void> _exportPdf() async {
    if (_filteredRows.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data untuk diekspor.')),
      );
      return;
    }

    final doc = pw.Document();
    
    // Load signature image
    pw.ImageProvider? signatureImage;
    try {
      final signatureBytes = await rootBundle.load('assets/images/signature_iskandar.png');
      signatureImage = pw.MemoryImage(signatureBytes.buffer.asUint8List());
    } catch (e) {
      print('Failed to load signature image: $e');
      // Jika gagal load, signatureImage akan tetap null
    }

    final titleStyle = pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold);
    final smallStyle = const pw.TextStyle(fontSize: 9);
    final headerStyle = pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.black);
    final cellStyle = const pw.TextStyle(fontSize: 9, color: PdfColors.black);

    final tableHeaders = [
      'NO', 'NAMA', 'JABATAN', 'HADIR', 'GAJI POKOK',
      'LEMBUR/JAM', 'LEMBUR (jam)', 'POTONGAN', 'TOTAL LEMBUR', 'JUMLAH'
    ];

    double totalKeseluruhan = 0;
    
    final tableData = _filteredRows.map<List<String>>((r) {
      totalKeseluruhan += r.jumlah;
      final upahLemburPerJam = r.gajiPokok / 8;
      final lemburJam = r.lemburMenit / 60.0; // Konversi menit ke jam
      return [
        '${r.no}',
        r.name,
        r.position,
        '${r.hadir}',
        _rp(r.gajiPokok),
        r.gajiPokok > 0 ? _rp(upahLemburPerJam) : '-',
        lemburJam > 0 ? lemburJam.toStringAsFixed(1) : '0',
        r.kasbon > 0 ? _rp(r.kasbon) : '',
        _rp(r.totalLembur),
        _rp(r.jumlah),
      ];
    }).toList();

    tableData.add([
      '', '', '', '', '', '', '', '', 'TOTAL', _rp(totalKeseluruhan)
    ]);

    final String periodeLabel = _selectedRange != null 
        ? '${DateFormat('dd MMM yyyy', 'id_ID').format(_selectedRange!.start)} s/d ${DateFormat('dd MMM yyyy', 'id_ID').format(_selectedRange!.end)}'
        : '-';

    doc.addPage(
      pw.MultiPage(
        pageTheme: pw.PageTheme(
          margin: const pw.EdgeInsets.fromLTRB(24, 24, 24, 30),
          pageFormat: PdfPageFormat.a4.landscape, 
          theme: pw.ThemeData.withFont(),
        ),
        header: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Rekap Gaji Pegawai', style: titleStyle),
            pw.SizedBox(height: 4),
            pw.Text('Periode: $periodeLabel', style: smallStyle),
            pw.SizedBox(height: 8),
            pw.Container(height: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 12),
          ],
        ),
        footer: (ctx) => pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(
              'Dicetak: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())}',
              style: smallStyle,
            ),
            pw.Text('Hal. ${ctx.pageNumber}/${ctx.pagesCount}', style: smallStyle),
          ],
        ),
        build: (ctx) => [
          pw.Table.fromTextArray(
            cellAlignment: pw.Alignment.centerLeft,
            headerAlignment: pw.Alignment.center,
            headerDecoration: const pw.BoxDecoration(color: PdfColors.yellow),
            headerStyle: headerStyle,
            cellStyle: cellStyle,
            rowDecoration: const pw.BoxDecoration(),
            cellPadding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4),
            border: pw.TableBorder.all(color: PdfColors.grey500, width: 0.5),
            headers: tableHeaders,
            data: tableData,
            columnWidths: {
              0: const pw.FixedColumnWidth(25),
              1: const pw.FlexColumnWidth(2),
              2: const pw.FlexColumnWidth(1.5),
              3: const pw.FixedColumnWidth(40),
              4: const pw.FlexColumnWidth(1.2),
              5: const pw.FlexColumnWidth(1.2),
              6: const pw.FixedColumnWidth(55),
              7: const pw.FlexColumnWidth(1),
              8: const pw.FlexColumnWidth(1.2),
              9: const pw.FlexColumnWidth(1.3),
            },
            cellAlignments: {
              0: pw.Alignment.center,
              1: pw.Alignment.centerLeft,
              2: pw.Alignment.centerLeft,
              3: pw.Alignment.center,
              4: pw.Alignment.centerLeft,
              5: pw.Alignment.centerLeft,
              6: pw.Alignment.center,
              7: pw.Alignment.centerLeft,
              8: pw.Alignment.centerLeft,
              9: pw.Alignment.centerRight,
            },
          ),
          
          pw.SizedBox(height: 40),
          
          // Tanda Tangan
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    'Mengetahui,',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Admin',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  // Gambar tanda tangan atau placeholder
                  pw.Container(
                    width: 150,
                    height: 50,
                    child: signatureImage != null
                        ? pw.Image(signatureImage, fit: pw.BoxFit.contain)
                        : pw.Center(
                            child: pw.Text(
                              '( Tanda Tangan )',
                              style: pw.TextStyle(
                                fontSize: 20,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.grey400,
                                fontStyle: pw.FontStyle.italic,
                              ),
                            ),
                          ),
                  ),
                  pw.Container(
                    width: 150,
                    decoration: const pw.BoxDecoration(
                      border: pw.Border(
                        bottom: pw.BorderSide(width: 1, color: PdfColors.black),
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Iskandar',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    final String filePeriode = _selectedRange != null
        ? '${DateFormat('yyyyMMdd').format(_selectedRange!.start)}-${DateFormat('yyyyMMdd').format(_selectedRange!.end)}'
        : 'unknown';
    
    final bytes = await doc.save();
    _downloadPdf(bytes, 'rekap_gaji_$filePeriode.pdf');
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: const BackButton(color: Colors.black87),
        title: Row(
          children: [
            const Text(
              'Rekap gaji Pegawai',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 18,
                color: Colors.black87,
              ),
            ),
            const SizedBox(width: 10),
            // Indikator Live
            AnimatedOpacity(
              opacity: _liveUpdate ? 1.0 : 0.4,
              duration: const Duration(milliseconds: 400),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _liveUpdate ? Colors.green : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.circle,
                      size: 8,
                      color: _liveUpdate ? Colors.white : Colors.white70,
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.picture_as_pdf, color: Colors.redAccent),
            tooltip: 'Export ke PDF',
            onPressed: _exportPdf,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Banner update realtime ──────────────────────────────
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _liveUpdate ? 36 : 0,
            color: Colors.green.shade50,
            child: _liveUpdate
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.sync, size: 16, color: Colors.green),
                      SizedBox(width: 8),
                      Text(
                        'Data presensi diperbarui secara otomatis',
                        style: TextStyle(
                          color: Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
          // ── Periode Picker + Search ──────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Periode selector
                Row(
                  children: [
                    const Text(
                      'Periode: ',
                      style: TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _selectedRange != null
                          ? '${DateFormat('dd MMM yyyy', 'id_ID').format(_selectedRange!.start)} - ${DateFormat('dd MMM yyyy', 'id_ID').format(_selectedRange!.end)}'
                          : 'Pilih Periode',
                      style: const TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () async {
                        final now = DateTime.now();
                        final picked = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(now.year - 2),
                          lastDate: DateTime(now.year + 2),
                          initialDateRange: _selectedRange,
                        );
                        if (picked != null) {
                          setState(() => _selectedRange = picked);
                          _loadData();
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.blue.shade200),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.calendar_month, size: 14, color: Colors.blue),
                            SizedBox(width: 6),
                            Text('Ubah Periode', style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Search field
                SizedBox(
                  height: 40,
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _applySearch,
                    decoration: InputDecoration(
                      hintText: 'Cari Nama/NIK/Posisi',
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide:
                            BorderSide(color: Colors.grey.shade400),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide:
                            BorderSide(color: Colors.grey.shade400),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.search, size: 18),
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),

          // ── Tabel ─────────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRows.isEmpty
                    ? const Center(
                        child: Text(
                          'Tidak ada data.',
                          style: TextStyle(color: Colors.black45),
                        ),
                      )
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                          child: _buildTable(),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ── Tabel ─────────────────────────────────────────────────────────
  Widget _buildTable() {
    const headerColor = Color(0xFFFFFF00); // kuning persis seperti gambar
    const borderColor = Color(0xFF999999);
    const headerStyle = TextStyle(
      fontWeight: FontWeight.w700,
      fontSize: 11,
      color: Colors.black,
    );
    const cellStyle = TextStyle(fontSize: 11, color: Colors.black87);

    // Lebar kolom (11 kolom) - DIPERBAIKI untuk lebih proporsional
    const colW = [
      40.0,  // [0] NO
      140.0, // [1] NAMA (diperlebar)
      100.0, // [2] JABATAN
      50.0,  // [3] HADIR
      110.0, // [4] GAJI POKOK
      100.0, // [5] LEMBUR/JAM (tarif = gajiPokok ÷ 8)
      70.0,  // [6] LEMBUR (jam) - DIPERLEBAR
      100.0, // [7] KASBON
      110.0, // [8] TOTAL LEMBUR
      120.0, // [9] JUMLAH (diperlebar)
      60.0,  // [10] AKSI
    ];
    final headers = [
      'NO', 'NAMA', 'JABATAN', 'HADIR',
      'GAJI POKOK', 'LEMBUR/JAM', 'LEMBUR\n(jam)',
      'POTONGAN', 'TOTAL LEMBUR', 'JUMLAH', 'AKSI',
    ];

    TableBorder border = TableBorder.all(
      color: borderColor,
      width: 0.8,
    );

    TableRow headerRow = TableRow(
      decoration: const BoxDecoration(color: headerColor),
      children: List.generate(headers.length, (i) {
        return _cell(headers[i], colW[i], headerStyle,
            align: TextAlign.center, pad: 8); // Padding diperbesar
      }),
    );

    List<TableRow> dataRows = List.generate(_filteredRows.length, (i) {
      final r = _filteredRows[i];
      final bg = i.isOdd ? const Color(0xFFF9F9F9) : Colors.white;
      final upahLemburPerJam = r.gajiPokok / 8;
      final lemburJam = r.lemburMenit / 60.0; // Konversi menit ke jam

      return TableRow(
        decoration: BoxDecoration(color: bg),
        children: [
          _cell('${r.no}', colW[0], cellStyle,
              align: TextAlign.center, pad: 6),
          _cell(r.name, colW[1], cellStyle, pad: 6),
          _cell(r.position, colW[2], cellStyle, pad: 6),
          _cell('${r.hadir}', colW[3], cellStyle,
              align: TextAlign.center, pad: 6),
          _cell(_rp(r.gajiPokok), colW[4], cellStyle, 
              align: TextAlign.right, pad: 6), // Rata kanan
          _cell(
            r.gajiPokok > 0 ? _rp(upahLemburPerJam) : '-',
            colW[5],
            cellStyle.copyWith(
              color: r.gajiPokok > 0
                  ? const Color(0xFF1565C0)
                  : Colors.black38,
              fontWeight: r.gajiPokok > 0
                  ? FontWeight.w600
                  : FontWeight.normal,
            ),
            align: TextAlign.right, // Rata kanan
            pad: 6,
          ),
          _cell(
            lemburJam > 0 ? lemburJam.toStringAsFixed(1) : '0',
            colW[6],
            cellStyle,
            align: TextAlign.center,
            pad: 6,
          ),
          _cell(r.kasbon > 0 ? _rp(r.kasbon) : '', colW[7], cellStyle,
              align: TextAlign.right, pad: 6), // Rata kanan
          _cell(_rp(r.totalLembur), colW[8], cellStyle, 
              align: TextAlign.right, pad: 6), // Rata kanan
          _cell(
            _rp(r.jumlah),
            colW[9],
            cellStyle.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: 12, // Sedikit lebih besar
              color: Colors.black87, // DIPERBAIKI: warna lebih gelap, background kuning
            ),
            align: TextAlign.right, // Rata kanan
            pad: 6,
            bgColor: const Color(0xFFFFEB3B), // Background kuning cerah
          ),
          // Kolom AKSI - Tombol Cetak Slip Gaji
          Container(
            width: colW[10],
            padding: const EdgeInsets.all(5),
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.print, size: 18),
                color: Colors.blue.shade700,
                tooltip: 'Cetak Slip Gaji',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _cetakSlipGaji(r),
              ),
            ),
          ),
        ],
      );
    });

    double totalKeseluruhan = 0;
    for (final r in _filteredRows) {
      totalKeseluruhan += r.jumlah;
    }

    TableRow footerRow = TableRow(
      decoration: const BoxDecoration(color: Color(0xFFEEEEEE)),
      children: [
        _cell('', colW[0], cellStyle, pad: 6),
        _cell('', colW[1], cellStyle, pad: 6),
        _cell('', colW[2], cellStyle, pad: 6),
        _cell('', colW[3], cellStyle, pad: 6),
        _cell('', colW[4], cellStyle, pad: 6),
        _cell('', colW[5], cellStyle, pad: 6),
        _cell('', colW[6], cellStyle, pad: 6),
        _cell('', colW[7], cellStyle, pad: 6),
        _cell(
          'TOTAL',
          colW[8],
          cellStyle.copyWith(fontWeight: FontWeight.w800, fontSize: 11),
          align: TextAlign.right,
          pad: 6,
        ),
        _cell(
          _rp(totalKeseluruhan),
          colW[9],
          cellStyle.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 13,
            color: Colors.black87, // DIPERBAIKI: warna lebih gelap
          ),
          align: TextAlign.right,
          pad: 6,
          bgColor: const Color(0xFFFFEB3B), // Background kuning cerah
        ),
        _cell('', colW[10], cellStyle, pad: 6), // Kolom AKSI kosong
      ],
    );

    return Table(
      border: border,
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      columnWidths: {
        for (int i = 0; i < colW.length; i++)
          i: FixedColumnWidth(colW[i]),
      },
      children: [headerRow, ...dataRows, footerRow],
    );
  }

  Widget _cell(
    String text,
    double width,
    TextStyle style, {
    TextAlign align = TextAlign.left,
    double pad = 6,
    Color? bgColor,
  }) {
    return Container(
      width: width,
      color: bgColor,
      child: Padding(
        padding: EdgeInsets.all(pad),
        child: Text(
          text,
          style: style,
          textAlign: align,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  // ── Cetak Slip Gaji ───────────────────────────────────────────────
  Future<void> _cetakSlipGaji(_RowData row) async {
    try {
      // Ambil data employee lengkap
      final emps = await fetchEmployees();
      final employee = emps.firstWhere(
        (e) => (e['name'] ?? '').toString() == row.name,
        orElse: () => {},
      );

      if (employee.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Data karyawan tidak ditemukan')),
        );
        return;
      }

      // Data kehadiran untuk slip gaji
      final attendanceData = {
        'total_days': (_selectedRange!.end.difference(_selectedRange!.start).inDays + 1),
        'present_days': row.hadir,
        'total_late_minutes': 0, // Bisa ditambahkan jika ada data telat
        'total_overtime_minutes': row.lemburMenit,
      };

      // Generate slip gaji PDF
      await SlipGajiService.generateSlipGaji(
        employee: employee,
        periodeStart: _selectedRange!.start,
        periodeEnd: _selectedRange!.end,
        attendanceData: attendanceData,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Slip gaji berhasil dicetak!'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ── Data classes ───────────────────────────────────────────────────

class _Aggregate {
  final String empId;
  final String name;
  final String position;
  final String nik;
  int hadir = 0;
  int lemburMenit = 0;

  _Aggregate({
    required this.empId,
    required this.name,
    required this.position,
    required this.nik,
  });
}

class _RowData {
  final int no;
  final String name;
  final String position;
  final String nik;
  final int hadir;
  final double gajiPokok;
  final double gajiLembur;
  final int lemburMenit;
  final double kasbon;
  final double totalLembur;
  final double jumlah;

  const _RowData({
    required this.no,
    required this.name,
    required this.position,
    required this.nik,
    required this.hadir,
    required this.gajiPokok,
    required this.gajiLembur,
    required this.lemburMenit,
    required this.kasbon,
    required this.totalLembur,
    required this.jumlah,
  });
}
