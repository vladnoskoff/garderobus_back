import 'package:flutter/widgets.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [
    Locale('ru'),
    Locale('en'),
  ];

  static const _localizedValues = <String, Map<String, String>>{
    'ru': {
      'app_title': 'Гардероб 26',
      'settings_title': 'Настройки',
      'settings_account': 'Аккаунт',
      'settings_home': 'Дом',
      'settings_places': 'Места',
      'settings_language': 'Язык',
      'settings_logout': 'Выход',
      'settings_general_section': 'Дом и места',
      'settings_security_privacy': 'Безопасность и конфиденциальность',
      'settings_account_full_name': 'ФИО',
      'settings_account_email': 'Почта',
      'settings_account_phone': 'Телефон',
      'settings_account_gender': 'Пол',
      'settings_security_password': 'Пароль и его смена',
      'settings_security_pin': 'PIN-код',
      'settings_security_photo_permissions':
          'Отображение разрешений на приложения Фото',
      'settings_security_camera_permissions':
          'Отображение разрешений на приложения Камера',
      'settings_theme_section': 'Выбор темы',
      'settings_theme_slider_hint': 'Выберите оформление приложения',
      'settings_theme_light': 'Светлая тема',
      'settings_theme_dark': 'Тёмная тема',
      'language_screen_title': 'Язык интерфейса',
      'language_select_prompt': 'Выберите язык приложения',
      'language_russian': 'Русский',
      'language_english': 'Английский',
      'language_apply': 'Применить',
      'language_cancel': 'Отмена',
      'language_updated': 'Язык обновлён',
      'language_update_failed': 'Не удалось обновить язык',
      'language_current_label': 'Текущий язык',
      'logout_confirmation': 'Вы уверены, что хотите выйти?',
      'logout_cancel': 'Отмена',
      'logout_confirm': 'Выйти',
    },
    'en': {
      'app_title': 'Wardrobe 26',
      'settings_title': 'Settings',
      'settings_account': 'Account',
      'settings_home': 'Home',
      'settings_places': 'Places',
      'settings_language': 'Language',
      'settings_logout': 'Log out',
      'settings_general_section': 'Home & places',
      'settings_security_privacy': 'Security & Privacy',
      'settings_account_full_name': 'Full name',
      'settings_account_email': 'Email',
      'settings_account_phone': 'Phone',
      'settings_account_gender': 'Gender',
      'settings_security_password': 'Password & updates',
      'settings_security_pin': 'PIN code',
      'settings_security_photo_permissions':
          'Display permissions for Photos app',
      'settings_security_camera_permissions':
          'Display permissions for Camera app',
      'settings_theme_section': 'Theme selection',
      'settings_theme_slider_hint': 'Choose the app appearance',
      'settings_theme_light': 'Light theme',
      'settings_theme_dark': 'Dark theme',
      'language_screen_title': 'Interface language',
      'language_select_prompt': 'Choose the app language',
      'language_russian': 'Russian',
      'language_english': 'English',
      'language_apply': 'Apply',
      'language_cancel': 'Cancel',
      'language_updated': 'Language updated',
      'language_update_failed': 'Failed to update language',
      'language_current_label': 'Current language',
      'logout_confirmation': 'Are you sure you want to log out?',
      'logout_cancel': 'Cancel',
      'logout_confirm': 'Log out',
    },
  };

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(localizations != null, 'No AppLocalizations found in context');
    return localizations!;
  }

  String getString(String key) {
    final languageCode = locale.languageCode;
    return _localizedValues[languageCode]?[key] ??
        _localizedValues['ru']?[key] ??
        key;
  }

  String get appTitle => getString('app_title');
  String get settingsTitle => getString('settings_title');
  String get settingsAccount => getString('settings_account');
  String get settingsHome => getString('settings_home');
  String get settingsPlaces => getString('settings_places');
  String get settingsLanguage => getString('settings_language');
  String get settingsLogout => getString('settings_logout');
  String get settingsGeneralSection => getString('settings_general_section');
  String get settingsSecurityPrivacy => getString('settings_security_privacy');
  String get settingsAccountFullName => getString('settings_account_full_name');
  String get settingsAccountEmail => getString('settings_account_email');
  String get settingsAccountPhone => getString('settings_account_phone');
  String get settingsAccountGender => getString('settings_account_gender');
  String get settingsSecurityPassword => getString('settings_security_password');
  String get settingsSecurityPin => getString('settings_security_pin');
  String get settingsSecurityPhotoPermissions =>
      getString('settings_security_photo_permissions');
  String get settingsSecurityCameraPermissions =>
      getString('settings_security_camera_permissions');
  String get settingsThemeSection => getString('settings_theme_section');
  String get settingsThemeSliderHint => getString('settings_theme_slider_hint');
  String get settingsThemeLight => getString('settings_theme_light');
  String get settingsThemeDark => getString('settings_theme_dark');
  String get languageScreenTitle => getString('language_screen_title');
  String get languageSelectPrompt => getString('language_select_prompt');
  String get languageApply => getString('language_apply');
  String get languageCancel => getString('language_cancel');
  String get languageUpdated => getString('language_updated');
  String get languageUpdateFailed => getString('language_update_failed');
  String get languageCurrentLabel => getString('language_current_label');
  String get logoutConfirmation => getString('logout_confirmation');
  String get logoutCancel => getString('logout_cancel');
  String get logoutConfirm => getString('logout_confirm');

  String languageName(String code) {
    switch (code) {
      case 'en':
        return getString('language_english');
      case 'ru':
      default:
        return getString('language_russian');
    }
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLocales
          .map((supported) => supported.languageCode)
          .contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}
