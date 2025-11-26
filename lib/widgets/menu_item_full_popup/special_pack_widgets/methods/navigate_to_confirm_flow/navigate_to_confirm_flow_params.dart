import '../../../../../cart_provider.dart';
import '../../../../../models/enhanced_menu_item.dart';
import '../../../../../models/ingredient_preference.dart';
import '../../../../../models/menu_item.dart';
import '../../../../../models/menu_item_pricing.dart';
import '../../../../../models/menu_item_supplement.dart';
import '../../../../../models/order_item.dart';
import '../../../../../models/restaurant.dart';

/// Parameters for navigate to confirm flow operations
class NavigateToConfirmFlowParams {
  final CartProvider cartProvider;
  final MenuItem menuItem;
  final Restaurant? restaurant;
  final EnhancedMenuItem? enhancedMenuItem;
  final bool isSpecialPack;
  final Set<String> selectedVariants;
  final Map<String, MenuItemPricing> selectedPricingPerVariant;
  final List<MenuItemSupplement> selectedSupplements;
  final List<String> removedIngredients;
  final Map<String, IngredientPreference> ingredientPreferences;
  final List<OrderItem> savedOrders;
  final List<MenuItem> selectedDrinks;
  final List<MenuItem> restaurantDrinks;
  final Map<String, int> drinkQuantities;
  final Map<String, int> paidDrinkQuantities;
  final Map<String, String> drinkSizesById;
  final int quantity;
  final Map<String, int> variantQuantities;
  final Map<String, Map<int, String>> packItemSelections;
  final Map<String, Map<int, Map<String, IngredientPreference>>>
      packIngredientPreferences;
  final Map<String, Map<int, Set<String>>> packSupplementSelections;
  final Map<String, List<Map<String, dynamic>>> savedVariantOrders;
  final String popupSessionId;
  final String? Function() buildSpecialInstructions;
  final Map<String, dynamic> Function(
          Map<String, Map<int, Map<String, IngredientPreference>>>)
      convertIngredientPreferencesToJson;
  final List<String> Function(String?) parsePackItemOptions;

  NavigateToConfirmFlowParams({
    required this.cartProvider,
    required this.menuItem,
    required this.restaurant,
    required this.enhancedMenuItem,
    required this.isSpecialPack,
    required this.selectedVariants,
    required this.selectedPricingPerVariant,
    required this.selectedSupplements,
    required this.removedIngredients,
    required this.ingredientPreferences,
    required this.savedOrders,
    required this.selectedDrinks,
    required this.restaurantDrinks,
    required this.drinkQuantities,
    required this.paidDrinkQuantities,
    required this.drinkSizesById,
    required this.quantity,
    required this.variantQuantities,
    required this.packItemSelections,
    required this.packIngredientPreferences,
    required this.packSupplementSelections,
    required this.savedVariantOrders,
    required this.popupSessionId,
    required this.buildSpecialInstructions,
    required this.convertIngredientPreferencesToJson,
    required this.parsePackItemOptions,
  });
}
