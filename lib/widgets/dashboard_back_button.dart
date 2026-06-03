// lib/widgets/dashboard_back_button.dart
import 'package:flutter/material.dart';
import '../pages/dashboard_page.dart';

/// Widget tombol untuk kembali ke Dashboard
/// Digunakan di AppBar halaman-halaman lain
class DashboardBackButton extends StatelessWidget {
  final Color? color;
  final String? tooltip;

  const DashboardBackButton({
    super.key,
    this.color,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.home, color: color),
      tooltip: tooltip ?? 'Kembali ke Dashboard',
      onPressed: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DashboardPage()),
          (route) => false,
        );
      },
    );
  }
}

/// Widget tombol text untuk kembali ke Dashboard
/// Alternatif dengan text button
class DashboardBackTextButton extends StatelessWidget {
  final String? label;
  final Color? color;

  const DashboardBackTextButton({
    super.key,
    this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      icon: Icon(Icons.home, size: 18, color: color ?? Colors.blue),
      label: Text(
        label ?? 'Dashboard',
        style: TextStyle(color: color ?? Colors.blue),
      ),
      onPressed: () {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DashboardPage()),
          (route) => false,
        );
      },
    );
  }
}
