import 'package:flutter/material.dart';
import '../models/vista_user.dart';
import '../services/firebase_service.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  VistaUser? _userProfile;
  bool _isLoading = false;

  VistaUser? get userProfile => _userProfile;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _init();
  }

  void _init() {
    _firebaseService.userStream.listen((user) async {
      if (user != null) {
        await fetchUserProfile(user.uid);
      } else {
        _userProfile = null;
        notifyListeners();
      }
    });
  }

  Future<void> fetchUserProfile(String uid) async {
    _isLoading = true;
    notifyListeners();
    _userProfile = await _firebaseService.getUserProfile(uid);
    _isLoading = false;
    notifyListeners();
  }

  Future<void> signUp(
    String name,
    String email,
    String password,
    String hostel,
    String phoneNumber,
  ) async {
    _isLoading = true;
    notifyListeners();
    try {
      final credential = await _firebaseService.signUp(email, password);
      final newUser = VistaUser(
        uid: credential.user!.uid,
        name: name,
        email: email,
        role: UserRole.student,
        hostel: hostel,
        phoneNumber: phoneNumber,
        isApproved: false,
      );
      await _firebaseService.createUserProfile(newUser);
      await fetchUserProfile(credential.user!.uid);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signIn(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final credential = await _firebaseService.signIn(email, password);
      await fetchUserProfile(credential.user!.uid);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _firebaseService.signOut();
  }
}
