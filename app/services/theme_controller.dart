import 'package:flutter/material.dart';

import 'api_service.dart';

class ThemeNotifier extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  Future<void> initialize() async {
    final cachedTheme = await ApiService.getCachedThemePreference();
    if (cachedTheme != null) {
      _themeMode = _resolveThemeMode(cachedTheme);
    }

    final userId = await ApiService.getStoredUserId();
    if (userId != null) {
      final remoteTheme = await ApiService.fetchThemePreference(userId);
      if (remoteTheme != null) {
        _themeMode = _resolveThemeMode(remoteTheme);
        await ApiService.cacheThemePreference(remoteTheme);
      }
    }

    notifyListeners();
  }

  Future<void> toggleTheme() async {
    final nextMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await _persistTheme(nextMode);
  }

  Future<void> setTheme(ThemeMode mode) async {
    await _persistTheme(mode);
  }

  Future<void> refreshFromRemote() async {
    final userId = await ApiService.getStoredUserId();
    if (userId == null) {
      return;
    }

    try {
      final remoteTheme = await ApiService.fetchThemePreference(userId);
      if (remoteTheme == null) {
        return;
      }

      final resolved = _resolveThemeMode(remoteTheme);
      if (_themeMode != resolved) {
        _themeMode = resolved;
        notifyListeners();
      }
      await ApiService.cacheThemePreference(remoteTheme);
    } catch (_) {
      // Игнорируем ошибки синхронизации, чтобы не блокировать вход.
    }
  }

  Future<void> _persistTheme(ThemeMode mode) async {
    if (_themeMode == mode) {
      await ApiService.cacheThemePreference(_serializeThemeMode(mode));
      return;
    }

    final previous = _themeMode;
    _themeMode = mode;
    notifyListeners();

    final themeValue = _serializeThemeMode(mode);
    try {
      final userId = await ApiService.getStoredUserId();
      if (userId != null) {
        await ApiService.updateThemePreference(userId, themeValue);
      } else {
        await ApiService.cacheThemePreference(themeValue);
      }
    } catch (error) {
      _themeMode = previous;
      notifyListeners();
      throw error;
    }
  }

  String _serializeThemeMode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
      default:
        return 'system';
    }
  }

  ThemeMode _resolveThemeMode(String rawValue) {
    final normalized = rawValue.trim().toLowerCase();
    if ({
          'dark',
          'dark theme',
          'dark_mode',
          'темная',
          'тёмная',
          'темная тема',
          'тёмная тема',
          'night',
        }.contains(normalized)) {
      return ThemeMode.dark;
    }
    if (normalized.contains('system') ||
        normalized.contains('auto') ||
        normalized.contains('device') ||
        normalized.contains('систем') ||
        normalized.contains('авто') ||
        normalized.contains('умолч')) {
      return ThemeMode.system;
    }
    return ThemeMode.light;
  }
}

class ThemeScope extends InheritedNotifier<ThemeNotifier> {
  const ThemeScope({super.key, required ThemeNotifier notifier, required Widget child})
      : super(notifier: notifier, child: child);

  static ThemeNotifier of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<ThemeScope>();
    assert(scope != null, 'ThemeScope not found in context');
    return scope!.notifier!;
  }
}
