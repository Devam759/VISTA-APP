import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart' as vista;
import '../../utils/sanitizer.dart';
import '../../widgets/vista_loader.dart';
import '../../widgets/hover_effect.dart';

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
  String _userType = 'Hosteller';
  String _idType = 'Roll Number';
  String? _selectedHostel;
  String? _selectedProgramme;
  String? _selectedGender;
  final _idController = TextEditingController(); // Reusing for both Roll and Reg No
  bool _isSubmitting = false;

  bool get _isCompleteProfileMode {
    final authProvider = Provider.of<vista.AuthProvider>(context, listen: false);
    return authProvider.firebaseUser != null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _prefillFromMicrosoft();
    });
  }

  void _prefillFromMicrosoft() {
    final authProvider = Provider.of<vista.AuthProvider>(context, listen: false);
    final user = authProvider.firebaseUser;
    if (user != null) {
      String fullName = user.displayName ?? "";
      if (fullName.isNotEmpty) {
        // Sanitize and Capitalize using our utility
        fullName = InputSanitizer.capitalize(fullName);
        final names = fullName.trim().split(RegExp(r'\s+'));
        if (names.length > 1) {
          _firstNameController.text = names.first;
          _lastNameController.text = names.sublist(1).join(' ');
        } else {
          _firstNameController.text = names.first;
        }
      }
      if (user.email != null && user.email!.isNotEmpty) {
        // If email is already full JKLU email, strip it for the controller if possible or keep as is
        if (user.email!.endsWith('@jklu.edu.in')) {
          _emailController.text = user.email!.split('@').first;
        } else {
          _emailController.text = user.email!;
        }
      }
      setState(() {});
    }
  }

  final List<String> _permanentHostels = ['BH1', 'BH2', 'GH1', 'GH2'];
  final List<String> _programmes = ['BTECH', 'BBA', 'BDES', 'MDES', 'MBA'];

  void _signup() async {
    String firstNameInput = InputSanitizer.capitalize(
      _firstNameController.text.trim(),
    );
    String lastNameInput = InputSanitizer.capitalize(
      _lastNameController.text.trim(),
    );
    String emailInput = InputSanitizer.sanitize(_emailController.text.trim());
    String phoneInput = InputSanitizer.formatPhoneWithCountryCode(
      _phoneController.text.trim(),
    );

    if (firstNameInput.isEmpty || lastNameInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your first and last name')),
      );
      return;
    }

    // Validate phone number format (+91 XXXXXXXXXX)
    final phoneDigits = phoneInput.replaceAll(RegExp(r'\D'), '');
    if (phoneDigits.length != 12 || !phoneInput.startsWith('+91')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a valid 10-digit mobile number'),
        ),
      );
      return;
    }

    if (emailInput.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your Email'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    _finalizeSignup();
  }

  void _finalizeSignup() async {
    String firstNameInput = InputSanitizer.capitalize(
      _firstNameController.text.trim(),
    );
    String lastNameInput = InputSanitizer.capitalize(
      _lastNameController.text.trim(),
    );
    String nameInput = "$firstNameInput $lastNameInput";
    String emailInput = InputSanitizer.sanitize(_emailController.text.trim());
    String phoneInput = InputSanitizer.formatPhoneWithCountryCode(
      _phoneController.text.trim(),
    );

    final String finalEmail = emailInput.contains('@')
        ? emailInput
        : '$emailInput@jklu.edu.in';

    if (_firstNameController.text.trim().isEmpty ||
        _lastNameController.text.trim().isEmpty ||
        _emailController.text.trim().isEmpty ||
        _phoneController.text.trim().isEmpty ||
        _parentNameController.text.trim().isEmpty ||
        _parentContactController.text.trim().isEmpty ||
        (!_isCompleteProfileMode && _passwordController.text.trim().isEmpty) ||
        _idController.text.trim().isEmpty ||
        _selectedProgramme == null ||
        _selectedGender == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('All fields are required')));
      setState(() => _isSubmitting = false);
      return;
    }

    setState(() => _isSubmitting = true);
    final authProvider = Provider.of<vista.AuthProvider>(
      context,
      listen: false,
    );

    try {
      debugPrint(
        '[Signup] Attempting ${_isCompleteProfileMode ? "profile completion" : "signup"} for $finalEmail...',
      );
      final String? rollNo = _idType == 'Roll Number' ? _idController.text.trim().toUpperCase() : null;
      final String? registrationNo = _idType == 'Registration Number' ? _idController.text.trim().toUpperCase() : null;

      if (_isCompleteProfileMode) {
        await authProvider.completeProfile(
          name: nameInput,
          email: finalEmail,
          hostel: _userType == 'Day Scholar' ? 'Short Stay' : _selectedHostel!,
          phoneNumber: phoneInput,
          rollNo: rollNo ?? '',
          registrationNo: registrationNo,
          programme: _selectedProgramme!,
          gender: _selectedGender!,
          parentName: _parentNameController.text.trim(),
          parentContact: _parentContactController.text.trim(),
          isApproved: _userType == 'Day Scholar',
          staySignedIn: _userType == 'Day Scholar',
          isDayScholar: _userType == 'Day Scholar',
          isMicrosoftLinked: true,
        );
      } else {
        await authProvider.signUp(
          nameInput,
          finalEmail,
          _passwordController.text.trim(),
          _userType == 'Day Scholar' ? 'Short Stay' : _selectedHostel!,
          phoneInput,
          rollNo ?? '',
          _selectedProgramme!,
          _selectedGender!,
          registrationNo: registrationNo,
          parentName: _parentNameController.text.trim(),
          parentContact: _parentContactController.text.trim(),
          isApproved: _userType == 'Day Scholar',
          staySignedIn: _userType == 'Day Scholar',
          isDayScholar: _userType == 'Day Scholar',
          isMicrosoftLinked: false,
        );
      }

      debugPrint('[Signup] Signup succeeded. Finalizing flow...');

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
    final bool isDayScholar = _userType == 'Day Scholar';

    debugPrint('[Signup] Showing success dialog. isDayScholar: $isDayScholar');
    showDialog(
      context: context,
      useRootNavigator: true, 
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
                      Text(
                        isDayScholar
                            ? 'Welcome to VISTA! Your account is active and you can now access the portal directly.'
                            : 'Your account has been submitted for warden approval. Once approved, you\'ll be able to access all VISTA features.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.black54,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 28),
                      HoverEffect(
                        child: SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            icon: Icon(
                              isDayScholar ? Icons.dashboard_rounded : Icons.login_rounded,
                              size: 20,
                            ),
                            label: Text(
                              isDayScholar ? 'Go to Portal' : 'Go to Login',
                              style: const TextStyle(
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
                            onPressed: () async {
                              _performSuccessRedirect(isDayScholar);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Redirecting automatically...',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.black38,
                          fontStyle: FontStyle.italic,
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

    // Auto-redirect after 2 seconds
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted) {
        debugPrint('[Signup] Auto-redirect timer fired.');
        // Only redirect if the dialog is still the top-most route (not closed manually)
        Navigator.of(context, rootNavigator: true).pop(); // Close dialog first
        _performSuccessRedirect(isDayScholar);
      } else {
        debugPrint('[Signup] SignupScreen no longer mounted, skipping auto-redirect.');
      }
    });
  }

  void _performSuccessRedirect(bool isDayScholar) async {
    debugPrint('[Signup] Performing success redirect. isDayScholar: $isDayScholar');
    if (isDayScholar) {
      // For Day Scholars, go to the Student Dashboard
      if (mounted) {
        debugPrint('[Signup] Navigating to /student...');
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/student',
          (route) => false,
        );
      }
    } else {
      // For Hostellers, we need to sign out and go to Login
      final authProvider = Provider.of<vista.AuthProvider>(context, listen: false);
      
      debugPrint('[Signup] Hosteller registration. Signing out and going to login...');
      await authProvider.signOut();
      
      if (mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil(
          '/',
          (route) => false,
        );
      }
    }
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
                                  child: HoverEffect(
                                    child: _buildTypeButton(
                                      'Hosteller',
                                      Icons.apartment_rounded,
                                      _userType == 'Hosteller',
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: HoverEffect(
                                    child: _buildTypeButton(
                                      'Day Scholar',
                                      Icons.home_outlined,
                                      _userType == 'Day Scholar',
                                    ),
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
                            labelText: 'Email',
                            prefixIcon: const Icon(Icons.email_outlined),
                            suffix:
                                (_emailController.text.isEmpty ||
                                    _emailController.text.contains('@'))
                                ? null
                                : const Text(
                                    '@jklu.edu.in',
                                    style: TextStyle(color: Colors.grey),
                                  ),
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
                        if (_userType == 'Hosteller') ...[
                          const SizedBox(height: 20),
                          DropdownButtonFormField<String>(
                            initialValue: _selectedHostel,
                            items: _permanentHostels
                                .map(
                                  (h) => DropdownMenuItem(
                                    value: h,
                                    child: Text(h),
                                  ),
                                )
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedHostel = val),
                            decoration: const InputDecoration(
                              labelText: 'Select Hostel',
                              prefixIcon: Icon(Icons.hotel_outlined),
                            ),
                          ),
                        ],
                        if (!_isCompleteProfileMode) ...[
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
                        ],
                        // ID Type Toggle and Input
                        const SizedBox(height: 20),
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          padding: const EdgeInsets.all(4),
                          child: Row(
                            children: [
                              HoverEffect(child: _buildIDTypeButton('Roll Number', _idType == 'Roll Number')),
                              HoverEffect(child: _buildIDTypeButton('Registration Number', _idType == 'Registration Number')),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _idController,
                          decoration: InputDecoration(
                            labelText: _idType,
                            prefixIcon: const Icon(Icons.numbers_outlined),
                            hintText: _idType == 'Roll Number' ? 'e.g. 2025BTECH195' : 'e.g. REG12345',
                          ),
                          textCapitalization: TextCapitalization.characters,
                          inputFormatters: [UpperCaseTextFormatter()],
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
                                title: const Text(
                                  'Male',
                                  style: TextStyle(fontSize: 14),
                                ),
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
                                title: const Text(
                                  'Female',
                                  style: TextStyle(fontSize: 14),
                                ),
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
                  HoverEffect(
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _signup,
                      child: _isSubmitting
                          ? const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                VISTALoader(size: 24, color: Colors.white),
                                SizedBox(width: 12),
                                Text('Submitting...'),
                              ],
                            )
                          : const Text('Submit Registration'),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Already have an account?'),
                      HoverEffect(
                        child: TextButton(
                          onPressed: () {
                            if (Navigator.of(context).canPop()) {
                              Navigator.pop(context);
                            } else {
                              // This case happens during SSO profile completion (where SignupScreen is the root)
                              context.read<vista.AuthProvider>().signOut();
                            }
                          },
                          child: const Text('Login'),
                        ),
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

  Widget _buildIDTypeButton(String type, bool isSelected) {
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _idType = type),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ]
                : null,
          ),
          child: Text(
            type,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              color: isSelected ? const Color(0xFF1E3A8A) : Colors.grey.shade600,
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
          if (_userType == 'Day Scholar') {
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
