import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';
import '../services/pdf_service.dart';

class RiwayatTagihanPage extends StatefulWidget {
  const RiwayatTagihanPage({super.key});

  @override
  State<RiwayatTagihanPage> createState() => _RiwayatTagihanPageState();
}

class _RiwayatTagihanPageState extends State<RiwayatTagihanPage> {
  List<Map<String, dynamic>> _invoices = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _loading = true);
    try {
      final data = await fetchInvoices();
      setState(() {
        _invoices = data;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Gagal memuat data: ${e.toString()}'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  String _fmt(dynamic v) {
    final value = (v is num) ? v.toDouble() : double.tryParse(v.toString()) ?? 0;
    return value.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final dt = DateTime.parse(dateStr);
      return DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dt);
    } catch (_) {
      return dateStr;
    }
  }

  Future<void> _showDetailDialog(Map<String, dynamic> invoice) async {
    // Load items
    final items = await fetchInvoiceItems(invoice['id']);

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
          child: Column(
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue.shade700,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.receipt_long, color: Colors.white, size: 28),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invoice['nomor'] ?? '-',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _formatDate(invoice['created_at']),
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Tombol Print PDF
                    IconButton(
                      icon: const Icon(Icons.print, color: Colors.white),
                      onPressed: () async {
                        Navigator.pop(context); // Close dialog
                        await _printPdf(invoice, items);
                      },
                      tooltip: 'Cetak PDF',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // Content
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Info pelanggan
                    _buildInfoRow('Pelanggan', invoice['pelanggan'] ?? '-'),
                    if (invoice['phone'] != null && 
                        invoice['phone'].toString().trim().isNotEmpty)
                      _buildInfoRow('No. Telepon', invoice['phone']),
                    if (invoice['catatan'] != null && 
                        invoice['catatan'].toString().trim().isNotEmpty)
                      _buildInfoRow('Catatan', invoice['catatan']),
                    const Divider(height: 24),

                    // Items
                    const Text(
                      'Item Pekerjaan',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...items.map((item) => _buildItemCard(item)),

                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 8),

                    // Grand Total
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Grand Total',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                        Text(
                          'Rp ${_fmt(invoice['grand_total'])}',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 20,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _printPdf(Map<String, dynamic> invoice, List<Map<String, dynamic>> items) async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      await PdfService.generateInvoicePdf(
        invoice: invoice,
        items: items,
      );

      // Close loading
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      // Close loading
      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Gagal membuat PDF: ${e.toString()}'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black54,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Text(': ', style: TextStyle(color: Colors.black54)),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.black87,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(Map<String, dynamic> item) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item['nama_pekerjaan'] ?? '-',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 13,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '${_fmt(item['qty'])} ${item['satuan']}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const Text(' × ', style: TextStyle(fontSize: 12, color: Colors.black54)),
              Text(
                'Rp ${_fmt(item['harga_satuan'])}',
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const Spacer(),
              Text(
                'Rp ${_fmt(item['subtotal'])}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> invoice) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Tagihan'),
        content: Text(
          'Yakin ingin menghapus tagihan "${invoice['nomor']}"?\n'
          'Tindakan ini tidak dapat dibatalkan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      await deleteInvoice(invoice['id']);
      
      // Close loading
      if (!mounted) return;
      Navigator.pop(context);

      // Reload data
      _loadInvoices();

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✓ Tagihan berhasil dihapus'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      // Close loading
      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Gagal menghapus: ${e.toString()}'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _showPaymentStatusDialog(Map<String, dynamic> invoice) async {
    final currentStatus = invoice['payment_status'] ?? 'unpaid';
    final grandTotal = (invoice['grand_total'] is num) 
        ? (invoice['grand_total'] as num).toDouble() 
        : double.tryParse('${invoice['grand_total'] ?? 0}') ?? 0;
    final currentPaidAmount = (invoice['paid_amount'] is num) 
        ? (invoice['paid_amount'] as num).toDouble() 
        : double.tryParse('${invoice['paid_amount'] ?? 0}') ?? 0;
    
    String selectedStatus = currentStatus;
    final paidAmountCtrl = TextEditingController(
      text: currentPaidAmount > 0 ? currentPaidAmount.toStringAsFixed(0) : '',
    );

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Update Status Pembayaran'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invoice: ${invoice['nomor']}',
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 4),
              Text(
                'Total: Rp ${_fmt(grandTotal)}',
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
              const SizedBox(height: 16),
              const Text(
                'Status Pembayaran',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
                items: const [
                  DropdownMenuItem(value: 'unpaid', child: Text('Belum Dibayar')),
                  DropdownMenuItem(value: 'partial', child: Text('Dibayar Sebagian')),
                  DropdownMenuItem(value: 'paid', child: Text('Lunas')),
                ],
                onChanged: (val) {
                  setDialogState(() {
                    selectedStatus = val!;
                    if (val == 'paid') {
                      paidAmountCtrl.text = grandTotal.toStringAsFixed(0);
                    } else if (val == 'unpaid') {
                      paidAmountCtrl.text = '0';
                    }
                  });
                },
              ),
              if (selectedStatus == 'partial') ...[
                const SizedBox(height: 16),
                const Text(
                  'Jumlah Dibayar',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: paidAmountCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    prefixText: 'Rp ',
                    hintText: 'Masukkan jumlah',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () {
                double paidAmount = 0;
                if (selectedStatus == 'paid') {
                  paidAmount = grandTotal;
                } else if (selectedStatus == 'partial') {
                  paidAmount = double.tryParse(paidAmountCtrl.text) ?? 0;
                }
                
                Navigator.pop(context, {
                  'status': selectedStatus,
                  'paid_amount': paidAmount,
                });
              },
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );

    if (result == null) return;

    // Show loading
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final updateData = {
        'payment_status': result['status'],
        'paid_amount': result['paid_amount'],
      };
      
      if (result['status'] == 'paid') {
        updateData['payment_date'] = DateTime.now().toIso8601String();
      } else {
        updateData['payment_date'] = null;
      }

      await supabase
          .from('invoices')
          .update(updateData)
          .eq('id', invoice['id']);
      
      // Close loading
      if (!mounted) return;
      Navigator.pop(context);

      // Reload data
      _loadInvoices();

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✓ Status pembayaran berhasil diupdate'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));
    } catch (e) {
      // Close loading
      if (!mounted) return;
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Gagal update status: ${e.toString()}'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Riwayat Tagihan',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        leading: const BackButton(color: Colors.black87),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black87),
            onPressed: _loadInvoices,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _invoices.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  onRefresh: _loadInvoices,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _invoices.length,
                    itemBuilder: (_, i) => _buildInvoiceCard(_invoices[i]),
                  ),
                ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Belum ada tagihan',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade500,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tagihan yang dibuat akan muncul di sini',
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceCard(Map<String, dynamic> invoice) {
    final paymentStatus = invoice['payment_status'] ?? 'unpaid';
    final paidAmount = (invoice['paid_amount'] is num) 
        ? (invoice['paid_amount'] as num).toDouble() 
        : double.tryParse('${invoice['paid_amount'] ?? 0}') ?? 0;
    final grandTotal = (invoice['grand_total'] is num) 
        ? (invoice['grand_total'] as num).toDouble() 
        : double.tryParse('${invoice['grand_total'] ?? 0}') ?? 0;
    
    // Warna dan label status
    Color statusColor;
    String statusLabel;
    IconData statusIcon;
    
    switch (paymentStatus) {
      case 'paid':
        statusColor = Colors.green;
        statusLabel = 'Lunas';
        statusIcon = Icons.check_circle;
        break;
      case 'partial':
        statusColor = Colors.orange;
        statusLabel = 'Dibayar Sebagian';
        statusIcon = Icons.hourglass_bottom;
        break;
      default:
        statusColor = Colors.red;
        statusLabel = 'Belum Dibayar';
        statusIcon = Icons.cancel;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: InkWell(
        onTap: () => _showDetailDialog(invoice),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.receipt_long,
                      color: Colors.blue.shade700,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoice['nomor'] ?? '-',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          invoice['pelanggan'] ?? '-',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Status Badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withOpacity(0.3)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Rp ${_fmt(grandTotal)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 18,
                          color: Colors.green.shade700,
                        ),
                      ),
                      if (paymentStatus == 'partial') ...[
                        const SizedBox(height: 4),
                        Text(
                          'Dibayar: Rp ${_fmt(paidAmount)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange.shade700,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        'Dibuat',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(invoice['created_at']),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Action buttons
              Row(
                children: [
                  // Tombol Update Status
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showPaymentStatusDialog(invoice),
                      icon: const Icon(Icons.payment, size: 16),
                      label: const Text('Status Bayar', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Tombol Export PDF
                  OutlinedButton.icon(
                    onPressed: () async {
                      final items = await fetchInvoiceItems(invoice['id']);
                      if (!mounted) return;
                      _printPdf(invoice, items);
                    },
                    icon: const Icon(Icons.picture_as_pdf, size: 16),
                    label: const Text('Export PDF', style: TextStyle(fontSize: 12)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Tombol Delete
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                    onPressed: () => _confirmDelete(invoice),
                    tooltip: 'Hapus',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
