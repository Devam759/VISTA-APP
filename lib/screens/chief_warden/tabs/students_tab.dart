import 'package:flutter/material.dart';
import '../../../models/vista_user.dart';
import '../../../models/leave_request_model.dart';
import '../../../models/short_stay_model.dart';
import '../../../services/firebase_service.dart';
import '../../warden/components/warden_components.dart';
import '../../warden/components/warden_tab_scaffold.dart';

class StudentsTab extends StatefulWidget {
  final VistaUser warden;
  final FirebaseService fs;
  const StudentsTab({super.key, required this.warden, required this.fs});

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> with SingleTickerProviderStateMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  late TabController _tabController;
  bool _showRequests = false;
  String _hostelFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<LeaveRequest>>(
      stream: widget.fs.getApprovedLeaves('All'),
      builder: (context, leaveSnap) {
        return StreamBuilder<List<ShortStayRequest>>(
          stream: widget.fs.getApprovedShortStays('All'),
          builder: (context, ssSnap) {
            final leaves = leaveSnap.data ?? [];
            final shortStays = ssSnap.data ?? [];

            return StreamBuilder<List<VistaUser>>(
              stream: widget.fs.getUnifiedStudentsStream('All'),
              builder: (context, studentSnap) {

                return WardenTabScaffold<VistaUser>(
                  title: 'Residents',
                  sectionTitle: 'Hostel Students',
                  showCount: true,
                  searchHint: 'Search by student name, room...',
                  searchCtrl: _searchCtrl,
                  tabController: _tabController,
                  tabs: const ['All', 'In Campus', 'On Leave', 'Short Stay'],
                  actionWidget: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
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
                    ],
                  ),
                  streamFactory: () => widget.fs.getUnifiedStudentsStream('All'),
                  emptyIcon: Icons.people_outline_rounded,
                  emptyTitle: 'No Students Found',
                  emptySubtitle: 'No students registered in the university yet.',
                  extraHeaderBuilder: (_) {
                    return StreamBuilder<List<VistaUser>>(
                      stream: widget.fs.getPendingRegistrationsStream('All'),
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

                    final matchesHostel = _hostelFilter == 'All' || student.hostel == _hostelFilter;
                    if (!matchesHostel) return false;

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
                      showRoom: true, // Chief Warden sees room info
                      onTap: () => showWardenStudentDetails(context: context, student: student, fs: widget.fs),
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}
