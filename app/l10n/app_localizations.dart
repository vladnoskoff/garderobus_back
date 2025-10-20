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
      'settings_account_load_failed': 'Не удалось загрузить данные профиля',
      'settings_update_success': 'Данные обновлены',
      'settings_update_failed': 'Не удалось обновить данные',
      'settings_value_loading': 'Загрузка…',
      'settings_value_not_set': 'Не указано',
      'settings_edit_field_prefix': 'Изменить',
      'settings_cancel': 'Отмена',
      'settings_save': 'Сохранить',
      'settings_select_gender': 'Выберите пол',
      'settings_gender_male': 'Мужской',
      'settings_gender_female': 'Женский',
      'settings_gender_unspecified': 'Не указывать',
      'settings_password_change_title': 'Изменить пароль',
      'settings_password_new': 'Новый пароль',
      'settings_password_confirm': 'Подтвердите пароль',
      'settings_password_empty': 'Заполните оба поля',
      'settings_password_mismatch': 'Пароли не совпадают',
      'settings_password_updated': 'Пароль обновлён',
      'settings_password_error': 'Не удалось обновить пароль',
      'settings_pin_set': 'Установлен',
      'settings_pin_not_set': 'Не задан',
      'settings_pin_length_error': 'PIN-код должен содержать от 4 до 8 цифр',
      'settings_pin_digits_error': 'Используйте только цифры',
      'settings_pin_mismatch_error': 'PIN-коды не совпадают',
      'settings_pin_saved': 'PIN-код сохранён',
      'settings_pin_save_error': 'Не удалось сохранить PIN-код',
      'settings_pin_removed': 'PIN-код удалён',
      'settings_pin_remove_error': 'Не удалось удалить PIN-код',
      'settings_pin_manage_title': 'Управление PIN-кодом',
      'settings_pin_new': 'Новый PIN-код',
      'settings_pin_confirm': 'Подтвердите PIN-код',
      'settings_pin_save_action': 'Сохранить PIN',
      'settings_pin_remove_action': 'Удалить PIN',
      'settings_pin_remove_confirm_title': 'Удалить PIN-код',
      'settings_pin_remove_confirm_message':
          'Вы уверены, что хотите отключить PIN-код?',
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
      'settings_account_load_failed': 'Failed to load profile data',
      'settings_update_success': 'Details updated',
      'settings_update_failed': 'Failed to update details',
      'settings_value_loading': 'Loading…',
      'settings_value_not_set': 'Not set',
      'settings_edit_field_prefix': 'Edit',
      'settings_cancel': 'Cancel',
      'settings_save': 'Save',
      'settings_select_gender': 'Select gender',
      'settings_gender_male': 'Male',
      'settings_gender_female': 'Female',
      'settings_gender_unspecified': 'Prefer not to say',
      'settings_password_change_title': 'Change password',
      'settings_password_new': 'New password',
      'settings_password_confirm': 'Confirm password',
      'settings_password_empty': 'Please fill in both fields',
      'settings_password_mismatch': 'Passwords do not match',
      'settings_password_updated': 'Password updated',
      'settings_password_error': 'Failed to update password',
      'settings_pin_set': 'Enabled',
      'settings_pin_not_set': 'Not set',
      'settings_pin_length_error': 'PIN code must contain 4–8 digits',
      'settings_pin_digits_error': 'Digits only',
      'settings_pin_mismatch_error': 'PIN codes do not match',
      'settings_pin_saved': 'PIN code saved',
      'settings_pin_save_error': 'Failed to save PIN code',
      'settings_pin_removed': 'PIN code removed',
      'settings_pin_remove_error': 'Failed to remove PIN code',
      'settings_pin_manage_title': 'Manage PIN code',
      'settings_pin_new': 'New PIN code',
      'settings_pin_confirm': 'Confirm PIN code',
      'settings_pin_save_action': 'Save PIN',
      'settings_pin_remove_action': 'Remove PIN',
      'settings_pin_remove_confirm_title': 'Remove PIN code',
      'settings_pin_remove_confirm_message':
          'Are you sure you want to disable the PIN code?',
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
  String get settingsAccountLoadFailed => getString('settings_account_load_failed');
  String get settingsUpdateSuccess => getString('settings_update_success');
  String get settingsUpdateFailed => getString('settings_update_failed');
  String get settingsValueLoading => getString('settings_value_loading');
  String get settingsValueNotSet => getString('settings_value_not_set');
  String get settingsEditFieldPrefix => getString('settings_edit_field_prefix');
  String get settingsCancel => getString('settings_cancel');
  String get settingsSave => getString('settings_save');
  String get settingsSelectGender => getString('settings_select_gender');
  String get settingsGenderMale => getString('settings_gender_male');
  String get settingsGenderFemale => getString('settings_gender_female');
  String get settingsGenderUnspecified => getString('settings_gender_unspecified');
  String get settingsPasswordChangeTitle => getString('settings_password_change_title');
  String get settingsPasswordNew => getString('settings_password_new');
  String get settingsPasswordConfirm => getString('settings_password_confirm');
  String get settingsPasswordEmpty => getString('settings_password_empty');
  String get settingsPasswordMismatch => getString('settings_password_mismatch');
  String get settingsPasswordUpdated => getString('settings_password_updated');
  String get settingsPasswordError => getString('settings_password_error');
  String get settingsPinSet => getString('settings_pin_set');
  String get settingsPinNotSet => getString('settings_pin_not_set');
  String get settingsPinLengthError => getString('settings_pin_length_error');
  String get settingsPinDigitsError => getString('settings_pin_digits_error');
  String get settingsPinMismatchError => getString('settings_pin_mismatch_error');
  String get settingsPinSaved => getString('settings_pin_saved');
  String get settingsPinSaveError => getString('settings_pin_save_error');
  String get settingsPinRemoved => getString('settings_pin_removed');
  String get settingsPinRemoveError => getString('settings_pin_remove_error');
  String get settingsPinManageTitle => getString('settings_pin_manage_title');
  String get settingsPinNew => getString('settings_pin_new');
  String get settingsPinConfirm => getString('settings_pin_confirm');
  String get settingsPinSaveAction => getString('settings_pin_save_action');
  String get settingsPinRemoveAction => getString('settings_pin_remove_action');
  String get settingsPinRemoveConfirmTitle => getString('settings_pin_remove_confirm_title');
  String get settingsPinRemoveConfirmMessage =>
      getString('settings_pin_remove_confirm_message');
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

  String settingsGenderLabel(String value) {
    switch (value) {
      case 'male':
        return settingsGenderMale;
      case 'female':
        return settingsGenderFemale;
      case 'not_specified':
      default:
        return settingsGenderUnspecified;
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
