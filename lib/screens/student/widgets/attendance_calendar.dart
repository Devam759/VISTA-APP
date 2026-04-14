import 'package:flutter/material.dart';
import 'dart:async';

import 'package:table_calendar/table_calendar.dart';
import '../../../models/vista_user.dart';
import '../../../services/firebase_service.dart';
import '../widgets/student_components.dart';

import '../../../widgets/skeleton_loader.dart';

class StudentAttendanceCalendar extends StatefulWidget {
  final VistaUser student;
  final FirebaseService fs;

  const StudentAttendanceCalendar({
    super.key,
    required this.student,
    required this.fs,
  });

  @override
  State<StudentAttendanceCalendar> createState() => _StudentAttendanceCalendarState();
}

class _StudentAttendanceCalendarState extends State<StudentAttendanceCalendar> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, String> _attendanceMap = {};
  Set<DateTime> _shortStayDays = {};
  bool _isLoading = true;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _loadAttendance();
  }

  void _loadAttendance() async {
    try {
      final attendanceList = await widget.fs.getStudentAttendance(widget.student.uid).first;
      final leaves = await widget.fs.getStudentLeaves(widget.student.uid).first;
      final approvedLeaves = leaves.where((l) => l.status == 'Approved').toList();
      
      // Fetch Short Stays for Day Scholars
      Set<DateTime> ssDays = {};
      if (widget.student.isDayScholar) {
        final shortStays = await widget.fs.getStudentShortStays(widget.student.uid).first;
        final activeShortStays = shortStays.where((s) => s.status == 'Approved' || s.status == 'Completed').toList();
        for (var s in activeShortStays) {
          var curr = DateTime(s.checkInDate.year, s.checkInDate.month, s.checkInDate.day);
          final end = DateTime(s.checkOutDate.year, s.checkOutDate.month, s.checkOutDate.day);
          while (!curr.isAfter(end)) {
            ssDays.add(curr);
            curr = curr.add(const Duration(days: 1));
          }
        }
      }

      final Map<DateTime, String> map = {};
      for (var a in attendanceList) {
        final d = DateTime(a.timestamp.year, a.timestamp.month, a.timestamp.day);
        map[d] = a.status;
      }

      for (var l in approvedLeaves) {
        var curr = DateTime(l.fromDate.year, l.fromDate.month, l.fromDate.day);
        final end = DateTime(l.toDate.year, l.toDate.month, l.toDate.day);
        while (!curr.isAfter(end)) {
          if (!map.containsKey(curr)) {
            map[curr] = 'On Leave';
          }
          curr = curr.add(const Duration(days: 1));
        }
      }

      if (mounted) {
        setState(() {
          _attendanceMap = map;
          _shortStayDays = ssDays;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: constraints.maxHeight * 0.9,
          ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const AttendanceListSkeleton()
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        _buildCalendar(),
                        const SizedBox(height: 32),
                        _buildLegend(),
                      ],
                    ),
                  ),
          ),
        ],
          ),
        ),
      );
    },
  );
}

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: kStudentPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.history_rounded, color: kStudentPrimary),
              ),
              const SizedBox(width: 16),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attendance History',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                  Text(
                    'Your daily reporting record',
                    style: TextStyle(
                      color: Colors.black45,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return TableCalendar(
      firstDay: DateTime.now().subtract(const Duration(days: 365)),
      lastDay: DateTime.now(),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      onDaySelected: (selectedDay, focusedDay) {
        setState(() {
          _selectedDay = selectedDay;
          _focusedDay = focusedDay;
        });
      },
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(
          color: kStudentPrimary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        todayTextStyle: const TextStyle(
          color: kStudentPrimary,
          fontWeight: FontWeight.bold,
        ),
        markerDecoration: const BoxDecoration(
          color: Colors.transparent,
        ),
      ),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) {
          final normalizedDay = DateTime(day.year, day.month, day.day);
          
          // Day Scholar Logic: If no short stay, show grey
          if (widget.student.isDayScholar && !_shortStayDays.contains(normalizedDay)) {
            // Only apply to past/today days (don't grey out future in a weird way, or actually future is grey by default)
            if (normalizedDay.isAfter(DateTime.now())) return null;
            
            return Container(
              margin: const EdgeInsets.all(6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${day.day}',
                style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
              ),
            );
          }

          final status = _attendanceMap[normalizedDay];
          if (status != null) {
            Color color;
            switch (status) {
              case 'Present':
                color = kStudentSuccess;
                break;
              case 'Late':
                color = kStudentWarning;
                break;
              case 'On Leave':
                color = Colors.grey;
                break;
              default:
                color = kStudentDanger;
            }
            return Container(
              margin: const EdgeInsets.all(6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
              ),
              child: Text(
                '${day.day}',
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            );
          }

          // Absent logic (before today and after start of sem)
          if (normalizedDay.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)) && 
              normalizedDay.isAfter(DateTime(2025, 2, 10))) {
            final color = kStudentDanger;
            return Container(
              margin: const EdgeInsets.all(6),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${day.day}',
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            );
          }
          return null;
        },
      ),
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kStudentPrimary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildLegendItem(kStudentSuccess, 'Present'),
          _buildLegendItem(kStudentWarning, 'Late'),
          _buildLegendItem(kStudentDanger, 'Absent'),
          _buildLegendItem(Colors.grey, widget.student.isDayScholar ? 'Not on short stay' : 'On Leave'),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, {bool isGrey = false}) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(
            color: isGrey ? Colors.black38 : Colors.black87,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
