import 'package:shared_preferences/shared_preferences.dart';

/// Tracks whether the app is in foreground or background.
/// This is stored in SharedPreferences so it can be read from background isolates.
class AppLifecycleTracker {
  static const String _key = 'app_is_in_foreground';

  /// Mark the app as in foreground.
  static Future<void> setForeground() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, true);
  }

  /// Mark the app as in background.
  static Future<void> setBackground() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_key, false);
  }

  /// Check if the app is in foreground.
  /// Returns false if not set (assumes background).
  static Future<bool> isInForeground() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_key) ?? false;
  }
}
