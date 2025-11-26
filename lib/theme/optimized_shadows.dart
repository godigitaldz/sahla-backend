import 'package:flutter/material.dart';

/// Optimized shadow utilities to reduce overdraw and improve performance
/// Pre-computed shadows are more efficient than creating new ones on each build
class OptimizedShadows {
  OptimizedShadows._();

  // CARD SHADOWS - Single shadow for better performance
  static const cardShadowLight = BoxShadow(
    color: Color(0x14000000), // black.withValues(alpha: 0.08)
    spreadRadius: 0,
    blurRadius: 8,
    offset: Offset(0, 2),
  );

  static const cardShadowMedium = BoxShadow(
    color: Color(0x1A000000), // black.withValues(alpha: 0.10)
    spreadRadius: 0,
    blurRadius: 12,
    offset: Offset(0, 4),
  );

  static const cardShadowHeavy = BoxShadow(
    color: Color(0x26000000), // black.withValues(alpha: 0.15)
    spreadRadius: 0,
    blurRadius: 16,
    offset: Offset(0, 6),
  );

  // BUTTON SHADOWS
  static const buttonShadow = BoxShadow(
    color: Color(0x26000000), // black.withValues(alpha: 0.15)
    spreadRadius: 0,
    blurRadius: 6,
    offset: Offset(0, 2),
  );

  static const buttonShadowPressed = BoxShadow(
    color: Color(0x14000000), // black.withValues(alpha: 0.08)
    spreadRadius: 0,
    blurRadius: 3,
    offset: Offset(0, 1),
  );

  // FLOATING ACTION BUTTON SHADOWS
  static const fabShadow = BoxShadow(
    color: Color(0x26000000), // black.withValues(alpha: 0.15)
    spreadRadius: 2,
    blurRadius: 8,
    offset: Offset(0, 4),
  );

  // CHIP SHADOWS
  static const chipShadow = BoxShadow(
    color: Color(0x0A000000), // black.withValues(alpha: 0.04)
    spreadRadius: 0,
    blurRadius: 4,
    offset: Offset(0, 2),
  );

  // IMAGE SHADOWS
  static const imageShadowLight = BoxShadow(
    color: Color(0x1A000000), // black.withValues(alpha: 0.10)
    blurRadius: 8,
    offset: Offset(0, 4),
    spreadRadius: 0,
  );

  // APP BAR SHADOW
  static const appBarShadow = BoxShadow(
    color: Color(0x14000000), // black.withValues(alpha: 0.08)
    blurRadius: 4,
    offset: Offset(0, 2),
  );

  // MODAL SHADOWS
  static const modalShadow = BoxShadow(
    color: Color(0x33000000), // black.withValues(alpha: 0.20)
    spreadRadius: 0,
    blurRadius: 24,
    offset: Offset(0, 8),
  );

  // COMBINED SHADOWS (use sparingly - prefer single shadow)
  static const List<BoxShadow> cardShadowLayered = [
    BoxShadow(
      color: Color(0x14000000), // black.withValues(alpha: 0.08)
      spreadRadius: 0,
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> fabShadowLayered = [
    BoxShadow(
      color: Color(0x26000000), // black.withValues(alpha: 0.15)
      spreadRadius: 2,
      blurRadius: 8,
      offset: Offset(0, 4),
    ),
  ];

  /// Helper method to get shadow based on elevation level
  /// Returns single shadow for better performance
  static BoxShadow getShadowForElevation(int elevation) {
    switch (elevation) {
      case 1:
        return cardShadowLight;
      case 2:
        return cardShadowMedium;
      case 3:
      case 4:
        return cardShadowHeavy;
      default:
        return cardShadowMedium;
    }
  }

  /// Create a custom optimized shadow
  static BoxShadow createOptimizedShadow({
    required double opacity, // 0.0 to 1.0
    required double blurRadius,
    Offset offset = const Offset(0, 2),
    double spreadRadius = 0,
  }) {
    // Clamp opacity to valid range
    final clampedOpacity = opacity.clamp(0.0, 1.0);

    // Convert opacity to alpha value (0-255)
    final alpha = (clampedOpacity * 255).round();

    return BoxShadow(
      color: Color.fromARGB(alpha, 0, 0, 0),
      blurRadius: blurRadius,
      offset: offset,
      spreadRadius: spreadRadius,
    );
  }
}

/// Extension on BoxDecoration for easy shadow application
extension BoxDecorationShadows on BoxDecoration {
  /// Create a copy with optimized shadow
  BoxDecoration withOptimizedShadow({
    int elevation = 2,
  }) {
    return copyWith(
      boxShadow: [OptimizedShadows.getShadowForElevation(elevation)],
    );
  }
}

/// Helper widget to wrap content with optimized shadows
class OptimizedShadowContainer extends StatelessWidget {
  const OptimizedShadowContainer({
    required this.child,
    super.key,
    this.elevation = 2,
    this.borderRadius,
    this.color = Colors.white,
  });

  final Widget child;
  final int elevation;
  final BorderRadius? borderRadius;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        borderRadius: borderRadius ?? BorderRadius.circular(8),
        boxShadow: [OptimizedShadows.getShadowForElevation(elevation)],
      ),
      child: child,
    );
  }
}
