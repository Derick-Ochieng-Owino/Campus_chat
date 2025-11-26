import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/colors.dart';
import '../Profile/complete_profile.dart';
import 'login_screen.dart';
import '../home/home_screen.dart';

// Assuming these classes are available in your project structure:
// class CampusData { ... }
// class HomePage extends StatelessWidget { ... }
// class LoginPage extends StatelessWidget { ... }
// class CompleteProfilePage extends StatelessWidget { ... }

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
    // We'll keep the min delay check, ensuring the splash shows for AT LEAST 2 seconds.
    final minDelay = Future.delayed(const Duration(seconds: 2)); // Changed to 2 seconds

    // Perform the logic (Auth + Profile Check) while waiting
    final nextScreenFuture = _determineNextScreen();

    // Wait for BOTH the 2-second timer AND the logic to finish
    final results = await Future.wait([minDelay, nextScreenFuture]);

    // The second result in the list is the Widget returned by _determineNextScreen
    final Widget nextScreen = results[1] as Widget;

    if (!mounted) return;

    // Navigate
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => nextScreen),
    );
  }

  // Separated logic for cleanliness (unchanged)
  Future<Widget> _determineNextScreen() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      // Load campus data first
      CampusData campusData;
      try {
        final jsonString = await rootBundle.loadString('assets/data/campus_data.json');
        campusData = CampusData.fromJsonString(jsonString);
        debugPrint('loading campus JSON in Splash: ');
      } catch (e) {
        debugPrint('Error loading campus JSON in Splash: $e');
        campusData = CampusData(campuses: {}); // fallback
      }

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
          return const HomePage(); // Use const if HomePage is stateless
        } else {
          return CompleteProfilePage(campusData: campusData);
        }
      } else {
        // User exists in Auth but not Firestore -> Complete Profile
        return CompleteProfilePage(campusData: campusData);
      }
    } catch (e) {
      debugPrint("Error in Splash: $e");
      return const LoginPage();
    }
  }


  @override
  Widget build(BuildContext context) {
    // Define the size for the logo and the container
    const double logoSize = 120.0;
    const double indicatorSize = 140.0; // Slightly larger for the progress bar

    return Scaffold(
      // 1. Indigo Background
      backgroundColor: Colors.indigo.shade900,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // 2. Logo with Circular Progress Bar around it
            SizedBox(
              height: indicatorSize,
              width: indicatorSize,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Circular Progress Indicator (Layer 1: Bottom)
                  SizedBox(
                    height: indicatorSize,
                    width: indicatorSize,
                    child: CircularProgressIndicator(
                      color: Colors.white, // White indicator for contrast
                      strokeWidth: 4,
                      // The duration is controlled by the Future.delayed in _navigateAfterDelay
                      // No need for an explicit value here as it should be running continuously
                    ),
                  ),

                  // Logo Image (Layer 2: Top)
                  Container(
                    height: logoSize,
                    width: logoSize,
                    decoration: BoxDecoration(
                      color: Colors.white, // White background for the logo image
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/logo.png',
                      height: logoSize,
                      width: logoSize,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Text
            const Text(
              "Campus Hub",
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white, // White text
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              "Loading your portal...",
              style: TextStyle(
                fontSize: 18,
                color: Colors.white70, // Light grey text
              ),
            ),
          ],
        ),
      ),
    );
  }
}