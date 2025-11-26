import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/delivery_location.dart';
import 'context_aware_service.dart';
import 'logging_service.dart';

class LocationTrackingService extends ChangeNotifier {
  static final LocationTrackingService _instance =
      LocationTrackingService._internal();
  factory LocationTrackingService() => _instance;
  LocationTrackingService._internal();

  SupabaseClient get client => Supabase.instance.client;

  // Context-aware service for tracking and validation
  final ContextAwareService _contextAware = ContextAwareService();

  // Logging service for business metrics
  final LoggingService _logger = LoggingService();

  // Real-time location tracking
  RealtimeChannel? _locationChannel;
  final List<DeliveryLocation> _recentLocations = [];
  bool _isTracking = false;

  // Initialize the service with context tracking
  Future<void> initialize() async {
    await _contextAware.initialize();
    debugPrint('🚀 LocationTrackingService initialized with context tracking');
  }

  // Start location tracking for a delivery person
  Future<bool> startLocationTracking({
    required String deliveryPersonId,
    required double latitude,
    required double longitude,
    double? accuracy,
    double? speed,
    double? heading,
    String? address,
  }) async {
    // Start performance timer
    _logger.startPerformanceTimer('location_tracking_start', metadata: {
      'delivery_person_id': deliveryPersonId,
      'latitude': latitude,
      'longitude': longitude,
    });

    return await _contextAware.executeWithContext(
          operation: 'startLocationTracking',
          service: 'LocationTrackingService',
          operationFunction: () async {
            try {
              final locationData = {
                'delivery_person_id': deliveryPersonId,
                'latitude': latitude,
                'longitude': longitude,
                'accuracy': accuracy,
                'speed': speed,
                'heading': heading,
                'address': address,
                'is_active': true,
                'timestamp': DateTime.now().toIso8601String(),
              };

              final response = await client
                  .from('delivery_locations')
                  .insert(locationData)
                  .select()
                  .single();

              final location = DeliveryLocation.fromJson(response);
              _recentLocations.add(location);

              // Keep only last 100 locations in memory
              if (_recentLocations.length > 100) {
                _recentLocations.removeAt(0);
              }

              _isTracking = true;
              notifyListeners();

              // Log business metrics
              _logger.logLocationMetrics(
                deliveryPersonId: deliveryPersonId,
                latitude: latitude,
                longitude: longitude,
                accuracy: accuracy,
                speed: speed,
                address: address,
                additionalData: {
                  'operation': 'start_tracking',
                  'heading': heading,
                },
              );

              _logger.logUserAction(
                'location_tracking_started',
                userId: deliveryPersonId,
                data: {
                  'latitude': latitude,
                  'longitude': longitude,
                  'accuracy': accuracy,
                  'speed': speed,
                  'address': address,
                },
              );

              _logger.endPerformanceTimer('location_tracking_start',
                  details: 'Location tracking started successfully');
              return true;
            } catch (e) {
              _logger.error(
                'Failed to start location tracking',
                tag: 'LOCATION',
                error: e,
                additionalData: {
                  'delivery_person_id': deliveryPersonId,
                  'latitude': latitude,
                  'longitude': longitude,
                },
              );
              _logger.endPerformanceTimer('location_tracking_start',
                  details: 'Location tracking failed');
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

  // Update location for a delivery person
  Future<bool> updateLocation({
    required String deliveryPersonId,
    required double latitude,
    required double longitude,
    double? accuracy,
    double? speed,
    double? heading,
    String? address,
  }) async {
    return await _contextAware.executeWithContext(
          operation: 'updateLocation',
          service: 'LocationTrackingService',
          operationFunction: () async {
            try {
              final locationData = {
                'delivery_person_id': deliveryPersonId,
                'latitude': latitude,
                'longitude': longitude,
                'accuracy': accuracy,
                'speed': speed,
                'heading': heading,
                'address': address,
                'is_active': true,
                'timestamp': DateTime.now().toIso8601String(),
              };

              final response = await client
                  .from('delivery_locations')
                  .insert(locationData)
                  .select()
                  .single();

              final location = DeliveryLocation.fromJson(response);
              _recentLocations.add(location);

              // Keep only last 100 locations in memory
              if (_recentLocations.length > 100) {
                _recentLocations.removeAt(0);
              }

              // Log business metrics for location updates
              _logger.logLocationMetrics(
                deliveryPersonId: deliveryPersonId,
                latitude: latitude,
                longitude: longitude,
                accuracy: accuracy,
                speed: speed,
                address: address,
                additionalData: {
                  'operation': 'location_update',
                  'heading': heading,
                  'total_locations': _recentLocations.length,
                },
              );

              notifyListeners();
              return true;
            } catch (e) {
              _logger.error(
                'Failed to update location',
                tag: 'LOCATION',
                error: e,
                additionalData: {
                  'delivery_person_id': deliveryPersonId,
                  'latitude': latitude,
                  'longitude': longitude,
                },
              );
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

  // Stop location tracking
  Future<bool> stopLocationTracking(String deliveryPersonId) async {
    return await _contextAware.executeWithContext(
          operation: 'stopLocationTracking',
          service: 'LocationTrackingService',
          operationFunction: () async {
            try {
              // Mark all active locations as inactive
              await client
                  .from('delivery_locations')
                  .update({'is_active': false})
                  .eq('delivery_person_id', deliveryPersonId)
                  .eq('is_active', true);

              _isTracking = false;
              notifyListeners();

              // Log business metrics for tracking stop
              _logger.logUserAction(
                'location_tracking_stopped',
                userId: deliveryPersonId,
                data: {
                  'total_locations_tracked': _recentLocations.length,
                  'tracking_duration': _recentLocations.isNotEmpty
                      ? DateTime.now()
                          .difference(_recentLocations.first.timestamp)
                          .inMinutes
                      : 0,
                },
              );

              _logger.info(
                'Location tracking stopped',
                tag: 'LOCATION',
                additionalData: {
                  'delivery_person_id': deliveryPersonId,
                  'total_locations': _recentLocations.length,
                },
              );

              return true;
            } catch (e) {
              _logger.error(
                'Failed to stop location tracking',
                tag: 'LOCATION',
                error: e,
                additionalData: {
                  'delivery_person_id': deliveryPersonId,
                },
              );
              return false;
            }
          },
          metadata: {
            'delivery_person_id': deliveryPersonId,
          },
        ) ??
        false;
  }

  // Get recent locations for a delivery person
  Future<List<DeliveryLocation>?> getRecentLocations({
    required String deliveryPersonId,
    int limit = 50,
    DateTime? since,
  }) async {
    return _contextAware.executeWithContext(
      operation: 'getRecentLocations',
      service: 'LocationTrackingService',
      operationFunction: () async {
        try {
          var query = client
              .from('delivery_locations')
              .select()
              .eq('delivery_person_id', deliveryPersonId);

          if (since != null) {
            query = query.gte('timestamp', since.toIso8601String());
          }

          final finalQuery =
              query.order('timestamp', ascending: false).limit(limit);

          final response = await finalQuery;

          return response
              .map((json) => DeliveryLocation.fromJson(json))
              .toList();
        } catch (e) {
          debugPrint('Error fetching recent locations: $e');
          return [];
        }
      },
      metadata: {
        'delivery_person_id': deliveryPersonId,
        'limit': limit,
        'since': since?.toIso8601String(),
      },
    );
  }

  // Get current location for a delivery person
  Future<DeliveryLocation?> getCurrentLocation(String deliveryPersonId) async {
    return _contextAware.executeWithContext(
      operation: 'getCurrentLocation',
      service: 'LocationTrackingService',
      operationFunction: () async {
        try {
          final response = await client
              .from('delivery_locations')
              .select()
              .eq('delivery_person_id', deliveryPersonId)
              .eq('is_active', true)
              .order('timestamp', ascending: false)
              .limit(1)
              .single();

          return DeliveryLocation.fromJson(response);
        } catch (e) {
          debugPrint('Error fetching current location: $e');
          return null;
        }
      },
      metadata: {
        'delivery_person_id': deliveryPersonId,
      },
    );
  }

  // Get location history for a delivery person
  Future<List<DeliveryLocation>?> getLocationHistory({
    required String deliveryPersonId,
    required DateTime startDate,
    required DateTime endDate,
    int limit = 1000,
  }) async {
    return _contextAware.executeWithContext(
      operation: 'getLocationHistory',
      service: 'LocationTrackingService',
      operationFunction: () async {
        try {
          final response = await client
              .from('delivery_locations')
              .select()
              .eq('delivery_person_id', deliveryPersonId)
              .gte('timestamp', startDate.toIso8601String())
              .lte('timestamp', endDate.toIso8601String())
              .order('timestamp', ascending: true)
              .limit(limit);

          return response
              .map((json) => DeliveryLocation.fromJson(json))
              .toList();
        } catch (e) {
          debugPrint('Error fetching location history: $e');
          return [];
        }
      },
      metadata: {
        'delivery_person_id': deliveryPersonId,
        'start_date': startDate.toIso8601String(),
        'end_date': endDate.toIso8601String(),
        'limit': limit,
      },
    );
  }

  // Subscribe to real-time location updates
  void subscribeToLocationUpdates(String deliveryPersonId) {
    _locationChannel = client
        .channel('delivery_locations_$deliveryPersonId')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'delivery_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'delivery_person_id',
            value: deliveryPersonId,
          ),
          callback: (payload) {
            try {
              final location = DeliveryLocation.fromJson(payload.newRecord);
              _recentLocations.add(location);

              // Keep only last 100 locations in memory
              if (_recentLocations.length > 100) {
                _recentLocations.removeAt(0);
              }

              notifyListeners();
            } catch (e) {
              debugPrint('Error processing location update: $e');
            }
          },
        )
        .subscribe();
  }

  // Unsubscribe from real-time location updates
  void unsubscribeFromLocationUpdates() {
    _locationChannel?.unsubscribe();
    _locationChannel = null;
  }

  // Get locations within radius
  Future<List<DeliveryLocation>?> getLocationsWithinRadius({
    required double centerLatitude,
    required double centerLongitude,
    required double radiusKm,
    int limit = 100,
  }) async {
    return _contextAware.executeWithContext(
      operation: 'getLocationsWithinRadius',
      service: 'LocationTrackingService',
      operationFunction: () async {
        try {
          // Get all active locations
          final response = await client
              .from('delivery_locations')
              .select()
              .eq('is_active', true)
              .order('timestamp', ascending: false)
              .limit(limit * 2); // Get more to filter by radius

          final centerLocation = DeliveryLocation(
            id: 'center',
            deliveryPersonId: 'center',
            latitude: centerLatitude,
            longitude: centerLongitude,
            timestamp: DateTime.now(),
          );

          final locations = response
              .map((json) => DeliveryLocation.fromJson(json))
              .where((location) =>
                  location.isWithinRadius(centerLocation, radiusKm))
              .take(limit)
              .toList();

          return locations;
        } catch (e) {
          debugPrint('Error fetching locations within radius: $e');
          return [];
        }
      },
      metadata: {
        'center_latitude': centerLatitude,
        'center_longitude': centerLongitude,
        'radius_km': radiusKm,
        'limit': limit,
      },
    );
  }

  // Calculate total distance traveled
  Future<double> calculateTotalDistance({
    required String deliveryPersonId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    return await _contextAware.executeWithContext(
          operation: 'calculateTotalDistance',
          service: 'LocationTrackingService',
          operationFunction: () async {
            try {
              _logger.startPerformanceTimer('distance_calculation', metadata: {
                'delivery_person_id': deliveryPersonId,
                'start_date': startDate.toIso8601String(),
                'end_date': endDate.toIso8601String(),
              });

              final locations = await getLocationHistory(
                deliveryPersonId: deliveryPersonId,
                startDate: startDate,
                endDate: endDate,
                limit: 10000,
              );

              if (locations == null || locations.length < 2) {
                _logger.info(
                  'Insufficient location data for distance calculation',
                  tag: 'LOCATION',
                  additionalData: {
                    'delivery_person_id': deliveryPersonId,
                    'location_count': locations?.length ?? 0,
                  },
                );
                return 0.0;
              }

              double totalDistance = 0.0;
              for (int i = 1; i < locations.length; i++) {
                totalDistance += locations[i].distanceTo(locations[i - 1]);
              }

              // Log business metrics for distance calculation
              _logger.logLocationMetrics(
                deliveryPersonId: deliveryPersonId,
                latitude: locations.last.latitude,
                longitude: locations.last.longitude,
                additionalData: {
                  'operation': 'distance_calculation',
                  'total_distance_km': totalDistance,
                  'location_count': locations.length,
                  'start_date': startDate.toIso8601String(),
                  'end_date': endDate.toIso8601String(),
                  'average_distance_per_point': locations.length > 1
                      ? totalDistance / (locations.length - 1)
                      : 0,
                },
              );

              _logger.endPerformanceTimer('distance_calculation',
                  details: 'Distance calculated successfully');

              return totalDistance;
            } catch (e) {
              _logger.error(
                'Failed to calculate total distance',
                tag: 'LOCATION',
                error: e,
                additionalData: {
                  'delivery_person_id': deliveryPersonId,
                  'start_date': startDate.toIso8601String(),
                  'end_date': endDate.toIso8601String(),
                },
              );
              _logger.endPerformanceTimer('distance_calculation',
                  details: 'Distance calculation failed');
              return 0.0;
            }
          },
          metadata: {
            'delivery_person_id': deliveryPersonId,
            'start_date': startDate.toIso8601String(),
            'end_date': endDate.toIso8601String(),
          },
        ) ??
        0.0;
  }

  // Getters
  List<DeliveryLocation> get recentLocations =>
      List.unmodifiable(_recentLocations);
  bool get isTracking => _isTracking;

  // Get context summary for debugging
  Map<String, dynamic> getContextSummary() {
    return _contextAware.getContextSummary();
  }

  @override
  void dispose() {
    unsubscribeFromLocationUpdates();
    super.dispose();
  }
}
