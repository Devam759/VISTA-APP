import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import '../../providers/auth_provider.dart';

import '../../utils/sanitizer.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _errorMessage;

  void _login() async {
    setState(() => _errorMessage = null);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      String identifier = InputSanitizer.sanitize(_emailController.text.trim());
      if (identifier.isEmpty) {
        setState(() => _errorMessage = 'Please enter your ID');
        return;
      }

      // Handle cases where user might have typed the full email
      String finalIdentifier = identifier;
      if (!identifier.contains('@')) {
        finalIdentifier = '$identifier@jklu.edu.in';
      }

      await authProvider.signIn(finalIdentifier, _passwordController.text.trim());
      // Trigger the password-save prompt on Android / iOS / Web
      TextInput.finishAutofillContext();
    } catch (e) {
      if (mounted) {
        String message = 'Login failed. Please check your credentials.';
        if (e.toString().contains('invalid-credential') ||
            e.toString().contains('wrong-password') ||
            e.toString().contains('user-not-found')) {
          message = 'Incorrect ID or password entered.';
        } else if (e.toString().contains('network-request-failed')) {
          message = 'Network error. Please check your connection.';
        }

        setState(() => _errorMessage = message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    debugPrint("VISTA: LoginScreen build (v2). Loading: ${authProvider.isLoading}");

    // Reactive Linking Dialog Trigger
    if (authProvider.pendingEmail != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        debugPrint("VISTA: Reactive Trigger - Calling _showAccountLinkingDialog...");
        _showAccountLinkingDialog(context);
      });
    }
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
                      children: [
                        const SizedBox(height: 40),
                        Center(
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
                        const SizedBox(height: 50),
                        OutlinedButton(
                          onPressed: authProvider.isLoading
                              ? null
                              : () async {
                                  debugPrint("VISTA: Microsoft Login button CLICKED");
                                  try {
                                    await authProvider.signInWithMicrosoft();
                                    debugPrint("VISTA: signInWithMicrosoft completion - Pending: ${authProvider.pendingEmail != null}");
                                  } on FirebaseAuthException catch (e) {
                                    if (mounted) {
                                      setState(() => _errorMessage =
                                          'Microsoft Login failed: ${e.message}');
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      setState(() => _errorMessage =
                                          'An unexpected error occurred: ${e.toString()}');
                                    }
                                  }
                                },
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            side: BorderSide.none,
                            padding: const EdgeInsets.symmetric(
                              vertical: 16,
                              horizontal: 20,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            elevation: 2,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              // Custom Microsoft 4-color square logo
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Expanded(child: Container(color: const Color(0xFFF25022))),
                                          const SizedBox(width: 1.5),
                                          Expanded(child: Container(color: const Color(0xFF7FBA00))),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 1.5),
                                    Expanded(
                                      child: Row(
                                        children: [
                                          Expanded(child: Container(color: const Color(0xFF00A4EF))),
                                          const SizedBox(width: 1.5),
                                          Expanded(child: Container(color: const Color(0xFFFFB900))),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 16),
                              const Text(
                                'Sign in with Microsoft',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 30),
                        const Row(
                          children: [
                            Expanded(child: Divider()),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16),
                              child: Text('OR', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                            ),
                            Expanded(child: Divider()),
                          ],
                        ),
                        const SizedBox(height: 30),
                        AutofillGroup(
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
                                    autofillHints: const [
                                      AutofillHints.password,
                                    ],
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      prefixIcon: const Icon(
                                        Icons.lock_outline,
                                      ),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                        ),
                                        onPressed: () => setState(
                                          () => _obscurePassword =
                                              !_obscurePassword,
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
                        if (_errorMessage != null)
                          Padding(
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
                        const SizedBox(height: 40),
                        ElevatedButton(
                          onPressed: authProvider.isLoading ? null : _login,
                          child: authProvider.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Login'),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text("Don't have an account?"),
                            TextButton(
                              onPressed: () =>
                                  Navigator.pushNamed(context, '/signup'),
                              child: const Text('Sign Up'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
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
              TextButton(
                onPressed: authProvider.isLoading ? null : () {
                  authProvider.clearPendingCredential();
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
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
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Link & Log In'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
