import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/menu_item_supplement.dart';

/// Service to manage restaurant supplements through restaurant_supplements table
class RestaurantSupplementService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Create a new supplement for a restaurant
  /// Creates supplement in menu_item_supplements with null menu_item_id
  /// and adds entry to restaurant_supplements table
  Future<MenuItemSupplement> createRestaurantSupplement({
    required String restaurantId,
    required String name,
    required double price,
    String? description,
    bool isAvailable = true,
  }) async {
    try {
      debugPrint(
          '➕ Creating restaurant supplement: $name for restaurant: $restaurantId');

      // First, create supplement in menu_item_supplements table with null menu_item_id
      final supplementResponse = await _supabase
          .from('menu_item_supplements')
          .insert({
            'menu_item_id': null, // No menu item initially
            'name': name,
            'description': description ?? '',
            'price': price,
            'is_available': isAvailable,
            'display_order': 0,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      final supplementId = supplementResponse['id'] as String;
      debugPrint(
          '✅ Created supplement in menu_item_supplements with ID: $supplementId');

      // Then, add entry to restaurant_supplements table
      await _supabase.from('restaurant_supplements').insert({
        'restaurant_id': restaurantId,
        'supplement_id': supplementId,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      debugPrint('✅ Added supplement to restaurant_supplements table');

      // Parse and return the created supplement
      return MenuItemSupplement.fromJson(supplementResponse);
    } catch (e) {
      debugPrint('❌ Error creating restaurant supplement: $e');
      rethrow;
    }
  }

  /// Get all supplements for a restaurant from restaurant_supplements table
  /// Optimized with a single query using Postgres join
  Future<List<MenuItemSupplement>> getRestaurantSupplements(
      String restaurantId) async {
    try {
      debugPrint('🔍 Loading supplements for restaurant: $restaurantId');

      // Use a single optimized query with join to reduce database round trips
      // This is faster than two separate queries
      // Note: Can't order nested relations directly in Supabase, so we sort in Dart
      final supplementsResponse =
          await _supabase.from('restaurant_supplements').select('''
            menu_item_supplements!inner(
              id,
              name,
              description,
              price,
              is_available,
              display_order,
              created_at,
              updated_at
            )
          ''').eq('restaurant_id', restaurantId);

      if (supplementsResponse.isEmpty) {
        debugPrint('⚠️ No supplements found for restaurant');
        return [];
      }

      // Parse the nested response structure
      // Filter for restaurant-level supplements (null menu_item_id) in Dart
      final supplementsList = <MenuItemSupplement>[];
      for (final row in (supplementsResponse as List)) {
        final supplementData = row['menu_item_supplements'];
        if (supplementData != null) {
          try {
            final supplement = MenuItemSupplement.fromJson(
              supplementData as Map<String, dynamic>,
            );
            // Only include restaurant-level supplements (null menu_item_id)
            // menuItemId will be empty string if null in database
            if (supplement.menuItemId.isEmpty) {
              supplementsList.add(supplement);
              debugPrint(
                  '   ✅ Added restaurant-level supplement: ${supplement.name} (menuItemId: "${supplement.menuItemId}")');
            } else {
              debugPrint(
                  '   ⏭️ Skipped linked supplement: ${supplement.name} (menuItemId: "${supplement.menuItemId}")');
            }
          } catch (e) {
            debugPrint('⚠️ Error parsing supplement: $e');
          }
        }
      }

      // Sort in Dart: by display_order, then by created_at
      supplementsList.sort((a, b) {
        final orderComparison = a.displayOrder.compareTo(b.displayOrder);
        if (orderComparison != 0) return orderComparison;
        return a.createdAt.compareTo(b.createdAt);
      });

      debugPrint(
          '✅ Loaded ${supplementsList.length} supplements for restaurant');
      return supplementsList;
    } catch (e) {
      debugPrint('❌ Error loading restaurant supplements: $e');
      // Fallback to original two-query approach if join fails
      return _getRestaurantSupplementsFallback(restaurantId);
    }
  }

  /// Fallback method using two separate queries (original approach)
  Future<List<MenuItemSupplement>> _getRestaurantSupplementsFallback(
      String restaurantId) async {
    try {
      debugPrint('🔄 Using fallback method to load supplements');

      // Get supplement IDs from restaurant_supplements table
      final restaurantSupplementsResponse = await _supabase
          .from('restaurant_supplements')
          .select('supplement_id')
          .eq('restaurant_id', restaurantId);

      if (restaurantSupplementsResponse.isEmpty) {
        return [];
      }

      final supplementIds = (restaurantSupplementsResponse as List)
          .map((rs) => rs['supplement_id'].toString())
          .toList();

      if (supplementIds.isEmpty) {
        return [];
      }

      // Fetch supplements from menu_item_supplements table
      final supplementsResponse = await _supabase
          .from('menu_item_supplements')
          .select('*')
          .inFilter('id', supplementIds)
          .isFilter('menu_item_id', null) // Only restaurant-level supplements
          .order('display_order')
          .order('created_at');

      final supplementsList = (supplementsResponse as List)
          .map((s) => MenuItemSupplement.fromJson(s as Map<String, dynamic>))
          .toList();

      return supplementsList;
    } catch (e) {
      debugPrint('❌ Error in fallback method: $e');
      return [];
    }
  }

  /// Link a supplement to a menu item
  /// Updates menu_item_id in menu_item_supplements table
  Future<void> linkSupplementToMenuItem({
    required String supplementId,
    required String menuItemId,
  }) async {
    try {
      debugPrint(
          '🔗 Linking supplement $supplementId to menu item $menuItemId');

      await _supabase.from('menu_item_supplements').update({
        'menu_item_id': menuItemId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', supplementId);

      debugPrint('✅ Supplement linked to menu item successfully');
    } catch (e) {
      debugPrint('❌ Error linking supplement to menu item: $e');
      rethrow;
    }
  }

  /// Add a supplement to restaurant_supplements if it doesn't exist
  Future<void> ensureSupplementInRestaurant({
    required String restaurantId,
    required String supplementId,
  }) async {
    try {
      // Check if entry already exists
      final existingResponse = await _supabase
          .from('restaurant_supplements')
          .select('id')
          .eq('restaurant_id', restaurantId)
          .eq('supplement_id', supplementId)
          .maybeSingle();

      if (existingResponse == null) {
        // Entry doesn't exist, create it
        await _supabase.from('restaurant_supplements').insert({
          'restaurant_id': restaurantId,
          'supplement_id': supplementId,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
        debugPrint('✅ Added supplement to restaurant_supplements');
      } else {
        debugPrint('ℹ️ Supplement already in restaurant_supplements');
      }
    } catch (e) {
      debugPrint('❌ Error ensuring supplement in restaurant: $e');
      rethrow;
    }
  }
}
