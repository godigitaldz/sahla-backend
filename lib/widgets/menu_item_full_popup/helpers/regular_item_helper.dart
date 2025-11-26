import 'package:flutter/foundation.dart';

import '../../../models/enhanced_menu_item.dart';
import '../../../models/menu_item.dart';
import '../../../models/menu_item_pricing.dart';
import '../../../models/menu_item_variant.dart';
import 'popup_type_helper.dart';

/// Helper class for regular item (non-special pack) specific logic
/// Handles standard variant selection, size selection, and UI rendering
class RegularItemHelper {
  /// Check if standard variant selector should be used
  /// Returns true for LTO regular and regular items (not special packs)
  static bool shouldUseStandardVariantSelector(MenuItem item) {
    return PopupTypeHelper.shouldUseStandardVariantSelector(item);
  }

  /// Get available variants for regular item display
  /// Filters out hidden variants (is_available = false)
  static List<MenuItemVariant> getAvailableVariants({
    required MenuItem menuItem,
    required EnhancedMenuItem? enhancedMenuItem,
  }) {
    if (enhancedMenuItem == null || enhancedMenuItem.variants.isEmpty) {
      // Return default variant if none exist
      return [
        MenuItemVariant(
          id: 'default',
          menuItemId: menuItem.id,
          name: 'Standard',
          description: 'Default option',
          isDefault: true,
          displayOrder: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        )
      ];
    }

    // Filter out hidden variants - check is_available in the raw variant data
    return enhancedMenuItem.variants.where((variant) {
      // Find variant in raw pricing options to check is_available
      final variantData = menuItem.variants.firstWhere(
        (v) => v['id'] == variant.id,
        orElse: () => <String, dynamic>{},
      );

      // If is_available is not set, default to true (visible)
      final isAvailable = variantData['is_available'] ?? true;
      return isAvailable;
    }).toList();
  }

  /// Get pricing options for a specific variant
  static List<MenuItemPricing> getVariantPricing({
    required EnhancedMenuItem? enhancedMenuItem,
    required String variantId,
  }) {
    if (enhancedMenuItem == null) {
      return [];
    }

    return enhancedMenuItem.pricing
        .where((p) => p.variantId == variantId)
        .toList();
  }

  /// Get supplements for a specific variant
  /// Shows supplements that are:
  /// 1. Explicitly assigned to this variant (available_for_variants contains variantId)
  /// 2. Global supplements (available_for_variants is empty - legacy supplements)
  static List<dynamic> getVariantSupplements({
    required EnhancedMenuItem? enhancedMenuItem,
    required String variantId,
  }) {
    if (enhancedMenuItem == null) {
      return [];
    }

    final allSupplements = enhancedMenuItem.supplements;
    return allSupplements.where((supp) {
      final availableFor = supp.availableForVariants;

      // If available_for_variants is empty, treat as global (show for all variants)
      // This handles legacy supplements that were added before variant-specific feature
      if (availableFor.isEmpty) {
        if (kDebugMode) {
          debugPrint(
              '🌐 RegularItemHelper: Supplement ${supp.name} has empty available_for_variants - treating as global');
        }
        return true; // Global supplement - show for all variants
      }

      // Check if this supplement is available for the current variant
      final variantIdStr = variantId.toString();
      final availableForList = availableFor.map((e) => e.toString()).toList();
      final isAssigned = availableForList.contains(variantIdStr);

      if (kDebugMode) {
        debugPrint(
            '🔍 RegularItemHelper: Supplement ${supp.name} for variant $variantIdStr: availableFor=$availableForList, isAssigned=$isAssigned');
      }

      return isAssigned;
    }).toList();
  }

  /// Get main ingredients for display
  static List<String> getMainIngredients(EnhancedMenuItem? enhancedMenuItem) {
    if (enhancedMenuItem == null) {
      return [];
    }

    return enhancedMenuItem.mainIngredients
            ?.split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        [];
  }

  /// Get optional ingredients for customization
  static List<String> getOptionalIngredients(
      EnhancedMenuItem? enhancedMenuItem) {
    if (enhancedMenuItem == null) {
      return [];
    }

    return enhancedMenuItem.ingredients;
  }

  /// Check if variant has any ingredients (main or optional)
  static bool hasIngredients(EnhancedMenuItem? enhancedMenuItem) {
    final main = getMainIngredients(enhancedMenuItem);
    final optional = getOptionalIngredients(enhancedMenuItem);
    return main.isNotEmpty || optional.isNotEmpty;
  }

  /// Check if variant has supplements
  static bool hasSupplements({
    required EnhancedMenuItem? enhancedMenuItem,
    required String variantId,
  }) {
    final supplements = getVariantSupplements(
      enhancedMenuItem: enhancedMenuItem,
      variantId: variantId,
    );
    return supplements.isNotEmpty;
  }

  /// Check if variant has pricing options
  static bool hasPricing({
    required EnhancedMenuItem? enhancedMenuItem,
    required String variantId,
  }) {
    final pricing = getVariantPricing(
      enhancedMenuItem: enhancedMenuItem,
      variantId: variantId,
    );
    return pricing.isNotEmpty;
  }

  /// Get default pricing for variant
  /// Returns first pricing option if available
  static MenuItemPricing? getDefaultPricing({
    required EnhancedMenuItem? enhancedMenuItem,
    required String variantId,
  }) {
    final pricing = getVariantPricing(
      enhancedMenuItem: enhancedMenuItem,
      variantId: variantId,
    );

    if (pricing.isEmpty) {
      return null;
    }

    // Try to find default pricing first
    try {
      final defaultPricing = pricing.firstWhere((p) => p.isDefault);
      return defaultPricing;
    } catch (_) {
      // No default pricing found, fall through to return first
    }

    // Fallback to first pricing
    return pricing.first;
  }

  /// Check if size selection should be shown as optional
  /// For LTO regular items, size is optional (extra charge)
  /// For regular items, size is required
  static bool isSizeOptional(MenuItem item) {
    return PopupTypeHelper.isLTO(item) && !PopupTypeHelper.isSpecialPack(item);
  }

  /// Check if size selection should be shown as required
  /// For regular items and special packs
  static bool isSizeRequired(MenuItem item) {
    return PopupTypeHelper.isSizeRequired(item);
  }

  /// Get base price for item
  /// ✅ FIX: Regular items use size price as main price, LTO regular uses item price as base
  /// - Regular items (non-LTO): base price = 0 (size price IS the main price)
  /// - LTO regular: base price = item.price (size is extra charge)
  /// - Special packs: pricing.price is the base price (special case)
  static double getBasePrice({
    required MenuItem item,
    required MenuItemPricing? pricing,
  }) {
    final isSpecialPack = PopupTypeHelper.isSpecialPack(item);
    final isLTO = PopupTypeHelper.isLTO(item);
    final isRegular = PopupTypeHelper.isRegular(item);

    if (isSpecialPack) {
      // Special Pack: pricing.price is the base price (special case)
      return pricing?.price ?? item.price;
    } else if (isLTO) {
      // LTO regular: base price is item.price (size is extra charge)
      return item.price;
    } else if (isRegular) {
      // Regular items: base price = 0 (size price IS the main price, not item.price)
      return 0.0;
    } else {
      // Fallback
      return item.price;
    }
  }

  /// Get extra charge for size selection
  /// ✅ FIX: Regular items use size price as main price, LTO regular uses size as extra
  /// - Regular items (non-LTO): size price = pricing.price (this IS the main price)
  /// - LTO regular: size extra = pricing.price (size is extra charge)
  /// - Special packs: no extra charge (size is part of base price)
  static double getSizeExtraCharge({
    required MenuItem item,
    required MenuItemPricing? pricing,
  }) {
    final isSpecialPack = PopupTypeHelper.isSpecialPack(item);
    final isLTO = PopupTypeHelper.isLTO(item);
    final isRegular = PopupTypeHelper.isRegular(item);

    if (isSpecialPack) {
      // Special Pack: no extra charge (size is part of base price)
      return 0.0;
    } else if (isLTO) {
      // LTO regular: pricing.price is extra charge for size
      return pricing?.price ?? 0.0;
    } else if (isRegular) {
      // Regular items: pricing.price IS the main price (not an extra charge)
      // Return it here so total = 0 + pricing.price = pricing.price
      return pricing?.price ?? 0.0;
    } else {
      // Fallback
      return pricing?.price ?? 0.0;
    }
  }

  /// Calculate total price for regular item
  static double calculatePrice({
    required MenuItem item,
    required MenuItemPricing? pricing,
    required double supplementsPrice,
    required double drinksPrice,
    required int quantity,
  }) {
    final basePrice = getBasePrice(item: item, pricing: pricing);
    final sizeExtra = getSizeExtraCharge(item: item, pricing: pricing);

    return (basePrice + sizeExtra + supplementsPrice) * quantity + drinksPrice;
  }

  /// Calculate unit price for regular item
  static double calculateUnitPrice({
    required MenuItem item,
    required MenuItemPricing? pricing,
    required double supplementsPrice,
    required double drinksPrice,
  }) {
    final basePrice = getBasePrice(item: item, pricing: pricing);
    final sizeExtra = getSizeExtraCharge(item: item, pricing: pricing);

    return basePrice + sizeExtra + supplementsPrice + drinksPrice;
  }
}
