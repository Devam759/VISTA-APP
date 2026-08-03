import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/vista_user.dart';
import '../../models/attendance_model.dart';
import '../../models/leave_request_model.dart';
import '../../services/firebase_service.dart';
import '../../utils/export_helper.dart';
import '../../widgets/dialogs/export_dialog.dart';
import '../../widgets/common/skeleton_loader.dart';
import '../../providers/warden_provider.dart';

// Tabs
import 'tabs/students_tab.dart';
import 'tabs/attendance_tab.dart';
import 'tabs/leaves_tab.dart';
import 'tabs/complaints_tab.dart';
import 'tabs/short_stay_tab.dart';
import '../../widgets/mess/mess_scanner_tab.dart';
import '../../widgets/mess/mess_weekly_editor_tab.dart';
import '../../widgets/mess/mess_scan_logs_tab.dart';
import '../../widgets/mess/mess_feedback_analytics_view.dart';
import '../../widgets/common/web_dashboard_scaffold.dart';

const _kPrimary = Color(0xFF1E3A8A);
const _kBg = Color(0xFFF0F4FF);

class ChiefWardenDashboard extends StatefulWidget {
  const ChiefWardenDashboard({super.key});

  @override
  State<ChiefWardenDashboard> createState() => _ChiefWardenDashboardState();
}

class _ChiefWardenDashboardState extends State<ChiefWardenDashboard> {
  final FirebaseService _fs = FirebaseService();
  int _selectedIndex = 0;
  late PageController _pageController;
  final List<StreamSubscription> _subscriptions = [];
  
  // Activity Markers
  bool _hasNewRegistrations = false;
  bool _hasNewLeaves = false;
  bool _hasNewComplaints = false;
  bool _hasNewShortStays = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    _setupChiefWardenListeners();
  }

  @override
  void dispose() {
    _pageController.dispose();
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
    
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preparing Export...')));

    try {
      switch (result.exportType) {
        case ExportType.attendance:
          List<DateTime> dates = [];
          for (int i = 0; i <= result.endDate.difference(result.startDate).inDays; i++) {
            dates.add(result.startDate.add(Duration(days: i)));
          }

          final hostelNames = ['BH1', 'BH2', 'GH1', 'GH2'];
          final Map<String, List<VistaUser>> hostelStudents = {};
          final Map<String, List<Attendance>> hostelAttendance = {};
          final Map<String, List<LeaveRequest>> hostelLeaves = {};

          for (final hostel in hostelNames) {
            hostelStudents[hostel] = await _fs.getHostelStudents(hostel).first;
            hostelAttendance[hostel] = await _fs.getHostelAttendanceRange(hostel, result.startDate, result.endDate).first;
            hostelLeaves[hostel] = await _fs.getHostelLeavesRange(hostel, result.startDate, result.endDate).first;
          }

          await ExportHelper.exportAttendanceSummaryMultiHostel(hostelStudents, hostelAttendance, hostelLeaves, dates);
          break;

        case ExportType.students:
          final students = await _fs.getHostelStudents('All').first;
          await ExportHelper.exportStudents(students, 'All', startDate: result.startDate, endDate: result.endDate);
          break;

        case ExportType.leaveRequests:
          final students = await _fs.getHostelStudents('All').first;
          final leaves = await _fs.getHostelLeavesRange('All', result.startDate, result.endDate).first;
          await ExportHelper.exportLeaves(leaves, students, 'All', startDate: result.startDate, endDate: result.endDate);
          break;

        case ExportType.complaints:
          final complaints = await _fs.getHostelComplaintsRange('All', result.startDate, result.endDate).first;
          await ExportHelper.exportComplaints(complaints, 'All', startDate: result.startDate, endDate: result.endDate);
          break;

        case ExportType.shortStays:
          final shortStays = await _fs.getHostelShortStaysRange('All', result.startDate, result.endDate).first;
          await ExportHelper.exportShortStays(shortStays, 'All', startDate: result.startDate, endDate: result.endDate);
          break;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export completed successfully!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  void _setupChiefWardenListeners() {
    _subscriptions.add(
      _fs.getPendingRegistrations('All').listen((list) {
        if (list.isNotEmpty) {
          if (_selectedIndex != 0) setState(() => _hasNewRegistrations = true);
          _showInAppAlert('New Registration Request', '${list.length} students pending', 0);
        } else {
          setState(() => _hasNewRegistrations = false);
        }
      }),
    );

    _subscriptions.add(
      _fs.getPendingLeaves('All').listen((list) {
        if (list.isNotEmpty) {
          if (_selectedIndex != 2) setState(() => _hasNewLeaves = true);
        } else {
          setState(() => _hasNewLeaves = false);
        }
      }),
    );

    _subscriptions.add(
      _fs.getComplaintsForRole('Chief Warden', 'All').listen((list) {
        final pending = list.where((c) => c.status == 'Pending').toList();
        if (pending.isNotEmpty) {
          if (_selectedIndex != 3) setState(() => _hasNewComplaints = true);
          _showInAppAlert('New Complaint Received', pending.first.title, 3);
        } else {
          setState(() => _hasNewComplaints = false);
        }
      }),
    );

    _subscriptions.add(
      _fs.getPendingShortStays('All').listen((list) {
        if (list.isNotEmpty) {
          if (_selectedIndex != 4) setState(() => _hasNewShortStays = true);
          _showInAppAlert('Short Stay Request', '${list.length} pending requests', 4);
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
          onPressed: () => _onTabTapped(targetIndex),
        ),
      ),
    );
  }

  void _onTabTapped(int index) {
    if (_selectedIndex == index) return;
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    _clearMarkers(index);
  }

  void _clearMarkers(int index) {
    if (!mounted) return;
    // Hide notification alert if we're on the target tab
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    
    setState(() {
      _selectedIndex = index;
      if (index == 0) _hasNewRegistrations = false;
      if (index == 2) _hasNewLeaves = false;
      if (index == 3) _hasNewComplaints = false;
      if (index == 4) _hasNewShortStays = false;
    });
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
      StudentsTab(warden: warden, fs: _fs, onExport: _showExportDialog),
      AttendanceTab(warden: warden, fs: _fs),
      LeavesTab(warden: warden, fs: _fs),
      ComplaintsTab(warden: warden, fs: _fs),
      ShortStayTab(warden: warden, fs: _fs),
      MessScannerTab(isActive: _selectedIndex == 5),
      const MessWeeklyEditorTab(),
      const MessScanLogsTab(),
      const MessFeedbackAnalyticsView(),
    ];

    return ChangeNotifierProvider<WardenProvider>(
      create: (_) => WardenProvider('All', role: 'Chief Warden'),
      child: Consumer<WardenProvider>(
        builder: (context, wp, _) {
          final items = [
            WebNavigationItem(
              icon: Icons.groups_outlined,
              selectedIcon: Icons.groups,
              label: 'Students',
              showBadge: _hasNewRegistrations,
            ),
            const WebNavigationItem(
              icon: Icons.assignment_ind_outlined,
              selectedIcon: Icons.assignment_ind,
              label: 'Attendance',
            ),
            WebNavigationItem(
              icon: Icons.event_note_outlined,
              selectedIcon: Icons.event_note,
              label: 'Leaves',
              showBadge: _hasNewLeaves,
            ),
            WebNavigationItem(
              icon: Icons.assignment_late_outlined,
              selectedIcon: Icons.assignment_late,
              label: 'Complaints',
              showBadge: _hasNewComplaints,
            ),
            WebNavigationItem(
              icon: Icons.hotel_outlined,
              selectedIcon: Icons.hotel,
              label: 'Short Stay',
              showBadge: _hasNewShortStays,
            ),
            const WebNavigationItem(
              icon: Icons.restaurant_outlined,
              selectedIcon: Icons.restaurant,
              label: 'Mess',
              subItems: [
                WebNavigationSubItem(label: 'Scanner', icon: Icons.qr_code_scanner_rounded, pageIndex: 5),
                WebNavigationSubItem(label: 'Weekly Menu', icon: Icons.restaurant_menu_rounded, pageIndex: 6),
                WebNavigationSubItem(label: 'Scan Logs', icon: Icons.fact_check_rounded, pageIndex: 7),
                WebNavigationSubItem(label: 'Feedback', icon: Icons.analytics_rounded, pageIndex: 8),
              ],
            ),
            WebNavigationItem(
              icon: Icons.file_download_outlined,
              selectedIcon: Icons.file_download,
              label: 'Export Data',
              onTap: _showExportDialog,
            ),
          ];

          return WebDashboardScaffold(
            title: 'VISTA',
            roleBadge: warden.role.displayName,
            userName: warden.name,
            hostelFilter: wp.currentHostelFilter ?? 'All',
            onHostelFilterChanged: (h) => wp.setHostelFilter(h),
            items: items,
            selectedIndex: _selectedIndex,
            onItemSelected: (i) => _onTabTapped(i),
            onSignOut: () => authProvider.signOut(),
            pages: pages,
          );
        },
      ),
    );
  }
}
