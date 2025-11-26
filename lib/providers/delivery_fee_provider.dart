import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/restaurant.dart';
import '../providers/location_provider.dart';
import '../services/delivery_fee_service.dart';
import '../services/geolocation_service.dart';

/// Cached delivery fee with timestamp for TTL validation
class CachedDeliveryFee {
  final double fee;
  final DateTime timestamp;
  final String locationHash;

  static const _ttl = Duration(minutes: 30);

  CachedDeliveryFee({
    required this.fee,
    required this.timestamp,
    required this.locationHash,
  });

  /// Check if cached fee is still valid
  bool get isValid => DateTime.now().difference(timestamp) < _ttl;

  /// Check if cached fee matches current location
  bool isValidForLocation(String currentLocationHash) =>
      isValid && locationHash == currentLocationHash;
}

/// Shared delivery fee provider with intelligent caching and batch calculation
///
/// Features:
/// - Shared cache across all restaurant cards
/// - TTL-based cache invalidation (30 minutes)
/// - Location-aware caching (recalculates on location change)
/// - Batch calculation for multiple restaurants
/// - Error recovery with fallback to base fee
/// - Memory-efficient cache management
/// - App lifecycle awareness for background refresh
/// - Periodic stale data refresh
class DeliveryFeeProvider extends ChangeNotifier with WidgetsBindingObserver {
  // ==================== INITIALIZATION ====================

  /// Initialize provider with lifecycle observer
  void initialize() {
    WidgetsBinding.instance.addObserver(this);
    _startPeriodicRefresh();
    debugPrint('🚀 DeliveryFeeProvider: Initialized with lifecycle observer');
  }

  /// Set location provider for reactive location updates
  /// This enables automatic recalculation when location becomes available
  void setLocationProvider(LocationProvider locationProvider) {
    // Remove old listener if exists
    if (_locationProvider != null) {
      _locationProvider!.removeListener(_onLocationChanged);
    }

    _locationProvider = locationProvider;
    _locationProvider!.addListener(_onLocationChanged);
    debugPrint('📍 DeliveryFeeProvider: Location provider attached');
  }

  /// Handle location changes with debouncing
  void _onLocationChanged() {
    if (_locationProvider == null) return;

    final currentLocation = _locationProvider!.currentLocation;
    final isLoading = _locationProvider!.isLoading;
    final hasPermission = _locationProvider!.hasPermission;

    // Cancel previous debounce timer
    _locationDebounceTimer?.cancel();

    // If location is loading or no permission, don't do anything yet
    if (isLoading || !hasPermission) {
      debugPrint('📍 DeliveryFeeProvider: Location loading or no permission, skipping recalculation');
      return;
    }

    // Debounce location changes to avoid excessive recalculations
    _locationDebounceTimer = Timer(_locationDebounceDuration, () {
      _handleLocationChangeDebounced(currentLocation);
    });
  }

  /// Handle debounced location change
  void _handleLocationChangeDebounced(LocationData? newLocation) {
    if (newLocation == null) {
      debugPrint('📍 DeliveryFeeProvider: Location is null after debounce, skipping');
      return;
    }

    final newLocationHash = _generateLocationHash(
      newLocation.latitude,
      newLocation.longitude,
    );

    // Check if location changed significantly
    if (_currentLocationHash != null && _currentLocationHash != 'no_location') {
      final distanceChanged = _hasLocationChangedSignificantly(
        _currentLocationHash!,
        newLocationHash,
      );

      if (!distanceChanged) {
        debugPrint('📍 DeliveryFeeProvider: Location change too small, skipping recalculation');
        return;
      }
    }

    debugPrint('📍 DeliveryFeeProvider: Location changed significantly, invalidating cache');

    // Update location hash and invalidate cache
    _currentLocationHash = newLocationHash;
    _invalidateCacheForNewLocation(newLocationHash);

    // Notify that batch recalculation is needed (will be handled asynchronously)
    _scheduleAsyncBatchRecalculation(newLocation);
  }

  /// Check if location changed significantly (more than threshold)
  bool _hasLocationChangedSignificantly(String oldHash, String newHash) {
    if (oldHash == 'no_location' || newHash == 'no_location') {
      return true; // Always recalculate when location becomes available
    }

    try {
      // Parse hashes (format: "lat_lon")
      final oldParts = oldHash.split('_');
      final newParts = newHash.split('_');

      if (oldParts.length != 2 || newParts.length != 2) {
        return true; // If parsing fails, assume changed
      }

      final oldLat = double.parse(oldParts[0]);
      final oldLon = double.parse(oldParts[1]);
      final newLat = double.parse(newParts[0]);
      final newLon = double.parse(newParts[1]);

      // Calculate distance using Haversine formula (simplified)
      final distance = _calculateDistance(oldLat, oldLon, newLat, newLon);

      return distance > _minLocationChangeMeters;
    } catch (e) {
      debugPrint('⚠️ DeliveryFeeProvider: Error calculating location change: $e');
      return true; // If error, assume changed to be safe
    }
  }

  /// Calculate distance between two coordinates in meters (Haversine formula)
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371000; // meters
    final dLat = (lat2 - lat1) * (math.pi / 180.0);
    final dLon = (lon2 - lon1) * (math.pi / 180.0);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.asin(math.sqrt(a));
    return earthRadius * c;
  }

  /// Schedule async batch recalculation (non-blocking)
  void _scheduleAsyncBatchRecalculation(LocationData location) {
    // Schedule on next microtask to avoid blocking main thread
    Future.microtask(() async {
      // Small delay to ensure UI is responsive
      await Future.delayed(const Duration(milliseconds: 100));

      // Notify that recalculation is needed
      // The actual recalculation will be handled by the caller
      notifyListeners();

      debugPrint('🔄 DeliveryFeeProvider: Scheduled async batch recalculation');
    });
  }

  // ==================== CACHE & STATE ====================

  /// Shared cache for delivery fees across all cards
  final Map<String, CachedDeliveryFee> _cache = {};

  /// Currently calculating fees (prevents duplicate requests)
  final Set<String> _calculating = {};

  /// Pending calculation completers (allows multiple callers to wait for same calculation)
  final Map<String, Completer<double>> _pendingCalculations = {};

  /// Failed calculations (for error tracking)
  final Set<String> _failed = {};

  /// Service for delivery fee calculations
  final DeliveryFeeService _service = DeliveryFeeService();

  /// Current user location hash for cache invalidation
  String? _currentLocationHash;

  /// Timer for periodic cache refresh
  Timer? _refreshTimer;

  /// Last app resume timestamp
  DateTime? _lastResumeTime;

  /// Minimum time between background refreshes (prevents excessive refreshes)
  static const Duration _minRefreshInterval = Duration(minutes: 5);

  /// Max concurrent fee calculations to prevent memory spikes
  static const int _maxConcurrentCalculations = 5;

  /// Debounce timer for location changes
  Timer? _locationDebounceTimer;

  /// Location provider listener (for reactive updates)
  LocationProvider? _locationProvider;

  /// Minimum distance change to trigger recalculation (100 meters)
  static const double _minLocationChangeMeters = 100.0;

  /// Debounce duration for location changes
  static const Duration _locationDebounceDuration = Duration(milliseconds: 800);

  // ==================== GETTERS ====================

  /// Get cached fee for a restaurant (null if not cached or expired)
  double? getCachedFee(String restaurantId) {
    if (!_cache.containsKey(restaurantId)) {
      return null;
    }

    final cached = _cache[restaurantId]!;
    if (!cached.isValid) {
      _cache.remove(restaurantId);
      return null;
    }

    // Check location match
    if (_currentLocationHash != null &&
        !cached.isValidForLocation(_currentLocationHash!)) {
      _cache.remove(restaurantId);
      return null;
    }

    return cached.fee;
  }

  /// Check if a fee is currently being calculated
  bool isCalculating(String restaurantId) =>
      _calculating.contains(restaurantId);

  /// Check if a fee calculation failed
  bool hasFailed(String restaurantId) => _failed.contains(restaurantId);

  /// Check if location is available (not loading and has permission)
  bool get isLocationAvailable {
    if (_locationProvider == null) return false;
    return _locationProvider!.currentLocation != null &&
        !_locationProvider!.isLoading &&
        _locationProvider!.hasPermission;
  }

  /// Check if location is loading
  bool get isLocationLoading {
    if (_locationProvider == null) return false;
    return _locationProvider!.isLoading;
  }

  /// Get cache statistics for debugging
  Map<String, dynamic> getCacheStats() {
    final validCount = _cache.values.where((c) => c.isValid).length;
    final expiredCount = _cache.length - validCount;

    return {
      'totalCached': _cache.length,
      'validCached': validCount,
      'expiredCached': expiredCount,
      'calculating': _calculating.length,
      'failed': _failed.length,
      'currentLocationHash': _currentLocationHash,
    };
  }

  // ==================== SINGLE CALCULATION ====================

  /// Calculate delivery fee for a single restaurant
  ///
  /// Returns cached fee if available and valid, otherwise calculates new fee
  Future<double> getDeliveryFee({
    required String restaurantId,
    required double baseDeliveryFee,
    double? customerLatitude,
    double? customerLongitude,
  }) async {
    // Update location hash
    final locationHash =
        _generateLocationHash(customerLatitude, customerLongitude);
    if (locationHash != _currentLocationHash) {
      _currentLocationHash = locationHash;
      // Location changed - invalidate cache
      _invalidateCacheForNewLocation(locationHash);
    }

    // Check cache first
    final cached = getCachedFee(restaurantId);
    if (cached != null) {
      debugPrint('✅ DeliveryFeeProvider: Cache hit for $restaurantId: $cached');
      return cached;
    }

    // If no location, check if we're still loading
    if (customerLatitude == null || customerLongitude == null) {
      // If location is loading, throw exception to signal loading state
      if (isLocationLoading) {
        throw DeliveryFeeLoadingException('Location is being loaded');
      }
      // If no permission or location unavailable, return base fee
      debugPrint(
          '📍 DeliveryFeeProvider: No location for $restaurantId, using base fee: $baseDeliveryFee');
      return baseDeliveryFee;
    }

    // Check if already calculating - wait for the in-progress calculation instead of returning base fee
    if (_calculating.contains(restaurantId)) {
      debugPrint(
          '⏳ DeliveryFeeProvider: Already calculating for $restaurantId, waiting for result...');

      // If there's a pending completer, wait for it
      if (_pendingCalculations.containsKey(restaurantId)) {
        debugPrint(
            '⏳ DeliveryFeeProvider: Waiting for pending calculation for $restaurantId');
        try {
          final result = await _pendingCalculations[restaurantId]!.future;
          debugPrint(
              '✅ DeliveryFeeProvider: Received pending calculation result for $restaurantId: $result');
          return result;
        } catch (e) {
          debugPrint(
              '❌ DeliveryFeeProvider: Pending calculation failed for $restaurantId: $e, using base fee');
          return baseDeliveryFee;
        }
      }

      // Fallback: if no completer exists yet, return base fee and let caller retry
      // This should rarely happen but provides a safety net
      debugPrint(
          '⚠️ DeliveryFeeProvider: Calculation in progress but no completer found for $restaurantId, returning base fee');
      return baseDeliveryFee;
    }

    // Calculate new fee
    return _calculateSingleFee(
      restaurantId: restaurantId,
      baseDeliveryFee: baseDeliveryFee,
      customerLatitude: customerLatitude,
      customerLongitude: customerLongitude,
    );
  }

  /// Internal method to calculate single fee
  Future<double> _calculateSingleFee({
    required String restaurantId,
    required double baseDeliveryFee,
    required double customerLatitude,
    required double customerLongitude,
  }) async {
    // Create a completer for this calculation so other callers can wait for it
    final completer = Completer<double>();
    _pendingCalculations[restaurantId] = completer;
    _calculating.add(restaurantId);
    _failed.remove(restaurantId);
    notifyListeners();

    try {
      final calculatedFee = await _service.calculateDeliveryFee(
        restaurantId: restaurantId,
        customerLatitude: customerLatitude,
        customerLongitude: customerLongitude,
      );

      // Cache the result
      _cache[restaurantId] = CachedDeliveryFee(
        fee: calculatedFee,
        timestamp: DateTime.now(),
        locationHash: _currentLocationHash ?? '',
      );

      _calculating.remove(restaurantId);
      _pendingCalculations.remove(restaurantId);

      // Complete the completer so waiting callers get the result
      completer.complete(calculatedFee);
      notifyListeners();

      debugPrint(
          '✅ DeliveryFeeProvider: Calculated fee for $restaurantId: $calculatedFee');
      return calculatedFee;
    } catch (e) {
      debugPrint(
          '❌ DeliveryFeeProvider: Error calculating fee for $restaurantId: $e');

      _calculating.remove(restaurantId);
      _pendingCalculations.remove(restaurantId);
      _failed.add(restaurantId);

      // Complete the completer with base fee as fallback
      completer.complete(baseDeliveryFee);
      notifyListeners();

      // Return base fee as fallback
      return baseDeliveryFee;
    }
  }

  // ==================== BATCH CALCULATION ====================

  /// Precalculate delivery fees for multiple restaurants (batch operation)
  ///
  /// This is more efficient than calculating fees individually as it can:
  /// - Make a single API call for multiple restaurants
  /// - Reduce network overhead
  /// - Update UI once instead of per-restaurant
  Future<void> precalculateFees({
    required List<Restaurant> restaurants,
    double? customerLatitude,
    double? customerLongitude,
  }) async {
    if (restaurants.isEmpty) {
      return;
    }

    // Update location hash
    final locationHash =
        _generateLocationHash(customerLatitude, customerLongitude);
    if (locationHash != _currentLocationHash) {
      _currentLocationHash = locationHash;
      _invalidateCacheForNewLocation(locationHash);
    }

    // If no location, skip calculation
    if (customerLatitude == null || customerLongitude == null) {
      debugPrint(
          '📍 DeliveryFeeProvider: No location for batch calculation, skipping');
      return;
    }

    // Filter to only uncached/expired restaurants
    final restaurantsToCalculate = restaurants.where((restaurant) {
      final cached = getCachedFee(restaurant.id);
      return cached == null && !_calculating.contains(restaurant.id);
    }).toList();

    if (restaurantsToCalculate.isEmpty) {
      debugPrint(
          '✅ DeliveryFeeProvider: All ${restaurants.length} restaurants already cached');
      return;
    }

    debugPrint(
        '🔄 DeliveryFeeProvider: Batch calculating fees for ${restaurantsToCalculate.length}/${restaurants.length} restaurants');

    // RACE CONDITION FIX: Process in chunks to limit concurrent operations
    final results = <MapEntry<String, double>>[];

    // Split into chunks of maxConcurrentCalculations
    for (var i = 0;
        i < restaurantsToCalculate.length;
        i += _maxConcurrentCalculations) {
      final chunk = restaurantsToCalculate
          .skip(i)
          .take(_maxConcurrentCalculations)
          .toList();

      // Mark chunk as calculating and create completers for pending calculations
      for (final restaurant in chunk) {
        _calculating.add(restaurant.id);
        // Create completer so individual calls can wait for batch calculation
        if (!_pendingCalculations.containsKey(restaurant.id)) {
          _pendingCalculations[restaurant.id] = Completer<double>();
        }
      }
      notifyListeners();

      // Calculate fees for chunk (batched for efficiency)
      final chunkResults = await Future.wait(
        chunk.map((restaurant) async {
          try {
            final fee = await _service.calculateDeliveryFee(
              restaurantId: restaurant.id,
              customerLatitude: customerLatitude,
              customerLongitude: customerLongitude,
            );

            return MapEntry(restaurant.id, fee);
          } catch (e) {
            debugPrint(
                '❌ DeliveryFeeProvider: Error in batch for ${restaurant.id}: $e');
            _failed.add(restaurant.id);
            final baseFee = restaurant.deliveryFee;
            return MapEntry(restaurant.id, baseFee);
          }
        }),
      );

      // Cache chunk results, complete pending calculations, and remove from calculating
      for (final entry in chunkResults) {
        _cache[entry.key] = CachedDeliveryFee(
          fee: entry.value,
          timestamp: DateTime.now(),
          locationHash: locationHash,
        );
        _calculating.remove(entry.key);

        // Complete the completer so waiting callers get the result
        final completer = _pendingCalculations.remove(entry.key);
        if (completer != null && !completer.isCompleted) {
          completer.complete(entry.value);
        }
      }

      results.addAll(chunkResults);
      notifyListeners();
    }

    debugPrint(
        '✅ DeliveryFeeProvider: Batch calculation complete for ${results.length} restaurants');
    notifyListeners();
  }

  // ==================== CACHE MANAGEMENT ====================

  /// Clear all cached fees
  void clearCache() {
    _cache.clear();
    _calculating.clear();
    _pendingCalculations.clear();
    _failed.clear();
    _currentLocationHash = null;
    notifyListeners();
    debugPrint('🗑️ DeliveryFeeProvider: Cache cleared');
  }

  /// Clear cache for a specific restaurant
  void clearRestaurantCache(String restaurantId) {
    _cache.remove(restaurantId);
    _calculating.remove(restaurantId);
    _pendingCalculations.remove(restaurantId);
    _failed.remove(restaurantId);
    notifyListeners();
    debugPrint('🗑️ DeliveryFeeProvider: Cache cleared for $restaurantId');
  }

  /// Invalidate cache when location changes
  void _invalidateCacheForNewLocation(String newLocationHash) {
    final invalidated = _cache.keys
        .where((key) => !_cache[key]!.isValidForLocation(newLocationHash))
        .toList();

    invalidated.forEach(_cache.remove);

    if (invalidated.isNotEmpty) {
      debugPrint(
          '🔄 DeliveryFeeProvider: Location changed, invalidated ${invalidated.length} cached fees');
      notifyListeners();
    }
  }

  /// Remove expired entries from cache
  void cleanupExpiredCache() {
    final before = _cache.length;
    _cache.removeWhere((key, value) => !value.isValid);
    final removed = before - _cache.length;

    if (removed > 0) {
      debugPrint(
          '🧹 DeliveryFeeProvider: Cleaned up $removed expired cache entries');
      notifyListeners();
    }
  }

  /// Generate location hash for cache key
  String _generateLocationHash(double? latitude, double? longitude) {
    if (latitude == null || longitude == null) {
      return 'no_location';
    }

    // Round to 3 decimal places (~110m precision) for cache efficiency
    final lat = (latitude * 1000).round() / 1000;
    final lon = (longitude * 1000).round() / 1000;
    return '${lat}_$lon';
  }

  // ==================== MEMORY MANAGEMENT ====================

  /// Optimize cache memory usage by limiting size
  void optimizeMemory({int maxCacheSize = 500}) {
    // Increased from 200 to 500 for better scalability
    if (_cache.length <= maxCacheSize) {
      return;
    }

    // Remove oldest entries
    final sortedEntries = _cache.entries.toList()
      ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));

    final toRemove = sortedEntries.take(_cache.length - maxCacheSize);
    for (final entry in toRemove) {
      _cache.remove(entry.key);
    }

    debugPrint(
        '🧹 DeliveryFeeProvider: Optimized memory, removed ${toRemove.length} old entries');
    notifyListeners();
  }

  // ==================== APP LIFECYCLE MANAGEMENT ====================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        _onAppResumed();
        break;
      case AppLifecycleState.paused:
        _onAppPaused();
        break;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        // Do nothing for these states
        break;
    }
  }

  /// Handle app resume - refresh stale cache
  void _onAppResumed() {
    final now = DateTime.now();

    // Check if enough time has passed since last resume
    if (_lastResumeTime != null) {
      final timeSinceLastResume = now.difference(_lastResumeTime!);
      if (timeSinceLastResume < _minRefreshInterval) {
        debugPrint(
          '⏭️ DeliveryFeeProvider: Skipping refresh, too soon since last resume',
        );
        return;
      }
    }

    _lastResumeTime = now;

    debugPrint('🔄 DeliveryFeeProvider: App resumed, refreshing stale cache');

    // Clean up expired cache entries
    cleanupExpiredCache();

    // Restart periodic refresh timer
    _startPeriodicRefresh();
  }

  /// Handle app pause - stop periodic refresh
  void _onAppPaused() {
    debugPrint('⏸️ DeliveryFeeProvider: App paused, stopping periodic refresh');
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  /// Start periodic refresh timer for stale data
  void _startPeriodicRefresh() {
    // Cancel existing timer
    _refreshTimer?.cancel();

    // Create new timer that runs every 10 minutes
    _refreshTimer = Timer.periodic(
      const Duration(minutes: 10),
      (timer) {
        debugPrint('🔄 DeliveryFeeProvider: Periodic refresh triggered');
        cleanupExpiredCache();
      },
    );

    debugPrint('⏰ DeliveryFeeProvider: Periodic refresh timer started');
  }

  /// Stop periodic refresh timer
  void _stopPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    debugPrint('⏹️ DeliveryFeeProvider: Periodic refresh timer stopped');
  }

  // ==================== DISPOSE ====================

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopPeriodicRefresh();
    _locationDebounceTimer?.cancel();

    // Remove location provider listener
    if (_locationProvider != null) {
      _locationProvider!.removeListener(_onLocationChanged);
      _locationProvider = null;
    }

    _cache.clear();
    _calculating.clear();
    _pendingCalculations.clear();
    _failed.clear();
    debugPrint('🔌 DeliveryFeeProvider: Disposed');
    super.dispose();
  }
}

/// Exception thrown when delivery fee calculation is in progress (location loading)
class DeliveryFeeLoadingException implements Exception {
  final String message;
  DeliveryFeeLoadingException(this.message);

  @override
  String toString() => message;
}
