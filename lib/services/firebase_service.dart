import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/vista_user.dart';
import '../models/attendance_model.dart';
import '../models/leave_request_model.dart';
import '../models/complaint_model.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

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

  Future<VistaUser?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      return VistaUser.fromMap(doc.data() as Map<String, dynamic>);
    }
    return null;
  }

  // Attendance Methods
  Future<void> markAttendance(Attendance attendance) {
    return _db.collection('attendance').add(attendance.toMap());
  }

  Stream<List<Attendance>> getHostelAttendance(String hostel, String date) {
    return _db
        .collection('attendance')
        .where('hostel', isEqualTo: hostel)
        .where('date', isEqualTo: date)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => Attendance.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  // Leave Methods
  Future<void> submitLeaveRequest(LeaveRequest request) {
    return _db.collection('leave_requests').add(request.toMap());
  }

  Stream<List<LeaveRequest>> getPendingLeaves(String hostel) {
    return _db
        .collection('leave_requests')
        .where('hostel', isEqualTo: hostel)
        .where('status', isEqualTo: 'Pending')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LeaveRequest.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Future<void> updateLeaveStatus(String id, String status) {
    return _db.collection('leave_requests').doc(id).update({'status': status});
  }

  // Complaint Methods
  Future<void> submitComplaint(Complaint complaint) {
    return _db.collection('complaints').add(complaint.toMap());
  }

  Stream<List<Complaint>> getComplaintsForRole(String role, String? hostel) {
    Query query = _db
        .collection('complaints')
        .where('targetRole', isEqualTo: role);
    if (hostel != null && role == 'Warden') {
      query = query.where('hostel', isEqualTo: hostel);
    }
    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map(
            (doc) =>
                Complaint.fromMap(doc.data() as Map<String, dynamic>, doc.id),
          )
          .toList(),
    );
  }

  Future<void> updateComplaintStatus(String id, String status) {
    return _db.collection('complaints').doc(id).update({'status': status});
  }

  Future<void> escalateComplaint(String id) {
    return _db.collection('complaints').doc(id).update({
      'isEscalated': true,
      'targetRole': 'Head Warden',
    });
  }

  // Warden Approval Methods
  Stream<List<VistaUser>> getPendingRegistrations(String hostel) {
    return _db
        .collection('users')
        .where('hostel', isEqualTo: hostel)
        .where('isApproved', isEqualTo: false)
        .where('role', isEqualTo: 'student')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => VistaUser.fromMap(doc.data()))
              .toList(),
        );
  }

  Future<void> approveStudent(String uid, String roomNumber) {
    return _db.collection('users').doc(uid).update({
      'isApproved': true,
      'roomNumber': roomNumber,
    });
  }
}
