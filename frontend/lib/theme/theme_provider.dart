import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  late SharedPreferences _prefs;
  ThemeMode _themeMode = ThemeMode.light;
  bool _isInitialized = false;

  ThemeMode get themeMode => _themeMode;
  bool get isDark {
    if (_themeMode == ThemeMode.system) {
      return WidgetsBinding.instance.platformDispatcher.platformBrightness == Brightness.dark;
    }
    return _themeMode == ThemeMode.dark;
  }
  bool get isInitialized => _isInitialized;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();

    // Carregar preferência salva
    final savedTheme = _prefs.getString('theme_preference');
    if (savedTheme != null) {
      _setThemeFromString(savedTheme);
    } else {
      // Usar preferência do dispositivo
      _themeMode = ThemeMode.system;
    }

    _isInitialized = true;
    notifyListeners();
  }

  void _setThemeFromString(String theme) {
    switch (theme) {
      case 'light':
        _themeMode = ThemeMode.light;
        break;
      case 'dark':
        _themeMode = ThemeMode.dark;
        break;
      case 'system':
        _themeMode = ThemeMode.system;
        break;
      default:
        _themeMode = ThemeMode.system;
    }
  }

  Future<void> toggleTheme() async {
    final currentIsDark = isDark;
    _themeMode = currentIsDark ? ThemeMode.light : ThemeMode.dark;
    await _saveThemePreference();
    notifyListeners();
  }

  Future<void> setTheme(ThemeMode mode) async {
    _themeMode = mode;
    await _saveThemePreference();
    notifyListeners();
  }

  Future<void> _saveThemePreference() async {
    String themeString;
    switch (_themeMode) {
      case ThemeMode.light:
        themeString = 'light';
        break;
      case ThemeMode.dark:
        themeString = 'dark';
        break;
      case ThemeMode.system:
        themeString = 'system';
        break;
    }
    await _prefs.setString('theme_preference', themeString);
  }
}
