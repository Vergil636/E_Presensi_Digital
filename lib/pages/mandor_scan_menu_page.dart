// lib/pages/mandor_scan_menu_page.dart
import 'package:flutter/material.dart';
import 'mandor_scan_page.dart';

class MandorScanMenuPage extends StatelessWidget {
  final Map<String, dynamic> mandorData;

  const MandorScanMenuPage({
    super.key,
    required this.mandorData,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        title: const Text(
          'Pilih Mode Scan',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),

            // Title
            const Text(
              'Pilih Jenis Absensi',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Silakan pilih mode scan sesuai kebutuhan',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.black54,
              ),
            ),
            const SizedBox(height: 24),

            // Option 1: Scan IN
            _buildScanModeCard(
              context: context,
              icon: Icons.login,
              iconColor: Colors.blue,
              gradientColors: [Colors.blue.shade600, Colors.blue.shade400],
              title: 'Scan IN (Masuk)',
              subtitle:
                  'Scan QR untuk absen masuk sesuai aturan jam kerja.',
              badge: 'IN',
              badgeColor: Colors.blue,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MandorScanPage(
                      mandorData: mandorData,
                      isEmergency: false,
                      scanType: 'IN',
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // Option 2: Scan OUT
            _buildScanModeCard(
              context: context,
              icon: Icons.logout,
              iconColor: Colors.green,
              gradientColors: [Colors.green.shade600, Colors.green.shade400],
              title: 'Scan OUT (Pulang)',
              subtitle:
                  'Scan QR untuk absen pulang sesuai aturan jam kerja.',
              badge: 'OUT',
              badgeColor: Colors.green,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MandorScanPage(
                      mandorData: mandorData,
                      isEmergency: false,
                      scanType: 'OUT',
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 12),

            // Option 3: Emergency Out
            _buildScanModeCard(
              context: context,
              icon: Icons.emergency,
              iconColor: Colors.red,
              gradientColors: [Colors.red.shade600, Colors.red.shade400],
              title: 'Pulang Darurat',
              subtitle:
                  'Scan QR untuk absen pulang darurat. Langsung OUT tanpa validasi waktu.',
              badge: 'DARURAT',
              badgeColor: Colors.red,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MandorScanPage(
                      mandorData: mandorData,
                      isEmergency: true,
                      scanType: 'OUT',
                    ),
                  ),
                );
              },
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildScanModeCard({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required List<Color> gradientColors,
    required String title,
    required String subtitle,
    required String badge,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: Colors.white, size: 26),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Text(
                      badge,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.arrow_forward,
                      color: Colors.white,
                      size: 18,
                    ),
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
