import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/retry_helper.dart';
import 'connectivity_service.dart';
import 'context_aware_service.dart';
import 'system_config_service.dart';

/// Service for calculating delivery fees based on distance and configuration
class DeliveryFeeService extends ChangeNotifier {
  static final DeliveryFeeService _instance = DeliveryFeeService._internal();
  factory DeliveryFeeService() => _instance;
  DeliveryFeeService._internal();

  SupabaseClient get client => Supabase.instance.client;
  final ContextAwareService _contextAware = ContextAwareService();
  final SystemConfigService _systemConfigService = SystemConfigService();
  final ConnectivityService _connectivityService = ConnectivityService();

  // Cache for calculated delivery fees
  final Map<String, double> _deliveryFeeCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);

  // Initialize the service
  Future<void> initialize() async {
    await _contextAware.initialize();
    debugPrint('🚀 DeliveryFeeService initialized');
  }

  /// PHASE 2: Batch calculate delivery fees for multiple restaurants
  /// This is significantly more efficient than calculating individually
  Future<Map<String, double>> calculateBatchDeliveryFees({
    required List<String> restaurantIds,
    required double customerLatitude,
    required double customerLongitude,
  }) async {
    final results = <String, double>{};

    if (restaurantIds.isEmpty) return results;

    try {
      // Check connectivity first
      if (!_connectivityService.isConnected) {
        debugPrint('⚠️ No network connection, returning default fees');
        return {for (final id in restaurantIds) id: 0.0};
      }

      debugPrint(
          '🚀 Batch calculating delivery fees for ${restaurantIds.length} restaurants');

      // Fetch all restaurant data in one query (much faster!)
      final restaurantsData = await client
          .from('restaurants')
          .select('id, latitude, longitude, delivery_fee')
          .inFilter('id', restaurantIds)
          .timeout(const Duration(seconds: 15));

      // Calculate fees for each restaurant
      for (final restaurantData in restaurantsData) {
        final restaurantId = restaurantData['id'] as String;
        final cacheKey =
            '${restaurantId}_${customerLatitude}_$customerLongitude';

        // Check cache first
        if (_deliveryFeeCache.containsKey(cacheKey)) {
          final cacheTime = _cacheTimestamps[cacheKey];
          if (cacheTime != null &&
              DateTime.now().difference(cacheTime) < _cacheExpiry) {
            results[restaurantId] = _deliveryFeeCache[cacheKey]!;
            continue;
          }
        }

        // Validate coordinates; fallback to base fee if missing
        final restLat = (restaurantData['latitude'] as num?)?.toDouble();
        final restLng = (restaurantData['longitude'] as num?)?.toDouble();
        final baseFee =
            (restaurantData['delivery_fee'] as num?)?.toDouble() ?? 0.0;

        double deliveryFee;

        if (restLat == null ||
            restLng == null ||
            (restLat == 0.0 && restLng == 0.0)) {
          deliveryFee = baseFee;
          debugPrint(
              'ℹ️ Missing restaurant coordinates for $restaurantId, using base fee: $baseFee');
        } else {
          // Validate customer coordinates
          if (customerLatitude.abs() > 90 || customerLongitude.abs() > 180) {
            debugPrint(
                '⚠️ Invalid customer coordinates: ($customerLatitude, $customerLongitude), using base fee: $baseFee');
            deliveryFee = baseFee;
          } else {
            // Calculate distance
            final distance = await _calculateDistance(
              restaurantLatitude: restLat,
              restaurantLongitude: restLng,
              customerLatitude: customerLatitude,
              customerLongitude: customerLongitude,
            );

            // Calculate fee from distance
            deliveryFee = _calculateFeeFromDistance(distance);
          }
        }

        // Cache the result
        _deliveryFeeCache[cacheKey] = deliveryFee;
        _cacheTimestamps[cacheKey] = DateTime.now();

        results[restaurantId] = deliveryFee;
      }

      debugPrint('✅ Batch calculated ${results.length} delivery fees');
      return results;
    } catch (e) {
      debugPrint('❌ Error in batch calculation: $e');
      // Try to fetch base fees from restaurants as fallback
      try {
        final restaurantsData = await client
            .from('restaurants')
            .select('id, delivery_fee')
            .inFilter('id', restaurantIds)
            .timeout(const Duration(seconds: 5));

        final fallbackFees = <String, double>{};
        for (final data in restaurantsData) {
          final id = data['id'] as String;
          final fee = (data['delivery_fee'] as num?)?.toDouble() ?? 0.0;
          fallbackFees[id] = fee;
        }

        // Fill in missing restaurants with 0.0
        for (final id in restaurantIds) {
          if (!fallbackFees.containsKey(id)) {
            fallbackFees[id] = 0.0;
          }
        }

        debugPrint('⚠️ Using base delivery fees as fallback: $fallbackFees');
        return fallbackFees;
      } catch (fallbackError) {
        debugPrint('❌ Error fetching fallback fees: $fallbackError');
        // Last resort: return 0.0 for all
        return {for (final id in restaurantIds) id: 0.0};
      }
    }
  }

  /// Calculate delivery fee based on distance and restaurant settings
  Future<double> calculateDeliveryFee({
    required String restaurantId,
    required double customerLatitude,
    required double customerLongitude,
    bool useCache = true,
  }) async {
    final cacheKey = '${restaurantId}_${customerLatitude}_$customerLongitude';

    // Check cache first
    if (useCache && _deliveryFeeCache.containsKey(cacheKey)) {
      final cacheTime = _cacheTimestamps[cacheKey];
      if (cacheTime != null &&
          DateTime.now().difference(cacheTime) < _cacheExpiry) {
        debugPrint(
            '📦 Using cached delivery fee: ${_deliveryFeeCache[cacheKey]}');
        return _deliveryFeeCache[cacheKey]!;
      }
    }

    final result = await _contextAware.executeWithContext(
      operation: 'calculateDeliveryFee',
      service: 'DeliveryFeeService',
      operationFunction: () async {
        try {
          // Get restaurant location and settings
          final restaurantData = await _getRestaurantData(restaurantId);
          if (restaurantData == null) {
            debugPrint('❌ Restaurant not found: $restaurantId');
            return 0.0;
          }

          // Validate coordinates; fallback to base fee if missing
          final restLat = (restaurantData['latitude'] as num?)?.toDouble();
          final restLng = (restaurantData['longitude'] as num?)?.toDouble();
          final baseFee =
              (restaurantData['delivery_fee'] as num?)?.toDouble() ?? 0.0;

          if (restLat == null ||
              restLng == null ||
              (restLat == 0.0 && restLng == 0.0)) {
            _deliveryFeeCache[cacheKey] = baseFee;
            _cacheTimestamps[cacheKey] = DateTime.now();
            debugPrint(
                'ℹ️ Missing restaurant coordinates for $restaurantId, using base fee: $baseFee');
            return baseFee;
          }

          // Validate customer coordinates
          if (customerLatitude.abs() > 90 || customerLongitude.abs() > 180) {
            debugPrint(
                '⚠️ Invalid customer coordinates: ($customerLatitude, $customerLongitude) for restaurant $restaurantId, using base fee: $baseFee');
            _deliveryFeeCache[cacheKey] = baseFee;
            _cacheTimestamps[cacheKey] = DateTime.now();
            return baseFee;
          }

          // Calculate distance
          final distance = await _calculateDistance(
            restaurantLatitude: restLat,
            restaurantLongitude: restLng,
            customerLatitude: customerLatitude,
            customerLongitude: customerLongitude,
          );

          // Log distance for debugging
          debugPrint(
              '📏 Calculated distance for $restaurantId: ${distance.toStringAsFixed(2)} km (rest: $restLat, $restLng | customer: $customerLatitude, $customerLongitude)');

          // Calculate fee based on distance and configuration
          final deliveryFee = _calculateFeeFromDistance(distance);

          // Cache the result
          _deliveryFeeCache[cacheKey] = deliveryFee;
          _cacheTimestamps[cacheKey] = DateTime.now();

          debugPrint(
              '💰 Calculated delivery fee: $deliveryFee DA for ${distance.toStringAsFixed(2)} km');
          return deliveryFee;
        } catch (e) {
          debugPrint('❌ Error calculating delivery fee: $e');
          return 0.0;
        }
      },
      metadata: {
        'restaurant_id': restaurantId,
        'customer_lat': customerLatitude,
        'customer_lng': customerLongitude,
      },
    );

    return result ?? 0.0;
  }

  /// Get restaurant data including location and delivery settings
  /// With retry mechanism and connectivity checks
  Future<Map<String, dynamic>?> _getRestaurantData(String restaurantId) async {
    // Check connectivity first
    if (!_connectivityService.isConnected) {
      debugPrint('⚠️ No network connection, skipping restaurant data fetch');
      return null;
    }

    // Execute with retry and exponential backoff
    final result = await RetryHelper.executeOrNull<Map<String, dynamic>>(
      action: () async {
        final response = await client
            .from('restaurants')
            .select('latitude, longitude, delivery_fee')
            .eq('id', restaurantId)
            .single()
            .timeout(const Duration(seconds: 10));

        return response;
      },
      config: RetryConfig.network,
      shouldRetry: (error) => RetryHelper.isNetworkError(error),
    );

    if (result == null) {
      debugPrint('❌ Failed to fetch restaurant data after retries');
    }

    return result;
  }

  /// Calculate distance between two points using Haversine formula
  Future<double> _calculateDistance({
    required double restaurantLatitude,
    required double restaurantLongitude,
    required double customerLatitude,
    required double customerLongitude,
  }) async {
    try {
      // Use Geolocator for accurate distance calculation
      final distance = Geolocator.distanceBetween(
        restaurantLatitude,
        restaurantLongitude,
        customerLatitude,
        customerLongitude,
      );

      // Convert from meters to kilometers
      return distance / 1000.0;
    } catch (e) {
      debugPrint('❌ Error calculating distance: $e');
      // Fallback to Haversine formula
      return _haversineDistance(
        restaurantLatitude,
        restaurantLongitude,
        customerLatitude,
        customerLongitude,
      );
    }
  }

  /// Haversine formula for distance calculation (fallback)
  double _haversineDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final dLat = _degreesToRadians(lat2 - lat1);
    final dLon = _degreesToRadians(lon2 - lon1);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  /// Calculate delivery fee based on distance using system configuration
  double _calculateFeeFromDistance(double distanceKm) {
    // Use SystemConfigService for distance-based fee calculation
    return _systemConfigService.calculateDeliveryFee(distanceKm);
  }

  /// Get delivery fee for a specific restaurant (without distance calculation)
  /// With retry mechanism and connectivity checks
  Future<double> getRestaurantDeliveryFee(String restaurantId) async {
    // Check connectivity first
    if (!_connectivityService.isConnected) {
      debugPrint('⚠️ No network connection, returning default fee');
      return 0.0;
    }

    final result = await RetryHelper.executeOrNull<double>(
      action: () async {
        final response = await client
            .from('restaurants')
            .select('delivery_fee')
            .eq('id', restaurantId)
            .single()
            .timeout(const Duration(seconds: 10));

        return (response['delivery_fee'] ?? 0.0).toDouble();
      },
      config: RetryConfig.network,
      shouldRetry: (error) => RetryHelper.isNetworkError(error),
    );

    return result ?? 0.0;
  }

  /// Check if delivery is available to the given location
  Future<bool> isDeliveryAvailable({
    required String restaurantId,
    required double customerLatitude,
    required double customerLongitude,
  }) async {
    try {
      final restaurantData = await _getRestaurantData(restaurantId);
      if (restaurantData == null) return false;

      final distance = await _calculateDistance(
        restaurantLatitude: restaurantData['latitude'] ?? 0.0,
        restaurantLongitude: restaurantData['longitude'] ?? 0.0,
        customerLatitude: customerLatitude,
        customerLongitude: customerLongitude,
      );

      // Use system-wide max delivery radius if table has no radius column
      final maxRadius = SystemConfigService().maxDeliveryRadius.toDouble();
      return distance <= maxRadius;
    } catch (e) {
      debugPrint('❌ Error checking delivery availability: $e');
      return false;
    }
  }

  /// Get estimated delivery time based on distance
  Future<int> getEstimatedDeliveryTime({
    required String restaurantId,
    required double customerLatitude,
    required double customerLongitude,
  }) async {
    try {
      final restaurantData = await _getRestaurantData(restaurantId);
      if (restaurantData == null) return 30; // Default 30 minutes

      final distance = await _calculateDistance(
        restaurantLatitude: restaurantData['latitude'] ?? 0.0,
        restaurantLongitude: restaurantData['longitude'] ?? 0.0,
        customerLatitude: customerLatitude,
        customerLongitude: customerLongitude,
      );

      // Base time + distance factor
      const baseTime = 20; // 20 minutes base
      final distanceTime = (distance * 2).round(); // 2 minutes per km
      final totalTime = baseTime + distanceTime;

      return totalTime.clamp(15, 120); // Between 15 and 120 minutes
    } catch (e) {
      debugPrint('❌ Error calculating delivery time: $e');
      return 30;
    }
  }

  /// Clear delivery fee cache
  void clearCache() {
    _deliveryFeeCache.clear();
    _cacheTimestamps.clear();
    debugPrint('🧹 Delivery fee cache cleared');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'cached_fees': _deliveryFeeCache.length,
      'cache_keys': _deliveryFeeCache.keys.toList(),
      'oldest_cache': _cacheTimestamps.values.isNotEmpty
          ? _cacheTimestamps.values.reduce((a, b) => a.isBefore(b) ? a : b)
          : null,
    };
  }

  /// Update delivery fee configuration
  Future<void> updateDeliveryFeeConfig({
    required List<Map<String, dynamic>> ranges,
    required double extraRangeFee,
  }) async {
    try {
      await _systemConfigService.updateDeliveryFeeRanges(
        ranges
            .map((r) => DeliveryFeeRange(
                  maxDistance: r['maxDistance']?.toDouble() ?? 0.0,
                  fee: r['fee']?.toDouble() ?? 0.0,
                ))
            .toList(),
      );

      await _systemConfigService.updateExtraRangeFee(extraRangeFee);

      // Clear cache when configuration changes
      clearCache();

      debugPrint('✅ Delivery fee configuration updated');
    } catch (e) {
      debugPrint('❌ Error updating delivery fee configuration: $e');
    }
  }
}
