import 'package:flutter/material.dart';

class AppLogoLoadingWidget extends StatelessWidget {
  final double size;
  final bool isOverlay;

  const AppLogoLoadingWidget({
    super.key,
    this.size = 70,
    this.isOverlay = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    final surface = theme.colorScheme.surface;

    if (isOverlay) {
      // Using a full-screen transparent Scaffold blocks everything underneath
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: Stack(
          children: [
            ModalBarrier(
              dismissible: false,
              color: Colors.black.withOpacity(0.4), // Dimmed background overlay
            ),
            Center(child: _buildContent(primary, surface)),
          ],
        ),
      );
    }

    return Center(child: _buildContent(primary, surface));
  }

  Widget _buildContent(Color primary, Color surface) {
    final double indicatorSize = size * 1.25;

    return SizedBox(
      height: indicatorSize,
      width: indicatorSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: indicatorSize,
            width: indicatorSize,
            child: CircularProgressIndicator(
              strokeWidth: 5,
              valueColor: AlwaysStoppedAnimation(primary),
            ),
          ),
          Container(
            height: size,
            width: size,
            decoration: BoxDecoration(
              color: surface,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.hardEdge,
            child: Image.asset(
              'assets/images/logo.png',
              fit: BoxFit.cover,
            ),
          ),
        ],
      ),
    );
  }
}