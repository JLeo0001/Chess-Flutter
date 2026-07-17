import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 日夜模式管理 — 1:1 移植自 DayNightManager.java
class ThemeProvider extends ChangeNotifier {
  static const String _prefsKey = 'theme_mode';
  static const String _prefsFollow = 'follow_system';

  ThemeMode _themeMode = ThemeMode.system;
  bool _followSystem = true;
  bool _isDarkOverride = false;

  ThemeMode get themeMode => _themeMode;
  bool get isDarkMode {
    if (_followSystem) {
      final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      return brightness == Brightness.dark;
    }
    return _isDarkOverride;
  }

  bool get followSystem => _followSystem;
  bool get isDarkOverride => _isDarkOverride;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    _followSystem = prefs.getBool(_prefsFollow) ?? true;
    _isDarkOverride = prefs.getBool(_prefsKey) ?? false;
    _themeMode = _followSystem
        ? ThemeMode.system
        : (_isDarkOverride ? ThemeMode.dark : ThemeMode.light);
    notifyListeners();
  }

  Future<void> setFollowSystem(bool value) async {
    _followSystem = value;
    if (value) {
      _themeMode = ThemeMode.system;
    } else {
      final brightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      _isDarkOverride = brightness == Brightness.dark;
      _themeMode = _isDarkOverride ? ThemeMode.dark : ThemeMode.light;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsFollow, value);
    await prefs.setBool(_prefsKey, _isDarkOverride);
    notifyListeners();
  }

  Future<void> toggleManual() async {
    _followSystem = false;
    _isDarkOverride = !_isDarkOverride;
    _themeMode = _isDarkOverride ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsFollow, false);
    await prefs.setBool(_prefsKey, _isDarkOverride);
    notifyListeners();
  }

  Future<void> setMode(ThemeMode mode) async {
    _themeMode = mode;
    _followSystem = mode == ThemeMode.system;
    if (!_followSystem) _isDarkOverride = mode == ThemeMode.dark;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsFollow, _followSystem);
    await prefs.setBool(_prefsKey, _isDarkOverride);
    notifyListeners();
  }
}
