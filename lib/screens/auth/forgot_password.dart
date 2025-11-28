import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
// Note: AppColors import is kept for reference but its values are overridden
// import '../../core/constants/colors.dart';
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
  final FocusNode _emailFocusNode = FocusNode();

  bool _isLoading = false;
  bool _emailSent = false;

  final String _requiredDomain = 'students.jkuat.ac.ke';

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  // Simplified Decoration Helper (Themed)
  InputDecoration _getDecoration(BuildContext context, {required String label, String? hint, required IconData icon}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // The rest of the decoration is inherited from InputDecorationTheme in theme_manager
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: colorScheme.onSurface.withOpacity(0.6)), // Themed Icon color
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    );
  }

  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    setState(() => _isLoading = true);

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
          SnackBar(
            content: const Text("Password reset email sent! Check your inbox."),
            backgroundColor: colorScheme.primary,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        String errorMessage;
        switch (e.code) {
          case 'user-not-found':
            errorMessage = 'No account found with this email address.';
            break;
          case 'invalid-email':
            errorMessage = 'Email address is invalid.';
            break;
          case 'too-many-requests':
            errorMessage = 'Too many attempts. Please try again later.';
            break;
          default:
            errorMessage = 'An error occurred. Please try again.';
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: colorScheme.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Network error: ${e.toString()}"),
            backgroundColor: colorScheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // Dynamic Background
      body: SingleChildScrollView(
        child: SizedBox(
          height: size.height,
          child: Stack(
            children: [
              // Top gradient / background (Themed)
              Container(
                height: size.height * 0.35,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [colorScheme.primary, colorScheme.secondary], // Dynamic Gradient
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
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
                    color: theme.cardColor, // Dynamic Card Color
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
                            Text(
                              'Reset Password',
                              style: theme.textTheme.headlineSmall!.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary), // Dynamic Primary Color
                            ),
                            const SizedBox(height: 16),

                            // Ghost (No change needed)
                            InteractiveGhost(
                              controller: _emailController,
                              focusNode: _emailFocusNode,
                              isPasswordField: false,
                              isPasswordVisible: false,
                              size: 120,
                            ),
                            const SizedBox(height: 30),

                            if (_emailSent) ...[
                              // Success message
                              Icon(
                                Icons.check_circle,
                                color: colorScheme.primary, // Dynamic Primary Color
                                size: 64,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Email Sent!',
                                style: theme.textTheme.titleMedium!.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.onSurface, // Dynamic Text Color
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Check your student email for password reset instructions',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium!.copyWith(
                                  color: colorScheme.onSurface.withOpacity(0.7), // Dynamic Text Color
                                ),
                              ),
                              const SizedBox(height: 32),
                            ] else ...[
                              // Instructions
                              Text(
                                'Enter your student email address and we\'ll send you a link to reset your password.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium!.copyWith(
                                  color: colorScheme.onSurface.withOpacity(0.7), // Dynamic Text Color
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Email field
                              TextFormField(
                                controller: _emailController,
                                focusNode: _emailFocusNode,
                                keyboardType: TextInputType.emailAddress,
                                decoration: _getDecoration(context,
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
                                  ? Center(
                                child: CircularProgressIndicator(color: colorScheme.primary), // Dynamic Indicator
                              )
                                  : ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.primary, // Dynamic Button BG
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: _emailSent ? null : _resetPassword,
                                child: Text(
                                  _emailSent ? 'EMAIL SENT' : 'SEND RESET LINK',
                                  style: theme.textTheme.labelLarge!.copyWith(
                                      fontSize: 18,
                                      color: colorScheme.onPrimary), // Dynamic Text
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
                                child: Text(
                                  'Send to a different email?',
                                  style: theme.textTheme.bodyMedium!.copyWith(color: colorScheme.primary), // Dynamic Primary Link
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
                              child: Text(
                                'Back to Login',
                                style: theme.textTheme.bodyMedium!.copyWith(color: colorScheme.onSurface.withOpacity(0.7)), // Dynamic Text
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