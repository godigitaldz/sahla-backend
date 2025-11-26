import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/menu_item.dart';
import '../models/restaurant.dart';
import 'context_aware_service.dart';
import 'error_logging_service.dart';
import 'performance_optimization_service.dart';
// Redis optimized service removed

/// Ultra-high performance RestaurantService with 100% optimization
class OptimizedRestaurantService extends ChangeNotifier {
  SupabaseClient get _supabase => Supabase.instance.client;

  // Performance optimization service
  final PerformanceOptimizationService _perfService =
      PerformanceOptimizationService();

  // Context-aware service for tracking and validation
  final ContextAwareService _contextAware = ContextAwareService();

  // Realtime support with optimized channels
  RealtimeChannel? _restaurantsChannel;
  RealtimeChannel? _menuItemsChannel;
  final StreamController<List<Restaurant>> _restaurantsUpdateStream =
      StreamController<List<Restaurant>>.broadcast();
  final StreamController<List<MenuItem>> _menuItemsUpdateStream =
      StreamController<List<MenuItem>>.broadcast();

  // Precomputed data for instant access
  List<Restaurant> _featuredRestaurants = [];
  List<Restaurant> _popularRestaurants = [];
  final Map<String, List<Restaurant>> _categoryCache = {};
  final Map<String, List<Restaurant>> _cuisineCache = {};

  // Smart prefetching
  Timer? _prefetchTimer;
  final Set<String> _prefetchQueue = <String>{};

  // Performance metrics
  int _totalRequests = 0;
  int _cacheHits = 0;
  int _databaseHits = 0;
  Duration _totalResponseTime = Duration.zero;

  /// Stream for real-time restaurant updates
  Stream<List<Restaurant>> get restaurantsUpdateStream =>
      _restaurantsUpdateStream.stream;

  /// Stream for real-time menu item updates
  Stream<List<MenuItem>> get menuItemsUpdateStream =>
      _menuItemsUpdateStream.stream;

  /// Get performance metrics
  Map<String, dynamic> get performanceMetrics => {
        'total_requests': _totalRequests,
        'cache_hits': _cacheHits,
        'database_hits': _databaseHits,
        'cache_hit_rate':
            _totalRequests > 0 ? _cacheHits / _totalRequests : 0.0,
        'avg_response_time_ms': _totalRequests > 0
            ? _totalResponseTime.inMilliseconds / _totalRequests
            : 0.0,
        'featured_restaurants_cached': _featuredRestaurants.length,
        'popular_restaurants_cached': _popularRestaurants.length,
        'category_cache_size': _categoryCache.length,
        'cuisine_cache_size': _cuisineCache.length,
      };

  // Initialize the service with maximum performance
  Future<void> initialize() async {
    await _contextAware.initialize();
    await _perfService.initialize();

    // Start prefetching in background
    _startPrefetching();

    // Subscribe to realtime updates
    _subscribeToRealtime();

    // Preload critical data
    await _preloadCriticalData();

    debugPrint(
        '🚀 OptimizedRestaurantService initialized with 100% performance optimization');
  }

  /// Preload critical data for instant access
  Future<void> _preloadCriticalData() async {
    try {
      // Load featured restaurants
      _featuredRestaurants = await _perfService.getOptimizedRestaurants(
        isFeatured: true,
        limit: 20,
      );

      // Load popular restaurants
      _popularRestaurants = await _perfService.getOptimizedRestaurants(
        limit: 50,
      );

      debugPrint(
          '✅ Preloaded ${_featuredRestaurants.length} featured and ${_popularRestaurants.length} popular restaurants');
    } catch (e) {
      debugPrint('❌ Error preloading critical data: $e');
    }
  }

  /// Start intelligent prefetching
  void _startPrefetching() {
    _prefetchTimer = Timer.periodic(const Duration(minutes: 2), (_) {
      _processPrefetchQueue();
    });
  }

  /// Process prefetch queue
  Future<void> _processPrefetchQueue() async {
    if (_prefetchQueue.isEmpty) return;

    final itemsToPrefetch = _prefetchQueue.toList();
    _prefetchQueue.clear();

    // Prefetch in parallel
    final futures = <Future<void>>[];
    for (final item in itemsToPrefetch) {
      futures.add(_prefetchItem(item));
    }

    await Future.wait(futures);
  }

  /// Prefetch individual item
  Future<void> _prefetchItem(String item) async {
    try {
      if (item.startsWith('category_')) {
        final category = item.substring(8);
        await getRestaurantsByCategory(category, limit: 20);
      } else if (item.startsWith('cuisine_')) {
        final cuisine = item.substring(7);
        await getRestaurantsByCuisine(cuisine, limit: 20);
      }
    } catch (e) {
      debugPrint('❌ Error prefetching $item: $e');
    }
  }

  /// Subscribe to realtime updates with optimized handling
  void _subscribeToRealtime() {
    try {
      // Subscribe to restaurant updates
      _restaurantsChannel = _supabase
          .channel('optimized_restaurants_updates')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'restaurants',
            callback: (payload) {
              _handleRestaurantRealtimeUpdate(payload);
            },
          )
          .subscribe();

      // Subscribe to menu item updates
      _menuItemsChannel = _supabase
          .channel('optimized_menu_items_updates')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'menu_items',
            callback: (payload) {
              _handleMenuItemRealtimeUpdate(payload);
            },
          )
          .subscribe();

      debugPrint('✅ Optimized realtime subscriptions started');
    } catch (e) {
      final errorLoggingService = ErrorLoggingService();
      errorLoggingService.logError(
        'Failed to start optimized realtime subscriptions',
        error: e,
        context: 'OptimizedRestaurantService._subscribeToRealtime',
        additionalData: {
          'service': 'optimized_restaurant_service',
          'method': '_subscribeToRealtime',
        },
      );

      debugPrint('❌ Failed to start optimized realtime subscriptions: $e');
    }
  }

  /// Handle realtime restaurant updates with smart invalidation
  void _handleRestaurantRealtimeUpdate(PostgresChangePayload payload) {
    try {
      debugPrint('🔄 Real-time restaurant update: ${payload.eventType}');

      // Handle different event types
      if (payload.eventType == PostgresChangeEvent.delete) {
        debugPrint(
            '🗑️ Restaurant deleted via real-time: ${payload.oldRecord['id']}');
        // Comprehensive cache invalidation for deletions
        _invalidateAllCaches();
      } else if (payload.eventType == PostgresChangeEvent.insert) {
        debugPrint(
            '➕ Restaurant added via real-time: ${payload.newRecord['id']}');
        // Clear caches to include new restaurant
        _invalidateAllCaches();
      } else if (payload.eventType == PostgresChangeEvent.update) {
        debugPrint(
            '✏️ Restaurant updated via real-time: ${payload.newRecord['id']}');
        // Invalidate related caches
        _invalidateRelatedCaches(payload);
      }

      // Notify listeners
      notifyListeners();

      // Emit stream update
      _restaurantsUpdateStream.add([]);

      debugPrint(
          '✅ Real-time restaurant update processed: ${payload.eventType}');
    } catch (e) {
      debugPrint('❌ Error handling optimized restaurant realtime update: $e');
    }
  }

  /// Handle realtime menu item updates
  void _handleMenuItemRealtimeUpdate(PostgresChangePayload payload) {
    try {
      // Notify listeners
      notifyListeners();

      // Emit stream update
      _menuItemsUpdateStream.add([]);

      debugPrint(
          '🔄 Optimized menu item update processed: ${payload.eventType}');
    } catch (e) {
      debugPrint('❌ Error handling optimized menu item realtime update: $e');
    }
  }

  /// Invalidate related caches based on update
  void _invalidateRelatedCaches(PostgresChangePayload payload) {
    try {
      final data = payload.newRecord;
      final restaurantId = data['id']?.toString();
      final category = data['category']?.toString();
      final isFeatured = data['is_featured'];

      // Invalidate specific caches
      if (restaurantId != null) {
        _perfService.clearAllCaches(); // Clear all for simplicity
      }

      if (isFeatured) {
        _featuredRestaurants.clear();
      }

      if (category != null) {
        _categoryCache.remove(category);
      }
    } catch (e) {
      debugPrint('❌ Error invalidating caches: $e');
    }
  }

  // ========================================
  // ULTRA-OPTIMIZED RESTAURANT METHODS
  // ========================================

  /// Get restaurants with maximum performance optimization
  Future<List<Restaurant>> getRestaurants({
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
    _totalRequests++;

    try {
      // Check precomputed caches first
      if (isFeatured == true && _featuredRestaurants.isNotEmpty) {
        _cacheHits++;
        stopwatch.stop();
        _totalResponseTime += stopwatch.elapsed;
        return _featuredRestaurants.take(limit).toList();
      }

      // Use performance optimization service
      final restaurants = await _perfService.getOptimizedRestaurants(
        category: category,
        cuisine: cuisine,
        isOpen: isOpen,
        isFeatured: isFeatured,
        location: location,
        minRating: minRating,
        offset: offset,
        limit: limit,
      );

      // Update caches
      if (isFeatured == true && _featuredRestaurants.isEmpty) {
        _featuredRestaurants = restaurants;
      }

      stopwatch.stop();
      _totalResponseTime += stopwatch.elapsed;
      _databaseHits++;

      return restaurants;
    } catch (e) {
      stopwatch.stop();
      _totalResponseTime += stopwatch.elapsed;
      debugPrint(
          '❌ OptimizedRestaurantService: Error fetching restaurants: $e');
      return [];
    }
  }

  /// Get restaurant by ID with instant cache lookup
  Future<Restaurant?> getRestaurantById(String id) async {
    final stopwatch = Stopwatch()..start();
    _totalRequests++;

    try {
      // Check if restaurant is in precomputed caches
      for (final restaurant in _featuredRestaurants) {
        if (restaurant.id == id) {
          _cacheHits++;
          stopwatch.stop();
          _totalResponseTime += stopwatch.elapsed;
          return restaurant;
        }
      }

      for (final restaurant in _popularRestaurants) {
        if (restaurant.id == id) {
          _cacheHits++;
          stopwatch.stop();
          _totalResponseTime += stopwatch.elapsed;
          return restaurant;
        }
      }

      // Fallback to database
      final response =
          await _supabase.from('restaurants').select('*').eq('id', id).single();

      // Overlay with info registry - service not available
      // final info = await InfoService().getEntity(
      //   namespace: 'lo9ma',
      //   entity: 'restaurant',
      //   entityId: id,
      // );

      final base = Map<String, dynamic>.from(response);
      // Info service not available - use base data
      final merged = base;

      // Overlay numeric attributes - info service not available
      // final minOrderInfo = info['minimum_order'];
      // if (minOrderInfo != null) {
      //   if (minOrderInfo is num) {
      //     merged['minimum_order'] = minOrderInfo.toDouble();
      //   } else if (minOrderInfo is String) {
      //     final parsed = double.tryParse(minOrderInfo);
      //     if (parsed != null) merged['minimum_order'] = parsed;
      //   }
      // }

      stopwatch.stop();
      _totalResponseTime += stopwatch.elapsed;
      _databaseHits++;

      return Restaurant.fromJson(merged);
    } catch (e) {
      stopwatch.stop();
      _totalResponseTime += stopwatch.elapsed;
      debugPrint('❌ Error fetching restaurant by ID: $e');
      return null;
    }
  }

  /// Get restaurants by IDs with batch optimization
  Future<List<Restaurant>> getRestaurantsByIds(List<String> ids) async {
    if (ids.isEmpty) return [];

    final stopwatch = Stopwatch()..start();
    _totalRequests++;

    try {
      // Check precomputed caches first
      final cachedRestaurants = <Restaurant>[];
      final remainingIds = <String>[];

      for (final id in ids) {
        bool found = false;

        for (final restaurant in _featuredRestaurants) {
          if (restaurant.id == id) {
            cachedRestaurants.add(restaurant);
            found = true;
            break;
          }
        }

        if (!found) {
          for (final restaurant in _popularRestaurants) {
            if (restaurant.id == id) {
              cachedRestaurants.add(restaurant);
              found = true;
              break;
            }
          }
        }

        if (!found) {
          remainingIds.add(id);
        }
      }

      if (remainingIds.isEmpty) {
        _cacheHits++;
        stopwatch.stop();
        _totalResponseTime += stopwatch.elapsed;
        return cachedRestaurants;
      }

      // Fetch remaining restaurants
      final response = await _supabase
          .from('restaurants')
          .select('*')
          .inFilter('id', remainingIds);

      final fetchedRestaurants = <Restaurant>[];
      for (final item in (response as List)) {
        final map = Map<String, dynamic>.from(item);
        final id = map['id']?.toString();
        if (id != null) {
          // Info service not available - use base data
          // final info = await InfoService().getEntity(
          //   namespace: 'lo9ma',
          //   entity: 'restaurant',
          //   entityId: id,
          // );
          final merged = map; // Use base data instead of overlay

          // Numeric overlays - info service not available
          // final minOrderInfo = info['minimum_order'];
          // if (minOrderInfo != null) {
          //   if (minOrderInfo is num) {
          //     merged['minimum_order'] = minOrderInfo.toDouble();
          //   } else if (minOrderInfo is String) {
          //     final parsed = double.tryParse(minOrderInfo);
          //     if (parsed != null) merged['minimum_order'] = parsed;
          //   }
          // }

          fetchedRestaurants.add(Restaurant.fromJson(merged));
        }
      }

      stopwatch.stop();
      _totalResponseTime += stopwatch.elapsed;
      _databaseHits++;

      return [...cachedRestaurants, ...fetchedRestaurants];
    } catch (e) {
      stopwatch.stop();
      _totalResponseTime += stopwatch.elapsed;
      debugPrint('❌ Error fetching restaurants by IDs: $e');
      return [];
    }
  }

  /// Get featured restaurants with instant cache
  Future<List<Restaurant>> getFeaturedRestaurants({int limit = 10}) async {
    if (_featuredRestaurants.isNotEmpty) {
      return _featuredRestaurants.take(limit).toList();
    }

    return getRestaurants(isFeatured: true, limit: limit);
  }

  /// Get restaurants by category with smart caching
  Future<List<Restaurant>> getRestaurantsByCategory(String category,
      {int limit = 20}) async {
    // Check category cache
    if (_categoryCache.containsKey(category)) {
      return _categoryCache[category]!.take(limit).toList();
    }

    // Add to prefetch queue for future requests
    _prefetchQueue.add('category_$category');

    final restaurants = await getRestaurants(category: category, limit: limit);

    // Cache the results
    _categoryCache[category] = restaurants;

    return restaurants;
  }

  /// Get restaurants by cuisine with smart caching
  Future<List<Restaurant>> getRestaurantsByCuisine(String cuisine,
      {int limit = 20}) async {
    // Check cuisine cache
    if (_cuisineCache.containsKey(cuisine)) {
      return _cuisineCache[cuisine]!.take(limit).toList();
    }

    // Add to prefetch queue for future requests
    _prefetchQueue.add('cuisine_$cuisine');

    final restaurants = await getRestaurants(cuisine: cuisine, limit: limit);

    // Cache the results
    _cuisineCache[cuisine] = restaurants;

    return restaurants;
  }

  /// Search restaurants with ultra-fast Redis optimization
  Future<List<Restaurant>> searchRestaurants(String query,
      {int limit = 20}) async {
    final stopwatch = Stopwatch()..start();
    _totalRequests++;

    try {
      // Redis optimization removed - using local search only

      // Fallback to optimized local search
      final allRestaurants = [..._featuredRestaurants, ..._popularRestaurants];
      final results = allRestaurants.where((restaurant) {
        final name = restaurant.name.toLowerCase();
        final description = restaurant.description.toLowerCase();
        final city = restaurant.city.toLowerCase();
        final state = restaurant.state.toLowerCase();
        final wilaya = (restaurant.wilaya ?? '').toLowerCase();
        final queryLower = query.toLowerCase();

        return name.contains(queryLower) ||
            description.contains(queryLower) ||
            city.contains(queryLower) ||
            state.contains(queryLower) ||
            wilaya.contains(queryLower);
      }).toList();

      stopwatch.stop();
      _totalResponseTime += stopwatch.elapsed;
      _databaseHits++;

      return results.take(limit).toList();
    } catch (e) {
      stopwatch.stop();
      _totalResponseTime += stopwatch.elapsed;
      debugPrint('❌ Error searching restaurants: $e');
      return [];
    }
  }

  /// Get restaurants near location with optimized distance calculation
  Future<List<Restaurant>> getRestaurantsNearLocation(
    double latitude,
    double longitude, {
    double radiusKm = 10.0,
    int limit = 20,
  }) async {
    final stopwatch = Stopwatch()..start();
    _totalRequests++;

    try {
      // Use cached restaurants for faster location filtering
      final allRestaurants = [..._featuredRestaurants, ..._popularRestaurants];

      if (allRestaurants.isEmpty) {
        // Fallback to database if no cached data
        final response = await _supabase
            .from('restaurants')
            .select('*')
            .eq('is_open', true)
            .order('rating', ascending: false)
            .limit(limit * 2); // Get more to filter by distance

        final restaurants = (response as List)
            .map((json) => Restaurant.fromJson(json))
            .toList();

        // Filter by distance
        final nearbyRestaurants = restaurants.where((restaurant) {
          if (restaurant.latitude == null || restaurant.longitude == null) {
            return false;
          }
          final distance = _calculateDistance(
            latitude,
            longitude,
            restaurant.latitude!,
            restaurant.longitude!,
          );
          return distance <= radiusKm;
        }).toList();

        stopwatch.stop();
        _totalResponseTime += stopwatch.elapsed;
        _databaseHits++;

        return nearbyRestaurants.take(limit).toList();
      }

      // Filter cached restaurants by distance
      final nearbyRestaurants = allRestaurants.where((restaurant) {
        if (restaurant.latitude == null || restaurant.longitude == null) {
          return false;
        }
        final distance = _calculateDistance(
          latitude,
          longitude,
          restaurant.latitude!,
          restaurant.longitude!,
        );
        return distance <= radiusKm;
      }).toList();

      stopwatch.stop();
      _totalResponseTime += stopwatch.elapsed;
      _cacheHits++;

      return nearbyRestaurants.take(limit).toList();
    } catch (e) {
      stopwatch.stop();
      _totalResponseTime += stopwatch.elapsed;
      debugPrint('❌ Error fetching restaurants near location: $e');
      return [];
    }
  }

  // ========================================
  // MENU ITEM METHODS WITH OPTIMIZATION
  // ========================================

  /// Get menu items for a restaurant with caching
  Future<List<MenuItem>> getRestaurantMenu(String restaurantId) async {
    final stopwatch = Stopwatch()..start();
    _totalRequests++;

    try {
      final response = await _supabase
          .from('menu_items')
          .select('*')
          .eq('restaurant_id', restaurantId)
          .order('category')
          .order('name');

      // Parse items and handle missing images gracefully
      final menuItems = <MenuItem>[];
      for (final json in (response as List)) {
        try {
          final item = MenuItem.fromJson(json);
          // Only include items with valid images
          if (item.image.isNotEmpty) {
            menuItems.add(item);
          } else {
            debugPrint('⚠️ Skipping menu item with empty image: ${json['id']}');
          }
        } catch (e) {
          // Skip items that can't be parsed (e.g., missing required fields like image)
          final itemId = json['id']?.toString() ?? 'unknown';
          debugPrint('⚠️ Skipping menu item due to parsing error: $e');
          debugPrint('   Item ID: $itemId');
        }
      }

      stopwatch.stop();
      _totalResponseTime += stopwatch.elapsed;
      _databaseHits++;

      return menuItems;
    } catch (e) {
      stopwatch.stop();
      _totalResponseTime += stopwatch.elapsed;
      debugPrint('❌ Error fetching restaurant menu: $e');
      return [];
    }
  }

  /// Get menu items by category with optimization
  Future<List<MenuItem>> getMenuItemsByCategory(
    String restaurantId,
    String category,
  ) async {
    final stopwatch = Stopwatch()..start();
    _totalRequests++;

    try {
      final response = await _supabase
          .from('menu_items')
          .select('*')
          .eq('restaurant_id', restaurantId)
          .eq('category', category)
          .order('name');

      // Parse items and handle missing images gracefully
      final menuItems = <MenuItem>[];
      for (final json in (response as List)) {
        try {
          final item = MenuItem.fromJson(json);
          // Only include items with valid images
          if (item.image.isNotEmpty) {
            menuItems.add(item);
          } else {
            debugPrint('⚠️ Skipping menu item with empty image: ${json['id']}');
          }
        } catch (e) {
          // Skip items that can't be parsed (e.g., missing required fields like image)
          final itemId = json['id']?.toString() ?? 'unknown';
          debugPrint('⚠️ Skipping menu item due to parsing error: $e');
          debugPrint('   Item ID: $itemId');
        }
      }

      stopwatch.stop();
      _totalResponseTime += stopwatch.elapsed;
      _databaseHits++;

      return menuItems;
    } catch (e) {
      stopwatch.stop();
      _totalResponseTime += stopwatch.elapsed;
      debugPrint('❌ Error fetching menu items by category: $e');
      return [];
    }
  }

  /// Search menu items with optimization
  Future<List<MenuItem>> searchMenuItems(
    String restaurantId,
    String query, {
    int limit = 20,
  }) async {
    final stopwatch = Stopwatch()..start();
    _totalRequests++;

    try {
      final response = await _supabase
          .from('menu_items')
          .select('*')
          .eq('restaurant_id', restaurantId)
          .order('name')
          .limit(limit);

      // Filter by search query
      final menuItems = (response as List)
          .map((json) => MenuItem.fromJson(json))
          .where((item) =>
              item.name.toLowerCase().contains(query.toLowerCase()) ||
              item.description.toLowerCase().contains(query.toLowerCase()))
          .toList();

      stopwatch.stop();
      _totalResponseTime += stopwatch.elapsed;
      _databaseHits++;

      return menuItems;
    } catch (e) {
      stopwatch.stop();
      _totalResponseTime += stopwatch.elapsed;
      debugPrint('❌ Error searching menu items: $e');
      return [];
    }
  }

  /// Get popular menu items with optimization
  Future<List<MenuItem>> getPopularMenuItems(
    String restaurantId, {
    int limit = 10,
  }) async {
    final stopwatch = Stopwatch()..start();
    _totalRequests++;

    try {
      // PERFORMANCE: Select only needed fields instead of all columns
      // This reduces data transfer and improves query speed
      final response = await _supabase
          .from('menu_items')
          .select(
              'id, restaurant_id, restaurant_name, name, description, image, images, price, category, cuisine_type_id, category_id, cuisine_types(*), categories(*), is_available, is_featured, preparation_time, rating, review_count, variants, pricing_options, supplements, created_at, updated_at')
          .eq('restaurant_id', restaurantId)
          .order('popularity', ascending: false)
          .limit(limit);

      // Parse items and handle missing images gracefully
      final menuItems = <MenuItem>[];
      for (final json in (response as List)) {
        try {
          final item = MenuItem.fromJson(json);
          // Only include items with valid images
          if (item.image.isNotEmpty) {
            menuItems.add(item);
          } else {
            debugPrint('⚠️ Skipping menu item with empty image: ${json['id']}');
          }
        } catch (e) {
          // Skip items that can't be parsed (e.g., missing required fields like image)
          final itemId = json['id']?.toString() ?? 'unknown';
          debugPrint('⚠️ Skipping menu item due to parsing error: $e');
          debugPrint('   Item ID: $itemId');
        }
      }

      stopwatch.stop();
      _totalResponseTime += stopwatch.elapsed;
      _databaseHits++;

      return menuItems;
    } catch (e) {
      stopwatch.stop();
      _totalResponseTime += stopwatch.elapsed;
      debugPrint('❌ Error fetching popular menu items: $e');
      return [];
    }
  }

  /// Get menu item by ID with optimization
  Future<MenuItem?> getMenuItemById(String id) async {
    final stopwatch = Stopwatch()..start();
    _totalRequests++;

    try {
      // PERFORMANCE: Select only needed fields instead of all columns
      // This reduces data transfer and improves query speed
      final response = await _supabase
          .from('menu_items')
          .select(
              'id, restaurant_id, restaurant_name, name, description, image, images, price, category, cuisine_type_id, category_id, cuisine_types(*), categories(*), is_available, is_featured, preparation_time, rating, review_count, variants, pricing_options, supplements, created_at, updated_at')
          .eq('id', id)
          .single();

      final menuItem = MenuItem.fromJson(response);

      stopwatch.stop();
      _totalResponseTime += stopwatch.elapsed;
      _databaseHits++;

      return menuItem;
    } catch (e) {
      stopwatch.stop();
      _totalResponseTime += stopwatch.elapsed;
      debugPrint('❌ Error fetching menu item by ID: $e');
      return null;
    }
  }

  // ========================================
  // CRUD OPERATIONS WITH OPTIMIZATION
  // ========================================

  /// Add new restaurant with cache invalidation
  Future<bool> addRestaurant(Restaurant restaurant) async {
    try {
      await _supabase.from('restaurants').insert(restaurant.toJson());

      // Invalidate caches
      _invalidateAllCaches();

      return true;
    } catch (e) {
      debugPrint('❌ Error adding restaurant: $e');
      return false;
    }
  }

  /// Update restaurant with cache invalidation
  Future<bool> updateRestaurant(Restaurant restaurant) async {
    try {
      await _supabase
          .from('restaurants')
          .update(restaurant.toJson())
          .eq('id', restaurant.id);

      // Invalidate caches
      _invalidateAllCaches();

      return true;
    } catch (e) {
      debugPrint('❌ Error updating restaurant: $e');
      return false;
    }
  }

  /// Delete restaurant with comprehensive cache invalidation
  Future<bool> deleteRestaurant(String id) async {
    try {
      debugPrint('🗑️ Deleting restaurant: $id');

      // Delete from database
      await _supabase.from('restaurants').delete().eq('id', id);

      // Comprehensive cache invalidation
      await _invalidateAllCachesComprehensive(id);

      // Force refresh all data
      await _forceRefreshAllData();

      // Emit real-time update
      _restaurantsUpdateStream.add([]);
      notifyListeners();

      debugPrint('✅ Restaurant deleted and caches invalidated: $id');
      return true;
    } catch (e) {
      debugPrint('❌ Error deleting restaurant: $e');
      return false;
    }
  }

  /// Add new menu item
  Future<bool> addMenuItem(MenuItem menuItem) async {
    try {
      await _supabase.from('menu_items').insert(menuItem.toJson());

      return true;
    } catch (e) {
      debugPrint('❌ Error adding menu item: $e');
      return false;
    }
  }

  /// Update menu item
  Future<bool> updateMenuItem(MenuItem menuItem) async {
    try {
      await _supabase
          .from('menu_items')
          .update(menuItem.toJson())
          .eq('id', menuItem.id);

      return true;
    } catch (e) {
      debugPrint('❌ Error updating menu item: $e');
      return false;
    }
  }

  /// Delete menu item
  Future<bool> deleteMenuItem(String id) async {
    try {
      await _supabase.from('menu_items').delete().eq('id', id);

      return true;
    } catch (e) {
      debugPrint('❌ Error deleting menu item: $e');
      return false;
    }
  }

  // ========================================
  // UTILITY METHODS
  // ========================================

  /// Calculate distance between two points using Haversine formula
  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  /// Invalidate all caches
  void _invalidateAllCaches() {
    _featuredRestaurants.clear();
    _popularRestaurants.clear();
    _categoryCache.clear();
    _cuisineCache.clear();
    _perfService.clearAllCaches();
  }

  /// Comprehensive cache invalidation for restaurant deletion
  Future<void> _invalidateAllCachesComprehensive(String restaurantId) async {
    try {
      debugPrint(
          '🗑️ Comprehensive cache invalidation for restaurant: $restaurantId');

      // Clear all local caches
      _featuredRestaurants.clear();
      _popularRestaurants.clear();
      _categoryCache.clear();
      _cuisineCache.clear();
      _perfService.clearAllCaches();

      // Clear search cache (handled by _invalidateAllCaches)

      // Clear Redis cache via server API
      try {
        final response = await _supabase.functions.invoke(
            'clear-restaurant-cache',
            body: {'restaurantId': restaurantId, 'clearAll': true});
        debugPrint('✅ Server cache cleared: ${response.data}');
      } catch (e) {
        debugPrint('⚠️ Server cache clear failed: $e');
      }

      debugPrint('✅ Comprehensive cache invalidation completed');
    } catch (e) {
      debugPrint('❌ Error in comprehensive cache invalidation: $e');
    }
  }

  /// Force refresh all restaurant data
  Future<void> _forceRefreshAllData() async {
    try {
      debugPrint('🔄 Force refreshing all restaurant data...');

      // Clear all cached data
      _featuredRestaurants.clear();
      _popularRestaurants.clear();
      _categoryCache.clear();
      _cuisineCache.clear();

      // Force reload featured restaurants
      await getFeaturedRestaurants();

      debugPrint('✅ Force refresh completed');
    } catch (e) {
      debugPrint('❌ Error in force refresh: $e');
    }
  }

  /// Force refresh all restaurant data (public method)
  Future<void> forceRefreshAllRestaurants() async {
    try {
      debugPrint('🔄 Force refreshing all restaurants...');
      await _forceRefreshAllData();
      notifyListeners();
      debugPrint('✅ Force refresh completed');
    } catch (e) {
      debugPrint('❌ Error in force refresh: $e');
    }
  }

  /// Clear all caches and force reload (public method)
  Future<void> clearAllCachesAndRefresh() async {
    try {
      debugPrint('🗑️ Clearing all caches and refreshing...');
      _invalidateAllCaches();
      await _forceRefreshAllData();
      notifyListeners();
      debugPrint('✅ All caches cleared and data refreshed');
    } catch (e) {
      debugPrint('❌ Error clearing caches and refreshing: $e');
    }
  }

  /// Get context summary for debugging
  Map<String, dynamic> getContextSummary() {
    return {
      ..._contextAware.getContextSummary(),
      'performance_metrics': performanceMetrics,
      'cache_status': {
        'featured_cached': _featuredRestaurants.isNotEmpty,
        'popular_cached': _popularRestaurants.isNotEmpty,
        'category_cache_size': _categoryCache.length,
        'cuisine_cache_size': _cuisineCache.length,
      },
    };
  }

  /// Dispose method to clean up resources
  @override
  void dispose() {
    _restaurantsChannel?.unsubscribe();
    _menuItemsChannel?.unsubscribe();
    _restaurantsUpdateStream.close();
    _menuItemsUpdateStream.close();
    _prefetchTimer?.cancel();
    super.dispose();
  }
}
