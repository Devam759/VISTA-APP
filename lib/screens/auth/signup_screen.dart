import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as vista;
import '../../utils/sanitizer.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({super.key});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _parentNameController = TextEditingController();
  final _parentContactController = TextEditingController();
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
    String firstNameInput = InputSanitizer.capitalize(_firstNameController.text.trim());
    String lastNameInput = InputSanitizer.capitalize(_lastNameController.text.trim());
    String emailInput = InputSanitizer.sanitize(_emailController.text.trim());
    String phoneInput = InputSanitizer.normalizePhone(_phoneController.text.trim());

    if (firstNameInput.isEmpty || lastNameInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your first and last name')),
      );
      return;
    }

    if (phoneInput.length != 10 && !phoneInput.startsWith('+')) {
       // Assuming 10 digits if no country code, or just enforce 10 for local
       if (phoneInput.length != 10) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Mobile number must be exactly 10 digits')),
          );
          return;
       }
    }

    if (emailInput.isEmpty && phoneInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter either an email or a phone number')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    _finalizeSignup();
  }

  void _finalizeSignup() async {
    String firstNameInput = InputSanitizer.capitalize(_firstNameController.text.trim());
    String lastNameInput = InputSanitizer.capitalize(_lastNameController.text.trim());
    String nameInput = "$firstNameInput $lastNameInput";
    String emailInput = InputSanitizer.sanitize(_emailController.text.trim());
    String phoneInput = InputSanitizer.normalizePhone(_phoneController.text.trim());
    
    String finalEmail;
    if (emailInput.isNotEmpty) {
      finalEmail = emailInput.contains('@') ? emailInput : '$emailInput@jklu.edu.in';
    } else {
      finalEmail = '$phoneInput@vista.local';
    }

    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _parentNameController.text.trim().isEmpty ||
        _parentContactController.text.trim().isEmpty ||
        _passwordController.text.trim().isEmpty ||
        _rollNoController.text.trim().isEmpty ||
        _selectedProgramme == null ||
        _selectedGender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('All fields are required')),
      );
      setState(() => _isSubmitting = false);
      return;
    }

    setState(() => _isSubmitting = true);
    final authProvider = Provider.of<vista.AuthProvider>(context, listen: false);
    
    try {
      debugPrint('[Signup] Attempting signup for $finalEmail...');
      await authProvider.signUp(
        nameInput,
        finalEmail,
        _passwordController.text.trim(),
        _userType == 'Short Stay' ? 'Short Stay' : _selectedHostel!,
        phoneInput,
        _rollNoController.text.trim().toUpperCase(),
        _selectedProgramme!,
        _selectedGender!,
        parentName: _parentNameController.text.trim(),
        parentContact: _parentContactController.text.trim(),
        isApproved: _userType == 'Short Stay',
        staySignedIn: _userType == 'Short Stay', // Auto-login for Short Stay
      );
      
      debugPrint('[Signup] Signup succeeded. Finalizing flow...');
      
      if (mounted) {
        setState(() => _isSubmitting = false);
        if (_userType == 'Short Stay') {
          // Short Stay students are auto-approved and stay signed in.
          // Navigation is handled by AuthWrapper.
        } else {
          // Permanent students need approval and should be signed out
          await authProvider.signOut();
          _showSuccessDialog();
        }
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
                  ),
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
                        ),

                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _firstNameController,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'First Name',
                                  prefixIcon: Icon(Icons.person_outline),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: TextField(
                                controller: _lastNameController,
                                textCapitalization: TextCapitalization.words,
                                decoration: const InputDecoration(
                                  labelText: 'Last Name',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _emailController,
                          autofillHints: const [
                            AutofillHints.email,
                            AutofillHints.newUsername,
                          ],
                          decoration: InputDecoration(
                            labelText: 'JKLU Email Username',
                            prefixIcon: const Icon(Icons.email_outlined),
                            suffix: (_emailController.text.isEmpty ||
                                    _emailController.text.contains('@') ||
                                    RegExp(r'^[0-9+\s-]+$')
                                        .hasMatch(_emailController.text))
                                ? null
                                : const Text('@jklu.edu.in',
                                    style: TextStyle(color: Colors.grey)),
                            hintText: 'example',
                          ),
                          onChanged: (val) => setState(() {}),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _phoneController,
                          autofillHints: const [AutofillHints.telephoneNumber],
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            prefixIcon: Icon(Icons.phone_outlined),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _parentNameController,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                            labelText: 'Parent/Guardian Name',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _parentContactController,
                          decoration: const InputDecoration(
                            labelText: 'Parent/Guardian Contact',
                            prefixIcon: Icon(Icons.contact_phone_outlined),
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        if (_userType == 'Permanent') ...[
                          const SizedBox(height: 20),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedHostel,
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
                          ),
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
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _rollNoController,
                          decoration: const InputDecoration(
                            labelText: 'Roll Number',
                            prefixIcon: Icon(Icons.numbers_outlined),
                            hintText: 'e.g. 2025BTECH195',
                          ),
                          textCapitalization: TextCapitalization.characters,
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedProgramme,
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
                        ),
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
                                // ignore: deprecated_member_use
                                groupValue: _selectedGender,
                                // ignore: deprecated_member_use
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
                                // ignore: deprecated_member_use
                                groupValue: _selectedGender,
                                // ignore: deprecated_member_use
                                onChanged: (val) =>
                                    setState(() => _selectedGender = val),
                                contentPadding: EdgeInsets.zero,
                                dense: true,
                              ),
                            ),
                          ],
                        ),
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
                  ),
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
                  ),
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
      child: Container(
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
