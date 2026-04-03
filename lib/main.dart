import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/auth_provider.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/signup_screen.dart';
import 'screens/student/student_dashboard.dart';
import 'screens/warden/warden_dashboard.dart';
import 'screens/head_warden/head_warden_dashboard.dart';
import 'screens/chief_warden/chief_warden_dashboard.dart';
import 'screens/auth/pending_approval_screen.dart';
import 'screens/auth/mandatory_link_screen.dart';
import 'utils/theme.dart';
import 'models/vista_user.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode, debugPrint;
import 'services/security_service.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/services.dart';

const platform = MethodChannel('com.ashish.vista.jklu/debug_token');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // .env is optional — it may not exist on web (gitignored).
  // Firebase options fall back to the hardcoded values in firebase_options.dart.
  try {
    await dotenv.load(fileName: ".env");
  } catch (_) {
    debugPrint('.env not found — continuing without it.');
  }
  // Note: Firebase.initializeApp() requires configuration files (google-services.json / GoogleService-Info.plist)
  // which are usually added manually. I will assume they are present or will be added.
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // ─────────────────────────────────────────────────────────────────────────
    // APP CHECK INITIALIZATION
    // Play Integrity is required for Production to prevent unauthorized access.
    // ─────────────────────────────────────────────────────────────────────────
    if (!kIsWeb) {
      await FirebaseAppCheck.instance.activate(
        providerAndroid: kDebugMode ? const AndroidDebugProvider() : const AndroidPlayIntegrityProvider(),
        providerApple: const AppleDebugProvider(),
      );
      // In debug mode, force-fetch the App Check token so it prints in Flutter console
      if (kDebugMode) {
        try {
          final token = await FirebaseAppCheck.instance.getToken(true);
          debugPrint("\n\n=======================================================");
          debugPrint("YOUR FIREBASE APP CHECK DEBUG TOKEN IS:");
          debugPrint(token ?? "Failed to get token");
          debugPrint("=======================================================\n\n");
        } catch (e) {
          debugPrint("Could not fetch App Check debug token: $e");
        }
      }
    }


  } catch (e) {
    // ignore: prefer_interpolation_to_compose_strings
    debugPrint("Firebase initialization failed: " + e.toString());
    // On web, if Firebase fails once, subsequent calls usually fail. 
    // We try to catch it early.
  }

  bool isSecure = true;

  // Only attempt to retrieve debug token in debug builds
  if (kDebugMode) {
    try {
      if (!kIsWeb) {
        final String debugToken = await platform.invokeMethod('getDebugToken');
        debugPrint("\n\n=======================================================");
        debugPrint("YOUR FIREBASE APP CHECK DEBUG TOKEN IS:");
        debugPrint(debugToken);
        debugPrint("=======================================================\n\n");
      }
    } on PlatformException catch (e) {
      debugPrint("Failed to get debug token: '${e.message}'.");
    } catch (e) {
      debugPrint("Debug token not available: $e");
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SECURITY CHECK: BLOCK EMULATORS, ROOT, VPN, & MOCK LOCATION
  // Only runs on mobile platforms (via SecurityService platform abstraction).
  // ─────────────────────────────────────────────────────────────────────────
  if (!kIsWeb) {
    isSecure = await SecurityService.checkSecurity();
  }

  runApp(VistaApp(isSecure: isSecure));
}

class VistaApp extends StatelessWidget {
  final bool isSecure;
  const VistaApp({super.key, required this.isSecure});

  @override
  Widget build(BuildContext context) {
    if (!isSecure) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: _BlockedScreen(),
      );
    }
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (_) => AuthProvider())],
      child: MaterialApp(
        title: 'VISTA',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const AuthWrapper(),
        routes: {
          '/login': (context) => const LoginScreen(),
          '/signup': (context) => const SignupScreen(),
          '/pending': (context) => const PendingApprovalScreen(),
          '/mandatory-link': (context) => const MandatoryLinkScreen(),
          '/student': (context) => const StudentDashboard(),
          '/warden': (context) => const WardenDashboard(),
          '/head-warden': (context) => const HeadWardenDashboard(),
          '/chief-warden': (context) => const ChiefWardenDashboard(),
        },
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    debugPrint("VISTA: AuthWrapper Building. isLoading: ${authProvider.isLoading}, firebaseUser: ${authProvider.firebaseUser?.email}, userProfile: ${authProvider.userProfile != null ? 'EXISTS' : 'NULL'}");

    if (authProvider.isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // NEW Profile Load Error Handling
    if (authProvider.hasProfileLoadError && authProvider.firebaseUser != null) {
       debugPrint("VISTA: AuthWrapper -> ProfileSyncErrorScreen");
       return const ProfileSyncErrorScreen();
    }

    if (authProvider.userProfile == null) {
      if (authProvider.firebaseUser != null) {
        // Authenticated via SSO but no profile yet
        debugPrint("VISTA: AuthWrapper -> SignupScreen (SSO User without profile)");
        return const SignupScreen();
      }
      debugPrint("VISTA: AuthWrapper -> LoginScreen (No user)");
      return const LoginScreen();
    }

    final user = authProvider.userProfile!;
    debugPrint("VISTA: AuthWrapper -> Role-based Routing (Role: ${user.role})");


    // Role-based routing
    switch (user.role) {
      case UserRole.student:
        // A student is blocked if:
        // 1. Account is explicitly deactivated (isAccountActive == false)
        // 3. It's a hosteller (!isDayScholar) and not yet approved (!isApproved)
        final bool hostellerNeedsApproval = !user.isDayScholar && !user.isApproved;
        if (!user.isAccountActive || hostellerNeedsApproval) {
          return const PendingApprovalScreen();
        }
        if (user.isMicrosoftLinkRequired) {
          return const MandatoryLinkScreen();
        }
        return const StudentDashboard();
      case UserRole.warden:
        return const WardenDashboard();
      case UserRole.headWarden:
        return const HeadWardenDashboard();
      case UserRole.chiefWarden:
        return const ChiefWardenDashboard();
    }
  }
}

class ProfileSyncErrorScreen extends StatelessWidget {
  const ProfileSyncErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.sync_problem_rounded,
                  size: 80,
                  color: Color(0xFF3B82F6),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Profile Sync Issue',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF1E3A8A),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  "We've authenticated your account, but couldn't sync your student profile from our secure server. This usually happens if your phone is not yet recognized by our security system (App Check).",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54, height: 1.5),
                ),
                const SizedBox(height: 32),
                
                if (kDebugMode) ...[
                   Container(
                     padding: const EdgeInsets.all(16),
                     decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                        boxShadow: [
                           BoxShadow(
                             color: Colors.black.withValues(alpha: 0.05),
                             blurRadius: 10,
                             offset: const Offset(0, 4),
                           ),
                        ],
                     ),
                     child: Column(
                       children: [
                         const Text(
                           "DEVELOPER NOTICE",
                           style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blue),
                         ),
                         const SizedBox(height: 8),
                         const Text(
                           "If you see 'permission-denied' in logs, make sure to add your App Check Debug Token to the Firebase Console.",
                           style: TextStyle(fontSize: 12, color: Colors.black87),
                           textAlign: TextAlign.center,
                         ),
                         const SizedBox(height: 12),
                         FutureBuilder<String?>(
                           future: FirebaseAppCheck.instance.getToken(false),
                           builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                 return const SizedBox(height: 14, width: 14, child: CircularProgressIndicator(strokeWidth: 2));
                              }
                              return SelectableText(
                                "Attestation: ${snapshot.data?.substring(0, 10)}...",
                                style: const TextStyle(fontFamily: 'monospace', fontSize: 10, color: Colors.grey),
                              );
                           },
                         ),
                       ],
                     ),
                   ),
                   const SizedBox(height: 32),
                ],

                ElevatedButton.icon(
                  onPressed: () => authProvider.fetchUserProfile(authProvider.firebaseUser!.uid),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Retry Sync'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E3A8A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => authProvider.signOut(),
                  child: const Text('Sign Out & Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BlockedScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4FF),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.no_sim_rounded,
                size: 80,
                color: Color(0xFFEF4444),
              ),
              const SizedBox(height: 24),
              const Text(
                'Security Violation',
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'VISTA is not allowed to run on Emulators, Rooted devices, with Mock Locations enabled, or if USB Debugging/Developer Options are active for security and attendance integrity.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, height: 1.5),
              ),
              const SizedBox(height: 32),
              const Text(
                'Please disable Mock Locations/Developer Options and use a physical Android phone.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E3A8A),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
