import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import 'ghost.dart';
import 'login_screen.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FocusNode _nameFocusNode = FocusNode();
  final FocusNode _emailFocusNode = FocusNode();
  final FocusNode _passwordFocusNode = FocusNode();

  bool _showPassword = false;
  bool _loading = false;
  final String _requiredDomain = 'students.jkuat.ac.ke';

  int _activeFieldIndex = 0;

  @override
  void initState() {
    super.initState();
    _nameFocusNode.addListener(() { if(_nameFocusNode.hasFocus) _updateActiveField(0); });
    _emailFocusNode.addListener(() { if(_emailFocusNode.hasFocus) _updateActiveField(1); });
    _passwordFocusNode.addListener(() { if(_passwordFocusNode.hasFocus) _updateActiveField(2); });
  }

  void _updateActiveField(int index) {
    setState(() {
      _activeFieldIndex = index;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _handleSignUp() {
    if (_formKey.currentState!.validate()) {
      setState(() => _loading = true);
      // Simulate network delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() => _loading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Sign Up Successful!"),
              backgroundColor: AppColors.primary,
            ),
          );
        }
      });
    }
  }

  TextEditingController get _activeController {
    switch (_activeFieldIndex) {
      case 0: return _nameController;
      case 1: return _emailController;
      case 2: return _passwordController;
      default: return _nameController;
    }
  }

  FocusNode get _activeFocusNode {
    switch (_activeFieldIndex) {
      case 0: return _nameFocusNode;
      case 1: return _emailFocusNode;
      case 2: return _passwordFocusNode;
      default: return _nameFocusNode;
    }
  }

  // Shared Input Decoration Styling
  InputDecoration _getDecoration({required String label, String? hint, required IconData icon, Widget? suffixIcon}) {
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
      suffixIcon: suffixIcon,
    );
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
                // Top gradient / background - Updated colors
                Container(
                  height: size.height * 0.35,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, AppColors.secondary],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(40),
                        bottomRight: Radius.circular(40)),
                  ),
                ),

                // Sign up form card
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
                              Text(
                                'Create Account',
                                style: TextStyle(
                                    fontSize: 26,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary),
                              ),
                              const SizedBox(height: 20),

                              // Interactive Ghost
                              InteractiveGhost(
                                controller: _activeController,
                                focusNode: _activeFocusNode,
                                isPasswordField: _activeFieldIndex == 2,
                                isPasswordVisible: _showPassword,
                                size: 120,
                              ),
                              const SizedBox(height: 30),

                              // Name Field
                              TextFormField(
                                controller: _nameController,
                                focusNode: _nameFocusNode,
                                onTap: () => _updateActiveField(0),
                                decoration: _getDecoration(
                                    label: 'Full Name',
                                    hint: 'Enter your full name',
                                    icon: Icons.person
                                ),
                                validator: (v) => v == null || v.isEmpty ? "Enter name" : null,
                              ),
                              const SizedBox(height: 20),

                              // Email field
                              TextFormField(
                                controller: _emailController,
                                focusNode: _emailFocusNode,
                                keyboardType: TextInputType.emailAddress,
                                onTap: () => _updateActiveField(1),
                                decoration: _getDecoration(
                                    label: 'Student Email',
                                    hint: 'example@$_requiredDomain',
                                    icon: Icons.email
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return "Enter email";
                                  }
                                  if (!v.toLowerCase().endsWith(_requiredDomain)) {
                                    return 'Must end with @$_requiredDomain';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 20),

                              // Password field
                              TextFormField(
                                controller: _passwordController,
                                focusNode: _passwordFocusNode,
                                obscureText: !_showPassword,
                                onTap: () => _updateActiveField(2),
                                decoration: _getDecoration(
                                  label: 'Password',
                                  hint: 'Create a password',
                                  icon: Icons.lock,
                                  suffixIcon: IconButton(
                                    icon: Icon(
                                      _showPassword ? Icons.visibility : Icons.visibility_off,
                                      color: AppColors.darkGrey,
                                    ),
                                    onPressed: () => setState(() => _showPassword = !_showPassword),
                                  ),
                                ),
                                validator: (v) => v != null && v.length < 6
                                    ? "Minimum 6 characters"
                                    : null,
                              ),
                              const SizedBox(height: 32),

                              // Sign up button
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: _loading
                                    ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                                    : ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16)),
                                  ),
                                  onPressed: _handleSignUp,
                                  child: const Text(
                                    'SIGN UP',
                                    style: TextStyle(fontSize: 18, color: Colors.white),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Login link
                              Wrap(
                                alignment: WrapAlignment.center,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  const Text(
                                    "Already have an account?",
                                    style: TextStyle(color: AppColors.darkGrey),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const LoginPage()),
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                      minimumSize: Size.zero,
                                    ),
                                    child: const Text(
                                      "Log In",
                                      style: TextStyle(color: AppColors.primary),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
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