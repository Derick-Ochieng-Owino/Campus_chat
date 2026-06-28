// ignore_for_file: deprecated_member_use

import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import 'splash_screen.dart';

class OnboardingSlider extends StatefulWidget {
  final VoidCallback onFinish;

  const OnboardingSlider({super.key, required this.onFinish});

  @override
  State<OnboardingSlider> createState() => _OnboardingSliderState();
}

class _OnboardingSliderState extends State<OnboardingSlider> {
  final PageController _pageController = PageController();
  Timer? _timer;
  int _currentPage = 0;

  // --- Exact Original 5 Slides with Asset Paths Intact ---
  final List<Map<String, String>> _slides = [
    {
      'title': 'Welcome to Alma Mater!',
      'description': 'Your central platform for course notes, groups, and campus communication.',
      'image': 'assets/images/onboarding_1.jpg',
    },
    {
      'title': 'Real-time Group Chat',
      'description': 'Chat with your course, year, or specific group subdivisions (A & B) instantly.',
      'image': 'assets/images/onboarding_2.jpg',
    },
    {
      'title': 'Access All Course Notes',
      'description': 'Download notes, assignments, and CATs uploaded by your class reps and lecturers.',
      'image': 'assets/images/onboarding_3.jpg',
    },
    {
      'title': 'Stay Updated & On Time',
      'description': 'Receive instant modal pop-ups for critical Class Confirmations, Assignments, Notes and CAT setup reminders.',
      'image': 'assets/images/onboarding_4.jpg',
    },
    {
      'title': 'Alma Mater',
      'description': 'Unlock your potential with personalized learning',
      'image': 'assets/images/onboarding_5.png',
    },
  ];

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // --- Preserved Original Timer Logic ---
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_currentPage < _slides.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
        );
      } else {
        _timer?.cancel();
        widget.onFinish();
      }
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    _startTimer();
  }

  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
    _resetTimer(); // Reset auto-scroll whenever user manually changes slide
  }

  void _prevPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // --- Page View Builder for slides ---
          PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) {
              final slide = _slides[index];
              return _buildSlide(context, slide);
            },
          ),

          // --- TOP BAR: Exact Original Skip Button ---
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: TextButton(
              onPressed: widget.onFinish,
              child: Text(
                'SKIP',
                style: theme.textTheme.labelLarge!.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
          ),

          // --- BOTTOM CONTROLS: Restored Precision Layout & Hardware-safe Padding ---
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + 24,
            left: 20,
            right: 20,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back Arrow Layout
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 300),
                  opacity: _currentPage > 0 ? 1.0 : 0.0,
                  child: IgnorePointer(
                    ignoring: _currentPage == 0,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                      onPressed: _prevPage,
                    ),
                  ),
                ),

                // Indicators Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_slides.length, (index) => _buildDot(index, colorScheme)),
                ),

                // Next Button or Finish Button Layout
                if (_currentPage < _slides.length - 1)
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white),
                    onPressed: () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOut,
                      );
                    },
                  )
                else
                  ElevatedButton(
                    onPressed: widget.onFinish,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: colorScheme.secondary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: Text(
                      'GET STARTED',
                      style: theme.textTheme.labelLarge!.copyWith(
                        color: colorScheme.onSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Restores original slide architecture with background images and heavy dark gradient masks
  Widget _buildSlide(BuildContext context, Map<String, String> slide) {
    return Stack(
      children: [
        // Fullscreen background image asset
        Positioned.fill(
          child: Image.asset(
            slide['image']!,
            fit: BoxFit.cover,
          ),
        ),

        // Deep rich ambient text contrast mask overlay
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.6),
                  Colors.black.withOpacity(0.85),
                ],
              ),
            ),
          ),
        ),

        // Content layout container
        Positioned(
          bottom: 140, // Perfectly floats slides safe from dot navigation systems
          left: 24,
          right: 24,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                slide['title']!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineMedium!.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 28,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                slide['description']!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 18,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Exact original indicator capsule logic builder
  Widget _buildDot(int index, ColorScheme colorScheme) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: _currentPage == index ? 24 : 8,
      decoration: BoxDecoration(
        color: _currentPage == index ? colorScheme.secondary : Colors.grey.shade700,
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

// ====================================================================
// --- Clean Logic Wrapper State ---
// ====================================================================
class OnboardingSliderWrapper extends StatelessWidget {
  const OnboardingSliderWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    return OnboardingSlider(
      onFinish: () async {
        // Safe asynchronous device preference registration via centralized logic system
        await AuthService().markOnboardingComplete();
        if (!context.mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const SplashScreen(hasCompletedOnboarding: true)),
        );
      },
    );
  }
}