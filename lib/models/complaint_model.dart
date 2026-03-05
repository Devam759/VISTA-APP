import 'package:cloud_firestore/cloud_firestore.dart';

class Complaint {
  final String id;
  final String? studentId; // Hidden from Warden if anonymous
  final String title;
  final String description;
  final String hostel;
  final String targetRole; // Keep for backward compat or replace if safe
  final List<String> targetRoles; // Warden, Head Warden, Maintenance, etc.
  final String status; // Pending, Resolved
  final bool isAnonymous;
  final bool? studentConfirmed; // Yes (Resolved), No (Escalated)
  final bool isEscalated;
  final DateTime createdAt;

  Complaint({
    required this.id,
    this.studentId,
    required this.title,
    required this.description,
    required this.hostel,
    this.targetRole = 'Warden',
    required this.targetRoles,
    required this.status,
    required this.isAnonymous,
    this.studentConfirmed,
    this.isEscalated = false,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'title': title,
      'description': description,
      'hostel': hostel,
      'targetRole': targetRoles.isNotEmpty ? targetRoles.first : 'Warden',
      'targetRoles': targetRoles,
      'status': status,
      'isAnonymous': isAnonymous,
      'studentConfirmed': studentConfirmed,
      'isEscalated': isEscalated,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  factory Complaint.fromMap(Map<String, dynamic> map, String id) {
    return Complaint(
      id: id,
      studentId: map['studentId'],
      title: map['title'] ?? '',
      description: map['description'] ?? '',
      hostel: map['hostel'] ?? '',
      targetRole: map['targetRole'] ?? 'Warden',
      targetRoles: List<String>.from(
        map['targetRoles'] ?? [map['targetRole'] ?? 'Warden'],
      ),
      status: map['status'] ?? 'Pending',
      isAnonymous: map['isAnonymous'] ?? true,
      studentConfirmed: map['studentConfirmed'],
      isEscalated: map['isEscalated'] ?? false,
      createdAt: (map['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
    );
  }
}
