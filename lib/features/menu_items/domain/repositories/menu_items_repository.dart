import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../models/menu_item.dart';
import '../../data/cache/menu_items_cache_manager.dart';
import '../../data/sources/menu_items_local_source.dart';
import '../../data/sources/menu_items_remote_source.dart';
import '../models/menu_items_state.dart';

/// Provider for menu items repository
final menuItemsRepositoryProvider = Provider<MenuItemsRepository>((ref) {
  return MenuItemsRepository(
    remoteSource: MenuItemsRemoteSource(),
    localSource: MenuItemsLocalSource(),
    cacheManager: MenuItemsCacheManager(),
  );
});

/// Repository for menu items data access
class MenuItemsRepository {
  MenuItemsRepository({
    required MenuItemsRemoteSource remoteSource,
    required MenuItemsLocalSource localSource,
    required MenuItemsCacheManager cacheManager,
  })  : _remoteSource = remoteSource,
        _localSource = localSource,
        _cacheManager = cacheManager;

  final MenuItemsRemoteSource _remoteSource;
  final MenuItemsLocalSource _localSource;
  final MenuItemsCacheManager _cacheManager;

  /// Fetch menu items with intelligent caching strategy
  Future<PaginatedResult<MenuItem>> fetchMenuItems({
    required int limit,
    String? cursor,
    String? query,
    Set<String>? categories,
    Set<String>? cuisines,
    RangeValues? priceRange,
  }) async {
    final cacheKey = _buildCacheKey(query, categories, cuisines, priceRange);

    // Try cache first (only for initial load)
    if (cursor == null) {
      final cached = await _cacheManager.get(cacheKey);
      if (cached != null && cached.isValid) {
        debugPrint('🚀 MenuItemsRepository: Cache HIT ($cacheKey)');

        // Fetch fresh data in background (no await - fire and forget)
        unawaited(_fetchFreshData(
          cacheKey,
          limit,
          query,
          categories,
          cuisines,
          priceRange,
        ));

        return cached.data;
      }
      debugPrint('⚠️ MenuItemsRepository: Cache MISS ($cacheKey)');
    }

    // Fetch from network with server-side filtering
    try {
      final result = await _remoteSource.fetchMenuItems(
        limit: limit,
        cursor: cursor,
        query: query,
        categories: categories?.toList(),
        cuisines: cuisines?.toList(),
        minPrice: priceRange?.start,
        maxPrice: priceRange?.end,
      );

      // Cache result (only first page)
      if (cursor == null) {
        await _cacheManager.set(
          cacheKey,
          result,
          ttl: const Duration(minutes: 15),
        );
      }

      debugPrint(
          '✅ MenuItemsRepository: Fetched ${result.items.length} items from network');

      return result;
    } catch (e) {
      debugPrint('❌ MenuItemsRepository: Network failed, trying local: $e');

      // Fallback to local database
      try {
        return await _localSource.getMenuItems(limit: limit);
      } catch (localError) {
        debugPrint('❌ MenuItemsRepository: Local fallback failed: $localError');
        rethrow;
      }
    }
  }

  /// Fetch fresh data in background for cache update
  Future<void> _fetchFreshData(
    String cacheKey,
    int limit,
    String? query,
    Set<String>? categories,
    Set<String>? cuisines,
    RangeValues? priceRange,
  ) async {
    try {
      final fresh = await _remoteSource.fetchMenuItems(
        limit: limit,
        cursor: null,
        query: query,
        categories: categories?.toList(),
        cuisines: cuisines?.toList(),
        minPrice: priceRange?.start,
        maxPrice: priceRange?.end,
      );

      await _cacheManager.set(
        cacheKey,
        fresh,
        ttl: const Duration(minutes: 15),
      );

      debugPrint('🔄 MenuItemsRepository: Background refresh complete');
    } catch (e) {
      // Silent fail for background refresh
      debugPrint('⚠️ MenuItemsRepository: Background refresh failed: $e');
    }
  }

  /// Build cache key from query parameters
  String _buildCacheKey(
    String? query,
    Set<String>? categories,
    Set<String>? cuisines,
    RangeValues? priceRange,
  ) {
    final parts = [
      'menu_items',
      query ?? '',
      categories?.join(',') ?? '',
      cuisines?.join(',') ?? '',
      priceRange?.start.toString() ?? '',
      priceRange?.end.toString() ?? '',
    ];

    return parts.join(':');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStatistics() {
    return _cacheManager.statistics.toJson();
  }

  /// Clear all cache
  Future<void> clearCache() async {
    await _cacheManager.clear();
    debugPrint('🗑️ MenuItemsRepository: Cache cleared');
  }
}
