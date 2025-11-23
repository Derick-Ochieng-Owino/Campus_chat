import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/constants/colors.dart';
import '../Profile/complete_profile.dart';
import 'login_screen.dart';
import '../home/home_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    // 1. Force a minimum wait time of 3 seconds
    // We use Future.wait to run the Timer and the Auth Check in parallel,
    // ensuring the splash shows for AT LEAST 3 seconds, but doesn't delay extra
    // if the internet connection is fast.

    final minDelay = Future.delayed(const Duration(seconds: 3));

    // 2. Perform the logic (Auth + Profile Check) while waiting
    final nextScreenFuture = _determineNextScreen();

    // 3. Wait for BOTH the 3-second timer AND the logic to finish
    final results = await Future.wait([minDelay, nextScreenFuture]);

    // The second result in the list is the Widget returned by _determineNextScreen
    final Widget nextScreen = results[1] as Widget;

    if (!mounted) return;

    // 4. Navigate
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => nextScreen),
    );
  }

  // Separated logic for cleanliness
  Future<Widget> _determineNextScreen() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return const LoginPage();
      }

      // Check Firestore for profile completion
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (userDoc.exists) {
        final data = userDoc.data();
        final bool isProfileComplete = data?['profile_completed'] ?? false;

        if (isProfileComplete) {
          return const HomePage();
        } else {
          return const CompleteProfilePage();
        }
      } else {
        // User exists in Auth but not Firestore -> Complete Profile
        return const CompleteProfilePage();
      }
    } catch (e) {
      debugPrint("Error in Splash: $e");
      // Default to Login on error
      return const LoginPage();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon or Logo
            // Replace the Icon with this:
            Image.asset(
              'assets/images/logo.png', // Ensure this path matches your folder structure
              height: 120,
              width: 120,
            ),
            const SizedBox(height: 24),

            // Loading Indicator
            const CircularProgressIndicator(
              color: AppColors.primary,
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),

            // Text
            const Text(
              "Campus Hub",
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Loading your portal...",
              style: TextStyle(
                fontSize: 16,
                color: Colors.black54,
              ),
            ),
          ],
        ),
      ),
    );
  }
}