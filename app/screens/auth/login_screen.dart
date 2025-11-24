import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../services/api_service.dart';
import '../../services/draft_storage_service.dart';
import '../../services/form_validators.dart';
import '../../services/theme_controller.dart';
import '../../services/auth_scope.dart';
import '../../services/support_service.dart';
import '../../widgets/app_snackbar.dart';

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
      final authState = AuthScope.of(context);

      if (hasPin && userId != null) {
        await authState.refresh();
        if (!mounted) return;
        if (accessToken != null) {
          ApiService.rememberAccessToken(accessToken);
        }
        if (!mounted) return;
        context.go('/pin');
      } else {
        await authState.refresh();
        if (!mounted) return;
        context.go('/home');
      }
      await DraftStorageService.clearDraft(_draftKey);
    } catch (e) {
      if (!mounted) return;
      setState(() => isLoading = false);
      if (!mounted) return;
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

  Future<void> _contactSupport() async {
    final l10n = AppLocalizations.of(context);
    try {
      final deviceInfo = await SupportService.loadDeviceInfo();
      await SupportService.composeEmail(
        subject: l10n.supportEmailSubject(l10n.supportEmailSourceLogin),
        body: l10n.supportEmailBody(
          model: deviceInfo.model,
          osVersion: deviceInfo.osVersion,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      AppSnackbar.showError(context, l10n.supportEmailLaunchError);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 48,
                  maxWidth: 520,
                ),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              shape: BoxShape.circle,
                            ),
                            child: Image.asset(
                              "assets/logo.png",
                              height: 72,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.appTitle,
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.authLoginTitle,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: colorScheme.onSurface.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w600,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Card(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Form(
                            key: _formKey,
                            autovalidateMode: AutovalidateMode.onUserInteraction,
                            child: AutofillGroup(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    l10n.authLoginTitle,
                                    style: theme.textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: emailController,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    autofillHints: const [
                                      AutofillHints.email,
                                      AutofillHints.username,
                                    ],
                                    textCapitalization: TextCapitalization.none,
                                    decoration: InputDecoration(
                                      labelText: l10n.authEmailLabel,
                                      prefixIcon: const Icon(Icons.alternate_email_rounded),
                                    ),
                                    onChanged: (_) => _saveDraft(),
                                    validator: (value) => validateEmail(context, value),
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: passwordController,
                                    obscureText: true,
                                    textInputAction: TextInputAction.done,
                                    autofillHints: const [AutofillHints.password],
                                    decoration: InputDecoration(
                                      labelText: l10n.authPasswordLabel,
                                      prefixIcon: const Icon(Icons.lock_outline_rounded),
                                    ),
                                    onChanged: (_) => _saveDraft(),
                                    validator: (value) => validatePassword(context, value),
                                    onFieldSubmitted: (_) {
                                      if (!isLoading) {
                                        login();
                                      }
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  FilledButton(
                                    onPressed: isLoading ? null : login,
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size.fromHeight(48),
                                    ),
                                    child: isLoading
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          )
                                        : Text(l10n.authLoginAction),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () => context.go('/register'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: colorScheme.primary,
                                      minimumSize: const Size.fromHeight(44),
                                    ),
                                    child: Text(l10n.authRegisterPrompt),
                                  ),
                                  const SizedBox(height: 12),
                                  OutlinedButton.icon(
                                    onPressed: isLoading ? null : _contactSupport,
                                    icon: const Icon(Icons.support_agent_outlined),
                                    label: Text(l10n.supportContactAction),
                                    style: OutlinedButton.styleFrom(
                                      minimumSize: const Size.fromHeight(48),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    l10n.supportContactLoginHint,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
