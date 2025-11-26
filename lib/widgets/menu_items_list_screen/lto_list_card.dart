import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../features/reviews/ui/reviews_screen.dart';
import '../../l10n/app_localizations.dart';
import '../../models/menu_item.dart';
import '../../providers/delivery_fee_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/delivery_fee_service.dart';
import '../../utils/price_formatter.dart';
import '../menu_item_full_popup/helpers/popup_helper.dart';
import 'components/menu_item_image.dart';
import 'components/menu_item_name_display.dart';
import 'components/rating_stars_display.dart';
import 'components/restaurant_name_header.dart';
import 'components/review_count_display.dart';

/// LTO list card widget - copies MenuItemCard style but for LTO items
/// Shows LTO items in the same horizontal card layout as regular menu items
class LTOListCard extends StatefulWidget {
  const LTOListCard({
    required this.menuItem,
    required this.onCacheCleared,
    required this.onDataChanged,
    super.key,
  });

  final MenuItem menuItem;
  final VoidCallback onCacheCleared;
  final VoidCallback onDataChanged;

  @override
  State<LTOListCard> createState() => _LTOListCardState();
}

class _LTOListCardState extends State<LTOListCard> {
  double? _deliveryFee;
  bool _isLoadingFee = true;

  // LTO delivery offer state (similar to LTO section card)
  String _deliveryOfferText = '';
  String? _deliveryNewPrice;
  bool _isRTL = false;

  // PHASE 2: Pre-calculated dimensions and font sizes
  late final double _screenWidth;
  late final double _itemNameFontSize;
  late final double _reviewFontSize;
  late final double _priceFontSize;
  late final double _prepTimeFontSize;
  late final double _cardWidth;
  late final double _contentHeight;
  late final double _imageHeight;

  // Track if dimensions have been initialized
  bool _dimensionsInitialized = false;

  @override
  void initState() {
    super.initState();
    // Calculate delivery fee on initialization
    _initializeDeliveryFee();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // PHASE 2: Pre-calculate all dimensions once
    // This runs only once per card, not on every build
    if (!_dimensionsInitialized) {
      _screenWidth = MediaQuery.of(context).size.width;
      _itemNameFontSize = _getAdaptiveFontSize(_screenWidth, 14);
      _reviewFontSize = _getAdaptiveFontSize(_screenWidth, 11);
      _priceFontSize = _getAdaptiveFontSize(_screenWidth, 14) * 0.9;
      _prepTimeFontSize = _getAdaptiveFontSize(_screenWidth, 12) * 0.9;
      _cardWidth = _screenWidth - 40; // 20px padding on each side
      _contentHeight = _cardWidth * 0.3;
      _imageHeight = _contentHeight;
      _dimensionsInitialized = true;
    }

    // Update RTL state
    _isRTL = Directionality.of(context) == TextDirection.rtl;

    // Listen to location changes and recalculate fee when location changes
    final locationProvider =
        Provider.of<LocationProvider>(context, listen: true);
    final hasPermission = locationProvider.hasPermission;
    final isLocationEnabled = locationProvider.isLocationEnabled;

    // Only recalculate if permission and service are available
    if (hasPermission && isLocationEnabled) {
      if (locationProvider.currentLocation != null) {
        // Recalculate fee when location changes (DeliveryFeeProvider handles cache invalidation)
        _calculateDeliveryFee();
      }
    } else {
      // Hide delivery fee if no permission or service is off
      if (mounted) {
        setState(() {
          _deliveryFee = null;
          _isLoadingFee = false;
          _deliveryOfferText = '';
          _deliveryNewPrice = null;
        });
      }
    }

    // Recalculate delivery offer text when dependencies change
    if (_deliveryFee != null || !_isLoadingFee) {
      final deliveryResult = _computeDeliveryOfferText();
      if (mounted) {
        setState(() {
          _deliveryOfferText = deliveryResult['text'] as String;
          _deliveryNewPrice = deliveryResult['newPrice'] as String?;
        });
      }
    }
  }

  /// PHASE 2: Initialize delivery fee - try cache first, fallback to calculation
  void _initializeDeliveryFee() {
    // Calculate delivery fee using DeliveryFeeProvider (handles location changes automatically)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _calculateDeliveryFee();
    });
  }

  /// Calculate delivery fee for the restaurant using DeliveryFeeProvider
  /// This ensures consistent calculation triggered by location changes
  Future<void> _calculateDeliveryFee() async {
    try {
      final locationProvider =
          Provider.of<LocationProvider>(context, listen: false);
      final deliveryFeeProvider =
          Provider.of<DeliveryFeeProvider>(context, listen: false);

      // Check location permission and service status
      final hasPermission = locationProvider.hasPermission;
      final isLocationEnabled = locationProvider.isLocationEnabled;

      // If no permission or service is off, hide delivery fee
      if (!hasPermission || !isLocationEnabled) {
        if (mounted) {
          setState(() {
            _deliveryFee = null;
            _isLoadingFee = false;
          });
        }
        return;
      }

      // Get current user location
      final currentLocation = locationProvider.currentLocation;

      if (currentLocation == null) {
        // Get base delivery fee from restaurant when no location
        final deliveryFeeService = DeliveryFeeService();
        final baseFee = await deliveryFeeService.getRestaurantDeliveryFee(
          widget.menuItem.restaurantId,
        );
        if (mounted) {
          setState(() {
            _deliveryFee = baseFee;
            _isLoadingFee = false;
          });
        }
        return;
      }

      // Get base delivery fee from restaurant
      final deliveryFeeService = DeliveryFeeService();
      final baseDeliveryFee = await deliveryFeeService.getRestaurantDeliveryFee(
        widget.menuItem.restaurantId,
      );

      // Calculate delivery fee using DeliveryFeeProvider
      // This provider handles location changes and cache invalidation automatically
      final deliveryFee = await deliveryFeeProvider.getDeliveryFee(
        restaurantId: widget.menuItem.restaurantId,
        baseDeliveryFee: baseDeliveryFee,
        customerLatitude: currentLocation.latitude,
        customerLongitude: currentLocation.longitude,
      );

      if (mounted) {
        setState(() {
          _deliveryFee = deliveryFee;
          _isLoadingFee = false;
        });
        // Recalculate delivery offer text with actual fee
        final deliveryResult = _computeDeliveryOfferText();
        if (mounted) {
          setState(() {
            _deliveryOfferText = deliveryResult['text'] as String;
            _deliveryNewPrice = deliveryResult['newPrice'] as String?;
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error calculating delivery fee: $e');
      // Get base delivery fee as fallback
      final deliveryFeeService = DeliveryFeeService();
      final baseFee = await deliveryFeeService.getRestaurantDeliveryFee(
        widget.menuItem.restaurantId,
      );
      if (mounted) {
        setState(() {
          _deliveryFee = baseFee;
          _isLoadingFee = false;
        });
        // Recalculate delivery offer text with fallback fee
        final deliveryResult = _computeDeliveryOfferText();
        if (mounted) {
          setState(() {
            _deliveryOfferText = deliveryResult['text'] as String;
            _deliveryNewPrice = deliveryResult['newPrice'] as String?;
          });
        }
      }
    }
  }

  /// Compute delivery offer text using actual delivery fee (same as LTO section card)
  /// Returns a map with 'text' (the discount text) and 'newPrice' (the new price after discount)
  Map<String, dynamic> _computeDeliveryOfferText() {
    // Check if this is an LTO offer with special_delivery
    if (!widget.menuItem.hasOfferType('special_delivery')) {
      return {'text': '', 'newPrice': null};
    }

    // If loading, return empty to show loading state
    if (_isLoadingFee || _deliveryFee == null) {
      return {'text': '', 'newPrice': null};
    }

    // Use actual delivery fee
    final baseDeliveryFee = _deliveryFee!;

    // Access offer_details from pricing_options
    final pricingOptions = widget.menuItem.pricingOptions;
    if (pricingOptions.isEmpty) {
      final l10n = AppLocalizations.of(context);
      return {
        'text': l10n?.freeDeliveryLabel ?? 'Free delivery',
        'newPrice': null
      };
    }

    final firstPricing = pricingOptions.first;
    final offerDetails = firstPricing['offer_details'] as Map<String, dynamic>?;
    if (offerDetails == null) {
      final l10n = AppLocalizations.of(context);
      return {
        'text': l10n?.freeDeliveryLabel ?? 'Free delivery',
        'newPrice': null
      };
    }

    final deliveryType = offerDetails['delivery_type'] as String?;
    final deliveryValue = offerDetails['delivery_value'] as num?;
    final l10n = AppLocalizations.of(context);
    final isArabic = _isRTL;

    if (deliveryType == 'free') {
      // Free delivery - show only "Free delivery" text, no price
      return {
        'text': l10n?.freeDeliveryLabel ?? 'Free delivery',
        'newPrice': null, // Don't show "0 DA" for free delivery
      };
    } else if (deliveryType == 'percentage' && deliveryValue != null) {
      final discountPercent = deliveryValue.toDouble();
      // Apply percentage discount to actual delivery fee
      final newPrice = baseDeliveryFee * (1 - discountPercent / 100);

      // If discounted price is 0 or less, show "Free delivery" instead of "0 DA"
      if (newPrice <= 0) {
        return {
          'text': l10n?.freeDeliveryLabel ?? 'Free delivery',
          'newPrice': null, // Don't show "0 DA" for free delivery
        };
      }

      final discountText = isArabic
          ? '-${discountPercent.toInt()}%'
          : '-${discountPercent.toInt()}%';
      return {
        'text': discountText,
        'newPrice': PriceFormatter.formatWithSettings(
            context, newPrice.round().toStringAsFixed(0)),
      };
    } else if (deliveryType == 'fixed' && deliveryValue != null) {
      final discountAmount = deliveryValue.toDouble();
      // Apply fixed discount to actual delivery fee
      final newPrice =
          (baseDeliveryFee - discountAmount).clamp(0.0, double.infinity);

      // If discounted price is 0, show "Free delivery" instead of "0 DA"
      if (newPrice <= 0) {
        return {
          'text': l10n?.freeDeliveryLabel ?? 'Free delivery',
          'newPrice': null, // Don't show "0 DA" for free delivery
        };
      }

      final discountText = isArabic
          ? '-${discountAmount.toInt()} دج'
          : '-${discountAmount.toInt()} DA';
      return {
        'text': discountText,
        'newPrice': PriceFormatter.formatWithSettings(
            context, newPrice.round().toStringAsFixed(0)),
      };
    }

    return {
      'text': l10n?.freeDeliveryLabel ?? 'Free delivery',
      'newPrice': null
    };
  }

  /// Build price display with original price if available
  Widget _buildPriceDisplay(BuildContext context, AppLocalizations l10n) {
    final originalPrice = widget.menuItem.originalPriceFromPricing;
    final hasOriginalPrice = originalPrice != null &&
                             originalPrice > 0 &&
                             originalPrice > widget.menuItem.price;

    return Container(
      padding: const EdgeInsets.only(
        right: 12 * 0.9, // Only right padding, no left padding
        top: 8,
        bottom: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: _isRTL ? TextDirection.rtl : TextDirection.ltr,
        children: [
          // Price section with discounted and original price - fits available area
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              textDirection: _isRTL ? TextDirection.rtl : TextDirection.ltr,
              children: [
                // Discounted price in #363832 - increased size
                Flexible(
                  child: Text(
                    PriceFormatter.formatWithSettings(
                      context,
                      widget.menuItem.price.toStringAsFixed(0),
                    ),
                    style: GoogleFonts.poppins(
                      fontSize: _priceFontSize * 1.2, // 20% increase in size
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF363832),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Original price if available - increased size
                if (hasOriginalPrice) ...[
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      PriceFormatter.formatWithSettings(
                        context,
                        originalPrice.toStringAsFixed(0),
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: _priceFontSize * 0.85 * 1.2, // 20% increase in size
                        fontWeight: FontWeight.normal,
                        color: Colors.grey[600]!,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: Colors.grey[600]!,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Navigate to reviews screen for this menu item
  void _navigateToReviews(BuildContext context, AppLocalizations l10n) {
    // Extract base name (remove variant suffix like "Small", "Medium", etc.)
    String baseName = widget.menuItem.name;

    // If item has variants, keep only the part before the last word
    if (widget.menuItem.variants.isEmpty &&
        widget.menuItem.name.contains(' ')) {
      final parts = widget.menuItem.name.split(' ');
      if (parts.length > 1) {
        baseName = parts.sublist(0, parts.length - 1).join(' ');
      }
    }

    debugPrint(
        '🔍 View Reviews: Original name="${widget.menuItem.name}", BaseName="$baseName", RestaurantId="${widget.menuItem.restaurantId}", HasVariants=${widget.menuItem.variants.isNotEmpty}');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ReviewsScreen(
          restaurantId: widget.menuItem.restaurantId,
          restaurantName: widget.menuItem.restaurantName ?? 'Restaurant',
          initialSelectedMenuItem: baseName,
        ),
      ),
    );
  }

  /// Calculate adaptive font size based on screen width
  /// Small screens: reduce font size, larger screens: keep original or slightly increase
  static double _getAdaptiveFontSize(double screenWidth, double baseFontSize) {
    // Screen width ranges:
    // Small phones: < 360px -> 85% of base
    // Medium phones: 360-400px -> 90-100% of base
    // Large phones/tablets: > 400px -> 100% of base
    if (screenWidth < 360) {
      return baseFontSize * 0.85;
    } else if (screenWidth < 380) {
      return baseFontSize * 0.90;
    } else if (screenWidth < 400) {
      return baseFontSize * 0.95;
    } else {
      return baseFontSize;
    }
  }

  /// Calculate adaptive icon size based on screen width
  static double _getAdaptiveIconSize(double screenWidth, double baseIconSize) {
    // Use same logic as font size for consistency
    if (screenWidth < 360) {
      return baseIconSize * 0.85;
    } else if (screenWidth < 380) {
      return baseIconSize * 0.90;
    } else if (screenWidth < 400) {
      return baseIconSize * 0.95;
    } else {
      return baseIconSize;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Detect text direction for RTL support
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    final l10n = AppLocalizations.of(context)!;

    // PHASE 2: Use pre-calculated dimensions (no LayoutBuilder needed)
    const padding = 12.0;
    const headerHeight = 40.0;
    final cardHeight = _contentHeight + (padding * 2) + headerHeight;

    // Wrap with RepaintBoundary to isolate repaints for better performance
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => PopupHelper.showMenuItemPopup(
          context: context,
          menuItem: widget.menuItem,
          onItemAddedToCart: (orderItem) {
            // Show confirmation when item is added to cart
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    "${orderItem.menuItem?.name ?? l10n.item} ${l10n.addedToCart}",
                  ),
                  duration: const Duration(seconds: 2),
                  backgroundColor: Colors.green[600],
                ),
              );
            }
          },
          onDataChanged: () {
            // Refresh LTO items when data changes (same as LTO section card)
            if (mounted) {
              widget.onCacheCleared();
              widget.onDataChanged();
            }
          },
        ),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: SizedBox(
              height: cardHeight,
              width: double.infinity, // Full screen width
              child: Padding(
                padding: const EdgeInsets.all(12), // Padding inside container
                child: Column(
                  children: [
                    // Header section with restaurant name, prep time, and delivery fee
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Restaurant name and prep time on the left - prep time directly next to restaurant name
                        Expanded(
                          child: Row(
                            textDirection: _isRTL ? TextDirection.rtl : TextDirection.ltr,
                            children: [
                              // Restaurant name
                              Flexible(
                                child: RestaurantNameHeader(
                                  restaurantName: widget.menuItem.restaurantName,
                                  fontSize: _getAdaptiveFontSize(_screenWidth, 12),
                                ),
                              ),
                              const SizedBox(width: 8 * 0.9),
                              // Divider
                              Container(
                                width: 1,
                                height: 12 * 0.9,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(width: 8 * 0.9),
                              // Prep time icon
                              Icon(
                                Icons.access_time,
                                size: _getAdaptiveIconSize(_screenWidth, 14) * 0.9,
                                color: Colors.grey[700],
                              ),
                              const SizedBox(width: 4 * 0.9),
                              // Prep time text
                              Text(
                                '${widget.menuItem.preparationTime} ${l10n.min}',
                                style: GoogleFonts.poppins(
                                  fontSize: _prepTimeFontSize,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Delivery fee with LTO section style container - hide if no location permission or service
                        Consumer<LocationProvider>(
                          builder: (context, locationProvider, child) {
                            final hasPermission = locationProvider.hasPermission;
                            final isLocationEnabled = locationProvider.isLocationEnabled;

                            // Hide delivery fee if no permission or service is off
                            if (!hasPermission || !isLocationEnabled) {
                              return const SizedBox.shrink();
                            }

                            // Show LTO delivery offer container if item has special_delivery
                            if (widget.menuItem.hasOfferType('special_delivery')) {
                              final restaurantFontSize = _getAdaptiveFontSize(_screenWidth, 10) * 1.1; // 10% increase

                              return _isLoadingFee
                                  ? SizedBox(
                                      width: 66, // 10% increase: 60 * 1.1
                                      height: (restaurantFontSize + 8) * 1.1, // 10% increase
                                      child: LinearProgressIndicator(
                                        backgroundColor: Colors.yellow[100],
                                        valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.yellow[600]!,
                                        ),
                                        minHeight: 2.2, // 10% increase: 2 * 1.1
                                      ),
                                    )
                                  : Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6.6, // 10% increase: 6 * 1.1
                                        vertical: 3.3, // 10% increase: 3 * 1.1
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.yellow[600],
                                        borderRadius: BorderRadius.circular(6.6), // 10% increase: 6 * 1.1
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.moped,
                                            size: restaurantFontSize, // Already increased by 10%
                                            color: Colors.black,
                                          ),
                                          const SizedBox(width: 4.4), // 10% increase: 4 * 1.1
                                          Flexible(
                                            child: Text(
                                              _deliveryNewPrice != null
                                                  ? '$_deliveryOfferText ($_deliveryNewPrice)'
                                                  : _deliveryOfferText,
                                              style: GoogleFonts.poppins(
                                                fontSize: (restaurantFontSize - 1) * 1.1, // 10% increase
                                                fontWeight: FontWeight.normal,
                                                color: Colors.black,
                                              ),
                                              textDirection: _isRTL
                                                  ? TextDirection.rtl
                                                  : TextDirection.ltr,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                            }

                            // Fallback to regular delivery fee display if no special_delivery offer
                            return const SizedBox.shrink();
                          },
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),

                    // Divider line
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: Colors.grey[300],
                    ),

                    const SizedBox(height: 8),

                    // Main content row
                    Expanded(
                      child: Row(
                        textDirection:
                            isRTL ? TextDirection.rtl : TextDirection.ltr,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Menu item details - 60% width using flex
                          Expanded(
                            flex: 6,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Item name - RTL aware
                                MenuItemNameDisplay(
                                  name: widget.menuItem.name,
                                  fontSize: _itemNameFontSize,
                                  isRTL: isRTL,
                                ),

                                const SizedBox(height: 8), // Reduced from 10 to prevent overflow

                                // Rating - fills available width
                                Row(
                                  textDirection: isRTL
                                      ? TextDirection.rtl
                                      : TextDirection.ltr,
                                  children: [
                                    // 5-star rating display
                                    RatingStarsDisplay(
                                      rating: widget.menuItem.rating,
                                      starSize: _getAdaptiveIconSize(
                                          _screenWidth, 14),
                                    ),

                                    const SizedBox(width: 4),

                                    // Review count and link
                                    Expanded(
                                      child: ReviewCountDisplay(
                                        reviewCount:
                                            widget.menuItem.reviewCount,
                                        fontSize: _reviewFontSize,
                                        onViewReviews: widget.menuItem
                                                .restaurantId.isNotEmpty
                                            ? () => _navigateToReviews(
                                                context, l10n)
                                            : null,
                                      ),
                                    ),
                                  ],
                                ),

                                const SizedBox(height: 8), // Reduced from 12 to prevent overflow

                                // Discount %off container (above price) - only show if item has special_price offer
                                if (widget.menuItem.hasOfferType('special_price') &&
                                    widget.menuItem.discountPercentage != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 4), // Reduced from 6.6 to prevent overflow
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6.6, // 10% increase: 6 * 1.1
                                        vertical: 3.3, // 10% increase: 3 * 1.1
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.yellow[600],
                                        borderRadius: BorderRadius.circular(6.6), // 10% increase: 6 * 1.1
                                      ),
                                      child: Text(
                                        _isRTL
                                            ? 'خصم ${widget.menuItem.discountPercentage!.toInt()}%'
                                            : '${widget.menuItem.discountPercentage!.toInt()}% off',
                                        style: GoogleFonts.poppins(
                                          fontSize: (_getAdaptiveFontSize(_screenWidth, 10) - 1) * 1.1, // 10% increase
                                          fontWeight: FontWeight.normal,
                                          color: Colors.black,
                                        ),
                                        textDirection: _isRTL
                                            ? TextDirection.rtl
                                            : TextDirection.ltr,
                                      ),
                                    ),
                                  ),

                                // Price and prep time in white container - show original price if available
                                _buildPriceDisplay(context, l10n),
                              ],
                            ),
                          ),

                          // Square image with rounded border - 40% width using flex
                          Expanded(
                            flex: 4,
                            child: Center(
                              child: MenuItemImage(
                                imageUrl: widget.menuItem.image,
                                itemId: widget.menuItem.id,
                                imageSize: _imageHeight,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
