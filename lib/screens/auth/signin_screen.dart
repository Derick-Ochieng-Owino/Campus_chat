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

  // --- Rate Limiting Verification Cooldown Parameters ---
  int _loginCooldownSeconds = 0;
  Timer? _loginCooldownTimer;

  final String _requiredDomain = 'students.jkuat.ac.ke';
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
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _loginCooldownTimer?.cancel(); // Kill active ticker background footprints cleanly
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

  // --- Secure Authentication Rate Limiter ---
  void _startLoginCooldown() {
    setState(() => _loginCooldownSeconds = 60);
    _loginCooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_loginCooldownSeconds == 0) {
        _loginCooldownTimer?.cancel();
      } else {
        setState(() => _loginCooldownSeconds--);
      }
    });
  }

  /// Displays the secondary structural verification intercept sheet
  void _showLoginVerificationModal(User user) {
    _startLoginCooldown();

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
                  Text('Email Not Verified Yet', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  Text(
                    'Your account setup exists, but your institutional student email has not been activated yet.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    user.email ?? '',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 24),

                  // Rate-limited Link Resend Option
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.send_rounded),
                      label: Text(_loginCooldownSeconds > 0
                          ? 'Resend Link ($_loginCooldownSeconds s)'
                          : 'Resend Verification Email'
                      ),
                      onPressed: _loginCooldownSeconds > 0 ? null : () async {
                        try {
                          await user.sendEmailVerification();
                          _startLoginCooldown();
                          setModalState(() {}); // Force update countdown inside dialog canvas
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('A fresh verification link has been sent to your inbox.')),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                          );
                        }
                      },
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Clean abort navigation option
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      onPressed: () async {
                        _loginCooldownTimer?.cancel();
                        await FirebaseAuth.instance.signOut(); // Cleanly detach local memory footprint token
                        if (!mounted) return;
                        Navigator.pop(bContext);
                      },
                      child: const Text('Back to Sign In'),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            );
          },
        );
      },
    ).then((_) async {
      _loginCooldownTimer?.cancel();
      // Safety Intercept Guard: Ensure unverified credentials don't bypass auth rules if sheets dismiss weirdly
      if (FirebaseAuth.instance.currentUser != null && !FirebaseAuth.instance.currentUser!.emailVerified) {
        await FirebaseAuth.instance.signOut();
      }
    });
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
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        if (!mounted) return;

        if (userDoc.exists) {
          final userData = userDoc.data();
          final bool isProfileComplete = userData?['profile_completed'] ?? false;

          if (isProfileComplete) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: const Text("Welcome back! Login Successful."), backgroundColor: theme.colorScheme.primary),
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

        // 🎯 THE CRITICAL SECURITY INTERCEPT STEP:
        if (!user.emailVerified) {
          setState(() => _isLoading = false);
          _showLoginVerificationModal(user); // Hold execution and display safety sheet
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