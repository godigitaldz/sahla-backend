import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";
import "../models/restaurant.dart";

/// Display-focused service to fetch restaurants filtered by cuisines/categories
class RestaurantDisplayService {
  SupabaseClient get _supabase => Supabase.instance.client;

  String _normalize(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r"[\s-]+"), "_")
        .replaceAll(RegExp("[^a-z0-9_]+"), "");
  }

  /// Fetch restaurants having at least one menu item matching any of the provided categories or cuisines
  Future<List<Restaurant>> getRestaurantsByCuisinesAndCategories({
    Set<String> cuisineNames = const {},
    Set<String> categoryNames = const {},
    int limit = 20,
    double? minRating,
    RangeValues? deliveryFeeRange,
  }) async {
    try {
      // Map cuisine names -> ids
      List<String> cuisineIds = [];
      if (cuisineNames.isNotEmpty) {
        final cuisineRows = await _supabase
            .from("cuisine_types")
            .select("id,name")
            .eq("is_active", true);
        final Map<String, String> normToId = {};
        for (final row in (cuisineRows as List)) {
          final name = (row["name"] ?? "").toString();
          final id = (row["id"] ?? "").toString();
          if (name.isEmpty || id.isEmpty) {
            continue;
          }
          normToId[_normalize(name)] = id;
        }
        cuisineIds = cuisineNames
            .map(_normalize)
            .map((n) => normToId[n])
            .whereType<String>()
            .toList();
      }

      // If we have neither cuisineIds nor categories, return featured/open restaurants as fallback
      if (cuisineIds.isEmpty && categoryNames.isEmpty) {
        final response = await _supabase
            .from("restaurants")
            .select("*")
            .order("rating", ascending: false)
            .limit(limit);
        return (response as List).map((e) => Restaurant.fromJson(e)).toList();
      }

      // Collect restaurant IDs from menu items
      final restaurantIds = <String>{};

      // If we have filters, find restaurants that match the criteria
      if (categoryNames.isNotEmpty || cuisineIds.isNotEmpty) {
        // Build menu_items selector for restaurants
        var mi = _supabase
            .from("menu_items")
            .select("restaurant_id,category,cuisine_type_id");

        if (categoryNames.isNotEmpty) {
          // Try exact match first
          mi = mi.inFilter("category", categoryNames.toList());
        }
        if (cuisineIds.isNotEmpty) {
          mi = mi.inFilter("cuisine_type_id", cuisineIds);
        }

        final menuRows = await mi.eq("is_available", "true");
        debugPrint(
            "🍽️ RestaurantDisplayService: Found ${menuRows.length} menu items for filters: cuisines=$cuisineNames, categories=$categoryNames");

        // Collect restaurant IDs from matching menu items
        for (final row in (menuRows as List)) {
          final rid = (row["restaurant_id"] ?? "").toString();
          if (rid.isNotEmpty) {
            restaurantIds.add(rid);
          }
        }

        // If we have category filters but no results, try case-insensitive matching
        if (categoryNames.isNotEmpty && restaurantIds.isEmpty) {
          debugPrint(
              "🍽️ RestaurantDisplayService: No exact matches found, trying case-insensitive matching");

          // Get all menu items with categories and try case-insensitive matching
          final allMenuItems = await _supabase
              .from("menu_items")
              .select("restaurant_id,category")
              .eq("is_available", "true");

          for (final row in (allMenuItems as List)) {
            final category = (row["category"] ?? "").toString();
            final rid = (row["restaurant_id"] ?? "").toString();

            // Check if any of the requested categories match (case-insensitive)
            for (final requestedCategory in categoryNames) {
              if (category
                      .toLowerCase()
                      .contains(requestedCategory.toLowerCase()) ||
                  requestedCategory
                      .toLowerCase()
                      .contains(category.toLowerCase())) {
                restaurantIds.add(rid);
                break;
              }
            }
          }

          debugPrint(
              "🍽️ RestaurantDisplayService: Found ${restaurantIds.length} restaurants with case-insensitive category matching");
        }
      } else {
        // If no filters, return featured/open restaurants as fallback
        final response = await _supabase
            .from("restaurants")
            .select("*")
            .order("rating", ascending: false)
            .limit(limit);
        return (response as List).map((e) => Restaurant.fromJson(e)).toList();
      }

      debugPrint(
          "🍽️ RestaurantDisplayService: Found ${restaurantIds.length} restaurants for filters");
      if (restaurantIds.isEmpty) {
        return [];
      }

      // Get restaurants by IDs with additional filtering
      final restaurants = await _getRestaurantsByIds(
          restaurantIds.toList(), limit, minRating, deliveryFeeRange);

      // Additional deduplication to ensure no duplicates
      final uniqueRestaurants = <String, Restaurant>{};
      for (final restaurant in restaurants) {
        uniqueRestaurants[restaurant.id] = restaurant;
      }

      debugPrint(
          "🍽️ RestaurantDisplayService: Returning ${uniqueRestaurants.length} unique restaurants (deduplicated from ${restaurants.length})");
      return uniqueRestaurants.values.toList();
    } on Exception catch (e) {
      debugPrint(
          "Error in RestaurantDisplayService.getRestaurantsByCuisinesAndCategories: $e");
      return [];
    }
  }

  /// Helper method to get restaurants by their IDs
  Future<List<Restaurant>> _getRestaurantsByIds(List<String> restaurantIds,
      int limit, double? minRating, RangeValues? deliveryFeeRange) async {
    try {
      var restQuery = _supabase
          .from("restaurants")
          .select("*")
          .inFilter("id", restaurantIds);

      if (minRating != null) {
        restQuery = restQuery.gte("rating", minRating);
      }

      final restRows =
          await restQuery.order("rating", ascending: false).limit(limit);

      List<Restaurant> restaurants =
          (restRows as List).map((e) => Restaurant.fromJson(e)).toList();

      if (deliveryFeeRange != null) {
        restaurants = restaurants
            .where((r) =>
                r.deliveryFee >= deliveryFeeRange.start &&
                r.deliveryFee <= deliveryFeeRange.end)
            .toList();
      }

      // Deduplicate restaurants by ID to prevent duplicates
      final uniqueRestaurants = <String, Restaurant>{};
      for (final restaurant in restaurants) {
        uniqueRestaurants[restaurant.id] = restaurant;
      }

      debugPrint(
          "🍽️ RestaurantDisplayService._getRestaurantsByIds: Returning ${uniqueRestaurants.length} unique restaurants (deduplicated from ${restaurants.length})");
      return uniqueRestaurants.values.toList();
    } on Exception catch (e) {
      debugPrint("Error in RestaurantDisplayService._getRestaurantsByIds: $e");
      return [];
    }
  }
}
