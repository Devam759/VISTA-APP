import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../models/vista_user.dart';
import '../../../services/firebase_service.dart';
import '../../../models/attendance_record.dart';
import 'package:provider/provider.dart';
import '../../../providers/warden_provider.dart';
import '../components/warden_components.dart';
import '../components/warden_tab_scaffold.dart';
import '../components/warden_attendance_calendar.dart';
import '../../../widgets/common/skeleton_loader.dart';

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
    return Consumer<WardenProvider>(
      builder: (context, wp, _) {
        return WardenTabScaffold<AttendanceRecord>(
          title: 'Daily Attendance',
          sectionTitle: 'Attendance Records',
          tabs: const ['All', 'Present', 'Late', 'On Leave', 'Absent'],
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
          streamFactory: () => widget.fs.getUnifiedAttendanceStream(wp.currentHostelFilter, _selectedDate),
          loadingWidget: const AttendanceListSkeleton(),
          emptyIcon: Icons.how_to_reg_rounded,
          emptyTitle: wp.currentHostelFilter == null ? 'No Attendance Data (All)' : 'No Attendance in ${wp.currentHostelFilter}',
          emptySubtitle: 'Student attendance records for this date will appear here.',
          extraHeaderBuilder: (context, records) {
            final now = DateTime.now();
            final isLateWindow = now.hour >= 22;
            final defaulters = records.where((r) => r.status == 'Absent').toList();
            if (isLateWindow && defaulters.isNotEmpty) {
              return PendingAttendanceBanner(
                count: defaulters.length,
                onViewList: () => WardenUIUtils.showPendingAttendanceList(
                  context,
                  widget.fs.getUnifiedAttendanceStream(wp.currentHostelFilter, _selectedDate),
                  wardenUid: widget.warden.uid,
                  wardenName: widget.warden.name,
                ),
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
                        '${getFullHostelName(record.student.hostel)} - ${record.student.roomNumber ?? "N/A"}',
                        style: const TextStyle(color: Colors.black45, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                _statusIndicator(record.status),
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
    );
  }

  Widget _statusIndicator(String status) {
    Color color;
    switch (status) {
      case 'Present':
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
