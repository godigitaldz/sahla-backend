import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../models/menu_item.dart';
import '../../domain/models/menu_items_state.dart';

/// Remote data source for menu items using Supabase
class MenuItemsRemoteSource {
  SupabaseClient get _supabase => Supabase.instance.client;

  /// Fetch menu items with server-side filtering and cursor pagination
  Future<PaginatedResult<MenuItem>> fetchMenuItems({
    required int limit,
    String? cursor,
    String? query,
    List<String>? categories,
    List<String>? cuisines,
    double? minPrice,
    double? maxPrice,
  }) async {
    // PERFORMANCE: Add timeout to prevent long waits
    // Build base query WITHOUT order() - apply it at the end
    var queryBuilder = _supabase.from('menu_items').select('''
          id, restaurant_id, restaurant_name, name, description,
          image, price, category, cuisine_type_id, category_id,
          cuisine_types(*), categories(*), is_available, is_featured,
          preparation_time, rating, review_count, variants,
          pricing_options, supplements, created_at, updated_at
        ''').eq('is_available', true);

    // Server-side text search
    if (query != null && query.isNotEmpty) {
      queryBuilder = queryBuilder.or(
        'name.ilike.%$query%,description.ilike.%$query%',
      );
    }

    // Server-side category filtering
    if (categories != null && categories.isNotEmpty) {
      // Use 'in' filter with proper PostgreSQL array syntax
      if (categories.length == 1) {
        queryBuilder = queryBuilder.eq('category', categories.first);
      } else {
        queryBuilder = queryBuilder.inFilter('category', categories);
      }
    }

    // PERFORMANCE: Fetch cuisine IDs first (with timeout) before building query
    // Server-side cuisine filtering
    List<String>? cuisineIds;
    if (cuisines != null && cuisines.isNotEmpty) {
      try {
        cuisineIds = await _getCuisineIds(cuisines).timeout(
          const Duration(seconds: 2),
          onTimeout: () => <String>[],
        );
        if (cuisineIds.isEmpty) {
          // If cuisine IDs couldn't be fetched, return empty result
          return PaginatedResult(
            items: [],
            nextCursor: null,
            hasMore: false,
            totalCount: 0,
          );
        }
        // Apply cuisine filter
        if (cuisineIds.length == 1) {
          queryBuilder = queryBuilder.eq('cuisine_type_id', cuisineIds.first);
        } else {
          queryBuilder = queryBuilder.inFilter('cuisine_type_id', cuisineIds);
        }
      } catch (e) {
        debugPrint('⚠️ RemoteSource: Error fetching cuisine IDs: $e');
        return PaginatedResult(
          items: [],
          nextCursor: null,
          hasMore: false,
          totalCount: 0,
        );
      }
    }

    // Server-side price range filtering
    if (minPrice != null) {
      queryBuilder = queryBuilder.gte('price', minPrice);
    }

    if (maxPrice != null) {
      queryBuilder = queryBuilder.lte('price', maxPrice);
    }

    // Cursor-based pagination
    if (cursor != null) {
      queryBuilder = queryBuilder.lt('created_at', cursor);
    }

    // Apply ordering and limit at the END with timeout
    final response = await queryBuilder
        .order('created_at', ascending: false)
        .limit(limit + 1)
        .timeout(const Duration(seconds: 10));
    final responseList = response as List;

    // Parse items and handle missing images gracefully (exclude the extra one)
    final items = <MenuItem>[];
    for (final json in responseList.take(limit)) {
      try {
        final item = MenuItem.fromJson(json);
        // Only include items with valid images
        if (item.image.isNotEmpty) {
          items.add(item);
        } else {
          debugPrint(
              '⚠️ RemoteSource: Skipping menu item with empty image: ${json['id']}');
        }
      } catch (e) {
        // Skip items that can't be parsed (e.g., missing required fields like image)
        final itemId = json['id']?.toString() ?? 'unknown';
        debugPrint(
            '⚠️ RemoteSource: Skipping menu item due to parsing error: $e');
        debugPrint('   Item ID: $itemId');
      }
    }

    // Determine if there are more items
    final hasMore = responseList.length > limit;
    final nextCursor = hasMore && items.isNotEmpty
        ? items.last.createdAt.toIso8601String()
        : null;

    debugPrint(
        '📡 RemoteSource: Fetched ${items.length} items (hasMore: $hasMore)');

    return PaginatedResult(
      items: items,
      nextCursor: nextCursor,
      hasMore: hasMore,
      totalCount: items.length,
    );
  }

  /// Get cuisine type IDs from names (with timeout and error handling)
  Future<List<String>> _getCuisineIds(List<String> cuisineNames) async {
    try {
      final response = await _supabase
          .from('cuisine_types')
          .select('id')
          .inFilter('name', cuisineNames)
          .timeout(const Duration(seconds: 2));

      return (response as List).map((item) => item['id'] as String).toList();
    } catch (e) {
      debugPrint('⚠️ RemoteSource: Error fetching cuisine IDs: $e');
      return [];
    }
  }
}
