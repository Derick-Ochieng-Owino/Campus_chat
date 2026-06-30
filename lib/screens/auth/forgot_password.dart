import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/auth_service.dart';
import 'signin_screen.dart';
import 'ghost.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  // --- Original Text Controllers and Focus Nodes ---
  final TextEditingController _emailController = TextEditingController();
  final FocusNode _emailFocusNode = FocusNode();

  // --- Original State Flags ---
  bool _isLoading = false;
  bool _emailSent = false;

  final String _requiredDomain = 'students.jkuat.ac.ke';

  @override
  void dispose() {
    _emailController.dispose();
    _emailFocusNode.dispose();
    super.dispose();
  }

  /// Original theme-compliant decoration builder
  InputDecoration _getDecoration(BuildContext context, {required String label, String? hint, required IconData icon}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: colorScheme.onSurface.withOpacity(0.6)),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
    );
  }

  /// Original reset routine with detailed production exception parsing
  Future<void> _resetPassword() async {
    if (!_formKey.currentState!.validate()) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final emailInput = _emailController.text.trim().toLowerCase();

    setState(() => _isLoading = true);

    try {
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: emailInput)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        if (!mounted) return;
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No account found with this student email.'),
            backgroundColor: colorScheme.error,
          ),
        );
        return; // Stop execution early
      }

      // 2. Fall-through path: Account confirmed! Safe to dispatch the recovery email link
      await _authService.sendPasswordReset(emailInput);

      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _emailSent = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text("A password reset link has been sent! Check your student inbox."),
          backgroundColor: colorScheme.primary,
          duration: const Duration(seconds: 5),
        ),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);

      String errorMessage;
      switch (e.code) {
        case 'invalid-email':
          errorMessage = 'The email address format is invalid.';
          break;
        case 'too-many-requests':
          errorMessage = 'Too many attempts. Please try again later.';
          break;
        case 'network-request-failed':
          errorMessage = 'Connection failed. Please check your internet connection.';
          break;
        default:
          errorMessage = 'An error occurred. Please try again.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: colorScheme.error),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("An error occurred: ${e.toString()}"), backgroundColor: colorScheme.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Stack(
                  children: [
                    // --- Exact Original Background Header Top Gradient Panel ---
                    Container(
                      height: size.height * 0.35,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colorScheme.primary, colorScheme.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(
                          bottomLeft: Radius.circular(40),
                          bottomRight: Radius.circular(40),
                        ),
                      ),
                    ),

                    // --- Form Positioning Constraints Architecture ---
                    Center( // 🛠️ CRITICAL FIX: Forces card elements to sit comfortably in absolute vertical center alignment coords
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                        child: Card(
                          elevation: 8,
                          color: theme.cardColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
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
                                    style: theme.textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary),
                                  ),
                                  const SizedBox(height: 16),

                                  // --- Original Ghost Interaction Point ---
                                  InteractiveGhost(
                                    controller: _emailController,
                                    focusNode: _emailFocusNode,
                                    isPasswordField: false,
                                    isPasswordVisible: false,
                                    size: 120,
                                  ),
                                  const SizedBox(height: 30),

                                  // --- Original Email Success Conditional View States ---
                                  if (_emailSent) ...[
                                    Icon(Icons.check_circle, color: colorScheme.primary, size: 64),
                                    const SizedBox(height: 16),
                                    Text('Email Sent!', style: theme.textTheme.titleMedium!.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Check your student inbox for password reset instructions.',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyMedium!.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
                                    ),
                                    const SizedBox(height: 32),
                                  ] else ...[
                                    Text(
                                      'Enter your student email address and we\'ll send you a link to reset your password.',
                                      textAlign: TextAlign.center,
                                      style: theme.textTheme.bodyMedium!.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
                                    ),
                                    const SizedBox(height: 32),

                                    // --- Email Input Form Field ---
                                    TextFormField(
                                      controller: _emailController,
                                      focusNode: _emailFocusNode,
                                      keyboardType: TextInputType.emailAddress,
                                      decoration: _getDecoration(
                                        context,
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

                                  // --- Action Button Control Trigger ---
                                  SizedBox(
                                    width: double.infinity,
                                    child: _isLoading
                                        ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                                        : ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: colorScheme.primary,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                      ),
                                      onPressed: _emailSent ? null : _resetPassword,
                                      child: Text(
                                        _emailSent ? 'EMAIL SENT' : 'SEND RESET LINK',
                                        style: theme.textTheme.labelLarge!.copyWith(fontSize: 18, color: colorScheme.onPrimary),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // --- Fallback Option Helpers ---
                                  if (_emailSent) ...[
                                    TextButton(
                                      onPressed: () {
                                        setState(() {
                                          _emailSent = false;
                                          _emailController.clear();
                                        });
                                      },
                                      child: Text('Send to a different email?', style: theme.textTheme.bodyMedium!.copyWith(color: colorScheme.primary)),
                                    ),
                                    const SizedBox(height: 8),
                                  ],
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginPage()));
                                    },
                                    child: Text('Back to Login', style: theme.textTheme.bodyMedium!.copyWith(color: colorScheme.onSurface.withOpacity(0.7))),
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
        },
      ),
    );
  }
}