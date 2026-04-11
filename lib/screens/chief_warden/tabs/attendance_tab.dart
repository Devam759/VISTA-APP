import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/vista_user.dart';
import '../../../models/attendance_record.dart';
import '../../../services/firebase_service.dart';
import '../../../utils/export_helper.dart';
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
    final now = DateTime.now();
    final isLateWindow = now.hour >= 22;

    return WardenTabScaffold<AttendanceRecord>(
      sectionTitle: 'University Attendance',
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
          const SizedBox(width: 8),
          WardenSearchAction(
            onTap: _showRangeExport,
            child: const Icon(Icons.file_download_outlined, color: kPrimary, size: 22),
          ),
        ],
      ),
      streamFactory: () => widget.fs.getUnifiedAttendanceStream('All', _selectedDate),
      emptyIcon: Icons.how_to_reg_rounded,
      emptyTitle: 'No Attendance Records',
      emptySubtitle: 'Student attendance records for this date will appear here.',
      extraHeaderBuilder: (records) {
        final defaulters = records.where((r) => r.status == 'Absent').toList();
        if (isLateWindow && defaulters.isNotEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.1)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '${defaulters.length} students pending attendance',
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: () => _showDefaultersList(defaulters),
                    child: const Text(
                      'View List',
                      style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, decoration: TextDecoration.underline),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
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
                  Text(record.student.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  Text('Room ${record.student.roomNumber ?? "N/A"} • ${record.student.hostel ?? ""}', style: const TextStyle(color: Colors.black45, fontSize: 12)),
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

  Future<void> _showRangeExport() async {
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _selectedDate.subtract(const Duration(days: 7)),
        end: _selectedDate,
      ),
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: kPrimary, onPrimary: Colors.white, onSurface: Colors.black87),
        ),
        child: child!,
      ),
    );

    if (range != null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preparing Export...')));

      final students = await widget.fs.getHostelStudents(_hostelFilter).first;
      final attendance = await widget.fs.getHostelAttendanceRange(_hostelFilter, range.start, range.end).first;
      final leaves = await widget.fs.getHostelLeavesRange(_hostelFilter, range.start, range.end).first;

      List<DateTime> dates = [];
      for (int i = 0; i <= range.end.difference(range.start).inDays; i++) {
        dates.add(range.start.add(Duration(days: i)));
      }

      await ExportHelper.exportAttendanceSummary(
        students,
        attendance,
        leaves,
        dates,
        _hostelFilter,
      );
    }
  }

  void _showDefaultersList(List<AttendanceRecord> defaulters) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  const Text('Pending Attendance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                    child: Text('${defaulters.length}', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(),
            SizedBox(
              height: 400,
              child: ListView.builder(
                itemCount: defaulters.length,
                itemBuilder: (context, i) {
                  final student = defaulters[i].student;
                  return ListTile(
                    leading: CircleAvatar(
                        backgroundColor: kPrimary.withValues(alpha: 0.1),
                        child: Text(student.name[0], style: const TextStyle(color: kPrimary, fontWeight: FontWeight.bold))),
                    title: Text(student.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                    subtitle: Text('Room ${student.roomNumber ?? 'N/A'} [${student.hostel ?? ''}]', style: const TextStyle(fontSize: 12, color: Colors.black45)),
                    trailing: IconButton(
                      icon: const Icon(Icons.call_rounded, color: kPrimary),
                      onPressed: () async {
                        final phone = (student.phoneNumber ?? '').replaceAll(RegExp(r'[^\d+]'), '');
                        final Uri telUri = Uri.parse('tel:$phone');
                        if (await canLaunchUrl(telUri)) await launchUrl(telUri, mode: LaunchMode.externalApplication);
                      },
                    ),
                  );
                },
              ),
            ),
          ],
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
