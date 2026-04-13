import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../models/vista_user.dart';
import '../../../services/firebase_service.dart';
import 'warden_components.dart';

class WardenStudentCalendar extends StatefulWidget {
  final VistaUser student;
  final FirebaseService fs;

  const WardenStudentCalendar({
    super.key,
    required this.student,
    required this.fs,
  });

  @override
  State<WardenStudentCalendar> createState() => _WardenStudentCalendarState();
}

class _WardenStudentCalendarState extends State<WardenStudentCalendar> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, String> _attendanceMap = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    try {
      final history = await widget.fs.getStudentAttendance(widget.student.uid).first;
      final leaves = await widget.fs.getStudentLeaves(widget.student.uid).first;
      final approvedLeaves = leaves.where((l) => l.status == 'Approved').toList();

      if (!mounted) return;

      final Map<DateTime, String> map = {};
      for (var a in history) {
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
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: kPrimary))
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        _buildCalendar(),
                        const SizedBox(height: 32),
                        _buildLegend(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
          ),
        ],
      ),
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
                  color: kPrimary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(Icons.history_rounded, color: kPrimary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.student.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                    const Text(
                      'Attendance & Leave History',
                      style: TextStyle(
                        color: Colors.black45,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.black45),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCalendar() {
    return TableCalendar(
      firstDay: DateTime(2025, 1, 1),
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
          color: kPrimary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        todayTextStyle: const TextStyle(
          color: kPrimary,
          fontWeight: FontWeight.bold,
        ),
        markerDecoration: const BoxDecoration(
          color: Colors.transparent,
        ),
      ),
      calendarBuilders: CalendarBuilders(
        defaultBuilder: (context, day, focusedDay) {
          final normalizedDay = DateTime(day.year, day.month, day.day);
          final status = _attendanceMap[normalizedDay];
          
          if (status != null) {
            Color color;
            switch (status) {
              case 'Present':
                color = const Color(0xFF10B981); // kStudentSuccess
                break;
              case 'Late':
                color = const Color(0xFFF59E0B); // kStudentWarning
                break;
              case 'On Leave':
                color = Colors.grey;
                break;
              default:
                color = Colors.red;
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
            final color = Colors.red;
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
      onPageChanged: (focusedDay) => setState(() => _focusedDay = focusedDay),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kPrimary.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem(const Color(0xFF10B981), 'Present'),
              _buildLegendItem(const Color(0xFFF59E0B), 'Late'),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem(Colors.grey, 'On Leave'),
              _buildLegendItem(Colors.red, 'Absent'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label, {bool isGrey = false}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
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
