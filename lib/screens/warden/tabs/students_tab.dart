import 'package:flutter/material.dart';
import '../../../models/vista_user.dart';
import '../../../models/leave_request_model.dart';
import '../../../models/short_stay_model.dart';
import '../../../services/firebase_service.dart';
import '../components/warden_components.dart';
import '../components/warden_tab_scaffold.dart';

class StudentsTab extends StatefulWidget {
  final VistaUser warden;
  final FirebaseService fs;
  const StudentsTab({super.key, required this.warden, required this.fs});

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  bool _showRequests = false;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LeaveRequest>>(
      stream: widget.fs.getApprovedLeaves(widget.warden.hostel ?? 'All'),
      builder: (context, leaveSnap) {
        return StreamBuilder<List<ShortStayRequest>>(
          stream: widget.fs.getApprovedShortStays(widget.warden.hostel ?? 'All'),
          builder: (context, ssSnap) {
            final leaves = leaveSnap.data ?? [];
            final shortStays = ssSnap.data ?? [];

            return WardenTabScaffold<VistaUser>(
              sectionTitle: 'Hostel Students',
              searchHint: 'Search by student name, room...',
              tabs: const ['All', 'In Campus', 'On Leave', 'Short Stay'],
              streamFactory: () => widget.fs.getUnifiedStudentsStream(widget.warden.hostel),
              emptyIcon: Icons.people_outline_rounded,
              emptyTitle: 'No Students Found',
              emptySubtitle: 'No students registered in this hostel yet.',
              extraHeaderBuilder: (students) {
                return StreamBuilder<List<VistaUser>>(
                  stream: widget.fs.getPendingRegistrationsStream(widget.warden.hostel),
                  builder: (context, pendingSnap) {
                    final pending = pendingSnap.data ?? [];
                    if (pending.isEmpty) return const SizedBox.shrink();
                    return WardenRegistrationBanner(
                      pending: pending,
                      isExpanded: _showRequests,
                      onTap: () => setState(() => _showRequests = !_showRequests),
                      onDeny: (s) => widget.fs.denyStudent(s.uid),
                      onApprove: (s) => WardenUIUtils.showRoomAssignmentDialog(
                        context: context,
                        student: s,
                        fs: widget.fs,
                      ),
                    );
                  },
                );
              },
              filterLogic: (student, tab, query) {
                final matchesSearch = student.name.toLowerCase().contains(query.toLowerCase()) ||
                    (student.roomNumber ?? '').toLowerCase().contains(query.toLowerCase());
                if (!matchesSearch) return false;

                final now = DateTime.now();
                final hasActiveShortStay = shortStays.any((ss) =>
                    ss.studentId == student.uid &&
                    ss.status == 'Approved' &&
                    ss.actualCheckOutTime == null &&
                    !now.isBefore(ss.checkInDate) &&
                    !now.isAfter(ss.checkOutDate));
                if ((student.isDayScholar || student.hasUsedShortStay) && !hasActiveShortStay) return false;

                final onLeave = FirebaseService.isStudentOnLeave(student.uid, leaves);
                final onShortStay = FirebaseService.isStudentOnShortStay(student.uid, shortStays);

                if (tab == 'On Leave') return onLeave;
                if (tab == 'Short Stay') return onShortStay;
                if (tab == 'In Campus') return !onLeave && !onShortStay;
                return true;
              },
              itemBuilder: (context, student) {
                final onLeave = FirebaseService.isStudentOnLeave(student.uid, leaves);
                final onShortStay = FirebaseService.isStudentOnShortStay(student.uid, shortStays);
                return WardenStudentListItem(
                  student: student,
                  onLeave: onLeave,
                  onShortStay: onShortStay,
                  onTap: () => showWardenStudentDetails(context: context, student: student, fs: widget.fs),
                );
              },
            );
          },
        );
      },
    );
  }
}
