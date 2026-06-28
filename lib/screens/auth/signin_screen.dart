// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/auth_service.dart';
import '../home/home_screen.dart';
import 'complete_profile.dart';
import 'forgot_password.dart';
import 'ghost.dart';
import 'signup_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _rememberMe = false; // Persistent Remember Me checkbox token tracker
  int _activeFieldIndex = 0; // 0 = Email, 1 = Password

  final String _requiredDomain = 'students.jkuat.ac.ke';
  Timer? _verificationTimer;
  dynamic _universityData;

  @override
  void initState() {
    super.initState();
    _loadUniversityData();
    _loadSavedEmailPreference(); // Fetch persistent identity configurations on state initialization

    _emailFocusNode.addListener(() {
      if (_emailFocusNode.hasFocus) setState(() => _activeFieldIndex = 0);
    });

    _passwordFocusNode.addListener(() {
      if (_passwordFocusNode.hasFocus) setState(() => _activeFieldIndex = 1);
    });
  }

  @override
  void dispose() {
    _verificationTimer?.cancel();
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

  /// Extracts university structures safely across centralized service file hooks
  Future<void> _loadUniversityData() async {
    try {
      final data = await _authService.loadCampusData();
      if (mounted) {
        setState(() {
          _universityData = data;
        });
      }
    } catch (e) {
      debugPrint('Error loading campus metrics configuration: $e');
    }
  }

  /// Fetches persistent email credentials from secure storage if Remember Me is active
  Future<void> _loadSavedEmailPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? savedEmail = prefs.getString('remembered_student_email');
      if (savedEmail != null && savedEmail.isNotEmpty) {
        setState(() {
          _emailController.text = savedEmail;
          _rememberMe = true;
        });
      }
    } catch (e) {
      debugPrint("Error reading shared preference configurations: $e");
    }
  }

  /// Persists or purges email token variables based on user preference
  Future<void> _saveEmailPreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_rememberMe) {
        await prefs.setString('remembered_student_email', _emailController.text.trim());
      } else {
        await prefs.remove('remembered_student_email');
      }
    } catch (e) {
      debugPrint("Error writing shared preference modifications: $e");
    }
  }

  Future<void> _signUpWithApple() async {
    setState(() => _isLoading = true);
    // Fires native platform identity tokens up to auth service wrapper architecture...
    setState(() => _isLoading = false);
  }

  /// Rewritten institutional Google OAuth authentication login engine workflow
  Future<void> _signUpWithGoogle() async {
    setState(() => _isLoading = true);
    final theme = Theme.of(context);

    try {
      // 1. Force explicit institutional hosted domain constraints
      final googleSignIn = GoogleSignIn(hostedDomain: _requiredDomain);
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      // 2. Client-side security lock safeguard validation
      if (!googleUser.email.toLowerCase().endsWith(_requiredDomain)) {
        await googleSignIn.signOut();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Access Denied. You must authenticate using your official @$_requiredDomain account.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() => _isLoading = false);
        return;
      }

      // 3. Acquire OAuth sign-in credentials from Google session
      final googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Fire authentication token up to Firebase Auth core
      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        // 5. Look for an existing profile record inside the database collection
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        if (!mounted) return;

        if (userDoc.exists) {
          final userData = userDoc.data();
          final bool isProfileComplete = userData?['profile_completed'] ?? false;

          // If the profile is complete, bypass the setup sliders and go straight home
          if (isProfileComplete) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: const Text("Welcome back! Login Successful."), backgroundColor: theme.colorScheme.primary),
            );
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
            return;
          }
        }

        // 6. Split display strings into distinct fields for new sign-ups
        final String displayName = user.displayName ?? "";
        final List<String> nameParts = displayName.split(" ");
        final String firstName = nameParts.isNotEmpty ? nameParts.first : "";
        final String lastName = nameParts.length > 1 ? nameParts.skip(1).join(" ") : "";

        // 7. Initialize user metadata base structures inside Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'first_name': firstName,
          'last_name': lastName,
          'email': user.email?.toLowerCase(),
          'photo_url': user.photoURL,
          'role': 'student',
          'auth_provider': 'google',
          'profile_completed': false,
          'registered_units': [],
          'created_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (!mounted) return;

        // Force remaining profile updates on first sign-up
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => CompleteProfilePage(universityData: _universityData)),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String friendlyMessage = e.message ?? 'Google OAuth authentication processing aborted.';
      if (e.code == 'account-exists-with-different-credential') {
        friendlyMessage = 'An account already exists with standard credentials under this email. Use your password entry forms.';
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyMessage), backgroundColor: Colors.red));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Login failed: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Standard email/password processing engine
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    setState(() => _isLoading = true);

    try {
      UserCredential cred = await _authService.signInWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;
      User? user = cred.user;

      if (user != null) {
        await user.reload();
        user = FirebaseAuth.instance.currentUser ?? user;

        if (!user.emailVerified) {
          await _showEmailNotVerifiedDialog(user);
          if (mounted) setState(() => _isLoading = false);
          return;
        }
      }

      await _saveEmailPreference(); // Commit Remember Me caching configurations to device
      final String targetRoute = await _authService.determineNextScreenRoute();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: const Text("Login Successful!"), backgroundColor: colorScheme.primary),
      );

      if (targetRoute == 'home') {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CompleteProfilePage(universityData: _universityData)));
      }

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String friendlyMessage = "Authentication error occurred.";

      if (e.code == 'user-not-found' || e.code == 'wrong-password' || e.code == 'invalid-credential') {
        friendlyMessage = "Invalid credentials. Please verify your email and password.";
      } else if (e.code == 'network-request-failed') {
        friendlyMessage = "Connection failed. Please check your internet connection.";
      } else if (e.code == 'user-disabled') {
        friendlyMessage = "This student account has been disabled.";
      } else if (e.code == 'too-many-requests') {
        friendlyMessage = "Too many failed attempts. Try again later.";
      } else if (e.message != null) {
        friendlyMessage = e.message!;
      }

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyMessage), backgroundColor: colorScheme.error));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: colorScheme.error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showEmailNotVerifiedDialog(User user) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Email Not Verified'),
          content: const Text('Please verify your email address before logging in. Check your student inbox for the verification email link.'),
          actions: <Widget>[
            TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(dialogContext).pop()),
            TextButton(
              child: const Text('Resend Email'),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
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
    try {
      await user.sendEmailVerification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Verification email sent! Please check your portal inbox.'), backgroundColor: theme.colorScheme.primary));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send verification email: $e'), backgroundColor: theme.colorScheme.error));
    }
  }

  void _startEmailVerificationCheck(User user) {
    _verificationTimer?.cancel();
    int checkCount = 0;
    const maxChecks = 12;

    _verificationTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      checkCount++;
      if (checkCount >= maxChecks) {
        timer.cancel();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Verification check timeout. Please sign in again once verified.'), backgroundColor: Theme.of(context).colorScheme.error));
        }
        return;
      }
      try {
        await user.reload();
        final updatedUser = FirebaseAuth.instance.currentUser;
        if (updatedUser != null && updatedUser.emailVerified) {
          timer.cancel();
          if (mounted) {
            await updatedUser.getIdToken(true);
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Email verified! You can now log in securely.'), backgroundColor: Theme.of(context).colorScheme.primary));
          }
        }
      } catch (e) {
        debugPrint("Silent polling loop trace: $e");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    InputDecoration themedInputDecoration({required String label, String? hint, required IconData icon, Widget? suffixIcon}) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: colorScheme.onSurface.withOpacity(0.6)),
        suffixIcon: suffixIcon,
      );
    }

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
                    Container(
                      height: size.height * 0.35,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [colorScheme.primary, colorScheme.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
                      ),
                    ),
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24.0),
                        child: Card(
                          color: theme.cardColor,
                          elevation: 8,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 16),
                                  Text('Student Login', style: theme.textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary)),
                                  const SizedBox(height: 16),
                                  InteractiveGhost(
                                    controller: _activeController,
                                    focusNode: _activeFocusNode,
                                    isPasswordField: _activeFieldIndex == 1,
                                    isPasswordVisible: _isPasswordVisible,
                                    size: 120,
                                  ),
                                  const SizedBox(height: 30),
                                  TextFormField(
                                    controller: _emailController,
                                    focusNode: _emailFocusNode,
                                    onTap: () => setState(() => _activeFieldIndex = 0),
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: themedInputDecoration(label: 'Student Email', hint: 'example@$_requiredDomain', icon: Icons.email),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) return 'Please enter your student email';
                                      if (!value.toLowerCase().endsWith(_requiredDomain)) return 'Email must end with @$_requiredDomain';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  TextFormField(
                                    controller: _passwordController,
                                    focusNode: _passwordFocusNode,
                                    onTap: () => setState(() => _activeFieldIndex = 1),
                                    obscureText: !_isPasswordVisible,
                                    decoration: themedInputDecoration(
                                      label: 'Password',
                                      icon: Icons.lock,
                                      suffixIcon: IconButton(
                                        icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: colorScheme.onSurface.withOpacity(0.6)),
                                        onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                                      ),
                                    ),
                                    validator: (value) => (value == null || value.isEmpty) ? 'Enter your password' : null,
                                  ),

                                  // --- REMEMBER ME CHECKSBOX UTILITY ---
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          height: 24,
                                          child: Checkbox(
                                            value: _rememberMe,
                                            activeColor: colorScheme.primary,
                                            onChanged: (bool? newValue) {
                                              setState(() {
                                                _rememberMe = newValue ?? false;
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text('Remember Me', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onSurface.withOpacity(0.7))),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),

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
                                      onPressed: _login,
                                      child: Text('LOG IN', style: theme.textTheme.labelLarge!.copyWith(fontSize: 18, color: colorScheme.onPrimary)),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          icon: Image.asset('assets/icons/google_logo.png', height: 20, errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, color: Colors.white, size: 24)),
                                          label: const Text('Google', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                          onPressed: _isLoading ? null : _signUpWithGoogle,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          icon: const Icon(Icons.apple, color: Colors.white, size: 22),
                                          label: const Text('Apple', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
                                          style: ElevatedButton.styleFrom(backgroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                                          onPressed: _isLoading ? null : _signUpWithApple,
                                        ),
                                      ),
                                    ],
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage())),
                                    child: Text('Forgot Password?', style: theme.textTheme.bodyMedium!.copyWith(color: colorScheme.primary)),
                                  ),
                                  TextButton(
                                    onPressed: () async {
                                      final user = FirebaseAuth.instance.currentUser;
                                      if (user != null && !user.emailVerified) {
                                        await _sendVerificationEmail(user);
                                      } else {
                                        if (!mounted) return;
                                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Please log in first or check if you\'re already verified.'), backgroundColor: theme.colorScheme.error));
                                      }
                                    },
                                    child: Text('Resend Verification Email', style: theme.textTheme.bodyMedium!.copyWith(color: colorScheme.primary)),
                                  ),
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text("Don't have an account?", style: theme.textTheme.bodyMedium!.copyWith(color: colorScheme.onSurface.withOpacity(0.6))),
                                      TextButton(
                                        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpPage())),
                                        style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4.0), minimumSize: Size.zero),
                                        child: Text("Register Now", style: theme.textTheme.bodyMedium!.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold)),
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
        },
      ),
    );
  }
}