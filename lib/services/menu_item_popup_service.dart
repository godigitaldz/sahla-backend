import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/enhanced_menu_item.dart';
import '../models/menu_item.dart';
import '../services/enhanced_menu_item_service.dart';
import '../services/image_api_service.dart';

/// Service for handling data operations in MenuItemFullPopup
/// Extracted from the widget to separate data fetching logic
class MenuItemPopupService {
  final EnhancedMenuItemService _menuItemService;

  MenuItemPopupService({
    EnhancedMenuItemService? menuItemService,
  }) : _menuItemService = menuItemService ?? EnhancedMenuItemService();

  /// Load enhanced menu item data
  Future<EnhancedMenuItem?> getEnhancedMenuItem(String menuItemId) async {
    try {
      return await _menuItemService.getEnhancedMenuItem(menuItemId);
    } catch (e) {
      debugPrint(
          '❌ MenuItemPopupService: Error loading enhanced menu item: $e');
      rethrow;
    }
  }

  /// Load restaurant drinks optimized
  Future<List<MenuItem>> loadRestaurantDrinksOptimized(
      String restaurantId) async {
    try {
      debugPrint('🥤 Loading drinks for restaurant: $restaurantId');

      final supabase = Supabase.instance.client;

      // PERFORMANCE: Select only needed fields instead of all columns
      // This reduces data transfer and improves query speed
      final response = await supabase
          .from('menu_items')
          .select(
              'id, restaurant_id, restaurant_name, name, description, image, images, price, category, cuisine_type_id, category_id, is_available, is_featured, preparation_time, rating, review_count, variants, pricing_options, supplements, created_at, updated_at')
          .eq('restaurant_id', restaurantId)
          .eq('is_available', true)
          .limit(50); // Increased limit to get more items

      final allItems = response as List;
      debugPrint(
          '🥤 Total available items from restaurant: ${allItems.length}');

      // Filter drinks by checking category (case-insensitive)
      final drinks = allItems
          .where((item) {
            final category = (item['category'] ?? '').toString().toLowerCase();
            final isDrink = category.contains('drink') ||
                category.contains('beverage') ||
                category.contains('boisson'); // French for drink
            if (isDrink) {
              debugPrint(
                  '  Found drink: ${item['name']} (category: ${item['category']})');
            }
            return isDrink;
          })
          .map((item) {
            try {
              final menuItem = MenuItem.fromJson(item);
              // Only include items with valid images
              return menuItem.image.isNotEmpty ? menuItem : null;
            } catch (e) {
              // Skip items that can't be parsed (e.g., missing required fields like image)
              debugPrint(
                  '⚠️ MenuItemPopupService: Skipping drink due to parsing error: $e');
              return null;
            }
          })
          .whereType<MenuItem>()
          .toList();

      debugPrint('🥤 Filtered drinks: ${drinks.length}');
      return drinks;
    } catch (e) {
      debugPrint('❌ MenuItemPopupService: Error loading restaurant drinks: $e');
      return [];
    }
  }

  /// Load drink image from cache or fetch via Node.js API (with Supabase fallback)
  Future<String?> loadDrinkImage(String drinkId) async {
    try {
      // Use optimized image API service (Node.js API with Supabase fallback)
      return await ImageApiService().loadImageById(drinkId);
    } catch (e) {
      debugPrint('❌ MenuItemPopupService: Error loading drink image: $e');
      return null;
    }
  }

  /// Batch load drink images - optimized with Node.js API (with Supabase fallback)
  /// This replaces the N+1 query pattern with a single batch query
  Future<Map<String, String>> loadDrinkImages(List<String> drinkIds) async {
    // Early return if no IDs to fetch
    if (drinkIds.isEmpty) {
      return {};
    }

    try {
      // Use optimized image API service (Node.js API with Supabase fallback)
      final imageCache = await ImageApiService().loadImagesBatch(drinkIds);

      debugPrint(
          '✅ MenuItemPopupService: Batch loaded ${imageCache.length}/${drinkIds.length} drink images');

      return imageCache;
    } catch (e) {
      debugPrint(
          '❌ MenuItemPopupService: Error batch loading drink images: $e');
      return {};
    }
  }
}
