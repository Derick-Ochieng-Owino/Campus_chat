import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/constants/theme_manager.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themeKey = 'user_selected_theme';
  String _currentThemeName = 'Dark/Hot Pink'; // Default theme name

  ThemeProvider() {
    _loadTheme();
  }

  ThemeData get themeData => AppThemes.all[_currentThemeName] ?? AppThemes.all['Dark/Hot Pink']!;
  String get currentThemeName => _currentThemeName;
  List<String> get availableThemes => AppThemes.all.keys.toList();

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final savedThemeName = prefs.getString(_themeKey);
    if (savedThemeName != null && AppThemes.all.containsKey(savedThemeName)) {
      _currentThemeName = savedThemeName;
      notifyListeners();
    }
  }

  Future<void> setTheme(String themeName) async {
    if (_currentThemeName == themeName || !AppThemes.all.containsKey(themeName)) return;

    _currentThemeName = themeName;
    notifyListeners();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, themeName);
  }
}