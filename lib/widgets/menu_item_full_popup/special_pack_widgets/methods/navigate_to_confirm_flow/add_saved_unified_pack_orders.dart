import 'package:flutter/foundation.dart';

import '../../../../../cart_provider.dart';
import '../../../../../models/menu_item.dart';
import 'navigate_to_confirm_flow_params.dart';

/// Add saved unified pack orders to cart
/// Returns true if drinks were added, false otherwise
bool addSavedUnifiedPackOrdersToCart({
  required NavigateToConfirmFlowParams params,
  required List<Map<String, dynamic>> savedPackOrders,
  required double totalPaidDrinksPrice,
  required List<Map<String, dynamic>> Function() buildDrinksWithSizes,
  required bool isFirstOverallItem,
}) {
  bool drinksAdded = false;

  for (final savedOrder in savedPackOrders) {
    final quantity = (savedOrder['quantity'] as num?)?.toInt() ?? 1;

    // Parse supplements for customizations
    final supplements = (savedOrder['supplements'] as List?)
            ?.map((s) => s as Map<String, dynamic>)
            .toList() ??
        const <Map<String, dynamic>>[];

    // Use saved total_price directly to ensure accuracy
    double perUnitPrice;
    if (savedOrder.containsKey('total_price')) {
      final savedTotalPrice = (savedOrder['total_price'] as num).toDouble();
      perUnitPrice =
          quantity > 0 ? (savedTotalPrice / quantity) : savedTotalPrice;
    } else {
      // Fallback: calculate from pricing and supplements
      final pricingJson = savedOrder['pricing'] as Map<String, dynamic>?;
      final basePrice = (pricingJson?['price'] as num?)?.toDouble() ??
          (params.menuItem.price > 0 ? params.menuItem.price : 200.0);
      final supplementsPrice = supplements.fold<double>(
          0.0, (sum, s) => sum + ((s['price'] as num?)?.toDouble() ?? 0.0));
      perUnitPrice = basePrice + supplementsPrice;
    }

    final removedIngredients = (savedOrder['removed_ingredients'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const <String>[];
    final ingredientPrefs = (savedOrder['ingredient_preferences'] as Map?)
            ?.map((k, v) => MapEntry(k.toString(), v.toString())) ??
        const <String, String>{};

    // Restore drinks from saved order
    final savedDrinks = (savedOrder['drinks'] as List?)?.map((d) {
          if (d is Map<String, dynamic>) {
            return d;
          }
          return <String, dynamic>{};
        }).toList() ??
        [];
    final savedDrinkQuantities =
        Map<String, int>.from(savedOrder['drink_quantities'] as Map? ?? {});

    // Restore separate free and paid quantities if available
    final savedFreeDrinkQuantities = savedOrder['free_drink_quantities'] != null
        ? Map<String, int>.from(savedOrder['free_drink_quantities'] as Map)
        : <String, int>{};

    // Paid drinks are global - only use current selections, NOT saved
    final mergedPaidDrinkQuantities = <String, int>{
      ...params.paidDrinkQuantities,
    };
    final mergedFreeDrinkQuantities = <String, int>{
      ...savedFreeDrinkQuantities,
      ...params.drinkQuantities,
    };

    // Build current paid drinks list to merge with saved drinks
    final currentPaidDrinks = <Map<String, dynamic>>[];
    for (final entry in params.paidDrinkQuantities.entries) {
      if (entry.value > 0) {
        final drink = params.restaurantDrinks.firstWhere(
          (d) => d.id == entry.key,
          orElse: () => MenuItem(
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
          ),
        );
        if (drink.id.isNotEmpty) {
          final map = drink.toJson();
          final sz = params.drinkSizesById[drink.id];
          if (sz != null && sz.isNotEmpty) map['size'] = sz;
          map['is_free'] = false;
          currentPaidDrinks.add(map);
        }
      }
    }

    // Build current free drinks list to merge with saved drinks
    final currentFreeDrinks = <Map<String, dynamic>>[];
    for (final drink in params.selectedDrinks) {
      if ((params.drinkQuantities[drink.id] ?? 0) > 0) {
        final map = drink.toJson();
        final sz = params.drinkSizesById[drink.id];
        if (sz != null && sz.isNotEmpty) map['size'] = sz;
        map['price'] = 0.0;
        map['is_free'] = true;
        currentFreeDrinks.add(map);
      }
    }

    // ✅ FIX: Update saved drinks with correct prices before merging
    // If a saved drink is in paid_drink_quantities, it should have the correct price
    // This handles cases where a drink appears both as free and paid
    final updatedSavedDrinks = savedDrinks.map((drink) {
      final drinkId = drink['id']?.toString() ?? '';
      if (drinkId.isEmpty) return drink;

      // Check if this drink is a paid drink
      final isPaidDrink = mergedPaidDrinkQuantities.containsKey(drinkId) &&
          (mergedPaidDrinkQuantities[drinkId] ?? 0) > 0;

      if (isPaidDrink) {
        // Find the actual drink from restaurant drinks to get the correct price
        final actualDrink = params.restaurantDrinks.firstWhere(
          (d) => d.id == drinkId,
          orElse: () => params.restaurantDrinks.firstWhere(
            (d) => d.name == (drink['name']?.toString() ?? ''),
            orElse: () => params.restaurantDrinks.isNotEmpty
                ? params.restaurantDrinks.first
                : params.menuItem,
          ),
        );

        // Update drink with correct price and mark as paid
        final updatedDrink = Map<String, dynamic>.from(drink);
        updatedDrink['price'] = actualDrink.price;
        updatedDrink['is_free'] = false;
        return updatedDrink;
      } else {
        // Free drink - ensure price is 0 and is_free is true
        final updatedDrink = Map<String, dynamic>.from(drink);
        updatedDrink['price'] = 0.0;
        updatedDrink['is_free'] = true;
        return updatedDrink;
      }
    }).toList();

    // Merge saved and current drinks (avoid duplicates by drink ID)
    final allDrinks = <Map<String, dynamic>>[];
    final drinkIdsAdded = <String>{};

    // Add updated saved drinks first
    for (final drink in updatedSavedDrinks) {
      final drinkId = drink['id']?.toString() ?? '';
      if (drinkId.isNotEmpty && !drinkIdsAdded.contains(drinkId)) {
        allDrinks.add(drink);
        drinkIdsAdded.add(drinkId);
      }
    }

    // Add current drinks (will override saved if same ID)
    // ✅ FIX: Paid drinks should come FIRST, then free drinks (matching display order)
    // ✅ FIX: When a drink appears both as free and paid, prioritize the paid version
    for (final drink in [...currentPaidDrinks, ...currentFreeDrinks]) {
      final drinkId = drink['id']?.toString() ?? '';
      if (drinkId.isEmpty) continue;

      // Check if this drink is a paid drink (in mergedPaidDrinkQuantities)
      final isPaidDrink = mergedPaidDrinkQuantities.containsKey(drinkId) &&
          (mergedPaidDrinkQuantities[drinkId] ?? 0) > 0;

      if (drinkIdsAdded.contains(drinkId)) {
        final index =
            allDrinks.indexWhere((d) => d['id']?.toString() == drinkId);
        if (index >= 0) {
          final existingDrink = allDrinks[index];
          final existingIsPaid = (existingDrink['is_free'] != true) &&
              ((existingDrink['price'] as num?)?.toDouble() ?? 0.0) > 0;

          // ✅ FIX: Prioritize paid drinks - if new drink is paid, replace existing
          // If existing is paid and new is free, keep existing (don't replace)
          if (isPaidDrink && !existingIsPaid) {
            // New drink is paid, existing is free - replace with paid version
            allDrinks[index] = drink;
          } else if (isPaidDrink && existingIsPaid) {
            // Both are paid - ensure price is correct
            final actualDrink = params.restaurantDrinks.firstWhere(
              (d) => d.id == drinkId,
              orElse: () => params.restaurantDrinks.isNotEmpty
                  ? params.restaurantDrinks.first
                  : params.menuItem,
            );
            final updatedDrink = Map<String, dynamic>.from(drink);
            updatedDrink['price'] = actualDrink.price;
            updatedDrink['is_free'] = false;
            allDrinks[index] = updatedDrink;
          }
          // If existing is paid and new is free, don't replace (keep paid version)
        }
      } else {
        // Drink not in list yet - add it
        // ✅ FIX: If it's a paid drink, ensure it has correct price
        if (isPaidDrink) {
          final actualDrink = params.restaurantDrinks.firstWhere(
            (d) => d.id == drinkId,
            orElse: () => params.restaurantDrinks.firstWhere(
              (d) => d.name == (drink['name']?.toString() ?? ''),
              orElse: () => params.restaurantDrinks.isNotEmpty
                  ? params.restaurantDrinks.first
                  : params.menuItem,
            ),
          );
          final updatedDrink = Map<String, dynamic>.from(drink);
          updatedDrink['price'] = actualDrink.price;
          updatedDrink['is_free'] = false;
          allDrinks.add(updatedDrink);
        } else {
          allDrinks.add(drink);
        }
        drinkIdsAdded.add(drinkId);
      }
    }

    // ✅ FIX: Post-processing: Ensure all paid drinks in the final list have correct prices
    // This is a safety check to handle any edge cases
    for (int i = 0; i < allDrinks.length; i++) {
      final drink = allDrinks[i];
      final drinkId = drink['id']?.toString() ?? '';
      if (drinkId.isEmpty) continue;

      // Check if this drink is a paid drink
      final isPaidDrink = mergedPaidDrinkQuantities.containsKey(drinkId) &&
          (mergedPaidDrinkQuantities[drinkId] ?? 0) > 0;

      if (isPaidDrink) {
        final currentPrice = (drink['price'] as num?)?.toDouble() ?? 0.0;
        if (currentPrice == 0.0) {
          // Price is 0 but drink is paid - fix it
          final actualDrink = params.restaurantDrinks.firstWhere(
            (d) => d.id == drinkId,
            orElse: () => params.restaurantDrinks.firstWhere(
              (d) => d.name == (drink['name']?.toString() ?? ''),
              orElse: () => params.restaurantDrinks.isNotEmpty
                  ? params.restaurantDrinks.first
                  : params.menuItem,
            ),
          );
          final updatedDrink = Map<String, dynamic>.from(drink);
          updatedDrink['price'] = actualDrink.price;
          updatedDrink['is_free'] = false;
          allDrinks[i] = updatedDrink;
        }
      }
    }

    // Merge free and paid quantities for drink_quantities (backward compatibility)
    final mergedDrinkQuantities = <String, int>{
      ...mergedFreeDrinkQuantities,
      ...mergedPaidDrinkQuantities,
    };

    // Restore pack selections and customizations for unified pack order
    final packSelectionsWithNames =
        savedOrder['pack_selections'] as Map<String, dynamic>?;
    final packIngredientPrefsJson =
        savedOrder['pack_ingredient_preferences'] as Map<String, dynamic>?;
    final packSupplementSelectionsJson =
        savedOrder['pack_supplement_selections'] as Map<String, dynamic>?;
    final packSupplementPricesJson =
        savedOrder['pack_supplement_prices'] as Map<String, dynamic>?;

    final currentCustomizations = {
      'menu_item_id': params.menuItem.id,
      'restaurant_id': (params.menuItem.restaurantId.isNotEmpty
              ? params.menuItem.restaurantId
              : (params.restaurant?.id.toString() ?? ''))
          .trim(),
      'main_item_quantity': quantity,
      'variant': null,
      'size': null,
      'portion': null,
      'supplements': supplements,
      'drinks': allDrinks.isNotEmpty ? allDrinks : savedDrinks,
      'drink_quantities': mergedDrinkQuantities.isNotEmpty
          ? mergedDrinkQuantities
          : savedDrinkQuantities,
      'free_drink_quantities': mergedFreeDrinkQuantities.isNotEmpty
          ? mergedFreeDrinkQuantities
          : null,
      'paid_drink_quantities': mergedPaidDrinkQuantities.isNotEmpty
          ? mergedPaidDrinkQuantities
          : null,
      'removed_ingredients': removedIngredients,
      'ingredient_preferences': ingredientPrefs,
      if (packSelectionsWithNames != null && packSelectionsWithNames.isNotEmpty)
        'pack_selections': packSelectionsWithNames,
      if (packIngredientPrefsJson != null && packIngredientPrefsJson.isNotEmpty)
        'pack_ingredient_preferences': packIngredientPrefsJson,
      if (packSupplementSelectionsJson != null &&
          packSupplementSelectionsJson.isNotEmpty)
        'pack_supplement_selections': packSupplementSelectionsJson,
      if (packSupplementPricesJson != null &&
          packSupplementPricesJson.isNotEmpty)
        'pack_supplement_prices': packSupplementPricesJson,
      'is_special_pack': params.isSpecialPack,
      'is_limited_offer': params.menuItem.isLimitedOffer,
      'popup_session_id': params.popupSessionId,
    };

    // Split quantity > 1 into separate items (one per unit)
    for (int i = 0; i < quantity; i++) {
      final isFirstOverallItem = i == 0 && !drinksAdded;
      final itemPrice = isFirstOverallItem
          ? perUnitPrice + totalPaidDrinksPrice
          : perUnitPrice;

      final itemDrinkQuantities = {
        ...mergedFreeDrinkQuantities,
        if (isFirstOverallItem) ...mergedPaidDrinkQuantities,
      };

      final itemCustomizations =
          Map<String, dynamic>.from(currentCustomizations);
      if (!isFirstOverallItem) {
        itemCustomizations['paid_drink_quantities'] = null;
        itemCustomizations['free_drink_quantities'] =
            Map<String, int>.from(mergedFreeDrinkQuantities);
        itemCustomizations['drink_quantities'] =
            Map<String, int>.from(mergedFreeDrinkQuantities);
        final freeDrinksOnly = allDrinks.where((d) {
          final isFree =
              d['is_free'] == true || (d['price'] as num?)?.toDouble() == 0.0;
          return isFree;
        }).toList();
        itemCustomizations['drinks'] = freeDrinksOnly;
      } else {
        itemCustomizations['free_drink_quantities'] =
            Map<String, int>.from(mergedFreeDrinkQuantities);
        itemCustomizations['paid_drink_quantities'] =
            Map<String, int>.from(mergedPaidDrinkQuantities);
      }

      final cartItem = CartItem(
        id: '${DateTime.now().millisecondsSinceEpoch}_saved_pack_$i',
        name: params.menuItem.name,
        price: itemPrice,
        quantity: 1,
        image: params.menuItem.image,
        restaurantName: params.menuItem.restaurantName,
        customizations: itemCustomizations,
        drinkQuantities: itemDrinkQuantities,
        specialInstructions: (savedOrder['note'] ?? '').toString(),
      );

      debugPrint(
          '🛒 addSavedUnifiedPackOrders: Adding saved unified pack order item ${i + 1}/$quantity (unitPrice: $itemPrice, hasFreeDrinks: true, hasPaidDrinks: $isFirstOverallItem)');
      params.cartProvider.addToCart(cartItem);

      if (isFirstOverallItem) {
        drinksAdded = true;
      }
    }
  }

  return drinksAdded;
}
