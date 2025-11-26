// lib/core/themes/theme_manager.dart
import 'package:flutter/material.dart';

// --- Base Colors for Techy Vibe ---
const Color kDarkBackground = Color(0xFF121212); // Deep charcoal/black
const Color kDarkSurface = Color(0xFF1E1E1E);    // Slightly lighter surface
const Color kDarkForeground = Color(0xFFE0E0E0); // Light grey text

// --- Accent Colors ---
const Color kHotPink = Color(0xFFFF4081); // Bright, vibrant pink
const Color kHotTeal = Color(0xFF00BCD4); // Cyan/Teal for tech
const Color kDeepPurple = Color(0xFF673AB7); // Primary color replacement

// ------------------------------------------------------------------
// Theme Data Maps
// ------------------------------------------------------------------

class AppThemes {
  static final Map<String, ThemeData> all = {
    'Dark/Hot Pink': _createTheme(
      primary: kDeepPurple, // Consistent primary accent
      secondary: kHotPink,
      background: kDarkBackground,
      surface: kDarkSurface,
      brightness: Brightness.dark,
    ),
    'Dark/Hot Teal': _createTheme(
      primary: kDeepPurple, // Consistent primary accent
      secondary: kHotTeal,
      background: kDarkBackground,
      surface: kDarkSurface,
      brightness: Brightness.dark,
    ),
    'Light/Primary': _createTheme(
      primary: Colors.blue,
      secondary: Colors.teal,
      background: Colors.white,
      surface: Colors.grey.shade50,
      brightness: Brightness.light,
    ),
  };

  static ThemeData _createTheme({
    required Color primary,
    required Color secondary,
    required Color background,
    required Color surface,
    required Brightness brightness,
  }) {
    final isDark = brightness == Brightness.dark;

    // Base setup
    final baseTheme = isDark ? ThemeData.dark() : ThemeData.light();

    return baseTheme.copyWith(
      // Primary colors
      colorScheme: ColorScheme(
        brightness: brightness,
        primary: primary,
        onPrimary: Colors.white,
        secondary: secondary,
        onSecondary: Colors.black,
        error: Colors.red,
        onError: Colors.white,
        background: background,
        onBackground: isDark ? kDarkForeground : Colors.black,
        surface: surface,
        onSurface: isDark ? kDarkForeground : Colors.black,
      ),
      primaryColor: primary,

      // Scaffolding and Cards
      scaffoldBackgroundColor: background,
      cardColor: surface,

      // AppBar Styling (Techy, slightly elevated)
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: isDark ? kDarkForeground : primary,
        elevation: 4,
        titleTextStyle: TextStyle(
            color: isDark ? kDarkForeground : Colors.black,
            fontSize: 20,
            fontWeight: FontWeight.bold
        ),
      ),

      // Button Styling (Using secondary accent)
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: secondary,
        foregroundColor: isDark ? Colors.black : Colors.white,
      ),

      // Text Selection (High contrast)
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: secondary,
        selectionColor: secondary.withOpacity(0.4),
        selectionHandleColor: secondary,
      ),

      // Text Styling
      textTheme: baseTheme.textTheme.apply(
        bodyColor: isDark ? kDarkForeground : Colors.black87,
        displayColor: isDark ? kDarkForeground : Colors.black,
      ),

      // Divider Styling (Subtle in dark mode)
      dividerTheme: DividerThemeData(
        color: isDark ? Colors.white12 : Colors.grey.shade300,
        thickness: 1,
      ),
    );
  }
}