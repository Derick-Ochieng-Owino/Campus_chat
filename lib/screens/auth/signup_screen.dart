import 'package:campus_app/screens/auth/login_screen.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  final String _requiredDomain = 'students.jkuat.ac.ke';

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------
  // 1. MAIN FIRESTORE USER DOCUMENT CREATOR
  // ---------------------------------------------------------
  Future<void> createUserDocument(User user,
      {String? fullName, String? phone}) async {
    final firestore = FirebaseFirestore.instance;
    final userDoc = firestore.collection("users").doc(user.uid);

    final exists = await userDoc.get();
    if (exists.exists) return;

    await userDoc.set({
      "uid": user.uid,
      "email": user.email,
      "fullName": fullName ?? user.displayName ?? "",
      "phone": phone ?? "",
      "photoUrl": user.photoURL ?? "",
      "provider": user.providerData.isNotEmpty
          ? user.providerData.first.providerId
          : "email",
      "createdAt": FieldValue.serverTimestamp(),
      "role": "student",
    });
  }

  // ---------------------------------------------------------
  // 2. EMAIL/PASSWORD SIGNUP
  // ---------------------------------------------------------
  Future<void> _signUpWithEmail() async {
    setState(() => _loading = true);

    try {
      UserCredential cred = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      await createUserDocument(
        cred.user!,
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim(),
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Account created successfully!")),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } on FirebaseAuthException catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message ?? "Authentication error")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  // ---------------------------------------------------------
  // 3. GOOGLE SIGN-IN
  // ---------------------------------------------------------
  Future<void> _signInWithGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential cred =
      await FirebaseAuth.instance.signInWithCredential(credential);

      await createUserDocument(cred.user!);

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Google Sign-In failed: $e")),
      );
    }
  }

  // ---------------------------------------------------------
  // 4. FAKE OTP (Option C)
  // ---------------------------------------------------------
  Future<void> _fakeOtpFlow() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Sending OTP... (simulated)")),
    );

    await Future.delayed(const Duration(seconds: 2));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text("OTP Verified! Creating account..."),
        backgroundColor: Colors.indigo,
      ),
    );

    await _signUpWithEmail();
  }

  // ---------------------------------------------------------
  // 5. SUBMIT HANDLER
  // ---------------------------------------------------------
  void _handleSubmit() {
    if (_formKey.currentState!.validate()) {
      _fakeOtpFlow();
    }
  }

  // ---------------------------------------------------------
  // UI
  // ---------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Create Account"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  "Join Us!",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                ),
                const SizedBox(height: 40),

                // ---------------- NAME ----------------
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: "Full Name",
                    prefixIcon: Icon(Icons.person),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                  v == null || v.isEmpty ? "Enter name" : null,
                ),
                const SizedBox(height: 20),

                // ---------------- EMAIL ----------------
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    labelText: "Email",
                    hintText: "example@$_requiredDomain",
                    prefixIcon: const Icon(Icons.email),
                    border: const OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) {
                      return "Enter your JKUAT email";
                    }
                    if (!v.toLowerCase().endsWith(_requiredDomain)) {
                      return "Email must end with @$_requiredDomain";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ---------------- PHONE ----------------
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: "Phone Number",
                    hintText: "07XX XXX XXX",
                    prefixIcon: Icon(Icons.phone),
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return "Enter phone number";
                    if (!RegExp(r"^(07|01)\d{8}$").hasMatch(v)) {
                      return "Invalid Kenyan phone number";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ---------------- PASSWORD ----------------
                TextFormField(
                  controller: _passwordController,
                  obscureText: !_showPassword,
                  decoration: InputDecoration(
                    labelText: "Password",
                    prefixIcon: const Icon(Icons.lock),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_showPassword
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () =>
                          setState(() => _showPassword = !_showPassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.length < 6) {
                      return "Minimum 6 characters";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 20),

                // ---------------- CONFIRM PASSWORD ----------------
                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: !_showConfirmPassword,
                  decoration: InputDecoration(
                    labelText: "Confirm Password",
                    prefixIcon: const Icon(Icons.lock_reset),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_showConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off),
                      onPressed: () => setState(
                              () => _showConfirmPassword = !_showConfirmPassword),
                    ),
                  ),
                  validator: (v) {
                    if (v != _passwordController.text) {
                      return "Passwords do not match";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 30),

                // ---------------- SIGN UP BUTTON ----------------
                _loading
                    ? const Center(
                    child: CircularProgressIndicator(color: Colors.indigo))
                    : ElevatedButton(
                  onPressed: _handleSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.indigo,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text("SIGN UP & VERIFY",
                      style: TextStyle(fontSize: 18)),
                ),

                const SizedBox(height: 20),

                // ---------------- GOOGLE SIGN-IN ----------------
                OutlinedButton.icon(
                  onPressed: _signInWithGoogle,
                  icon: const Icon(Icons.g_mobiledata),
                  label: const Text("Sign Up with Google"),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
                const SizedBox(height: 20),

                // ---------------- LOGIN LINK ----------------
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => const LoginPage()),
                    );
                  },
                  child: const Text(
                    "Already have an account? Log In",
                    style: TextStyle(color: Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
