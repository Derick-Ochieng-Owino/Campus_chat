import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/theme_manager.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themeKey = 'user_selected_theme';

  // Start with a default theme
  String _currentThemeName = 'Dark Hot Pink';
  bool _isInitialized = false;

  ThemeProvider() {
    _loadTheme();
  }

  /// Safe getter: always returns a valid ThemeData
  ThemeData get themeData {
    if (!_isInitialized) {
      // Return default theme until saved value loads
      return AppThemes.all['Dark Hot Pink']!;
    }
    return AppThemes.all[_currentThemeName] ?? AppThemes.all['Dark Hot Pink']!;
  }

  String get currentThemeName => _currentThemeName;
  List<String> get availableThemes => AppThemes.all.keys.toList();

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedThemeName = prefs.getString(_themeKey);
    if (savedThemeName != null && AppThemes.all.containsKey(savedThemeName)) {
      _currentThemeName = savedThemeName;
    }
    _isInitialized = true;
    notifyListeners(); // Notify widgets to rebuild with correct theme
  }

  Future<void> setTheme(String themeName) async {
    if (_currentThemeName == themeName || !AppThemes.all.containsKey(themeName)) return;

    _currentThemeName = themeName;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, themeName);
  }
}
