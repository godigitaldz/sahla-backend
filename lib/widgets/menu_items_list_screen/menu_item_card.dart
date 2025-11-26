import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../features/reviews/ui/reviews_screen.dart';
import '../../l10n/app_localizations.dart';
import '../../models/menu_item.dart';
import '../../providers/delivery_fee_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/delivery_fee_service.dart';
import '../menu_item_full_popup/helpers/popup_helper.dart';
import 'components/delivery_fee_display.dart';
import 'components/menu_item_image.dart';
import 'components/menu_item_name_display.dart';
import 'components/price_prep_time_display.dart';
import 'components/rating_stars_display.dart';
import 'components/restaurant_name_header.dart';
import 'components/review_count_display.dart';

/// High-performance menu item card widget optimized for lists with 1000+ items
///
/// Performance optimizations:
/// - RepaintBoundary to isolate repaints
/// - Efficient key management
/// - Cached network images with proper sizing (120x120 for speed)
/// - Minimal rebuilds
/// - Memory-efficient rendering
/// - Aggressive caching to prevent refresh on scroll
/// - Delivery fee calculated once and cached
///
/// Handles 1000+ items smoothly with:
/// - Lazy loading
/// - Image caching
/// - Isolated widget repaints
class MenuItemCard extends StatefulWidget {
  const MenuItemCard({
    required this.menuItem,
    required this.onCacheCleared,
    required this.onDataChanged,
    super.key,
  });

  final MenuItem menuItem;
  final VoidCallback onCacheCleared;
  final VoidCallback onDataChanged;

  @override
  State<MenuItemCard> createState() => _MenuItemCardState();
}

class _MenuItemCardState extends State<MenuItemCard> {
  double? _deliveryFee;
  bool _isLoadingFee = true;

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
      }
    }
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
          menuItem: widget.menuItem, // Pass variant card directly
          onItemAddedToCart: (orderItem) {
            // Show confirmation when item is added to cart
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  "${orderItem.menuItem?.name ?? l10n.item} ${l10n.addedToCart}",
                ),
                duration: const Duration(seconds: 2),
                backgroundColor: Colors.green[600],
              ),
            );
          },
          onDataChanged: () {
            // Clear cache and refresh menu items when review is submitted
            widget.onCacheCleared();
            widget.onDataChanged();
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
                    // Header section with restaurant name and delivery fee
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Restaurant name on the left
                        Expanded(
                          child: RestaurantNameHeader(
                            restaurantName: widget.menuItem.restaurantName,
                            fontSize: _getAdaptiveFontSize(_screenWidth, 12),
                          ),
                        ),

                        const SizedBox(width: 8),

                        // Delivery fee with icon on the right - hide if no location permission or service
                        Consumer<LocationProvider>(
                          builder: (context, locationProvider, child) {
                            final hasPermission = locationProvider.hasPermission;
                            final isLocationEnabled = locationProvider.isLocationEnabled;

                            // Hide delivery fee if no permission or service is off
                            if (!hasPermission || !isLocationEnabled) {
                              return const SizedBox.shrink();
                            }

                            return DeliveryFeeDisplay(
                              deliveryFee: _deliveryFee,
                              isLoading: _isLoadingFee,
                              fontSize: _getAdaptiveFontSize(_screenWidth, 12),
                              iconSize: _getAdaptiveIconSize(_screenWidth, 16),
                            );
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
                              children: [
                                // Item name - RTL aware
                                MenuItemNameDisplay(
                                  name: widget.menuItem.name,
                                  fontSize: _itemNameFontSize,
                                  isRTL: isRTL,
                                ),

                                const SizedBox(
                                    height:
                                        10), // Increased from 8 to 10 (25% increase)

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

                                const SizedBox(
                                    height:
                                        12), // Increased from 10 to 12 (20% increase)

                                // Price and prep time in white container
                                PricePrepTimeDisplay(
                                  price: widget.menuItem.price,
                                  prepTime: widget.menuItem.preparationTime,
                                  priceFontSize: _priceFontSize,
                                  prepFontSize: _prepTimeFontSize,
                                  iconSize:
                                      _getAdaptiveIconSize(_screenWidth, 14) *
                                          0.9,
                                  isRTL: isRTL,
                                ),
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
