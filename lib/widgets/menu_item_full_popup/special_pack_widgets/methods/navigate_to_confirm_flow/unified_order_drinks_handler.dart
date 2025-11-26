import 'package:flutter/foundation.dart';

import '../../../../../models/menu_item.dart';
import '../../../../../models/menu_item_pricing.dart';
import 'navigate_to_confirm_flow_params.dart';

/// Unified order drinks handler for LTO and regular items
/// Handles the scenario when both current selections and saved orders exist
class UnifiedOrderDrinksHandler {
  /// Calculate total paid drinks price globally (merging current selections + saved orders)
  /// Paid drinks are global for the entire order and should only be added once to the first item
  /// Current selections take precedence over saved orders
  static double calculateTotalPaidDrinksPrice({
    required NavigateToConfirmFlowParams params,
    Map<String, List<Map<String, dynamic>>>? savedVariantOrders,
  }) {
    double totalPaidDrinksPrice = 0.0;

    // Calculate from current selections first
    for (final entry in params.paidDrinkQuantities.entries) {
      if (entry.value > 0) {
        final drink = params.restaurantDrinks.firstWhere(
          (d) => d.id == entry.key,
          orElse: () => _createEmptyMenuItem(),
        );
        if (drink.price > 0) {
          totalPaidDrinksPrice += drink.price * entry.value;
        }
      }
    }

    // Also calculate paid drinks from saved orders (merge with current)
    // Only add if not already in current selections (current takes precedence)
    if (savedVariantOrders != null) {
      for (final variantEntry in savedVariantOrders.entries) {
        for (final savedOrder in variantEntry.value) {
          final savedPaidDrinkQuantities =
              savedOrder['paid_drink_quantities'] as Map?;
          if (savedPaidDrinkQuantities != null) {
            for (final entry in savedPaidDrinkQuantities.entries) {
              final drinkId = entry.key.toString();
              final qty = entry.value is int
                  ? entry.value
                  : int.tryParse(entry.value.toString()) ?? 0;

              // Only add if not already in current selections (current takes precedence)
              if (qty > 0 && !params.paidDrinkQuantities.containsKey(drinkId)) {
                final drink = params.restaurantDrinks.firstWhere(
                  (d) => d.id == drinkId,
                  orElse: () => _createEmptyMenuItem(),
                );
                if (drink.price > 0) {
                  totalPaidDrinksPrice += drink.price * qty;
                }
              }
            }
          }
        }
      }
    }

    if (kDebugMode) {
      debugPrint(
          '🥤 UnifiedOrderDrinksHandler: Total paid drinks price: $totalPaidDrinksPrice');
      debugPrint('   Current paid drinks: ${params.paidDrinkQuantities}');
    }

    return totalPaidDrinksPrice;
  }

  /// Merge paid drink quantities from saved orders with current selections
  /// Current selections take precedence if both exist
  /// Returns merged map with current selections overriding saved
  static Map<String, int> mergePaidDrinkQuantities({
    required NavigateToConfirmFlowParams params,
    Map<String, dynamic>? savedOrder,
  }) {
    final savedPaidDrinkQuantities =
        savedOrder?['paid_drink_quantities'] as Map?;

    // Current selections take precedence over saved orders
    final mergedPaidDrinkQuantities = <String, int>{
      if (savedPaidDrinkQuantities != null)
        ...Map<String, int>.from(savedPaidDrinkQuantities),
      ...params.paidDrinkQuantities, // Current selections override saved
    };

    if (kDebugMode && savedPaidDrinkQuantities != null) {
      debugPrint(
          '🥤 UnifiedOrderDrinksHandler: Merging paid drinks quantities');
      debugPrint('   Saved: $savedPaidDrinkQuantities');
      debugPrint('   Current: ${params.paidDrinkQuantities}');
      debugPrint('   Merged: $mergedPaidDrinkQuantities');
    }

    return mergedPaidDrinkQuantities;
  }

  /// Calculate free drinks quantities for LTO and regular items
  /// For LTO/regular items: multiplies base quantity by variant quantity
  /// For special packs: returns as-is (each pack gets its own free drinks)
  static Map<String, int> calculateFreeDrinksForVariant({
    required NavigateToConfirmFlowParams params,
    required MenuItemPricing? pricing,
    required int variantQuantity,
    required String variantId,
    String? variantName,
  }) {
    Map<String, int> freeDrinkQuantitiesForCart;

    if (!params.isSpecialPack) {
      // For LTO/regular items: get base free drinks quantity from pricing and multiply by variant quantity
      // This ensures each variant gets the correct number of free drinks based on its own quantity
      final baseFreeDrinksQty = pricing?.freeDrinksQuantity ?? 1;
      final freeDrinkIds = pricing?.freeDrinksList ?? [];

      // Calculate free drinks for this variant: base quantity × variant quantity
      freeDrinkQuantitiesForCart = {};

      // ✅ FIX: Include free drinks from pricing even if not manually selected
      // Also include manually selected free drinks
      final allFreeDrinkIds = <String>{};

      // 1. Add free drinks from pricing (available for this variant)
      // These should be included even if user hasn't manually selected them
      allFreeDrinkIds.addAll(freeDrinkIds);

      // 2. Add drinks from drinkQuantities (these are free drinks with quantities manually selected)
      // These are drinks the user explicitly selected as free drinks
      allFreeDrinkIds.addAll(params.drinkQuantities.keys);

      // 3. Add drinks from selectedDrinks (these are free drinks selected by user)
      // Include all selected drinks that are NOT in paidDrinkQuantities (they're free)
      for (final drink in params.selectedDrinks) {
        // Only include if NOT a paid drink (paid drinks are tracked separately)
        if (!params.paidDrinkQuantities.containsKey(drink.id)) {
          allFreeDrinkIds.add(drink.id);
        }
      }

      // Process all free drinks (from pricing + manually selected)
      for (final drinkId in allFreeDrinkIds) {
        // ✅ FIX: Exclude paid drinks - if a drink is in paidDrinkQuantities, it's not free
        if (params.paidDrinkQuantities.containsKey(drinkId) &&
            (params.paidDrinkQuantities[drinkId] ?? 0) > 0) {
          // This drink is paid, skip it (paid drinks are handled separately)
          continue;
        }

        // Check if this drink is in the free drinks list for this variant's pricing
        final isInFreeList = freeDrinkIds.contains(drinkId);
        // Check if it was manually selected as a free drink
        final isSelectedAsFree = params.drinkQuantities.containsKey(drinkId) ||
            params.selectedDrinks.any((d) =>
                d.id == drinkId &&
                !params.paidDrinkQuantities.containsKey(d.id));

        // ✅ FIX: Include if: in free list from pricing OR manually selected as free
        // This ensures free drinks from pricing are always included, even if not manually selected
        if (isInFreeList || isSelectedAsFree) {
          // Use quantity from drinkQuantities if manually selected, otherwise use base quantity from pricing
          final selectedQuantity =
              params.drinkQuantities[drinkId] ?? baseFreeDrinksQty;
          // For LTO/regular items: multiply by variant quantity (per-item calculation)
          final totalFreeDrinksForVariant = selectedQuantity * variantQuantity;
          freeDrinkQuantitiesForCart[drinkId] = totalFreeDrinksForVariant;
        }
      }

      if (kDebugMode) {
        debugPrint(
            '🥤 UnifiedOrderDrinksHandler: Calculating free drinks for variant');
        debugPrint('   Variant: ${variantName ?? variantId}');
        debugPrint('   Base free drinks qty per item: $baseFreeDrinksQty');
        debugPrint('   Variant quantity: $variantQuantity');
        debugPrint('   Free drink IDs from pricing: $freeDrinkIds');
        debugPrint(
            '   Selected free drinks (from drinkQuantities): ${params.drinkQuantities.keys.toList()}');
        debugPrint(
            '   Selected free drinks (from selectedDrinks): ${params.selectedDrinks.map((d) => d.id).toList()}');
        debugPrint('   All free drink IDs (pricing + selected): $allFreeDrinkIds');
        debugPrint('   Calculated free drinks: $freeDrinkQuantitiesForCart');
      }
    } else {
      // Special packs: use as-is (each pack gets its own free drinks)
      freeDrinkQuantitiesForCart =
          Map<String, int>.from(params.drinkQuantities);
    }

    return freeDrinkQuantitiesForCart;
  }

  /// Calculate free drinks from saved order for LTO and regular items
  /// For LTO/regular items: ALWAYS multiplies by saved order quantity (per-item calculation)
  /// For special packs: returns as-is (each pack gets its own free drinks)
  static Map<String, int> calculateFreeDrinksFromSavedOrder({
    required NavigateToConfirmFlowParams params,
    required Map<String, dynamic> savedOrder,
    required int quantity,
  }) {
    final Map<String, int> savedDrinkQuantities =
        Map<String, int>.from(savedOrder['drink_quantities'] as Map? ?? {});

    // Check if we have separate free_drink_quantities (preferred)
    final savedFreeDrinkQuantities =
        savedOrder['free_drink_quantities'] as Map?;

    if (!params.isSpecialPack) {
      // ✅ FIX: For LTO/regular items, ALWAYS multiply free drinks by quantity (per-item calculation)
      // Free drinks are per-item: each item gets its own free drinks
      // Saved order stores per-item quantities (e.g., 1 free drink per item)
      // We need to multiply by cart item quantity to get total free drinks for this cart item
      if (savedFreeDrinkQuantities != null) {
        // Use free_drink_quantities if available (separated) - these are per-item quantities
        final freeQuantities = Map<String, int>.from(savedFreeDrinkQuantities);
        final multipliedFreeQuantities = freeQuantities.map(
          (drinkId, qty) => MapEntry(drinkId.toString(), qty * quantity),
        );

        if (kDebugMode) {
          debugPrint(
              '🥤 UnifiedOrderDrinksHandler: Multiplying free drinks by quantity (per-item calculation): $quantity');
          debugPrint('   Original free (per-item): $freeQuantities');
          debugPrint(
              '   Multiplied free (total for this cart item): $multipliedFreeQuantities');
          debugPrint('   Item quantity: $quantity');
        }

        return multipliedFreeQuantities;
      } else {
        // Fallback: if free_drink_quantities not available, assume all drinks in drink_quantities are free
        // and multiply by quantity (this handles old saved orders format)
        // Note: This assumes drink_quantities contains per-item quantities
        final multipliedFreeQuantities = savedDrinkQuantities.map(
          (drinkId, qty) => MapEntry(drinkId.toString(), qty * quantity),
        );

        if (kDebugMode) {
          debugPrint(
              '🥤 UnifiedOrderDrinksHandler: Multiplying all drinks by quantity (fallback, per-item calculation): $quantity');
          debugPrint(
              '   Original (per-item): ${savedOrder['drink_quantities']}');
          debugPrint(
              '   Multiplied (total for cart item): $multipliedFreeQuantities');
        }

        return multipliedFreeQuantities;
      }
    } else {
      // Special packs: use as-is (each pack gets its own free drinks, no multiplication needed)
      if (savedFreeDrinkQuantities != null) {
        return Map<String, int>.from(savedFreeDrinkQuantities);
      } else {
        return savedDrinkQuantities;
      }
    }
  }

  /// Determine if drinks price should be added to this variant/order
  /// Drinks price is only added to the FIRST item overall (across all variants/orders)
  /// Returns the drinks price for this variant/order (0.0 if not first)
  static double getDrinksPriceForItem({
    required double totalPaidDrinksPrice,
    required bool isFirstItem,
    required bool drinksAlreadyAdded,
  }) {
    final shouldAddDrinksPrice = isFirstItem && !drinksAlreadyAdded;
    final drinksPriceForThisItem =
        shouldAddDrinksPrice ? totalPaidDrinksPrice : 0.0;

    if (kDebugMode && shouldAddDrinksPrice) {
      debugPrint(
          '🥤 UnifiedOrderDrinksHandler: Adding paid drinks price to first item: $totalPaidDrinksPrice');
    }

    return drinksPriceForThisItem;
  }

  /// Merge all drink quantities (free + paid) for a variant/order
  /// Combines free drinks and paid drinks into a single map
  /// For multiple variants: only includes drinks in the FIRST variant
  static Map<String, int> mergeAllDrinkQuantities({
    required Map<String, int> freeDrinkQuantities,
    required Map<String, int> paidDrinkQuantities,
    required bool isMultipleVariants,
    required bool isFirstVariant,
  }) {
    // Only include drinks in the FIRST variant when multiple variants are selected
    if (isMultipleVariants && !isFirstVariant) {
      return <String, int>{};
    }

    // Combine free and paid drinks
    final allDrinkQuantities = <String, int>{
      ...freeDrinkQuantities,
      ...paidDrinkQuantities, // Always include paid drinks, even if price was already added
    };

    if (kDebugMode) {
      debugPrint('🥤 UnifiedOrderDrinksHandler: Merging all drink quantities');
      debugPrint('   Free drinks: $freeDrinkQuantities');
      debugPrint('   Paid drinks: $paidDrinkQuantities');
      debugPrint('   Combined: $allDrinkQuantities');
      debugPrint('   Is first variant: $isFirstVariant');
    }

    return allDrinkQuantities;
  }

  /// Helper to create empty MenuItem for fallback
  static MenuItem _createEmptyMenuItem() {
    return MenuItem(
      id: '',
      name: '',
      description: '',
      price: 0,
      restaurantId: '',
      category: '',
      isAvailable: true,
      image: '',
      isFeatured: false,
      preparationTime: 0,
      rating: 0.0,
      reviewCount: 0,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
