import 'package:flutter/foundation.dart';

import '../../../models/menu_item.dart';
import '../../../models/menu_item_pricing.dart';
import '../../../models/menu_item_variant.dart';

/// Helper class for special pack formatting and detection
class SpecialPackHelper {
  /// Check if item is a special pack based on category
  static bool isSpecialPack(MenuItem item) {
    final category = item.category.toLowerCase();
    final result = category.contains('pack') ||
        category.contains('combo') ||
        category.contains('special');

    if (kDebugMode) {
      debugPrint(
          '🔍 isSpecialPack check: category="$category", result=$result');
    }

    return result;
  }

  /// Parse quantity from variant description (format: "qty:2" or "qty:2|options:...")
  static int parseQuantity(String? description) {
    if (description == null || !description.startsWith('qty:')) return 1;

    try {
      // Split by | to handle options
      final parts = description.split('|');
      final qtyPart = parts[0]; // "qty:2"
      final qtyValue = qtyPart.split(':')[1]; // "2"
      return int.tryParse(qtyValue) ?? 1;
    } catch (e) {
      return 1;
    }
  }

  /// Parse options from variant description
  /// Format: "qty:2|options:Poulet,Viande,Crispy|ingredients:..."
  /// Returns: ['Poulet', 'Viande', 'Crispy']
  static List<String> parseOptions(String? description) {
    if (description == null || !description.contains('|options:')) {
      return [];
    }

    try {
      final parts = description.split('|options:');
      if (parts.length > 1) {
        // Get the options part and stop at the next separator (|ingredients: or |anything:)
        final optionsPart = parts[1].split('|')[0];
        return optionsPart
            .split(',')
            .map((o) => o.trim())
            .where((o) => o.isNotEmpty)
            .toList();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error parsing options: $e');
      }
    }
    return [];
  }

  /// Parse ingredients from variant description
  /// Format: "qty:2|options:A,B|ingredients:Cheese,Tomato,Lettuce"
  /// Returns: ['Cheese', 'Tomato', 'Lettuce']
  static List<String> parseIngredients(String? description) {
    if (description == null || !description.contains('|ingredients:')) {
      return [];
    }

    try {
      final parts = description.split('|ingredients:');
      if (parts.length > 1) {
        // Get the ingredients part and split by comma
        final ingredientsPart =
            parts[1].split('|')[0]; // In case there are more fields after
        return ingredientsPart
            .split(',')
            .map((i) => i.trim())
            .where((i) => i.isNotEmpty)
            .toList();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error parsing ingredients: $e');
      }
    }
    return [];
  }

  /// Parse hidden supplements from variant description
  /// Format: "qty:2|options:A,B|hidden_supplements:Supp1,Supp2|supplements:..."
  /// Returns: ['Supp1', 'Supp2']
  static List<String> parseHiddenSupplements(String? description) {
    if (description == null || !description.contains('|hidden_supplements:')) {
      return [];
    }

    try {
      final parts = description.split('|hidden_supplements:');
      if (parts.length > 1) {
        // Get the hidden_supplements part and stop at the next separator
        final hiddenSupplementsPart = parts[1].split('|')[0];
        return hiddenSupplementsPart
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error parsing hidden supplements: $e');
      }
    }
    return [];
  }

  /// Parse supplements from variant description
  /// Format: "qty:2|options:A,B|ingredients:X,Y|supplements:Supplement1:50.0,Supplement2:30.0"
  /// Returns a Map of supplement name to price
  static Map<String, double> parseSupplements(String? description) {
    if (description == null || !description.contains('|supplements:')) {
      return {};
    }

    try {
      final parts = description.split('|supplements:');
      if (parts.length > 1) {
        // Get the supplements part and split by comma
        final supplementsPart =
            parts[1].split('|')[0]; // In case there are more fields after
        final supplements = supplementsPart.split(',');
        final result = <String, double>{};

        for (final supplement in supplements) {
          final trimmed = supplement.trim();
          if (trimmed.isNotEmpty) {
            // Parse format: "name:price" or just "name" (default price 0)
            if (trimmed.contains(':')) {
              final namePriceParts = trimmed.split(':');
              if (namePriceParts.length >= 2) {
                final name = namePriceParts[0].trim();
                final priceStr = namePriceParts[1].trim();
                final price = double.tryParse(priceStr) ?? 0.0;
                if (name.isNotEmpty) {
                  result[name] = price;
                }
              }
            } else {
              // Old format without price (default to 0)
              result[trimmed] = 0.0;
            }
          }
        }
        return result;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error parsing supplements: $e');
      }
    }
    return {};
  }

  /// Check if pack has global supplements configuration
  /// Global supplements are stored in pricing_options[pack].offer_details or item.offer_details
  static Map<String, double> getGlobalSupplements(MenuItem item) {
    try {
      // Check pricing_options for global supplements (stored in offer_details within pack pricing)
      if (item.pricingOptions.isNotEmpty) {
        final packPricing = item.pricingOptions.firstWhere(
          (p) => p['size']?.toString().toLowerCase() == 'pack',
          orElse: () => <String, dynamic>{},
        );

        if (packPricing.isNotEmpty && packPricing['offer_details'] is Map) {
          final offerDetails = packPricing['offer_details'] as Map;
          if (offerDetails['global_supplements'] != null) {
            if (kDebugMode) {
              debugPrint(
                  '💊 Found global supplements in pack pricing: ${offerDetails['global_supplements']}');
            }
            final supplements = offerDetails['global_supplements'];
            // Handle Map format (new format with prices)
            if (supplements is Map) {
              final Map<String, double> result = {};
              supplements.forEach((key, value) {
                result[key.toString()] = value is num
                    ? value.toDouble()
                    : (double.tryParse(value.toString()) ?? 0.0);
              });
              return result;
            }
            // Handle List format (old format without prices - default to 0.0)
            else if (supplements is List) {
              final Map<String, double> result = {};
              for (final supplement in supplements) {
                result[supplement.toString()] = 0.0;
              }
              return result;
            }
          }
        }
      }

      // Fallback: Check item-level offer_details for global supplements
      if (item.offerDetails.isNotEmpty &&
          item.offerDetails['global_supplements'] != null) {
        if (kDebugMode) {
          debugPrint(
              '💊 Found global supplements in item offer_details: ${item.offerDetails['global_supplements']}');
        }
        final supplements = item.offerDetails['global_supplements'];
        // Handle Map format (new format with prices)
        if (supplements is Map) {
          final Map<String, double> result = {};
          supplements.forEach((key, value) {
            result[key.toString()] = value is num
                ? value.toDouble()
                : (double.tryParse(value.toString()) ?? 0.0);
          });
          return result;
        }
        // Handle List format (old format without prices - default to 0.0)
        else if (supplements is List) {
          final Map<String, double> result = {};
          for (final supplement in supplements) {
            result[supplement.toString()] = 0.0;
          }
          return result;
        }
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error getting global supplements: $e');
      }
    }
    return {};
  }

  /// Parse hidden global supplements from offer_details
  /// Format: offer_details['hidden_global_supplements'] = ['Supp1', 'Supp2']
  /// Returns: ['Supp1', 'Supp2']
  static List<String> getHiddenGlobalSupplements(MenuItem item) {
    try {
      // Check pricing_options for hidden global supplements
      if (item.pricingOptions.isNotEmpty) {
        final packPricing = item.pricingOptions.firstWhere(
          (p) => p['size']?.toString().toLowerCase() == 'pack',
          orElse: () => <String, dynamic>{},
        );

        if (packPricing.isNotEmpty && packPricing['offer_details'] is Map) {
          final offerDetails = packPricing['offer_details'] as Map;
          if (offerDetails['hidden_global_supplements'] is List) {
            return (offerDetails['hidden_global_supplements'] as List)
                .map((e) => e.toString())
                .where((e) => e.isNotEmpty)
                .toList();
          }
        }
      }

      // Fallback: Check item-level offer_details
      if (item.offerDetails.isNotEmpty &&
          item.offerDetails['hidden_global_supplements'] is List) {
        return (item.offerDetails['hidden_global_supplements'] as List)
            .map((e) => e.toString())
            .where((e) => e.isNotEmpty)
            .toList();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error getting hidden global supplements: $e');
      }
    }
    return [];
  }

  /// Check if pack has global ingredients configuration
  /// Global ingredients are stored in pricing_options[pack].offer_details or item.offer_details
  static List<String> getGlobalIngredients(MenuItem item) {
    try {
      // Check pricing_options for global ingredients (stored in offer_details within pack pricing)
      if (item.pricingOptions.isNotEmpty) {
        final packPricing = item.pricingOptions.firstWhere(
          (p) => p['size']?.toString().toLowerCase() == 'pack',
          orElse: () => <String, dynamic>{},
        );

        if (packPricing.isNotEmpty && packPricing['offer_details'] is Map) {
          final offerDetails = packPricing['offer_details'] as Map;
          if (offerDetails['global_ingredients'] is List) {
            if (kDebugMode) {
              debugPrint(
                  '🌿 Found global ingredients in pack pricing: ${offerDetails['global_ingredients']}');
            }
            return (offerDetails['global_ingredients'] as List)
                .map((e) => e.toString())
                .toList();
          }
        }
      }

      // Fallback: Check item-level offer_details for global ingredients
      if (item.offerDetails.isNotEmpty &&
          item.offerDetails['global_ingredients'] is List) {
        if (kDebugMode) {
          debugPrint(
              '🌿 Found global ingredients in item offer_details: ${item.offerDetails['global_ingredients']}');
        }
        return (item.offerDetails['global_ingredients'] as List)
            .map((e) => e.toString())
            .toList();
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('❌ Error getting global ingredients: $e');
      }
    }
    return [];
  }

  /// Format special pack display name
  /// Example: "Pack Familial (2)x Burger, (1)x Fries et (1)x Drink"
  static String formatPackName(MenuItem item) {
    if (kDebugMode) {
      debugPrint('🎁 formatPackName called for: ${item.name}');
      debugPrint('   Variants count: ${item.variants.length}');
    }

    if (item.variants.isEmpty) {
      if (kDebugMode) {
        debugPrint('   ⚠️ No variants, returning base name: ${item.name}');
      }
      return item.name;
    }

    // Check if name is already formatted (contains " et " or starts with quantity pattern)
    // This prevents double-formatting: "Pack A, B et C A, B et C"
    final isAlreadyFormatted = item.name.contains(' et ') ||
        item.name.contains(')x ') ||
        _containsAnyVariantName(item.name, item.variants);

    if (isAlreadyFormatted) {
      if (kDebugMode) {
        debugPrint('   ✅ Already formatted, returning: ${item.name}');
      }
      return item.name; // Already formatted, return as-is
    }

    final packItems = <String>[];

    for (final variantJson in item.variants) {
      try {
        final itemName = variantJson['name'] as String? ?? '';
        final description = variantJson['description'] as String?;
        final quantity = parseQuantity(description);

        if (kDebugMode) {
          debugPrint('   Processing variant: $itemName (qty: $quantity)');
        }

        if (itemName.isNotEmpty) {
          if (quantity > 1) {
            packItems.add('($quantity)x $itemName');
          } else {
            packItems.add(itemName);
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('   ❌ Error processing variant: $e');
        }
        continue;
      }
    }

    if (packItems.isEmpty) {
      if (kDebugMode) {
        debugPrint(
            '   ⚠️ No valid pack items found, returning base name: ${item.name}');
      }
      return item.name;
    }

    // Build formatted string with commas and "et" before last item
    final StringBuffer formatted = StringBuffer(item.name);
    formatted.write(' ');

    for (int i = 0; i < packItems.length; i++) {
      if (i == packItems.length - 1 && i > 0) {
        // Last item: use "et" instead of comma
        formatted.write(' et ${packItems[i]}');
      } else if (i > 0) {
        // Middle items: use comma
        formatted.write(', ${packItems[i]}');
      } else {
        // First item
        formatted.write(packItems[i]);
      }
    }

    final result = formatted.toString();
    if (kDebugMode) {
      debugPrint('   ✅ Formatted result: $result');
    }
    return result;
  }

  /// Check if the name already contains any variant name (helper for duplicate detection)
  static bool _containsAnyVariantName(
      String name, List<Map<String, dynamic>> variants) {
    for (final variantJson in variants) {
      try {
        final itemName = variantJson['name'] as String? ?? '';
        if (itemName.isNotEmpty && name.contains(itemName)) {
          return true;
        }
      } catch (e) {
        continue;
      }
    }
    return false;
  }

  /// Get display name for menu item (formatted for special packs, regular for others)
  static String getDisplayName(MenuItem item) {
    if (isSpecialPack(item)) {
      return formatPackName(item);
    }
    return item.name;
  }

  /// Process menu item for display (format pack name if needed)
  static MenuItem processForDisplay(MenuItem item) {
    if (isSpecialPack(item)) {
      return item.copyWith(
        name: formatPackName(item),
        // Keep variants for popup display
      );
    }
    return item;
  }

  /// Calculate total price for special pack with variants
  /// For special packs: pricing is the base price, variants determine quantities
  static double calculatePackPrice({
    required MenuItem menuItem,
    required MenuItemPricing? pricing,
    required Map<String, int> variantQuantities,
    required double supplementsPrice,
    required double drinksPrice,
  }) {
    if (pricing == null) {
      if (kDebugMode) {
        debugPrint('⚠️ Special pack has no pricing selected');
      }
      return 0.0;
    }

    final basePrice = pricing.price;

    // Calculate total quantity from all variants
    int totalQuantity = 0;
    for (final quantity in variantQuantities.values) {
      totalQuantity += quantity;
    }

    final totalPrice = (basePrice + supplementsPrice) *
            (totalQuantity > 0 ? totalQuantity : 1) +
        drinksPrice;

    if (kDebugMode) {
      debugPrint('💰 Special Pack Price Calculation:');
      debugPrint('   Base price: $basePrice');
      debugPrint('   Total variants quantity: $totalQuantity');
      debugPrint('   Supplements: $supplementsPrice');
      debugPrint('   Drinks: $drinksPrice');
      debugPrint('   Total: $totalPrice');
    }

    return totalPrice;
  }

  /// Calculate unit price for special pack
  static double calculatePackUnitPrice({
    required MenuItem menuItem,
    required MenuItemPricing? pricing,
    required double supplementsPrice,
    required double drinksPrice,
  }) {
    if (pricing == null) return 0.0;

    final basePrice = pricing.price;
    return basePrice + supplementsPrice + drinksPrice;
  }

  /// Calculate supplements price for a specific variant in special pack
  /// This method properly handles per-variant supplement pricing
  /// [includeGlobalSupplements] controls whether global supplements are included
  /// (should be true for first variant only in multi-variant scenarios)
  static double calculateVariantSupplementsPrice({
    required MenuItem menuItem,
    required List<MenuItemVariant> variants,
    required String variantId,
    required Map<String, Map<int, List<String>>> packSupplementSelections,
    required List<String> globalPackSupplements,
    bool includeGlobalSupplements = true,
  }) {
    double supplementsPrice = 0.0;

    // Get global supplements map
    final globalSupplementsMap = getGlobalSupplements(menuItem);

    // Find the variant
    final variant = variants.where((v) => v.id == variantId).firstOrNull;
    if (variant == null) {
      if (kDebugMode) {
        debugPrint(
            '⚠️ Variant $variantId not found for supplements calculation');
      }
      return 0.0;
    }

    // Calculate variant-specific supplements from packSupplementSelections
    final variantName = variant.name;
    if (packSupplementSelections.containsKey(variantName)) {
      final quantitiesMap = packSupplementSelections[variantName]!;
      final variantSupplements = parseSupplements(variant.description);

      for (final quantityEntry in quantitiesMap.entries) {
        final selectedSupplements = quantityEntry.value;
        for (final supplementName in selectedSupplements) {
          final supplementPrice = variantSupplements[supplementName] ?? 0.0;
          supplementsPrice += supplementPrice;
        }
      }
    }

    // Add global supplement prices (these apply to the pack, not per-variant)
    // Only include if includeGlobalSupplements is true
    if (includeGlobalSupplements) {
      for (final supplementName in globalPackSupplements) {
        final supplementPrice = globalSupplementsMap[supplementName] ?? 0.0;
        supplementsPrice += supplementPrice;
      }
    }

    if (kDebugMode) {
      debugPrint(
          '💰 Variant Supplements Price for $variantName: $supplementsPrice (global included: $includeGlobalSupplements)');
    }

    return supplementsPrice;
  }

  /// Build customizations map for special pack cart
  static Map<String, dynamic> buildCustomizations({
    required MenuItem menuItem,
    required String? restaurantId,
    required List<MenuItemVariant> selectedVariants,
    required int quantity,
    required Map<String, dynamic> packSupplementSelections,
    required List<String> globalPackSupplements,
    required Map<String, int> drinkQuantities,
    required Map<String, dynamic> ingredientPreferences,
    required String popupSessionId,
  }) {
    return {
      'menu_item_id': menuItem.id,
      'restaurant_id': restaurantId ?? '',
      'main_item_quantity': quantity,
      'variants': selectedVariants.map((v) => v.toJson()).toList(),
      'pack_supplement_selections': packSupplementSelections,
      'global_pack_supplements': globalPackSupplements,
      'drink_quantities': drinkQuantities,
      'ingredient_preferences': ingredientPreferences,
      'popup_session_id': popupSessionId,
    };
  }

  /// Get free drinks info for special pack LTO
  static (List<String> freeDrinkIds, int freeDrinksQuantity)
      getFreeDrinksForPack({
    required MenuItem menuItem,
    required MenuItemPricing? pricing,
    required bool isLTO,
  }) {
    if (pricing != null && pricing.freeDrinksIncluded) {
      return (pricing.freeDrinksList, pricing.freeDrinksQuantity);
    }

    if (isLTO && menuItem.offerFreeDrinksList.isNotEmpty) {
      return (menuItem.offerFreeDrinksList, menuItem.offerFreeDrinksQuantity);
    }

    return ([], 0);
  }

  /// Check if special pack has global ingredients/supplements from LTO offer_details
  static (Map<String, double> globalSupplements, List<String> globalIngredients)
      getGlobalPackOfferDetails({
    required MenuItem menuItem,
    required MenuItemPricing? pricing,
  }) {
    // First check pricing offer_details
    if (pricing != null && pricing.offerDetails.isNotEmpty) {
      final globalSupps = <String, double>{};
      final globalIngs = <String>[];

      if (pricing.offerDetails['global_supplements'] != null) {
        final supplements = pricing.offerDetails['global_supplements'];
        if (supplements is Map) {
          supplements.forEach((key, value) {
            globalSupps[key.toString()] = value is num
                ? value.toDouble()
                : (double.tryParse(value.toString()) ?? 0.0);
          });
        }
      }

      if (pricing.offerDetails['global_ingredients'] != null) {
        final ingredients = pricing.offerDetails['global_ingredients'];
        if (ingredients is List) {
          globalIngs.addAll(ingredients.map((e) => e.toString()));
        }
      }

      if (globalSupps.isNotEmpty || globalIngs.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('💊 Found global pack offer details in pricing:');
          debugPrint('   Supplements: $globalSupps');
          debugPrint('   Ingredients: $globalIngs');
        }
        return (globalSupps, globalIngs);
      }
    }

    // Fallback to item-level
    return (getGlobalSupplements(menuItem), getGlobalIngredients(menuItem));
  }
}
