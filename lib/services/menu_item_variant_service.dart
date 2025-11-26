import 'package:flutter/foundation.dart';

import '../models/menu_item.dart';
import '../widgets/menu_item_full_popup/helpers/special_pack_helper.dart';

/// Service for handling menu item variants expansion and management
///
/// This service provides intelligent variant expansion, converting items with
/// variants into separate menu items for better display and searchability.
///
/// Features:
/// - Variant expansion with proper naming
/// - Price handling from variant data
/// - Consistent ID generation for variant items
/// - Performance optimizations for large lists
class MenuItemVariantService {
  /// Expand menu items with variants into separate items
  ///
  /// Takes a list of menu items and expands any items with variants into
  /// separate menu items, making each variant a standalone item.
  ///
  /// Example:
  /// Input: Pizza (Small: 500 DA, Medium: 700 DA, Large: 900 DA)
  /// Output:
  ///   - Pizza Small (500 DA)
  ///   - Pizza Medium (700 DA)
  ///   - Pizza Large (900 DA)
  static List<MenuItem> expandVariantsToSeparateItems(List<MenuItem> items) {
    if (items.isEmpty) return items;

    debugPrint(
        '🔍 MenuItemVariantService: Processing ${items.length} items for variant expansion');

    final expandedItems = <MenuItem>[];
    int totalVariantsExpanded = 0;
    int specialPacksSkipped = 0;

    for (final item in items) {
      // Check if this is a special pack - DON'T expand special packs!
      if (SpecialPackHelper.isSpecialPack(item)) {
        // Special packs: Keep as single card with formatted name
        final formattedItem = SpecialPackHelper.processForDisplay(item);
        expandedItems.add(formattedItem);
        specialPacksSkipped++;

        if (kDebugMode) {
          debugPrint('🎁 Special pack (not expanded): ${formattedItem.name}');
        }
      } else if (item.variants.isEmpty) {
        // No variants, add the item as-is
        expandedItems.add(item);
      } else {
        // Regular items with variants: Expand them
        debugPrint(
            '🔍 Expanding ${item.variants.length} variants for: ${item.name}');

        final variantItems = _expandItemVariants(item);
        expandedItems.addAll(variantItems);
        totalVariantsExpanded += variantItems.length;
      }
    }

    if (totalVariantsExpanded > 0 || specialPacksSkipped > 0) {
      debugPrint(
          '✅ MenuItemVariantService: Processed ${items.length} items → ${expandedItems.length} items');
      if (totalVariantsExpanded > 0) {
        debugPrint('   📦 Expanded: $totalVariantsExpanded variant items');
      }
      if (specialPacksSkipped > 0) {
        debugPrint('   🎁 Special packs (single cards): $specialPacksSkipped');
      }
    }

    return expandedItems;
  }

  /// Expand a single menu item's variants into separate items
  static List<MenuItem> _expandItemVariants(MenuItem item) {
    final variantItems = <MenuItem>[];

    for (var i = 0; i < item.variants.length; i++) {
      final variant = item.variants[i];

      // Extract variant name from multiple possible fields
      final variantName = _extractVariantName(variant);

      if (variantName.isEmpty) {
        debugPrint(
            '⚠️ MenuItemVariantService: Skipping variant without name for item: ${item.name}');
        continue;
      }

      // Extract variant price
      final variantPrice = _extractVariantPrice(variant, item.price);

      // Generate unique ID for variant item
      final variantId = _generateVariantId(item.id, i, variantName);

      // Create new menu item with variant data
      final expandedItem = MenuItem(
        id: variantId,
        restaurantId: item.restaurantId,
        restaurantName: item.restaurantName,
        name: '${item.name} $variantName', // Append variant name
        description: item.description,
        image: item.image,
        images: item.images,
        price: variantPrice,
        category: item.category,
        cuisineTypeId: item.cuisineTypeId,
        categoryId: item.categoryId,
        cuisineType: item.cuisineType,
        categoryObj: item.categoryObj,
        isAvailable: item.isAvailable,
        isFeatured: item.isFeatured,
        preparationTime: item.preparationTime,
        rating: item.rating,
        reviewCount: item.reviewCount,
        mainIngredients: item.mainIngredients,
        ingredients: item.ingredients,
        isSpicy: item.isSpicy,
        spiceLevel: item.spiceLevel,
        isTraditional: item.isTraditional,
        isVegetarian: item.isVegetarian,
        isVegan: item.isVegan,
        isGlutenFree: item.isGlutenFree,
        isDairyFree: item.isDairyFree,
        isLowSodium: item.isLowSodium,
        variants: const [], // Don't include variants in expanded items
        pricingOptions: item.pricingOptions,
        supplements: item.supplements,
        calories: item.calories,
        protein: item.protein,
        carbs: item.carbs,
        fat: item.fat,
        fiber: item.fiber,
        sugar: item.sugar,
        createdAt: item.createdAt,
        updatedAt: item.updatedAt,
      );

      variantItems.add(expandedItem);

      debugPrint(
          '✅ Expanded variant: ${expandedItem.name} (${expandedItem.price} DA)');
    }

    return variantItems;
  }

  /// Extract variant name from variant data
  /// Tries multiple possible field names for maximum compatibility
  static String _extractVariantName(Map<String, dynamic> variant) {
    // Try different possible name fields
    final possibleFields = [
      'name',
      'variant_name',
      'size',
      'type',
      'label',
      'title',
    ];

    for (final field in possibleFields) {
      final value = variant[field];
      if (value != null && value.toString().isNotEmpty) {
        return value.toString();
      }
    }

    return '';
  }

  /// Extract variant price from variant data
  /// Falls back to item's base price if variant price is not found
  static double _extractVariantPrice(
      Map<String, dynamic> variant, double basePrice) {
    // Try different possible price fields
    final possibleFields = [
      'price',
      'variant_price',
      'cost',
      'amount',
    ];

    for (final field in possibleFields) {
      final value = variant[field];
      if (value != null) {
        if (value is num) {
          return value.toDouble();
        } else if (value is String) {
          final parsed = double.tryParse(value);
          if (parsed != null) return parsed;
        }
      }
    }

    // Fallback to base price
    return basePrice;
  }

  /// Generate a unique ID for a variant item
  /// Format: {itemId}_variant_{index}_{normalizedName}
  static String _generateVariantId(
      String itemId, int index, String variantName) {
    final normalizedName = variantName
        .toLowerCase()
        .replaceAll(RegExp('[^a-z0-9]+'), '_')
        .replaceAll(RegExp('_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');

    return '${itemId}_variant_${index}_$normalizedName';
  }

  /// Check if an item has variants
  static bool hasVariants(MenuItem item) {
    return item.variants.isNotEmpty;
  }

  /// Get variant count for an item
  static int getVariantCount(MenuItem item) {
    return item.variants.length;
  }

  /// Get total variant count for a list of items
  static int getTotalVariantCount(List<MenuItem> items) {
    return items.fold(0, (sum, item) => sum + item.variants.length);
  }

  /// Extract variant options from an item (for display purposes)
  /// Returns a list of variant option strings like "Small (500 DA)"
  static List<String> getVariantOptions(MenuItem item) {
    if (item.variants.isEmpty) return [];

    return item.variants.map((variant) {
      final name = _extractVariantName(variant);
      final price = _extractVariantPrice(variant, item.price);
      return '$name ($price DA)';
    }).toList();
  }

  /// Batch expand multiple item lists efficiently
  /// Useful for processing multiple categories at once
  static Map<String, List<MenuItem>> expandVariantsByCategory(
      Map<String, List<MenuItem>> groupedItems) {
    final result = <String, List<MenuItem>>{};

    for (final entry in groupedItems.entries) {
      result[entry.key] = expandVariantsToSeparateItems(entry.value);
    }

    return result;
  }

  /// Performance: Check if any items have variants before processing
  /// Avoids unnecessary iteration for lists with no variants
  static bool anyItemsHaveVariants(List<MenuItem> items) {
    return items.any((item) => item.variants.isNotEmpty);
  }
}
