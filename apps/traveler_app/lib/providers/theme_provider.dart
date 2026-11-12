import 'package:flutter/material.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;

  ThemeMode get themeMode => _themeMode;

  String get appearanceString {
    switch (_themeMode) {
      case ThemeMode.light:
        return 'Light Theme Mode';
      case ThemeMode.dark:
        return 'Dark Theme Mode';
      case ThemeMode.system:
        return 'System Adaptive';
    }
  }

  void setThemeMode(ThemeMode mode) {
    if (_themeMode != mode) {
      _themeMode = mode;
      notifyListeners();
    }
  }

  void setAppearanceFromString(String themeStr) {
    if (themeStr == 'Light Theme Mode') {
      setThemeMode(ThemeMode.light);
    } else if (themeStr == 'Dark Theme Mode') {
      setThemeMode(ThemeMode.dark);
    } else {
      setThemeMode(ThemeMode.system);
    }
  }
}
