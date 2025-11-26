import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/delivery_location.dart';
import 'comprehensive_maps_service.dart';
import 'context_aware_service.dart';

class DeliveryTrackingService extends ChangeNotifier {
  static final DeliveryTrackingService _instance =
      DeliveryTrackingService._internal();
  factory DeliveryTrackingService() => _instance;
  DeliveryTrackingService._internal();

  SupabaseClient get client => Supabase.instance.client;

  // Context-aware service for tracking and validation
  final ContextAwareService _contextAware = ContextAwareService();

  // Active tracking subscriptions
  final Map<String, RealtimeChannel> _trackingSubscriptions = {};

  // Current location updates
  final Map<String, StreamController<DeliveryLocation>> _locationStreams = {};

  // Tracking status
  final Map<String, bool> _trackingStatus = {};

  // Initialize the service
  Future<void> initialize() async {
    await _contextAware.initialize();
    debugPrint('🚀 DeliveryTrackingService initialized with context tracking');
  }

  // Start real-time tracking for an order
  Future<bool> startOrderTracking({
    required String orderId,
    required String deliveryPersonId,
  }) async {
    return await _contextAware.executeWithContext(
          operation: 'startOrderTracking',
          service: 'DeliveryTrackingService',
          operationFunction: () async {
            try {
              // Check if already tracking
              if (_trackingStatus[orderId] == true) {
                debugPrint('📍 Order $orderId is already being tracked');
                return true;
              }

              // TODO(dev): Implement real-time tracking when RealtimeChannel API is available
              // final channel = client.channel('order_tracking_$orderId')
              //   .on(RealtimeListenTypes.postgresChanges, ChannelFilter(...))
              //   .subscribe();

              // Create location stream
              _locationStreams[orderId] =
                  StreamController<DeliveryLocation>.broadcast();

              // Update tracking status
              _trackingStatus[orderId] = true;

              debugPrint('✅ Started real-time tracking for order $orderId');
              notifyListeners();

              return true;
            } catch (e) {
              debugPrint('❌ Error starting order tracking: $e');
              return false;
            }
          },
          metadata: {
            'order_id': orderId,
            'delivery_person_id': deliveryPersonId,
          },
        ) ??
        false;
  }

  // Stop tracking for an order
  Future<bool> stopOrderTracking(String orderId) async {
    return await _contextAware.executeWithContext(
          operation: 'stopOrderTracking',
          service: 'DeliveryTrackingService',
          operationFunction: () async {
            try {
              // Unsubscribe from real-time updates
              final channel = _trackingSubscriptions[orderId];
              if (channel != null) {
                await client.removeChannel(channel);
                _trackingSubscriptions.remove(orderId);
              }

              // Close location stream
              final stream = _locationStreams[orderId];
              if (stream != null) {
                await stream.close();
                _locationStreams.remove(orderId);
              }

              // Update tracking status
              _trackingStatus[orderId] = false;

              debugPrint('✅ Stopped tracking for order $orderId');
              notifyListeners();

              return true;
            } catch (e) {
              debugPrint('❌ Error stopping order tracking: $e');
              return false;
            }
          },
          metadata: {'order_id': orderId},
        ) ??
        false;
  }

  // Get current location stream for an order
  Stream<DeliveryLocation>? getLocationStream(String orderId) {
    return _locationStreams[orderId]?.stream;
  }

  // Update delivery person location
  Future<bool> updateDeliveryLocation({
    required String deliveryPersonId,
    required double latitude,
    required double longitude,
    double? accuracy,
    double? speed,
    double? heading,
  }) async {
    return await _contextAware.executeWithContext(
          operation: 'updateDeliveryLocation',
          service: 'DeliveryTrackingService',
          operationFunction: () async {
            try {
              final locationData = {
                'delivery_person_id': deliveryPersonId,
                'latitude': latitude,
                'longitude': longitude,
                'accuracy': accuracy ?? 10.0,
                'speed': speed ?? 0.0,
                'heading': heading ?? 0.0,
                'is_active': true,
                'updated_at': DateTime.now().toIso8601String(),
              };

              // Upsert location
              await client.from('delivery_locations').upsert(locationData);

              debugPrint('📍 Updated delivery location: $latitude, $longitude');
              return true;
            } catch (e) {
              debugPrint('❌ Error updating delivery location: $e');
              return false;
            }
          },
          metadata: {
            'delivery_person_id': deliveryPersonId,
            'latitude': latitude,
            'longitude': longitude,
          },
        ) ??
        false;
  }

  // Get current tracking status
  bool isTracking(String orderId) {
    return _trackingStatus[orderId] ?? false;
  }

  // Get all active tracking sessions
  List<String> getActiveTrackingSessions() {
    return _trackingStatus.entries
        .where((entry) => entry.value)
        .map((entry) => entry.key)
        .toList();
  }

  // Clean up all tracking sessions
  Future<void> cleanupAllTracking() async {
    debugPrint('🧹 Cleaning up all tracking sessions...');

    final activeSessions = List<String>.from(getActiveTrackingSessions());

    for (final orderId in activeSessions) {
      await stopOrderTracking(orderId);
    }

    debugPrint('✅ All tracking sessions cleaned up');
  }

  // Get context summary for debugging
  Map<String, dynamic> getContextSummary() {
    return _contextAware.getContextSummary();
  }

  /// Enhanced delivery tracking with ComprehensiveMapsService
  Future<Map<String, dynamic>?> getComprehensiveDeliveryInfo({
    required String orderId,
    required double deliveryPersonLatitude,
    required double deliveryPersonLongitude,
    required double restaurantLatitude,
    required double restaurantLongitude,
    required double customerLatitude,
    required double customerLongitude,
    String? restaurantName,
  }) async {
    return _contextAware.executeWithContext(
      operation: 'getComprehensiveDeliveryInfo',
      service: 'DeliveryTrackingService',
      operationFunction: () async {
        try {
          debugPrint(
              '🗺️ Getting comprehensive delivery info for order $orderId');

          final deliveryInfo =
              await ComprehensiveMapsService.getCompleteDeliveryInfo(
            restaurantLocation: LatLng(restaurantLatitude, restaurantLongitude),
            customerLocation: LatLng(customerLatitude, customerLongitude),
            deliveryPersonLocation:
                LatLng(deliveryPersonLatitude, deliveryPersonLongitude),
            restaurantName: restaurantName ?? 'Restaurant',
          );

          if (deliveryInfo != null) {
            debugPrint('✅ Comprehensive delivery info retrieved:');
            debugPrint('   Distance: ${deliveryInfo.formattedDistance}');
            debugPrint(
                '   Delivery time: ${deliveryInfo.formattedDeliveryTime}');
            debugPrint(
                '   Street View available: ${deliveryInfo.streetViewAvailable}');

            return {
              'orderId': orderId,
              'distanceKm': deliveryInfo.distanceKm,
              'formattedDistance': deliveryInfo.formattedDistance,
              'estimatedMinutes': deliveryInfo.estimatedDeliveryMinutes,
              'formattedDeliveryTime': deliveryInfo.formattedDeliveryTime,
              'streetViewAvailable': deliveryInfo.streetViewAvailable,
              'routePoints':
                  null, // Route points would need to be fetched separately
              'timestamp': DateTime.now().toIso8601String(),
            };
          }

          return null;
        } catch (e) {
          debugPrint('❌ Error getting comprehensive delivery info: $e');
          return null;
        }
      },
      metadata: {
        'order_id': orderId,
        'delivery_person_lat': deliveryPersonLatitude,
        'delivery_person_lng': deliveryPersonLongitude,
      },
    );
  }

  /// Get real-time order tracking with comprehensive maps
  Future<Map<String, dynamic>?> getRealTimeOrderTracking({
    required String orderId,
    required double deliveryPersonLatitude,
    required double deliveryPersonLongitude,
    required double restaurantLatitude,
    required double restaurantLongitude,
    required double customerLatitude,
    required double customerLongitude,
  }) async {
    return _contextAware.executeWithContext(
      operation: 'getRealTimeOrderTracking',
      service: 'DeliveryTrackingService',
      operationFunction: () async {
        try {
          debugPrint('📍 Getting real-time order tracking for order $orderId');

          final trackingInfo =
              await ComprehensiveMapsService.getRealTimeOrderTracking(
            restaurantLocation: LatLng(restaurantLatitude, restaurantLongitude),
            customerLocation: LatLng(customerLatitude, customerLongitude),
            deliveryPersonLocation:
                LatLng(deliveryPersonLatitude, deliveryPersonLongitude),
            orderId: orderId,
          );

          if (trackingInfo != null) {
            debugPrint('✅ Real-time tracking info retrieved:');
            debugPrint(
                '   Real-time ETA: ${trackingInfo.formattedRealTimeETA}');
            debugPrint('   Last updated: ${trackingInfo.lastUpdated}');

            return {
              'orderId': orderId,
              'realTimeETA': trackingInfo.formattedRealTimeETA,
              'lastUpdated': trackingInfo.lastUpdated,
              'timestamp': DateTime.now().toIso8601String(),
            };
          }

          return null;
        } catch (e) {
          debugPrint('❌ Error getting real-time order tracking: $e');
          return null;
        }
      },
      metadata: {
        'order_id': orderId,
        'delivery_person_lat': deliveryPersonLatitude,
        'delivery_person_lng': deliveryPersonLongitude,
      },
    );
  }

  // Dispose resources
  @override
  void dispose() {
    cleanupAllTracking();
    super.dispose();
  }
}
