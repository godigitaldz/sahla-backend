import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Isolated menu item image widget
/// RepaintBoundary prevents image loading from affecting parent
class MenuItemImage extends StatelessWidget {
  const MenuItemImage({
    required this.imageUrl,
    required this.itemId,
    required this.imageSize,
    super.key,
  });

  final String imageUrl;
  final String itemId;
  final double imageSize;

  static const _placeholderGrey = Color(0xFFEEEEEE);
  static const _iconGreyColor = Color(0xFF9E9E9E);

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.hardEdge,
        child: Container(
          width: imageSize,
          height: imageSize,
          color: Colors.grey[200],
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            width: imageSize,
            height: imageSize,
            fit: BoxFit.cover,
            // Improved cache size for better quality
            memCacheWidth: 300,
            memCacheHeight: 300,
            // CRITICAL: Remove ALL fade animations
            fadeInDuration: Duration.zero,
            fadeOutDuration: Duration.zero,
            // Professional shimmer placeholder
            placeholder: (context, url) => ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Shimmer.fromColors(
                baseColor: Colors.grey[300]!,
                highlightColor: Colors.grey[100]!,
                period: const Duration(milliseconds: 1500),
                child: Container(
                  width: imageSize,
                  height: imageSize,
                  color: Colors.grey[300],
                ),
              ),
            ),
            // Simple error widget - NO animations
            errorWidget: (context, url, error) => Container(
              width: imageSize,
              height: imageSize,
              color: _placeholderGrey,
              child: Icon(
                Icons.restaurant_menu,
                color: _iconGreyColor,
                size: imageSize * 0.35,
              ),
            ),
            // CACHE: Optimized settings with better quality
            cacheKey: 'mi_$itemId',
            maxWidthDiskCache: 400,
            maxHeightDiskCache: 400,
            // Use cached image immediately
            useOldImageOnUrlChange: true,
            // Medium quality filter for balance between quality and speed
            filterQuality: FilterQuality.medium,
          ),
        ),
      ),
    );
  }
}
