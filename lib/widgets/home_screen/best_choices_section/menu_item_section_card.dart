import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/menu_item.dart';
import '../../../utils/price_formatter.dart';
import '../../../widgets/menu_item_full_popup/helpers/special_pack_helper.dart';
import 'cached_menu_item_dimensions.dart';

/// Menu item card widget for home screen's menu items section
/// Performance improvements:
/// - Accepts pre-calculated dimensions (eliminates MediaQuery calls)
/// - StatelessWidget (no setState overhead)
/// - Image size constraints (prevents full resolution decoding)
class MenuItemSectionCard extends StatelessWidget {
  const MenuItemSectionCard({
    required this.menuItem,
    required this.onTap,
    required this.dimensions,
    this.variantName,
    super.key,
  });

  final MenuItem menuItem;
  final VoidCallback onTap;
  final CachedMenuItemDimensions dimensions; // Pre-calculated dimensions!
  final String? variantName; // Optional variant name for card display

  @override
  Widget build(BuildContext context) {
    // Detect text direction for RTL support
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    // Check if this is a special pack
    final isSpecialPack = SpecialPackHelper.isSpecialPack(menuItem);

    // Get display name (with variant if provided)
    final displayName = variantName != null && variantName!.isNotEmpty
        ? '${menuItem.name} - $variantName'
        : menuItem.name;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: dimensions.cardWidth,
        // Special pack cards use original fixed aspect ratio (1.65), regular cards use responsive height
        height: isSpecialPack ? dimensions.cardWidth * 1.65 : dimensions.cardHeight,
        // Remove bottom margin - cards are in horizontal ListView, not vertical
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(dimensions.borderRadius),
        ),
        child: isSpecialPack
            ? _buildSpecialPackCard(isRTL, dimensions)
            : _buildRegularCard(isRTL, dimensions, displayName),
      ),
    );
  }

  Widget _buildSpecialPackCard(bool isRTL, CachedMenuItemDimensions dimensions) {
    return Builder(
      builder: (context) => Column(
        crossAxisAlignment:
            isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.max,
        children: [
          // Image section with price overlay for special packs
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(dimensions.borderRadius),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Image
                  CachedNetworkImage(
                    imageUrl: menuItem.image,
                    width: double.infinity,
                    height: double.infinity,
                    fit: BoxFit.cover,
                    // PERFORMANCE: Decode at 2x card size (not full resolution!)
                    memCacheWidth: (dimensions.cardWidth * 2).round(),
                    memCacheHeight: (dimensions.cardHeight * 2).round(),
                    maxWidthDiskCache: (dimensions.cardWidth * 2).round(),
                    maxHeightDiskCache: (dimensions.cardHeight * 2).round(),
                    // Performance: Disable fade animation
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                    // Performance: Use low quality for thumbnails
                    filterQuality: FilterQuality.low,
                    placeholder: (context, url) => Shimmer.fromColors(
                      baseColor: Colors.grey[300]!,
                      highlightColor: Colors.grey[100]!,
                      period: const Duration(milliseconds: 1500),
                      child: Container(
                        color: Colors.grey[300],
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[300],
                      child: const Icon(Icons.restaurant, color: Colors.grey),
                    ),
                  ),
                  // Price overlay for special packs (top right)
                  Positioned(
                    top: 8,
                    right: isRTL ? null : 8,
                    left: isRTL ? 8 : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        PriceFormatter.formatWithSettings(
                          context,
                          menuItem.price.toStringAsFixed(0),
                        ),
                        style: GoogleFonts.poppins(
                          fontSize: dimensions.priceFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[600],
                          height: 1.0,
                        ),
                        textDirection:
                            isRTL ? TextDirection.rtl : TextDirection.ltr,
                      ),
                    ),
                  ),
                  // Order Now chip for special packs (bottom right) - same style as min order chip
                  Positioned(
                    bottom: 4, // Little bottom padding
                    right: isRTL ? null : 8,
                    left: isRTL ? 8 : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5), // Dark with low transparency for visibility on all backgrounds
                        borderRadius: BorderRadius.circular(12), // Fully rounded
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.center,
                        child: Text(
                          'Order Now',
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: Colors.white, // White text is visible on dark background
                          ),
                          textAlign: TextAlign.center,
                          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // For special packs, only show restaurant name if available
          if (menuItem.restaurantName != null)
            Padding(
              padding: EdgeInsetsDirectional.all(dimensions.detailsPadding),
              child: Text(
                menuItem.restaurantName!,
                style: GoogleFonts.poppins(
                  fontSize: dimensions.restaurantFontSize,
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: isRTL ? TextAlign.right : TextAlign.left,
                textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRegularCard(bool isRTL, CachedMenuItemDimensions dimensions, String displayName) {
    return Builder(
      builder: (context) {
        // Calculate image height based on AspectRatio 1.2 (width/height = 1.2, so height = width/1.2)
        final imageHeight = dimensions.cardWidth / 1.2;

        return Column(
          crossAxisAlignment:
              isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.max,
          children: [
            // Image section - use Expanded to fill remaining space after details
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(dimensions.borderRadius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Image
                    CachedNetworkImage(
                      imageUrl: menuItem.image,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      // PERFORMANCE: Decode at 2x card size (not full resolution!)
                      memCacheWidth: (dimensions.cardWidth * 2).round(),
                      memCacheHeight: (imageHeight * 2).round(),
                      maxWidthDiskCache: (dimensions.cardWidth * 2).round(),
                      maxHeightDiskCache: (imageHeight * 2).round(),
                      // Performance: Disable fade animation
                      fadeInDuration: Duration.zero,
                      fadeOutDuration: Duration.zero,
                      // Performance: Use low quality for thumbnails
                      filterQuality: FilterQuality.low,
                      placeholder: (context, url) => Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        period: const Duration(milliseconds: 1500),
                        child: Container(
                          color: Colors.grey[300],
                        ),
                      ),
                      errorWidget: (context, url, error) => Container(
                        color: Colors.grey[300],
                        child: const Icon(Icons.restaurant, color: Colors.grey),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Details section - fits content naturally, no extra spacing
            Padding(
              padding: EdgeInsetsDirectional.all(dimensions.detailsPadding),
              child: Column(
                crossAxisAlignment: isRTL
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Price with localized currency
                  Text(
                    PriceFormatter.formatWithSettings(
                      context,
                      menuItem.price.toStringAsFixed(0),
                    ),
                    style: GoogleFonts.poppins(
                      fontSize: dimensions.priceFontSize,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[600],
                      height: 1.0,
                    ),
                    textDirection:
                        isRTL ? TextDirection.rtl : TextDirection.ltr,
                    textAlign: isRTL ? TextAlign.right : TextAlign.left,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),

                  SizedBox(height: dimensions.verticalSpacing1),

                  // Item name (handles +16 characters with responsive font, single line)
                  Text(
                    displayName,
                    style: GoogleFonts.poppins(
                      fontSize: dimensions.nameFontSize,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: isRTL ? TextAlign.right : TextAlign.left,
                    textDirection:
                        isRTL ? TextDirection.rtl : TextDirection.ltr,
                  ),

                  if (menuItem.restaurantName != null) ...[
                    SizedBox(height: dimensions.verticalSpacing2),
                    // Restaurant name with responsive font
                    Text(
                      menuItem.restaurantName!,
                      style: GoogleFonts.poppins(
                        fontSize: dimensions.restaurantFontSize,
                        color: Colors.grey[600],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: isRTL ? TextAlign.right : TextAlign.left,
                      textDirection:
                          isRTL ? TextDirection.rtl : TextDirection.ltr,
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
