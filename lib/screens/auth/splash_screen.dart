import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'complete_profile.dart';
import 'onboarding_slider.dart';
import 'signin_screen.dart';
import '../home/home_screen.dart';
import '../../widgets/loading_widget.dart';

class SplashScreen extends StatefulWidget {
  final bool hasCompletedOnboarding;

  const SplashScreen({super.key, required this.hasCompletedOnboarding});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final AuthService _authService = AuthService();

  @override
  void initState() {
    super.initState();
    _handleAppRouting();
  }

  /// Evaluates background application routes via the centralized AuthService layer
  Future<void> _handleAppRouting() async {
    // 1. Maintain the exact 2-second minimum display time animation guarantee
    final minDelay = Future.delayed(const Duration(seconds: 2));

    // 2. Fetch target landing destination path string
    String targetRoute;
    if (widget.hasCompletedOnboarding) {
      // 🛠️ FIX: If explicitly completed from slider wrapper, bypass disk read checking fallback
      final user = _authService.currentUser;
      if (user == null) {
        targetRoute = 'login';
      } else {
        targetRoute = await _authService.determineNextScreenRoute();
      }
    } else {
      // Standard deep system startup orchestration check
      targetRoute = await _authService.determineNextScreenRoute();
    }

    // 3. Coordinate both timelines securely
    await minDelay;
    if (!mounted) return;

    // 4. Resolve exact views matching output states
    Widget nextScreen;
    switch (targetRoute) {
      case 'onboarding':
        nextScreen = const OnboardingSliderWrapper();
        break;
      case 'login':
        nextScreen = const LoginPage();
        break;
      case 'complete_profile':
        final universityData = await _authService.loadCampusData();
        nextScreen = CompleteProfilePage(universityData: universityData);
        break;
      default:
        nextScreen = const HomePage();
    }

    // 5. Fire smooth, single-stack route replacements
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => nextScreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.indigo.shade900,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AppLogoLoadingWidget(size: 80),
            SizedBox(height: 20),
            FadeInAlmaMaterText()
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// --- Preserved Original Animated Text Layout Component ---
// ====================================================================
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
}

// ====================================================================
// --- Onboarding Slider Routing Wrapper ---
// ====================================================================
class OnboardingSliderWrapper extends StatelessWidget {
  const OnboardingSliderWrapper({super.key});

  void _handleOnboardingFinish(BuildContext context) async {
    // 🛠️ FIX: Explicitly await asynchronous disk persistence flag before pushing context state replacements
    await AuthService().markOnboardingComplete();

    if (!context.mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (context) => const SplashScreen(hasCompletedOnboarding: true),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return OnboardingSlider(
      onFinish: () => _handleOnboardingFinish(context),
    );
  }
}