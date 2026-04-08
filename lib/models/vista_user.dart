import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { student, warden, headWarden, chiefWarden }

/// Known-good role strings. Any value not in this set is rejected.
const _kValidRoles = {'student', 'warden', 'headWarden', 'chiefWarden'};

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
  final bool registrationNotified;
  final bool approvalNotified;
  final String? rollNo;
  final String? programme;
  final String? gender;
  final String? address;
  final bool hasUsedShortStay;
  final bool isDayScholar;
  final bool isAccountActive;
  final String? parentName;
  final String? parentContact;
  final String? registrationNo;
  final bool isMicrosoftLinked;
  final bool isMicrosoftLinkRequired;

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
    this.registrationNotified = false,
    this.approvalNotified = false,
    this.rollNo,
    this.programme,
    this.gender,
    this.address,
    this.hasUsedShortStay = false,
    this.isDayScholar = false,
    this.isAccountActive = true,
    this.parentName,
    this.parentContact,
    this.registrationNo,
    this.isMicrosoftLinked = false,
    this.isMicrosoftLinkRequired = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'role': role.toString().split('.').last,
      'hostel': hostel,
      'roomNumber': roomNumber,
      'isApproved': isApproved,
      'phoneNumber': phoneNumber,
      'fcmToken': fcmToken,
      'registrationNotified': registrationNotified,
      'approvalNotified': approvalNotified,
      'rollNo': rollNo,
      'programme': programme,
      'gender': gender,
      'address': address,
      'parentName': parentName,
      'parentContact': parentContact,
      'hasUsedShortStay': hasUsedShortStay,
      'isDayScholar': isDayScholar,
      'isAccountActive': isAccountActive,
      'registrationNo': registrationNo,
      'isMicrosoftLinked': isMicrosoftLinked,
      'isMicrosoftLinkRequired': isMicrosoftLinkRequired,
      'createdAt': FieldValue.serverTimestamp(),
    };
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
      uid:                  rawUid,
      name:                 map['name']?.toString() ?? '',
      email:                rawEmail,
      role:                 resolvedRole,
      hostel:               map['hostel']?.toString(),
      roomNumber:           map['roomNumber']?.toString(),
      // Explicit bool comparison — no implicit JS-style truthy casting.
      isApproved:           map['isApproved'] == true,
      phoneNumber:          map['phoneNumber']?.toString(),
      fcmToken:             map['fcmToken']?.toString(),
      registrationNotified: map['registrationNotified'] == true,
      approvalNotified:     map['approvalNotified'] == true,
      rollNo:               map['rollNo']?.toString(),
      programme:            map['programme']?.toString(),
      gender:               map['gender']?.toString(),
      address:              map['address']?.toString(),
      parentName:           map['parentName']?.toString(),
      parentContact:        map['parentContact']?.toString(),
      hasUsedShortStay:     map['hasUsedShortStay'] == true,
      isDayScholar:         map['isDayScholar'] == true,
    );
  }
}
