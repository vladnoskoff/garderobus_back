import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

mixin FormValidationMixin {
  AppLocalizations l10n(BuildContext context) => AppLocalizations.of(context);

  String? validateEmail(BuildContext context, String? value) {
    return FormValidators.validateEmail(value, l10n(context));
  }

  String? validatePhone(BuildContext context, String? value) {
    return FormValidators.validatePhone(value, l10n(context));
  }

  String? validatePassword(BuildContext context, String? value) {
    return FormValidators.validatePassword(value, l10n(context));
  }

  String? validateRequiredField(BuildContext context, String? value,
      {String? fieldName}) {
    return FormValidators.validateRequired(value, l10n(context),
        fieldName: fieldName);
  }

  String? validatePasswordConfirmation(
    BuildContext context,
    String? value,
    String? otherValue,
  ) {
    return FormValidators.validatePasswordConfirmation(
      value,
      otherValue,
      l10n(context),
    );
  }
}

class FormValidators {
  static String? validateRequired(
    String? value,
    AppLocalizations l10n, {
    String? fieldName,
  }) {
    if (value == null || value.trim().isEmpty) {
      return l10n.formRequired(fieldName ?? l10n.formFieldDefault);
    }
    return null;
  }

  static String? validateEmail(String? value, AppLocalizations l10n) {
    if (value == null || value.trim().isEmpty) {
      return l10n.formEmailRequired;
    }
    final emailRegex = RegExp(r"^[\w.!#%&'*+/=?`{|}~-]+@[\w-]+(\.[\w-]+)+");
    if (!emailRegex.hasMatch(value.trim())) {
      return l10n.formEmailInvalid;
    }
    return null;
  }

  static String? validatePhone(String? value, AppLocalizations l10n) {
    if (value == null || value.trim().isEmpty) {
      return l10n.formPhoneRequired;
    }
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 10) {
      return l10n.formPhoneInvalid;
    }
    return null;
  }

  static String? validatePassword(String? value, AppLocalizations l10n) {
    if (value == null || value.isEmpty) {
      return l10n.formPasswordRequired;
    }
    if (value.length < 8) {
      return l10n.formPasswordShort;
    }
    return null;
  }

  static String? validatePasswordConfirmation(
    String? value,
    String? other,
    AppLocalizations l10n,
  ) {
    if (value == null || value.isEmpty || other == null || other.isEmpty) {
      return l10n.formPasswordRequired;
    }
    if (value != other) {
      return l10n.formPasswordMismatch;
    }
    return null;
  }
}
