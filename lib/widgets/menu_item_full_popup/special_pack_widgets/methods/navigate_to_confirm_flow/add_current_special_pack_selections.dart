import 'package:flutter/foundation.dart';

import '../../../../../cart_provider.dart';
import '../../../../../models/ingredient_preference.dart';
import '../../../helpers/lto_helper.dart';
import '../../../helpers/pack_customizations_builder.dart';
import 'navigate_to_confirm_flow_params.dart';

/// Add current special pack selections to cart
/// Returns true if drinks were added, false otherwise
bool addCurrentSpecialPackSelectionsToCart({
  required NavigateToConfirmFlowParams params,
  required double totalPaidDrinksPrice,
  required List<Map<String, dynamic>> Function() buildDrinksWithSizes,
  required String? Function() buildSpecialInstructions,
  required Map<String, dynamic> Function(
          Map<String, Map<int, Map<String, IngredientPreference>>>)
      convertIngredientPreferencesToJson,
  required List<String> Function(String?) parsePackItemOptions,
  required bool drinksAdded,
}) {
  // Calculate unified pack price
  double basePrice = params.menuItem.price;
  if (basePrice <= 0 && params.selectedPricingPerVariant.isNotEmpty) {
    final firstPricing = params.selectedPricingPerVariant.values.first;
    basePrice = firstPricing.price;
  }
  if (basePrice <= 0) {
    basePrice = 200.0;
  }

  // Calculate supplements price
  final supplementsPrice =
      params.selectedSupplements.fold(0.0, (sum, s) => sum + s.price);

  // Calculate per-unit price WITHOUT drinks (drinks are global, not per item)
  final perUnitPrice = basePrice + supplementsPrice;

  // Build drinks payload using shared helper
  final drinksWithSizes = buildDrinksWithSizes();

  // Build pack customizations using shared helper
  final packCustomizations = buildPackCustomizations(
    PackCustomizationsParams(
      enhancedMenuItem: params.enhancedMenuItem,
      packItemSelections: params.packItemSelections,
      packIngredientPreferences: params.packIngredientPreferences,
      packSupplementSelections: params.packSupplementSelections,
      parsePackItemOptions: parsePackItemOptions,
      convertIngredientPreferencesToJson: convertIngredientPreferencesToJson,
      enableDebugLogs: false,
    ),
  );

  final packSelectionsWithNames = packCustomizations.packSelectionsWithNames;
  final packIngredientPrefsJson = packCustomizations.packIngredientPrefsJson;
  final packSupplementSelectionsJson =
      packCustomizations.packSupplementSelectionsJson;
  final packSupplementPricesJson = packCustomizations.packSupplementPricesJson;

  // Create ONE unified cart item for the special pack
  final currentCustomizations = {
    'menu_item_id': params.menuItem.id,
    'restaurant_id': (params.menuItem.restaurantId.isNotEmpty
            ? params.menuItem.restaurantId
            : (params.restaurant?.id.toString() ?? ''))
        .trim(),
    'main_item_quantity': params.quantity,
    'variant': null,
    'size': null,
    'portion': null,
    'supplements': params.selectedSupplements.map((s) => s.toJson()).toList(),
    'drinks': drinksWithSizes,
    'drink_quantities': {
      ...params.drinkQuantities,
      ...params.paidDrinkQuantities,
    },
    'free_drink_quantities': params.drinkQuantities.isNotEmpty
        ? Map<String, int>.from(params.drinkQuantities)
        : null,
    'paid_drink_quantities': params.paidDrinkQuantities.isNotEmpty
        ? Map<String, int>.from(params.paidDrinkQuantities)
        : null,
    'removed_ingredients': params.removedIngredients,
    'ingredient_preferences': params.ingredientPreferences.map(
      (key, value) => MapEntry(key, value.toString().split('.').last),
    ),
    if (packSelectionsWithNames.isNotEmpty)
      'pack_selections': packSelectionsWithNames,
    if (packIngredientPrefsJson != null && packIngredientPrefsJson.isNotEmpty)
      'pack_ingredient_preferences': packIngredientPrefsJson,
    if (packSupplementSelectionsJson != null &&
        packSupplementSelectionsJson.isNotEmpty)
      'pack_supplement_selections': packSupplementSelectionsJson,
    if (packSupplementPricesJson != null && packSupplementPricesJson.isNotEmpty)
      'pack_supplement_prices': packSupplementPricesJson,
    'is_special_pack': params.isSpecialPack,
    'is_limited_offer': params.menuItem.isLimitedOffer,
    // ✅ FIX: Add LTO offer types and details for special delivery discount calculation
    ...LTOHelper.getLTOCartCustomizations(
      item: params.menuItem,
      pricing: params.selectedPricingPerVariant.isNotEmpty
          ? params.selectedPricingPerVariant.values.first
          : null,
    ),
    'popup_session_id': params.popupSessionId,
  };

  bool drinksWereAdded = drinksAdded;

  // Split quantity > 1 into separate items (one per unit)
  for (int i = 0; i < params.quantity; i++) {
    final isFirstOverallItem = i == 0 && !drinksWereAdded;
    final itemPrice =
        isFirstOverallItem ? perUnitPrice + totalPaidDrinksPrice : perUnitPrice;

    final itemDrinkQuantities = {
      ...params.drinkQuantities,
      if (isFirstOverallItem) ...params.paidDrinkQuantities,
    };

    final itemCustomizations = Map<String, dynamic>.from(currentCustomizations);
    if (!isFirstOverallItem) {
      itemCustomizations['paid_drink_quantities'] = null;
      itemCustomizations['free_drink_quantities'] =
          Map<String, int>.from(params.drinkQuantities);
      itemCustomizations['drink_quantities'] =
          Map<String, int>.from(params.drinkQuantities);
      final freeDrinksOnly = drinksWithSizes.where((d) {
        final isFree =
            d['is_free'] == true || (d['price'] as num?)?.toDouble() == 0.0;
        return isFree;
      }).toList();
      itemCustomizations['drinks'] = freeDrinksOnly;
    } else {
      itemCustomizations['free_drink_quantities'] =
          Map<String, int>.from(params.drinkQuantities);
      itemCustomizations['paid_drink_quantities'] =
          Map<String, int>.from(params.paidDrinkQuantities);
    }

    final cartItem = CartItem(
      id: '${DateTime.now().millisecondsSinceEpoch}_current_pack_$i',
      name: params.menuItem.name,
      price: itemPrice,
      quantity: 1,
      image: params.menuItem.image,
      restaurantName: params.menuItem.restaurantName,
      customizations: itemCustomizations,
      drinkQuantities: itemDrinkQuantities,
      specialInstructions: buildSpecialInstructions() ?? '',
    );

    debugPrint(
        '🛒 addCurrentSpecialPackSelections: Adding unified pack order item ${i + 1}/${params.quantity} (unitPrice: $itemPrice, hasFreeDrinks: true, hasPaidDrinks: $isFirstOverallItem)');
    params.cartProvider.addToCart(cartItem);

    if (isFirstOverallItem) {
      drinksWereAdded = true;
    }
  }

  return drinksWereAdded;
}
