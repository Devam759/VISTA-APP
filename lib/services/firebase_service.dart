import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/vista_user.dart';
import '../models/attendance_model.dart';
import '../models/leave_request_model.dart';
import '../models/complaint_model.dart';
import '../models/short_stay_model.dart';
import '../utils/rate_limiter.dart';

class FirebaseService {
  // Using lazy getters for all Firebase instances.
  FirebaseAuth get _auth => FirebaseAuth.instance;
  // The Firestore database was created with ID 'default' (not the standard '(default)').
  // Using a lazy getter so Firebase.app() is only called after initializeApp() is done.
  FirebaseFirestore get _db => FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'default',
  );

  FirebaseFirestore get db => _db;

  // Auth State Stream
  Stream<User?> get userStream => _auth.authStateChanges();

  // Current User
  User? get currentUser => _auth.currentUser;

  // Sign Up with Email (JKLU Email)
  Future<UserCredential> signUp(String email, String password) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  // Sign In
  Future<UserCredential> signIn(String email, String password) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  // Phone Verification
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String, int?) onCodeSent,
    required Function(FirebaseAuthException) onVerificationFailed,
    required Function(PhoneAuthCredential) onVerificationCompleted,
    Object? webVerifier, // RecaptchaVerifier for web
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: onVerificationCompleted,
      verificationFailed: onVerificationFailed,
      codeSent: onCodeSent,
      codeAutoRetrievalTimeout: (String verificationId) {},
      timeout: const Duration(seconds: 60),
    );
  }

  // Sign Out
  Future<void> signOut() {
    return _auth.signOut();
  }

  // Password Reset
  Future<void> sendPasswordResetEmail(String email) {
    debugPrint('FirebaseService: Sending password reset email to $email');
    return _auth.sendPasswordResetEmail(email: email);
  }

  // User Profile Methods
  Future<void> createUserProfile(VistaUser user) async {
    await _db.collection('users').doc(user.uid).set(user.toMap());
    if (user.phoneNumber != null) {
      await _updatePhoneMapping(user.phoneNumber, user.email);
    }
  }

  Future<void> updateFcmToken(String uid, String token) {
    return _db.collection('users').doc(uid).update({'fcmToken': token});
  }

  Future<void> clearFcmToken(String uid) {
    return _db.collection('users').doc(uid).update({'fcmToken': null});
  }

  Future<String?> getUserEmailByPhone(String phone) async {
    // We target a specific document by phone number to avoid 'list' permissions
    final doc = await _db.collection('phone_mappings').doc(phone).get();
    if (doc.exists) {
      return doc.data()?['email'] as String?;
    }
    return null;
  }

  /// Internal helper to sync phone-to-email mapping for secure login
  Future<void> _updatePhoneMapping(String? phone, String email) async {
    if (phone == null || phone.isEmpty) return;
    try {
      await _db.collection('phone_mappings').doc(phone).set({
        'email': email,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('[FirebaseService] Error updating phone mapping: $e');
    }
  }

  Future<VistaUser?> getUserProfile(String uid) async {
    // 1. Try by UID (document ID = uid) — the standard case
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      final user = VistaUser.fromMap(doc.data() as Map<String, dynamic>);
      if (user.phoneNumber != null) {
        _updatePhoneMapping(user.phoneNumber, user.email);
      }
      return user;
    }

    // 2. Fallback: query by email field — handles manually-created docs
    //    where the document ID is the email instead of the UID
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      final query = await _db
          .collection('users')
          .where('email', isEqualTo: currentUser.email)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        final data = query.docs.first.data();
        // Fix the uid field if it's wrong, so future lookups work by UID too
        if (data['uid'] != uid) {
          await _db.collection('users').doc(query.docs.first.id).update({
            'uid': uid,
          });
        }
        final user = VistaUser.fromMap({...data, 'uid': uid});
        if (user.phoneNumber != null) {
          _updatePhoneMapping(user.phoneNumber, user.email);
        }
        return user;
      }
    }
    return null;
  }

  // Attendance Methods
  Future<void> markAttendance(Attendance attendance) {
    return RateLimiter.run('markAttendance_${attendance.studentId}', () {
      return _db.collection('attendance').add(attendance.toMap());
    });
  }

  Stream<List<Attendance>> getHostelAttendance(String? hostel, String date) {
    Query<Map<String, dynamic>> query = _db
        .collection('attendance')
        .where('date', isEqualTo: date);
    if (hostel != null && hostel != 'All') {
      query = query.where('hostel', isEqualTo: hostel);
    }
    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Attendance.fromMap(doc.data(), doc.id))
          .toList(),
    );
  }

  Stream<List<Attendance>> getStudentAttendance(String uid) {
    return _db
        .collection('attendance')
        .where('studentId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => Attendance.fromMap(doc.data(), doc.id))
              .toList();
          list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          return list;
        });
  }

  // Sequential ID Generator
  Future<String> _getNextSequence(String prefix) async {
    final counterRef = _db.collection('counters').doc(prefix);

    return _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(counterRef);
      int currentVal = 0;

      if (snapshot.exists) {
        currentVal = snapshot.data()?['current'] ?? 0;
      }

      int nextVal = currentVal + 1;
      transaction.set(counterRef, {'current': nextVal});

      // Format as 3-digit with padding (e.g., CA001)
      String padded = nextVal.toString().padLeft(3, '0');
      return '$prefix$padded';
    });
  }

  // Leave Methods
  Future<void> submitLeaveRequest(LeaveRequest request) async {
    return RateLimiter.run('submitLeave_${request.studentId}', () async {
      final seqId = await _getNextSequence('LA');
    final updatedRequest = LeaveRequest(
      id: request.id,
      studentId: request.studentId,
      studentName: request.studentName,
      hostel: request.hostel,
      fromDate: request.fromDate,
      toDate: request.toDate,
      reason: request.reason,
      address: request.address,
      parentName: request.parentName,
      parentRelation: request.parentRelation,
      parentContact: request.parentContact,
      studentContact: request.studentContact,
      status: request.status,
      createdAt: DateTime.now(),
      checkInTime: request.checkInTime,
      seqId: seqId,
    );
    await _db.collection('leave_requests').add(updatedRequest.toMap());
    });
  }

  Stream<List<LeaveRequest>> getPendingLeaves(String? hostel) {
    Query<Map<String, dynamic>> query = _db
        .collection('leave_requests')
        .where('status', isEqualTo: 'Pending');
    if (hostel != null && hostel != 'All') {
      query = query.where('hostel', isEqualTo: hostel);
    }
    return query.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => LeaveRequest.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<List<LeaveRequest>> getHostelLeaves(String? hostel) {
    Query<Map<String, dynamic>> query = _db.collection('leave_requests');
    if (hostel != null && hostel != 'All') {
      query = query.where('hostel', isEqualTo: hostel);
    }
    return query.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => LeaveRequest.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<void> updateLeaveStatus(String id, String status) {
    return _db.collection('leave_requests').doc(id).update({'status': status});
  }

  Stream<List<LeaveRequest>> getApprovedLeaves(String? hostel) {
    Query<Map<String, dynamic>> query = _db
        .collection('leave_requests')
        .where('status', isEqualTo: 'Approved');
    if (hostel != null && hostel != 'All') {
      query = query.where('hostel', isEqualTo: hostel);
    }
    return query.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => LeaveRequest.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<List<LeaveRequest>> getStudentLeaves(String uid) {
    return _db
        .collection('leave_requests')
        .where('studentId', isEqualTo: uid)
        .withConverter<Map<String, dynamic>>(
          fromFirestore: (snapshot, _) => snapshot.data()!,
          toFirestore: (map, _) => map,
        )
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => LeaveRequest.fromMap(doc.data(), doc.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  // Short Stay Methods (Annexure - F)
  Future<void> submitShortStayRequest(ShortStayRequest request) async {
    return RateLimiter.run('submitShortStay_${request.studentId}', () async {
      final seqId = await _getNextSequence('SS');
      final updatedRequest = ShortStayRequest(
        id: request.id,
        seqId: seqId,
        studentId: request.studentId,
        studentName: request.studentName,
        rollNo: request.rollNo,
        programme: request.programme,
        gender: request.gender,
        email: request.email,
        contactNo: request.contactNo,
        address: request.address,
        reason: request.reason,
        parentName: request.parentName,
        parentContact: request.parentContact,
        checkInDate: request.checkInDate,
        checkOutDate: request.checkOutDate,
        status: 'Pending',
        appliedHostel: request.gender == 'Male' ? 'Boys' : 'Girls',
        roomNumber: request.roomNumber,
        createdAt: DateTime.now(),
      );
      await _db.collection('short_stay_requests').add(updatedRequest.toMap());
    });
  }

  Stream<List<ShortStayRequest>> getPendingShortStays(String? hostel) {
    Query<Map<String, dynamic>> query = _db
        .collection('short_stay_requests')
        .where('status', isEqualTo: 'Pending');
    if (hostel != null && hostel != 'All') {
      if (hostel == 'BH1' || hostel == 'BH2') {
        query = query.where('appliedHostel', whereIn: ['Boys', 'BH1', 'BH2']);
      } else if (hostel == 'GH1' || hostel == 'GH2') {
        query = query.where('appliedHostel', whereIn: ['Girls', 'GH1', 'GH2']);
      } else {
        query = query.where('appliedHostel', isEqualTo: hostel);
      }
    }
    return query.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ShortStayRequest.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<List<ShortStayRequest>> getApprovedShortStays(String? hostel) {
    Query<Map<String, dynamic>> query = _db
        .collection('short_stay_requests')
        .where('status', isEqualTo: 'Approved');
    if (hostel != null && hostel != 'All') {
      if (hostel == 'BH1' || hostel == 'BH2') {
        query = query.where('appliedHostel', whereIn: ['Boys', 'BH1', 'BH2']);
      } else if (hostel == 'GH1' || hostel == 'GH2') {
        query = query.where('appliedHostel', whereIn: ['Girls', 'GH1', 'GH2']);
      } else {
        query = query.where('appliedHostel', isEqualTo: hostel);
      }
    }
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => ShortStayRequest.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  Stream<List<ShortStayRequest>> getStudentShortStays(String uid) {
    return _db
        .collection('short_stay_requests')
        .where('studentId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ShortStayRequest.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<void> updateShortStayStatus(String id, String status, {String? roomNumber, String? allotmentHostel}) async {
    final updates = <String, dynamic>{'status': status};
    if (roomNumber != null) updates['roomNumber'] = roomNumber;
    if (allotmentHostel != null) updates['appliedHostel'] = allotmentHostel;
    await _db.collection('short_stay_requests').doc(id).update(updates);

    if (status == 'Approved') {
      final snap = await _db.collection('short_stay_requests').doc(id).get();
      if (snap.exists) {
        final studentId = snap.data()?['studentId'];
        if (studentId != null) {
          final userSnap = await _db.collection('users').doc(studentId).get();
          if (userSnap.exists) {
            final userData = userSnap.data()!;
            final userUpdates = <String, dynamic>{'hasUsedShortStay': true};
            // If the student is still in 'Short Stay' category, move them to the actual hostel
            if (userData['hostel'] == 'Short Stay' && allotmentHostel != null) {
              userUpdates['hostel'] = allotmentHostel;
              if (roomNumber != null) userUpdates['roomNumber'] = roomNumber;
            }
            await _db.collection('users').doc(studentId).update(userUpdates);
          }
        }
      }
    }
  }

  Future<void> checkOutFromShortStay(String id) {
    return _db.collection('short_stay_requests').doc(id).update({
      'status': 'Completed',
      'actualCheckOutTime': FieldValue.serverTimestamp(),
    });
  }

  Future<void> requestShortStayExtension(String id, DateTime newToDate) {
    return _db.collection('short_stay_requests').doc(id).update({
      'pendingToDate': Timestamp.fromDate(newToDate),
    });
  }

  Future<void> approveShortStayExtension(String id, DateTime newToDate) {
    return _db.collection('short_stay_requests').doc(id).update({
      'checkOutDate': Timestamp.fromDate(newToDate),
      'pendingToDate': null,
    });
  }

  // Complaint Methods
  Future<void> submitComplaint(Complaint complaint) async {
    return RateLimiter.run('submitComplaint_${complaint.studentId}', () async {
      final seqId = await _getNextSequence('CA');
    final updatedComplaint = Complaint(
      id: complaint.id,
      studentId: complaint.studentId,
      studentName: complaint.studentName,
      title: complaint.title,
      description: complaint.description,
      hostel: complaint.hostel,
      targetRole: complaint.targetRole,
      targetRoles: complaint.targetRoles,
      status: complaint.status,
      isAnonymous: complaint.isAnonymous,
      studentConfirmed: complaint.studentConfirmed,
      isEscalated: complaint.isEscalated,
      createdAt: complaint.createdAt,
      seqId: seqId,
    );
    await _db.collection('complaints').add(updatedComplaint.toMap());
    });
  }

  Stream<List<Complaint>> getComplaintsForRole(String role, [String? hostel]) {
    Query<Map<String, dynamic>> query = _db
        .collection('complaints')
        .where('targetRoles', arrayContains: role);
    if (hostel != null && hostel != 'All') {
      query = query.where('hostel', isEqualTo: hostel);
    }

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Complaint.fromMap(doc.data(), doc.id))
          .toList(),
    );
  }

  Stream<List<Complaint>> getStudentComplaints(String uid) {
    return _db
        .collection('complaints')
        .where('studentId', isEqualTo: uid)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => Complaint.fromMap(doc.data(), doc.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  Future<void> updateComplaintStatus(String id, String status) {
    if (status == 'Confirmed') {
      return _db.collection('complaints').doc(id).update({
        'status': status,
        'studentConfirmed': true,
      });
    }
    return _db.collection('complaints').doc(id).update({'status': status});
  }

  Future<void> escalateComplaint(String id) {
    return _db.collection('complaints').doc(id).update({
      'status': 'Pending',
      'isEscalated': true,
      'studentConfirmed': false,
      'targetRole': 'Head Warden', // Keep for compatibility
      'targetRoles': ['Head Warden', 'Chief Warden'],
    });
  }

  // Warden Approval Methods
  Stream<List<VistaUser>> getPendingRegistrations(String? hostel) {
    Query<Map<String, dynamic>> query = _db
        .collection('users')
        .where('isApproved', isEqualTo: false)
        .where('role', isEqualTo: 'student')
        .where('hostel', isNotEqualTo: 'Short Stay');
    if (hostel != null && hostel != 'All') {
      query = query.where('hostel', isEqualTo: hostel);
    }
    return query.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => VistaUser.fromMap(doc.data())).toList(),
    );
  }

  Future<void> approveStudent(String uid, String roomNumber) {
    return _db.collection('users').doc(uid).update({
      'isApproved': true,
      'roomNumber': roomNumber,
    });
  }

  Future<void> denyStudent(String uid) {
    return _db.collection('users').doc(uid).update({
      'hostel': null,
      'isApproved': false,
    });
  }

  // Returns approved students for a hostel
  Stream<List<VistaUser>> getHostelStudents(String? hostel) {
    Query<Map<String, dynamic>> query = _db
        .collection('users')
        .where('isApproved', isEqualTo: true)
        .where('role', isEqualTo: 'student');
    if (hostel != null && hostel != 'All') {
      query = query.where('hostel', isEqualTo: hostel);
    }
    return query.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => VistaUser.fromMap(doc.data())).toList(),
    );
  }

  Stream<List<Attendance>> getHostelAttendanceRange(
    String? hostel,
    DateTime start,
    DateTime end,
  ) {
    final s = DateTime(start.year, start.month, start.day, 0, 0, 0);
    final e = DateTime(end.year, end.month, end.day, 23, 59, 59);

    Query<Map<String, dynamic>> query = _db
        .collection('attendance')
        .where('timestamp', isGreaterThanOrEqualTo: s)
        .where('timestamp', isLessThanOrEqualTo: e);

    if (hostel != null && hostel != 'All') {
      query = query.where('hostel', isEqualTo: hostel);
    }
    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Attendance.fromMap(doc.data(), doc.id))
          .toList(),
    );
  }

  Stream<List<LeaveRequest>> getHostelLeavesRange(
    String? hostel,
    DateTime start,
    DateTime end,
  ) {
    Query<Map<String, dynamic>> query = _db.collection('leave_requests');

    if (hostel != null && hostel != 'All') {
      query = query.where('hostel', isEqualTo: hostel);
    }

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => LeaveRequest.fromMap(doc.data(), doc.id))
          .where((l) {
            return !l.fromDate.isAfter(end) && !l.toDate.isBefore(start);
          })
          .toList(),
    );
  }

  Stream<List<ShortStayRequest>> getHostelShortStaysRange(
    String? hostel,
    DateTime start,
    DateTime end,
  ) {
    Query<Map<String, dynamic>> query = _db.collection('short_stay_requests');

    if (hostel != null && hostel != 'All') {
      if (hostel == 'BH1' || hostel == 'BH2') {
        query = query.where('appliedHostel', whereIn: ['Boys', 'BH1', 'BH2']);
      } else if (hostel == 'GH1' || hostel == 'GH2') {
        query = query.where('appliedHostel', whereIn: ['Girls', 'GH1', 'GH2']);
      } else {
        query = query.where('appliedHostel', isEqualTo: hostel);
      }
    }

    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => ShortStayRequest.fromMap(doc.data(), doc.id))
          .where((s) {
            return !s.checkInDate.isAfter(end) && !s.checkOutDate.isBefore(start);
          })
          .toList(),
    );
  }

  Stream<List<ShortStayRequest>> getHostelShortStays(String? hostel) {
    Query<Map<String, dynamic>> query = _db.collection('short_stay_requests');
    if (hostel != null && hostel != 'All') {
      if (hostel == 'BH1' || hostel == 'BH2') {
        query = query.where('appliedHostel', whereIn: ['Boys', 'BH1', 'BH2']);
      } else if (hostel == 'GH1' || hostel == 'GH2') {
        query = query.where('appliedHostel', whereIn: ['Girls', 'GH1', 'GH2']);
      } else {
        query = query.where('appliedHostel', isEqualTo: hostel);
      }
    }
    return query.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => ShortStayRequest.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Stream<List<Complaint>> getHostelComplaintsRange(
    String? hostel,
    DateTime start,
    DateTime end,
  ) {
    final s = DateTime(start.year, start.month, start.day, 0, 0, 0);
    final e = DateTime(end.year, end.month, end.day, 23, 59, 59);

    Query<Map<String, dynamic>> query = _db
        .collection('complaints')
        .where('createdAt', isGreaterThanOrEqualTo: s)
        .where('createdAt', isLessThanOrEqualTo: e);

    if (hostel != null && hostel != 'All') {
      query = query.where('hostel', isEqualTo: hostel);
    }
    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Complaint.fromMap(doc.data(), doc.id))
          .toList(),
    );
  }

  Future<void> checkInFromLeave(String leaveId) {
    return _db.collection('leave_requests').doc(leaveId).update({
      'checkInTime': FieldValue.serverTimestamp(),
    });
  }
}
