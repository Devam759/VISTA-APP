import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/vista_user.dart';
import '../models/attendance_model.dart';
import '../models/leave_request_model.dart';
import '../models/complaint_model.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  // The Firestore database was created with ID 'default' (not the standard '(default)')
  final FirebaseFirestore _db = FirebaseFirestore.instanceFor(
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

  // Sign Out
  Future<void> signOut() {
    return _auth.signOut();
  }

  // User Profile Methods
  Future<void> createUserProfile(VistaUser user) {
    return _db.collection('users').doc(user.uid).set(user.toMap());
  }

  Future<void> updateFcmToken(String uid, String token) {
    return _db.collection('users').doc(uid).update({'fcmToken': token});
  }

  Future<VistaUser?> getUserProfile(String uid) async {
    // 1. Try by UID (document ID = uid) — the standard case
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      return VistaUser.fromMap(doc.data() as Map<String, dynamic>);
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
        return VistaUser.fromMap({...data, 'uid': uid});
      }
    }
    return null;
  }

  // Attendance Methods
  Future<void> markAttendance(Attendance attendance) {
    return _db.collection('attendance').add(attendance.toMap());
  }

  Stream<List<Attendance>> getHostelAttendance(String? hostel, String date) {
    var query = _db.collection('attendance').where('date', isEqualTo: date);
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

  // Leave Methods
  Future<void> submitLeaveRequest(LeaveRequest request) {
    return _db.collection('leave_requests').add(request.toMap());
  }

  Stream<List<LeaveRequest>> getPendingLeaves(String? hostel) {
    var query = _db
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

  Future<void> updateLeaveStatus(String id, String status) {
    return _db.collection('leave_requests').doc(id).update({'status': status});
  }

  Stream<List<LeaveRequest>> getApprovedLeaves(String? hostel) {
    var query = _db
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
        .snapshots()
        .map((snapshot) {
          final list = snapshot.docs
              .map((doc) => LeaveRequest.fromMap(doc.data(), doc.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          return list;
        });
  }

  // Complaint Methods
  Future<void> submitComplaint(Complaint complaint) {
    return _db.collection('complaints').add(complaint.toMap());
  }

  Stream<List<Complaint>> getComplaintsForRole(String role, [String? hostel]) {
    var query = _db
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
    return _db.collection('complaints').doc(id).update({'status': status});
  }

  Future<void> escalateComplaint(String id) {
    return _db.collection('complaints').doc(id).update({
      'status': 'Pending',
      'isEscalated': true,
      'studentConfirmed': false,
      'targetRole': 'Head Warden',
      'targetRoles': ['Head Warden'],
    });
  }

  // Warden Approval Methods
  Stream<List<VistaUser>> getPendingRegistrations(String? hostel) {
    var query = _db
        .collection('users')
        .where('isApproved', isEqualTo: false)
        .where('role', isEqualTo: 'student');
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
    var query = _db
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
}
