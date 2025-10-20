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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        children: [
          _buildSectionHeader(l10n.settingsAccount, theme),
          const SizedBox(height: 12),
          _buildGradientSection(
            context,
            accentColor: colorScheme.primary,
            children: [
              _buildNumberedTile(
                context,
                index: 1,
                label: l10n.settingsAccountFullName,
                icon: Icons.badge_outlined,
                onTap: () => _openAccount(context),
              ),
              _buildDivider(colorScheme),
              _buildNumberedTile(
                context,
                index: 2,
                label: l10n.settingsAccountEmail,
                icon: Icons.email_outlined,
                onTap: () => _openAccount(context),
              ),
              _buildDivider(colorScheme),
              _buildNumberedTile(
                context,
                index: 3,
                label: l10n.settingsAccountPhone,
                icon: Icons.phone_outlined,
                onTap: () => _openAccount(context),
              ),
              _buildDivider(colorScheme),
              _buildNumberedTile(
                context,
                index: 4,
                label: l10n.settingsAccountGender,
                icon: Icons.wc_outlined,
                onTap: () => _openAccount(context),
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
              _buildNumberedTile(
                context,
                index: 1,
                label: l10n.settingsSecurityPassword,
                icon: Icons.lock_outline,
                onTap: () => _openAccount(context),
              ),
              _buildDivider(colorScheme),
              _buildNumberedTile(
                context,
                index: 2,
                label: l10n.settingsSecurityPin,
                icon: Icons.shield_outlined,
                onTap: () => _openPin(context),
              ),
              _buildDivider(colorScheme),
              _buildToggleTile(
                context,
                index: 3,
                label: l10n.settingsSecurityPhotoPermissions,
                icon: Icons.photo_outlined,
                value: _photoPermissionsVisible,
                onChanged: (value) =>
                    setState(() => _photoPermissionsVisible = value),
              ),
              _buildDivider(colorScheme),
              _buildToggleTile(
                context,
                index: 4,
                label: l10n.settingsSecurityCameraPermissions,
                icon: Icons.photo_camera_outlined,
                value: _cameraPermissionsVisible,
                onChanged: (value) =>
                    setState(() => _cameraPermissionsVisible = value),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _buildSectionHeader(l10n.settingsGeneralSection, theme),
          const SizedBox(height: 12),
          _buildQuickActions(
            context,
            currentLanguage: currentLanguage,
            colorScheme: colorScheme,
            l10n: l10n,
          ),
          const SizedBox(height: 28),
          _buildSectionHeader(l10n.settingsThemeSection, theme),
          const SizedBox(height: 12),
          _buildThemeSelectorCard(colorScheme, l10n),
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

  Widget _buildGradientSection(
    BuildContext context, {
    required Color accentColor,
    required List<Widget> children,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = colorScheme.surfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            baseColor.withOpacity(0.7),
            baseColor,
            accentColor.withOpacity(0.22),
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

  Widget _buildNumberedTile(
    BuildContext context, {
    required int index,
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
          children: [
            _buildNumberBadge(colorScheme, index),
            const SizedBox(width: 16),
            Icon(icon, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall,
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

  Widget _buildToggleTile(
    BuildContext context, {
    required int index,
    required String label,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          _buildNumberBadge(colorScheme, index),
          const SizedBox(width: 16),
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
          Switch.adaptive(
            value: value,
            activeColor: colorScheme.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildNumberBadge(ColorScheme colorScheme, int index) {
    return Container(
      height: 40,
      width: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: colorScheme.primaryContainer.withOpacity(0.7),
      ),
      child: Center(
        child: Text(
          index.toString().padLeft(2, '0'),
          style: TextStyle(
            fontWeight: FontWeight.w700,
            color: colorScheme.onPrimaryContainer,
          ),
        ),
      ),
    );
  }

  Widget _buildDivider(ColorScheme colorScheme) {
    return Divider(
      color: colorScheme.outlineVariant.withOpacity(0.6),
      height: 4,
      thickness: 1,
    );
  }

  Widget _buildQuickActions(
    BuildContext context, {
    required String currentLanguage,
    required ColorScheme colorScheme,
    required AppLocalizations l10n,
  }) {
    return Wrap(
      spacing: 14,
      runSpacing: 14,
      children: [
        _QuickActionButton(
          icon: Icons.home_outlined,
          label: l10n.settingsHome,
          color: colorScheme.primaryContainer,
          onTap: () => _openHomeSettings(context),
        ),
        _QuickActionButton(
          icon: Icons.place_outlined,
          label: l10n.settingsPlaces,
          color: colorScheme.secondaryContainer,
          onTap: () => _openPlaces(context),
        ),
        _QuickActionButton(
          icon: Icons.language_outlined,
          label: '${l10n.settingsLanguage}\n$currentLanguage',
          color: colorScheme.tertiaryContainer,
          onTap: () => _openLanguage(context),
        ),
      ],
    );
  }

  Widget _buildThemeSelectorCard(
    ColorScheme colorScheme,
    AppLocalizations l10n,
  ) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: colorScheme.outlineVariant.withOpacity(0.4)),
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withOpacity(0.06),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.palette_outlined, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.settingsThemeSliderHint,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
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
                Icon(
                  Icons.swap_horiz,
                  color: colorScheme.primary,
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
    final backgroundColor = color.withOpacity(0.85);
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
