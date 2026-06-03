import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/supabase_service.dart';

// ── Model item pekerjaan ────────────────────────────────────────────
class _ItemPekerjaan {
  final String nama;
  final String satuan;
  final double hargaSatuan;

  const _ItemPekerjaan({
    required this.nama,
    required this.satuan,
    required this.hargaSatuan,
  });
}

// ── Daftar pekerjaan pre-defined ───────────────────────────────────
const _daftarPekerjaan = <_ItemPekerjaan>[
  _ItemPekerjaan(nama: 'Pasangan Habel',                satuan: 'm²',   hargaSatuan: 60000),
  _ItemPekerjaan(nama: 'Plester Aci',                   satuan: 'm²',   hargaSatuan: 75000),
  _ItemPekerjaan(nama: 'Pembesian Begisting + Cor',     satuan: 'm¹',   hargaSatuan: 70000),
  _ItemPekerjaan(nama: 'Opening',                       satuan: 'm¹',   hargaSatuan: 40000),
  _ItemPekerjaan(nama: 'Pemasangan Granit Lantai',      satuan: 'm²',   hargaSatuan: 60000),
  _ItemPekerjaan(nama: 'Pemasangan Granit Dinding',     satuan: 'm²',   hargaSatuan: 75000),
  _ItemPekerjaan(nama: 'Pengecatan',                    satuan: 'm²',   hargaSatuan: 20000),
  _ItemPekerjaan(nama: 'Pemasangan Kloset Duduk',       satuan: 'unit', hargaSatuan: 400000),
  _ItemPekerjaan(nama: 'Pemasangan Kran Single',        satuan: 'unit', hargaSatuan: 55000),
  _ItemPekerjaan(nama: 'Pemasangan Shower',             satuan: 'unit', hargaSatuan: 350000),
  _ItemPekerjaan(nama: 'Pemasangan Tabung Water Heater',satuan: 'unit', hargaSatuan: 700000),
  _ItemPekerjaan(nama: 'Pemasangan Full Drain',         satuan: 'pcs',  hargaSatuan: 55000),
  _ItemPekerjaan(nama: 'Pemasangan Washtaple',          satuan: 'unit', hargaSatuan: 350000),
  _ItemPekerjaan(nama: 'Pemasangan Bathtub',            satuan: 'unit', hargaSatuan: 1100000),
  _ItemPekerjaan(nama: 'Waterproofing',                 satuan: 'm²',   hargaSatuan: 50000),
  _ItemPekerjaan(nama: 'Bobokan Dinding/Lantai',        satuan: 'm¹',   hargaSatuan: 40000),
  _ItemPekerjaan(nama: 'Instalasi Pipa Air Bersih',     satuan: 'titik',hargaSatuan: 150000),
  _ItemPekerjaan(nama: 'Instalasi Pipa Air Kotor',      satuan: 'titik',hargaSatuan: 175000),
  _ItemPekerjaan(nama: 'Pasang Keramik Lantai',         satuan: 'm²',   hargaSatuan: 65000),
  _ItemPekerjaan(nama: 'Pasang Keramik Dinding',        satuan: 'm²',   hargaSatuan: 80000),
  _ItemPekerjaan(nama: 'Pasang Plafon Gypsum/GRC',      satuan: 'm²',   hargaSatuan: 65000),
  _ItemPekerjaan(nama: 'Rangka Plafon Hollow',          satuan: 'm²',   hargaSatuan: 50000),
  _ItemPekerjaan(nama: 'Instalasi Listrik',             satuan: 'titik',hargaSatuan: 100000),
  _ItemPekerjaan(nama: 'Cleaning Akhir',                satuan: 'm²',   hargaSatuan: 10000),
];


// ── State item yang dipilih ─────────────────────────────────────────
class _PilihanItem {
  final _ItemPekerjaan item;
  double qty;
  _PilihanItem({required this.item, required this.qty});

  double get subtotal => qty * item.hargaSatuan;
}

class BuatTagihanPage extends StatefulWidget {
  const BuatTagihanPage({super.key});

  @override
  State<BuatTagihanPage> createState() => _BuatTagihanPageState();
}

class _BuatTagihanPageState extends State<BuatTagihanPage> {
  final List<_PilihanItem> _dipilih = [];
  final _nomorCtrl   = TextEditingController();
  final _pelangganCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _catatanCtrl = TextEditingController();

  // Format angka ribuan
  String _fmt(double v) => v.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );

  double get _grandTotal =>
      _dipilih.fold(0, (s, e) => s + e.subtotal);

  // Cek apakah item sudah ada di list
  bool _sudahDipilih(_ItemPekerjaan item) =>
      _dipilih.any((p) => p.item.nama == item.nama);

  void _pilihItem(_ItemPekerjaan item) {
    if (_sudahDipilih(item)) return;
    setState(() => _dipilih.add(_PilihanItem(item: item, qty: 1)));
  }

  void _hapusItem(int index) {
    setState(() => _dipilih.removeAt(index));
  }

  void _updateQty(int index, String val) {
    final q = double.tryParse(val) ?? 0;
    setState(() => _dipilih[index].qty = q);
  }

  void _bukaDialogPilihPekerjaan() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PilihPekerjaanSheet(
        dipilih: _dipilih.map((e) => e.item.nama).toSet(),
        onPilih: (item) {
          Navigator.pop(context);
          _pilihItem(item);
        },
      ),
    );
  }

  void _simpanTagihan() async {
    if (_dipilih.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Tambahkan minimal 1 item pekerjaan.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    // Validasi nomor tagihan
    if (_nomorCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nomor tagihan harus diisi.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    // Validasi nama pelanggan
    if (_pelangganCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nama pelanggan harus diisi.'),
        behavior: SnackBarBehavior.floating,
      ));
      return;
    }

    // Konfirmasi
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: Text(
          'Tagihan dengan ${_dipilih.length} item senilai\n'
          'Rp ${_fmt(_grandTotal)}\nakan disimpan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Simpan'),
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
      // Prepare items data
      final items = _dipilih.map((p) => {
        'nama_pekerjaan': p.item.nama,
        'satuan': p.item.satuan,
        'harga_satuan': p.item.hargaSatuan,
        'qty': p.qty,
        'subtotal': p.subtotal,
      }).toList();

      // Save to database
      await saveInvoice(
        nomor: _nomorCtrl.text.trim(),
        pelanggan: _pelangganCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        catatan: _catatanCtrl.text.trim(),
        grandTotal: _grandTotal,
        items: items,
      );

      // Close loading
      if (!mounted) return;
      Navigator.pop(context);

      // Show success
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('✓ Tagihan berhasil disimpan!'),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ));

      // Back to previous page
      Navigator.pop(context, true); // return true to indicate success
    } catch (e) {
      // Close loading
      if (!mounted) return;
      Navigator.pop(context);

      // Show error
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Gagal menyimpan: ${e.toString()}'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
      ));
    }
  }

  @override
  void dispose() {
    _nomorCtrl.dispose();
    _pelangganCtrl.dispose();
    _phoneCtrl.dispose();
    _catatanCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Buat Tagihan',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        leading: const BackButton(color: Colors.black87),
        actions: [
          TextButton.icon(
            onPressed: _simpanTagihan,
            icon: const Icon(Icons.save_outlined, size: 18),
            label: const Text('Simpan'),
            style: TextButton.styleFrom(
              foregroundColor: Colors.green.shade700,
              textStyle: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // ── Info Tagihan ───────────────────────────────────
                _buildInfoCard(),
                const SizedBox(height: 16),

                // ── Header item pekerjaan ──────────────────────────
                Row(
                  children: [
                    const Text(
                      'Item Pekerjaan',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      onPressed: _bukaDialogPilihPekerjaan,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Tambah'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // ── Daftar item dipilih ────────────────────────────
                if (_dipilih.isEmpty)
                  _buildEmptyItemCard()
                else
                  ..._dipilih.asMap().entries.map((e) =>
                      _buildItemCard(e.key, e.value)),

                const SizedBox(height: 80),
              ],
            ),
          ),

          // ── Footer total ───────────────────────────────────────
          _buildFooterTotal(),
        ],
      ),
    );
  }

  // ── Info tagihan (nomor, pelanggan, catatan) ────────────────────
  Widget _buildInfoCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Informasi Tagihan',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 14),
          _inputField(_nomorCtrl,    'Nomor Tagihan', 'Contoh: INV-2024-001'),
          const SizedBox(height: 10),
          _inputField(_pelangganCtrl, 'Nama Pelanggan', 'Contoh: PT. Maju Jaya'),
          const SizedBox(height: 10),
          _inputField(_phoneCtrl, 'No. Telepon', 'Contoh: 08123456789', 
              keyboardType: TextInputType.phone),
          const SizedBox(height: 10),
          _inputField(_catatanCtrl,  'Catatan (opsional)', '', maxLines: 2),
        ],
      ),
    );
  }

  Widget _inputField(
    TextEditingController ctrl,
    String label,
    String hint, {
    int maxLines = 1,
    TextInputType? keyboardType,
  }) {
    return TextField(
      controller: ctrl,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.grey.shade50,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  // ── Card kosong ─────────────────────────────────────────────────
  Widget _buildEmptyItemCard() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          Icon(Icons.playlist_add, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 10),
          Text(
            'Belum ada item pekerjaan',
            style: TextStyle(color: Colors.grey.shade500, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            'Ketuk tombol "Tambah" untuk memilih pekerjaan',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
        ],
      ),
    );
  }

  // ── Card setiap item dipilih ────────────────────────────────────
  Widget _buildItemCard(int index, _PilihanItem p) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  p.item.nama,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, size: 18, color: Colors.red),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _hapusItem(index),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Rp ${_fmt(p.item.hargaSatuan)} / ${p.item.satuan}',
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // ── Input Qty ──────────────────────────────────────
              Expanded(
                child: TextFormField(
                  key: ValueKey('qty_$index'),
                  initialValue: p.qty == 0 ? '' : (p.qty == p.qty.truncateToDouble()
                      ? p.qty.toInt().toString()
                      : p.qty.toString()),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  onChanged: (v) {
                    if (v.isEmpty) {
                      _updateQty(index, '0');
                    } else {
                      _updateQty(index, v);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'Qty (${p.item.satuan})',
                    hintText: '0',
                    filled: true,
                    fillColor: Colors.grey.shade50,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // ── Subtotal ───────────────────────────────────────
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'Subtotal',
                    style: TextStyle(fontSize: 11, color: Colors.black45),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Rp ${_fmt(p.subtotal)}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Footer total ─────────────────────────────────────────────────
  Widget _buildFooterTotal() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: .06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Grand Total',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
              const SizedBox(height: 2),
              Text(
                'Rp ${_fmt(_grandTotal)}',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 22,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
          const Spacer(),
          FilledButton.icon(
            onPressed: _simpanTagihan,
            icon: const Icon(Icons.receipt_long, size: 18),
            label: const Text('Buat Tagihan'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              textStyle: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom Sheet Pilih Pekerjaan ────────────────────────────────────
class _PilihPekerjaanSheet extends StatefulWidget {
  final Set<String> dipilih;
  final void Function(_ItemPekerjaan) onPilih;

  const _PilihPekerjaanSheet({
    required this.dipilih,
    required this.onPilih,
  });

  @override
  State<_PilihPekerjaanSheet> createState() => _PilihPekerjaanSheetState();
}

class _PilihPekerjaanSheetState extends State<_PilihPekerjaanSheet> {
  String _query = '';

  List<_ItemPekerjaan> get _filtered => _daftarPekerjaan
      .where((p) => p.nama.toLowerCase().contains(_query.toLowerCase()))
      .toList();

  String _fmt(double v) => v.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]}.',
      );

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * .75,
      margin: EdgeInsets.only(bottom: bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Handle
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),

          // Judul
          const Text(
            'Pilih Pekerjaan',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),

          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              autofocus: false,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'Cari pekerjaan...',
                prefixIcon: const Icon(Icons.search, size: 20),
                filled: true,
                fillColor: Colors.grey.shade100,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
          const SizedBox(height: 10),

          // List
          Expanded(
            child: ListView.builder(
              itemCount: _filtered.length,
              itemBuilder: (_, i) {
                final item = _filtered[i];
                final sudahDipilih = widget.dipilih.contains(item.nama);
                return ListTile(
                  onTap: sudahDipilih ? null : () => widget.onPilih(item),
                  title: Text(
                    item.nama,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: sudahDipilih ? Colors.grey : Colors.black87,
                    ),
                  ),
                  subtitle: Text(
                    'Rp ${_fmt(item.hargaSatuan)} / ${item.satuan}',
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: sudahDipilih
                      ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                      : Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black87,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Text(
                            'Pilih',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
