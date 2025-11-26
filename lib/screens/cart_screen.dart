import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../cart_provider.dart';
import '../l10n/app_localizations.dart';
import '../models/promo_code.dart';
import '../providers/location_provider.dart';
import '../services/geolocation_service.dart';
import '../services/map_location_permission_service.dart';
import '../services/promo_code_service.dart';
import '../services/transition_service.dart';
import '../utils/discount_formatter.dart';
import '../utils/price_formatter.dart';
import '../utils/responsive_sizing.dart';
import '../widgets/cart_screen/cart_drinks_section.dart';
import '../widgets/cart_screen/empty_cart_widget.dart';
import '../widgets/cart_screen/order_details_summary.dart';
import '../widgets/home_screen/home_layout_helper.dart';
import 'map_location_picker_screen.dart';
import 'real_time_order_tracking_screen.dart';
import '../models/menu_item_customizations.dart';
import '../models/order_item.dart';
import '../services/auth_service.dart';
import '../services/order_service.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> with TickerProviderStateMixin {
  final TextEditingController _promoCodeController = TextEditingController();
  bool _isApplyingPromoCode = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));

    // Start the animation
    _animationController.forward();

    // Trigger delivery fee calculation once we have a location
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initDeliveryFeeFromLocation();
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _promoCodeController.dispose();
    super.dispose();
  }

  Future<void> _initDeliveryFeeFromLocation() async {
    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      if (cartProvider.isEmpty) return;

      // Check if delivery is free due to special offers - skip location request if free
      final discountDetails = cartProvider.specialDeliveryDiscountDetails;
      if (discountDetails != null) {
        final discountType = discountDetails['type'] as String?;
        // If delivery is completely free, skip location request
        if (discountType == 'free') {
          debugPrint('📍 Cart: Delivery is free, skipping location request');
          return;
        }
      }

      // Check location permission first
      final permissionResult = await MapLocationPermissionService
          .checkAndRequestLocationPermission();

      if (!permissionResult.granted) {
        debugPrint('📍 Cart: Location permission not granted, skipping delivery fee calculation');

        // If permission is denied but not permanently, show a message
        if (permissionResult.needsPermission && mounted) {
          // Show a snackbar to inform user
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location permission is required to calculate delivery fee'),
              duration: const Duration(seconds: 3),
              action: permissionResult.needsSettings
                  ? SnackBarAction(
                      label: 'Open Settings',
                      onPressed: () async {
                        await MapLocationPermissionService.openAppSettings();
                      },
                    )
                  : null,
            ),
          );
        }
        return;
      }

      // Permission granted, get location
      final geo = GeolocationService();
      LocationData? loc;

      try {
        // Try last known location first (faster)
        loc = await geo.getLastKnownLocation();

        // If no last known location, get current location
        if (loc == null) {
          loc = await geo.getCurrentLocation();
        }
      } catch (e) {
        debugPrint('❌ Cart: Error getting location: $e');
        // Check if location services are disabled
        final serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Please enable location services to calculate delivery fee'),
              duration: const Duration(seconds: 3),
              action: SnackBarAction(
                label: 'Enable',
                onPressed: () async {
                  await MapLocationPermissionService.openLocationSettings();
                },
              ),
            ),
          );
        }
        return;
      }

      if (loc != null) {
        // restaurantId inferred inside CartProvider if not provided
        await cartProvider.updateDeliveryLocation(
          latitude: loc.latitude,
          longitude: loc.longitude,
        );
      }
    } catch (e) {
      debugPrint('❌ Cart: Error in delivery fee initialization: $e');
      // non-fatal, continue without location-based delivery fee
    }
  }

  Future<void> _applyPromoCode() async {
    final l10n = AppLocalizations.of(context)!;
    final code = _promoCodeController.text.trim();
    if (code.isEmpty) {
      _showErrorMessage(l10n.enterPromoCode);
      return;
    }

    setState(() {
      _isApplyingPromoCode = true;
    });

    try {
      final promoCodeService =
          Provider.of<PromoCodeService>(context, listen: false);

      // Use direct validation to bypass the problematic API endpoint
      final validationResult = await promoCodeService.validatePromoCodeDirect(
        code,
        restaurantId: null,
        userId: null,
      );

      final promoCode = validationResult["promoCode"];
      final errorMessage = validationResult["errorMessage"];

      if (promoCode != null && mounted) {
        final cartProvider = Provider.of<CartProvider>(context, listen: false);

        // For cart screen context, we'll use null for restaurant ID since we don't have a specific restaurant selected
        final success = cartProvider.applyPromoCode(promoCode, null);

        if (success) {
          _promoCodeController.clear();
          _showSuccessMessage(l10n.promoCodeApplied);
        } else {
          _showErrorMessage(l10n.promoCodeNotApplicable);
        }
      } else {
        _showErrorMessage(errorMessage ?? l10n.invalidPromoCode);
      }
    } catch (e) {
      debugPrint('Error applying promo code: $e');
      _showErrorMessage(l10n.errorApplyingPromoCode);
    } finally {
      setState(() {
        _isApplyingPromoCode = false;
      });
    }
  }

  void _removePromoCode() {
    final l10n = AppLocalizations.of(context)!;
    try {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      cartProvider.removePromoCode();
      _showSuccessMessage(l10n.promoCodeRemoved);
    } catch (e) {
      debugPrint('Error removing promo code: $e');
      _showErrorMessage(l10n.errorRemovingPromoCode);
    }
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  void _showSuccessMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    // Calculate safe area-aware header dimensions
    final headerTopPosition = HomeLayoutHelper.getHeaderTopPosition(context);
    final containerHeight = 52.0;
    const bottomSpacing = 12.0;
    final preferredHeight = headerTopPosition + containerHeight + bottomSpacing;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(preferredHeight),
        child: Padding(
          padding: EdgeInsets.only(top: headerTopPosition),
          child: Container(
            height: containerHeight,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            padding: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Row(
              children: [
                // Back Button - RTL aware
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: IconButton(
                    icon: Icon(
                        isRTL
                            ? Icons.keyboard_arrow_right
                            : Icons.keyboard_arrow_left,
                        size: 16),
                    color: Colors.black87,
                    onPressed: () => Navigator.pop(context),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ),

                const SizedBox(width: 12),

                // Title
                Expanded(
                  child: Text(
                    l10n.yourOrder,
                    style: GoogleFonts.poppins(
                      fontSize: ResponsiveSizing.fontSize(16, context),
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                const SizedBox(width: 12),

                // Clear All Button - RTL aware positioning
                Consumer<CartProvider>(
                  builder: (context, cartProvider, child) {
                    if (cartProvider.isEmpty) {
                      return const SizedBox(width: 80);
                    }

                    return Container(
                      height: 32,
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: TextButton(
                        onPressed: () => _showClearCartDialog(context),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 0),
                          minimumSize: const Size(0, 32),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          l10n.clearAll,
                          style: GoogleFonts.poppins(
                            fontSize: ResponsiveSizing.fontSize(12, context),
                            color: Colors.red[600],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: Consumer<CartProvider>(
            builder: (context, cartProvider, child) {
              if (cartProvider.isEmpty) {
                return const EmptyCartWidget();
              }

              return Column(
                children: [
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          // Order Details Summary with animation
                          AnimatedBuilder(
                            animation: _fadeAnimation,
                            builder: (context, child) {
                              return Transform.translate(
                                offset:
                                    Offset(0, 20 * (1 - _fadeAnimation.value)),
                                child: Opacity(
                                  opacity: _fadeAnimation.value,
                                  child: Builder(
                                    builder: (context) {
                                      try {
                                        return OrderDetailsSummary(
                                          onCheckout: () =>
                                              _navigateToCheckout(context),
                                          showPriceSummary:
                                              false, // Hide extra price section in summary
                                        );
                                      } catch (e) {
                                        debugPrint(
                                            'Error loading order summary: $e');
                                        final l10n = AppLocalizations.of(context)!;
                                        return Center(
                                          child: Text(
                                            l10n.errorLoadingOrderSummary,
                                            style: GoogleFonts.poppins(
                                                color: Colors.red),
                                          ),
                                        );
                                      }
                                    },
                                  ),
                                ),
                              );
                            },
                          ),

                          // Drinks by restaurant section (wrapped in white container)
                          const CartDrinksSection(),

                          // Extra spacing at bottom for the floating bar
                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),

                  // Bottom price bar - always visible
                  // Bottom Price Bar with animation
                  AnimatedBuilder(
                    animation: _fadeAnimation,
                    builder: (context, child) {
                      return Transform.translate(
                        offset: Offset(0, 30 * (1 - _fadeAnimation.value)),
                        child: Opacity(
                          opacity: _fadeAnimation.value,
                          child: Padding(
                            padding: EdgeInsets.only(
                              bottom: MediaQuery.of(context).padding.bottom *
                                  0.6, // 40% reduction
                            ),
                            child: _buildBottomPriceBar(context, cartProvider),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  void _showClearCartDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.clearCart,
          style: GoogleFonts.poppins(
            fontSize: ResponsiveSizing.fontSize(18, context),
            fontWeight: FontWeight.w600,
          ),
        ),
        content: Text(
          l10n.clearCartConfirmation,
          style: GoogleFonts.poppins(
            fontSize: ResponsiveSizing.fontSize(14, context),
            color: Colors.grey[600],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.cancel,
              style: GoogleFonts.poppins(
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              Provider.of<CartProvider>(context, listen: false).clearCart();
              Navigator.pop(context);
            },
            child: Text(
              l10n.clear,
              style: GoogleFonts.poppins(
                color: Colors.red[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomPriceBar(BuildContext context, CartProvider cartProvider) {
    final l10n = AppLocalizations.of(context)!;
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    final subtotal = cartProvider.subtotal;
    final discountAmount = cartProvider.discountAmount;
    final total = cartProvider.totalOrderAmount;
    final appliedPromoCode = cartProvider.appliedPromoCode;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24), // Fully rounded corners
        border: Border.all(
          color: Colors.grey[100]!,
          width: 1,
        ),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white,
            Colors.grey[50]!.withValues(alpha: 0.5),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
            spreadRadius: 2,
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Promo Code Section - Integrated at top
          if (appliedPromoCode == null)
            _buildPromoCodeInput()
          else
            _buildAppliedPromoCode(appliedPromoCode),

          const SizedBox(height: 12),

          // Discount validation warning
          if (!DiscountFormatter.isDiscountValid(
              discountAmount, subtotal)) ...[
            DiscountFormatter.buildDiscountWarning(
                context,
                DiscountFormatter.getDiscountValidationMessage(
                        discountAmount, subtotal) ??
                    l10n.invalidPromoCode),
          ],

          // Discount (if applicable)
          if (discountAmount > 0) ...[
            const SizedBox(height: 4),
            DiscountFormatter.buildDiscountRow(
                context, l10n.discount, discountAmount),
          ],

          const SizedBox(height: 4),

          // Delivery Fee with special delivery badge
          _buildDeliveryFeeRow(cartProvider, context),

          const SizedBox(height: 4),

          // Total Price (moved under delivery fee)
          Row(
            textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "${l10n.total} ",
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                PriceFormatter.formatWithSettings(
                    context, total.toString()),
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[600],
                ),
              ),
            ],
          ),

          const Divider(height: 12),

          // Confirm button - RTL aware layout
          Consumer<LocationProvider>(
                  builder: (context, locationProvider, child) {
                    // Check if location is available
                    final hasPermission = locationProvider.hasPermission;
                    final isLocationEnabled = locationProvider.isLocationEnabled;
                    final hasLocation = hasPermission && isLocationEnabled;

                    // If no location, show "Pick Location" button
                    if (!hasLocation) {
                      return Row(
                        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          ElevatedButton(
                            onPressed: () => _pickLocationOnMap(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange[600],
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 20, vertical: 8),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20),
                              ),
                              elevation: 2,
                            ),
                            child: Text(
                              l10n.pickLocation,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    // If location is available, show "Edit Location" and "Confirm" buttons
                    return Row(
                      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                      children: [
                        // Edit Location button - 50% width
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: isRTL ? 0 : 4,
                              left: isRTL ? 4 : 0,
                            ),
                            child: OutlinedButton(
                              onPressed: () => _pickLocationOnMap(context),
                              style: OutlinedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.black87,
                                side: BorderSide(color: Colors.grey[300]!),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                              child: Text(
                                l10n.editLocation,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // Confirm button - 50% width
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.only(
                              right: isRTL ? 4 : 0,
                              left: isRTL ? 0 : 4,
                            ),
                            child: ElevatedButton(
                              onPressed: () => _navigateToCheckout(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange[600],
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 8),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                elevation: 2,
                              ),
                              child: Text(
                                l10n.confirm,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount, BuildContext context) {
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return Row(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.grey[600],
          ),
          textAlign: isRTL ? TextAlign.right : TextAlign.left,
        ),
        Text(
          PriceFormatter.formatWithSettings(context, amount.toString()),
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.black87,
          ),
          textAlign: isRTL ? TextAlign.right : TextAlign.left,
        ),
      ],
    );
  }

  Widget _buildDeliveryFeeRow(CartProvider cartProvider, BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    // Check location permission and service status
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final hasPermission = locationProvider.hasPermission;
    final isLocationEnabled = locationProvider.isLocationEnabled;

    // If no permission or service is off, show "no location provided"
    if (!hasPermission || !isLocationEnabled) {
      return Row(
        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l10n.deliveryFee,
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey[600],
            ),
            textAlign: isRTL ? TextAlign.right : TextAlign.left,
          ),
          Text(
            'No location provided',
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
            textAlign: isRTL ? TextAlign.right : TextAlign.left,
          ),
        ],
      );
    }

    final deliveryFee = cartProvider.deliveryFee;
    final discountDetails = cartProvider.specialDeliveryDiscountDetails;

    // If there's no special delivery discount, show normal delivery fee row
    if (discountDetails == null) {
      return _buildPriceRow(l10n.deliveryFee, deliveryFee, context);
    }

    final discountType = discountDetails['type'] as String;
    final discountValue = discountDetails['value'] as num;

    // Build discount badge based on type
    Widget discountBadge;
    if (discountType == 'free') {
      // Free delivery - show "FREE" badge only
      discountBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red[600],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          'FREE',
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    } else if (discountType == 'percentage') {
      // Percentage discount - show "-50%" badge
      discountBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red[600],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '-${discountValue.toInt()}%',
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    } else if (discountType == 'fixed') {
      // Fixed amount discount - show "-100 DA" badge
      discountBadge = Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.red[600],
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          '-${discountValue.toInt()} DA',
          style: GoogleFonts.poppins(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    } else {
      // Unknown type, show normal row
      return _buildPriceRow(l10n.deliveryFee, deliveryFee, context);
    }

    // Build the row with label, badge, and amount
    return Row(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          l10n.deliveryFee,
          style: GoogleFonts.poppins(
            fontSize: 13,
            color: Colors.grey[600],
          ),
          textAlign: isRTL ? TextAlign.right : TextAlign.left,
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: isRTL
              ? [
                  Text(
                    PriceFormatter.formatWithSettings(
                        context, deliveryFee.toString()),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(width: 6),
                  discountBadge,
                ]
              : [
                  discountBadge,
                  const SizedBox(width: 6),
                  Text(
                    PriceFormatter.formatWithSettings(
                        context, deliveryFee.toString()),
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      color: Colors.black87,
                    ),
                  ),
                ],
        ),
      ],
    );
  }

  Widget _buildPromoCodeInput() {
    final l10n = AppLocalizations.of(context)!;
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          if (isRTL) ...[
            // Apply button
            InkWell(
              onTap: _isApplyingPromoCode ? null : _applyPromoCode,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _isApplyingPromoCode
                      ? Colors.grey[300]
                      : Colors.orange[600],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _isApplyingPromoCode
                    ? const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        l10n.apply,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            // Promo code input
            Expanded(
              child: TextField(
                controller: _promoCodeController,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                decoration: InputDecoration(
                  hintText: l10n.enterPromoCode,
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[500],
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.grey[300]!,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.grey[400]!,
                      width: 1.5,
                    ),
                  ),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                textCapitalization: TextCapitalization.none,
              ),
            ),
          ] else ...[
            // Promo code input
            Expanded(
              child: TextField(
                controller: _promoCodeController,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                decoration: InputDecoration(
                  hintText: l10n.enterPromoCode,
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[500],
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.grey[300]!,
                      width: 1.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: Colors.grey[400]!,
                      width: 1.5,
                    ),
                  ),
                  isDense: true,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                textCapitalization: TextCapitalization.none,
              ),
            ),
            const SizedBox(width: 12),
            // Apply button
            InkWell(
              onTap: _isApplyingPromoCode ? null : _applyPromoCode,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: _isApplyingPromoCode
                      ? Colors.grey[300]
                      : Colors.orange[600],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _isApplyingPromoCode
                    ? const SizedBox(
                        height: 14,
                        width: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : Text(
                        l10n.apply,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Generate localized description for promo code
  String _getLocalizedPromoDescription(PromoCode promoCode) {
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    switch (promoCode.type) {
      case PromoCodeType.percentage:
        // Add max discount info if applicable
        if (promoCode.maximumDiscountAmount != null &&
            promoCode.maximumDiscountAmount! > 0) {
          return isArabic
              ? 'استخدم الكود ${promoCode.code} للحصول على خصم ${promoCode.value.toInt()}٪ (حد أقصى ${promoCode.maximumDiscountAmount!.toInt()} د.ج)'
              : 'Use code ${promoCode.code} for ${promoCode.value.toInt()}% off (max ${promoCode.maximumDiscountAmount!.toInt()} DZD)';
        }
        return isArabic
            ? 'استخدم الكود ${promoCode.code} للحصول على خصم ${promoCode.value.toInt()}٪'
            : 'Use code ${promoCode.code} for ${promoCode.value.toInt()}% off';

      case PromoCodeType.fixedAmount:
        return isArabic
            ? 'استخدم الكود ${promoCode.code} للحصول على خصم ${promoCode.value.toInt()} د.ج'
            : 'Use code ${promoCode.code} for ${promoCode.value.toInt()} DZD off';

      case PromoCodeType.freeDelivery:
        return isArabic
            ? 'استخدم الكود ${promoCode.code} للحصول على توصيل مجاني'
            : 'Use code ${promoCode.code} for free delivery';

      case PromoCodeType.buyOneGetOne:
        return isArabic
            ? 'استخدم الكود ${promoCode.code} لعرض اشتري واحد واحصل على الثاني'
            : 'Use code ${promoCode.code} for buy one get one';
    }
  }

  Widget _buildAppliedPromoCode(PromoCode promoCode) {
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    final localizedDescription = _getLocalizedPromoDescription(promoCode);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.grey[200]!,
          width: 1,
        ),
      ),
      child: Row(
        children: [
          if (isRTL) ...[
            // Remove button
            InkWell(
              onTap: _removePromoCode,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.close,
                  color: Colors.red[600],
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Promo code details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    promoCode.code,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                    textAlign: TextAlign.right,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    localizedDescription,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.green[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Success icon
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 22,
            ),
          ] else ...[
            // Success icon
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 22,
            ),
            const SizedBox(width: 10),
            // Promo code details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    promoCode.code,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    localizedDescription,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.green[600],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            // Remove button
            InkWell(
              onTap: _removePromoCode,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.close,
                  color: Colors.red[600],
                  size: 16,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _navigateToCheckout(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);

    // Check if cart is empty
    if (cartProvider.items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.cartEmpty, style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check location permission and service status
    final hasPermission = locationProvider.hasPermission;
    final isLocationEnabled = locationProvider.isLocationEnabled;

    if (!hasPermission || !isLocationEnabled) {
      final permissionResult = await MapLocationPermissionService.checkAndRequestLocationPermission();

      if (!permissionResult.granted) {
        await MapLocationPermissionService.showPermissionDialog(
          context,
          title: 'Location Permission Required',
          message: permissionResult.message,
          onRequestPermission: () async {
            await MapLocationPermissionService.checkAndRequestLocationPermission();
          },
          onOpenSettings: () async {
            if (permissionResult.needsLocationServices) {
              await MapLocationPermissionService.openLocationSettings();
            } else {
              await MapLocationPermissionService.openAppSettings();
            }
          },
        );
        return;
      }

      // Re-check after permission request
      await locationProvider.checkLocationStatus();
      final newHasPermission = locationProvider.hasPermission;
      final newIsLocationEnabled = locationProvider.isLocationEnabled;

      if (!newHasPermission || !newIsLocationEnabled) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please enable location permission and service to continue',
              style: GoogleFonts.poppins(),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
        return;
      }
    }

    // Check if delivery location is set
    if (cartProvider.deliveryLatitude == null || cartProvider.deliveryLongitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            l10n.pleaseSelectDeliveryLocation,
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Show loading indicator
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final cart = Provider.of<CartProvider>(context, listen: false);
      final orderService = Provider.of<OrderService>(context, listen: false);

      // Infer restaurant id from cart items
      String firstItemRestaurantId = "";
      for (final c in cart.items) {
        final rid = (c.customizations?["restaurant_id"]?.toString() ?? "").trim();
        if (rid.isNotEmpty) {
          firstItemRestaurantId = rid;
          break;
        }
      }
      if (firstItemRestaurantId.isEmpty) {
        throw Exception("Restaurant not specified");
      }

      // Validate restaurant ID format
      final uuidRegex = RegExp(
          r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$");
      if (!uuidRegex.hasMatch(firstItemRestaurantId)) {
        throw Exception("Invalid restaurant ID format");
      }

      // Build delivery address payload
      final deliveryAddress = {
        "latitude": cartProvider.deliveryLatitude!,
        "longitude": cartProvider.deliveryLongitude!,
        "fullAddress": cartProvider.deliveryAddress ?? "Selected Location",
        "secondaryPhone": null,
        "source": "current_location",
      };

      // Validate and map cart items to order items
      final orderItems = cart.items.map((c) {
        final menuItemId = c.customizations?["menu_item_id"]?.toString() ?? "";
        if (menuItemId.isEmpty) {
          throw Exception("Menu item ID is missing for cart item: ${c.name}");
        }

        // Validate menu item ID format
        final uuidRegex = RegExp(
            r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$");
        if (!uuidRegex.hasMatch(menuItemId)) {
          throw Exception("Invalid menu item ID format for: ${c.name}");
        }

        if (c.quantity <= 0) {
          throw Exception("Invalid quantity for cart item: ${c.name}");
        }

        if (c.price <= 0) {
          throw Exception("Invalid price for cart item: ${c.name}");
        }

        return OrderItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          orderId: "",
          menuItemId: menuItemId,
          quantity: c.quantity,
          unitPrice: c.price,
          totalPrice: c.totalPrice,
          specialInstructions: c.specialInstructions,
          customizations: c.customizations != null
              ? MenuItemCustomizations.fromMap(c.customizations!)
              : null,
          createdAt: DateTime.now(),
          menuItem: null,
        );
      }).toList();

      final currentUser = auth.currentUser;
      if (currentUser == null) {
        throw Exception("Not signed in");
      }

      // Create COD order
      final order = await orderService.createOrder(
        restaurantId: firstItemRestaurantId,
        customerId: currentUser.id,
        orderItems: orderItems,
        deliveryAddress: deliveryAddress,
        paymentMethod: "cash_on_delivery",
        specialInstructions: null,
        estimatedDeliveryTime: null,
      );

      if (order == null) {
        throw Exception("Failed to create order");
      }

      // Clear cart after successful order
      cart.clearCart();

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Navigate to live tracking with smooth animation
      if (mounted) {
        await Navigator.pushAndRemoveUntil(
          context,
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                RealTimeOrderTrackingScreen(order: order),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              // Slide up animation with fade
              const begin = Offset(0.0, 1.0);
              const end = Offset.zero;
              const curve = Curves.easeOutCubic;

              final tween = Tween(begin: begin, end: end).chain(
                CurveTween(curve: curve),
              );

              final offsetAnimation = animation.drive(tween);

              // Fade animation
              final fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.0, 0.6, curve: Curves.easeIn),
                ),
              );

              // Scale animation for a subtle zoom effect
              final scaleAnimation =
                  Tween<double>(begin: 0.95, end: 1.0).animate(
                CurvedAnimation(
                  parent: animation,
                  curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
                ),
              );

              return SlideTransition(
                position: offsetAnimation,
                child: FadeTransition(
                  opacity: fadeAnimation,
                  child: ScaleTransition(
                    scale: scaleAnimation,
                    child: child,
                  ),
                ),
              );
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
          (route) => route.isFirst, // Keep only the first route (home screen)
        );
      }
    } on Exception catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceAll('Exception: ', ''),
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'An unexpected error occurred: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _pickLocationOnMap(BuildContext context) async {
    try {
      final result = await TransitionService.navigateWithTransition(
        context,
        const MapLocationPickerScreen(),
        transitionType: TransitionType.slideFromBottom,
      );

      if (result is Map &&
          result["latitude"] != null &&
          result["longitude"] != null) {
        final latitude = (result["latitude"] as num).toDouble();
        final longitude = (result["longitude"] as num).toDouble();

        // Update cart delivery location
        final cartProvider = Provider.of<CartProvider>(context, listen: false);
        await cartProvider.updateDeliveryLocation(
          latitude: latitude,
          longitude: longitude,
          address: result["address"]?.toString(),
        );

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                result["address"]?.toString() ?? 'Location selected',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('❌ Error picking location: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error opening map: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
