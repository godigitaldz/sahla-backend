import 'package:flutter/foundation.dart';

import '../../../../../cart_provider.dart';
import '../../../../../models/ingredient_preference.dart';
import '../../../../../models/menu_item_variant.dart';
import '../../../helpers/lto_helper.dart';
import '../../../helpers/pack_customizations_builder.dart';
import '../../../helpers/regular_item_helper.dart';
import 'navigate_to_confirm_flow_params.dart';
import 'unified_order_drinks_handler.dart';

/// Add current variant selections to cart
/// Returns true if drinks were added, false otherwise
bool addCurrentVariantSelectionsToCart({
  required NavigateToConfirmFlowParams params,
  required List<MenuItemVariant> variants,
  required double totalPaidDrinksPrice,
  required List<Map<String, dynamic>> Function() buildDrinksWithSizes,
  required String? Function() buildSpecialInstructions,
  required Map<String, dynamic> Function(
          Map<String, Map<int, Map<String, IngredientPreference>>>)
      convertIngredientPreferencesToJson,
  required List<String> Function(String?) parsePackItemOptions,
  required bool drinksAdded,
}) {
  // Build drinks payload ONCE (shared across all variants for special packs, or single variant for regular items)
  final drinksWithSizes = buildDrinksWithSizes();

  // ✅ FIX: For regular items, only one variant is allowed, so no multi-variant logic needed
  // Determine if multiple variants are selected (only relevant for special packs)
  final isMultipleVariants =
      params.isSpecialPack && params.selectedVariants.length > 1;
  final firstVariantId =
      params.selectedVariants.isNotEmpty ? params.selectedVariants.first : null;

  bool drinksWereAdded = drinksAdded;

  // ✅ FIX: For regular items, only process the first (and only) selected variant
  final List<String> variantsToProcess = params.isSpecialPack
      ? params.selectedVariants.toList()
      : (params.selectedVariants.isNotEmpty
          ? [params.selectedVariants.first]
          : <String>[]);

  for (final variantId in variantsToProcess) {
    // ✅ FIX: For LTO regular items, size is optional, so don't skip variants without pricing
    // For special packs and regular items, skip variants without pricing (they were saved and reset)
    final isLTORegular =
        params.menuItem.isLimitedOffer && !params.isSpecialPack;
    if (!isLTORegular &&
        !params.selectedPricingPerVariant.containsKey(variantId)) {
      // Skip variants that were saved and reset (no active pricing selected)
      continue;
    }
    MenuItemVariant? variant;
    try {
      variant = variants.firstWhere((v) => v.id == variantId);
    } catch (_) {
      variant = null;
    }
    final quantityToUse = params.variantQuantities[variantId] ?? 1;
    final pricing = params.selectedPricingPerVariant[
        variantId]; // Can be null for LTO regular items

    final supplementsPrice =
        params.selectedSupplements.fold(0.0, (sum, s) => sum + s.price);

    // Use unified handler to calculate free drinks for this variant
    final freeDrinkQuantitiesForCart =
        UnifiedOrderDrinksHandler.calculateFreeDrinksForVariant(
      params: params,
      pricing: pricing,
      variantQuantity: quantityToUse,
      variantId: variantId,
      variantName: variant?.name,
    );

    // Use unified handler to determine drinks price for this variant
    final isFirstOverallVariant =
        variantId == firstVariantId && !drinksWereAdded;
    final drinksPriceForThisVariant =
        UnifiedOrderDrinksHandler.getDrinksPriceForItem(
      totalPaidDrinksPrice: totalPaidDrinksPrice,
      isFirstItem: isFirstOverallVariant,
      drinksAlreadyAdded: drinksWereAdded,
    );

    // ✅ FIX: Only include paid drinks in FIRST variant AND only if drinks weren't already added
    // Paid drinks are global - if already added in saved orders, don't include again
    // IMPORTANT: Check BEFORE marking drinks as added, so first variant gets paid drinks
    // This ensures paid drinks are included when there are no saved orders
    final isFirstVariantAndDrinksNotAdded =
        variantId == firstVariantId && !drinksWereAdded;

    if (kDebugMode && isFirstVariantAndDrinksNotAdded) {
      debugPrint(
          '🥤 addCurrentVariantSelections: Including paid drinks in first variant');
      debugPrint('   Paid drinks quantities: ${params.paidDrinkQuantities}');
      debugPrint('   Free drinks quantities: $freeDrinkQuantitiesForCart');
    }

    // Mark drinks as added if this was the first variant overall
    if (isFirstOverallVariant) {
      drinksWereAdded = true;
    }

    // ✅ FIX: For regular items, always include drinks (only one variant)
    // For special packs, paid drinks should only be included if this is the first variant AND drinks weren't already added
    // The price is only added once (to the first item), and quantities should only be in first item
    final shouldIncludeDrinks =
        !params.isSpecialPack || isFirstVariantAndDrinksNotAdded;

    // Calculate price using RegularItemHelper for non-special packs
    final double perUnitPrice;
    if (params.isSpecialPack) {
      // Special pack: use pricing.price as base price
      double basePrice = pricing?.price ?? params.menuItem.price;
      if (basePrice <= 0) {
        basePrice = 200.0;
      }
      final mainItemTotal = (basePrice + supplementsPrice) * quantityToUse +
          drinksPriceForThisVariant;
      perUnitPrice =
          quantityToUse > 0 ? (mainItemTotal / quantityToUse) : mainItemTotal;
    } else {
      // Regular items and LTO regular: use RegularItemHelper
      // ✅ FIX: For regular items, always include drinks price (only one variant)
      final totalPrice = RegularItemHelper.calculatePrice(
        item: params.menuItem,
        pricing: pricing,
        supplementsPrice: supplementsPrice,
        drinksPrice: drinksPriceForThisVariant,
        quantity: quantityToUse,
      );
      perUnitPrice =
          quantityToUse > 0 ? (totalPrice / quantityToUse) : totalPrice;
    }

    // Build pack customizations using shared helper
    Map<String, dynamic>? packSelectionsWithNames;
    Map<String, dynamic>? packIngredientPrefsJson;
    if (params.isSpecialPack) {
      final packCustomizations = buildPackCustomizations(
        PackCustomizationsParams(
          enhancedMenuItem: params.enhancedMenuItem,
          packItemSelections: params.packItemSelections,
          packIngredientPreferences: params.packIngredientPreferences,
          packSupplementSelections: params.packSupplementSelections,
          parsePackItemOptions: parsePackItemOptions,
          convertIngredientPreferencesToJson:
              convertIngredientPreferencesToJson,
          enableDebugLogs: false,
        ),
      );
      packSelectionsWithNames = packCustomizations.packSelectionsWithNames;
      packIngredientPrefsJson = packCustomizations.packIngredientPrefsJson;
    }

    // ✅ FIX: Extract LTO offer types and details for cart customizations
    // This is needed by CartProvider to calculate special delivery discounts
    final ltoCartData = LTOHelper.getLTOCartCustomizations(
      item: params.menuItem,
      pricing: pricing,
    );

    // ✅ FIX: For regular/LTO items, ensure variant and size are always saved when available
    // Similar to how special packs save pack_selections, we need to ensure variant and size are saved
    // Get variant information (always save if variant exists)
    final variantJson = variant?.toJson();

    // Get size and portion from pricing (for regular/LTO items only, not special packs)
    String? sizeValue;
    String? portionValue;
    if (!params.isSpecialPack && pricing != null) {
      // For regular and LTO items, get size from pricing if available
      sizeValue = pricing.size;
      portionValue = pricing.portion;
    }
    // For special packs, size and portion remain null
    // For regular/LTO items without pricing, size and portion remain null (size is optional for LTO)

    final currentCustomizations = {
      'menu_item_id': params.menuItem.id,
      'restaurant_id': (params.menuItem.restaurantId.isNotEmpty
              ? params.menuItem.restaurantId
              : (params.restaurant?.id.toString() ?? ''))
          .trim(),
      'main_item_quantity': quantityToUse,
      'variant': variantJson, // Always save variant if available
      'size':
          sizeValue, // Save size if available (for regular/LTO items with pricing)
      'portion':
          portionValue, // Save portion if available (for regular/LTO items with pricing)
      'supplements': params.selectedSupplements.map((s) => s.toJson()).toList(),
      // ✅ FIX: For regular items, always include drinks (only one variant)
      // For special packs, only include paid drinks in FIRST variant AND only if drinks weren't already added
      'drinks': (!params.isSpecialPack || shouldIncludeDrinks)
          ? drinksWithSizes // Regular items: always include all drinks, or special pack first variant with drinks
          : drinksWithSizes.where((d) {
              // Special pack other variants or drinks already added: only include free drinks
              final isFree = d['is_free'] == true ||
                  (d['price'] as num?)?.toDouble() == 0.0;
              return isFree;
            }).toList(),
      // ✅ FIX: For regular items, always include all drink quantities (only one variant)
      // For special packs, only include paid drinks in FIRST variant AND only if drinks weren't already added
      'drink_quantities': (!params.isSpecialPack || shouldIncludeDrinks)
          ? UnifiedOrderDrinksHandler.mergeAllDrinkQuantities(
              freeDrinkQuantities: freeDrinkQuantitiesForCart,
              paidDrinkQuantities: params.paidDrinkQuantities,
              isMultipleVariants: isMultipleVariants,
              isFirstVariant: true,
            )
          : {
              // Special pack other variants or drinks already added: only include free drinks
              ...freeDrinkQuantitiesForCart,
            },
      // Save free and paid quantities separately to prevent overwriting
      // ✅ FIX: For regular items, always include (only one variant)
      // For special packs, only include in FIRST variant when multiple variants are selected
      // For LTO/regular items: free drinks quantities are already quantity-based (from _getFreeDrinksQuantity())
      'free_drink_quantities': (!params.isSpecialPack ||
              !isMultipleVariants ||
              variantId == firstVariantId)
          ? Map<String, int>.from(freeDrinkQuantitiesForCart)
          : null,
      // ✅ FIX: For regular items, always include paid drinks (only one variant)
      // For special packs, paid drinks quantities ONLY in first variant AND only if drinks weren't already added
      'paid_drink_quantities':
          ((!params.isSpecialPack || shouldIncludeDrinks) &&
                  params.paidDrinkQuantities.isNotEmpty)
              ? Map<String, int>.from(params.paidDrinkQuantities)
              : null,
      'removed_ingredients': params.removedIngredients,
      'ingredient_preferences': params.ingredientPreferences.map(
        (key, value) => MapEntry(key, value.toString().split('.').last),
      ),
      if (packSelectionsWithNames != null && packSelectionsWithNames.isNotEmpty)
        'pack_selections': packSelectionsWithNames,
      if (packIngredientPrefsJson != null && packIngredientPrefsJson.isNotEmpty)
        'pack_ingredient_preferences': packIngredientPrefsJson,
      'is_special_pack': params.isSpecialPack,
      'is_limited_offer': params.menuItem.isLimitedOffer,
      // ✅ FIX: Add LTO offer types and details for special delivery discount calculation
      ...ltoCartData,
      'popup_session_id': params.popupSessionId,
    };

    final cartItem = CartItem(
      id: '${DateTime.now().millisecondsSinceEpoch}_$variantId',
      name:
          '${params.menuItem.name}${variant != null ? ' - ${variant.name}' : ''}',
      price: perUnitPrice,
      quantity: quantityToUse,
      image: params.menuItem.image,
      restaurantName: params.menuItem.restaurantName,
      customizations: currentCustomizations,
      // ✅ FIX: For regular items, always include all drink quantities (only one variant)
      // For special packs, only include paid drinks in FIRST variant AND only if drinks weren't already added
      // Paid drinks are global - if already added in saved orders, don't include again
      drinkQuantities: (!params.isSpecialPack || shouldIncludeDrinks)
          ? UnifiedOrderDrinksHandler.mergeAllDrinkQuantities(
              freeDrinkQuantities: freeDrinkQuantitiesForCart,
              paidDrinkQuantities: params.paidDrinkQuantities,
              isMultipleVariants: isMultipleVariants,
              isFirstVariant: true,
            )
          : {
              // Special pack other variants or drinks already added: only include free drinks
              ...freeDrinkQuantitiesForCart,
            },
      specialInstructions: buildSpecialInstructions() ?? '',
    );

    if (kDebugMode) {
      debugPrint(
          '🛒 addCurrentVariantSelections: Adding variant ${variant?.name} (qty: $quantityToUse, unitPrice: $perUnitPrice, drinksPrice: $drinksPriceForThisVariant)');
      debugPrint(
          '   isFirstVariantAndDrinksNotAdded: $isFirstVariantAndDrinksNotAdded');
      debugPrint('   drinkQuantities: ${cartItem.drinkQuantities}');
      debugPrint(
          '   paid_drink_quantities in customizations: ${cartItem.customizations?['paid_drink_quantities']}');
      debugPrint(
          '   drinks count in customizations: ${(cartItem.customizations?['drinks'] as List?)?.length ?? 0}');
    }
    params.cartProvider.addToCart(cartItem);
  }

  return drinksWereAdded;
}
