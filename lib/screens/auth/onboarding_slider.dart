// lib/screens/onboarding/onboarding_slider.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingSlider extends StatefulWidget {
  // Callback when the user finishes or skips the onboarding
  final VoidCallback onFinish;

  const OnboardingSlider({super.key, required this.onFinish});

  @override
  State<OnboardingSlider> createState() => _OnboardingSliderState();
}

class _OnboardingSliderState extends State<OnboardingSlider> {
  final PageController _pageController = PageController();
  Timer? _timer;
  int _currentPage = 0;

  // Define the slider content
  final List<Map<String, String>> _slides = [
    {
      'title': 'Welcome to Alma Mater!',
      'description': 'Your central platform for course notes, groups, and campus communication.',
      'image': 'assets/images/onboarding_1.jpg', // Placeholder image path
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
      'description': 'Your All In One School Solution',
      'image': 'assets/images/onboarding_5.jpg',
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

  // --- Timer Management ---
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_currentPage < _slides.length - 1) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOut,
        );
      } else {
        // Automatically finish after the last slide
        _timer?.cancel();
        _markOnboardingComplete();
      }
    });
  }

  void _resetTimer() {
    _timer?.cancel();
    _startTimer();
  }

  // --- Finish Logic ---
  Future<void> _markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('has_completed_onboarding', true);
    widget.onFinish();
  }

  // --- Page Navigation ---
  void _onPageChanged(int index) {
    setState(() {
      _currentPage = index;
    });
    // Reset timer whenever user interacts
    _resetTimer();
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

    // Opaque Overlay Container (Blocks taps underneath)
    return Container(
      color: Colors.black.withOpacity(0.95), // Highly opaque dark overlay
      child: SafeArea(
        child: Stack(
          children: [
            // --- Page View ---
            PageView.builder(
              controller: _pageController,
              itemCount: _slides.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final slide = _slides[index];
                return _buildSlide(context, slide, colorScheme);
              },
            ),

            // --- TOP BAR: Skip Button ---
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextButton(
                  onPressed: _markOnboardingComplete,
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
            ),

            // --- BOTTOM NAVIGATION & INDICATORS ---
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 40.0, left: 20, right: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Back Arrow
                    AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: _currentPage > 0 ? 1.0 : 0.0,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
                        onPressed: _prevPage,
                      ),
                    ),

                    // Indicators
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_slides.length, (index) => _buildDot(index, colorScheme)),
                    ),

                    // Next Button or Finish Button
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
                        onPressed: _markOnboardingComplete,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.secondary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        ),
                        child: Text('GET STARTED', style: theme.textTheme.labelLarge!.copyWith(color: colorScheme.onSecondary)),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSlide(BuildContext context, Map<String, String> slide, ColorScheme colorScheme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Image Placeholder (Ensure you have assets/images/onboarding_x.png)
        SizedBox(
          height: MediaQuery.of(context).size.height * 0.4,
          child: Image.asset(
            slide['image']!,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) => Icon(Icons.school, size: 150, color: colorScheme.primary),
          ),
        ),
        const SizedBox(height: 40),

        // Title
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Text(
            slide['title']!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineMedium!.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Description
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: Text(
            slide['description']!,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
              color: Colors.white70,
              fontSize: 16,
            ),
          ),
        ),
      ],
    );
  }

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