// lib/pages/dashboard_page.dart
import 'dart:async';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

import '../services/supabase_service.dart';
import 'unified_login_page.dart';
import 'register_page.dart';
import 'employees_page.dart';
import 'scan_page.dart' show ScanMenuPage;
import 'rekap_page.dart' show RekapPage;
import 'penggajian_page.dart';
import 'invoice_borongan_page.dart';
import 'mandor_management_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  Map<String, dynamic>? _rule;
  bool _loadingRule = true;

  // === Real-time clock ===
  late Timer _clockTimer;
  late String _todayText;
  late String _timeText;

  // === Data KPI ===
  bool _loadingKpi = true;
  int _totalEmployees = 0;
  int _presentToday = 0;
  int _lateToday = 0;
  int _overtimeToday = 0;
  double _totalInvoicesThisMonth = 0; // Tambahan untuk tagihan bulan ini
  List<Map<String, dynamic>> _rowsToday = [];

  // === Active Tab ===
  // 0 = Presensi, 1 = Penggajian, 2 = Invoice, 3 = Kelola Mandor
  int _activeTab = -1; // -1 = none selected

  @override
  void initState() {
    super.initState();
    _initClock();
    _refreshAll();
  }

  void _initClock() {
    final now = DateTime.now();
    _todayText = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(now);
    _timeText = DateFormat('HH:mm:ss').format(now);
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final now = DateTime.now();
      setState(() {
        _timeText = DateFormat('HH:mm:ss').format(now);
      });
    });
  }

  @override
  void dispose() {
    _clockTimer.cancel();
    super.dispose();
  }

  Future<void> _refreshAll() async {
    await Future.wait([_loadRule(), _loadKpisToday(), _loadInvoicesThisMonth()]);
  }

  Future<void> _loadRule() async {
    setState(() => _loadingRule = true);
    try {
      final rule = await fetchActiveWorkRules();
      setState(() => _rule = rule);
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _loadingRule = false);
    }
  }

  Future<void> _loadKpisToday() async {
    setState(() => _loadingKpi = true);
    try {
      final emps = await supabase.from('employees').select('id');
      final totalEmp = (emps as List).length;

      final now = DateTime.now();
      final from = DateTime(now.year, now.month, now.day);
      final to = from;

      final rows = await listAttendanceDaily(from: from, to: to);

      int present = 0;
      int totalLate = 0;
      int totalOT = 0;

      for (final r in rows) {
        if ((r['first_in_at'] ?? '') != '') present += 1;
        final late = int.tryParse('${r['total_minutes_late'] ?? 0}') ?? 0;
        final ot = int.tryParse('${r['total_overtime_minutes'] ?? 0}') ?? 0;
        totalLate += late;
        totalOT += ot;
      }

      setState(() {
        _totalEmployees = totalEmp;
        _presentToday = present;
        _lateToday = totalLate;
        _overtimeToday = totalOT;
        _rowsToday = rows;
      });
    } catch (e) {
      _showSnack(e.toString());
    } finally {
      if (mounted) setState(() => _loadingKpi = false);
    }
  }

  Future<void> _loadInvoicesThisMonth() async {
    try {
      final now = DateTime.now();
      final startOfMonth = DateTime(now.year, now.month, 1);
      final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final response = await supabase
          .from('invoices')
          .select('grand_total')
          .gte('created_at', startOfMonth.toIso8601String())
          .lte('created_at', endOfMonth.toIso8601String());

      double total = 0;
      for (final invoice in response as List) {
        final grandTotal = invoice['grand_total'];
        if (grandTotal != null) {
          total += (grandTotal is num) 
              ? grandTotal.toDouble() 
              : double.tryParse('$grandTotal') ?? 0;
        }
      }

      setState(() {
        _totalInvoicesThisMonth = total;
      });
    } catch (e) {
      _showSnack('Error loading invoices: $e');
    }
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  /// Format waktu dari ISO string ke HH:mm
  String _formatTime(dynamic timeValue) {
    if (timeValue == null || timeValue.toString().isEmpty || timeValue == '-') {
      return '-';
    }

    try {
      final timeStr = timeValue.toString();
      
      // Parse ISO datetime string
      final dt = DateTime.parse(timeStr);
      
      // Format ke HH:mm (24 jam)
      return DateFormat('HH:mm').format(dt);
    } catch (e) {
      // Jika gagal parse, return original value
      return timeValue.toString();
    }
  }

  /// Format rupiah
  String _formatRupiah(double value) {
    if (value == 0) return 'Rp 0';
    final formatted = value.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]}.',
    );
    return 'Rp $formatted';
  }

  Future<void> _logout() async {
    await adminLogout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const UnifiedLoginPage()),
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        title: const Text(
          'Dashboard Admin',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Colors.black87,
          ),
        ),
        automaticallyImplyLeading: false,
        actions: [
          TextButton(
            onPressed: _logout,
            child: const Text(
              'Logout',
              style: TextStyle(color: Colors.black54),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refreshAll,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Header (sapaan + tanggal) ──────────────────────────
            _buildHeader(),

            const SizedBox(height: 16),

            // ── Tombol Navigasi (Presensi / Penggajian / Invoice) ──
            _buildNavButtons(),

            const SizedBox(height: 16),

            // ── Konten tab Presensi ────────────────────────────────
            if (_activeTab == 0) ...[
              _buildPresensiSection(),
              const SizedBox(height: 16),
            ],

            // ── Ringkasan Hari Ini (hanya tampil jika tidak ada tab aktif) ─
            if (_activeTab == -1) ...[
              _buildRingkasanCard(),
              const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  HEADER - MODERN GRADIENT DESIGN
  // ─────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2196F3), Color(0xFF9C27B0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Avatar Icon
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          // Text Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Selamat datang, admin',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _todayText,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.9),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Clock & Refresh
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_rounded, size: 18, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      _timeText,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Material(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  onTap: _refreshAll,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    child: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  TOMBOL NAVIGASI - MODERN PILL DESIGN
  // ─────────────────────────────────────────────────────────────────
  Widget _buildNavButtons() {
    final tabs = [
      {'label': 'Presensi', 'icon': Icons.qr_code_scanner_rounded, 'color': Color(0xFF2196F3)},
      {'label': 'Penggajian', 'icon': Icons.payments_rounded, 'color': Color(0xFF4CAF50)},
      {'label': 'Invoice', 'icon': Icons.receipt_long_rounded, 'color': Color(0xFFFF9800)},
      {'label': 'Kelola Mandor', 'icon': Icons.supervisor_account_rounded, 'color': Color(0xFF9C27B0)},
    ];
    
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: List.generate(tabs.length, (i) {
        final selected = _activeTab == i;
        final tab = tabs[i];
        final color = tab['color'] as Color;
        
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          child: Material(
            color: selected ? color : Colors.white,
            borderRadius: BorderRadius.circular(16),
            elevation: selected ? 4 : 0,
            shadowColor: color.withOpacity(0.4),
            child: InkWell(
              onTap: () {
                if (i == 1) {
                  // Penggajian → halaman terpisah
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const PenggajianPage()),
                  );
                  return;
                }
                if (i == 2) {
                  // Invoice → halaman terpisah
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const InvoiceBoronganPage()),
                  );
                  return;
                }
                if (i == 3) {
                  // Kelola Mandor → halaman terpisah
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const MandorManagementPage()),
                  );
                  return;
                }
                setState(() {
                  _activeTab = selected ? -1 : i;
                });
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected ? Colors.transparent : Colors.grey.shade300,
                    width: 1.5,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      tab['icon'] as IconData,
                      color: selected ? Colors.white : color,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      tab['label'] as String,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: selected ? Colors.white : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  SECTION PRESENSI (aksi dari dashboard lama)
  // ─────────────────────────────────────────────────────────────────
  Widget _buildPresensiSection() {
    final scheme = Theme.of(context).colorScheme;

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
          // Header dengan tombol tutup
          Row(
            children: [
              const Text(
                'Aksi Presensi',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: Colors.black87,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                tooltip: 'Tutup',
                onPressed: () => setState(() => _activeTab = -1),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Scan QR – tall card
          _PresensiActionTile(
            icon: Icons.qr_code_scanner,
            iconColor: Colors.deepPurple,
            title: 'Mulai Presensi',
            subtitle: 'Pilih mode absen: Normal atau Pulang Darurat',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ScanMenuPage()),
            ),
          ),

          const SizedBox(height: 10),

          // Registrasi Pegawai
          _PresensiActionTile(
            icon: Icons.person_add_alt_1,
            iconColor: scheme.primary,
            title: 'Registrasi Pegawai',
            subtitle: 'Tambah pegawai & cetak QR dari NIK / CODE',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RegisterPage()),
            ),
          ),

          const SizedBox(height: 10),

          // Daftar Pegawai
          _PresensiActionTile(
            icon: Icons.people_outline,
            iconColor: Colors.blue,
            title: 'Daftar Pegawai',
            subtitle: 'Lihat & cari data pegawai',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const EmployeesPage()),
            ),
          ),

          const SizedBox(height: 10),

          // Riwayat Presensi
          _PresensiActionTile(
            icon: Icons.history_rounded,
            iconColor: Colors.teal,
            title: 'Riwayat Presensi',
            subtitle: 'Lihat riwayat absensi & unduh PDF',
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const RekapPage()),
            ),
          ),

          const SizedBox(height: 10),

          // Aktivitas hari ini
          const Divider(),
          const SizedBox(height: 8),
          const Text(
            'Aktivitas Hari Ini',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          _loadingKpi
              ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
              : _rowsToday.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('Belum ada data absensi hari ini.'),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _rowsToday.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (ctx, i) {
                        final r = _rowsToday[i];
                        final name = (r['name'] ?? '-').toString();
                        final pos =
                            (r['position'] ?? '-').toString();
                        final inAt = _formatTime(r['first_in_at']);
                        final outAt = _formatTime(r['last_out_at']);
                        final late = int.tryParse(
                                '${r['total_minutes_late'] ?? 0}') ??
                            0;
                        final ot = int.tryParse(
                                '${r['total_overtime_minutes'] ?? 0}') ??
                            0;
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            child: Icon(
                              outAt != '-'
                                  ? Icons.logout
                                  : Icons.login,
                              size: 18,
                            ),
                          ),
                          title: Text('$name • $pos'),
                          subtitle: Text(
                            'Masuk: $inAt • Pulang: $outAt'
                            '${late > 0 ? ' • Telat ${late}m' : ''}'
                            '${ot > 0 ? ' • OT ${ot}m' : ''}',
                          ),
                        );
                      },
                    ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────
  //  RINGKASAN HARI INI (PIE CHART) - MODERN CARD
  // ─────────────────────────────────────────────────────────────────
  Widget _buildRingkasanCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2196F3), Color(0xFF9C27B0)],
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.pie_chart_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Text(
                'Ringkasan Hari Ini',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 17,
                  color: Colors.black87,
                  letterSpacing: 0.3,
                ),
              ),
              const Spacer(),
              Material(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  onTap: _loadingKpi ? null : _loadKpisToday,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      Icons.refresh_rounded,
                      size: 20,
                      color: _loadingKpi ? Colors.grey : Colors.black54,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _loadingKpi
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(strokeWidth: 3),
                  ),
                )
              : _buildPieChartSection(),
        ],
      ),
    );
  }

  Widget _buildPieChartSection() {
    // Data untuk pie chart
    final hadir = _presentToday;
    final tidakHadir = _totalEmployees - _presentToday;
    
    // Debug: print data
    print('DEBUG: Total Employees: $_totalEmployees, Present: $_presentToday');
    print('DEBUG: Hadir: $hadir, Tidak Hadir: $tidakHadir');
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        
        if (isWide) {
          // Layout horizontal untuk layar lebar
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Pie Chart
              Expanded(
                flex: 2,
                child: SizedBox(
                  height: 300,
                  child: _buildPieChart(hadir, tidakHadir),
                ),
              ),
              const SizedBox(width: 24),
              // Stats Cards
              Expanded(
                flex: 3,
                child: _buildStatsGrid(),
              ),
            ],
          );
        } else {
          // Layout vertikal untuk layar sempit
          return Column(
            children: [
              SizedBox(
                height: 250,
                child: _buildPieChart(hadir, tidakHadir),
              ),
              const SizedBox(height: 16),
              _buildStatsGrid(),
            ],
          );
        }
      },
    );
  }

  Widget _buildPieChart(int hadir, int tidakHadir) {
    final total = hadir + tidakHadir;
    
    if (total == 0) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.inbox_rounded, size: 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              const Text(
                'Belum ada data pegawai',
                style: TextStyle(color: Colors.black54, fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Pie Chart dengan AspectRatio
        Expanded(
          child: AspectRatio(
            aspectRatio: 1,
            child: PieChart(
              PieChartData(
                sectionsSpace: 3,
                centerSpaceRadius: 70,
                sections: [
                  PieChartSectionData(
                    color: const Color(0xFF4CAF50),
                    value: hadir.toDouble(),
                    title: '$hadir',
                    radius: 90,
                    titleStyle: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    badgeWidget: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.check_circle, color: Color(0xFF4CAF50), size: 16),
                    ),
                    badgePositionPercentageOffset: 1.3,
                  ),
                  PieChartSectionData(
                    color: const Color(0xFFEF5350),
                    value: tidakHadir.toDouble(),
                    title: '$tidakHadir',
                    radius: 90,
                    titleStyle: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 4,
                        ),
                      ],
                    ),
                    badgeWidget: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(Icons.cancel, color: Color(0xFFEF5350), size: 16),
                    ),
                    badgePositionPercentageOffset: 1.3,
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Legend dengan design modern
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem(const Color(0xFF4CAF50), 'Hadir', hadir, Icons.check_circle_rounded),
              Container(width: 1, height: 40, color: Colors.grey.shade300),
              _buildLegendItem(const Color(0xFFEF5350), 'Tidak Hadir', tidakHadir, Icons.cancel_rounded),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(Color color, String label, int value, IconData icon) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black54,
              ),
            ),
            Text(
              '$value',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Total Pegawai',
                _totalEmployees.toString(),
                Icons.people_rounded,
                const Color(0xFF2196F3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Hadir Hari Ini',
                _presentToday.toString(),
                Icons.check_circle_rounded,
                const Color(0xFF4CAF50),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Tagihan Bulan Ini',
                _formatRupiah(_totalInvoicesThisMonth),
                Icons.receipt_long_rounded,
                const Color(0xFFFF9800),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Total Lembur',
                '${_overtimeToday} menit',
                Icons.work_history_rounded,
                const Color(0xFF9C27B0),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.2), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 14),
          // Label
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.black.withOpacity(0.6),
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),
          // Value
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: color,
              letterSpacing: -0.5,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

}

// ─────────────────────────────────────────────────────────────────
//  HELPER WIDGETS
// ─────────────────────────────────────────────────────────────────

class _PresensiActionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _PresensiActionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
}
