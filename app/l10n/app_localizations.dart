import 'dart:collection';

import 'package:flutter/widgets.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [
    Locale('ru'),
  ];

  static const _localizedValues = <String, Map<String, String>>{
    'ru': {
      'app_title': 'Гардероб 26',
      'home_refresh_mannequin': 'Обновить манекен',
      'nav_home': 'Главная',
      'nav_wardrobe': 'Гардероб',
      'nav_settings': 'Настройки',
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
      'settings_theme_section': 'Выбор темы',
      'settings_theme_light': 'Светлая тема',
      'settings_theme_dark': 'Тёмная тема',
      'settings_theme_system': 'Системная',
      'settings_manage_action': 'Настроить',
      'settings_home_manage_description':
          'Просмотрите и обновите информацию о вашем доме.',
      'settings_places_manage_description':
          'Управляйте сохранёнными местами и адресами.',
      'settings_account_load_failed': 'Не удалось загрузить данные профиля',
      'settings_update_success': 'Данные обновлены',
      'settings_update_failed': 'Не удалось обновить данные',
      'settings_update_queued': 'Изменения сохранены офлайн',
      'settings_update_queued_hint': 'в ожидании синхронизации',
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
      'form_field_default': 'поле',
      'form_required': 'Заполните {field}',
      'form_email_required': 'Укажите email',
      'form_email_invalid': 'Проверьте формат email',
      'form_phone_required': 'Укажите телефон',
      'form_phone_invalid': 'Введите не менее 10 цифр',
      'form_password_required': 'Введите пароль',
      'form_password_short': 'Пароль должен быть длиннее 8 символов',
      'form_password_mismatch': 'Пароли не совпадают',
      'form_fix_errors': 'Проверьте выделенные поля',
      'form_unexpected_error': 'Что-то пошло не так. Попробуйте ещё раз.',
      'form_draft_saved': 'Черновик сохранён',
      'form_draft_restored': 'Черновик восстановлен',
      'auth_login_title': 'Добро пожаловать!',
      'auth_login_action': 'Войти',
      'auth_register_prompt': 'Нет аккаунта? Зарегистрироваться',
      'auth_register_action': 'Создать аккаунт',
      'auth_register_title': 'Регистрация',
      'auth_login_has_account': 'Есть аккаунт',
      'auth_email_label': 'Email',
      'auth_password_label': 'Пароль',
      'auth_confirm_password_label': 'Повторите пароль',
      'auth_name_label': 'Имя',
      'auth_gender_label': 'Пол',
      'auth_select_gender_hint': 'Выберите пол',
      'auth_login_error': 'Неверный логин или пароль.',
      'auth_passwords_match': 'Пароли совпадают',
      'auth_passwords_mismatch': 'Пароли не совпадают',
      'auth_location_error': 'Не удалось создать стартовую локацию: {error}',
      'auth_pin_length_error': 'Введите PIN-код из 4–8 цифр.',
      'auth_pin_verify_error': 'Не удалось проверить PIN-код: {error}',
      'auth_pin_verify_generic': 'Не удалось проверить PIN-код. Попробуйте позже.',
      'auth_pin_prompt': 'Введите PIN-код',
      'auth_pin_hint': 'Для продолжения требуется подтверждение безопасности.',
      'auth_pin_label': 'PIN-код',
      'auth_unlock_action': 'Разблокировать',
      'auth_exit_action': 'Выйти',
      'auth_pin_invalid': 'Неверный PIN-код. Попробуйте ещё раз.',
      'auth_biometric_reason': 'Подтвердите личность для доступа к гардеробу',
      'auth_biometric_failed':
          'Биометрическая аутентификация не выполнена. Введите PIN-код.',
      'support_section_title': 'Помощь и поддержка',
      'support_contact_action': 'Написать в поддержку',
      'support_contact_settings_hint':
          'Опишите проблему — мы автоматически добавим модель устройства и версию системы.',
      'support_contact_login_hint':
          'Не получается войти? Напишите нам, и мы поможем.',
      'support_email_subject': 'Запрос в поддержку: {source}',
      'support_email_body':
          'Опишите проблему или вопрос ниже.\n\n---\nМодель устройства: {model}\nВерсия системы: {osVersion}',
      'support_email_source_settings': 'Настройки',
      'support_email_source_login': 'Экран входа',
      'support_email_launch_error':
          'Не удалось открыть почтовое приложение. Проверьте настройки почты.',
      'location_picker_title': 'Выбор координат',
      'location_picker_selected': 'Выбранные координаты',
      'location_picker_hint': 'Нажмите на карту, чтобы изменить точку.',
      'location_picker_confirm': 'Сохранить координаты',
      'home_mannequin_preview': 'Просмотр манекена',
      'home_mannequin_status_preparing': 'Готовим образ...',
      'home_mannequin_status_collecting': 'Подбираем вещи...',
      'home_mannequin_status_queue': 'Задача в очереди',
      'home_mannequin_status_rendering': 'Генерируем изображение',
      'home_mannequin_status_ready': 'Готово',
      'home_mannequin_status_error': 'Ошибка генерации',
      'home_mannequins_update_failed': 'Не удалось обновить данные',
      'home_mannequin_history_load_failed':
          'Не удалось загрузить историю манекенов',
      'home_mannequin_generation_starting': 'Запускаем генерацию...',
      'home_mannequin_create_failed':
          'Не удалось создать манекен. Попробуйте снова.',
      'home_mannequin_error_label': 'Ошибка',
      'home_recommendation_default':
          'Следите за погодой и подбирайте одежду по ощущениям.',
      'home_recommendation_extreme_cold':
          'Экстремальный холод — утепляйтесь по максимуму.',
      'home_recommendation_very_cold':
          'Очень холодно, одевайтесь теплее и добавьте аксессуары для защиты от мороза.',
      'home_recommendation_cool': 'Прохладно — наденьте тёплый верхний слой.',
      'home_recommendation_light_cool':
          'Лёгкая прохлада, возьмите ветровку или кардиган.',
      'home_recommendation_comfortable':
          'Комфортно, можно выбрать лёгкий повседневный образ.',
      'home_recommendation_hot':
          'Жарко, выбирайте лёгкие ткани и дышащую одежду.',
      'home_recommendation_rain_add': 'Возьмите зонт или дождевик.',
      'home_recommendation_snow_add':
          'Не забудьте тёплую верхнюю одежду и обувь для снега.',
      'home_recommendation_wind_add':
          'На улице ветрено — выбирайте закрытые верхние слои.',
      'home_mannequin_title': 'Манекен',
      'home_item_placeholder_name': 'Вещь',
      'home_outfit_details_pending': 'Состав образа уточняется...',
      'home_item_missing_for_preview':
          'Не удалось определить вещь для просмотра.',
      'home_item_open_error': 'Не удалось открыть вещь: {error}',
      'home_sync_banner_syncing': 'Идет синхронизация локальных данных',
      'home_sync_banner_offline':
          'Вы офлайн — изменения будут отправлены при появлении связи',
      'home_settings_tooltip': 'Настройки',
      'home_use_personal_coords': 'Использовать личные координаты',
      'home_location_untitled': 'Без названия',
      'home_location_missing_coords': ' (нет координат)',
      'home_places_title': 'Дом и места',
      'home_places_description':
          'Выберите гардероб для погоды и рекомендаций.',
      'home_places_manage': 'Управлять',
      'home_places_add_address_hint':
          'Добавьте адрес в настройках, чтобы выбрать конкретный гардероб.',
      'home_weather_now': 'Погода сейчас',
      'home_weather_humidity': 'Влажность',
      'home_weather_pressure': 'Давление',
      'home_weather_pressure_value': '{value} мм рт. ст.',
      'home_weather_wind': 'Ветер',
      'home_weather_wind_value': '{value} м/с',
      'home_weather_forecast_hint':
          'Нажмите, чтобы посмотреть подробный прогноз и погоду на неделю',
      'home_weather_forecast_title': 'Прогноз погоды',
      'common_close': 'Закрыть',
      'home_feels_like': 'Ощущается как {value}°C',
      'home_week_forecast_title': 'Прогноз на неделю',
      'home_outfit_of_day': 'Образ дня',
      'home_outfit_refresh_hint':
          'Нажмите «Обновить», чтобы ИИ подобрал образ под вашу погоду и гардероб.',
      'home_outfit_collecting_items': 'Подбираем вещи...',
      'home_outfit_queued': 'Задача в очереди',
      'home_outfit_rendering': 'Генерируем изображение',
      'home_outfit_ready': 'Готово',
      'home_outfit_error': 'Ошибка генерации',
      'home_outfit_preparing': 'Готовим образ...',
      'wardrobe_user_not_found': 'Пользователь не найден',
      'wardrobe_invalid_user_id': 'Некорректный идентификатор пользователя',
      'wardrobe_locations_load_failed': 'Не удалось загрузить локации: {error}',
      'wardrobe_syncing_queue': 'Синхронизация очереди действий',
      'wardrobe_offline_hint':
          'Офлайн-режим: новые изменения помечены как ожидающие',
      'wardrobe_clothes_load_failed': 'Ошибка при загрузке одежды: {error}',
      'wardrobe_filters_title': 'Фильтры гардероба',
      'wardrobe_filters_subtitle': 'Сужайте подборку по категориям и сезонам.',
      'wardrobe_filter_category_label': 'Категория',
      'wardrobe_filter_category_all': 'Все категории',
      'wardrobe_filter_season_label': 'Сезон',
      'wardrobe_filter_season_all': 'Все сезоны',
      'wardrobe_filters_empty_hint':
          'Фильтры появятся, когда вы добавите вещи с категориями и сезонами.',
      'wardrobe_filters_reset': 'Сбросить',
      'wardrobe_filters_apply': 'Применить',
      'wardrobe_delete_title': 'Удалить вещь',
      'wardrobe_delete_confirmation':
          'Вы уверены, что хотите удалить эту вещь?',
      'common_cancel': 'Отмена',
      'wardrobe_delete_action': 'Удалить',
      'wardrobe_title': 'Гардероб',
      'wardrobe_total_items': 'Всего вещей: {count}',
      'wardrobe_empty_call_to_action': 'Добавьте первую вещь в гардероб',
      'wardrobe_history_tooltip': 'История нарядов',
      'wardrobe_location_label': 'Локация гардероба',
      'wardrobe_location_all': 'Все локации',
      'wardrobe_add_item': 'Добавить вещь',
      'wardrobe_filters_chip_active': 'Фильтры • {count}',
      'wardrobe_filters_chip_label': 'Фильтры',
      'wardrobe_filter_category_chip': 'Категория: {value}',
      'wardrobe_filter_season_chip': 'Сезон: {value}',
      'wardrobe_active_filters': 'Активные фильтры',
      'wardrobe_reset_filters': 'Сбросить фильтры',
      'wardrobe_delete_tooltip': 'Удалить',
      'wardrobe_location_fallback': 'Локация #{id}',
      'wardrobe_header_title': 'Гардероб {count}',
      'wardrobe_empty_state_message':
          'В этом гардеробе пока нет вещей. Добавьте новые элементы, чтобы увидеть их здесь.',
    },
    'en': {
      'app_title': 'Wardrobe 26',
      'home_refresh_mannequin': 'Refresh mannequin',
      'nav_home': 'Home',
      'nav_wardrobe': 'Wardrobe',
      'nav_settings': 'Settings',
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
      'settings_theme_section': 'Theme selection',
      'settings_theme_light': 'Light theme',
      'settings_theme_dark': 'Dark theme',
      'settings_theme_system': 'System default',
      'settings_manage_action': 'Manage',
      'settings_home_manage_description':
          'Review and update your home configuration.',
      'settings_places_manage_description':
          'Manage your saved places and addresses.',
      'settings_account_load_failed': 'Failed to load profile data',
      'settings_update_success': 'Details updated',
      'settings_update_failed': 'Failed to update details',
      'settings_update_queued': 'Changes saved offline',
      'settings_update_queued_hint': 'pending sync',
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
      'form_field_default': 'field',
      'form_required': 'Please fill in {field}',
      'form_email_required': 'Enter your email',
      'form_email_invalid': 'Email format looks incorrect',
      'form_phone_required': 'Enter your phone number',
      'form_phone_invalid': 'Use at least 10 digits',
      'form_password_required': 'Enter a password',
      'form_password_short': 'Password must be longer than 8 characters',
      'form_password_mismatch': 'Passwords do not match',
      'form_fix_errors': 'Please check the highlighted fields',
      'form_unexpected_error': 'Something went wrong. Please try again.',
      'form_draft_saved': 'Draft saved',
      'form_draft_restored': 'Draft restored',
      'auth_login_title': 'Welcome back!',
      'auth_login_action': 'Log in',
      'auth_register_prompt': 'No account? Sign up',
      'auth_register_action': 'Create account',
      'auth_register_title': 'Sign up',
      'auth_login_has_account': 'Already have an account',
      'auth_email_label': 'Email',
      'auth_password_label': 'Password',
      'auth_confirm_password_label': 'Confirm password',
      'auth_name_label': 'Name',
      'auth_gender_label': 'Gender',
      'auth_select_gender_hint': 'Select gender',
      'auth_login_error': 'Incorrect email or password.',
      'auth_passwords_match': 'Passwords match',
      'auth_passwords_mismatch': 'Passwords do not match',
      'auth_location_error': 'Failed to create initial location: {error}',
      'auth_pin_length_error': 'Enter a 4–8 digit PIN code.',
      'auth_pin_verify_error': 'Could not verify PIN code: {error}',
      'auth_pin_verify_generic': 'Unable to verify the PIN code. Please try later.',
      'auth_pin_prompt': 'Enter PIN code',
      'auth_pin_hint': 'Security confirmation is required to continue.',
      'auth_pin_label': 'PIN code',
      'auth_unlock_action': 'Unlock',
      'auth_exit_action': 'Sign out',
      'auth_pin_invalid': 'Incorrect PIN code. Please try again.',
      'auth_biometric_reason': 'Confirm your identity to access the wardrobe',
      'auth_biometric_failed':
          'Biometric authentication failed. Please enter your PIN code.',
      'support_section_title': 'Help & Support',
      'support_contact_action': 'Contact support',
      'support_contact_settings_hint':
          'Tell us what happened — the device model and OS version will be added automatically.',
      'support_contact_login_hint':
          'Trouble signing in? Email us and we will help.',
      'support_email_subject': 'Support request: {source}',
      'support_email_body':
          'Describe your issue or question below.\n\n---\nDevice model: {model}\nOS version: {osVersion}',
      'support_email_source_settings': 'Settings',
      'support_email_source_login': 'Login screen',
      'support_email_launch_error':
          'Could not open the mail app. Please check your mail setup.',
      'location_picker_title': 'Choose coordinates',
      'location_picker_selected': 'Selected coordinates',
      'location_picker_hint': 'Tap the map to move the pin.',
      'location_picker_confirm': 'Save coordinates',
    },
  };

  static Map<String, Map<String, String>> get localizedValues =>
      UnmodifiableMapView(_localizedValues);

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

  String getStringWithPlaceholder(String key, String value) {
    return getString(key).replaceFirst('{source}', value);
  }

  String getStringWithPlaceholders(String key, Map<String, String> placeholders) {
    var result = getString(key);
    placeholders.forEach((placeholder, value) {
      result = result.replaceAll('{$placeholder}', value);
    });
    return result;
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
  String get settingsThemeSection => getString('settings_theme_section');
  String get settingsThemeLight => getString('settings_theme_light');
  String get settingsThemeDark => getString('settings_theme_dark');
  String get settingsThemeSystem => getString('settings_theme_system');
  String get settingsManageAction => getString('settings_manage_action');
  String get settingsHomeManageDescription =>
      getString('settings_home_manage_description');
  String get settingsPlacesManageDescription =>
      getString('settings_places_manage_description');
  String get settingsAccountLoadFailed => getString('settings_account_load_failed');
  String get settingsUpdateSuccess => getString('settings_update_success');
  String get settingsUpdateFailed => getString('settings_update_failed');
  String get settingsUpdateQueued => getString('settings_update_queued');
  String get settingsUpdateQueuedHint => getString('settings_update_queued_hint');
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
  String get formFieldDefault => getString('form_field_default');
  String formRequired(String field) =>
      getString('form_required').replaceFirst('{field}', field);
  String get formEmailRequired => getString('form_email_required');
  String get formEmailInvalid => getString('form_email_invalid');
  String get formPhoneRequired => getString('form_phone_required');
  String get formPhoneInvalid => getString('form_phone_invalid');
  String get formPasswordRequired => getString('form_password_required');
  String get formPasswordShort => getString('form_password_short');
  String get formPasswordMismatch => getString('form_password_mismatch');
  String get formFixErrors => getString('form_fix_errors');
  String get formUnexpectedError => getString('form_unexpected_error');
  String get formDraftSaved => getString('form_draft_saved');
  String get formDraftRestored => getString('form_draft_restored');
  String get authLoginTitle => getString('auth_login_title');
  String get authLoginAction => getString('auth_login_action');
  String get authRegisterPrompt => getString('auth_register_prompt');
  String get authRegisterAction => getString('auth_register_action');
  String get authRegisterTitle => getString('auth_register_title');
  String get authLoginHasAccount => getString('auth_login_has_account');
  String get authEmailLabel => getString('auth_email_label');
  String get authPasswordLabel => getString('auth_password_label');
  String get authConfirmPasswordLabel =>
      getString('auth_confirm_password_label');
  String get authNameLabel => getString('auth_name_label');
  String get authGenderLabel => getString('auth_gender_label');
  String get authSelectGenderHint => getString('auth_select_gender_hint');
  String get authLoginError => getString('auth_login_error');
  String get authPasswordsMatch => getString('auth_passwords_match');
  String get authPasswordsMismatch => getString('auth_passwords_mismatch');
  String authLocationError(String error) =>
      getString('auth_location_error').replaceFirst('{error}', error);
  String get authPinLengthError => getString('auth_pin_length_error');
  String authPinVerifyError(String error) =>
      getString('auth_pin_verify_error').replaceFirst('{error}', error);
  String get authPinVerifyGeneric => getString('auth_pin_verify_generic');
  String get authPinPrompt => getString('auth_pin_prompt');
  String get authPinHint => getString('auth_pin_hint');
  String get authPinLabel => getString('auth_pin_label');
  String get authUnlockAction => getString('auth_unlock_action');
  String get authExitAction => getString('auth_exit_action');
  String get authPinInvalid => getString('auth_pin_invalid');
  String get authBiometricReason => getString('auth_biometric_reason');
  String get authBiometricFailed => getString('auth_biometric_failed');
  String get supportSectionTitle => getString('support_section_title');
  String get supportContactAction => getString('support_contact_action');
  String get supportContactSettingsHint =>
      getString('support_contact_settings_hint');
  String get supportContactLoginHint => getString('support_contact_login_hint');
  String supportEmailSubject(String source) =>
      getStringWithPlaceholder('support_email_subject', source);
  String supportEmailBody({required String model, required String osVersion}) =>
      getStringWithPlaceholders('support_email_body', {
        'model': model,
        'osVersion': osVersion,
      });
  String get supportEmailSourceSettings =>
      getString('support_email_source_settings');
  String get supportEmailSourceLogin => getString('support_email_source_login');
  String get supportEmailLaunchError => getString('support_email_launch_error');
  String get homeRefreshMannequin => getString('home_refresh_mannequin');
  String get navHome => getString('nav_home');
  String get navWardrobe => getString('nav_wardrobe');
  String get navSettings => getString('nav_settings');
  String get locationPickerTitle => getString('location_picker_title');
  String get locationPickerSelected => getString('location_picker_selected');
  String get locationPickerHint => getString('location_picker_hint');
  String get locationPickerConfirm => getString('location_picker_confirm');

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
