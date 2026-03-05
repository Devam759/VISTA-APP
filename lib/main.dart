import 'package:firebase_core/firebase_core.dart';
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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Note: Firebase.initializeApp() requires configuration files (google-services.json / GoogleService-Info.plist)
  // which are usually added manually. I will assume they are present or will be added.
  try {
    debugPrint(
      "Initializing Firebase with options: ${DefaultFirebaseOptions.currentPlatform}",
    );
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint("Firebase initialized successfully on Web!");
  } catch (e) {
    debugPrint("Firebase initialization failed: \$e");
  }
  runApp(const VistaApp());
}

class VistaApp extends StatelessWidget {
  const VistaApp({super.key});

  @override
  Widget build(BuildContext context) {
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
