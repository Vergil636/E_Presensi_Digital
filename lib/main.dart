// lib/main.dart
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart'; // ✅ Tambahkan ini

// PAGES
import 'pages/unified_login_page.dart';
import 'pages/dashboard_page.dart';

// ====== KONFIGURASI SUPABASE ======
const SUPABASE_URL = 'https://ywcorlgzufyxcaaznxwu.supabase.co';
const SUPABASE_ANON_KEY =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl3Y29ybGd6dWZ5eGNhYXpueHd1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjA2MjgzODgsImV4cCI6MjA3NjIwNDM4OH0.F8SmRDtUD5eBSljTUAbLcmvmk6BTy-d3J4UBRWi2SkQ';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🟢 Inisialisasi locale "id_ID" agar bisa pakai DateFormat('EEEE, dd MMMM yyyy', 'id_ID')
  await initializeDateFormatting('id_ID', null);

  await Supabase.initialize(
    url: SUPABASE_URL,
    anonKey: SUPABASE_ANON_KEY,
    // PKCE recommended untuk Web
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );

  runApp(const AbsensiApp());
}

class AbsensiApp extends StatelessWidget {
  const AbsensiApp({super.key});

  // Key global agar AuthWatcher bisa navigate tanpa context dari builder
  static final navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;

    return MaterialApp(
      navigatorKey: AbsensiApp.navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'E-Absensi Cv.Tanjung Agung',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.green,
        brightness: Brightness.light,
      ),
      home: client.auth.currentSession == null
          ? const UnifiedLoginPage()
          : const DashboardPage(),
      builder: (context, child) {
        return AuthWatcher(child: child ?? const SizedBox.shrink());
      },
    );
  }
}

/// Widget kecil untuk mengawasi perubahan sesi Auth
class AuthWatcher extends StatefulWidget {
  final Widget child;
  const AuthWatcher({super.key, required this.child});

  @override
  State<AuthWatcher> createState() => _AuthWatcherState();
}

class _AuthWatcherState extends State<AuthWatcher> {
  late final Stream<AuthState> _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = Supabase.instance.client.auth.onAuthStateChange;
    _authSub.listen((event) {
      final session = event.session;
      final nav = AbsensiApp.navigatorKey.currentState;
      if (nav == null) return;
      if (session != null) {
        nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const DashboardPage()),
          (route) => false,
        );
      } else {
        nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const UnifiedLoginPage()),
          (route) => false,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
