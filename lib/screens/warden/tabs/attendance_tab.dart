import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../models/vista_user.dart';
import '../../../models/attendance_model.dart';
import '../../../models/leave_request_model.dart';
import '../../../services/firebase_service.dart';
import '../../../utils/export_helper.dart';
import '../../../widgets/skeleton_loader.dart';
import '../../../providers/warden_provider.dart';
import '../components/warden_components.dart';


class AttendanceTab extends StatefulWidget {
  final VistaUser warden;
  const AttendanceTab({super.key, required this.warden});

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  String _statusFilter = 'All'; // 'All', 'Marked', 'Late', 'Absent'
  DateTime _selectedDate = DateTime.now();

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(() {
      if (mounted) {
        setState(() => _searchQuery = _searchCtrl.text);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
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
      });
    }
  }

  void _showStudentAttendanceHistory(VistaUser student) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => StudentAttendanceCalendar(student: student),
    );
  }

  // ignore: unused_element
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

      final fs = FirebaseService();
      final students = await fs.getHostelStudents(widget.warden.hostel).first;
      final attendance = await fs.getHostelAttendanceRange(
        widget.warden.hostel,
        range.start,
        range.end,
      ).first;
      final leaves = await fs.getHostelLeavesRange(widget.warden.hostel, range.start, range.end).first;

      List<DateTime> dates = [];
      for (int i = 0; i <= range.end.difference(range.start).inDays; i++) {
        dates.add(range.start.add(Duration(days: i)));
      }

      await ExportHelper.exportAttendanceSummary(
        students,
        attendance,
        leaves,
        dates,
        widget.warden.hostel ?? 'All',
      );
    }
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _statusFilter == label;
    return InkWell(
      onTap: () => setState(() => _statusFilter = label),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? kPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? kPrimary : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.black87,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
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
        final checkInDate = DateTime(
          leave.checkInTime!.year,
          leave.checkInTime!.month,
          leave.checkInTime!.day,
        );
        if (!checkDate.isBefore(checkInDate)) return false;
      }
      final from = DateTime(leave.fromDate.year, leave.fromDate.month, leave.fromDate.day);
      final to = DateTime(leave.toDate.year, leave.toDate.month, leave.toDate.day);
      return !checkDate.isBefore(from) && !checkDate.isAfter(to);
    });
  }

  void _showDefaultersList(List<AttendanceRecord> defaulters) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(
                  'Pending Attendance List',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.black87),
                ),
              ),
              const Divider(),
              Expanded(
                child: defaulters.isEmpty
                    ? const Center(
                        child: Text('All records completed.', style: TextStyle(color: Colors.black54)),
                      )
                    : ListView.builder(
                        itemCount: defaulters.length,
                        itemBuilder: (context, i) {
                          final student = defaulters[i].student;
                          return ListTile(
                            title: Text(
                              student.name,
                              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                            ),
                            subtitle: Text(
                              'Room ${student.roomNumber ?? "N/A"}',
                              style: const TextStyle(fontSize: 13, color: Colors.black54),
                            ),
                            trailing: OutlinedButton.icon(
                              icon: const Icon(Icons.call, size: 16),
                              label: const Text('Call'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: kPrimary,
                                side: const BorderSide(color: kPrimary),
                                padding: const EdgeInsets.symmetric(horizontal: 12),
                                minimumSize: const Size(0, 32),
                              ),
                              onPressed: () async {
                                final phoneStr = student.phoneNumber ?? '';
                                final phone = phoneStr.replaceAll(RegExp(r'[^\d+]'), '');
                                final Uri telUri = Uri.parse('tel:$phone');
                                if (await canLaunchUrl(telUri)) {
                                  await launchUrl(telUri, mode: LaunchMode.externalApplication);
                                }
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
    final wardenProv = Provider.of<WardenProvider>(context);
    final now = DateTime.now();
    final isLateWindow = now.hour >= 22;

    if (wardenProv.isLoading && wardenProv.students.isEmpty) {
      return const AttendanceListSkeleton();
    }

    // Determine target attendance list (selected date)
    final dateStr = DateFormat('yyyy-M-d').format(_selectedDate);
    // Since WardenProvider maintains current date attendance, we might need a separate stream for historical
    // But for the "real-time" aspect, we care about TODAY.

    return StreamBuilder<List<Attendance>>(
      stream: FirebaseService().getHostelAttendance(widget.warden.hostel!, dateStr),
      builder: (context, attendanceSnap) {
        final attendanceLists = attendanceSnap.data ?? [];
        final Map<String, Attendance> attendanceMap = {
          for (var a in attendanceLists) a.studentId: a,
        };

        final studentsData = wardenProv.students;
        final leaveRequests = wardenProv.leaves;
        final approvedShortStays = wardenProv.shortStays;

        final students = studentsData.where((m) {
          final hasActiveShortStay = approvedShortStays.any(
            (ss) =>
                ss.studentId == m.uid &&
                ss.status == 'Approved' &&
                ss.actualCheckOutTime == null &&
                !_selectedDate.isBefore(ss.checkInDate) &&
                !_selectedDate.isAfter(ss.checkOutDate),
          );
          if ((m.isDayScholar || m.hasUsedShortStay) && !hasActiveShortStay) {
            return false;
          }
          return true;
        }).toList();

        final approvedLeaves = leaveRequests.where((l) => l.status == 'Approved').toList();

        List<AttendanceRecord> records = students.map((s) {
          final onLeave = _isStudentOnLeave(s.uid, approvedLeaves, _selectedDate);
          return AttendanceRecord(s, attendanceMap[s.uid], onLeave: onLeave);
        }).toList();

        final defaulters = records.where((r) => r.status == 'Absent').toList();

        if (_statusFilter != 'All') {
          records = records.where((r) => r.status == _statusFilter).toList();
        }

        if (_searchQuery.isNotEmpty) {
          records = records.where((r) =>
              r.student.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
              (r.student.roomNumber ?? '').toLowerCase().contains(_searchQuery.toLowerCase())).toList();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Search by name, room...',
                        prefixIcon: const Icon(Icons.search, size: 20, color: Colors.black45),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                        isDense: true,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Colors.grey.shade300),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(color: kPrimary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => _selectDate(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_month, size: 18, color: kPrimary),
                          const SizedBox(width: 6),
                          Text(
                            DateFormat('MMM d').format(_selectedDate),
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kPrimary),
                          ),
                        ],
                      ),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isLateWindow && defaulters.isNotEmpty && isSameDay(_selectedDate, DateTime.now()))
                    Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        border: Border.all(color: Colors.red.shade200),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber, color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              '${defaulters.length} pending attendance',
                              style: TextStyle(color: Colors.red.shade700, fontWeight: FontWeight.w500, fontSize: 13),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _showDefaultersList(defaulters),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text('View List', style: TextStyle(fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    child: Text(
                      "DAILY LOG (${records.length})",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        letterSpacing: 0.8,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  Expanded(
                    child: records.isEmpty
                        ? Center(
                            child: Text('No records found.', style: TextStyle(color: Colors.grey.shade500, fontSize: 14)),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                            itemCount: records.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 8),
                            itemBuilder: (context, i) {
                              final r = records[i];
                              final isAbsent = r.status == 'Absent';
                              final isLate = r.status == 'Late';
                              final isOnLeave = r.status == 'On Leave';

                              Color statusColor = Colors.green.shade600;
                              if (isAbsent) {
                                statusColor = Colors.red.shade600;
                              } else if (isLate) {
                                statusColor = Colors.orange.shade700;
                              } else if (isOnLeave) {
                                statusColor = Colors.blue.shade600;
                              }

                              return InkWell(
                                onTap: () => _showStudentAttendanceHistory(r.student),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: Colors.grey.shade200),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              r.student.name,
                                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Colors.black87),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Room ${r.student.roomNumber ?? "N/A"}',
                                              style: const TextStyle(color: Colors.black54, fontSize: 12),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            r.status.toUpperCase(),
                                            style: TextStyle(
                                              color: statusColor,
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                          if (r.attendance != null) ...[
                                            const SizedBox(height: 4),
                                            Text(
                                              DateFormat('HH:mm').format(r.attendance!.timestamp),
                                              style: const TextStyle(color: Colors.black45, fontSize: 12),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class AttendanceRecord {
  final VistaUser student;
  final Attendance? attendance;
  final String status;

  AttendanceRecord(this.student, this.attendance, {bool onLeave = false})
      : status = attendance != null
            ? ((attendance.timestamp.hour == 22 && attendance.timestamp.minute >= 30) || attendance.timestamp.hour == 23
                ? 'Late'
                : 'Marked')
            : (onLeave ? 'On Leave' : 'Absent');
}

class StudentAttendanceCalendar extends StatefulWidget {
  final VistaUser student;
  const StudentAttendanceCalendar({super.key, required this.student});

  @override
  State<StudentAttendanceCalendar> createState() => _StudentAttendanceCalendarState();
}

class _StudentAttendanceCalendarState extends State<StudentAttendanceCalendar> {
  CalendarFormat _format = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final fs = FirebaseService();
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: kPrimary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                const Icon(Icons.history, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${widget.student.name}\'s Attendance',
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Room ${widget.student.roomNumber ?? "N/A"}',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<Attendance>>(
              stream: fs.getStudentAttendance(widget.student.uid),
              builder: (context, attendanceSnap) {
                return StreamBuilder<List<LeaveRequest>>(
                  stream: fs.getStudentLeaves(widget.student.uid),
                  builder: (context, leaveSnap) {
                    if (attendanceSnap.connectionState == ConnectionState.waiting || leaveSnap.connectionState == ConnectionState.waiting) {
                      return const AttendanceListSkeleton();
                    }

                    final attendanceList = attendanceSnap.data ?? [];
                    final leaves = leaveSnap.data ?? [];

                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          TableCalendar(
                            focusedDay: _focusedDay,
                            firstDay: DateTime(2025, 1, 1),
                            lastDay: DateTime.now(),
                            calendarFormat: _format,
                            selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                            onDaySelected: (selectedDay, focusedDay) {
                              setState(() {
                                _selectedDay = selectedDay;
                                _focusedDay = focusedDay;
                              });
                            },
                            onFormatChanged: (format) {
                              setState(() => _format = format);
                            },
                            calendarStyle: CalendarStyle(
                              todayDecoration: BoxDecoration(
                                color: Colors.transparent,
                                border: Border.all(color: kPrimary, width: 1.5),
                                shape: BoxShape.circle,
                              ),
                              todayTextStyle: const TextStyle(color: kPrimary, fontWeight: FontWeight.bold),
                              selectedDecoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
                            ),
                            headerStyle: const HeaderStyle(
                              formatButtonVisible: true,
                              titleCentered: true,
                              formatButtonShowsNext: false,
                            ),
                            calendarBuilders: CalendarBuilders(
                              defaultBuilder: (context, day, focusedDay) {
                                final status = _getDayStatus(day, attendanceList, leaves);
                                if (status == null) return null;
                                return _buildCalendarDay(day, status);
                              },
                              outsideBuilder: (context, day, focusedDay) {
                                final status = _getDayStatus(day, attendanceList, leaves);
                                if (status == null) return null;
                                return Opacity(opacity: 0.5, child: _buildCalendarDay(day, status));
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildLegend(),
                          const SizedBox(height: 24),
                          if (_selectedDay != null) _buildSelectedDayDetails(attendanceList, leaves),
                          const SizedBox(height: 24),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDayDetails(List<Attendance> attendance, List<LeaveRequest> leaves) {
    final status = _getDayStatus(_selectedDay!, attendance, leaves);
    if (status == null) return const SizedBox.shrink();

    final att = attendance.where((a) => isSameDay(a.timestamp, _selectedDay)).firstOrNull;

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'Present':
      case 'Marked':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'Late':
        statusColor = Colors.yellow.shade700;
        statusIcon = Icons.access_time_filled;
        break;
      case 'Absent':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      case 'On Leave':
        statusColor = Colors.grey;
        statusIcon = Icons.beach_access;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: statusColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('MMMM d, y').format(_selectedDay!),
                  style: const TextStyle(fontSize: 12, color: Colors.black54, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: TextStyle(color: statusColor, fontSize: 15, fontWeight: FontWeight.bold),
                ),
                if (att != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Time: ${DateFormat("hh:mm a").format(att.timestamp)}',
                    style: const TextStyle(fontSize: 13, color: Colors.black38),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String? _getDayStatus(DateTime day, List<Attendance> attendance, List<LeaveRequest> leaves) {
    if (day.isAfter(DateTime.now())) return null;
    final att = attendance.where((a) => isSameDay(a.timestamp, day)).firstOrNull;
    if (att != null) return (att.status == 'Marked') ? 'Present' : att.status;
    final onLeave = leaves.any((l) =>
        l.status == 'Approved' &&
        !day.isBefore(DateTime(l.fromDate.year, l.fromDate.month, l.fromDate.day)) &&
        !day.isAfter(DateTime(l.toDate.year, l.toDate.month, l.toDate.day)));
    if (onLeave) return 'On Leave';
    if (day.isBefore(DateTime.now())) {
      if (isSameDay(day, DateTime.now())) return null;
      return 'Absent';
    }
    return null;
  }

  Widget _buildCalendarDay(DateTime day, String status) {
    Color color;
    switch (status) {
      case 'Present':
      case 'Marked':
        color = Colors.green;
        break;
      case 'Late':
        color = Colors.yellow.shade700;
        break;
      case 'Absent':
        color = Colors.red;
        break;
      case 'On Leave':
        color = Colors.grey;
        break;
      default:
        color = Colors.transparent;
    }
    return Container(
      margin: const EdgeInsets.all(4),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: color == Colors.yellow.shade700 ? Colors.brown : color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _legendItem('Present', Colors.green),
              _legendItem('Late', Colors.yellow.shade700),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _legendItem('Absent', Colors.red),
              _legendItem('On Leave', Colors.grey),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }
}

// ignore: unused_element
extension _ListExt<T> on List<T> {
  // ignore: unused_element
  T? firstWhereOrNull(bool Function(T) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
