import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order.dart';
import '../models/restaurant.dart';
import 'comprehensive_maps_service.dart';
import 'context_aware_service.dart';
import 'location_tracking_service.dart';
import 'logging_service.dart';

enum OrderStep {
  accepted,
  headingToRestaurant,
  arrivedAtRestaurant,
  pickedUp,
  headingToCustomer,
  arrivedAtCustomer,
  delivered,
}

class OrderTrackingData {
  final String orderId;
  final OrderStep currentStep;
  final LatLng? currentLocation;
  final LatLng? restaurantLocation;
  final LatLng? customerLocation;
  final List<LatLng> routePoints;
  final double? distanceToDestination;
  final Duration? estimatedTimeToDestination;
  final DateTime? estimatedArrivalTime;
  final String? currentAddress;
  final String? nextStepAddress;
  final bool isRouteCalculated;

  OrderTrackingData({
    required this.orderId,
    required this.currentStep,
    this.currentLocation,
    this.restaurantLocation,
    this.customerLocation,
    this.routePoints = const [],
    this.distanceToDestination,
    this.estimatedTimeToDestination,
    this.estimatedArrivalTime,
    this.currentAddress,
    this.nextStepAddress,
    this.isRouteCalculated = false,
  });

  OrderTrackingData copyWith({
    String? orderId,
    OrderStep? currentStep,
    LatLng? currentLocation,
    LatLng? restaurantLocation,
    LatLng? customerLocation,
    List<LatLng>? routePoints,
    double? distanceToDestination,
    Duration? estimatedTimeToDestination,
    DateTime? estimatedArrivalTime,
    String? currentAddress,
    String? nextStepAddress,
    bool? isRouteCalculated,
  }) {
    return OrderTrackingData(
      orderId: orderId ?? this.orderId,
      currentStep: currentStep ?? this.currentStep,
      currentLocation: currentLocation ?? this.currentLocation,
      restaurantLocation: restaurantLocation ?? this.restaurantLocation,
      customerLocation: customerLocation ?? this.customerLocation,
      routePoints: routePoints ?? this.routePoints,
      distanceToDestination:
          distanceToDestination ?? this.distanceToDestination,
      estimatedTimeToDestination:
          estimatedTimeToDestination ?? this.estimatedTimeToDestination,
      estimatedArrivalTime: estimatedArrivalTime ?? this.estimatedArrivalTime,
      currentAddress: currentAddress ?? this.currentAddress,
      nextStepAddress: nextStepAddress ?? this.nextStepAddress,
      isRouteCalculated: isRouteCalculated ?? this.isRouteCalculated,
    );
  }
}

class OrderTrackingService extends ChangeNotifier {
  static final OrderTrackingService _instance =
      OrderTrackingService._internal();
  factory OrderTrackingService() => _instance;
  OrderTrackingService._internal();

  SupabaseClient get client => Supabase.instance.client;

  final ContextAwareService _contextAware = ContextAwareService();
  final LocationTrackingService _locationService = LocationTrackingService();
  final LoggingService _logger = LoggingService();

  // Active order tracking data
  final Map<String, OrderTrackingData> _activeOrders = {};
  final Map<String, String> _trackingDeliveryPersons =
      {}; // orderId -> deliveryPersonId
  final Map<String, Timer> _etaUpdateTimers = {};
  final Map<String, DateTime> _operationStartTimes = {};
  final Map<String, int> _operationCounts = {};

  // Initialize the service
  Future<void> initialize() async {
    try {
      _logger.startPerformanceTimer('order_tracking_service_init');
      await _contextAware.initialize();
      _logger.endPerformanceTimer('order_tracking_service_init',
          details: 'OrderTrackingService initialized successfully');
      debugPrint('🚀 OrderTrackingService initialized');
      _logger.info('OrderTrackingService initialized', tag: 'ORDER_TRACKING');
    } catch (e) {
      _logger.error('Failed to initialize OrderTrackingService',
          tag: 'ORDER_TRACKING', error: e);
      rethrow;
    }
  }

  // Start tracking an order
  Future<bool> startOrderTracking({
    required String orderId,
    required String deliveryPersonId,
    required LatLng currentLocation,
  }) async {
    try {
      _logger.startPerformanceTimer('start_order_tracking', metadata: {
        'order_id': orderId,
        'delivery_person_id': deliveryPersonId,
        'latitude': currentLocation.latitude,
        'longitude': currentLocation.longitude,
      });

      _logger.logUserAction(
        'order_tracking_started',
        userId: deliveryPersonId,
        data: {
          'order_id': orderId,
          'delivery_person_id': deliveryPersonId,
          'latitude': currentLocation.latitude,
          'longitude': currentLocation.longitude,
        },
      );

      return await _contextAware.executeWithContext(
            operation: 'startOrderTracking',
            service: 'OrderTrackingService',
            operationFunction: () async {
              try {
                // Get order details
                final order = await _getOrderDetails(orderId);
                if (order == null) {
                  _logger.warning('Order not found for tracking',
                      tag: 'ORDER_TRACKING',
                      additionalData: {
                        'order_id': orderId,
                      });
                  debugPrint('❌ Order $orderId not found');
                  return false;
                }

                // Extract locations
                final restaurantLocation =
                    _extractLocationFromRestaurant(order.restaurant);
                final customerLocation =
                    _extractLocationFromAddress(order.deliveryAddress.toMap());

                if (restaurantLocation == null || customerLocation == null) {
                  _logger.warning('Missing location data for order tracking',
                      tag: 'ORDER_TRACKING',
                      additionalData: {
                        'order_id': orderId,
                        'has_restaurant_location': restaurantLocation != null,
                        'has_customer_location': customerLocation != null,
                      });
                  debugPrint('❌ Missing location data for order $orderId');
                  return false;
                }

                // Create initial tracking data
                final trackingData = OrderTrackingData(
                  orderId: orderId,
                  currentStep: OrderStep.accepted,
                  currentLocation: currentLocation,
                  restaurantLocation: restaurantLocation,
                  customerLocation: customerLocation,
                  currentAddress:
                      await _getAddressFromLocation(currentLocation),
                  nextStepAddress:
                      await _getAddressFromLocation(restaurantLocation),
                );

                _activeOrders[orderId] = trackingData;
                _trackingDeliveryPersons[orderId] = deliveryPersonId;

                // Calculate initial route and ETA
                await _calculateRouteAndETA(orderId);

                // Start ETA updates
                _startETAUpdates(orderId);

                _logger.logUserAction(
                  'order_tracking_started_successfully',
                  userId: deliveryPersonId,
                  data: {
                    'order_id': orderId,
                    'delivery_person_id': deliveryPersonId,
                    'restaurant_location': restaurantLocation.toString(),
                    'customer_location': customerLocation.toString(),
                  },
                );

                notifyListeners();
                debugPrint('✅ Started tracking order $orderId');
                return true;
              } catch (e) {
                _logger.error('Error starting order tracking',
                    tag: 'ORDER_TRACKING',
                    error: e,
                    additionalData: {
                      'order_id': orderId,
                      'delivery_person_id': deliveryPersonId,
                    });
                debugPrint('Error starting order tracking: $e');
                return false;
              }
            },
            metadata: {
              'order_id': orderId,
              'delivery_person_id': deliveryPersonId,
            },
          ) ??
          false;
    } finally {
      _logger.endPerformanceTimer('start_order_tracking',
          details: 'Order tracking start completed');
    }
  }

  // Update order step
  Future<bool> updateOrderStep({
    required String orderId,
    required OrderStep newStep,
    LatLng? location,
  }) async {
    return await _contextAware.executeWithContext(
          operation: 'updateOrderStep',
          service: 'OrderTrackingService',
          operationFunction: () async {
            try {
              final trackingData = _activeOrders[orderId];
              if (trackingData == null) {
                debugPrint('❌ Order $orderId not being tracked');
                return false;
              }

              // Update tracking data
              final updatedData = trackingData.copyWith(
                currentStep: newStep,
                currentLocation: location ?? trackingData.currentLocation,
                currentAddress: location != null
                    ? await _getAddressFromLocation(location)
                    : trackingData.currentAddress,
                nextStepAddress: _getNextStepAddress(newStep, trackingData),
              );

              _activeOrders[orderId] = updatedData;

              // Update order status in database
              await _updateOrderStatusInDatabase(orderId, newStep);

              // Recalculate route and ETA if needed
              if (_shouldRecalculateRoute(newStep)) {
                await _calculateRouteAndETA(orderId);
              }

              notifyListeners();
              debugPrint('✅ Updated order $orderId to step: $newStep');
              return true;
            } catch (e) {
              debugPrint('Error updating order step: $e');
              return false;
            }
          },
          metadata: {
            'order_id': orderId,
            'new_step': newStep.name,
          },
        ) ??
        false;
  }

  // Get tracking data for an order
  OrderTrackingData? getOrderTrackingData(String orderId) {
    return _activeOrders[orderId];
  }

  // Get all active tracking data
  Map<String, OrderTrackingData> get activeOrders =>
      Map.unmodifiable(_activeOrders);

  // Stop tracking an order
  Future<bool> stopOrderTracking(String orderId) async {
    return await _contextAware.executeWithContext(
          operation: 'stopOrderTracking',
          service: 'OrderTrackingService',
          operationFunction: () async {
            try {
              // Cancel ETA timer
              _etaUpdateTimers[orderId]?.cancel();
              _etaUpdateTimers.remove(orderId);

              // Remove from active orders and tracking
              _activeOrders.remove(orderId);
              _trackingDeliveryPersons.remove(orderId);

              notifyListeners();
              debugPrint('✅ Stopped tracking order $orderId');
              return true;
            } catch (e) {
              debugPrint('Error stopping order tracking: $e');
              return false;
            }
          },
          metadata: {
            'order_id': orderId,
          },
        ) ??
        false;
  }

  // Private helper methods
  Future<Order?> _getOrderDetails(String orderId) async {
    try {
      final response = await client.from('orders').select('''
            *,
            restaurants(*),
            user_profiles(*),
            delivery_personnel(
              *,
              user:user_id(*)
            ),
            order_items(
              *,
              menu_items(*)
            )
          ''').eq('id', orderId).single();

      return Order.fromJson(response);
    } catch (e) {
      debugPrint('Error fetching order details: $e');
      return null;
    }
  }

  LatLng? _extractLocationFromAddress(Map<String, dynamic>? address) {
    if (address == null || address.isEmpty) return null;

    final lat = address['latitude'] as double?;
    final lng = address['longitude'] as double?;

    if (lat != null && lng != null) {
      return LatLng(lat, lng);
    }
    return null;
  }

  LatLng? _extractLocationFromRestaurant(Restaurant? restaurant) {
    if (restaurant == null) return null;

    if (restaurant.latitude != null && restaurant.longitude != null) {
      return LatLng(restaurant.latitude!, restaurant.longitude!);
    }
    return null;
  }

  Future<String> _getAddressFromLocation(LatLng location) async {
    // This would typically use a geocoding service
    // For now, return coordinates as a placeholder
    return '${location.latitude.toStringAsFixed(6)}, ${location.longitude.toStringAsFixed(6)}';
  }

  String? _getNextStepAddress(OrderStep step, OrderTrackingData data) {
    switch (step) {
      case OrderStep.accepted:
      case OrderStep.headingToRestaurant:
        return data.restaurantLocation != null ? 'Restaurant Location' : null;
      case OrderStep.arrivedAtRestaurant:
      case OrderStep.pickedUp:
      case OrderStep.headingToCustomer:
        return data.customerLocation != null ? 'Customer Location' : null;
      case OrderStep.arrivedAtCustomer:
      case OrderStep.delivered:
        return null;
    }
  }

  bool _shouldRecalculateRoute(OrderStep step) {
    return step == OrderStep.headingToRestaurant ||
        step == OrderStep.headingToCustomer;
  }

  Future<void> _calculateRouteAndETA(String orderId) async {
    final trackingData = _activeOrders[orderId];
    if (trackingData == null) return;

    try {
      LatLng? destination;
      switch (trackingData.currentStep) {
        case OrderStep.accepted:
        case OrderStep.headingToRestaurant:
        case OrderStep.arrivedAtRestaurant:
          destination = trackingData.restaurantLocation;
          break;
        case OrderStep.pickedUp:
        case OrderStep.headingToCustomer:
        case OrderStep.arrivedAtCustomer:
        case OrderStep.delivered:
          destination = trackingData.customerLocation;
          break;
      }

      if (destination == null || trackingData.currentLocation == null) return;

      // Enhanced route calculation with ComprehensiveMapsService
      try {
        // Get comprehensive delivery information
        final deliveryInfo =
            await ComprehensiveMapsService.getCompleteDeliveryInfo(
          restaurantLocation: trackingData.restaurantLocation ?? destination,
          customerLocation: trackingData.customerLocation ?? destination,
          deliveryPersonLocation: trackingData.currentLocation,
          restaurantName: 'Restaurant', // This would come from order data
        );

        if (deliveryInfo != null) {
          // Use comprehensive maps data for more accurate calculations
          final routePoints = _generateMockRoutePoints(
            trackingData.currentLocation!,
            destination,
          );

          // Update tracking data with comprehensive information
          _activeOrders[orderId] = trackingData.copyWith(
            routePoints: routePoints,
            distanceToDestination: deliveryInfo.distanceKm,
            estimatedTimeToDestination:
                Duration(minutes: deliveryInfo.estimatedDeliveryMinutes),
            estimatedArrivalTime: DateTime.now()
                .add(Duration(minutes: deliveryInfo.estimatedDeliveryMinutes)),
            isRouteCalculated: true,
          );

          debugPrint(
              '✅ Enhanced route calculated using ComprehensiveMapsService');
          notifyListeners();
          return;
        }
      } catch (e) {
        debugPrint(
            '⚠️ ComprehensiveMapsService failed, falling back to basic calculation: $e');
      }

      // Fallback to basic calculation
      final distance = _calculateDistance(
        trackingData.currentLocation!.latitude,
        trackingData.currentLocation!.longitude,
        destination.latitude,
        destination.longitude,
      );

      // Estimate travel time (assuming average speed of 30 km/h in city)
      const double averageSpeedKmh = 30.0;
      final estimatedMinutes = (distance / averageSpeedKmh * 60).round();
      final estimatedTime = Duration(minutes: estimatedMinutes);
      final estimatedArrival = DateTime.now().add(estimatedTime);

      // Generate mock route points (in real implementation, use Google Directions API)
      final routePoints = _generateMockRoutePoints(
        trackingData.currentLocation!,
        destination,
      );

      // Update tracking data
      _activeOrders[orderId] = trackingData.copyWith(
        routePoints: routePoints,
        distanceToDestination: distance,
        estimatedTimeToDestination: estimatedTime,
        estimatedArrivalTime: estimatedArrival,
        isRouteCalculated: true,
      );

      notifyListeners();
    } catch (e) {
      debugPrint('Error calculating route and ETA: $e');
    }
  }

  List<LatLng> _generateMockRoutePoints(LatLng start, LatLng end) {
    // Generate intermediate points for a mock route
    final points = <LatLng>[];
    const int numPoints = 10;

    for (int i = 0; i <= numPoints; i++) {
      final ratio = i / numPoints;
      final lat = start.latitude + (end.latitude - start.latitude) * ratio;
      final lng = start.longitude + (end.longitude - start.longitude) * ratio;

      // Add some random variation to simulate real road paths
      final random = Random();
      final latVariation = (random.nextDouble() - 0.5) * 0.001;
      final lngVariation = (random.nextDouble() - 0.5) * 0.001;

      points.add(LatLng(lat + latVariation, lng + lngVariation));
    }

    return points;
  }

  void _updateOrderLocation(String orderId, LatLng location) {
    final trackingData = _activeOrders[orderId];
    if (trackingData == null) return;

    _activeOrders[orderId] = trackingData.copyWith(
      currentLocation: location,
    );

    // Recalculate ETA if route is calculated
    if (trackingData.isRouteCalculated) {
      _calculateRouteAndETA(orderId);
    }

    notifyListeners();
  }

  void _startETAUpdates(String orderId) {
    _etaUpdateTimers[orderId] = Timer.periodic(
      const Duration(seconds: 30),
      (timer) {
        final trackingData = _activeOrders[orderId];
        if (trackingData == null) {
          timer.cancel();
          return;
        }

        // Check for location updates
        final deliveryPersonId = _trackingDeliveryPersons[orderId];
        if (deliveryPersonId != null) {
          _checkForLocationUpdates(orderId, deliveryPersonId);
        }

        _calculateRouteAndETA(orderId);
      },
    );
  }

  void _checkForLocationUpdates(String orderId, String deliveryPersonId) {
    final recentLocations = _locationService.recentLocations;
    final relevantLocation = recentLocations
        .where((location) => location.deliveryPersonId == deliveryPersonId)
        .lastOrNull;

    if (relevantLocation != null) {
      _updateOrderLocation(orderId,
          LatLng(relevantLocation.latitude, relevantLocation.longitude));
    }
  }

  Future<void> _updateOrderStatusInDatabase(
      String orderId, OrderStep step) async {
    try {
      String status;
      switch (step) {
        case OrderStep.accepted:
          status = 'picked_up';
          break;
        case OrderStep.headingToRestaurant:
        case OrderStep.arrivedAtRestaurant:
          status = 'picked_up';
          break;
        case OrderStep.pickedUp:
        case OrderStep.headingToCustomer:
        case OrderStep.arrivedAtCustomer:
          status = 'picked_up';
          break;
        case OrderStep.delivered:
          status = 'delivered';
          break;
      }

      final response = await client
          .from('orders')
          .update({
            'status': status,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', orderId)
          .neq('status', status)
          .select('id, status, updated_at');

      if (response.isEmpty) {
        debugPrint(
            'No rows updated for order $orderId (not found or status unchanged)');
      }
    } catch (e) {
      debugPrint('Error updating order status in database: $e');
    }
  }

  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);

    final double c = 2 * asin(sqrt(a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (3.14159265359 / 180);
  }

  // Get context summary for debugging
  Map<String, dynamic> getContextSummary() {
    return _contextAware.getContextSummary();
  }

  /// Get performance analytics for the service
  Map<String, dynamic> getPerformanceAnalytics() {
    final totalOperations =
        _operationCounts.values.fold(0, (sum, count) => sum + count);
    final averageOperationTime = _operationStartTimes.isNotEmpty
        ? _operationStartTimes.values
                .map((startTime) =>
                    DateTime.now().difference(startTime).inMilliseconds)
                .reduce((a, b) => a + b) /
            _operationStartTimes.length
        : 0.0;

    return {
      'service_name': 'OrderTrackingService',
      'active_orders_count': _activeOrders.length,
      'tracking_delivery_persons_count': _trackingDeliveryPersons.length,
      'eta_timers_count': _etaUpdateTimers.length,
      'total_operations': totalOperations,
      'average_operation_time_ms': averageOperationTime,
      'operation_counts': Map.from(_operationCounts),
    };
  }

  /// Clear performance cache
  void clearPerformanceCache() {
    _operationStartTimes.clear();
    _operationCounts.clear();
    _logger.info('OrderTrackingService performance cache cleared',
        tag: 'ORDER_TRACKING');
  }

  @override
  void dispose() {
    // Cancel all timers
    for (final timer in _etaUpdateTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }
}
