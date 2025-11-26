import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order.dart';
import 'geolocation_service.dart';
import 'socket_service.dart';

/// Enhanced Order Tracking Service combining Socket.IO and Supabase
class EnhancedOrderTrackingService extends ChangeNotifier {
  static final EnhancedOrderTrackingService _instance =
      EnhancedOrderTrackingService._internal();
  factory EnhancedOrderTrackingService() => _instance;
  EnhancedOrderTrackingService._internal();

  // Services
  final SocketService _socketService = SocketService();
  SupabaseClient get _supabase => Supabase.instance.client;

  // Tracking state
  final Map<String, bool> _trackingStatus = {};
  final Map<String, StreamController<DeliveryLocation>> _locationStreams = {};
  final Map<String, LatLng> _lastKnownLocations = {};

  // Service state
  bool disposed = false;

  // Stream controllers
  final StreamController<Order> _orderUpdateController =
      StreamController<Order>.broadcast();
  final StreamController<Map<String, dynamic>> _deliveryStatusController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _deliveryLocationController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Getters
  Stream<Order> get orderUpdateStream => _orderUpdateController.stream;
  Stream<Map<String, dynamic>> get deliveryStatusStream =>
      _deliveryStatusController.stream;
  Stream<Map<String, dynamic>> get deliveryLocationStream =>
      _deliveryLocationController.stream;

  // Configuration
  static const Duration _locationUpdateInterval = Duration(seconds: 3);
  static const double _minMovementThreshold = 0.01; // ~10 meters

  /// Initialize the enhanced tracking service
  Future<void> initialize() async {
    // Initialize Socket.IO connection
    await _socketService.initialize();

    // Set up Socket.IO event listeners
    _setupSocketListeners();

    debugPrint('✅ Enhanced Order Tracking Service initialized');
  }

  /// Set up Socket.IO event listeners
  void _setupSocketListeners() {
    // Listen for order status changes
    _socketService.orderUpdatesStream.listen((data) {
      _handleOrderStatusChange(data);
    });

    // Listen for delivery location updates
    _socketService.deliveryLocationStream.listen((data) {
      _handleDeliveryLocationUpdate(data);
    });
  }

  /// Start enhanced order tracking
  Future<bool> startOrderTracking({
    required String orderId,
    required String deliveryPersonId,
  }) async {
    try {
      // Check if already tracking
      if (_trackingStatus[orderId] == true) {
        debugPrint('📍 Order $orderId is already being tracked');
        return true;
      }

      // Join order room for real-time updates
      _socketService.joinOrderRoom(orderId);

      // Create location stream
      _locationStreams[orderId] =
          StreamController<DeliveryLocation>.broadcast();

      // Update tracking status
      _trackingStatus[orderId] = true;

      // Start periodic location updates
      _startPeriodicLocationUpdates(orderId, deliveryPersonId);

      debugPrint('✅ Started enhanced tracking for order $orderId');

      // Only notify listeners if the service is still active
      if (!disposed) {
        notifyListeners();
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error starting enhanced order tracking: $e');
      return false;
    }
  }

  /// Stop order tracking
  Future<bool> stopOrderTracking(String orderId,
      {bool skipNotification = false}) async {
    try {
      // Leave order room
      _socketService.leaveOrderRoom(orderId);

      // Stop location updates
      await _locationStreams[orderId]?.close();
      _locationStreams.remove(orderId);

      // Update tracking status
      _trackingStatus[orderId] = false;
      _lastKnownLocations.remove(orderId);

      debugPrint('✅ Stopped tracking for order $orderId');

      // Only notify listeners if the service is still active and not during disposal
      if (!disposed && !skipNotification) {
        try {
          notifyListeners();
        } catch (e) {
          debugPrint(
              '⚠️ Could not notify listeners during stopOrderTracking: $e');
        }
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error stopping order tracking: $e');
      return false;
    }
  }

  /// Get location stream for an order
  Stream<DeliveryLocation>? getLocationStream(String orderId) {
    return _locationStreams[orderId]?.stream;
  }

  /// Start periodic location updates
  void _startPeriodicLocationUpdates(String orderId, String deliveryPersonId) {
    Timer.periodic(_locationUpdateInterval, (timer) async {
      if (_trackingStatus[orderId] != true) {
        timer.cancel();
        return;
      }

      try {
        // Get current location (this would integrate with your location service)
        final currentLocation = await _getCurrentLocation();
        if (currentLocation == null) return;

        // Check if location has changed significantly
        final lastLocation = _lastKnownLocations[orderId];
        if (lastLocation != null) {
          final distance = _calculateDistance(
            lastLocation.latitude,
            lastLocation.longitude,
            currentLocation.latitude,
            currentLocation.longitude,
          );

          if (distance < _minMovementThreshold) {
            return; // Skip update if movement is too small
          }
        }

        // Update last known location
        _lastKnownLocations[orderId] = currentLocation;

        // Send location update via Socket.IO
        _socketService.sendDeliveryLocationUpdate(
          orderId,
          currentLocation.latitude,
          currentLocation.longitude,
        );

        // Create delivery location data for stream
        final locationData = {
          'orderId': orderId,
          'latitude': currentLocation.latitude,
          'longitude': currentLocation.longitude,
          'timestamp': DateTime.now().toIso8601String(),
          'deliveryPersonId': deliveryPersonId,
        };

        // Emit to delivery location stream
        _deliveryLocationController.add(locationData);

        // Create delivery location object
        final deliveryLocation = DeliveryLocation(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          deliveryPersonId: deliveryPersonId,
          latitude: currentLocation.latitude,
          longitude: currentLocation.longitude,
          accuracy: 10.0, // This would come from actual location service
          speed: 0.0,
          heading: 0.0,
          address: null,
          isActive: true,
          timestamp: DateTime.now(),
        );

        // Emit to local stream
        _locationStreams[orderId]?.add(deliveryLocation);
      } catch (e) {
        debugPrint('❌ Error updating location for order $orderId: $e');
      }
    });
  }

  /// Handle order status changes from Socket.IO
  void _handleOrderStatusChange(Map<String, dynamic> data) {
    try {
      final orderId = data['orderId'] as String;
      final status = data['status'] as String;

      debugPrint('📦 Order status changed via Socket.IO: $orderId -> $status');

      // Emit to delivery status stream
      _deliveryStatusController.add(data);

      // If order is delivered or cancelled, stop tracking
      if (status == 'delivered' || status == 'cancelled') {
        stopOrderTracking(orderId);
      }
    } catch (e) {
      debugPrint('❌ Error handling order status change: $e');
    }
  }

  /// Handle delivery location updates from Socket.IO
  void _handleDeliveryLocationUpdate(Map<String, dynamic> data) {
    try {
      final orderId = data['orderId'] as String;
      final latitude = (data['latitude'] as num).toDouble();
      final longitude = (data['longitude'] as num).toDouble();
      final timestamp = DateTime.parse(data['timestamp'] as String);

      debugPrint(
          '📍 Delivery location update via Socket.IO: $orderId at ($latitude, $longitude)');

      // Emit to delivery location stream
      _deliveryLocationController.add(data);

      // Create delivery location object
      final deliveryLocation = DeliveryLocation(
        id: timestamp.millisecondsSinceEpoch.toString(),
        deliveryPersonId: '', // This would come from the data
        latitude: latitude,
        longitude: longitude,
        accuracy: 10.0,
        speed: 0.0,
        heading: 0.0,
        address: null,
        isActive: true,
        timestamp: timestamp,
      );

      // Emit to local stream if we have one
      _locationStreams[orderId]?.add(deliveryLocation);
    } catch (e) {
      debugPrint('❌ Error handling delivery location update: $e');
    }
  }

  /// Send order status change
  Future<void> updateOrderStatus(String orderId, String status,
      {String? customerId}) async {
    try {
      // Validate against allowed statuses
      const allowed = [
        'pending',
        'confirmed',
        'preparing',
        'ready',
        'picked_up',
        'delivered',
        'cancelled'
      ];
      final normalized = status.trim();
      if (!allowed.contains(normalized)) {
        throw Exception('Invalid status: $status');
      }
      // Update in Supabase
      final response = await _supabase
          .from('orders')
          .update({
            'status': normalized,
            'updated_at': DateTime.now().toIso8601String()
          })
          .eq('id', orderId)
          .neq('status', normalized)
          .select('id, status, updated_at');

      if (response.isEmpty) {
        throw Exception('No rows updated (id not found or status unchanged)');
      }

      // Send via Socket.IO for real-time updates
      _socketService.sendOrderStatusChange(orderId, normalized,
          customerId: customerId);

      debugPrint('✅ Updated order status: $orderId -> $status');
    } catch (e) {
      debugPrint('❌ Error updating order status: $e');
      rethrow;
    }
  }

  /// Get current location using GeolocationService
  Future<LatLng?> _getCurrentLocation() async {
    try {
      final geoService = GeolocationService();
      final location = await geoService.getFreshCurrentLocation();
      if (location != null) {
        return LatLng(location.latitude, location.longitude);
      }
    } catch (e) {
      debugPrint('❌ Error getting current location: $e');
    }

    // Fallback to mock location for testing
    return const LatLng(36.7538, 3.0588);
  }

  /// Calculate distance between two points
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

  /// Check if order is being tracked
  bool isOrderBeingTracked(String orderId) {
    return _trackingStatus[orderId] == true;
  }

  /// Get tracking status for all orders
  Map<String, bool> get trackingStatus => Map.unmodifiable(_trackingStatus);

  /// Dispose resources
  @override
  void dispose() {
    disposed = true;

    // Stop all tracking without notifications to avoid widget tree lock issues
    for (final orderId in _trackingStatus.keys.toList()) {
      stopOrderTracking(orderId, skipNotification: true);
    }

    _orderUpdateController.close();
    _deliveryStatusController.close();
    _deliveryLocationController.close();

    super.dispose();
  }
}

/// Delivery location model for real-time tracking
class DeliveryLocation {
  final String id;
  final String deliveryPersonId;
  final double latitude;
  final double longitude;
  final double accuracy;
  final double speed;
  final double heading;
  final String? address;
  final bool isActive;
  final DateTime timestamp;

  const DeliveryLocation({
    required this.id,
    required this.deliveryPersonId,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.speed,
    required this.heading,
    required this.isActive,
    required this.timestamp,
    this.address,
  });

  LatLng get latLng => LatLng(latitude, longitude);

  @override
  String toString() {
    return 'DeliveryLocation(id: $id, lat: $latitude, lng: $longitude, timestamp: $timestamp)';
  }
}
