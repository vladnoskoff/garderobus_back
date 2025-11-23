import 'package:hive_flutter/hive_flutter.dart';

import '../models/outfit.dart';
import 'clothes.dart';

class LocalStorageService {
  static const _clothesBox = 'clothes_box';
  static const _outfitsBox = 'outfits_box';
  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;
    try {
      if (!Hive.isBoxOpen(_clothesBox) && !Hive.isBoxOpen(_outfitsBox)) {
        await Hive.initFlutter();
      }
    } catch (_) {
      // Ignore if Hive has been initialised in tests with a manual path.
    }
    _initialized = true;
    if (!Hive.isBoxOpen(_clothesBox)) {
      await Hive.openBox<Map>(_clothesBox);
    }
    if (!Hive.isBoxOpen(_outfitsBox)) {
      await Hive.openBox<Map>(_outfitsBox);
    }
  }

  static Future<void> cacheClothes(int userId, List<Clothes> clothes) async {
    final box = Hive.box<Map>(_clothesBox);
    final key = _userKey(userId);
    await box.put(key, {
      'items': clothes.map((c) => c.toJson()).toList(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<void> upsertClothes(int userId, Clothes clothes) async {
    final current = await getCachedClothes(userId);
    final updated = [
      for (final item in current)
        if (item.id == clothes.id)
          clothes
        else
          item,
    ];
    if (!updated.any((element) => element.id == clothes.id)) {
      updated.add(clothes);
    }
    await cacheClothes(userId, updated);
  }

  static Future<List<Clothes>> getCachedClothes(int userId) async {
    final box = Hive.box<Map>(_clothesBox);
    final data = box.get(_userKey(userId));
    if (data is Map && data['items'] is List) {
      return (data['items'] as List)
          .whereType<Map>()
          .map((item) => Clothes.fromJson(item.cast<String, dynamic>()))
          .toList();
    }
    return [];
  }

  static Future<void> cacheOutfits(int userId, List<Outfit> outfits) async {
    final box = Hive.box<Map>(_outfitsBox);
    await box.put(_userKey(userId), {
      'items': outfits.map((o) => o.toJson()).toList(),
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  static Future<List<Outfit>> getCachedOutfits(int userId) async {
    final box = Hive.box<Map>(_outfitsBox);
    final data = box.get(_userKey(userId));
    if (data is Map && data['items'] is List) {
      return (data['items'] as List)
          .whereType<Map>()
          .map((item) => Outfit.fromJson(item.cast<String, dynamic>()))
          .toList();
    }
    return [];
  }

  static String _userKey(int userId) => 'user_$userId';
}
