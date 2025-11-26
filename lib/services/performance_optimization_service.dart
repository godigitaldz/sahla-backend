import 'dart:async';
import 'dart:collection';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/restaurant.dart';
import 'info_service.dart';
import 'logging_service.dart';
// Redis integrations removed

/// Advanced performance optimization service for restaurant operations
class PerformanceOptimizationService extends ChangeNotifier {
  static final PerformanceOptimizationService _instance =
      PerformanceOptimizationService._internal();
  factory PerformanceOptimizationService() => _instance;
  PerformanceOptimizationService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;
  final LoggingService _logger = LoggingService();
  // No Redis Cloud

  // ========================================
  // ADVANCED CACHING SYSTEM
  // ========================================

  // Multi-level cache system
  final Map<String, dynamic> _l1Cache = {}; // Memory cache (fastest)
  final Map<String, DateTime> _l1Timestamps = {};
  final Map<String, int> _l1AccessCount = {};
  final Map<String, double> _l1Priority = {};

  // Cache configuration
  static const Duration _l1CacheDuration = Duration(minutes: 2);
  static const int _maxL1CacheSize = 1000;

  // Connection pooling
  final Queue<Completer<void>> _connectionPool = Queue<Completer<void>>();
  static const int _maxConnections = 10;
  int _activeConnections = 0;

  // Request batching
  final Map<String, List<Completer<dynamic>>> _pendingRequests = {};
  Timer? _batchTimer;
  static const Duration _batchDelay = Duration(milliseconds: 50);

  // Performance metrics
  final Map<String, List<Duration>> _operationTimings = {};
  final Map<String, int> _operationCounts = {};
  final Map<String, int> _cacheHits = {};
  final Map<String, int> _cacheMisses = {};

  // ========================================
  // INITIALIZATION
  // ========================================

  Future<void> initialize() async {
    // Redis disabled

    await _warmupCache();
    _startBatchProcessor();
    _startCacheCleanup();
    _logger.info('PerformanceOptimizationService initialized (Supabase direct)',
        tag: 'PERF');
  }

  // ========================================
  // ADVANCED CACHING METHODS
  // ========================================

  /// Get data with intelligent caching
  Future<T?> getCachedData<T>({
    required String key,
    required Future<T> Function() fetcher,
    Duration? customDuration,
    double priority = 1.0,
  }) async {
    final operationKey = 'getCachedData_$key';
    final stopwatch = Stopwatch()..start();

    try {
      // Check L1 cache first
      if (_isL1CacheValid(key)) {
        _recordCacheHit('L1', operationKey);
        _l1AccessCount[key] = (_l1AccessCount[key] ?? 0) + 1;
        _logger.debug('L1 cache hit for $key', tag: 'PERF');
        return _l1Cache[key] as T?;
      }

      _cacheMisses[operationKey] = (_cacheMisses[operationKey] ?? 0) + 1;

      // Redis Cloud removed - L1/L2 cache only now

      // Fetch data
      final data = await fetcher();

      // Store in L1 cache with priority
      _storeInL1Cache(key, data, customDuration, priority);

      // Redis Cloud cache removed - using L1/L2 only
      try {
        // Write-through caching removed
        _logger.debug('Data stored in local cache',
            tag: 'PERF', additionalData: {'key': key});
      } catch (e) {
        _logger.warning('Local cache store failed', tag: 'PERF', error: e);
      }

      stopwatch.stop();
      _recordOperationTiming(operationKey, stopwatch.elapsed);

      return data;
    } catch (e) {
      stopwatch.stop();
      _recordOperationTiming(operationKey, stopwatch.elapsed);
      _logger.error('Error in getCachedData', tag: 'PERF', error: e);
      return null;
    }
  }

  /// Store data in L1 cache with intelligent eviction
  void _storeInL1Cache(
      String key, dynamic data, Duration? customDuration, double priority) {
    // Evict if cache is full
    if (_l1Cache.length >= _maxL1CacheSize) {
      _evictLeastImportant();
    }

    _l1Cache[key] = data;
    _l1Timestamps[key] = DateTime.now();
    _l1AccessCount[key] = 1;
    _l1Priority[key] = priority;
  }

  /// Intelligent cache eviction based on access patterns
  void _evictLeastImportant() {
    if (_l1Cache.isEmpty) return;

    String? keyToEvict;
    double lowestScore = double.infinity;

    for (final key in _l1Cache.keys) {
      final accessCount = _l1AccessCount[key] ?? 0;
      final priority = _l1Priority[key] ?? 1.0;
      final age = DateTime.now()
          .difference(_l1Timestamps[key] ?? DateTime.now())
          .inMinutes;

      // Score based on access count, priority, and age
      final score = (accessCount * priority) / (age + 1);

      if (score < lowestScore) {
        lowestScore = score;
        keyToEvict = key;
      }
    }

    if (keyToEvict != null) {
      _l1Cache.remove(keyToEvict);
      _l1Timestamps.remove(keyToEvict);
      _l1AccessCount.remove(keyToEvict);
      _l1Priority.remove(keyToEvict);
    }
  }

  /// Check if L1 cache is valid
  bool _isL1CacheValid(String key) {
    if (!_l1Cache.containsKey(key)) return false;

    final timestamp = _l1Timestamps[key];
    if (timestamp == null) return false;

    return DateTime.now().difference(timestamp) < _l1CacheDuration;
  }

  // ========================================
  // CONNECTION POOLING
  // ========================================

  /// Get connection from pool
  Future<void> _getConnection() async {
    if (_activeConnections < _maxConnections) {
      _activeConnections++;
      return;
    }

    final completer = Completer<void>();
    _connectionPool.add(completer);
    return completer.future;
  }

  /// Release connection back to pool
  void _releaseConnection() {
    if (_connectionPool.isNotEmpty) {
      final completer = _connectionPool.removeFirst();
      completer.complete();
    } else {
      _activeConnections--;
    }
  }

  // ========================================
  // REQUEST BATCHING
  // ========================================

  /// Batch multiple requests together
  Future<T> batchRequest<T>(
      String batchKey, Future<T> Function() request) async {
    final completer = Completer<T>();

    if (!_pendingRequests.containsKey(batchKey)) {
      _pendingRequests[batchKey] = [];
    }

    _pendingRequests[batchKey]!.add(completer);

    return completer.future;
  }

  /// Process batched requests
  void _startBatchProcessor() {
    _batchTimer = Timer.periodic(_batchDelay, (_) {
      _processBatches();
    });
  }

  /// Process all pending batches
  Future<void> _processBatches() async {
    for (final batchKey in _pendingRequests.keys.toList()) {
      final requests = _pendingRequests.remove(batchKey);
      if (requests != null && requests.isNotEmpty) {
        await _processBatch(batchKey, requests);
      }
    }
  }

  /// Process a single batch
  Future<void> _processBatch(
      String batchKey, List<Completer<dynamic>> requests) async {
    try {
      // Execute batch operation based on key
      switch (batchKey) {
        case 'restaurant_info':
          await _processRestaurantInfoBatch(requests);
          break;
        case 'menu_items':
          await _processMenuItemsBatch(requests);
          break;
        default:
          // Complete individual requests
          for (final request in requests) {
            request.complete(null);
          }
      }
    } catch (e) {
      _logger.error('Error processing batch $batchKey', tag: 'PERF', error: e);
      for (final request in requests) {
        request.completeError(e);
      }
    }
  }

  /// Process restaurant info batch
  Future<void> _processRestaurantInfoBatch(
      List<Completer<dynamic>> requests) async {
    // Extract restaurant IDs from requests
    final restaurantIds = <String>[];
    for (final _ in requests) {
      // This would need to be implemented based on your request structure
      // Currently not extracting IDs from requests
    }

    if (restaurantIds.isNotEmpty) {
      // Batch fetch restaurant info
      final infoResults = await _batchFetchRestaurantInfo(restaurantIds);

      // Complete requests with results
      for (int i = 0; i < requests.length; i++) {
        if (i < infoResults.length) {
          requests[i].complete(infoResults[i]);
        } else {
          requests[i].complete(null);
        }
      }
    }
  }

  /// Process menu items batch
  Future<void> _processMenuItemsBatch(List<Completer<dynamic>> requests) async {
    // Similar implementation for menu items
    for (final request in requests) {
      request.complete(null);
    }
  }

  // ========================================
  // OPTIMIZED RESTAURANT OPERATIONS
  // ========================================

  /// Get restaurants with advanced optimization
  Future<List<Restaurant>> getOptimizedRestaurants({
    String? category,
    String? cuisine,
    bool? isOpen,
    bool? isFeatured,
    String? location,
    double? minRating,
    int offset = 0,
    int limit = 20,
  }) async {
    final cacheKey =
        'restaurants_${category ?? 'all'}_${cuisine ?? 'all'}_${isOpen ?? 'all'}_${isFeatured ?? 'all'}_${location ?? 'all'}_${minRating ?? 'all'}_${offset}_$limit';

    return await getCachedData<List<Restaurant>>(
          key: cacheKey,
          priority: 2.0, // High priority for restaurant data
          fetcher: () async {
            await _getConnection();
            try {
              // Optimized database query
              return await _getRestaurantsFromDatabase(
                category: category,
                cuisine: cuisine,
                isOpen: isOpen,
                isFeatured: isFeatured,
                location: location,
                minRating: minRating,
                offset: offset,
                limit: limit,
              );
            } finally {
              _releaseConnection();
            }
          },
        ) ??
        [];
  }

  /// Optimized database query with parallel processing
  Future<List<Restaurant>> _getRestaurantsFromDatabase({
    String? category,
    String? cuisine,
    bool? isOpen,
    bool? isFeatured,
    String? location,
    double? minRating,
    int offset = 0,
    int limit = 20,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      // Build optimized query
      final query = _supabase
          .from('restaurants')
          .select('*')
          .range(offset, offset + limit - 1);

      // Apply database-level filters where possible
      // Note: Filters temporarily disabled due to API compatibility
      // if (isOpen != null) {
      //   query = query.filter('is_open', 'eq', isOpen);
      // }
      // if (isFeatured != null) {
      //   query = query.filter('is_featured', 'eq', isFeatured);
      // }
      // if (minRating != null) {
      //   query = query.filter('rating', 'gte', minRating);
      // }

      final response = await query.order('rating', ascending: false);

      // Parallel processing for restaurant data
      final restaurants = await _processRestaurantsInParallel(response as List);

      // Apply remaining filters
      final filtered =
          _applyFilters(restaurants, isOpen, isFeatured, location, minRating);

      stopwatch.stop();
      _recordOperationTiming('getRestaurantsFromDatabase', stopwatch.elapsed);

      return filtered;
    } catch (e) {
      stopwatch.stop();
      _recordOperationTiming('getRestaurantsFromDatabase', stopwatch.elapsed);
      _logger.error('Error in _getRestaurantsFromDatabase',
          tag: 'PERF', error: e);
      return [];
    }
  }

  /// Process restaurants in parallel for maximum performance
  Future<List<Restaurant>> _processRestaurantsInParallel(
      List<dynamic> response) async {
    final restaurants = <Restaurant>[];
    final restaurantMaps = <Map<String, dynamic>>[];
    final restaurantIds = <String>[];

    // First pass: collect data
    for (final item in response) {
      final map = Map<String, dynamic>.from(item);
      final id = map['id']?.toString();
      if (id != null) {
        restaurantMaps.add(map);
        restaurantIds.add(id);
      } else {
        restaurants.add(Restaurant.fromJson(map));
      }
    }

    if (restaurantIds.isNotEmpty) {
      // Parallel info fetching
      final infoResults = await _batchFetchRestaurantInfo(restaurantIds);

      // Parallel menu price fetching
      final menuPrices = await _batchFetchMenuPrices(restaurantIds);

      // Process results in parallel
      final futures = <Future<Restaurant>>[];
      for (int i = 0; i < restaurantMaps.length; i++) {
        futures.add(_processRestaurantMap(
            restaurantMaps[i], infoResults[i], menuPrices));
      }

      final processedRestaurants = await Future.wait(futures);
      restaurants.addAll(processedRestaurants);
    }

    return restaurants;
  }

  /// Process individual restaurant map
  Future<Restaurant> _processRestaurantMap(
    Map<String, dynamic> map,
    Map<String, dynamic> info,
    Map<String, double> menuPrices,
  ) async {
    final merged = InfoService().overlayStrings(
      target: map,
      info: info,
      keys: ['name', 'city', 'logo_url', 'wilaya', 'description'],
    );

    // Apply numeric overlays
    final minOrderInfo = info['minimum_order'];
    if (minOrderInfo != null) {
      if (minOrderInfo is num) {
        merged['minimum_order'] = minOrderInfo.toDouble();
      } else if (minOrderInfo is String) {
        final parsed = double.tryParse(minOrderInfo);
        if (parsed != null) merged['minimum_order'] = parsed;
      }
    }

    // Fallback to menu price
    final rid = map['id']?.toString();
    final currentMinOrder = merged['minimum_order'];
    if (rid != null &&
        (currentMinOrder == null ||
            (currentMinOrder is num && currentMinOrder.toDouble() <= 0))) {
      final alt = menuPrices[rid];
      if (alt != null && alt > 0) {
        merged['minimum_order'] = alt;
      }
    }

    return Restaurant.fromJson(merged);
  }

  /// Batch fetch restaurant info
  Future<List<Map<String, dynamic>>> _batchFetchRestaurantInfo(
      List<String> restaurantIds) async {
    final futures = <Future<Map<String, dynamic>>>[];

    for (final id in restaurantIds) {
      futures.add(InfoService()
          .getEntity(
        namespace: 'lo9ma',
        entity: 'restaurant',
        entityId: id,
      )
          .catchError((e) {
        _logger.warning('Failed to load info for restaurant $id', tag: 'PERF');
        return <String, dynamic>{};
      }));
    }

    return Future.wait(futures);
  }

  /// Batch fetch menu prices
  Future<Map<String, double>> _batchFetchMenuPrices(
      List<String> restaurantIds) async {
    try {
      final menuRows = await _supabase
          .from('menu_items')
          .select('restaurant_id, price')
          .inFilter('restaurant_id', restaurantIds)
          .eq('is_available', 'true');

      final minMenuPriceByRestaurant = <String, double>{};
      for (final row in (menuRows as List)) {
        final rid = (row['restaurant_id'] ?? '').toString();
        final price = (row['price'] is num)
            ? (row['price'] as num).toDouble()
            : (row['price'] is String)
                ? (double.tryParse(row['price']) ?? 0.0)
                : 0.0;

        if (rid.isEmpty) continue;

        if (!minMenuPriceByRestaurant.containsKey(rid)) {
          minMenuPriceByRestaurant[rid] = price;
        } else {
          final current = minMenuPriceByRestaurant[rid]!;
          if (price > 0 && (current == 0 || price < current)) {
            minMenuPriceByRestaurant[rid] = price;
          }
        }
      }

      return minMenuPriceByRestaurant;
    } catch (e) {
      _logger.warning('Failed to prefetch min menu prices', tag: 'PERF');
      return {};
    }
  }

  /// Apply filters to restaurants
  List<Restaurant> _applyFilters(
    List<Restaurant> restaurants,
    bool? isOpen,
    bool? isFeatured,
    String? location,
    double? minRating,
  ) {
    List<Restaurant> filtered = List<Restaurant>.from(restaurants);

    if (isOpen != null) {
      filtered = filtered.where((r) => r.isOpen == isOpen).toList();
    }
    if (isFeatured != null) {
      filtered = filtered.where((r) => r.isFeatured == isFeatured).toList();
    }
    if (location != null) {
      filtered = filtered
          .where((r) =>
              r.city.toLowerCase().contains(location.toLowerCase()) ||
              r.state.toLowerCase().contains(location.toLowerCase()))
          .toList();
    }
    if (minRating != null) {
      filtered = filtered.where((r) => r.rating >= minRating).toList();
    }

    return filtered;
  }

  // ========================================
  // CACHE MANAGEMENT
  // ========================================

  /// Warm up cache with frequently accessed data
  Future<void> _warmupCache() async {
    try {
      _logger.info('Starting cache warmup', tag: 'PERF');

      // Warm up popular restaurants
      await getOptimizedRestaurants(limit: 50);

      // Warm up featured restaurants
      await getOptimizedRestaurants(isFeatured: true, limit: 20);

      _logger.info('Cache warmup completed', tag: 'PERF');
    } catch (e) {
      _logger.error('Cache warmup failed', tag: 'PERF', error: e);
    }
  }

  /// Start cache cleanup timer
  void _startCacheCleanup() {
    Timer.periodic(const Duration(minutes: 5), (_) {
      _cleanupCache();
    });
  }

  /// Clean up expired cache entries
  void _cleanupCache() {
    final now = DateTime.now();
    final keysToRemove = <String>[];

    for (final key in _l1Cache.keys) {
      final timestamp = _l1Timestamps[key];
      if (timestamp != null && now.difference(timestamp) > _l1CacheDuration) {
        keysToRemove.add(key);
      }
    }

    for (final key in keysToRemove) {
      _l1Cache.remove(key);
      _l1Timestamps.remove(key);
      _l1AccessCount.remove(key);
      _l1Priority.remove(key);
    }

    if (keysToRemove.isNotEmpty) {
      _logger.debug('Cleaned up ${keysToRemove.length} expired cache entries',
          tag: 'PERF');
    }
  }

  // ========================================
  // PERFORMANCE MONITORING
  // ========================================

  /// Record operation timing
  void _recordOperationTiming(String operation, Duration duration) {
    if (!_operationTimings.containsKey(operation)) {
      _operationTimings[operation] = [];
    }

    _operationTimings[operation]!.add(duration);
    _operationCounts[operation] = (_operationCounts[operation] ?? 0) + 1;

    // Keep only last 100 timings per operation
    if (_operationTimings[operation]!.length > 100) {
      _operationTimings[operation]!.removeAt(0);
    }
  }

  /// Get performance metrics
  Map<String, dynamic> getPerformanceMetrics() {
    final metrics = <String, dynamic>{};

    // Cache metrics
    metrics['l1_cache_size'] = _l1Cache.length;
    metrics['l1_cache_hit_rate'] = _calculateHitRate();

    // Operation metrics
    for (final operation in _operationTimings.keys) {
      final timings = _operationTimings[operation]!;
      final count = _operationCounts[operation] ?? 0;

      if (timings.isNotEmpty) {
        final avgDuration = Duration(
            milliseconds: timings.reduce((a, b) => a + b).inMilliseconds ~/
                timings.length);
        final minDuration = timings.reduce((a, b) => a < b ? a : b);
        final maxDuration = timings.reduce((a, b) => a > b ? a : b);

        metrics['${operation}_avg_duration_ms'] = avgDuration.inMilliseconds;
        metrics['${operation}_min_duration_ms'] = minDuration.inMilliseconds;
        metrics['${operation}_max_duration_ms'] = maxDuration.inMilliseconds;
        metrics['${operation}_count'] = count;
      }
    }

    // Connection pool metrics
    metrics['active_connections'] = _activeConnections;
    metrics['pending_connections'] = _connectionPool.length;

    return metrics;
  }

  /// Record cache hit by type
  void _recordCacheHit(String cacheType, String operationKey) {
    final hitKey = '${cacheType}_hits';
    _cacheHits[hitKey] = (_cacheHits[hitKey] ?? 0) + 1;
    _cacheHits[operationKey] = (_cacheHits[operationKey] ?? 0) + 1;
  }

  /// Calculate cache hit rate
  double _calculateHitRate() {
    final totalHits = _cacheHits.values.fold(0, (a, b) => a + b);
    final totalMisses = _cacheMisses.values.fold(0, (a, b) => a + b);
    final total = totalHits + totalMisses;

    return total > 0 ? totalHits / total : 0.0;
  }

  /// Clear all caches
  void clearAllCaches() {
    _l1Cache.clear();
    _l1Timestamps.clear();
    _l1AccessCount.clear();
    _l1Priority.clear();
    _operationTimings.clear();
    _operationCounts.clear();
    _cacheHits.clear();
    _cacheMisses.clear();

    _logger.info('All caches cleared', tag: 'PERF');
    notifyListeners();
  }

  /// Dispose resources
  @override
  void dispose() {
    _batchTimer?.cancel();
    super.dispose();
  }
}
