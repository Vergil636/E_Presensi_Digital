// lib/pages/kelola_potongan_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';

class KelolaPotonganPage extends StatefulWidget {
  const KelolaPotonganPage({super.key});

  @override
  State<KelolaPotonganPage> createState() => _KelolaPotonganPageState();
}

class _KelolaPotonganPageState extends State<KelolaPotonganPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _deductions = [];
  List<Map<String, dynamic>> _employees = [];
  
  // Filter Periode (date range)
  DateTimeRange? _selectedRange;

  @override
  void initState() {
    super.initState();
    // Default: 1 bulan terakhir
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1); // Awal bulan ini
    _selectedRange = DateTimeRange(start: start, end: now);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // Load employees
      final emps = await fetchEmployees();
      
      // Load deductions untuk periode yang dipilih
      // Format as YYYY-MM-DD for DATE column comparison
      final fromDate = DateFormat('yyyy-MM-dd').format(_selectedRange!.start);
      final toDate = DateFormat('yyyy-MM-dd').format(_selectedRange!.end);
      
      final deductions = await supabase
          .from('salary_deductions')
          .select('*, employees(name, nik, position)')
          .gte('deduction_date', fromDate)
          .lte('deduction_date', toDate)
          .order('deduction_date', ascending: false);

      setState(() {
        _employees = emps;
        _deductions = List<Map<String, dynamic>>.from(deductions);
      });
    } catch (e) {
      _showSnack('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: _selectedRange,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.blue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedRange) {
      setState(() => _selectedRange = picked);
      _loadData();
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  String _formatRupiah(dynamic value) {
    final amount = (value is num) ? value.toDouble() : double.tryParse('$value') ?? 0;
    if (amount == 0) return 'Rp 0';
    return 'Rp ${amount.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        leading: const BackButton(color: Colors.black87),
        title: const Text(
          'Kelola Potongan Gaji',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.black54),
            onPressed: _loadData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddDialog,
        icon: const Icon(Icons.add),
        label: const Text('Tambah Potongan'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          // Filter Periode (Date Range Picker)
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                const Text(
                  'Periode:',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _pickDateRange,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.calendar_today, size: 20, color: Colors.blue),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _selectedRange == null
                                  ? 'Pilih Periode'
                                  : '${DateFormat('dd MMM yyyy', 'id_ID').format(_selectedRange!.start)} - ${DateFormat('dd MMM yyyy', 'id_ID').format(_selectedRange!.end)}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, color: Colors.grey),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // List Potongan
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _deductions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.inbox, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'Belum ada potongan untuk periode ini',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _deductions.length,
                        itemBuilder: (context, index) {
                          final d = _deductions[index];
                          final emp = d['employees'] ?? {};
                          return _buildDeductionCard(d, emp);
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDeductionCard(Map<String, dynamic> deduction, Map<String, dynamic> employee) {
    final type = deduction['deduction_type'] ?? '-';
    final amount = deduction['amount'] ?? 0;
    final desc = deduction['description'] ?? '';
    final status = deduction['status'] ?? 'active';
    final name = employee['name'] ?? '-';
    final nik = employee['nik'] ?? '-';

    Color typeColor;
    IconData typeIcon;
    switch (type) {
      case 'kasbon':
        typeColor = Colors.orange;
        typeIcon = Icons.money_off;
        break;
      case 'bpjs':
        typeColor = Colors.blue;
        typeIcon = Icons.health_and_safety;
        break;
      case 'pinjaman':
        typeColor = Colors.red;
        typeIcon = Icons.account_balance_wallet;
        break;
      case 'denda':
        typeColor = Colors.purple;
        typeIcon = Icons.warning;
        break;
      default:
        typeColor = Colors.grey;
        typeIcon = Icons.remove_circle;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: typeColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(typeIcon, color: typeColor),
        ),
        title: Text(
          name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NIK: $nik • ${type.toUpperCase()}'),
            if (desc.isNotEmpty) Text(desc, style: const TextStyle(fontSize: 12)),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              _formatRupiah(amount),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: typeColor,
              ),
            ),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: status == 'active' ? Colors.green.shade50 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                status == 'active' ? 'Aktif' : status == 'paid' ? 'Lunas' : 'Batal',
                style: TextStyle(
                  fontSize: 10,
                  color: status == 'active' ? Colors.green.shade700 : Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        onTap: () => _showEditDialog(deduction),
      ),
    );
  }

  void _showAddDialog() {
    showDialog(
      context: context,
      builder: (_) => _DeductionDialog(
        employees: _employees,
        dateRange: _selectedRange!,
        onSave: _loadData,
      ),
    );
  }

  void _showEditDialog(Map<String, dynamic> deduction) {
    showDialog(
      context: context,
      builder: (_) => _DeductionDialog(
        employees: _employees,
        dateRange: _selectedRange!,
        deduction: deduction,
        onSave: _loadData,
      ),
    );
  }
}

// Dialog untuk tambah/edit potongan
class _DeductionDialog extends StatefulWidget {
  final List<Map<String, dynamic>> employees;
  final DateTimeRange dateRange;
  final Map<String, dynamic>? deduction;
  final VoidCallback onSave;

  const _DeductionDialog({
    required this.employees,
    required this.dateRange,
    this.deduction,
    required this.onSave,
  });

  @override
  State<_DeductionDialog> createState() => _DeductionDialogState();
}

class _DeductionDialogState extends State<_DeductionDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedEmployeeId;
  String _selectedType = 'kasbon';
  final _amountCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  DateTime? _selectedDate;
  String _selectedStatus = 'active';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    if (widget.deduction != null) {
      _selectedEmployeeId = widget.deduction!['employee_id'];
      _selectedType = widget.deduction!['deduction_type'] ?? 'kasbon';
      _amountCtrl.text = '${widget.deduction!['amount'] ?? 0}';
      _descCtrl.text = widget.deduction!['description'] ?? '';
      _selectedStatus = widget.deduction!['status'] ?? 'active';
      // Parse deduction_date
      final dateStr = widget.deduction!['deduction_date'];
      if (dateStr != null) {
        _selectedDate = DateTime.parse(dateStr);
      }
    } else {
      // Default: hari ini
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmployeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih karyawan')),
      );
      return;
    }
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pilih tanggal potongan')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      // Format date as YYYY-MM-DD (DATE type in SQL, no time component)
      final dateOnly = DateFormat('yyyy-MM-dd').format(_selectedDate!);
      
      final data = {
        'employee_id': _selectedEmployeeId,
        'deduction_type': _selectedType,
        'amount': double.parse(_amountCtrl.text),
        'description': _descCtrl.text.trim(),
        'deduction_date': dateOnly,
        'period_month': _selectedDate!.month, // Isi dari deduction_date
        'period_year': _selectedDate!.year,   // Isi dari deduction_date
        'status': _selectedStatus,
      };

      if (widget.deduction == null) {
        // Insert
        await supabase.from('salary_deductions').insert(data);
      } else {
        // Update
        await supabase
            .from('salary_deductions')
            .update(data)
            .eq('id', widget.deduction!['id']);
      }

      if (mounted) {
        Navigator.pop(context);
        widget.onSave();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Potongan berhasil disimpan')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );

    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Potongan'),
        content: const Text('Yakin ingin menghapus potongan ini?'),
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

    try {
      await supabase
          .from('salary_deductions')
          .delete()
          .eq('id', widget.deduction!['id']);

      if (mounted) {
        Navigator.pop(context);
        widget.onSave();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Potongan berhasil dihapus')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.deduction != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit Potongan' : 'Tambah Potongan'),
      content: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Karyawan
              DropdownButtonFormField<String>(
                value: _selectedEmployeeId,
                decoration: const InputDecoration(
                  labelText: 'Karyawan',
                  border: OutlineInputBorder(),
                ),
                items: widget.employees.map<DropdownMenuItem<String>>((e) {
                  return DropdownMenuItem<String>(
                    value: e['id'],
                    child: Text('${e['name']} (${e['nik'] ?? e['code']})'),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedEmployeeId = val),
              ),
              const SizedBox(height: 16),

              // Jenis Potongan
              DropdownButtonFormField<String>(
                value: _selectedType,
                decoration: const InputDecoration(
                  labelText: 'Jenis Potongan',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'kasbon', child: Text('Kasbon')),
                  DropdownMenuItem(value: 'bpjs', child: Text('BPJS')),
                  DropdownMenuItem(value: 'pinjaman', child: Text('Pinjaman')),
                  DropdownMenuItem(value: 'denda', child: Text('Denda')),
                  DropdownMenuItem(value: 'lainnya', child: Text('Lainnya')),
                ],
                onChanged: (val) => setState(() => _selectedType = val!),
              ),
              const SizedBox(height: 16),

              // Tanggal Potongan
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Tanggal Potongan',
                    border: OutlineInputBorder(),
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  child: Text(
                    _selectedDate == null
                        ? 'Pilih tanggal'
                        : DateFormat('dd MMMM yyyy', 'id_ID').format(_selectedDate!),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Jumlah
              TextFormField(
                controller: _amountCtrl,
                decoration: const InputDecoration(
                  labelText: 'Jumlah (Rp)',
                  border: OutlineInputBorder(),
                  prefixText: 'Rp ',
                ),
                keyboardType: TextInputType.number,
                validator: (val) {
                  if (val == null || val.isEmpty) return 'Wajib diisi';
                  if (double.tryParse(val) == null) return 'Harus angka';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Keterangan
              TextFormField(
                controller: _descCtrl,
                decoration: const InputDecoration(
                  labelText: 'Keterangan (opsional)',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 16),

              // Status (hanya untuk edit)
              if (isEdit)
                DropdownButtonFormField<String>(
                  value: _selectedStatus,
                  decoration: const InputDecoration(
                    labelText: 'Status',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('Aktif')),
                    DropdownMenuItem(value: 'paid', child: Text('Lunas')),
                    DropdownMenuItem(value: 'cancelled', child: Text('Dibatalkan')),
                  ],
                  onChanged: (val) => setState(() => _selectedStatus = val!),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (isEdit)
          TextButton(
            onPressed: _delete,
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Hapus'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEdit ? 'Update' : 'Simpan'),
        ),
      ],
    );
  }
}
