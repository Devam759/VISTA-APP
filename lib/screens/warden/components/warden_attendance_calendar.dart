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
  final Map<DateTime, String> _attendanceMap = {};
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

      setState(() {
        for (var a in history) {
          final d = DateTime(a.timestamp.year, a.timestamp.month, a.timestamp.day);
          // Warden view specific: we want to know if it was late or just present
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
        _isLoading = false;
      });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildHeader(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: kPrimary))
                : SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
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

  Widget _buildHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.black12,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: kPrimary.withValues(alpha: 0.1),
            child: const Icon(Icons.history_rounded, color: kPrimary, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.student.name,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                ),
                Text(
                  'Attendance & Leave History',
                  style: TextStyle(color: Colors.black.withValues(alpha: 0.4), fontSize: 12, fontWeight: FontWeight.w600),
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
    );
  }

  Widget _buildCalendar() {
    return TableCalendar(
      firstDay: DateTime(2025, 1, 1),
      lastDay: DateTime.now(),
      focusedDay: _focusedDay,
      calendarFormat: CalendarFormat.month,
      headerStyle: const HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
      ),
      calendarStyle: CalendarStyle(
        todayDecoration: BoxDecoration(
          color: kPrimary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        todayTextStyle: const TextStyle(color: kPrimary, fontWeight: FontWeight.bold),
      ),
      calendarBuilders: CalendarBuilders(
        markerBuilder: (context, date, events) {
          final d = DateTime(date.year, date.month, date.day);
          if (_attendanceMap.containsKey(d)) {
            final status = _attendanceMap[d];
            Color color = status == 'Late' ? Colors.orange : (status == 'On Leave' ? Colors.blue : Colors.green);
            return Positioned(
              bottom: 4,
              child: Container(
                width: 5,
                height: 5,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            );
          }
          // Absent logic (before today and after start of semester)
          if (d.isBefore(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)) && 
              d.isAfter(DateTime(2025, 2, 10)) && d.weekday != DateTime.sunday) {
            return Positioned(
              bottom: 4,
              child: Container(
                width: 5,
                height: 5,
                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              ),
            );
          }
          return null;
        },
      ),
      onPageChanged: (focusedDay) => setState(() => _focusedDay = focusedDay),
    );
  }

  Widget _buildLegend() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kPrimary.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kPrimary.withValues(alpha: 0.05)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem(Colors.green, 'Present'),
              _buildLegendItem(Colors.orange, 'Late'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildLegendItem(Colors.blue, 'On Leave'),
              _buildLegendItem(Colors.red, 'Absent'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return SizedBox(
      width: 80,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.black54)),
        ],
      ),
    );
  }
}
