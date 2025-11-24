import 'package:shared_preferences/shared_preferences.dart';

class StateRestorationService {
  static const _mainTabKey = 'state_main_tab';
  static const _wardrobeCategoryKey = 'state_wardrobe_category';
  static const _wardrobeSeasonKey = 'state_wardrobe_season';

  static Future<void> persistMainTab(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_mainTabKey, index);
  }

  static Future<int?> restoreMainTab() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_mainTabKey);
  }

  static Future<void> persistWardrobeFilters({
    String? category,
    String? season,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (category != null) {
      await prefs.setString(_wardrobeCategoryKey, category);
    } else {
      await prefs.remove(_wardrobeCategoryKey);
    }
    if (season != null) {
      await prefs.setString(_wardrobeSeasonKey, season);
    } else {
      await prefs.remove(_wardrobeSeasonKey);
    }
  }

  static Future<(String?, String?)> restoreWardrobeFilters() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      prefs.getString(_wardrobeCategoryKey),
      prefs.getString(_wardrobeSeasonKey),
    );
  }
}
