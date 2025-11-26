import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../models/restaurant.dart";
import "api_client.dart";
import "context_aware_service.dart";
import "optimized_api_client.dart";
import "optimized_backend_service.dart";
import "performance_monitoring_service.dart";

class RestaurantService extends ChangeNotifier {
  // Context-aware service for tracking and validation
  final ContextAwareService _contextAware = ContextAwareService();

  // Ultra-optimized backend service for world-class performance
  final OptimizedBackendService _optimizedBackendService =
      OptimizedBackendService();

  // Ultra-optimized API client for maximum performance
  final OptimizedApiClient _optimizedApiClient = OptimizedApiClient();

  // Performance monitoring service
  final PerformanceMonitoringService _performanceMonitor =
      PerformanceMonitoringService();

  // Initialize the service with context tracking (synchronous ultra-fast version)
  void initializeSync() {
    _contextAware.initialize();
    _optimizedBackendService.initializeSync();
    debugPrint("🚀 RestaurantService initialized with context tracking (sync)");
  }

  // Initialize the service with context tracking (legacy async version)
  Future<void> initialize() async {
    await _contextAware.initialize();
    await _optimizedBackendService.initialize();
    debugPrint("🚀 RestaurantService initialized with context tracking");
  }

  // Get all restaurants with optional filters - ULTRA-OPTIMIZED
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
    try {
      debugPrint(
          "🍽️ FETCHING RESTAURANTS FROM SUPABASE: category=$category, cuisine=$cuisine, location=$location, limit=$limit, offset=$offset");

      final supabase = Supabase.instance.client;
      var queryBuilder = supabase.from('restaurants').select('*');

      // Apply filters if provided
      if (category != null && category.isNotEmpty) {
        queryBuilder = queryBuilder.eq('category', category);
      }
      if (cuisine != null && cuisine.isNotEmpty) {
        queryBuilder = queryBuilder.eq('cuisine_type', cuisine);
      }
      if (minRating != null) {
        queryBuilder = queryBuilder.gte('rating', minRating);
      }
      if (isFeatured != null) {
        queryBuilder = queryBuilder.eq('is_featured', isFeatured);
      }

      final response = await queryBuilder
          .order('rating', ascending: false)
          .range(offset, offset + limit - 1);
      final restaurantsData = response as List;

      if (restaurantsData.isEmpty) {
        debugPrint("⚠️ No restaurants found");
        return [];
      }

      final restaurants = <Restaurant>[];
      for (var i = 0; i < restaurantsData.length; i++) {
        try {
          final restaurant = Restaurant.fromJson(restaurantsData[i]);
          restaurants.add(restaurant);
        } on Exception catch (e) {
          debugPrint("❌ RESTAURANT PARSING ERROR at index $i: $e");
        }
      }

      debugPrint("✅ Loaded ${restaurants.length} restaurants from Supabase");
      return restaurants;
    } on Exception catch (e) {
      debugPrint("❌ RestaurantService: Error fetching restaurants: $e");
      return [];
    }
  }

  // Get restaurant by ID
  Future<Restaurant?> getRestaurantById(String id) async {
    try {
      // Use Node.js backend for optimized restaurant data with business logic
      final response = await ApiClient.get(
        "/api/business/restaurants/optimized",
        queryParameters: {
          "restaurantId": id,
          "includeMetrics": "true",
        },
      );

      if (!response["success"] || response["data"].isEmpty) {
        debugPrint(
            "Error fetching restaurant from Node.js backend: ${response["error"]}");
        return null;
      }

      final restaurantData = response["data"];
      return Restaurant.fromJson(restaurantData);
    } on Exception catch (e) {
      debugPrint("Error fetching restaurant by ID via API: $e");
      return null;
    }
  }

  // Get restaurant by owner ID
  Future<Restaurant?> getRestaurantByOwnerId(String ownerId) async {
    try {
      debugPrint('🔍 Fetching restaurant for owner ID: $ownerId');

      final supabase = Supabase.instance.client;
      final response = await supabase
          .from('restaurants')
          .select()
          .eq('owner_id', ownerId)
          .maybeSingle();

      if (response == null) {
        debugPrint('❌ No restaurant found for owner: $ownerId');
        return null;
      }

      debugPrint('✅ Found restaurant: ${response['name']} (${response['id']})');
      return Restaurant.fromJson(response);
    } catch (e) {
      debugPrint("❌ Error fetching restaurant by owner ID: $e");
      return null;
    }
  }

  // Get restaurants by IDs
  Future<List<Restaurant>> getRestaurantsByIds(List<String> ids) async {
    try {
      // Use Node.js backend for optimized restaurant data with business logic
      final response =
          await ApiClient.post("/api/business/restaurants/by-ids", data: {
        "ids": ids,
      });

      if (!response["success"]) {
        debugPrint(
            "❌ RestaurantService: Error fetching restaurants by IDs: ${response["error"]}");
        return [];
      }

      final restaurantsData = response["data"] as List;
      final restaurants =
          restaurantsData.map((json) => Restaurant.fromJson(json)).toList();

      debugPrint(
          "🚀 RestaurantService: Fetched ${restaurants.length} restaurants by IDs via Node.js backend");
      return restaurants;
    } on Exception catch (e) {
      debugPrint(
          "❌ RestaurantService: Error fetching restaurants by IDs via API: $e");
      return [];
    }
  }

  // Get restaurant menu - ULTRA-OPTIMIZED with Redis caching and performance monitoring
  Future<List<dynamic>> getRestaurantMenu(String restaurantId) async {
    final stopwatch = Stopwatch()..start();

    debugPrint(
        "🔄 RestaurantService: Starting menu load for restaurant $restaurantId");

    // Use Supabase as primary method since API endpoints are failing
    try {
      final supabase = Supabase.instance.client;
      debugPrint(
          "🔄 RestaurantService: Querying Supabase for restaurant $restaurantId");

      // First try: Get all menu items for the restaurant
      final response = await supabase
          .from('menu_items')
          .select('*')
          .eq('restaurant_id', restaurantId)
          .order('category')
          .limit(50);

      final menuData = response as List;
      debugPrint(
          "🔄 RestaurantService: Supabase query returned ${menuData.length} items");

      if (menuData.isNotEmpty) {
        // Track success performance
        _performanceMonitor.trackApiRequest(
          endpoint: 'supabase/menu_items',
          method: 'GET',
          duration: stopwatch.elapsed,
          success: true,
          metadata: {
            'menuItemsCount': menuData.length,
            'restaurantId': restaurantId,
            'cached': false,
            'responseTime': stopwatch.elapsedMilliseconds,
            'source': 'supabase_primary',
          },
        );

        debugPrint(
            "🚀 RestaurantService: Fetched ${menuData.length} menu items for restaurant $restaurantId via Supabase (${stopwatch.elapsedMilliseconds}ms)");
        return menuData;
      } else {
        debugPrint(
            "⚠️ RestaurantService: No menu items found for restaurant $restaurantId");

        // Try without restaurant_id filter to see if there are any menu items at all
        final allItemsResponse =
            await supabase.from('menu_items').select('*').limit(10);

        final allItems = allItemsResponse as List;
        debugPrint(
            "🔄 RestaurantService: Total menu items in database: ${allItems.length}");

        if (allItems.isNotEmpty) {
          debugPrint(
              "🔄 RestaurantService: Sample menu item restaurant_id: ${allItems.first['restaurant_id']}");
        }

        return [];
      }
    } catch (supabaseError) {
      debugPrint("❌ RestaurantService: Supabase query failed: $supabaseError");

      // Fallback to API methods if Supabase fails
      try {
        debugPrint("🔄 RestaurantService: Trying API fallback...");

        // Try ultra-optimized API client
        final response = await _optimizedApiClient.get(
          "/api/menu/$restaurantId",
          queryParameters: {
            "limit": "50",
            "includeUnavailable": "false",
            "sortBy": "category",
            "sortOrder": "asc",
          },
          useCache: true,
          priority: 1,
        );

        if (response["success"] && response["data"] != null) {
          final menuData = response["data"] as List;
          debugPrint(
              "🚀 RestaurantService: API fallback successful, ${menuData.length} items");
          return menuData;
        }
      } catch (apiError) {
        debugPrint("❌ RestaurantService: API fallback also failed: $apiError");

        // Final fallback to direct Supabase with enhanced error handling
        try {
          final supabase = Supabase.instance.client;
          debugPrint(
              "🔄 RestaurantService: Attempting Supabase fallback for restaurant $restaurantId");

          final response = await supabase
              .from('menu_items')
              .select('*')
              .eq('restaurant_id', restaurantId)
              .eq('is_available', true)
              .order('category')
              .limit(50);

          final menuData = response as List;
          debugPrint(
              "🔄 RestaurantService: Supabase query returned ${menuData.length} items");

          // Track success performance
          _performanceMonitor.trackApiRequest(
            endpoint: 'supabase/menu_items',
            method: 'GET',
            duration: stopwatch.elapsed,
            success: true,
            metadata: {
              'menuItemsCount': menuData.length,
              'restaurantId': restaurantId,
              'cached': false,
              'responseTime': stopwatch.elapsedMilliseconds,
              'source': 'supabase_direct',
            },
          );

          debugPrint(
              "🚀 RestaurantService: Fetched ${menuData.length} menu items for restaurant $restaurantId via direct Supabase (${stopwatch.elapsedMilliseconds}ms)");
          return menuData;
        } catch (supabaseError) {
          debugPrint(
              "❌ RestaurantService: Supabase fallback failed: $supabaseError");

          // Try a simpler Supabase query as last resort
          try {
            debugPrint("🔄 RestaurantService: Trying simpler Supabase query");
            final supabase = Supabase.instance.client;
            final response = await supabase
                .from('menu_items')
                .select('*')
                .eq('restaurant_id', restaurantId)
                .limit(50);

            final menuData = response as List;
            debugPrint(
                "🔄 RestaurantService: Simple Supabase query returned ${menuData.length} items");

            if (menuData.isNotEmpty) {
              _performanceMonitor.trackApiRequest(
                endpoint: 'supabase/menu_items_simple',
                method: 'GET',
                duration: stopwatch.elapsed,
                success: true,
                metadata: {
                  'menuItemsCount': menuData.length,
                  'restaurantId': restaurantId,
                  'cached': false,
                  'responseTime': stopwatch.elapsedMilliseconds,
                  'source': 'supabase_simple',
                },
              );

              debugPrint(
                  "🚀 RestaurantService: Fetched ${menuData.length} menu items for restaurant $restaurantId via simple Supabase query (${stopwatch.elapsedMilliseconds}ms)");
              return menuData;
            }
          } catch (simpleSupabaseError) {
            debugPrint(
                "❌ RestaurantService: Simple Supabase query also failed: $simpleSupabaseError");
          }

          // Track error performance
          _performanceMonitor.trackApiRequest(
            endpoint: '/api/menu/$restaurantId',
            method: 'GET',
            duration: stopwatch.elapsed,
            success: false,
            metadata: {
              'error':
                  'All API methods failed: API=$apiError, Supabase: $supabaseError',
              'restaurantId': restaurantId,
            },
          );

          debugPrint(
              "❌ RestaurantService: All methods failed to fetch restaurant menu: API=$apiError, Supabase=$supabaseError");
          return [];
        }
      }

      return [];
    } finally {
      stopwatch.stop();
    }
  }

  // Search restaurants using ultra-optimized service
  Future<List<Restaurant>> searchRestaurants(String query,
      {int limit = 20}) async {
    try {
      debugPrint(
          "🔍 SEARCHING RESTAURANTS IN SUPABASE: query='$query', limit=$limit");

      final supabase = Supabase.instance.client;

      // Search restaurants by name using ilike for case-insensitive search
      final response = await supabase
          .from('restaurants')
          .select('*')
          .ilike('name', '%$query%')
          .order('rating', ascending: false)
          .limit(limit);

      final restaurantsData = response as List;

      if (restaurantsData.isEmpty) {
        debugPrint("⚠️ No restaurants found for query '$query'");
        return [];
      }

      final restaurants =
          restaurantsData.map((json) => Restaurant.fromJson(json)).toList();

      debugPrint(
          "✅ Found ${restaurants.length} restaurants for query '$query'");
      return restaurants;
    } on Exception catch (e) {
      debugPrint("❌ RestaurantService: Error searching restaurants: $e");
      return [];
    }
  }
}
