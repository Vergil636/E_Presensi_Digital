// lib/pages/dashboard_page.dart
import 'dart:async';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../services/supabase_service.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'employees_page.dart';
import 'scan_page.dart';
import 'rekap_page.dart';

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

  @override
  void initState() {
    super.initState();
    _initClock();
    _loadRule();
  }

  void _initClock() {
    _todayText = DateFormat('EEEE, dd MMMM yyyy', 'id_ID').format(DateTime.now());
    _timeText = DateFormat('HH:mm:ss').format(DateTime.now());
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

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _logout() async {
    await adminLogout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (r) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text('Dashboard Admin'),
        actions: [
          IconButton(
            tooltip: 'Refresh aturan',
            onPressed: _loadingRule ? null : _loadRule,
            icon: const Icon(Icons.refresh),
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            label: const Text('Logout'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadRule,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            // Header (bukan card, tampil hero-like)
            _HeaderHero(today: _todayText, timeText: _timeText),

            const SizedBox(height: 16),

            // Work Rules (CardView)
            SectionCard(
              title: 'Aturan Kerja',
              trailing: IconButton(
                tooltip: 'Muat ulang',
                icon: const Icon(Icons.refresh),
                onPressed: _loadingRule ? null : _loadRule,
              ),
              child: _loadingRule
                  ? Row(
                      children: const [
                        SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 12),
                        Text('Memuat aturan kerja...'),
                      ],
                    )
                  : _rule == null
                      ? Row(
                          children: const [
                            Icon(Icons.warning_amber, color: Colors.orange),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Belum ada work rules aktif. Silakan set di tabel backend.',
                              ),
                            ),
                          ],
                        )
                      : _WorkRulesView(rule: _rule!),
            ),

            const SizedBox(height: 16),

            // Aksi Cepat (CardView berisi grid/list of cards)
            SectionCard(
              title: 'Aksi Cepat',
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 920;

                  if (isWide) {
                    // 3 kartu kecil kiri + 1 kartu scan tinggi kanan (semua dalam card container di atas)
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: Column(
                            children: [
                              ActionCard(
                                icon: Icons.person_add_alt_1,
                                title: 'Registrasi Pegawai',
                                subtitle: 'Tambah pegawai & cetak QR dari NIK / CODE',
                                color: scheme.primary,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const RegisterPage()),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ActionCard(
                                icon: Icons.people_outline,
                                title: 'Daftar Pegawai',
                                subtitle: 'Lihat & cari data pegawai',
                                color: Colors.blue,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const EmployeesPage()),
                                ),
                              ),
                              const SizedBox(height: 12),
                              ActionCard(
                                icon: Icons.assessment_outlined,
                                title: 'Rekap & Export',
                                subtitle: 'Lihat rekap absensi & unduh PDF',
                                color: Colors.teal,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const RekapPage()),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: ScanTallCard(
                            onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(builder: (_) => const ScanPage()),
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  // Mobile: semuanya vertikal
                  return Column(
                    children: [
                      ActionCard(
                        icon: Icons.person_add_alt_1,
                        title: 'Registrasi Pegawai',
                        subtitle: 'Tambah pegawai & cetak QR dari NIK / CODE',
                        color: scheme.primary,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RegisterPage()),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ActionCard(
                        icon: Icons.people_outline,
                        title: 'Daftar Pegawai',
                        subtitle: 'Lihat & cari data pegawai',
                        color: Colors.blue,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const EmployeesPage()),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ActionCard(
                        icon: Icons.assessment_outlined,
                        title: 'Rekap & Export',
                        subtitle: 'Lihat rekap absensi & unduh PDF',
                        color: Colors.teal,
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const RekapPage()),
                        ),
                      ),
                      const SizedBox(height: 12),
                      ScanTallCard(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ScanPage()),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),

            const SizedBox(height: 16),

            // Tip (CardView)
            SectionCard(
              title: 'Tips',
              child: _TipBox(
                text:
                    'Aturan aktif: IN ≤ 08:30; OUT 16:30–17:15 normal; OUT >17:15–22:00 lembur; >22:00 lembur dipatok sampai 22:00.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===================== REUSABLE CARD CONTAINERS =====================

class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: scheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header kecil untuk judul section
            Row(
              children: [
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

// ===================== HEADER HERO =====================

class _HeaderHero extends StatelessWidget {
  final String today;
  final String timeText;
  const _HeaderHero({required this.today, required this.timeText});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            scheme.primary.withOpacity(.18),
            scheme.secondary.withOpacity(.14),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withOpacity(.4)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Row(
        children: [
          Container(
            height: 56,
            width: 56,
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.dashboard_outlined, color: scheme.primary, size: 30),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selamat datang, Sir Iskandar 👋',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(today, style: Theme.of(context).textTheme.bodyMedium),
                    const SizedBox(width: 10),
                    const Text('•'),
                    const SizedBox(width: 10),
                    Row(
                      children: [
                        Icon(Icons.access_time, size: 16, color: scheme.primary),
                        const SizedBox(width: 6),
                        Text(
                          timeText,
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
                        ),
                      ],
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

// ===================== ACTION CARDS =====================

class ActionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const ActionCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: scheme.surfaceContainerHighest,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: color.withOpacity(.16),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 26, color: color),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class ScanTallCard extends StatelessWidget {
  final VoidCallback onTap;
  const ScanTallCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0.8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: scheme.surfaceContainerHighest,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: SizedBox(
            height: 272,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: Colors.deepPurple.withOpacity(.18),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(Icons.qr_code_scanner,
                      color: Colors.deepPurple, size: 28),
                ),
                const SizedBox(height: 14),
                Text(
                  'Scan QR (IN/OUT)',
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  'Absen sesuai aturan aktif. Klik untuk mulai kamera.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.bottomRight,
                  child: FilledButton.icon(
                    onPressed: onTap,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Mulai Scan'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ===================== WORK RULES & TIP =====================

class _WorkRulesView extends StatelessWidget {
  final Map<String, dynamic> rule;
  const _WorkRulesView({required this.rule});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    String tz = (rule['tz'] ?? 'Asia/Jakarta').toString();
    String inStart = (rule['in_start'] ?? '07:30').toString();
    String inEnd = (rule['in_end'] ?? '08:30').toString();
    String outStart = (rule['out_start'] ?? '16:30').toString();
    String outEnd = (rule['out_end'] ?? '17:15').toString();
    String otEnd = (rule['overtime_end'] ?? '22:00').toString();
    String name = (rule['name'] ?? 'Default').toString();

    Widget chip(IconData icon, String label, String value) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant.withOpacity(.6)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Text(
                '$label: ',
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              Text(value, style: Theme.of(context).textTheme.labelMedium),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.schedule, color: scheme.primary),
            const SizedBox(width: 8),
            Text(
              'Aturan Kerja Aktif — $name',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            chip(Icons.public, 'TZ', tz),
            chip(Icons.login, 'IN Mulai', inStart),
            chip(Icons.timer_off, 'IN Batas', inEnd),
            chip(Icons.logout, 'OUT Mulai', outStart),
            chip(Icons.check_circle, 'OUT Normal', outEnd),
            chip(Icons.bolt, 'Lembur Maks', otEnd),
          ],
        ),
      ],
    );
  }
}

class _TipBox extends StatelessWidget {
  final String text;
  const _TipBox({required this.text});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withOpacity(.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withOpacity(.5)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}
