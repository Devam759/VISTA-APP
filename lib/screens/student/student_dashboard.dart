import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../utils/sanitizer.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'face_capture_screen.dart'
    if (dart.library.html) 'face_capture_screen_stub.dart';
import '../../providers/auth_provider.dart';
import '../../models/attendance_model.dart';
import '../../models/leave_request_model.dart';
import '../../models/complaint_model.dart';
import '../../models/short_stay_model.dart';
import '../../services/firebase_service.dart';
import '../../models/vista_user.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/security_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../widgets/skeleton_loader.dart';

// ─────────────────────────────────────────────────────────────────────────────
// THEME CONSTANTS (Consistent with Warden portal for unified feel)
// ─────────────────────────────────────────────────────────────────────────────
const _kPrimary = Color(0xFF1E3A8A);
const _kAccent = Color(0xFF2563EB);
const _kBg = Color(0xFFF0F4FF);
const _kSuccess = Color(0xFF10B981);
const _kWarning = Color(0xFFF59E0B);

class StudentDashboard extends StatefulWidget {
  const StudentDashboard({super.key});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  final FirebaseService _firebaseService = FirebaseService();
  int _selectedIndex = 0;
  bool _checkingPermissions = true;
  bool _permissionsGranted = false;
  final List<StreamSubscription> _subscriptions = [];

  @override
  void initState() {
    super.initState();
    _checkPermissions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _setupStudentListeners();
    });
  }

  @override
  void dispose() {
    for (var sub in _subscriptions) {
      sub.cancel();
    }
    super.dispose();
  }

  void _setupStudentListeners() {
    final user = Provider.of<AuthProvider>(context, listen: false).userProfile;
    if (user == null) return;

    // 1. Listen for Account Approval (if not already approved)
    if (!user.isApproved) {
      _subscriptions.add(
        _firebaseService.db.collection('users').doc(user.uid).snapshots().listen((
          snap,
        ) {
          if (snap.exists && (snap.data()?['isApproved'] ?? false)) {
            _showInAppAlert(
              'Account Approved!',
              'Your registration for ${snap.data()?['hostel']} is now active.',
            );
          }
        }),
      );
    }

    // 2. Listen for Leave Updates
    _subscriptions.add(
      _firebaseService.getStudentLeaves(user.uid).listen((list) {
        // We only care about things that changed status recently (local logic or comparing with cached)
        // For simplicity in-app, we can show an alert if any 'Approved' or 'Rejected' exists that wasn't there before
      }),
    );

    // 3. Listen for Complaint Updates
    _subscriptions.add(
      _firebaseService.getStudentComplaints(user.uid).listen((list) {
        // Similar logic for complaints
      }),
    );
  }

  void _showInAppAlert(String title, String message) {
    if (!mounted) return;
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
        duration: const Duration(seconds: 5),
      ),
    );
  }

  Future<void> _checkPermissions() async {
    if (kIsWeb) {
      if (mounted) {
        setState(() {
          _checkingPermissions = false;
          _permissionsGranted = true;
        });
      }
      return;
    }

    final locationStatus = await Permission.location.request();
    final cameraStatus = await Permission.camera.request();

    if (mounted) {
      setState(() {
        _checkingPermissions = false;
        _permissionsGranted =
            locationStatus.isGranted && cameraStatus.isGranted;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingPermissions) {
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_permissionsGranted && !kIsWeb) {
      return Scaffold(
        backgroundColor: _kBg,
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.security_rounded, size: 64, color: _kWarning),
                const SizedBox(height: 24),
                const Text(
                  'Permissions Required',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: _kPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Location and Camera permissions are strictly required to use the VISTA Mobile App for security purposes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    openAppSettings();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _kPrimary,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Open Settings',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: _checkPermissions,
                  child: const Text(
                    'Check Again',
                    style: TextStyle(color: _kPrimary),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final user = Provider.of<AuthProvider>(context).userProfile!;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, user),
            Expanded(
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
                  child: IndexedStack(
                    index: _selectedIndex,
                    children: [
                      _AttendanceTab(
                        user: user,
                        fs: _firebaseService,
                        isActive: _selectedIndex == 0,
                      ),
                      if (user.hostel != 'Short Stay')
                        _LeaveTab(user: user, fs: _firebaseService),
                      if (user.hostel != 'Short Stay')
                        _ComplaintsTab(user: user, fs: _firebaseService),
                      if (user.hostel == 'Short Stay' || user.hasUsedShortStay)
                        _ShortStayTab(user: user, fs: _firebaseService),
                    ],
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
              color: _kPrimary.withValues(alpha: 0.08),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          elevation: 0,
          backgroundColor: Colors.transparent,
          selectedItemColor: _kPrimary,
          unselectedItemColor: Colors.black26,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.assignment_ind_outlined),
              activeIcon: Icon(Icons.assignment_ind_rounded),
              label: 'Attendance',
            ),
            if (user.hostel != 'Short Stay')
              const BottomNavigationBarItem(
                icon: Icon(Icons.event_note_outlined),
                activeIcon: Icon(Icons.event_note_rounded),
                label: 'Leaves',
              ),
            if (user.hostel != 'Short Stay')
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
    );
  }

  Widget _buildHeader(BuildContext context, VistaUser user) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset('assets/images/jklu_logo_bgremove.png', height: 40),
              const SizedBox(width: 12),
              const Text(
                'VISTA',
                style: TextStyle(
                  color: _kPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
              const Spacer(),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => _firebaseService.signOut(),
                icon: const Icon(
                  Icons.power_settings_new_rounded,
                  color: Colors.black26,
                  size: 22,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'STUDENT PORTAL',
                style: TextStyle(
                  color: _kPrimary.withValues(alpha: 0.4),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                user.name.toUpperCase(),
                style: const TextStyle(
                  color: _kPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ATTENDANCE TAB
// ─────────────────────────────────────────────────────────────────────────────
class _AttendanceTab extends StatefulWidget {
  final VistaUser user;
  final FirebaseService fs;
  final bool isActive;
  const _AttendanceTab({
    required this.user,
    required this.fs,
    required this.isActive,
  });

  @override
  State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab> {
  bool _isMarking = false;
  bool _isCheckingIn = false;
  bool _isRealDevice = true;

  @override
  void initState() {
    super.initState();
    _checkDevice();
  }

  Future<void> _checkDevice() async {
    final isReal = await SecurityService.isRealDevice();
    if (mounted) {
      setState(() {
        _isRealDevice = isReal;
      });
    }
  }

  void _handleLeaveCheckIn(String leaveId) async {
    setState(() => _isCheckingIn = true);
    try {
      // Use geofence to verify student is actually on campus
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showError('Location services are disabled.');
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        _showError('Location permissions are denied.');
        return;
      }
      Position position = await Geolocator.getCurrentPosition();
      bool inside = _isPointInGeofence(position.latitude, position.longitude);
      if (!inside) {
        _showError('You must be inside the campus to check-in from leave.');
        return;
      }

      await widget.fs.checkInFromLeave(leaveId);
      _showSuccess('Checked in! You can now mark attendance.');
    } catch (e) {
      _showError('Failed to check-in: $e');
    } finally {
      if (mounted) setState(() => _isCheckingIn = false);
    }
  }

  bool _isValidTime() {
    final now = DateTime.now();
    // 10:00 PM to 12:00 AM (midnight)
    return now.hour >= 22;
  }

  bool _isWithinGracePeriod() {
    final now = DateTime.now();
    // 10:00 PM to 10:29 PM
    return now.hour == 22 && now.minute < 30;
  }

  bool _isLate() {
    final now = DateTime.now();
    // 10:30 PM to 12:00 AM (midnight)
    return (now.hour == 22 && now.minute >= 30) || (now.hour == 23);
  }

  bool _isStudentOnLeave(List<LeaveRequest> approvedLeaves) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return approvedLeaves.any((leave) {
      if (leave.status != 'Approved') return false;
      if (leave.checkInTime != null) return false;
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
      return !today.isBefore(from) && !today.isAfter(to);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb || !_isRealDevice) {
      return Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, _kPrimary.withValues(alpha: 0.02)],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.mobile_friendly_rounded,
                      size: 80,
                      color: _kPrimary,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Mobile Only Feature',
                    style: GoogleFonts.outfit(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: _kPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Text(
                      'For security and accurate location verification, attendance marking is exclusively available on the VISTA mobile app.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        color: Colors.black54,
                        fontSize: 16,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 48),
                  Text(
                    'Download the App',
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black38,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    alignment: WrapAlignment.center,
                    children: [
                      _buildDownloadButton(Icons.apple, 'App Store'),
                      _buildDownloadButton(Icons.android_rounded, 'Play Store'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return StreamBuilder<List<LeaveRequest>>(
      stream: widget.fs.getStudentLeaves(widget.user.uid),
      builder: (context, leaveSnap) {
        return StreamBuilder<List<ShortStayRequest>>(
          stream: widget.fs.getStudentShortStays(widget.user.uid),
          builder: (context, staySnap) {
            // Early exit if snapshots are still loading to avoid build flutters
            if (leaveSnap.connectionState == ConnectionState.waiting ||
                staySnap.connectionState == ConnectionState.waiting) {
              return const AttendanceListSkeleton();
            }

            final approvedLeaves = (leaveSnap.data ?? [])
                .where((l) => l.status == 'Approved')
                .toList();
            final onLeave = _isStudentOnLeave(approvedLeaves);

            final approvedStays = (staySnap.data ?? [])
                .where((s) => s.status == 'Approved')
                .toList();

            bool hasValidStay = true;
            if (widget.user.hostel == 'Short Stay') {
              final now = DateTime.now();
              final today = DateTime(now.year, now.month, now.day);
              hasValidStay = approvedStays.any((stay) {
                final from = DateTime(
                  stay.checkInDate.year,
                  stay.checkInDate.month,
                  stay.checkInDate.day,
                );
                final to = DateTime(
                  stay.checkOutDate.year,
                  stay.checkOutDate.month,
                  stay.checkOutDate.day,
                );
                return !today.isBefore(from) && !today.isAfter(to);
              });
            }

            return ListView(
              padding: const EdgeInsets.all(24),
              children: [
                _SectionLabel("Night Attendance"),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _kPrimary.withValues(alpha: 0.05),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _kPrimary.withValues(alpha: 0.03),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'Reporting Window',
                        style: TextStyle(
                          color: Colors.black45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Text(
                        '10:00 PM - 10:30 PM',
                        style: TextStyle(
                          color: _kPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Late: 10:30 PM - 11:59 PM',
                        style: TextStyle(
                          color: _kPrimary.withValues(alpha: 0.5),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 40),
                      GestureDetector(
                        onTap: (onLeave || !hasValidStay || _isMarking)
                            ? null
                            : _handleMarkAttendance,
                        child: Container(
                          width: 180,
                          height: 180,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            boxShadow: [
                              BoxShadow(
                                color: onLeave
                                    ? Colors.green.withValues(alpha: 0.1)
                                    : _isValidTime()
                                    ? (_isLate() ? _kWarning : _kPrimary)
                                          .withValues(alpha: 0.1)
                                    : Colors.black.withValues(alpha: 0.05),
                                blurRadius: 30,
                                spreadRadius: 5,
                              ),
                            ],
                          ),
                          child: Center(
                            child: Container(
                              width: 150,
                              height: 150,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  colors: onLeave
                                      ? [_kSuccess, Colors.green.shade700]
                                      : (hasValidStay && _isValidTime())
                                      ? (_isLate()
                                            ? [_kWarning, Colors.orange]
                                            : [_kPrimary, _kAccent])
                                      : [
                                          Colors.grey.shade300,
                                          Colors.grey.shade400,
                                        ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                              ),
                              child: Center(
                                child: onLeave
                                    ? const Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.event_available_rounded,
                                            color: Colors.white,
                                            size: 40,
                                          ),
                                          SizedBox(height: 8),
                                          Text(
                                            'ON LEAVE',
                                            style: TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ],
                                      )
                                    : _isMarking
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                    : Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.touch_app_rounded,
                                            color: Colors.white,
                                            size: 40,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            _isValidTime()
                                                ? (_isLate()
                                                      ? 'LATE'
                                                      : 'TAP TO MARK')
                                                : 'CLOSED',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 1.2,
                                            ),
                                          ),
                                        ],
                                      ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (onLeave) ...[
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isCheckingIn
                                ? null
                                : () {
                                    final activeLeave = approvedLeaves
                                        .firstWhere((l) {
                                          final today = DateTime(
                                            DateTime.now().year,
                                            DateTime.now().month,
                                            DateTime.now().day,
                                          );
                                          final from = DateTime(
                                            l.fromDate.year,
                                            l.fromDate.month,
                                            l.fromDate.day,
                                          );
                                          final to = DateTime(
                                            l.toDate.year,
                                            l.toDate.month,
                                            l.toDate.day,
                                          );
                                          return !today.isBefore(from) &&
                                              !today.isAfter(to) &&
                                              l.checkInTime == null;
                                        });
                                    _handleLeaveCheckIn(activeLeave.id);
                                  },
                            icon: _isCheckingIn
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Icon(Icons.location_on_rounded),
                            label: Text(
                              _isCheckingIn
                                  ? 'CHECKING...'
                                  : 'CHECK-IN FROM LEAVE',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _kSuccess,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 40),
                      Text(
                        onLeave
                            ? "You are officially on leave. Attendance is handled automatically."
                            : !hasValidStay
                            ? "Attendance is blocked. You must have an approved Short Stay for today."
                            : _isWithinGracePeriod()
                            ? (_isLate()
                                  ? "You are outside the reporting window. Marking now will be flagged as Late."
                                  : "It's time! Please mark your presence.")
                            : "Attendance window is currently closed.",
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: onLeave
                              ? _kSuccess
                              : _isWithinGracePeriod()
                              ? (_isLate() ? _kWarning : _kSuccess)
                              : Colors.black38,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextButton.icon(
                        onPressed: () =>
                            _showAttendanceHistory(context, widget.user),
                        icon: const Icon(Icons.history_rounded, size: 20),
                        label: const Text(
                          'View My Attendance History',
                          style: TextStyle(fontWeight: FontWeight.w700),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: _kPrimary,
                          backgroundColor: _kPrimary.withValues(alpha: 0.05),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAttendanceHistory(BuildContext context, VistaUser user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) =>
          _StudentAttendanceCalendar(student: user, fs: widget.fs),
    );
  }

  Widget _buildDownloadButton(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _kPrimary,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: _kPrimary.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  final List<List<double>> _collegeGeofence = const [
    [26.83578622, 75.65131165],
    [26.83740740, 75.65114535],
    [26.83662239, 75.64845745],
    [26.83605158, 75.64818118],
    [26.83546162, 75.65019753],
    [26.83460988, 75.65087344],
    [26.83401423, 75.65117888],
    [26.83333241, 75.65138273],
    [26.83262606, 75.65278552],
    [26.83388768, 75.65269735],
    [26.83412283, 75.65222863],
    [26.83494166, 75.65249585],
  ];

  bool _isPointInGeofence(double lat, double lng) {
    bool isInside = false;
    int j = _collegeGeofence.length - 1;
    for (int i = 0; i < _collegeGeofence.length; i++) {
      double xi = _collegeGeofence[i][0], yi = _collegeGeofence[i][1];
      double xj = _collegeGeofence[j][0], yj = _collegeGeofence[j][1];

      bool intersect =
          ((yi > lng) != (yj > lng)) &&
          (lat < (xj - xi) * (lng - yi) / (yj - yi) + xi);
      if (intersect) isInside = !isInside;

      j = i;
    }
    return isInside;
  }

  void _handleMarkAttendance() async {
    // Access is allowed, but marking will be blocked later if outside window
    setState(() => _isMarking = true);
    try {
      const bool bypassGeofence = false;

      // ── Face Recognition (with liveness blink check) ──────────────────────
      FaceCaptureResult? faceResult;
      if (!kIsWeb) {
        // Check if face has been registered
        final userDoc = await widget.fs.db
            .collection('users')
            .doc(widget.user.uid)
            .get();
        final hasFace = userDoc.data()?['faceEmbedding'] != null;

        if (!hasFace) {
          // First time: register face
          if (mounted) setState(() => _isMarking = false);
          if (!mounted) return;
          faceResult = await Navigator.of(context).push<FaceCaptureResult>(
            MaterialPageRoute(
              builder: (_) => FaceCaptureScreen(
                userId: widget.user.uid,
                mode: FaceCaptureMode.registration,
              ),
            ),
          );
        } else {
          // Verify identity
          if (mounted) setState(() => _isMarking = false);
          if (!mounted) return;
          faceResult = await Navigator.of(context).push<FaceCaptureResult>(
            MaterialPageRoute(
              builder: (_) => FaceCaptureScreen(
                userId: widget.user.uid,
                mode: FaceCaptureMode.verification,
              ),
            ),
          );
        }

        if (faceResult == null || !faceResult.success) {
          if (faceResult?.message != null) _showError(faceResult!.message!);
          return;
        }
      }

      // ── NOW PERFORM VALIDATIONS AFTER FACE SUCCESS ──────────────────────────
      if (mounted) setState(() => _isMarking = true);

      // 1. Geofence Check
      if (!kIsWeb && !bypassGeofence) {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          _showError('Location services are disabled. Please enable them.');
          if (mounted) setState(() => _isMarking = false);
          return;
        }

        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          _showError('Location permissions are denied.');
          if (mounted) setState(() => _isMarking = false);
          return;
        }

        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        bool inside = _isPointInGeofence(position.latitude, position.longitude);
        if (!inside) {
          _showError(
            'You must be inside the college campus to mark attendance.',
          );
          if (mounted) setState(() => _isMarking = false);
          return;
        }
      }

      // 2. Time Check
      if (!_isValidTime()) {
        _showError('Attendance not marked, try after 10:00 PM');
        if (mounted) setState(() => _isMarking = false);
        return;
      }

      // 3. Duplicate Check
      final now = DateTime.now();
      final dateKey = "${now.year}-${now.month}-${now.day}";
      final existingSnap = await widget.fs.db
          .collection('attendance')
          .where('studentId', isEqualTo: widget.user.uid)
          .where('date', isEqualTo: dateKey)
          .limit(1)
          .get();
      if (existingSnap.docs.isNotEmpty) {
        _showError('Attendance already marked for today.');
        if (mounted) setState(() => _isMarking = false);
        return;
      }

      setState(() => _isMarking = true);

      final isLateMarker = _isLate();
      final attObj = Attendance(
        id: '',
        studentId: widget.user.uid,
        studentName: widget.user.name,
        hostel: widget.user.hostel!,
        roomNumber: widget.user.roomNumber ?? 'N/A',
        timestamp: DateTime.now(),
        status: isLateMarker ? 'Late' : 'Marked',
      );
      await widget.fs.markAttendance(attObj);
      if (mounted) {
        _showSuccess('Attendance marked successfully!');
      }
    } catch (e) {
      if (mounted) _showError('Failed: $e');
    } finally {
      if (mounted) setState(() => _isMarking = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.redAccent,
        behavior: SnackBarBehavior.floating,
        content: Text(msg),
      ),
    );
  }

  void _showSuccess(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: _kSuccess,
        behavior: SnackBarBehavior.floating,
        content: Text(msg),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LEAVES TAB
// ─────────────────────────────────────────────────────────────────────────────
class _LeaveTab extends StatelessWidget {
  final VistaUser user;
  final FirebaseService fs;
  const _LeaveTab({required this.user, required this.fs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        heroTag: 'leaveFAB',
        onPressed: () => _showLeaveDialog(context, user, fs),
        backgroundColor: _kPrimary,
        elevation: 4,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: StreamBuilder<List<LeaveRequest>>(
        stream: fs.getStudentLeaves(user.uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const AttendanceListSkeleton();
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const _EmptyState(
              icon: Icons.event_note_outlined,
              title: 'No Leaves Yet',
              subtitle: 'Your leave application history will appear here.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final l = list[i];
              Color statusColor;
              switch (l.status) {
                case 'Approved':
                  statusColor = _kSuccess;
                  break;
                case 'Rejected':
                  statusColor = Colors.redAccent;
                  break;
                default:
                  statusColor = _kWarning;
              }

              return _Card(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.event_note_rounded,
                                size: 14,
                                color: _kPrimary.withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '${l.seqId} · ${DateFormat('dd MMM').format(l.fromDate)} - ${DateFormat('dd MMM yyyy').format(l.toDate)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: Color(0xFF1E293B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l.reason,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black45,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        l.status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 10,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showLeaveDialog(
    BuildContext context,
    VistaUser user,
    FirebaseService fs,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final fromController = TextEditingController(
      text: prefs.getString('leaveDraft_from') ?? '',
    );
    final toController = TextEditingController(
      text: prefs.getString('leaveDraft_to') ?? '',
    );
    final reasonController = TextEditingController(
      text: prefs.getString('leaveDraft_reason') ?? '',
    );
    final parentNameController = TextEditingController(
      text: prefs.getString('leaveDraft_parentName') ?? '',
    );
    final parentContactController = TextEditingController(
      text: prefs.getString('leaveDraft_parentContact') ?? '',
    );
    final addressController = TextEditingController(
      text: prefs.getString('leaveDraft_address') ?? '',
    );
    String? selectedRelation = prefs.getString(
      'leaveDraft_relation',
    ); // State for dropdown

    void saveDraft() {
      prefs.setString('leaveDraft_from', fromController.text);
      prefs.setString('leaveDraft_to', toController.text);
      prefs.setString('leaveDraft_reason', reasonController.text);
      prefs.setString('leaveDraft_parentName', parentNameController.text);
      prefs.setString('leaveDraft_parentContact', parentContactController.text);
      prefs.setString('leaveDraft_address', addressController.text);
      if (selectedRelation != null) {
        prefs.setString('leaveDraft_relation', selectedRelation!);
      }
    }

    fromController.addListener(saveDraft);
    toController.addListener(saveDraft);
    reasonController.addListener(saveDraft);
    parentNameController.addListener(saveDraft);
    parentContactController.addListener(saveDraft);
    addressController.addListener(saveDraft);

    bool isSubmitting = false;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => PopScope(
          onPopInvokedWithResult: (didPop, result) {
            // If they dismissed the dialog without submitting (didPop implies they exited), we clear it.
            // Submit explicitly pops with a result/navigates, or we just clear aggressively if it's not a success path.
            // Actually, `onPopInvoked` is called whenever the dialog pops (including submit).
            // We already clear on submit. So doing it here ensures it always clears on exit.
            for (final key in prefs.getKeys()) {
              if (key.startsWith('leaveDraft_')) {
                prefs.remove(key);
              }
            }
          },
          child: Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Text(
                      'Apply for Leave',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: _kPrimary,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildInput(
                      'From Date & Time',
                      fromController,
                      icon: Icons.access_time_rounded,
                      readOnly: true,
                      onTap: () async {
                        final date = await _selectDate(
                          context,
                          DateTime.now(),
                          DateTime.now(),
                        );
                        if (date != null && context.mounted) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (time != null) {
                            final fullDateTime = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                            fromController.text = DateFormat(
                              'dd/MM/yyyy hh:mm a',
                            ).format(fullDateTime);
                          }
                        }
                      },
                    ),
                    _buildInput(
                      'To Date & Time',
                      toController,
                      icon: Icons.update_rounded,
                      readOnly: true,
                      onTap: () async {
                        final fromDateStr = fromController.text;
                        DateTime initialDate = DateTime.now();
                        if (fromDateStr.isNotEmpty) {
                          initialDate = DateFormat(
                            'dd/MM/yyyy hh:mm a',
                          ).parse(fromDateStr);
                        }

                        final date = await _selectDate(
                          context,
                          initialDate,
                          initialDate,
                        );
                        if (date != null && context.mounted) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.now(),
                          );
                          if (time != null) {
                            final fullDateTime = DateTime(
                              date.year,
                              date.month,
                              date.day,
                              time.hour,
                              time.minute,
                            );
                            toController.text = DateFormat(
                              'dd/MM/yyyy hh:mm a',
                            ).format(fullDateTime);
                          }
                        }
                      },
                    ),
                    _buildInput(
                      'Reason',
                      reasonController,
                      icon: Icons.edit_note_rounded,
                    ),
                    _buildInput(
                      'Address during leave',
                      addressController,
                      icon: Icons.home_work_outlined,
                    ),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: _buildInput(
                            'Parent Name',
                            parentNameController,
                            icon: Icons.person_outline,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 1,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: DropdownButtonFormField<String>(
                              isExpanded: true,
                              initialValue: selectedRelation,
                              decoration: InputDecoration(
                                labelText: 'Relation',
                                filled: true,
                                fillColor: _kBg.withValues(alpha: 0.5),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 14,
                                ),
                              ),
                              items: ['Father', 'Mother', 'Guardian']
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(
                                        s,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) {
                                setDialogState(() => selectedRelation = v);
                                saveDraft();
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                    _buildInput(
                      'Parent Contact',
                      parentContactController,
                      icon: Icons.phone_android_rounded,
                      keyboardType: TextInputType.phone,
                      maxLength: 10,
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: isSubmitting
                          ? null
                          : () async {
                              final contact = parentContactController.text
                                  .trim();
                              if (contact.length != 10 ||
                                  double.tryParse(contact) == null) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Please enter a valid 10-digit number',
                                      ),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                }
                                return;
                              }

                              setDialogState(() => isSubmitting = true);
                              try {
                                final fromText = fromController.text.trim();
                                final toText = toController.text.trim();
                                final reasonText = reasonController.text.trim();

                                if (fromText.isEmpty || toText.isEmpty) {
                                  throw 'Please select both From and To dates';
                                }
                                if (reasonText.isEmpty) {
                                  throw 'Please enter a reason';
                                }

                                final request = LeaveRequest(
                                  id: '',
                                  studentId: user.uid,
                                  studentName: user.name,
                                  hostel: user.hostel ?? 'N/A',
                                  fromDate: DateFormat(
                                    'dd/MM/yyyy hh:mm a',
                                  ).parse(fromText),
                                  toDate: DateFormat(
                                    'dd/MM/yyyy hh:mm a',
                                  ).parse(toText),
                                  reason: InputSanitizer.sanitize(reasonText),
                                  address: InputSanitizer.sanitize(
                                    addressController.text,
                                  ),
                                  parentName: InputSanitizer.sanitize(
                                    parentNameController.text,
                                  ),
                                  parentRelation:
                                      selectedRelation ?? 'Guardian',
                                  parentContact: contact,
                                  studentContact: user.phoneNumber ?? '',
                                  status: 'Pending',
                                  createdAt: DateTime.now(),
                                );
                                await fs.submitLeaveRequest(request);

                                // Clear draft on success
                                for (final key in prefs.getKeys()) {
                                  if (key.startsWith('leaveDraft_')) {
                                    prefs.remove(key);
                                  }
                                }

                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Leave request submitted successfully!',
                                      ),
                                      backgroundColor: _kSuccess,
                                      behavior: SnackBarBehavior.floating,
                                    ),
                                  );
                                }
                              } catch (e) {
                                debugPrint('Error submitting leave: $e');
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Submission failed: $e'),
                                  ),
                                );
                              } finally {
                                if (context.mounted) {
                                  setDialogState(() => isSubmitting = false);
                                }
                              }
                            },
                      child: isSubmitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Submit Request'),
                    ),
                    TextButton(
                      onPressed: () {
                        for (final key in prefs.getKeys()) {
                          if (key.startsWith('leaveDraft_')) {
                            prefs.remove(key);
                          }
                        }
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Cancel',
                        style: TextStyle(color: Colors.black38),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED UI HELPERS
// ─────────────────────────────────────────────────────────────────────────────

Future<DateTime?> _selectDate(
  BuildContext context,
  DateTime initialDate,
  DateTime firstDate,
) async {
  DateTime tempDate = initialDate;
  return showDialog<DateTime>(
    context: context,
    builder: (context) => AlertDialog(
      contentPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Text(
              'Select Date',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: _kPrimary,
              ),
            ),
          ),
          SizedBox(
            height: 320,
            width: 320,
            child: CalendarDatePicker(
              initialDate: initialDate,
              firstDate: firstDate,
              lastDate: DateTime.now().add(const Duration(days: 90)),
              onDateChanged: (date) => tempDate = date,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel', style: TextStyle(color: Colors.black38)),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, tempDate),
          style: ElevatedButton.styleFrom(
            backgroundColor: _kPrimary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Confirm'),
        ),
      ],
    ),
  );
}

Widget _buildInput(
  String label,
  TextEditingController ctrl, {
  IconData? icon,
  bool readOnly = false,
  VoidCallback? onTap,
  TextInputType? keyboardType,
  int? maxLength,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextField(
      controller: ctrl,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      maxLength: maxLength,
      decoration: InputDecoration(
        labelText: label,
        counterText: "",
        prefixIcon: icon != null ? Icon(icon, size: 20) : null,
        filled: true,
        fillColor: _kBg.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPLAINTS TAB
// ─────────────────────────────────────────────────────────────────────────────
class _ComplaintsTab extends StatelessWidget {
  final VistaUser user;
  final FirebaseService fs;
  const _ComplaintsTab({required this.user, required this.fs});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        heroTag: 'complaintFAB',
        onPressed: () => _showComplaintDialog(context, user, fs),
        backgroundColor: _kPrimary,
        elevation: 4,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: StreamBuilder<List<Complaint>>(
        stream: fs.getStudentComplaints(user.uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const ComplaintListSkeleton();
          }
          final list = snap.data ?? [];
          if (list.isEmpty) {
            return const _EmptyState(
              icon: Icons.assignment_late_outlined,
              title: 'No Issues Raised',
              subtitle:
                  'Your complaint history will appear here once you raise any.',
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            itemCount: list.length,
            itemBuilder: (context, i) {
              final c = list[i];
              final isResolved =
                  c.status == 'Resolved' || c.status == 'Confirmed';
              Color statusColor = isResolved ? _kSuccess : _kWarning;
              if (!isResolved && c.isEscalated) {
                statusColor = Colors.redAccent;
              }

              return _Card(
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.assignment_late_outlined,
                                size: 14,
                                color: _kPrimary.withValues(alpha: 0.5),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  '${c.seqId}: ${c.title}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                    color: Color(0xFF1E293B),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'To: ${c.targetRoles.join(", ")} · ${DateFormat('dd MMM').format(c.createdAt)}',
                            style: const TextStyle(
                              color: Colors.black45,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (c.status == 'Resolved' && c.studentConfirmed == null)
                      TextButton(
                        onPressed: () => _confirmResolution(context, c, fs),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          backgroundColor: _kPrimary.withValues(alpha: 0.05),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'VERIFY',
                          style: TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      )
                    else if (c.status == 'Pending' &&
                        DateTime.now().difference(c.createdAt).inDays >= 3 &&
                        !c.targetRoles.contains('Chief Warden'))
                      TextButton(
                        onPressed: () => _confirmEscalation(context, c, fs),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          backgroundColor: Colors.redAccent.withValues(
                            alpha: 0.1,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'ESCALATE',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w900,
                            fontSize: 11,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          (!isResolved && c.isEscalated)
                              ? 'ESCALATED'
                              : (c.status == 'Confirmed'
                                    ? 'SOLVED'
                                    : c.status.toUpperCase()),
                          style: TextStyle(
                            color: statusColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 10,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _confirmEscalation(
    BuildContext context,
    Complaint c,
    FirebaseService fs,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Escalate Issue'),
        content: const Text(
          'It has been more than 3 days without a resolution. Do you want to escalate this issue to the higher authorities?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              fs.escalateComplaint(c);
              Navigator.pop(context);
            },
            child: const Text(
              'Yes, Escalate',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmResolution(
    BuildContext context,
    Complaint c,
    FirebaseService fs,
  ) {
    final isChiefWarden = c.targetRoles.contains('Chief Warden');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Resolution'),
        content: Text(
          isChiefWarden
              ? 'Is the issue resolved to your satisfaction?'
              : 'Is the issue resolved to your satisfaction? Escalating will move it to the ${c.targetRoles.contains('Head Warden') ? 'Chief Warden' : 'Head Warden'}.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              fs.updateComplaintStatus(c.id, 'Confirmed');
              Navigator.pop(context);
            },
            child: const Text('Yes, Solved'),
          ),
          if (!isChiefWarden)
            TextButton(
              onPressed: () {
                fs.escalateComplaint(c);
                Navigator.pop(context);
              },
              child: const Text(
                'No, Escalate',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
        ],
      ),
    );
  }

  void _showComplaintDialog(
    BuildContext context,
    VistaUser user,
    FirebaseService fs,
  ) {
    final titleController = TextEditingController();
    final descController = TextEditingController();

    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Raise New Issue',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: _kPrimary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Title',
                      filled: true,
                      fillColor: _kBg.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: descController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      labelText: 'Detailed Description',
                      alignLabelWithHint: true,
                      filled: true,
                      fillColor: _kBg.withValues(alpha: 0.5),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            if (titleController.text.trim().isEmpty) return;

                            setModalState(() => isSubmitting = true);
                            try {
                              final complaint = Complaint(
                                id: '',
                                studentId: user.uid,
                                studentName: user.name,
                                title: InputSanitizer.sanitize(
                                  titleController.text.trim(),
                                ),
                                description: InputSanitizer.sanitize(
                                  descController.text.trim(),
                                ),
                                hostel: user.hostel!,
                                targetRoles: ['Warden'],
                                status: 'Pending',
                                isAnonymous: true,
                                createdAt: DateTime.now(),
                              );
                              await fs.submitComplaint(complaint);
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Issue reported successfully. Authorities notified.',
                                    ),
                                    backgroundColor: _kSuccess,
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to report issue'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
                            } finally {
                              if (context.mounted) {
                                setModalState(() => isSubmitting = false);
                              }
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
                            'SUBMIT ANONYMOUS REPORT',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      'CANCEL',
                      style: TextStyle(
                        color: Colors.black26,
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// COMPONENT WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _TabHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final VoidCallback onAction;
  final String actionLabel;
  final IconData actionIcon;

  const _TabHeader({
    required this.title,
    required this.subtitle,
    required this.onAction,
    required this.actionLabel,
    required this.actionIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: _kPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  subtitle,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: Colors.black45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton.icon(
            onPressed: onAction,
            icon: Icon(actionIcon, size: 18),
            label: Text(actionLabel),
            style: ElevatedButton.styleFrom(
              backgroundColor: _kPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          color: _kPrimary,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 1.5,
        ),
      ),
    );
  }
}

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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: child,
    );
  }
}

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
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 80, color: _kPrimary.withValues(alpha: 0.1)),
            const SizedBox(height: 24),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: _kPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black38,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _kPrimary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.history_rounded,
                    color: _kPrimary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Attendance History',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: _kPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.black26),
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
                    return StreamBuilder<List<ShortStayRequest>>(
                      stream: widget.student.hostel == 'Short Stay'
                          ? widget.fs.getStudentShortStays(widget.student.uid)
                          : Stream.value([]),
                      builder: (context, staySnap) {
                        if (attendanceSnap.connectionState ==
                                ConnectionState.waiting ||
                            leaveSnap.connectionState ==
                                ConnectionState.waiting ||
                            staySnap.connectionState ==
                                ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(color: _kPrimary),
                          );
                        }

                        final attendanceList = attendanceSnap.data ?? [];
                        final leaves = leaveSnap.data ?? [];
                        final stays = staySnap.data ?? [];

                        return SingleChildScrollView(
                          physics: const BouncingScrollPhysics(),
                          child: Column(
                            children: [
                              TableCalendar(
                                focusedDay: _focusedDay,
                                firstDay: DateTime(2025, 1, 1),
                                lastDay: DateTime.now(),
                                calendarFormat: _format,
                                rowHeight: 52,
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
                                  defaultTextStyle: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                  weekendTextStyle: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: Color(0xFF1E293B),
                                  ),
                                ),
                                headerStyle: HeaderStyle(
                                  formatButtonVisible: true,
                                  titleCentered: true,
                                  formatButtonShowsNext: false,
                                  titleTextStyle: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: _kPrimary,
                                  ),
                                  leftChevronIcon: const Icon(
                                    Icons.chevron_left_rounded,
                                    color: _kPrimary,
                                  ),
                                  rightChevronIcon: const Icon(
                                    Icons.chevron_right_rounded,
                                    color: _kPrimary,
                                  ),
                                  formatButtonDecoration: BoxDecoration(
                                    border: Border.all(
                                      color: _kPrimary.withValues(alpha: 0.2),
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  formatButtonTextStyle: const TextStyle(
                                    color: _kPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                calendarBuilders: CalendarBuilders(
                                  defaultBuilder: (context, day, focusedDay) {
                                    final status = _getDayStatus(
                                      day,
                                      attendanceList,
                                      leaves,
                                      stays,
                                    );
                                    if (status == null) return null;
                                    return _buildCalendarDay(day, status);
                                  },
                                  outsideBuilder: (context, day, focusedDay) {
                                    final status = _getDayStatus(
                                      day,
                                      attendanceList,
                                      leaves,
                                      stays,
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
                                _buildSelectedDayDetails(
                                  attendanceList,
                                  leaves,
                                  stays,
                                ),
                              const SizedBox(height: 32),
                            ],
                          ),
                        );
                      },
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
    List<ShortStayRequest> stays,
  ) {
    final status = _getDayStatus(_selectedDay!, attendance, leaves, stays);
    if (status == null) return const SizedBox.shrink();

    final att = attendance.firstWhereOrNull(
      (a) => isSameDay(a.timestamp, _selectedDay),
    );

    Color statusColor;
    IconData statusIcon;
    switch (status) {
      case 'Present':
        statusColor = _kSuccess;
        statusIcon = Icons.check_circle_rounded;
        break;
      case 'Late':
        statusColor = _kWarning;
        statusIcon = Icons.access_time_filled_rounded;
        break;
      case 'Absent':
        statusColor = Colors.redAccent;
        statusIcon = Icons.cancel_rounded;
        break;
      case 'On Leave':
        statusColor = Colors.orangeAccent;
        statusIcon = Icons.beach_access_rounded;
        break;
      case 'Not in Stay':
        statusColor = Colors.grey;
        statusIcon = Icons.bed_rounded;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.info_rounded;
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: statusColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: statusColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(statusIcon, color: statusColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat('MMMM d, yyyy').format(_selectedDay!),
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                if (att != null) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: Colors.black26,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Time: ${DateFormat('hh:mm a').format(att.timestamp)}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black38,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
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
    List<ShortStayRequest> stays,
  ) {
    if (day.isAfter(DateTime.now())) return null;

    final att = attendance.firstWhereOrNull((a) => isSameDay(a.timestamp, day));
    if (att != null) return att.status;

    if (widget.student.hostel == 'Short Stay') {
      final hasApprovedStay = stays.any(
        (s) =>
            s.status == 'Approved' &&
            !day.isBefore(
              DateTime(
                s.checkInDate.year,
                s.checkInDate.month,
                s.checkInDate.day,
              ),
            ) &&
            !day.isAfter(
              DateTime(
                s.checkOutDate.year,
                s.checkOutDate.month,
                s.checkOutDate.day,
              ),
            ),
      );
      if (!hasApprovedStay) return 'Not in Stay';
    } else {
      final onLeave = leaves.any(
        (l) =>
            l.status == 'Approved' &&
            !day.isBefore(
              DateTime(l.fromDate.year, l.fromDate.month, l.fromDate.day),
            ) &&
            !day.isAfter(DateTime(l.toDate.year, l.toDate.month, l.toDate.day)),
      );
      if (onLeave) return 'On Leave';
    }

    if (day.isBefore(DateTime.now())) {
      if (isSameDay(day, DateTime.now())) {
        return null;
      }
      // For hostel attendance, if there's no record and no leave, it's Absent
      return 'Absent';
    }

    return null;
  }

  Widget _buildCalendarDay(DateTime day, String status) {
    Color color;
    switch (status) {
      case 'Present':
        color = _kSuccess;
        break;
      case 'Late':
        color = _kWarning;
        break;
      case 'Absent':
        color = Colors.redAccent;
        break;
      case 'On Leave':
        color = Colors.orangeAccent;
        break;
      case 'Not in Stay':
        color = Colors.grey;
        break;
      default:
        color = Colors.transparent;
    }

    return Container(
      margin: const EdgeInsets.all(6),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildLegend() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kBg.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: _legendItem('Present', _kSuccess)),
                Expanded(child: _legendItem('Late', _kWarning)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _legendItem('Absent', Colors.redAccent)),
                if (widget.student.hostel != 'Short Stay')
                  Expanded(child: _legendItem('On Leave', Colors.orangeAccent))
                else
                  Expanded(child: _legendItem('Not in Stay', Colors.grey)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.black54,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHORT STAY TAB (Annexure - F)
// ─────────────────────────────────────────────────────────────────────────────
class _ShortStayTab extends StatelessWidget {
  final VistaUser user;
  final FirebaseService fs;
  const _ShortStayTab({required this.user, required this.fs});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _TabHeader(
          title: 'Hostel Stays',
          subtitle: 'Apply for temporary stay',
          onAction: () => _showShortStayDialog(context),
          actionLabel: 'Apply Now',
          actionIcon: Icons.add_home_work_rounded,
        ),
        Expanded(
          child: StreamBuilder<List<ShortStayRequest>>(
            stream: fs.getStudentShortStays(user.uid),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const AttendanceListSkeleton();
              }
              final list = snapshot.data ?? [];
              if (list.isEmpty) {
                return const _EmptyState(
                  icon: Icons.hotel_rounded,
                  title: 'No Stay Requests',
                  subtitle: 'Your approved hostel stays will appear here.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 8,
                ),
                itemCount: list.length,
                itemBuilder: (context, i) =>
                    _ShortStayCard(request: list[i], fs: fs),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showShortStayDialog(BuildContext context) {
    final checkInCtrl = TextEditingController();
    final checkOutCtrl = TextEditingController();
    final addressCtrl = TextEditingController(text: user.address ?? '');
    final parentNameCtrl = TextEditingController(text: user.parentName ?? '');
    final parentContactCtrl = TextEditingController(
      text: user.parentContact ?? '',
    );
    final reasonCtrl = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Short Stay (Annexure-F)',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: _kPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'FOR DAY SCHOLARS ONLY',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.redAccent,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 24),
                  _buildInput(
                    'Check-in Date & Time',
                    checkInCtrl,
                    icon: Icons.login_rounded,
                    readOnly: true,
                    onTap: () async {
                      final date = await _selectDate(
                        context,
                        DateTime.now(),
                        DateTime.now(),
                      );
                      if (date != null && context.mounted) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null) {
                          checkInCtrl.text = DateFormat('dd/MM/yyyy hh:mm a')
                              .format(
                                DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  time.hour,
                                  time.minute,
                                ),
                              );
                        }
                      }
                    },
                  ),
                  _buildInput(
                    'Check-out Date & Time',
                    checkOutCtrl,
                    icon: Icons.logout_rounded,
                    readOnly: true,
                    onTap: () async {
                      final fromStr = checkInCtrl.text;
                      DateTime initialDate = DateTime.now();
                      if (fromStr.isNotEmpty) {
                        try {
                          initialDate = DateFormat(
                            'dd/MM/yyyy hh:mm a',
                          ).parse(fromStr);
                        } catch (_) {}
                      }

                      final date = await _selectDate(
                        context,
                        initialDate,
                        initialDate,
                      );
                      if (date != null && context.mounted) {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null) {
                          checkOutCtrl.text = DateFormat('dd/MM/yyyy hh:mm a')
                              .format(
                                DateTime(
                                  date.year,
                                  date.month,
                                  date.day,
                                  time.hour,
                                  time.minute,
                                ),
                              );
                        }
                      }
                    },
                  ),
                  _buildInput(
                    'Address',
                    addressCtrl,
                    icon: Icons.home_outlined,
                  ),
                  _buildInput(
                    'Parent Name',
                    parentNameCtrl,
                    icon: Icons.person_outline,
                  ),
                  _buildInput(
                    'Parent Contact',
                    parentContactCtrl,
                    icon: Icons.phone_android_rounded,
                    keyboardType: TextInputType.phone,
                    maxLength: 10,
                  ),
                  _buildInput(
                    'Reason for Stay',
                    reasonCtrl,
                    icon: Icons.description_outlined,
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: isSubmitting
                        ? null
                        : () async {
                            if (checkInCtrl.text.isEmpty ||
                                checkOutCtrl.text.isEmpty) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Please fill all fields'),
                                ),
                              );
                              return;
                            }
                            setDialogState(() => isSubmitting = true);
                            try {
                              final req = ShortStayRequest(
                                id: '',
                                seqId: '',
                                studentId: user.uid,
                                studentName: user.name,
                                rollNo: user.rollNo ?? '',
                                programme: user.programme ?? '',
                                gender: user.gender ?? '',
                                email: user.email,
                                contactNo: user.phoneNumber ?? '',
                                address: addressCtrl.text,
                                reason: reasonCtrl.text,
                                parentName: parentNameCtrl.text,
                                parentContact: parentContactCtrl.text,
                                checkInDate: DateFormat(
                                  'dd/MM/yyyy hh:mm a',
                                ).parse(checkInCtrl.text),
                                checkOutDate: DateFormat(
                                  'dd/MM/yyyy hh:mm a',
                                ).parse(checkOutCtrl.text),
                                status: 'Pending',
                                appliedHostel: 'Pending',
                                createdAt: DateTime.now(),
                              );
                              await fs.submitShortStayRequest(req);
                              if (context.mounted) {
                                Navigator.pop(context);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Request submitted!',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                    backgroundColor: _kSuccess,
                                  ),
                                );
                              }
                            } catch (e) {
                              if (context.mounted)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error: $e')),
                                );
                            } finally {
                              setDialogState(() => isSubmitting = false);
                            }
                          },
                    child: isSubmitting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Submit Application'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShortStayCard extends StatelessWidget {
  final ShortStayRequest request;
  final FirebaseService fs;
  const _ShortStayCard({required this.request, required this.fs});

  @override
  Widget build(BuildContext context) {
    final isActive = request.status == 'Approved';
    final isPending = request.status == 'Pending';
    final isExtensionPending = request.pendingToDate != null;

    Color statusColor = isPending
        ? _kWarning
        : (isActive ? _kSuccess : Colors.grey);
    if (request.status == 'Rejected') statusColor = Colors.redAccent;

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  request.status.toUpperCase(),
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const Spacer(),
              Text(
                request.seqId,
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.black26,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            request.appliedHostel,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: _kPrimary,
            ),
          ),
          if (request.roomNumber != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Room: ${request.roomNumber}',
                style: const TextStyle(
                  color: _kAccent,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          const SizedBox(height: 16),
          _row(
            Icons.login_rounded,
            'Check-in',
            DateFormat('MMM d, hh:mm a').format(request.checkInDate),
          ),
          const SizedBox(height: 8),
          _row(
            Icons.logout_rounded,
            'Check-out',
            DateFormat('MMM d, hh:mm a').format(request.checkOutDate),
          ),
          if (isExtensionPending)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _kWarning.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kWarning.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.history_rounded,
                      size: 16,
                      color: _kWarning,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Extension requested until ${DateFormat('MMM d').format(request.pendingToDate!)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: _kWarning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (isActive) ...[
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: _kPrimary.withValues(alpha: 0.2)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => _showExtensionDialog(context),
                    icon: const Icon(Icons.history_rounded, size: 18),
                    label: const Text('Extend'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    onPressed: () => _handleCheckOut(context),
                    child: const Text('Check-out'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.black26),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black45,
            fontWeight: FontWeight.w500,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.black87,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _handleCheckOut(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Check-out'),
        content: const Text('Are you sure you want to end your hostel stay?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes, Check-out'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await fs.checkOutFromShortStay(request.id);
      if (context.mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Checked out successfully!')),
        );
    }
  }

  void _showExtensionDialog(BuildContext context) async {
    final date = await showDatePicker(
      context: context,
      initialDate: request.checkOutDate.add(const Duration(days: 1)),
      firstDate: request.checkOutDate,
      lastDate: request.checkOutDate.add(const Duration(days: 7)),
    );
    if (date != null && context.mounted) {
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(request.checkOutDate),
      );
      if (time != null) {
        final newDate = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
        await fs.requestShortStayExtension(request.id, newDate);
        if (context.mounted)
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Extension request sent!')),
          );
      }
    }
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
