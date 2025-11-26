import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/menu_item.dart';
import '../../../providers/delivery_fee_provider.dart';
import '../../../providers/location_provider.dart';
import '../../../services/delivery_fee_service.dart';
import '../../../services/geolocation_service.dart';
import '../../../utils/price_formatter.dart';

/// Limited Time Offer card widget for home screen's LTO section
/// Vertical layout with image on top (50%) and details below (50%)
/// Shows discount badge and original price when applicable
///
/// Performance optimized:
/// - Uses ValueNotifiers for real-time updates without full rebuilds
/// - Caches expensive calculations
/// - Downscales images with cacheWidth/cacheHeight
class LimitedTimeOfferCard extends StatefulWidget {
  const LimitedTimeOfferCard({
    required this.menuItem,
    required this.onTap,
    this.availabilityNotifier,
    this.priceNotifier,
    super.key,
  });

  final MenuItem menuItem;
  final VoidCallback onTap;
  final ValueNotifier<bool>? availabilityNotifier;
  final ValueNotifier<double>? priceNotifier;

  @override
  State<LimitedTimeOfferCard> createState() => _LimitedTimeOfferCardState();
}

class _LimitedTimeOfferCardState extends State<LimitedTimeOfferCard> {
  Timer? _countdownTimer;
  String _countdownText = 'LIMITED';

  // Performance: Cache expensive calculations
  late Size _screenSize;
  bool _isRTL = false; // Initialize to false, updated in didChangeDependencies
  late double _cardWidth;
  late double _cardHeight;
  late String _deliveryOfferText;
  String? _deliveryNewPrice;
  late bool _hasDiscount;
  late double? _discountPercent;

  // Delivery fee state
  double? _actualDeliveryFee;
  bool _isLoadingDeliveryFee = true;
  LocationData?
      _lastLocation; // Track last location to avoid unnecessary recalculations

  // Performance: Cache text styles to avoid repeated GoogleFonts calls
  late TextStyle _nameStyle;

  @override
  void initState() {
    super.initState();
    _deliveryNewPrice = null; // Initialize to null
    // Defer countdown start to avoid setState during initialization
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _startCountdown();
        _calculateDeliveryFee();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Performance: Cache MediaQuery and calculations once
    _screenSize = MediaQuery.of(context).size;
    final bool wasRTL = _isRTL;
    _isRTL = Directionality.of(context) == TextDirection.rtl;

    // Calculate card dimensions based on aspect ratio (not screen height percentage)
    // Width: Calculate to show exactly 3.1 cards per screen width
    // Formula: (screen width - total padding and spacing) / 3.1 cards
    // Breakdown: left padding (16px) + 3.1 cards + 2.1 spacings between cards (8px each = 16.8px)
    // Total padding + spacing = 16 + 16.8 = 32.8px
    // This ensures exactly 3.1 cards are visible with proper spacing, creating a peek effect for the next card
    _cardWidth = (_screenSize.width - 32.8) / 3.1;
    // Height: Use aspect ratio (width:height ratio ~1:1.4) for consistent card proportions
    _cardHeight =
        _cardWidth * 1.4; // Aspect ratio maintains card design proportions

    // Cache expensive calculations - will be recalculated after delivery fee is loaded
    _hasDiscount = widget.menuItem.hasOfferType('special_price');
    _discountPercent = widget.menuItem.discountPercentage;

    // Check if location has changed and recalculate if needed
    final locationProvider = Provider.of<LocationProvider>(context);
    final currentLocation = locationProvider.currentLocation;
    final isLoadingLocation = locationProvider.isLoading;

    // Recalculate if:
    // 1. Location changed (coordinates different)
    // 2. Location became available (was null, now not null)
    // 3. Location loading state changed (was loading, now not)
    final locationChanged = currentLocation != null &&
        (_lastLocation == null ||
            _lastLocation!.latitude != currentLocation.latitude ||
            _lastLocation!.longitude != currentLocation.longitude);

    final locationBecameAvailable =
        _lastLocation == null && currentLocation != null;
    final loadingStateChanged =
        _isLoadingDeliveryFee && !isLoadingLocation && currentLocation != null;

    if (locationChanged || locationBecameAvailable || loadingStateChanged) {
      _lastLocation = currentLocation;
      // Recalculate fee when location changes (async, won't block build)
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _calculateDeliveryFee();
        }
      });
    }

    // If location is loading and we don't have a location, keep loading state
    if (isLoadingLocation &&
        currentLocation == null &&
        !_isLoadingDeliveryFee) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _isLoadingDeliveryFee = true;
            _actualDeliveryFee = null;
          });
        }
      });
    }

    // Recalculate delivery offer text when dependencies change
    if (_actualDeliveryFee != null || !_isLoadingDeliveryFee) {
      final deliveryResult = _computeDeliveryOfferText();
      _deliveryOfferText = deliveryResult['text'] as String;
      _deliveryNewPrice = deliveryResult['newPrice'] as String?;
    } else {
      // Initialize with empty values until delivery fee is calculated
      _deliveryOfferText = '';
      _deliveryNewPrice = null;
    }

    // Cache text styles
    final bool isSmallScreen = _screenSize.width < 360;
    final nameFontSize = isSmallScreen ? 10.0 : 12.0;

    _nameStyle = GoogleFonts.poppins(
      fontSize: nameFontSize,
      fontWeight: FontWeight.w600,
      color: Colors.black87,
    );

    // Update countdown if RTL changed to ensure correct symbols are shown
    // Defer to next frame to avoid setState during didChangeDependencies
    if (wasRTL != _isRTL) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _updateCountdown();
        }
      });
    }
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  void _startCountdown() {
    _updateCountdown();
    // Performance: Update every 30 seconds instead of every second to reduce rebuilds
    _countdownTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _updateCountdown();
      }
    });
  }

  void _updateCountdown() {
    final offerEndAt = widget.menuItem.offerEndAtFromPricing;
    final l10n = AppLocalizations.of(context);
    if (offerEndAt == null) {
      if (mounted) {
        setState(() {
          _countdownText = l10n?.limited ?? 'LIMITED';
        });
      }
      return;
    }

    final now = DateTime.now();
    final difference = offerEndAt.difference(now);

    if (difference.isNegative) {
      if (mounted) {
        setState(() {
          _countdownText = l10n?.expired ?? 'EXPIRED';
        });
      }
      _countdownTimer?.cancel();
      return;
    }

    final totalHours = difference.inHours;
    final totalMinutes = difference.inMinutes;

    // Use cached RTL value - it's updated in didChangeDependencies
    // This avoids accessing context during initialization
    final bool isRTL = _isRTL;

    String newText;
    if (totalHours >= 24) {
      // Show days
      final days = difference.inDays;
      newText = isRTL ? '$days ي' : '$days D';
    } else if (totalMinutes >= 60) {
      // Show hours
      newText = isRTL ? '$totalHours س' : '$totalHours H';
    } else {
      // Show minutes
      newText = isRTL ? '$totalMinutes د' : '$totalMinutes M';
    }

    if (_countdownText != newText && mounted) {
      setState(() {
        _countdownText = newText;
      });
    }
  }

  /// Calculate actual delivery fee for the restaurant
  Future<void> _calculateDeliveryFee() async {
    try {
      debugPrint(
          '🛵 LTO Card: Calculating delivery fee for ${widget.menuItem.name} (restaurant: ${widget.menuItem.restaurantId})');

      final locationProvider =
          Provider.of<LocationProvider>(context, listen: false);
      final deliveryFeeProvider =
          Provider.of<DeliveryFeeProvider>(context, listen: false);

      // Get current user location
      final currentLocation = locationProvider.currentLocation;
      final isLoadingLocation = locationProvider.isLoading;
      final hasPermission = locationProvider.hasPermission;
      final isLocationEnabled = locationProvider.isLocationEnabled;

      // Check if location permission is granted and service is enabled
      final hasLocationAccess = hasPermission && isLocationEnabled;

      // If no permission or service is off, hide delivery fee
      if (!hasLocationAccess) {
        debugPrint(
            '🛵 LTO Card: No location permission or service disabled, hiding delivery fee');
        if (mounted) {
          setState(() {
            _isLoadingDeliveryFee = false;
            _actualDeliveryFee = null;
            _deliveryOfferText = '';
            _deliveryNewPrice = null;
          });
        }
        return;
      }

      // If location is loading, keep loading state
      if (currentLocation == null) {
        if (isLoadingLocation) {
          // Location is being loaded, keep loading state
          debugPrint('🛵 LTO Card: Location is loading, keeping loading state');
          if (mounted) {
            setState(() {
              _isLoadingDeliveryFee = true;
              _actualDeliveryFee = null;
              _deliveryOfferText = '';
              _deliveryNewPrice = null;
            });
          }
          return;
        } else {
          // No location available even though permission is granted
          debugPrint(
              '🛵 LTO Card: No location available, using base delivery fee');
          final deliveryFeeService = DeliveryFeeService();
          final baseFee = await deliveryFeeService.getRestaurantDeliveryFee(
            widget.menuItem.restaurantId,
          );
          debugPrint(
              '🛵 LTO Card: Base delivery fee (no location): $baseFee DA');
          if (mounted) {
            setState(() {
              _actualDeliveryFee = baseFee;
              _isLoadingDeliveryFee = false;
              // Recalculate delivery offer text with actual fee
              final deliveryResult = _computeDeliveryOfferText();
              _deliveryOfferText = deliveryResult['text'] as String;
              _deliveryNewPrice = deliveryResult['newPrice'] as String?;
              debugPrint(
                  '🛵 LTO Card: Delivery offer text updated - text: $_deliveryOfferText, newPrice: $_deliveryNewPrice');
            });
          }
          return;
        }
      }

      debugPrint(
          '🛵 LTO Card: Location available: ${currentLocation.latitude}, ${currentLocation.longitude}');

      // Get base delivery fee from restaurant
      final deliveryFeeService = DeliveryFeeService();
      final baseDeliveryFee = await deliveryFeeService.getRestaurantDeliveryFee(
        widget.menuItem.restaurantId,
      );
      debugPrint('🛵 LTO Card: Base delivery fee: $baseDeliveryFee DA');

      // Calculate delivery fee using DeliveryFeeProvider
      double deliveryFee;
      try {
        deliveryFee = await deliveryFeeProvider.getDeliveryFee(
          restaurantId: widget.menuItem.restaurantId,
          baseDeliveryFee: baseDeliveryFee,
          customerLatitude: currentLocation.latitude,
          customerLongitude: currentLocation.longitude,
        );
      } catch (e) {
        // If loading exception, keep loading state
        if (e.toString().contains('Location is being loaded')) {
          debugPrint(
              '🛵 LTO Card: Delivery fee calculation in progress, keeping loading state');
          if (mounted) {
            setState(() {
              _isLoadingDeliveryFee = true;
              _actualDeliveryFee = null;
            });
          }
          return;
        }
        // For other errors, use base fee
        deliveryFee = baseDeliveryFee;
      }

      debugPrint(
          '🛵 LTO Card: Calculated delivery fee: $deliveryFee DA (base: $baseDeliveryFee DA)');

      if (mounted) {
        setState(() {
          _actualDeliveryFee = deliveryFee;
          _isLoadingDeliveryFee = false;
          // Recalculate delivery offer text with actual fee
          final deliveryResult = _computeDeliveryOfferText();
          _deliveryOfferText = deliveryResult['text'] as String;
          _deliveryNewPrice = deliveryResult['newPrice'] as String?;
          debugPrint(
              '🛵 LTO Card: Delivery offer text updated - text: $_deliveryOfferText, newPrice: $_deliveryNewPrice, baseFee: $deliveryFee DA');
        });
      }
    } catch (e) {
      debugPrint(
          '❌ Error calculating delivery fee for LTO (${widget.menuItem.name}): $e');
      // Get base delivery fee as fallback
      try {
        final deliveryFeeService = DeliveryFeeService();
        final baseFee = await deliveryFeeService.getRestaurantDeliveryFee(
          widget.menuItem.restaurantId,
        );
        debugPrint('🛵 LTO Card: Fallback base delivery fee: $baseFee DA');
        if (mounted) {
          setState(() {
            _actualDeliveryFee = baseFee;
            _isLoadingDeliveryFee = false;
            // Recalculate delivery offer text with fallback fee
            final deliveryResult = _computeDeliveryOfferText();
            _deliveryOfferText = deliveryResult['text'] as String;
            _deliveryNewPrice = deliveryResult['newPrice'] as String?;
            debugPrint(
                '🛵 LTO Card: Fallback delivery offer text - text: $_deliveryOfferText, newPrice: $_deliveryNewPrice');
          });
        }
      } catch (fallbackError) {
        debugPrint(
            '❌ Error fetching fallback delivery fee for LTO: $fallbackError');
        if (mounted) {
          setState(() {
            _actualDeliveryFee = 0.0;
            _isLoadingDeliveryFee = false;
            final deliveryResult = _computeDeliveryOfferText();
            _deliveryOfferText = deliveryResult['text'] as String;
            _deliveryNewPrice = deliveryResult['newPrice'] as String?;
            debugPrint(
                '🛵 LTO Card: Error fallback - using 0.0 DA, text: $_deliveryOfferText, newPrice: $_deliveryNewPrice');
          });
        }
      }
    }
  }

  /// Performance: Compute delivery offer text using actual delivery fee
  /// Returns a map with 'text' (the discount text) and 'newPrice' (the new price after discount)
  /// Supports LTO offers and Arabic localization
  Map<String, dynamic> _computeDeliveryOfferText() {
    // Check if this is an LTO offer with special_delivery
    if (!widget.menuItem.hasOfferType('special_delivery')) {
      return {'text': '', 'newPrice': null};
    }

    // If loading, return empty to show loading state
    if (_isLoadingDeliveryFee || _actualDeliveryFee == null) {
      return {'text': '', 'newPrice': null};
    }

    // Use actual delivery fee
    final baseDeliveryFee = _actualDeliveryFee!;

    debugPrint(
        '🛵 LTO Card: Computing delivery offer text for ${widget.menuItem.name}');
    debugPrint('   Base delivery fee: $baseDeliveryFee DA');
    debugPrint('   Is loading: $_isLoadingDeliveryFee');
    debugPrint('   Actual fee: $_actualDeliveryFee');

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
      debugPrint('   Percentage discount: $discountPercent%');
      debugPrint('   Original fee: $baseDeliveryFee DA');
      debugPrint('   Discounted fee: $newPrice DA');

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
      debugPrint('   Fixed discount: $discountAmount DA');
      debugPrint('   Original fee: $baseDeliveryFee DA');
      debugPrint('   Discounted fee: $newPrice DA');

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

  @override
  Widget build(BuildContext context) {
    // Performance: Use cached values instead of recalculating
    final bool isSmallScreen = _screenSize.width < 360;

    // Responsive padding
    final detailsPadding = isSmallScreen ? 6.0 : 8.0;
    final verticalSpacing2 = isSmallScreen ? 1.0 : 2.0;
    final discountFontSize = isSmallScreen ? 10.0 : 11.0;
    final restaurantFontSize = isSmallScreen ? 8.0 : 10.0;

    // Responsive border radius
    final borderRadius = isSmallScreen ? 10.0 : 12.0;

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: _cardWidth,
        height: _cardHeight,
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Column(
          crossAxisAlignment:
              _isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            // Image section with discount badge
            Expanded(
              child: Stack(
                children: [
                  // Performance: Optimized image with downscaling
                  ClipRRect(
                    borderRadius: BorderRadius.circular(borderRadius),
                    child: CachedNetworkImage(
                      imageUrl: widget.menuItem.image,
                      width: double.infinity,
                      height: double.infinity,
                      fit: BoxFit.cover,
                      // Performance: Downscale image to actual display size
                      memCacheWidth: (_cardWidth * 2).toInt(), // 2x for retina
                      memCacheHeight: (_cardHeight * 0.6 * 2)
                          .toInt(), // Image is 60% of card
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
                  ),

                  // Discount badge (bottom-left in English, bottom-right in Arabic)
                  if (_hasDiscount && _discountPercent != null)
                    Positioned(
                      bottom: 8,
                      left: _isRTL ? null : 8,
                      right: _isRTL ? 8 : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.yellow[600],
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _isRTL
                              ? 'خصم ${_discountPercent!.toInt()}%'
                              : '${_discountPercent!.toInt()}% off',
                          style: GoogleFonts.poppins(
                            fontSize: discountFontSize - 1,
                            fontWeight: FontWeight.normal,
                            color: Colors.black,
                          ),
                        ),
                      ),
                    ),

                  // LTO countdown badge (bottom-right in English, bottom-left in Arabic)
                  Positioned(
                    bottom: 8,
                    left: _isRTL ? 8 : null,
                    right: _isRTL ? null : 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFf8eded),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.access_time,
                            size: discountFontSize,
                            color: Colors.black87,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            _countdownText,
                            style: GoogleFonts.poppins(
                              fontSize: discountFontSize - 1,
                              fontWeight: FontWeight.normal,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Details section - shrink-wraps to content (RTL aware)
            Padding(
              padding: EdgeInsetsDirectional.all(detailsPadding),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: _isRTL
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Price (above item name, no container, no discount)
                    // Performance: Use ValueListenableBuilder for dynamic price updates
                    // Use price column for discounted price (not effectivePrice)
                    ValueListenableBuilder<double>(
                      valueListenable: widget.priceNotifier ??
                          ValueNotifier(widget.menuItem.price),
                      builder: (context, price, _) {
                        // Create price style in build method to avoid late initialization issues
                        // Match menu item section card price font size
                        final priceFontSize = isSmallScreen ? 12.0 : 14.0;
                        final priceStyle = GoogleFonts.poppins(
                          fontSize: priceFontSize,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[600]!,
                        );
                        return SizedBox(
                          width: double.infinity,
                          child: Text(
                            PriceFormatter.formatWithSettings(
                              context,
                              price.toStringAsFixed(0),
                            ),
                            style: priceStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign:
                                _isRTL ? TextAlign.right : TextAlign.left,
                            textDirection:
                                _isRTL ? TextDirection.rtl : TextDirection.ltr,
                          ),
                        );
                      },
                    ),

                    SizedBox(height: verticalSpacing2),

                    // Item name
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        widget.menuItem.name,
                        style: _nameStyle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: _isRTL ? TextAlign.right : TextAlign.left,
                        textDirection:
                            _isRTL ? TextDirection.rtl : TextDirection.ltr,
                      ),
                    ),

                    SizedBox(height: verticalSpacing2),

                    // Delivery (under item name) - only show if location permission and service are active
                    if (widget.menuItem.hasOfferType('special_delivery'))
                      Consumer<LocationProvider>(
                        builder: (context, locationProvider, child) {
                          final hasPermission = locationProvider.hasPermission;
                          final isLocationEnabled =
                              locationProvider.isLocationEnabled;

                          // Hide delivery fee if no permission or service is off
                          if (!hasPermission || !isLocationEnabled) {
                            return const SizedBox.shrink();
                          }

                          return _isLoadingDeliveryFee
                              ? SizedBox(
                                  width: 60,
                                  height: restaurantFontSize + 8,
                                  child: LinearProgressIndicator(
                                    backgroundColor: Colors.yellow[100],
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.yellow[600]!,
                                    ),
                                    minHeight: 2,
                                  ),
                                )
                              : ConstrainedBox(
                                  // Constrain max width to card width minus padding
                                  // Container will shrink to fit content (small content scenario)
                                  // But won't exceed card width, and text will ellipsize for long content
                                  constraints: BoxConstraints(
                                    maxWidth: _cardWidth - (detailsPadding * 2),
                                  ),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.yellow[600],
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.moped,
                                          size: restaurantFontSize,
                                          color: Colors.black,
                                        ),
                                        const SizedBox(width: 4),
                                        Flexible(
                                          // Flexible allows text to shrink and use ellipsis when maxWidth constraint is hit
                                          child: Text(
                                            _deliveryNewPrice != null
                                                ? '$_deliveryOfferText ($_deliveryNewPrice)'
                                                : _deliveryOfferText,
                                            style: GoogleFonts.poppins(
                                              fontSize: restaurantFontSize - 1,
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
                                  ),
                                );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
