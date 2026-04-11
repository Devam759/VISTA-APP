import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../providers/auth_provider.dart';
import '../../utils/sanitizer.dart';
import '../../utils/rate_limiter.dart';
import '../../widgets/hover_effect.dart';
import '../../widgets/vista_loader.dart';
import '../../widgets/smooth_animations.dart';
import 'package:url_launcher/url_launcher.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController    = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword     = true;
  String? _errorMessage;

  // Lockout countdown
  int _lockoutSeconds = 0;
  Timer? _lockoutTimer;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _lockoutTimer?.cancel();
    super.dispose();
  }

  /// Start or refresh the lockout countdown widget.
  void _startLockoutCountdown(int seconds) {
    _lockoutTimer?.cancel();
    setState(() => _lockoutSeconds = seconds);
    if (seconds <= 0) return;
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      setState(() {
        _lockoutSeconds = (_lockoutSeconds - 1).clamp(0, 99999);
        if (_lockoutSeconds == 0) t.cancel();
      });
    });
  }

  String _formatLockout(int secs) {
    final h = secs ~/ 3600;
    final m = (secs % 3600) ~/ 60;
    final s = secs % 60;
    if (h > 0) return '${h}h ${m}m ${s}s';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  void _login() async {
    setState(() => _errorMessage = null);

    final identifier = InputSanitizer.sanitize(_emailController.text.trim());
    if (identifier.isEmpty) {
      setState(() => _errorMessage = 'Please enter your ID');
      return;
    }

    // ── Pre-check lockout BEFORE calling Firebase (no unnecessary round-trip) ──
    // Capture context-dependent objects BEFORE the first await.
    // Using a BuildContext across an async gap triggers
    // use_build_context_synchronously lint.
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    final remaining = await LoginThrottle.lockoutRemainingSeconds(identifier);
    if (remaining > 0) {
      _startLockoutCountdown(remaining);
      if (mounted) setState(() => _errorMessage = null);
      return;
    }

    try {
      String finalIdentifier = identifier;
      if (!identifier.contains('@')) {
        finalIdentifier = '$identifier@jklu.edu.in';
      }

      await authProvider.signIn(finalIdentifier, _passwordController.text.trim());
      TextInput.finishAutofillContext();
    } catch (e) {
      if (!mounted) return;

      // Check if the exception is a lockout from LoginThrottle.
      final newRemaining =
          await LoginThrottle.lockoutRemainingSeconds(identifier);
      if (newRemaining > 0) {
        _startLockoutCountdown(newRemaining);
        return;
      }

      String message = 'Login failed. Please check your credentials.';
      final errorStr = e.toString();
      if (errorStr.contains('invalid-credential') ||
          errorStr.contains('wrong-password') ||
          errorStr.contains('user-not-found')) {
        message = 'Incorrect ID or password entered.';
      } else if (errorStr.contains('network-request-failed')) {
        message = 'Network error. Please check your connection.';
      } else if (errorStr.contains('too-many-requests')) {
        message = 'Too many attempts. Please try again later.';
      }

      setState(() => _errorMessage = message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isLocked     = _lockoutSeconds > 0;

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight,
                    maxWidth: 400,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      const SizedBox(height: 40),
                      SmoothEntrance(
                        delay: const Duration(milliseconds: 200),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Image.asset(
                                'assets/images/jklu_logo.jpg',
                                height: 60,
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'VISTA',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: const Color(0xFF1E3A8A),
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 50),
                      SmoothEntrance(
                        delay: const Duration(milliseconds: 400),
                        child: AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              TextField(
                                controller: _emailController,
                                autofillHints: const [
                                  AutofillHints.email,
                                  AutofillHints.username,
                                ],
                                decoration: InputDecoration(
                                  labelText: 'Email',
                                  prefixIcon: const Icon(Icons.person_outline),
                                  suffix: _emailController.text.contains('@')
                                      ? null
                                      : const Text(
                                          '@jklu.edu.in',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                ),
                                onChanged: (val) => setState(() {}),
                                keyboardType: TextInputType.emailAddress,
                              ),
                              const SizedBox(height: 20),
                              TextField(
                                controller: _passwordController,
                                autofillHints: const [AutofillHints.password],
                                decoration: InputDecoration(
                                  labelText: 'Password',
                                  prefixIcon: const Icon(Icons.lock_outline),
                                  suffixIcon: HoverEffect(
                                    child: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                      ),
                                      onPressed: () => setState(
                                        () => _obscurePassword = !_obscurePassword,
                                      ),
                                    ),
                                  ),
                                ),
                                obscureText: _obscurePassword,
                                onEditingComplete: () =>
                                    TextInput.finishAutofillContext(
                                      shouldSave: false,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // ── Lockout Banner ──────────────────────────────────
                      SmoothSwitcher(
                        child: !isLocked ? const SizedBox.shrink() : Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFF3CD),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: const Color(0xFFFFCA2C)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.lock_clock,
                                    color: Color(0xFF856404), size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Account locked due to too many failed attempts.\n'
                                    'Try again in ${_formatLockout(_lockoutSeconds)}.',
                                    style: const TextStyle(
                                      color: Color(0xFF856404),
                                      fontSize: 13,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // ── Error Message ───────────────────────────────────
                      SmoothSwitcher(
                        child: (_errorMessage == null || isLocked) ? const SizedBox.shrink() : Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  color: Colors.red,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 40),
                      SmoothEntrance(
                        delay: const Duration(milliseconds: 600),
                        child: Column(
                          children: [
                            HoverEffect(
                              child: ElevatedButton(
                                onPressed:
                                    (authProvider.isLoading || isLocked) ? null : _login,
                                child: authProvider.isLoading
                                    ? const VISTALoader(size: 24, color: Colors.white)
                                    : const Text('Login'),
                              ),
                            ),
                            const SizedBox(height: 20),
                            const Row(
                              children: [
                                Expanded(child: Divider()),
                                Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 16),
                                  child: Text('or', style: TextStyle(color: Colors.grey)),
                                ),
                                Expanded(child: Divider()),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      SmoothEntrance(
                        delay: const Duration(milliseconds: 800),
                        child: HoverEffect(
                          child: ElevatedButton(
                            onPressed: authProvider.isLoading ? null : () async {
                              try {
                                await authProvider.signInWithMicrosoft();
                                if (!mounted) return;
                                if (authProvider.pendingMicrosoftCredential != null) {
                                  // ignore: use_build_context_synchronously
                                  _showAccountLinkingDialog(context);
                                }
                              } catch (e) {
                                if (!mounted) return;
                                String errorMessage = 'Microsoft sign-in failed. Please try again.';
                                if (e is FirebaseAuthException && e.message != null) {
                                  errorMessage = e.message!;
                                } else if (e is Exception) {
                                  errorMessage = e.toString();
                                }
                                setState(() {
                                  _errorMessage = errorMessage;
                                });
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 50),
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                SizedBox(
                                  width: 24,
                                  height: 24,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
                                            color: const Color(0xFFF25022),
                                          ),
                                          const SizedBox(width: 2),
                                          Container(
                                            width: 10,
                                            height: 10,
                                            color: const Color(0xFF7FBA00), // Swapped from Blue to Green
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Container(
                                            width: 10,
                                            height: 10,
                                            color: const Color(0xFF00A4EF), // Swapped from Green to Blue
                                          ),
                                          const SizedBox(width: 2),
                                          Container(
                                            width: 10,
                                            height: 10,
                                            color: const Color(0xFFFFB900),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                const Flexible(
                                  child: Text(
                                    'Sign in with Microsoft',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text("Don't have an account?"),
                          HoverEffect(
                            child: TextButton(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/signup'),
                              child: const Text('Sign Up'),
                            ),
                          ),
                        ],
                      ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: HoverEffect(
                          child: TextButton.icon(
                            onPressed: _showDeveloperInfo,
                            icon: const Icon(Icons.code, size: 14),
                            label: const Text(
                              'Developer Info',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                            ),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.grey[400],
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _showAccountLinkingDialog(BuildContext context) {
    debugPrint("VISTA: Inside _showAccountLinkingDialog");
    final passwordController = TextEditingController();
    String? localError;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Consumer<AuthProvider>(
        builder: (context, authProvider, _) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Account Link Found'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'We found an existing account for your university email. To securely link it to your Microsoft login, please verify your identity by entering your old password once.',
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Old Password',
                    errorText: localError,
                    prefixIcon: const Icon(Icons.lock_outline),
                  ),
                ),
              ],
            ),
            actions: [
              HoverEffect(
                child: TextButton(
                  onPressed: authProvider.isLoading ? null : () {
                    authProvider.clearPendingCredential();
                    Navigator.pop(context);
                  },
                  child: const Text('Cancel'),
                ),
              ),
              HoverEffect(
                child: ElevatedButton(
                  onPressed: authProvider.isLoading ? null : () async {
                    try {
                      setDialogState(() => localError = null);
                      await authProvider.linkAccountWithPassword(passwordController.text);
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      debugPrint("VISTA: Linking error in dialog: $e");
                      setDialogState(() {
                        if (e is FirebaseAuthException) {
                          localError = e.message;
                        } else {
                          localError = 'Linking failed: ${e.toString()}';
                        }
                      });
                    }
                  },
                  child: authProvider.isLoading
                      ? const VISTALoader(size: 24, color: Colors.white)
                      : const Text('Link & Log In'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeveloperInfo() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(32),
            topRight: Radius.circular(32),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              spreadRadius: 5,
            )
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'The Minds Behind VISTA',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF1E3A8A),
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Designed & Developed with Passion',
              style: TextStyle(color: Colors.grey[600], fontSize: 13),
            ),
            const SizedBox(height: 30),
            _developerCard(
              name: 'Devam Gupta',
              github: 'https://github.com/Devam759',
              image: 'https://github.com/Devam759.png',
              role: 'Project Lead & Lead Developer',
            ),
            const SizedBox(height: 16),
            _developerCard(
              name: 'Yash Mishra',
              github: 'https://github.com/yashmish18',
              image: 'https://github.com/yashmish18.png',
              role: 'Full Stack Developer',
            ),
            const SizedBox(height: 30),
            Text(
              '© ${DateTime.now().year} VISTA Team',
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _developerCard({
    required String name,
    required String github,
    required String image,
    required String role,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey[100]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF1E3A8A).withValues(alpha: 0.2)),
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: Colors.grey[200],
              backgroundImage: NetworkImage(image),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  role,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          HoverEffect(
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E3A8A).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.open_in_new,
                  size: 18,
                  color: Color(0xFF1E3A8A),
                ),
              ),
              onPressed: () async {
                final url = Uri.parse(github);
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
