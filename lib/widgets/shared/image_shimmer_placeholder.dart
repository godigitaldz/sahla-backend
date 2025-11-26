import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Professional shimmer placeholder for images
/// Replaces circular loading indicators with a polished skeleton effect
class ImageShimmerPlaceholder extends StatelessWidget {
  const ImageShimmerPlaceholder({
    required this.width,
    required this.height,
    this.borderRadius,
    this.baseColor,
    this.highlightColor,
    super.key,
  });

  final double width;
  final double height;
  final BorderRadius? borderRadius;
  final Color? baseColor;
  final Color? highlightColor;

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? BorderRadius.circular(12);
    final base = baseColor ?? Colors.grey[300]!;
    final highlight = highlightColor ?? Colors.grey[100]!;

    return ClipRRect(
      borderRadius: radius,
      child: Shimmer.fromColors(
        baseColor: base,
        highlightColor: highlight,
        period: const Duration(milliseconds: 1500),
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: base,
            borderRadius: radius,
            // Subtle gradient for depth
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                base,
                base.withOpacity(0.8),
                base,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact shimmer placeholder for small images (icons, thumbnails)
class CompactImageShimmerPlaceholder extends StatelessWidget {
  const CompactImageShimmerPlaceholder({
    required this.size,
    this.borderRadius,
    super.key,
  });

  final double size;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return ImageShimmerPlaceholder(
      width: size,
      height: size,
      borderRadius: borderRadius ?? BorderRadius.circular(8),
      baseColor: Colors.grey[250],
      highlightColor: Colors.white,
    );
  }
}
