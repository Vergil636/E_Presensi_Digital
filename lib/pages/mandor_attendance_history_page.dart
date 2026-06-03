// lib/pages/mandor_attendance_history_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/supabase_service.dart';

class MandorAttendanceHistoryPage extends StatefulWidget {
  final Map<String, dynamic> mandorData;

  const MandorAttendanceHistoryPage({
    super.key,
    required this.mandorData,
  });

  @override
  State<MandorAttendanceHistoryPage> createState() =>
      _MandorAttendanceHistoryPageState();
}

class _MandorAttendanceHistoryPageState
    extends State<MandorAttendanceHistoryPage> {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _attendances = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAttendances();
  }

  Future<void> _loadAttendances() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final from = DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
      );
      final to = from;

      final data = await listAttendanceDailyForMandor(from: from, to: to);

      setState(() {
        _attendances = data;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      _loadAttendances();
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      appBar: AppBar(
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
        title: const Text(
          'Riwayat Presensi',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAttendances,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Date selector
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.calendar_today, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    DateFormat('EEEE, dd MMMM yyyy', 'id_ID')
                        .format(_selectedDate),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: _selectDate,
                  icon: const Icon(Icons.edit_calendar, size: 18),
                  label: const Text('Ubah'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.error_outline,
                                size: 48, color: Colors.red),
                            const SizedBox(height: 16),
                            Text('Error: $_error'),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: _loadAttendances,
                              child: const Text('Coba Lagi'),
                            ),
                          ],
                        ),
                      )
                    : _attendances.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.inbox_outlined,
                                    size: 64, color: Colors.grey.shade400),
                                const SizedBox(height: 16),
                                Text(
                                  'Tidak ada presensi pada tanggal ini',
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.grey.shade600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _loadAttendances,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _attendances.length,
                              itemBuilder: (context, index) {
                                final attendance = _attendances[index];
                                return _buildAttendanceCard(attendance);
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttendanceCard(Map<String, dynamic> attendance) {
    final name = attendance['name'] ?? '-';
    final position = attendance['position'] ?? '-';
    final firstInAt = _formatTime(attendance['first_in_at']);
    final lastOutAt = _formatTime(attendance['last_out_at']);
    final totalMinutesLate =
        int.tryParse('${attendance['total_minutes_late'] ?? 0}') ?? 0;
    final totalOvertimeMinutes =
        int.tryParse('${attendance['total_overtime_minutes'] ?? 0}') ?? 0;

    final hasIn = firstInAt != '-';
    final hasOut = lastOutAt != '-';

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.green.shade100,
                  child: Icon(
                    Icons.person,
                    color: Colors.green.shade700,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        position,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const Divider(height: 24),

            // Attendance details
            Row(
              children: [
                Expanded(
                  child: _buildTimeInfo(
                    icon: Icons.login,
                    iconColor: Colors.blue,
                    label: 'Masuk',
                    time: firstInAt,
                    hasData: hasIn,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildTimeInfo(
                    icon: Icons.logout,
                    iconColor: Colors.orange,
                    label: 'Pulang',
                    time: lastOutAt,
                    hasData: hasOut,
                  ),
                ),
              ],
            ),

            // Late & Overtime
            if (totalMinutesLate > 0 || totalOvertimeMinutes > 0) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (totalMinutesLate > 0)
                    _buildBadge(
                      icon: Icons.schedule,
                      label: 'Telat ${totalMinutesLate}m',
                      color: Colors.red,
                    ),
                  if (totalOvertimeMinutes > 0)
                    _buildBadge(
                      icon: Icons.access_time,
                      label: 'Lembur ${totalOvertimeMinutes}m',
                      color: Colors.green,
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTimeInfo({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String time,
    required bool hasData,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: hasData ? iconColor.withOpacity(0.1) : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: hasData ? iconColor : Colors.grey, size: 20),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            time,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: hasData ? Colors.black87 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge({
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
