import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { student, warden, headWarden }

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
    );
  }
}
