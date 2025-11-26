import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/menu_item.dart';
import '../utils/logger.dart';
import 'info_service.dart';
import 'logging_service.dart';
// Redis optimized service removed

/// Custom exceptions for better error handling
class MenuItemServiceException implements Exception {
  final String message;
  final dynamic originalError;

  MenuItemServiceException(this.message, {this.originalError});

  @override
  String toString() => 'MenuItemServiceException: $message';
}

class MenuItemCreationException extends MenuItemServiceException {
  MenuItemCreationException(super.message, {super.originalError});
}

/// Filters for menu item queries
class MenuItemFilters {
  final String? restaurantId;
  final String? category;
  final bool? isAvailable;
  final bool? isFeatured;
  final double? minPrice;
  final double? maxPrice;
  final String? searchQuery;

  MenuItemFilters({
    this.restaurantId,
    this.category,
    this.isAvailable,
    this.isFeatured,
    this.minPrice,
    this.maxPrice,
    this.searchQuery,
  });
}

/// Result class for paginated menu item queries
class MenuItemListResult {
  final List<MenuItem> menuItems;
  final String? nextCursor;
  final int totalCount;

  MenuItemListResult({
    required this.menuItems,
    required this.totalCount,
    this.nextCursor,
  });
}

/// Service for managing menu items
class MenuItemService extends ChangeNotifier {
  SupabaseClient get _supabase => Supabase.instance.client;

  // Logging service for business metrics and performance tracking
  final LoggingService _logger = LoggingService();

  // Cache for menu items
  final Map<String, MenuItem> _menuItemCache = {};
  final Map<String, DateTime> _menuItemCacheTimestamps = {};
  final Map<String, MenuItemListResult> _listCache = {};
  final Map<String, DateTime> _listCacheTimestamps = {};

  // Cache duration (5 minutes)
  static const Duration _cacheDuration = Duration(minutes: 5);

  // Performance tracking
  final Map<String, DateTime> _operationStartTimes = {};
  final Map<String, int> _operationCounts = {};

  /// Initialize service and start realtime subscriptions
  Future<void> initialize() async {
    try {
      _logger.startPerformanceTimer('menu_item_service_init');
      Logger.info('Initializing MenuItemService');

      // Start realtime subscription
      _subscribeToRealtime();

      _logger.endPerformanceTimer('menu_item_service_init',
          details: 'MenuItemService initialized successfully');
      Logger.info('MenuItemService initialized successfully');
      _logger.info('MenuItemService initialized', tag: 'MENU_ITEM');
    } catch (e) {
      _logger.error('Failed to initialize MenuItemService',
          tag: 'MENU_ITEM', error: e);
      Logger.error('Failed to initialize MenuItemService: $e');
      rethrow;
    }
  }

  /// Subscribe to realtime updates for menu items
  void _subscribeToRealtime() {
    try {
      _supabase
          .channel('menu_items_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'menu_items',
            callback: (payload) {
              Logger.info('Menu item realtime update: ${payload.eventType}');

              // Clear relevant caches
              clearCache();
            },
          )
          .subscribe();

      Logger.info('Subscribed to menu items realtime updates');
    } catch (e) {
      Logger.error('Failed to subscribe to menu items realtime updates');
    }
  }

  /// Get menu item by ID
  Future<MenuItem?> getMenuItemById(String id,
      {bool forceRefresh = false}) async {
    try {
      // PERF: Check cache first (skip if forceRefresh)
      if (!forceRefresh && _menuItemCache.containsKey(id)) {
        final cacheTime = _menuItemCacheTimestamps[id];
        if (cacheTime != null &&
            DateTime.now().difference(cacheTime) < _cacheDuration) {
          return _menuItemCache[id];
        }
      }

      Logger.info('Fetching menu item by ID: $id');

      // Build query with restaurant join
      final response = await _supabase.from('menu_items').select('''
            *,
            restaurant:restaurants(id, name, phone, email, rating, logo_url)
          ''').eq('id', id).single();

      // Overlay via InfoService to avoid null display fields
      if (response.isNotEmpty) {
        final info = await InfoService().getEntity(
          namespace: 'lo9ma',
          entity: 'menu_item',
          entityId: id,
        );
        final merged = InfoService().overlayStrings(
          target: Map<String, dynamic>.from(response),
          info: info,
          keys: ['name', 'description', 'image', 'category'],
        );
        final menuItem = MenuItem.fromJson(merged);
        // Cache the result
        _menuItemCache[id] = menuItem;
        _menuItemCacheTimestamps[id] = DateTime.now();

        Logger.info('Successfully fetched menu item: $id');
        return menuItem;
      }

      final menuItem = MenuItem.fromJson(response);

      // Cache the result
      _menuItemCache[id] = menuItem;
      _menuItemCacheTimestamps[id] = DateTime.now();

      Logger.info('Successfully fetched menu item: $id');
      return menuItem;
    } catch (e) {
      Logger.error('Error fetching menu item by ID: $e');
      return null;
    }
  }

  /// List menu items with filters and pagination
  Future<MenuItemListResult> listMenuItems({
    MenuItemFilters? filters,
    int limit = 20,
    String? cursor,
  }) async {
    try {
      // Create cache key
      final cacheKey =
          '${filters?.toString() ?? 'all'}_${limit}_${cursor ?? 'start'}';

      // Check cache first
      if (_listCache.containsKey(cacheKey)) {
        final cacheTime = _listCacheTimestamps[cacheKey];
        if (cacheTime != null &&
            DateTime.now().difference(cacheTime) < _cacheDuration) {
          return _listCache[cacheKey]!;
        }
      }

      Logger.info('Listing menu items with filters: $filters, limit: $limit');

      // PERFORMANCE: Select only needed fields instead of all columns
      // This reduces data transfer and improves query speed
      var query = _supabase.from('menu_items').select(
          'id, restaurant_id, restaurant_name, name, description, image, images, price, category, cuisine_type_id, category_id, cuisine_types(*), categories(*), is_available, is_featured, preparation_time, rating, review_count, variants, pricing_options, supplements, created_at, updated_at');

      // Apply filters
      if (filters != null) {
        if (filters.restaurantId != null) {
          query = query.eq('restaurant_id', filters.restaurantId!);
        }
        if (filters.category != null) {
          query = query.eq('category', filters.category!);
        }
        if (filters.isAvailable != null) {
          query = query.eq('is_available', filters.isAvailable!);
        }
        if (filters.isFeatured != null) {
          query = query.eq('is_featured', filters.isFeatured!);
        }
        if (filters.minPrice != null) {
          query = query.gte('price', filters.minPrice!);
        }
        if (filters.maxPrice != null) {
          query = query.lte('price', filters.maxPrice!);
        }
        if (filters.searchQuery != null && filters.searchQuery!.isNotEmpty) {
          query = query.or(
              'name.ilike.%${filters.searchQuery}%,description.ilike.%${filters.searchQuery}%');
        }
      }

      // Apply ordering and pagination
      final orderedQuery = query.order('created_at', ascending: false);
      final limitedQuery = orderedQuery.limit(limit);

      final finalQuery = cursor != null
          ? query
              .gt('created_at', cursor)
              .order('created_at', ascending: false)
              .limit(limit)
          : limitedQuery;

      final response = await finalQuery;
      final List<MenuItem> menuItems = [];

      // PERFORMANCE: Batch fetch all InfoService data in parallel
      final List<Map<String, dynamic>> itemsData = [];
      final List<String?> itemIds = [];

      for (final item in (response as List)) {
        final map = Map<String, dynamic>.from(item);
        itemsData.add(map);
        itemIds.add(map['id']?.toString());
      }

      // Parallel fetch all InfoService data
      final infoFutures = itemIds.map((id) {
        if (id != null) {
          return InfoService()
              .getEntity(
            namespace: 'lo9ma',
            entity: 'menu_item',
            entityId: id,
          )
              .catchError((e) {
            if (kDebugMode) {
              debugPrint('InfoService error for menu_item $id: $e');
            }
            return <String, dynamic>{};
          });
        } else {
          return Future.value(<String, dynamic>{});
        }
      }).toList();

      final infoResults = await Future.wait(infoFutures);

      // Merge InfoService data with menu items
      for (int i = 0; i < itemsData.length; i++) {
        final map = itemsData[i];
        final info = infoResults[i];

        try {
          final merged = InfoService().overlayStrings(
            target: map,
            info: info,
            keys: ['name', 'description', 'image', 'category'],
          );
          final menuItem = MenuItem.fromJson(merged);
          // Only add items with valid images
          if (menuItem.image.isNotEmpty) {
            menuItems.add(menuItem);
          } else {
            if (kDebugMode) {
              final itemId = map['id']?.toString() ?? 'unknown';
              debugPrint('⚠️ Skipping menu item with empty image: $itemId');
            }
          }
        } catch (e) {
          // Skip items that can't be parsed (e.g., missing required fields like image)
          if (kDebugMode) {
            final itemId = map['id']?.toString() ?? 'unknown';
            debugPrint('⚠️ Skipping menu item due to parsing error: $e');
            debugPrint('   Item ID: $itemId');
          }
        }
      }

      // Cache individual menu items
      for (final menuItem in menuItems) {
        _menuItemCache[menuItem.id] = menuItem;
        _menuItemCacheTimestamps[menuItem.id] = DateTime.now();
      }

      // Get total count for pagination
      int totalCount = 0;
      try {
        final countResponse = await _supabase.from('menu_items').select('id');
        totalCount = countResponse.length;
      } catch (e) {
        Logger.error('Failed to get total count');
        totalCount = menuItems.length;
      }

      // Determine next cursor
      String? nextCursor;
      if (menuItems.length == limit && menuItems.isNotEmpty) {
        nextCursor = menuItems.last.createdAt.toIso8601String();
      }

      final result = MenuItemListResult(
        menuItems: menuItems,
        nextCursor: nextCursor,
        totalCount: totalCount,
      );

      // Cache the result
      _listCache[cacheKey] = result;
      _listCacheTimestamps[cacheKey] = DateTime.now();

      Logger.info('Successfully listed ${menuItems.length} menu items');
      return result;
    } catch (e) {
      Logger.error('Failed to list menu items');
      throw MenuItemServiceException('Failed to list menu items: $e',
          originalError: e);
    }
  }

  /// Get menu items by restaurant with full related data
  /// OPTIMIZED: Batch fetches all related data instead of sequential queries
  Future<List<MenuItem>> getMenuItemsByRestaurant(String restaurantId) async {
    try {
      final stopwatch = Stopwatch()..start();

      // Fetch menu items first
      final result = await listMenuItems(
        filters: MenuItemFilters(restaurantId: restaurantId),
        limit: 100,
      );

      if (result.menuItems.isEmpty) {
        return [];
      }

      // Extract menu item IDs for batch queries
      final menuItemIds = result.menuItems.map((item) => item.id).toList();

      // PERFORMANCE: Batch fetch all related data in parallel (3 queries instead of N*3)
      final relatedDataResults = await Future.wait([
        // Batch fetch all variants for all menu items
        _supabase
            .from('menu_item_variants')
            .select('*')
            .inFilter('menu_item_id', menuItemIds)
            .order('menu_item_id')
            .order('display_order'),
        // Batch fetch all pricing options for all menu items
        _supabase
            .from('menu_item_pricing')
            .select('*')
            .inFilter('menu_item_id', menuItemIds)
            .order('menu_item_id')
            .order('display_order'),
        // Batch fetch all supplements for all menu items
        _supabase
            .from('menu_item_supplements')
            .select('*')
            .inFilter('menu_item_id', menuItemIds)
            .order('menu_item_id')
            .order('display_order'),
      ]);

      // Parse responses
      final allVariants =
          (relatedDataResults[0] as List).cast<Map<String, dynamic>>();
      final allPricing =
          (relatedDataResults[1] as List).cast<Map<String, dynamic>>();
      final allSupplements =
          (relatedDataResults[2] as List).cast<Map<String, dynamic>>();

      // Group related data by menu_item_id for efficient lookup
      final variantsByMenuItem = <String, List<Map<String, dynamic>>>{};
      final pricingByMenuItem = <String, List<Map<String, dynamic>>>{};
      final supplementsByMenuItem = <String, List<Map<String, dynamic>>>{};

      for (final variant in allVariants) {
        final menuItemId = variant['menu_item_id'] as String;
        variantsByMenuItem.putIfAbsent(menuItemId, () => []).add(variant);
      }

      for (final pricing in allPricing) {
        final menuItemId = pricing['menu_item_id'] as String;
        pricingByMenuItem.putIfAbsent(menuItemId, () => []).add(pricing);
      }

      for (final supplement in allSupplements) {
        final menuItemId = supplement['menu_item_id'] as String;
        supplementsByMenuItem.putIfAbsent(menuItemId, () => []).add(supplement);
      }

      // Enrich menu items with pre-fetched related data
      final enrichedItems = result.menuItems.map((item) {
        return item.copyWith(
          variants: variantsByMenuItem[item.id] ?? [],
          pricingOptions: pricingByMenuItem[item.id] ?? [],
          supplements: supplementsByMenuItem[item.id] ?? [],
        );
      }).toList();

      stopwatch.stop();
      if (kDebugMode) {
        debugPrint(
            '⚡ Batch enriched ${enrichedItems.length} menu items in ${stopwatch.elapsedMilliseconds}ms (was ~${enrichedItems.length * 3} sequential queries)');
      }

      return enrichedItems;
    } catch (e) {
      Logger.error('Failed to get menu items by restaurant: $restaurantId');
      if (kDebugMode) {
        debugPrint('❌ Error in getMenuItemsByRestaurant: $e');
      }
      return [];
    }
  }

  /// Enrich a menu item with fresh related data from separate tables
  Future<MenuItem> _enrichMenuItemWithRelatedData(MenuItem menuItem) async {
    try {
      if (kDebugMode) {
        debugPrint('🔄 Enriching menu item: ${menuItem.name} (${menuItem.id})');
      }

      // Fetch variants
      final variantsResponse = await _supabase
          .from('menu_item_variants')
          .select('*')
          .eq('menu_item_id', menuItem.id)
          .order('display_order');

      // Fetch pricing options
      final pricingResponse = await _supabase
          .from('menu_item_pricing')
          .select('*')
          .eq('menu_item_id', menuItem.id)
          .order('display_order');

      // Fetch supplements
      final supplementsResponse = await _supabase
          .from('menu_item_supplements')
          .select('*')
          .eq('menu_item_id', menuItem.id)
          .order('display_order');

      final variantsList =
          (variantsResponse as List).cast<Map<String, dynamic>>();
      final pricingList =
          (pricingResponse as List).cast<Map<String, dynamic>>();
      final supplementsList =
          (supplementsResponse as List).cast<Map<String, dynamic>>();

      if (kDebugMode) {
        debugPrint('  ✅ Fetched ${variantsList.length} variants');
        debugPrint('  ✅ Fetched ${pricingList.length} pricing options');
        debugPrint('  ✅ Fetched ${supplementsList.length} supplements');
      }

      // Create updated menu item with fresh related data
      return menuItem.copyWith(
        variants: variantsList,
        pricingOptions: pricingList,
        supplements: supplementsList,
      );
    } catch (e) {
      Logger.error(
          'Failed to enrich menu item ${menuItem.id} with related data: $e');
      if (kDebugMode) {
        debugPrint('❌ Error enriching menu item ${menuItem.id}: $e');
      }
      // Return original item if enrichment fails
      return menuItem;
    }
  }

  /// Get menu items by category
  Future<List<MenuItem>> getMenuItemsByCategory(String category) async {
    try {
      final result = await listMenuItems(
        filters: MenuItemFilters(category: category),
        limit: 100,
      );
      return result.menuItems;
    } catch (e) {
      Logger.error('Failed to get menu items by category: $category');
      return [];
    }
  }

  /// Search menu items
  Future<List<MenuItem>> searchMenuItems(String query) async {
    try {
      final result = await listMenuItems(
        filters: MenuItemFilters(searchQuery: query),
        limit: 50,
      );
      return result.menuItems;
    } catch (e) {
      Logger.error('Failed to search menu items: $query');
      return [];
    }
  }

  /// Get featured menu items
  Future<List<MenuItem>> getFeaturedMenuItems() async {
    try {
      final result = await listMenuItems(
        filters: MenuItemFilters(isFeatured: true),
        limit: 20,
      );
      return result.menuItems;
    } catch (e) {
      Logger.error('Failed to get featured menu items');
      return [];
    }
  }

  /// Get popular menu items
  Future<List<MenuItem>> getPopularMenuItems() async {
    try {
      final result = await listMenuItems(
        filters: MenuItemFilters(isFeatured: true),
        limit: 20,
      );
      return result.menuItems;
    } catch (e) {
      Logger.error('Failed to get popular menu items');
      return [];
    }
  }

  /// Create a new menu item
  Future<MenuItem> createMenuItem(MenuItem menuItem, List<File> images) async {
    final operationId =
        'create_menu_item_${DateTime.now().millisecondsSinceEpoch}';

    try {
      _logger.startPerformanceTimer('menu_item_creation', metadata: {
        'menu_item_name': menuItem.name,
        'restaurant_id': menuItem.restaurantId,
        'operation_id': operationId,
      });

      _logger.logUserAction(
        'menu_item_creation_started',
        data: {
          'menu_item_name': menuItem.name,
          'restaurant_id': menuItem.restaurantId,
          'price': menuItem.price,
          'category': menuItem.category,
          'operation_id': operationId,
        },
      );

      Logger.info('Creating new menu item: ${menuItem.name}');

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) {
        throw MenuItemCreationException('User not authenticated');
      }

      // Ensure user has a restaurant record
      final restaurantInfo = await ensureUserHasRestaurant(userId);
      final restaurantId = restaurantInfo['id']!;
      final restaurantName = restaurantInfo['name'] ?? 'Unknown Restaurant';

      // Create menu item record
      final menuItemData = menuItem.toJson();
      menuItemData['restaurant_id'] = restaurantId;
      menuItemData['restaurant_name'] = restaurantName;
      menuItemData['created_at'] = DateTime.now().toIso8601String();
      menuItemData['updated_at'] = DateTime.now().toIso8601String();

      // Remove empty id field to let database auto-generate it
      if (menuItemData['id'] == '' || menuItemData['id'] == null) {
        menuItemData.remove('id');
      }

      Logger.info('Menu item data to insert: $menuItemData');

      // Debug free drinks data specifically
      if (kDebugMode) {
        debugPrint('🥤 Free Drinks in menuItemData:');
      }
      if (kDebugMode) {
        debugPrint(
            '   free_drinks_included: ${menuItemData['free_drinks_included']}');
      }
      if (kDebugMode) {
        debugPrint('   free_drinks_list: ${menuItemData['free_drinks_list']}');
      }
      if (kDebugMode) {
        debugPrint(
            '   free_drinks_quantity: ${menuItemData['free_drinks_quantity']}');
      }

      // Debug LTO data specifically
      if (kDebugMode) {
        debugPrint('🎯 LIMITED TIME OFFER in menuItemData:');
      }
      if (kDebugMode) {
        debugPrint('   is_limited_offer: ${menuItemData['is_limited_offer']}');
      }
      if (kDebugMode) {
        debugPrint('   offer_types: ${menuItemData['offer_types']}');
      }
      if (kDebugMode) {
        debugPrint('   offer_start_at: ${menuItemData['offer_start_at']}');
      }
      if (kDebugMode) {
        debugPrint('   offer_end_at: ${menuItemData['offer_end_at']}');
      }
      if (kDebugMode) {
        debugPrint('   original_price: ${menuItemData['original_price']}');
      }
      if (kDebugMode) {
        debugPrint('   offer_details: ${menuItemData['offer_details']}');
      }

      final menuItemResponse = await _supabase
          .from('menu_items')
          .insert(menuItemData)
          .select()
          .single();

      final newMenuItemId = menuItemResponse['id'];
      Logger.info('Menu item record created with ID: $newMenuItemId');

      // Image upload disabled - _imageService not available
      final List<String> imageUrls = [];

      // Use image from menuItemData if available, otherwise use response image, otherwise use placeholder
      final imageFromData = menuItemData['image'] as String? ?? '';
      final imageFromResponse = menuItemResponse['image'] as String? ?? '';
      final finalImage = imageFromData.isNotEmpty
          ? imageFromData
          : (imageFromResponse.isNotEmpty
              ? imageFromResponse
              : 'https://via.placeholder.com/150');

      // Return the created menu item
      final createdMenuItem = MenuItem.fromJson({
        ...menuItemData,
        'id': newMenuItemId,
        'image': finalImage,
        'images': imageUrls.isNotEmpty
            ? imageUrls
            : (finalImage.isNotEmpty ? [finalImage] : []),
        'created_at': menuItemResponse['created_at'],
        'updated_at': menuItemResponse['updated_at'],
      });

      // Clear cache
      clearCache();

      _logger.logUserAction(
        'menu_item_creation_completed',
        data: {
          'menu_item_id': newMenuItemId,
          'menu_item_name': menuItem.name,
          'restaurant_id': restaurantId,
          'restaurant_name': restaurantName,
          'price': menuItem.price,
          'category': menuItem.category,
          'operation_id': operationId,
        },
      );

      _logger.logOrderMetrics(
        orderId: newMenuItemId,
        status: 'created',
        totalAmount: menuItem.price,
        restaurantId: restaurantId,
        customerId: userId,
      );

      _logger.endPerformanceTimer('menu_item_creation',
          details: 'Menu item created successfully');

      Logger.info('Menu item created successfully: $newMenuItemId');
      return createdMenuItem;
    } catch (e) {
      _logger.error(
        'Failed to create menu item',
        tag: 'MENU_ITEM',
        error: e,
        additionalData: {
          'menu_item_name': menuItem.name,
          'restaurant_id': menuItem.restaurantId,
          'operation_id': operationId,
        },
      );

      _logger.endPerformanceTimer('menu_item_creation',
          details: 'Menu item creation failed');

      Logger.error('❌ Failed to create menu item: $e');
      Logger.error('❌ Error type: ${e.runtimeType}');
      Logger.error('❌ Error details: ${e.toString()}');
      if (e is MenuItemServiceException) {
        Logger.error('❌ Re-throwing MenuItemServiceException: ${e.message}');
        rethrow;
      }
      throw MenuItemServiceException('Failed to create menu item: $e',
          originalError: e);
    }
  }

  /// Update a menu item
  Future<bool> updateMenuItem(MenuItem menuItem) async {
    try {
      Logger.info('Updating menu item: ${menuItem.id}');

      final menuItemData = menuItem.toJson();
      menuItemData['updated_at'] = DateTime.now().toIso8601String();

      if (kDebugMode) {
        debugPrint('📝 Update data keys: ${menuItemData.keys.toList()}');
      }
      if (kDebugMode) {
        debugPrint('📝 Image value: ${menuItemData['image']}');
      }
      if (kDebugMode) {
        debugPrint('📝 Images value: ${menuItemData['images']}');
      }
      if (kDebugMode) {
        debugPrint('📝 LTO enabled: ${menuItemData['is_limited_offer']}');
      }

      await _supabase
          .from('menu_items')
          .update(menuItemData)
          .eq('id', menuItem.id);

      // Clear cache
      clearCache();

      Logger.info('Menu item updated successfully: ${menuItem.id}');
      return true;
    } catch (e, stackTrace) {
      Logger.error('Failed to update menu item: ${menuItem.id}');
      if (kDebugMode) debugPrint('❌ Update error: $e');
      if (kDebugMode) debugPrint('❌ Stack trace: $stackTrace');
      return false;
    }
  }

  /// Delete a menu item
  Future<bool> deleteMenuItem(String menuItemId) async {
    try {
      Logger.info('Deleting menu item: $menuItemId');

      // Get menu item to find restaurant ID for image cleanup
      final menuItem = await getMenuItemById(menuItemId);
      if (menuItem != null) {
        // Delete images from storage (commented out - _imageService not available)
        try {
          // await _imageService.deleteMenuItemImages(menuItemId, menuItem.restaurantId);
        } catch (e) {
          Logger.error('Failed to delete images for menu item: $menuItemId');
          // Continue with deletion even if image cleanup fails
        }
      }

      // Delete menu item
      await _supabase.from('menu_items').delete().eq('id', menuItemId);

      // Clear cache
      clearCache();

      Logger.info('Menu item deleted successfully: $menuItemId');
      return true;
    } catch (e) {
      Logger.error('Failed to delete menu item: $menuItemId');
      return false;
    }
  }

  /// Add menu item (alias for createMenuItem)
  Future<bool> addMenuItem(MenuItem menuItem) async {
    try {
      await createMenuItem(menuItem, []);
      return true;
    } catch (e) {
      Logger.error('Failed to add menu item: $e');
      return false;
    }
  }

  /// Get all menu items
  Future<List<MenuItem>> getMenuItems() async {
    try {
      final result = await listMenuItems(limit: 1000);
      return result.menuItems;
    } catch (e) {
      Logger.error('Failed to get menu items');
      return [];
    }
  }

  /// Ensure user has a restaurant record, create one if not exists
  Future<Map<String, String>> ensureUserHasRestaurant(String userId) async {
    try {
      Logger.info('🔍 Checking if user has restaurant: $userId');

      // Check if user already has a restaurant
      final existingRestaurant = await _supabase
          .from('restaurants')
          .select('id, name')
          .eq('owner_id', userId)
          .maybeSingle();

      if (existingRestaurant != null) {
        Logger.info(
            '✅ User already has restaurant: ${existingRestaurant['id']}');
        return {
          'id': existingRestaurant['id'] as String,
          'name': existingRestaurant['name'] as String,
        };
      }

      Logger.info('📝 User does not have restaurant, creating one...');

      // Get user profile to create restaurant
      Logger.info('🔍 Fetching user profile for ID: $userId');
      final userProfile = await _supabase
          .from('user_profiles')
          .select('name, phone, email')
          .eq('id', userId)
          .maybeSingle();

      if (userProfile == null) {
        Logger.error(
            '❌ User profile not found in user_profiles table for ID: $userId');
        Logger.error(
            '❌ This usually means the user hasn\'t completed their profile setup');

        // Try to get user from auth.users as fallback
        try {
          await _supabase.auth.admin.getUserById(userId);
          Logger.info('ℹ️ User exists in auth.users but not in user_profiles');
        } catch (authError) {
          Logger.error('❌ User also not found in auth.users: $authError');
        }

        throw MenuItemServiceException(
            'User profile not found. Please complete your profile setup in the app.');
      }

      Logger.info(
          '👤 User profile retrieved: ${userProfile['name']}, Phone: ${userProfile['phone']}');

      // Create a default restaurant for the user
      final restaurantData = {
        'owner_id': userId,
        'name': '${userProfile['name'] ?? 'User'}\'s Restaurant',
        'description': 'Restaurant created automatically for menu management',
        'image': '', // Required field
        'phone': userProfile['phone'] ?? '',
        'email': '', // Email not available in user_profiles
        'address_line1': 'Address not set',
        'address_line2': '',
        'city': 'City not set',
        'state': 'State not set',
        'postal_code': '00000',
        'is_open': true,
        'is_verified': false,
        'is_featured': false,
        'rating': 0.0,
        'review_count': 0,
        'delivery_fee': 0.0,
        'minimum_order': 0.0,
        'estimated_delivery_time': 30,
        'wilaya': '',
        'logo_url': '',
      };

      Logger.info('🏪 Creating restaurant with data: $restaurantData');

      final newRestaurant = await _supabase
          .from('restaurants')
          .insert(restaurantData)
          .select('id, name')
          .single();

      Logger.info('✅ Created new restaurant for user: ${newRestaurant['id']}');
      return {
        'id': newRestaurant['id'] as String,
        'name': newRestaurant['name'] as String,
      };
    } catch (e) {
      Logger.error('❌ Failed to ensure user has restaurant: $e');
      Logger.error('❌ Error type: ${e.runtimeType}');
      Logger.error('❌ Error details: ${e.toString()}');

      if (e is PostgrestException) {
        Logger.error('❌ PostgrestException details:');
        Logger.error('  - Message: ${e.message}');
        Logger.error('  - Code: ${e.code}');
        Logger.error('  - Details: ${e.details}');
        Logger.error('  - Hint: ${e.hint}');

        // Check for specific error types
        if (e.message.contains('violates foreign key constraint')) {
          throw MenuItemServiceException(
              'User account not properly set up. Please contact support.',
              originalError: e);
        }
        if (e.message.contains('duplicate key value')) {
          throw MenuItemServiceException(
              'Restaurant already exists for this user.',
              originalError: e);
        }
        if (e.message.contains('permission denied')) {
          throw MenuItemServiceException(
              'Permission denied. Please check your account permissions.',
              originalError: e);
        }
      }

      throw MenuItemServiceException('Failed to create restaurant record: $e',
          originalError: e);
    }
  }

  /// Toggle menu item availability
  Future<bool> toggleMenuItemAvailability(String menuItemId) async {
    try {
      final menuItem = await getMenuItemById(menuItemId);
      if (menuItem == null) return false;

      final updatedMenuItem = menuItem.copyWith(
        isAvailable: !menuItem.isAvailable,
        updatedAt: DateTime.now(),
      );

      return await updateMenuItem(updatedMenuItem);
    } catch (e) {
      Logger.error('Failed to toggle menu item availability: $menuItemId');
      return false;
    }
  }

  /// Check and update expired LTO items to unavailable in database
  /// This runs automatically when menu items are loaded
  Future<void> updateExpiredLTOItems(List<MenuItem> items) async {
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

  /// Update menu item rating
  Future<bool> updateMenuItemRating(String menuItemId, double rating) async {
    try {
      await _supabase.from('menu_items').update({
        'rating': rating,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', menuItemId);

      // Clear cache
      clearCache();

      return true;
    } catch (e) {
      Logger.error('Failed to update menu item rating: $menuItemId');
      return false;
    }
  }

  /// Increment order count for menu item
  Future<bool> incrementOrderCount(String menuItemId) async {
    try {
      await _supabase.from('menu_items').update({
        'order_count': 'order_count + 1',
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', menuItemId);

      // Clear cache
      clearCache();

      return true;
    } catch (e) {
      Logger.error('Failed to increment order count: $menuItemId');
      return false;
    }
  }

  /// Get performance analytics for the service
  Map<String, dynamic> getPerformanceAnalytics() {
    final now = DateTime.now();
    final analytics = <String, dynamic>{
      'total_operations':
          _operationCounts.values.fold<int>(0, (sum, count) => sum + count),
      'active_operations': _operationCounts.length,
      'cached_menu_items': _menuItemCache.length,
      'cached_lists': _listCache.length,
      'cache_hit_rate': _calculateCacheHitRate(),
      'service_uptime': now
          .difference(_operationStartTimes.isNotEmpty
              ? _operationStartTimes.values
                  .reduce((a, b) => a.isBefore(b) ? a : b)
              : now)
          .inMinutes,
    };

    _logger.info('MenuItemService performance analytics',
        tag: 'MENU_ITEM', additionalData: analytics);
    return analytics;
  }

  /// Calculate cache hit rate
  double _calculateCacheHitRate() {
    if (_operationCounts.isEmpty) return 0.0;
    final totalOperations =
        _operationCounts.values.fold<int>(0, (sum, count) => sum + count);
    final cacheHits = _menuItemCache.length + _listCache.length;
    return totalOperations > 0 ? (cacheHits / totalOperations) * 100 : 0.0;
  }

  /// Clear performance cache
  void clearPerformanceCache() {
    _operationStartTimes.clear();
    _operationCounts.clear();
    _logger.info('MenuItemService performance cache cleared', tag: 'MENU_ITEM');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStatistics() {
    final stats = <String, dynamic>{
      'cached_menu_items': _menuItemCache.length,
      'cached_lists': _listCache.length,
      'cache_size_bytes':
          _menuItemCache.toString().length + _listCache.toString().length,
      'oldest_cache_entry': _menuItemCacheTimestamps.values.isNotEmpty
          ? _menuItemCacheTimestamps.values
              .reduce((a, b) => a.isBefore(b) ? a : b)
              .toIso8601String()
          : null,
      'newest_cache_entry': _menuItemCacheTimestamps.values.isNotEmpty
          ? _menuItemCacheTimestamps.values
              .reduce((a, b) => a.isAfter(b) ? a : b)
              .toIso8601String()
          : null,
    };

    _logger.info('MenuItemService cache statistics',
        tag: 'MENU_ITEM', additionalData: stats);
    return stats;
  }

  /// Preload popular menu items for better performance
  Future<void> preloadPopularMenuItems() async {
    try {
      _logger.startPerformanceTimer('menu_item_preload');

      // Preload featured items
      await getFeaturedMenuItems();

      // Preload popular items
      await getPopularMenuItems();

      _logger.endPerformanceTimer('menu_item_preload',
          details: 'Popular menu items preloaded successfully');
      _logger.info('Preloaded popular menu items', tag: 'MENU_ITEM');
    } catch (e) {
      _logger.error('Failed to preload popular menu items',
          tag: 'MENU_ITEM', error: e);
    }
  }

  // Clear cache method
  void clearCache() {
    _menuItemCache.clear();
    _menuItemCacheTimestamps.clear();
    if (kDebugMode) debugPrint('Menu item cache cleared');
  }
}
