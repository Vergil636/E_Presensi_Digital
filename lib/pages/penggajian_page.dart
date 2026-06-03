import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/supabase_service.dart';
import '../widgets/dashboard_back_button.dart';
import 'rekap_gaji_page.dart';
import 'edit_gaji_page.dart';
import 'kelola_potongan_page.dart';

class PenggajianPage extends StatefulWidget {
  const PenggajianPage({super.key});

  @override
  State<PenggajianPage> createState() => _PenggajianPageState();
}

class _PenggajianPageState extends State<PenggajianPage> {
  bool _loading = true;
  int _totalPegawai = 0;
  double _rataRataSalary = 0;
  double _totalSalaryTerbaru = 0;

  // Data pegawai + gaji untuk tabel
  List<Map<String, dynamic>> _employees = [];
  
  // Data untuk 3 pie charts
  double _totalGajiFullWeek = 0;  // Total gaji jika semua pegawai full 1 minggu
  double _totalOvertimeHours = 0;  // Total jam lembur minggu ini
  int _employeesPresent = 0;       // Jumlah pegawai yang masuk minggu ini

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final emps = await fetchEmployees();
      // Ambil field salary jika ada, fallback ke 0
      double total = 0;
      double totalFullWeek = 0;
      for (final e in emps) {
        final s = double.tryParse('${e['salary'] ?? 0}') ?? 0;
        total += s;
        // Asumsi: salary adalah gaji per hari, full week = 7 hari
        totalFullWeek += s * 7;
      }
      final rata = emps.isEmpty ? 0.0 : total / emps.length;

      // Ambil data attendance minggu ini untuk hitung lembur dan kehadiran
      final now = DateTime.now();
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      final endOfWeek = startOfWeek.add(const Duration(days: 6));
      
      final attendanceData = await listAttendanceDaily(
        from: startOfWeek,
        to: endOfWeek,
      );
      
      // Hitung total jam lembur dan upah lembur
      double totalOvertimeMinutes = 0;
      Set<String> employeesWithAttendance = {};
      
      // Map employee_id ke salary untuk hitung upah lembur
      final empSalaryMap = <String, double>{};
      for (final e in emps) {
        empSalaryMap[e['id'].toString()] = double.tryParse('${e['salary'] ?? 0}') ?? 0;
      }
      
      for (final att in attendanceData) {
        // total_overtime_minutes dari hasil query listAttendanceDaily
        final overtimeMinutes = double.tryParse('${att['total_overtime_minutes'] ?? 0}') ?? 0;
        totalOvertimeMinutes += overtimeMinutes;
        
        // Track pegawai yang hadir (yang punya first_in_at)
        final empId = att['employee_id']?.toString();
        final firstIn = att['first_in_at']?.toString() ?? '';
        if (empId != null && firstIn.isNotEmpty) {
          employeesWithAttendance.add(empId);
        }
      }
      
      // Convert total menit lembur ke jam
      final totalOvertimeHours = totalOvertimeMinutes / 60;

      setState(() {
        _employees = emps;
        _totalPegawai = emps.length;
        _rataRataSalary = rata;
        _totalSalaryTerbaru = total;
        _totalGajiFullWeek = totalFullWeek;
        _totalOvertimeHours = totalOvertimeHours;
        _employeesPresent = employeesWithAttendance.length;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Format angka menjadi ribuan (misal: 1.500.000) ──────────────
  String _fmt(double v) {
    if (v == 0) return '0';
    return v
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Penggajian',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 20,
            color: Colors.black87,
            letterSpacing: 0.3,
          ),
        ),
        leading: const BackButton(color: Colors.black87),
        actions: [
          const DashboardBackButton(color: Colors.black54),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: Colors.black54),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(strokeWidth: 3))
          : RefreshIndicator(
              onRefresh: _loadData,
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  // ── Ringkasan dengan Grafik ───────────────────
                  _buildRingkasanGrafik(),

                  const SizedBox(height: 24),

                  // ── Menu Aksi ─────────────────────────────────
                  _buildMenuSection(),

                  const SizedBox(height: 80),
                ],
              ),
            ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  RINGKASAN DENGAN 3 PIE CHARTS - MODERN DESIGN
  // ─────────────────────────────────────────────────────────────────
  Widget _buildRingkasanGrafik() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF4CAF50), Color(0xFF2E7D32)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withOpacity(0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.pie_chart_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              const Expanded(
                child: Text(
                  'Ringkasan Gaji Minggu Ini',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 20,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // 3 Pie Charts
          Row(
            children: [
              // Chart 1: Total Gaji Full Week
              Expanded(
                child: _buildPieChartCard(
                  title: 'Gaji Full Week',
                  subtitle: '7 hari kerja',
                  value: _totalGajiFullWeek,
                  total: _totalGajiFullWeek,
                  icon: Icons.calendar_month_rounded,
                  showRupiah: true,
                ),
              ),
              const SizedBox(width: 12),
              
              // Chart 2: Total Lembur
              Expanded(
                child: _buildPieChartCard(
                  title: 'Total Lembur',
                  subtitle: 'Jam lembur',
                  value: _totalOvertimeHours,
                  total: _totalOvertimeHours > 0 ? _totalOvertimeHours : 1,
                  icon: Icons.access_time_rounded,
                  showRupiah: false,
                  suffix: ' jam',
                ),
              ),
              const SizedBox(width: 12),
              
              // Chart 3: Pegawai Masuk
              Expanded(
                child: _buildPieChartCard(
                  title: 'Pegawai Masuk',
                  subtitle: 'Dari total pegawai',
                  value: _employeesPresent.toDouble(),
                  total: _totalPegawai.toDouble(),
                  icon: Icons.people_rounded,
                  showRupiah: false,
                  suffix: ' orang',
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Total Salary Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Gaji Keseluruhan',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Semua pegawai (per hari)',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.black38,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Rp ${_fmt(_totalSalaryTerbaru)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF4CAF50),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChartCard({
    required String title,
    required String subtitle,
    required double value,
    required double total,
    required IconData icon,
    required bool showRupiah,
    String suffix = '',
  }) {
    final percentage = total > 0 ? (value / total * 100) : 0;
    final remaining = total - value;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          // Icon
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(height: 8),
          
          // Title
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
          
          const SizedBox(height: 16),
          
          // Pie Chart
          SizedBox(
            height: 100,
            width: 100,
            child: PieChart(
              PieChartData(
                sectionsSpace: 2,
                centerSpaceRadius: 30,
                sections: [
                  PieChartSectionData(
                    color: Colors.white.withOpacity(0.9),
                    value: value > 0 ? value : 0.1,
                    title: '',
                    radius: 20,
                  ),
                  PieChartSectionData(
                    color: Colors.white.withOpacity(0.2),
                    value: remaining > 0 ? remaining : 0.1,
                    title: '',
                    radius: 20,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Percentage
          Text(
            '${percentage.toStringAsFixed(0)}%',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: Colors.white,
            ),
          ),
          
          const SizedBox(height: 4),
          
          // Value
          Text(
            showRupiah 
                ? 'Rp ${_fmt(value)}'
                : '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}$suffix',
            style: TextStyle(
              fontSize: 11,
              color: Colors.white.withOpacity(0.9),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  MENU SECTION - PRESENSI STYLE (LIST TILES)
  // ─────────────────────────────────────────────────────────────────
  Widget _buildMenuSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            'Menu Penggajian',
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 16,
              color: Colors.black87,
              letterSpacing: 0.3,
            ),
          ),
        ),
        
        // Menu List
        _buildMenuTile(
          icon: Icons.summarize_rounded,
          iconColor: const Color(0xFF2196F3),
          title: 'Rekap Gaji',
          subtitle: 'Lihat rekap gaji pegawai',
          onTap: _showRekapGaji,
        ),
        
        const SizedBox(height: 10),
        
        _buildMenuTile(
          icon: Icons.edit_note_rounded,
          iconColor: const Color(0xFFFF9800),
          title: 'Edit Gaji',
          subtitle: 'Ubah gaji pegawai',
          onTap: _showEditGaji,
        ),
        
        const SizedBox(height: 10),
        
        _buildMenuTile(
          icon: Icons.money_off_rounded,
          iconColor: const Color(0xFFEF5350),
          title: 'Kelola Potongan',
          subtitle: 'Kasbon, BPJS, pinjaman',
          onTap: _showKelolaPotongan,
        ),
      ],
    );
  }

  Widget _buildMenuTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.grey.shade50,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.black38),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  AKSI HANDLERS
  // ─────────────────────────────────────────────────────────────────
  void _showRekapGaji() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const RekapGajiPage()),
    );
  }

  void _showEditGaji() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const EditGajiPage()),
    ).then((_) => _loadData()); // reload KPI setelah kembali
  }

  void _showKelolaPotongan() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const KelolaPotonganPage()),
    );
  }

  void _showEditGajiDialog(Map<String, dynamic> emp) {
    final ctrl = TextEditingController(
      text: (double.tryParse('${emp['salary'] ?? 0}') ?? 0) == 0
          ? ''
          : '${emp['salary']}',
    );

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Edit Gaji — ${emp['name']}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              (emp['position'] ?? '-').toString(),
              style: const TextStyle(color: Colors.black54, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Gaji (Rp)',
                hintText: 'Contoh: 3500000',
                prefixText: 'Rp ',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              final val = double.tryParse(ctrl.text.trim());
              if (val == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Masukkan angka yang valid.'),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
                return;
              }
              Navigator.pop(context);
              await _saveSalary(emp['id'].toString(), val);
            },
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveSalary(String employeeId, double salary) async {
    try {
      await supabase
          .from('employees')
          .update({'salary': salary})
          .eq('id', employeeId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Gaji berhasil disimpan.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      await _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _cetakRekap() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cetak Rekap Gaji'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Rekap gaji semua pegawai:'),
            const SizedBox(height: 12),
            ..._employees.map((e) {
              final salary =
                  double.tryParse('${e['salary'] ?? 0}') ?? 0;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                        child: Text((e['name'] ?? '-').toString())),
                    Text(
                      salary == 0
                          ? 'Belum diatur'
                          : 'Rp ${_fmt(salary)}',
                      style:
                          const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              );
            }),
            const Divider(),
            Row(
              children: [
                const Expanded(
                    child: Text(
                  'Total',
                  style: TextStyle(fontWeight: FontWeight.w800),
                )),
                Text(
                  'Rp ${_fmt(_totalSalaryTerbaru)}',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Tutup'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                      'Fitur cetak PDF akan segera tersedia.'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            icon: const Icon(Icons.print),
            label: const Text('Cetak PDF'),
          ),
        ],
      ),
    );
  }
}
