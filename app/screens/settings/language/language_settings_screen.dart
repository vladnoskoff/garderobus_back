import 'package:flutter/material.dart';

import '../../../l10n/l10n_extensions.dart';
import '../../../services/language_controller.dart';

class LanguageSettingsScreen extends StatefulWidget {
  const LanguageSettingsScreen({super.key});

  @override
  State<LanguageSettingsScreen> createState() => _LanguageSettingsScreenState();
}

class _LanguageSettingsScreenState extends State<LanguageSettingsScreen> {
  late String _selectedLanguageCode;
  bool _isSaving = false;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      final currentLocale = LanguageScope.of(context).locale;
      _selectedLanguageCode = currentLocale.languageCode;
      _initialized = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final languageNotifier = LanguageScope.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.languageScreenTitle),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.languageSelectPrompt,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: LanguageNotifier.supportedLocales.map((locale) {
                  final languageName = l10n.languageName(locale.languageCode);
                  return RadioListTile<String>(
                    title: Text(languageName),
                    value: locale.languageCode,
                    groupValue: _selectedLanguageCode,
                    onChanged: _isSaving
                        ? null
                        : (value) {
                            if (value == null) return;
                            setState(() => _selectedLanguageCode = value);
                          },
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving
                    ? null
                    : () async {
                        await _applyLanguage(languageNotifier);
                      },
                child: _isSaving
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.languageApply),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applyLanguage(LanguageNotifier notifier) async {
    if (_isSaving) return;

    setState(() {
      _isSaving = true;
    });

    final l10n = context.l10n;

    try {
      final newLocale = Locale(_selectedLanguageCode);
      await notifier.setLocale(newLocale);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.languageUpdated)),
      );
      Navigator.pop(context);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.languageUpdateFailed)),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
}
