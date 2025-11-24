import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../l10n/app_localizations.dart';

void main() {
  group('AppLocalizations validation strings', () {
    for (final locale in const [Locale('ru'), Locale('en')]) {
      test('provides human readable validation messages for ${locale.languageCode}', () {
        final l10n = AppLocalizations(locale);
        expect(l10n.formEmailInvalid, isNotEmpty);
        expect(l10n.formEmailInvalid, isNot('form_email_invalid'));
        expect(l10n.formPasswordMismatch, isNotEmpty);
        expect(l10n.formPasswordMismatch, isNot('form_password_mismatch'));
        expect(l10n.authLoginError, isNotEmpty);
        expect(l10n.authPasswordLabel, isNotEmpty);
      });
    }
  });
}
