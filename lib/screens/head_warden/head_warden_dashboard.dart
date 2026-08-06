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
import 'tabs/students_tab.dart';
import 'tabs/attendance_tab.dart';
import 'tabs/leaves_tab.dart';
import 'tabs/complaints_tab.dart';
import 'tabs/short_stay_tab.dart';

import '../../widgets/common/skeleton_loader.dart';
import '../../providers/warden_provider.dart';
import '../../widgets/common/web_dashboard_scaffold.dart';



class HeadWardenDashboard extends StatefulWidget {
  const HeadWardenDashboard({super.key});

  @override
  State<HeadWardenDashboard> createState() => _HeadWardenDashboardState();
}

class _HeadWardenDashboardState extends State<HeadWardenDashboard> {
  final FirebaseService _fs = FirebaseService();
  int _selectedIndex = 0;
  late PageController _pageController;
  final List<GlobalKey> _tabKeys = List.generate(5, (index) => GlobalKey());
  static bool _autoEscalateRanThisSession = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    if (!_autoEscalateRanThisSession) {
      _autoEscalateRanThisSession = true;
      _fs.autoEscalateOverdueComplaints('Head Warden');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
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
          await ExportHelper.exportStudentsMultiHostel(
            students,
            startDate: result.startDate,
            endDate: result.endDate,
          );
          break;

        case ExportType.leaveRequests:
          final students = await _fs.getHostelStudents('All').first;
          final leaves = await _fs
              .getHostelLeavesRange('All', result.startDate, result.endDate)
              .first;
          await ExportHelper.exportLeavesMultiHostel(
            leaves,
            students,
            startDate: result.startDate,
            endDate: result.endDate,
          );
          break;

        case ExportType.complaints:
          final complaints = await _fs
              .getHostelComplaintsRange('All', result.startDate, result.endDate)
              .first;
          await ExportHelper.exportComplaintsMultiHostel(
            complaints,
            startDate: result.startDate,
            endDate: result.endDate,
          );
          break;

        case ExportType.shortStays:
          final shortStays = await _fs
              .getHostelShortStaysRange('All', result.startDate, result.endDate)
              .first;
          await ExportHelper.exportShortStaysMultiHostel(
            shortStays,
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
      StudentsTab(key: _tabKeys[0], warden: warden, fs: _fs, onExport: _showExportDialog),
      AttendanceTab(key: _tabKeys[1], warden: warden, fs: _fs),
      LeavesTab(key: _tabKeys[2], warden: warden, fs: _fs),
      ComplaintsTab(key: _tabKeys[3], warden: warden, fs: _fs),
      ShortStayTab(key: _tabKeys[4], warden: warden, fs: _fs),
    ];

    return ChangeNotifierProvider<WardenProvider>(
      create: (_) => WardenProvider('', role: 'Head Warden'),
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

