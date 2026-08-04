import 'package:cloud_firestore/cloud_firestore.dart';

class Complaint {
  final String id;
  final String? studentId; // Hidden from Warden if anonymous
  final String studentName; // Added for search
  final String title;
  final String description;
  final String hostel;
  final String targetRole; // Keep for backward compat
  final List<String> targetRoles; // Warden, Head Warden, Chief Warden
  final String currentHandler; // Current level: 'Warden' | 'Head Warden' | 'Chief Warden'
  final String status; // Pending, Resolved, Confirmed, ClosedByStudent
  final bool isAnonymous;
  final bool? studentConfirmed; // true (Confirmed), null (pending)
  final bool isEscalated;
  final DateTime createdAt;
  final DateTime? lastActionAt; // When complaint was assigned to currentHandler (for SLA)
  final DateTime? escalateAt;  // Deadline for auto-escalation
  final DateTime? resolvedAt;  // When handler marked resolved (for 2-day student confirmation window)
  final String? closedReason;  // 'Student Confirmed' | 'Closed by Student' | 'Chief Warden Closed' | 'Auto Closed'
  final bool isNotified;
  final String lastStatusNotified;
  final String seqId;
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
    this.currentHandler = 'Warden',
    required this.status,
    required this.isAnonymous,
    this.studentConfirmed,
    this.isEscalated = false,
    required this.createdAt,
    this.lastActionAt,
    this.escalateAt,
    this.resolvedAt,
    this.closedReason,
    this.isNotified = false,
    this.lastStatusNotified = 'Pending',
    this.seqId = '',
    this.imageUrl,
  });

  Map<String, dynamic> toMap({bool forCreate = false}) {
    final map = <String, dynamic>{
      'studentId': studentId,
      'studentName': studentName,
      'title': title,
      'description': description,
      'hostel': hostel,
      'targetRoles': targetRoles,
      'currentHandler': currentHandler,
      'status': status,
      'isAnonymous': isAnonymous,
      'targetRole': targetRole,
      'isNotified': isNotified,
      'lastStatusNotified': lastStatusNotified,
      'createdAt': FieldValue.serverTimestamp(),
      'lastActionAt': FieldValue.serverTimestamp(),
      // Warden-level: auto-escalate after 6 days
      'escalateAt': Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 6)),
      ),
    };

    if (!forCreate) {
      map['studentConfirmed'] = studentConfirmed;
      map['isEscalated'] = isEscalated;
      map['seqId'] = seqId;
      if (resolvedAt != null) {
        map['resolvedAt'] = Timestamp.fromDate(resolvedAt!);
      }
      if (closedReason != null) {
        map['closedReason'] = closedReason;
      }
      if (escalateAt != null) {
        map['escalateAt'] = Timestamp.fromDate(escalateAt!);
      }
    }

    if (imageUrl != null) {
      map['imageUrl'] = imageUrl;
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
      currentHandler: map['currentHandler'] ??
          (List<String>.from(map['targetRoles'] ?? ['Warden']).contains('Chief Warden')
              ? 'Chief Warden'
              : (List<String>.from(map['targetRoles'] ?? ['Warden']).contains('Head Warden')
                  ? 'Head Warden'
                  : 'Warden')),
      status: map['status'] ?? 'Pending',
      isAnonymous: map['isAnonymous'] ?? true,
      studentConfirmed: map['studentConfirmed'],
      isEscalated: map['isEscalated'] ?? false,
      createdAt: (map['createdAt'] as Timestamp? ?? Timestamp.now()).toDate(),
      lastActionAt: (map['lastActionAt'] as Timestamp?)?.toDate(),
      escalateAt: (map['escalateAt'] as Timestamp?)?.toDate(),
      resolvedAt: (map['resolvedAt'] as Timestamp?)?.toDate(),
      closedReason: map['closedReason'] as String?,
      isNotified: map['isNotified'] ?? true,
      lastStatusNotified: map['lastStatusNotified'] ?? (map['status'] ?? 'Pending'),
      seqId: map['seqId'] ?? '',
      imageUrl: map['imageUrl'] as String?,
    );
  }

  /// Returns true if this complaint is definitively closed.
  bool get isClosed =>
      status == 'Confirmed' || status == 'ClosedByStudent';

  /// Returns how many days since last action (for SLA display).
  int get daysSinceLastAction {
    final ref = lastActionAt ?? createdAt;
    return DateTime.now().difference(ref).inDays;
  }

  /// Days remaining until auto-escalation (null if no deadline or already past).
  int? get daysUntilAutoEscalate {
    if (escalateAt == null) return null;
    final remaining = escalateAt!.difference(DateTime.now()).inDays;
    return remaining < 0 ? 0 : remaining;
  }

  /// Days remaining for student to confirm before auto-close (null if not resolved).
  int? get daysUntilAutoClose {
    if (status != 'Resolved' || resolvedAt == null) return null;
    const window = 2;
    final deadline = resolvedAt!.add(const Duration(days: window));
    final remaining = deadline.difference(DateTime.now()).inDays;
    return remaining < 0 ? 0 : remaining;
  }
}
