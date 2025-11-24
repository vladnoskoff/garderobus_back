import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class DraftStorageService {
  static SharedPreferences? _prefs;

  static Future<SharedPreferences> _ensurePrefs() async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<void> saveDraft(String key, Map<String, String> data) async {
    final prefs = await _ensurePrefs();
    await prefs.setString(key, jsonEncode(data));
  }

  static Future<Map<String, String>> loadDraft(String key) async {
    final prefs = await _ensurePrefs();
    final stored = prefs.getString(key);
    if (stored == null || stored.isEmpty) {
      return {};
    }
    try {
      final json = jsonDecode(stored);
      if (json is Map) {
        return json.map((k, v) => MapEntry(k.toString(), v?.toString() ?? ''));
      }
    } catch (_) {
      // Ignore corrupted data and reset on next save.
    }
    return {};
  }

  static Future<void> clearDraft(String key) async {
    final prefs = await _ensurePrefs();
    await prefs.remove(key);
  }
}
