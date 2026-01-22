// lib/subscription.dart
import 'package:shared_preferences/shared_preferences.dart';

class Subscription {
  static SharedPreferences? _prefs;
  static const _kIsPlus = 'is_plus';

  static bool _cachedIsPlus = false;

  /// Call once in main() before runApp()
  static Future<void> init() async {
    _prefs ??= await SharedPreferences.getInstance();
    _cachedIsPlus = _prefs!.getBool(_kIsPlus) ?? false;
  }

  /// Optional: keep this if your main.dart calls it
  static Future<void> load() async {
    if (_prefs == null) {
      await init();
      return;
    }
    _cachedIsPlus = _prefs!.getBool(_kIsPlus) ?? false;
  }

  static bool isPlus() => _cachedIsPlus;

  static Future<void> setPlus(bool v) async {
    if (_prefs == null) await init();
    _cachedIsPlus = v;
    await _prefs!.setBool(_kIsPlus, v);
  }
}
