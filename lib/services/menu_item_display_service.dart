import "package:flutter/foundation.dart" hide Category;
import "package:flutter/material.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../models/category.dart";
import "../models/cuisine_type.dart";
import "../models/menu_item.dart";
import "../utils/smart_text_detector.dart";
import "logging_service.dart";

// Category-based grouping service for menu items
class MenuItemCategoryService {
  static SupabaseClient get _supabase => Supabase.instance.client;

  // Cache for categories to avoid repeated database calls
  static Map<String, Map<String, dynamic>>? _cachedCategories;
  static DateTime? _lastCacheUpdate;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  // Default category for items that don't match any category
  static const String defaultCategory = "other";

  /// Fetch categories from the database
  static Future<Map<String, Map<String, dynamic>>>
      _fetchCategoriesFromDatabase() async {
    try {
      if (kDebugMode) {
        if (kDebugMode) debugPrint("🔍 Fetching categories from database...");
      }

      final response = await _supabase
          .from("categories")
          .select(
              "id, name, description, icon, color, is_active, display_order")
          .eq("is_active", "true")
          .order("display_order");

      if (kDebugMode) {
        if (kDebugMode) debugPrint("🔍 Raw categories response: $response");
      }

      final Map<String, Map<String, dynamic>> categories = {};

      for (final row in response) {
        final categoryId = row["id"]?.toString() ?? "";
        final categoryName = row["name"]?.toString() ?? "";

        if (categoryId.isNotEmpty && categoryName.isNotEmpty) {
          categories[categoryName.toLowerCase()] = {
            "id": categoryId,
            "displayName": categoryName,
            "description": row["description"]?.toString() ?? "",
            "icon": row["icon"]?.toString() ?? "",
            "color": row["color"]?.toString() ?? "#FF6B35",
            "is_active": row["is_active"] ?? true,
            "display_order": row["display_order"] ?? 0,
          };
        }
      }

      if (kDebugMode) {
        if (kDebugMode) debugPrint("🔍 Parsed ${categories.length} categories from database");
        if (kDebugMode) debugPrint("🔍 Categories: ${categories.keys.toList()}");
      }

      return categories;
    } on Exception catch (e) {
      if (kDebugMode) {
        if (kDebugMode) debugPrint("❌ Error fetching categories from database: $e");
      }
      return _getFallbackCategories();
    }
  }

  /// Get fallback categories if database fetch fails
  static Map<String, Map<String, dynamic>> _getFallbackCategories() {
    if (kDebugMode) {
      if (kDebugMode) debugPrint("🔍 Using fallback categories");
    }
    return {
      "other": {
        "displayName": "Other Dishes",
        "description": "Miscellaneous food items",
        "icon": "",
        "color": "#FF6B35",
        "is_active": true,
        "display_order": 999,
      }
    };
  }

  /// Get categories with caching
  static Future<Map<String, Map<String, dynamic>>> _getCategories() async {
    final now = DateTime.now();

    // Return cached categories if still valid
    if (_cachedCategories != null &&
        _lastCacheUpdate != null &&
        now.difference(_lastCacheUpdate!) < _cacheExpiry) {
      if (kDebugMode) {
        if (kDebugMode) debugPrint("🔍 Using cached categories");
      }
      return _cachedCategories!;
    }

    // Fetch fresh categories from database
    _cachedCategories = await _fetchCategoriesFromDatabase();
    _lastCacheUpdate = now;

    return _cachedCategories!;
  }

  /// Determine the category for an item based on its name
  /// This method now uses a simple name-based matching since we're using database categories
  static String determineCategory(String itemName) {
    if (itemName.isEmpty) {
      return defaultCategory;
    }

    final name = itemName.toLowerCase().trim();

    // Simple keyword-based category determination
    // This is a fallback when the item doesn't have a category from the database
    if (name.contains("sandwich") ||
        name.contains("burger") ||
        name.contains("shawarma")) {
      return "sandwich";
    } else if (name.contains("pizza")) {
      return "pizza";
    } else if (name.contains("pasta") || name.contains("spaghetti")) {
      return "pasta";
    } else if (name.contains("chicken") ||
        name.contains("beef") ||
        name.contains("meat")) {
      return "main_course";
    } else if (name.contains("rice") || name.contains("kabsa")) {
      return "rice_dish";
    } else if (name.contains("soup")) {
      return "soup";
    } else if (name.contains("dessert") ||
        name.contains("cake") ||
        name.contains("sweet")) {
      return "dessert";
    } else if (name.contains("drink") ||
        name.contains("juice") ||
        name.contains("coffee")) {
      return "beverage";
    } else if (name.contains("crepe") || name.contains("pancake")) {
      return "crepe";
    } else if (name.contains("breakfast") || name.contains("egg")) {
      return "breakfast";
    }

    return defaultCategory;
  }

  /// Group menu items by their determined categories
  static Map<String, List<MenuItem>> groupByCategory(List<MenuItem> items) {
    final Map<String, List<MenuItem>> groupedItems = {};

    for (final item in items) {
      final category = determineCategory(item.name);
      groupedItems.putIfAbsent(category, () => []).add(item);
    }

    return groupedItems;
  }

  /// Get display name for a category (synchronous fallback)
  static String getDisplayNameSync(String categoryId) {
    if (categoryId.isEmpty) {
      return "Other Dishes";
    }
    if (categoryId == defaultCategory) {
      return "Other Dishes";
    }

    // Simple fallback: capitalize the category ID
    return categoryId.substring(0, 1).toUpperCase() + categoryId.substring(1);
  }

  /// Get display name for a category (async version with database lookup)
  static Future<String> getDisplayName(String categoryId) async {
    if (categoryId == defaultCategory) {
      return "Other Dishes";
    }

    try {
      final categories = await _getCategories();
      final categoryData = categories[categoryId.toLowerCase()];
      if (categoryData != null) {
        return categoryData["displayName"] as String;
      }
    } on Exception catch (e) {
      if (kDebugMode) {
        if (kDebugMode) debugPrint("❌ Error getting display name for category $categoryId: $e");
      }
    }

    // Fallback: capitalize the category ID
    return categoryId.substring(0, 1).toUpperCase() + categoryId.substring(1);
  }

  /// Get all available category IDs
  static Future<List<String>> getAllCategoryIds() async {
    try {
      final categories = await _getCategories();
      return categories.keys.toList();
    } on Exception catch (e) {
      if (kDebugMode) {
        if (kDebugMode) debugPrint("❌ Error getting category IDs: $e");
      }
      return [defaultCategory];
    }
  }

  /// Check if a menu item matches any of the selected categories
  static bool matchesSelectedCategories(
      MenuItem item, Set<String> selectedCategories) {
    if (selectedCategories.isEmpty) {
      return true;
    }

    final itemName = item.name.toLowerCase();
    final itemCategory = item.category.toLowerCase();
    final determinedCategory = determineCategory(item.name);

    // Handle null or empty category names
    if (itemCategory.isEmpty && determinedCategory.isEmpty) {
      if (kDebugMode) {
        if (kDebugMode) debugPrint('⚠️ Item "${item.name}" has no category information');
      }
      return false;
    }

    return selectedCategories.any((selectedCategory) {
      final normalizedSelected = selectedCategory.toLowerCase();

      // Check if selected category matches any of the item's category representations
      return itemCategory.contains(normalizedSelected) ||
          normalizedSelected.contains(itemCategory) ||
          itemName.contains(normalizedSelected) ||
          normalizedSelected.contains(itemName) ||
          determinedCategory.contains(normalizedSelected) ||
          normalizedSelected.contains(determinedCategory);
    });
  }

  /// Check if a menu item matches any of the selected cuisines
  static bool matchesSelectedCuisines(
      MenuItem item, Set<String> selectedCuisines) {
    if (selectedCuisines.isEmpty) {
      return true;
    }

    // Check cuisine type if available
    if (item.cuisineType != null) {
      final cuisineName = item.cuisineType!.name.toLowerCase();
      return selectedCuisines.any((selectedCuisine) {
        final normalizedSelected = selectedCuisine.toLowerCase();
        return cuisineName.contains(normalizedSelected) ||
            normalizedSelected.contains(cuisineName);
      });
    }

    // Fallback to checking item name and category for cuisine keywords
    final itemName = item.name.toLowerCase();
    final itemCategory = item.category.toLowerCase();

    return selectedCuisines.any((selectedCuisine) {
      final normalizedSelected = selectedCuisine.toLowerCase();
      return itemName.contains(normalizedSelected) ||
          itemCategory.contains(normalizedSelected) ||
          normalizedSelected.contains(itemName) ||
          normalizedSelected.contains(itemCategory);
    });
  }

  /// Sort categories by priority (most common/popular first)
  static List<String> sortCategoriesByPriority(
      Map<String, List<MenuItem>> groupedItems) {
    final keywords = groupedItems.keys.toList();

    // Define category priority order (most common first)
    const priorityOrder = [
      "main_courses",
      "sandwiches",
      "pizzas",
      "appetizers",
      "rice_dishes",
      "pasta",
      "soups",
      "beverages",
      "desserts",
      "breakfast",
      "other"
    ];

    // Sort by priority order, then by item count
    keywords.sort((a, b) {
      final aPriority = priorityOrder.indexOf(a);
      final bPriority = priorityOrder.indexOf(b);

      // If both categories are in priority list, sort by priority
      if (aPriority != -1 && bPriority != -1) {
        return aPriority.compareTo(bPriority);
      }

      // If one is in priority list, it comes first
      if (aPriority != -1) {
        return -1;
      }
      if (bPriority != -1) {
        return 1;
      }

      // Otherwise sort by item count (descending)
      final aCount = groupedItems[a]?.length ?? 0;
      final bCount = groupedItems[b]?.length ?? 0;

      if (aCount != bCount) {
        return bCount.compareTo(aCount);
      }

      // Finally sort alphabetically
      return a.compareTo(b);
    });

    return keywords;
  }

  /// Get categories with their display information
  static Future<Map<String, Map<String, dynamic>>>
      getCategoriesWithDisplayInfo() async {
    return _getCategories();
  }
}

class MenuItemDisplayService {
  SupabaseClient get _supabase => Supabase.instance.client;

  // Logging service for business metrics and performance tracking
  final LoggingService _logger = LoggingService();

  // Performance tracking
  final Map<String, DateTime> _queryStartTimes = {};
  final Map<String, int> _queryCounts = {};

  // Cache for menu items
  final Map<String, List<MenuItem>> _menuItemCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const Duration _cacheDuration = Duration(minutes: 5);

  /// Initialize the service
  Future<void> initialize() async {
    try {
      _logger.startPerformanceTimer("menu_display_service_init");
      _logger.endPerformanceTimer("menu_display_service_init",
          details: "MenuItemDisplayService initialized successfully");
      _logger.info("MenuItemDisplayService initialized", tag: "MENU_DISPLAY");
    } on Exception catch (e) {
      _logger.error("Failed to initialize MenuItemDisplayService",
          tag: "MENU_DISPLAY", error: e);
      rethrow;
    }
  }

  /// Fetch featured menu items with restaurant information
  Future<List<MenuItem>> getFeaturedMenuItems({
    int limit = 20,
    int offset = 0,
  }) async {
    final cacheKey = "featured_${limit}_$offset";

    try {
      // Check cache first
      if (_menuItemCache.containsKey(cacheKey)) {
        final cacheTime = _cacheTimestamps[cacheKey];
        if (cacheTime != null &&
            DateTime.now().difference(cacheTime) < _cacheDuration) {
          _logger.info("Returning cached featured menu items",
              tag: "MENU_DISPLAY",
              additionalData: {
                "cache_key": cacheKey,
                "cached_count": _menuItemCache[cacheKey]!.length,
              });
          return _menuItemCache[cacheKey]!;
        }
      }

      _logger.startPerformanceTimer("featured_menu_items_query", metadata: {
        "limit": limit,
        "offset": offset,
        "cache_key": cacheKey,
      });

      _logger.logUserAction(
        "featured_menu_items_requested",
        data: {
          "limit": limit,
          "offset": offset,
          "cache_key": cacheKey,
        },
      );

      if (kDebugMode) {
        debugPrint("🔍 Fetching featured menu items...");
      }
      if (kDebugMode) {
        debugPrint(
            "🔍 Query: menu_items where is_featured=true and is_available=true");
      }

      final response = await _supabase
          .from("menu_items")
          .select(
              "id, restaurant_id, restaurant_name, name, description, image, price, category, cuisine_type_id, category_id, cuisine_types(*), categories(*), is_available, is_featured, preparation_time, rating, review_count, variants, pricing_options, supplements, created_at, updated_at")
          .eq("is_featured", "true")
          .eq("is_available", "true")
          .order("created_at", ascending: false)
          .range(offset, offset + limit - 1);

      if (kDebugMode) debugPrint("🔍 Raw response: $response");
      if (kDebugMode) debugPrint("🔍 Response length: ${response.length}");

      final parsedItems = _parseMenuItems(response);
      if (kDebugMode) debugPrint("🔍 Parsed items: ${parsedItems.length}");

      // Cache the results
      _menuItemCache[cacheKey] = parsedItems;
      _cacheTimestamps[cacheKey] = DateTime.now();

      _logger.logUserAction(
        "featured_menu_items_retrieved",
        data: {
          "limit": limit,
          "offset": offset,
          "retrieved_count": parsedItems.length,
          "cache_key": cacheKey,
        },
      );

      _logger.endPerformanceTimer("featured_menu_items_query",
          details: "Featured menu items retrieved successfully");

      return parsedItems;
    } on Exception catch (e) {
      _logger.error(
        "Error fetching featured menu items",
        tag: "MENU_DISPLAY",
        error: e,
        additionalData: {
          "limit": limit,
          "offset": offset,
          "cache_key": cacheKey,
        },
      );

      _logger.endPerformanceTimer("featured_menu_items_query",
          details: "Featured menu items query failed");

      if (kDebugMode) debugPrint("❌ Error fetching featured menu items: $e");
      if (kDebugMode) debugPrint("❌ Error type: ${e.runtimeType}");
      return [];
    }
  }

  /// Fetch all available menu items with restaurant information
  Future<List<MenuItem>> getAllMenuItems({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      if (kDebugMode) debugPrint("🔍 Fetching all menu items...");
      if (kDebugMode) debugPrint("🔍 Query: menu_items where is_available=true");

      final response = await _supabase
          .from("menu_items")
          .select(
              "id, restaurant_id, restaurant_name, name, description, image, price, category, cuisine_type_id, category_id, cuisine_types(*), categories(*), is_available, is_featured, preparation_time, rating, review_count, variants, pricing_options, supplements, created_at, updated_at")
          .eq("is_available", "true")
          .order("created_at", ascending: false)
          .range(offset, offset + limit - 1);

      if (kDebugMode) debugPrint("🔍 Raw response: $response");
      if (kDebugMode) debugPrint("🔍 Response length: ${response.length}");

      final parsedItems = _parseMenuItems(response);
      if (kDebugMode) debugPrint("🔍 Parsed items: ${parsedItems.length}");

      return parsedItems;
    } on Exception catch (e) {
      if (kDebugMode) debugPrint("❌ Error fetching all menu items: $e");
      if (kDebugMode) debugPrint("❌ Error type: ${e.runtimeType}");
      return [];
    }
  }

  /// Fetch menu items filtered by optional minRating, priceRange (menu item price)
  /// and deliveryFeeRange (restaurant delivery_fee)
  Future<List<MenuItem>> getAllMenuItemsFiltered({
    int limit = 50,
    int offset = 0,
    double? minRating,
    RangeValues? priceRange,
    RangeValues? deliveryFeeRange,
  }) async {
    try {
      // Base fetch
      final response = await _supabase
          .from("menu_items")
          .select(
              "id, restaurant_id, restaurant_name, name, description, image, price, category, cuisine_type_id, category_id, cuisine_types(*), categories(*), is_available, is_featured, preparation_time, rating, review_count, variants, pricing_options, supplements, created_at, updated_at")
          .eq("is_available", "true")
          .order("created_at", ascending: false)
          .range(offset, offset + limit - 1);

      List<dynamic> rows = List<dynamic>.from(response as List);

      // Filter by menu item rating
      if (minRating != null) {
        rows = rows
            .where((e) => ((e["rating"] ?? 0.0).toDouble()) >= minRating)
            .toList();
      }

      // Filter by menu item price range
      if (priceRange != null) {
        final start = priceRange.start;
        final end = priceRange.end;
        rows = rows.where((e) {
          final p = (e["price"] ?? 0.0).toDouble();
          return p >= start && p <= end;
        }).toList();
      }

      // Filter by restaurant delivery fee range
      if (deliveryFeeRange != null && rows.isNotEmpty) {
        final ids = rows
            .map((e) => (e["restaurant_id"] ?? "").toString())
            .where((s) => s.isNotEmpty)
            .toSet()
            .toList();
        if (ids.isNotEmpty) {
          final rRows = await _supabase
              .from("restaurants")
              .select("id,delivery_fee")
              .inFilter("id", ids);
          final allowed = <String>{};
          for (final r in (rRows as List)) {
            final id = (r["id"] ?? "").toString();
            final fee = (r["delivery_fee"] ?? 0.0).toDouble();
            if (fee >= deliveryFeeRange.start && fee <= deliveryFeeRange.end) {
              allowed.add(id);
            }
          }
          rows = rows
              .where((e) =>
                  allowed.contains((e["restaurant_id"] ?? "").toString()))
              .toList();
        }
      }

      return _parseMenuItems(rows);
    } on Exception catch (e) {
      if (kDebugMode) debugPrint("❌ Error fetching filtered menu items: $e");
      return [];
    }
  }

  /// Fetch menu items by category
  Future<List<MenuItem>> getMenuItemsByCategory({
    required String category,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      final response = await _supabase
          .from("menu_items")
          .select("*, cuisine_types(*), categories(*)")
          .eq("category", category)
          .eq("is_available", "true")
          .order("created_at", ascending: false)
          .range(offset, offset + limit - 1);

      return _parseMenuItems(response);
    } on Exception catch (e) {
      if (kDebugMode) debugPrint("Error fetching menu items by category: $e");
      return [];
    }
  }

  /// Search menu items by name or description with smart text detection
  Future<List<MenuItem>> searchMenuItems({
    required String query,
    int limit = 20,
    int offset = 0,
  }) async {
    final cacheKey = "search_${query}_${limit}_$offset";

    try {
      // Check cache first
      if (_menuItemCache.containsKey(cacheKey)) {
        final cacheTime = _cacheTimestamps[cacheKey];
        if (cacheTime != null &&
            DateTime.now().difference(cacheTime) < _cacheDuration) {
          _logger.info("Returning cached search results",
              tag: "MENU_DISPLAY",
              additionalData: {
                "query": query,
                "cache_key": cacheKey,
                "cached_count": _menuItemCache[cacheKey]!.length,
              });
          return _menuItemCache[cacheKey]!;
        }
      }

      _logger.startPerformanceTimer("menu_search_query", metadata: {
        "query": query,
        "limit": limit,
        "offset": offset,
        "cache_key": cacheKey,
      });

      _logger.logUserAction(
        "menu_search_requested",
        data: {
          "query": query,
          "limit": limit,
          "offset": offset,
          "cache_key": cacheKey,
        },
      );

      // Generate search variations for better matching
      final searchVariations =
          SmartTextDetector.generateSearchVariations(query);
      final normalizedQuery = SmartTextDetector.normalizeText(query);

      if (kDebugMode) debugPrint('🔍 MenuItemSearch: Original query: "$query"');
      if (kDebugMode) debugPrint('🔍 MenuItemSearch: Normalized: "$normalizedQuery"');
      if (kDebugMode) debugPrint("🔍 MenuItemSearch: Variations: $searchVariations");

      // Build search conditions for all variations
      final searchConditions = <String>[];
      for (final variation in searchVariations) {
        searchConditions.add("name.ilike.%$variation%");
        searchConditions.add("description.ilike.%$variation%");
      }

      final orCondition = searchConditions.join(",");

      final response = await _supabase
          .from("menu_items")
          .select(
              "id, restaurant_id, restaurant_name, name, description, image, price, category, cuisine_type_id, category_id, cuisine_types(*), categories(*), is_available, is_featured, preparation_time, rating, review_count, variants, pricing_options, supplements, created_at, updated_at")
          .or(orCondition)
          .eq("is_available", "true")
          .order("created_at", ascending: false)
          .range(offset, offset + limit - 1);

      final results = _parseMenuItems(response);

      // Apply additional fuzzy matching for better results
      final fuzzyResults = results.where((item) {
        final itemName = item.name.toLowerCase();
        final itemDescription = item.description.toLowerCase();

        // Check if any variation is similar to the item
        for (final variation in searchVariations) {
          if (SmartTextDetector.isSimilar(variation, itemName) ||
              SmartTextDetector.isSimilar(variation, itemDescription)) {
            return true;
          }
        }

        return false;
      }).toList();

      // Combine exact matches and fuzzy matches, removing duplicates
      final allResults = <MenuItem>[];
      final seenIds = <String>{};

      // Add exact matches first
      for (final item in results) {
        if (!seenIds.contains(item.id)) {
          allResults.add(item);
          seenIds.add(item.id);
        }
      }

      // Add fuzzy matches
      for (final item in fuzzyResults) {
        if (!seenIds.contains(item.id)) {
          allResults.add(item);
          seenIds.add(item.id);
        }
      }

      // Cache the results
      _menuItemCache[cacheKey] = allResults;
      _cacheTimestamps[cacheKey] = DateTime.now();

      _logger.logUserAction(
        "menu_search_completed",
        data: {
          "query": query,
          "limit": limit,
          "offset": offset,
          "exact_matches": results.length,
          "fuzzy_matches": fuzzyResults.length,
          "total_results": allResults.length,
          "cache_key": cacheKey,
        },
      );

      _logger.endPerformanceTimer("menu_search_query",
          details: "Menu search completed successfully");

      if (kDebugMode) {
        debugPrint(
            "🔍 MenuItemSearch: Found ${allResults.length} items (${results.length} exact + ${fuzzyResults.length} fuzzy)");
      }

      return allResults;
    } on Exception catch (e) {
      _logger.error(
        "Error searching menu items",
        tag: "MENU_DISPLAY",
        error: e,
        additionalData: {
          "query": query,
          "limit": limit,
          "offset": offset,
          "cache_key": cacheKey,
        },
      );

      _logger.endPerformanceTimer("menu_search_query",
          details: "Menu search failed");

      if (kDebugMode) debugPrint("Error searching menu items: $e");
      return [];
    }
  }

  /// Get menu item by ID with restaurant information
  Future<MenuItem?> getMenuItemById(String id) async {
    try {
      final response =
          await _supabase.from("menu_items").select("*").eq("id", id).single();

      final items = _parseMenuItems([response]);
      return items.isNotEmpty ? items.first : null;
    } on Exception catch (e) {
      if (kDebugMode) debugPrint("Error fetching menu item by ID: $e");
      return null;
    }
  }

  /// Get available categories (structured categories from categories table)
  Future<List<String>> getCategories() async {
    try {
      // First try to get structured categories
      final response = await _supabase
          .from("categories")
          .select("name")
          .eq("is_active", "true")
          .order("display_order")
          .order("name");

      final categories = (response as List)
          .map((item) => (item["name"] ?? "").toString())
          .where((e) => e.isNotEmpty)
          .where((name) => !_isDrinksCategory(name)) // Filter out drinks
          .toSet()
          .toList()
        ..sort();

      if (categories.isNotEmpty) {
        return categories;
      }

      // Fallback to menu item categories if no structured categories exist
      final fallbackResponse = await _supabase
          .from("menu_items")
          .select("category")
          .eq("is_available", "true");

      final fallbackCategories = fallbackResponse
          .map((item) => item["category"] as String)
          .where((name) => !_isDrinksCategory(name)) // Filter out drinks
          .toSet()
          .toList();

      fallbackCategories.sort();
      return fallbackCategories;
    } on Exception catch (e) {
      if (kDebugMode) debugPrint("Error fetching categories: $e");
      return [];
    }
  }

  /// Get available cuisines (future-proof for cuisine column)
  Future<List<String>> getCuisines() async {
    try {
      // Fetch cuisine names from cuisine_types table (authoritative source)
      final response = await _supabase
          .from("cuisine_types")
          .select("name")
          .eq("is_active", "true")
          .order("display_order")
          .order("name");

      final cuisines = (response as List)
          .map((item) => (item["name"] ?? "").toString())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList()
        ..sort();

      return cuisines;
    } on Exception catch (e) {
      if (kDebugMode) debugPrint("Error fetching cuisines: $e");
      return [];
    }
  }

  /// Normalize helper used to compare cuisine keys
  String _normalizeKey(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r"[\s-]+"), "_")
        .replaceAll(RegExp("[^a-z0-9_]+"), "");
  }

  /// Get distinct categories limited to provided cuisines (normalized cuisine names)
  Future<List<String>> getCategoriesByCuisines(
      Set<String> normalizedCuisines) async {
    if (normalizedCuisines.isEmpty) {
      return getCategories();
    }
    try {
      // 1) Map cuisine names -> ids
      final cuisineRows = await _supabase
          .from("cuisine_types")
          .select("id,name")
          .eq("is_active", "true");

      final Map<String, String> normCuisineNameToId = {};
      for (final row in (cuisineRows as List)) {
        final name = (row["name"] ?? "").toString();
        final id = (row["id"] ?? "").toString();
        if (name.isEmpty || id.isEmpty) {
          continue;
        }
        normCuisineNameToId[_normalizeKey(name)] = id;
      }

      final List<String> cuisineIds = normalizedCuisines
          .map((n) => normCuisineNameToId[n])
          .whereType<String>()
          .toList();

      if (cuisineIds.isEmpty) {
        return [];
      }

      // 2) Get categories that belong to these cuisines from the structured categories table
      final categoryRows = await _supabase
          .from("categories")
          .select("name")
          .eq("is_active", "true")
          .inFilter("cuisine_type_id", cuisineIds);

      final categories = <String>{};
      for (final row in (categoryRows as List)) {
        final category = (row["name"] ?? "").toString();
        if (category.isNotEmpty) {
          categories.add(category);
        }
      }

      // Fallback: if no structured categories found, get from menu items
      if (categories.isEmpty) {
        final menuItemRows = await _supabase
            .from("menu_items")
            .select("category, cuisine_type_id")
            .eq("is_available", "true")
            .inFilter("cuisine_type_id", cuisineIds);

        for (final row in (menuItemRows as List)) {
          final category = (row["category"] ?? "").toString();
          if (category.isNotEmpty) {
            categories.add(category);
          }
        }
      }

      final list = categories.toList()..sort();
      return list;
    } on Exception catch (e) {
      if (kDebugMode) debugPrint("Error fetching categories by cuisines: $e");
      // Fallback to regular categories if the cuisine filtering fails
      return getCategories();
    }
  }

  /// Debug method to check database connection and table contents
  Future<void> debugDatabaseConnection() async {
    try {
      if (kDebugMode) debugPrint("🔍 Testing database connection...");

      // Test 1: Check if we can connect to menu_items table
      final countResponse = await _supabase.from("menu_items").select("id");

      if (kDebugMode) debugPrint("🔍 Total menu items in database: ${countResponse.length}");

      // Test 2: Get all menu items without restaurant join
      final allItemsResponse =
          await _supabase.from("menu_items").select("*").limit(5);

      if (kDebugMode) debugPrint("🔍 Sample menu items: $allItemsResponse");

      // Test 3: Check restaurants table
      final restaurantsResponse =
          await _supabase.from("restaurants").select("id, name").limit(3);

      if (kDebugMode) debugPrint("🔍 Sample restaurants: $restaurantsResponse");
    } on Exception catch (e) {
      if (kDebugMode) debugPrint("❌ Database connection test failed: $e");
      if (kDebugMode) debugPrint("❌ Error type: ${e.runtimeType}");
    }
  }

  /// Fallback method to get menu items without restaurant join
  Future<List<MenuItem>> getMenuItemsSimple({
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      if (kDebugMode) debugPrint("🔍 Fetching menu items (simple query)...");

      // PERFORMANCE: Select only needed fields instead of all columns
      // This reduces data transfer and improves query speed
      final response = await _supabase
          .from("menu_items")
          .select(
              "id, restaurant_id, restaurant_name, name, description, image, images, price, category, cuisine_type_id, category_id, cuisine_types(*), categories(*), is_available, is_featured, preparation_time, rating, review_count, variants, pricing_options, supplements, created_at, updated_at")
          .eq("is_available", "true")
          .order("created_at", ascending: false)
          .range(offset, offset + limit - 1);

      if (kDebugMode) debugPrint("🔍 Simple query response: $response");
      if (kDebugMode) debugPrint("🔍 Response length: ${response.length}");

      return response.map((item) {
        return MenuItem(
          id: item["id"] ?? "",
          restaurantId: item["restaurant_id"] ?? "",
          restaurantName: item["restaurant_name"],
          name: item["name"] ?? "",
          description: item["description"] ?? "",
          image: item["image"] ?? "",
          price: (item["price"] ?? 0.0).toDouble(),
          category: item["category"] ?? "",
          isAvailable: item["is_available"] ?? true,
          isFeatured: item["is_featured"] ?? false,
          preparationTime: item["preparation_time"] ?? 15,
          rating: (item["rating"] ?? 0.0).toDouble(),
          reviewCount: item["review_count"] ?? 0,
          createdAt: item["created_at"] != null
              ? DateTime.parse(item["created_at"])
              : DateTime.now(),
          updatedAt: item["updated_at"] != null
              ? DateTime.parse(item["updated_at"])
              : DateTime.now(),
        );
      }).toList();
    } on Exception catch (e) {
      if (kDebugMode) debugPrint("❌ Error in simple query: $e");
      return [];
    }
  }

  /// Get performance analytics for the service
  Map<String, dynamic> getPerformanceAnalytics() {
    final now = DateTime.now();
    final analytics = <String, dynamic>{
      "total_queries":
          _queryCounts.values.fold<int>(0, (sum, count) => sum + count),
      "active_queries": _queryCounts.length,
      "cached_items": _menuItemCache.length,
      "cache_hit_rate": _calculateCacheHitRate(),
      "service_uptime": now
          .difference(_queryStartTimes.isNotEmpty
              ? _queryStartTimes.values.reduce((a, b) => a.isBefore(b) ? a : b)
              : now)
          .inMinutes,
    };

    _logger.info("MenuItemDisplayService performance analytics",
        tag: "MENU_DISPLAY", additionalData: analytics);
    return analytics;
  }

  /// Calculate cache hit rate
  double _calculateCacheHitRate() {
    if (_queryCounts.isEmpty) {
      return 0;
    }
    final totalQueries =
        _queryCounts.values.fold<int>(0, (sum, count) => sum + count);
    final cacheHits = _menuItemCache.length;
    return totalQueries > 0 ? (cacheHits / totalQueries) * 100 : 0.0;
  }

  /// Clear performance cache
  void clearPerformanceCache() {
    _queryStartTimes.clear();
    _queryCounts.clear();
    _menuItemCache.clear();
    _cacheTimestamps.clear();
    _logger.info("MenuItemDisplayService performance cache cleared",
        tag: "MENU_DISPLAY");
  }

  /// Preload popular menu items for better performance
  Future<void> preloadPopularMenuItems() async {
    try {
      _logger.startPerformanceTimer("menu_preload");

      // Preload featured items
      await getFeaturedMenuItems(limit: 10);

      // Preload popular categories
      final categories = await getCategories();
      for (final category in categories.take(5)) {
        await getMenuItemsByCategory(category: category, limit: 10);
      }

      _logger.endPerformanceTimer("menu_preload",
          details: "Popular menu items preloaded successfully");
      _logger.info("Preloaded popular menu items", tag: "MENU_DISPLAY");
    } on Exception catch (e) {
      _logger.error("Failed to preload popular menu items",
          tag: "MENU_DISPLAY", error: e);
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStatistics() {
    final stats = <String, dynamic>{
      "total_cached_queries": _menuItemCache.length,
      "cache_size_bytes": _menuItemCache.toString().length,
      "oldest_cache_entry": _cacheTimestamps.values.isNotEmpty
          ? _cacheTimestamps.values
              .reduce((a, b) => a.isBefore(b) ? a : b)
              .toIso8601String()
          : null,
      "newest_cache_entry": _cacheTimestamps.values.isNotEmpty
          ? _cacheTimestamps.values
              .reduce((a, b) => a.isAfter(b) ? a : b)
              .toIso8601String()
          : null,
    };

    _logger.info("MenuItemDisplayService cache statistics",
        tag: "MENU_DISPLAY", additionalData: stats);
    return stats;
  }

  /// Parse menu items from query response
  List<MenuItem> _parseMenuItems(List<dynamic> response) {
    return response.map((item) {
      // Parse cuisine type if available
      CuisineType? cuisineType;
      if (item["cuisine_type_id"] != null) {
        // Handle joined cuisine type data structure
        final cuisineData = item["cuisine_types"];
        if (cuisineData != null && cuisineData is Map<String, dynamic>) {
          cuisineType = CuisineType(
            id: cuisineData["id"] ?? item["cuisine_type_id"],
            name: cuisineData["name"] ?? item["cuisine_type_name"] ?? "Unknown",
            description: cuisineData["description"] as String?,
            icon: cuisineData["icon"] as String?,
            color: cuisineData["color"] as String?,
            isActive: cuisineData["is_active"] as bool? ?? true,
            displayOrder: cuisineData["display_order"] as int? ?? 0,
            createdAt: cuisineData["created_at"] != null
                ? DateTime.parse(cuisineData["created_at"])
                : DateTime.now(),
            updatedAt: cuisineData["updated_at"] != null
                ? DateTime.parse(cuisineData["updated_at"])
                : DateTime.now(),
          );
        } else {
          // Fallback for direct cuisine type data
          cuisineType = CuisineType(
            id: item["cuisine_type_id"],
            name: item["cuisine_type_name"] ?? "Unknown",
            description: item["cuisine_type_description"] as String?,
            icon: item["cuisine_type_icon"] as String?,
            color: item["cuisine_type_color"] as String?,
            isActive: item["cuisine_type_is_active"] as bool? ?? true,
            displayOrder: item["cuisine_type_display_order"] as int? ?? 0,
            createdAt: item["cuisine_type_created_at"] != null
                ? DateTime.parse(item["cuisine_type_created_at"])
                : DateTime.now(),
            updatedAt: item["cuisine_type_updated_at"] != null
                ? DateTime.parse(item["cuisine_type_updated_at"])
                : DateTime.now(),
          );
        }
      }

      // Parse category if available
      Category? categoryObj;
      if (item["category_id"] != null) {
        // Handle joined category data structure
        final categoryData = item["categories"];
        if (categoryData != null && categoryData is Map<String, dynamic>) {
          categoryObj = Category(
            id: categoryData["id"] ?? item["category_id"],
            cuisineTypeId: categoryData["cuisine_type_id"] ?? "",
            name: categoryData["name"] ?? item["category_name"] ?? "Unknown",
            description: categoryData["description"] as String?,
            icon: categoryData["icon"] as String?,
            color: categoryData["color"] as String?,
            isActive: categoryData["is_active"] as bool? ?? true,
            displayOrder: categoryData["display_order"] as int? ?? 0,
            createdAt: categoryData["created_at"] != null
                ? DateTime.parse(categoryData["created_at"])
                : DateTime.now(),
            updatedAt: categoryData["updated_at"] != null
                ? DateTime.parse(categoryData["updated_at"])
                : DateTime.now(),
          );
        } else {
          // Fallback for direct category data
          categoryObj = Category(
            id: item["category_id"],
            cuisineTypeId: item["cuisine_type_id"] ?? "",
            name: item["category_name"] ?? "Unknown",
            description: item["category_description"] as String?,
            icon: item["category_icon"] as String?,
            color: item["category_color"] as String?,
            isActive: item["category_is_active"] as bool? ?? true,
            displayOrder: item["category_display_order"] as int? ?? 0,
            createdAt: item["category_created_at"] != null
                ? DateTime.parse(item["category_created_at"])
                : DateTime.now(),
            updatedAt: item["category_updated_at"] != null
                ? DateTime.parse(item["category_updated_at"])
                : DateTime.now(),
          );
        }
      }

      // Parse variants (JSONB array)
      List<Map<String, dynamic>> variants = [];
      if (item["variants"] != null) {
        if (item["variants"] is List) {
          variants = (item["variants"] as List)
              .map((v) => Map<String, dynamic>.from(v as Map))
              .toList();
        }
      }

      // Parse pricing options (JSONB array)
      List<Map<String, dynamic>> pricingOptions = [];
      if (item["pricing_options"] != null) {
        if (item["pricing_options"] is List) {
          pricingOptions = (item["pricing_options"] as List)
              .map((v) => Map<String, dynamic>.from(v as Map))
              .toList();
        }
      }

      // Parse supplements (JSONB array)
      List<Map<String, dynamic>> supplements = [];
      if (item["supplements"] != null) {
        if (item["supplements"] is List) {
          supplements = (item["supplements"] as List)
              .map((v) => Map<String, dynamic>.from(v as Map))
              .toList();
        }
      }

      // Parse images (JSONB array)
      List<String> images = [];
      if (item["images"] != null) {
        if (item["images"] is List) {
          images = (item["images"] as List)
              .map((img) => img.toString())
              .where((img) => img.isNotEmpty)
              .toList();
        }
      }

      // Parse ingredients (can be JSONB array or comma-separated string)
      List<String> ingredients = [];
      if (item["ingredients"] != null) {
        if (item["ingredients"] is List) {
          ingredients = (item["ingredients"] as List)
              .map((ing) => ing.toString())
              .where((ing) => ing.isNotEmpty)
              .toList();
        } else if (item["ingredients"] is String) {
          final ingredientsStr = item["ingredients"] as String;
          if (ingredientsStr.isNotEmpty) {
            ingredients = ingredientsStr
                .split(',')
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList();
          }
        }
      }

      return MenuItem(
        id: item["id"] ?? "",
        restaurantId: item["restaurant_id"] ?? "",
        restaurantName: item["restaurant_name"],
        name: item["name"] ?? "",
        description: item["description"] ?? "",
        image: item["image"] ?? "",
        images: images,
        price: (item["price"] ?? 0.0).toDouble(),
        category: item["category"] ?? "",
        cuisineTypeId: item["cuisine_type_id"],
        categoryId: item["category_id"],
        cuisineType: cuisineType,
        categoryObj: categoryObj,
        isAvailable: item["is_available"] ?? true,
        isFeatured: item["is_featured"] ?? false,
        preparationTime: item["preparation_time"] ?? 15,
        rating: (item["rating"] ?? 0.0).toDouble(),
        reviewCount: item["review_count"] ?? 0,
        mainIngredients: item["main_ingredients"] as String?,
        ingredients: ingredients,
        isSpicy: item["is_spicy"] as bool? ?? false,
        spiceLevel: item["spice_level"] as int? ?? 0,
        isTraditional: item["is_traditional"] as bool? ?? false,
        isVegetarian: item["is_vegetarian"] as bool? ?? false,
        isVegan: item["is_vegan"] as bool? ?? false,
        isGlutenFree: item["is_gluten_free"] as bool? ?? false,
        isDairyFree: item["is_dairy_free"] as bool? ?? false,
        isLowSodium: item["is_low_sodium"] as bool? ?? false,
        variants: variants,
        pricingOptions: pricingOptions,
        supplements: supplements,
        calories: item["calories"] as int?,
        protein: (item["protein"] as num?)?.toDouble(),
        carbs: (item["carbs"] as num?)?.toDouble(),
        fat: (item["fat"] as num?)?.toDouble(),
        fiber: (item["fiber"] as num?)?.toDouble(),
        sugar: (item["sugar"] as num?)?.toDouble(),
        createdAt: item["created_at"] != null
            ? DateTime.parse(item["created_at"])
            : DateTime.now(),
        updatedAt: item["updated_at"] != null
            ? DateTime.parse(item["updated_at"])
            : DateTime.now(),
      );
    }).toList();
  }

  /// Check if a category is a drinks/beverages category that should be hidden
  bool _isDrinksCategory(String categoryName) {
    final lowerName = categoryName.toLowerCase();
    return lowerName.contains("poissons") ||
        lowerName.contains("drinks") ||
        lowerName.contains("beverages") ||
        lowerName.contains("boissons");
  }

  /// Comprehensive method to fetch menu items with intelligent fallback strategy
  /// This method implements a multi-stage fallback pipeline for maximum reliability
  Future<List<MenuItem>> getMenuItemsWithFallback({
    Set<String>? selectedCategories,
    Set<String>? selectedCuisines,
    String? searchQuery,
    RangeValues? priceRange,
    int limit = 20,
  }) async {
    final cacheKey =
        'fallback_${selectedCategories?.join(',') ?? ''}_${selectedCuisines?.join(',') ?? ''}_${searchQuery ?? ''}_${priceRange?.start ?? ''}_${priceRange?.end ?? ''}';

    try {
      _logger.startPerformanceTimer('menu_items_fallback_query',
          metadata: {'cache_key': cacheKey});

      List<MenuItem> items = [];

      // Stage 1: Try filtered query based on active filters
      if (priceRange != null) {
        if (kDebugMode) {
          debugPrint(
              '🔍 Stage 1: Loading menu items with price range filter: ${priceRange.start} - ${priceRange.end}');
        }
        items = await getAllMenuItemsFiltered(
          limit: limit,
          priceRange: priceRange,
        );
        if (kDebugMode) {
          debugPrint('🔍 Stage 1 result: ${items.length} items');
        }
      } else if (searchQuery != null && searchQuery.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
              '🔍 Stage 1: Searching menu items with query: "$searchQuery"');
        }
        items = await searchMenuItems(
          query: searchQuery,
          limit: limit,
        );
        if (kDebugMode) {
          debugPrint('🔍 Stage 1 result: ${items.length} items');
        }
      } else {
        if (kDebugMode) {
          debugPrint('🔍 Stage 1: Loading all available menu items');
        }
        items = await getAllMenuItems(limit: limit);
        if (kDebugMode) {
          debugPrint('🔍 Stage 1 result: ${items.length} items');
        }
      }

      // Stage 2: If no items found, try with category filter only
      if (items.isEmpty &&
          selectedCategories != null &&
          selectedCategories.isNotEmpty) {
        if (kDebugMode) {
          debugPrint(
              '🔍 Stage 2: No items found, trying with category filter: $selectedCategories');
        }
        for (final category in selectedCategories) {
          final categoryItems = await getMenuItemsByCategory(
            category: category,
            limit: limit,
          );
          items.addAll(categoryItems);
        }
        if (kDebugMode) {
          debugPrint('🔍 Stage 2 result: ${items.length} items');
        }
      }

      // Stage 3: If still no items, try simple query (no joins)
      if (items.isEmpty) {
        if (kDebugMode) {
          debugPrint(
              '🔍 Stage 3: No items with filters, trying simple query without joins');
        }
        items = await getMenuItemsSimple(limit: limit);
        if (kDebugMode) {
          debugPrint('🔍 Stage 3 result: ${items.length} items');
        }
      }

      // Stage 4: If still no items, try featured items
      if (items.isEmpty) {
        if (kDebugMode) {
          debugPrint(
              '🔍 Stage 4: No items found, trying featured items as fallback');
        }
        items = await getFeaturedMenuItems(limit: limit);
        if (kDebugMode) {
          debugPrint('🔍 Stage 4 result: ${items.length} items');
        }
      }

      // Stage 5: Final fallback - direct unfiltered query
      if (items.isEmpty) {
        if (kDebugMode) {
          debugPrint(
              '🔍 Stage 5: No items found with any method, trying direct unfiltered query');
        }
        try {
          // PERFORMANCE: Select only needed fields instead of all columns
          // This reduces data transfer and improves query speed
          final response = await _supabase
              .from('menu_items')
              .select(
                  'id, restaurant_id, restaurant_name, name, description, image, images, price, category, cuisine_type_id, category_id, cuisine_types(*), categories(*), is_available, is_featured, preparation_time, rating, review_count, variants, pricing_options, supplements, created_at, updated_at')
              .limit(10);
          items = _parseMenuItems(response);
          if (kDebugMode) {
            debugPrint('🔍 Stage 5 result: ${items.length} items');
          }
        } catch (e) {
          if (kDebugMode) {
            debugPrint('❌ Stage 5 failed: $e');
          }
        }
      }

      _logger.endPerformanceTimer('menu_items_fallback_query',
          details:
              'Menu items loaded successfully with fallback (${items.length} items)');

      if (kDebugMode) {
        debugPrint(
            '✅ MenuItemDisplayService: Final result: ${items.length} menu items');
      }

      return items;
    } catch (e) {
      _logger.error(
        'Error in getMenuItemsWithFallback',
        tag: 'MENU_DISPLAY',
        error: e,
        additionalData: {'cache_key': cacheKey},
      );
      if (kDebugMode) debugPrint('❌ Error in getMenuItemsWithFallback: $e');
      return [];
    }
  }
}
