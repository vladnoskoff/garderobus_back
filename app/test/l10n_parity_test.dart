import 'package:flutter_test/flutter_test.dart';

import '../l10n/app_localizations.dart';

void main() {
  test('all locales expose the same localization keys', () {
    final localizedValues = AppLocalizations.localizedValues;
    final localeCodes = AppLocalizations.supportedLocales
        .map((locale) => locale.languageCode)
        .toList();

    expect(localeCodes, isNotEmpty);

    final referenceKeys = localizedValues[localeCodes.first]?.keys;
    expect(referenceKeys, isNotNull);

    for (final code in localeCodes) {
      expect(localizedValues.containsKey(code), isTrue,
          reason: 'Locale $code should be registered.');
      final values = localizedValues[code]!;
      expect(values.keys, unorderedEquals(referenceKeys),
          reason: 'Localization keys should match for locale $code.');

      for (final entry in values.entries) {
        expect(entry.value.trim(), isNotEmpty,
            reason: 'Missing translation for "${entry.key}" in "$code".');
      }
    }
  });
}
