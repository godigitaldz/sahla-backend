import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/menu_item.dart';
import '../../../models/restaurant.dart';
import '../../../screens/photo_view_gallery_screen.dart';
import '../../../services/menu_item_image_service.dart';

// ============================================================================
// Menu Item Info Container
// ============================================================================

/// Shared info container widget for all menu item popups
/// Shows prep time, rating, and restaurant name
class MenuItemInfoContainer extends StatelessWidget {
  final MenuItem menuItem;
  final Restaurant? restaurant;
  final double? updatedRating;
  final int? updatedReviewCount;

  const MenuItemInfoContainer({
    required this.menuItem,
    super.key,
    this.restaurant,
    this.updatedRating,
    this.updatedReviewCount,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final prepTime = menuItem.preparationTime;
    final rating = updatedRating ?? menuItem.rating;
    final reviewCount = updatedReviewCount ?? menuItem.reviewCount;
    final restaurantName = menuItem.restaurantName ?? restaurant?.name ?? '';
    final isRTL = Localizations.localeOf(context).languageCode == 'ar';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
        children: [
          // Prep time
          if (prepTime > 0) ...[
            Icon(Icons.access_time, size: 16, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              '$prepTime ${l10n.min}',
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500,
              ),
              textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
            ),
            const SizedBox(width: 12),
            Container(
              width: 1,
              height: 14,
              color: Colors.grey[300],
            ),
            const SizedBox(width: 12),
          ],

          // Reviews with star
          Icon(Icons.star, size: 16, color: Colors.amber[600]),
          const SizedBox(width: 4),
          Text(
            rating > 0 ? rating.toStringAsFixed(1) : '0.0',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey[700],
              fontWeight: FontWeight.w600,
            ),
            textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
          ),
          Text(
            ' ($reviewCount)',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey[600],
              fontWeight: FontWeight.w400,
            ),
            textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
          ),

          // Separator
          if (restaurantName.isNotEmpty) ...[
            const SizedBox(width: 12),
            Container(
              width: 1,
              height: 14,
              color: Colors.grey[300],
            ),
            const SizedBox(width: 12),

            // Restaurant name
            Flexible(
              child: Text(
                restaurantName,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// Menu Item Image Section
// ============================================================================

/// Shared image section widget for all menu item popups
/// Displays scrollable image gallery with page indicators and tap-to-view
class MenuItemImageSection extends StatelessWidget {
  final MenuItem menuItem;
  final PageController? imagePageController;
  final int currentImagePage;
  final ValueChanged<int> onPageChanged;
  final List<Widget>? additionalOverlays; // For LTO badges, etc.

  const MenuItemImageSection({
    required this.menuItem,
    required this.currentImagePage,
    required this.onPageChanged,
    super.key,
    this.imagePageController,
    this.additionalOverlays,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    // Get all images for the gallery
    final List<String> allImages = menuItem.images.isNotEmpty
        ? menuItem.images
            .map((img) => MenuItemImageService().ensureImageUrl(img))
            .toList()
        : (menuItem.image.isNotEmpty
            ? [MenuItemImageService().ensureImageUrl(menuItem.image)]
            : []);

    return SizedBox(
      width: double.infinity,
      height: screenWidth * 0.4, // 40% of screen width for height
      child: Stack(
        children: [
          // PageView for scrollable images
          ClipRRect(
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
            child: allImages.isEmpty
                ? Container(
                    color: Colors.grey[200],
                    child: Center(
                      child: Icon(
                        Icons.restaurant,
                        size: screenWidth * 0.15,
                        color: Colors.grey,
                      ),
                    ),
                  )
                : PageView.builder(
                    controller: imagePageController,
                    onPageChanged: onPageChanged,
                    itemCount: allImages.length,
                    itemBuilder: (context, index) {
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PhotoViewGalleryScreen(
                                images: allImages,
                                initialIndex: index,
                              ),
                            ),
                          );
                        },
                        child: CachedNetworkImage(
                          imageUrl: allImages[index],
                          fit: BoxFit.cover,
                          // CACHE FIX: Add cache key with menu item ID and updated timestamp
                          // This ensures the image refreshes when the menu item is updated
                          // Also include image URL hash to force refresh when image URL changes
                          cacheKey: '${menuItem.id}_${menuItem.updatedAt.millisecondsSinceEpoch}_${allImages[index].hashCode}_$index',
                          // PERFORMANCE FIX: Calculate optimal cache size based on screen width
                          // Image height is 40% of screen width, use 2x for retina displays
                          memCacheWidth: (screenWidth * 2).round(),
                          memCacheHeight: ((screenWidth * 0.4) * 2).round(),
                          // PERFORMANCE FIX: Disable fade for smooth scrolling (no cross-fade jank)
                          fadeInDuration: Duration.zero,
                          // PERFORMANCE FIX: Use low filter quality for thumbnails to reduce raster cost
                          filterQuality: FilterQuality.low,
                          placeholder: (context, url) => Container(
                            color: Colors.grey[200],
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                          errorWidget: (context, url, error) => Container(
                            color: Colors.grey[200],
                            child: Center(
                              child: Icon(
                                Icons.restaurant,
                                size: screenWidth * 0.15,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Gradient overlay at bottom
          if (allImages.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.7),
                    ],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
              ),
            ),

          // Additional overlays (e.g., LTO badges)
          if (additionalOverlays != null) ...additionalOverlays!,

          // "Tap to view" indicator (bottom-left, icon only)
          if (allImages.isNotEmpty)
            Positioned(
              bottom: 12,
              left: 12,
              child: GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PhotoViewGalleryScreen(
                        images: allImages,
                        initialIndex: currentImagePage,
                      ),
                    ),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.8),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.zoom_out_map,
                    color: Colors.white,
                    size: 18,
                  ),
                ),
              ),
            ),

          // Page indicators (bottom-middle)
          if (allImages.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    // PERFORMANCE FIX: For small lists (<10), List.generate is acceptable
                    // Each indicator is wrapped in RepaintBoundary to isolate repaints
                    children: List.generate(
                      allImages.length,
                      (index) => RepaintBoundary(
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: currentImagePage == index
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
