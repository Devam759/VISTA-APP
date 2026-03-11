import 'package:cloud_firestore/cloud_firestore.dart';

class ShortStayRequest {
  final String id;
  final String seqId;
  final String studentId;
  final String studentName;
  final String rollNo;
  final String programme;
  final String gender;
  final String email;
  final String contactNo;
  final String address;
  final String reason;
  final String parentName;
  final String parentContact;
  final DateTime checkInDate;
  final DateTime checkOutDate;
  final String status; // Pending, Approved, Rejected, Completed
  final String appliedHostel;
  final String? roomNumber;
  final DateTime createdAt;
  final DateTime? actualCheckOutTime;
  final DateTime? pendingToDate; // For extension requests

  ShortStayRequest({
    required this.id,
    required this.seqId,
    required this.studentId,
    required this.studentName,
    required this.rollNo,
    required this.programme,
    required this.gender,
    required this.email,
    required this.contactNo,
    required this.address,
    required this.reason,
    required this.parentName,
    required this.parentContact,
    required this.checkInDate,
    required this.checkOutDate,
    required this.status,
    required this.appliedHostel,
    this.roomNumber,
    required this.createdAt,
    this.actualCheckOutTime,
    this.pendingToDate,
  });

  Map<String, dynamic> toMap() {
    return {
      'seqId': seqId,
      'studentId': studentId,
      'studentName': studentName,
      'rollNo': rollNo,
      'programme': programme,
      'gender': gender,
      'email': email,
      'contactNo': contactNo,
      'address': address,
      'reason': reason,
      'parentName': parentName,
      'parentContact': parentContact,
      'checkInDate': Timestamp.fromDate(checkInDate),
      'checkOutDate': Timestamp.fromDate(checkOutDate),
      'status': status,
      'appliedHostel': appliedHostel,
      'roomNumber': roomNumber,
      'createdAt': Timestamp.fromDate(createdAt),
      'actualCheckOutTime': actualCheckOutTime != null 
          ? Timestamp.fromDate(actualCheckOutTime!) 
          : null,
      'pendingToDate': pendingToDate != null 
          ? Timestamp.fromDate(pendingToDate!) 
          : null,
    };
  }

  factory ShortStayRequest.fromMap(Map<String, dynamic> map, String id) {
    return ShortStayRequest(
      id: id,
      seqId: map['seqId'] ?? '',
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      rollNo: map['rollNo'] ?? '',
      programme: map['programme'] ?? '',
      gender: map['gender'] ?? '',
      email: map['email'] ?? '',
      contactNo: map['contactNo'] ?? '',
      address: map['address'] ?? '',
      reason: map['reason'] ?? '',
      parentName: map['parentName'] ?? '',
      parentContact: map['parentContact'] ?? '',
      checkInDate: (map['checkInDate'] as Timestamp).toDate(),
      checkOutDate: (map['checkOutDate'] as Timestamp).toDate(),
      status: map['status'] ?? 'Pending',
      appliedHostel: map['appliedHostel'] ?? '',
      roomNumber: map['roomNumber'],
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      actualCheckOutTime: (map['actualCheckOutTime'] as Timestamp?)?.toDate(),
      pendingToDate: (map['pendingToDate'] as Timestamp?)?.toDate(),
    );
  }
}
