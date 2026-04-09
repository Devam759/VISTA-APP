import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/vista_user.dart';
import '../../../models/leave_request_model.dart';
import '../../../models/short_stay_model.dart';
import '../../../services/firebase_service.dart';
import '../../../utils/sanitizer.dart';
import '../../../utils/export_helper.dart';
import '../../../widgets/skeleton_loader.dart';
import '../../../providers/warden_provider.dart';
import '../components/warden_components.dart';
import '../../../widgets/vista_loader.dart';
import '../../student/widgets/attendance_calendar.dart';

class StudentsTab extends StatefulWidget {
  final VistaUser warden;
  const StudentsTab({super.key, required this.warden});

  @override
  State<StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<StudentsTab> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _showRequests = false;
  String _searchQuery = '';
  String _statusFilter = 'All'; // 'All', 'In Campus', 'On Leave', 'Short Stay'

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

  Future<void> export() async {
    final fs = FirebaseService();
    final students = await fs.getHostelStudents(widget.warden.hostel!).first;
    await ExportHelper.exportStudents(students, widget.warden.hostel ?? 'All');
  }

  void _showStudentDetails(BuildContext context, VistaUser s) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75, // Slightly increased height
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: kPrimary.withValues(alpha: 0.1),
                  child: Text(
                    s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
                    style: const TextStyle(
                      color: kPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        s.email,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const Divider(height: 32),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _detailItem(
                      Icons.badge_outlined,
                      'Roll Number',
                      s.rollNo ?? 'Not Set',
                    ),
                    _detailItem(
                      Icons.app_registration_sharp,
                      'Registration Number',
                      s.registrationNo ?? 'Not Set',
                    ),
                    _detailItem(
                      Icons.phone_outlined,
                      'Student Phone',
                      s.phoneNumber ?? 'Not Set',
                    ),
                    _detailItem(
                      Icons.school_outlined,
                      'Programme',
                      s.programme ?? 'Not Set',
                    ),
                    const Divider(height: 32, thickness: 0.5),
                    const Text(
                      'Parent/Guardian Details',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: kPrimary,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _detailItem(
                      Icons.family_restroom_outlined,
                      'Parent Name',
                      s.parentName ?? 'Not Provided',
                    ),
                    _detailItem(
                      Icons.contact_phone_outlined,
                      'Parent Contact',
                      s.parentContact ?? 'Not Provided',
                    ),
                    const SizedBox(height: 24),
                    const Divider(height: 32, thickness: 0.5),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (context) => StudentAttendanceCalendar(
                              student: s,
                              fs: FirebaseService(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.calendar_month_outlined),
                        label: const Text('View Attendance History'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.black45),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 12, color: Colors.black38),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _approveDialog(BuildContext context, VistaUser s) {
    final ctrl = TextEditingController();
    bool isSubmitting = false;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Assign Room Number',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              const SizedBox(height: 4),
              Text(
                'Student: ${s.name}',
                style: const TextStyle(
                  fontSize: 13,
                  color: Colors.black45,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ],
          ),
          content: TextField(
            controller: ctrl,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText: 'Room Number',
              hintText: 'e.g. 101 or 104-D',
              prefixIcon: const Icon(
                Icons.meeting_room_outlined,
                color: kPrimary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kPrimary, width: 2),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() => isSubmitting = true);
                      try {
                        String sanitizedRoom = InputSanitizer.sanitize(
                          ctrl.text,
                        );
                        final fs = FirebaseService();
                        await fs.approveStudent(s.uid, sanitizedRoom);
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text('Error: $e')));
                        }
                      } finally {
                        if (context.mounted) {
                          setDialogState(() => isSubmitting = false);
                        }
                      }
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: VISTALoader(
                        color: Colors.white,
                        size: 20,
                      ),
                    )
                  : const Text(
                      'Approve',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _statusFilter == label;
    return GestureDetector(
      onTap: () => setState(() => _statusFilter = label),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? kPrimary : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected
                ? kPrimary
                : Colors.black.withValues(alpha: 0.08),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: kPrimary.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
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

  bool _isStudentOnLeave(String uid, List<LeaveRequest> approvedLeaves) {
    final now = DateTime.now();
    return approvedLeaves.any((l) {
      if (l.studentId != uid) return false;
      if (l.checkInTime != null && !now.isBefore(l.checkInTime!)) {
        return false;
      }
      return l.fromDate.isBefore(now) && l.toDate.isAfter(now);
    });
  }

  bool _isStudentOnShortStay(
    String uid,
    List<ShortStayRequest> approvedShortStays,
  ) {
    final now = DateTime.now();
    return approvedShortStays.any(
      (ss) =>
          ss.studentId == uid &&
          ss.status == 'Approved' &&
          ss.checkInDate.isBefore(now) &&
          ss.checkOutDate.isAfter(now),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final wardenProv = Provider.of<WardenProvider>(context);

    // Filter logic
    final pending = wardenProv.pendingRegistrations;
    final allMembers = wardenProv.students;
    final approvedLeaves = wardenProv.leaves;
    final approvedShortStays = wardenProv.shortStays;

    if (wardenProv.isLoading && allMembers.isEmpty) {
      return const StudentListSkeleton();
    }

    var filtered = allMembers.where((m) {
      final now = DateTime.now();
      final hasActiveShortStay = approvedShortStays.any(
        (ss) =>
            ss.studentId == m.uid &&
            ss.status == 'Approved' &&
            ss.actualCheckOutTime == null &&
            !now.isBefore(ss.checkInDate) &&
            !now.isAfter(ss.checkOutDate),
      );
      if ((m.isDayScholar || m.hasUsedShortStay) && !hasActiveShortStay) {
        return false;
      }

      final matchesSearch = m.name.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          (m.roomNumber ?? '').toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );
      bool matchesFilter = true;
      if (_statusFilter == 'On Leave') {
        matchesFilter = _isStudentOnLeave(m.uid, approvedLeaves);
      } else if (_statusFilter == 'Short Stay') {
        matchesFilter = _isStudentOnShortStay(m.uid, approvedShortStays);
      } else if (_statusFilter == 'In Campus') {
        matchesFilter = !_isStudentOnLeave(m.uid, approvedLeaves) &&
            !_isStudentOnShortStay(m.uid, approvedShortStays);
      }
      return matchesSearch && matchesFilter;
    }).toList();

    String emptyTitle = 'No Students Registered';
    String emptySubtitle = 'Approve registration requests from the banner above to add students.';
    IconData emptyIcon = Icons.people_outline;

    if (_searchQuery.isNotEmpty) {
      emptyTitle = 'No Results Found';
      emptySubtitle = 'We couldn\'t find any student matching "$_searchQuery".';
      emptyIcon = Icons.search_off_rounded;
    } else {
      switch (_statusFilter) {
        case 'In Campus':
          emptyTitle = 'Quiet Corridor';
          emptySubtitle = 'All our students seem to be away or on leave right now.';
          emptyIcon = Icons.nightlife_rounded;
          break;
        case 'On Leave':
          emptyTitle = 'All Students Present';
          emptySubtitle = 'It looks like everyone is currently on campus. No active leaves!';
          emptyIcon = Icons.home_rounded;
          break;
        case 'Short Stay':
          emptyTitle = 'No Active Short Stays';
          emptySubtitle = 'There are no visiting day scholars at the moment.';
          emptyIcon = Icons.timer_off_rounded;
          break;
      }
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            children: [
              Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchCtrl,
                  style: const TextStyle(fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Search by student name, room...',
                    hintStyle: TextStyle(color: Colors.black26, fontSize: 14),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: kPrimary,
                      size: 22,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All'),
                    const SizedBox(width: 8),
                    _buildFilterChip('In Campus'),
                    const SizedBox(width: 8),
                    _buildFilterChip('On Leave'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Short Stay'),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (pending.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Column(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _showRequests = !_showRequests),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: kPrimary,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: kPrimary.withValues(alpha: 0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.notifications_active_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${pending.length} Registration Request${pending.length > 1 ? "s" : ""}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      _showRequests ? 'Tap to hide detail' : 'Tap to review and approve',
                                      style: TextStyle(
                                        color: Colors.white.withValues(alpha: 0.7),
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Icon(
                                _showRequests ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                color: Colors.white70,
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_showRequests)
                        Container(
                          margin: const EdgeInsets.only(top: 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: kPrimary.withValues(alpha: 0.1)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: pending.map((s) {
                              return Column(
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 20,
                                          backgroundColor: kPrimary.withValues(alpha: 0.1),
                                          child: Text(
                                            s.name.isNotEmpty ? s.name[0].toUpperCase() : 'S',
                                            style: const TextStyle(
                                              color: kPrimary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                s.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 14,
                                                ),
                                              ),
                                              Text(
                                                s.email,
                                                style: const TextStyle(
                                                  color: Colors.black45,
                                                  fontSize: 11,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            GestureDetector(
                                              onTap: () async {
                                                final fs = FirebaseService();
                                                await fs.denyStudent(s.uid);
                                              },
                                              child: Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: Colors.red.withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: Colors.red.withValues(alpha: 0.15)),
                                                ),
                                                child: const Icon(Icons.close_rounded, color: Colors.red, size: 18),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            GestureDetector(
                                              onTap: () => _approveDialog(context, s),
                                              child: Container(
                                                padding: const EdgeInsets.all(10),
                                                decoration: BoxDecoration(
                                                  color: Colors.green.withValues(alpha: 0.08),
                                                  borderRadius: BorderRadius.circular(12),
                                                  border: Border.all(color: Colors.green.withValues(alpha: 0.15)),
                                                ),
                                                child: const Icon(Icons.check_rounded, color: Colors.green, size: 18),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (s != pending.last)
                                    const Divider(height: 1, indent: 14, endIndent: 14),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                    ],
                  ),
                ),
              WardenSectionLabel('Hostel Students', count: filtered.length),
              if (filtered.isEmpty)
                Expanded(
                  child: WardenEmptyState(
                    icon: emptyIcon,
                    title: emptyTitle,
                    subtitle: emptySubtitle,
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    itemCount: filtered.length,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemBuilder: (context, i) {
                      final m = filtered[i];
                      final onLeave = _isStudentOnLeave(m.uid, approvedLeaves);
                      final onShortStay = _isStudentOnShortStay(m.uid, approvedShortStays);
                      return WardenCard(
                        onTap: () => _showStudentDetails(context, m),
                        child: Row(
                          children: [
                            Stack(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: kPrimary.withValues(alpha: 0.1),
                                  child: Text(
                                    m.name.isNotEmpty ? m.name[0].toUpperCase() : 'S',
                                    style: const TextStyle(
                                      color: kPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                    ),
                                  ),
                                ),
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    width: 14,
                                    height: 14,
                                    decoration: BoxDecoration(
                                      color: onLeave ? Colors.orange : (onShortStay ? Colors.blue : Colors.green),
                                      shape: BoxShape.circle,
                                      border: Border.all(color: Colors.white, width: 2),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: Color(0xFF1E293B),
                                    ),
                                  ),
                                  Text(
                                    m.rollNo != null && m.rollNo!.isNotEmpty
                                        ? 'Roll: ${m.rollNo}'
                                        : 'Reg: ${m.registrationNo ?? "N/A"}',
                                    style: const TextStyle(
                                      color: kPrimary,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 10,
                                    ),
                                  ),
                                  Text(
                                    m.email,
                                    style: const TextStyle(color: Colors.black45, fontSize: 11),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.phone_outlined, size: 11, color: Colors.black38),
                                      const SizedBox(width: 4),
                                      Text(
                                        m.phoneNumber ?? 'No Phone',
                                        style: const TextStyle(color: Colors.black38, fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                if (m.roomNumber != null && m.roomNumber!.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: kPrimary.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.meeting_room_outlined, size: 13, color: kPrimary),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Room ${m.roomNumber}',
                                          style: const TextStyle(
                                            color: kPrimary,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                const SizedBox(height: 6),
                                Text(
                                  onLeave ? 'ON LEAVE' : (onShortStay ? 'SHORT STAY' : 'IN CAMPUS'),
                                  style: TextStyle(
                                    color: onLeave ? Colors.orange : (onShortStay ? Colors.blue : Colors.green),
                                    fontWeight: FontWeight.w800,
                                    fontSize: 10,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
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
  }
}
