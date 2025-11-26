import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';

import '../../features/reviews/ui/reviews_screen.dart';
import '../../l10n/app_localizations.dart';
import '../../models/menu_item.dart';
import '../../utils/price_formatter.dart';
import '../../widgets/menu_item_full_popup/helpers/special_pack_helper.dart';
import '../../widgets/menu_items_list_screen/components/menu_item_name_display.dart';

/// Optimized menu item card widget with cached network images
/// Extracted from RestaurantDetailsScreen for better performance and reusability
class MenuItemCard extends StatelessWidget {
  const MenuItemCard({
    required this.menuItem,
    required this.onTap,
    super.key,
  });

  final MenuItem menuItem;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Detect text direction for RTL support
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    // Process menu item for display - format special pack names to match menu item list screen
    final displayItem = SpecialPackHelper.processForDisplay(menuItem);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
              children: [
                // Menu item details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Use MenuItemNameDisplay to match menu item list screen styling
                      MenuItemNameDisplay(
                        name: displayItem.name,
                        fontSize: 14,
                        isRTL: isRTL,
                      ),
                      const SizedBox(height: 8),

                      // Rating only
                      Row(
                        textDirection:
                            isRTL ? TextDirection.rtl : TextDirection.ltr,
                        children: [
                          // PERFORMANCE: Memoize rating stars to avoid rebuilding on every build
                          _RatingStars(rating: menuItem.rating),
                          const SizedBox(width: 4),
                          Text(
                            "(${menuItem.reviewCount})",
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 4),
                          // View all reviews button
                          GestureDetector(
                            onTap: () {
                              if (menuItem.restaurantId.isNotEmpty) {
                                // Extract base name (remove variant suffix like "Small", "Medium", etc.)
                                // Variants are stored in DB with their base name only
                                String baseName = menuItem.name;
                                // If item has variants, the name format is: "Base Name VariantName"
                                // We want just "Base Name" to match DB records
                                if (menuItem.variants.isEmpty &&
                                    menuItem.name.contains(' ')) {
                                  // This is a variant card (no variants array, space in name)
                                  // Keep only the part before the last word (which is the variant)
                                  final parts = menuItem.name.split(' ');
                                  if (parts.length > 1) {
                                    baseName = parts
                                        .sublist(0, parts.length - 1)
                                        .join(' ');
                                  }
                                }

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => ReviewsScreen(
                                      restaurantId: menuItem.restaurantId,
                                      restaurantName: menuItem.restaurantName ??
                                          'Restaurant',
                                      initialSelectedMenuItem: baseName,
                                    ),
                                  ),
                                );
                              }
                            },
                            child: Text(
                              '(${AppLocalizations.of(context)!.viewAllReviews})',
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      // Price and preparation time in white container with border
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          textDirection:
                              isRTL ? TextDirection.rtl : TextDirection.ltr,
                          children: [
                            // Price (localized)
                            Text(
                              PriceFormatter.formatWithSettings(
                                  context, menuItem.price.toStringAsFixed(0)),
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Separator
                            Container(
                              width: 1,
                              height: 14,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(width: 8),
                            // Preparation time
                            Icon(
                              Icons.access_time,
                              size: 14,
                              color: Colors.grey[700],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              "${menuItem.preparationTime} ${AppLocalizations.of(context)!.min}",
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(width: 10),

                // Boxed image with rounded corners
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CachedNetworkImage(
                    imageUrl: menuItem.image,
                    width: 110,
                    height: 110,
                    fit: BoxFit.cover,
                    // PERFORMANCE: Optimize image cache - use 2x instead of 3x for better performance
                    // 110 * 2 = 220, rounded to 220 for memory efficiency
                    memCacheWidth: 220,
                    memCacheHeight: 220,
                    maxWidthDiskCache: 400,
                    maxHeightDiskCache: 400,
                    // PERFORMANCE: Use low filter quality for thumbnails to reduce rasterization cost
                    filterQuality: FilterQuality.low,
                    placeholder: (context, url) => ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        period: const Duration(milliseconds: 1500),
                        child: Container(
                          width: 110,
                          height: 110,
                          color: Colors.grey[300],
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 110,
                      height: 110,
                      color: Colors.grey[300],
                      child: const Icon(Icons.restaurant,
                          color: Colors.grey, size: 40),
                    ),
                    // PERFORMANCE: Disable fade animations for list items (causes jank during scroll)
                    fadeInDuration: Duration.zero,
                    fadeOutDuration: Duration.zero,
                  ),
                ),
              ],
            ),
          ),
          // Divider line
          Divider(
            height: 1,
            thickness: 1,
            color: Colors.grey[300],
            indent: 0,
            endIndent: 0,
          ),
        ],
      ),
    );
  }
}

/// PERFORMANCE: Memoized rating stars widget to avoid rebuilding on every build
/// Uses const constructors where possible for optimal performance
class _RatingStars extends StatelessWidget {
  const _RatingStars({required this.rating});

  final double rating;

  @override
  Widget build(BuildContext context) {
    // PERFORMANCE: Pre-compute star icons once, avoid generating on every build
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final starValue = index + 1;

        if (rating >= starValue) {
          // Full star
          return const Icon(
            Icons.star,
            size: 14,
            color: Colors.amber,
          );
        } else if (rating >= starValue - 0.5) {
          // Half star
          return const Icon(
            Icons.star_half,
            size: 14,
            color: Colors.amber,
          );
        } else {
          // Empty star
          return const Icon(
            Icons.star_border,
            size: 14,
            color: Colors.amber,
          );
        }
      }),
    );
  }
}
