import "dart:async";

import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";
import "package:google_maps_flutter/google_maps_flutter.dart";
import "package:provider/provider.dart";

import "../cart_provider.dart";
import "../l10n/app_localizations.dart";
import "../models/menu_item_customizations.dart";
import "../models/order_item.dart";
import "../providers/location_provider.dart";
import "../screens/map_location_picker_screen.dart";
import "../services/auth_service.dart";
import "../services/geolocation_service.dart";
import "../services/map_location_permission_service.dart";
import "../services/order_service.dart";
import "../services/transition_service.dart";
import "../utils/price_formatter.dart";
import "../widgets/home_screen/home_layout_helper.dart";
import "real_time_order_tracking_screen.dart";

class OrderConfirmFlowScreen extends StatefulWidget {
  const OrderConfirmFlowScreen({super.key});

  @override
  State<OrderConfirmFlowScreen> createState() => _OrderConfirmFlowScreenState();
}

class _OrderConfirmFlowScreenState extends State<OrderConfirmFlowScreen> {
  GoogleMapController? _mapController;
  LatLng? _customerLocation;
  String? _customerAddress;
  String? _secondaryPhone;
  bool _useCurrentLocation = true;
  bool _isLoading = false;
  bool _isLoadingAddress = false;
  bool _locationOptionSelected =
      true; // Track if user has actively selected a location option - default to true for current location
  final int _stepIndex =
      0; // 0: delivery details, 1: preparing, 2: pickup/delivery
  String? _mapStyle; // Simple map style to reduce load
  double _mapZoom = 14;
  MapType _currentMapType = MapType.normal;

  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};

  @override
  void initState() {
    super.initState();
    _loadMapStyle();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initLocation());
  }

  Future<void> _loadMapStyle() async {
    // Map style loading removed - using default map style
    setState(() {
      _mapStyle = null;
    });
  }

  Future<void> _initLocation() async {
    try {
      final geo = GeolocationService();

      // Show last known immediately if available
      final last = await geo.getLastKnownLocation();
      if (last != null) {
        setState(() {
          _customerLocation = LatLng(last.latitude, last.longitude);
          _customerAddress = null; // will enrich later
        });
        _updateMarkers();
        if (_mapController != null && _customerLocation != null) {
          // ignore: unawaited_futures
          _mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(_customerLocation!, 15));
        }
        _updateCartDeliveryLocation();
        // Enrich address in background with loading state
        // ignore: unawaited_futures
        Future<void>.delayed(Duration.zero, () async {
          if (!mounted) return;

          setState(() {
            _isLoadingAddress = true;
          });

          try {
            final placemarks = await geo
                .getAddressFromCoordinates(last.latitude, last.longitude)
                .timeout(const Duration(seconds: 3));

            if (placemarks.isNotEmpty && mounted) {
              final enrichedAddress = [
                placemarks.first.street,
                placemarks.first.locality
              ].where((e) => e != null && e.isNotEmpty).join(", ");

              // Only update if we don't already have a valid address
              if (_customerAddress == null ||
                  _customerAddress!.isEmpty ||
                  _customerAddress == "Address not found" ||
                  _customerAddress == "Unable to get address") {
                setState(() {
                  _customerAddress = enrichedAddress.isNotEmpty
                      ? enrichedAddress
                      : "Address not found";
                  _isLoadingAddress = false;
                });
              } else {
                // We already have an address, just stop loading
                setState(() {
                  _isLoadingAddress = false;
                });
              }
            } else if (mounted) {
              setState(() {
                // Only set error message if we don't already have a valid address
                if (_customerAddress == null || _customerAddress!.isEmpty) {
                  _customerAddress = "Address not found";
                }
                _isLoadingAddress = false;
              });
            }
          } on Exception {
            if (mounted) {
              setState(() {
                // Only set error message if we don't already have a valid address
                if (_customerAddress == null || _customerAddress!.isEmpty) {
                  _customerAddress = "Unable to get address";
                }
                _isLoadingAddress = false;
              });
            }
          }
        });
      }

      // Then get a fast location
      final loc = await geo.getFastLocation();
      if (loc != null) {
        setState(() {
          _customerLocation = LatLng(loc.latitude, loc.longitude);

          // Set address from placemark, with fallback to coordinates if no address available
          if (loc.placemark != null) {
            final addressParts = [
              loc.placemark?.street,
              loc.placemark?.locality
            ].where((e) => e != null && e.isNotEmpty).toList();

            _customerAddress = addressParts.isNotEmpty
                ? addressParts.join(", ")
                : "${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}";
          } else {
            // Fallback to coordinates if no placemark data
            _customerAddress =
                "${loc.latitude.toStringAsFixed(4)}, ${loc.longitude.toStringAsFixed(4)}";
          }

          _locationOptionSelected =
              true; // Mark as selected since location loaded
          _isLoadingAddress = false; // Stop loading if we have address
        });
        _updateMarkers();
        if (_mapController != null && _customerLocation != null) {
          // ignore: unawaited_futures
          _mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(_customerLocation!, 15));
        }
        _updateCartDeliveryLocation();
      }
    } on Exception {
      // Silently ignore location errors
    }
  }

  void _updateMarkers() {
    _markers.clear();
    _circles.clear();

    if (_customerLocation != null) {
      // Add customer location marker with custom icon
      final l10n = AppLocalizations.of(context)!;
      _markers.add(
        Marker(
          markerId: const MarkerId("customer"),
          position: _customerLocation!,
          infoWindow: InfoWindow(
              title: l10n.deliveryAddress,
              snippet: _customerAddress ?? l10n.selectedOnMap),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
        ),
      );

      // Add delivery radius circle (5km radius)
      _circles.add(
        Circle(
          circleId: const CircleId("delivery_radius"),
          center: _customerLocation!,
          radius: 5000, // 5km in meters
          fillColor: Colors.orange.withValues(alpha: 0.1),
          strokeColor: Colors.orange.withValues(alpha: 0.3),
          strokeWidth: 2,
        ),
      );

      // Add accuracy circle if location is precise
      _circles.add(
        Circle(
          circleId: const CircleId("accuracy_circle"),
          center: _customerLocation!,
          radius: 100, // 100m accuracy circle
          fillColor: Colors.blue.withValues(alpha: 0.1),
          strokeColor: Colors.blue.withValues(alpha: 0.3),
          strokeWidth: 1,
        ),
      );
    }
    setState(() {});
  }

  /// Update cart provider with current delivery location for real-time fee calculation
  void _updateCartDeliveryLocation() {
    if (_customerLocation != null) {
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      // Clear delivery fee cache to ensure recalculation with new location
      cartProvider.clearDeliveryFeeCache();
      // Update the cart provider's delivery location to trigger real-time fee calculation
      cartProvider.updateDeliveryLocation(
        latitude: _customerLocation!.latitude,
        longitude: _customerLocation!.longitude,
        restaurantId: null, // Will be inferred from cart items
      );
    }
  }

  /// Get display address with proper fallbacks
  String _getDisplayAddress(String? address, AppLocalizations? l10n) {
    if (address != null &&
        address.isNotEmpty &&
        address != "Address not found" &&
        address != "Unable to get address") {
      return address;
    }

    // If we have a location but no address, show coordinates
    if (_customerLocation != null) {
      return "${_customerLocation!.latitude.toStringAsFixed(4)}, ${_customerLocation!.longitude.toStringAsFixed(4)}";
    }

    // Fallback to localization
    return l10n?.noAddressSelected ?? "No address selected";
  }

  Future<void> _pickOnMap() async {
    final result = await TransitionService.navigateWithTransition(
      context,
      MapLocationPickerScreen(
        initialLatitude: _customerLocation?.latitude,
        initialLongitude: _customerLocation?.longitude,
      ),
      transitionType: TransitionType.slideFromBottom,
    );
    if (result is Map &&
        result["latitude"] != null &&
        result["longitude"] != null) {
      setState(() {
        _customerLocation = LatLng(result["latitude"], result["longitude"]);
        _customerAddress = result["address"]?.toString();
        // Note: _useCurrentLocation and _locationOptionSelected are already set in the ChoiceChip onSelected
      });
      _updateMarkers();
      _updateCartDeliveryLocation();
      if (_mapController != null && _customerLocation != null) {
        // ignore: unawaited_futures
        Future<void>.delayed(Duration.zero, () {
          _mapController!.animateCamera(
              CameraUpdate.newLatLngZoom(_customerLocation!, 16));
        });
      }
    }
  }

  Future<void> _confirmOrder() async {
    final l10n = AppLocalizations.of(context)!;

    if (!_locationOptionSelected) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(l10n.pleaseSelectDeliveryLocation,
                style: GoogleFonts.poppins())),
      );
      return;
    }

    if (_customerLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(l10n.pleaseSelectDeliveryLocationOption,
                style: GoogleFonts.poppins())),
      );
      return;
    }

    // Check location permission and service status before processing
    final locationProvider = Provider.of<LocationProvider>(context, listen: false);
    final hasPermission = locationProvider.hasPermission;
    final isLocationEnabled = locationProvider.isLocationEnabled;

    if (!hasPermission || !isLocationEnabled) {
      // Request permission or show dialog to enable location service
      final permissionResult = await MapLocationPermissionService.checkAndRequestLocationPermission();

      if (!permissionResult.granted) {
        // Show dialog asking user to enable location
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

    setState(() => _isLoading = true);
    try {
      final auth = Provider.of<AuthService>(context, listen: false);
      final cart = Provider.of<CartProvider>(context, listen: false);
      final orderService = Provider.of<OrderService>(context, listen: false);

      if (cart.items.isEmpty) {
        throw Exception("Your cart is empty");
      }

      // Infer restaurant id from cart items (find first non-empty)
      String firstItemRestaurantId = "";
      for (final c in cart.items) {
        final rid =
            (c.customizations?["restaurant_id"]?.toString() ?? "").trim();
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
        "latitude": _customerLocation!.latitude,
        "longitude": _customerLocation!.longitude,
        "fullAddress": _customerAddress ?? "Selected Location",
        "secondaryPhone": (_secondaryPhone ?? "").trim().isEmpty
            ? null
            : _secondaryPhone!.trim(),
        "source": _useCurrentLocation ? "current_location" : "map_pin",
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

      // Navigate to live tracking with smooth animation
      // Keep home screen in stack to avoid reloading data
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
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text("${l10n.failedToConfirmOrder}: $e",
                  style: GoogleFonts.poppins())),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _customerLocation ?? const LatLng(36.7538, 3.0588),
              zoom: _mapZoom,
            ),
            onMapCreated: (c) {
              _mapController = c;
              // Animate to customer location if available
              if (_customerLocation != null) {
                _mapController!.animateCamera(
                    CameraUpdate.newLatLngZoom(_customerLocation!, _mapZoom));
              }
            },
            markers: _markers,
            circles: _circles,
            myLocationEnabled: true,
            myLocationButtonEnabled: true,
            zoomControlsEnabled: true,
            mapType: _currentMapType,
            style: _mapStyle,
            // Map is view-only - users must use "Choose on Map" button to edit location
            onCameraMove: (CameraPosition position) {
              _mapZoom = position.zoom;
            },
            buildingsEnabled: true,
            trafficEnabled: false,
            compassEnabled: true,
          ),

          // Bottom step container
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  top: 20,
                  right: 16,
                  bottom: MediaQuery.of(context).padding.bottom *
                      0.6, // 40% reduction
                ),
                child: _buildStepContent(),
              ),
            ),
          ),

          // Map control buttons - RTL aware positioning
          Positioned(
            top: HomeLayoutHelper.getHeaderTopPosition(context) + 84,
            left: isRTL ? 16 : null,
            right: isRTL ? null : 16,
            child: Column(
              children: [
                // Current location button
                FloatingActionButton(
                  heroTag: "confirm_flow_current_location_fab",
                  onPressed: () {
                    setState(() => _locationOptionSelected =
                        true); // Mark as selected when tapped
                    _initLocation();
                    _updateCartDeliveryLocation();
                  },
                  backgroundColor: Colors.orange[600],
                  foregroundColor: Colors.white,
                  elevation: 4,
                  mini: true,
                  tooltip: l10n.getCurrentLocation,
                  child: const Icon(Icons.my_location),
                ),
                const SizedBox(height: 8),
                // Map type selector button
                FloatingActionButton(
                  heroTag: "confirm_flow_map_type_fab",
                  onPressed: () {
                    setState(() {
                      _currentMapType = _currentMapType == MapType.normal
                          ? MapType.satellite
                          : MapType.normal;
                    });
                  },
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.black87,
                  elevation: 4,
                  mini: true,
                  tooltip: l10n.switchMapType,
                  child: Icon(_currentMapType == MapType.normal
                      ? Icons.satellite
                      : Icons.map),
                ),
              ],
            ),
          ),

          // Header with back arrow and address field - RTL aware
          Positioned(
            top: HomeLayoutHelper.getHeaderTopPosition(context),
            left: 16,
            right: 16,
            child: Row(
              children: [
                // Back arrow button
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: IconButton(
                    icon: Icon(
                      isRTL
                          ? Icons.keyboard_arrow_right
                          : Icons.keyboard_arrow_left,
                      color: Colors.black87,
                      size: 18,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                  ),
                ),
                const SizedBox(width: 12),
                // Address field - full available width
                Expanded(
                  child: Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        if (isRTL) ...[
                          Expanded(
                            child: _isLoadingAddress
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      Text(
                                        l10n.loadingAddress,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                        textAlign: TextAlign.right,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(width: 6),
                                      SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.orange[600]!,
                                          ),
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    _getDisplayAddress(_customerAddress, l10n),
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.right,
                                  ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.home, size: 16, color: Colors.black54),
                        ] else ...[
                          const Icon(Icons.home, size: 16, color: Colors.black54),
                          const SizedBox(width: 6),
                          Expanded(
                            child: _isLoadingAddress
                                ? Row(
                                    children: [
                                      SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                            Colors.orange[600]!,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        l10n.loadingAddress,
                                        style: GoogleFonts.poppins(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  )
                                : Text(
                                    _getDisplayAddress(_customerAddress, l10n),
                                    style: GoogleFonts.poppins(
                                      fontSize: 12,
                                      color: Colors.black87,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.white.withValues(alpha: 0.6),
              child: const Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_stepIndex) {
      case 0:
        return _buildStepDeliveryDetails();
      case 1:
        return _buildStepPreparing();
      case 2:
        return _buildStepPickup();
      default:
        return _buildStepDeliveryDetails();
    }
  }

  Widget _buildStepDeliveryDetails() {
    final l10n = AppLocalizations.of(context)!;
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Align(
          alignment: isRTL ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(l10n.deliveryDetails,
              style: GoogleFonts.poppins(
                  fontSize: 16, fontWeight: FontWeight.w600),
              textAlign: isRTL ? TextAlign.right : TextAlign.left),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: Text(l10n.useCurrentLocation),
                selected: _useCurrentLocation,
                showCheckmark: false,
                labelStyle: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: _useCurrentLocation ? Colors.white : Colors.black87,
                ),
                backgroundColor: Colors.white,
                selectedColor: Colors.orange[600],
                shape: const StadiumBorder(
                    side: BorderSide(color: Color(0xFFE0E0E0), width: 1)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                onSelected: (v) async {
                  if (!v) {
                    return;
                  }
                  setState(() {
                    _useCurrentLocation = true;
                    _locationOptionSelected =
                        true; // Mark as selected when user taps
                  });
                  await _initLocation();
                },
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: InkWell(
                onTap: () async {
                  // Always allow tapping to open map picker
                  setState(() {
                    _useCurrentLocation = false;
                    _locationOptionSelected = true;
                  });
                  await _pickOnMap();
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: (!_useCurrentLocation && _locationOptionSelected)
                        ? Colors.orange[600]
                        : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: const Color(0xFFE0E0E0), width: 1),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (isRTL) ...[
                        Flexible(
                          child: Text(
                            l10n.chooseOnMap,
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: (!_useCurrentLocation &&
                                        _locationOptionSelected)
                                    ? Colors.white
                                    : Colors.black87),
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.location_on,
                            size: 14,
                            color: (!_useCurrentLocation &&
                                    _locationOptionSelected)
                                ? Colors.white
                                : Colors.black87),
                      ] else ...[
                        Icon(Icons.location_on,
                            size: 14,
                            color: (!_useCurrentLocation &&
                                    _locationOptionSelected)
                                ? Colors.white
                                : Colors.black87),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            l10n.chooseOnMap,
                            style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                                color: (!_useCurrentLocation &&
                                        _locationOptionSelected)
                                    ? Colors.white
                                    : Colors.black87),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          keyboardType: TextInputType.phone,
          textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
          decoration: InputDecoration(
            labelText: l10n.secondaryPhoneOptional,
            filled: true,
            fillColor: Colors.grey[50],
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide(color: Colors.grey[300]!)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide: BorderSide(color: Colors.grey[300]!)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(28),
                borderSide:
                    const BorderSide(color: Color(0xFFFB8C00), width: 2)),
          ),
          onChanged: (v) => _secondaryPhone = v,
        ),
        const SizedBox(height: 16),

        // Price Breakdown - matching cart screen style
        Consumer<CartProvider>(
          builder: (context, cartProvider, child) {
            final total = cartProvider.totalOrderAmount;

            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.grey[100]!,
                  width: 0.5,
                ),
              ),
              child: Column(
                children: [
                  // Delivery Fee with special delivery badge
                  _buildDeliveryFeeRow(cartProvider, context, l10n, isRTL),

                  const Divider(height: 12),

                  // Total with Confirm button - RTL aware layout
                  Row(
                    textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
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
                      ElevatedButton(
                        onPressed: _confirmOrder,
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
                          l10n.confirm,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDeliveryFeeRow(CartProvider cartProvider, BuildContext context,
      AppLocalizations l10n, bool isRTL) {
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
            PriceFormatter.formatWithSettings(context, deliveryFee.toString()),
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.black87,
            ),
            textAlign: isRTL ? TextAlign.right : TextAlign.left,
          ),
        ],
      );
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
            PriceFormatter.formatWithSettings(context, deliveryFee.toString()),
            style: GoogleFonts.poppins(
              fontSize: 13,
              color: Colors.black87,
            ),
            textAlign: isRTL ? TextAlign.right : TextAlign.left,
          ),
        ],
      );
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

  Widget _buildStepPreparing() {
    final l10n = AppLocalizations.of(context)!;
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (isRTL) ...[
          Expanded(
            child: Text(
              "${l10n.preparingOrder} ${l10n.preparingOrderSubtext}",
              style: GoogleFonts.poppins(fontSize: 14),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 12),
          const CircularProgressIndicator(strokeWidth: 3),
          const SizedBox(width: 8),
        ] else ...[
          const SizedBox(width: 8),
          const CircularProgressIndicator(strokeWidth: 3),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "${l10n.preparingOrder} ${l10n.preparingOrderSubtext}",
              style: GoogleFonts.poppins(fontSize: 14),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildStepPickup() {
    final l10n = AppLocalizations.of(context)!;
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment:
          isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(l10n.readyForPickup,
            style:
                GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
            textAlign: isRTL ? TextAlign.right : TextAlign.left),
        const SizedBox(height: 6),
        Text(l10n.deliveryPartnerPickup,
            style: GoogleFonts.poppins(fontSize: 14),
            textAlign: isRTL ? TextAlign.right : TextAlign.left),
      ],
    );
  }
}
