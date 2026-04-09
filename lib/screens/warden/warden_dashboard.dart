import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/vista_user.dart';
import '../../providers/auth_provider.dart';
import '../../providers/warden_provider.dart';
import '../../services/firebase_service.dart';

import '../../widgets/skeleton_loader.dart';
import '../../widgets/export_dialog.dart';
import '../../utils/export_helper.dart';
import 'tabs/students_tab.dart';
import 'tabs/attendance_tab.dart';
import 'tabs/leaves_tab.dart';
import 'tabs/complaints_tab.dart';
import 'tabs/short_stays_tab.dart';
import 'components/warden_components.dart';

class WardenDashboard extends StatefulWidget {
  const WardenDashboard({super.key});

  @override
  State<WardenDashboard> createState() => _WardenDashboardState();
}

class _WardenDashboardState extends State<WardenDashboard> {
  int _selectedIndex = 0;

  void _onTabTapped(int index, WardenProvider wardenProv) {
    setState(() {
      _selectedIndex = index;
    });
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
        backgroundColor: kBg,
        body: const DashboardSummarySkeleton(),
      );
    }

    return WardenResponsiveWrapper(
      child: ChangeNotifierProvider(
        create: (_) => WardenProvider(warden.hostel ?? ''),
        child: Consumer<WardenProvider>(
          builder: (context, wardenProv, _) {
            return Scaffold(
              backgroundColor: kBg,
              bottomNavigationBar: _buildBottomNav(wardenProv),
              body: Column(
                children: [
                  _buildHeader(warden, authProvider),
                  Expanded(
                    child: IndexedStack(
                      index: _selectedIndex,
                      children: [
                         StudentsTab(warden: warden),
                         AttendanceTab(warden: warden),
                         LeavesTab(warden: warden),
                         ComplaintsTab(warden: warden),
                         ShortStaysTab(warden: warden),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }
        ),
      ),
    );
  }

  Widget _buildHeader(VistaUser warden, AuthProvider authProvider) {
    return Container(
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
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(12)),
                    child: Text(warden.hostel ?? 'Hostel', style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _showExportDialog,
                    icon: const Icon(Icons.file_download_outlined, color: Colors.white, size: 22),
                    tooltip: 'Export Data',
                  ),
                  IconButton(
                    onPressed: () => authProvider.signOut(),
                    icon: const Icon(Icons.logout_rounded, color: Colors.white60, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                '$_greeting, ${warden.name}',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600, letterSpacing: -0.2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNav(WardenProvider wardenProv) {
    const labels = ['Students', 'Attendance', 'Leaves', 'Complaints', 'Short Stay'];
    const icons = [
      (off: Icons.groups_outlined, on: Icons.groups),
      (off: Icons.assignment_ind_outlined, on: Icons.assignment_ind),
      (off: Icons.event_note_outlined, on: Icons.event_note),
      (off: Icons.assignment_late_outlined, on: Icons.assignment_late),
      (off: Icons.hotel_outlined, on: Icons.hotel),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 20, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(5, (i) {
              final selected = _selectedIndex == i;
              final showMarker = (i == 0 && wardenProv.hasNewRegistrations) || 
                                 (i == 2 && wardenProv.hasNewLeaves) || 
                                 (i == 3 && wardenProv.hasNewComplaints) || 
                                 (i == 4 && wardenProv.hasNewShortStays);

              return GestureDetector(
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
              );
            }),
          ),
        ),
      ),
    );
  }
}
