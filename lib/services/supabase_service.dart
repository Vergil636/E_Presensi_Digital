// lib/services/supabase_service.dart
import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

/// ==============================
/// AUTH (ADMIN)
/// ==============================

Future<void> adminLogin(String email, String password) async {
  try {
    await supabase.auth.signInWithPassword(email: email, password: password);
  } on AuthException catch (e) {
    throw Exception(e.message);
  } catch (e) {
    rethrow;
  }
}

Future<void> adminLogout() async {
  await supabase.auth.signOut();
}

/// ==============================
/// AUTH (MANDOR) - Simple Auth
/// ==============================

Future<Map<String, dynamic>> mandorLogin(String email, String password) async {
  try {
    final List result = await supabase.rpc('mandor_login', params: {
      'p_email': email,
      'p_password': password,
    });
    
    if (result.isEmpty) {
      throw Exception('Invalid email or password');
    }
    
    return result.first as Map<String, dynamic>;
  } on PostgrestException catch (e) {
    throw _pgErrorMessage(e);
  } catch (e) {
    rethrow;
  }
}

/// ==============================
/// BOOTSTRAP ADMIN
/// ==============================

/// Tetapkan user login sebagai admin pertama (project fresh).
Future<bool> bootstrapFirstAdmin() async {
  _ensureLoggedIn();
  try {
    final res = await supabase.rpc('bootstrap_first_admin');
    return (res is bool) ? res : true;
  } on PostgrestException catch (e) {
    if (e.message.toLowerCase().contains('admin sudah ada')) return false;
    throw _pgErrorMessage(e);
  }
}

/// ==============================
/// EMPLOYEES
/// ==============================

/// Registrasi pegawai via RPC (hanya admin)
Future<Map<String, dynamic>> registerEmployee({
  required String name,
  required String nik,
  required String position,
  String? code, // optional: kalau null -> code = nik (sesuai SQL)
}) async {
  _ensureLoggedIn();
  try {
    final res = await supabase.rpc('register_employee', params: {
      'p_name': name,
      'p_nik': nik,
      'p_position': position,
      'p_code': code,
    });
    if (res is Map) return res.cast<String, dynamic>();
    throw Exception('Gagal registrasi pegawai.');
  } on PostgrestException catch (e) {
    throw _pgErrorMessage(e);
  }
}

/// Ambil daftar pegawai (opsional search: name/nik/position/code)
Future<List<Map<String, dynamic>>> fetchEmployees({String? search}) async {
  _ensureLoggedIn();
  try {
    var query = supabase.from('employees').select();

    if (search != null && search.trim().isNotEmpty) {
      final s = search.trim();
      // cari by name/nik/position/code
      query = query.or(
        'name.ilike.%$s%,nik.ilike.%$s%,position.ilike.%$s%,code.ilike.%$s%',
      );
    }

    final List data = await query.order('created_at', ascending: false);
    return data.cast<Map<String, dynamic>>();
  } on PostgrestException catch (e) {
    throw _pgErrorMessage(e);
  }
}

/// Hapus pegawai (akan gagal jika masih terkait di attendance kecuali FK CASCADE)
Future<void> deleteEmployee(String employeeId) async {
  _ensureLoggedIn();
  try {
    await supabase.from('employees').delete().eq('id', employeeId);
  } on PostgrestException catch (e) {
    final lower = e.message.toLowerCase();
    if (lower.contains('violates foreign key') ||
        (lower.contains('update or delete on table') && lower.contains('violates'))) {
      throw Exception(
        'Gagal menghapus: Pegawai masih memiliki data absensi terkait.\n'
        'Hapus data absensi terlebih dahulu, atau atur FK attendance.employee_id menjadi ON DELETE CASCADE.',
      );
    }
    throw _pgErrorMessage(e);
  }
}

/// ==============================
/// ATTENDANCE (scan + rekap)
/// ==============================

/// Absen IN/OUT via RPC final.
/// Pastikan fungsi DB: mark_attendance(p_scanned_value text, p_atype text|attendance_type)
/// - Aturan waktu IN (07:30–08:30) & OUT harus ada IN ditangani di SQL (RAISE EXCEPTION)
Future<Map<String, dynamic>> markAttendance({
  required String scannedValue,
  required String type, // 'IN' | 'OUT'
  bool isEmergency = false,
  double? latitude,
  double? longitude,
  String? locationAddress,
  double? locationAccuracy,
}) async {
  _ensureLoggedIn();

  final normalizedType = type.trim().toUpperCase();
  if (normalizedType != 'IN' && normalizedType != 'OUT') {
    throw Exception('Tipe absen tidak valid. Gunakan IN atau OUT.');
  }

  try {
    final res = await supabase.rpc('mark_attendance', params: {
      'p_scanned_value': scannedValue,
      'p_atype': normalizedType,
      'p_emergency': isEmergency,
      'p_latitude': latitude,
      'p_longitude': longitude,
      'p_location_address': locationAddress,
      'p_location_accuracy': locationAccuracy,
    });

    if (res is Map) return res.cast<String, dynamic>();
    throw Exception('Gagal mencatat absensi.');
  } on PostgrestException catch (e) {
    throw _pgErrorMessage(e);
  }
}

/// Input absensi manual (bypass validasi work_rules)
/// Digunakan untuk mengatasi lupa absen atau koreksi data
Future<Map<String, dynamic>> manualAttendanceEntry({
  required String employeeId,
  required DateTime date,
  required String checkInTime,  // format: 'HH:mm' contoh: '08:00'
  String? checkOutTime,          // format: 'HH:mm' contoh: '17:00'
  double overtimeHours = 0,      // dalam jam, contoh: 2.5
  String? notes,
}) async {
  _ensureLoggedIn();

  try {
    final res = await supabase.rpc('manual_attendance_entry', params: {
      'p_employee_id': employeeId,
      'p_date': _asDate(date),
      'p_check_in_time': checkInTime,
      'p_check_out_time': checkOutTime,
      'p_overtime_hours': overtimeHours,
      'p_notes': notes,
    });

    if (res is Map) return res.cast<String, dynamic>();
    throw Exception('Gagal mencatat absensi manual.');
  } on PostgrestException catch (e) {
    throw _pgErrorMessage(e);
  }
}

/// Rekap harian (memanggil RPC list_attendance_daily)
/// Signature contoh: list_attendance_daily(p_from date, p_to date, p_employee uuid, p_search text, p_limit int, p_offset int)
Future<List<Map<String, dynamic>>> listAttendanceDaily({
  required DateTime from,
  required DateTime to,
  String? employeeId,
  String? search,
  int limit = 50,
  int offset = 0,
}) async {
  _ensureLoggedIn();
  try {
    final params = {
      'p_from': _asDate(from),
      'p_to': _asDate(to),
      'p_employee': employeeId,
      'p_search': search,
      'p_limit': limit,
      'p_offset': offset,
    };

    final res = await supabase.rpc('list_attendance_daily', params: params);
    if (res is List) return res.cast<Map<String, dynamic>>();
    return (res as dynamic).cast<Map<String, dynamic>>();
  } on PostgrestException catch (e) {
    throw _pgErrorMessage(e);
  }
}

/// Rekap harian untuk mandor (tanpa auth check)
Future<List<Map<String, dynamic>>> listAttendanceDailyForMandor({
  required DateTime from,
  required DateTime to,
  String? employeeId,
  String? search,
  int limit = 50,
  int offset = 0,
}) async {
  try {
    final params = {
      'p_from': _asDate(from),
      'p_to': _asDate(to),
      'p_employee': employeeId,
      'p_search': search,
      'p_limit': limit,
      'p_offset': offset,
    };

    final res = await supabase.rpc('list_attendance_daily', params: params);
    if (res is List) return res.cast<Map<String, dynamic>>();
    return (res as dynamic).cast<Map<String, dynamic>>();
  } on PostgrestException catch (e) {
    throw _pgErrorMessage(e);
  }
}

/// (Opsional) Rekap mingguan bila kamu sediakan RPC list_attendance_weekly
Future<List<Map<String, dynamic>>> listAttendanceWeekly({
  required DateTime from,
  required DateTime to,
  String? employeeId,
  String? search,
  int limit = 50,
  int offset = 0,
}) async {
  _ensureLoggedIn();
  try {
    final params = {
      'p_from': _asDate(from),
      'p_to': _asDate(to),
      'p_employee': employeeId,
      'p_search': search,
      'p_limit': limit,
      'p_offset': offset,
    };

    final res = await supabase.rpc('list_attendance_weekly', params: params);
    if (res is List) return res.cast<Map<String, dynamic>>();
    return (res as dynamic).cast<Map<String, dynamic>>();
  } on PostgrestException catch (e) {
    // kalau RPC belum dibuat, biar errornya jelas
    throw _pgErrorMessage(e);
  }
}

/// Utility: Export CSV dari list<Map<String,dynamic>>
String buildCsv(List<Map<String, dynamic>> rows) {
  if (rows.isEmpty) return '';
  final headers = rows.first.keys.toList();
  final buf = StringBuffer()..writeln(headers.join(','));

  for (final r in rows) {
    final line = headers.map((h) {
      final v = r[h];
      final s = (v == null) ? '' : v.toString();
      // escape koma & kutip
      final escaped = s.replaceAll('"', '""');
      return '"$escaped"';
    }).join(',');
    buf.writeln(line);
  }
  return buf.toString();
}

/// ==============================
/// INVOICES
/// ==============================

/// Simpan tagihan baru beserta item-itemnya
Future<String> saveInvoice({
  required String nomor,
  required String pelanggan,
  String? phone,
  required String catatan,
  required double grandTotal,
  required List<Map<String, dynamic>> items,
}) async {
  _ensureLoggedIn();
  try {
    // Insert header invoice
    final res = await supabase
        .from('invoices')
        .insert({
          'nomor': nomor,
          'pelanggan': pelanggan,
          'phone': phone,
          'catatan': catatan,
          'grand_total': grandTotal,
        })
        .select('id')
        .single();

    final invoiceId = res['id'] as String;

    // Insert items
    if (items.isNotEmpty) {
      final rows = items
          .map((e) => {
                'invoice_id': invoiceId,
                'nama_pekerjaan': e['nama_pekerjaan'],
                'satuan': e['satuan'],
                'harga_satuan': e['harga_satuan'],
                'qty': e['qty'],
                'subtotal': e['subtotal'],
              })
          .toList();
      await supabase.from('invoice_items').insert(rows);
    }
    return invoiceId;
  } on PostgrestException catch (e) {
    throw _pgErrorMessage(e);
  }
}

/// Ambil daftar invoice (header saja, diurutkan terbaru)
Future<List<Map<String, dynamic>>> fetchInvoices() async {
  _ensureLoggedIn();
  try {
    final List data = await supabase
        .from('invoices')
        .select()
        .order('created_at', ascending: false);
    return data.cast<Map<String, dynamic>>();
  } on PostgrestException catch (e) {
    throw _pgErrorMessage(e);
  }
}

/// Ambil item-item dari satu invoice
Future<List<Map<String, dynamic>>> fetchInvoiceItems(String invoiceId) async {
  _ensureLoggedIn();
  try {
    final List data = await supabase
        .from('invoice_items')
        .select()
        .eq('invoice_id', invoiceId)
        .order('nama_pekerjaan');
    return data.cast<Map<String, dynamic>>();
  } on PostgrestException catch (e) {
    throw _pgErrorMessage(e);
  }
}

/// Hapus invoice (cascade akan hapus items otomatis)
Future<void> deleteInvoice(String invoiceId) async {
  _ensureLoggedIn();
  try {
    await supabase.from('invoices').delete().eq('id', invoiceId);
  } on PostgrestException catch (e) {
    throw _pgErrorMessage(e);
  }
}

/// ==============================
/// WORK RULES (lihat aturan aktif)
/// ==============================

Future<Map<String, dynamic>?> fetchActiveWorkRules() async {
  _ensureLoggedIn();
  try {
    final List rows = await supabase
        .from('work_rules')
        .select()
        .eq('active', true)
        .order('updated_at', ascending: false)
        .limit(1);
    if (rows.isEmpty) return null;
    return (rows.first as Map).cast<String, dynamic>();
  } on PostgrestException catch (e) {
    throw _pgErrorMessage(e);
  }
}

/// ==============================
/// MANDOR MANAGEMENT
/// ==============================

/// Get all mandors (Admin only)
Future<List<Map<String, dynamic>>> getAllMandors() async {
  _ensureLoggedIn();
  try {
    final List data = await supabase.rpc('get_all_mandors');
    return data.cast<Map<String, dynamic>>();
  } on PostgrestException catch (e) {
    throw _pgErrorMessage(e);
  }
}

/// Create mandor (simple auth, no Supabase Auth)
Future<String> createMandorSimple({
  required String name,
  required String email,
  required String phone,
  required String password,
}) async {
  _ensureLoggedIn();
  
  try {
    final mandorId = await supabase.rpc('create_mandor_simple', params: {
      'p_name': name,
      'p_email': email,
      'p_phone': phone,
      'p_password': password,
    });
    
    return mandorId as String;
  } on PostgrestException catch (e) {
    throw _pgErrorMessage(e);
  } catch (e) {
    rethrow;
  }
}

/// Update mandor info (Admin only)
Future<void> updateMandor({
  required String mandorId,
  required String name,
  required String phone,
}) async {
  _ensureLoggedIn();
  try {
    await supabase.rpc('update_mandor', params: {
      'p_mandor_id': mandorId,
      'p_name': name,
      'p_phone': phone,
    });
  } on PostgrestException catch (e) {
    throw _pgErrorMessage(e);
  }
}

/// Reset mandor password (Admin only)
Future<void> resetMandorPassword({
  required String mandorId,
  required String newPassword,
}) async {
  _ensureLoggedIn();
  
  try {
    await supabase.rpc('reset_mandor_password', params: {
      'p_mandor_id': mandorId,
      'p_new_password': newPassword,
    });
  } on PostgrestException catch (e) {
    throw _pgErrorMessage(e);
  } catch (e) {
    rethrow;
  }
}

/// Deactivate mandor (Admin only)
Future<void> deactivateMandor(String mandorId) async {
  _ensureLoggedIn();
  try {
    await supabase.rpc('deactivate_mandor', params: {
      'p_mandor_id': mandorId,
    });
  } on PostgrestException catch (e) {
    throw _pgErrorMessage(e);
  }
}

/// Activate mandor (Admin only)
Future<void> activateMandor(String mandorId) async {
  _ensureLoggedIn();
  try {
    await supabase.rpc('activate_mandor', params: {
      'p_mandor_id': mandorId,
    });
  } on PostgrestException catch (e) {
    throw _pgErrorMessage(e);
  }
}

/// Mark attendance by mandor (Mandor only)
Future<Map<String, dynamic>> markAttendanceByMandor({
  required String mandorId,
  required String scannedValue,
  required String atype,
  String? mandorNotes,
  double? latitude,
  double? longitude,
  String? locationAddress,
  double? locationAccuracy,
}) async {
  try {
    final result = await supabase.rpc('mark_attendance_by_mandor', params: {
      'p_mandor_id': mandorId,
      'p_scanned_value': scannedValue,
      'p_atype': atype,
      'p_mandor_notes': mandorNotes,
      'p_latitude': latitude,
      'p_longitude': longitude,
      'p_location_address': locationAddress,
      'p_location_accuracy': locationAccuracy,
    });
    
    return (result as Map).cast<String, dynamic>();
  } on PostgrestException catch (e) {
    throw _pgErrorMessage(e);
  } catch (e) {
    rethrow;
  }
}

/// Get current user info (role, etc)
Future<Map<String, dynamic>?> getCurrentUser() async {
  _ensureLoggedIn();
  try {
    final List data = await supabase.rpc('get_current_user');
    if (data.isEmpty) return null;
    return (data.first as Map).cast<String, dynamic>();
  } on PostgrestException catch (e) {
    throw _pgErrorMessage(e);
  }
}

/// Get today's attendance summary (for mandor/admin dashboard)
Future<List<Map<String, dynamic>>> getTodayAttendanceSummary() async {
  _ensureLoggedIn();
  try {
    final List data = await supabase.rpc('get_today_attendance_summary');
    return data.cast<Map<String, dynamic>>();
  } on PostgrestException catch (e) {
    throw _pgErrorMessage(e);
  }
}

/// ==============================
/// UTILITIES
/// ==============================

void _ensureLoggedIn() {
  if (supabase.auth.currentSession == null) {
    throw Exception('Anda belum login.');
  }
}

/// Format ke 'YYYY-MM-DD' agar aman untuk argumen bertipe DATE
String _asDate(DateTime dt) {
  return '${dt.year.toString().padLeft(4, '0')}-'
      '${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')}';
}

/// Rapikan pesan error Postgres/Supabase
Exception _pgErrorMessage(PostgrestException e) {
  final msg = e.message.trim();

  // Frasa error yang umum dipakai di fungsi SQL (case-insensitive)
  final known = <String>[
    'not allowed',
    'nik atau code sudah terdaftar',
    'nik/code sudah terdaftar',
    'pegawai dengan nik/code',
    'work rules belum diatur',
    'sudah absen masuk hari ini',
    'sudah absen pulang hari ini',
    'belum absen masuk hari ini',
    'belum masuk waktu absen pulang',
    'sudah lewat waktu absen masuk',
    'admin sudah ada',
    'function list_attendance_daily',
    'function list_attendance_weekly',
  ];

  for (final k in known) {
    if (msg.toLowerCase().contains(k.toLowerCase())) {
      // tampilkan original message dari DB supaya user paham aturannya
      return Exception(e.message);
    }
  }

  // Tampilkan detail asli jika ada
  final details = [
    e.details,
    e.hint,
    e.code,
  ].whereType<String>().where((s) => s.trim().isNotEmpty).join(' | ');

  final pretty = details.isNotEmpty ? '$msg ($details)' : msg;
  return Exception(pretty.isNotEmpty ? pretty : 'Terjadi kesalahan pada server.');
}
