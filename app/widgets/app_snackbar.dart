import 'package:flutter/material.dart';

class AppSnackbar {
  static void showError(BuildContext context, String message) {
    _show(context, message, isError: true);
  }

  static void showSuccess(BuildContext context, String message) {
    _show(context, message, isError: false);
  }

  static void _show(BuildContext context, String message, {required bool isError}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final backgroundColor = isError ? colorScheme.errorContainer : colorScheme.primaryContainer;
    final textColor = isError ? colorScheme.onErrorContainer : colorScheme.onPrimaryContainer;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: backgroundColor,
        content: Text(
          message,
          style: theme.textTheme.bodyMedium?.copyWith(color: textColor),
        ),
      ),
    );
  }
}
