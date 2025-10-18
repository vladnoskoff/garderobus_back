import 'package:flutter/material.dart';
import 'account/account_screen.dart';
import 'home_settings/home_screen_settings.dart';
import 'places/places_screen.dart';
import 'language/language_settings_screen.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../auth/login_screen.dart';
import '../../l10n/l10n_extensions.dart';
import '../../services/language_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final languageNotifier = LanguageScope.of(context);
    final currentLanguage =
        l10n.languageName(languageNotifier.locale.languageCode);
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.settingsTitle),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            buildSettingsButton(
              context,
              l10n.settingsAccount,
              const AccountScreen(),
            ),
            const SizedBox(height: 16),
            buildSettingsButton(
              context,
              l10n.settingsHome,
              const HomeScreenSettings(),
            ),
            const SizedBox(height: 16),
            buildSettingsButton(
              context,
              l10n.settingsPlaces,
              const PlacesScreen(),
            ),
            const SizedBox(height: 16),
            buildSettingsButton(
              context,
              l10n.settingsLanguage,
              const LanguageSettingsScreen(),
              subtitle: '${l10n.languageCurrentLabel}: $currentLanguage',
            ),
            const Spacer(),
            buildExitButton(context),
          ],
        ),
      ),
    );
  }

  Widget buildSettingsButton(
    BuildContext context,
    String text,
    Widget screen, {
    String? subtitle,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => screen),
        );
      },
      child: Container(
        width: double.infinity,
        height: 59,
        decoration: BoxDecoration(
          color: const Color(0xFF62DEFA),
          borderRadius: BorderRadius.circular(15),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 14,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black54),
          ],
        ),
      ),
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
        width: 170,
        height: 59,
        decoration: BoxDecoration(
          color: const Color(0xFFFF0C0C),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Text(
            l10n.settingsLogout,
            style: const TextStyle(
              color: Colors.black,
              fontSize: 24,
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}