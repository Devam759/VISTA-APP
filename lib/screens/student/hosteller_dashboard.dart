import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../providers/auth_provider.dart';
import '../../services/firebase_service.dart';
import '../../models/vista_user.dart';
import '../../services/notification_service.dart';
import '../../widgets/common/vista_loader.dart';

// Modular components and tabs
import 'widgets/student_components.dart';
import 'tabs/attendance_tab.dart';
import 'tabs/leave_tab.dart';
import 'tabs/complaints_tab.dart';
import 'tabs/short_stay_tab.dart';
import '../mess/mess_screen.dart';
import '../../widgets/common/smooth_animations.dart';
import '../../widgets/dialogs/dev_info_sheet.dart';

class HostellerDashboard extends StatefulWidget {
  const HostellerDashboard({super.key});

  @override
  State<HostellerDashboard> createState() => _HostellerDashboardState();
}

class _HostellerDashboardState extends State<HostellerDashboard> {
  final FirebaseService _firebaseService = FirebaseService();
  int _selectedIndex = 0;
  late PageController _pageController;
  bool _checkingPermissions = !kIsWeb;
  bool _permissionsGranted = kIsWeb; // Default to true on web to bypass blocker
  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    if (!kIsWeb) {
      _checkPermissions();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupStudentListeners();
      if (!kIsWeb) {
        _initNotifications();
      }
    });
  }

  Future<void> _initNotifications() async {
    final user = Provider.of<AuthProvider>(context, listen: false).userProfile;
    if (user != null) {
      await NotificationService().init(user.uid);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  void _setupStudentListeners() {
    final user = Provider.of<AuthProvider>(context, listen: false).userProfile;
    if (user == null) return;

    if (!user.isApproved) {
      _subscriptions.add(
        _firebaseService.db.collection('users').doc(user.uid).snapshots().listen((snap) {
          if (snap.exists && (snap.data()?['isApproved'] ?? false)) {
            _showInAppAlert(
              'Account Approved!',
              'Your registration for ${snap.data()?['hostel']} is now active.',
            );
          }
        }),
      );
    }
  }

  void _showInAppAlert(String title, String body) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, color: kStudentPrimary)),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _checkPermissions() async {
    setState(() => _checkingPermissions = true);
    final status = await Permission.location.status;
    if (status.isGranted) {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      setState(() {
        _permissionsGranted = serviceEnabled;
        _checkingPermissions = false;
      });
    } else {
      final result = await Permission.location.request();
      setState(() {
        _permissionsGranted = result.isGranted;
        _checkingPermissions = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingPermissions) {
      return const Scaffold(
        backgroundColor: kStudentBg,
        body: Center(child: VISTALoader(size: 80, color: kStudentPrimary)),
      );
    }

    if (!_permissionsGranted) {
      return Scaffold(
        backgroundColor: kStudentBg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.location_off_rounded, size: 80, color: Colors.redAccent),
                const SizedBox(height: 24),
                const Text(
                  'Location Required',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: kStudentPrimary),
                ),
                const SizedBox(height: 12),
                const Text(
                  'This app requires location access for geofenced attendance. Please enable location permissions in settings.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => openAppSettings(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kStudentPrimary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: const Text('Open Settings'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _checkPermissions,
                  child: const Text('Check Again', style: TextStyle(color: kStudentPrimary)),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.userProfile;

    if (user == null) {
      return Scaffold(
        backgroundColor: kStudentBg,
        body: const Center(child: VISTALoader(size: 35, color: kStudentPrimary)),
      );
    }

    return Stack(
      children: [
        Scaffold(
          backgroundColor: kStudentBg,
          body: SafeArea(
            child: Column(
              children: [
                _buildHeader(context, user, authProvider),
                Expanded(
                  child: SmoothEntrance(
                    delay: const Duration(milliseconds: 200),
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(24),
                          topRight: Radius.circular(24),
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(32),
                          topRight: Radius.circular(32),
                        ),
                        child: PageView(
                          controller: _pageController,
                          onPageChanged: (index) => setState(() => _selectedIndex = index),
                          children: [
                            AttendanceTab(
                              user: user,
                              fs: _firebaseService,
                              isActive: _selectedIndex == 0,
                            ),
                            const MessScreen(),
                            LeaveTab(user: user, fs: _firebaseService),
                            ComplaintsTab(user: user, fs: _firebaseService),
                            if (user.hostel == 'Short Stay' || user.hasUsedShortStay)
                              ShortStayTab(user: user, fs: _firebaseService),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: kStudentPrimary.withValues(alpha: 0.08),
                  blurRadius: 20,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (index) {
                if (_selectedIndex == index) return;
                _pageController.animateToPage(
                  index,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
              elevation: 0,
              backgroundColor: Colors.transparent,
              selectedItemColor: kStudentPrimary,
              unselectedItemColor: Colors.black26,
              showUnselectedLabels: true,
              type: BottomNavigationBarType.fixed,
              selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.assignment_ind_outlined),
                  activeIcon: Icon(Icons.assignment_ind_rounded),
                  label: 'Attendance',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.restaurant_outlined),
                  activeIcon: Icon(Icons.restaurant_rounded),
                  label: 'Mess',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.event_note_outlined),
                  activeIcon: Icon(Icons.event_note_rounded),
                  label: 'Leaves',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.assignment_late_outlined),
                  activeIcon: Icon(Icons.assignment_late_rounded),
                  label: 'Complaints',
                ),
                if (user.hostel == 'Short Stay' || user.hasUsedShortStay)
                  const BottomNavigationBarItem(
                    icon: Icon(Icons.hotel_outlined),
                    activeIcon: Icon(Icons.hotel_rounded),
                    label: 'Short Stay',
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, VistaUser user, AuthProvider authProvider) {
    return SmoothEntrance(
      delay: const Duration(milliseconds: 100),
      offset: const Offset(0, -20),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GestureDetector(
                    onTap: () => showDeveloperInfoSheet(context),
                    child: Row(
                      children: [
                        Image.asset('assets/images/jklu_logo_bgremove.png', height: 28),
                        const SizedBox(width: 8),
                        const Text(
                          'VISTA',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: kStudentPrimary,
                            letterSpacing: 2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hello, ${user.name.split(" ")[0]}',
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: Color(0xFF1E293B)),
                  ),
                ],
              ),
            ),
            IconButton(
              onPressed: () => authProvider.signOut(),
              tooltip: 'Logout',
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.logout_rounded, 
                  color: Colors.redAccent,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}
