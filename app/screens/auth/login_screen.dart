import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../l10n/app_localizations.dart';
import '../../services/api_service.dart';
import '../../services/draft_storage_service.dart';
import '../../services/form_validators.dart';
import '../../services/theme_controller.dart';
import '../../widgets/app_snackbar.dart';
import 'pin_unlock_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with FormValidationMixin {
  static const _draftKey = 'login_form_draft';
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _restoreDraft();
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  void login() async {
    final l10n = AppLocalizations.of(context);
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      AppSnackbar.showError(context, l10n.formFixErrors);
      return;
    }

    setState(() => isLoading = true);
    try {
      final email = emailController.text.trim();
      final password = passwordController.text.trim();

      final response = await ApiService.login(email, password);
      final storage = const FlutterSecureStorage();
      final userIdValue = response["user_id"]?.toString();
      final accessToken = response["access_token"]?.toString();

      if (userIdValue != null && userIdValue.isNotEmpty) {
        await storage.write(key: "user_id", value: userIdValue);
      } else {
        await storage.delete(key: "user_id");
      }

      if (accessToken != null && accessToken.isNotEmpty) {
        await storage.write(key: "token", value: accessToken);
        ApiService.rememberAccessToken(accessToken);
      } else {
        await storage.delete(key: "token");
        ApiService.rememberAccessToken(null);
      }
      try {
        await SystemChannels.textInput
            .invokeMethod<void>('TextInput.finishAutofillContext');
      } catch (_) {
        // Игнорируем, если контекст автозаполнения отсутствует.
      }

      try {
        final themeNotifier = ThemeScope.of(context);
        await themeNotifier.refreshFromRemote();
      } catch (_) {
        // Если тема недоступна, продолжаем без ошибок.
      }

      setState(() => isLoading = false);
      if (!mounted) return;
      final userId = int.tryParse(userIdValue ?? "");
      final hasPin = response["has_pin"] == true;

      if (hasPin && userId != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PinUnlockScreen(
              userId: userId,
              accessToken: accessToken,
              onUnlocked: (pinContext) async {
                if (!pinContext.mounted) return;
                await Navigator.pushReplacementNamed(pinContext, '/home');
              },
              onCancel: (pinContext) async {
                await storage.delete(key: "user_id");
                await storage.delete(key: "token");
                ApiService.rememberAccessToken(null);
                if (!pinContext.mounted) {
                  return;
                }
                await Navigator.pushNamedAndRemoveUntil(
                  pinContext,
                  '/login',
                  (route) => false,
                );
              },
            ),
          ),
        );
      } else {
        Navigator.pushReplacementNamed(context, '/home');
      }
      await DraftStorageService.clearDraft(_draftKey);
    } catch (e) {
      setState(() => isLoading = false);
      AppSnackbar.showError(context, '${l10n.authLoginError}\n$e');
    }
  }

  Future<void> _restoreDraft() async {
    final draft = await DraftStorageService.loadDraft(_draftKey);
    if (draft.isNotEmpty) {
      emailController.text = draft['email'] ?? '';
      passwordController.text = draft['password'] ?? '';
      if (mounted) {
        setState(() {});
        AppSnackbar.showSuccess(context, AppLocalizations.of(context).formDraftRestored);
      }
    }
  }

  Future<void> _saveDraft() async {
    await DraftStorageService.saveDraft(_draftKey, {
      'email': emailController.text,
      'password': passwordController.text,
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colorScheme.background,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Image.asset("assets/logo.png", height: 150),
                const SizedBox(height: 16),
                Text(
                  l10n.appTitle,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.authLoginTitle,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: colorScheme.onBackground,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [
                            AutofillHints.email,
                            AutofillHints.username,
                          ],
                          textCapitalization: TextCapitalization.none,
                          decoration: InputDecoration(labelText: l10n.authEmailLabel),
                          onChanged: (_) => _saveDraft(),
                          validator: (value) => validateEmail(context, value),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: passwordController,
                          obscureText: true,
                          textInputAction: TextInputAction.done,
                          autofillHints: const [AutofillHints.password],
                          decoration: InputDecoration(labelText: l10n.authPasswordLabel),
                          onChanged: (_) => _saveDraft(),
                          validator: (value) => validatePassword(context, value),
                          onFieldSubmitted: (_) {
                            if (!isLoading) {
                              login();
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: isLoading ? null : login,
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.authLoginAction),
                ),
                TextButton(
                  onPressed: () => Navigator.pushNamed(context, '/register'),
                  child: Text(
                    l10n.authRegisterPrompt,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
