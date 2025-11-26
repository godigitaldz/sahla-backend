import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/enhanced_menu_item.dart';
import '../models/menu_item_pricing.dart';
import '../models/menu_item_supplement.dart';
import '../models/menu_item_variant.dart';

class EnhancedMenuItemService {
  final _supabase = Supabase.instance.client;

  // Get enhanced menu item with all related data
  Future<EnhancedMenuItem> getEnhancedMenuItem(String menuItemId) async {
    try {
      debugPrint('🔍 Loading enhanced menu item: $menuItemId');

      // Load menu item directly from Supabase
      final response = await _supabase
          .from('menu_items')
          .select('*')
          .eq('id', menuItemId)
          .single();

      debugPrint('📦 Raw menu item data: $response');

      // Parse variants from JSON column
      final variantsJson = response['variants'] as List?;
      debugPrint('🔍 Variants JSON: $variantsJson');
      final variants = variantsJson
              ?.map((v) {
                try {
                  return MenuItemVariant.fromJson(v as Map<String, dynamic>);
                } catch (e) {
                  debugPrint('❌ Error parsing variant: $e');
                  return null;
                }
              })
              .whereType<MenuItemVariant>()
              .toList() ??
          [];
      debugPrint('✅ Parsed ${variants.length} variants');

      // Parse pricing from pricing_options JSON column
      final pricingJson = response['pricing_options'] as List?;
      debugPrint('🔍 Pricing options JSON: $pricingJson');
      final pricing = pricingJson
              ?.map((p) {
                try {
                  return MenuItemPricing.fromJson(p as Map<String, dynamic>);
                } catch (e) {
                  debugPrint('❌ Error parsing pricing: $e');
                  return null;
                }
              })
              .whereType<MenuItemPricing>()
              .toList() ??
          [];
      debugPrint('✅ Parsed ${pricing.length} pricing options');

      // Parse supplements from JSON column
      final supplementsJsonRaw = response['supplements'] as List?;
      debugPrint('🔍 Supplements JSON: $supplementsJsonRaw');
      final supplements = supplementsJsonRaw
              ?.map((s) {
                try {
                  final supplementMap = s as Map<String, dynamic>;
                  debugPrint(
                      '🔍 Parsing supplement: ${supplementMap['name']}, available_for_variants = ${supplementMap['available_for_variants']}');
                  final supplement = MenuItemSupplement.fromJson(supplementMap);
                  debugPrint(
                      '✅ Parsed supplement: ${supplement.name}, availableForVariants = ${supplement.availableForVariants}');
                  return supplement;
                } catch (e) {
                  debugPrint('❌ Error parsing supplement: $e');
                  return null;
                }
              })
              .whereType<MenuItemSupplement>()
              .toList() ??
          [];
      debugPrint('✅ Parsed ${supplements.length} supplements');

      // Parse ingredients from JSON column
      final ingredientsJson = response['ingredients'];
      debugPrint('🔍 Ingredients JSON: $ingredientsJson');
      List<String> ingredients = [];
      if (ingredientsJson is List) {
        ingredients = ingredientsJson.map((e) => e.toString()).toList();
      } else if (ingredientsJson is String && ingredientsJson.isNotEmpty) {
        // Handle comma-separated string format
        ingredients = ingredientsJson.split(',').map((e) => e.trim()).toList();
      }
      debugPrint('✅ Parsed ${ingredients.length} ingredients');

      // Create enhanced menu item
      // For supplements, we need to manually add available_for_variants since toJson() excludes it
      final supplementsJson = supplements.map((s) {
        final supplementJson = Map<String, dynamic>.from(s.toJson());
        supplementJson['available_for_variants'] = s.availableForVariants;
        return supplementJson;
      }).toList();

      final enhancedMenuItem = EnhancedMenuItem.fromJson({
        ...response,
        'variants': variants.map((v) => v.toJson()).toList(),
        'pricing': pricing.map((p) => p.toJson()).toList(),
        'supplements': supplementsJson,
        'ingredients': ingredients,
      });

      debugPrint('✅ Enhanced menu item loaded successfully');
      debugPrint('   Variants: ${enhancedMenuItem.variants.length}');
      debugPrint('   Pricing: ${enhancedMenuItem.pricing.length}');
      debugPrint('   Supplements: ${enhancedMenuItem.supplements.length}');
      debugPrint('   Ingredients: ${enhancedMenuItem.ingredients.length}');

      return enhancedMenuItem;
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading enhanced menu item: $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception('Failed to load enhanced menu item: $e');
    }
  }

  // Get all enhanced menu items for a restaurant
  Future<List<EnhancedMenuItem>> getRestaurantMenuItems(
      String restaurantId) async {
    try {
      debugPrint('🔍 Loading menu items for restaurant: $restaurantId');

      // Load menu items directly from Supabase
      final response = await _supabase
          .from('menu_items')
          .select('*')
          .eq('restaurant_id', restaurantId)
          .eq('is_available', true)
          .order('category')
          .order('name');

      final menuItemsData = response as List;
      debugPrint('📦 Found ${menuItemsData.length} menu items');

      final List<EnhancedMenuItem> menuItems = [];

      for (final itemData in menuItemsData) {
        try {
          // Parse variants from JSON column
          final variantsJson = itemData['variants'] as List?;
          final variants = variantsJson
                  ?.map((v) {
                    try {
                      return MenuItemVariant.fromJson(
                          v as Map<String, dynamic>);
                    } catch (e) {
                      debugPrint('❌ Error parsing variant: $e');
                      return null;
                    }
                  })
                  .whereType<MenuItemVariant>()
                  .toList() ??
              [];

          // Parse pricing from pricing_options JSON column
          final pricingJson = itemData['pricing_options'] as List?;
          final pricing = pricingJson
                  ?.map((p) {
                    try {
                      return MenuItemPricing.fromJson(
                          p as Map<String, dynamic>);
                    } catch (e) {
                      debugPrint('❌ Error parsing pricing: $e');
                      return null;
                    }
                  })
                  .whereType<MenuItemPricing>()
                  .toList() ??
              [];

          // Parse supplements from JSON column
          final supplementsJsonRaw = itemData['supplements'] as List?;
          final supplements = supplementsJsonRaw
                  ?.map((s) {
                    try {
                      return MenuItemSupplement.fromJson(
                          s as Map<String, dynamic>);
                    } catch (e) {
                      debugPrint('❌ Error parsing supplement: $e');
                      return null;
                    }
                  })
                  .whereType<MenuItemSupplement>()
                  .toList() ??
              [];

          // Parse ingredients from JSON column
          final ingredientsJson = itemData['ingredients'];
          List<String> ingredients = [];
          if (ingredientsJson is List) {
            ingredients = ingredientsJson.map((e) => e.toString()).toList();
          } else if (ingredientsJson is String && ingredientsJson.isNotEmpty) {
            ingredients =
                ingredientsJson.split(',').map((e) => e.trim()).toList();
          }

          // For supplements, we need to manually add available_for_variants since toJson() excludes it
          final supplementsJson = supplements.map((s) {
            final supplementJson = Map<String, dynamic>.from(s.toJson());
            supplementJson['available_for_variants'] = s.availableForVariants;
            return supplementJson;
          }).toList();

          final enhancedItem = EnhancedMenuItem.fromJson({
            ...itemData,
            'variants': variants.map((v) => v.toJson()).toList(),
            'pricing': pricing.map((p) => p.toJson()).toList(),
            'supplements': supplementsJson,
            'ingredients': ingredients,
          });

          menuItems.add(enhancedItem);
        } catch (e) {
          debugPrint('❌ Error loading menu item ${itemData['id']}: $e');
        }
      }

      debugPrint('✅ Loaded ${menuItems.length} enhanced menu items');
      return menuItems;
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading restaurant menu items: $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception('Failed to load restaurant menu items: $e');
    }
  }

  // Add variant to menu item
  Future<MenuItemVariant> addVariant({
    required String menuItemId,
    required String name,
    String? description,
    bool isDefault = false,
  }) async {
    try {
      debugPrint('➕ Adding variant to menu item: $menuItemId');

      // Load current variants
      final menuItemData = await _supabase
          .from('menu_items')
          .select('variants')
          .eq('id', menuItemId)
          .single();

      final currentVariants =
          (menuItemData['variants'] as List?)?.cast<Map<String, dynamic>>() ??
              [];

      // Create new variant
      final newVariant = MenuItemVariant(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        menuItemId: menuItemId,
        name: name,
        description: description,
        isDefault: isDefault,
        displayOrder: currentVariants.length,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Add to variants array
      currentVariants.add(newVariant.toJson());

      // Update menu item
      await _supabase
          .from('menu_items')
          .update({'variants': currentVariants}).eq('id', menuItemId);

      debugPrint('✅ Variant added successfully');
      return newVariant;
    } catch (e, stackTrace) {
      debugPrint('❌ Error adding variant: $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception('Failed to add variant: $e');
    }
  }

  // Add pricing to menu item
  Future<MenuItemPricing> addPricing({
    required String menuItemId,
    required String size,
    required String portion,
    required double price,
    String? variantId,
    bool isDefault = false,
  }) async {
    try {
      debugPrint('➕ Adding pricing to menu item: $menuItemId');

      // Load current pricing options
      final menuItemData = await _supabase
          .from('menu_items')
          .select('pricing_options')
          .eq('id', menuItemId)
          .single();

      final currentPricing = (menuItemData['pricing_options'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];

      // Create new pricing
      final newPricing = MenuItemPricing(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        menuItemId: menuItemId,
        variantId: variantId,
        size: size,
        portion: portion,
        price: price,
        isDefault: isDefault,
        displayOrder: currentPricing.length,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Add to pricing array
      currentPricing.add(newPricing.toJson());

      // Update menu item
      await _supabase
          .from('menu_items')
          .update({'pricing_options': currentPricing}).eq('id', menuItemId);

      debugPrint('✅ Pricing added successfully');
      return newPricing;
    } catch (e, stackTrace) {
      debugPrint('❌ Error adding pricing: $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception('Failed to add pricing: $e');
    }
  }

  // Add supplement to menu item
  Future<MenuItemSupplement> addSupplement({
    required String menuItemId,
    required String name,
    required double price,
    String? description,
    bool isAvailable = true,
    List<String>? availableForVariants,
  }) async {
    try {
      debugPrint('➕ Adding supplement to menu item: $menuItemId');

      // Load current supplements
      final menuItemData = await _supabase
          .from('menu_items')
          .select('supplements')
          .eq('id', menuItemId)
          .single();

      final currentSupplements = (menuItemData['supplements'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];

      // Create new supplement
      final newSupplement = MenuItemSupplement(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        menuItemId: menuItemId,
        name: name,
        price: price,
        description: description,
        isAvailable: isAvailable,
        displayOrder: currentSupplements.length,
        availableForVariants: availableForVariants ?? [],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Add to supplements array with available_for_variants field
      // If availableForVariants is provided, use it; otherwise use empty array (available for all)
      final supplementJson = Map<String, dynamic>.from(newSupplement.toJson());
      // Ensure we always set available_for_variants, even if it's an empty list
      final variantList = availableForVariants ?? [];
      supplementJson['available_for_variants'] = variantList;

      // Debug: Print to verify variant assignment
      debugPrint(
          '📦 Adding supplement with available_for_variants: $variantList');
      debugPrint('📦 Supplement JSON keys: ${supplementJson.keys}');
      debugPrint(
          '📦 available_for_variants value: ${supplementJson['available_for_variants']}');
      debugPrint(
          '📦 available_for_variants type: ${supplementJson['available_for_variants'].runtimeType}');

      currentSupplements.add(supplementJson);

      // Debug: Print the entire supplements array before saving
      debugPrint('📦 Full supplements array before save:');
      for (var i = 0; i < currentSupplements.length; i++) {
        final supp = currentSupplements[i];
        debugPrint(
            '  [$i] ${supp['name']}: available_for_variants = ${supp['available_for_variants']}');
      }

      // Update menu item
      await _supabase
          .from('menu_items')
          .update({'supplements': currentSupplements}).eq('id', menuItemId);

      // Verify the update
      debugPrint('✅ Database update completed');

      // Reload to verify
      final verifyData = await _supabase
          .from('menu_items')
          .select('supplements')
          .eq('id', menuItemId)
          .single();

      debugPrint('📦 Supplements after save:');
      final savedSupplements = verifyData['supplements'] as List? ?? [];
      for (var i = 0; i < savedSupplements.length; i++) {
        final supp = savedSupplements[i] as Map<String, dynamic>;
        debugPrint(
            '  [$i] ${supp['name']}: available_for_variants = ${supp['available_for_variants']}');
      }

      debugPrint('✅ Supplement added successfully');
      return newSupplement;
    } catch (e, stackTrace) {
      debugPrint('❌ Error adding supplement: $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception('Failed to add supplement: $e');
    }
  }

  // Update variant
  Future<MenuItemVariant> updateVariant({
    required String menuItemId,
    required String variantId,
    String? name,
    String? description,
    bool? isDefault,
    bool? isAvailable,
  }) async {
    try {
      debugPrint('🔄 Updating variant: $variantId');

      // Load current variants
      final menuItemData = await _supabase
          .from('menu_items')
          .select('variants')
          .eq('id', menuItemId)
          .single();

      final currentVariants =
          (menuItemData['variants'] as List?)?.cast<Map<String, dynamic>>() ??
              [];

      // Find and update variant
      final variantIndex =
          currentVariants.indexWhere((v) => v['id'] == variantId);

      if (variantIndex == -1) {
        throw Exception('Variant not found: $variantId');
      }

      final variantData = currentVariants[variantIndex];
      final variant = MenuItemVariant.fromJson(variantData);

      // Update variant
      final updatedVariant = variant.copyWith(
        name: name ?? variant.name,
        description: description ?? variant.description,
        isDefault: isDefault ?? variant.isDefault,
        updatedAt: DateTime.now(),
      );

      // Update is_available if provided (stored in variant map, not in MenuItemVariant model)
      final updatedVariantData = updatedVariant.toJson();
      if (isAvailable != null) {
        updatedVariantData['is_available'] = isAvailable;
      }

      // If setting as default, unset other defaults
      if (isDefault == true) {
        for (var i = 0; i < currentVariants.length; i++) {
          if (i != variantIndex && currentVariants[i]['is_default'] == true) {
            currentVariants[i]['is_default'] = false;
            currentVariants[i]['updated_at'] = DateTime.now().toIso8601String();
          }
        }
      }

      // Replace variant in array
      currentVariants[variantIndex] = updatedVariantData;

      // Update menu item
      await _supabase
          .from('menu_items')
          .update({'variants': currentVariants}).eq('id', menuItemId);

      debugPrint('✅ Variant updated successfully');
      return updatedVariant;
    } catch (e, stackTrace) {
      debugPrint('❌ Error updating variant: $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception('Failed to update variant: $e');
    }
  }

  // Delete variant
  Future<void> deleteVariant({
    required String menuItemId,
    required String variantId,
  }) async {
    try {
      debugPrint('🗑️ Deleting variant: $variantId');

      // Load current variants and pricing
      final menuItemData = await _supabase
          .from('menu_items')
          .select('variants, pricing_options, supplements')
          .eq('id', menuItemId)
          .single();

      final currentVariants =
          (menuItemData['variants'] as List?)?.cast<Map<String, dynamic>>() ??
              [];
      final currentPricing = (menuItemData['pricing_options'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];
      final currentSupplements = (menuItemData['supplements'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];

      // Remove variant
      currentVariants.removeWhere((v) => v['id'] == variantId);

      // Remove all pricing options for this variant
      currentPricing.removeWhere((p) => p['variant_id'] == variantId);

      // Remove variant from supplements' available_for_variants
      for (final supplement in currentSupplements) {
        final availableForVariants =
            (supplement['available_for_variants'] as List?)?.cast<String>() ??
                [];
        if (availableForVariants.contains(variantId)) {
          availableForVariants.remove(variantId);
          supplement['available_for_variants'] = availableForVariants;
        }
      }

      // Update menu item
      await _supabase.from('menu_items').update({
        'variants': currentVariants,
        'pricing_options': currentPricing,
        'supplements': currentSupplements,
      }).eq('id', menuItemId);

      debugPrint('✅ Variant deleted successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Error deleting variant: $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception('Failed to delete variant: $e');
    }
  }

  // Update pricing
  Future<MenuItemPricing> updatePricing({
    required String menuItemId,
    required String pricingId,
    String? size,
    String? portion,
    double? price,
    bool? isDefault,
  }) async {
    try {
      debugPrint('🔄 Updating pricing: $pricingId');

      // Load current pricing
      final menuItemData = await _supabase
          .from('menu_items')
          .select('pricing_options')
          .eq('id', menuItemId)
          .single();

      final currentPricing = (menuItemData['pricing_options'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];

      // Find and update pricing
      final pricingIndex =
          currentPricing.indexWhere((p) => p['id'] == pricingId);

      if (pricingIndex == -1) {
        throw Exception('Pricing not found: $pricingId');
      }

      final pricingData = currentPricing[pricingIndex];
      final pricing = MenuItemPricing.fromJson(pricingData);

      // Update pricing
      final updatedPricing = pricing.copyWith(
        size: size ?? pricing.size,
        portion: portion ?? pricing.portion,
        price: price ?? pricing.price,
        isDefault: isDefault ?? pricing.isDefault,
        updatedAt: DateTime.now(),
      );

      // If setting as default, unset other defaults for same variant
      if (isDefault == true && pricing.variantId != null) {
        for (var i = 0; i < currentPricing.length; i++) {
          if (i != pricingIndex &&
              currentPricing[i]['variant_id'] == pricing.variantId &&
              currentPricing[i]['is_default'] == true) {
            currentPricing[i]['is_default'] = false;
            currentPricing[i]['updated_at'] = DateTime.now().toIso8601String();
          }
        }
      }

      // Replace pricing in array
      currentPricing[pricingIndex] = updatedPricing.toJson();

      // Update menu item
      await _supabase
          .from('menu_items')
          .update({'pricing_options': currentPricing}).eq('id', menuItemId);

      debugPrint('✅ Pricing updated successfully');
      return updatedPricing;
    } catch (e, stackTrace) {
      debugPrint('❌ Error updating pricing: $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception('Failed to update pricing: $e');
    }
  }

  // Delete pricing
  Future<void> deletePricing({
    required String menuItemId,
    required String pricingId,
  }) async {
    try {
      debugPrint('🗑️ Deleting pricing: $pricingId');

      // Load current pricing
      final menuItemData = await _supabase
          .from('menu_items')
          .select('pricing_options')
          .eq('id', menuItemId)
          .single();

      final currentPricing = (menuItemData['pricing_options'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];

      // Remove pricing
      currentPricing.removeWhere((p) => p['id'] == pricingId);

      // Update menu item
      await _supabase
          .from('menu_items')
          .update({'pricing_options': currentPricing}).eq('id', menuItemId);

      debugPrint('✅ Pricing deleted successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Error deleting pricing: $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception('Failed to delete pricing: $e');
    }
  }

  // Update supplement
  Future<MenuItemSupplement> updateSupplement({
    required String menuItemId,
    required String supplementId,
    String? name,
    String? description,
    double? price,
    bool? isAvailable,
    List<String>? availableForVariants,
  }) async {
    try {
      debugPrint('🔄 Updating supplement: $supplementId');

      // Load current supplements
      final menuItemData = await _supabase
          .from('menu_items')
          .select('supplements')
          .eq('id', menuItemId)
          .single();

      final currentSupplements = (menuItemData['supplements'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];

      // Find and update supplement
      final supplementIndex =
          currentSupplements.indexWhere((s) => s['id'] == supplementId);

      if (supplementIndex == -1) {
        throw Exception('Supplement not found: $supplementId');
      }

      final supplementData = currentSupplements[supplementIndex];
      final supplement = MenuItemSupplement.fromJson(supplementData);

      // Update supplement
      final updatedSupplement = supplement.copyWith(
        name: name ?? supplement.name,
        description: description ?? supplement.description,
        price: price ?? supplement.price,
        isAvailable: isAvailable ?? supplement.isAvailable,
        availableForVariants:
            availableForVariants ?? supplement.availableForVariants,
        updatedAt: DateTime.now(),
      );

      // Replace supplement in array
      currentSupplements[supplementIndex] = {
        ...updatedSupplement.toJson(),
        'available_for_variants': updatedSupplement.availableForVariants,
      };

      // Update menu item
      await _supabase
          .from('menu_items')
          .update({'supplements': currentSupplements}).eq('id', menuItemId);

      debugPrint('✅ Supplement updated successfully');
      return updatedSupplement;
    } catch (e, stackTrace) {
      debugPrint('❌ Error updating supplement: $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception('Failed to update supplement: $e');
    }
  }

  // Delete supplement
  Future<void> deleteSupplement({
    required String menuItemId,
    required String supplementId,
  }) async {
    try {
      debugPrint('🗑️ Deleting supplement: $supplementId');

      // Load current supplements
      final menuItemData = await _supabase
          .from('menu_items')
          .select('supplements')
          .eq('id', menuItemId)
          .single();

      final currentSupplements = (menuItemData['supplements'] as List?)
              ?.cast<Map<String, dynamic>>() ??
          [];

      // Remove supplement
      currentSupplements.removeWhere((s) => s['id'] == supplementId);

      // Update menu item
      await _supabase
          .from('menu_items')
          .update({'supplements': currentSupplements}).eq('id', menuItemId);

      debugPrint('✅ Supplement deleted successfully');
    } catch (e, stackTrace) {
      debugPrint('❌ Error deleting supplement: $e');
      debugPrint('Stack trace: $stackTrace');
      throw Exception('Failed to delete supplement: $e');
    }
  }
}
