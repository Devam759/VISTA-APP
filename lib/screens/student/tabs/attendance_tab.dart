import 'dart:ui';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../models/attendance_model.dart';
import '../../../models/leave_request_model.dart';
import '../../../models/short_stay_model.dart';
import '../../../models/vista_user.dart';
import '../../../services/firebase_service.dart';
import '../../../services/security_service.dart';
import '../../../widgets/skeleton_loader.dart';
import '../widgets/attendance_calendar.dart';
import '../widgets/student_components.dart';
import '../../../widgets/vista_loader.dart';
import '../face_capture_screen.dart' if (dart.library.html) '../face_capture_screen_stub.dart';

class AttendanceTab extends StatefulWidget {
  final VistaUser user;
  final FirebaseService fs;
  final bool isActive;

  const AttendanceTab({
    super.key,
    required this.user,
    required this.fs,
    required this.isActive,
  });

  @override
  State<AttendanceTab> createState() => _AttendanceTabState();
}

class _AttendanceTabState extends State<AttendanceTab> with AutomaticKeepAliveClientMixin {
  bool _isMarking = false;
  bool _isCheckingIn = false;
  bool _isRealDevice = true;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _checkDevice();
  }

  Future<void> _checkDevice() async {
    final isSecure = await SecurityService.checkSecurity();
    final isReal = await SecurityService.isRealDevice();
    if (mounted) {
      setState(() {
        _isRealDevice = isSecure && isReal;
      });
    }
  }

  void _handleLeaveCheckIn(String leaveId) async {
    if (!mounted || kIsWeb) return;
    setState(() => _isCheckingIn = true);
    try {
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
      if (position.isMocked) {
        _showError('Mock location detected! Please disable fake GPS apps to check in.');
        return;
      }
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
    return now.hour >= 22;
  }

  bool _isLate() {
    final now = DateTime.now();
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
    super.build(context);
    final bool isMobileDevice = !kIsWeb && 
        (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);
        
    if (kIsWeb || !isMobileDevice || !_isRealDevice) {
      return _buildWebOrEmulatorWarning();
    }

    return StreamBuilder<List<LeaveRequest>>(
      stream: widget.fs.getStudentLeaves(widget.user.uid),
      builder: (context, leaveSnap) {
        return StreamBuilder<List<ShortStayRequest>>(
          stream: widget.fs.getStudentShortStays(widget.user.uid),
          builder: (context, staySnap) {
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
            if (widget.user.isDayScholar || widget.user.hostel == 'Short Stay') {
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

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(20, 22, 20, 16),
                  child: StudentSectionLabel("NIGHT ATTENDANCE"),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: kStudentPrimary.withValues(alpha: 0.05),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: kStudentPrimary.withValues(alpha: 0.03),
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
                                color: kStudentPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'Late: 10:30 PM - 11:59 PM',
                              style: TextStyle(
                                color: kStudentPrimary.withValues(alpha: 0.5),
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 40),
                            _buildMarkAttendanceButton(onLeave, hasValidStay),
                            if (onLeave) _buildLeaveCheckInButton(approvedLeaves),
                            const SizedBox(height: 40),
                            _buildStatusText(onLeave, hasValidStay),
                            const SizedBox(height: 32),
                            _buildHistoryButton(context),
                          ],
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

  Widget _buildWebOrEmulatorWarning() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: kStudentBg,
      child: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: kStudentPrimary.withValues(alpha: 0.05),
              ),
            ),
          ),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    constraints: const BoxConstraints(maxWidth: 500),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(32),
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: kStudentPrimary.withValues(alpha: 0.1),
                          blurRadius: 40,
                          offset: const Offset(0, 20),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(32),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(40),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.phonelink_lock_rounded,
                                size: 80,
                                color: kStudentPrimary.withValues(alpha: 0.3),
                              ),
                              const SizedBox(height: 32),
                              Text(
                                "Mobile App Only",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.outfit(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: kStudentPrimary,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                "For security and location verification, attendance marking is only available on the VISTA mobile application.",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  color: kStudentPrimary.withValues(alpha: 0.7),
                                  height: 1.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 48),
                              Row(
                                children: [
                                  Expanded(child: _buildDownloadButton(Icons.android_rounded, "Android App")),
                                  const SizedBox(width: 16),
                                  Expanded(child: _buildDownloadButton(Icons.apple_rounded, "iOS App")),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMarkAttendanceButton(bool onLeave, bool hasValidStay) {
    return GestureDetector(
      onTap: (onLeave || !hasValidStay || _isMarking) ? null : _handleMarkAttendance,
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
                      ? (_isLate() ? kStudentWarning : kStudentPrimary).withValues(alpha: 0.1)
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
                    ? [kStudentSuccess, Colors.green.shade700]
                    : (hasValidStay && _isValidTime())
                        ? (_isLate() ? [kStudentWarning, Colors.orange] : [kStudentPrimary, kStudentAccent])
                        : [Colors.grey.shade300, Colors.grey.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: onLeave
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event_available_rounded, color: Colors.white, size: 40),
                        SizedBox(height: 8),
                        Text('ON LEAVE',
                            style: TextStyle(
                                color: Colors.white, fontSize: 12, fontWeight: FontWeight.w900, letterSpacing: 1.2)),
                      ],
                    )
                  : _isMarking
                      ? const VISTALoader(size: 40, color: Colors.white)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.touch_app_rounded, color: Colors.white, size: 40),
                            const SizedBox(height: 8),
                            Text(
                              !hasValidStay
                                  ? 'NO ACTIVE STAY'
                                  : _isValidTime()
                                      ? (_isLate() ? 'LATE' : 'TAP TO MARK')
                                      : 'CLOSED',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 1.0)),
                          ],
                        ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLeaveCheckInButton(List<LeaveRequest> approvedLeaves) {
    return Column(
      children: [
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isCheckingIn
                ? null
                : () {
                    final activeLeave = approvedLeaves.firstWhere((l) {
                      final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
                      final from = DateTime(l.fromDate.year, l.fromDate.month, l.fromDate.day);
                      final to = DateTime(l.toDate.year, l.toDate.month, l.toDate.day);
                      return !today.isBefore(from) && !today.isAfter(to) && l.checkInTime == null;
                    });
                    _handleLeaveCheckIn(activeLeave.id);
                  },
            icon: _isCheckingIn
                ? const VISTALoader(size: 20, color: Colors.white)
                : const Icon(Icons.location_on_rounded),
            label: Text(_isCheckingIn ? 'CHECKING...' : 'CHECK-IN FROM LEAVE',
                style: const TextStyle(fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: kStudentSuccess,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusText(bool onLeave, bool hasValidStay) {
    return Text(
      onLeave
          ? "You are officially on leave. Attendance is handled automatically."
          : !hasValidStay
              ? "Attendance is blocked. You must have an approved Short Stay for today."
              : _isValidTime()
                  ? (_isLate()
                      ? "You are outside the reporting window. Marking now will be flagged as Late."
                      : "It's time! Please mark your presence.")
                  : "Attendance window is currently closed.",
      textAlign: TextAlign.center,
      style: TextStyle(
        color: onLeave
            ? kStudentSuccess
            : _isValidTime()
                ? (_isLate() ? kStudentWarning : kStudentSuccess)
                : Colors.black38,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
    );
  }

  Widget _buildHistoryButton(BuildContext context) {
    return TextButton.icon(
      onPressed: () => showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (context) => StudentAttendanceCalendar(student: widget.user, fs: widget.fs),
      ),
      icon: const Icon(Icons.history_rounded, size: 20),
      label: const Text('View My Attendance History', style: TextStyle(fontWeight: FontWeight.w700)),
      style: TextButton.styleFrom(
        foregroundColor: kStudentPrimary,
        backgroundColor: kStudentPrimary.withValues(alpha: 0.05),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildDownloadButton(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white.withValues(alpha: 0.15), Colors.white.withValues(alpha: 0.05)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 1.5),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Text(label,
              style: GoogleFonts.inter(
                  color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: -0.2)),
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
      bool intersect = ((yi > lng) != (yj > lng)) && (lat < (xj - xi) * (lng - yi) / (yj - yi) + xi);
      if (intersect) isInside = !isInside;
      j = i;
    }
    return isInside;
  }

  void _handleMarkAttendance() async {
    setState(() => _isMarking = true);
    try {
      const bool bypassGeofence = false;
      FaceCaptureResult? faceResult;
      
      if (!kIsWeb) {
        final userDoc = await widget.fs.db.collection('users').doc(widget.user.uid).get();
        final hasFace = userDoc.data()?['faceEmbedding'] != null;

        if (!hasFace) {
          if (mounted) setState(() => _isMarking = false);
          if (!mounted) return;
          faceResult = await Navigator.of(context).push<FaceCaptureResult>(
            MaterialPageRoute(
              builder: (_) => FaceCaptureScreen(userId: widget.user.uid, mode: FaceCaptureMode.registration),
            ),
          );
        } else {
          if (mounted) setState(() => _isMarking = false);
          if (!mounted) return;
          faceResult = await Navigator.of(context).push<FaceCaptureResult>(
            MaterialPageRoute(
              builder: (_) => FaceCaptureScreen(userId: widget.user.uid, mode: FaceCaptureMode.verification),
            ),
          );
        }

        if (faceResult == null || !faceResult.success) {
          if (faceResult?.message != null) _showError(faceResult!.message!);
          return;
        }
      }

      if (mounted) setState(() => _isMarking = true);

      // Extra Hardening: Double check Short Stay status for Day Scholars
      if (widget.user.isDayScholar || widget.user.hostel == 'Short Stay') {
        final stays = await widget.fs.getStudentShortStays(widget.user.uid).first;
        final now = DateTime.now();
        final today = DateTime(now.year, now.month, now.day);
        final hasValidStay = stays.any((stay) {
          if (stay.status != 'Approved') return false;
          final from = DateTime(stay.checkInDate.year, stay.checkInDate.month, stay.checkInDate.day);
          final to = DateTime(stay.checkOutDate.year, stay.checkOutDate.month, stay.checkOutDate.day);
          return !today.isBefore(from) && !today.isAfter(to);
        });
        if (!hasValidStay) {
          _showError('No active or approved short stay found for today.');
          return;
        }
      }

      if (!kIsWeb && !bypassGeofence) {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          _showError('Location services are disabled. Please enable them.');
          return;
        }
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          _showError('Location permissions are denied.');
          return;
        }
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
        );
        if (position.isMocked) {
          _showError('Mock location detected! Please disable fake GPS apps to mark attendance.');
          return;
        }
        // Client-side check: fast UX gate (also validated server-side independently).
        if (!_isPointInGeofence(position.latitude, position.longitude)) {
          _showError('You must be inside the college campus to mark attendance.');
          return;
        }

        if (!_isValidTime()) {
          _showError('Attendance not marked, try after 10:00 PM');
          return;
        }

        final now = DateTime.now();
        final dateKey = "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}";
        final isLateMarker = _isLate();

        // ── Server-side geofence validation ──────────────────────────────────
        // Calls validateAndMarkAttendance Cloud Function which independently
        // validates the GPS position and writes the record — a Fake GPS app
        // can spoof the client check above but cannot spoof this server check.
        try {
          final fn = FirebaseFunctions.instanceFor(region: 'asia-south1')
              .httpsCallable('validateAndMarkAttendance');
          await fn.call({
            'latitude':    position.latitude,
            'longitude':   position.longitude,
            'status':      isLateMarker ? 'Late' : 'Present',
            'hostel':      widget.user.hostel ?? '',
            'roomNumber':  widget.user.roomNumber ?? 'N/A',
            'studentName': widget.user.name,
            'date':        dateKey,
          });
          if (mounted) _showSuccess('Attendance marked successfully!');
        } on FirebaseFunctionsException catch (e) {
          if (e.code == 'already-exists') {
            _showError('Attendance already marked for today.');
          } else if (e.code == 'failed-precondition') {
            _showError(e.message ?? 'You must be inside the JKLU campus.');
          } else {
            _showError(e.message ?? 'Failed to mark attendance. Try again.');
          }
        }
        return; // Always return after server call path
      }

      // Web fallback: direct write (no GPS available on web)
      if (!_isValidTime()) {
        _showError('Attendance not marked, try after 10:00 PM');
        return;
      }

      final now = DateTime.now();
      final dateKey = "${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}";
      final existingSnap = await widget.fs.db
          .collection('attendance')
          .where('studentId', isEqualTo: widget.user.uid)
          .where('date', isEqualTo: dateKey)
          .limit(1)
          .get();
          
      if (existingSnap.docs.isNotEmpty) {
        _showError('Attendance already marked for today.');
        return;
      }

      final isLateMarker = _isLate();
      final attObj = Attendance(
        id: '',
        studentId: widget.user.uid,
        studentName: widget.user.name,
        hostel: widget.user.hostel!,
        roomNumber: widget.user.roomNumber ?? 'N/A',
        timestamp: DateTime.now(),
        status: isLateMarker ? 'Late' : 'Present',
      );
      await widget.fs.markAttendance(attObj);
      if (mounted) _showSuccess('Attendance marked successfully!');
    } catch (e) {
      if (mounted) _showError('Failed: $e');
    } finally {
      if (mounted) setState(() => _isMarking = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: Colors.redAccent, behavior: SnackBarBehavior.floating, content: Text(msg)),
    );
  }

  void _showSuccess(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(backgroundColor: kStudentSuccess, behavior: SnackBarBehavior.floating, content: Text(msg)),
    );
  }
}
