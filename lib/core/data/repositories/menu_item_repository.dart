import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/menu_item.dart';
import '../../json/json_parse.dart';
import '../cache/disk_cache.dart';
import '../cache/memory_cache.dart';
import '../repository_base.dart';
import '../request_dedupe.dart';

/// Repository for menu items with 3-tier caching
class MenuItemRepository extends RepositoryBase<String, MenuItem> {
  final SupabaseClient _supabase;

  // List query cache (separate from item cache)
  final MemoryCache<String, List<MenuItem>> _listCache;
  final DiskCache<String, List<MenuItem>> _listDiskCache;
  final RequestDedupe<String, List<MenuItem>> _listDedupe;

  MenuItemRepository({
    Duration? memoryTtl,
    Duration? diskTtl,
    int? maxMemorySize,
    SupabaseClient? supabaseClient,
  })  : _supabase = supabaseClient ?? Supabase.instance.client,
        _listCache = MemoryCache<String, List<MenuItem>>(
          defaultTtl: memoryTtl ?? const Duration(minutes: 15),
          maxSize: maxMemorySize ?? 50, // Cache up to 50 list queries
        ),
        _listDiskCache = DiskCache<String, List<MenuItem>>(
          defaultTtl: diskTtl ?? const Duration(hours: 12),
        ),
        _listDedupe = RequestDedupe<String, List<MenuItem>>(),
        super(
          memoryTtl: memoryTtl ?? const Duration(minutes: 15),
          diskTtl: diskTtl ?? const Duration(hours: 12),
          maxMemorySize: maxMemorySize ?? 500,
        );

  // Helper for unawaited futures
  void _unawaited(Future<void> future) {
    // Ignore future completion
  }

  @override
  Future<MenuItem> fetchFromNetwork(String key) async {
    try {
      // PERFORMANCE: Select only needed fields instead of all columns
      // This reduces data transfer and improves query speed
      final response = await _supabase
          .from('menu_items')
          .select(
              'id, restaurant_id, restaurant_name, name, description, image, images, price, category, cuisine_type_id, category_id, cuisine_types(*), categories(*), is_available, is_featured, preparation_time, rating, review_count, variants, pricing_options, supplements, created_at, updated_at')
          .eq('id', key)
          .single();

      return fromJson(Map<String, dynamic>.from(response));
    } catch (e) {
      debugPrint('Error fetching menu item $key from network: $e');
      rethrow;
    }
  }

  @override
  Map<String, dynamic> toJson(MenuItem value) {
    // Use MenuItem's toJson if available
    try {
      return value.toJson();
    } catch (e) {
      // Fallback to manual conversion
      return {
        'id': value.id,
        'restaurant_id': value.restaurantId,
        'restaurant_name': value.restaurantName,
        'name': value.name,
        'description': value.description,
        'image': value.image,
        'images': value.images,
        'price': value.price,
        'category': value.category,
        'cuisine_type_id': value.cuisineTypeId,
        'category_id': value.categoryId,
        'is_available': value.isAvailable,
        'is_featured': value.isFeatured,
        'preparation_time': value.preparationTime,
        'rating': value.rating,
        'review_count': value.reviewCount,
        'created_at': value.createdAt.toIso8601String(),
        'updated_at': value.updatedAt.toIso8601String(),
        'variants': value.variants,
        'pricing_options': value.pricingOptions,
        'supplements': value.supplements,
      };
    }
  }

  @override
  MenuItem fromJson(Map<String, dynamic> json) {
    return MenuItem.fromJson(json);
  }

  /// Get menu items by restaurant with 3-tier caching and request deduplication
  Future<List<MenuItem>> getByRestaurant(
    String restaurantId, {
    int offset = 0,
    int limit = 50,
    bool forceRefresh = false,
  }) async {
    // Create cache key for list query
    final cacheKey = 'restaurant:$restaurantId:offset:$offset:limit:$limit';

    // PERF: Use request deduplication to prevent duplicate concurrent requests
    return _listDedupe.execute(cacheKey, () async {
      // Tier 1: Memory cache
      if (!forceRefresh) {
        final memValue = _listCache.get(cacheKey);
        if (memValue != null) {
          // Return immediately, refresh in background (stale-while-revalidate)
          _unawaited(
              _refreshListInBackground(cacheKey, restaurantId, offset, limit));
          return memValue;
        }
      }

      // Tier 2: Disk cache
      if (!forceRefresh) {
        final diskValue = await _listDiskCache.get(cacheKey, _listFromJson);
        if (diskValue != null) {
          // Return immediately (stale), refresh in background
          _listCache.put(cacheKey, diskValue);
          _unawaited(
              _refreshListInBackground(cacheKey, restaurantId, offset, limit));
          return diskValue;
        }
      }

      // Tier 3: Network
      return _fetchListFromNetwork(cacheKey, restaurantId, offset, limit);
    });
  }

  /// Fetch list from network
  Future<List<MenuItem>> _fetchListFromNetwork(
    String cacheKey,
    String restaurantId,
    int offset,
    int limit,
  ) async {
    try {
      final stopwatch = Stopwatch()..start();

      // PERFORMANCE: Select only needed fields instead of all columns
      // This reduces data transfer and improves query speed
      final response = await _supabase
          .from('menu_items')
          .select(
              'id, restaurant_id, restaurant_name, name, description, image, images, price, category, cuisine_type_id, category_id, cuisine_types(*), categories(*), is_available, is_featured, preparation_time, rating, review_count, variants, pricing_options, supplements, created_at, updated_at')
          .eq('restaurant_id', restaurantId)
          .order('category')
          .range(offset, offset + limit - 1);

      stopwatch.stop();
      debugPrint('⏱️ Network fetch took ${stopwatch.elapsedMilliseconds}ms');

      // PERF: Parse in isolate for large lists to avoid blocking UI thread
      final responseList = response as List;

      // Parse items in isolate
      final parsedItems = await JsonParse.parseListFromDecoded(
        responseList,
        MenuItem.fromJson,
      );

      // Filter and cache items
      final validItems = <MenuItem>[];
      for (final item in parsedItems) {
        try {
          // Only include items with valid images
          if (item.image.isNotEmpty) {
            validItems.add(item);
            // Cache each menu item individually
            _unawaited(cacheItem(item.id, item));
          } else {
            debugPrint('⚠️ Skipping menu item with empty image: ${item.id}');
          }
        } catch (e) {
          debugPrint('⚠️ Skipping menu item due to error: $e');
        }
      }

      // Update expired LTO items to unavailable in database
      await _updateExpiredLTOItems(validItems);

      // Cache the list result
      _listCache.put(cacheKey, validItems);
      await _listDiskCache.put(cacheKey, validItems, _listToJson);

      debugPrint('✅ Parsed ${validItems.length} menu items in isolate');
      return validItems;
    } catch (e) {
      debugPrint(
          '❌ Error fetching menu items for restaurant $restaurantId: $e');
      return [];
    }
  }

  /// Refresh list in background (stale-while-revalidate)
  Future<void> _refreshListInBackground(
    String cacheKey,
    String restaurantId,
    int offset,
    int limit,
  ) async {
    try {
      await _fetchListFromNetwork(cacheKey, restaurantId, offset, limit);
      // Cache already updated in _fetchListFromNetwork
      debugPrint('🔄 Background refresh completed for $cacheKey');
    } catch (e) {
      // Ignore background refresh errors
      debugPrint('⚠️ Background refresh failed for $cacheKey: $e');
    }
  }

  /// Convert list to JSON for disk cache
  Map<String, dynamic> _listToJson(List<MenuItem> items) {
    return {
      'items': items.map((item) => toJson(item)).toList(),
    };
  }

  /// Convert list from JSON for disk cache
  List<MenuItem> _listFromJson(Map<String, dynamic> json) {
    final items = json['items'] as List? ?? [];
    return items.map((item) => fromJson(item as Map<String, dynamic>)).toList();
  }

  /// Get menu items by category
  Future<List<MenuItem>> getByCategory(
    String category, {
    int offset = 0,
    int limit = 50,
  }) async {
    try {
      // PERFORMANCE: Select only needed fields instead of all columns
      // This reduces data transfer and improves query speed
      final response = await _supabase
          .from('menu_items')
          .select(
              'id, restaurant_id, restaurant_name, name, description, image, images, price, category, cuisine_type_id, category_id, cuisine_types(*), categories(*), is_available, is_featured, preparation_time, rating, review_count, variants, pricing_options, supplements, created_at, updated_at')
          .eq('category', category)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      // Parse items and handle missing images gracefully
      final menuItems = <MenuItem>[];
      for (final json in (response as List)) {
        try {
          final item = MenuItem.fromJson(json as Map<String, dynamic>);
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
      // Update expired LTO items to unavailable in database
      await _updateExpiredLTOItems(menuItems);

      return menuItems;
    } catch (e) {
      debugPrint('Error fetching menu items for category $category: $e');
      return [];
    }
  }

  /// Get drinks by restaurant with 3-tier caching and request deduplication
  /// This method is optimized for the free drinks controller widget
  Future<List<MenuItem>> getDrinksByRestaurant(
    String restaurantId, {
    bool forceRefresh = false,
  }) async {
    // Create cache key for drinks query
    final cacheKey = 'drinks:$restaurantId';

    // PERF: Use request deduplication to prevent duplicate concurrent requests
    return _listDedupe.execute(cacheKey, () async {
      // Tier 1: Memory cache
      if (!forceRefresh) {
        final memValue = _listCache.get(cacheKey);
        if (memValue != null) {
          // Return immediately, refresh in background (stale-while-revalidate)
          _unawaited(_refreshDrinksInBackground(cacheKey, restaurantId));
          return memValue;
        }
      }

      // Tier 2: Disk cache
      if (!forceRefresh) {
        final diskValue = await _listDiskCache.get(cacheKey, _listFromJson);
        if (diskValue != null) {
          // Return immediately (stale), refresh in background
          _listCache.put(cacheKey, diskValue);
          _unawaited(_refreshDrinksInBackground(cacheKey, restaurantId));
          return diskValue;
        }
      }

      // Tier 3: Network
      return _fetchDrinksFromNetwork(cacheKey, restaurantId);
    });
  }

  /// Fetch drinks from network
  Future<List<MenuItem>> _fetchDrinksFromNetwork(
    String cacheKey,
    String restaurantId,
  ) async {
    try {
      final stopwatch = Stopwatch()..start();

      // PERF: Query drinks with optimized select fields
      final response = await _supabase
          .from('menu_items')
          .select(
              'id, name, image, price, restaurant_id, description, category, is_available, is_featured, preparation_time, rating, review_count, created_at, updated_at')
          .eq('restaurant_id', restaurantId)
          .eq('is_available', true)
          .or('category.ilike.%drink%,category.ilike.%beverage%')
          .order('name');

      stopwatch.stop();
      debugPrint(
          '⏱️ Network fetch for drinks took ${stopwatch.elapsedMilliseconds}ms');

      // PERF: Parse in isolate for large lists to avoid blocking UI thread
      final responseList = response as List;

      // Parse items in isolate
      final parsedItems = await JsonParse.parseListFromDecoded(
        responseList,
        (json) {
          try {
            // Ensure required fields have defaults
            final drinkData = Map<String, dynamic>.from(json);
            drinkData['restaurant_id'] =
                drinkData['restaurant_id'] ?? restaurantId;
            drinkData['description'] = drinkData['description'] ?? '';
            drinkData['category'] = drinkData['category'] ?? 'Drink';
            drinkData['is_available'] = drinkData['is_available'] ?? true;
            drinkData['is_featured'] = drinkData['is_featured'] ?? false;
            drinkData['preparation_time'] = drinkData['preparation_time'] ?? 0;
            drinkData['rating'] = drinkData['rating'] ?? 0.0;
            drinkData['review_count'] = drinkData['review_count'] ?? 0;
            drinkData['created_at'] =
                drinkData['created_at'] ?? DateTime.now().toIso8601String();
            drinkData['updated_at'] =
                drinkData['updated_at'] ?? DateTime.now().toIso8601String();
            drinkData['images'] = drinkData['images'] ?? [];
            drinkData['variants'] = drinkData['variants'] ?? [];
            drinkData['pricing_options'] = drinkData['pricing_options'] ?? [];
            drinkData['supplements'] = drinkData['supplements'] ?? [];
            drinkData['ingredients'] = drinkData['ingredients'] ?? [];
            drinkData['offer_types'] = drinkData['offer_types'] ?? [];
            drinkData['offer_details'] = drinkData['offer_details'] ?? {};

            return MenuItem.fromJson(drinkData);
          } catch (e) {
            debugPrint('❌ Error parsing drink: $e');
            debugPrint('   Drink data: $json');
            return null;
          }
        },
      );

      // Filter out null items (from parsing errors)
      final validItems = parsedItems.whereType<MenuItem>().toList();

      // Cache each menu item individually
      for (final item in validItems) {
        _unawaited(cacheItem(item.id, item));
      }

      // Cache the list result
      _listCache.put(cacheKey, validItems);
      await _listDiskCache.put(cacheKey, validItems, _listToJson);

      debugPrint('✅ Parsed ${validItems.length} drinks in isolate');
      return validItems;
    } catch (e) {
      debugPrint('❌ Error fetching drinks for restaurant $restaurantId: $e');
      return [];
    }
  }

  /// Refresh drinks in background (stale-while-revalidate)
  Future<void> _refreshDrinksInBackground(
    String cacheKey,
    String restaurantId,
  ) async {
    try {
      await _fetchDrinksFromNetwork(cacheKey, restaurantId);
      // Cache already updated in _fetchDrinksFromNetwork
      debugPrint('🔄 Background refresh completed for $cacheKey');
    } catch (e) {
      // Ignore background refresh errors
      debugPrint('⚠️ Background refresh failed for $cacheKey: $e');
    }
  }

  /// Get menu item names by IDs (batch query for drink names)
  /// This fixes the N+1 query pattern in _loadDrinkNames
  /// Returns a map of item ID to name
  Future<Map<String, String>> getMenuItemsNamesByIds(
    List<String> itemIds, {
    bool forceRefresh = false,
  }) async {
    if (itemIds.isEmpty) return {};

    // PERF: Check individual item cache first (from RepositoryBase)
    final cachedNames = <String, String>{};
    final uncachedIds = <String>[];

    for (final id in itemIds) {
      try {
        // Try to get from individual item cache first
        final cachedResult = await get(id, forceRefresh: forceRefresh);
        cachedNames[id] = cachedResult.data.name;
      } catch (e) {
        // Item not found in cache, add to uncached list
        uncachedIds.add(id);
      }
    }

    // If all items are cached, return immediately
    if (uncachedIds.isEmpty) {
      return cachedNames;
    }

    // PERF: Batch query uncached items from network (fixes N+1 pattern)
    try {
      final response = await _supabase
          .from('menu_items')
          .select('id, name')
          .inFilter('id', uncachedIds);

      final items = <String, String>{};
      for (final json in (response as List)) {
        try {
          final id = json['id'] as String? ?? '';
          final name = json['name'] as String? ?? '';
          if (id.isNotEmpty && name.isNotEmpty) {
            items[id] = name;
          }
        } catch (e) {
          debugPrint('⚠️ Error parsing menu item for name lookup: $e');
        }
      }

      // Merge cached and fetched items
      cachedNames.addAll(items);
      return cachedNames;
    } catch (e) {
      debugPrint('❌ Error fetching menu items by IDs: $e');
      return cachedNames; // Return cached items even if fetch fails
    }
  }

  /// Check and update expired LTO items to unavailable in database
  /// This runs automatically when menu items are loaded
  Future<void> _updateExpiredLTOItems(List<MenuItem> items) async {
    try {
      final now = DateTime.now();
      final expiredItems = <MenuItem>[];

      // Find all expired LTO items that are still marked as available
      for (final item in items) {
        if (item.hasExpiredLTOOffer &&
            !item.isOfferActive &&
            item.isAvailable) {
          expiredItems.add(item);
        }
      }

      // Update expired items to unavailable in database
      if (expiredItems.isNotEmpty) {
        debugPrint(
            '🔄 Updating ${expiredItems.length} expired LTO items to unavailable');

        for (final item in expiredItems) {
          try {
            await _supabase.from('menu_items').update({
              'is_available': false,
              'updated_at': now.toIso8601String(),
            }).eq('id', item.id);

            debugPrint('✅ Updated expired LTO item: ${item.name} (${item.id})');
          } catch (e) {
            debugPrint('❌ Failed to update expired LTO item ${item.id}: $e');
          }
        }
      }
    } catch (e) {
      debugPrint('❌ Error updating expired LTO items: $e');
    }
  }
}
