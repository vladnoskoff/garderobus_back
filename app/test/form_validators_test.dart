import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import '../l10n/app_localizations.dart';
import '../services/form_validators.dart';

void main() {
  final l10n = AppLocalizations(const Locale('en'));

  group('FormValidators', () {
    test('validates email format', () {
      expect(FormValidators.validateEmail('', l10n), isNotNull);
      expect(FormValidators.validateEmail('user@example.com', l10n), isNull);
    });

    test('validates phone digits count', () {
      expect(FormValidators.validatePhone('123', l10n), isNotNull);
      expect(FormValidators.validatePhone('+1 (123) 456-7890', l10n), isNull);
    });

    test('validates password length and confirmation', () {
      expect(FormValidators.validatePassword('123', l10n), isNotNull);
      expect(FormValidators.validatePassword('password', l10n), isNull);
      expect(
        FormValidators.validatePasswordConfirmation('pass', 'word', l10n),
        isNotNull,
      );
      expect(
        FormValidators.validatePasswordConfirmation('password', 'password', l10n),
        isNull,
      );
    });
  });
}
