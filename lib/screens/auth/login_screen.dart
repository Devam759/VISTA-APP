import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
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
      if (!identifier.contains('@') && !RegExp(r'^[0-9+\s-]+$').hasMatch(identifier)) {
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
                                      labelText: 'Email or Mobile Number',
                                      prefixIcon: const Icon(Icons.person_outline),
                                      suffix: _emailController.text.contains('@') ||
                                              RegExp(r'^[0-9+\s-]+$')
                                                  .hasMatch(_emailController.text)
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
                        const SizedBox(height: 40),
                        const SizedBox(height: 40),
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
}
