import 'package:cloud_firestore/cloud_firestore.dart';

class Attendance {
  final String id;
  final String studentId;
  final String studentName;
  final String hostel;
  final String roomNumber;
  final DateTime timestamp;
  final String status; // Present, Absent, Late

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
      'date': "${timestamp.day.toString().padLeft(2, '0')}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.year}",
    };
  }

  factory Attendance.fromMap(Map<String, dynamic> map, String id) {
    DateTime parsedTimestamp;
    final rawTs = map['timestamp'];

    if (rawTs is Timestamp) {
      parsedTimestamp = rawTs.toDate();
    } else if (rawTs is String) {
      parsedTimestamp = DateTime.tryParse(rawTs) ?? DateTime.now();
    } else if (rawTs is int) {
      parsedTimestamp = DateTime.fromMillisecondsSinceEpoch(rawTs);
    } else {
      parsedTimestamp = DateTime.now();
    }

    // Capitalize status properly (e.g., 'present' -> 'Present')
    String parsedStatus = (map['status'] as String?)?.trim() ?? 'Present';
    if (parsedStatus.toLowerCase() == 'present') {
      parsedStatus = 'Present';
    } else if (parsedStatus.toLowerCase() == 'late') {
      parsedStatus = 'Late';
    } else if (parsedStatus.toLowerCase() == 'absent') {
      parsedStatus = 'Absent';
    }

    return Attendance(
      id: id,
      studentId: map['studentId'] as String? ?? '',
      studentName: map['studentName'] as String? ?? '',
      hostel: map['hostel'] as String? ?? '',
      roomNumber: map['roomNumber'] as String? ?? '',
      timestamp: parsedTimestamp,
      status: parsedStatus,
    );
  }
}
