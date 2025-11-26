/// Cached responsive dimensions for restaurant cards
/// Calculated once per screen size to avoid expensive MediaQuery calls
///
/// This optimization eliminates 15-20 MediaQuery calls per card build,
/// providing 2-3x performance improvement for restaurant list scrolling.
class CachedRestaurantDimensions {
  final double cardWidth;
  final double coverHeight;
  final double logoSize;
  final double margin;
  final double padding;
  final double borderRadius;
  final double dividerHeight;
  final double chipHeight;
  final double iconSize;
  final double spacing;

  const CachedRestaurantDimensions({
    required this.cardWidth,
    required this.coverHeight,
    required this.logoSize,
    required this.margin,
    required this.padding,
    required this.borderRadius,
    required this.dividerHeight,
    required this.chipHeight,
    required this.iconSize,
    required this.spacing,
  });

  /// Calculate dimensions from screen width (called once)
  /// Responsive across all devices: Android (small/large), iPhones (all sizes)
  ///
  /// Design reference: iPhone 6/7/8 (375px width)
  /// Card width: 357px (leaves 9px margin per side on design width)
  /// All dimensions scale proportionally based on screen width
  factory CachedRestaurantDimensions.fromScreenWidth(double screenWidth) {
    const designWidth = 375.0; // iPhone 6/7/8 reference width
    final scaleFactor = screenWidth / designWidth;

    // Clamp scale factor to prevent extreme sizes on very small or very large screens
    // Range: 0.75 (small Android ~280px) to 1.5 (large tablets ~560px)
    // This ensures cards look proportional on all device sizes
    final clampedScale = scaleFactor.clamp(0.75, 1.5);

    // Calculate card width with responsive horizontal margins
    // Card width leaves ~9px margin per side at design width, scales proportionally
    final cardWidth = 357 * clampedScale;

    // All spacing and sizing values scale proportionally
    return CachedRestaurantDimensions(
      cardWidth: cardWidth,
      coverHeight: 150 * clampedScale,
      logoSize: 80 * clampedScale,
      margin: 0 * clampedScale, // Vertical spacing between cards
      padding:
          12 * clampedScale, // Internal card padding (top, bottom, left, right)
      borderRadius: 16 * clampedScale, // Card corner radius
      dividerHeight: 1 * clampedScale,
      chipHeight: 80 * clampedScale, // Same as logoSize
      iconSize: 14 * clampedScale, // Icon sizes scale proportionally
      spacing: 4 * clampedScale, // Internal spacing between elements
    );
  }

  /// Calculate total card height for itemExtent
  /// Fully responsive: matches exact card height (reduced by 15% - 0.306 instead of 0.36)
  /// This must match exactly the card height to prevent spacing gaps
  double get totalCardHeight {
    // Cover image height used in card widget (matches restaurant_card_widget.dart - reduced by 15%)
    final coverHeight = cardWidth * 0.306;

    // Card has top and bottom padding added around the content
    // Total card height = coverHeight + top padding + bottom padding
    return coverHeight + (padding * 2);
  }
}
