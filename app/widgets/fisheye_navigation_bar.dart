import 'dart:math' as math;
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
                colorScheme.surface.withOpacity(isDark ? 0.76 : 0.92),
                colorScheme.surfaceVariant.withOpacity(isDark ? 0.6 : 0.78),
              ],
            ),
            border: Border.all(
              color: colorScheme.outlineVariant.withOpacity(isDark ? 0.35 : 0.28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.45 : 0.18),
                blurRadius: 30,
                offset: const Offset(0, 18),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: 86,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double itemExtent = constraints.maxWidth / items.length;
                  final double alignmentStep = items.length == 1
                      ? 0
                      : 2 / (items.length - 1);

                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      AnimatedAlign(
                        duration: const Duration(milliseconds: 420),
                        curve: Curves.easeOutCubic,
                        alignment: Alignment(
                          -1 + alignmentStep * currentIndex,
                          0,
                        ),
                        child: Container(
                          width: math.max(itemExtent * 0.78, 86),
                          height: 56,
                          decoration: BoxDecoration(
                            color: colorScheme.primary.withOpacity(isDark ? 0.22 : 0.16),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: colorScheme.primary.withOpacity(isDark ? 0.32 : 0.24),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: colorScheme.primary.withOpacity(isDark ? 0.3 : 0.18),
                                blurRadius: 22,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (int index = 0; index < items.length; index++)
                            _FisheyeItem(
                              item: items[index],
                              index: index,
                              currentIndex: currentIndex,
                              onTap: () => onItemSelected(index),
                              colorScheme: colorScheme,
                            ),
                        ],
                      ),
                    ],
                  );
                },
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

  const _FisheyeItem({
    required this.item,
    required this.index,
    required this.currentIndex,
    required this.onTap,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final distance = (currentIndex - index).abs();
    final bool isSelected = distance == 0;
    final bool isNeighbor = distance == 1;

    final double targetScale = isSelected
        ? 1.35
        : isNeighbor
            ? 1.12
            : 0.98;
    final double targetYOffset = isSelected
        ? -14
        : isNeighbor
            ? -6
            : 0;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 1, end: targetScale),
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutBack,
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? item.selectedIcon : item.icon,
                size: 26,
                color: isSelected
                    ? colorScheme.onPrimary
                    : colorScheme.onSurfaceVariant,
              ),
              const SizedBox(height: 6),
              AnimatedOpacity(
                opacity: isSelected ? 1 : (isNeighbor ? 0.75 : 0),
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOut,
                child: AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOut,
                  style: TextStyle(
                    fontSize: isSelected ? 12 : 10,
                    fontWeight: FontWeight.w600,
                    color: colorScheme.onPrimary,
                    letterSpacing: 0.2,
                  ),
                  child: Text(item.label),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
