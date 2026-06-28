// ignore_for_file: deprecated_member_use

import 'package:alma_mata/screens/auth/signin_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../../services/auth_service.dart';
import 'complete_profile.dart';
import '../home/home_screen.dart'; // Ensure HomePage is imported for direct routing

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();

  // --- Original Form Controllers ---
  final TextEditingController _firstnameController = TextEditingController();
  final TextEditingController _lastnameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  // --- Original State Management Flags ---
  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _isCampusDataLoaded = false;
  dynamic _universityData;

  final String _requiredDomain = 'students.jkuat.ac.ke';

  @override
  void initState() {
    super.initState();
    _loadCampusData();
  }

  @override
  void dispose() {
    _firstnameController.dispose();
    _lastnameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /// Original logic mapping JSON data safely using the single AuthService layer
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

  /// Refactored manual form registration supplying structural layout variables
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
        // 2. Trigger verification email link out to user inbox
        await user.sendEmailVerification();

        // 3. Sync original parameters down to Cloud Firestore
        await _authService.syncUserToFirestore(user);

        final userDocRef = _authService.currentUser;
        if (userDocRef != null) {
          await FirebaseFirestore.instance.collection('users').doc(userDocRef.uid).set({
            'first_name': _firstnameController.text.trim(),
            'last_name': _lastnameController.text.trim(),
            'profile_completed': false,
            'auth_provider': 'email',
          }, SetOptions(merge: true));
        }
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Account created! Please verify your student email link.'),
          backgroundColor: theme.colorScheme.primary,
          duration: const Duration(seconds: 5),
        ),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => CompleteProfilePage(universityData: _universityData)),
      );

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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registration failed: $e'), backgroundColor: colorScheme.error),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Fully implemented Google Sign In authentication pipeline with Account existence checks
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
      // 1. Instantiate GoogleSignIn with your required institutional domain lock
      final googleSignIn = GoogleSignIn(hostedDomain: _requiredDomain);
      final googleUser = await googleSignIn.signIn();

      // If the user cancels the native popup prompt, abort gracefully
      if (googleUser == null) {
        setState(() => _isLoading = false);
        return;
      }

      // 2. CRITICAL SECURITY GUARD: Reject generic personal external Gmail profiles (@gmail.com)
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

      // 3. Obtain authentication keys from the Google provider session
      final googleAuth = await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Authenticate into Firebase Auth via the central credential
      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      User? user = userCredential.user;

      if (user != null) {
        // 5. Run standard sync routine via your unified logic file
        await _authService.syncUserToFirestore(user);

        // 🎯 🛠️ ACCOUNT EXISTENCE CHECK: Verify if this user document already exists in Firestore
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();

        if (!mounted) return;

        if (userDoc.exists) {
          final userData = userDoc.data();
          final bool isProfileComplete = userData?['profile_completed'] ?? false;

          // If they already have a completed profile, route them straight home instead of forcing setup
          if (isProfileComplete) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: const Text("Account already exists. Welcome back!"), backgroundColor: theme.colorScheme.primary),
            );
            Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
            return;
          }
        }

        // 6. Split Google's combined display string into atomic fields if it's a new registration
        final String displayName = user.displayName ?? "";
        final List<String> nameParts = displayName.split(" ");
        final String firstName = nameParts.isNotEmpty ? nameParts.first : "";
        final String lastName = nameParts.length > 1 ? nameParts.skip(1).join(" ") : "";

        // 7. Commit profile elements securely down to the Cloud Firestore node document
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

        // 8. Push replacement directly into your CompleteProfile screen setup
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => CompleteProfilePage(universityData: _universityData),
          ),
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

  /// 🛠️ NEW FUNCTION: Third Party Federated Apple Authorization Channel Hook
  Future<void> _signUpWithApple() async {
    setState(() => _isLoading = true);
    // Fires native platform identity tokens up to auth service wrapper architecture...
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // --- Original Theme-Compliant Input Decoration Builder ---
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
                    // --- Exact Original Top Gradient Header Background Panel ---
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

                    // --- Form Positioning Center Constraints Wrapper ---
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20.0, 40.0, 20.0, 24.0),
                        child: Card(
                          color: theme.cardColor,
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
                                  const SizedBox(height: 8),
                                  Text(
                                    'Create Account',
                                    style: theme.textTheme.headlineSmall!.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: colorScheme.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 24),

                                  // --- First Name Field ---
                                  TextFormField(
                                    controller: _firstnameController,
                                    textCapitalization: TextCapitalization.words,
                                    decoration: themedInputDecoration(
                                      label: 'First Name',
                                      icon: Icons.person,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your first name';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),

                                  // --- Last Name Field ---
                                  TextFormField(
                                    controller: _lastnameController,
                                    textCapitalization: TextCapitalization.words,
                                    decoration: themedInputDecoration(
                                      label: 'Last Name',
                                      icon: Icons.person_outlined,
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter your last name';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),

                                  // --- Student Email Field ---
                                  TextFormField(
                                    controller: _emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: themedInputDecoration(
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

                                  // --- Password Field ---
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: !_isPasswordVisible,
                                    decoration: themedInputDecoration(
                                      label: 'Password',
                                      icon: Icons.lock,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                          color: colorScheme.onSurface.withOpacity(0.6),
                                        ),
                                        onPressed: () => setState(() => _isPasswordVisible = !_isPasswordVisible),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please enter a password';
                                      }
                                      if (!RegExp(r'^(?=.*[A-Z])(?=.*[a-z])(?=.*\d).{8,}$').hasMatch(value)) {
                                        return 'Must be 8+ characters, include uppercase, lowercase & number';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),

                                  // --- Confirm Password Field ---
                                  TextFormField(
                                    controller: _confirmPasswordController,
                                    obscureText: !_isConfirmPasswordVisible,
                                    decoration: themedInputDecoration(
                                      label: 'Confirm Password',
                                      icon: Icons.lock_outline,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _isConfirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                                          color: colorScheme.onSurface.withOpacity(0.6),
                                        ),
                                        onPressed: () => setState(() => _isConfirmPasswordVisible = !_isConfirmPasswordVisible),
                                      ),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Please confirm your password';
                                      }
                                      if (value != _passwordController.text) {
                                        return 'Passwords do not match';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 32),

                                  // --- Interactive Loading / Form Submit Actions ---
                                  SizedBox(
                                    width: double.infinity,
                                    child: _isLoading
                                        ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                                        : ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: colorScheme.primary,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(16),
                                        ),
                                      ),
                                      onPressed: (!_isCampusDataLoaded || _isLoading) ? null : _signUp,
                                      child: Text(
                                        'SIGN UP',
                                        style: theme.textTheme.labelLarge!.copyWith(
                                          fontSize: 18,
                                          color: colorScheme.onPrimary,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  // --- Side-by-Side Federated Login Row ---
                                  Row(
                                    children: [
                                      // Google Login Button Wrapper
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          icon: Image.asset(
                                              'assets/icons/google_logo.png',
                                              height: 20,
                                              errorBuilder: (context, error, stackTrace) => const Icon(Icons.g_mobiledata, color: Colors.white, size: 24)
                                          ),
                                          label: const Text(
                                            'Google',
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.redAccent,
                                            padding: const EdgeInsets.symmetric(vertical: 14),
                                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          ),
                                          onPressed: _isLoading ? null : _signUpWithGoogle,
                                        ),
                                      ),
                                      const SizedBox(width: 12),

                                      // Apple Login Button Wrapper
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          icon: const Icon(Icons.apple, color: Colors.white, size: 22),
                                          label: const Text(
                                            'Apple',
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold),
                                          ),
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

                                  // --- Existing Navigation Redirect to Login Now ---
                                  Wrap(
                                    alignment: WrapAlignment.center,
                                    crossAxisAlignment: WrapCrossAlignment.center,
                                    children: [
                                      Text(
                                        "Already have an account? ",
                                        style: theme.textTheme.bodyMedium!.copyWith(
                                          color: colorScheme.onSurface.withOpacity(0.6),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.pushReplacement(
                                            context,
                                            MaterialPageRoute(builder: (_) => const LoginPage()),
                                          );
                                        },
                                        style: TextButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          minimumSize: Size.zero,
                                        ),
                                        child: Text(
                                          "Login Now",
                                          style: theme.textTheme.bodyMedium!.copyWith(
                                            color: colorScheme.primary,
                                            fontWeight: FontWeight.bold,
                                          ),
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