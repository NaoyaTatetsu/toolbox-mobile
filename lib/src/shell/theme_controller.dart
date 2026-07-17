import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide theme mode. Defaults to dark; persisted across launches.
class ThemeController extends ChangeNotifier {
  static const _key = 'theme_mode';

  ThemeMode mode = ThemeMode.dark;

  bool get isDark => mode == ThemeMode.dark;

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    mode = prefs.getString(_key) == 'light' ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
  }

  Future<void> setDark(bool dark) async {
    mode = dark ? ThemeMode.dark : ThemeMode.light;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, dark ? 'dark' : 'light');
  }
}
