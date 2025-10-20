import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../l10n/app_localizations.dart';
import '../../l10n/l10n_extensions.dart';
import '../../services/language_controller.dart';
import '../../services/theme_controller.dart';
import '../auth/login_screen.dart';
import 'account/account_screen.dart';
import 'account/pin_setup_screen.dart';
import 'home_settings/home_screen_settings.dart';
import 'language/language_settings_screen.dart';
import 'places/places_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _photoPermissionsVisible = true;
  bool _cameraPermissionsVisible = true;
  double _themeValue = 0;
  bool _didInitializeTheme = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_didInitializeTheme) {
      return;
    }

    final themeNotifier = ThemeScope.of(context);
    _themeValue = themeNotifier.themeMode == ThemeMode.dark ? 1 : 0;
    _didInitializeTheme = true;
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          _buildSectionTitle(l10n.settingsAccount, theme),
          _buildCard(
            context,
            children: [
              _buildNavigationTile(
                context,
                icon: Icons.badge_outlined,
                title: l10n.settingsAccountFullName,
                onTap: () => _openAccount(context),
              ),
              const Divider(height: 1),
              _buildNavigationTile(
                context,
                icon: Icons.email_outlined,
                title: l10n.settingsAccountEmail,
                onTap: () => _openAccount(context),
              ),
              const Divider(height: 1),
              _buildNavigationTile(
                context,
                icon: Icons.phone_outlined,
                title: l10n.settingsAccountPhone,
                onTap: () => _openAccount(context),
              ),
              const Divider(height: 1),
              _buildNavigationTile(
                context,
                icon: Icons.wc_outlined,
                title: l10n.settingsAccountGender,
                onTap: () => _openAccount(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionTitle(l10n.settingsSecurityPrivacy, theme),
          _buildCard(
            context,
            children: [
              _buildNavigationTile(
                context,
                icon: Icons.lock_outline,
                title: l10n.settingsSecurityPassword,
                onTap: () => _openAccount(context),
              ),
              const Divider(height: 1),
              _buildNavigationTile(
                context,
                icon: Icons.shield_outlined,
                title: l10n.settingsSecurityPin,
                onTap: () => _openPin(context),
              ),
              const Divider(height: 1),
              _buildSwitchTile(
                context,
                icon: Icons.photo_outlined,
                title: l10n.settingsSecurityPhotoPermissions,
                value: _photoPermissionsVisible,
                onChanged: (value) {
                  setState(() => _photoPermissionsVisible = value);
                },
              ),
              const Divider(height: 1),
              _buildSwitchTile(
                context,
                icon: Icons.photo_camera_outlined,
                title: l10n.settingsSecurityCameraPermissions,
                value: _cameraPermissionsVisible,
                onChanged: (value) {
                  setState(() => _cameraPermissionsVisible = value);
                },
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionTitle(l10n.settingsGeneralSection, theme),
          _buildCard(
            context,
            children: [
              _buildNavigationTile(
                context,
                icon: Icons.home_outlined,
                title: l10n.settingsHome,
                onTap: () => _openHomeSettings(context),
              ),
              const Divider(height: 1),
              _buildNavigationTile(
                context,
                icon: Icons.place_outlined,
                title: l10n.settingsPlaces,
                onTap: () => _openPlaces(context),
              ),
              const Divider(height: 1),
              _buildNavigationTile(
                context,
                icon: Icons.language_outlined,
                title: l10n.settingsLanguage,
                subtitle: '${l10n.languageCurrentLabel}: $currentLanguage',
                onTap: () => _openLanguage(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _buildSectionTitle(l10n.settingsThemeSection, theme),
          _buildThemeSelectorCard(colorScheme, l10n),
          const SizedBox(height: 32),
          Align(
            alignment: Alignment.center,
            child: buildExitButton(context),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        title,
        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildCard(
    BuildContext context, {
    required List<Widget> children,
  }) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: children),
    );
  }

  Widget _buildNavigationTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: colorScheme.secondaryContainer,
        foregroundColor: colorScheme.onSecondaryContainer,
        child: Icon(icon),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      activeColor: colorScheme.primary,
      secondary: CircleAvatar(
        backgroundColor: colorScheme.secondaryContainer,
        foregroundColor: colorScheme.onSecondaryContainer,
        child: Icon(icon),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildThemeSelectorCard(
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.settingsThemeSliderHint,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 6,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 20),
              ),
              child: Slider(
                value: _themeValue,
                min: 0,
                max: 1,
                divisions: 1,
                activeColor: colorScheme.primary,
                inactiveColor: colorScheme.surfaceVariant,
                onChanged: (value) {
                  setState(() => _themeValue = value);
                },
                onChangeEnd: (value) async {
                  final notifier = ThemeScope.of(context);
                  final mode = value < 0.5 ? ThemeMode.light : ThemeMode.dark;
                  await notifier.setTheme(mode);
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildThemeLabel(
                  label: l10n.settingsThemeLight,
                  isActive: _themeValue < 0.5,
                  colorScheme: colorScheme,
                ),
                _buildThemeLabel(
                  label: l10n.settingsThemeDark,
                  isActive: _themeValue >= 0.5,
                  colorScheme: colorScheme,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeLabel({
    required String label,
    required bool isActive,
    required ColorScheme colorScheme,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive ? colorScheme.primaryContainer : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
      ),
    );
  }

  void _openAccount(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AccountScreen()),
    );
  }

  void _openHomeSettings(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const HomeScreenSettings()),
    );
  }

  void _openPlaces(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PlacesScreen()),
    );
  }

  void _openLanguage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LanguageSettingsScreen()),
    );
  }

  void _openPin(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PinSetupScreen()),
    );
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
}