import 'package:flutter/material.dart';

// Assuming you have a file that defines AppColors.
// If not, replace AppColors.primary with a standard color like Colors.blue.
// import 'package:campus_app/core/constants/colors.dart';
final Color AppColorsPrimary = Colors.blue.shade700; // Placeholder

class AppLogoLoadingWidget extends StatelessWidget {
  final double size;
  final bool isOverlay; // New property to determine if it should block the screen

  const AppLogoLoadingWidget({
    super.key,
    this.size = 60, // Increased size for the logo
    this.isOverlay = false, // Default to false for inline use
  });

  @override
  Widget build(BuildContext context) {
    // If isOverlay is true, we wrap the loading animation with a ModalBarrier
    // to prevent interaction with the widgets underneath.
    if (isOverlay) {
      return Stack(
        children: [
          const ModalBarrier(
            dismissible: false,
            color: Colors.black45,
          ),

          Center(child: _buildLoadingContent()),
        ],
      );
    }

    // If isOverlay is false, return only the centered content (for inline use)
    return Center(child: _buildLoadingContent());
  }

  // Helper method to build the common loading graphic (Logo + Indicator)
  Widget _buildLoadingContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 1. App Logo/Icon
        Container(
          height: size,
          width: size,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(size / 4),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
              ),
            ],
          ),
          child: Image.asset('assets/images/logo.png', width: size),
        ),
        const SizedBox(height: 16),

        SizedBox(
          width: size * 0.4,
          height: size * 0.4,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(AppColorsPrimary),
          ),
        ),
      ],
    );
  }
}