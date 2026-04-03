import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { student, warden, headWarden, chiefWarden }

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
    return VistaUser(
      uid: map['uid'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      role: UserRole.values.firstWhere(
        (e) => e.toString().split('.').last == map['role'],
        orElse: () => UserRole.student,
      ),
      hostel: map['hostel'],
      roomNumber: map['roomNumber'],
      isApproved: map['isApproved'] ?? false,
      phoneNumber: map['phoneNumber'],
      fcmToken: map['fcmToken'],
      registrationNotified: map['registrationNotified'] ?? true,
      approvalNotified: map['approvalNotified'] ?? true,
      rollNo: map['rollNo'],
      programme: map['programme'],
      gender: map['gender'],
      address: map['address'],
      parentName: map['parentName'],
      parentContact: map['parentContact'],
      hasUsedShortStay: map['hasUsedShortStay'] ?? false,
      isDayScholar: map['isDayScholar'] ?? false,
      isAccountActive: map['isAccountActive'] ?? true,
      registrationNo: map['registrationNo'],
      isMicrosoftLinked: map['isMicrosoftLinked'] ?? false,
      isMicrosoftLinkRequired: map['isMicrosoftLinkRequired'] ?? false,
    );
  }
}
