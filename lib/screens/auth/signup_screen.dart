import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../Profile/complete_profile.dart';
import 'login_screen.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  UniversityData? universityData;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  final TextEditingController _firstnameController = TextEditingController();
  final TextEditingController _lastnameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;

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

  bool _isCampusDataLoaded = false;

  Future<void> _loadCampusData() async {
    try {
      final jsonString = await rootBundle.loadString('assets/data/campus_data.json');
      final data = UniversityData.fromJsonString(jsonString);
      if (!mounted) return;
      setState(() {
        universityData = data;
        _isCampusDataLoaded = true;
      });
    } catch (e) {
      debugPrint('Error loading campus JSON: $e');
    }
  }

  // In your signup method, add more debugging:
  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) return;

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    setState(() => _isLoading = true);

    try {
      // Create user
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      User user = userCredential.user!;

      debugPrint('User created successfully: ${user.uid}');
      debugPrint('User email: ${user.email}');
      debugPrint('Email verified: ${user.emailVerified}');

      // Send verification email
      await user.sendEmailVerification();
      debugPrint('Verification email sent');

      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid' : user.uid,
          'first_name': _firstnameController.text.trim(),
          'last_name': _lastnameController.text.trim(),
          'email': _emailController.text.trim().toLowerCase(),
          'auth_provider': 'email',
          'role': 'student',
          'profile_completed': false,
          'created_at': FieldValue.serverTimestamp(),
        });
        debugPrint('User data saved to Firestore');
      } catch (e) {
        await user.delete(); // rollback auth user
        rethrow; // propagate error
      }


      // Show success message with verification info
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Account created! Please check your email for verification.'),
            backgroundColor: theme.colorScheme.primary,
            duration: const Duration(seconds: 5),
          ),
        );

        if (!mounted) return;
        // Navigate to complete profile
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => CompleteProfilePage(universityData: universityData!)),
        );
      }

    } on FirebaseAuthException catch (e) {
      debugPrint('Firebase Auth Error: ${e.code} - ${e.message}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message ?? "Registration failed"),
            backgroundColor: colorScheme.error,
          ),
        );
      }
    } catch (e) {
      debugPrint('General Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Registration failed: $e'),
            backgroundColor: colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signUpWithGoogle() async {
    if (!_isCampusDataLoaded) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('University data not loaded yet')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Trigger Google Sign In
      final GoogleSignIn googleSignIn = GoogleSignIn();

      // If this line still errors, run 'flutter clean' in terminal
      final googleUser = await googleSignIn.signIn();

      if (googleUser == null) {
        // User canceled the sign-in flow
        setState(() => _isLoading = false);
        return;
      }

      final googleAuth = await googleUser.authentication;

      final googleCredential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential;

      try {
        // 2. Authenticate with Firebase
        userCredential = await FirebaseAuth.instance.signInWithCredential(googleCredential);

      } on FirebaseAuthException catch (e) {
        if (e.code == 'account-exists-with-different-credential') {
          // methods like fetchSignInMethodsForEmail are removed for security.
          // We simply inform the user to use their original login method.
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('An account already exists with this email. Please log in using Email & Password.'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        } else {
          rethrow;
        }
      }

      // 3. Check if user exists in Firestore, if not create them
      final user = userCredential.user!;
      final userRef = FirebaseFirestore.instance.collection('users').doc(user.uid);

      final snapshot = await userRef.get();

      if (!snapshot.exists) {
        await userRef.set({
          'uid': user.uid,
          'first_name': user.displayName?.split(' ').first ?? '',
          'last_name': user.displayName?.split(' ').skip(1).join(' ') ?? '',
          'email': user.email,
          'photo_url': user.photoURL,
          'role': 'student',
          'auth_provider': 'google',
          'profile_completed': false,
          'registered_units': [],
          'created_at': FieldValue.serverTimestamp(),
        });
      }

      if (!mounted) return;

      // 4. Navigate
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => CompleteProfilePage(universityData: universityData!),
        ),
      );

    } catch (e) {
      if (!mounted) return;
      debugPrint('Google sign up failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sign in failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    InputDecoration _themedInputDecoration({required String label, String? hint, required IconData icon, Widget? suffixIcon}) {
      return InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: colorScheme.onSurface.withOpacity(0.6)),
        suffixIcon: suffixIcon,
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
        child: SizedBox(
          child: Stack(
            children: [
              // Top gradient
              Container(
                height: size.height * 0.3,
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

              // Sign up form card
              Align(
                alignment: Alignment.center,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0

                  ),
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
                            const SizedBox(height: 16),
                            Text(
                              'Create Account',
                              style: theme.textTheme.headlineSmall!.copyWith(
                                fontWeight: FontWeight.bold,
                                color: colorScheme.primary,
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Name field
                            TextFormField(
                              controller: _firstnameController,
                              decoration: _themedInputDecoration(
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

                            TextFormField(
                              controller: _lastnameController,
                              decoration: _themedInputDecoration(
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

                            // Email field
                            TextFormField(
                              controller: _emailController,
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
                              obscureText: !_isPasswordVisible,
                              decoration: _themedInputDecoration(
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
                                  return 'Password must be at least 8 chars, include upper, lower & number';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 20),

                            // Confirm Password field
                            TextFormField(
                              controller: _confirmPasswordController,
                              obscureText: !_isConfirmPasswordVisible,
                              decoration: _themedInputDecoration(
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

                            // Sign up button
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

                            const SizedBox(height: 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: Image.asset('assets/icons/google_logo.png', height: 24), // your Google icon
                                label: Text(
                                  'Sign up with Google',
                                  style: theme.textTheme.labelLarge!.copyWith(
                                    fontSize: 18,
                                    color: colorScheme.onPrimary,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.redAccent,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: _isLoading ? null : _signUpWithGoogle,
                              ),
                            ),

                            // Login link
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Text(
                                  "Already have an account?",
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
                                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
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
  }
}