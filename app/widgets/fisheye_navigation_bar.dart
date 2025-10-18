import 'dart:ui';

import 'package:flutter/material.dart';

class FisheyeNavigationBarItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const FisheyeNavigationBarItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

class FisheyeNavigationBar extends StatelessWidget {
  final List<FisheyeNavigationBarItem> items;
  final int currentIndex;
  final ValueChanged<int> onItemSelected;

  const FisheyeNavigationBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onItemSelected,
  }) : assert(items.length >= 2, 'Need at least two destinations');

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                colorScheme.surface.withOpacity(isDark ? 0.6 : 0.88),
                colorScheme.surfaceVariant.withOpacity(isDark ? 0.42 : 0.72),
              ],
            ),
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(isDark ? 0.28 : 0.24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.32 : 0.14),
                blurRadius: 24,
                offset: const Offset(0, 14),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: SizedBox(
                height: 56,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (int index = 0; index < items.length; index++)
                      _FisheyeItem(
                        item: items[index],
                        index: index,
                        currentIndex: currentIndex,
                        onTap: () => onItemSelected(index),
                        colorScheme: colorScheme,
                        isDark: isDark,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FisheyeItem extends StatelessWidget {
  final FisheyeNavigationBarItem item;
  final int index;
  final int currentIndex;
  final VoidCallback onTap;
  final ColorScheme colorScheme;
  final bool isDark;

  const _FisheyeItem({
    required this.item,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    required this.colorScheme,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final distance = (currentIndex - index).abs();
    final bool isSelected = distance == 0;
    final bool isNeighbor = distance == 1;

    final double targetScale = isSelected
        ? 1.1
        : isNeighbor
            ? 1.04
            : 0.96;
    final double targetYOffset = isSelected
        ? -6
        : isNeighbor
            ? -3
            : 0;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 1, end: targetScale),
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          builder: (context, scale, child) {
            return TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: targetYOffset),
              duration: const Duration(milliseconds: 340),
              curve: Curves.easeOutCubic,
              builder: (context, offset, child) {
                return Transform.translate(
                  offset: Offset(0, offset),
                  child: Transform.scale(
                    scale: scale,
                    child: child,
                  ),
                );
              },
              child: child,
            );
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: EdgeInsets.symmetric(
              horizontal: isSelected ? 18 : 0,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? colorScheme.primary.withOpacity(isDark ? 0.28 : 0.18)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: isSelected
                    ? colorScheme.primary.withOpacity(isDark ? 0.4 : 0.28)
                    : Colors.transparent,
              ),
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              switchInCurve: Curves.easeOut,
              switchOutCurve: Curves.easeIn,
              layoutBuilder: (currentChild, previousChildren) {
                return Stack(
                  alignment: Alignment.center,
                  children: <Widget>[
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                );
              },
              child: isSelected
                  ? _SelectedNavContent(
                      key: const ValueKey('selected'),
                      item: item,
                      colorScheme: colorScheme,
                    )
                  : _UnselectedNavContent(
                      key: const ValueKey('unselected'),
                      item: item,
                      isNeighbor: isNeighbor,
                      colorScheme: colorScheme,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SelectedNavContent extends StatelessWidget {
  final FisheyeNavigationBarItem item;
  final ColorScheme colorScheme;

  const _SelectedNavContent({
    super.key,
    required this.item,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          item.selectedIcon,
          size: 22,
          color: colorScheme.onPrimary,
        ),
        const SizedBox(width: 8),
        Text(
          item.label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: colorScheme.onPrimary,
            letterSpacing: 0.2,
          ),
        ),
      ],
    );
  }
}

class _UnselectedNavContent extends StatelessWidget {
  final FisheyeNavigationBarItem item;
  final bool isNeighbor;
  final ColorScheme colorScheme;

  const _UnselectedNavContent({
    super.key,
    required this.item,
    required this.isNeighbor,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final Color iconColor = Color.lerp(
          colorScheme.onSurfaceVariant.withOpacity(0.6),
          colorScheme.onSurface.withOpacity(0.9),
          isNeighbor ? 0.7 : 0,
        ) ??
        colorScheme.onSurfaceVariant;

    final Color textColor = iconColor.withOpacity(isNeighbor ? 0.95 : 0.78);

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          item.icon,
          size: 22,
          color: iconColor,
        ),
        const SizedBox(height: 4),
        Text(
          item.label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: textColor,
            letterSpacing: 0.1,
          ),
        ),
      ],
    );
  }
}
