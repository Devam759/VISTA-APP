import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/vista_user.dart';
import '../../../models/attendance_record.dart';
import '../../../services/firebase_service.dart';
import '../../warden/components/warden_components.dart';
import '../../warden/components/warden_tab_scaffold.dart';
import '../../warden/components/warden_attendance_calendar.dart';

class AttendanceTab extends StatefulWidget {
  final VistaUser warden;
  final FirebaseService fs;
  const AttendanceTab({super.key, required this.warden, required this.fs});

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> {
  String _hostelFilter = 'All';
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return WardenTabScaffold<AttendanceRecord>(
      title: 'Daily Attendance',
      sectionTitle: 'Attendance Records',
      tabs: const ['All', 'Marked', 'Late', 'On Leave', 'Absent'],
      searchQueryPlaceholder: 'Search student or room...',
      actionWidget: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          WardenSearchAction(
            onTap: () async {
              final picked = await WardenUIUtils.showWardenDatePicker(context, initialDate: _selectedDate);
              if (picked != null) setState(() => _selectedDate = picked);
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.calendar_today_rounded, color: kPrimary, size: 18),
                const SizedBox(width: 8),
                Text(
                  DateFormat('MMM d').format(_selectedDate),
                  style: const TextStyle(color: kPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          WardenSearchAction(
            onTap: () => WardenUIUtils.showHostelFilter(
              context: context,
              currentFilter: _hostelFilter == 'All' ? null : _hostelFilter,
              onSelected: (val) => setState(() => _hostelFilter = val ?? 'All'),
            ),
            child: Icon(
              Icons.apartment_rounded,
              color: _hostelFilter == 'All' ? Colors.black54 : kPrimary,
              size: 22,
            ),
          ),
        ],
      ),
      streamFactory: () => widget.fs.getUnifiedAttendanceStream('All', _selectedDate),
      emptyIcon: Icons.how_to_reg_rounded,
      emptyTitle: 'No Attendance Records',
      emptySubtitle: 'Student attendance records for this date will appear here.',
      extraHeaderBuilder: (records) {
        final now = DateTime.now();
        final isLateWindow = now.hour >= 22;
        final defaulters = records.where((r) => r.status == 'Absent').toList();
        if (isLateWindow && defaulters.isNotEmpty) {
          return PendingAttendanceBanner(
            count: defaulters.length,
            onViewList: () => WardenUIUtils.showPendingAttendanceList(context, defaulters),
          );
        }
        return const SizedBox.shrink();
      },
      itemBuilder: (context, record) => WardenCard(
        onTap: () => _showStudentAttendanceHistory(record.student),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.student.name,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1E293B)),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Room ${record.student.roomNumber ?? "N/A"} • ${shortHostelName(record.student.hostel)}',
                    style: const TextStyle(color: Colors.black45, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            _statusIndicator(record.status),
          ],
        ),
      ),
      filterLogic: (record, tab, query) {
        if (_hostelFilter != 'All' && record.student.hostel != _hostelFilter) return false;
        if (tab != 'All' && record.status != tab) return false;
        if (query.isNotEmpty) {
          final q = query.toLowerCase();
          return record.student.name.toLowerCase().contains(q) || (record.student.roomNumber ?? '').toLowerCase().contains(q);
        }
        return true;
      },
    );
  }

  Widget _statusIndicator(String status) {
    Color color;
    switch (status) {
      case 'Present':
      case 'Marked':
        color = const Color(0xFF10B981); // Green
        break;
      case 'Late':
        color = const Color(0xFFF59E0B); // Yellow/Amber
        break;
      case 'On Leave':
        color = Colors.grey;
        break;
      default: // Absent
        color = Colors.red;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.15), width: 1),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  void _showStudentAttendanceHistory(VistaUser student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => WardenStudentCalendar(student: student, fs: widget.fs),
    );
  }
}
