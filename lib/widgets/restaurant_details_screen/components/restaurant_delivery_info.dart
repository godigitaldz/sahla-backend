import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";
import "package:provider/provider.dart";
import "package:shimmer/shimmer.dart";

import "../../../providers/delivery_fee_provider.dart";
import "../../../providers/location_provider.dart";

/// Delivery information badge with fee and estimated time
///
/// Features:
/// - Real-time delivery fee from DeliveryFeeProvider
/// - Loading and error states with visual feedback
/// - Retry button for failed calculations
/// - RTL support
/// - Localized currency and time format
/// - Color-coded states (normal, loading, error)
/// - Responsive sizing for small screens
class RestaurantDeliveryInfo extends StatelessWidget {
  final String restaurantId;
  final double baseDeliveryFee;
  final int estimatedDeliveryTime;
  final bool isRTL;
  final VoidCallback? onRetry;
  final double? availableWidth;

  const RestaurantDeliveryInfo({
    required this.restaurantId,
    required this.baseDeliveryFee,
    required this.estimatedDeliveryTime,
    super.key,
    this.isRTL = false,
    this.onRetry,
    this.availableWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer2<DeliveryFeeProvider, LocationProvider>(
      builder: (context, feeProvider, locationProvider, child) {
        final hasPermission = locationProvider.hasPermission;
        final isLocationEnabled = locationProvider.isLocationEnabled;

        // Hide delivery fee container if no permission or service is off
        if (!hasPermission || !isLocationEnabled) {
          return const SizedBox.shrink();
        }

        final cachedFee = feeProvider.getCachedFee(restaurantId);
        final isCalculating = feeProvider.isCalculating(restaurantId);
        final hasFailed = feeProvider.hasFailed(restaurantId);

        // Check if location is loading or unavailable
        final isLocationLoading = locationProvider.isLoading;
        final hasLocation = locationProvider.currentLocation != null;

        // Determine if we should show loading state
        final shouldShowLoading = isCalculating ||
            (isLocationLoading && hasPermission) ||
            (!hasLocation && hasPermission && !hasFailed);

        // Use cached fee if available, otherwise use base fee (but not when loading)
        final displayFee =
            shouldShowLoading ? null : (cachedFee ?? baseDeliveryFee);

        // Determine badge color based on state
        final badgeColor = _getBadgeColor(hasFailed, shouldShowLoading);
        final statusIcon = _getStatusIcon(hasFailed, shouldShowLoading);

        // Wrap with GestureDetector for retry functionality
        return GestureDetector(
          onTap: hasFailed && onRetry != null ? onRetry : null,
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Use actual container width for responsive sizing
              final containerWidth = constraints.maxWidth;

              // Calculate responsive font sizes based on actual container width
              // Fee font must accommodate "200 Da" minimum (3 digits + currency)
              final feeFontSize = _getResponsiveFontSize(
                containerWidth,
                baseFontSize: 12,
                minFontSize: 9,
              );
              final timeFontSize = _getResponsiveFontSize(
                containerWidth,
                baseFontSize: 10,
                minFontSize: 8,
              );
              final iconSize = _getResponsiveIconSize(
                containerWidth,
                baseSize: 12,
                minSize: 10,
              );

              return Container(
                padding: EdgeInsets.symmetric(
                  horizontal: containerWidth < 150 ? 6 : 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: badgeColor,
                  borderRadius: BorderRadius.circular(6),
                  // Add subtle border on error to indicate it's tappable
                  border: hasFailed && onRetry != null
                      ? Border.all(
                          color: Colors.white.withValues(alpha: 0.3), width: 1)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                  children: [
                    // Status icon or delivery icon
                    _buildLeadingIcon(statusIcon, shouldShowLoading, iconSize),

                    // Delivery fee text or skeleton loading
                    if (shouldShowLoading || displayFee == null)
                      _buildSkeletonLoader()
                    else
                      Flexible(
                        child: Text(
                          _formatDeliveryFee(context, displayFee),
                          style: GoogleFonts.poppins(
                            fontSize: feeFontSize,
                            fontWeight: FontWeight.normal,
                            color: Colors.white,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                    SizedBox(width: containerWidth < 150 ? 3 : 6),
                    _buildDivider(),
                    SizedBox(width: containerWidth < 150 ? 3 : 6),

                    // Time icon and text
                    Icon(
                      Icons.access_time,
                      size: iconSize,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 3),
                    Flexible(
                      child: Text(
                        _formatPrepTime(context, estimatedDeliveryTime),
                        style: GoogleFonts.poppins(
                          fontSize: timeFontSize,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  /// Calculate responsive font size based on actual container width
  /// Ensures minimum display of "200 Da" (3 digits + currency)
  double _getResponsiveFontSize(double width,
      {required double baseFontSize, required double minFontSize}) {
    // Adjusted for smaller container (35% of card width)
    // Ensuring "200 Da" or "237 927 Da" can display properly
    if (width < 130) {
      return minFontSize; // Very small containers
    } else if (width < 160) {
      // Scale smoothly for medium containers
      final scale = (width - 130) / 30;
      return minFontSize + (baseFontSize - minFontSize) * scale * 0.5;
    } else if (width < 200) {
      // Continue scaling for larger containers
      final scale = (width - 160) / 40;
      return minFontSize + (baseFontSize - minFontSize) * (0.5 + scale * 0.5);
    }
    return baseFontSize;
  }

  /// Calculate responsive icon size based on actual container width
  double _getResponsiveIconSize(double width,
      {required double baseSize, required double minSize}) {
    // Adjusted for smaller container (35% of card width)
    if (width < 130) {
      return minSize;
    } else if (width < 160) {
      final scale = (width - 130) / 30;
      return minSize + (baseSize - minSize) * scale * 0.5;
    } else if (width < 200) {
      final scale = (width - 160) / 40;
      return minSize + (baseSize - minSize) * (0.5 + scale * 0.5);
    }
    return baseSize;
  }

  /// Get badge color based on state
  Color _getBadgeColor(bool hasFailed, bool isCalculating) {
    const baseColor = Color(0xFFB2AC88); // #b2ac88

    if (hasFailed) {
      return baseColor.withOpacity(0.85); // Slightly lighter for error
    } else if (isCalculating) {
      return baseColor.withOpacity(0.90); // Medium opacity for loading
    } else {
      return baseColor; // Normal color
    }
  }

  /// Get status icon based on state
  IconData? _getStatusIcon(bool hasFailed, bool isCalculating) {
    if (hasFailed) {
      return Icons.warning_amber;
    } else if (isCalculating) {
      return null; // Show loading indicator instead
    }
    return null;
  }

  /// Build leading icon (status or delivery)
  Widget _buildLeadingIcon(
      IconData? statusIcon, bool isLoading, double iconSize) {
    if (statusIcon != null) {
      return Row(
        children: [
          Icon(
            statusIcon,
            size: iconSize,
            color: Colors.white,
          ),
          const SizedBox(width: 4),
        ],
      );
    } else if (!isLoading) {
      return Row(
        children: [
          Transform.flip(
            flipX: isRTL,
            child: Icon(
              Icons.delivery_dining,
              size: iconSize + 2,
              color: Colors.white,
            ),
          ),
          const SizedBox(width: 4),
        ],
      );
    }
    return const SizedBox.shrink();
  }

  /// Build skeleton loader for fee calculation
  Widget _buildSkeletonLoader() {
    return Shimmer.fromColors(
      baseColor: Colors.white.withValues(alpha: 0.3),
      highlightColor: Colors.white.withValues(alpha: 0.5),
      child: Container(
        width: 60,
        height: 14,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  /// Build divider line
  Widget _buildDivider() {
    return Container(
      width: 1,
      height: 12,
      color: Colors.white.withValues(alpha: 0.5),
    );
  }

  /// Format delivery fee with proper currency symbol based on locale
  String _formatDeliveryFee(BuildContext context, double fee) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    // Don't show "free delivery" for 0 - it might be loading or unavailable
    // Only show it if it's explicitly 0 and we're sure it's not loading
    if (fee == 0) {
      return isArabic ? '0 دج' : '0 Da';
    }

    final feeStr = _formatNumberWithSpaces(fee.toStringAsFixed(0));

    if (isArabic) {
      // Use LTR mark to ensure numbers display correctly with currency after
      return '\u200E$feeStr دج\u200E';
    } else {
      return '$feeStr Da';
    }
  }

  /// Format number with spaces every 3 digits
  String _formatNumberWithSpaces(String number) {
    final reversed = number.split('').reversed.join('');
    final chunks = <String>[];

    for (int i = 0; i < reversed.length; i += 3) {
      final end = i + 3;
      chunks.add(
          reversed.substring(i, end > reversed.length ? reversed.length : end));
    }

    return chunks.join(' ').split('').reversed.join('');
  }

  /// Format prep time with proper localization
  String _formatPrepTime(BuildContext context, int minutes) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    if (isArabic) {
      return '$minutes دقيقة';
    } else {
      return '$minutes min';
    }
  }
}
