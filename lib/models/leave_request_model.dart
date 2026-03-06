import 'package:cloud_firestore/cloud_firestore.dart';

class LeaveRequest {
  final String id;
  final String studentId;
  final String studentName;
  final String hostel;
  final DateTime fromDate;
  final DateTime toDate;
  final String reason;
  final String address;
  final String parentName;
  final String parentRelation;
  final String parentContact;
  final String studentContact;
  final String status; // Pending, Approved, Rejected
  final DateTime createdAt;
  final bool isNotified;
  final String lastStatusNotified;

  LeaveRequest({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.hostel,
    required this.fromDate,
    required this.toDate,
    required this.reason,
    required this.address,
    required this.parentName,
    required this.parentRelation,
    required this.parentContact,
    required this.studentContact,
    required this.status,
    required this.createdAt,
    this.isNotified = false,
    this.lastStatusNotified = 'Pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'hostel': hostel,
      'fromDate': Timestamp.fromDate(fromDate),
      'toDate': Timestamp.fromDate(toDate),
      'reason': reason,
      'address': address,
      'parentName': parentName,
      'parentRelation': parentRelation,
      'parentContact': parentContact,
      'studentContact': studentContact,
      'status': status,
      'isNotified': isNotified,
      'lastStatusNotified': lastStatusNotified,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  factory LeaveRequest.fromMap(Map<String, dynamic> map, String id) {
    return LeaveRequest(
      id: id,
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      hostel: map['hostel'] ?? '',
      fromDate: (map['fromDate'] as Timestamp? ?? Timestamp.now()).toDate(),
      toDate: (map['toDate'] as Timestamp? ?? Timestamp.now()).toDate(),
      reason: map['reason'] ?? '',
      address: map['address'] ?? '',
      parentName: map['parentName'] ?? '',
      parentRelation: map['parentRelation'] ?? '',
      parentContact: map['parentContact'] ?? '',
      studentContact: map['studentContact'] ?? '',
      status: map['status'] ?? 'Pending',
      createdAt: (map['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      isNotified: map['isNotified'] ?? true, // Default true for existing docs
      lastStatusNotified:
          map['lastStatusNotified'] ?? (map['status'] ?? 'Pending'),
    );
  }
}
