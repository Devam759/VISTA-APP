import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/vista_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/warden_provider.dart';
import '../../services/firebase_service.dart';

import '../../widgets/common/skeleton_loader.dart';
import '../../widgets/dialogs/export_dialog.dart';
import '../../utils/export_helper.dart';
import 'tabs/students_tab.dart';
import 'tabs/attendance_tab.dart';
import 'tabs/leaves_tab.dart';
import 'tabs/complaints_tab.dart';
import 'tabs/short_stays_tab.dart';
import '../../widgets/common/hover_effect.dart';
import 'components/warden_components.dart';
import '../mess/mess_screen.dart';
import '../../widgets/common/smooth_animations.dart';
import '../../widgets/common/web_dashboard_scaffold.dart';

class WardenDashboard extends StatefulWidget {
  const WardenDashboard({super.key});

  @override
  State<WardenDashboard> createState() => _WardenDashboardState();
}

class _WardenDashboardState extends State<WardenDashboard> {
  late PageController _pageController;
  int _selectedIndex = 0;
  static bool _autoEscalateRanThisSession = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    if (!_autoEscalateRanThisSession) {
      _autoEscalateRanThisSession = true;
      FirebaseService().autoEscalateOverdueComplaints('Warden');
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onTabTapped(int index, WardenProvider wardenProv) {
    if (_selectedIndex == index) return;
    
    // Hide notification alert if we're on the target tab
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    setState(() {
      _selectedIndex = index;
    });
    
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
    
    // Clear the marker in the provider when the tab is visited
    wardenProv.clearMarker(index);
  }

  Future<void> _showExportDialog() async {
    final warden = Provider.of<AuthProvider>(context, listen: false).userProfile;
    if (warden == null) return;

    final result = await showDialog<ExportDialogResult>(
      context: context,
      builder: (context) => ExportDialog(hostel: warden.hostel ?? 'All'),
    );

    if (result == null) return;

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preparing Export...')));

    try {
      final fs = FirebaseService();
      switch (result.exportType) {
        case ExportType.attendance:
          final students = await fs.getHostelStudents(warden.hostel).first;
          final attendance = await fs.getHostelAttendanceRange(warden.hostel, result.startDate, result.endDate).first;
          final leaves = await fs.getHostelLeavesRange(warden.hostel, result.startDate, result.endDate).first;

          List<DateTime> dates = [];
          for (int i = 0; i <= result.endDate.difference(result.startDate).inDays; i++) {
            dates.add(result.startDate.add(Duration(days: i)));
          }

          await ExportHelper.exportAttendanceSummary(
            students,
            attendance,
            leaves,
            dates,
            warden.hostel ?? 'All',
            sortByRoomNumber: true,
          );
          break;

        case ExportType.students:
          final students = await fs.getHostelStudents(warden.hostel).first;
          await ExportHelper.exportStudents(students, warden.hostel ?? 'All', startDate: result.startDate, endDate: result.endDate);
          break;

        case ExportType.leaveRequests:
          final students = await fs.getHostelStudents(warden.hostel).first;
          final leaves = await fs.getHostelLeavesRange(warden.hostel, result.startDate, result.endDate).first;
          await ExportHelper.exportLeaves(leaves, students, warden.hostel ?? 'All', startDate: result.startDate, endDate: result.endDate);
          break;

        case ExportType.complaints:
          final complaints = await fs.getHostelComplaintsRange(warden.hostel, result.startDate, result.endDate).first;
          await ExportHelper.exportComplaints(complaints, warden.hostel ?? 'All', startDate: result.startDate, endDate: result.endDate);
          break;

        case ExportType.shortStays:
          final shortStays = await fs.getHostelShortStaysRange(warden.hostel, result.startDate, result.endDate).first;
          await ExportHelper.exportShortStays(shortStays, warden.hostel ?? 'All', startDate: result.startDate, endDate: result.endDate);
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
        backgroundColor: kBg,
        body: const DashboardSummarySkeleton(),
      );
    }

    final pages = [
      StudentsTab(warden: warden, fs: FirebaseService(), onExport: _showExportDialog),
      AttendanceTab(warden: warden, fs: FirebaseService()),
      LeavesTab(warden: warden, fs: FirebaseService()),
      ComplaintsTab(warden: warden),
      ShortStaysTab(warden: warden),
      const MessScreen(),
    ];

    return ChangeNotifierProvider(
      create: (_) => WardenProvider(warden.hostel ?? ''),
      child: Consumer<WardenProvider>(
        builder: (context, wardenProv, _) {
          final items = [
            WebNavigationItem(
              icon: Icons.groups_outlined,
              selectedIcon: Icons.groups,
              label: 'Students',
              showBadge: wardenProv.hasNewRegistrations,
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
              showBadge: wardenProv.hasNewLeaves,
            ),
            WebNavigationItem(
              icon: Icons.assignment_late_outlined,
              selectedIcon: Icons.assignment_late,
              label: 'Complaints',
              showBadge: wardenProv.hasNewComplaints,
            ),
            WebNavigationItem(
              icon: Icons.hotel_outlined,
              selectedIcon: Icons.hotel,
              label: 'Short Stay',
              showBadge: wardenProv.hasNewShortStays,
            ),
            const WebNavigationItem(
              icon: Icons.restaurant_outlined,
              selectedIcon: Icons.restaurant,
              label: 'Mess',
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
            subtitle: getFullHostelName(warden.hostel),
            items: items,
            selectedIndex: _selectedIndex,
            onItemSelected: (i) => _onTabTapped(i, wardenProv),
            onSignOut: () => authProvider.signOut(),
            pages: pages,
            mobileChild: Scaffold(
              backgroundColor: kBg,
              bottomNavigationBar: _buildBottomNav(wardenProv),
              body: Column(
                children: [
                  _buildHeader(warden, authProvider),
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: (index) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        setState(() {
                          _selectedIndex = index;
                        });
                        wardenProv.clearMarker(index);
                      },
                      children: pages,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(VistaUser warden, AuthProvider authProvider) {
    return SmoothEntrance(
      key: const ValueKey('warden_portal_header'),
      delay: const Duration(milliseconds: 100),
      offset: const Offset(0, -20),
      child: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F2460), kPrimary, kAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Image.asset('assets/images/jklu_logo_darkbg_bgremove.png', height: 40),
                    const SizedBox(width: 10),
                    const Text('VISTA', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900, letterSpacing: 2)),
                    const Spacer(),
                    
                    // HOSTEL FILTER BUTTON (Visible for Head/Chief Warden)
                    if (warden.role == UserRole.headWarden || warden.role == UserRole.chiefWarden) ...[
                      Consumer<WardenProvider>(
                        builder: (context, wp, _) => GestureDetector(
                          onTap: () {
                            WardenUIUtils.showHostelFilter(
                              context: context,
                              currentFilter: wp.currentHostelFilter,
                              onSelected: (newHostel) => wp.updateHostelFilter(newHostel),
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.white24),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  wp.currentHostelFilter ?? 'All Hostels',
                                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900),
                                ),
                                const SizedBox(width: 4),
                                const Icon(Icons.keyboard_arrow_down_rounded, color: Colors.white70, size: 16),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ] else ...[
                      // Single Hostel Indicator for regular Warden
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
                        ),
                        child: Text(
                          warden.hostel ?? 'Hostel',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                    
                    const SizedBox(width: 8),
                    HoverEffect(
                      child: IconButton(
                        onPressed: () => authProvider.signOut(),
                        icon: const Icon(Icons.logout_rounded, color: Colors.white60, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Welcome ${warden.name} Sir',
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(WardenProvider wardenProv) {
    const labels = ['Students', 'Attendance', 'Leaves', 'Complaints', 'Short Stay', 'Mess'];
    const icons = [
      (off: Icons.groups_outlined, on: Icons.groups),
      (off: Icons.assignment_ind_outlined, on: Icons.assignment_ind),
      (off: Icons.event_note_outlined, on: Icons.event_note),
      (off: Icons.assignment_late_outlined, on: Icons.assignment_late),
      (off: Icons.hotel_outlined, on: Icons.hotel),
      (off: Icons.restaurant_outlined, on: Icons.restaurant),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -4)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Container(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(6, (i) {
              final selected = _selectedIndex == i;
              final showMarker = (i == 0 && wardenProv.hasNewRegistrations) || 
                                 (i == 2 && wardenProv.hasNewLeaves) || 
                                 (i == 3 && wardenProv.hasNewComplaints) || 
                                 (i == 4 && wardenProv.hasNewShortStays);

              return HoverEffect(
                child: GestureDetector(
                  onTap: () => _onTabTapped(i, wardenProv),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: selected ? kPrimary.withValues(alpha: 0.1) : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(selected ? icons[i].on : icons[i].off, size: 22, color: selected ? kPrimary : Colors.black38),
                            if (showMarker)
                              Positioned(top: -2, right: -2, child: Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle))),
                          ],
                        ),
                        if (selected) ...[
                          const SizedBox(width: 8),
                          Text(labels[i], style: const TextStyle(color: kPrimary, fontSize: 13, fontWeight: FontWeight.w800)),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
