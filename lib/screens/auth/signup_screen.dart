import 'dart:async';
import 'package:alma_mata/screens/auth/signin_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../services/auth_service.dart';
import 'complete_profile.dart';
import '../home/home_screen.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  // --- Original Form Controllers ---
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // --- State Management Flags ---
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isCampusDataLoaded = false;
  dynamic _universityData;

  // --- Anti-Abuse Rate Limiting Timer Parameters ---
  Timer? _verificationTimer;
  int _resendCooldownSeconds = 0;
  Timer? _cooldownTimer;

  final String _requiredDomain = 'students.jkuat.ac.ke';

  @override
  void initState() {
    super.initState();
    _loadCampusData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _verificationTimer?.cancel();
    _cooldownTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadCampusData() async {
    try {
      final data = await _authService.loadCampusData();
      if (!mounted) return;
      setState(() {
        _universityData = data;
        _isCampusDataLoaded = true;
      });
    } catch (e) {
      debugPrint('Error preparing campus JSON via service: $e');
    }
  }

  // --- Core Verification Processing Sequence ---
  void _startCooldownTimer() {
    setState(() => _resendCooldownSeconds = 60);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCooldownSeconds == 0) {
        _cooldownTimer?.cancel();
      } else {
        setState(() => _resendCooldownSeconds--);
      }
    });
  }

  /// Periodically polls Firebase Auth status to detect user inbox validation clicks automatically
  void _listenForEmailVerification(User user, BuildContext dialogContext) {
    _verificationTimer = Timer.periodic(const Duration(seconds: 3), (timer) async {
      await user.reload();
      final updatedUser = FirebaseAuth.instance.currentUser;

      if (updatedUser != null && updatedUser.emailVerified) {
        _verificationTimer?.cancel();
        _cooldownTimer?.cancel();

        if (!mounted) return;
        Navigator.pop(dialogContext); // Close holding modal view safely

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Email verified successfully!'), backgroundColor: Colors.green),
        );

        // Move securely to dynamic multi-phase setup layout wizard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => CompleteProfilePage(universityData: _universityData)),
        );
      }
    });
  }

  Future<void> _sendVerificationLink(User user) async {
    try {
      await user.sendEmailVerification();
      _startCooldownTimer();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to dispatch verification link: $e'), backgroundColor: Colors.red),
      );
    }
  }

  /// Displays the interactive structural intercept screen holding the user instance context
  void _showVerificationHoldingSheet(User user) {
    _startCooldownTimer();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bContext) {
        final theme = Theme.of(context);
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 12),
                  Icon(Icons.mark_email_unread_rounded, size: 64, color: theme.colorScheme.primary),
                  const SizedBox(height: 16),
                  Text('Verify Your Email', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: theme.textTheme.bodyMedium?.copyWith(height: 1.4),
                      children: [
                        const TextSpan(text: 'We sent an institutional activation link to:\n'),
                        TextSpan(text: user.email, style: const TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const LinearProgressIndicator(),
                  const SizedBox(height: 8),
                  Text(
                    'Waiting automatically for link confirmation...',
                    style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic),
                  ),
                  const SizedBox(height: 24),

                  // Rate-limited dispatch logic trigger
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(_resendCooldownSeconds > 0
                          ? 'Resend Code ($_resendCooldownSeconds s)'
                          : 'Resend Verification Link'
                      ),
                      onPressed: _resendCooldownSeconds > 0 ? null : () async {
                        await _sendVerificationLink(user);
                        setModalState(() {}); // Sync parent state timing countdown inside bottom modal layout
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Typo correction pathway layout
                  TextButton(
                    onPressed: () async {
                      _verificationTimer?.cancel();
                      _cooldownTimer?.cancel();
                      await user.delete(); // Removes temporary record to prevent database account bloat
                      if (!mounted) return;
                      Navigator.pop(bContext);
                    },
                    child: Text('Made a typo? Register again', style: TextStyle(color: theme.colorScheme.error)),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    ).then((_) {
      _verificationTimer?.cancel();
      _cooldownTimer?.cancel();
    });

    _listenForEmailVerification(user, context);
  }

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    setState(() => _isLoading = true);

    try {
      // 1. Create client credential across standard Auth layer
      final credential = await _authService.signUpWithEmail(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );

      if (!mounted) return;
      User? user = credential.user;

      if (user != null) {
        // 2. Dispatch the activation token outward
        await user.sendEmailVerification();

        // 3. Sync original parameters down to Cloud Firestore
        await _authService.syncUserToFirestore(user);

        final userDocRef = _authService.currentUser;
        if (userDocRef != null) {
          await FirebaseFirestore.instance.collection('users').doc(userDocRef.uid).set({
            'profile_completed': false,
            'auth_provider': 'email',
          }, SetOptions(merge: true));
        }

        setState(() => _isLoading = false);
        // Intercept navigation flow and show holding interface
        _showVerificationHoldingSheet(user);
      }

    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String friendlyMessage = "Registration failed.";
      if (e.code == 'email-already-in-use') {
        friendlyMessage = "This student email is already registered.";
      } else if (e.code == 'weak-password') {
        friendlyMessage = "The password provided is too weak.";
      } else if (e.code == 'invalid-email') {
        friendlyMessage = "The email format is invalid.";
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyMessage), backgroundColor: colorScheme.error),
      );
      setState(() => _isLoading = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: $e'), backgroundColor: colorScheme.error),
      );
      setState(() => _isLoading = false);
    }
  }

  /// Google Auth logic handles seamless identity provisioning bypass since domain ownership is pre-verified
  Future<void> _signUpWithGoogle() async {
    if (!_isCampusDataLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('University systems initialization pending...')),
      );
      return;
    }

    setState(() => _isLoading = true);
    final theme = Theme.of(context);

    try {
      final googleSignIn = GoogleSignIn(hostedDomain: _requiredDomain);
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

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

      final googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        await _authService.syncUserToFirestore(user);

        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        if (!mounted) return;

        if (userDoc.exists) {
          final userData = userDoc.data();
          final bool isProfileComplete = userData?['profile_completed'] ?? false;

          if (isProfileComplete) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: const Text("Account already exists. Welcome back!"), backgroundColor: theme.colorScheme.primary),
            );
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
            return;
          }
        }

        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'email': user.email?.toLowerCase(),
          'photo_url': user.photoURL,
          'role': 'student',
          'auth_provider': 'google',
          'profile_completed': false,
          'registered_units': [],
          'created_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        if (!mounted) return;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => CompleteProfilePage(universityData: _universityData)),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      String friendlyMessage = e.message ?? 'Authentication linking failed.';
      if (e.code == 'account-exists-with-different-credential') {
        friendlyMessage = 'An account already exists under this email with standard credentials. Please use your email/password login.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyMessage), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign up failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUpWithApple() async {
    setState(() => _isLoading = true);
    // Platform identity injection hooks...
    setState(() => _isLoading = false);
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
                      height: size.height * 0.25,
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
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20.0, 40.0, 20.0, 24.0),
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
                                  const SizedBox(height: 8),
                                  Text(
                                    'Create Account',
                                    style: theme.textTheme.headlineSmall!.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: themedInputDecoration(
                                      label: 'Student Email',
                                      hint: 'example@$_requiredDomain',
                                      icon: Icons.email,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) return 'Please enter your student email';
                                      if (!value.toLowerCase().endsWith(_requiredDomain)) return 'Email must end with @$_requiredDomain';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),

                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: !_isPasswordVisible,
                                    decoration: themedInputDecoration(
                                      label: 'Password',
                                      icon: Icons.lock,
                                      suffixIcon: IconButton(
                                        icon: Icon(_isPasswordVisible ? Icons.visibility : Icons.visibility_off, color: colorScheme.onSurface.withOpacity(0.6)),
                                        onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) return 'Please enter a password';
                                      if (!RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d).{8,}$').hasMatch(value)) {
                                        return 'Must be 8+ characters, include uppercase, lowercase & number';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),

                                  TextFormField(
                                    controller: _confirmPasswordController,
                                    obscureText: !_isConfirmPasswordVisible,
                                    decoration: themedInputDecoration(
                                      label: 'Confirm Password',
                                      icon: Icons.lock_outline,
                                      suffixIcon: IconButton(
                                        icon: Icon(_isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off, color: colorScheme.onSurface.withOpacity(0.6)),
                                        onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) return 'Please confirm your password';
                                      if (value != _passwordController.text) return 'Passwords do not match';
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 32),

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
                                      onPressed: (!_isCampusDataLoaded || _isLoading) ? null : _signUp,
                                      child: Text(
                                        'SIGN UP',
                                        style: theme.textTheme.labelLarge!.copyWith(fontSize: 18, color: colorScheme.onPrimary),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          icon: Image.asset(
                                              'assets/icons/google_logo.png',
                                              height: 20,
                                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, color: Colors.white, size: 24)
                                          ),
                                          label: const Text('Google', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          onPressed: _isLoading ? null : _signUpWithGoogle,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          icon: const Icon(Icons.apple, color: Colors.white, size: 22),
                                          label: const Text('Apple', overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.black,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          onPressed: _isLoading ? null : _signUpWithApple,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 24),

                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text("Already have an account? ", style: theme.textTheme.bodyMedium!.copyWith(color: colorScheme.onSurface.withOpacity(0.6))),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(builder: (_) => const LoginPage()),
                                          );
                                        },
                                        style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: Size.zero),
                                        child: Text(
                                          "Login Now",
                                          style: theme.textTheme.bodyMedium!.copyWith(color: colorScheme.primary, fontWeight: FontWeight.bold),
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
        },
      ),
    );
  }
}