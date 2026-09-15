import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// A cache failure must never prevent showing a successful server response.
class OfflineCache {
  late final SharedPreferencesAsync _preferences = SharedPreferencesAsync();

  Future<List<Map<String, dynamic>>?> read(String key) async {
    try {
      final raw = await _preferences.getString(key);
      if (raw == null) return null;
      return (jsonDecode(raw) as List)
          .map((value) => Map<String, dynamic>.from(value as Map))
          .toList();
    } catch (_) {
      return null;
    }
  }

  Future<void> write(String key, List<Map<String, dynamic>> rows) async {
    try {
      await _preferences.setString(key, jsonEncode(rows));
    } catch (_) {
      // Displaying data is independent of device storage availability.
    }
  }
}
