import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/vista_user.dart';
import '../models/attendance_model.dart';
import '../models/leave_request_model.dart';
import '../models/complaint_model.dart';
import '../models/short_stay_model.dart';
import '../utils/rate_limiter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


class FirebaseService {
  // Using lazy getters for all Firebase instances.
  FirebaseAuth get _auth => FirebaseAuth.instance;
  // The Firestore database was created with ID 'default' (not the standard '(default)').
  // Using a lazy getter so Firebase.app() is only called after initializeApp() is done.
  FirebaseFirestore get _db =>
      FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');

  FirebaseFirestore get db => _db;

  FirebaseService() {
    // We will now handle redirect explicitly from AuthProvider for better sync
  }

  final MicrosoftAuthProvider _microsoftProvider = MicrosoftAuthProvider();
  MicrosoftAuthProvider get microsoftProvider => _microsoftProvider;

  Future<void> handleRedirectResult() async {
    if (!kIsWeb) return;
    try {
      debugPrint("VISTA: Checking for Microsoft redirect result...");
      
      // Delay to allow Firebase JS SDK to initialize and pick up the redirect state
      await Future.delayed(const Duration(milliseconds: 1000));
      
      final result = await _auth.getRedirectResult();
      if (result.user != null) {
        debugPrint("VISTA: Redirect result found for: ${result.user!.email}");
      } else {
        debugPrint("VISTA: No redirect result found. checking current user...");
        if (_auth.currentUser != null) {
           debugPrint("VISTA: Current user is already synced: ${_auth.currentUser!.email}");
        } else {
           debugPrint("VISTA: No current user found (Still Null).");
        }
      }
    } catch (e) {
      debugPrint("VISTA: Redirect result error: $e");
    }
  }

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

  // Microsoft Sign In
  Future<UserCredential> signInWithMicrosoft() async {
    debugPrint("VISTA: signInWithMicrosoft START");
    
    // Check if we have a specific tenant ID, otherwise use common
    final tenantId = dotenv.env['MICROSOFT_TENANT_ID'] ?? 'common';
    
    _microsoftProvider.setCustomParameters({
      'tenant': tenantId,
    });

    
    try {
      if (kIsWeb) {
        debugPrint("VISTA: Web - Triggering signInWithRedirect...");
        await _auth.signInWithRedirect(_microsoftProvider);
        // On web, this will redirect the entire page. 
        // We return a dummy UserCredential or just return null since the page reloads.
        return null as dynamic; 
      } else {
        debugPrint("VISTA: Mobile - Triggering signInWithProvider...");
        return await _auth.signInWithProvider(_microsoftProvider);
      }
    } on FirebaseAuthException catch (e) {
      debugPrint("VISTA: FirebaseAuthException in signInWithMicrosoft: ${e.code}");
      if (e.code == 'account-exists-with-different-credential') {
        // This is a professional error case where we need to link accounts.
        // We rethrow it so the AuthProvider/UI can handle the linking flow.
        debugPrint("VISTA: Account exists with different credential. Linking required.");
      }
      rethrow;
    }
  }


  // Sign Out
  Future<void> signOut() {
    return _auth.signOut();
  }

  // Account Linking Methods
  Future<UserCredential> linkWithMicrosoftCredential(AuthCredential credential) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("No user logged in to link with.");
    return await user.linkWithCredential(credential);
  }

  Future<UserCredential> linkWithMicrosoftPopup() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception("No user logged in to link with.");
    
    _microsoftProvider.setCustomParameters({
      'prompt': 'select_account',
      'tenant': 'common',
    });

    if (kIsWeb) {
      return await user.linkWithPopup(_microsoftProvider);
    } else {
      return await user.linkWithProvider(_microsoftProvider);
    }
  }

  // Password Reset
  Future<void> sendPasswordResetEmail(String email) {
    debugPrint('FirebaseService: Sending password reset email to $email');
    return _auth.sendPasswordResetEmail(email: email);
  }

  // User Profile Methods
  Future<void> createUserProfile(VistaUser user) async {
    // 1. Phone Mapping (Identity Anchor)
    if (user.phoneNumber != null) {
      final phoneDoc = _db.collection('phone_mappings').doc(user.phoneNumber);
      
      await _db.runTransaction((transaction) async {
        final snap = await transaction.get(phoneDoc);
        if (snap.exists) {
          final existingUid = snap.data()?['uid'];
          final existingEmail = snap.data()?['email'];
          
          if (existingUid != user.uid && existingEmail != user.email) {
            throw Exception('This phone number is already registered with another account ($existingEmail).');
          }
        }
        
        // Check if a pre-populated profile exists with the email as key
        final emailDocRef = _db.collection('users').doc(user.email);
        final existingDoc = await transaction.get(emailDocRef);
        
        Map<String, dynamic> finalData;
        if (existingDoc.exists) {
          final existingData = existingDoc.data()!;
          finalData = {
            ...existingData,
            ...user.toMap(),
            'isAccountActive': true,
            'uid': user.uid,
          };
          transaction.delete(emailDocRef);
        } else {
          finalData = user.toMap();
        }
        
        // Set phone mapping and user profile
        transaction.set(phoneDoc, {
          'uid': user.uid,
          'email': user.email,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        transaction.set(_db.collection('users').doc(user.uid), finalData);
      });
    } else {
      // Standard creation if no phone (unlikely for students but safe)
      await _db.collection('users').doc(user.uid).set(user.toMap());
    }
  }

  Future<void> updateMicrosoftLinkRequirement(String uid, bool required) async {
    debugPrint('FirebaseService: Updating Microsoft link requirement for $uid to $required');
    await _db.collection('users').doc(uid).update({
      'isMicrosoftLinkRequired': required,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setMicrosoftLinkedStatus(String uid, bool linked) async {
    debugPrint('FirebaseService: Setting Microsoft link status for $uid to $linked');
    final Map<String, dynamic> data = {
      'isMicrosoftLinked': linked,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    if (linked) {
      // If linked, we automatically clear the required flag
      data['isMicrosoftLinkRequired'] = false;
    }
    await _db.collection('users').doc(uid).update(data);
  }

  Future<String?> getPhoneNumberOwner(String phoneNumber) async {
    final doc = await _db.collection('phone_mappings').doc(phoneNumber).get();
    if (doc.exists) {
      return doc.data()?['email'] as String?;
    }
    return null;
  }

  Future<bool> isPhoneNumberRegistered(String phoneNumber) async {
    final doc = await _db.collection('phone_mappings').doc(phoneNumber).get();
    return doc.exists;
  }

  Future<void> updateStudentProfile(String uid, Map<String, dynamic> data) {
    return _db.collection('users').doc(uid).update({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> requestMicrosoftLink(String uid) {
    return _db.collection('users').doc(uid).update({
      'isMicrosoftLinkRequired': true,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> linkInstitutionalAccount({
    required String uid,
    required String rollNo,
    required String institutionalEmail,
  }) async {
    final userDoc = _db.collection('users').doc(uid);
    
    await _db.runTransaction((transaction) async {
      transaction.update(userDoc, {
        'email': institutionalEmail,
        'rollNo': rollNo,
        'isMicrosoftLinked': true,
        'isMicrosoftLinkRequired': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> updateFcmToken(String uid, String token) {
    return _db.collection('users').doc(uid).update({'fcmToken': token});
  }

  Future<void> clearFcmToken(String uid) {
    return _db.collection('users').doc(uid).update({'fcmToken': null});
  }

  Future<VistaUser?> getUserProfile(String uid) async {
    debugPrint("VISTA: getUserProfile start for UID: $uid");
    
    // 1. Try by current UID (document ID = uid) — standard case
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      final user = VistaUser.fromMap(doc.data() as Map<String, dynamic>);
      return user;
    }

    // 2. Fallback: Search by Email if UID search failed
    //    Necessary for students who previously used Email/Password but now use Microsoft.
    final currentUser = _auth.currentUser;
    if (currentUser?.email != null) {
      final String email = currentUser!.email!;
      debugPrint("VISTA: UID lookup failed. Searching fallback for email: $email");
      
      // We check for both exactly matching email and lowercase matching
      try {
        final query = await _db.collection('users')
            .where('email', whereIn: [email, email.toLowerCase()])
            .limit(1)
            .get();

        if (query.docs.isNotEmpty) {
          final existingDoc = query.docs.first;
          final existingData = existingDoc.data();
          final String oldId = existingDoc.id;

          debugPrint("VISTA: Found existing profile at doc ID: $oldId. MIGRATING to new UID: $uid");

          // Prepare the migrated data
          final updatedData = {
            ...existingData,
            'uid': uid,
            'isAccountActive': true,
            'updatedAt': FieldValue.serverTimestamp(),
          };

          // TRANSACTIONAL MIGRATION: 
          // We move the data to a new document (new UID) and delete the old one.
          await _db.runTransaction((transaction) async {
            transaction.set(_db.collection('users').doc(uid), updatedData);
            // Only delete if it's not the same ID
            if (oldId != uid) {
              transaction.delete(_db.collection('users').doc(oldId));
            }
          });

          debugPrint("VISTA: Migration SUCCESSFUL for $email");
          return VistaUser.fromMap(updatedData);
        }
      } catch (e) {
        debugPrint("VISTA: Error during fallback email query: $e");
        // Fallback might fail due to missing index or rules, 
        // in which case we proceed and probably return null.
      }
    }

    debugPrint("VISTA: No profile found even after fallback/auto-registration.");
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

      // Get last 2 digits of current year (e.g., 2024 -> 24)
      final year = DateTime.now().year % 100;
      
      // Return Prefix + Year + Counter (e.g., CA241)
      return '$prefix$year$nextVal';
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

  Future<void> updateShortStayStatus(
    String id,
    String status, {
    String? roomNumber,
    String? allotmentHostel,
    String? actionBy,
  }) async {
    final Map<String, dynamic> data = {'status': status};
    if (roomNumber != null) data['roomNumber'] = roomNumber;
    if (allotmentHostel != null) data['appliedHostel'] = allotmentHostel;
    
    if (actionBy != null) {
      if (status == 'Approved') {
        data['approvedBy'] = actionBy;
      } else if (status == 'Rejected') {
        data['rejectedBy'] = actionBy;
      }
    }

    await _db.collection('short_stay_requests').doc(id).update(data);

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

  Future<void> escalateComplaint(Complaint complaint) {
    if (complaint.targetRoles.contains('Chief Warden')) {
      return Future.value();
    }

    List<String> nextRoles = List.from(complaint.targetRoles);
    String nextRole;

    if (complaint.targetRoles.contains('Head Warden')) {
      if (!nextRoles.contains('Chief Warden')) nextRoles.add('Chief Warden');
      nextRole = 'Chief Warden';
    } else {
      if (!nextRoles.contains('Head Warden')) nextRoles.add('Head Warden');
      nextRole = 'Head Warden';
    }

    return _db.collection('complaints').doc(complaint.id).update({
      'status': 'Pending',
      'isEscalated': true,
      'studentConfirmed': null,
      'targetRole': nextRole,
      'targetRoles': nextRoles,
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

  Future<void> updateUser(String uid, Map<String, dynamic> data) {
    return _db.collection('users').doc(uid).update(data);
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
            return !s.checkInDate.isAfter(end) &&
                !s.checkOutDate.isBefore(start);
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
