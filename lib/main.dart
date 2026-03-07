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
import 'screens/auth/pending_approval_screen.dart';
import 'utils/theme.dart';
import 'models/vista_user.dart';
import 'package:safe_device/safe_device.dart';

import 'package:flutter_dotenv/flutter_dotenv.dart';

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
    debugPrint(
      "Initializing Firebase with options: ${DefaultFirebaseOptions.currentPlatform}",
    );
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    // ─────────────────────────────────────────────────────────────────────────
    // APP CHECK INITIALIZATION
    // Play Integrity is required for Production to prevent unauthorized access.
    // ─────────────────────────────────────────────────────────────────────────
    await FirebaseAppCheck.instance.activate(
      providerAndroid: const AndroidPlayIntegrityProvider(),
      providerApple: const AppleDeviceCheckProvider(),
    );

    debugPrint("Firebase initialized successfully!");
  } catch (e) {
    debugPrint("Firebase initialization failed: \$e");
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SECURITY CHECK: BLOCK EMULATORS, ROOT, VPN, & MOCK LOCATION
  // ─────────────────────────────────────────────────────────────────────────
  bool isRealDevice = await SafeDevice.isRealDevice;
  bool isJailBroken = await SafeDevice.isJailBroken;
  bool isProxy = await SafeDevice.isDevelopmentModeEnable;
  bool isMock = await SafeDevice.isMockLocation;

  bool isSecure = isRealDevice && !isJailBroken && !isProxy && !isMock;

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
          '/student': (context) => const StudentDashboard(),
          '/warden': (context) => const WardenDashboard(),
          '/head-warden': (context) => const HeadWardenDashboard(),
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

    if (authProvider.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (authProvider.userProfile == null) {
      return const LoginScreen();
    }

    final user = authProvider.userProfile!;

    if (user.role == UserRole.student && !user.isApproved) {
      return const PendingApprovalScreen();
    }

    switch (user.role) {
      case UserRole.student:
        return const StudentDashboard();
      case UserRole.warden:
        return const WardenDashboard();
      case UserRole.headWarden:
        return const HeadWardenDashboard();
    }
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
                'VISTA is not allowed to run on Emulators, Rooted devices, or with Mock Locations enabled for security and attendance integrity.',
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
