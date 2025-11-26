/// Cached responsive dimensions for menu item cards
/// Calculate once per screen size to avoid expensive MediaQuery lookups
class CachedMenuItemDimensions {
  // Core dimensions
  final double screenWidth;
  final bool isSmallScreen;

  // Layout dimensions
  final double horizontalPadding;
  final double cardSpacing;
  final double cardBottomMargin;
  final double cardWidth;
  final double cardHeight;
  final double borderRadius;

  // Font sizes
  final double priceFontSize;
  final double nameFontSize;
  final double restaurantFontSize;

  // Padding/spacing
  final double detailsPadding;
  final double verticalSpacing1;
  final double verticalSpacing2;

  const CachedMenuItemDimensions._({
    required this.screenWidth,
    required this.isSmallScreen,
    required this.horizontalPadding,
    required this.cardSpacing,
    required this.cardBottomMargin,
    required this.cardWidth,
    required this.cardHeight,
    required this.borderRadius,
    required this.priceFontSize,
    required this.nameFontSize,
    required this.restaurantFontSize,
    required this.detailsPadding,
    required this.verticalSpacing1,
    required this.verticalSpacing2,
  });

  /// Factory to calculate all responsive dimensions from screen width
  factory CachedMenuItemDimensions.fromScreenWidth(double screenWidth) {
    // Responsive breakpoints
    final bool isSmallScreen = screenWidth < 360;

    // Responsive padding and spacing
    final double horizontalPadding = isSmallScreen ? 16.0 : 32.0;
    final double cardSpacing = isSmallScreen ? 12.0 : 24.0;
    final double cardBottomMargin = isSmallScreen ? 8.0 : 12.0;

    // Calculate card width: maintain 3.0 cards per screen width
    final double availableWidth = screenWidth - horizontalPadding - cardSpacing;
    final double cardWidth = availableWidth / 3.0;

    // Responsive border radius
    final double borderRadius = isSmallScreen ? 10.0 : 12.0;

    // Responsive font sizes
    final double priceFontSize = isSmallScreen ? 12.0 : 14.0;
    final double nameFontSize = isSmallScreen ? 10.0 : 12.0;
    final double restaurantFontSize = isSmallScreen ? 8.0 : 10.0;

    // Responsive padding
    final double detailsPadding = isSmallScreen ? 6.0 : 8.0;
    final double verticalSpacing1 = isSmallScreen ? 2.0 : 4.0;
    final double verticalSpacing2 = isSmallScreen ? 1.0 : 2.0;

    // Calculate responsive height based on content, not fixed aspect ratio
    // Image section: AspectRatio 1.2 means width/height = 1.2, so height = width/1.2
    final double imageHeight = cardWidth / 1.2;
    // Details section: padding (top + bottom) + price + spacing + name + spacing + restaurant (if exists)
    final double detailsPaddingTotal = detailsPadding * 2; // top + bottom
    final double priceHeight = priceFontSize * 1.0; // height: 1.0
    final double nameHeight = nameFontSize * 1.2; // with line height
    final double restaurantHeight = restaurantFontSize * 1.2; // with line height
    final double detailsHeight = detailsPaddingTotal +
        priceHeight +
        verticalSpacing1 +
        nameHeight +
        verticalSpacing2 +
        restaurantHeight; // Include restaurant for max height calculation
    // Total card height: image + details
    final double cardHeight = imageHeight + detailsHeight;

    return CachedMenuItemDimensions._(
      screenWidth: screenWidth,
      isSmallScreen: isSmallScreen,
      horizontalPadding: horizontalPadding,
      cardSpacing: cardSpacing,
      cardBottomMargin: cardBottomMargin,
      cardWidth: cardWidth,
      cardHeight: cardHeight,
      borderRadius: borderRadius,
      priceFontSize: priceFontSize,
      nameFontSize: nameFontSize,
      restaurantFontSize: restaurantFontSize,
      detailsPadding: detailsPadding,
      verticalSpacing1: verticalSpacing1,
      verticalSpacing2: verticalSpacing2,
    );
  }
}
