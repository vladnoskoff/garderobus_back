import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class ImageCacheService {
  static final CacheManager _cacheManager = CacheManager(
    Config(
      'garderobusImageCache',
      stalePeriod: const Duration(days: 14),
      maxNrOfCacheObjects: 120,
    ),
  );

  static Widget cached(
    String url, {
    BoxFit fit = BoxFit.cover,
    double? width,
    double? height,
    double borderRadius = 16,
    Widget? placeholder,
    Widget? errorWidget,
    Alignment alignment = Alignment.center,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: CachedNetworkImage(
        imageUrl: url,
        cacheManager: _cacheManager,
        fit: fit,
        width: width,
        height: height,
        alignment: alignment,
        memCacheHeight: 1600,
        memCacheWidth: 1600,
        maxHeightDiskCache: 1400,
        maxWidthDiskCache: 1400,
        placeholder: (_, __) => placeholder ??
            Container(
              color: Colors.black12,
              alignment: Alignment.center,
              child: const CircularProgressIndicator(strokeWidth: 2),
            ),
        errorWidget: (_, __, ___) => errorWidget ??
            const Icon(
              Icons.broken_image_outlined,
              size: 40,
              color: Colors.grey,
            ),
      ),
    );
  }
}
