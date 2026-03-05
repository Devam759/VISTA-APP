import 'package:cloud_firestore/cloud_firestore.dart';

class LeaveRequest {
  final String id;
  final String studentId;
  final String studentName;
  final String hostel;
  final DateTime fromDate;
  final DateTime toDate;
  final String reason;
  final String parentName;
  final String parentContact;
  final String studentContact;
  final String status; // Pending, Approved, Rejected

  LeaveRequest({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.hostel,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    required this.parentName,
    required this.parentContact,
    required this.studentContact,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'hostel': hostel,
      'fromDate': Timestamp.fromDate(fromDate),
      'toDate': Timestamp.fromDate(toDate),
      'reason': reason,
      'parentName': parentName,
      'parentContact': parentContact,
      'studentContact': studentContact,
      'status': status,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory LeaveRequest.fromMap(Map<String, dynamic> map, String id) {
    return LeaveRequest(
      id: id,
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      hostel: map['hostel'] ?? '',
      fromDate: (map['fromDate'] as Timestamp).toDate(),
      toDate: (map['toDate'] as Timestamp).toDate(),
      reason: map['reason'] ?? '',
      parentName: map['parentName'] ?? '',
      parentContact: map['parentContact'] ?? '',
      studentContact: map['studentContact'] ?? '',
      status: map['status'] ?? 'Pending',
    );
  }
}
