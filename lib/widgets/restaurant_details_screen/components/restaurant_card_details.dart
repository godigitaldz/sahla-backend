import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "../../../models/restaurant.dart";
import "../../../screens/restaurant_reviews_screen.dart";
import "restaurant_delivery_info.dart";
import "restaurant_status_badge.dart";

/// Restaurant details section with name, rating, and delivery information
///
/// Features:
/// - Restaurant name with proper overflow handling
/// - 5-star rating display with half-star support
/// - Tappable review count with navigation
/// - Status badge (opening/closing time)
/// - Delivery information badge with retry
/// - RTL support throughout
/// - Responsive font sizing for small screens
class RestaurantCardDetails extends StatelessWidget {
  final Restaurant restaurant;
  final bool isOpen;
  final String? openingTime;
  final String? closingTime;
  final bool isRTL;
  final VoidCallback? onRetryDeliveryFee;
  final double? availableWidth;
  final double? cardWidth;
  final bool showStatusBadge;

  const RestaurantCardDetails({
    required this.restaurant,
    required this.isOpen,
    super.key,
    this.openingTime,
    this.closingTime,
    this.isRTL = false,
    this.onRetryDeliveryFee,
    this.availableWidth,
    this.cardWidth,
    this.showStatusBadge = true,
  });

  @override
  Widget build(BuildContext context) {
    // Calculate responsive font sizes based on available width
    final width = availableWidth ?? 250;
    final nameFontSize =
        _getResponsiveFontSize(width, baseFontSize: 16, minFontSize: 12);
    final ratingFontSize =
        _getResponsiveFontSize(width, baseFontSize: 11, minFontSize: 9);

    // Calculate max width for delivery info (35% of card width)
    final deliveryInfoMaxWidth = (cardWidth ?? width) * 0.35;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Restaurant name
        _buildNameOnly(context, nameFontSize),

        // Status badge under name (if enabled)
        if (showStatusBadge) ...[
          const SizedBox(height: 6),
          _buildStatusBadge(),
        ],

        const SizedBox(height: 8),

        // Rating and reviews
        _buildRatingRow(context, ratingFontSize),
        const SizedBox(height: 10),

        // Delivery fee and time (constrained to 35% of card width)
        ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: deliveryInfoMaxWidth.clamp(120.0, 220.0),
          ),
          child: RestaurantDeliveryInfo(
            restaurantId: restaurant.id,
            baseDeliveryFee: restaurant.deliveryFee,
            estimatedDeliveryTime: restaurant.estimatedDeliveryTime,
            isRTL: isRTL,
            onRetry: onRetryDeliveryFee,
            availableWidth: width,
          ),
        ),
      ],
    );
  }

  /// Calculate responsive font size based on available width
  double _getResponsiveFontSize(double width,
      {required double baseFontSize, required double minFontSize}) {
    // Scale down font size for smaller screens
    if (width < 200) {
      return minFontSize;
    } else if (width < 250) {
      final scale = (width - 200) / 50;
      return minFontSize + (baseFontSize - minFontSize) * scale;
    }
    return baseFontSize;
  }

  /// Build restaurant name only
  Widget _buildNameOnly(BuildContext context, double fontSize) {
    return Text(
      restaurant.name,
      style: GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: FontWeight.w600,
        color: Colors.black87,
      ),
      maxLines: 1, // Single line for compact layout
      overflow: TextOverflow.ellipsis,
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
    );
  }

  /// Build status badge under name
  Widget _buildStatusBadge() {
    // Determine which time to show (closing or opening)
    final String? statusTime = isOpen ? closingTime : openingTime;

    if (statusTime == null) {
      return const SizedBox.shrink();
    }

    return RestaurantStatusBadge(
      isOpen: isOpen,
      time: statusTime,
      isRTL: isRTL,
    );
  }

  /// Build rating row with stars and review count
  Widget _buildRatingRow(BuildContext context, double fontSize) {
    final width = availableWidth ?? 250;

    return Row(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 5-star rating display
        ..._buildStarRating(),
        const SizedBox(width: 4),

        // Review count
        Text(
          "(${restaurant.reviewCount})",
          style: GoogleFonts.poppins(
            fontSize: fontSize,
            color: Colors.grey[600],
          ),
        ),
        const SizedBox(width: 6),

        // Tappable review text (Expanded to use remaining space - prevents ellipsis)
        Expanded(
          child: _buildReviewText(context, fontSize, width),
        ),
      ],
    );
  }

  /// Build 5-star rating with half-star support
  List<Widget> _buildStarRating() {
    return List.generate(5, (starIndex) {
      final rating = restaurant.rating;
      final starValue = starIndex + 1;

      if (rating >= starValue) {
        // Full star
        return Icon(
          Icons.star,
          size: 14,
          color: Colors.amber[600],
        );
      } else if (rating >= starValue - 0.5) {
        // Half star
        return Icon(
          Icons.star_half,
          size: 14,
          color: Colors.amber[600],
        );
      } else {
        // Empty star
        return Icon(
          Icons.star_border,
          size: 14,
          color: Colors.amber[600],
        );
      }
    });
  }

  /// Build tappable review text (responsive to available width)
  Widget _buildReviewText(BuildContext context, double fontSize, double width) {
    // For small screens, show shortened text
    final showFullText = width > 200;
    final locale = Localizations.localeOf(context).languageCode;
    final reviewText = isRTL
        ? "اضغط لعرض التقييمات"
        : locale == 'fr'
            ? "Appuyez pour voir les avis"
            : "Tap to view reviews";
    final shortText = isRTL
        ? "التقييمات"
        : locale == 'fr'
            ? "Avis"
            : "Reviews";

    return GestureDetector(
      onTap: () {
        // Navigate to reviews screen
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RestaurantReviewsScreen(
              restaurant: restaurant,
            ),
          ),
        );
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 4,
          vertical: 4,
        ),
        child: Text(
          showFullText ? reviewText : shortText,
          style: GoogleFonts.poppins(
            fontSize: fontSize - 1,
            color: Colors.grey[600],
            fontStyle: FontStyle.italic,
            decoration: TextDecoration.underline,
            decorationColor: Colors.grey[600],
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
