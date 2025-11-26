import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/menu_item.dart';

/// Helper class to load and manage LTO items for LTO mode
class LTOModeHelper {
  /// Load LTO items from database
  static Future<List<MenuItem>> loadLTOItems({String? restaurantId}) async {
    try {
      debugPrint("🎯 Loading LTO items for LTO mode...");

      final supabase = Supabase.instance.client;

      // Build query - add restaurant filter if specified
      var query =
          supabase.from('menu_items').select('*').eq('is_available', true);

      // Filter by restaurant ID if provided
      if (restaurantId != null && restaurantId.isNotEmpty) {
        query = query.eq('restaurant_id', restaurantId);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(100); // Load more items for list view

      // Parse items and handle missing images gracefully
      final items = <MenuItem>[];
      for (final json in (response as List)) {
        try {
          final item = MenuItem.fromJson(json);
          // Only include items with active LTO offers and valid images
          if (item.isOfferActive &&
              !item.hasExpiredLTOOffer &&
              item.image.isNotEmpty) {
            items.add(item);
          }
        } catch (e) {
          // Skip items that can't be parsed
          debugPrint("⚠️ Skipping LTO item due to parsing error: $e");
        }
      }

      debugPrint("✅ Loaded ${items.length} LTO items for LTO mode");

      return items;
    } catch (e) {
      debugPrint("❌ Error loading LTO items: $e");
      return [];
    }
  }

  /// Filter LTO items by search query
  static List<MenuItem> filterLTOItems(
    List<MenuItem> items,
    String searchQuery,
  ) {
    if (searchQuery.trim().isEmpty) {
      return items;
    }

    final query = searchQuery.toLowerCase();
    return items.where((item) {
      final matchesName = item.name.toLowerCase().contains(query);
      final matchesDescription = item.description.toLowerCase().contains(query);
      final matchesCategory = item.category.toLowerCase().contains(query);
      return matchesName || matchesDescription || matchesCategory;
    }).toList();
  }
}
