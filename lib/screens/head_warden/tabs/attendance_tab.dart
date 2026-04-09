import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../models/vista_user.dart';
import '../../../models/attendance_model.dart';
import '../../../models/leave_request_model.dart';
import '../../../models/short_stay_model.dart';
import '../../../services/firebase_service.dart';
import '../../../utils/export_helper.dart';
import '../../../widgets/skeleton_loader.dart';
import '../../warden/components/warden_components.dart';

class AttendanceTab extends StatefulWidget {
  final VistaUser warden;
  final FirebaseService fs;
  const AttendanceTab({super.key, required this.warden, required this.fs});

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'All'; // 'All', 'Marked', 'Late', 'Absent'
  String _hostelFilter = 'All';

  late Stream<List<VistaUser>> _studentStream;
  late Stream<List<LeaveRequest>> _leaveStream;
  late Stream<List<Attendance>> _attendanceStream;
  late Stream<List<ShortStayRequest>> _shortStayStream;

  DateTime _selectedDate = DateTime.now();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _studentStream = widget.fs.getHostelStudents('All');
    _leaveStream = widget.fs.getApprovedLeaves('All');
    _shortStayStream = widget.fs.getApprovedShortStays('All');

    _updateAttendanceStream();

    _searchCtrl.addListener(() {
      if (mounted) {
        setState(() => _searchQuery = _searchCtrl.text);
      }
    });
  }

  void _updateAttendanceStream() {
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
    _attendanceStream = widget.fs.getHostelAttendance('All', dateStr);
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: kPrimary,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _updateAttendanceStream();
      });
    }
  }

  void _showStudentAttendanceHistory(VistaUser student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _StudentAttendanceCalendar(student: student, fs: widget.fs),
    );
  }

  void export() => _showRangeExport();

  Future<void> _showRangeExport() async {
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: _selectedDate.subtract(const Duration(days: 7)),
        end: _selectedDate,
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: kPrimary,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
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

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _statusFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? kPrimary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isSelected ? kPrimary : Colors.black.withValues(alpha: 0.1)),
          boxShadow: isSelected ? [BoxShadow(color: kPrimary.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 3))] : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black54,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  bool _isStudentOnLeave(String studentId, List<LeaveRequest> approvedLeaves, DateTime date) {
    final checkDate = DateTime(date.year, date.month, date.day);
    return approvedLeaves.any((leave) {
      if (leave.studentId != studentId) return false;
      if (leave.checkInTime != null) {
        final checkInDate = DateTime(leave.checkInTime!.year, leave.checkInTime!.month, leave.checkInTime!.day);
        if (!checkDate.isBefore(checkInDate)) return false;
      }
      final from = DateTime(leave.fromDate.year, leave.fromDate.month, leave.fromDate.day);
      final to = DateTime(leave.toDate.year, leave.toDate.month, leave.toDate.day);
      return !checkDate.isBefore(from) && !checkDate.isAfter(to);
    });
  }

  void _showDefaultersList(List<_AttendanceRecord> defaulters) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
              Expanded(
                child: defaulters.isEmpty
                    ? const Center(child: Text('All records completed.', style: TextStyle(color: Colors.black54)))
                    : ListView.builder(
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final now = DateTime.now();
    final isLateWindow = now.hour >= 22;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 46,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 10, offset: const Offset(0, 4))],
                  ),
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(fontSize: 14),
                    decoration: const InputDecoration(
                      hintText: 'Search student or room...',
                      prefixIcon: Icon(Icons.search_rounded, size: 20, color: kPrimary),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: Container(
                  height: 46,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kPrimary.withValues(alpha: 0.1)),
                    boxShadow: [BoxShadow(color: kPrimary.withValues(alpha: 0.04), blurRadius: 8, offset: const Offset(0, 3))],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.event_note_rounded, size: 18, color: kPrimary),
                      const SizedBox(width: 8),
                      Text(DateFormat('MMM d').format(_selectedDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: kPrimary)),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kPrimary.withValues(alpha: 0.1)),
                ),
                child: PopupMenuButton<String>(
                  icon: Icon(Icons.apartment_rounded, color: _hostelFilter == 'All' ? Colors.black45 : kPrimary, size: 20),
                  onSelected: (val) => setState(() => _hostelFilter = val),
                  itemBuilder: (context) => [
                    const PopupMenuItem(value: 'All', child: Text('All Hostels')),
                    const PopupMenuItem(value: 'BH1', child: Text('BH1')),
                    const PopupMenuItem(value: 'BH2', child: Text('BH2')),
                    const PopupMenuItem(value: 'GH1', child: Text('GH1')),
                    const PopupMenuItem(value: 'GH2', child: Text('GH2')),
                  ],
                ),
              ),
            ],
          ),
        ),

        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              _buildFilterChip('All'),
              const SizedBox(width: 8),
              _buildFilterChip('Marked'),
              const SizedBox(width: 8),
              _buildFilterChip('Late'),
              const SizedBox(width: 8),
              _buildFilterChip('On Leave'),
              const SizedBox(width: 8),
              _buildFilterChip('Absent'),
            ],
          ),
        ),

        Expanded(
          child: StreamBuilder<List<VistaUser>>(
            stream: _studentStream,
            builder: (context, studentSnap) {
              return StreamBuilder<List<LeaveRequest>>(
                stream: _leaveStream,
                builder: (context, leaveSnap) {
                  return StreamBuilder<List<Attendance>>(
                    stream: _attendanceStream,
                    builder: (context, attendanceSnap) {
                      return StreamBuilder<List<ShortStayRequest>>(
                        stream: _shortStayStream,
                        builder: (context, ssSnap) {
                          if (studentSnap.connectionState == ConnectionState.waiting || leaveSnap.connectionState == ConnectionState.waiting || attendanceSnap.connectionState == ConnectionState.waiting || ssSnap.connectionState == ConnectionState.waiting) {
                            return const AttendanceListSkeleton();
                          }

                          final studentsData = studentSnap.data ?? [];
                          final leaveRequests = leaveSnap.data ?? [];
                          final attendanceLists = attendanceSnap.data ?? [];
                          final approvedShortStays = ssSnap.data ?? [];

                          final students = studentsData.where((m) {
                            final now = DateTime.now();
                            final hasActiveShortStay = approvedShortStays.any((ss) => ss.studentId == m.uid && ss.status == 'Approved' && ss.actualCheckOutTime == null && !now.isBefore(ss.checkInDate) && !now.isAfter(ss.checkOutDate));
                            if ((m.isDayScholar || m.hasUsedShortStay) && !hasActiveShortStay) return false;
                            return true;
                          }).toList();

                          final approvedLeaves = leaveRequests.where((l) => l.status == 'Approved').toList();
                          final Map<String, Attendance> attendanceMap = {for (var a in attendanceLists) a.studentId: a};

                          List<_AttendanceRecord> records = students.where((s) => _hostelFilter == 'All' || s.hostel == _hostelFilter).map((s) {
                            final onLeave = _isStudentOnLeave(s.uid, approvedLeaves, _selectedDate);
                            return _AttendanceRecord(s, attendanceMap[s.uid], onLeave: onLeave);
                          }).toList();

                          final defaulters = records.where((r) => r.status == 'Absent').toList();

                          if (_statusFilter != 'All') records = records.where((r) => r.status == _statusFilter).toList();
                          if (_searchQuery.isNotEmpty) {
                            records = records.where((r) => r.student.name.toLowerCase().contains(_searchQuery.toLowerCase()) || (r.student.roomNumber ?? '').toLowerCase().contains(_searchQuery.toLowerCase())).toList();
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isLateWindow && defaulters.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.withValues(alpha: 0.1))),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                                        const SizedBox(width: 12),
                                        Expanded(child: Text('${defaulters.length} students pending attendance', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13))),
                                        TextButton(onPressed: () => _showDefaultersList(defaulters), child: const Text('View List', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, decoration: TextDecoration.underline))),
                                      ],
                                    ),
                                  ),
                                ),
                              WardenSectionLabel('Daily Attendance', count: records.length),
                              Expanded(
                                child: records.isEmpty
                                    ? WardenEmptyState(icon: Icons.search_off_rounded, title: 'No Records Found', subtitle: 'No students match your current filters.')
                                    : ListView.separated(
                                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                                        itemCount: records.length,
                                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                                        itemBuilder: (context, i) {
                                          final r = records[i];
                                          return WardenCard(
                                            onTap: () => _showStudentAttendanceHistory(r.student),
                                            child: Row(
                                              children: [
                                                _statusIndicator(r.status),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment: CrossAxisAlignment.start,
                                                    children: [
                                                      Text(r.student.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                                      Text('Room ${r.student.roomNumber ?? "N/A"} • ${r.student.hostel ?? ""}', style: const TextStyle(color: Colors.black45, fontSize: 12)),
                                                    ],
                                                  ),
                                                ),
                                                Text(r.timeText, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.black38)),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
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
}

class _AttendanceRecord {
  final VistaUser student;
  final Attendance? attendance;
  final bool onLeave;

  _AttendanceRecord(this.student, this.attendance, {this.onLeave = false});

  String get status {
    if (onLeave) return 'On Leave';
    if (attendance == null) return 'Absent';
    return attendance!.status == 'Late' ? 'Late' : 'Marked';
  }

  String get timeText {
    if (status == 'On Leave') return 'On Leave';
    if (attendance == null) return 'Not Marked';
    return DateFormat('hh:mm a').format(attendance!.timestamp);
  }
}

class _StudentAttendanceCalendar extends StatefulWidget {
  final VistaUser student;
  final FirebaseService fs;
  const _StudentAttendanceCalendar({required this.student, required this.fs});

  @override
  State<_StudentAttendanceCalendar> createState() => _StudentAttendanceCalendarState();
}

class _StudentAttendanceCalendarState extends State<_StudentAttendanceCalendar> {
  DateTime _focusedDay = DateTime.now();
  final Map<DateTime, String> _attendanceMap = {};

  @override
  void initState() {
    super.initState();
    _loadAllAttendance();
  }

  void _loadAllAttendance() async {
    final history = await widget.fs.getStudentAttendance(widget.student.uid).first;
    final leaves = await widget.fs.getStudentLeaves(widget.student.uid).first;
    final approvedLeaves = leaves.where((l) => l.status == 'Approved').toList();

    if (mounted) {
      setState(() {
        for (var a in history) {
          final d = DateTime(a.timestamp.year, a.timestamp.month, a.timestamp.day);
          _attendanceMap[d] = a.status == 'Late' ? 'Late' : 'Present';
        }
        for (var l in approvedLeaves) {
          var curr = DateTime(l.fromDate.year, l.fromDate.month, l.fromDate.day);
          final end = DateTime(l.toDate.year, l.toDate.month, l.toDate.day);
          while (!curr.isAfter(end)) {
            if (!_attendanceMap.containsKey(curr)) {
              _attendanceMap[curr] = 'On Leave';
            }
            curr = curr.add(const Duration(days: 1));
          }
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.student.name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    Text('Attendance History Log', style: TextStyle(color: kPrimary.withValues(alpha: 0.6), fontWeight: FontWeight.w600, fontSize: 13)),
                  ],
                ),
              ),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close_rounded)),
            ],
          ),
          const SizedBox(height: 24),
          TableCalendar(
            firstDay: DateTime(2025, 1, 1),
            lastDay: DateTime.now(),
            focusedDay: _focusedDay,
            calendarFormat: CalendarFormat.month,
            headerStyle: const HeaderStyle(formatButtonVisible: false, titleCentered: true, titleTextStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            calendarStyle: CalendarStyle(
              todayDecoration: BoxDecoration(color: kPrimary.withValues(alpha: 0.1), shape: BoxShape.circle),
              todayTextStyle: const TextStyle(color: kPrimary, fontWeight: FontWeight.bold),
            ),
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, date, events) {
                final d = DateTime(date.year, date.month, date.day);
                if (_attendanceMap.containsKey(d)) {
                  final status = _attendanceMap[d];
                  Color color = Colors.green;
                  if (status == 'Late') {
                    color = Colors.orange;
                  } else if (status == 'On Leave') {
                    color = Colors.blue;
                  }
                  return Positioned(
                    bottom: 1,
                    child: Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                    ),
                  );
                }
                if (d.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)) && !d.isBefore(DateTime(2025, 2, 10))) {
                  return Positioned(bottom: 1, child: Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)));
                }
                return null;
              },
            ),
            onPageChanged: (focusedDay) => setState(() => _focusedDay = focusedDay),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: kPrimary.withValues(alpha: 0.04), borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _legendItem(Colors.green, 'Present'),
                _legendItem(Colors.orange, 'Late'),
                _legendItem(Colors.blue, 'Leave'),
                _legendItem(Colors.red, 'Absent'),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Column(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black45)),
      ],
    );
  }
}
