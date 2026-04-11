import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/vista_user.dart';
import '../../../services/firebase_service.dart';
import '../../../models/attendance_record.dart';
import '../components/warden_components.dart';
import '../components/warden_tab_scaffold.dart';
import '../components/warden_attendance_calendar.dart';

class AttendanceTab extends StatefulWidget {
  final VistaUser warden;
  final FirebaseService fs;
  const AttendanceTab({super.key, required this.warden, required this.fs});

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> {
  DateTime _selectedDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return WardenTabScaffold<AttendanceRecord>(
      sectionTitle: 'Attendance Records',
      tabs: const ['All', 'Marked', 'Late', 'On Leave', 'Absent'],
      actionWidget: WardenSearchAction(
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
      streamFactory: () => widget.fs.getUnifiedAttendanceStream(widget.warden.hostel, _selectedDate),
      emptyIcon: Icons.how_to_reg_rounded,
      emptyTitle: 'No Attendance Records',
      emptySubtitle: 'Student attendance records for this date will appear here.',
      itemBuilder: (context, record) => WardenCard(
        onTap: () => _showStudentAttendanceHistory(record.student),
        child: Row(
          children: [
            _statusIndicator(record.status),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    record.student.name,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, color: Color(0xFF1E293B)),
                  ),
                  Text(
                    'Room ${record.student.roomNumber ?? "N/A"}',
                    style: const TextStyle(color: Colors.black45, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text(
              record.status == 'On Leave' ? 'On Leave' : (record.attendance == null ? 'Not Marked' : DateFormat('hh:mm a').format(record.attendance!.timestamp)),
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black38),
            ),
          ],
        ),
      ),
      searchQueryPlaceholder: 'Search student or room...',
      filterLogic: (record, tab, query) {
        if (tab != 'All' && record.status != tab) return false;
        if (query.isNotEmpty) {
          final q = query.toLowerCase();
          return record.student.name.toLowerCase().contains(q) || (record.student.roomNumber?.toLowerCase().contains(q) ?? false);
        }
        return true;
      },
    );
  }

  Widget _statusIndicator(String status) {
    Color color;
    IconData icon;
    switch (status) {
      case 'Marked':
        color = Colors.green;
        icon = Icons.check_circle_rounded;
        break;
      case 'Late':
        color = Colors.orange;
        icon = Icons.access_time_filled_rounded;
        break;
      case 'On Leave':
        color = Colors.blue;
        icon = Icons.home_rounded;
        break;
      default:
        color = Colors.red;
        icon = Icons.cancel_rounded;
    }
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Icon(icon, color: color, size: 20),
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
