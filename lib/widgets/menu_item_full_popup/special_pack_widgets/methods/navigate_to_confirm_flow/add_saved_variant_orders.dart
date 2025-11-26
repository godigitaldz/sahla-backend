import 'package:flutter/foundation.dart';

import '../../../../../cart_provider.dart';
import '../../../../../models/menu_item_pricing.dart';
import '../../../../../models/menu_item_variant.dart';
import '../../../helpers/lto_helper.dart';
import '../../../helpers/regular_item_helper.dart';
import 'navigate_to_confirm_flow_params.dart';
import 'unified_order_drinks_handler.dart';

/// Add saved variant orders to cart (for regular variant orders)
/// Returns true if drinks were added, false otherwise
bool addSavedVariantOrdersToCart({
  required NavigateToConfirmFlowParams params,
  required Map<String, List<Map<String, dynamic>>> savedVariantOrders,
  required List<MenuItemVariant> variants,
}) {
  // Use unified handler to calculate total paid drinks price (merging current + saved)
  final totalPaidDrinksPrice =
      UnifiedOrderDrinksHandler.calculateTotalPaidDrinksPrice(
    params: params,
    savedVariantOrders: savedVariantOrders,
  );

  // Track if drinks have been added (global flag - drinks only added once)
  // Track the first order across all variants
  bool drinksAdded = false;
  bool isFirstOrder = true;

  savedVariantOrders.forEach((variantId, orders) {
    MenuItemVariant? variant;
    try {
      variant = variants.firstWhere((v) => v.id == variantId);
    } catch (_) {
      variant = null;
    }
    for (final savedOrder in orders) {
      final isFirstOverallOrder = isFirstOrder && !drinksAdded;
      final pricingJson = savedOrder['pricing'] as Map<String, dynamic>;
      final pricingSize = pricingJson['size'];
      final pricingPortion = pricingJson['portion'];
      // ✅ FIX: Create MenuItemPricing object for RegularItemHelper
      final pricing = MenuItemPricing.fromJson(pricingJson);

      // ✅ FIX: For regular items, use RegularItemHelper to get correct base price
      // For special packs, use pricing.price directly
      double basePrice;
      if (params.isSpecialPack) {
        // Special pack: pricing.price is the base price
        basePrice = pricing.price > 0 ? pricing.price : params.menuItem.price;
        if (basePrice <= 0) {
          basePrice = 200.0;
        }
      } else {
        // Regular item: use RegularItemHelper to get base price + size extra
        final basePriceFromHelper = RegularItemHelper.getBasePrice(
          item: params.menuItem,
          pricing: pricing,
        );
        final sizeExtra = RegularItemHelper.getSizeExtraCharge(
          item: params.menuItem,
          pricing: pricing,
        );
        basePrice = basePriceFromHelper + sizeExtra;
        if (basePrice <= 0) {
          basePrice = params.menuItem.price > 0 ? params.menuItem.price : 200.0;
        }
      }

      if (kDebugMode) {
        debugPrint('💰 addSavedVariantOrders: Extracting saved order data');
        debugPrint('   Pricing JSON: $pricingJson');
        debugPrint('   Base price from pricing: ${pricingJson['price']}');
        debugPrint('   Calculated basePrice: $basePrice');
        debugPrint(
            '   Has total_price: ${savedOrder.containsKey('total_price')}');
        if (savedOrder.containsKey('total_price')) {
          debugPrint('   total_price value: ${savedOrder['total_price']}');
        }
      }
      final quantity = (savedOrder['quantity'] as num?)?.toInt() ?? 1;
      final supplements = (savedOrder['supplements'] as List?)
              ?.map((s) => s as Map<String, dynamic>)
              .toList() ??
          const <Map<String, dynamic>>[];
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

      // Use unified handler to merge paid drinks from saved order with current selections
      final mergedPaidDrinkQuantities =
          UnifiedOrderDrinksHandler.mergePaidDrinkQuantities(
        params: params,
        savedOrder: savedOrder,
      );

      // Use unified handler to calculate free drinks from saved order
      final savedFreeDrinkQuantities =
          UnifiedOrderDrinksHandler.calculateFreeDrinksFromSavedOrder(
        params: params,
        savedOrder: savedOrder,
        quantity: quantity,
      );

      // Combine free and paid drinks
      final savedDrinkQuantities = {
        ...savedFreeDrinkQuantities,
        ...mergedPaidDrinkQuantities,
      };

      // ✅ FIX: Update drink prices in savedDrinks to ensure paid drinks have correct prices
      // This ensures drinks display correctly in the cart screen
      final updatedDrinks = savedDrinks.map((drink) {
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
              orElse: () => params.restaurantDrinks.first,
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

      // Also add any paid drinks from current selections that aren't in saved drinks
      final allDrinks = <Map<String, dynamic>>[];
      final drinkIdsAdded = <String>{};

      // Add saved drinks first (now with updated prices)
      for (final drink in updatedDrinks) {
        final drinkId = drink['id']?.toString() ?? '';
        if (drinkId.isNotEmpty && !drinkIdsAdded.contains(drinkId)) {
          allDrinks.add(drink);
          drinkIdsAdded.add(drinkId);
        }
      }

      // Add current paid drinks that aren't in saved drinks
      for (final entry in mergedPaidDrinkQuantities.entries) {
        if (entry.value > 0 && !drinkIdsAdded.contains(entry.key)) {
          final drink = params.restaurantDrinks.firstWhere(
            (d) => d.id == entry.key,
            orElse: () => params.restaurantDrinks.first,
          );
          final drinkMap = drink.toJson();
          final sz = params.drinkSizesById[drink.id];
          if (sz != null && sz.isNotEmpty) drinkMap['size'] = sz;
          drinkMap['price'] = drink.price;
          drinkMap['is_free'] = false;
          allDrinks.add(drinkMap);
          drinkIdsAdded.add(entry.key);
        }
      }

      // Use unified handler to determine drinks price for this order
      final drinksPriceForThisVariant =
          UnifiedOrderDrinksHandler.getDrinksPriceForItem(
        totalPaidDrinksPrice: totalPaidDrinksPrice,
        isFirstItem: isFirstOverallOrder,
        drinksAlreadyAdded: drinksAdded,
      );

      // Mark drinks as added if this was the first order overall
      if (isFirstOverallOrder) {
        drinksAdded = true;
      }

      // Mark that we've processed at least one order
      isFirstOrder = false;

      // Calculate per-unit price
      // savedTotalPrice already includes base price + supplements for the entire quantity
      // We need to add paid drinks to the total, then divide by quantity to get per-unit price
      // This matches the logic in add_current_variant_selections.dart
      double perUnitPrice;
      if (savedOrder.containsKey('total_price')) {
        final savedTotalPrice = (savedOrder['total_price'] as num).toDouble();
        // Add paid drinks to total (paid drinks are global, added once to first item)
        final totalWithDrinks = savedTotalPrice + drinksPriceForThisVariant;
        // Divide by quantity to get per-unit price
        perUnitPrice =
            quantity > 0 ? (totalWithDrinks / quantity) : totalWithDrinks;
      } else {
        // Fallback: calculate from pricing and supplements
        final supplementsPrice = supplements.fold<double>(
            0.0, (sum, s) => sum + ((s['price'] as num?)?.toDouble() ?? 0.0));

        // ✅ FIX: Use RegularItemHelper for regular items to correctly calculate price
        double totalWithDrinks;
        if (params.isSpecialPack) {
          // Special pack: (basePrice + supplements) * quantity + paid drinks
          totalWithDrinks = (basePrice + supplementsPrice) * quantity +
              drinksPriceForThisVariant;
        } else {
          // Regular item: use RegularItemHelper
          totalWithDrinks = RegularItemHelper.calculatePrice(
            item: params.menuItem,
            pricing: pricing,
            supplementsPrice: supplementsPrice,
            drinksPrice: drinksPriceForThisVariant,
            quantity: quantity,
          );
        }

        // Divide by quantity to get per-unit price
        perUnitPrice =
            quantity > 0 ? (totalWithDrinks / quantity) : totalWithDrinks;
      }

      if (kDebugMode) {
        debugPrint('💰 addSavedVariantOrders: Price calculation');
        final savedTotalPrice = savedOrder.containsKey('total_price')
            ? (savedOrder['total_price'] as num).toDouble()
            : null;
        final supplementsPrice = supplements.fold<double>(
            0.0, (sum, s) => sum + ((s['price'] as num?)?.toDouble() ?? 0.0));
        debugPrint(
            '   Saved total price (includes base + supplements): ${savedTotalPrice ?? 'N/A'}');
        debugPrint('   Quantity: $quantity');
        debugPrint('   Supplements price: $supplementsPrice');
        debugPrint(
            '   Paid drinks price (for this variant): $drinksPriceForThisVariant');
        debugPrint(
            '   Total with drinks: ${savedTotalPrice != null ? savedTotalPrice + drinksPriceForThisVariant : (basePrice + supplementsPrice) * quantity + drinksPriceForThisVariant}');
        debugPrint('   Final per-unit price: $perUnitPrice');
        debugPrint(
            '   Total price (perUnitPrice * quantity): ${perUnitPrice * quantity}');
      }

      if (kDebugMode && isFirstOverallOrder) {
        debugPrint(
            '🥤 addSavedVariantOrders: Adding paid drinks price: $totalPaidDrinksPrice');
        debugPrint('   Paid drinks quantities: $mergedPaidDrinkQuantities');
      }

      // ✅ FIX: Extract LTO offer types and details for cart customizations
      final ltoCartData = LTOHelper.getLTOCartCustomizations(
        item: params.menuItem,
        pricing: pricing,
      );

      final currentCustomizations = {
        'menu_item_id': params.menuItem.id,
        'restaurant_id': (params.menuItem.restaurantId.isNotEmpty
                ? params.menuItem.restaurantId
                : (params.restaurant?.id.toString() ?? ''))
            .trim(),
        'main_item_quantity': quantity,
        'variant': (variant != null) ? variant.toJson() : null,
        'size': pricingSize,
        'portion': pricingPortion,
        'supplements': supplements,
        // ✅ FIX: Only include paid drinks in drinks list for FIRST order overall
        // Paid drinks are global - should only appear in first item's drinks list
        'drinks': isFirstOverallOrder
            ? allDrinks // First order: include both free and paid drinks
            : allDrinks.where((d) {
                // Other orders: only include free drinks (filter out paid drinks)
                final isFree = d['is_free'] == true ||
                    (d['price'] as num?)?.toDouble() == 0.0;
                return isFree;
              }).toList(),
        // ✅ FIX: Only include paid drinks in drink_quantities for FIRST order overall
        // Paid drinks are global - quantities should only be in first item
        'drink_quantities': isFirstOverallOrder
            ? savedDrinkQuantities // First order: include both free and paid
            : {
                // Other orders: only include free drinks (paid drinks are global, only in first)
                ...savedFreeDrinkQuantities,
              },
        // For LTO/regular items: free drinks are already multiplied by quantity in savedDrinkQuantities
        // The unified handler already handles the multiplication, so we use the result directly
        'free_drink_quantities': savedFreeDrinkQuantities.isNotEmpty
            ? Map<String, int>.from(savedFreeDrinkQuantities)
            : null,
        // ✅ FIX: Paid drinks quantities ONLY in first order overall (they're global)
        'paid_drink_quantities':
            (isFirstOverallOrder && mergedPaidDrinkQuantities.isNotEmpty)
                ? Map<String, int>.from(mergedPaidDrinkQuantities)
                : null,
        'removed_ingredients': removedIngredients,
        'ingredient_preferences': ingredientPrefs,
        'is_special_pack': params.isSpecialPack,
        'is_limited_offer': params.menuItem.isLimitedOffer,
        // ✅ FIX: Add LTO offer types and details for special delivery discount calculation
        ...ltoCartData,
        'popup_session_id': params.popupSessionId,
      };

      final cartItem = CartItem(
        id: '${DateTime.now().millisecondsSinceEpoch}_saved_$variantId',
        name:
            '${params.menuItem.name}${variant != null ? ' - ${variant.name}' : ''}',
        price: perUnitPrice,
        quantity: quantity,
        image: params.menuItem.image,
        restaurantName: params.menuItem.restaurantName,
        customizations: currentCustomizations,
        // ✅ FIX: Only include paid drinks in drinkQuantities for FIRST order overall
        // Paid drinks are global - quantities should only be in first item
        drinkQuantities: isFirstOverallOrder
            ? savedDrinkQuantities // First order: include both free and paid
            : savedFreeDrinkQuantities, // Other orders: only free drinks
        specialInstructions: (savedOrder['note'] ?? '').toString(),
      );

      debugPrint(
          '🛒 addSavedVariantOrders: Adding saved variant ${variant?.name} (qty: $quantity, price: $perUnitPrice, drinksPrice: $drinksPriceForThisVariant)');
      params.cartProvider.addToCart(cartItem);
    }
  });

  return drinksAdded;
}
