import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:absensi_pegawai/pages/login_page.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('LoginPage renders email & password fields', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginPage()));

    // Judul form
    expect(find.text('Admin Login'), findsOneWidget);

    // Dua TextFormField (Email + Password)
    expect(find.byType(TextFormField), findsNWidgets(2));

    // Tombol Login
    expect(find.text('Masuk'), findsOneWidget);
  });
}
