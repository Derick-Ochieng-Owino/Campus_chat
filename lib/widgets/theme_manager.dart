// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// --- Base Colors ---
const Color kDarkBackground = Color(0xFF121212);
const Color kDarkSurface = Color(0xFF1E1E1E);
const Color kDarkForeground = Color(0xFFE0E0E0);

// --- Accent Colors ---
const Color kHotPink = Color(0xFFFF4081);
const Color kHotTeal = Color(0xFF00BCD4);
const Color kDeepPurple = Color(0xFF673AB7);
const Color kForestGreen = Color(0xFF1B5E20);

// --- New Theme Colors ---
const Color kAmberGold = Color(0xFFFFC107);
const Color kOceanBlue = Color(0xFF2196F3);
const Color kCrimsonRed = Color(0xFFDC143C);
const Color kEmeraldGreen = Color(0xFF2E8B57);
const Color kRoyalPurple = Color(0xFF9370DB);
const Color kSunsetOrange = Color(0xFFFF7F50);
const Color kSlateGray = Color(0xFF708090);
const Color kLavenderMist = Color(0xFFE6E6FA);
const Color kMintJulep = Color(0xFF98FB98);
const Color kCoralBlush = Color(0xFFFF7F7F);

const kOwlCyan = Color(0xFF2AB6F7);
const kOwlGold = Color(0xFFEBC66B);
const kDeepNavy = Color(0xFF040F1F);
const kSurfaceNavy = Color(0xFF0B1E33);
const kLightBackground = Color(0xFFF5F7FA);
const kLightSurface = Color(0xFFFFFFFF);

class AppThemes {
  static const String _prefsKey = 'selected_theme';

  // --- Theme creation ---
  static ThemeData _createTheme({
    required Color primary,
    required Color secondary,
    Brightness brightness = Brightness.dark,
    Color? background,
    Color? surface,
    String fontFamily = 'Roboto',
  }) {
    final Color finalBackground = background ??
        (brightness == Brightness.dark ? kDarkBackground : Colors.white);
    final Color finalSurface =
        surface ?? (brightness == Brightness.dark ? kDarkSurface : Colors.grey.shade50);
    final Color finalForeground =
    brightness == Brightness.dark ? kDarkForeground : Colors.black;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: primary,
      onPrimary: Colors.white,
      secondary: secondary,
      onSecondary: brightness == Brightness.dark ? Colors.black : Colors.white,
      error: Colors.red,
      onError: Colors.white,
      background: finalBackground,
      onBackground: finalForeground,
      surface: finalSurface,
      onSurface: finalForeground,
      primaryContainer: primary.withOpacity(0.2),
      secondaryContainer: secondary.withOpacity(0.2),
      onPrimaryContainer: primary,
      onSecondaryContainer: secondary,
    );

    final baseTheme = brightness == Brightness.dark ? ThemeData.dark() : ThemeData.light();
    final TextTheme textTheme = baseTheme.textTheme.copyWith(
      bodyMedium: TextStyle(color: finalForeground, fontFamily: fontFamily),
      bodySmall: TextStyle(color: finalForeground.withOpacity(0.7), fontFamily: fontFamily),
      titleLarge: TextStyle(
        color: finalForeground,
        fontFamily: fontFamily,
        fontWeight: FontWeight.bold,
        fontSize: 20,
      ),
      headlineSmall: TextStyle(
        color: finalForeground,
        fontFamily: fontFamily,
        fontWeight: FontWeight.w600,
        fontSize: 24,
      ),
    );

    return baseTheme.copyWith(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: finalBackground,
      cardColor: finalSurface,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: finalSurface,
        foregroundColor: finalForeground,
        titleTextStyle: textTheme.titleLarge,
        elevation: 4,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: secondary,
        foregroundColor: colorScheme.onSecondary,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: secondary,
        selectionColor: secondary.withOpacity(0.4),
        selectionHandleColor: secondary,
      ),
      inputDecorationTheme: InputDecorationTheme(
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: secondary, width: 2),
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: finalForeground.withOpacity(0.2), width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        hintStyle: textTheme.bodySmall,
        fillColor: finalSurface,
        filled: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      ),
      dividerTheme: DividerThemeData(
        color: brightness == Brightness.dark ? Colors.white12 : Colors.grey.shade300,
        thickness: 1,
      ),
      hoverColor: secondary.withOpacity(0.05),
      splashColor: secondary.withOpacity(0.1),
    );
  }

  // --- All Themes ---
  static final Map<String, ThemeData> all = {
    'Light Owl Day': _createTheme(
      primary: kOwlCyan,
      secondary: kOwlGold,
      background: kLightBackground,
      surface: kLightSurface,
      brightness: Brightness.light,
    ),
    'Dark Owl Night': _createTheme(
      primary: kOwlCyan,
      secondary: kOwlGold,
      background: kDeepNavy,
      surface: kSurfaceNavy,
      brightness: Brightness.dark,
    ),
    'Dark Hot Teal': _createTheme(
      primary: kHotTeal,
      secondary: kHotTeal,
      background: kDarkBackground,
      surface: kDarkSurface,
      brightness: Brightness.dark,
    ),
    'Dark Hot Pink': _createTheme(
      primary: kHotPink,
      secondary: kCoralBlush,
      background: kDarkBackground,
      surface: kDarkSurface,
      brightness: Brightness.dark,
    ),
    'Light Hot Pink': _createTheme(
      primary: kHotPink,
      secondary: kCoralBlush,
      background: Colors.white,
      surface: Colors.grey.shade50,
      brightness: Brightness.light,
    ),
    'Light Hot Teal': _createTheme(
      primary: kHotTeal,
      secondary: kSlateGray,
      background: Colors.white,
      surface: Colors.grey.shade50,
      brightness: Brightness.light,
    ),

    // 1. Amber & Ocean
    'Amber Ocean': _createTheme(
      primary: kAmberGold,
      secondary: kOceanBlue,
      background: kDarkBackground,
      surface: kDarkSurface,
      brightness: Brightness.dark,
    ),

    // 2. Crimson & Emerald
    'Crimson Emerald': _createTheme(
      primary: kCrimsonRed,
      secondary: kEmeraldGreen,
      background: kDarkBackground,
      surface: kDarkSurface,
      brightness: Brightness.dark,
    ),

    // 3. Royal & Mint
    'Royal Mint': _createTheme(
      primary: kRoyalPurple,
      secondary: kMintJulep,
      background: kDarkBackground,
      surface: kDarkSurface,
      brightness: Brightness.dark,
    ),

    // 4. Sunset & Slate
    'Sunset Slate': _createTheme(
      primary: kSunsetOrange,
      secondary: kSlateGray,
      background: kDarkBackground,
      surface: kDarkSurface,
      brightness: Brightness.dark,
    ),

    // 5. Lavender & Coral
    'Lavender Coral': _createTheme(
      primary: kLavenderMist,
      secondary: kCoralBlush,
      background: kDarkBackground,
      surface: kDarkSurface,
      brightness: Brightness.dark,
    ),

    // 6. Ocean & Amber (reversed)
    'Ocean Amber': _createTheme(
      primary: kOceanBlue,
      secondary: kAmberGold,
      background: kDarkBackground,
      surface: kDarkSurface,
      brightness: Brightness.dark,
    ),

    // 7. Emerald & Royal
    'Emerald Royal': _createTheme(
      primary: kEmeraldGreen,
      secondary: kRoyalPurple,
      background: kDarkBackground,
      surface: kDarkSurface,
      brightness: Brightness.dark,
    ),

    // 8. Mint & Crimson
    'Mint Crimson': _createTheme(
      primary: kMintJulep,
      secondary: kCrimsonRed,
      background: kDarkBackground,
      surface: kDarkSurface,
      brightness: Brightness.dark,
    ),

    // 9. Coral & Sunset
    'Coral Sunset': _createTheme(
      primary: kCoralBlush,
      secondary: kSunsetOrange,
      background: kDarkBackground,
      surface: kDarkSurface,
      brightness: Brightness.dark,
    ),

    // 10. Slate & Lavender
    'Slate Lavender': _createTheme(
      primary: kSlateGray,
      secondary: kLavenderMist,
      background: kDarkBackground,
      surface: kDarkSurface,
      brightness: Brightness.dark,
    ),
  };

  // --- Persisted Theme ---
  static Future<void> saveTheme(String themeName) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, themeName);
  }

  static Future<ThemeData> loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString(_prefsKey);
    if (themeName != null && all.containsKey(themeName)) {
      return all[themeName]!;
    }
    // Default theme
    return all.values.first;
  }
}