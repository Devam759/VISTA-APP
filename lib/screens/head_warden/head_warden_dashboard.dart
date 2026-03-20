import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../utils/sanitizer.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers/auth_provider.dart';
import '../../models/vista_user.dart';
import '../../models/attendance_model.dart';
import '../../models/leave_request_model.dart';
import '../../models/complaint_model.dart';
import '../../services/firebase_service.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../utils/export_helper.dart';
import '../../models/short_stay_model.dart';
import '../../widgets/export_dialog.dart';
import '../../widgets/skeleton_loader.dart';

// ─────────────────────────────────────────────────────────────────────────────
// THEME CONSTANTS
// ─────────────────────────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF1E3A8A);
const _kAccent = Color(0xFF2563EB);
const _kBg = Color(0xFFF0F4FF);

class HeadWardenDashboard extends StatefulWidget {
  const HeadWardenDashboard({super.key});

  @override
  State<HeadWardenDashboard> createState() => _HeadWardenDashboardState();
}

class _HeadWardenDashboardState extends State<HeadWardenDashboard> {
  final FirebaseService _fs = FirebaseService();
  int _selectedIndex = 0;
  final List<StreamSubscription> _subscriptions = [];
  final List<GlobalKey> _tabKeys = List.generate(5, (index) => GlobalKey());

  // Activity Markers
  bool _hasNewRegistrations = false;
  bool _hasNewLeaves = false;
  bool _hasNewComplaints = false;
  bool _hasNewShortStays = false;

  @override
  void initState() {
    super.initState();
    _setupHeadWardenListeners();
  }

  @override
  void dispose() {
    for (var s in _subscriptions) {
      s.cancel();
    }
    super.dispose();
  }

  Future<void> _showExportDialog() async {
    final result = await showDialog<ExportDialogResult>(
      context: context,
      builder: (context) => const ExportDialog(hostel: 'All'),
    );

    if (result == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Preparing Export...')));

    try {
      switch (result.exportType) {
        case ExportType.attendance:
          List<DateTime> dates = [];
          for (
            int i = 0;
            i <= result.endDate.difference(result.startDate).inDays;
            i++
          ) {
            dates.add(result.startDate.add(Duration(days: i)));
          }

          // Fetch data for all hostels separately
          final hostelNames = ['BH1', 'BH2', 'GH1', 'GH2'];
          final Map<String, List<VistaUser>> hostelStudents = {};
          final Map<String, List<Attendance>> hostelAttendance = {};
          final Map<String, List<LeaveRequest>> hostelLeaves = {};

          for (final hostel in hostelNames) {
            hostelStudents[hostel] = await _fs.getHostelStudents(hostel).first;
            hostelAttendance[hostel] = await _fs
                .getHostelAttendanceRange(
                  hostel,
                  result.startDate,
                  result.endDate,
                )
                .first;
            hostelLeaves[hostel] = await _fs
                .getHostelLeavesRange(hostel, result.startDate, result.endDate)
                .first;
          }

          await ExportHelper.exportAttendanceSummaryMultiHostel(
            hostelStudents,
            hostelAttendance,
            hostelLeaves,
            dates,
          );
          break;

        case ExportType.students:
          final students = await _fs.getHostelStudents('All').first;
          await ExportHelper.exportStudents(
            students,
            'All',
            startDate: result.startDate,
            endDate: result.endDate,
          );
          break;

        case ExportType.leaveRequests:
          final students = await _fs.getHostelStudents('All').first;
          final leaves = await _fs
              .getHostelLeavesRange('All', result.startDate, result.endDate)
              .first;
          await ExportHelper.exportLeaves(
            leaves,
            students,
            'All',
            startDate: result.startDate,
            endDate: result.endDate,
          );
          break;

        case ExportType.complaints:
          final complaints = await _fs
              .getHostelComplaintsRange('All', result.startDate, result.endDate)
              .first;
          await ExportHelper.exportComplaints(
            complaints,
            'All',
            startDate: result.startDate,
            endDate: result.endDate,
          );
          break;

        case ExportType.shortStays:
          final shortStays = await _fs
              .getHostelShortStaysRange('All', result.startDate, result.endDate)
              .first;
          await ExportHelper.exportShortStays(
            shortStays,
            'All',
            startDate: result.startDate,
            endDate: result.endDate,
          );
          break;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Export completed successfully!')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  void _setupHeadWardenListeners() {
    // final warden = Provider.of<AuthProvider>(context, listen: false).userProfile!;

    // 1. Listen for New Student Registrations
    _subscriptions.add(
      _fs.getPendingRegistrations('All').listen((list) {
        if (list.isNotEmpty) {
          if (_selectedIndex != 0) {
            setState(() => _hasNewRegistrations = true);
          }
          _showInAppAlert(
            'New Registration Request',
            '${list.length} students pending',
            0,
          );
        } else {
          setState(() => _hasNewRegistrations = false);
        }
      }),
    );

    // 2. Listen for New Leaves
    _subscriptions.add(
      _fs.getPendingLeaves('All').listen((list) {
        if (list.isNotEmpty) {
          if (_selectedIndex != 2) {
            setState(() => _hasNewLeaves = true);
          }
          _showInAppAlert(
            'New Leave Request',
            '${list.length} requests pending',
            2,
          );
        } else {
          setState(() => _hasNewLeaves = false);
        }
      }),
    );

    // 3. Listen for New Complaints
    _subscriptions.add(
      _fs.getComplaintsForRole('Head Warden', 'All').listen((list) {
        final pending = list.where((c) => c.status == 'Pending').toList();
        if (pending.isNotEmpty) {
          if (_selectedIndex != 3) {
            setState(() => _hasNewComplaints = true);
          }
          _showInAppAlert('New Complaint Received', pending.first.title, 3);
        } else {
          setState(() => _hasNewComplaints = false);
        }
      }),
    );

    // 4. Listen for Short Stay Requests
    _subscriptions.add(
      _fs.getPendingShortStays('All').listen((list) {
        if (list.isNotEmpty) {
          if (_selectedIndex != 4) {
            setState(() => _hasNewShortStays = true);
          }
          _showInAppAlert(
            'Short Stay Request',
            '${list.length} pending requests',
            4,
          );
        } else {
          setState(() => _hasNewShortStays = false);
        }
      }),
    );
  }

  void _showInAppAlert(String title, String message, int targetIndex) {
    if (!mounted) return;
    if (_selectedIndex == targetIndex) return;

    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(message, style: const TextStyle(fontSize: 12)),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: _kPrimary,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'View',
          textColor: Colors.white,
          onPressed: () {
            _onTabTapped(targetIndex);
          },
        ),
      ),
    );
  }

  void _onTabTapped(int index) {
    setState(() {
      _selectedIndex = index;
      if (index == 0) _hasNewRegistrations = false;
      if (index == 2) _hasNewLeaves = false;
      if (index == 3) _hasNewComplaints = false;
      if (index == 4) _hasNewShortStays = false;
    });
  }

  String get _greeting {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good Morning';
    if (h < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final warden = Provider.of<AuthProvider>(context).userProfile!;

    final pages = [
      _StudentsTab(key: _tabKeys[0], warden: warden, fs: _fs),
      _AttendanceTab(key: _tabKeys[1], warden: warden, fs: _fs),
      _LeavesTab(key: _tabKeys[2], warden: warden, fs: _fs),
      _ComplaintsTab(key: _tabKeys[3], warden: warden, fs: _fs),
      _ShortStaysTab(key: _tabKeys[4], warden: warden, fs: _fs),
    ];

    const labels = [
      'Students',
      'Attendance',
      'Leaves',
      'Complaints',
      'Short Stay',
    ];
    const icons = [
      (off: Icons.groups_outlined, on: Icons.groups),
      (off: Icons.assignment_ind_outlined, on: Icons.assignment_ind),
      (off: Icons.event_note_outlined, on: Icons.event_note),
      (off: Icons.assignment_late_outlined, on: Icons.assignment_late),
      (off: Icons.hotel_outlined, on: Icons.hotel),
    ];

    return Scaffold(
      backgroundColor: _kBg,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: List.generate(5, (i) {
                final selected = _selectedIndex == i;
                final showMarker =
                    (i == 0 && _hasNewRegistrations) ||
                    (i == 2 && _hasNewLeaves) ||
                    (i == 3 && _hasNewComplaints) ||
                    (i == 4 && _hasNewShortStays);

                return GestureDetector(
                  onTap: () => _onTabTapped(i),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? _kPrimary.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              selected ? icons[i].on : icons[i].off,
                              size: 22,
                              color: selected ? _kPrimary : Colors.black38,
                            ),
                            if (showMarker)
                              Positioned(
                                top: -2,
                                right: -2,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (selected) ...[
                          const SizedBox(width: 8),
                          Text(
                            labels[i],
                            style: const TextStyle(
                              color: _kPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // ─────────── HEADER ───────────
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0F2460), _kPrimary, _kAccent],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: SafeArea(
              bottom: false,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final hPad = constraints.maxWidth > 900
                      ? (constraints.maxWidth - 900) / 2
                      : 16.0;
                  return Padding(
                    padding: EdgeInsets.fromLTRB(hPad, 12, hPad, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Image.asset(
                              'assets/images/jklu_logo_darkbg_bgremove.png',
                              height: 40,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'VISTA',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                            const Spacer(),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _showExportDialog,
                              icon: const Icon(
                                Icons.download_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                              tooltip: 'Export Data',
                            ),
                            const SizedBox(width: 4),
                            IconButton(
                              onPressed: () => FirebaseService().signOut(),
                              icon: const Icon(
                                Icons.logout_rounded,
                                color: Colors.white60,
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '$_greeting, ${warden.name}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),

          // ─────────── CONTENT ───────────
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final hPad = constraints.maxWidth > 900
                    ? (constraints.maxWidth - 900) / 2
                    : 0.0;
                return Padding(
                  padding: EdgeInsets.symmetric(horizontal: hPad),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      key: ValueKey(_selectedIndex),
                      child: pages[_selectedIndex],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER CHIP
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// ─────────────────────────────────────────────────────────────────────────────
// COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────
// QUICK STAT CARD (in header)
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// SHARED SECTION HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  final int? count;
  const _SectionLabel(this.text, {this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 18,
            decoration: BoxDecoration(
              color: _kPrimary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _kPrimary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _kPrimary.withValues(alpha: 0.08),
                  _kAccent.withValues(alpha: 0.04),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 52,
              color: _kPrimary.withValues(alpha: 0.35),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 13, color: Colors.black38),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STYLED CARD
// ─────────────────────────────────────────────────────────────────────────────
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STUDENTS TAB — shows hostel students + pending-registration alert banner
// ─────────────────────────────────────────────────────────────────────────────
class _StudentsTab extends StatefulWidget {
  final VistaUser warden;
  final FirebaseService fs;
  const _StudentsTab({super.key, required this.warden, required this.fs});

  @override
  State<_StudentsTab> createState() => _StudentsTabState();
}

class _StudentsTabState extends State<_StudentsTab> {
  final TextEditingController _searchCtrl = TextEditingController();
  bool _showRequests = false;
  String _searchQuery = '';
  String _statusFilter = 'All'; // 'All', 'In Campus', 'On Leave', 'Short Stay'
  String _hostelFilter = 'All'; // 'All', 'BH1', 'BH2', 'GH1', 'GH2'

  late Stream<List<VistaUser>> _pendingStream;
  late Stream<List<VistaUser>> _memberStream;
  late Stream<List<LeaveRequest>> _leaveStream;
  late Stream<List<ShortStayRequest>> _shortStayStream;

  @override
  void initState() {
    super.initState();
    _pendingStream = widget.fs.getPendingRegistrations(widget.warden.hostel);
    _memberStream = widget.fs.getHostelStudents('All');
    _leaveStream = widget.fs.getApprovedLeaves('All');
    _shortStayStream = widget.fs.getApprovedShortStays('All');

    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void export() async {
    final allMembers = await widget.fs.getHostelStudents('All').first;
    final approvedLeaves = await widget.fs.getApprovedLeaves('All').first;
    final approvedShortStays = await widget.fs
        .getApprovedShortStays('All')
        .first;

    final filtered = allMembers.where((m) {
      final now = DateTime.now();
      // Check if student has an active short stay (Approved and not Completed)
      final hasActiveShortStay = approvedShortStays.any(
        (ss) =>
            ss.studentId == m.uid &&
            ss.status == 'Approved' &&
            ss.actualCheckOutTime == null &&
            !now.isBefore(ss.checkInDate) &&
            !now.isAfter(ss.checkOutDate),
      );
      // For day scholars, only show if they have an active approved short stay
      if ((m.isDayScholar || m.hasUsedShortStay) && !hasActiveShortStay) {
        return false;
      }

      final matchesSearch =
          m.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (m.roomNumber ?? '').toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );

      bool matchesFilter = true;
      if (_statusFilter == 'On Leave') {
        matchesFilter = _isStudentOnLeave(m.uid, approvedLeaves);
      } else if (_statusFilter == 'Short Stay') {
        matchesFilter = _isStudentOnShortStay(m.uid, approvedShortStays);
      } else if (_statusFilter == 'In Campus') {
        matchesFilter =
            !_isStudentOnLeave(m.uid, approvedLeaves) &&
            !_isStudentOnShortStay(m.uid, approvedShortStays);
      }

      final matchesHostel = _hostelFilter == 'All' || m.hostel == _hostelFilter;

      return matchesSearch && matchesFilter && matchesHostel;
    }).toList();

    await ExportHelper.exportStudents(filtered, _hostelFilter);
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
                color: _kPrimary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: _kPrimary, width: 2),
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
                        await widget.fs.approveStudent(s.uid, sanitizedRoom);
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
                backgroundColor: _kPrimary,
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
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
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

  Widget _buildFilterChip(String label, {bool isHostel = false}) {
    final isSelected = isHostel
        ? _hostelFilter == label
        : _statusFilter == label;
    return GestureDetector(
      onTap: () => setState(
        () => isHostel ? _hostelFilter = label : _statusFilter = label,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _kPrimary : Colors.white,
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isSelected
                ? _kPrimary
                : Colors.black.withValues(alpha: 0.08),
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: _kPrimary.withValues(alpha: 0.2),
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
      // If student has checked in from leave, they are no longer on leave
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
    return Column(
      children: [
        // ── Search & Filter ── (Moved outside to prevent focus loss)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Container(
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
                          hintStyle: TextStyle(
                            color: Colors.black26,
                            fontSize: 14,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: _kPrimary,
                            size: 22,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(vertical: 15),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    height: 50,
                    width: 50,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _kPrimary.withValues(alpha: 0.08),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: PopupMenuButton<String>(
                      icon: Icon(
                        Icons.filter_list_rounded,
                        color: _hostelFilter == 'All'
                            ? Colors.black54
                            : _kPrimary,
                      ),
                      tooltip: 'Filter by Hostel',
                      onSelected: (val) => setState(() => _hostelFilter = val),
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'All',
                          child: Text('All Hostels'),
                        ),
                        const PopupMenuItem(value: 'BH1', child: Text('BH1')),
                        const PopupMenuItem(value: 'BH2', child: Text('BH2')),
                        const PopupMenuItem(value: 'GH1', child: Text('GH1')),
                        const PopupMenuItem(value: 'GH2', child: Text('GH2')),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

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
          child: StreamBuilder<List<VistaUser>>(
            stream: _pendingStream,
            builder: (context, pendingSnap) {
              var pending = pendingSnap.data ?? [];
              if (_hostelFilter != 'All') {
                pending = pending
                    .where((s) => s.hostel == _hostelFilter)
                    .toList();
              }

              return StreamBuilder<List<VistaUser>>(
                stream: _memberStream,
                builder: (context, memberSnap) {
                  return StreamBuilder<List<LeaveRequest>>(
                    stream: _leaveStream,
                    builder: (context, leaveSnap) {
                      return StreamBuilder<List<ShortStayRequest>>(
                        stream: _shortStayStream,
                        builder: (context, ssSnap) {
                          if (memberSnap.connectionState ==
                                  ConnectionState.waiting &&
                              pendingSnap.connectionState ==
                                  ConnectionState.waiting) {
                            return const StudentListSkeleton();
                          }

                          final allMembers = memberSnap.data ?? [];
                          final approvedLeaves = leaveSnap.data ?? [];
                          final approvedShortStays = ssSnap.data ?? [];

                          // Filtering logic
                          var filtered = allMembers.where((m) {
                            final now = DateTime.now();
                            // Check if student has an active short stay (Approved and not Completed)
                            final hasActiveShortStay = approvedShortStays.any(
                              (ss) =>
                                  ss.studentId == m.uid &&
                                  ss.status == 'Approved' &&
                                  ss.actualCheckOutTime == null &&
                                  !now.isBefore(ss.checkInDate) &&
                                  !now.isAfter(ss.checkOutDate),
                            );
                            // For day scholars, only show if they have an active approved short stay
                            if ((m.isDayScholar || m.hasUsedShortStay) &&
                                !hasActiveShortStay) {
                              return false;
                            }

                            final matchesSearch =
                                m.name.toLowerCase().contains(
                                  _searchQuery.toLowerCase(),
                                ) ||
                                (m.roomNumber ?? '').toLowerCase().contains(
                                  _searchQuery.toLowerCase(),
                                );
                            bool matchesFilter = true;
                            if (_statusFilter == 'On Leave') {
                              matchesFilter = _isStudentOnLeave(
                                m.uid,
                                approvedLeaves,
                              );
                            } else if (_statusFilter == 'Short Stay') {
                              matchesFilter = _isStudentOnShortStay(
                                m.uid,
                                approvedShortStays,
                              );
                            } else if (_statusFilter == 'In Campus') {
                              matchesFilter =
                                  !_isStudentOnLeave(m.uid, approvedLeaves) &&
                                  !_isStudentOnShortStay(
                                    m.uid,
                                    approvedShortStays,
                                  );
                            }

                            final matchesHostel =
                                _hostelFilter == 'All' ||
                                m.hostel == _hostelFilter;

                            return matchesSearch &&
                                matchesFilter &&
                                matchesHostel;
                          }).toList();

                          // Determine empty state message
                          String emptyTitle = 'No Students Registered';
                          String emptySubtitle =
                              'Approve registration requests from the banner above to add students.';
                          IconData emptyIcon = Icons.people_outline;

                          if (_searchQuery.isNotEmpty) {
                            emptyTitle = 'No Results Found';
                            emptySubtitle =
                                'We couldn\'t find any student matching "$_searchQuery".';
                            emptyIcon = Icons.search_off_rounded;
                          } else {
                            String hostelPart = _hostelFilter == 'All'
                                ? ''
                                : ' from $_hostelFilter';
                            switch (_statusFilter) {
                              case 'In Campus':
                                emptyTitle = 'Quiet Corridor';
                                emptySubtitle =
                                    'All our students$hostelPart seem to be away or on leave right now.';
                                emptyIcon = Icons.nightlife_rounded;
                                break;
                              case 'On Leave':
                                emptyTitle = 'All Students Present';
                                emptySubtitle =
                                    'It looks like everyone$hostelPart is currently on campus. No active leaves!';
                                emptyIcon = Icons.home_rounded;
                                break;
                              case 'Short Stay':
                                emptyTitle = 'No Active Short Stays';
                                emptySubtitle =
                                    'There are no visiting day scholars$hostelPart at the moment.';
                                emptyIcon = Icons.timer_off_rounded;
                                break;
                              default:
                                if (_hostelFilter != 'All') {
                                  emptyTitle = 'No Students in $_hostelFilter';
                                  emptySubtitle =
                                      'There are no students registered in this hostel yet.';
                                }
                            }
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // ── Pending Alert Banner ──
                              if (pending.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    0,
                                    16,
                                    12,
                                  ),
                                  child: Column(
                                    children: [
                                      GestureDetector(
                                        onTap: () => setState(
                                          () => _showRequests = !_showRequests,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 14,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _kPrimary,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: _kPrimary.withValues(
                                                  alpha: 0.3,
                                                ),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.all(
                                                  8,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.15),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: const Icon(
                                                  Icons
                                                      .notifications_active_rounded,
                                                  color: Colors.white,
                                                  size: 16,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      '${pending.length} Registration Request${pending.length > 1 ? 's' : ''}',
                                                      style: const TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.w800,
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                    Text(
                                                      _showRequests
                                                          ? 'Tap to hide detail'
                                                          : 'Tap to review and approve',
                                                      style: TextStyle(
                                                        color: Colors.white
                                                            .withValues(
                                                              alpha: 0.7,
                                                            ),
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              Icon(
                                                _showRequests
                                                    ? Icons
                                                          .keyboard_arrow_up_rounded
                                                    : Icons
                                                          .keyboard_arrow_down_rounded,
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
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: _kPrimary.withValues(
                                                alpha: 0.1,
                                              ),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.04,
                                                ),
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
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 14,
                                                          vertical: 10,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        CircleAvatar(
                                                          radius: 20,
                                                          backgroundColor:
                                                              _kPrimary
                                                                  .withValues(
                                                                    alpha: 0.1,
                                                                  ),
                                                          child: Text(
                                                            s.name.isNotEmpty
                                                                ? s.name[0]
                                                                      .toUpperCase()
                                                                : 'S',
                                                            style:
                                                                const TextStyle(
                                                                  color:
                                                                      _kPrimary,
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .bold,
                                                                ),
                                                          ),
                                                        ),
                                                        const SizedBox(
                                                          width: 10,
                                                        ),
                                                        Expanded(
                                                          child: Column(
                                                            crossAxisAlignment:
                                                                CrossAxisAlignment
                                                                    .start,
                                                            children: [
                                                              Text(
                                                                s.name,
                                                                style: const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w700,
                                                                  fontSize: 14,
                                                                ),
                                                              ),
                                                              Text(
                                                                s.email,
                                                                style: const TextStyle(
                                                                  color: Colors
                                                                      .black45,
                                                                  fontSize: 11,
                                                                ),
                                                              ),
                                                            ],
                                                          ),
                                                        ),
                                                        Row(
                                                          mainAxisSize:
                                                              MainAxisSize.min,
                                                          children: [
                                                            GestureDetector(
                                                              onTap: () async =>
                                                                  widget.fs
                                                                      .denyStudent(
                                                                        s.uid,
                                                                      ),
                                                              child: Container(
                                                                padding:
                                                                    const EdgeInsets.all(
                                                                      10,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color: Colors
                                                                      .red
                                                                      .withValues(
                                                                        alpha:
                                                                            0.08,
                                                                      ),
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        12,
                                                                      ),
                                                                  border: Border.all(
                                                                    color: Colors
                                                                        .red
                                                                        .withValues(
                                                                          alpha:
                                                                              0.15,
                                                                        ),
                                                                  ),
                                                                ),
                                                                child: const Icon(
                                                                  Icons
                                                                      .close_rounded,
                                                                  color: Colors
                                                                      .red,
                                                                  size: 18,
                                                                ),
                                                              ),
                                                            ),
                                                            const SizedBox(
                                                              width: 10,
                                                            ),
                                                            GestureDetector(
                                                              onTap: () =>
                                                                  _approveDialog(
                                                                    context,
                                                                    s,
                                                                  ),
                                                              child: Container(
                                                                padding:
                                                                    const EdgeInsets.all(
                                                                      10,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color: Colors
                                                                      .green
                                                                      .withValues(
                                                                        alpha:
                                                                            0.08,
                                                                      ),
                                                                  borderRadius:
                                                                      BorderRadius.circular(
                                                                        12,
                                                                      ),
                                                                  border: Border.all(
                                                                    color: Colors
                                                                        .green
                                                                        .withValues(
                                                                          alpha:
                                                                              0.15,
                                                                        ),
                                                                  ),
                                                                ),
                                                                child: const Icon(
                                                                  Icons
                                                                      .check_rounded,
                                                                  color: Colors
                                                                      .green,
                                                                  size: 18,
                                                                ),
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (s != pending.last)
                                                    const Divider(
                                                      height: 1,
                                                      indent: 14,
                                                      endIndent: 14,
                                                    ),
                                                ],
                                              );
                                            }).toList(),
                                          ),
                                        ),
                                      const SizedBox(height: 8),
                                    ],
                                  ),
                                ),

                              _SectionLabel(
                                'Hostel Students',
                                count: filtered.length,
                              ),

                              if (filtered.isEmpty)
                                Expanded(
                                  child: _EmptyState(
                                    icon: emptyIcon,
                                    title: emptyTitle,
                                    subtitle: emptySubtitle,
                                  ),
                                )
                              else
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: filtered.length,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                    ),
                                    itemBuilder: (context, i) {
                                      final m = filtered[i];
                                      final onLeave = _isStudentOnLeave(
                                        m.uid,
                                        approvedLeaves,
                                      );
                                      final onShortStay = _isStudentOnShortStay(
                                        m.uid,
                                        approvedShortStays,
                                      );
                                      return _Card(
                                        child: Row(
                                          children: [
                                            Stack(
                                              children: [
                                                CircleAvatar(
                                                  radius: 24,
                                                  backgroundColor: _kPrimary
                                                      .withValues(alpha: 0.1),
                                                  child: Text(
                                                    m.name.isNotEmpty
                                                        ? m.name[0]
                                                              .toUpperCase()
                                                        : 'S',
                                                    style: const TextStyle(
                                                      color: _kPrimary,
                                                      fontWeight:
                                                          FontWeight.bold,
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
                                                      color: onLeave
                                                          ? Colors.orange
                                                          : (onShortStay
                                                                ? Colors.blue
                                                                : Colors.green),
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: Colors.white,
                                                        width: 2,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(width: 12),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    m.name,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      fontSize: 15,
                                                      color: Color(0xFF1E293B),
                                                    ),
                                                  ),
                                                  Text(
                                                    m.email,
                                                    style: const TextStyle(
                                                      color: Colors.black45,
                                                      fontSize: 11,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Row(
                                                    children: [
                                                      const Icon(
                                                        Icons.phone_outlined,
                                                        size: 11,
                                                        color: Colors.black38,
                                                      ),
                                                      const SizedBox(width: 4),
                                                      Text(
                                                        m.phoneNumber ??
                                                            'No Phone',
                                                        style: const TextStyle(
                                                          color: Colors.black38,
                                                          fontSize: 11,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.end,
                                              children: [
                                                if (m.roomNumber != null &&
                                                    m.roomNumber!.isNotEmpty)
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 10,
                                                          vertical: 5,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: _kPrimary
                                                          .withValues(
                                                            alpha: 0.08,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                          Icons
                                                              .meeting_room_outlined,
                                                          size: 13,
                                                          color: _kPrimary,
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Text(
                                                          'Room ${m.roomNumber}',
                                                          style:
                                                              const TextStyle(
                                                                color:
                                                                    _kPrimary,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w700,
                                                                fontSize: 12,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  onLeave
                                                      ? 'ON LEAVE'
                                                      : (onShortStay
                                                            ? 'SHORT STAY'
                                                            : 'IN CAMPUS'),
                                                  style: TextStyle(
                                                    color: onLeave
                                                        ? Colors.orange
                                                        : (onShortStay
                                                              ? Colors.blue
                                                              : Colors.green),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// ATTENDANCE TAB
// ─────────────────────────────────────────────────────────────────────────────
class _AttendanceRecord {
  final VistaUser student;
  final Attendance? attendance;
  final String status;

  _AttendanceRecord(this.student, this.attendance, {bool onLeave = false})
    : status = attendance != null
          ? ((attendance.timestamp.hour == 22 &&
                        attendance.timestamp.minute >= 30) ||
                    attendance.timestamp.hour == 23
                ? 'Late'
                : 'Marked')
          : (onLeave ? 'On Leave' : 'Absent');
}

class _AttendanceTab extends StatefulWidget {
  final VistaUser warden;
  final FirebaseService fs;
  const _AttendanceTab({super.key, required this.warden, required this.fs});

  @override
  State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab> {
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
  void initState() {
    super.initState();
    _studentStream = widget.fs.getHostelStudents(widget.warden.hostel);
    _leaveStream = widget.fs.getApprovedLeaves(widget.warden.hostel);
    _shortStayStream = widget.fs.getApprovedShortStays(widget.warden.hostel);

    _updateAttendanceStream();

    _searchCtrl.addListener(() {
      setState(() => _searchQuery = _searchCtrl.text);
    });
  }

  void _updateAttendanceStream() {
    final dateStr =
        "${_selectedDate.year}-${_selectedDate.month}-${_selectedDate.day}";
    _attendanceStream = widget.fs.getHostelAttendance(
      widget.warden.hostel,
      dateStr,
    );
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
              primary: _kPrimary,
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
      builder: (context) =>
          _StudentAttendanceCalendar(student: student, fs: widget.fs),
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
              primary: _kPrimary,
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
      // Show a simple loading indicator or just do it
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Preparing Export...')));

      final students = await widget.fs.getHostelStudents(_hostelFilter).first;
      final attendance = await widget.fs
          .getHostelAttendanceRange(_hostelFilter, range.start, range.end)
          .first;
      final leaves = await widget.fs
          .getHostelLeavesRange(_hostelFilter, range.start, range.end)
          .first;

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
    return InkWell(
      onTap: () => setState(() => _statusFilter = label),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _kPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? _kPrimary : Colors.grey.shade300,
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

  bool _isStudentOnLeave(
    String studentId,
    List<LeaveRequest> approvedLeaves,
    DateTime date,
  ) {
    final checkDate = DateTime(date.year, date.month, date.day);
    return approvedLeaves.any((leave) {
      if (leave.studentId != studentId) return false;
      // If student has checked in from leave, they are no longer on leave
      if (leave.checkInTime != null) {
        final checkInDate = DateTime(
          leave.checkInTime!.year,
          leave.checkInTime!.month,
          leave.checkInTime!.day,
        );
        // If checking for a date on or after check-in, they're not on leave
        if (!checkDate.isBefore(checkInDate)) return false;
      }
      final from = DateTime(
        leave.fromDate.year,
        leave.fromDate.month,
        leave.fromDate.day,
      );
      final to = DateTime(
        leave.toDate.year,
        leave.toDate.month,
        leave.toDate.day,
      );
      return !checkDate.isBefore(from) && !checkDate.isAfter(to);
    });
  }

  void _showDefaultersList(List<_AttendanceRecord> defaulters) {
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
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
              const Divider(),
              Expanded(
                child: defaulters.isEmpty
                    ? const Center(
                        child: Text(
                          'All records completed.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    : ListView.builder(
                        itemCount: defaulters.length,
                        itemBuilder: (context, i) {
                          final student = defaulters[i].student;
                          return ListTile(
                            title: Text(
                              student.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              'Room ${student.roomNumber ?? 'N/A'} [${student.hostel ?? ''}]',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                              ),
                            ),
                            trailing: OutlinedButton.icon(
                              icon: const Icon(Icons.call, size: 16),
                              label: const Text('Call'),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _kPrimary,
                                side: const BorderSide(color: _kPrimary),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                minimumSize: const Size(0, 32),
                              ),
                              onPressed: () async {
                                final phoneStr = student.phoneNumber ?? '';
                                final phone = phoneStr.replaceAll(
                                  RegExp(r'[^\d+]'),
                                  '',
                                );
                                final Uri telUri = Uri.parse('tel:$phone');
                                if (await canLaunchUrl(telUri)) {
                                  await launchUrl(
                                    telUri,
                                    mode: LaunchMode.externalApplication,
                                  );
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
    final now = DateTime.now();
    final isLateWindow = now.hour >= 22;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── SEARCH BAR & DATE PICKER ──
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
                    prefixIcon: const Icon(
                      Icons.search,
                      size: 20,
                      color: Colors.black45,
                    ),
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
                      borderSide: const BorderSide(color: _kPrimary),
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
                      const Icon(
                        Icons.calendar_month,
                        size: 18,
                        color: _kPrimary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        DateFormat('MMM d').format(_selectedDate),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _kPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: PopupMenuButton<String>(
                  icon: Icon(
                    Icons.filter_list_rounded,
                    color: _hostelFilter == 'All' ? Colors.black54 : _kPrimary,
                    size: 20,
                  ),
                  tooltip: 'Filter by Hostel',
                  onSelected: (val) => setState(() => _hostelFilter = val),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'All',
                      child: Text('All Hostels'),
                    ),
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

        // ── FILTER CHIPS ──
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
              _buildFilterChip('Absent'),
            ],
          ),
        ),

        // ── DATA SECTION ──
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
                          if (studentSnap.connectionState ==
                                  ConnectionState.waiting ||
                              leaveSnap.connectionState ==
                                  ConnectionState.waiting ||
                              attendanceSnap.connectionState ==
                                  ConnectionState.waiting ||
                              ssSnap.connectionState ==
                                  ConnectionState.waiting) {
                            return const AttendanceListSkeleton();
                          }

                          final studentsData = studentSnap.data ?? [];
                          final leaveRequests = leaveSnap.data ?? [];
                          final attendanceLists = attendanceSnap.data ?? [];
                          final approvedShortStays = ssSnap.data ?? [];

                          // Initial filtering: Show permanent hostellers OR day scholars with active short stay
                          final students = studentsData.where((m) {
                            final now = DateTime.now();
                            final hasActiveShortStay = approvedShortStays.any(
                              (ss) =>
                                  ss.studentId == m.uid &&
                                  ss.status == 'Approved' &&
                                  ss.actualCheckOutTime == null &&
                                  !now.isBefore(ss.checkInDate) &&
                                  !now.isAfter(ss.checkOutDate),
                            );
                            if ((m.isDayScholar || m.hasUsedShortStay) &&
                                !hasActiveShortStay) {
                              return false;
                            }
                            return true;
                          }).toList();

                          final approvedLeaves = leaveRequests
                              .where((l) => l.status == 'Approved')
                              .toList();

                          final Map<String, Attendance> attendanceMap = {
                            for (var a in attendanceLists) a.studentId: a,
                          };

                          List<_AttendanceRecord> records = students
                              .where(
                                (s) =>
                                    _hostelFilter == 'All' ||
                                    s.hostel == _hostelFilter,
                              )
                              .map((s) {
                                final onLeave = _isStudentOnLeave(
                                  s.uid,
                                  approvedLeaves,
                                  _selectedDate,
                                );
                                return _AttendanceRecord(
                                  s,
                                  attendanceMap[s.uid],
                                  onLeave: onLeave,
                                );
                              })
                              .toList();

                          final defaulters = records
                              .where((r) => r.status == 'Absent')
                              .toList();

                          if (_statusFilter != 'All') {
                            records = records
                                .where((r) => r.status == _statusFilter)
                                .toList();
                          }

                          if (_searchQuery.isNotEmpty) {
                            records = records
                                .where(
                                  (r) =>
                                      r.student.name.toLowerCase().contains(
                                        _searchQuery.toLowerCase(),
                                      ) ||
                                      (r.student.roomNumber ?? '')
                                          .toLowerCase()
                                          .contains(_searchQuery.toLowerCase()),
                                )
                                .toList();
                          }

                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isLateWindow && defaulters.isNotEmpty)
                                Container(
                                  margin: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    0,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    border: Border.all(
                                      color: Colors.red.shade200,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.warning_amber,
                                        color: Colors.red.shade700,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          '${defaulters.length} students pending attendance',
                                          style: TextStyle(
                                            color: Colors.red.shade700,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            _showDefaultersList(defaulters),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red.shade700,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                          minimumSize: Size.zero,
                                          tapTargetSize:
                                              MaterialTapTargetSize.shrinkWrap,
                                        ),
                                        child: const Text(
                                          'View List',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  16,
                                  12,
                                  16,
                                  8,
                                ),
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
                                        child: Text(
                                          'No records found.',
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontSize: 14,
                                          ),
                                        ),
                                      )
                                    : ListView.separated(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 8,
                                        ),
                                        itemCount: records.length,
                                        separatorBuilder: (context, index) =>
                                            const SizedBox(height: 8),
                                        itemBuilder: (context, i) {
                                          final r = records[i];
                                          final isAbsent = r.status == 'Absent';
                                          final isLate = r.status == 'Late';
                                          final isOnLeave =
                                              r.status == 'On Leave';

                                          Color statusColor =
                                              Colors.green.shade600;
                                          if (isAbsent) {
                                            statusColor = Colors.red.shade600;
                                          } else if (isLate) {
                                            statusColor =
                                                Colors.orange.shade700;
                                          } else if (isOnLeave) {
                                            statusColor = Colors.blue.shade600;
                                          }

                                          return InkWell(
                                            onTap: () =>
                                                _showStudentAttendanceHistory(
                                                  r.student,
                                                ),
                                            child: Container(
                                              padding: const EdgeInsets.all(16),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: Colors.grey.shade200,
                                                ),
                                              ),
                                              child: Row(
                                                children: [
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          r.student.name,
                                                          style:
                                                              const TextStyle(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                fontSize: 14,
                                                                color: Colors
                                                                    .black87,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          '(${r.student.hostel ?? 'N/A'}) Room ${r.student.roomNumber ?? 'N/A'}',
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .black54,
                                                                fontSize: 12,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment.end,
                                                    children: [
                                                      Text(
                                                        r.status.toUpperCase(),
                                                        style: TextStyle(
                                                          color: statusColor,
                                                          fontSize: 11,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          letterSpacing: 0.5,
                                                        ),
                                                      ),
                                                      if (r.attendance !=
                                                          null) ...[
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          DateFormat(
                                                            'HH:mm',
                                                          ).format(
                                                            r
                                                                .attendance!
                                                                .timestamp,
                                                          ),
                                                          style:
                                                              const TextStyle(
                                                                color: Colors
                                                                    .black45,
                                                                fontSize: 12,
                                                              ),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// LEAVES TAB
// ─────────────────────────────────────────────────────────────────────────────
class _LeavesTab extends StatefulWidget {
  final VistaUser warden;
  final FirebaseService fs;
  const _LeavesTab({super.key, required this.warden, required this.fs});

  @override
  State<_LeavesTab> createState() => _LeavesTabState();
}

class _LeavesTabState extends State<_LeavesTab> {
  String _searchQuery = '';
  String _hostelFilter = 'All';
  String _statusFilter = 'All';
  DateTime? _selectedDate = DateTime.now();

  void export() => _showRangeExport();

  Future<void> _showRangeExport() async {
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      initialDateRange: DateTimeRange(
        start: _selectedDate ?? DateTime.now(),
        end: (_selectedDate ?? DateTime.now()).add(const Duration(days: 7)),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _kPrimary,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Preparing Export...')));

      final students = await widget.fs.getHostelStudents(_hostelFilter).first;
      final leaves = await widget.fs
          .getHostelLeavesRange(_hostelFilter, range.start, range.end)
          .first;

      await ExportHelper.exportLeaves(leaves, students, _hostelFilter);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _kPrimary,
              onPrimary: Colors.white,
              onSurface: _kPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search & Filter Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _kPrimary.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: (v) => setState(
                      () => _searchQuery = InputSanitizer.sanitize(v),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search student name...',
                      hintStyle: const TextStyle(
                        color: Colors.black26,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: _kPrimary,
                        size: 20,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedDate == null
                          ? Colors.black.withValues(alpha: 0.1)
                          : _kPrimary.withValues(alpha: 0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _kPrimary.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 18,
                        color: _selectedDate == null
                            ? Colors.black38
                            : _kPrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedDate == null
                            ? 'Date'
                            : DateFormat('MMM d').format(_selectedDate!),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _selectedDate == null
                              ? Colors.black54
                              : _kPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_selectedDate != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => setState(() => _selectedDate = null),
                  icon: const Icon(Icons.close, color: Colors.redAccent),
                  tooltip: 'Clear Date Filter',
                ),
              ],
              const SizedBox(width: 8),
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _kPrimary.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: PopupMenuButton<String>(
                  icon: Icon(
                    Icons.filter_list_rounded,
                    color: _hostelFilter == 'All' ? Colors.black54 : _kPrimary,
                  ),
                  tooltip: 'Filter by Hostel',
                  onSelected: (val) => setState(() => _hostelFilter = val),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'All',
                      child: Text('All Hostels'),
                    ),
                    const PopupMenuItem(value: 'BH1', child: Text('BH1')),
                    const PopupMenuItem(value: 'BH2', child: Text('BH2')),
                    const PopupMenuItem(value: 'GH1', child: Text('GH1')),
                    const PopupMenuItem(value: 'GH2', child: Text('GH2')),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _kPrimary.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: PopupMenuButton<String>(
                  icon: Icon(
                    Icons.segment_rounded,
                    color: _statusFilter == 'All' ? Colors.black54 : _kPrimary,
                  ),
                  tooltip: 'Filter by Status',
                  onSelected: (val) => setState(() => _statusFilter = val),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'All',
                      child: Text('All Status'),
                    ),
                    const PopupMenuItem(
                      value: 'Pending',
                      child: Text('Pending'),
                    ),
                    const PopupMenuItem(
                      value: 'Approved',
                      child: Text('Approved'),
                    ),
                    const PopupMenuItem(
                      value: 'Rejected',
                      child: Text('Rejected'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        Expanded(
          child: StreamBuilder<List<LeaveRequest>>(
            stream: widget.fs.getHostelLeaves(widget.warden.hostel),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const AttendanceListSkeleton();
              }

              var list = snap.data ?? [];

              // Apply Local Filters
              if (_searchQuery.isNotEmpty) {
                list = list
                    .where(
                      (l) => l.studentName.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ),
                    )
                    .toList();
              }

              if (_selectedDate != null) {
                list = list.where((l) {
                  final start = DateTime(
                    l.fromDate.year,
                    l.fromDate.month,
                    l.fromDate.day,
                  );
                  final end = DateTime(
                    l.toDate.year,
                    l.toDate.month,
                    l.toDate.day,
                  );
                  final target = DateTime(
                    _selectedDate!.year,
                    _selectedDate!.month,
                    _selectedDate!.day,
                  );
                  return !target.isBefore(start) && !target.isAfter(end);
                }).toList();
              }

              if (_hostelFilter != 'All') {
                list = list.where((l) => l.hostel == _hostelFilter).toList();
              }

              if (_statusFilter != 'All') {
                list = list.where((l) => l.status == _statusFilter).toList();
              }

              if (list.isEmpty) {
                return const _EmptyState(
                  icon: Icons.event_note_outlined,
                  title: 'No Leaves Found',
                  subtitle: 'Try adjusting your search or filters',
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel('Leave History', count: list.length),
                  Expanded(
                    child: ListView.builder(
                      itemCount: list.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, i) {
                        final l = list[i];
                        final isApproved = l.status == 'Approved';
                        final isRejected = l.status == 'Rejected';

                        return _Card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    isApproved
                                        ? Icons.check_circle
                                        : (isRejected
                                              ? Icons.cancel
                                              : Icons.description_outlined),
                                    color: isApproved
                                        ? Colors.green
                                        : (isRejected
                                              ? Colors.redAccent
                                              : _kPrimary),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      '${l.seqId} - ${l.studentName.toUpperCase()}',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                        letterSpacing: 1.2,
                                        color: isApproved
                                            ? Colors.green
                                            : (isRejected
                                                  ? Colors.redAccent
                                                  : _kPrimary),
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          (isApproved
                                                  ? Colors.green
                                                  : (isRejected
                                                        ? Colors.redAccent
                                                        : Colors.orange))
                                              .withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      l.status.toUpperCase(),
                                      style: TextStyle(
                                        color: isApproved
                                            ? Colors.green
                                            : (isRejected
                                                  ? Colors.redAccent
                                                  : Colors.orange),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              _buildReadOnlyInput(
                                'From Date & Time',
                                DateFormat(
                                  'dd/MM/yyyy hh:mm a',
                                ).format(l.fromDate),
                                icon: Icons.access_time_rounded,
                              ),
                              _buildReadOnlyInput(
                                'To Date & Time',
                                DateFormat(
                                  'dd/MM/yyyy hh:mm a',
                                ).format(l.toDate),
                                icon: Icons.update_rounded,
                              ),
                              _buildReadOnlyInput(
                                'Reason',
                                l.reason,
                                icon: Icons.edit_note_rounded,
                              ),
                              _buildReadOnlyInput(
                                'Address during leave',
                                l.address,
                                icon: Icons.home_work_outlined,
                              ),
                              _buildReadOnlyInput(
                                'Parent Name',
                                '${l.parentName} (${l.parentRelation})',
                                icon: Icons.person_outline,
                              ),
                              _buildReadOnlyInput(
                                'Contact',
                                l.parentContact,
                                icon: Icons.phone_android_rounded,
                                trailing: IconButton(
                                  onPressed: () async {
                                    final phone = l.parentContact.replaceAll(
                                      RegExp(r'[^\d+]'),
                                      '',
                                    );
                                    final Uri telUri = Uri.parse('tel:$phone');
                                    try {
                                      if (await canLaunchUrl(telUri)) {
                                        await launchUrl(
                                          telUri,
                                          mode: LaunchMode.externalApplication,
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(content: Text('Error: $e')),
                                        );
                                      }
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.call_rounded,
                                    color: Colors.green,
                                    size: 18,
                                  ),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (isApproved
                                              ? Colors.green
                                              : (isRejected
                                                    ? Colors.redAccent
                                                    : Colors.orange))
                                          .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color:
                                        (isApproved
                                                ? Colors.green
                                                : (isRejected
                                                      ? Colors.redAccent
                                                      : Colors.orange))
                                            .withValues(alpha: 0.5),
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    isApproved
                                        ? 'LEAVE APPROVED'
                                        : (isRejected
                                              ? 'LEAVE REJECTED'
                                              : 'PENDING WARDEN APPROVAL'),
                                    style: TextStyle(
                                      color: isApproved
                                          ? Colors.green
                                          : (isRejected
                                                ? Colors.redAccent
                                                : Colors.orange),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 13,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyInput(
    String label,
    String value, {
    IconData? icon,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _kBg.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kPrimary.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: _kPrimary.withValues(alpha: 0.5)),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _kPrimary.withValues(alpha: 0.4),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPLAINTS TAB
// ─────────────────────────────────────────────────────────────────────────────
class _ComplaintsTab extends StatefulWidget {
  final VistaUser warden;
  final FirebaseService fs;
  const _ComplaintsTab({super.key, required this.warden, required this.fs});

  @override
  State<_ComplaintsTab> createState() => _ComplaintsTabState();
}

class _ComplaintsTabState extends State<_ComplaintsTab> {
  String _searchQuery = '';
  String _hostelFilter = 'All';
  DateTime? _selectedDate = DateTime.now();

  void export() => _showRangeExport();

  Future<void> _showRangeExport() async {
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start:
            _selectedDate ?? DateTime.now().subtract(const Duration(days: 30)),
        end: _selectedDate ?? DateTime.now(),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _kPrimary,
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Preparing Export...')));

      final complaints = await widget.fs
          .getHostelComplaintsRange(_hostelFilter, range.start, range.end)
          .first;

      await ExportHelper.exportComplaints(complaints, _hostelFilter);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime(2024),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: _kPrimary,
              onPrimary: Colors.white,
              onSurface: _kPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search & Filter Bar
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: _kPrimary.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    onChanged: (v) => setState(
                      () => _searchQuery = InputSanitizer.sanitize(v),
                    ),
                    decoration: InputDecoration(
                      hintText: 'Search complaint...',
                      hintStyle: const TextStyle(
                        color: Colors.black26,
                        fontSize: 13,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: _kPrimary,
                        size: 20,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () => _selectDate(context),
                child: Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _selectedDate == null
                          ? Colors.black.withValues(alpha: 0.1)
                          : _kPrimary.withValues(alpha: 0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _kPrimary.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.calendar_month_rounded,
                        size: 18,
                        color: _selectedDate == null
                            ? Colors.black38
                            : _kPrimary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _selectedDate == null
                            ? 'Date'
                            : DateFormat('MMM d').format(_selectedDate!),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _selectedDate == null
                              ? Colors.black54
                              : _kPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_selectedDate != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  onPressed: () => setState(() => _selectedDate = null),
                  icon: const Icon(Icons.close, color: Colors.redAccent),
                  tooltip: 'Clear Date Filter',
                ),
              ],
              const SizedBox(width: 8),
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _kPrimary.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: PopupMenuButton<String>(
                  icon: Icon(
                    Icons.filter_list_rounded,
                    color: _hostelFilter == 'All' ? Colors.black54 : _kPrimary,
                  ),
                  tooltip: 'Filter by Hostel',
                  onSelected: (val) => setState(() => _hostelFilter = val),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'All',
                      child: Text('All Hostels'),
                    ),
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

        Expanded(
          child: StreamBuilder<List<Complaint>>(
            stream: widget.fs.getComplaintsForRole(
              'Head Warden',
              widget.warden.hostel,
            ),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const ComplaintListSkeleton();
              }
              var list = snap.data ?? [];

              // Apply Local Filters
              if (_searchQuery.isNotEmpty) {
                list = list
                    .where(
                      (c) => c.title.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ),
                    )
                    .toList();
              }

              if (_selectedDate != null) {
                list = list.where((c) {
                  final target = DateTime(
                    _selectedDate!.year,
                    _selectedDate!.month,
                    _selectedDate!.day,
                  );
                  final created = DateTime(
                    c.createdAt.year,
                    c.createdAt.month,
                    c.createdAt.day,
                  );
                  return target.isAtSameMomentAs(created);
                }).toList();
              }

              if (_hostelFilter != 'All') {
                list = list.where((c) => c.hostel == _hostelFilter).toList();
              }

              if (list.isEmpty) {
                return const _EmptyState(
                  icon: Icons.inbox_outlined,
                  title: 'No Complaints Found',
                  subtitle: 'Try adjusting your search or filters',
                );
              }

              // Sort by date descending
              list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionLabel('All Complaints', count: list.length),
                  Expanded(
                    child: ListView.builder(
                      itemCount: list.length,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemBuilder: (context, i) {
                        final c = list[i];
                        final resolved =
                            c.status == 'Resolved' || c.status == 'Confirmed';
                        return _Card(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: resolved
                                      ? Colors.green.withValues(alpha: 0.1)
                                      : Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  resolved
                                      ? Icons.check_circle_outline
                                      : Icons.assignment_late_outlined,
                                  color: resolved
                                      ? Colors.green
                                      : Colors.orange,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            '${c.seqId}: (${c.hostel}) ${c.title}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                              color: Color(0xFF1E293B),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          DateFormat(
                                            'dd MMM',
                                          ).format(c.createdAt),
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: _kPrimary.withValues(
                                              alpha: 0.4,
                                            ),
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      c.description,
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 13,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: resolved
                                                ? Colors.green.withValues(
                                                    alpha: 0.1,
                                                  )
                                                : Colors.orange.withValues(
                                                    alpha: 0.1,
                                                  ),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            (!resolved && c.isEscalated)
                                                ? 'ESCALATED'
                                                : (c.status == 'Confirmed'
                                                      ? 'RESOLVED'
                                                      : c.status.toUpperCase()),
                                            style: TextStyle(
                                              color:
                                                  (!resolved && c.isEscalated)
                                                  ? Colors.redAccent
                                                  : (resolved
                                                        ? Colors.green
                                                        : Colors.orange),
                                              fontSize: 10,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                        ),
                                        if (!resolved) ...[
                                          const Spacer(),
                                          ElevatedButton(
                                            onPressed: () =>
                                                widget.fs.updateComplaintStatus(
                                                  c.id,
                                                  'Resolved',
                                                ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: _kPrimary,
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 10,
                                                  ),
                                              textStyle: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w700,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              elevation: 0,
                                            ),
                                            child: const Text('Resolve'),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _StudentAttendanceCalendar extends StatefulWidget {
  final VistaUser student;
  final FirebaseService fs;
  const _StudentAttendanceCalendar({required this.student, required this.fs});

  @override
  State<_StudentAttendanceCalendar> createState() =>
      _StudentAttendanceCalendarState();
}

class _StudentAttendanceCalendarState
    extends State<_StudentAttendanceCalendar> {
  CalendarFormat _format = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: _kPrimary,
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Room ${widget.student.roomNumber ?? 'N/A'}',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
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
              stream: widget.fs.getStudentAttendance(widget.student.uid),
              builder: (context, attendanceSnap) {
                return StreamBuilder<List<LeaveRequest>>(
                  stream: widget.fs.getStudentLeaves(widget.student.uid),
                  builder: (context, leaveSnap) {
                    if (attendanceSnap.connectionState ==
                            ConnectionState.waiting ||
                        leaveSnap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: _kPrimary),
                      );
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
                            selectedDayPredicate: (day) =>
                                isSameDay(_selectedDay, day),
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
                                border: Border.all(
                                  color: _kPrimary,
                                  width: 1.5,
                                ),
                                shape: BoxShape.circle,
                              ),
                              todayTextStyle: const TextStyle(
                                color: _kPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                              selectedDecoration: const BoxDecoration(
                                color: _kPrimary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            headerStyle: const HeaderStyle(
                              formatButtonVisible: true,
                              titleCentered: true,
                              formatButtonShowsNext: false,
                            ),
                            calendarBuilders: CalendarBuilders(
                              defaultBuilder: (context, day, focusedDay) {
                                final status = _getDayStatus(
                                  day,
                                  attendanceList,
                                  leaves,
                                );
                                if (status == null) return null;
                                return _buildCalendarDay(day, status);
                              },
                              outsideBuilder: (context, day, focusedDay) {
                                final status = _getDayStatus(
                                  day,
                                  attendanceList,
                                  leaves,
                                );
                                if (status == null) return null;
                                return Opacity(
                                  opacity: 0.5,
                                  child: _buildCalendarDay(day, status),
                                );
                              },
                            ),
                          ),
                          const SizedBox(height: 20),
                          _buildLegend(),
                          const SizedBox(height: 24),
                          if (_selectedDay != null)
                            _buildSelectedDayDetails(attendanceList, leaves),
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

  Widget _buildSelectedDayDetails(
    List<Attendance> attendance,
    List<LeaveRequest> leaves,
  ) {
    final status = _getDayStatus(_selectedDay!, attendance, leaves);
    if (status == null) return const SizedBox.shrink();

    final att = attendance.firstWhereOrNull(
      (a) => isSameDay(a.timestamp, _selectedDay),
    );

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'Present':
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
        statusColor = Colors.orange;
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (att != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Time: ${DateFormat('hh:mm a').format(att.timestamp)}',
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

  String? _getDayStatus(
    DateTime day,
    List<Attendance> attendance,
    List<LeaveRequest> leaves,
  ) {
    if (day.isAfter(DateTime.now())) return null;

    // Check attendance
    final att = attendance.firstWhereOrNull((a) => isSameDay(a.timestamp, day));
    if (att != null) return att.status; // Present, Late

    // Check leave
    final onLeave = leaves.any(
      (l) =>
          l.status == 'Approved' &&
          !day.isBefore(
            DateTime(l.fromDate.year, l.fromDate.month, l.fromDate.day),
          ) &&
          !day.isAfter(DateTime(l.toDate.year, l.toDate.month, l.toDate.day)),
    );
    if (onLeave) return 'On Leave';

    // If past day and no attendance/leave, marked as Absent
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
        color = Colors.green;
        break;
      case 'Late':
        color = Colors.yellow.shade700;
        break;
      case 'Absent':
        color = Colors.red;
        break;
      case 'On Leave':
        color = Colors.orange;
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
              _legendItem('On Leave', Colors.orange),
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
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }
}

class _ShortStaysTab extends StatefulWidget {
  final VistaUser warden;
  final FirebaseService fs;
  const _ShortStaysTab({super.key, required this.warden, required this.fs});

  @override
  State<_ShortStaysTab> createState() => _ShortStaysTabState();
}

class _ShortStaysTabState extends State<_ShortStaysTab> {
  String _statusFilter = 'Pending';
  String _searchQuery = '';
  final _searchCtrl = TextEditingController();

  Widget _buildFilterChip(String label) {
    final isSelected = _statusFilter == label;
    return InkWell(
      onTap: () => setState(() => _statusFilter = label),
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? _kPrimary : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: isSelected ? _kPrimary : Colors.grey.shade300,
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

  void _showApproveDialog(ShortStayRequest request) {
    final roomCtrl = TextEditingController();
    String? selectedHostel = 'BH1'; // Default

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Approve Short Stay'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Select Hostel and Room'),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedHostel,
                decoration: const InputDecoration(
                  labelText: 'Allot Hostel',
                  border: OutlineInputBorder(),
                ),
                items: ['BH1', 'BH2', 'GH1', 'GH2']
                    .map((h) => DropdownMenuItem(value: h, child: Text(h)))
                    .toList(),
                onChanged: (val) => setDialogState(() => selectedHostel = val),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: roomCtrl,
                decoration: const InputDecoration(
                  labelText: 'Room Number',
                  hintText: 'e.g. 101 or 104-D',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.text,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCEL'),
            ),
            ElevatedButton(
              onPressed: () {
                if (roomCtrl.text.trim().isEmpty || selectedHostel == null)
                  return;
                widget.fs.updateShortStayStatus(
                  request.id,
                  'Approved',
                  roomNumber: roomCtrl.text.trim(),
                  allotmentHostel: selectedHostel,
                );
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: const Text('APPROVE'),
            ),
          ],
        ),
      ),
    );
  }

  void export() => _showRangeExport();

  Future<void> _showRangeExport() async {
    final DateTimeRange? range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2025),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E3A8A), // _kPrimary
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Preparing Export...')));

      final stays = await widget.fs
          .getHostelShortStaysRange(
            widget.warden.hostel ?? 'All', // Head Warden can export 'All'
            range.start,
            range.end,
          )
          .first;

      await ExportHelper.exportShortStays(stays, widget.warden.hostel ?? 'All');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            children: [
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search by Student Name...',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  filled: true,
                  fillColor: _kBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
                onChanged: (v) => setState(() => _searchQuery = v),
              ),
              const SizedBox(height: 12),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('Pending'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Approved'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Completed'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Rejected'),
                    const SizedBox(width: 8),
                    _buildFilterChip('All'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<ShortStayRequest>>(
            stream: widget.fs.getHostelShortStays('All'),
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              var list = snap.data ?? [];

              // Apply filters
              if (_statusFilter != 'All') {
                list = list.where((r) => r.status == _statusFilter).toList();
              }
              if (_searchQuery.isNotEmpty) {
                list = list
                    .where(
                      (r) => r.studentName.toLowerCase().contains(
                        _searchQuery.toLowerCase(),
                      ),
                    )
                    .toList();
              }

              if (list.isEmpty) {
                return const _EmptyState(
                  icon: Icons.hotel_outlined,
                  title: 'No Requests Found',
                  subtitle: 'Pending short stay requests will appear here.',
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final r = list[i];
                  final isPending = r.status == 'Pending';
                  final isExtending = r.pendingToDate != null;

                  return _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.person,
                              color: _kPrimary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${r.seqId} - ${r.studentName}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (isExtending)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'EXTENSION PENDING',
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            else
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      (r.status == 'Approved'
                                              ? Colors.green
                                              : (r.status == 'Rejected'
                                                    ? Colors.red
                                                    : Colors.orange))
                                          .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  r.status.toUpperCase(),
                                  style: TextStyle(
                                    color: r.status == 'Approved'
                                        ? Colors.green
                                        : (r.status == 'Rejected'
                                              ? Colors.red
                                              : Colors.orange),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildReadOnlyInput(
                          'Student Details',
                          '${r.programme} · ${r.rollNo} · ${r.gender}\nEmail: ${r.email}\nPhone: ${r.contactNo}',
                          icon: Icons.info_outline,
                        ),
                        _buildReadOnlyInput(
                          'Reason for Stay',
                          r.reason,
                          icon: Icons.description_outlined,
                        ),
                        _buildReadOnlyInput(
                          'Duration',
                          '${DateFormat('dd MMM yyyy hh:mm a').format(r.checkInDate)} to \n${DateFormat('dd MMM yyyy hh:mm a').format(r.checkOutDate)}',
                          icon: Icons.date_range,
                        ),
                        if (isExtending)
                          _buildReadOnlyInput(
                            'Requested Extension',
                            DateFormat(
                              'dd MMM yyyy hh:mm a',
                            ).format(r.pendingToDate!),
                            icon: Icons.more_time,
                          ),
                        _buildReadOnlyInput(
                          'Parent',
                          '${r.parentName} (${r.parentContact})',
                          icon: Icons.family_restroom,
                        ),
                        if (r.roomNumber != null)
                          _buildReadOnlyInput(
                            'Room',
                            r.roomNumber!,
                            icon: Icons.room,
                          ),
                        if (isPending) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => widget.fs
                                      .updateShortStayStatus(r.id, 'Rejected'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red,
                                    side: const BorderSide(color: Colors.red),
                                  ),
                                  child: const Text('REJECT'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () => _showApproveDialog(r),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('APPROVE'),
                                ),
                              ),
                            ],
                          ),
                        ] else if (isExtending) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () =>
                                      widget.fs.approveShortStayExtension(
                                        r.id,
                                        r.pendingToDate!,
                                      ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _kPrimary,
                                    foregroundColor: Colors.white,
                                  ),
                                  child: const Text('APPROVE EXTENSION'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildReadOnlyInput(
    String label,
    String value, {
    IconData? icon,
    Widget? trailing,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: _kBg.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kPrimary.withValues(alpha: 0.05)),
        ),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: _kPrimary.withValues(alpha: 0.5)),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _kPrimary.withValues(alpha: 0.4),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            trailing ?? const SizedBox.shrink(),
          ],
        ),
      ),
    );
  }
}

extension _ListExt<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
