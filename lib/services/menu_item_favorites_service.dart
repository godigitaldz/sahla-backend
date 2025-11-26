import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/menu_item.dart';
import 'logging_service.dart';

class MenuItemFavoritesService extends ChangeNotifier {
  SupabaseClient get _supabase => Supabase.instance.client;
  final Map<String, bool> _favorites = {};
  RealtimeChannel? _favoritesChannel;

  // Logging service for business metrics and performance tracking
  final LoggingService _logger = LoggingService();

  // Performance tracking
  final Map<String, DateTime> _operationStartTimes = {};
  final Map<String, int> _operationCounts = {};

  // Cache for favorite menu items
  final Map<String, MenuItem> _favoriteMenuItemsCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  // Public getters for debugging
  SupabaseClient get supabase => _supabase;
  Map<String, bool> get favorites => _favorites;

  bool isMenuItemFavorite(String menuItemId) {
    final isFav = _favorites[menuItemId] ?? false;
    debugPrint('🔍 MenuItemFavoritesService: Checking $menuItemId = $isFav');
    return isFav;
  }

  /// Initialize service with real-time subscriptions
  Future<void> initialize() async {
    try {
      _logger.startPerformanceTimer('menu_favorites_service_init');
      debugPrint('🔄 MenuItemFavoritesService: Initializing...');

      // Test if table exists
      final tableExists = await testTableExists();
      if (!tableExists) {
        debugPrint(
            '❌ MenuItemFavoritesService: user_menu_item_favorites table does not exist!');
        debugPrint(
            '⚠️ MenuItemFavoritesService: Please run the create_menu_item_favorites_table.sql script');
        _logger.warning('MenuItemFavoritesService table does not exist',
            tag: 'MENU_FAVORITES');
        return;
      }

      await _loadUserFavorites();
      _setupRealtimeSubscription();

      _logger.endPerformanceTimer('menu_favorites_service_init',
          details: 'MenuItemFavoritesService initialized successfully');
      debugPrint('✅ MenuItemFavoritesService: Initialized successfully');
      _logger.info('MenuItemFavoritesService initialized',
          tag: 'MENU_FAVORITES');
    } catch (e) {
      _logger.error('Failed to initialize MenuItemFavoritesService',
          tag: 'MENU_FAVORITES', error: e);
      debugPrint('❌ MenuItemFavoritesService: Initialization failed: $e');
      rethrow;
    }
  }

  /// Setup real-time subscription for live updates
  void _setupRealtimeSubscription() {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      _favoritesChannel?.unsubscribe();
      _favoritesChannel = _supabase
          .channel('menu_item_favorites_$userId')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'user_menu_item_favorites',
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: 'user_id',
              value: userId,
            ),
            callback: (payload) async {
              debugPrint(
                  '🔄 Menu item favorites real-time update: ${payload.eventType}');
              await _loadUserFavorites();
            },
          )
          .subscribe();
    } catch (e) {
      debugPrint('❌ Failed to setup menu item favorites realtime: $e');
    }
  }

  /// Toggle menu item favorite status with optimistic updates
  Future<bool> toggleMenuItemFavorite(MenuItem menuItem) async {
    final operationId =
        'toggle_favorite_${menuItem.id}_${DateTime.now().millisecondsSinceEpoch}';

    try {
      _logger.startPerformanceTimer('menu_item_favorite_toggle', metadata: {
        'menu_item_id': menuItem.id,
        'menu_item_name': menuItem.name,
        'operation_id': operationId,
      });

      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return false;

      final currentState = _favorites[menuItem.id] ?? false;
      final newState = !currentState;

      // Optimistic update
      _favorites[menuItem.id] = newState;
      debugPrint(
          '🔄 MenuItemFavoritesService: Updated ${menuItem.name} to $newState');
      notifyListeners();

      _logger.logUserAction(
        'menu_item_favorite_toggle_started',
        data: {
          'menu_item_id': menuItem.id,
          'menu_item_name': menuItem.name,
          'restaurant_id': menuItem.restaurantId,
          'current_state': currentState,
          'new_state': newState,
          'operation_id': operationId,
        },
      );

      if (newState) {
        // Add to favorites - include restaurant_id from menuItem or get it from database
        String? restaurantId = menuItem.restaurantId;

        // If restaurantId not available in menuItem, get it from database
        if (restaurantId.isEmpty) {
          try {
            final menuItemData = await _supabase
                .from('menu_items')
                .select('restaurant_id')
                .eq('id', menuItem.id)
                .single();
            restaurantId = menuItemData['restaurant_id'] as String?;
          } catch (e) {
            debugPrint(
                '❌ Could not get restaurant_id for menu item ${menuItem.id}: $e');
            // Rollback optimistic update
            _favorites[menuItem.id] = false;
            notifyListeners();
            return false;
          }
        }

        if (restaurantId == null) {
          debugPrint('❌ No restaurant_id found for menu item ${menuItem.id}');
          // Rollback optimistic update
          _favorites[menuItem.id] = false;
          notifyListeners();
          return false;
        }

        await _supabase.from('user_menu_item_favorites').upsert({
          'user_id': userId,
          'menu_item_id': menuItem.id,
          'restaurant_id': restaurantId,
          'created_at': DateTime.now().toIso8601String(),
        }, onConflict: 'user_id,menu_item_id');
      } else {
        // Remove from favorites
        await _supabase.from('user_menu_item_favorites').delete().match({
          'user_id': userId,
          'menu_item_id': menuItem.id,
        });
      }

      _logger.logUserAction(
        'menu_item_favorite_toggle_completed',
        data: {
          'menu_item_id': menuItem.id,
          'menu_item_name': menuItem.name,
          'restaurant_id': menuItem.restaurantId,
          'new_state': newState,
          'operation_id': operationId,
        },
      );

      _logger.logOrderMetrics(
        orderId: menuItem.id,
        status: newState ? 'favorited' : 'unfavorited',
        totalAmount: menuItem.price,
        restaurantId: menuItem.restaurantId,
        customerId: userId,
      );

      _logger.endPerformanceTimer('menu_item_favorite_toggle',
          details: 'Menu item favorite toggle completed successfully');

      debugPrint(
          '✅ Menu item ${menuItem.name} ${newState ? 'added to' : 'removed from'} favorites');
      return true;
    } catch (e) {
      // Rollback optimistic update on error
      final currentState = _favorites[menuItem.id] ?? false;
      _favorites[menuItem.id] = !currentState;
      notifyListeners();

      _logger.error(
        'Error toggling menu item favorite',
        tag: 'MENU_FAVORITES',
        error: e,
        additionalData: {
          'menu_item_id': menuItem.id,
          'menu_item_name': menuItem.name,
          'operation_id': operationId,
        },
      );

      _logger.endPerformanceTimer('menu_item_favorite_toggle',
          details: 'Menu item favorite toggle failed');

      debugPrint('❌ Error toggling menu item favorite: $e');
      return false;
    }
  }

  Future<void> addMenuItemToFavorites(MenuItem menuItem) async {
    await toggleMenuItemFavorite(menuItem);
  }

  Future<void> removeMenuItemFromFavorites(String menuItemId) async {
    // Find menu item by ID (this is a legacy method, prefer toggleMenuItemFavorite)
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      await _supabase.from('user_menu_item_favorites').delete().match({
        'user_id': userId,
        'menu_item_id': menuItemId,
      });

      _favorites[menuItemId] = false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error removing menu item from favorites: $e');
    }
  }

  Future<List<String>> getUserFavoriteMenuItemIds() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return [];

      final response = await _supabase
          .from('user_menu_item_favorites')
          .select('menu_item_id')
          .eq('user_id', userId);

      return (response as List)
          .map((item) => item['menu_item_id'] as String)
          .toList();
    } catch (e) {
      debugPrint('Error getting user favorite menu item IDs: $e');
      return [];
    }
  }

  Future<List<MenuItem>> getUserFavoriteMenuItems() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      debugPrint(
          '🔍 MenuItemFavoritesService: getUserFavoriteMenuItems called, userId: $userId');
      if (userId == null) {
        debugPrint('🔍 MenuItemFavoritesService: No user ID available');
        return [];
      }

      final favoriteIds = await getUserFavoriteMenuItemIds();
      debugPrint(
          '🔍 MenuItemFavoritesService: Found ${favoriteIds.length} favorite IDs: $favoriteIds');
      if (favoriteIds.isEmpty) {
        debugPrint('🔍 MenuItemFavoritesService: No favorite IDs found');
        return [];
      }

      // SIMPLIFIED APPROACH: Get menu items with basic restaurant info
      debugPrint(
          '🔍 MenuItemFavoritesService: Querying menu items for IDs: $favoriteIds');
      final response = await _supabase.from('menu_items').select('''
            id, name, description, price, image, category, main_ingredients,
            preparation_time, rating, review_count, is_available, created_at, updated_at,
            restaurant_id
          ''').inFilter('id', favoriteIds);

      debugPrint(
          '🔍 MenuItemFavoritesService: Menu items query response: ${response.length} items');

      if (response.isNotEmpty) {
        final List<MenuItem> menuItems = [];

        for (final json in response) {
          try {
            // Get restaurant name first if possible
            String? restaurantName;
            if (json['restaurant_id'] != null) {
              try {
                final restaurantResponse = await _supabase
                    .from('restaurants')
                    .select('name')
                    .eq('id', json['restaurant_id'])
                    .single();

                restaurantName = restaurantResponse['name'] as String?;
              } catch (restaurantError) {
                debugPrint(
                    '⚠️ MenuItemFavoritesService: Could not get restaurant name for ${json['restaurant_id']}: $restaurantError');
                // Continue without restaurant name - not critical
              }
            }

            // Create MenuItem with complete data
            final menuItem = MenuItem(
              id: json['id'] as String,
              restaurantId: json['restaurant_id'] as String? ?? '',
              restaurantName: restaurantName, // Pass restaurant name here
              name: json['name'] as String? ?? '',
              description: json['description'] as String? ?? '',
              image: json['image'] as String? ?? '',
              price: (json['price'] as num?)?.toDouble() ?? 0.0,
              category: json['category'] as String? ?? '',
              isAvailable: json['is_available'] as bool? ?? true,
              isFeatured: json['is_featured'] as bool? ?? false,
              preparationTime: json['preparation_time'] as int? ?? 15,
              rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
              reviewCount: json['review_count'] as int? ?? 0,
              mainIngredients:
                  json['main_ingredients'] as String?, // Use correct field name
              createdAt: json['created_at'] != null
                  ? DateTime.parse(json['created_at'] as String)
                  : DateTime.now(),
              updatedAt: json['updated_at'] != null
                  ? DateTime.parse(json['updated_at'] as String)
                  : DateTime.now(),
            );

            menuItems.add(menuItem);
          } catch (itemError) {
            debugPrint(
                '⚠️ MenuItemFavoritesService: Error parsing menu item ${json['id']}: $itemError');
            // Continue with other items
          }
        }

        debugPrint(
            '🔍 MenuItemFavoritesService: Successfully parsed ${menuItems.length} menu items');
        return menuItems;
      } else {
        debugPrint('🔍 MenuItemFavoritesService: No menu items found');
        return [];
      }
    } catch (e) {
      debugPrint(
          '❌ MenuItemFavoritesService: Error getting user favorite menu items: $e');
      debugPrint('❌ MenuItemFavoritesService: Error type: ${e.runtimeType}');

      // Check if it's a table not found error
      if (e.toString().contains('relation') &&
          e.toString().contains('does not exist')) {
        debugPrint('🚨 CRITICAL: Table does not exist!');
        debugPrint('💡 SOLUTION: Run database setup scripts');
      }

      // Check if it's an RLS/policy error
      if (e.toString().contains('policy') ||
          e.toString().contains('permission')) {
        debugPrint('🚨 CRITICAL: RLS policy or permission error!');
        debugPrint('💡 SOLUTION: Check RLS policies in Supabase dashboard');
      }

      return [];
    }
  }

  Future<void> loadUserFavorites() async {
    await _loadUserFavorites();
  }

  Future<void> _loadUserFavorites() async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      final response = await _supabase
          .from('user_menu_item_favorites')
          .select('menu_item_id')
          .eq('user_id', userId);

      _favorites.clear();
      for (final item in response) {
        final menuItemId = item['menu_item_id'] as String;
        _favorites[menuItemId] = true;
      }
      notifyListeners();
      debugPrint('✅ Loaded ${_favorites.length} favorite menu items');
    } catch (e) {
      debugPrint('❌ Error loading user menu item favorites: $e');
      // Clear favorites on error to prevent inconsistent state
      _favorites.clear();
      notifyListeners();
    }
  }

  /// Test if the database table exists
  Future<bool> testTableExists() async {
    try {
      debugPrint(
          '🔍 MenuItemFavoritesService: Testing if user_menu_item_favorites table exists');

      // Try to query the table
      final response = await _supabase
          .from('user_menu_item_favorites')
          .select('id')
          .limit(1);

      debugPrint(
          '🔍 MenuItemFavoritesService: Table exists test response: $response');
      return true;
    } catch (e) {
      debugPrint('❌ MenuItemFavoritesService: Table exists test failed: $e');
      debugPrint('❌ MenuItemFavoritesService: Error type: ${e.runtimeType}');
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
      'total_favorites': _favorites.length,
      'cached_favorite_items': _favoriteMenuItemsCache.length,
      'cache_hit_rate': _calculateCacheHitRate(),
      'service_uptime': now
          .difference(_operationStartTimes.isNotEmpty
              ? _operationStartTimes.values
                  .reduce((a, b) => a.isBefore(b) ? a : b)
              : now)
          .inMinutes,
    };

    _logger.info('MenuItemFavoritesService performance analytics',
        tag: 'MENU_FAVORITES', additionalData: analytics);
    return analytics;
  }

  /// Calculate cache hit rate
  double _calculateCacheHitRate() {
    if (_operationCounts.isEmpty) return 0.0;
    final totalOperations =
        _operationCounts.values.fold<int>(0, (sum, count) => sum + count);
    final cacheHits = _favoriteMenuItemsCache.length;
    return totalOperations > 0 ? (cacheHits / totalOperations) * 100 : 0.0;
  }

  /// Clear performance cache
  void clearPerformanceCache() {
    _operationStartTimes.clear();
    _operationCounts.clear();
    _favoriteMenuItemsCache.clear();
    _cacheTimestamps.clear();
    _logger.info('MenuItemFavoritesService performance cache cleared',
        tag: 'MENU_FAVORITES');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStatistics() {
    final stats = <String, dynamic>{
      'cached_favorite_items': _favoriteMenuItemsCache.length,
      'cache_size_bytes': _favoriteMenuItemsCache.toString().length,
      'oldest_cache_entry': _cacheTimestamps.values.isNotEmpty
          ? _cacheTimestamps.values
              .reduce((a, b) => a.isBefore(b) ? a : b)
              .toIso8601String()
          : null,
      'newest_cache_entry': _cacheTimestamps.values.isNotEmpty
          ? _cacheTimestamps.values
              .reduce((a, b) => a.isAfter(b) ? a : b)
              .toIso8601String()
          : null,
    };

    _logger.info('MenuItemFavoritesService cache statistics',
        tag: 'MENU_FAVORITES', additionalData: stats);
    return stats;
  }

  /// Preload favorite menu items for better performance
  Future<void> preloadFavoriteMenuItems() async {
    try {
      _logger.startPerformanceTimer('favorite_menu_items_preload');

      await getUserFavoriteMenuItems();

      _logger.endPerformanceTimer('favorite_menu_items_preload',
          details: 'Favorite menu items preloaded successfully');
      _logger.info('Preloaded favorite menu items', tag: 'MENU_FAVORITES');
    } catch (e) {
      _logger.error('Failed to preload favorite menu items',
          tag: 'MENU_FAVORITES', error: e);
    }
  }
}
