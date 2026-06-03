// lib/services/slip_gaji_service.dart
import 'dart:html' as html;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import 'supabase_service.dart';

class SlipGajiService {
  /// Generate slip gaji PDF untuk satu karyawan
  static Future<void> generateSlipGaji({
    required Map<String, dynamic> employee,
    required DateTime periodeStart,
    required DateTime periodeEnd,
    required Map<String, dynamic> attendanceData,
  }) async {
    final pdf = pw.Document();

    // Format tanggal
    final dfPeriode = DateFormat('dd MMM yyyy', 'id_ID');
    final dfCetak = DateFormat('dd MMMM yyyy, HH:mm', 'id_ID');

    // Data karyawan
    final nama = employee['name'] ?? '-';
    final nik = employee['nik'] ?? employee['code'] ?? '-';
    final posisi = employee['position'] ?? '-';
    final gajiPokok = (employee['salary'] is num) 
        ? (employee['salary'] as num).toDouble() 
        : double.tryParse('${employee['salary'] ?? 0}') ?? 0;

    // Data kehadiran
    final hariKerja = attendanceData['total_days'] ?? 0;
    final hadir = attendanceData['present_days'] ?? 0;
    final telat = attendanceData['total_late_minutes'] ?? 0;
    final lembur = attendanceData['total_overtime_minutes'] ?? 0;

    // Perhitungan
    final lemburJam = lembur / 60.0;
    final upahLemburPerJam = gajiPokok / 8; // Gaji per hari dibagi 8 jam kerja
    final totalLembur = lemburJam * upahLemburPerJam; // Upah per jam × jam lembur
    final totalGajiPokok = gajiPokok * hadir; // Gaji pokok × hari hadir

    // Ambil potongan dari tabel salary_deductions berdasarkan deduction_date
    final fromDate = DateFormat('yyyy-MM-dd').format(periodeStart);
    final toDate = DateFormat('yyyy-MM-dd').format(periodeEnd);
    
    final deductionsData = await supabase
        .from('salary_deductions')
        .select()
        .eq('employee_id', employee['id'])
        .gte('deduction_date', fromDate)
        .lte('deduction_date', toDate)
        .eq('status', 'active');
    
    final deductions = List<Map<String, dynamic>>.from(deductionsData);
    
    // Hitung total potongan
    double totalPotongan = 0;
    for (final d in deductions) {
      final amount = (d['amount'] is num) 
          ? (d['amount'] as num).toDouble() 
          : double.tryParse('${d['amount'] ?? 0}') ?? 0;
      totalPotongan += amount;
    }
    
    // Total gaji: (Gaji Pokok × Hari Hadir) + Total Lembur - Total Potongan
    final totalGaji = totalGajiPokok + totalLembur - totalPotongan;

    // Build PDF
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Header
              pw.Container(
                padding: const pw.EdgeInsets.only(bottom: 20),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    bottom: pw.BorderSide(width: 2, color: PdfColors.blue700),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'SLIP GAJI KARYAWAN',
                          style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue700,
                          ),
                        ),
                        pw.SizedBox(height: 4),
                        pw.Text(
                          'CV Tanjung Agung',
                          style: const pw.TextStyle(
                            fontSize: 12,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Periode',
                          style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          '${dfPeriode.format(periodeStart)} - ${dfPeriode.format(periodeEnd)}',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              pw.SizedBox(height: 24),

              // Data Karyawan
              pw.Text(
                'Data Karyawan',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue700,
                ),
              ),
              pw.SizedBox(height: 12),
              _buildInfoRow('Nama', nama),
              _buildInfoRow('NIK / Kode', nik),
              _buildInfoRow('Posisi', posisi),

              pw.SizedBox(height: 20),

              // Rincian Gaji
              pw.Text(
                'Rincian Gaji',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.blue700,
                ),
              ),
              pw.SizedBox(height: 12),

              // Tabel Rincian
              pw.Container(
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey400),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  children: [
                    // Gaji Pokok per hari
                    _buildTableRow('Gaji Pokok (per hari)', _formatRupiah(gajiPokok), isHeader: true),
                    pw.Divider(height: 1, color: PdfColors.grey300),

                    // Kehadiran
                    _buildTableRow('Hari Kerja', '$hariKerja hari'),
                    _buildTableRow('Hadir', '$hadir hari'),
                    _buildTableRow('Keterlambatan', '$telat menit'),
                    _buildTableRow('Lembur', '${lemburJam.toStringAsFixed(1)} jam'),
                    pw.Divider(height: 1, color: PdfColors.grey300),

                    // Total Gaji Pokok (Gaji × Hadir)
                    _buildTableRow('Total Gaji Pokok', _formatRupiah(totalGajiPokok), isPositive: true),
                    
                    // Tambahan
                    _buildTableRow('Upah Lembur', _formatRupiah(totalLembur), isPositive: true),
                    
                    // Potongan (dari tabel salary_deductions)
                    if (deductions.isNotEmpty) ...[
                      pw.Divider(height: 1, color: PdfColors.grey300),
                      for (final d in deductions)
                        _buildTableRow(
                          'Potongan ${(d['deduction_type'] ?? '').toString().toUpperCase()}',
                          _formatRupiah(d['amount']),
                          isNegative: true,
                        ),
                    ],
                    
                    pw.Divider(height: 1, color: PdfColors.grey300),

                    // Total
                    _buildTableRow(
                      'TOTAL GAJI',
                      _formatRupiah(totalGaji),
                      isHeader: true,
                      isTotal: true,
                    ),
                  ],
                ),
              ),

              pw.Spacer(),

              // Footer
              pw.Container(
                padding: const pw.EdgeInsets.only(top: 20),
                decoration: const pw.BoxDecoration(
                  border: pw.Border(
                    top: pw.BorderSide(width: 1, color: PdfColors.grey400),
                  ),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'Dicetak pada:',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.Text(
                          dfCetak.format(DateTime.now()),
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'Tanda Tangan',
                          style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey700,
                          ),
                        ),
                        pw.SizedBox(height: 40),
                        pw.Container(
                          width: 150,
                          decoration: const pw.BoxDecoration(
                            border: pw.Border(
                              top: pw.BorderSide(width: 1, color: PdfColors.grey700),
                            ),
                          ),
                          padding: const pw.EdgeInsets.only(top: 4),
                          child: pw.Text(
                            '( $nama )',
                            textAlign: pw.TextAlign.center,
                            style: const pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.grey700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );

    // Download PDF
    final bytes = await pdf.save();
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = 'slip_gaji_${nik}_${DateFormat('yyyyMM').format(periodeStart)}.pdf'
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        children: [
          pw.SizedBox(
            width: 120,
            child: pw.Text(
              label,
              style: const pw.TextStyle(
                fontSize: 11,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Text(
            ': ',
            style: const pw.TextStyle(fontSize: 11),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 11,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildTableRow(
    String label,
    String value, {
    bool isHeader = false,
    bool isTotal = false,
    bool isPositive = false,
    bool isNegative = false,
  }) {
    final bgColor = isTotal
        ? PdfColors.blue50
        : isHeader
            ? PdfColors.grey100
            : null;

    final textColor = isPositive
        ? PdfColors.green700
        : isNegative
            ? PdfColors.red700
            : PdfColors.black;

    final fontSize = isTotal ? 13.0 : isHeader ? 12.0 : 11.0;
    final fontWeight = (isHeader || isTotal) ? pw.FontWeight.bold : pw.FontWeight.normal;

    return pw.Container(
      color: bgColor,
      padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: textColor,
            ),
          ),
          pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: fontWeight,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }

  static String _formatRupiah(double value) {
    if (value == 0) return 'Rp 0';
    final formatted = value.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return 'Rp $formatted';
  }
}
