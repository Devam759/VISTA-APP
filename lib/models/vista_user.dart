import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/sanitizer.dart';

enum UserRole { student, warden, headWarden, chiefWarden, admin, messManager }

extension UserRoleExtension on UserRole {
  String get displayName {
    switch (this) {
      case UserRole.student:
        return 'Student';
      case UserRole.warden:
        return 'Warden';
      case UserRole.headWarden:
        return 'Head Warden';
      case UserRole.chiefWarden:
        return 'Chief Warden';
      case UserRole.admin:
        return 'Admin';
      case UserRole.messManager:
        return 'Mess Manager';
    }
  }
}

/// Known-good role strings. Any value not in this set is rejected.
const _kValidRoles = {'student', 'warden', 'headWarden', 'chiefWarden', 'admin', 'messManager'};

class VistaUser {
  final String uid;
  final String name;
  final String email;
  final UserRole role;
  final String? hostel; // BH1, BH2, GH1, GH2
  final String? roomNumber;
  final bool isApproved;
  final String? phoneNumber;
  final String? fcmToken;
  final String? rollNo;
  final String? programme;
  final String? gender;
  final String? address;
  final bool hasUsedShortStay;
  final bool isDayScholar;
  final bool isAccountActive;
  final String? parentName;
  final String? parentContact;
  final String? parentEmail;
  final String? registrationNo;
  final bool isMicrosoftLinked;
  final bool hasActiveShortStay;
  final DateTime? createdAt;

  VistaUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.hostel,
    this.roomNumber,
    this.isApproved = false,
    this.phoneNumber,
    this.fcmToken,
    this.rollNo,
    this.programme,
    this.gender,
    this.address,
    this.hasUsedShortStay = false,
    this.isDayScholar = false,
    this.isAccountActive = true,
    this.parentName,
    this.parentContact,
    this.parentEmail,
    this.registrationNo,
    this.isMicrosoftLinked = false,
    this.hasActiveShortStay = false,
    this.createdAt,
  });

  Map<String, dynamic> toMap({bool forCreate = false}) {
    final map = {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role.toString().split('.').last,
      'hostel': hostel,
      'roomNumber': roomNumber,
      'isApproved': isApproved,
      'phoneNumber': phoneNumber != null ? InputSanitizer.formatPhoneWithCountryCode(phoneNumber!) : null,
      'fcmToken': fcmToken,
      'rollNo': rollNo,
      'programme': programme,
      'gender': gender,
      'address': address,
      'parentName': parentName,
      'parentContact': parentContact != null ? InputSanitizer.formatPhoneWithCountryCode(parentContact!) : null,
      'parentEmail': parentEmail,
      'hasUsedShortStay': hasUsedShortStay,
      'isDayScholar': isDayScholar,
      'isAccountActive': isAccountActive,
      'registrationNo': registrationNo,
      'isMicrosoftLinked': isMicrosoftLinked,
      'hasActiveShortStay': hasActiveShortStay,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };

    if (forCreate) {
      map.remove('fcmToken');
      map.remove('hasUsedShortStay');
    }

    return map;
  }

  factory VistaUser.fromMap(Map<String, dynamic> map) {
    // ── Hard validation: reject documents with missing or empty identity fields.
    final rawUid   = map['uid']?.toString()   ?? '';
    final rawEmail = map['email']?.toString() ?? '';
    final rawRole  = map['role']?.toString()  ?? '';

    if (rawUid.isEmpty) {
      throw StateError('VistaUser: document is missing required field "uid"');
    }
    if (rawEmail.isEmpty) {
      throw StateError('VistaUser: document is missing required field "email"');
    }
    if (rawRole.isEmpty) {
      throw StateError('VistaUser: document is missing required field "role"');
    }

    // ── Role deserialization: unknown values are rejected outright.
    // SECURITY: do NOT silently fall back to UserRole.student.
    // A document with role="superAdmin" or role="" must never produce
    // a valid VistaUser; it should force sign-out in the auth listener.
    if (!_kValidRoles.contains(rawRole)) {
      throw StateError(
        'VistaUser: unrecognized role "$rawRole" — '
        'document rejected. This may indicate Firestore data corruption or '
        'a privilege escalation attempt. Contact the administrator.',
      );
    }

    final resolvedRole = UserRole.values.firstWhere(
      (e) => e.toString().split('.').last == rawRole,
    );

    return VistaUser(
      uid: rawUid,
      name: map['name']?.toString() ?? '',
      email: rawEmail,
      role: resolvedRole,
      hostel: map['hostel']?.toString(),
      roomNumber: map['roomNumber']?.toString(),
      // Explicit bool comparison — no implicit JS-style truthy casting.
      isApproved: map['isApproved'] == true,
      phoneNumber: (map['phoneNumber'] != null && map['phoneNumber'].toString().isNotEmpty)
          ? InputSanitizer.formatPhoneWithCountryCode(map['phoneNumber'].toString())
          : null,
      fcmToken: map['fcmToken']?.toString(),
      rollNo: map['rollNo']?.toString(),
      programme: map['programme']?.toString(),
      gender: map['gender']?.toString(),
      address: map['address']?.toString(),
      parentName: map['parentName']?.toString(),
      parentContact: (map['parentContact'] != null && map['parentContact'].toString().isNotEmpty)
          ? InputSanitizer.formatPhoneWithCountryCode(map['parentContact'].toString())
          : null,
      parentEmail: map['parentEmail']?.toString(),
      hasUsedShortStay: map['hasUsedShortStay'] == true,
      isDayScholar: map['isDayScholar'] == true,
      // ── FIXED: Missing field mappings identified post-merge
      registrationNo: map['registrationNo']?.toString(),
      isAccountActive: map['isAccountActive'] ?? true, // Default to true if missing (legacy/warden docs)
       isMicrosoftLinked: map['isMicrosoftLinked'] == true,
      hasActiveShortStay: map['hasActiveShortStay'] == true,
      createdAt: map['createdAt'] is Timestamp 
          ? (map['createdAt'] as Timestamp).toDate() 
          : null,
    );
  }
}
