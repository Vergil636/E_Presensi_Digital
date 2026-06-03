import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:absensi_pegawai/pages/unified_login_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('UnifiedLoginPage renders email & password fields', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: UnifiedLoginPage()));

    // Judul form
    expect(find.text('Admin Login'), findsOneWidget);

    // Dua TextFormField (Email + Password)
    expect(find.byType(TextFormField), findsNWidgets(2));

    // Tombol Login
    expect(find.text('Masuk'), findsOneWidget);
  });
}
