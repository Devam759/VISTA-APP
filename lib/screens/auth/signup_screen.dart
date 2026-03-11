import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../providers/auth_provider.dart';
import '../../utils/sanitizer.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  String _userType = 'Permanent';
  String? _selectedHostel;
  String? _selectedProgramme;
  String? _selectedGender;
  final _rollNoController = TextEditingController();
  bool _isSubmitting = false;

  final List<String> _permanentHostels = ['BH1', 'BH2', 'GH1', 'GH2'];
  final List<String> _programmes = ['BTECH', 'BBA', 'BDES', 'MDES', 'MBA'];

  void _signup() async {
    String nameInput = InputSanitizer.sanitize(_nameController.text.trim());
    String emailInput = InputSanitizer.sanitize(_emailController.text.trim());
    String phoneInput = InputSanitizer.sanitize(_phoneController.text.trim());

    if (emailInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your email username')),
      );
      return;
    }

    final email = emailInput.contains('@')
        ? emailInput
        : '$emailInput@jklu.edu.in';

    if (_selectedProgramme == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your programme')),
      );
      return;
    }

    if (_selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select your gender')),
      );
      return;
    }

    if (_rollNoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your roll number')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    try {
      debugPrint('[Signup] Attempting signup for $email...');
      await authProvider.signUp(
        nameInput,
        email,
        _passwordController.text.trim(),
        _userType == 'Short Stay' ? 'Short Stay' : _selectedHostel!,
        phoneInput,
        _rollNoController.text.trim().toUpperCase(),
        _selectedProgramme!,
        _selectedGender!,
      );
      // Trigger the password-save prompt on Android / iOS / Web
      TextInput.finishAutofillContext();
      debugPrint('[Signup] Signup succeeded, showing dialog. mounted=$mounted');
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showSuccessDialog();
      }
    } catch (e, s) {
      debugPrint('[Signup] Error: $e');
      debugPrint('[Signup] Stack: $s');
      if (mounted) {
        setState(() => _isSubmitting = false);
        _showErrorDialog(e.toString());
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: SizedBox(
          width: 380,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top gradient header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 32),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1E3A8A), Color(0xFF3B82F6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child: const Column(
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundColor: Colors.white24,
                        child: Icon(
                          Icons.check_rounded,
                          size: 44,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Registration Successful!',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ),
                // Body
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                  child: Column(
                    children: [
                      const Text(
                        'Your account has been submitted for warden approval. Once approved, you\'ll be able to access all VISTA features.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.login_rounded, size: 20),
                          label: const Text(
                            'Go to Login',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E3A8A),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                          onPressed: () {
                            Navigator.of(context).pop();
                            Navigator.of(context).pop();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 32,
                backgroundColor: Color(0xFFFFEBEE),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 36,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Registration Failed',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54, fontSize: 13),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.asset('assets/images/jklu_logo.jpg', height: 60),
                      const SizedBox(width: 16),
                      Text(
                        'VISTA',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF1E3A8A),
                            ),
                      ),
                    ],
                  ).animate().fadeIn(duration: 800.ms).slideY(begin: -0.2),
                  const SizedBox(height: 40),
                  AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // User Type Selection
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Row(
                              children: [
                                Expanded(
                                  child: _buildTypeButton(
                                    'Permanent',
                                    Icons.apartment_rounded,
                                    _userType == 'Permanent',
                                  ),
                                ),
                                Expanded(
                                  child: _buildTypeButton(
                                    'Short Stay',
                                    Icons.home_outlined,
                                    _userType == 'Short Stay',
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ).animate().fadeIn(delay: 50.ms).slideY(begin: -0.2),

                        TextField(
                          controller: _nameController,
                          autofillHints: const [AutofillHints.name],
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ).animate().fadeIn(delay: 100.ms).slideX(begin: -0.1),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _emailController,
                          autofillHints: const [
                            AutofillHints.email,
                            AutofillHints.newUsername,
                          ],
                          decoration: const InputDecoration(
                            labelText: 'JKLU Email Username',
                            prefixIcon: Icon(Icons.email_outlined),
                            suffixText: '@jklu.edu.in',
                            hintText: 'example',
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ).animate().fadeIn(delay: 200.ms).slideX(begin: -0.1),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _phoneController,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          keyboardType: TextInputType.phone,
                        ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.1),
                        if (_userType == 'Permanent') ...[
                          const SizedBox(height: 20),
                          DropdownButtonFormField<String>(
                            value: _selectedHostel,
                            items: _permanentHostels
                                .map(
                                  (h) => DropdownMenuItem(value: h, child: Text(h)),
                                )
                                .toList(),
                            onChanged: (val) => setState(() => _selectedHostel = val),
                            decoration: const InputDecoration(
                              labelText: 'Select Hostel',
                              prefixIcon: Icon(Icons.hotel_outlined),
                            ),
                          ).animate().fadeIn(delay: 400.ms).slideX(begin: -0.1),
                        ],
                        const SizedBox(height: 20),
                        TextField(
                          controller: _passwordController,
                          autofillHints: const [AutofillHints.newPassword],
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            prefixIcon: Icon(Icons.lock_outline),
                          ),
                          obscureText: true,
                        ).animate().fadeIn(delay: 500.ms).slideX(begin: -0.1),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _rollNoController,
                          decoration: const InputDecoration(
                            labelText: 'Roll Number',
                            prefixIcon: Icon(Icons.numbers_outlined),
                            hintText: 'e.g. 2025BTECH195',
                          ),
                          textCapitalization: TextCapitalization.characters,
                        ).animate().fadeIn(delay: 550.ms).slideX(begin: -0.1),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          value: _selectedProgramme,
                          items: _programmes
                              .map(
                                (p) =>
                                    DropdownMenuItem(value: p, child: Text(p)),
                              )
                              .toList(),
                          onChanged: (val) =>
                              setState(() => _selectedProgramme = val),
                          decoration: const InputDecoration(
                            labelText: 'Select Programme',
                            prefixIcon: Icon(Icons.school_outlined),
                          ),
                        ).animate().fadeIn(delay: 600.ms).slideX(begin: -0.1),
                        const SizedBox(height: 20),
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'Gender',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('Male', style: TextStyle(fontSize: 14)),
                                value: 'Male',
                                groupValue: _selectedGender,
                                onChanged: (val) =>
                                    setState(() => _selectedGender = val),
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                              ),
                            ),
                            Expanded(
                              child: RadioListTile<String>(
                                title: const Text('Female', style: TextStyle(fontSize: 14)),
                                value: 'Female',
                                groupValue: _selectedGender,
                                onChanged: (val) =>
                                    setState(() => _selectedGender = val),
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                              ),
                            ),
                          ],
                        ).animate().fadeIn(delay: 650.ms).slideX(begin: -0.1),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _signup,
                    child: _isSubmitting
                        ? const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text('Submitting...'),
                            ],
                          )
                        : const Text('Submit Registration'),
                  ).animate().fadeIn(delay: 700.ms).slideY(begin: 0.2),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account?'),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Login'),
                      ),
                    ],
                  ).animate().fadeIn(delay: 700.ms),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
  Widget _buildTypeButton(String label, IconData icon, bool isSelected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _userType = label;
          if (_userType == 'Short Stay') {
            _selectedHostel = 'Short Stay';
          } else if (_selectedHostel == 'Short Stay') {
            _selectedHostel = null;
          }
        });
      },
      child: AnimatedContainer(
        duration: 300.ms,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? const Color(0xFF1E3A8A) : Colors.black45,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? const Color(0xFF1E3A8A) : Colors.black45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
