import 'package:flutter/material.dart';
import '../models/vista_user.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../utils/sanitizer.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  VistaUser? _userProfile;
  bool _isLoading = false;
  // When true, the auth state listener will not update _userProfile.
  // Used during signup to prevent AuthWrapper from navigating away
  // before the success dialog is shown.
  bool _suppressAuthChanges = false;

  VistaUser? get userProfile => _userProfile;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _init();
  }

  void _init() {
    _firebaseService.userStream.listen((user) async {
      if (_suppressAuthChanges) return;
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
    if (_userProfile != null) {
      try {
        await NotificationService().init(uid);
      } catch (e) {
        debugPrint('Error initializing notifications: $e');
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> signUp(
    String name,
    String email,
    String password,
    String hostel,
    String phoneNumber,
    String rollNo,
    String programme,
    String gender,
  ) async {
    _isLoading = true;
    _suppressAuthChanges = true; // Block AuthWrapper navigation
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
        rollNo: rollNo,
        programme: programme,
        gender: gender,
      );
      // Write Firestore profile with a timeout — if Firestore is slow/unavailable
      // on web, we still consider signup successful since the Auth account exists.
      try {
        await _firebaseService
            .createUserProfile(newUser)
            .timeout(const Duration(seconds: 10));
      } catch (firestoreError) {
        debugPrint(
          '[Auth] Firestore profile write failed (non-fatal): $firestoreError',
        );
      }
      // Sign out silently — the listener is suppressed so AuthWrapper won't navigate.
      await _firebaseService.signOut();
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      _suppressAuthChanges = false; // Re-enable auth listener
      notifyListeners();
    }
  }

  Future<void> signIn(String identifier, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      String email = identifier;
      // If identifier looks like a phone number
      if (RegExp(r'^[0-9+\s-]+$').hasMatch(identifier) && identifier.length >= 10) {
        final normalizedPhone = InputSanitizer.normalizePhone(identifier);
        final resolvedEmail = await _firebaseService.getUserEmailByPhone(normalizedPhone);
        if (resolvedEmail == null) {
          throw Exception('No account found with this phone number.');
        }
        email = resolvedEmail;
      }

      final credential = await _firebaseService.signIn(email, password);
      await fetchUserProfile(credential.user!.uid);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    final uid = _firebaseService.currentUser?.uid;
    if (uid != null) {
      try {
        // Clear FCM token from Firestore first so the server stops sending
        // notifications to this device for the previous user.
        await _firebaseService.clearFcmToken(uid);
        // Delete the token on the device so a fresh one is generated for
        // the next user who logs in.
        await NotificationService().deleteToken();
      } catch (e) {
        debugPrint('Error clearing FCM token on logout: $e');
      }
    }
    await _firebaseService.signOut();
  }
}
