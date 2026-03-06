import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'face_capture_screen.dart'
    if (dart.library.html) 'face_capture_screen_stub.dart';
import '../../providers/auth_provider.dart';
import '../../models/attendance_model.dart';
import '../../models/leave_request_model.dart';
import '../../models/complaint_model.dart';
import '../../services/firebase_service.dart';
import '../../models/vista_user.dart';

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
                      _AttendanceTab(user: user, fs: _firebaseService),
                      _LeaveTab(user: user, fs: _firebaseService),
                      _ComplaintsTab(user: user, fs: _firebaseService),
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
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_ind_outlined),
              activeIcon: Icon(Icons.assignment_ind_rounded),
              label: 'Attendance',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.event_note_outlined),
              activeIcon: Icon(Icons.event_note_rounded),
              label: 'Leaves',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.assignment_late_outlined),
              activeIcon: Icon(Icons.assignment_late_rounded),
              label: 'Complaints',
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
  const _AttendanceTab({required this.user, required this.fs});

  @override
  State<_AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<_AttendanceTab> {
  bool _isMarking = false;

  bool _isValidTime() {
    final now = DateTime.now();
    return now.hour >= 22; // 10:00 PM onwards
  }

  bool _isWithinGracePeriod() {
    final now = DateTime.now();
    // 10:00 PM to 10:29 PM
    return now.hour == 22 && now.minute < 30;
  }

  bool _isLate() {
    final now = DateTime.now();
    // 10:30 PM to 12:00 AM
    return (now.hour == 22 && now.minute >= 30) || (now.hour == 23);
  }

  bool _isStudentOnLeave(List<LeaveRequest> approvedLeaves) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return approvedLeaves.any((leave) {
      if (leave.status != 'Approved') return false;
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
    if (kIsWeb) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.phonelink_lock_rounded,
                  size: 64,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Mobile Only Feature',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: _kPrimary,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Attendance marking is restricted to the VISTA Mobile App for security and location verification purposes.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.black54,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  _buildDownloadButton(Icons.apple, 'App Store'),
                  _buildDownloadButton(Icons.android_rounded, 'Play Store'),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<List<LeaveRequest>>(
      stream: widget.fs.getStudentLeaves(widget.user.uid),
      builder: (context, leaveSnap) {
        final approvedLeaves = (leaveSnap.data ?? [])
            .where((l) => l.status == 'Approved')
            .toList();
        final onLeave = _isStudentOnLeave(approvedLeaves);

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
                border: Border.all(color: _kPrimary.withValues(alpha: 0.05)),
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
                    onTap: (onLeave || _isMarking)
                        ? null
                        : _handleMarkAttendance,
                    child:
                        Container(
                              width: 180,
                              height: 180,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: onLeave
                                        ? Colors.green.withValues(alpha: 0.1)
                                        : _isWithinGracePeriod()
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
                                          : _isWithinGracePeriod()
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
                                                _isLate()
                                                    ? Icons.history_rounded
                                                    : Icons.touch_app_rounded,
                                                color: Colors.white,
                                                size: 40,
                                              ),
                                              const SizedBox(height: 8),
                                              Text(
                                                _isWithinGracePeriod()
                                                    ? (_isLate()
                                                          ? 'MARK LATE'
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
                            )
                            .animate(
                              onPlay: (c) =>
                                  (_isWithinGracePeriod() && !onLeave)
                                  ? c.repeat(reverse: true)
                                  : null,
                            )
                            .scale(
                              begin: const Offset(1, 1),
                              end: const Offset(1.03, 1.03),
                              duration: 2.seconds,
                              curve: Curves.easeInOut,
                            ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    onLeave
                        ? "You are officially on leave. Attendance is handled automatically."
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
  }

  void _showAttendanceHistory(BuildContext context, VistaUser user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
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
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Attendance History',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _kPrimary,
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<List<Attendance>>(
                stream: FirebaseService().getStudentAttendance(user.uid),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final list = snap.data ?? [];
                  if (list.isEmpty) {
                    return const _EmptyState(
                      icon: Icons.history_rounded,
                      title: 'No Records',
                      subtitle: 'You havent marked any attendance yet.',
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final a = list[i];
                      final isLate = a.status == 'Late';
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: _kBg.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              color: isLate ? _kWarning : _kSuccess,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                DateFormat('dd MMM yyyy').format(a.timestamp),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  DateFormat('hh:mm a').format(a.timestamp),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (isLate)
                                  const Text(
                                    'LATE',
                                    style: TextStyle(
                                      color: _kWarning,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                              ],
                            ),
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
      ),
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
        onPressed: () => _showLeaveDialog(context, user, fs),
        backgroundColor: _kPrimary,
        elevation: 4,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: StreamBuilder<List<LeaveRequest>>(
        stream: fs.getStudentLeaves(user.uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _kPrimary),
            );
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
                                  '${DateFormat('dd MMM').format(l.fromDate)} - ${DateFormat('dd MMM yyyy').format(l.toDate)}',
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
  ) {
    final fromController = TextEditingController();
    final toController = TextEditingController();
    final reasonController = TextEditingController();
    final parentNameController = TextEditingController();
    final parentContactController = TextEditingController();
    final addressController = TextEditingController();
    String? selectedRelation; // State for dropdown

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
                            onChanged: (v) =>
                                setDialogState(() => selectedRelation = v),
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
                    onPressed: () async {
                      final contact = parentContactController.text.trim();
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

                      try {
                        final request = LeaveRequest(
                          id: '',
                          studentId: user.uid,
                          studentName: user.name,
                          hostel: user.hostel!,
                          fromDate: DateFormat(
                            'dd/MM/yyyy hh:mm a',
                          ).parse(fromController.text),
                          toDate: DateFormat(
                            'dd/MM/yyyy hh:mm a',
                          ).parse(toController.text),
                          reason: reasonController.text,
                          address: addressController.text,
                          parentName: parentNameController.text,
                          parentRelation: selectedRelation ?? 'Guardian',
                          parentContact: contact,
                          studentContact: user.phoneNumber ?? '',
                          status: 'Pending',
                          createdAt: DateTime.now(),
                        );
                        await fs.submitLeaveRequest(request);
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
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Verification failed: Check fields'),
                          ),
                        );
                      }
                    },
                    child: const Text('Submit Request'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
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
    );
  }

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
            child: const Text(
              'Cancel',
              style: TextStyle(color: Colors.black38),
            ),
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
        onPressed: () => _showComplaintDialog(context, user, fs),
        backgroundColor: _kPrimary,
        elevation: 4,
        child: const Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: StreamBuilder<List<Complaint>>(
        stream: fs.getStudentComplaints(user.uid),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: _kPrimary),
            );
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
                                  c.title,
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
                              : c.status.toUpperCase(),
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

  void _confirmResolution(
    BuildContext context,
    Complaint c,
    FirebaseService fs,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Verify Resolution'),
        content: const Text(
          'Is the issue resolved to your satisfaction? Escalating will move it to the Head Warden.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              fs.updateComplaintStatus(c.id, 'Confirmed');
              Navigator.pop(context);
            },
            child: const Text('Yes, Solved'),
          ),
          TextButton(
            onPressed: () {
              fs.escalateComplaint(c.id);
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
    List<String> selectedTargets = ['Warden'];
    final authorities = ['Warden', 'Head Warden'];

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
                  const SizedBox(height: 24),
                  Text(
                    'TARGET AUTHORITIES',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: _kPrimary.withValues(alpha: 0.5),
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: authorities.map((a) {
                      final isSelected = selectedTargets.contains(a);
                      return FilterChip(
                        label: Text(
                          a,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected ? Colors.white : Colors.black54,
                          ),
                        ),
                        selected: isSelected,
                        onSelected: (val) {
                          setModalState(() {
                            if (val) {
                              selectedTargets.add(a);
                            } else {
                              if (selectedTargets.length > 1) {
                                selectedTargets.remove(a);
                              }
                            }
                          });
                        },
                        selectedColor: _kPrimary,
                        checkmarkColor: Colors.white,
                        backgroundColor: _kBg.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: isSelected ? _kPrimary : Colors.black12,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () async {
                      if (titleController.text.trim().isEmpty) return;

                      final complaint = Complaint(
                        id: '',
                        studentId: user.uid,
                        title: titleController.text.trim(),
                        description: descController.text.trim(),
                        hostel: user.hostel!,
                        targetRoles: selectedTargets,
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
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _kPrimary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
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
