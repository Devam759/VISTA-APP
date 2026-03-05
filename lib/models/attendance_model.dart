import 'package:cloud_firestore/cloud_firestore.dart';

class Attendance {
  final String id;
  final String studentId;
  final String studentName;
  final String hostel;
  final String roomNumber;
  final DateTime timestamp;
  final String status; // Present, Absent

  Attendance({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.hostel,
    required this.roomNumber,
    required this.timestamp,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName,
      'hostel': hostel,
      'roomNumber': roomNumber,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status,
      'date': "${timestamp.year}-${timestamp.month}-${timestamp.day}",
    };
  }

  factory Attendance.fromMap(Map<String, dynamic> map, String id) {
    return Attendance(
      id: id,
      studentId: map['studentId'] ?? '',
      studentName: map['studentName'] ?? '',
      hostel: map['hostel'] ?? '',
      roomNumber: map['roomNumber'] ?? '',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      status: map['status'] ?? 'Absent',
    );
  }
}
