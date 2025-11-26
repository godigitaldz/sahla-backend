import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/menu_item.dart';

/// Service for caching menu items offline with TTL
/// Uses Hive for fast local storage
class MenuCacheService {
  static const String _boxName = 'menu_cache';
  static const Duration _defaultTtl = Duration(hours: 6);

  Box<dynamic>? _box;

  /// Initialize the cache service
  Future<void> initialize() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        _box = await Hive.openBox(_boxName);
      } else {
        _box = Hive.box(_boxName);
      }
      debugPrint('✅ MenuCacheService initialized');
    } catch (e) {
      debugPrint('❌ Failed to initialize MenuCacheService: $e');
    }
  }

  /// Save menu items to cache with TTL
  Future<void> cacheMenuItems(
    String restaurantId,
    List<MenuItem> menuItems, {
    Duration? ttl,
  }) async {
    try {
      if (_box == null) await initialize();

      final cacheData = {
        'items': menuItems.map((item) => item.toJson()).toList(),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'ttl': (ttl ?? _defaultTtl).inMilliseconds,
      };

      await _box?.put('menu_$restaurantId', cacheData);
      debugPrint(
          '💾 Cached ${menuItems.length} menu items for restaurant $restaurantId');
    } catch (e) {
      debugPrint('❌ Failed to cache menu items: $e');
    }
  }

  /// Get cached menu items if still valid
  Future<List<MenuItem>?> getCachedMenuItems(String restaurantId) async {
    try {
      if (_box == null) await initialize();

      final cacheData =
          _box?.get('menu_$restaurantId') as Map<dynamic, dynamic>?;
      if (cacheData == null) {
        debugPrint('📭 No cache found for restaurant $restaurantId');
        return null;
      }

      final timestamp = cacheData['timestamp'] as int;
      final ttl = cacheData['ttl'] as int;
      final now = DateTime.now().millisecondsSinceEpoch;

      // Check if cache is still valid
      if (now - timestamp > ttl) {
        debugPrint('⏰ Cache expired for restaurant $restaurantId');
        await _box?.delete('menu_$restaurantId');
        return null;
      }

      // Parse items and handle missing images gracefully
      final items = <MenuItem>[];
      for (final json in (cacheData['items'] as List)) {
        try {
          final item = MenuItem.fromJson(Map<String, dynamic>.from(json));
          // Only include items with valid images
          if (item.image.isNotEmpty) {
            items.add(item);
          }
        } catch (e) {
          // Skip items that can't be parsed (e.g., missing required fields like image)
          debugPrint(
              '⚠️ MenuCacheService: Skipping cached menu item due to parsing error: $e');
        }
      }

      final ageMinutes = ((now - timestamp) / 60000).round();
      debugPrint(
          '📦 Retrieved ${items.length} cached menu items for restaurant $restaurantId (age: ${ageMinutes}m)');

      return items;
    } catch (e) {
      debugPrint('❌ Failed to get cached menu items: $e');
      return null;
    }
  }

  /// Check if cache exists and is valid
  Future<bool> hasCachedMenuItems(String restaurantId) async {
    final cached = await getCachedMenuItems(restaurantId);
    return cached != null && cached.isNotEmpty;
  }

  /// Invalidate cache for a specific restaurant
  Future<void> invalidateCache(String restaurantId) async {
    try {
      if (_box == null) await initialize();
      await _box?.delete('menu_$restaurantId');
      debugPrint('🗑️ Invalidated cache for restaurant $restaurantId');
    } catch (e) {
      debugPrint('❌ Failed to invalidate cache: $e');
    }
  }

  /// Clear all cached menu items
  Future<void> clearAllCache() async {
    try {
      if (_box == null) await initialize();
      await _box?.clear();
      debugPrint('🧹 Cleared all menu cache');
    } catch (e) {
      debugPrint('❌ Failed to clear cache: $e');
    }
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    try {
      if (_box == null) await initialize();

      final keys = _box?.keys.toList() ?? [];
      int totalItems = 0;
      int expiredItems = 0;
      final now = DateTime.now().millisecondsSinceEpoch;

      for (final key in keys) {
        final cacheData = _box?.get(key) as Map<dynamic, dynamic>?;
        if (cacheData != null) {
          final items = cacheData['items'] as List;
          totalItems += items.length;

          final timestamp = cacheData['timestamp'] as int;
          final ttl = cacheData['ttl'] as int;
          if (now - timestamp > ttl) {
            expiredItems++;
          }
        }
      }

      return {
        'cached_restaurants': keys.length,
        'total_items': totalItems,
        'expired_items': expiredItems,
        'cache_size_bytes': _box?.length ?? 0,
      };
    } catch (e) {
      debugPrint('❌ Failed to get cache stats: $e');
      return {};
    }
  }

  /// Clean up expired cache entries
  Future<void> cleanupExpiredCache() async {
    try {
      if (_box == null) await initialize();

      final keys = _box?.keys.toList() ?? [];
      final now = DateTime.now().millisecondsSinceEpoch;
      int cleaned = 0;

      for (final key in keys) {
        final cacheData = _box?.get(key) as Map<dynamic, dynamic>?;
        if (cacheData != null) {
          final timestamp = cacheData['timestamp'] as int;
          final ttl = cacheData['ttl'] as int;
          if (now - timestamp > ttl) {
            await _box?.delete(key);
            cleaned++;
          }
        }
      }

      if (cleaned > 0) {
        debugPrint('🧹 Cleaned up $cleaned expired cache entries');
      }
    } catch (e) {
      debugPrint('❌ Failed to cleanup expired cache: $e');
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    // Hive boxes are managed globally, so we don't close here
    _box = null;
  }
}
