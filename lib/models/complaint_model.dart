import 'package:cloud_firestore/cloud_firestore.dart';

class Complaint {
  final String id;
  final String? studentId; // Hidden from Warden if anonymous
  final String studentName; // Added for search
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
  final bool isNotified;
  final String lastStatusNotified;
  final String seqId;
  final DateTime? resolvedAt;
  final String? imageUrl;

  Complaint({
    required this.id,
    this.studentId,
    this.studentName = '',
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
    this.isNotified = false,
    this.lastStatusNotified = 'Pending',
    this.seqId = '',
    this.resolvedAt,
    this.imageUrl,
  });

  Map<String, dynamic> toMap({bool forCreate = false}) {
    final map = {
      'studentId': studentId,
      'studentName': studentName,
      'title': title,
      'description': description,
      'hostel': hostel,
      'targetRole': targetRoles.isNotEmpty ? targetRoles.first : 'Warden',
      'targetRoles': targetRoles,
      'status': status,
      'isAnonymous': isAnonymous,
      'isNotified': isNotified,
      'lastStatusNotified': lastStatusNotified,
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (!forCreate) {
      map['studentConfirmed'] = studentConfirmed;
      map['isEscalated'] = isEscalated;
      map['seqId'] = seqId;
      if (resolvedAt != null) {
        map['resolvedAt'] = Timestamp.fromDate(resolvedAt!);
      }
      if (imageUrl != null) {
        map['imageUrl'] = imageUrl;
      }
    }

    return map;
  }

  factory Complaint.fromMap(Map<String, dynamic> map, String id) {
    return Complaint(
      id: id,
      studentId: map['studentId'],
      studentName: map['studentName'] ?? '',
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
      isNotified: map['isNotified'] ?? true,
      lastStatusNotified:
          map['lastStatusNotified'] ?? (map['status'] ?? 'Pending'),
      seqId: map['seqId'] ?? '',
      resolvedAt: (map['resolvedAt'] as Timestamp?)?.toDate(),
      imageUrl: map['imageUrl'] as String?,
    );
  }
}
