import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:rxdart/rxdart.dart';
import '../models/vista_user.dart';
import '../models/attendance_model.dart';
import '../models/leave_request_model.dart';
import '../models/complaint_model.dart';
import '../models/short_stay_model.dart';
import '../models/attendance_record.dart';
import '../utils/rate_limiter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'cache_service.dart';

import 'audit_logger.dart';

// ── Institutional tenant configuration ──────────────────────────────────────
// JKLU Microsoft 365 tenant. Using 'common' would allow ANY Microsoft account
// to authenticate — not just JKLU institutional accounts.
// To find your tenant ID: https://login.microsoftonline.com/<yourdomain>/.well-known/openid-configuration
const _kJkluTenantId = 'organizations'; // Valid Azure AD tenant endpoint for institutional accounts (@jklu.edu.in)
// If you have the GUID, prefer it: 'xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx'

// ── Immutable status whitelists (defence-in-depth alongside Firestore rules) ──
const _kLeaveStatuses       = {'Pending', 'Approved', 'Rejected', 'Cancelled'};
const _kShortStayStatuses   = {'Pending', 'Approved', 'Rejected', 'Cancelled', 'Completed'};
const _kComplaintStatuses   = {'Pending', 'Resolved', 'Confirmed', 'ClosedByStudent', 'AutoClosed'};
const _kAttendanceStatuses  = {'Present', 'Absent', 'Late'};

final _kRoomNumRegex = RegExp(r'[^0-9]');
int _roomNum(String? room) => int.tryParse(room?.replaceAll(_kRoomNumRegex, '') ?? '') ?? 999999;

class FirebaseService {
  // Using lazy getters for all Firebase instances.
  FirebaseAuth get _auth => FirebaseAuth.instance;

  static bool _persistenceEnabled = false;
  final FirebaseFirestore _db = () {
    try {
      return FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');
    } catch (_) {
      return FirebaseFirestore.instance;
    }
  }();

  FirebaseStorage get _storage => FirebaseStorage.instanceFor(
        bucket: 'vista-jklu.firebasestorage.app',
      );

  FirebaseFirestore get db => _db;

  FirebaseService() {
    if (!_persistenceEnabled) {
      try {
        _db.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
        _persistenceEnabled = true;
        if (kDebugMode) debugPrint('[FirebaseService] Firestore offline persistence ENABLED');
      } catch (e) {
        _persistenceEnabled = true;
        if (kDebugMode) debugPrint('[FirebaseService] Firestore persistence already set: $e');
      }
    }
  }

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
    final stopwatch = Stopwatch()..start();
    debugPrint("VISTA: signInWithMicrosoft START");
    
    // Check if we have a specific tenant ID, otherwise use common
    String tenantId = 'common';
    try {
      if (dotenv.isInitialized) {
        tenantId = dotenv.env['MICROSOFT_TENANT_ID'] ?? _kJkluTenantId;
      } else {
        tenantId = _kJkluTenantId; // Never fall back to 'common'
      }
    } catch (_) {
      tenantId = _kJkluTenantId; // Never fall back to 'common'
    }
    
    final provider = OAuthProvider('microsoft.com');
    final Map<String, String> customParams = {'prompt': 'select_account'};
    if (tenantId.isNotEmpty && tenantId != 'common' && tenantId != 'organizations' && tenantId.contains('-')) {
      customParams['tenant'] = tenantId;
    }
    provider.setCustomParameters(customParams);
    provider.addScope('email');
    provider.addScope('profile');
    provider.addScope('openid');

    try {
      UserCredential? credential;
      debugPrint("VISTA: Microsoft provider setup: tenant=$tenantId");
      if (kIsWeb) {
        debugPrint("VISTA: Web - Triggering signInWithPopup...");
        // Use popup on web to avoid full page reloads and state loss
        credential = await _auth.signInWithPopup(provider);
      } else {
        debugPrint("VISTA: Mobile - Triggering signInWithProvider...");
        credential = await _auth.signInWithProvider(provider);
      }
      stopwatch.stop();
      debugPrint("VISTA: signInWithMicrosoft SUCCESS in ${stopwatch.elapsedMilliseconds}ms");
      return credential;

    } on FirebaseAuthException catch (e) {
      stopwatch.stop();
      debugPrint("VISTA: FirebaseAuthException in signInWithMicrosoft (${stopwatch.elapsedMilliseconds}ms): ${e.code}");
      if (e.code == 'account-exists-with-different-credential') {
        debugPrint("VISTA: Account exists with different credential. Linking required.");
      }
      rethrow;
    } catch (e) {
      stopwatch.stop();
      debugPrint("VISTA: Error in signInWithMicrosoft (${stopwatch.elapsedMilliseconds}ms): $e");
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

    final provider = OAuthProvider('microsoft.com');
    provider.setCustomParameters({
      'prompt': 'select_account',
    });
    provider.addScope('email');
    provider.addScope('profile');
    provider.addScope('openid');

    if (kIsWeb) {
      return await user.linkWithPopup(provider);
    } else {
      return await user.linkWithProvider(provider);
    }
  }

  // Password Reset
  Future<void> sendPasswordResetEmail(String email) {
    debugPrint('FirebaseService: Sending password reset email to $email');
    return _auth.sendPasswordResetEmail(email: email);
  }

  // User Profile Methods
  Future<void> createUserProfile(VistaUser user, {bool forCreate = false}) async {
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
            ...user.toMap(forCreate: forCreate),
            'isAccountActive': true,
            'uid': user.uid,
          };
          transaction.delete(emailDocRef);
        } else {
          finalData = user.toMap(forCreate: forCreate);
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
      await _db.collection('users').doc(user.uid).set(user.toMap(forCreate: forCreate));
    }
  }


  Future<void> setMicrosoftLinkedStatus(String uid, bool linked) async {
    debugPrint('FirebaseService: Setting Microsoft link status for $uid to $linked');
    await _db.collection('users').doc(uid).update({
      'isMicrosoftLinked': linked,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }


  Future<bool> isPhoneNumberRegistered(String phoneNumber) async {
    final doc = await _db.collection('phone_mappings').doc(phoneNumber).get();
    return doc.exists;
  }

  Future<String?> getPhoneNumberOwner(String phoneNumber) async {
    final doc = await _db.collection('phone_mappings').doc(phoneNumber).get();
    if (doc.exists) {
      return doc.data()?['email'] as String?;
    }
    return null;
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

    if (currentUser?.email?.toLowerCase() == 'mess@vista.com') {
      debugPrint("VISTA: Auto-provisioning Mess Manager profile for UID: $uid");
      final messManagerUser = VistaUser(
        uid: uid,
        name: 'Mess Manager',
        email: 'mess@vista.com',
        role: UserRole.messManager,
        isApproved: true,
        isAccountActive: true,
        createdAt: DateTime.now(),
      );
      try {
        await _db.collection('users').doc(uid).set(messManagerUser.toMap(forCreate: true));
      } catch (e) {
        debugPrint("VISTA: Error writing messManager profile to firestore: $e");
      }
      return messManagerUser;
    }

    debugPrint("VISTA: No profile found even after fallback/auto-registration.");
    return null;
  }

  // Attendance Methods
  Future<void> markAttendance(Attendance attendance) {
    if (!_kAttendanceStatuses.contains(attendance.status)) {
      throw ArgumentError(
        'Invalid attendance status "${attendance.status}". '
        'Must be one of: ${_kAttendanceStatuses.join(', ')}',
      );
    }
    return RateLimiter.run('markAttendance_${attendance.studentId}', () {
      final data = attendance.toMap()
        ..['timestamp'] = FieldValue.serverTimestamp();
      
      // Deterministic document ID to atomically prevent TOCTOU double-marking
      final docId = '${attendance.studentId}_${attendance.dateKey}';
      return _db.collection('attendance').doc(docId).set(data);
    });
  }

  Stream<List<Attendance>> getHostelAttendance(String? hostel, String date) {
    Query<Map<String, dynamic>> query = _db
        .collection('attendance')
        .where('date', isEqualTo: date);
    if (hostel != null && hostel != 'All') {
      query = query.where('hostel', isEqualTo: hostel);
    }
    query = query.limit(50);
    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => Attendance.fromMap(doc.data(), doc.id))
          .toList(),
    );
  }

  Stream<List<Attendance>> getStudentAttendance(String uid) {
    final cacheKey = CacheService.attendanceKey(uid);
    final liveStream = _db
        .collection('attendance')
        .where('studentId', isEqualTo: uid)
        .limit(50)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => Attendance.fromMap(doc.data(), doc.id))
              .toList();
          list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
          // Keep cache warm so the next calendar open is instant.
          CacheService.instance.set<List<Attendance>>(
            cacheKey,
            list,
            ttl: const Duration(minutes: 5),
          );
          return list;
        });

    // If we have a previously cached list, prepend it as the first event so
    // the attendance calendar renders immediately instead of showing a loader.
    final cached = CacheService.instance.get<List<Attendance>>(cacheKey);
    if (cached != null) {
      return Rx.concat([Stream.value(cached), liveStream]);
    }
    return liveStream;
  }



  // Leave Methods
  Future<void> submitLeaveRequest(LeaveRequest request) async {
    return RateLimiter.run('submitLeave_${request.studentId}', () async {
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
        seqId: '', // Assigned securely on the server via Cloud Functions
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
    query = query.limit(50);
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
    query = query.limit(50);
    return query.snapshots().map((snapshot) {
      final list = snapshot.docs
          .map((doc) => LeaveRequest.fromMap(doc.data(), doc.id))
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  Future<void> updateLeaveStatus(String id, String status, {String? actionUid}) async {
    if (!_kLeaveStatuses.contains(status)) {
      throw ArgumentError(
        'Invalid leave status "$status". '
        'Valid values: ${_kLeaveStatuses.join(', ')}',
      );
    }
    await _db.collection('leave_requests').doc(id).update({'status': status});
    if (actionUid != null) {
      AuditLogger.logSync(
        uid: actionUid,
        event: AuditEvent.statusChange,
        detail: 'leave_requests/$id → $status',
      );
    }
  }

  Stream<List<LeaveRequest>> getApprovedLeaves(String? hostel) {
    Query<Map<String, dynamic>> query = _db
        .collection('leave_requests')
        .where('status', isEqualTo: 'Approved');
    if (hostel != null && hostel != 'All') {
      query = query.where('hostel', isEqualTo: hostel);
    }
    query = query.limit(50);
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
        .limit(50)
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
      final updatedRequest = ShortStayRequest(
        id: request.id,
        seqId: '', // Assigned securely on the server via Cloud Functions
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
    query = query.limit(50);
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
    query = query.limit(50);
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
        .limit(50)
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
    String? actionUid,
    String? actionByName,
  }) async {
    if (!_kShortStayStatuses.contains(status)) {
      throw ArgumentError(
        'Invalid short-stay status "$status". '
        'Valid values: ${_kShortStayStatuses.join(', ')}',
      );
    }
    final Map<String, dynamic> data = {'status': status};
    if (roomNumber != null) data['roomNumber'] = roomNumber;
    if (allotmentHostel != null) {
      data['allotmentHostel'] = allotmentHostel;
      data['appliedHostel'] = allotmentHostel;
    }
    
    final docRef = _db.collection('short_stay_requests').doc(id);
    final snap = await docRef.get();
    if (!snap.exists) return;
    final snapData = snap.data();

    if (actionByName != null) {
      if (status == 'Approved') {
        data['approvedBy'] = actionByName;
        // Handle Extension Approval
        if (snapData?['pendingToDate'] != null) {
          data['checkOutDate'] = snapData!['pendingToDate'];
          data['pendingToDate'] = FieldValue.delete();
        }
      } else if (status == 'Rejected') {
        data['rejectedBy'] = actionByName;
        // Handle Extension Rejection
        if (snapData?['pendingToDate'] != null) {
          data['pendingToDate'] = FieldValue.delete();
        }
      }
    }

    await docRef.update(data);
    if (actionUid != null) {
      AuditLogger.logSync(
        uid: actionUid,
        event: AuditEvent.statusChange,
        detail: 'short_stay_requests/$id → $status',
      );
    }

    final studentId = snapData?['studentId'];
    if (studentId != null) {
      if (status == 'Approved') {
        final userSnap = await _db.collection('users').doc(studentId).get();
        if (userSnap.exists) {
          final userData = userSnap.data()!;
          final userUpdates = <String, dynamic>{
            'hasUsedShortStay': true,
            'hasActiveShortStay': true,
          };
          if (userData['hostel'] == 'Short Stay' && allotmentHostel != null) {
            userUpdates['hostel'] = allotmentHostel;
            if (roomNumber != null) userUpdates['roomNumber'] = roomNumber;
          }
          await _db.collection('users').doc(studentId).update(userUpdates);
        }
      } else if (status == 'Completed' || status == 'Rejected' || status == 'Cancelled') {
        final userSnap = await _db.collection('users').doc(studentId).get();
        if (userSnap.exists) {
          final userData = userSnap.data()!;
          final userUpdates = <String, dynamic>{
            'hasActiveShortStay': false,
          };
          // Automatically revert Day Scholars' hostel to 'Short Stay' and clear room
          if (userData['userType'] == 'Day Scholar' || userData['hostel'] != 'Short Stay') {
             userUpdates['hostel'] = 'Short Stay';
             userUpdates['roomNumber'] = null;
          }
          await _db.collection('users').doc(studentId).update(userUpdates);
        }
      }
    }
  }

  Future<void> checkOutFromShortStay(String id) async {
    final snap = await _db.collection('short_stay_requests').doc(id).get();
    if (snap.exists) {
      final studentId = snap.data()?['studentId'];
      await _db.collection('short_stay_requests').doc(id).update({
        'status': 'Completed',
        'actualCheckOutTime': FieldValue.serverTimestamp(),
      });
      if (studentId != null) {
        final userSnap = await _db.collection('users').doc(studentId).get();
        if (userSnap.exists) {
          final userData = userSnap.data()!;
          final userUpdates = <String, dynamic>{
            'hasActiveShortStay': false,
          };
          if (userData['userType'] == 'Day Scholar') {
            userUpdates['hostel'] = 'Short Stay';
            userUpdates['roomNumber'] = null;
          }
          await _db.collection('users').doc(studentId).update(userUpdates);
        }
      }
    }
  }

  Future<void> requestShortStayExtension(String id, DateTime newToDate) {
    return _db.collection('short_stay_requests').doc(id).update({
      'pendingToDate': Timestamp.fromDate(newToDate),
      'status': 'Pending', // Move back to pending for Warden to approve
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
      final now = DateTime.now();
      final data = {
        'studentId': complaint.studentId,
        'studentName': complaint.studentName,
        'title': complaint.title,
        'description': complaint.description,
        'hostel': complaint.hostel,
        'targetRole': 'Warden',
        'targetRoles': ['Warden'],
        'currentHandler': 'Warden',
        'status': 'Pending',
        'isAnonymous': complaint.isAnonymous,
        'isEscalated': false,
        'studentConfirmed': null,
        'isNotified': false,
        'lastStatusNotified': 'Pending',
        'createdAt': FieldValue.serverTimestamp(),
        'lastActionAt': FieldValue.serverTimestamp(),
        // Warden SLA: 6 days before auto-escalation to Head Warden
        'escalateAt': Timestamp.fromDate(now.add(const Duration(days: 6))),
        if (complaint.imageUrl != null) 'imageUrl': complaint.imageUrl,
      };
      await _db.collection('complaints').add(data);
    });
  }

  Future<String> uploadComplaintImage(Uint8List imageData, String studentUid) async {
    final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final Reference ref = _storage.ref().child('complaints').child(studentUid).child(fileName);
    
    final UploadTask uploadTask = ref.putData(
      imageData,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    
    final TaskSnapshot snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  Stream<List<Complaint>> getComplaintsForRole(String role, [String? hostel]) {
    Query<Map<String, dynamic>> query = _db
        .collection('complaints')
        .where('targetRoles', arrayContains: role);
    if (hostel != null && hostel != 'All') {
      query = query.where('hostel', isEqualTo: hostel);
    }
    query = query.limit(50);

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
        .limit(50)
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => Complaint.fromMap(doc.data(), doc.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  /// Warden/Head Warden marks complaint resolved — student must confirm within 2 days.
  Future<void> updateComplaintStatus(String id, String status, {String? actionUid}) async {
    if (!_kComplaintStatuses.contains(status)) {
      throw ArgumentError(
        'Invalid complaint status "$status". '
        'Valid values: ${_kComplaintStatuses.join(', ')}',
      );
    }
    final Map<String, dynamic> data = {'status': status};
    if (status == 'Confirmed') {
      data['studentConfirmed'] = true;
      data['closedReason'] = 'Student Confirmed';
      data['escalateAt'] = null; // No more escalation needed
    } else if (status == 'Resolved') {
      // Store resolvedAt — student has 2 days to confirm before auto-close
      data['resolvedAt'] = FieldValue.serverTimestamp();
      data['escalateAt'] = null; // Cancel SLA escalation once resolved
    } else if (status == 'AutoClosed') {
      data['studentConfirmed'] = true;
      data['closedReason'] = 'Auto Closed';
    }
    await _db.collection('complaints').doc(id).update(data);
    if (actionUid != null) {
      AuditLogger.logSync(
        uid: actionUid,
        event: AuditEvent.statusChange,
        detail: 'complaints/$id → $status',
      );
    }
  }

  /// Chief Warden marks resolved — closes immediately without student confirmation.
  Future<void> markResolvedByChiefWarden(String id, {String? actionUid}) async {
    await _db.collection('complaints').doc(id).update({
      'status': 'Confirmed',
      'studentConfirmed': true,
      'closedReason': 'Chief Warden Closed',
      'resolvedAt': FieldValue.serverTimestamp(),
      'escalateAt': null,
    });
    if (actionUid != null) {
      AuditLogger.logSync(
        uid: actionUid,
        event: AuditEvent.statusChange,
        detail: 'complaints/$id → Confirmed (Chief Warden Direct Close)',
      );
    }
  }

  /// Student closes the complaint without the problem being solved.
  Future<void> closeComplaintByStudent(String id, {String? actionUid}) async {
    await _db.collection('complaints').doc(id).update({
      'status': 'ClosedByStudent',
      'closedReason': 'Closed by Student',
      'escalateAt': null,
    });
    if (actionUid != null) {
      AuditLogger.logSync(
        uid: actionUid,
        event: AuditEvent.statusChange,
        detail: 'complaints/$id → ClosedByStudent',
      );
    }
  }

  /// Escalates complaint to next level and sets a new SLA deadline.
  Future<void> escalateComplaint(Complaint complaint) {
    if (complaint.currentHandler == 'Chief Warden') {
      return Future.value(); // Already at top — cannot escalate further
    }

    List<String> nextRoles = List.from(complaint.targetRoles);
    final String nextHandler;
    final int slaDays;

    if (complaint.currentHandler == 'Head Warden') {
      if (!nextRoles.contains('Chief Warden')) nextRoles.add('Chief Warden');
      nextHandler = 'Chief Warden';
      slaDays = 999; // Chief Warden level has no auto-escalation
    } else {
      // Warden → Head Warden
      if (!nextRoles.contains('Head Warden')) nextRoles.add('Head Warden');
      nextHandler = 'Head Warden';
      slaDays = 3; // Head Warden SLA: 3 days
    }

    final now = DateTime.now();

    if (complaint.studentId != null) {
      AuditLogger.logSync(
        uid: complaint.studentId!,
        event: AuditEvent.statusChange,
        detail: 'Escalated complaint ${complaint.seqId} to $nextHandler',
      );
    }

    return _db.collection('complaints').doc(complaint.id).update({
      'status': 'Pending',
      'isEscalated': true,
      'studentConfirmed': null,
      'targetRole': nextHandler,
      'targetRoles': nextRoles,
      'currentHandler': nextHandler,
      'resolvedAt': null,
      'lastActionAt': FieldValue.serverTimestamp(),
      'escalateAt': nextHandler == 'Chief Warden'
          ? null
          : Timestamp.fromDate(now.add(Duration(days: slaDays))),
    });
  }

  /// Runs on every warden-level dashboard load to:
  /// 1. Auto-escalate overdue complaints (based on escalateAt field).
  /// 2. Auto-close Resolved complaints that student has not confirmed in 2 days.
  Future<void> autoEscalateOverdueComplaints([String? role]) async {
    final nowDate = DateTime.now();

    // ── 1. Auto-escalate: find Pending complaints whose escalateAt has passed ──
    try {
      Query<Map<String, dynamic>> query = _db
          .collection('complaints')
          .where('status', isEqualTo: 'Pending');
      if (role != null) {
        query = query.where('targetRoles', arrayContains: role);
      }
      query = query.limit(50);
      final pendingSnap = await query.get();

      final escalations = <Future<void>>[];
      for (final doc in pendingSnap.docs) {
        final complaint = Complaint.fromMap(doc.data(), doc.id);
        if (complaint.currentHandler != 'Chief Warden' &&
            complaint.escalateAt != null &&
            complaint.escalateAt!.isBefore(nowDate)) {
          escalations.add(escalateComplaint(complaint));
        }
      }
      if (escalations.isNotEmpty) await Future.wait(escalations);
    } catch (e) {
      if (kDebugMode) debugPrint('[AutoEscalate] Error: $e');
    }

    // ── 2. Auto-close: find Resolved complaints older than 2 days ──
    try {
      final autoCloseDeadline = nowDate.subtract(const Duration(days: 2));
      Query<Map<String, dynamic>> query = _db
          .collection('complaints')
          .where('status', isEqualTo: 'Resolved');
      if (role != null) {
        query = query.where('targetRoles', arrayContains: role);
      }
      query = query.limit(50);
      final resolvedSnap = await query.get();

      final autoCloses = <Future<void>>[];
      for (final doc in resolvedSnap.docs) {
        final data = doc.data();
        final resolvedAt = (data['resolvedAt'] as Timestamp?)?.toDate();
        if (resolvedAt != null && resolvedAt.isBefore(autoCloseDeadline)) {
          autoCloses.add(_db.collection('complaints').doc(doc.id).update({
            'status': 'AutoClosed',
            'studentConfirmed': true,
            'closedReason': 'Auto Closed',
          }));
        }
      }
      if (autoCloses.isNotEmpty) await Future.wait(autoCloses);
    } catch (e) {
      if (kDebugMode) debugPrint('[AutoClose] Error: $e');
    }
  }

  // Warden Approval Methods
  Stream<List<VistaUser>> getPendingRegistrations(String? hostel) {
    Query<Map<String, dynamic>> query = _db
        .collection('users')
        .where('isApproved', isEqualTo: false)
        .where('role', isEqualTo: 'student');
        
    if (hostel != null && hostel != 'All') {
      query = query.where('hostel', isEqualTo: hostel);
    } else {
      query = query.where('hostel', isNotEqualTo: 'Short Stay');
    }
    query = query.limit(50);
    return query.snapshots().map(
      (snapshot) =>
          snapshot.docs.map((doc) => VistaUser.fromMap(doc.data())).toList(),
    );
  }

  Future<void> approveStudent(String uid, String roomNumber, {String? actionUid}) {
    if (actionUid != null) {
      AuditLogger.logSync(
        uid: actionUid,
        event: AuditEvent.statusChange,
        detail: 'Approved student $uid with room $roomNumber',
      );
    }
    return _db.collection('users').doc(uid).update({
      'isApproved': true,
      'roomNumber': roomNumber,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> denyStudent(String uid, {String? actionUid}) async {
    if (actionUid != null) {
      AuditLogger.logSync(
        uid: actionUid,
        event: AuditEvent.statusChange,
        detail: 'Denied student $uid',
      );
    }
    return _db.collection('users').doc(uid).update({
      'hostel': null,
      'registrationNo': null,
      'isApproved': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateUser(String uid, Map<String, dynamic> data) {
    // SECURITY: Whitelist protection against privilege escalation
    final sanitizedData = Map<String, dynamic>.from(data);
    sanitizedData.remove('role');
    sanitizedData.remove('isApproved');
    sanitizedData.remove('isAccountActive');
    return _db.collection('users').doc(uid).update(sanitizedData);
  }

  // Returns approved students for a hostel (sorted by room number)
  Stream<List<VistaUser>> getHostelStudents(String? hostel, {int limit = 500}) {
    Query<Map<String, dynamic>> query = _db
        .collection('users')
        .where('isApproved', isEqualTo: true)
        .where('role', isEqualTo: 'student');
    if (hostel != null && hostel != 'All') {
      query = query.where('hostel', isEqualTo: hostel);
    }
    query = query.limit(limit);
    return query.snapshots().map((snapshot) {
      final list = snapshot.docs.map((doc) => VistaUser.fromMap(doc.data())).toList();
      list.sort((a, b) {
        final numA = _roomNum(a.roomNumber);
        final numB = _roomNum(b.roomNumber);
        if (numA != numB) return numA.compareTo(numB);
        return (a.roomNumber ?? '').compareTo(b.roomNumber ?? '');
      });
      return list;
    });
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
    query = query.limit(50);
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
    query = query.limit(50);

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
    query = query.limit(50);

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
    query = query.limit(50);
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
    query = query.limit(50);
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

  // ── Unified Warden Data Streams ──

  /// Combines Students, Attendance, and Approved Leaves into a single source of truth
  /// for attendance monitoring. Used across base Warden, Head, and Chief warden portals.
  Stream<List<AttendanceRecord>> getUnifiedAttendanceStream(String? hostel, DateTime date) {
    final dateStr = '${date.day.toString().padLeft(2, '0')}-${date.month.toString().padLeft(2, '0')}-${date.year}';
    final startOfDay = DateTime(date.year, date.month, date.day);

    return CombineLatestStream.combine3(
      getHostelStudents(hostel ?? 'All'),
      getHostelAttendance(hostel, dateStr),
      getApprovedLeaves(hostel),
      (List<VistaUser> students, List<Attendance> attendanceList, List<LeaveRequest> leaveRequests) {
        final records = students.map((student) {
          final att = attendanceList.where((a) => a.studentId == student.uid).firstOrNull;
          final onLeave = leaveRequests.any((l) =>
              l.studentId == student.uid &&
              l.checkInTime == null &&
              !startOfDay.isBefore(DateTime(l.fromDate.year, l.fromDate.month, l.fromDate.day)) &&
              !startOfDay.isAfter(DateTime(l.toDate.year, l.toDate.month, l.toDate.day)));

          return AttendanceRecord(student, att, onLeave: onLeave);
        }).toList();

        records.sort((a, b) {
          final numA = _roomNum(a.student.roomNumber);
          final numB = _roomNum(b.student.roomNumber);
          if (numA != numB) return numA.compareTo(numB);
          return (a.student.roomNumber ?? '').compareTo(b.student.roomNumber ?? '');
        });

        return records;
      },
    );
  }

  /// Unified stream for fetching and searching leaves across portals.
  Stream<List<LeaveRequest>> getUnifiedLeavesStream(String? hostel) {
    return getHostelLeaves(hostel ?? 'All').map((list) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Unified stream for fetching and searching short stay requests.
  Stream<List<ShortStayRequest>> getUnifiedShortStaysStream(String? hostel) {
    return getHostelShortStays(hostel ?? 'All').map((list) {
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    });
  }

  /// Unified stream for fetching and searching students (sorted by room number).
  Stream<List<VistaUser>> getUnifiedStudentsStream(String? hostel) {
    return getHostelStudents(hostel ?? 'All');
  }

  /// Unified stream for fetching pending registrations.
  Stream<List<VistaUser>> getPendingRegistrationsStream(String? hostel) {
    return getPendingRegistrations(hostel ?? 'All').map((list) {
      try {
        list.sort((a, b) => (a.registrationNo ?? '').compareTo(b.registrationNo ?? ''));
      } catch (e) {
        debugPrint('VISTA Error sorting pending registrations: $e');
      }
      return list;
    });
  }

  /// Static helper to check if a student is currently on approved leave.
  static bool isStudentOnLeave(String uid, List<LeaveRequest> approvedLeaves) {
    final now = DateTime.now();
    return approvedLeaves.any((l) {
      if (l.studentId != uid) return false;
      if (l.checkInTime != null && !now.isBefore(l.checkInTime!)) return false;
      return l.fromDate.isBefore(now) && l.toDate.isAfter(now);
    });
  }

  /// Static helper to check if a student is currently on an approved short stay.
  static bool isStudentOnShortStay(String uid, List<ShortStayRequest> approvedShortStays) {
    final now = DateTime.now();
    return approvedShortStays.any(
      (ss) => ss.studentId == uid && ss.status == 'Approved' && ss.checkInDate.isBefore(now) && ss.checkOutDate.isAfter(now),
    );
  }

  /// Sends a manual attendance reminder to a student.
  Future<void> sendAttendanceNudge({
    required String studentId,
    required String wardenId,
    required String wardenName,
    required String hostel,
  }) async {
    await _db.collection('notifications').add({
      'studentId': studentId,
      'wardenId': wardenId,
      'title': 'Attendance Reminder',
      'body': 'Warden $wardenName from $hostel is requesting you to mark your attendance.',
      'type': 'attendance_nudge',
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Also log the nudge in audit logs
    AuditLogger.logSync(
      uid: wardenId,
      event: AuditEvent.statusChange,
      detail: 'Sent attendance nudge to student $studentId',
    );
  }

  /// Stream of notifications for a specific student.
  Stream<List<Map<String, dynamic>>> getStudentNotifications(String studentId) {
    return _db
        .collection('notifications')
        .where('studentId', isEqualTo: studentId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => {...doc.data(), 'id': doc.id}).toList());
  }
}
