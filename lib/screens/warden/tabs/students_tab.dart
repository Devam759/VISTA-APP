import 'package:flutter/material.dart';
import '../../../models/vista_user.dart';
import '../../../models/leave_request_model.dart';
import '../../../models/short_stay_model.dart';
import '../../../services/firebase_service.dart';
import 'package:provider/provider.dart';
import '../../../providers/warden_provider.dart';
import '../components/warden_components.dart';
import '../components/warden_tab_scaffold.dart';

class StudentsTab extends StatefulWidget {
  final VistaUser warden;
  final FirebaseService fs;
  final VoidCallback? onExport;
  const StudentsTab({super.key, required this.warden, required this.fs, this.onExport});

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> {
  bool _showRequests = false;
  String? _lastFilter;
  Stream<List<LeaveRequest>>? _leaveStream;
  Stream<List<ShortStayRequest>>? _shortStayStream;

  void _updateStreams(String? filter) {
    if (_lastFilter != filter || _leaveStream == null) {
      _lastFilter = filter;
      _leaveStream = widget.fs.getApprovedLeaves(filter);
      _shortStayStream = widget.fs.getApprovedShortStays(filter);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<WardenProvider>(
      builder: (context, wp, _) {
        _updateStreams(wp.currentHostelFilter);
        return StreamBuilder<List<LeaveRequest>>(
          stream: _leaveStream,
          builder: (context, leaveSnap) {
            return StreamBuilder<List<ShortStayRequest>>(
              stream: _shortStayStream,
              builder: (context, ssSnap) {
                final leaves = leaveSnap.data ?? [];
                final shortStays = ssSnap.data ?? [];

                return WardenTabScaffold<VistaUser>(
                  title: 'Residents',
                  sectionTitle: 'Hostel Students',
                  showCount: true,
                  searchHint: 'Search by student name, room...',
                  tabs: const ['All', 'In Campus', 'On Leave', 'Short Stay'],
                  streamFactory: () => widget.fs.getUnifiedStudentsStream(wp.currentHostelFilter),
                  emptyIcon: Icons.people_outline_rounded,
                  emptyTitle: wp.currentHostelFilter == null ? 'No Students (All)' : 'No Students in ${wp.currentHostelFilter}',
                  emptySubtitle: 'No students registered in this hostel yet.',
                  extraHeaderBuilder: (context, students) {
                    final pending = context.select<WardenProvider, List<VistaUser>>((p) => p.pendingRegistrations);
                    
                    if (pending.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    
                    return WardenRegistrationBanner(
                      pending: pending,
                      isExpanded: _showRequests,
                      onTap: () => setState(() => _showRequests = !_showRequests),
                      onApprove: (student) => WardenUIUtils.showRoomAssignmentDialog(
                        context: context,
                        student: student,
                        fs: widget.fs,
                        wardenUid: widget.warden.uid,
                      ),
                      onDeny: (student) => widget.fs.denyStudent(student.uid, actionUid: widget.warden.uid),
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
                  listBuilder: (context, filteredStudents, [startIndex = 0]) {
                    return WardenStudentTableView(
                      students: filteredStudents,
                      leaves: leaves,
                      shortStays: shortStays,
                      fs: widget.fs,
                      startIndex: startIndex,
                    );
                  },
                );
              },
            );
          },
        );
      }
    );
  }
}
