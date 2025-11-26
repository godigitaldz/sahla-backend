import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../models/menu_item.dart';
import '../../domain/models/menu_items_state.dart';

/// Local data source for menu items (fallback from cache/database)
class MenuItemsLocalSource {
  SupabaseClient get _supabase => Supabase.instance.client;

  /// Get menu items from local storage
  Future<PaginatedResult<MenuItem>> getMenuItems({
    required int limit,
  }) async {
    try {
      // Simple local query without complex filtering
      // Note: Only filters menu_items table, not restaurants
      final response = await _supabase
          .from('menu_items')
          .select('*')
          .eq('is_available', true)
          .order('created_at', ascending: false)
          .limit(limit);

      // Parse items and handle missing images gracefully
      final items = <MenuItem>[];
      for (final json in (response as List)) {
        try {
          final item = MenuItem.fromJson(json);
          // Only include items with valid images
          if (item.image.isNotEmpty) {
            items.add(item);
          } else {
            debugPrint(
                '⚠️ LocalSource: Skipping menu item with empty image: ${json['id']}');
          }
        } catch (e) {
          // Skip items that can't be parsed (e.g., missing required fields like image)
          final itemId = json['id']?.toString() ?? 'unknown';
          debugPrint(
              '⚠️ LocalSource: Skipping menu item due to parsing error: $e');
          debugPrint('   Item ID: $itemId');
        }
      }

      debugPrint('💾 LocalSource: Retrieved ${items.length} items');

      return PaginatedResult(
        items: items,
        nextCursor: null,
        hasMore: false,
        totalCount: items.length,
      );
    } catch (e) {
      debugPrint('❌ LocalSource: Error retrieving items: $e');
      // Return empty result instead of throwing to allow graceful fallback
      return PaginatedResult(
        items: [],
        nextCursor: null,
        hasMore: false,
        totalCount: 0,
      );
    }
  }
}
