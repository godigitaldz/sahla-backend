import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../home_screen.dart';
import '../l10n/app_localizations.dart';
import '../models/order.dart';
import '../models/restaurant.dart';
import '../services/comprehensive_maps_service.dart';
import '../services/delivery_tracking_service.dart';
import '../services/directions_service.dart';
import '../services/enhanced_order_tracking_service.dart';
import '../services/geolocation_service.dart';
import '../services/order_service.dart';
import '../widgets/real_time_order_tracking_screen/floating_3d_card.dart';

// ==== Tuning constants (easy to adjust) ====
// How often to poll the server for latest order status
const Duration kOrderStatusPollInterval = Duration(seconds: 5);

// How often to update camera following when live tracking is active
const Duration kCameraFollowInterval = Duration(seconds: 3);

// Minimum movement required to update UI (in kilometers). 0.01 km = 10 meters
const double kMinMovementKmToUpdate = 0.01;

// Zoom levels used when following delivery and when recentring
const double kFollowZoomLevel = 16.0;
const double kRecenterZoomLevel = 16.0;

class RealTimeOrderTrackingScreen extends StatefulWidget {
  final Order order;
  final bool isDeliveryPersonView; // true if delivery person is viewing

  const RealTimeOrderTrackingScreen({
    required this.order,
    super.key,
    this.isDeliveryPersonView = false,
  });

  @override
  State<RealTimeOrderTrackingScreen> createState() =>
      _RealTimeOrderTrackingScreenState();
}

class _RealTimeOrderTrackingScreenState
    extends State<RealTimeOrderTrackingScreen> with TickerProviderStateMixin {
  GoogleMapController? _mapController;
  DeliveryTrackingService? _trackingService;
  EnhancedOrderTrackingService? _enhancedTrackingService;
  StreamSubscription? _locationSubscription;
  StreamSubscription? _enhancedLocationSubscription;
  StreamSubscription? _orderStatusSubscription;
  Timer? _orderStatusCheckTimer;
  Timer? _locationUpdateTimer;

  // Delivery tracking variables
  String? _estimatedArrivalTime;
  String? _distanceToCustomer;

  Future<void> _launchTel(String phoneNumber) async {
    try {
      final cleaned = phoneNumber.trim();
      if (cleaned.isEmpty) return;
      final uri = Uri(scheme: 'tel', path: cleaned);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
      } else {
        if (!mounted) return;
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.cannotPlaceCall, style: GoogleFonts.inter()),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.failedToOpenDialer, style: GoogleFonts.inter()),
          duration: const Duration(seconds: 2),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // Map markers and polylines with caching
  final Set<Marker> _markers = {};
  final Set<Polyline> _polylines = {};
  String? _lastMarkersHash;
  String? _lastPolylinesHash;

  // Custom marker icons

  // Route data
  List<LatLng>? _deliveryRoute;

  // Location data with smoothing
  LatLng? _deliveryPersonLocation;
  LatLng? _restaurantLocation;
  LatLng? _customerLocation;

  // Map bounds and camera management
  bool _hasInitializedCamera = false;

  // Animation controllers with multiple animations (nullable to prevent LateInitializationError)
  AnimationController? _pulseController;
  AnimationController? _fadeController;
  AnimationController? _slideController;
  Animation<double>? _fadeAnimation;
  Animation<Offset>? _slideAnimation;

  // State with performance optimizations
  bool _isTracking = false;
  String _trackingStatus = 'Initializing...';
  Order? _currentOrder;
  bool _isRefreshing = false;
  String? _mapStyle; // Simple map style to reduce load

  // Map loading states
  bool _isMapLoading = true;
  bool _isMapReady = false;
  String? _loadingError;

  @override
  void initState() {
    super.initState();
    // Load full order data immediately to get restaurant with image
    _loadFullOrderData();

    // Initialize asynchronously to prevent blocking
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Add small delay to ensure UI is fully rendered
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _initializeAppAsync();
        }
      });
    });
  }

  /// Load full order data with restaurant details
  Future<void> _loadFullOrderData() async {
    try {
      debugPrint('🔄 Loading full order data for order ${widget.order.id}');
      final orderService = Provider.of<OrderService>(context, listen: false);
      final fullOrder = await orderService.getOrderById(widget.order.id);

      if (fullOrder != null && mounted) {
        setState(() {
          _currentOrder = fullOrder;
        });
        debugPrint(
            '✅ Full order loaded with restaurant: ${fullOrder.restaurant?.name}');
        debugPrint('   Restaurant image: ${fullOrder.restaurant?.image}');
        debugPrint('   Restaurant ID: ${fullOrder.restaurant?.id}');

        // Initialize restaurant location with the updated data
        if (fullOrder.restaurant != null) {
          await _initializeRestaurantLocation().then((_) {
            if (mounted) {
              _updateMarkers();
              _updateRoute();
            }
          });
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading full order data: $e');
    }
  }

  /// Optimized async initialization sequence
  Future<void> _initializeAppAsync() async {
    try {
      // Use microtask to prevent blocking the main thread
      await Future.microtask(() async {
        // Load map style first (non-blocking)
        await _loadMapStyle();

        // Setup animations immediately
        _setupAnimations();

        // Initialize tracking services
        _initializeEnhancedTracking();

        // Start with basic order data
        _setDefaultEstimatedArrival();

        // Initialize map with basic data first
        await _initializeMapFast();

        // Start real-time tracking after map is ready
        await _startRealTimeTracking();

        // Start periodic updates
        _startPeriodicUpdates();

        // Initialize comprehensive tracking
        await _initializeComprehensiveTracking();

        // Generate static maps - method removed
      });
    } catch (e) {
      debugPrint('❌ Error during app initialization: $e');
      setState(() {
        _loadingError = 'Failed to initialize map: ${e.toString()}';
        _isMapLoading = false;
      });
    }
  }

  Future<void> _loadMapStyle() async {
    // Map style loading removed - using default map style
    setState(() {
      _mapStyle = null;
    });
  }

  /// Fast map initialization - load basic data first
  Future<void> _initializeMapFast() async {
    try {
      // Set up customer location from delivery address (fastest)
      if (widget.order.deliveryAddress['latitude'] != null &&
          widget.order.deliveryAddress['longitude'] != null) {
        final address = widget.order.deliveryAddress;
        if (address['latitude'] != null && address['longitude'] != null) {
          _customerLocation = LatLng(
            address['latitude'],
            address['longitude'],
          );
        }
      }

      // Update markers with available data
      _updateMarkers();

      // Mark locations as initialized

      // Load restaurant location asynchronously (slower operation)
      await _initializeRestaurantLocationAsync();

      // Load routes after a delay to allow map to render first
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _loadRealRoadRoutes();
        }
      });
    } catch (e) {
      debugPrint('❌ Error in fast map initialization: $e');
      setState(() {
        _loadingError = 'Failed to initialize locations: ${e.toString()}';
      });
    }
  }

  /// Async restaurant location loading (non-blocking)
  Future<void> _initializeRestaurantLocationAsync() async {
    try {
      await _initializeRestaurantLocation();

      // Update markers and routes after restaurant location is loaded
      if (mounted) {
        _updateMarkers();
        _updateRoute();
        await _loadRealRoadRoutes();
        await _updateCameraToShowAllLocations();
      }
    } catch (e) {
      debugPrint('❌ Error loading restaurant location: $e');
    }
  }

  Future<void> _initializeRestaurantLocation() async {
    // Prefer latest order info if available
    final Restaurant? restaurant =
        _currentOrder?.restaurant ?? widget.order.restaurant;
    if (restaurant == null) return;

    // First try to use existing coordinates if available
    if (restaurant.latitude != null && restaurant.longitude != null) {
      _restaurantLocation = LatLng(restaurant.latitude!, restaurant.longitude!);
      debugPrint(
          '📍 Restaurant location from coordinates: $_restaurantLocation');
      return;
    }

    // If no coordinates, try to geocode the address using fast method
    if (restaurant.addressLine1.isNotEmpty) {
      try {
        final geoService = GeolocationService();
        final fullAddress = _buildFullAddress(restaurant);
        debugPrint('🔍 Fast geocoding restaurant address: $fullAddress');

        final coordinates =
            await geoService.getRestaurantCoordinates(fullAddress);
        if (coordinates != null) {
          _restaurantLocation = coordinates;
          debugPrint(
              '✅ Restaurant location from fast geocoding: $_restaurantLocation');

          // Update markers and route with new location
          if (mounted) {
            _updateMarkers();
            _updateRoute();
            // Load real road routes with the new restaurant location
            await _loadRealRoadRoutes();
            // Update camera to show all locations
            await _updateCameraToShowAllLocations();
          }
        } else {
          debugPrint(
              '❌ No coordinates found for restaurant address: $fullAddress');
        }
      } catch (e) {
        debugPrint('❌ Error fast geocoding restaurant address: $e');
      }
    } else {
      debugPrint('❌ Restaurant has no address to geocode');
    }
  }

  String _buildFullAddress(Restaurant restaurant) {
    final addressParts = [
      restaurant.addressLine1,
      restaurant.addressLine2,
      restaurant.city,
      restaurant.state,
      restaurant.wilaya,
    ].where((part) => part != null && part.isNotEmpty);

    return addressParts.join(', ');
  }

  /// Calculate bounds to fit all relevant locations
  LatLngBounds? _calculateAllLocationsBounds() {
    final locations = <LatLng>[];

    // Add restaurant location
    if (_restaurantLocation != null) {
      locations.add(_restaurantLocation!);
    }

    // Add customer location
    if (_customerLocation != null) {
      locations.add(_customerLocation!);
    }

    // Add delivery person location if available
    if (_deliveryPersonLocation != null) {
      locations.add(_deliveryPersonLocation!);
    }

    if (locations.isEmpty) {
      return null;
    }

    if (locations.length == 1) {
      // Single location - create bounds with padding
      final location = locations.first;
      const padding = 0.01; // ~1km padding
      return LatLngBounds(
        southwest:
            LatLng(location.latitude - padding, location.longitude - padding),
        northeast:
            LatLng(location.latitude + padding, location.longitude + padding),
      );
    }

    // Multiple locations - calculate actual bounds
    double minLat = locations.first.latitude;
    double maxLat = locations.first.latitude;
    double minLng = locations.first.longitude;
    double maxLng = locations.first.longitude;

    for (final location in locations) {
      minLat = math.min(minLat, location.latitude);
      maxLat = math.max(maxLat, location.latitude);
      minLng = math.min(minLng, location.longitude);
      maxLng = math.max(maxLng, location.longitude);
    }

    // Add padding to bounds (10% of the range or minimum 0.005 degrees)
    final latPadding = math.max((maxLat - minLat) * 0.1, 0.005);
    final lngPadding = math.max((maxLng - minLng) * 0.1, 0.005);

    return LatLngBounds(
      southwest: LatLng(minLat - latPadding, minLng - lngPadding),
      northeast: LatLng(maxLat + latPadding, maxLng + lngPadding),
    );
  }

  /// Update camera to show all relevant locations
  Future<void> _updateCameraToShowAllLocations() async {
    if (_mapController == null) return;

    final bounds = _calculateAllLocationsBounds();
    if (bounds == null) return;

    try {
      // Use CameraUpdate.newLatLngBounds with padding
      final cameraUpdate =
          CameraUpdate.newLatLngBounds(bounds, 100.0); // 100px padding
      await _mapController!.animateCamera(cameraUpdate);

      debugPrint('📷 Camera updated to show all locations');
      debugPrint(
          '   Bounds: SW(${bounds.southwest.latitude}, ${bounds.southwest.longitude}) NE(${bounds.northeast.latitude}, ${bounds.northeast.longitude})');
    } catch (e) {
      debugPrint('❌ Error updating camera bounds: $e');
      // Fallback to center on restaurant or customer
      _fallbackCameraPosition();
    }
  }

  /// Fallback camera position when bounds calculation fails
  void _fallbackCameraPosition() {
    if (_mapController == null) return;

    LatLng? centerLocation;
    double zoom = 14.0;

    if (_restaurantLocation != null) {
      centerLocation = _restaurantLocation;
    } else if (_customerLocation != null) {
      centerLocation = _customerLocation;
    } else if (_deliveryPersonLocation != null) {
      centerLocation = _deliveryPersonLocation;
    } else {
      // Default to Algiers
      centerLocation = const LatLng(36.7538, 3.0588);
      zoom = 12.0;
    }

    if (centerLocation != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(centerLocation, zoom),
      );
      debugPrint('📷 Fallback camera position: $centerLocation');
    }
  }

  /// Initialize camera position based on available locations
  Future<void> _initializeCameraPosition() async {
    if (_hasInitializedCamera || _mapController == null) return;

    // Wait a bit for locations to be loaded
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    // Try to show all locations first
    await _updateCameraToShowAllLocations();
    _hasInitializedCamera = true;

    debugPrint('📷 Initial camera position set');
  }

  /// Initialize enhanced tracking with Socket.IO
  void _initializeEnhancedTracking() {
    try {
      _enhancedTrackingService =
          Provider.of<EnhancedOrderTrackingService>(context, listen: false);

      // Listen for enhanced delivery location updates
      _enhancedLocationSubscription =
          _enhancedTrackingService!.deliveryLocationStream.listen((data) {
        _handleEnhancedLocationUpdate(data);
      });

      // Listen for order status updates
      _orderStatusSubscription =
          _enhancedTrackingService!.deliveryStatusStream.listen((data) {
        _handleEnhancedOrderStatusUpdate(data);
      });

      debugPrint('✅ Enhanced tracking initialized with Socket.IO');
    } catch (e) {
      debugPrint('❌ Error initializing enhanced tracking: $e');
    }
  }

  /// Handle enhanced location updates from Socket.IO
  void _handleEnhancedLocationUpdate(Map<String, dynamic> data) {
    try {
      final orderId = data['orderId'] as String;
      final latitude = (data['latitude'] as num).toDouble();
      final longitude = (data['longitude'] as num).toDouble();

      // Only process if this is for the current order
      if (orderId != widget.order.id) return;

      debugPrint(
          '📍 Enhanced location update: $orderId at ($latitude, $longitude)');

      // Update delivery person location
      final newLocation = LatLng(latitude, longitude);

      // Check if location has changed significantly
      if (_shouldUpdateLocation(newLocation)) {
        setState(() {
          _deliveryPersonLocation = newLocation;
        });

        // Update map elements
        _updateMapElements();

        // Update estimated arrival time
        _calculateEstimatedArrival();

        // Refresh delivery route with new waypoint
        _refreshDeliveryRoute();

        debugPrint('✅ Enhanced location update applied');
      }
    } catch (e) {
      debugPrint('❌ Error handling enhanced location update: $e');
    }
  }

  /// Refresh delivery route when delivery person location changes
  Future<void> _refreshDeliveryRoute() async {
    if (_restaurantLocation == null ||
        _deliveryPersonLocation == null ||
        _customerLocation == null) {
      return;
    }

    try {
      debugPrint('🗺️ Refreshing delivery route with new waypoint...');
      _deliveryRoute = await DirectionsService.getDeliveryRoute(
        restaurant: _restaurantLocation!,
        deliveryPerson: _deliveryPersonLocation!,
        customer: _customerLocation!,
      );

      // Update polylines with new route
      _updatePolylinesWithRealRoutes();
    } catch (e) {
      debugPrint('❌ Error refreshing delivery route: $e');
    }
  }

  /// Handle enhanced order status updates from Socket.IO
  void _handleEnhancedOrderStatusUpdate(Map<String, dynamic> data) {
    try {
      final orderId = data['orderId'] as String;
      final status = data['status'] as String;

      // Only process if this is for the current order
      if (orderId != widget.order.id) return;

      debugPrint('📦 Enhanced order status update: $orderId -> $status');

      // Update tracking status and refresh restaurant details immediately if provided
      setState(() {
        // If payload contains updated restaurant, merge it
        if (data.containsKey('restaurant')) {
          try {
            final rJson = data['restaurant'] as Map<String, dynamic>;
            final updated = Restaurant.fromJson(rJson);
            _currentOrder =
                (_currentOrder ?? widget.order).copyWith(restaurant: updated);
            // Re-evaluate restaurant location and marker
            _initializeRestaurantLocation();
            _updateMapElements();
          } catch (_) {}
        }
        _trackingStatus = _getTrackingStatusForOrderStatus();
      });

      // Handle status-specific logic
      if (status == 'picked_up' && widget.order.deliveryPersonId != null) {
        // Start enhanced tracking for picked up orders
        _startEnhancedOrderTracking();
      } else if (status == 'delivered' || status == 'cancelled') {
        // Stop tracking for completed orders
        _stopEnhancedOrderTracking();
      }
    } catch (e) {
      debugPrint('❌ Error handling enhanced order status update: $e');
    }
  }

  /// Start enhanced order tracking
  void _startEnhancedOrderTracking() {
    if (_enhancedTrackingService == null ||
        widget.order.deliveryPersonId == null) {
      return;
    }

    _enhancedTrackingService!.startOrderTracking(
      orderId: widget.order.id,
      deliveryPersonId: widget.order.deliveryPersonId!,
    );

    setState(() {
      _isTracking = true;
      _trackingStatus = 'Order picked up - Enhanced tracking active';
    });

    debugPrint('🚀 Enhanced order tracking started');
  }

  /// Stop enhanced order tracking
  void _stopEnhancedOrderTracking() {
    if (_enhancedTrackingService == null) return;

    _enhancedTrackingService!.stopOrderTracking(widget.order.id);

    setState(() {
      _isTracking = false;
      _trackingStatus = _getTrackingStatusForOrderStatus();
    });

    debugPrint('🛑 Enhanced order tracking stopped');
  }

  void _setupAnimations() {
    // Pulse animation for delivery marker
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    if (_pulseController != null) {}

    // Fade animation for smooth transitions
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    if (_fadeController != null) {
      _fadeAnimation = Tween<double>(
        begin: 0.0,
        end: 1.0,
      ).animate(CurvedAnimation(
        parent: _fadeController!,
        curve: Curves.easeInOut,
      ));
    }

    // Slide animation for status updates
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );

    if (_slideController != null) {
      _slideAnimation = Tween<Offset>(
        begin: const Offset(0, 0.1),
        end: Offset.zero,
      ).animate(CurvedAnimation(
        parent: _slideController!,
        curve: Curves.easeOut,
      ));
    }

    // Start animations
    _fadeController?.forward();
    _slideController?.forward();
  }

  // Start periodic updates for better real-time experience
  void _startPeriodicUpdates() {
    // Check order status periodically
    _orderStatusCheckTimer = Timer.periodic(kOrderStatusPollInterval, (_) {
      _checkOrderStatusUpdate();
    });

    // Update camera following periodically when tracking
    _locationUpdateTimer = Timer.periodic(kCameraFollowInterval, (_) {
      if (_isTracking && _deliveryPersonLocation != null && mounted) {
        _updateMapCameraSmoothly();
      }
    });
  }

  // Smooth camera updates to reduce jank
  void _updateMapCameraSmoothly() {
    if (_mapController != null && _deliveryPersonLocation != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_deliveryPersonLocation!, kFollowZoomLevel),
      );
    }
  }

  // Recenter camera to show all locations or fallback to restaurant/customer
  void _recenterCameraToShowAllLocations() {
    if (_mapController == null) return;

    // Try to show all locations first
    _updateCameraToShowAllLocations().catchError((e) {
      debugPrint('❌ Error recentering to all locations: $e');
      // Fallback to restaurant or customer
      final target = _restaurantLocation ?? _customerLocation;
      if (target != null) {
        _mapController!.animateCamera(
            CameraUpdate.newLatLngZoom(target, kRecenterZoomLevel));
      }
    });
  }

  // Check for order status updates more frequently
  Future<void> _checkOrderStatusUpdate() async {
    try {
      if (!mounted) return;

      final orderService = Provider.of<OrderService>(context, listen: false);
      final currentOrder = await orderService.getOrderById(widget.order.id);

      if (currentOrder == null) {
        debugPrint('⚠️ Order has been deleted during tracking');
        await _handleOrderDeleted();
        return;
      }

      // Check if order status has changed
      if (currentOrder.status != (_currentOrder ?? widget.order).status ||
          currentOrder.restaurant?.id !=
              (_currentOrder ?? widget.order).restaurant?.id) {
        debugPrint(
            '🔄 Order status changed: ${(_currentOrder ?? widget.order).status} → ${currentOrder.status}');

        // Animate status change
        await _animateStatusChange();

        // Update the order and refresh UI
        if (mounted) {
          setState(() {
            _currentOrder = currentOrder;
            _trackingStatus = _getTrackingStatusForOrderStatus();
          });

          // Trigger fade animation for smooth status transition
          if (_fadeController != null) {
            _fadeController!.reset();
            await _fadeController!.forward();
          }

          // Update markers and routes if needed
          await _initializeRestaurantLocation();
          _updateMarkers();
          _updateRoute();

          // Update camera to show all locations if not tracking delivery person
          if (!_isTracking) {
            await _updateCameraToShowAllLocations();
          }
        }

        // Start live following only when picked up
        if (currentOrder.status == OrderStatus.pickedUp &&
            currentOrder.deliveryPersonId != null &&
            !_isTracking) {
          debugPrint('🚀 Starting location tracking for picked up order');
          await _startLocationTrackingForOrder(currentOrder);
        } else {
          // Any non-pickedUp status: stop following and recenter to show all locations
          if (_isTracking) {
            await _locationSubscription?.cancel();
          }
          if (mounted) {
            setState(() {
              _isTracking = false;
              _trackingStatus = _getTrackingStatusForOrderStatus();
            });
          }
          _recenterCameraToShowAllLocations();
        }
      }

      // Update current order reference
      _currentOrder = currentOrder;
    } catch (e) {
      debugPrint('Error checking order status: $e');
    }
  }

  // Animate status changes for better UX
  Future<void> _animateStatusChange() async {
    if (!mounted || _slideController == null || _slideAnimation == null) return;

    // Reset and restart slide animation
    _slideController!.reset();
    await _slideController!.forward();

    // Add a slight delay for visual feedback
    await Future.delayed(const Duration(milliseconds: 200));
  }

  // Start location tracking specifically for a picked up order
  Future<void> _startLocationTrackingForOrder(Order order) async {
    try {
      debugPrint(
          '📍 Starting enhanced location tracking for order ${order.id}');

      // Start enhanced tracking service
      if (_enhancedTrackingService != null) {
        final success = await _enhancedTrackingService!.startOrderTracking(
          orderId: order.id,
          deliveryPersonId: order.deliveryPersonId!,
        );

        if (success && mounted) {
          setState(() {
            _isTracking = true;
            _trackingStatus = 'Order picked up - Enhanced tracking active';
          });

          debugPrint(
              '✅ Enhanced location tracking started successfully for picked up order');
        } else {
          debugPrint(
              '❌ Failed to start enhanced location tracking for picked up order');
          if (mounted) {
            setState(() {
              _trackingStatus = 'Unable to track delivery person location';
            });
          }
        }
      } else {
        // Fallback to regular tracking service
        _trackingService ??=
            Provider.of<DeliveryTrackingService>(context, listen: false);

        final success = await _trackingService!.startOrderTracking(
          orderId: order.id,
          deliveryPersonId: order.deliveryPersonId!,
        );

        if (success && mounted) {
          setState(() {
            _isTracking = true;
            _trackingStatus = 'Order picked up by delivery person';
          });

          // Subscribe to location updates
          await _locationSubscription
              ?.cancel(); // Cancel any existing subscription
          _locationSubscription = _trackingService!
              .getLocationStream(order.id)
              ?.listen(_onLocationUpdate);

          debugPrint(
              '✅ Fallback location tracking started successfully for picked up order');
        } else {
          debugPrint(
              '❌ Failed to start fallback location tracking for picked up order');
          if (mounted) {
            setState(() {
              _trackingStatus = 'Unable to track delivery person location';
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error starting location tracking: $e');
      if (mounted) {
        setState(() {
          _trackingStatus = 'Error tracking location';
        });
      }
    }
  }

  // Handle case when order has been deleted from database
  Future<void> _handleOrderDeleted() async {
    setState(() {
      _trackingStatus = 'Order has been cancelled or deleted';
      _isTracking = false;
    });

    // Show error dialog and navigate back
    if (mounted) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              'Order Unavailable',
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: Colors.red[700],
              ),
            ),
            content: Text(
              'This order has been cancelled or deleted from the system. You will be redirected to the home screen.',
              style: GoogleFonts.poppins(),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  // Navigate back to home screen
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const HomeScreen(),
                    ),
                  );
                },
                child: Text(
                  'OK',
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFd47b00),
                  ),
                ),
              ),
            ],
          );
        },
      );
    }
  }

  Future<void> _startRealTimeTracking() async {
    try {
      setState(() {
        _trackingStatus = 'Initializing...';
      });

      _trackingService =
          Provider.of<DeliveryTrackingService>(context, listen: false);

      // First, verify the order still exists in the database
      final orderService = Provider.of<OrderService>(context, listen: false);
      final currentOrder = await orderService.getOrderById(widget.order.id);

      // Handle case where order has been deleted from database
      if (currentOrder == null) {
        debugPrint(
            '⚠️ Order ${widget.order.id} has been deleted from database');
        await _handleOrderDeleted();
        return;
      }

      // Update the order data if it has changed
      if (currentOrder.status != widget.order.status) {
        debugPrint(
            'Order status changed from ${widget.order.status} to ${currentOrder.status}');
        // You might want to navigate back or refresh the screen here
      }

      // Update tracking status based on order status
      await _updateTrackingStatusForOrderStatus();

      // Start tracking for this order if delivery person is assigned
      if (currentOrder.deliveryPersonId != null) {
        // Check if we should start location tracking based on order status
        final shouldTrackLocation = currentOrder.status == OrderStatus.pickedUp;

        if (shouldTrackLocation) {
          // Use enhanced tracking service if available
          if (_enhancedTrackingService != null) {
            final success = await _enhancedTrackingService!.startOrderTracking(
              orderId: currentOrder.id,
              deliveryPersonId: currentOrder.deliveryPersonId!,
            );

            if (success) {
              setState(() {
                _isTracking = true;
                _trackingStatus = 'Order picked up - Enhanced tracking active';
              });

              debugPrint(
                  '📍 Enhanced location tracking started for order ${currentOrder.id} (status: ${currentOrder.status})');
            } else {
              setState(() {
                _trackingStatus = _getTrackingStatusForOrderStatus();
              });
              debugPrint(
                  '❌ Failed to start enhanced location tracking for order ${currentOrder.id}');
            }
          } else {
            // Fallback to regular tracking service
            final success = await _trackingService!.startOrderTracking(
              orderId: currentOrder.id,
              deliveryPersonId: currentOrder.deliveryPersonId!,
            );

            if (success) {
              setState(() {
                _isTracking = true;
                _trackingStatus = _getTrackingStatusForOrderStatus();
              });

              // Subscribe to location updates
              _locationSubscription = _trackingService!
                  .getLocationStream(currentOrder.id)
                  ?.listen(_onLocationUpdate);

              debugPrint(
                  '📍 Fallback location tracking started for order ${currentOrder.id} (status: ${currentOrder.status})');
            } else {
              setState(() {
                _trackingStatus = _getTrackingStatusForOrderStatus();
              });
              debugPrint(
                  '❌ Failed to start fallback location tracking for order ${currentOrder.id}');
            }
          }
        } else {
          // Order is not yet picked up, show status without location tracking and recenter
          setState(() {
            _isTracking = false;
            _trackingStatus = _getTrackingStatusForOrderStatus();
          });
          debugPrint(
              '⏳ Order ${currentOrder.id} not picked up yet (status: ${currentOrder.status}), no location tracking');
          _recenterCameraToShowAllLocations();
        }
      } else {
        // No delivery person assigned yet, but still show order status
        setState(() {
          _trackingStatus = _getTrackingStatusForOrderStatus();
        });
        debugPrint(
            '👤 No delivery person assigned to order ${currentOrder.id}');
        _recenterCameraToShowAllLocations();
      }
    } catch (e) {
      debugPrint('Error starting real-time tracking: $e');
      setState(() {
        _trackingStatus = 'Error: ${e.toString()}';
      });
    }
  }

  Future<void> _updateTrackingStatusForOrderStatus() async {
    // Simulate restaurant preparation progress for demo purposes
    if (widget.order.status == OrderStatus.pending) {
      // Simulate order confirmation after a delay
      await Future.delayed(const Duration(seconds: 3));
      if (mounted) {
        setState(() {
          _trackingStatus = 'Order confirmed by restaurant';
        });
      }

      // Simulate preparation start
      await Future.delayed(const Duration(seconds: 5));
      if (mounted) {
        setState(() {
          _trackingStatus = 'Restaurant is preparing your order';
        });
      }

      // Simulate preparation completion
      await Future.delayed(const Duration(seconds: 8));
      if (mounted) {
        setState(() {
          _trackingStatus = 'Order ready for pickup';
        });
      }
    }
  }

  String _getTrackingStatusForOrderStatus() {
    final currentOrder = _currentOrder ?? widget.order;
    switch (currentOrder.status) {
      case OrderStatus.pending:
        return 'Order placed successfully';
      case OrderStatus.confirmed:
        return 'Order confirmed by restaurant';
      case OrderStatus.preparing:
        return 'Restaurant is preparing your order';
      case OrderStatus.ready:
        return 'Order ready for pickup';
      case OrderStatus.pickedUp:
        if (currentOrder.deliveryPersonId != null) {
          final trackingIndicator = _isTracking
              ? ' 📍 Enhanced Tracking Active'
              : ' ⚠️ Location tracking unavailable';
          return 'Order picked up by delivery person$trackingIndicator';
        } else {
          return 'Order ready for delivery';
        }
      case OrderStatus.delivered:
        return 'Order delivered successfully ✅';
      case OrderStatus.cancelled:
        return 'Order cancelled';
    }
  }

  void _onLocationUpdate(dynamic locationData) {
    if (locationData is Map<String, dynamic>) {
      final latitude = locationData['latitude'] as double?;
      final longitude = locationData['longitude'] as double?;

      if (latitude != null && longitude != null) {
        final newLocation = LatLng(latitude, longitude);

        // Only update if location has actually changed significantly (reduce updates)
        if (_shouldUpdateLocation(newLocation)) {
          setState(() {
            _deliveryPersonLocation = newLocation;
          });

          // Batch UI updates for better performance
          _updateMapElements();

          // Update estimated arrival time
          _calculateEstimatedArrival();
        }
      }
    }
  }

  // Check if location update is significant enough to warrant UI update
  bool _shouldUpdateLocation(LatLng newLocation) {
    if (_deliveryPersonLocation == null) return true;

    // Calculate distance between current and new location
    final distance = _calculateDistance(
      _deliveryPersonLocation!.latitude,
      _deliveryPersonLocation!.longitude,
      newLocation.latitude,
      newLocation.longitude,
    );

    // Only update if moved more than configured threshold
    return distance > kMinMovementKmToUpdate;
  }

  // Batch map element updates for better performance
  void _updateMapElements() {
    if (!mounted) return;

    _updateMarkers();
    _updateRoute();
    // Camera update is handled by periodic timer for smoother experience
  }

  void _updateMarkers() {
    // Create hash of current state to avoid unnecessary recreations
    final currentHash =
        '${_restaurantLocation}_${_customerLocation}_${_deliveryPersonLocation}_$_trackingStatus';

    if (_lastMarkersHash == currentHash && _markers.isNotEmpty) {
      // No changes needed
      return;
    }

    _lastMarkersHash = currentHash;
    _markers.clear();

    final currentOrder = _currentOrder ?? widget.order;

    // Restaurant marker - simple ring
    if (_restaurantLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('restaurant'),
          position: _restaurantLocation!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
          infoWindow: InfoWindow(
            title: currentOrder.restaurant?.name ?? 'Restaurant',
            snippet: currentOrder.restaurant != null
                ? _buildFullAddress(currentOrder.restaurant!)
                : 'Restaurant Location',
          ),
        ),
      );
    }

    // Customer marker - simple ring
    if (_customerLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('customer'),
          position: _customerLocation!,
          icon:
              BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: InfoWindow(
            title: 'Delivery Address',
            snippet: currentOrder.deliveryAddress['fullAddress'] ??
                'Customer Location',
          ),
        ),
      );
    }

    // Delivery person marker - simple ring
    if (_deliveryPersonLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('delivery_person'),
          position: _deliveryPersonLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue),
          infoWindow: InfoWindow(
            title: _isTracking
                ? 'Delivery Person (Live Tracking)'
                : 'Delivery Person',
            snippet: _trackingStatus,
          ),
        ),
      );

      debugPrint(
          '📍 Delivery person marker updated: tracking=$_isTracking, location=$_deliveryPersonLocation');
    }
  }

  void _updateRoute() {
    // Create hash of current locations to avoid unnecessary recreations
    final currentHash =
        '$_restaurantLocation$_customerLocation$_deliveryPersonLocation';

    if (_lastPolylinesHash == currentHash && _polylines.isNotEmpty) {
      // No changes needed
      return;
    }

    _lastPolylinesHash = currentHash;
    _polylines.clear();

    // Load real road routes
    _loadRealRoadRoutes();
  }

  /// Load real road routes using Google Maps Directions API
  Future<void> _loadRealRoadRoutes() async {
    if (_restaurantLocation == null || _customerLocation == null) {
      debugPrint('⚠️ Cannot load routes: missing locations');
      debugPrint('   Restaurant: $_restaurantLocation');
      debugPrint('   Customer: $_customerLocation');
      return;
    }

    debugPrint('🗺️ Starting to load real road routes...');
    debugPrint(
        '   Restaurant: ${_restaurantLocation!.latitude}, ${_restaurantLocation!.longitude}');
    debugPrint(
        '   Customer: ${_customerLocation!.latitude}, ${_customerLocation!.longitude}');
    if (_deliveryPersonLocation != null) {
      debugPrint(
          '   Delivery Person: ${_deliveryPersonLocation!.latitude}, ${_deliveryPersonLocation!.longitude}');
    }

    try {
      // Only load delivery route (restaurant -> delivery person -> customer) if delivery person is available
      if (_deliveryPersonLocation != null) {
        debugPrint('🗺️ Loading delivery route with waypoint...');
        _deliveryRoute = await DirectionsService.getDeliveryRoute(
          restaurant: _restaurantLocation!,
          deliveryPerson: _deliveryPersonLocation!,
          customer: _customerLocation!,
        );

        if (_deliveryRoute != null) {
          debugPrint(
              '✅ Delivery route loaded with ${_deliveryRoute!.length} points');
        } else {
          debugPrint('❌ Failed to load delivery route');
        }
      }

      // Update polylines with real road routes when available
      final hasDeliveryRoute =
          _deliveryRoute != null && _deliveryRoute!.isNotEmpty;
      if (hasDeliveryRoute) {
        _updatePolylinesWithRealRoutes();
        debugPrint('✅ Real road routes applied to map');
      } else {
        // Fallback if API returned no routes
        debugPrint(
            '⚠️ No real routes returned; drawing fallback straight lines');
        _updatePolylinesWithFallback();
      }
    } catch (e) {
      debugPrint('❌ Error loading real road routes: $e');
      debugPrint('   Stack trace: ${StackTrace.current}');
      // Fallback to straight lines if API fails
      _updatePolylinesWithFallback();
    }
  }

  /// Update polylines with real road routes
  void _updatePolylinesWithRealRoutes() {
    debugPrint('🗺️ Updating polylines with real road routes...');
    _polylines.clear();

    // Removed restaurant to customer route - only show delivery route when available

    // Add delivery route (restaurant -> delivery person -> customer) if available
    if (_deliveryRoute != null && _deliveryRoute!.isNotEmpty) {
      // Underlay (glow)
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('delivery_route_under'),
          points: _deliveryRoute!,
          color: Colors.black.withValues(alpha: 0.2),
          width: 10,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
      // Main route
      _polylines.add(
        Polyline(
          polylineId: const PolylineId('delivery_route'),
          points: _deliveryRoute!,
          color: const Color(0xFFd47b00),
          width: 6,
          startCap: Cap.roundCap,
          endCap: Cap.roundCap,
          jointType: JointType.round,
        ),
      );
      debugPrint(
          '✅ Added delivery route with ${_deliveryRoute!.length} points');
    } else {
      debugPrint('⚠️ Delivery route is null or empty');
    }

    debugPrint('🗺️ Total polylines on map: ${_polylines.length}');

    // Force UI update
    if (mounted) {
      setState(() {});
    }
  }

  /// Fallback to straight lines if real routes fail
  void _updatePolylinesWithFallback() {
    _polylines.clear();

    // Removed restaurant to customer route - only show delivery route when available

    // Create straight line delivery path if delivery person is available
    if (_restaurantLocation != null &&
        _deliveryPersonLocation != null &&
        _customerLocation != null) {
      final List<LatLng> pts2 = [
        _restaurantLocation!,
        _deliveryPersonLocation!,
        _customerLocation!
      ];
      _polylines.add(Polyline(
        polylineId: const PolylineId('fallback_delivery_path_under'),
        points: pts2,
        color: Colors.black.withValues(alpha: 0.2),
        width: 10,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ));
      _polylines.add(Polyline(
        polylineId: const PolylineId('fallback_delivery_path'),
        points: pts2,
        color: const Color(0xFFd47b00),
        width: 6,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ));
    }

    debugPrint('⚠️ Using fallback straight line routes');
    if (mounted) {
      setState(() {});
    }
  }

  void _setDefaultEstimatedArrival() {
    // Set a default estimated arrival time (30 minutes from now)
    setState(() {
      // Default arrival time set
    });
  }

  void _calculateEstimatedArrival() {
    if (_deliveryPersonLocation != null && _customerLocation != null) {
      // Try to get real route info first
      _getRealTimeRouteInfo().then((routeInfo) {
        if (routeInfo != null && mounted) {
          // Use real route duration
          setState(() {
            // Real-time ETA calculated
          });
          debugPrint(
              '📍 Real-time ETA: ${routeInfo.duration} (${routeInfo.distance})');
        } else {
          // Fallback to distance calculation
          _calculateFallbackETA();
        }
      }).catchError((e) {
        debugPrint('❌ Error getting real-time route info: $e');
        _calculateFallbackETA();
      });
    }
  }

  /// Get real-time route information from delivery person to customer
  Future<RouteInfo?> _getRealTimeRouteInfo() async {
    if (_deliveryPersonLocation == null || _customerLocation == null) {
      return null;
    }

    try {
      return await DirectionsService.getRouteInfo(
        origin: _deliveryPersonLocation!,
        destination: _customerLocation!,
      );
    } catch (e) {
      debugPrint('❌ Error getting real-time route info: $e');
      return null;
    }
  }

  /// Fallback ETA calculation using distance
  void _calculateFallbackETA() {
    if (_deliveryPersonLocation != null && _customerLocation != null) {
      // Calculate distance between delivery person and customer
      final distance = _calculateDistance(
        _deliveryPersonLocation!.latitude,
        _deliveryPersonLocation!.longitude,
        _customerLocation!.latitude,
        _customerLocation!.longitude,
      );

      // Estimate time (assuming 20 km/h average speed)
      final estimatedMinutes = (distance / 20.0) * 60;

      if (mounted) {
        setState(() {
          // Fallback ETA calculated
        });
      }
      debugPrint(
          '📍 Fallback ETA: ${estimatedMinutes.round()} minutes (${distance.toStringAsFixed(2)} km)');
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // km
    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_degreesToRadians(lat1)) *
            math.cos(_degreesToRadians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);

    final double c = 2.0 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) => degrees * (math.pi / 180.0);

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _enhancedLocationSubscription?.cancel();
    _orderStatusSubscription?.cancel();
    _orderStatusCheckTimer?.cancel();
    _locationUpdateTimer?.cancel();

    // Stop enhanced tracking safely without notifications to avoid widget tree lock
    try {
      if (_enhancedTrackingService != null) {
        _enhancedTrackingService!
            .stopOrderTracking(widget.order.id, skipNotification: true);
      }
    } catch (e) {
      debugPrint('Error stopping enhanced tracking: $e');
    }

    // Dispose animation controllers safely (nullable checks)
    _pulseController?.dispose();
    _fadeController?.dispose();
    _slideController?.dispose();

    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _onRefresh() async {
    if (_isRefreshing) return;
    setState(() => _isRefreshing = true);

    try {
      debugPrint('🔄 Manual refresh triggered');

      // Force update of order status
      await _checkOrderStatusUpdate();

      // Update map elements
      _updateMapElements();

      // Recalculate estimated arrival
      _calculateEstimatedArrival();

      debugPrint('✅ Manual refresh completed');
    } catch (e) {
      debugPrint('❌ Error during manual refresh: $e');
    } finally {
      setState(() => _isRefreshing = false);
    }
  }

  /// Navigate back to home with smooth animation
  void _navigateBackToHome() {
    // Pop back to home screen with custom animation
    // This preserves the existing home screen instance and avoids data reload
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvoked: (didPop) async {
        if (didPop) {
          // Pop back to home screen preserving its state
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
      child: Scaffold(
        body: Stack(
          children: [
            // Map View with pull-to-refresh
            RefreshIndicator(
              onRefresh: _onRefresh,
              color: const Color(0xFFd47b00),
              backgroundColor: Colors.white,
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: _restaurantLocation ??
                          _customerLocation ??
                          const LatLng(36.7538, 3.0588),
                      zoom: 14,
                    ),
                    markers: _markers,
                    polylines: _polylines,
                    mapType: MapType.normal,
                    trafficEnabled: false, // Disable traffic for faster loading
                    buildingsEnabled:
                        false, // Disable 3D buildings for better performance
                    style: _mapStyle, // Apply simple map style to reduce load
                    onMapCreated: (controller) {
                      _mapController = controller;
                      setState(() {
                        _isMapReady = true;
                        _isMapLoading = false;
                      });
                      // Initialize camera position after map is ready
                      _initializeCameraPosition();
                    },
                    myLocationEnabled: widget.isDeliveryPersonView,
                    myLocationButtonEnabled: widget.isDeliveryPersonView,
                    zoomControlsEnabled: true,
                    // Optimize map performance
                    compassEnabled: false,
                    mapToolbarEnabled: false,
                    rotateGesturesEnabled: true,
                    scrollGesturesEnabled: true,
                    tiltGesturesEnabled: false,
                  ),

                  // Loading overlay
                  if (_isMapLoading || !_isMapReady)
                    Container(
                      color: Colors.white,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  Color(0xFFd47b00)),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              AppLocalizations.of(context)!.loadingMap,
                              style: GoogleFonts.inter(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // Error overlay
                  if (_loadingError != null)
                    Container(
                      color: Colors.white,
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 64,
                              color: Colors.red[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              AppLocalizations.of(context)!.mapLoadingError,
                              style: GoogleFonts.inter(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.red[700],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _loadingError!,
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  _loadingError = null;
                                  _isMapLoading = true;
                                });
                                _initializeAppAsync();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFd47b00),
                                foregroundColor: Colors.white,
                              ),
                              child: Text(
                                AppLocalizations.of(context)!.retry,
                                style: GoogleFonts.inter(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Header: back arrow only
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
                  child: Row(
                    children: [
                      Material(
                        color: Colors.white,
                        shape: const CircleBorder(),
                        elevation: 2,
                        child: IconButton(
                          icon:
                              const Icon(Icons.arrow_back, color: Colors.black),
                          onPressed: _navigateBackToHome,
                          tooltip: 'Back to Home',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Tracking Info Panel with smooth animations (only if controllers are initialized)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _slideController != null &&
                      _fadeController != null &&
                      _slideAnimation != null &&
                      _fadeAnimation != null
                  ? SlideTransition(
                      position: _slideAnimation!,
                      child: FadeTransition(
                        opacity: _fadeAnimation!,
                        child: _buildTrackingInfoPanel(),
                      ),
                    )
                  : _buildTrackingInfoPanel(), // Fallback without animations
            ),

            // Map Controls - Circular orange buttons
            Positioned(
              top: 100,
              left: Directionality.of(context) == TextDirection.rtl ? 20 : null,
              right:
                  Directionality.of(context) == TextDirection.rtl ? null : 20,
              child: Column(
                children: [
                  // Show All Locations Button
                  Material(
                    color: const Color(0xFFd47b00),
                    shape: const CircleBorder(),
                    elevation: 3,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _recenterCameraToShowAllLocations,
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.fit_screen,
                            color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Load Routes Button
                  Material(
                    color: const Color(0xFFd47b00),
                    shape: const CircleBorder(),
                    elevation: 3,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: () {
                        debugPrint('🔄 Manual route loading triggered');
                        _loadRealRoadRoutes();
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Icon(Icons.route, color: Colors.white, size: 22),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Delivery Person Controls (only for delivery person view)
                  if (widget.isDeliveryPersonView) _buildDeliveryControls(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrackingInfoPanel() {
    final restaurant = _currentOrder?.restaurant ?? widget.order.restaurant;
    return SafeArea(
      top: false,
      child: Floating3DCard(
        margin: const EdgeInsets.fromLTRB(
            16, 0, 16, 16), // Increased bottom margin for safe area
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 16), // Reduced padding
        borderRadius: 20,
        elevation: 8.0, // Increased elevation for better 3D effect
        backgroundColor: Colors.white, // Changed to white background
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Order steps moved to top
            _buildCenteredOrderSteps(),

            const SizedBox(height: 12), // Reduced spacing

            // Restaurant card with floating style
            if (restaurant != null) _buildRestaurantCardFloating(),
            if (restaurant == null) _buildFallbackRestaurantCardFloating(),

            const SizedBox(height: 12), // Reduced spacing

            // Delivery man card only when picked up and data exists
            if ((_currentOrder?.status ?? widget.order.status) ==
                    OrderStatus.pickedUp &&
                ((_currentOrder?.deliveryPerson ??
                        widget.order.deliveryPerson) !=
                    null))
              _buildDeliveryManCardFloating(),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantCardFloating() {
    final r = _currentOrder?.restaurant ?? widget.order.restaurant!;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Directionality.of(context) == TextDirection.rtl
          ? Row(
              children: [
                // For RTL: Call button first (right side)
                if (r.phone.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFd47b00),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _launchTel(r.phone),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child:
                              Icon(Icons.call, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ),
                if (r.phone.isNotEmpty) const SizedBox(width: 12),
                // Restaurant info in the middle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        r.name,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.right,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(context)!.restaurant,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Restaurant icon last (left side)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFd47b00), // Orange background
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: (() {
                    // Use the same fallback logic as Restaurant model: cover_image_url ?? image ?? logo_url
                    final imageUrl = r.coverImageUrl ?? r.image ?? r.logoUrl;
                    debugPrint(
                        '🏪 Restaurant image selection for ${r.name}: cover=${r.coverImageUrl != null}, image=${r.image != null}, logo=${r.logoUrl != null}');
                    debugPrint('   Selected URL: $imageUrl');
                    return imageUrl != null && imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            key: ValueKey(
                                'restaurant_${r.id}_$imageUrl'), // Force rebuild when image changes
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: const Color(0xFFd47b00),
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) {
                              debugPrint(
                                  '❌ Error loading restaurant image: $error');
                              debugPrint('   Image URL: $url');
                              debugPrint(
                                  '   Available image fields: cover=${r.coverImageUrl}, image=${r.image}, logo=${r.logoUrl}');
                              return const Icon(Icons.restaurant,
                                  color: Colors.white);
                            },
                            fadeInDuration: const Duration(milliseconds: 300),
                            memCacheWidth: 96, // Optimize for 48dp at 2x scale
                            memCacheHeight: 96,
                          )
                        : const Icon(Icons.restaurant, color: Colors.white);
                  })(),
                ),
              ],
            )
          : Row(
              children: [
                // For LTR: Original layout (restaurant icon, info, call button)
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFd47b00), // Orange background
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: (() {
                    // Use the same fallback logic as Restaurant model: cover_image_url ?? image ?? logo_url
                    final imageUrl = r.coverImageUrl ?? r.image ?? r.logoUrl;
                    debugPrint(
                        '🏪 Restaurant image selection for ${r.name}: cover=${r.coverImageUrl != null}, image=${r.image != null}, logo=${r.logoUrl != null}');
                    debugPrint('   Selected URL: $imageUrl');
                    return imageUrl != null && imageUrl.isNotEmpty
                        ? CachedNetworkImage(
                            key: ValueKey(
                                'restaurant_${r.id}_$imageUrl'), // Force rebuild when image changes
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              color: const Color(0xFFd47b00),
                              child: const Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white),
                                  ),
                                ),
                              ),
                            ),
                            errorWidget: (context, url, error) {
                              debugPrint(
                                  '❌ Error loading restaurant image: $error');
                              debugPrint('   Image URL: $url');
                              debugPrint(
                                  '   Available image fields: cover=${r.coverImageUrl}, image=${r.image}, logo=${r.logoUrl}');
                              return const Icon(Icons.restaurant,
                                  color: Colors.white);
                            },
                            fadeInDuration: const Duration(milliseconds: 300),
                            memCacheWidth: 96, // Optimize for 48dp at 2x scale
                            memCacheHeight: 96,
                          )
                        : const Icon(Icons.restaurant, color: Colors.white);
                  })(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.name,
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                        textAlign: TextAlign.left,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(context)!.restaurant,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                        textAlign: TextAlign.left,
                      ),
                    ],
                  ),
                ),
                // Call button for restaurant (non-invasive)
                if (r.phone.isNotEmpty)
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFd47b00),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.2),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: () => _launchTel(r.phone),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child:
                              Icon(Icons.call, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildFallbackRestaurantCardFloating() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFd47b00), // Orange background
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.restaurant, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  Directionality.of(context) == TextDirection.rtl
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.restaurant,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                  textAlign: Directionality.of(context) == TextDirection.rtl
                      ? TextAlign.right
                      : TextAlign.left,
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context)!.loading,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  textAlign: Directionality.of(context) == TextDirection.rtl
                      ? TextAlign.right
                      : TextAlign.left,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenteredOrderSteps() {
    final l10n = AppLocalizations.of(context)!;
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    final steps = [
      {'label': l10n.placed, 'icon': Icons.receipt_long},
      {'label': l10n.preparing, 'icon': Icons.restaurant},
      {'label': l10n.pickedUp, 'icon': Icons.delivery_dining},
      {'label': l10n.delivered, 'icon': Icons.check_circle},
    ];

    final idx =
        _mapStatusToFourStepIndex(_currentOrder?.status ?? widget.order.status);

    return SizedBox(
      height: 60, // Reduced height
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            // Step icon + label
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color:
                        (i <= idx) ? const Color(0xFFd47b00) : Colors.grey[200],
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    steps[i]['icon'] as IconData,
                    size: 14,
                    color: (i <= idx) ? Colors.white : Colors.grey[500],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  steps[i]['label'] as String,
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color:
                        (i <= idx) ? const Color(0xFFd47b00) : Colors.grey[500],
                  ),
                  textAlign: isRTL ? TextAlign.right : TextAlign.center,
                ),
              ],
            ),
            if (i < steps.length - 1)
              Expanded(
                child: Container(
                  // Align line to vertical center of icon (28px tall)
                  margin: const EdgeInsets.only(top: 14, left: 6, right: 6),
                  height: 2,
                  color: (i < idx) ? const Color(0xFFd47b00) : Colors.grey[300],
                ),
              ),
          ]
        ],
      ),
    );
  }

// Moved _StepsConnectorPainter to bottom of file as a top-level class

  int _mapStatusToFourStepIndex(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
      case OrderStatus.confirmed:
        return 0; // Placed
      case OrderStatus.preparing:
      case OrderStatus.ready:
        return 1; // Preparing
      case OrderStatus.pickedUp:
        return 2; // PickedUp
      case OrderStatus.delivered:
        return 3; // Delivered
      case OrderStatus.cancelled:
        return 0;
    }
  }

  Widget _buildDeliveryManCardFloating() {
    final delivery =
        _currentOrder?.deliveryPerson ?? widget.order.deliveryPerson;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFFd47b00), // Orange background
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.delivery_dining, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  Directionality.of(context) == TextDirection.rtl
                      ? CrossAxisAlignment.end
                      : CrossAxisAlignment.start,
              children: [
                Text(
                  delivery?.name ??
                      AppLocalizations.of(context)!.deliveryPartner,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black,
                  ),
                  textAlign: Directionality.of(context) == TextDirection.rtl
                      ? TextAlign.right
                      : TextAlign.left,
                ),
                const SizedBox(height: 4),
                Text(
                  _estimatedArrivalTime ??
                      AppLocalizations.of(context)!.onTheWay,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                  textAlign: Directionality.of(context) == TextDirection.rtl
                      ? TextAlign.right
                      : TextAlign.left,
                ),
                if (_distanceToCustomer != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    _distanceToCustomer!,
                    style: GoogleFonts.inter(
                      fontSize: 10,
                      color: Colors.grey[500],
                    ),
                    textAlign: Directionality.of(context) == TextDirection.rtl
                        ? TextAlign.right
                        : TextAlign.left,
                  ),
                ],
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFd47b00),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: () {
                  final phone = delivery?.phone;
                  if (phone != null && phone.isNotEmpty) {
                    _launchTel(phone);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                            AppLocalizations.of(context)!
                                .phoneNumberNotAvailable,
                            style: GoogleFonts.inter()),
                        duration: const Duration(seconds: 2),
                        backgroundColor: const Color(0xFFd47b00),
                      ),
                    );
                  }
                },
                child: const Padding(
                  padding: EdgeInsets.all(12),
                  child: Icon(Icons.call, color: Colors.white, size: 18),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

// Painter moved below State class

  Widget _buildDeliveryControls() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Update Location Button
            ElevatedButton.icon(
              onPressed: _updateCurrentLocation,
              icon: const Icon(Icons.my_location, size: 16),
              label: Text(
                AppLocalizations.of(context)!.updateLocation,
                style: GoogleFonts.inter(fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFd47b00),
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),

            const SizedBox(height: 8),

            // Status Update Button
            ElevatedButton.icon(
              onPressed: _updateDeliveryStatus,
              icon: const Icon(Icons.check_circle, size: 16),
              label: Text(
                'Update Status',
                style: GoogleFonts.inter(fontSize: 12),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _updateCurrentLocation() async {
    // This would integrate with location services to update delivery person location
    debugPrint('Updating current location...');
    // Implementation would use geolocator to get current position
  }

  Future<void> _updateDeliveryStatus() async {
    // This would show a dialog to update delivery status
    debugPrint('Updating delivery status...');
    // Implementation would show status update dialog
  }

  /// Enhanced tracking using ComprehensiveMapsService
  Future<void> _loadComprehensiveTrackingInfo() async {
    if (_restaurantLocation == null || _customerLocation == null) {
      debugPrint('❌ Cannot load comprehensive tracking - missing locations');
      return;
    }

    try {
      debugPrint('🗺️ Loading comprehensive tracking information...');

      // Get comprehensive delivery information
      final deliveryInfo =
          await ComprehensiveMapsService.getCompleteDeliveryInfo(
        restaurantLocation: _restaurantLocation!,
        customerLocation: _customerLocation!,
        deliveryPersonLocation: _deliveryPersonLocation,
        restaurantName: widget.order.restaurant?.name,
      );

      if (deliveryInfo != null && mounted) {
        setState(() {
          // Update with comprehensive information
          _estimatedArrivalTime = deliveryInfo.formattedDeliveryTime;
          _distanceToCustomer = deliveryInfo.formattedDistance;
        });

        debugPrint('✅ Comprehensive tracking loaded:');
        debugPrint('   Delivery time: ${deliveryInfo.formattedDeliveryTime}');
        debugPrint('   Distance: ${deliveryInfo.formattedDistance}');
        debugPrint(
            '   Street View available: ${deliveryInfo.streetViewAvailable}');
      }

      // Get real-time order tracking if delivery person location is available
      if (_deliveryPersonLocation != null) {
        final trackingInfo =
            await ComprehensiveMapsService.getRealTimeOrderTracking(
          restaurantLocation: _restaurantLocation!,
          customerLocation: _customerLocation!,
          deliveryPersonLocation: _deliveryPersonLocation!,
          orderId: widget.order.id,
        );

        if (trackingInfo != null && mounted) {
          setState(() {
            _estimatedArrivalTime = trackingInfo.formattedRealTimeETA;
          });

          debugPrint('✅ Real-time tracking updated:');
          debugPrint('   Real-time ETA: ${trackingInfo.formattedRealTimeETA}');
          debugPrint('   Last updated: ${trackingInfo.lastUpdated}');
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading comprehensive tracking: $e');
    }
  }

  /// Initialize comprehensive tracking on app start
  Future<void> _initializeComprehensiveTracking() async {
    // Wait for initial locations to be loaded
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      await _loadComprehensiveTrackingInfo();
    }
  }
}
