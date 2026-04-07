import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/vista_user.dart';
import '../services/firebase_service.dart';
import '../services/notification_service.dart';

class AuthProvider with ChangeNotifier {
  final FirebaseService _firebaseService = FirebaseService();
  VistaUser? _userProfile;
  bool _isLoading = false;
  bool _hasProfileLoadError = false;
  
  // Account Linking State
  AuthCredential? _pendingMicrosoftCredential;
  String? _pendingEmail;

  bool _suppressAuthChanges = false;
  bool _isInitialized = false;
  String? _isFetchingProfileForUid;

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
      final profile = await _firebaseService.getUserProfile(uid);
      if (profile != null) {
        _userProfile = profile;
        _hasProfileLoadError = false;
        debugPrint("VISTA: Profile fetch result: SUCCESS");
      } else if (retryOnNull && retries > 0) {
        debugPrint("VISTA: Profile returned null, retrying in 1s...");
        await Future.delayed(const Duration(seconds: 1));
        return fetchUserProfile(uid, retries: retries - 1, retryOnNull: retryOnNull);
      } else {
        // Only clear the profile if we don't already have one for this UID
        if (_userProfile?.uid != uid) {
          _userProfile = null;
          debugPrint("VISTA: Profile fetch result: NULL (Directing to Signup/Link)");
        } else {
          debugPrint("VISTA: Profile fetch result: NULL (Preserving existing local profile for $uid)");
        }
      }
    } catch (e) {
      debugPrint("VISTA: Profile fetch error: $e");
      if (retries > 0) {
        debugPrint("VISTA: Error caught, retrying in 2s...");
        await Future.delayed(const Duration(seconds: 2));
        return fetchUserProfile(uid, retries: retries - 1, retryOnNull: retryOnNull);
      }
      // Only clear on error if the UID is different
      if (_userProfile?.uid != uid) {
        _userProfile = null;
        _hasProfileLoadError = true;
      } else {
        debugPrint("VISTA: Preserving existing local profile for $uid despite fetch error.");
      }
    } finally {
      if (_isFetchingProfileForUid == uid) {
        _isFetchingProfileForUid = null;
      }
      _isInitialized = true;
      _isLoading = false;
      notifyListeners();

      
      if (_userProfile != null) {
        try {
          await NotificationService().init(uid);
        } catch (e) {
          debugPrint('Error initializing notifications: $e');
        }
      }
    }
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
    // Always suppress auth changes during signup to prevent race conditions
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
      _suppressAuthChanges = false; // Re-enable auth listener
      notifyListeners();
    }
    // REDUNDANT Sync removed - we already have the newUser data and it's set locally.
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

      await _firebaseService
          .createUserProfile(newUser);

      // Always set the profile locally so AuthWrapper can see the change
      // before a potential signOut() or redirection.
      _userProfile = newUser;
    } catch (e) {
      rethrow;
    } finally {
      _isLoading = false;
      _suppressAuthChanges = false;
      notifyListeners();
    }
    // REDUNDANT Sync removed - newUser is already the target state.
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

  Future<void> signIn(String identifier, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final credential = await _firebaseService.signIn(identifier, password);
      await fetchUserProfile(credential.user!.uid);
    } catch (e) {
      _isLoading = false;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> signInWithMicrosoft() async {
    _isLoading = true;
    notifyListeners();
    clearPendingCredential();
    try {
      final credential = await _firebaseService.signInWithMicrosoft();
      if (credential.user != null) {
        // Skip retries for Microsoft SSO to ensure instant redirect for new users
        await fetchUserProfile(credential.user!.uid, retryOnNull: false);
      } else {
        // This case is unlikely given Firebase's behavior but handled for safety
        debugPrint("VISTA: signInWithMicrosoft returned no user.");
        _isLoading = false;
        notifyListeners();
      }
    } on FirebaseAuthException catch (e) {


      if (e.code == 'account-exists-with-different-credential') {
        _pendingMicrosoftCredential = e.credential;
        _pendingEmail = e.email;
        debugPrint('VISTA: Account exists with different credential. Linking required. Email: ${_pendingEmail}, Credential: ${_pendingMicrosoftCredential != null ? "FOUND" : "NULL"}');
        _isLoading = false;
        notifyListeners();
        return; // Don't rethrow, handled via state
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
    _suppressAuthChanges = true; // Essential: stop AuthWrapper from redirecting mid-link
    notifyListeners();

    try {
      // 1. Sign in with the original password to prove ownership
      debugPrint('VISTA: Signing in with email/pass to prove ownership...');
      final credential = await _firebaseService.signIn(_pendingEmail!, password);
      
      try {
        // 2. Link the Microsoft credential to this signed-in user
        if (kIsWeb) {
          debugPrint('VISTA: Web - Triggering linkWithPopup...');
          await _firebaseService.linkWithMicrosoftPopup();
        } else if (_pendingMicrosoftCredential != null) {
          await _firebaseService.linkWithMicrosoftCredential(_pendingMicrosoftCredential!);
        }
        
        debugPrint('VISTA: Linking SUCCESS. Finalizing login...');
        // 3. Success! Now allow auth changes and refresh profile
        _suppressAuthChanges = false;
        final uid = credential.user!.uid;
        clearPendingCredential();
        await fetchUserProfile(uid);
      } catch (linkingError) {
        debugPrint('VISTA: Linking step failed: $linkingError. Signing out.');
        _suppressAuthChanges = false;
        await _firebaseService.signOut();
        rethrow;
      }
    } catch (e) {
      debugPrint('VISTA: Error in linkAccountWithPassword: $e');
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

      // Refresh Firebase User to get the new email/provider info
      final updatedUser = _firebaseService.currentUser;
      final linkedEmail = updatedUser?.email;

      if (rollNo != null && linkedEmail != null) {
        // use the specialized method that also updates roll number
        await _firebaseService.linkInstitutionalAccount(
          uid: user.uid,
          rollNo: rollNo,
          institutionalEmail: linkedEmail,
        );
      } else {
        // Just update the linked status
        await _firebaseService.setMicrosoftLinkedStatus(user.uid, true);
      }

      // Refresh local profile
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
      // 1. Link if not already linked
      bool alreadyLinked = user.providerData.any((p) => p.providerId == 'microsoft.com');
      if (!alreadyLinked) {
        if (kIsWeb) {
          await _firebaseService.linkWithMicrosoftPopup();
        } else {
          await _firebaseService.linkWithMicrosoftPopup(); // Mobile uses linkWithProvider inside this
        }
      }

      // 2. Update Firestore profile
      await _firebaseService.db.collection('users').doc(user.uid).update({
        'rollNo': rollNo.toUpperCase(),
        'isMicrosoftLinked': true,
        'isMicrosoftLinkRequired': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // 3. Refresh user profile
      await fetchUserProfile(user.uid);
    } catch (e) {
      debugPrint('[Auth] Account linking failed: $e');
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }


  Future<void> updateUserProfile(Map<String, dynamic> data) async {
    final uid = firebaseUser?.uid;
    if (uid == null) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _firebaseService.updateStudentProfile(uid, data);
      // Refresh local profile
      await fetchUserProfile(uid);
    } catch (e) {
      debugPrint("VISTA: Error updating user profile: $e");
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> signOut() async {
    final uid = _firebaseService.currentUser?.uid;
    if (uid != null) {
      try {
        await _firebaseService.clearFcmToken(uid);
        await NotificationService().deleteToken();
      } catch (e) {
        debugPrint('Error clearing FCM token on logout: $e');
      }
    }
    await _firebaseService.signOut();
  }
}
