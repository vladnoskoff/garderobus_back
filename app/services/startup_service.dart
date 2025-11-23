import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'api_service.dart';

class HomeStartupData {
  const HomeStartupData({
    required this.locations,
    required this.selectedLocationId,
    required this.weather,
    required this.mannequins,
  });

  final List<dynamic> locations;
  final int? selectedLocationId;
  final Map<String, dynamic>? weather;
  final List<Map<String, dynamic>> mannequins;
}

class StartupService {
  static const _locationsCachePrefix = 'cached_locations_user_';

  static Future<List<dynamic>> _readCachedLocations(int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('$_locationsCachePrefix$userId');
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) return decoded;
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<void> cacheLocations(int userId, List<dynamic> locations) async {
    if (locations.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_locationsCachePrefix$userId', jsonEncode(locations));
  }

  static Future<List<dynamic>> getCachedLocations(int userId) =>
      _readCachedLocations(userId);

  static int? _parseLocationId(dynamic raw) {
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw);
    return int.tryParse(raw?.toString() ?? '');
  }

  static int? _resolveLocationId(
    List<dynamic> locations,
    int? preferredLocationId,
  ) {
    if (preferredLocationId != null &&
        locations.any((loc) => _parseLocationId(loc is Map ? loc['id'] : null) == preferredLocationId)) {
      return preferredLocationId;
    }
    for (final loc in locations.whereType<Map<String, dynamic>>()) {
      if (loc['latitude'] != null && loc['longitude'] != null) {
        return _parseLocationId(loc['id']);
      }
    }
    return preferredLocationId;
  }

  static int? resolveLocationId(List<dynamic> locations, int? preferredLocationId) =>
      _resolveLocationId(locations, preferredLocationId);

  static Future<HomeStartupData> loadHomeStartup({
    required int userId,
    int? preferredLocationId,
  }) async {
    final cachedLocations = await _readCachedLocations(userId);
    int? resolvedLocationId = _resolveLocationId(cachedLocations, preferredLocationId);

    final locations = await ApiService.getWardrobeLocations(userId);
    resolvedLocationId =
        _resolveLocationId(locations, resolvedLocationId) ?? _resolveLocationId(cachedLocations, null);
    await cacheLocations(userId, locations);

    final results = await Future.wait([
      ApiService.getWeatherByUserId(
        userId,
        locationId: resolvedLocationId,
      ),
      ApiService.getMannequinHistory(
        userId,
        locationId: resolvedLocationId,
        limit: 1,
      ),
    ]);

    final weather = results[0] as Map<String, dynamic>?;
    final mannequins = (results[1] as List?)
            ?.whereType<Map>()
            .map((value) => value.map((k, v) => MapEntry(k.toString(), v)))
            .toList(growable: false) ??
        const [];

    return HomeStartupData(
      locations: locations,
      selectedLocationId: resolvedLocationId,
      weather: weather,
      mannequins: mannequins,
    );
  }

  static Future<HomeStartupData> loadDashboardData({
    required int userId,
    int? locationId,
    List<dynamic>? knownLocations,
  }) async {
    final locations = knownLocations ?? await ApiService.getWardrobeLocations(userId);
    final resolvedLocationId = _resolveLocationId(locations, locationId);

    final results = await Future.wait([
      ApiService.getWeatherByUserId(
        userId,
        locationId: resolvedLocationId,
      ),
      ApiService.getMannequinHistory(
        userId,
        locationId: resolvedLocationId,
        limit: 1,
      ),
    ]);

    final weather = results[0] as Map<String, dynamic>?;
    final mannequins = (results[1] as List?)
            ?.whereType<Map>()
            .map((value) => value.map((k, v) => MapEntry(k.toString(), v)))
            .toList(growable: false) ??
        const [];

    return HomeStartupData(
      locations: locations,
      selectedLocationId: resolvedLocationId,
      weather: weather,
      mannequins: mannequins,
    );
  }
}
