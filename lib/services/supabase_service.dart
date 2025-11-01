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

/// Hapus pegawai (perhatikan FK pada attendance)
Future<void> deleteEmployee(String employeeId) async {
  _ensureLoggedIn();
  try {
    await supabase.from('employees').delete().eq('id', employeeId);
  } on PostgrestException catch (e) {
    // Pesan yang ramah jika terhalang FK
  final lower = e.message.toLowerCase();
    if (lower.contains('violates foreign key') ||
        lower.contains('update or delete on table') && lower.contains('violates')) {
      throw Exception(
        'Gagal menghapus: Pegawai masih memiliki data absensi terkait.\n'
        'Hapus data absensi pegawai tersebut terlebih dahulu, atau atur FK attendance.employee_id menjadi ON DELETE CASCADE.',
      );
    }
    throw _pgErrorMessage(e);
  }
}

/// ==============================
/// ATTENDANCE (scan + rekap)
/// ==============================

/// Absen IN/OUT via RPC rules final
///
/// Catatan: Pastikan fungsi di DB bernama `mark_attendance`
/// dengan argumen: (scanned_value text, atype attendance_type/text).
/// Jika nama fungsi kamu masih `mark_attendance_with_rules`,
/// cukup ganti string RPC di bawah.
Future<Map<String, dynamic>> markAttendance({
  required String scannedValue,
  required String type, // 'IN' | 'OUT'
}) async {
  _ensureLoggedIn();
  try {
    final res = await supabase.rpc('mark_attendance', params: {
      'scanned_value': scannedValue, // nama argumen di SQL
      'atype': type,                 // 'IN' atau 'OUT' (DB akan cast ke attendance_type)
    });
    if (res is Map) return res.cast<String, dynamic>();
    throw Exception('Gagal mencatat absensi.');
  } on PostgrestException catch (e) {
    throw _pgErrorMessage(e);
  }
}

/// Rekap harian (memanggil RPC list_attendance_daily)
/// Pastikan kamu sudah membuat fungsi SQL:
/// list_attendance_daily(date, date, uuid, text, int, int)
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

/// (Opsional) Rekap mingguan bila kamu buat RPC list_attendance_weekly
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
  // header
  final headers = rows.first.keys.toList();
  final buf = StringBuffer();
  buf.writeln(headers.join(','));

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

  // Sesuaikan dengan RAISE EXCEPTION di fungsi SQL
  final known = <String>[
    'not allowed',
    'NIK atau CODE sudah terdaftar',
    'NIK/CODE sudah terdaftar.',
    'pegawai dengan nik/code',
    'work rules belum diatur',
    'sudah absen masuk hari ini',
    'sudah absen pulang hari ini',
    'belum absen masuk hari ini',
    'belum masuk waktu absen pulang',
    'sudah lewat waktu absen masuk',
    'admin sudah ada',
    'function list_attendance_daily',     // kalau RPC belum ada
    'function list_attendance_weekly',
  ];

  for (final k in known) {
    if (msg.toLowerCase().contains(k.toLowerCase())) {
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
