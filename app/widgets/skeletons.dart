import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class ShimmerSkeleton extends StatelessWidget {
  const ShimmerSkeleton({
    super.key,
    this.height,
    this.width,
    this.borderRadius = 12,
  });

  final double? height;
  final double? width;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final baseColor = colorScheme.surfaceVariant.withOpacity(0.35);
    final highlightColor = colorScheme.surfaceVariant.withOpacity(0.15);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
      ),
    );
  }
}

class HomeCardSkeleton extends StatelessWidget {
  const HomeCardSkeleton({
    super.key,
    this.lines = 2,
    this.hasMedia = true,
  });

  final int lines;
  final bool hasMedia;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: theme.shadowColor.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const ShimmerSkeleton(height: 40, width: 40, borderRadius: 14),
              const SizedBox(width: 12),
              const ShimmerSkeleton(height: 14, width: 120),
              const Spacer(),
              const ShimmerSkeleton(height: 12, width: 48),
            ],
          ),
          const SizedBox(height: 16),
          if (hasMedia) ...[
            const ShimmerSkeleton(height: 180, borderRadius: 18),
            const SizedBox(height: 14),
          ],
          for (var i = 0; i < lines; i++) ...[
            ShimmerSkeleton(
              height: 12,
              width: (MediaQuery.sizeOf(context).width * 0.6) - (i * 16),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class ListTileSkeleton extends StatelessWidget {
  const ListTileSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        ShimmerSkeleton(height: 60, width: 60, borderRadius: 16),
        SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ShimmerSkeleton(height: 12, width: 140),
              SizedBox(height: 8),
              ShimmerSkeleton(height: 12, width: 90),
            ],
          ),
        ),
      ],
    );
  }
}
