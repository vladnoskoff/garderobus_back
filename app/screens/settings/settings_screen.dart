import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_extensions.dart';
import '../../services/api_service.dart';
import '../../services/language_controller.dart';
import '../../services/local_storage_service.dart';
import '../../services/network_service.dart';
import '../../services/pending_action_queue.dart';
import '../../services/sync_service.dart';
import '../../services/theme_controller.dart';
import '../auth/login_screen.dart';
import 'home_settings/home_screen_settings.dart';
import 'places/places_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  ThemeMode _themeMode = ThemeMode.system;
  bool _didInitializeTheme = false;
  bool _isLoadingAccount = true;
  bool _hasPin = false;
  int? _userId;
  String _fullName = '';
  String _email = '';
  String _phone = '';
  String _gender = 'not_specified';
  bool _isLoadingSelectedLocation = false;
  String? _currentLocationName;
  Set<String> _pendingFields = {};

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    SyncService.instance.isSyncing.addListener(_handleSyncStatusChanged);
    _loadAccountData();
  }

  @override
  void dispose() {
    SyncService.instance.isSyncing.removeListener(_handleSyncStatusChanged);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitializeTheme) {
      return;
    }

    final themeNotifier = ThemeScope.of(context);
    _themeMode = themeNotifier.themeMode;
    _didInitializeTheme = true;
  }

  Future<void> _loadAccountData() async {
    setState(() {
      _isLoadingAccount = true;
    });

    try {
      final idString = await _storage.read(key: 'user_id');
      final parsedId = idString != null ? int.tryParse(idString) : null;

      if (parsedId == null) {
        if (!mounted) return;
        setState(() {
          _userId = null;
          _isLoadingAccount = false;
          _currentLocationName = null;
          _isLoadingSelectedLocation = false;
          _pendingFields.clear();
        });
        return;
      }

      final isOnline = NetworkService.isOnline.value;
      Map<String, dynamic>? data;
      if (isOnline) {
        data = await ApiService.getUser(parsedId);
      } else {
        data = await LocalStorageService.getCachedUserProfile(parsedId);
        if (data == null) {
          throw Exception('Нет локальных данных профиля');
        }
      }
      if (!mounted) return;

      _applyProfileData(parsedId, data);
      await _refreshPendingFields(parsedId);

      if (isOnline) {
        await _loadSelectedLocationName(parsedId);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoadingAccount = false;
      });
      final l10n = context.l10n;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.settingsAccountLoadFailed)),
      );
    }
  }

  Future<bool> _updateUserField(String field, String value, {bool silent = false}) async {
    if (_userId == null) {
      return false;
    }

    try {
      if (!NetworkService.isOnline.value) {
        await SyncService.instance
            .enqueueUserUpdate(userId: _userId!, field: field, value: value);
        await LocalStorageService.updateCachedUserField(_userId!, field, value);
        setState(() {
          _pendingFields = {..._pendingFields, field};
        });
        await _applyPendingFieldLocally(field, value);
        if (!silent && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(context.l10n.settingsUpdateQueued)),
          );
        }
        return true;
      }

      await ApiService.updateUser(_userId!, field, value);
      await LocalStorageService.updateCachedUserField(_userId!, field, value);
      await _loadAccountData();
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.settingsUpdateSuccess)),
        );
      }
      return true;
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.settingsUpdateFailed)),
        );
      }
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final languageNotifier = LanguageScope.of(context);
    final currentLanguage =
        l10n.languageName(languageNotifier.locale.languageCode);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          _buildStatusBanner(),
          const SizedBox(height: 16),
          _buildSectionHeader(l10n.settingsAccount, theme),
          const SizedBox(height: 12),
          _buildGradientSection(
            context,
            accentColor: colorScheme.primary,
            children: [
              _buildSettingsTile(
                context,
                label: l10n.settingsAccountFullName,
                icon: Icons.badge_outlined,
                subtitle: _valueOrPlaceholder(
                  _fullName,
                  l10n,
                  fieldKey: 'name',
                ),
                onTap: _userId != null
                    ? () => _showEditableFieldDialog(
                          title: l10n.settingsAccountFullName,
                          initialValue: _fullName,
                          keyboardType: TextInputType.name,
                          onSubmitted: (value) async {
                            await _updateUserField('name', value);
                          },
                        )
                    : null,
              ),
              _buildDivider(colorScheme),
              _buildSettingsTile(
                context,
                label: l10n.settingsAccountEmail,
                icon: Icons.email_outlined,
                subtitle: _valueOrPlaceholder(
                  _email,
                  l10n,
                  fieldKey: 'email',
                ),
                onTap: _userId != null
                    ? () => _showEditableFieldDialog(
                          title: l10n.settingsAccountEmail,
                          initialValue: _email,
                          keyboardType: TextInputType.emailAddress,
                          onSubmitted: (value) async {
                            await _updateUserField('email', value);
                          },
                        )
                    : null,
              ),
              _buildDivider(colorScheme),
              _buildSettingsTile(
                context,
                label: l10n.settingsAccountPhone,
                icon: Icons.phone_outlined,
                subtitle: _valueOrPlaceholder(
                  _phone,
                  l10n,
                  fieldKey: 'phone',
                ),
                onTap: _userId != null
                    ? () => _showEditableFieldDialog(
                          title: l10n.settingsAccountPhone,
                          initialValue: _phone,
                          keyboardType: TextInputType.phone,
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9()+\s-]'),
                            ),
                          ],
                          onSubmitted: (value) async {
                            await _updateUserField('phone', value, silent: true);
                          },
                        )
                    : null,
              ),
              _buildDivider(colorScheme),
              _buildSettingsTile(
                context,
                label: l10n.settingsAccountGender,
                icon: Icons.wc_outlined,
                subtitle: _isLoadingAccount
                    ? l10n.settingsValueLoading
                    : l10n.settingsGenderLabel(_gender),
                onTap: _userId != null ? () => _showGenderDialog() : null,
              ),
            ],
          ),
          const SizedBox(height: 28),
          _buildSectionHeader(l10n.settingsSecurityPrivacy, theme),
          const SizedBox(height: 12),
          _buildGradientSection(
            context,
            accentColor: colorScheme.secondary,
            children: [
              _buildSettingsTile(
                context,
                label: l10n.settingsSecurityPassword,
                icon: Icons.lock_outline,
                subtitle: '••••••',
                onTap: _userId != null ? () => _showPasswordDialog() : null,
              ),
              _buildDivider(colorScheme),
              _buildSettingsTile(
                context,
                label: l10n.settingsSecurityPin,
                icon: Icons.shield_outlined,
                subtitle: _isLoadingAccount
                    ? l10n.settingsValueLoading
                    : _hasPin
                        ? l10n.settingsPinSet
                        : l10n.settingsPinNotSet,
                onTap: _userId != null ? () => _showPinSheet() : null,
              ),
            ],
          ),
          const SizedBox(height: 28),
          _buildSectionHeader(l10n.settingsGeneralSection, theme),
          const SizedBox(height: 12),
          _buildQuickActions(
            context,
            currentLanguage: currentLanguage,
            themeMode: _themeMode,
            colorScheme: colorScheme,
            l10n: l10n,
          ),
          const SizedBox(height: 36),
          Align(
            alignment: Alignment.center,
            child: buildExitButton(context),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, ThemeData theme) {
    return Text(
      title,
      style: theme.textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
      ),
    );
  }

  Widget _buildStatusBanner() {
    final colorScheme = Theme.of(context).colorScheme;
    return ValueListenableBuilder<bool>(
      valueListenable: NetworkService.isOnline,
      builder: (context, isOnline, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: SyncService.instance.isSyncing,
          builder: (context, isSyncing, __) {
            if (isOnline && !isSyncing) return const SizedBox.shrink();

            final background = isOnline
                ? colorScheme.tertiaryContainer
                : colorScheme.errorContainer;
            final foreground = isOnline
                ? colorScheme.onTertiaryContainer
                : colorScheme.onErrorContainer;

            return Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: background,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    isOnline ? Icons.sync : Icons.wifi_off,
                    color: foreground,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      isOnline
                          ? 'Идет синхронизация локальных изменений'
                          : 'Офлайн: изменения в настройках будут отправлены позже',
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: foreground),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildGradientSection(
    BuildContext context, {
    required Color accentColor,
    required List<Widget> children,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = colorScheme.surfaceContainerHighest;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
            colors: [
              baseColor.withValues(alpha: 0.7),
              baseColor,
              accentColor.withValues(alpha: 0.22),
            ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    BuildContext context, {
    required String label,
    required IconData icon,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      subtitle,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right_rounded,
                color: colorScheme.onSurfaceVariant,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider(ColorScheme colorScheme) {
    return Divider(
      color: colorScheme.outlineVariant.withValues(alpha: 0.6),
      height: 4,
      thickness: 1,
    );
  }

  Widget _buildQuickActions(
    BuildContext context, {
    required String currentLanguage,
    required ThemeMode themeMode,
    required ColorScheme colorScheme,
    required AppLocalizations l10n,
  }) {
    final themeIcon = _themeIconFor(themeMode);
    final themeLabel = _describeThemeMode(l10n, themeMode);
    final locationLabel = _isLoadingSelectedLocation
        ? l10n.settingsValueLoading
        : ((_currentLocationName?.trim().isNotEmpty ?? false)
            ? _currentLocationName!.trim()
            : l10n.settingsHome);
    return Align(
      alignment: Alignment.center,
      child: Wrap(
        alignment: WrapAlignment.center,
        runAlignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 14,
        children: [
          _QuickActionButton(
            icon: Icons.home_outlined,
            label: locationLabel,
            color: colorScheme.primaryContainer,
            onTap: () {
              _openHomeSettings(context);
            },
          ),
          _QuickActionButton(
            icon: Icons.place_outlined,
            label: l10n.settingsPlaces,
            color: colorScheme.secondaryContainer,
            onTap: () {
              _openPlaces(context);
            },
          ),
          _QuickActionButton(
            icon: Icons.language_outlined,
            label: '${l10n.settingsLanguage}\n$currentLanguage',
            color: colorScheme.tertiaryContainer,
            onTap: () {
              _openLanguageSelector(context);
            },
          ),
          _QuickActionButton(
            icon: themeIcon,
            label: '${l10n.settingsThemeSection}\n$themeLabel',
            color: colorScheme.primaryContainer,
            onTap: () {
              _openThemeSelector(context);
            },
          ),
        ],
      ),
    );
  }

  Future<void> _openHomeSettings(BuildContext context) async {
    await showHomeSettingsSheet(context);
    if (_userId != null) {
      await _loadSelectedLocationName(_userId!);
    }
  }

  Future<void> _openPlaces(BuildContext context) async {
    await showPlacesSettingsSheet(context);
    if (_userId != null) {
      await _loadSelectedLocationName(_userId!);
    }
  }

  Future<void> _openThemeSelector(BuildContext context) async {
    final l10n = context.l10n;
    ThemeMode tempMode = _themeMode;

    final selectedThemeMode = await showModalBottomSheet<ThemeMode>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
          child: StatefulBuilder(
            builder: (context, setState) {
              Widget buildOption({
                required ThemeMode mode,
                required IconData icon,
                required String label,
              }) {
                final theme = Theme.of(context);
                final colorScheme = theme.colorScheme;
                final selected = tempMode == mode;
                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    setState(() {
                      tempMode = mode;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: selected
                            ? colorScheme.primary.withValues(alpha: 0.08)
                            : colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.2),
                        border: Border.all(
                          color: selected
                              ? colorScheme.primary
                              : colorScheme.outlineVariant.withValues(alpha: 0.2),
                          width: 1.4,
                        ),
                      ),
                    child: Row(
                      children: [
                        Icon(icon, color: colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            label,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Radio<ThemeMode>(
                          value: mode,
                          groupValue: tempMode,
                          activeColor: colorScheme.primary,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                tempMode = value;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.settingsThemeSection,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 20),
                  buildOption(
                    mode: ThemeMode.system,
                    icon: Icons.brightness_auto,
                    label: l10n.settingsThemeSystem,
                  ),
                  const SizedBox(height: 12),
                  buildOption(
                    mode: ThemeMode.light,
                    icon: Icons.light_mode_outlined,
                    label: l10n.settingsThemeLight,
                  ),
                  const SizedBox(height: 12),
                  buildOption(
                    mode: ThemeMode.dark,
                    icon: Icons.dark_mode_outlined,
                    label: l10n.settingsThemeDark,
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: Text(l10n.settingsCancel),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () => Navigator.pop(sheetContext, tempMode),
                        child: Text(l10n.settingsSave),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (selectedThemeMode != null && selectedThemeMode != _themeMode) {
      _onThemeChanged(selectedThemeMode);
    }
  }

  Future<void> _openLanguageSelector(BuildContext context) async {
    final languageNotifier = LanguageScope.of(context);
    final l10n = context.l10n;
    Locale tempLocale = languageNotifier.locale;

    final selectedLocale = await showModalBottomSheet<Locale>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 36),
          child: StatefulBuilder(
            builder: (context, setState) {
              Widget buildOption(Locale locale) {
                final theme = Theme.of(context);
                final colorScheme = theme.colorScheme;
                final selected = tempLocale == locale;
                return InkWell(
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    setState(() {
                      tempLocale = locale;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(18),
                        color: selected
                            ? colorScheme.primary.withValues(alpha: 0.08)
                            : colorScheme.surfaceContainerHighest
                                .withValues(alpha: 0.2),
                        border: Border.all(
                          color: selected
                              ? colorScheme.primary
                              : colorScheme.outlineVariant.withValues(alpha: 0.2),
                          width: 1.4,
                        ),
                      ),
                    child: Row(
                      children: [
                        Icon(Icons.language_outlined, color: colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            l10n.languageName(locale.languageCode),
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Radio<Locale>(
                          value: locale,
                          groupValue: tempLocale,
                          activeColor: colorScheme.primary,
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                tempLocale = value;
                              });
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.settingsLanguage,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 20),
                  for (final locale in LanguageNotifier.supportedLocales) ...[
                    buildOption(locale),
                    if (locale != LanguageNotifier.supportedLocales.last)
                      const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        child: Text(l10n.settingsCancel),
                      ),
                      const SizedBox(width: 12),
                      FilledButton(
                        onPressed: () => Navigator.pop(sheetContext, tempLocale),
                        child: Text(l10n.settingsSave),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (selectedLocale != null && selectedLocale != languageNotifier.locale) {
      try {
        await languageNotifier.setLocale(selectedLocale);
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.languageUpdated)),
        );
      } catch (_) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.languageUpdateFailed)),
        );
        return;
      }
      if (mounted) {
        setState(() {});
      }
    }
  }

  String _describeThemeMode(AppLocalizations l10n, ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return l10n.settingsThemeDark;
      case ThemeMode.light:
        return l10n.settingsThemeLight;
      case ThemeMode.system:
        return l10n.settingsThemeSystem;
    }
  }

  IconData _themeIconFor(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.dark:
        return Icons.dark_mode_outlined;
      case ThemeMode.light:
        return Icons.light_mode_outlined;
      case ThemeMode.system:
        return Icons.brightness_auto;
    }
  }

  Future<void> _onThemeChanged(ThemeMode mode) async {
    setState(() {
      _themeMode = mode;
    });
    final notifier = ThemeScope.of(context);
    await notifier.setTheme(mode);
  }

  Widget buildExitButton(BuildContext context) {
    final l10n = context.l10n;
    return GestureDetector(
      onTap: () async {
        final shouldLogout = await showDialog<bool>(
              context: context,
              builder: (dialogContext) => AlertDialog(
                title: Text(l10n.settingsLogout),
                content: Text(l10n.logoutConfirmation),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, false),
                    child: Text(l10n.logoutCancel),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext, true),
                    child: Text(l10n.logoutConfirm),
                  ),
                ],
              ),
            ) ??
            false;

        if (!shouldLogout) {
          return;
        }

        const storage = FlutterSecureStorage();
        await storage.delete(key: 'user_id');
        await storage.delete(key: 'token');

        if (!context.mounted) return;

        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
          (route) => false,
        );
      },
      child: Container(
        width: 190,
        height: 59,
        decoration: BoxDecoration(
          color: const Color(0xFFFF4D4D),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            l10n.settingsLogout,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  String _valueOrPlaceholder(
    String value,
    AppLocalizations l10n, {
    String? fieldKey,
  }) {
    if (_isLoadingAccount) {
      return l10n.settingsValueLoading;
    }
    final sanitized = value.trim();
    String resolved =
        sanitized.isEmpty || sanitized.toLowerCase() == 'null'
            ? l10n.settingsValueNotSet
            : sanitized;

    if (fieldKey != null && _pendingFields.contains(fieldKey)) {
      resolved = '$resolved · ${l10n.settingsUpdateQueuedHint}';
    }
    return resolved;
  }

  Future<void> _applyPendingFieldLocally(String field, String value) async {
    if (!mounted) return;
    setState(() {
      switch (field) {
        case 'name':
          _fullName = value;
          break;
        case 'email':
          _email = value;
          break;
        case 'phone':
        case 'phone_number':
        case 'phoneNumber':
          _phone = value;
          break;
        case 'gender':
          _gender = value;
          break;
      }
    });
  }

  void _applyProfileData(int userId, Map<String, dynamic> data) {
    final phoneValue = data['phone'] ??
        data['phone_number'] ??
        data['phoneNumber'] ??
        data['mobile'] ??
        data['mobile_phone'];

    setState(() {
      _userId = userId;
      _fullName = (data['name'] ?? '') as String;
      _email = (data['email'] ?? '') as String;
      _phone = phoneValue != null ? phoneValue.toString() : '';
      _gender = (data['gender'] ?? 'not_specified') as String;
      _hasPin = data['has_pin'] == true;
      _isLoadingAccount = false;
    });
  }

  Future<void> _refreshPendingFields(int userId) async {
    final queue = await PendingActionQueue.loadQueue();
    final pendingForUser = queue
        .where((action) =>
            action.entity == 'user' &&
            int.tryParse('${action.payload['user_id']}') == userId)
        .map((action) => action.payload['field']?.toString())
        .whereType<String>()
        .toSet();

    if (!mounted) return;
    setState(() {
      _pendingFields = pendingForUser;
    });
  }

  Future<void> _showEditableFieldDialog({
    required String title,
    required String initialValue,
    required Future<void> Function(String) onSubmitted,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? inputFormatters,
  }) async {
    final controller = TextEditingController(text: initialValue);
    final l10n = context.l10n;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('${l10n.settingsEditFieldPrefix} $title'),
          content: TextField(
            controller: controller,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            autofocus: true,
            decoration: InputDecoration(
              labelText: title,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.settingsCancel),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.pop(dialogContext, controller.text.trim()),
              child: Text(l10n.settingsSave),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      await onSubmitted(result);
    }
  }

  Future<void> _showGenderDialog() async {
    String tempGender = _gender;
    final l10n = context.l10n;

    final selected = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.settingsSelectGender),
          content: StatefulBuilder(
            builder: (context, updateSheetState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  RadioListTile<String>(
                    value: 'male',
                    groupValue: tempGender,
                    onChanged: (value) {
                      if (value == null) return;
                      updateSheetState(() {
                        tempGender = value;
                      });
                    },
                    title: Text(l10n.settingsGenderMale),
                  ),
                  RadioListTile<String>(
                    value: 'female',
                    groupValue: tempGender,
                    onChanged: (value) {
                      if (value == null) return;
                      updateSheetState(() {
                        tempGender = value;
                      });
                    },
                    title: Text(l10n.settingsGenderFemale),
                  ),
                  RadioListTile<String>(
                    value: 'not_specified',
                    groupValue: tempGender,
                    onChanged: (value) {
                      if (value == null) return;
                      updateSheetState(() {
                        tempGender = value;
                      });
                    },
                    title: Text(l10n.settingsGenderUnspecified),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.settingsCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, tempGender),
              child: Text(l10n.settingsSave),
            ),
          ],
        );
      },
    );

    if (selected != null && selected != _gender) {
      setState(() {
        _gender = selected;
      });
      await _updateUserField('gender', selected, silent: true);
    }
  }

  Future<void> _showPasswordDialog() async {
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final l10n = context.l10n;
    String? errorMessage;

    final shouldUpdate = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(l10n.settingsPasswordChangeTitle),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: newPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: l10n.settingsPasswordNew,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: l10n.settingsPasswordConfirm,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        errorMessage!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: Text(l10n.settingsCancel),
                ),
                TextButton(
                  onPressed: () {
                    final newPassword = newPasswordController.text.trim();
                    final confirmPassword =
                        confirmPasswordController.text.trim();
                    if (newPassword.isEmpty || confirmPassword.isEmpty) {
                      setState(() {
                        errorMessage = l10n.settingsPasswordEmpty;
                      });
                      return;
                    }
                    if (newPassword != confirmPassword) {
                      setState(() {
                        errorMessage = l10n.settingsPasswordMismatch;
                      });
                      return;
                    }
                    Navigator.pop(dialogContext, true);
                  },
                  child: Text(l10n.settingsSave),
                ),
              ],
            );
          },
        );
      },
    );

    if (shouldUpdate == true) {
      final success = await _updateUserField(
        'password',
        newPasswordController.text.trim(),
        silent: true,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? l10n.settingsPasswordUpdated
                : l10n.settingsPasswordError,
          ),
        ),
      );
    }
  }

  Future<void> _showPinSheet() async {
    if (_userId == null) {
      return;
    }

    final l10n = context.l10n;
    final newPinController = TextEditingController();
    final confirmPinController = TextEditingController();
    String? error;
    String? successMessage;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 24,
            left: 24,
            right: 24,
            top: 24,
          ),
          child: StatefulBuilder(
            builder: (context, sheetSetState) {
              Future<void> savePin() async {
                final newPin = newPinController.text.trim();
                final confirmPin = confirmPinController.text.trim();

                if (newPin.length < 4 || newPin.length > 8) {
                  sheetSetState(() {
                    error = l10n.settingsPinLengthError;
                    successMessage = null;
                  });
                  return;
                }
                if (!RegExp(r'^[0-9]+$').hasMatch(newPin)) {
                  sheetSetState(() {
                    error = l10n.settingsPinDigitsError;
                    successMessage = null;
                  });
                  return;
                }
                if (newPin != confirmPin) {
                  sheetSetState(() {
                    error = l10n.settingsPinMismatchError;
                    successMessage = null;
                  });
                  return;
                }

                try {
                  await ApiService.setPinCode(_userId!, newPin);
                  if (!mounted) return;
                  sheetSetState(() {
                    error = null;
                    successMessage = l10n.settingsPinSaved;
                  });
                  newPinController.clear();
                  confirmPinController.clear();
                  setState(() {
                    _hasPin = true;
                  });
                  await _loadAccountData();
                  sheetSetState(() {});
                } catch (_) {
                  sheetSetState(() {
                    error = l10n.settingsPinSaveError;
                    successMessage = null;
      });
    }
  }

  void _handleSyncStatusChanged() async {
    if (!SyncService.instance.isSyncing.value && _userId != null) {
      await _refreshPendingFields(_userId!);
      if (NetworkService.isOnline.value) {
        await _loadAccountData();
      }
    }
  }

              Future<void> removePin() async {
                final confirm = await showDialog<bool>(
                  context: sheetContext,
                  builder: (dialogContext) {
                    return AlertDialog(
                      title: Text(l10n.settingsPinRemoveConfirmTitle),
                      content: Text(l10n.settingsPinRemoveConfirmMessage),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: Text(l10n.settingsCancel),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: Text(l10n.settingsPinRemoveAction),
                        ),
                      ],
                    );
                  },
                );

                if (confirm != true) {
                  return;
                }

                try {
                  await ApiService.clearPinCode(_userId!);
                  if (!mounted) return;
                  sheetSetState(() {
                    error = null;
                    successMessage = l10n.settingsPinRemoved;
                  });
                  setState(() {
                    _hasPin = false;
                  });
                  await _loadAccountData();
                  sheetSetState(() {});
                } catch (_) {
                  sheetSetState(() {
                    error = l10n.settingsPinRemoveError;
                    successMessage = null;
                  });
                }
              }

              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        l10n.settingsPinManageTitle,
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: newPinController,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: l10n.settingsPinNew,
                      counterText: '',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPinController,
                    keyboardType: TextInputType.number,
                    maxLength: 8,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: l10n.settingsPinConfirm,
                      counterText: '',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ],
                  if (successMessage != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      successMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: savePin,
                          child: Text(l10n.settingsPinSaveAction),
                        ),
                      ),
                      if (_hasPin) ...[
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: removePin,
                            child: Text(l10n.settingsPinRemoveAction),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _handleSyncStatusChanged() async {
    if (!SyncService.instance.isSyncing.value && _userId != null) {
      await _refreshPendingFields(_userId!);
      if (NetworkService.isOnline.value) {
        await _loadAccountData();
      }
    }
  }

  Future<void> _loadSelectedLocationName(int userId) async {
    if (!mounted) return;
    setState(() {
      _isLoadingSelectedLocation = true;
    });

    String? resolvedName = _currentLocationName;

    try {
      final storedLocationIdString =
          await _storage.read(key: 'selected_location_id');
      int? selectedLocationId;
      if (storedLocationIdString != null) {
        selectedLocationId = int.tryParse(storedLocationIdString);
      }

      final locations = await ApiService.getWardrobeLocations(userId);

      Map<String, dynamic>? selectedLocation;
      if (selectedLocationId != null) {
        selectedLocation =
            _findLocationById(locations, selectedLocationId);
      }

      if (selectedLocation == null) {
        final fallbackId = _deriveDefaultLocationId(locations);
        if (fallbackId != null) {
          selectedLocation = _findLocationById(locations, fallbackId);
        }
      }

      if (selectedLocation != null) {
        final rawName = selectedLocation['name'];
        final trimmedName = rawName?.toString().trim();
        if (trimmedName != null && trimmedName.isNotEmpty) {
          resolvedName = trimmedName;
        }
      }
    } catch (error) {
      debugPrint('Не удалось загрузить выбранную локацию: $error');
    }

    if (!mounted) return;
    setState(() {
      _currentLocationName = resolvedName;
      _isLoadingSelectedLocation = false;
    });
  }

  Map<String, dynamic>? _findLocationById(
    List<dynamic> locations,
    int locationId,
  ) {
    for (final location in locations.whereType<Map<String, dynamic>>()) {
      if (_parseLocationId(location['id']) == locationId) {
        return location;
      }
    }
    return null;
  }

  int? _deriveDefaultLocationId(List<dynamic> locations) {
    for (final location in locations.whereType<Map<String, dynamic>>()) {
      final latitude = location['latitude'];
      final longitude = location['longitude'];
      if (latitude != null && longitude != null) {
        return _parseLocationId(location['id']);
      }
    }
    return null;
  }

  int? _parseLocationId(dynamic rawId) {
    if (rawId is int) {
      return rawId;
    }
    if (rawId is String) {
      return int.tryParse(rawId);
    }
    if (rawId != null) {
      return int.tryParse(rawId.toString());
    }
    return null;
  }

}

class _QuickActionButton extends StatelessWidget {
  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final backgroundColor = color.withValues(alpha: 0.85);
    final brightness = ThemeData.estimateBrightnessForColor(backgroundColor);
    final foregroundColor =
        brightness == Brightness.dark ? Colors.white : Colors.black87;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          width: 150,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: backgroundColor,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 28,
                color: foregroundColor,
              ),
              const SizedBox(height: 12),
              Text(
                label,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: foregroundColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
