import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Update these imports to match your project structure
// import '../../core/constants/colors.dart'; // No longer needed
import '../Profile/complete_profile.dart';
import '../home/home_screen.dart';
import 'forgot_password.dart';
import 'ghost.dart';
import 'signup_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  CampusData? campusData;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // Focus Nodes for Ghost Interaction
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isPasswordVisible = false;

  // Track which field is active: 0 = Email, 1 = Password
  int _activeFieldIndex = 0;

  final String _requiredDomain = 'students.jkuat.ac.ke';

  @override
  void initState() {
    super.initState();
    _loadCampusData();

    _emailFocusNode.addListener(() {
      if (_emailFocusNode.hasFocus) setState(() => _activeFieldIndex = 0);
    });

    _passwordFocusNode.addListener(() {
      if (_passwordFocusNode.hasFocus) setState(() => _activeFieldIndex = 1);
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  TextEditingController get _activeController {
    return _activeFieldIndex == 1 ? _passwordController : _emailController;
  }

  FocusNode get _activeFocusNode {
    return _activeFieldIndex == 1 ? _passwordFocusNode : _emailFocusNode;
  }

  Future<void> _loadCampusData() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/campus_data.json');
      final data = CampusData.fromJsonString(jsonString);
      setState(() {
        campusData = data;
      });
    } catch (e) {
      debugPrint('Error loading campus JSON: $e');
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    setState(() => _isLoading = true);

    try {
      // 1. Firebase login
      UserCredential cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User user = cred.user!;

      // 2. Check if email is verified
      if (!user.emailVerified) {
        // Show dialog to resend verification email
        await _showEmailNotVerifiedDialog(user);
        if (mounted) setState(() => _isLoading = false);
        return;
      }

      // 3. Check Firestore for user data
      final userDoc = await FirebaseFirestore.instance.collection("users").doc(user.uid).get();

      if (!mounted) return;

      if (campusData == null) {
        throw Exception("Campus data not loaded. Please try again.");
      }

      if (!userDoc.exists) {
        // Document missing? Treat as incomplete profile
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CompleteProfilePage(campusData: campusData!)));
        return;
      }

      final userData = userDoc.data();
      final role = userData?["role"] ?? "student";

      // Allow specific roles to login
      final allowedRoles = ['student', 'admin', 'class_rep', 'assistant'];
      if (!allowedRoles.contains(role)) {
        throw Exception("Access denied. Your role '$role' is not authorized.");
      }

      // 4. Check if profile is completed
      bool isProfileComplete = userData?['profile_completed'] ?? false;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text("Login Successful!"), backgroundColor: colorScheme.primary),
      );

      // 5. Navigate based on status
      if (isProfileComplete) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CompleteProfilePage(campusData: campusData!)));
      }

    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? "Authentication error"), backgroundColor: colorScheme.error),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: colorScheme.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showEmailNotVerifiedDialog(User user) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Email Not Verified'),
          content: const Text(
            'Please verify your email address before logging in. '
                'Check your inbox for the verification email.',
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: const Text('Resend Email'),
              onPressed: () async {
                Navigator.of(context).pop();
                await _sendVerificationEmail(user);
                await _sendVerificationEmail(user);
                _startEmailVerificationCheck(user);
              },
            ),
          ],
        );

      },
    );
  }

  Future<void> _sendVerificationEmail(User user) async {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    try {
      await user.sendEmailVerification();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Verification email sent! Please check your inbox.'),
            backgroundColor: colorScheme.primary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send verification email: $e'),
            backgroundColor: colorScheme.error,
          ),
        );
      }
    }
  }

  void _startEmailVerificationCheck(User user) {
    int checkCount = 0;
    const maxChecks = 12; // 1 minute max (12 * 5 seconds)

    Timer.periodic(const Duration(seconds: 5), (timer) async {
      checkCount++;

      if (checkCount >= maxChecks) {
        timer.cancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Verification check timeout. Please try logging in again.'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
        return;
      }

      await user.reload();
      final updatedUser = FirebaseAuth.instance.currentUser;

      if (updatedUser != null && updatedUser.emailVerified) {
        timer.cancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Email verified! You can now log in.'),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Helper for input decoration (simplifies the code below)
    InputDecoration _themedInputDecoration({required String label, String? hint, required IconData icon, Widget? suffixIcon}) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: colorScheme.onSurface.withOpacity(0.6)), // Themed Icon color
        // The rest of the decoration (fillColor, focusedBorder, enabledBorder)
        // is inherited from InputDecorationTheme in theme_manager.dart.
        suffixIcon: suffixIcon,
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor, // Dynamic Background
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: SizedBox(
          height: size.height,
          child: Stack(
            children: [
              // Top gradient / background (Dynamic Theme Colors)
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

              // Login form card
              Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Card(
                    color: theme.cardColor, // Dynamic Card Color
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
                            Text(
                              'Student Login',
                              style: theme.textTheme.headlineSmall!.copyWith( // Dynamic Text Style
                                  fontWeight: FontWeight.bold,
                                  color: colorScheme.primary), // Dynamic Primary Color
                            ),
                            const SizedBox(height: 16),

                            // --- INTERACTIVE GHOST ---
                            InteractiveGhost(
                              controller: _activeController,
                              focusNode: _activeFocusNode,
                              isPasswordField: _activeFieldIndex == 1,
                              isPasswordVisible: _isPasswordVisible,
                              size: 120,
                            ),
                            const SizedBox(height: 30),

                            // Email field
                            TextFormField(
                              controller: _emailController,
                              focusNode: _emailFocusNode,
                              onTap: () => setState(() => _activeFieldIndex = 0),
                              keyboardType: TextInputType.emailAddress,
                              decoration: _themedInputDecoration(
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
                            const SizedBox(height: 20),

                            // Password field
                            TextFormField(
                              controller: _passwordController,
                              focusNode: _passwordFocusNode,
                              onTap: () => setState(() => _activeFieldIndex = 1),
                              obscureText: !_isPasswordVisible,
                              decoration: _themedInputDecoration(
                                label: 'Password',
                                icon: Icons.lock,
                                suffixIcon: IconButton(
                                  icon: Icon(_isPasswordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                    color: colorScheme.onSurface.withOpacity(0.6), // Themed visibility icon
                                  ),
                                  onPressed: () => setState(
                                          () => _isPasswordVisible = !_isPasswordVisible),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Enter your password';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 32),

                            // Login button
                            SizedBox(
                              width: double.infinity,
                              child: _isLoading
                                  ? Center(
                                  child:
                                  CircularProgressIndicator(color: colorScheme.primary)) // Dynamic Indicator
                                  : ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: colorScheme.primary, // Dynamic Button BG
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: _login,
                                child: Text(
                                  'LOG IN',
                                  style: theme.textTheme.labelLarge!.copyWith(fontSize: 18, color: colorScheme.onPrimary), // Dynamic Text
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Forgot password
                            TextButton(
                              onPressed: () {
                                Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (_) => const ForgotPasswordPage())
                                );
                              },
                              child: Text(
                                'Forgot Password?',
                                style: theme.textTheme.bodyMedium!.copyWith(color: colorScheme.primary), // Dynamic Primary Link
                              ),
                            ),

                            // Add this to your login screen, below the "Forgot Password" button
                            TextButton(
                              onPressed: () async {
                                final user = FirebaseAuth.instance.currentUser;
                                if (user != null && !user.emailVerified) {
                                  await _sendVerificationEmail(user);
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: const Text('Please log in first or check if you\'re already verified.'),
                                      backgroundColor: theme.colorScheme.error,
                                    ),
                                  );
                                }
                              },
                              child: Text(
                                'Resend Verification Email',
                                style: theme.textTheme.bodyMedium!.copyWith(color: colorScheme.primary),
                              ),
                            ),

                            // Sign up
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  "Don't have an account?",
                                  style: theme.textTheme.bodyMedium!.copyWith(color: colorScheme.onSurface.withOpacity(0.6)), // Dynamic Text
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const SignUpPage()),
                                    );
                                  },
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                    minimumSize: Size.zero,
                                  ),
                                  child: Text(
                                    "Register Now",
                                    style: theme.textTheme.bodyMedium!.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold), // Dynamic Primary Link
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}