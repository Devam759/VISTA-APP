import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/vista_user.dart';
import '../../models/attendance_model.dart';
import '../../models/leave_request_model.dart';
import '../../services/firebase_service.dart';
import '../../utils/export_helper.dart';
import '../../widgets/export_dialog.dart';
import 'tabs/students_tab.dart';
import 'tabs/attendance_tab.dart';
import 'tabs/leaves_tab.dart';
import 'tabs/complaints_tab.dart';
import 'tabs/short_stay_tab.dart';

import '../../widgets/skeleton_loader.dart';
import '../warden/components/warden_components.dart';


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
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
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
    final authProvider = Provider.of<AuthProvider>(context);
    final warden = authProvider.userProfile;

    if (warden == null) {
      return Scaffold(
        backgroundColor: _kBg,
        body: const DashboardSummarySkeleton(),
      );
    }

    final pages = [
      StudentsTab(key: _tabKeys[0], warden: warden, fs: _fs),
      AttendanceTab(key: _tabKeys[1], warden: warden, fs: _fs),
      LeavesTab(key: _tabKeys[2], warden: warden, fs: _fs),
      ComplaintsTab(key: _tabKeys[3], warden: warden, fs: _fs),
      ShortStayTab(key: _tabKeys[4], warden: warden, fs: _fs),
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

    return WardenResponsiveWrapper(
      child: Scaffold(
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
                              onPressed: () => authProvider.signOut(),
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
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: pages,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
  );
}
}

