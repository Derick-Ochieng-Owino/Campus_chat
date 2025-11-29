import 'package:campus_app/widgets/loading_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart'; // <-- REQUIRED IMPORT
import '../Profile/complete_profile.dart';
import 'login_screen.dart';
import '../home/home_screen.dart';
import 'onboarding_slider.dart';

class SplashScreen extends StatefulWidget {
  final bool hasCompletedOnboarding;

  const SplashScreen({super.key,required this.hasCompletedOnboarding});

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
    // 1. Minimum display time
    final minDelay = Future.delayed(const Duration(seconds: 2)); // Use 2s instead of 3s as noted in comment

    // 2. Perform loading logic
    final nextScreenFuture = _determineNextScreen();

    // 3. Wait for both to finish
    final results = await Future.wait([minDelay, nextScreenFuture]);

    final Widget nextScreen = results[1] as Widget;

    if (!mounted) return;

    // 4. Navigate using replacement
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => nextScreen),
    );
  }

  // 🎯 CORE LOGIC: Determines the final screen, checking Onboarding first 🎯
  Future<Widget> _determineNextScreen() async {
    final prefs = await SharedPreferences.getInstance();
    final bool hasCompletedOnboarding = prefs.getBool('has_completed_onboarding') ?? false;

    // --- ONBOARDING CHECK ---
    if (!hasCompletedOnboarding) {
      // Return the wrapper, which will call the actual home check after the user skips/finishes.
      return const OnboardingSliderWrapper();
    }
    // --- END ONBOARDING CHECK ---

    // Continue with existing authentication and profile checks
    try {
      final user = FirebaseAuth.instance.currentUser;

      // Load campus data first (required for CompleteProfilePage)
      CampusData campusData;
      try {
        final jsonString = await rootBundle.loadString('assets/data/campus_data.json');
        campusData = CampusData.fromJsonString(jsonString);
      } catch (e) {
        campusData = CampusData(campuses: {});
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
          return const HomePage();
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
    return Scaffold(
      backgroundColor: Colors.indigo.shade900,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // --- LOGO + LOADING RING ---
            AppLogoLoadingWidget(size: 80),

            SizedBox(height: 20),

            FadeInAlmaMaterText()
          ],
        ),
      ),
    );
  }
}


class FadeInAlmaMaterText extends StatefulWidget {
  const FadeInAlmaMaterText({super.key});

  @override
  State<FadeInAlmaMaterText> createState() => _FadeInAlmaMaterTextState();
}

class _FadeInAlmaMaterTextState extends State<FadeInAlmaMaterText>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _opacity = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOut,
      ),
    );

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FadeTransition(
      opacity: _opacity,
      child: Text(
        "Alma Mater",
        style: TextStyle(
          fontFamily: "AlmaFont",
          fontSize: 30,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.3,
          color: theme.colorScheme.onPrimary,
        ),
      ),
    );
  }
// ❌ The duplicate _determineNextScreen logic is removed from here.
}

class OnboardingSliderWrapper extends StatelessWidget {
  const OnboardingSliderWrapper({super.key});

  void _handleOnboardingFinish(BuildContext context) {
    // When the user finishes the slider, we push back to the initial route ('/')
    // which causes the splash screen logic to run again.
    // This time, 'has_completed_onboarding' will be true, and it will navigate to HomePage/LoginPage.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const SplashScreen(hasCompletedOnboarding: true,)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingSlider(
      onFinish: () => _handleOnboardingFinish(context),
    );
  }
}