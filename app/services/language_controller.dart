import 'package:flutter/material.dart';

import 'api_service.dart';

class LanguageNotifier extends ChangeNotifier {
  static const List<Locale> supportedLocales = [
    Locale('ru'),
    Locale('en'),
  ];

  Locale _locale = const Locale('ru');

  Locale get locale => _locale;

  Future<void> initialize() async {
    final cachedLanguage = await ApiService.getCachedLanguagePreference();
    if (_isSupported(cachedLanguage)) {
      _locale = Locale(cachedLanguage!);
    }

    final userId = await ApiService.getStoredUserId();
    if (userId != null) {
      final remoteLanguage = await ApiService.fetchLanguagePreference(userId);
      if (_isSupported(remoteLanguage)) {
        _locale = Locale(remoteLanguage!);
        await ApiService.cacheLanguagePreference(remoteLanguage);
      }
    }

    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) {
      await ApiService.cacheLanguagePreference(locale.languageCode);
      return;
    }

    final previous = _locale;
    _locale = locale;
    notifyListeners();

    try {
      final userId = await ApiService.getStoredUserId();
      if (userId != null) {
        await ApiService.updateLanguagePreference(userId, locale.languageCode);
      } else {
        await ApiService.cacheLanguagePreference(locale.languageCode);
      }
    } catch (error) {
      _locale = previous;
      notifyListeners();
      rethrow;
    }
  }

  Future<void> refreshFromRemote() async {
    final userId = await ApiService.getStoredUserId();
    if (userId == null) {
      return;
    }

    try {
      final remoteLanguage = await ApiService.fetchLanguagePreference(userId);
      if (!_isSupported(remoteLanguage)) {
        return;
      }

      final resolvedLocale = Locale(remoteLanguage!);
      if (_locale != resolvedLocale) {
        _locale = resolvedLocale;
        notifyListeners();
      }
      await ApiService.cacheLanguagePreference(remoteLanguage);
    } catch (_) {
      // Игнорируем ошибки синхронизации, чтобы не блокировать вход.
    }
  }

  static Locale get defaultLocale => const Locale('ru');

  bool _isSupported(String? languageCode) {
    if (languageCode == null || languageCode.trim().isEmpty) {
      return false;
    }
    return supportedLocales
        .map((locale) => locale.languageCode)
        .contains(languageCode.toLowerCase());
  }
}

class LanguageScope extends InheritedNotifier<LanguageNotifier> {
  const LanguageScope({super.key, required LanguageNotifier notifier, required Widget child})
      : super(notifier: notifier, child: child);

  static LanguageNotifier of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<LanguageScope>();
    assert(scope != null, 'LanguageScope not found in context');
    return scope!.notifier!;
  }
}
