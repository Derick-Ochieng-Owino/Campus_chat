import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// REPLACE with your actual path
import '../../core/constants/colors.dart';
import 'ghost.dart';
import 'login_screen.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode(); // Added FocusNode

  bool _isLoading = false;
  bool _emailSent = false;

  final String _requiredDomain = 'students.jkuat.ac.ke';

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  // Simplified Decoration Helper
  InputDecoration _getDecoration({required String label, String? hint, required IconData icon}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: AppColors.darkGrey),
      filled: true,
      fillColor: AppColors.lightGrey,
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
    );
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Simulate API call delay for UX
    await Future.delayed(const Duration(seconds: 2));

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
          _emailSent = true;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Password reset email sent!"),
            backgroundColor: AppColors.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: ${e.toString()}"),
            backgroundColor: Colors.red, // Use standard red or AppColors.error
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        child: SizedBox(
          height: size.height,
          child: Stack(
            children: [
              // Top gradient / background
              Container(
                height: size.height * 0.35,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(40),
                      bottomRight: Radius.circular(40)),
                ),
              ),

              // Forgot password form card
              Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Card(
                    elevation: 8,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const SizedBox(height: 16),
                            const Text(
                              'Reset Password',
                              style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary),
                            ),
                            const SizedBox(height: 16),

                            // FIXED GHOST: Only listening to Email
                            InteractiveGhost(
                              controller: _emailController,
                              focusNode: _emailFocusNode,
                              isPasswordField: false, // No password field here
                              isPasswordVisible: false,
                              size: 120,
                            ),
                            const SizedBox(height: 30),

                            if (_emailSent) ...[
                              // Success message
                              const Icon(
                                Icons.check_circle,
                                color: AppColors.primary,
                                size: 64,
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'Email Sent!',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.darkGrey,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Check your student email for password reset instructions',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.darkGrey.withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(height: 32),
                            ] else ...[
                              // Instructions
                              Text(
                                'Enter your student email address and we\'ll send you a link to reset your password.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.darkGrey.withOpacity(0.7),
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Email field
                              TextFormField(
                                controller: _emailController,
                                focusNode: _emailFocusNode, // Connect FocusNode
                                keyboardType: TextInputType.emailAddress,
                                decoration: _getDecoration(
                                  label: 'Student Email',
                                  hint: 'example@$_requiredDomain',
                                  icon: Icons.email,
                                ),
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your student email';
                                  }
                                  if (!value.toLowerCase().endsWith(_requiredDomain)) {
                                    return 'Email must end with @$_requiredDomain';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 32),
                            ],

                            // Reset password button
                            SizedBox(
                              width: double.infinity,
                              child: _isLoading
                                  ? const Center(
                                child: CircularProgressIndicator(color: AppColors.primary),
                              )
                                  : ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: _emailSent ? null : _resetPassword,
                                child: Text(
                                  _emailSent ? 'EMAIL SENT' : 'SEND RESET LINK',
                                  style: const TextStyle(
                                      fontSize: 18, color: Colors.white),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            if (_emailSent) ...[
                              // Resend email option
                              TextButton(
                                onPressed: () {
                                  setState(() {
                                    _emailSent = false;
                                    _emailController.clear();
                                  });
                                },
                                child: const Text(
                                  'Send to a different email?',
                                  style: TextStyle(color: AppColors.primary),
                                ),
                              ),
                              const SizedBox(height: 8),
                            ],

                            // Back to login
                            TextButton(
                              onPressed: () {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(builder: (_) => const LoginPage()),
                                );
                              },
                              child: const Text(
                                'Back to Login',
                                style: TextStyle(color: AppColors.darkGrey),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}