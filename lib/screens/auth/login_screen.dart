import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Update these imports to match your project structure
import '../../core/constants/colors.dart';
import '../Profile/complete_profile.dart';
import '../home/home_screen.dart';
import 'forgot_password.dart';
import 'ghost.dart';
import 'signup_screen.dart'; // <--- IMPORT THIS

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
    _loadCampusData;

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

    setState(() => _isLoading = true);

    try {
      // 1. Firebase login
      UserCredential cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Define 'user' here so it is available for the Firestore check
      User user = cred.user!;

      // 3. Check Firestore for user data
      final userDoc = await FirebaseFirestore.instance.collection("users").doc(user.uid).get();

      if (!mounted) return;

      if (!userDoc.exists) {
        // Document missing? Treat as incomplete profile
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CompleteProfilePage(campusData: campusData!,)));
        return;
      }

      final userData = userDoc.data();
      final role = userData?["role"] ?? "student";

      if (role != "student") {
        throw Exception("Only student accounts can log in here.");
      }

      // 4. Check if profile is completed
      bool isProfileComplete = userData?['profile_completed'] ?? false;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Login Successful!"), backgroundColor: AppColors.primary),
      );

      // 5. Navigate based on status
      if (isProfileComplete) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomePage()));
      } else {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => CompleteProfilePage(campusData: campusData!,)));
      }

    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? "Auth error"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        physics: const ClampingScrollPhysics(),
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

              // Login form card
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
                              'Student Login',
                              style: TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary),
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
                              decoration: InputDecoration(
                                labelText: 'Student Email',
                                hintText: 'example@$_requiredDomain',
                                prefixIcon: const Icon(Icons.email),
                                filled: true,
                                fillColor: AppColors.lightGrey,
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
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
                              decoration: InputDecoration(
                                labelText: 'Password',
                                prefixIcon: const Icon(Icons.lock),
                                filled: true,
                                fillColor: AppColors.lightGrey,
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: const BorderSide(color: AppColors.primary, width: 2),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  borderSide: BorderSide.none,
                                ),
                                suffixIcon: IconButton(
                                  icon: Icon(_isPasswordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off),
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
                                  ? const Center(
                                  child:
                                  CircularProgressIndicator(color: AppColors.primary))
                                  : ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16)),
                                ),
                                onPressed: _login,
                                child: const Text(
                                  'LOG IN',
                                  style: TextStyle(fontSize: 18, color: Colors.white),
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
                              child: const Text(
                                'Forgot Password?',
                                style: TextStyle(color: AppColors.primary),
                              ),
                            ),

                            // Sign up
                            Wrap(
                              alignment: WrapAlignment.center,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                const Text(
                                  "Don't have an account?",
                                  style: TextStyle(color: AppColors.darkGrey),
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
                                  child: const Text(
                                    "Register Now",
                                    style: TextStyle(color: AppColors.primary),
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