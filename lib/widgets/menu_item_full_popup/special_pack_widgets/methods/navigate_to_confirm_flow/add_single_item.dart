import 'package:flutter/foundation.dart';

import '../../../../../cart_provider.dart';
import 'navigate_to_confirm_flow_params.dart';

/// Add single item to cart (no variants selected)
void addSingleItemToCart({
  required NavigateToConfirmFlowParams params,
  required double totalPaidDrinksPrice,
  required List<Map<String, dynamic>> Function() buildDrinksWithSizes,
  required String? Function() buildSpecialInstructions,
}) {
  final quantityToUse = params.quantity;
  double basePrice = params.menuItem.price;
  if (basePrice <= 0) {
    basePrice = 200.0; // Default fallback price
  }

  final supplementsPrice =
      params.selectedSupplements.fold(0.0, (sum, s) => sum + s.price);

  final mainItemTotal =
      (basePrice + supplementsPrice) * quantityToUse + totalPaidDrinksPrice;
  final perUnitPrice =
      quantityToUse > 0 ? (mainItemTotal / quantityToUse) : mainItemTotal;

  final drinksWithSizes = buildDrinksWithSizes();

  final currentCustomizations = {
    'menu_item_id': params.menuItem.id,
    'restaurant_id': (params.menuItem.restaurantId.isNotEmpty
            ? params.menuItem.restaurantId
            : (params.restaurant?.id.toString() ?? ''))
        .trim(),
    'main_item_quantity': quantityToUse,
    'variant': null,
    'size': null,
    'portion': null,
    'supplements': params.selectedSupplements.map((s) => s.toJson()).toList(),
    'drinks': drinksWithSizes,
    'drink_quantities': params.drinkQuantities,
    'removed_ingredients': params.removedIngredients,
    'ingredient_preferences': params.ingredientPreferences.map(
      (key, value) => MapEntry(key, value.toString().split('.').last),
    ),
    // Grouping key for items added from the same popup
    'popup_session_id': params.popupSessionId,
  };

  final cartItem = CartItem(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    name: params.menuItem.name,
    price: perUnitPrice,
    quantity: quantityToUse,
    image: params.menuItem.image,
    restaurantName: params.menuItem.restaurantName,
    customizations: currentCustomizations,
    drinkQuantities: Map<String, int>.from(params.drinkQuantities),
    specialInstructions: buildSpecialInstructions() ?? '',
  );

  debugPrint(
      '🛒 addSingleItem: Adding single item (no variant) - qty: $quantityToUse, price: $perUnitPrice');
  params.cartProvider.addToCart(cartItem);
}
