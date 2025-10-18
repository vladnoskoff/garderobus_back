import 'package:flutter/material.dart';

class RoundedBackButton extends StatelessWidget {
  const RoundedBackButton({super.key, this.onPressed, this.icon});

  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: IconButton(
        onPressed: onPressed ?? () => Navigator.of(context).maybePop(),
        icon: Icon(icon ?? Icons.arrow_back_ios_new_rounded),
        iconSize: 20,
        style: IconButton.styleFrom(
          shape: const CircleBorder(),
          padding: const EdgeInsets.all(10),
          backgroundColor: colorScheme.surfaceVariant.withOpacity(0.85),
          foregroundColor: colorScheme.onSurface,
          disabledForegroundColor: colorScheme.onSurface.withOpacity(0.4),
          disabledBackgroundColor:
              colorScheme.surfaceVariant.withOpacity(0.4),
        ),
      ),
    );
  }
}
