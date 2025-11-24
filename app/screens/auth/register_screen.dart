import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../services/api_service.dart';
import '../../services/draft_storage_service.dart';
import '../../services/form_validators.dart';
import '../../widgets/app_snackbar.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> with FormValidationMixin {
  static const _draftKey = 'register_form_draft';
  final emailController = TextEditingController();
  final nameController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  String? selectedGender;
  bool isLoading = false;

  bool get _passwordsMatch =>
      passwordController.text == confirmPasswordController.text;

  bool get _showPasswordMatchMessage =>
      passwordController.text.isNotEmpty &&
      confirmPasswordController.text.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _restoreDraft();
  }

  Future<void> register() async {
    final l10n = AppLocalizations.of(context);
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) {
      AppSnackbar.showError(context, l10n.formFixErrors);
      return;
    }

    setState(() => isLoading = true);
    try {
      final password = passwordController.text.trim();
      final confirmPassword = confirmPasswordController.text.trim();
      if (password != confirmPassword) {
        setState(() => isLoading = false);
        AppSnackbar.showError(context, l10n.formPasswordMismatch);
        return;
      }

      final response = await ApiService.register(
        nameController.text.trim(),
        emailController.text.trim(),
        password,
        selectedGender ?? 'not_specified',
      );

      final newUserId = _extractUserId(response);
      if (newUserId != null) {
        try {
          await ApiService.createWardrobeLocation(
            userId: newUserId,
            name: 'Место 1',
          );
        } catch (e) {
          if (mounted) {
            AppSnackbar.showError(
              context,
              l10n.authLocationError(e.toString()),
            );
          }
        }
      }

      setState(() => isLoading = false);
      await DraftStorageService.clearDraft(_draftKey);
      Navigator.pop(context);
    } catch (e) {
      setState(() => isLoading = false);
      AppSnackbar.showError(context, '${l10n.formUnexpectedError}\n$e');
    }
  }

  int? _extractUserId(Map<String, dynamic> response) {
    final idValue = response['user_id'] ?? response['id'];
    if (idValue is int) return idValue;
    if (idValue is String) {
      return int.tryParse(idValue);
    }
    return null;
  }

  @override
  void dispose() {
    emailController.dispose();
    nameController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _restoreDraft() async {
    final draft = await DraftStorageService.loadDraft(_draftKey);
    if (draft.isNotEmpty) {
      nameController.text = draft['name'] ?? '';
      emailController.text = draft['email'] ?? '';
      passwordController.text = draft['password'] ?? '';
      confirmPasswordController.text = draft['confirm_password'] ?? '';
      selectedGender = draft['gender'];
      if (mounted) {
        setState(() {});
        AppSnackbar.showSuccess(context, AppLocalizations.of(context).formDraftRestored);
      }
    }
  }

  Future<void> _saveDraft() async {
    await DraftStorageService.saveDraft(_draftKey, {
      'name': nameController.text,
      'email': emailController.text,
      'password': passwordController.text,
      'confirm_password': confirmPasswordController.text,
      'gender': selectedGender ?? '',
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
                  l10n.authRegisterTitle,
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: colorScheme.onBackground,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),
                Form(
                  key: _formKey,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(labelText: l10n.authNameLabel),
                        onChanged: (_) => _saveDraft(),
                        validator: (value) => validateRequiredField(
                          context,
                          value,
                          fieldName: l10n.authNameLabel.toLowerCase(),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: emailController,
                        decoration: InputDecoration(labelText: l10n.authEmailLabel),
                        keyboardType: TextInputType.emailAddress,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.email],
                        onChanged: (_) => _saveDraft(),
                        validator: (value) => validateEmail(context, value),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: passwordController,
                        obscureText: true,
                        decoration:
                            InputDecoration(labelText: l10n.authPasswordLabel),
                        onChanged: (_) {
                          setState(() {});
                          _saveDraft();
                        },
                        validator: (value) => validatePassword(context, value),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: confirmPasswordController,
                        obscureText: true,
                        decoration: InputDecoration(
                          labelText: l10n.authConfirmPasswordLabel,
                        ),
                        onChanged: (_) {
                          setState(() {});
                          _saveDraft();
                        },
                        validator: (value) => validatePasswordConfirmation(
                          context,
                          value,
                          passwordController.text,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (_showPasswordMatchMessage)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _passwordsMatch
                                ? l10n.authPasswordsMatch
                                : l10n.authPasswordsMismatch,
                            style: TextStyle(
                              color: _passwordsMatch
                                  ? Colors.green
                                  : theme.colorScheme.error,
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedGender?.isEmpty == true ? null : selectedGender,
                        decoration: InputDecoration(
                          labelText: l10n.authGenderLabel,
                        ),
                        hint: Text(l10n.authSelectGenderHint),
                        items: [
                          DropdownMenuItem(
                            value: 'male',
                            child: Text(l10n.settingsGenderMale),
                          ),
                          DropdownMenuItem(
                            value: 'female',
                            child: Text(l10n.settingsGenderFemale),
                          ),
                          DropdownMenuItem(
                            value: 'not_specified',
                            child: Text(l10n.settingsGenderUnspecified),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => selectedGender = value);
                          _saveDraft();
                        },
                        validator: (value) => validateRequiredField(
                          context,
                          value,
                          fieldName: l10n.authGenderLabel.toLowerCase(),
                        ),
                      ),
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: isLoading ? null : register,
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(l10n.authRegisterAction),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pushNamed(context, '/login'),
                        child: Text(
                          l10n.authLoginHasAccount,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.primary,
                          ),
                        ),
                      ),
                    ],
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
