import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';

class PdfService {
  /// Generate PDF untuk invoice borongan
  static Future<void> generateInvoicePdf({
    required Map<String, dynamic> invoice,
    required List<Map<String, dynamic>> items,
  }) async {
    final pdf = pw.Document();
    
    // Load signature image
    pw.ImageProvider? signatureImage;
    try {
      final signatureBytes = await rootBundle.load('assets/images/signature_budi.png');
      signatureImage = pw.MemoryImage(signatureBytes.buffer.asUint8List());
    } catch (e) {
      print('Failed to load signature image: $e');
      // Jika gagal load, signatureImage akan tetap null
    }

    // Format angka ribuan
    String formatCurrency(dynamic value) {
      final amount = (value is num) ? value.toDouble() : double.tryParse(value.toString()) ?? 0;
      return amount.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );
    }

    // Format tanggal
    String formatDate(String? dateStr) {
      if (dateStr == null) return '-';
      try {
        final dt = DateTime.parse(dateStr);
        return DateFormat('dd MMMM yyyy', 'id_ID').format(dt);
      } catch (_) {
        return dateStr;
      }
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'TAGIHAN BORONGAN',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'No: ${invoice['nomor'] ?? '-'}',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(
                    'Tanggal',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    formatDate(invoice['created_at']),
                    style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 30),

          // Info Pelanggan
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  'Kepada:',
                  style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                ),
                pw.SizedBox(height: 4),
                pw.Text(
                  invoice['pelanggan'] ?? '-',
                  style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                ),
                if (invoice['phone'] != null && invoice['phone'].toString().trim().isNotEmpty) ...[
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Telp: ${invoice['phone']}',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ],
                if (invoice['catatan'] != null && invoice['catatan'].toString().trim().isNotEmpty) ...[
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Catatan: ${invoice['catatan']}',
                    style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                  ),
                ],
              ],
            ),
          ),

          pw.SizedBox(height: 30),

          // Tabel Items
          pw.Text(
            'Rincian Pekerjaan',
            style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),

          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400),
            columnWidths: {
              0: const pw.FlexColumnWidth(1), // No
              1: const pw.FlexColumnWidth(4), // Nama Pekerjaan
              2: const pw.FlexColumnWidth(2), // Qty
              3: const pw.FlexColumnWidth(2.5), // Harga Satuan
              4: const pw.FlexColumnWidth(2.5), // Subtotal
            },
            children: [
              // Header
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                children: [
                  _buildTableCell('No', isHeader: true),
                  _buildTableCell('Nama Pekerjaan', isHeader: true),
                  _buildTableCell('Qty', isHeader: true, align: pw.TextAlign.center),
                  _buildTableCell('Harga Satuan', isHeader: true, align: pw.TextAlign.right),
                  _buildTableCell('Subtotal', isHeader: true, align: pw.TextAlign.right),
                ],
              ),
              // Items
              ...items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;
                return pw.TableRow(
                  children: [
                    _buildTableCell('${index + 1}', align: pw.TextAlign.center),
                    _buildTableCell(item['nama_pekerjaan'] ?? '-'),
                    _buildTableCell(
                      '${formatCurrency(item['qty'])} ${item['satuan'] ?? ''}',
                      align: pw.TextAlign.center,
                    ),
                    _buildTableCell(
                      'Rp ${formatCurrency(item['harga_satuan'])}',
                      align: pw.TextAlign.right,
                    ),
                    _buildTableCell(
                      'Rp ${formatCurrency(item['subtotal'])}',
                      align: pw.TextAlign.right,
                    ),
                  ],
                );
              }),
            ],
          ),

          pw.SizedBox(height: 20),

          // Grand Total
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 250,
                padding: const pw.EdgeInsets.all(16),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'GRAND TOTAL',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.Text(
                      'Rp ${formatCurrency(invoice['grand_total'])}',
                      style: pw.TextStyle(
                        fontSize: 16,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          pw.SizedBox(height: 16),

          // Info Rekening
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Container(
                width: 250,
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.blue300, width: 1.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                  color: PdfColors.blue50,
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Informasi Pembayaran',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      'No Rekening BCA',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '2310335552',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'a/n Budi Hermawan',
                      style: const pw.TextStyle(
                        fontSize: 9,
                        color: PdfColors.grey700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                    'Hormat kami,',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Owner',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 10),
                  // Gambar tanda tangan atau placeholder
                  pw.Container(
                    width: 150,
                    height: 60,
                    child: signatureImage != null
                        ? pw.Image(signatureImage, fit: pw.BoxFit.contain)
                        : pw.Center(
                            child: pw.Text(
                              '( Tanda Tangan )',
                              style: pw.TextStyle(
                                fontSize: 24,
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
                    'Budi Hermawan',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
            ],
          ),

          pw.SizedBox(height: 20),

          // Footer
          pw.Divider(color: PdfColors.grey400),
          pw.SizedBox(height: 10),
          pw.Text(
            'Terima kasih atas kepercayaan Anda.',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );

    // Download PDF
    final bytes = await pdf.save();
    final blob = html.Blob([bytes], 'application/pdf');
    final url = html.Url.createObjectUrlFromBlob(blob);
    final anchor = html.AnchorElement(href: url)
      ..download = 'Invoice_${invoice['nomor']}.pdf'
      ..click();
    html.Url.revokeObjectUrl(url);
  }

  static pw.Widget _buildTableCell(
    String text, {
    bool isHeader = false,
    pw.TextAlign align = pw.TextAlign.left,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(8),
      child: pw.Text(
        text,
        style: pw.TextStyle(
          fontSize: isHeader ? 11 : 10,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
        textAlign: align,
      ),
    );
  }
}
