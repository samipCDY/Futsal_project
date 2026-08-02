import 'package:flutter/material.dart';

/// Holds the user's chosen app appearance (light/dark) and drives
/// MaterialApp.themeMode. No persistence yet — resets on app restart.
class ThemeProvider extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.light;

  ThemeMode get mode => _mode;
  bool get isDark => _mode == ThemeMode.dark;

  void setMode(ThemeMode mode) {
    if (_mode == mode) return;
    _mode = mode;
    notifyListeners();
  }
}
