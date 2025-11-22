import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Import your necessary pages
import '../auth/signup_screen.dart';
import 'package:campus_app/screens/auth/login_screen.dart';
import 'package:campus_app/screens/home/home_screen.dart';
import 'package:campus_app/screens/auth/signup_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    _checkAuthStatus();
  }

  void _checkAuthStatus() async {
    // 1. Show the splash screen for at least 2 seconds for a smooth transition.
    await Future.delayed(const Duration(seconds: 2));

    // 2. Use FirebaseAuth to listen for the current user status once.
    // This stream provides the current user (or null if logged out).
    final user = FirebaseAuth.instance.currentUser;

    // 3. Navigate based on the authentication state
    if (!mounted) return;

    Widget nextScreen;
    if (user != null) {
      // User is logged in, go to the main application page
      nextScreen = const HomePage();
    } else {
      // User is not logged in, force them to sign up first
      nextScreen = const SignUpPage();
    }

    // Replace the current route with the next screen
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Simple, centered loading indicator for the splash screen duration
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.indigo),
            SizedBox(height: 20),
            Text(
              "Loading Campus App...",
              style: TextStyle(fontSize: 18, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}