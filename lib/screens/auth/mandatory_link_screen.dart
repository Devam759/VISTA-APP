import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/sanitizer.dart';
import 'dart:ui';

class MandatoryLinkScreen extends StatefulWidget {
  const MandatoryLinkScreen({super.key});

  @override
  State<MandatoryLinkScreen> createState() => _MandatoryLinkScreenState();
}

class _MandatoryLinkScreenState extends State<MandatoryLinkScreen> {
  final _rollNoController = TextEditingController();
  bool _isLinking = false;
  bool _isSuccess = false;

  @override
  void initState() {
    super.initState();
    final user = Provider.of<AuthProvider>(context, listen: false).userProfile;
    if (user != null && user.rollNo != null) {
      _rollNoController.text = user.rollNo!;
    }
  }

  @override
  void dispose() {
    _rollNoController.dispose();
    super.dispose();
  }

  Future<void> _handleLinking() async {
    final rollNo = _rollNoController.text.trim().toUpperCase();
    if (rollNo.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your official Roll Number')),
      );
      return;
    }

    setState(() => _isLinking = true);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    try {
      await authProvider.linkMicrosoftAccount(rollNo);
      if (mounted) {
        setState(() {
          _isLinking = false;
          _isSuccess = true;
        });
        
        // Wait a bit to show success before redirecting (AuthWrapper will redirect automatically on profile change)
        await Future.delayed(const Duration(seconds: 2));
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLinking = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isAlreadyLinked = authProvider.firebaseUser?.providerData
            .any((p) => p.providerId == 'microsoft.com') ??
        false;

    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF3B82F6)],
              ),
            ),
          ),
          
          // Custom Bubbles for aesthetic
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.05),
              ),
            ),
          ),

          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(30),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.2),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Icon Header
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: _isSuccess ? Colors.green.withValues(alpha: 0.2) : Colors.blue.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isSuccess ? Icons.verified_user_rounded : Icons.security_rounded,
                              size: 48,
                              color: _isSuccess ? Colors.greenAccent : Colors.white,
                            ),
                          ),
                          const SizedBox(height: 24),
                          
                          Text(
                            _isSuccess ? 'Account Verified!' : 'Identity Verification',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(height: 12),
                          
                          Text(
                            _isSuccess 
                              ? 'Your account has been successfully linked and verified.'
                              : 'The administration requires you to link your Microsoft SSO and verify your Roll Number for security purposes.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withValues(alpha: 0.7),
                              height: 1.5,
                            ),
                          ),
                          const SizedBox(height: 40),

                          if (!_isSuccess) ...[
                            // Microsoft Linking Indicator
                            _StepItem(
                              icon: Icons.link_rounded,
                              title: 'Microsoft SSO Link',
                              subtitle: isAlreadyLinked ? 'Successfully Linked' : 'Required',
                              isCompleted: isAlreadyLinked,
                            ),
                            const SizedBox(height: 16),
                            
                            // Roll Number Input
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.1),
                                ),
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: TextField(
                                controller: _rollNoController,
                                style: const TextStyle(color: Colors.white),
                                textCapitalization: TextCapitalization.characters,
                                inputFormatters: [UpperCaseTextFormatter()],
                                decoration: InputDecoration(
                                  icon: const Icon(Icons.badge_rounded, color: Colors.white70),
                                  hintText: 'Official Roll Number (e.g. 2024BTECH001)',
                                  hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                                  border: InputBorder.none,
                                ),
                              ),
                            ),
                            const SizedBox(height: 32),

                            // Action Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
                              child: ElevatedButton(
                                onPressed: _isLinking ? null : _handleLinking,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isAlreadyLinked ? Colors.blueAccent : Colors.white,
                                  foregroundColor: isAlreadyLinked ? Colors.white : Colors.blueAccent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isLinking
                                    ? const SizedBox(
                                        height: 24,
                                        width: 24,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(Colors.blueAccent),
                                        ),
                                      )
                                    : Text(
                                        isAlreadyLinked ? 'Submit Verification' : 'Link & Verify',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            
                            TextButton(
                              onPressed: () => authProvider.signOut(),
                              child: Text(
                                'Sign Out',
                                style: TextStyle(color: Colors.white.withValues(alpha: 0.5)),
                              ),
                            ),
                          ] else ...[
                            const SizedBox(height: 20),
                            const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation(Colors.greenAccent),
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Redirecting to Dashboard...',
                              style: TextStyle(color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isCompleted;

  const _StepItem({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCompleted ? Colors.green.withValues(alpha: 0.1) : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted ? Colors.greenAccent.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isCompleted ? Icons.check_circle_rounded : icon,
            color: isCompleted ? Colors.greenAccent : Colors.white70,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: isCompleted ? Colors.greenAccent : Colors.white38,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
