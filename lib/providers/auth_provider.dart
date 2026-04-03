import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vista_user.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';
import '../services/audit_logger.dart';
import '../utils/sanitizer.dart';
import '../utils/rate_limiter.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  VistaUser? _userProfile;
  bool _isLoading = false;

  // When true, the auth state listener will not update _userProfile.
  // Used during signup to prevent AuthWrapper from navigating away
  // before the success dialog is shown.
  bool _suppressAuthChanges = false;
  bool _isInitialized = false;
  String? _isFetchingProfileForUid;
  bool _hasProfileLoadError = false;
  
  // Account Linking State
  AuthCredential? _pendingMicrosoftCredential;
  String? _pendingEmail;

  VistaUser? get userProfile => _userProfile;
  bool get isLoading => _isLoading || !_isInitialized;
  bool get hasProfileLoadError => _hasProfileLoadError;
  AuthCredential? get pendingMicrosoftCredential => _pendingMicrosoftCredential;
  String? get pendingEmail => _pendingEmail;
  User? get firebaseUser => _firebaseService.currentUser;

  AuthProvider() {
    _init();
  }

  void clearPendingCredential() {
    _pendingMicrosoftCredential = null;
    _pendingEmail = null;
    notifyListeners();
  }

  Future<void> _init() async {
    debugPrint("VISTA: AuthProvider initializing...");
    // 1. Check for current user first
    if (_firebaseService.currentUser != null) {
      debugPrint("VISTA: Found existing user: ${_firebaseService.currentUser!.email}. Fetching profile...");
      await fetchUserProfile(_firebaseService.currentUser!.uid);
    }

    // 2. Wait for redirect result (Web only)
    await _firebaseService.handleRedirectResult();

    // 3. Start listening to auth changes
    _firebaseService.userStream.listen((user) async {
      debugPrint("VISTA: Auth state changed. User: ${user?.email ?? 'null'}");
      if (_suppressAuthChanges) {
        debugPrint("VISTA: Auth changes suppressed.");
        return;
      }
      if (user != null) {
        // If we already have a profile for this user, don't re-fetch unless it's a different UID
        if (_userProfile?.uid != user.uid) {
           _hasProfileLoadError = false; // Reset error on new user
           await fetchUserProfile(user.uid);
        }
      } else {
        debugPrint("VISTA: User is null, clearing profile.");
        _userProfile = null;
        _hasProfileLoadError = false;
        _isInitialized = true;
        notifyListeners();
      }
    });

    // 4. Final safety check: if we are still not initialized after redirect/initial check, mark it.
    if (!_isInitialized) {
       _isInitialized = true;
       notifyListeners();
    }
  }

  Future<void> fetchUserProfile(String uid, {int retries = 2, bool retryOnNull = true}) async {
    // Prevent redundant fetches for the same UID while one is in progress
    // BUT allow internal recursive retries (indicated by retries < 2)
    if (_isFetchingProfileForUid == uid && retries == 2) {
      debugPrint("VISTA: Profile fetch already in progress for $uid. Skipping redundant call.");
      return;
    }

    
    debugPrint("VISTA: fetchUserProfile for $uid (Retries remaining: $retries, retryOnNull: $retryOnNull)");
    _isFetchingProfileForUid = uid;
    _isLoading = true;
    _hasProfileLoadError = false;
    notifyListeners();
    try {
      _userProfile = await _firebaseService.getUserProfile(uid);
    } on StateError catch (e) {
      // VistaUser.fromMap threw — bad/corrupted Firestore document.
      // Force sign-out immediately: do not leave the user in a limbo state.
      debugPrint('[AuthProvider] Rejected user document: $e');
      await AuditLogger.log(
        uid: uid,
        event: AuditEvent.securityViolation,
        detail: 'User document rejected: ${e.message}',
      );
      _userProfile = null;
      await _firebaseService.signOut();
      notifyListeners();
      return;
    } catch (e) {
      debugPrint('[AuthProvider] fetchUserProfile error: $e');
      _userProfile = null;
    }

    if (_userProfile != null) {
      try {
        await NotificationService().init(_userProfile!.uid);
      } catch (e) {
        debugPrint('[AuthProvider] Notification init error: $e');
      }
    }
    _isLoading = false;
    notifyListeners();
  }

  String _normalizeName(String name) {
    if (name.isEmpty) return name;
    return name.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  Future<void> signUp(
    String name,
    String email,
    String password,
    String hostel,
    String phoneNumber,
    String rollNo,
    String programme,
    String gender, {
    String? registrationNo,
    bool isMicrosoftLinked = false,
    String? parentName,
    String? parentContact,
    bool isApproved = false,
    bool staySignedIn = false,
    bool isDayScholar = false,
  }) async {
    _isLoading = true;
    // Always suppress auth changes during signup to prevent race conditions.
    _suppressAuthChanges = true;
    notifyListeners();
    try {
      // Check phone uniqueness first
      final ownerEmail = await _firebaseService.getPhoneNumberOwner(phoneNumber);
      if (ownerEmail != null && ownerEmail != email) {
        throw Exception('This phone number is already registered with another account ($ownerEmail).');
      }

      final credential = await _firebaseService.signUp(email, password);
      final newUser = VistaUser(
        uid: credential.user!.uid,
        name: _normalizeName(name),
        email: email,
        role: UserRole.student,
        hostel: hostel,
        phoneNumber: phoneNumber,
        isApproved: isApproved,
        rollNo: rollNo,
        registrationNo: registrationNo,
        programme: programme,
        gender: gender,
        parentName: parentName,
        parentContact: parentContact,
        isDayScholar: isDayScholar,
        isMicrosoftLinked: isMicrosoftLinked,
        isMicrosoftLinkRequired: false,
      );
      
      try {
        await _firebaseService
            .createUserProfile(newUser);
      } catch (firestoreError) {
        debugPrint(
          '[Auth] Firestore profile write failed: $firestoreError',
        );
        rethrow; // If profile creation fails, we should probably know
      }

      // Always set the profile locally so AuthWrapper can see the change
      // before potentially redirection OR fetchUserProfile handles it.
      _userProfile = newUser;
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      _suppressAuthChanges = false;
      notifyListeners();
    }
    if (staySignedIn && _userProfile != null) {
      await fetchUserProfile(_userProfile!.uid);
    }
  }

  Future<void> completeProfile({
    required String name,
    required String email,
    required String hostel,
    required String phoneNumber,
    required String rollNo,
    required String programme,
    required String gender,
    String? registrationNo,
    bool isMicrosoftLinked = false,
    String? parentName,
    String? parentContact,
    bool isApproved = false,
    bool staySignedIn = false,
    bool isDayScholar = false,
  }) async {
    final user = _firebaseService.currentUser;
    if (user == null) throw Exception("No authenticated user found.");

    _isLoading = true;
    _suppressAuthChanges = true;
    notifyListeners();

    try {
      // Check phone uniqueness
      final ownerEmail = await _firebaseService.getPhoneNumberOwner(phoneNumber);
      if (ownerEmail != null && ownerEmail != email) {
        throw Exception('This phone number is already registered with another account ($ownerEmail).');
      }

      final newUser = VistaUser(
        uid: user.uid,
        name: _normalizeName(name),
        email: email,
        role: UserRole.student,
        hostel: hostel,
        phoneNumber: phoneNumber,
        isApproved: isApproved,
        rollNo: rollNo,
        registrationNo: registrationNo,
        programme: programme,
        gender: gender,
        parentName: parentName,
        parentContact: parentContact,
        isDayScholar: isDayScholar,
        isMicrosoftLinked: isMicrosoftLinked,
        isMicrosoftLinkRequired: false,
      );

      await _firebaseService.createUserProfile(newUser);

      _userProfile = newUser;
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      _suppressAuthChanges = false;
      notifyListeners();
    }

    if (staySignedIn && _userProfile != null) {
      await fetchUserProfile(_userProfile!.uid);
    }
  }

  // OTP Verification
  String? _verificationId;

  Future<void> sendOTP(
    String phoneNumber, {
    required Function(String, int?) onCodeSent,
    required Function(String) onError,
    Object? webVerifier,
  }) async {
    try {
      await _firebaseService.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        webVerifier: webVerifier,
        onCodeSent: (verId, forceResend) {
          _verificationId = verId;
          onCodeSent(verId, forceResend);
        },
        onVerificationFailed: (e) =>
            onError(e.message ?? 'Verification failed'),
        onVerificationCompleted: (credential) async {
          // Auto-retrieval path — handled in the UI layer for now.
        },
      );
    } catch (e) {
      onError(e.toString());
    }
  }

  Future<void> verifyOTP(String smsCode) async {
    if (_verificationId == null) throw Exception('No verification ID found');
    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: smsCode,
    );

    final currentUser = _firebaseService.currentUser;
    if (currentUser != null) {
      await currentUser.linkWithCredential(credential);
    } else {
      await FirebaseAuth.instance.signInWithCredential(credential);
    }
  }


  Future<void> sendPasswordReset(String email) async {
    _isLoading = true;
    notifyListeners();
    try {
      await _firebaseService.sendPasswordResetEmail(email);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Returns null if login is allowed; a display message if the account is locked.
  Future<String?> checkLoginLockout(String identifier) {
    return LoginThrottle.checkLockout(identifier);
  }

  /// How many seconds remain in the current lockout for [identifier].
  Future<int> lockoutRemainingSeconds(String identifier) {
    return LoginThrottle.lockoutRemainingSeconds(identifier);
  }

  Future<void> signIn(String identifier, String password) async {
    _isLoading = true;
    notifyListeners();

    // ── Step 1: Check for active lockout before touching Firebase Auth.
    final lockoutMsg = await LoginThrottle.checkLockout(identifier);
    if (lockoutMsg != null) {
      _isLoading = false;
      notifyListeners();
      throw Exception(lockoutMsg);
    }

    try {
      String email = identifier;
      // If identifier looks like a phone number, resolve to email first.
      if (RegExp(r'^[0-9+\s-]+$').hasMatch(identifier) &&
          identifier.length >= 10) {
        final normalizedPhone = InputSanitizer.normalizePhone(identifier);
        final resolvedEmail = await _firebaseService.getPhoneNumberOwner(
          normalizedPhone,
        );
        if (resolvedEmail == null) {
          // Do NOT tell the caller whether the phone exists — enumeration protection.
          await LoginThrottle.onFailure(identifier);
          await AuditLogger.logAnonymous(
            event: AuditEvent.loginFailed,
            detail: 'Phone lookup returned no account.',
          );
          throw Exception('Login failed. Please check your credentials.');
        }
        email = resolvedEmail;
      }

      final credential = await _firebaseService.signIn(email, password);

      // ── Success path ──────────────────────────────────────────────────
      await LoginThrottle.onSuccess(identifier);
      await AuditLogger.log(
        uid: credential.user!.uid,
        event: AuditEvent.loginSuccess,
        detail: 'Signed in via ${identifier.contains('@') ? 'email' : 'phone'}.',
      );
      await fetchUserProfile(credential.user!.uid);
    } on FirebaseAuthException catch (e) {
      // Record the failure for throttling.
      await LoginThrottle.onFailure(identifier);
      await AuditLogger.logAnonymous(
        event: AuditEvent.loginFailed,
        detail: 'FirebaseAuthException code=${e.code}',
      );
      _isLoading = false;
      notifyListeners();
      rethrow;
    } catch (e) {
      await LoginThrottle.onFailure(identifier);
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signOut() async {
    final uid = _firebaseService.currentUser?.uid;
    if (uid != null) {
      try {
        await AuditLogger.log(
          uid: uid,
          event: AuditEvent.logout,
          detail: 'User signed out.',
        );
        await _firebaseService.clearFcmToken(uid);
        await NotificationService().deleteToken();
      } catch (e) {
        debugPrint('[AuthProvider] signOut cleanup error: $e');
      }
    }
    await _firebaseService.signOut();
  }

  Future<void> signInWithMicrosoft() async {
    _isLoading = true;
    notifyListeners();
    clearPendingCredential();
    try {
      final credential = await _firebaseService.signInWithMicrosoft();
      if (credential.user != null) {
        await fetchUserProfile(credential.user!.uid, retryOnNull: false);
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'account-exists-with-different-credential') {
        _pendingMicrosoftCredential = e.credential;
        _pendingEmail = e.email;
        debugPrint('VISTA: Account exists with different credential. Linking required. Email: \${_pendingEmail}, Credential: \${_pendingMicrosoftCredential != null ? "FOUND" : "NULL"}');
        _isLoading = false;
        notifyListeners();
        return;
      }
      rethrow;
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> linkAccountWithPassword(String password) async {
    if (_pendingMicrosoftCredential == null || _pendingEmail == null) {
      throw Exception("No pending Microsoft account to link.");
    }

    _isLoading = true;
    _suppressAuthChanges = true;
    notifyListeners();

    try {
      debugPrint('VISTA: Signing in with email/pass to prove ownership...');
      final credential = await _firebaseService.signIn(_pendingEmail!, password);
      
      try {
        if (kIsWeb) {
          debugPrint('VISTA: Web - Triggering linkWithPopup...');
          await _firebaseService.linkWithMicrosoftPopup();
        } else if (_pendingMicrosoftCredential != null) {
          await _firebaseService.linkWithMicrosoftCredential(_pendingMicrosoftCredential!);
        }
        
        debugPrint('VISTA: Linking SUCCESS. Finalizing login...');
        _suppressAuthChanges = false;
        final uid = credential.user!.uid;
        clearPendingCredential();
        await fetchUserProfile(uid);
      } catch (linkingError) {
        debugPrint('VISTA: Linking step failed: \$linkingError. Signing out.');
        _suppressAuthChanges = false;
        await _firebaseService.signOut();
        rethrow;
      }
    } catch (e) {
      debugPrint('VISTA: Error in linkAccountWithPassword: \$e');
      _suppressAuthChanges = false;
      _isLoading = false;
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> linkInstitutionalAccount({String? rollNo}) async {
    final user = _firebaseService.currentUser;
    if (user == null) throw Exception("No user signed in to link.");

    _isLoading = true;
    _suppressAuthChanges = true;
    notifyListeners();

    try {
      if (kIsWeb) {
        await _firebaseService.linkWithMicrosoftPopup();
      } else {
        final credential = await _firebaseService.signInWithMicrosoft();
        if (credential.credential != null) {
          await _firebaseService.linkWithMicrosoftCredential(
            credential.credential!,
          );
        }
      }

      final updatedUser = _firebaseService.currentUser;
      final linkedEmail = updatedUser?.email;

      if (rollNo != null && linkedEmail != null) {
        await _firebaseService.linkInstitutionalAccount(
          uid: user.uid,
          rollNo: rollNo,
          institutionalEmail: linkedEmail,
        );
      } else {
        await _firebaseService.setMicrosoftLinkedStatus(user.uid, true);
      }

      await fetchUserProfile(user.uid);

      _suppressAuthChanges = false;
    } catch (e) {
      _suppressAuthChanges = false;
      _isLoading = false;
      notifyListeners();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> linkMicrosoftAccount(String rollNo) async {
    final user = _firebaseService.currentUser;
    if (user == null) throw Exception("No authenticated user found.");

    _isLoading = true;
    notifyListeners();

    try {
      bool alreadyLinked = user.providerData.any((p) => p.providerId == 'microsoft.com');
      if (!alreadyLinked) {
        if (kIsWeb) {
          await _firebaseService.linkWithMicrosoftPopup();
        } else {
          await _firebaseService.linkWithMicrosoftPopup();
        }
      }

      await _firebaseService.db.collection('users').doc(user.uid).update({
        'rollNo': rollNo.toUpperCase(),
        'isMicrosoftLinked': true,
        'isMicrosoftLinkRequired': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await fetchUserProfile(user.uid);
    } catch (e) {
      debugPrint('[Auth] Account linking failed: \$e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
