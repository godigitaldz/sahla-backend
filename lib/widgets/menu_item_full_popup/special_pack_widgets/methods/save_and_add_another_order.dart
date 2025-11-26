import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/enhanced_menu_item.dart';
import '../../../../models/ingredient_preference.dart';
import '../../../../models/menu_item.dart';
import '../../../../models/menu_item_pricing.dart';
import '../../../../models/menu_item_supplement.dart';
import '../../../../models/menu_item_variant.dart';
import '../../helpers/pack_customizations_builder.dart';
import '../../helpers/regular_item_helper.dart';

/// Parameters bundle for saveAndAddAnotherOrder method
class SaveAndAddAnotherOrderParams {
  final BuildContext context;
  final MenuItem menuItem;
  final bool isSpecialPack;

  // State variables
  final EnhancedMenuItem? enhancedMenuItem;
  final Set<String> selectedVariants;
  final Map<String, MenuItemPricing> selectedPricingPerVariant;
  final int quantity;
  final List<MenuItemSupplement> selectedSupplements;
  final List<String> removedIngredients;
  final Map<String, IngredientPreference> ingredientPreferences;
  final Map<String, Map<int, String>> packItemSelections;
  final Map<String, Map<int, Map<String, IngredientPreference>>>
      packIngredientPreferences;
  final Map<String, Map<int, Set<String>>> packSupplementSelections;
  final List<MenuItem> selectedDrinks;
  final Map<String, int> drinkQuantities;
  final Map<String, int> paidDrinkQuantities;
  final Map<String, String> drinkSizesById;
  final List<MenuItem> restaurantDrinks;
  final String specialNote;
  final Map<String, List<Map<String, dynamic>>> savedVariantOrders;
  final Map<String, int>?
      variantQuantities; // For regular items with per-variant quantities
  final Map<String, String>?
      variantNotes; // For regular items with per-variant notes

  // Callbacks
  final Map<String, dynamic> Function(
          Map<String, Map<int, Map<String, IngredientPreference>>>)
      convertIngredientPreferencesToJson;
  final List<String> Function(String?) parsePackItemOptions;
  final void Function() clearSelections;
  final void Function() autoSelectSingleFreeDrink;

  SaveAndAddAnotherOrderParams({
    required this.context,
    required this.menuItem,
    required this.isSpecialPack,
    required this.enhancedMenuItem,
    required this.selectedVariants,
    required this.selectedPricingPerVariant,
    required this.quantity,
    required this.selectedSupplements,
    required this.removedIngredients,
    required this.ingredientPreferences,
    required this.packItemSelections,
    required this.packIngredientPreferences,
    required this.packSupplementSelections,
    required this.selectedDrinks,
    required this.drinkQuantities,
    required this.paidDrinkQuantities,
    required this.drinkSizesById,
    required this.restaurantDrinks,
    required this.specialNote,
    required this.savedVariantOrders,
    required this.convertIngredientPreferencesToJson,
    required this.parsePackItemOptions,
    required this.clearSelections,
    required this.autoSelectSingleFreeDrink,
    this.variantQuantities,
    this.variantNotes,
  });
}

/// Save current order and clear all selections to allow user to create another order
void saveAndAddAnotherOrder(SaveAndAddAnotherOrderParams params) {
  if (params.enhancedMenuItem == null || params.selectedVariants.isEmpty) {
    return;
  }

  debugPrint('💾 saveAndAddAnotherOrder: Saving current order state');

  // Build drinks payload once (shared across all variants)
  final drinksWithSizes = <Map<String, dynamic>>[
    // Free drinks - mark as free by setting price to 0
    ...params.selectedDrinks.map((d) {
      final map = d.toJson();
      final sz = params.drinkSizesById[d.id];
      if (sz != null && sz.isNotEmpty) map['size'] = sz;
      map['price'] = 0.0;
      map['is_free'] = true;
      return map;
    }),
    // Paid drinks
    ...params.paidDrinkQuantities.entries
        .map((entry) => params.restaurantDrinks
                .where((d) => d.id == entry.key)
                .map((drink) {
              final map = drink.toJson();
              final sz = params.drinkSizesById[drink.id];
              if (sz != null && sz.isNotEmpty) map['size'] = sz;
              map['is_free'] = false;
              return map;
            }))
        .expand((e) => e),
  ];

  // For special packs, save ONE unified order with pack price
  if (params.isSpecialPack) {
    // Calculate unified pack price
    double basePrice = params.menuItem.price;
    if (basePrice <= 0 && params.selectedPricingPerVariant.isNotEmpty) {
      final firstPricing = params.selectedPricingPerVariant.values.first;
      basePrice = firstPricing.price;
    }
    if (basePrice <= 0) {
      basePrice = 200.0; // Default fallback price
    }

    // Calculate supplements price
    final supplementsPrice =
        params.selectedSupplements.fold(0.0, (sum, s) => sum + s.price);

    // ✅ FIX: Don't include paid drinks in saved order total - drinks are global and separate
    // Paid drinks should only be included when adding to cart from current selections
    // Unified total price: (base pack price + supplements) × quantity (NO drinks)
    final unifiedTotalPrice = (basePrice + supplementsPrice) * params.quantity;

    // Use the first pricing structure for special packs (for consistency)
    final pricingToUse = params.selectedPricingPerVariant.isNotEmpty
        ? params.selectedPricingPerVariant.values.first
        : null;

    // Build pack customizations using shared helper
    final packCustomizations = buildPackCustomizations(
      PackCustomizationsParams(
        enhancedMenuItem: params.enhancedMenuItem,
        packItemSelections: params.packItemSelections,
        packIngredientPreferences: params.packIngredientPreferences,
        packSupplementSelections: params.packSupplementSelections,
        parsePackItemOptions: params.parsePackItemOptions,
        convertIngredientPreferencesToJson:
            params.convertIngredientPreferencesToJson,
        enableDebugLogs: false,
      ),
    );

    final packSelectionsWithNames = packCustomizations.packSelectionsWithNames;
    final packIngredientPrefsJson = packCustomizations.packIngredientPrefsJson;
    final packSupplementSelectionsJson =
        packCustomizations.packSupplementSelectionsJson;
    final packSupplementPricesJson =
        packCustomizations.packSupplementPricesJson;

    // Create ONE unified saved order for the special pack
    final savedOrder = {
      'pricing': pricingToUse?.toJson() ??
          MenuItemPricing(
            id: '',
            menuItemId: params.menuItem.id,
            size: '',
            portion: '',
            price: basePrice,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ).toJson(),
      'quantity': params.quantity,
      'total_price': unifiedTotalPrice, // Store unified total price
      'supplements': params.selectedSupplements.map((s) => s.toJson()).toList(),
      'removed_ingredients': params.removedIngredients,
      'ingredient_preferences': params.ingredientPreferences.map(
        (key, value) => MapEntry(key, value.toString().split('.').last),
      ),
      'drinks': drinksWithSizes,
      'drink_quantities': {
        ...params.drinkQuantities,
        ...params.paidDrinkQuantities,
      },
      'free_drink_quantities': Map<String, int>.from(params.drinkQuantities),
      'paid_drink_quantities':
          Map<String, int>.from(params.paidDrinkQuantities),
      'note': params.specialNote,
      if (packSelectionsWithNames.isNotEmpty)
        'pack_selections': packSelectionsWithNames,
      if (packIngredientPrefsJson != null && packIngredientPrefsJson.isNotEmpty)
        'pack_ingredient_preferences': packIngredientPrefsJson,
      if (packSupplementSelectionsJson != null &&
          packSupplementSelectionsJson.isNotEmpty)
        'pack_supplement_selections': packSupplementSelectionsJson,
      if (packSupplementPricesJson != null &&
          packSupplementPricesJson.isNotEmpty)
        'pack_supplement_prices': packSupplementPricesJson,
    };

    // Store as unified pack order (use a special key like 'pack' or menu item id)
    const unifiedPackKey = 'pack'; // Use a constant key for unified pack orders
    // Note: savedVariantOrders is passed by reference, so we can modify it directly
    if (!params.savedVariantOrders.containsKey(unifiedPackKey)) {
      params.savedVariantOrders[unifiedPackKey] = [];
    }
    params.savedVariantOrders[unifiedPackKey]!.add(savedOrder);

    debugPrint(
        '💾 Saved unified pack order: qty=${params.quantity}, totalPrice=$unifiedTotalPrice');
  } else {
    // For regular items and LTO regular: save each variant separately
    final variants = params.enhancedMenuItem?.variants ?? [];
    final supplementsPrice =
        params.selectedSupplements.fold(0.0, (sum, s) => sum + s.price);

    // ✅ FIX: For regular items, only process the first (and only) selected variant
    // For special packs, process all selected variants
    final List<String> variantsToProcess = params.isSpecialPack
        ? params.selectedVariants.toList()
        : (params.selectedVariants.isNotEmpty ? [params.selectedVariants.first] : <String>[]);

    for (final variantId in variantsToProcess) {
      final variant = variants.firstWhere(
        (v) => v.id == variantId,
        orElse: () => MenuItemVariant(
          id: variantId,
          name: 'Unknown',
          menuItemId: params.menuItem.id,
          description: '',
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      final pricing = params.selectedPricingPerVariant[variantId];

      // ✅ FIX: For LTO regular items, size is optional, so don't skip variants without pricing
      // For regular items (non-LTO), skip variants without pricing
      final isLTORegular = params.menuItem.isLimitedOffer && !params.isSpecialPack;
      if (!isLTORegular && pricing == null) {
        // Skip variants without pricing (for non-LTO regular items)
        continue;
      }

      // Get quantity for this variant (use per-variant quantity if available, otherwise global)
      final quantity = params.variantQuantities?[variantId] ?? params.quantity;

      // Get note for this variant
      final note = params.variantNotes?[variantId] ?? params.specialNote;

      // Calculate price using RegularItemHelper
      final totalPrice = RegularItemHelper.calculatePrice(
        item: params.menuItem,
        pricing: pricing,
        supplementsPrice: supplementsPrice,
        drinksPrice: 0.0, // Drinks handled separately
        quantity: quantity,
      );

      // For LTO and regular items: save per-item free drinks quantity (divide by quantity if needed)
      // Special packs: save as-is (each pack gets its own free drinks)
      Map<String, int> freeDrinkQuantitiesToSave =
          Map<String, int>.from(params.drinkQuantities);
      if (!params.isSpecialPack && quantity > 1) {
        // For LTO/regular items: save per-item quantities (divide by quantity)
        // This ensures that when restoring, we can multiply by the saved order's quantity
        freeDrinkQuantitiesToSave = freeDrinkQuantitiesToSave.map(
          (drinkId, qty) =>
              MapEntry(drinkId, (qty / quantity).round().clamp(1, qty)),
        );

        if (kDebugMode) {
          debugPrint(
              '💾 saveAndAddAnotherOrder: Saving per-item free drinks for LTO/regular');
          debugPrint('   Original (quantity-based): ${params.drinkQuantities}');
          debugPrint('   Per-item (saved): $freeDrinkQuantitiesToSave');
          debugPrint('   Quantity: $quantity');
        }
      }

      // ✅ FIX: For LTO regular items, pricing can be null (size is optional)
      // Create a default pricing object if null
      final pricingToSave = pricing ?? MenuItemPricing(
        id: '',
        menuItemId: params.menuItem.id,
        size: '',
        portion: '',
        price: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Create saved order for this variant
      final savedOrder = {
        'variant_id': variantId,
        'variant_name': variant.name,
        'pricing': pricingToSave.toJson(),
        'quantity': quantity,
        'total_price':
            totalPrice, // Store total price (includes base + supplements)
        'supplements':
            params.selectedSupplements.map((s) => s.toJson()).toList(),
        'removed_ingredients': List<String>.from(params.removedIngredients),
        'ingredient_preferences': Map<String, String>.from(
          params.ingredientPreferences.map(
            (key, value) => MapEntry(key, value.toString().split('.').last),
          ),
        ),
        'drinks': drinksWithSizes,
        'drink_quantities': {
          ...freeDrinkQuantitiesToSave,
          ...params.paidDrinkQuantities,
        },
        'free_drink_quantities': freeDrinkQuantitiesToSave,
        'paid_drink_quantities':
            Map<String, int>.from(params.paidDrinkQuantities),
        'note': note,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      };

      // Store in savedVariantOrders by variant ID
      if (!params.savedVariantOrders.containsKey(variantId)) {
        params.savedVariantOrders[variantId] = [];
      }
      params.savedVariantOrders[variantId]!.add(savedOrder);

      debugPrint(
          '💾 Saved variant order: variant=${variant.name}, qty=$quantity, totalPrice=$totalPrice');
    }
  }

  // Clear variants, pricing, and all customizations (no defaults - null selections)
  params.clearSelections();

  debugPrint('✅ saveAndAddAnotherOrder: Order saved and selections cleared');

  // Auto-select single free drink again if available (for the new order)
  params.autoSelectSingleFreeDrink();

  // Show success message
  ScaffoldMessenger.of(params.context).showSnackBar(
    SnackBar(
      content: Text(
        'Order saved! You can now create another order with different preferences.',
        style: GoogleFonts.poppins(),
      ),
      backgroundColor: Colors.green[600],
      duration: const Duration(seconds: 2),
    ),
  );
}
