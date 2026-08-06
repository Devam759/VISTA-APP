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

class ChiefWardenDashboard extends StatefulWidget {
  const ChiefWardenDashboard({super.key});

  @override
  State<ChiefWardenDashboard> createState() => _ChiefWardenDashboardState();
}

class _ChiefWardenDashboardState extends State<ChiefWardenDashboard> {
  final FirebaseService _fs = FirebaseService();
  int _selectedIndex = 0;
  late PageController _pageController;
  static bool _autoEscalateRanThisSession = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    if (!_autoEscalateRanThisSession) {
      _autoEscalateRanThisSession = true;
      _fs.autoEscalateOverdueComplaints('Chief Warden');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index, WardenProvider wp) {
    if (_selectedIndex == index) return;
    setState(() => _selectedIndex = index);
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    wp.clearMarker(index);
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
          await ExportHelper.exportStudentsMultiHostel(students, startDate: result.startDate, endDate: result.endDate);
          break;

        case ExportType.leaveRequests:
          final students = await _fs.getHostelStudents('All').first;
          final leaves = await _fs.getHostelLeavesRange('All', result.startDate, result.endDate).first;
          await ExportHelper.exportLeavesMultiHostel(leaves, students, startDate: result.startDate, endDate: result.endDate);
          break;

        case ExportType.complaints:
          final complaints = await _fs.getHostelComplaintsRange('All', result.startDate, result.endDate).first;
          await ExportHelper.exportComplaintsMultiHostel(complaints, startDate: result.startDate, endDate: result.endDate);
          break;

        case ExportType.shortStays:
          final shortStays = await _fs.getHostelShortStaysRange('All', result.startDate, result.endDate).first;
          await ExportHelper.exportShortStaysMultiHostel(shortStays, startDate: result.startDate, endDate: result.endDate);
          break;
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Export completed successfully!')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final warden = authProvider.userProfile;

    if (warden == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0F4FF),
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
              showBadge: wp.hasNewRegistrations,
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
              showBadge: wp.hasNewLeaves,
            ),
            WebNavigationItem(
              icon: Icons.assignment_late_outlined,
              selectedIcon: Icons.assignment_late,
              label: 'Complaints',
              showBadge: wp.hasNewComplaints,
            ),
            WebNavigationItem(
              icon: Icons.hotel_outlined,
              selectedIcon: Icons.hotel,
              label: 'Short Stay',
              showBadge: wp.hasNewShortStays,
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
            onItemSelected: (i) => _onTabTapped(i, wp),
            onSignOut: () => authProvider.signOut(),
            pages: pages,
          );
        },
      ),
    );
  }
}
