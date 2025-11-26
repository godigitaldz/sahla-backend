import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../cart_provider.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../models/enhanced_menu_item.dart';
import '../../../../models/ingredient_preference.dart';
import '../../../../models/menu_item.dart';
import '../../../../models/menu_item_pricing.dart';
import '../../../../models/menu_item_supplement.dart';
import '../../../../models/menu_item_variant.dart';
import '../../../../models/order_item.dart';
import '../../../../models/restaurant.dart';
import '../../helpers/lto_helper.dart';
import '../../helpers/pack_customizations_builder.dart';
import '../../helpers/regular_item_helper.dart';
import '../../helpers/special_pack_helper.dart';
import '../add_to_cart_widget.dart';
import '../helpers/pack_state_helper.dart';
import 'build_drink_image.dart';
import 'navigate_to_confirm_flow/add_current_variant_selections.dart';
import 'navigate_to_confirm_flow/navigate_to_confirm_flow_params.dart';

/// Parameters bundle for addToCart method
class AddToCartParams {
  final BuildContext context;
  final MenuItem menuItem;
  final Restaurant? restaurant;
  final bool isSpecialPack;
  final String popupSessionId;

  // State variables
  final List<OrderItem> savedOrders;
  final Set<String> selectedVariants;
  final Map<String, MenuItemPricing> selectedPricingPerVariant;
  final Map<String, int> paidDrinkQuantities;
  final List<MenuItem> selectedDrinks;
  final Map<String, int> drinkQuantities;
  final Map<String, String> drinkSizesById;
  final int quantity;
  final List<MenuItemSupplement> selectedSupplements;
  final List<String> removedIngredients;
  final Map<String, IngredientPreference> ingredientPreferences;
  final Map<String, Map<int, String>> packItemSelections;
  final Map<String, Map<int, Map<String, IngredientPreference>>>
      packIngredientPreferences;
  final Map<String, Map<int, Set<String>>> packSupplementSelections;
  final Map<String, List<Map<String, dynamic>>> savedVariantOrders;
  final EnhancedMenuItem? enhancedMenuItem;
  final List<MenuItem> restaurantDrinks;
  final String specialNote;

  // Callbacks
  final bool Function({required bool checkFreeDrinks}) validateSelection;
  final String? Function() buildSpecialInstructions;
  final Map<String, dynamic> Function(
          Map<String, Map<int, Map<String, IngredientPreference>>>)
      convertIngredientPreferencesToJson;
  final List<String> Function(String?) parsePackItemOptions;
  final Future<void> Function() clearPreferences;
  final void Function() onComplete;

  AddToCartParams({
    required this.context,
    required this.menuItem,
    required this.restaurant,
    required this.isSpecialPack,
    required this.popupSessionId,
    required this.savedOrders,
    required this.selectedVariants,
    required this.selectedPricingPerVariant,
    required this.paidDrinkQuantities,
    required this.selectedDrinks,
    required this.drinkQuantities,
    required this.drinkSizesById,
    required this.quantity,
    required this.selectedSupplements,
    required this.removedIngredients,
    required this.ingredientPreferences,
    required this.packItemSelections,
    required this.packIngredientPreferences,
    required this.packSupplementSelections,
    required this.savedVariantOrders,
    required this.enhancedMenuItem,
    required this.restaurantDrinks,
    required this.specialNote,
    required this.validateSelection,
    required this.buildSpecialInstructions,
    required this.convertIngredientPreferencesToJson,
    required this.parsePackItemOptions,
    required this.clearPreferences,
    required this.onComplete,
  });
}

/// Add to cart method for special pack popup
/// Returns true if successful, false if validation failed
Future<bool> addToCart(AddToCartParams params) async {
  debugPrint('🛒 addToCart: Starting add to cart process');
  debugPrint('  savedOrders.length: ${params.savedOrders.length}');
  debugPrint(
      '  selectedPricingPerVariant: ${params.selectedPricingPerVariant.keys.toList()}');
  debugPrint('  menuItem.price: ${params.menuItem.price}');

  // Validate selection (including free drinks check)
  if (!params.validateSelection(checkFreeDrinks: true)) {
    return false;
  }

  // ✅ FIX: Calculate paid drinks price ONCE globally (drinks are global for entire order)
  // This will be added only to the first item overall (whether saved or current)
  double totalPaidDrinksPrice = 0.0;
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
      if (drink.price > 0) {
        totalPaidDrinksPrice += drink.price * entry.value;
      }
    }
  }

  // Track if drinks have been added (global flag - drinks only added once)
  bool drinksAdded = false;

  if (params.savedOrders.isNotEmpty) {
    // Add only saved orders to cart to match pricing/confirm behavior
    for (final saved in params.savedOrders) {
      final savedQty = saved.quantity > 0 ? saved.quantity : 1;
      final savedUnitPrice = saved.totalPrice / savedQty;
      debugPrint(
          '🛒 addToCart: Saved order - qty: $savedQty, unitPrice: $savedUnitPrice, totalPrice: ${saved.totalPrice}');

      final savedRestaurantIdRaw =
          (saved.customizations?['restaurant_id']?.toString() ?? '').trim();
      final fallbackRestaurantIdRaw = (params.menuItem.restaurantId.isNotEmpty
              ? params.menuItem.restaurantId
              : (params.restaurant?.id.toString() ?? ''))
          .trim();
      final restaurantIdToUse = savedRestaurantIdRaw.isNotEmpty
          ? savedRestaurantIdRaw
          : fallbackRestaurantIdRaw;
      // Preserve drink quantities from saved customizations
      final Map<String, int> savedDrinkQuantities = {};
      final dq = saved.customizations?['drink_quantities'];
      if (dq is Map) {
        dq.forEach((k, v) {
          final key = k.toString();
          final val = v is int ? v : int.tryParse(v.toString()) ?? 0;
          if (val > 0) savedDrinkQuantities[key] = val;
        });
      }
      final drinksListFromSaved = savedDrinkQuantities.keys.map((id) {
        final match = params.restaurantDrinks.where((d) => d.id == id);
        final name = match.isNotEmpty ? (match.first.name) : id;
        final size = params.drinkSizesById[id];
        final map = {
          'id': id,
          'name': name,
        };
        if (size != null && size.isNotEmpty) map['size'] = size;
        return map;
      }).toList();

      final cartItemSaved = CartItem(
        id: saved.id,
        name: saved.menuItem?.name ?? params.menuItem.name,
        price: savedUnitPrice,
        quantity: savedQty,
        image: saved.menuItem?.image ?? params.menuItem.image,
        restaurantName:
            saved.menuItem?.restaurantName ?? params.menuItem.restaurantName,
        customizations: {
          ...?saved.customizations?.toMap(),
          'restaurant_id': restaurantIdToUse,
          if (drinksListFromSaved.isNotEmpty) 'drinks': drinksListFromSaved,
        },
        drinkQuantities: savedDrinkQuantities,
        specialInstructions: saved.specialInstructions,
      );
      final cartProvider =
          Provider.of<CartProvider>(params.context, listen: false);
      cartProvider.addToCart(cartItemSaved);
    }
  } else {
    // No saved orders: add current form selection
    final cartProvider =
        Provider.of<CartProvider>(params.context, listen: false);

    // Special packs always have variants, so skip the empty variants check
    // Build drinks payload ONCE (shared across all variants)
    // ✅ FIX: Paid drinks should come FIRST, then free drinks (matching display order)
    final drinksWithSizes = <Map<String, dynamic>>[
      // Paid drinks FIRST (look up by id from restaurant list)
      ...params.paidDrinkQuantities.entries
          .map((entry) => params.restaurantDrinks
                  .where((d) => d.id == entry.key)
                  .map((drink) {
                final map = drink.toJson();
                final sz = params.drinkSizesById[drink.id];
                if (sz != null && sz.isNotEmpty) map['size'] = sz;
                // Mark as paid drink
                map['is_free'] = false;
                return map;
              }))
          .expand((e) => e),
      // Free drinks SECOND - mark as free by setting price to 0
      ...params.selectedDrinks.map((d) {
        final map = d.toJson();
        final sz = params.drinkSizesById[d.id];
        if (sz != null && sz.isNotEmpty) map['size'] = sz;
        // Mark as free drink by setting price to 0
        map['price'] = 0.0;
        map['is_free'] = true;
        return map;
      }),
    ];

    // ✅ FIX: For special packs only, create ONE unified cart item
    // Regular items should use addCurrentVariantSelectionsToCart instead
    if (params.isSpecialPack && params.selectedVariants.isNotEmpty) {
      // Calculate unified pricing for special packs
      double basePrice = params.menuItem.price;
      if (basePrice <= 0 && params.selectedPricingPerVariant.isNotEmpty) {
        final firstPricing = params.selectedPricingPerVariant.values.first;
        basePrice = firstPricing.price;
      }
      if (basePrice <= 0) {
        basePrice = 200.0; // Default fallback price
      }

      final supplementsPrice =
          params.selectedSupplements.fold(0.0, (sum, s) => sum + s.price);

      // ✅ FIX: Calculate per-unit price WITHOUT drinks (drinks are global, not per item)
      // Drinks should be added only once for the entire order, not per item
      final perUnitPrice = basePrice + supplementsPrice;

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
          enableDebugLogs: true,
        ),
      );

      final packSelectionsWithNames =
          packCustomizations.packSelectionsWithNames;
      final packIngredientPrefsJson =
          packCustomizations.packIngredientPrefsJson;
      final packSupplementSelectionsJson =
          packCustomizations.packSupplementSelectionsJson;
      final packSupplementPricesJson =
          packCustomizations.packSupplementPricesJson;

      // ✅ FIX: Extract LTO offer types and details for cart customizations
      // For special packs, use first pricing if available
      final firstPricingForLTO = params.selectedPricingPerVariant.isNotEmpty
          ? params.selectedPricingPerVariant.values.first
          : null;
      final ltoCartData = LTOHelper.getLTOCartCustomizations(
        item: params.menuItem,
        pricing: firstPricingForLTO,
      );

      // Create ONE unified cart item for special pack with unified pricing
      final currentCustomizations = {
        'menu_item_id': params.menuItem.id,
        'restaurant_id': (params.menuItem.restaurantId.isNotEmpty
                ? params.menuItem.restaurantId
                : (params.restaurant?.id.toString() ?? ''))
            .trim(),
        'main_item_quantity': params.quantity,
        'variant': null, // No single variant for special packs
        'size': null,
        'portion': null,
        'supplements':
            params.selectedSupplements.map((s) => s.toJson()).toList(),
        'drinks': drinksWithSizes,
        'drink_quantities': {
          ...params.drinkQuantities,
          ...params.paidDrinkQuantities,
        },
        // Save free and paid quantities separately to prevent overwriting
        'free_drink_quantities': Map<String, int>.from(params.drinkQuantities),
        'paid_drink_quantities':
            Map<String, int>.from(params.paidDrinkQuantities),
        'removed_ingredients': params.removedIngredients,
        'ingredient_preferences': params.ingredientPreferences.map(
          (key, value) => MapEntry(key, value.toString().split('.').last),
        ),
        // ✅ ADD: Save pack selections with variant names for special packs
        if (packSelectionsWithNames.isNotEmpty)
          'pack_selections': packSelectionsWithNames,
        // ✅ ADD: Save pack ingredient preferences
        if (packIngredientPrefsJson != null &&
            packIngredientPrefsJson.isNotEmpty)
          'pack_ingredient_preferences': packIngredientPrefsJson,
        // ✅ ADD: Save pack supplement selections
        if (packSupplementSelectionsJson != null &&
            packSupplementSelectionsJson.isNotEmpty)
          'pack_supplement_selections': packSupplementSelectionsJson,
        // ✅ ADD: Save pack supplement prices
        if (packSupplementPricesJson != null &&
            packSupplementPricesJson.isNotEmpty)
          'pack_supplement_prices': packSupplementPricesJson,
        // ✅ ADD: Flag to identify special pack items
        'is_special_pack': params.isSpecialPack,
        // ✅ ADD: Flag for LTO items
        'is_limited_offer': params.menuItem.isLimitedOffer,
        // ✅ FIX: Add LTO offer types and details for special delivery discount calculation
        ...ltoCartData,
        // ✅ Grouping key for items added from the same popup
        'popup_session_id': params.popupSessionId,
      };

      // ✅ FIX: Split quantity > 1 into separate items (one per unit)
      // Free drinks are per-item (each pack includes its own free drink)
      // Paid drinks are global for the whole order - add paid drinks price only to the first item
      for (int i = 0; i < params.quantity; i++) {
        final isFirstOverallItem = i == 0 && !drinksAdded;
        // Only the very first item overall includes paid drinks price (paid drinks are global, not per item)
        final itemPrice = isFirstOverallItem
            ? perUnitPrice +
                totalPaidDrinksPrice // First item overall includes paid drinks
            : perUnitPrice; // Other items: no paid drinks

        // Each item gets free drinks (each pack includes its own free drink)
        // Only the first item gets paid drinks (paid drinks are global)
        final itemDrinkQuantities = {
          ...params.drinkQuantities, // Free drinks: add to each item
          if (isFirstOverallItem)
            ...params.paidDrinkQuantities, // Paid drinks: only first item
        };

        // Create customizations for this item
        // Free drinks are included in each item, paid drinks only in first item
        final itemCustomizations =
            Map<String, dynamic>.from(currentCustomizations);
        if (!isFirstOverallItem) {
          // For items after the first: remove paid drinks but keep free drinks
          itemCustomizations.remove('paid_drink_quantities');
          // Keep free drinks for each item
          itemCustomizations['free_drink_quantities'] =
              Map<String, int>.from(params.drinkQuantities);
          // Update drink_quantities to only include free drinks
          itemCustomizations['drink_quantities'] =
              Map<String, int>.from(params.drinkQuantities);
          // Update drinks list to only include free drinks
          final freeDrinksOnly = drinksWithSizes.where((d) {
            final isFree =
                d['is_free'] == true || (d['price'] as num?)?.toDouble() == 0.0;
            return isFree;
          }).toList();
          itemCustomizations['drinks'] = freeDrinksOnly;
        } else {
          // First item gets both free and paid drinks
          itemCustomizations['free_drink_quantities'] =
              Map<String, int>.from(params.drinkQuantities);
          itemCustomizations['paid_drink_quantities'] =
              Map<String, int>.from(params.paidDrinkQuantities);
        }

        // Clean up customizations to ensure all values are JSON-encodable
        final cleanedCustomizations = <String, dynamic>{};
        itemCustomizations.forEach((key, value) {
          if (value != null) {
            // Recursively clean the value to ensure it's JSON-encodable
            cleanedCustomizations[key] = _makeJsonEncodable(value);
          }
        });

        final cartItem = CartItem(
          id: '${DateTime.now().millisecondsSinceEpoch}_addtocart_pack_$i',
          name: params.menuItem.name,
          price: itemPrice,
          quantity: 1, // Each item has quantity 1
          image: params.menuItem.image,
          restaurantName: params.menuItem.restaurantName,
          customizations: cleanedCustomizations,
          drinkQuantities: itemDrinkQuantities,
          specialInstructions: params.buildSpecialInstructions() ?? '',
        );

        debugPrint(
            '🛒 addToCart: Adding special pack item ${i + 1}/${params.quantity} (unitPrice: $itemPrice, hasFreeDrinks: true, hasPaidDrinks: $isFirstOverallItem)');
        cartProvider.addToCart(cartItem);

        // Mark drinks as added if this was the first item overall
        if (isFirstOverallItem) {
          drinksAdded = true;
        }
      }
      // Exit early for special packs - don't loop through variants
      return true;
    }

    // Add all saved variant orders
    // Handle unified pack orders (special packs only use 'pack' key)
    if (params.savedVariantOrders.containsKey('pack')) {
      // Process unified pack orders
      final savedPackOrders = params.savedVariantOrders['pack']!;
      for (final savedOrder in savedPackOrders) {
        final quantity = savedOrder['quantity'] as int;

        // Use unified total price if available
        double totalPrice;
        double perUnitPrice;
        if (savedOrder.containsKey('total_price')) {
          totalPrice = (savedOrder['total_price'] as num).toDouble();
          perUnitPrice = quantity > 0 ? (totalPrice / quantity) : totalPrice;
        } else {
          // Fallback: calculate from pricing
          final pricing = MenuItemPricing.fromJson(
              savedOrder['pricing'] as Map<String, dynamic>);
          final supplements = (savedOrder['supplements'] as List?)
                  ?.map((s) =>
                      MenuItemSupplement.fromJson(s as Map<String, dynamic>))
                  .toList() ??
              [];
          final basePrice = pricing.price;
          final supplementsPrice =
              supplements.fold(0.0, (sum, s) => sum + s.price);

          // ✅ FIX: Don't calculate paid drinks from saved order - paid drinks are global
          // Paid drinks should only come from current selections (paidDrinkQuantities)

          // ✅ FIX: Use saved total_price directly to ensure accuracy
          // Saved orders already have the correct total (base + supplements) without drinks
          if (savedOrder.containsKey('total_price')) {
            totalPrice = (savedOrder['total_price'] as num).toDouble();
            perUnitPrice = quantity > 0 ? (totalPrice / quantity) : totalPrice;
          } else {
            // Fallback: calculate from pricing and supplements
            totalPrice = (basePrice + supplementsPrice) * quantity;
            perUnitPrice = basePrice + supplementsPrice;
          }
        }

        final supplements = (savedOrder['supplements'] as List?)
                ?.map((s) =>
                    MenuItemSupplement.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [];
        final removedIngredients =
            List<String>.from(savedOrder['removed_ingredients'] as List? ?? []);
        final ingredientPrefs = Map<String, String>.from(
            savedOrder['ingredient_preferences'] as Map? ?? {});
        final note = savedOrder['note'] as String? ?? '';

        // Restore drinks from saved order
        final savedDrinks = (savedOrder['drinks'] as List?)?.map((d) {
              if (d is Map<String, dynamic>) {
                return d;
              }
              return {};
            }).toList() ??
            [];

        // Restore separate free and paid quantities if available
        final savedFreeDrinkQuantities = savedOrder['free_drink_quantities'] !=
                null
            ? Map<String, int>.from(savedOrder['free_drink_quantities'] as Map)
            : <String, int>{};
        // ✅ FIX: Paid drinks are global - only use current selections, NOT saved
        // Saved orders don't include paid drinks - they're separate/global
        final mergedPaidDrinkQuantities = <String, int>{
          ...params
              .paidDrinkQuantities, // Only current paid drinks - don't include saved
        };
        final mergedFreeDrinkQuantities = <String, int>{
          ...savedFreeDrinkQuantities,
          ...params.drinkQuantities, // Include current free drinks
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

        // Merge saved and current drinks (avoid duplicates by drink ID)
        final allDrinks = <Map<String, dynamic>>[];
        final drinkIdsAdded = <String>{};

        // Add saved drinks first
        for (final drink in savedDrinks) {
          final drinkId = drink['id']?.toString() ?? '';
          if (drinkId.isNotEmpty && !drinkIdsAdded.contains(drinkId)) {
            allDrinks.add(Map<String, dynamic>.from(drink));
            drinkIdsAdded.add(drinkId);
          }
        }

        // Add current drinks (will override saved if same ID)
        for (final drink in [...currentFreeDrinks, ...currentPaidDrinks]) {
          final drinkId = drink['id']?.toString() ?? '';
          if (drinkId.isNotEmpty) {
            if (drinkIdsAdded.contains(drinkId)) {
              // Update existing drink entry
              final index =
                  allDrinks.indexWhere((d) => d['id']?.toString() == drinkId);
              if (index >= 0) {
                allDrinks[index] = drink;
              }
            } else {
              allDrinks.add(drink);
              drinkIdsAdded.add(drinkId);
            }
          }
        }

        // Merge free and paid quantities for drink_quantities (backward compatibility)
        final mergedDrinkQuantities = <String, int>{
          ...mergedFreeDrinkQuantities,
          ...mergedPaidDrinkQuantities,
        };

        // ✅ FIX: Don't recalculate drinks price here - already calculated globally above
        // Use the global totalPaidDrinksPrice variable

        // Restore pack selections and customizations for unified pack order
        final packSelectionsWithNames =
            savedOrder['pack_selections'] as Map<String, dynamic>?;
        final packIngredientPrefsJson =
            savedOrder['pack_ingredient_preferences'] as Map<String, dynamic>?;
        final packSupplementSelectionsJson =
            savedOrder['pack_supplement_selections'] as Map<String, dynamic>?;
        final packSupplementPricesJson =
            savedOrder['pack_supplement_prices'] as Map<String, dynamic>?;

        // ✅ FIX: Extract LTO offer types and details for cart customizations
        // For saved orders, use first pricing if available
        final firstPricingForSavedLTO = params.selectedPricingPerVariant.isNotEmpty
            ? params.selectedPricingPerVariant.values.first
            : null;
        final ltoCartDataForSaved = LTOHelper.getLTOCartCustomizations(
          item: params.menuItem,
          pricing: firstPricingForSavedLTO,
        );

        // Create ONE unified cart item for the special pack
        final currentCustomizations = {
          'menu_item_id': params.menuItem.id,
          'restaurant_id': (params.menuItem.restaurantId.isNotEmpty
                  ? params.menuItem.restaurantId
                  : (params.restaurant?.id.toString() ?? ''))
              .trim(),
          'main_item_quantity': quantity,
          'variant': null, // No single variant for unified pack
          'size': null,
          'portion': null,
          'supplements': supplements.map((s) => s.toJson()).toList(),
          'drinks': allDrinks.isNotEmpty ? allDrinks : savedDrinks,
          'drink_quantities': mergedDrinkQuantities,
          'free_drink_quantities': mergedFreeDrinkQuantities.isNotEmpty
              ? mergedFreeDrinkQuantities
              : null,
          'paid_drink_quantities': mergedPaidDrinkQuantities.isNotEmpty
              ? mergedPaidDrinkQuantities
              : null,
          'removed_ingredients': removedIngredients,
          'ingredient_preferences': ingredientPrefs,
          if (packSelectionsWithNames != null &&
              packSelectionsWithNames.isNotEmpty)
            'pack_selections': packSelectionsWithNames,
          if (packIngredientPrefsJson != null &&
              packIngredientPrefsJson.isNotEmpty)
            'pack_ingredient_preferences': packIngredientPrefsJson,
          if (packSupplementSelectionsJson != null &&
              packSupplementSelectionsJson.isNotEmpty)
            'pack_supplement_selections': packSupplementSelectionsJson,
          if (packSupplementPricesJson != null &&
              packSupplementPricesJson.isNotEmpty)
            'pack_supplement_prices': packSupplementPricesJson,
          'is_special_pack': params.isSpecialPack,
          'is_limited_offer': params.menuItem.isLimitedOffer,
          // ✅ FIX: Add LTO offer types and details for special delivery discount calculation
          ...ltoCartDataForSaved,
          'popup_session_id': params.popupSessionId,
        };

        // ✅ FIX: Split quantity > 1 into separate items (one per unit)
        // Free drinks are per-item (each pack includes its own free drink)
        // Paid drinks are global for the whole order - add paid drinks price only to the first item
        for (int i = 0; i < quantity; i++) {
          final isFirstOverallItem = i == 0 && !drinksAdded;
          // Only the very first item overall includes paid drinks price (paid drinks are global, not per item)
          final itemPrice = isFirstOverallItem
              ? perUnitPrice +
                  totalPaidDrinksPrice // First item overall includes paid drinks
              : perUnitPrice; // Other items: no paid drinks

          // Each item gets free drinks (each pack includes its own free drink)
          // Only the first item gets paid drinks (paid drinks are global)
          final itemDrinkQuantities = {
            ...mergedFreeDrinkQuantities, // Free drinks: add to each item
            if (isFirstOverallItem)
              ...mergedPaidDrinkQuantities, // Paid drinks: only first item
          };

          // Create customizations for this item
          // Free drinks are included in each item, paid drinks only in first item
          final itemCustomizations =
              Map<String, dynamic>.from(currentCustomizations);
          if (!isFirstOverallItem) {
            // For items after the first: remove paid drinks but keep free drinks
            itemCustomizations['paid_drink_quantities'] = null;
            // Keep free drinks for each item
            itemCustomizations['free_drink_quantities'] =
                Map<String, int>.from(mergedFreeDrinkQuantities);
            // Update drink_quantities to only include free drinks
            itemCustomizations['drink_quantities'] =
                Map<String, int>.from(mergedFreeDrinkQuantities);
            // Update drinks list to only include free drinks
            final freeDrinksOnly = allDrinks.where((d) {
              final isFree = d['is_free'] == true ||
                  (d['price'] as num?)?.toDouble() == 0.0;
              return isFree;
            }).toList();
            itemCustomizations['drinks'] = freeDrinksOnly;
          } else {
            // First item gets both free and paid drinks
            itemCustomizations['free_drink_quantities'] =
                Map<String, int>.from(mergedFreeDrinkQuantities);
            itemCustomizations['paid_drink_quantities'] =
                Map<String, int>.from(mergedPaidDrinkQuantities);
          }

          final cartItem = CartItem(
            id: '${DateTime.now().millisecondsSinceEpoch}_saved_pack_$i',
            name: params.menuItem.name,
            price: itemPrice,
            quantity: 1, // Each item has quantity 1
            image: params.menuItem.image,
            restaurantName: params.menuItem.restaurantName,
            customizations: itemCustomizations,
            drinkQuantities: itemDrinkQuantities,
            specialInstructions: note,
          );

          debugPrint(
              '🛒 addToCart: Adding saved unified pack order item ${i + 1}/$quantity (unitPrice: $itemPrice, hasFreeDrinks: true, hasPaidDrinks: $isFirstOverallItem)');
          cartProvider.addToCart(cartItem);

          // Mark drinks as added if this was the first item overall
          if (isFirstOverallItem) {
            drinksAdded = true;
          }
        }
      }
    }

    // ✅ FIX: For regular items (non-special pack) without saved orders, use addCurrentVariantSelectionsToCart
    // This ensures variant and size are properly saved for regular/LTO items
    if (!params.isSpecialPack && params.savedVariantOrders.isEmpty) {
      final cartProvider = Provider.of<CartProvider>(params.context, listen: false);

      // Build variant quantities map (for regular items, use quantity for each selected variant)
      final variantQuantities = <String, int>{};
      for (final variantId in params.selectedVariants) {
        variantQuantities[variantId] = params.quantity;
      }

      // Build drinks with sizes
      final drinksWithSizes = <Map<String, dynamic>>[
        // Paid drinks FIRST
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
        // Free drinks SECOND
        ...params.selectedDrinks.map((d) {
          final map = d.toJson();
          final sz = params.drinkSizesById[d.id];
          if (sz != null && sz.isNotEmpty) map['size'] = sz;
          map['price'] = 0.0;
          map['is_free'] = true;
          return map;
        }),
      ];

      // Create NavigateToConfirmFlowParams
      final navigateParams = NavigateToConfirmFlowParams(
        cartProvider: cartProvider,
        menuItem: params.menuItem,
        restaurant: params.restaurant,
        enhancedMenuItem: params.enhancedMenuItem,
        isSpecialPack: params.isSpecialPack,
        selectedVariants: params.selectedVariants,
        selectedPricingPerVariant: params.selectedPricingPerVariant,
        selectedSupplements: params.selectedSupplements,
        removedIngredients: params.removedIngredients,
        ingredientPreferences: params.ingredientPreferences,
        savedOrders: params.savedOrders,
        selectedDrinks: params.selectedDrinks,
        restaurantDrinks: params.restaurantDrinks,
        drinkQuantities: params.drinkQuantities,
        paidDrinkQuantities: params.paidDrinkQuantities,
        drinkSizesById: params.drinkSizesById,
        quantity: params.quantity,
        variantQuantities: variantQuantities,
        packItemSelections: params.packItemSelections,
        packIngredientPreferences: params.packIngredientPreferences,
        packSupplementSelections: params.packSupplementSelections,
        savedVariantOrders: params.savedVariantOrders,
        popupSessionId: params.popupSessionId,
        buildSpecialInstructions: params.buildSpecialInstructions,
        convertIngredientPreferencesToJson: params.convertIngredientPreferencesToJson,
        parsePackItemOptions: params.parsePackItemOptions,
      );

      // Get variants from enhanced menu item
      final variants = params.enhancedMenuItem?.variants ?? <MenuItemVariant>[];

      // Call addCurrentVariantSelectionsToCart for regular items
      addCurrentVariantSelectionsToCart(
        params: navigateParams,
        variants: variants,
        totalPaidDrinksPrice: totalPaidDrinksPrice,
        buildDrinksWithSizes: () => drinksWithSizes,
        buildSpecialInstructions: params.buildSpecialInstructions,
        convertIngredientPreferencesToJson: params.convertIngredientPreferencesToJson,
        parsePackItemOptions: params.parsePackItemOptions,
        drinksAdded: drinksAdded,
      );
    }
  }

  // Clear saved orders after adding to cart (via callback)
  params.onComplete();

  // Show success message
  ScaffoldMessenger.of(params.context).showSnackBar(
    SnackBar(
      content: Text(
        AppLocalizations.of(params.context)!.addedToCart,
        style: GoogleFonts.poppins(),
      ),
      backgroundColor: Colors.green[600],
      duration: const Duration(seconds: 2),
    ),
  );

  // ✅ FIX: For regular items and LTO items, keep popup open (smooth transition)
  // Only close popup for special packs
  if (params.isSpecialPack) {
    Navigator.pop(params.context);
  }
  // For regular/LTO items, popup stays open and cart counter updates automatically
  // via Consumer<CartProvider> in the add to cart button

  return true;
}

// ============================================================================
// Build Add to Cart Section (UI Builder)
// ============================================================================

/// Parameters for build add to cart section operations
class BuildAddToCartSectionParams {
  final EnhancedMenuItem? enhancedMenuItem;
  final MenuItem menuItem;
  final bool isSpecialPack;
  final Set<String> selectedVariants;
  final Map<String, MenuItemPricing> selectedPricingPerVariant;
  final List<MenuItemSupplement> selectedSupplements;
  final List<MenuItem> restaurantDrinks;
  final Map<String, int> paidDrinkQuantities;
  final int quantity;
  final Map<String, Map<int, String>> packItemSelections;
  final Map<String, Map<int, Set<String>>> packSupplementSelections;
  final Map<String, List<Map<String, dynamic>>> savedVariantOrders;
  final List<OrderItem> savedOrders;
  final CartItem? existingCartItem;
  final List<String> Function() getFreeDrinkIds;
  final bool Function() hasSavedVariantOrders;
  final int Function() getFreeDrinksQuantity;
  final void Function(String, int) removeSavedVariantOrder;
  final void Function() saveAndAddAnotherOrder;
  final Future<bool> Function() addToCart;
  final Future<void> Function() submitOrder;
  final Future<void> Function() navigateToConfirmFlow;
  final Map<String, int> drinkQuantities;
  final Map<String, String> drinkImageCache;
  final VoidCallback? onQuantityDecrease;
  final VoidCallback onQuantityIncrease;
  final Function(String, int) onFreeDrinkQuantityChanged;
  final Function(MenuItem) onFreeDrinkSelected;
  final Function(String) onFreeDrinkDeselected;
  final Widget Function(MenuItem) buildDrinkImage;
  final Widget? paidDrinksSection;
  final Map<String, int>?
      variantQuantities; // For regular items with per-variant quantities

  BuildAddToCartSectionParams({
    required this.enhancedMenuItem,
    required this.menuItem,
    required this.isSpecialPack,
    required this.selectedVariants,
    required this.selectedPricingPerVariant,
    required this.selectedSupplements,
    required this.restaurantDrinks,
    required this.paidDrinkQuantities,
    required this.quantity,
    required this.packItemSelections,
    required this.packSupplementSelections,
    required this.savedVariantOrders,
    required this.savedOrders,
    required this.existingCartItem,
    required this.getFreeDrinkIds,
    required this.hasSavedVariantOrders,
    required this.getFreeDrinksQuantity,
    required this.removeSavedVariantOrder,
    required this.saveAndAddAnotherOrder,
    required this.addToCart,
    required this.submitOrder,
    required this.navigateToConfirmFlow,
    required this.drinkQuantities,
    required this.drinkImageCache,
    required this.onQuantityDecrease,
    required this.onQuantityIncrease,
    required this.onFreeDrinkQuantityChanged,
    required this.onFreeDrinkSelected,
    required this.onFreeDrinkDeselected,
    required this.buildDrinkImage,
    this.paidDrinksSection,
    this.variantQuantities,
  });
}

/// Build unified add to cart section (combines quantity, save, saved orders, free drinks, and confirm/add to cart)
Widget buildAddToCartSection(BuildAddToCartSectionParams params) {
  if (params.enhancedMenuItem == null) {
    return const SizedBox.shrink();
  }

  // Check if we have selections to save
  // ✅ FIX: For LTO regular items, size is optional, so don't require pricing
  final isLTORegular = params.menuItem.isLimitedOffer && !params.isSpecialPack;
  final hasVariantSelections = params.selectedVariants.isNotEmpty &&
      (isLTORegular || params.selectedPricingPerVariant.isNotEmpty);
  final hasPackItemSelections =
      PackStateHelper.hasPackSelections(params.packItemSelections);

  // Get free drinks (exclude for special packs and LTO items - they're shown in selector/container instead)
  final freeDrinkIds = (params.isSpecialPack || isLTORegular) ? <String>[] : params.getFreeDrinkIds();
  final freeDrinks = freeDrinkIds.isEmpty
      ? <MenuItem>[]
      : params.restaurantDrinks
          .where((drink) => freeDrinkIds.contains(drink.id))
          .toList();

  // Build saved orders list
  final List<Map<String, dynamic>> savedOrdersList = [];
  if (params.hasSavedVariantOrders()) {
    final variants = params.enhancedMenuItem?.variants ?? [];
    for (final variantEntry in params.savedVariantOrders.entries) {
      final variantId = variantEntry.key;
      final savedOrders = variantEntry.value;

      for (int orderIndex = 0; orderIndex < savedOrders.length; orderIndex++) {
        final savedOrder = savedOrders[orderIndex];
        final quantity = savedOrder['quantity'] as int;

        if (params.isSpecialPack && variantId == 'pack') {
          double totalPrice;
          if (savedOrder.containsKey('total_price')) {
            totalPrice = (savedOrder['total_price'] as num).toDouble();
          } else {
            final pricing = MenuItemPricing.fromJson(
                savedOrder['pricing'] as Map<String, dynamic>);
            final supplements = (savedOrder['supplements'] as List?)
                    ?.map((s) =>
                        MenuItemSupplement.fromJson(s as Map<String, dynamic>))
                    .toList() ??
                [];
            final basePrice = pricing.price;

            // ✅ FIX: Only include global supplements (filter out pack supplements)
            final globalSupplementsOnly = supplements.where((s) {
              return !s.id.startsWith('pack_');
            }).toList();
            final globalSupplementsPrice =
                globalSupplementsOnly.fold(0.0, (sum, s) => sum + s.price);

            // ✅ FIX: Calculate pack supplements price from pack_supplement_prices
            double packSupplementsPrice = 0.0;
            final packSupplementPrices =
                savedOrder['pack_supplement_prices'] as Map<String, dynamic>?;
            if (packSupplementPrices != null) {
              packSupplementPrices.forEach((variantName, qtyPrices) {
                if (qtyPrices is Map) {
                  qtyPrices.forEach((qtyIndex, supplementPrices) {
                    if (supplementPrices is Map) {
                      supplementPrices.forEach((supplementName, price) {
                        packSupplementsPrice += (price as num).toDouble();
                      });
                    }
                  });
                }
              });
            }

            // ✅ FIX: Total = (basePrice + globalSupplements) * quantity + packSupplements
            totalPrice = (basePrice + globalSupplementsPrice) * quantity +
                packSupplementsPrice;
          }

          savedOrdersList.add({
            'variantId': variantId,
            'displayName': params.menuItem.name,
            'quantity': quantity,
            'totalPrice': totalPrice,
            'orderIndex': orderIndex,
          });
        } else {
          final pricing = MenuItemPricing.fromJson(
              savedOrder['pricing'] as Map<String, dynamic>);
          final supplements = (savedOrder['supplements'] as List?)
                  ?.map((s) =>
                      MenuItemSupplement.fromJson(s as Map<String, dynamic>))
                  .toList() ??
              [];
          final supplementsPrice =
              supplements.fold(0.0, (sum, s) => sum + s.price);

          // Use RegularItemHelper for non-special packs
          final totalPrice = params.isSpecialPack
              ? () {
                  // ✅ FIX: For special packs, calculate with pack supplements
                  final basePrice = pricing.price;

                  // Only include global supplements (filter out pack supplements)
                  final globalSupplementsOnly = supplements.where((s) {
                    return !s.id.startsWith('pack_');
                  }).toList();
                  final globalSupplementsPrice = globalSupplementsOnly.fold(
                      0.0, (sum, s) => sum + s.price);

                  // Calculate pack supplements price from pack_supplement_prices
                  double packSupplementsPrice = 0.0;
                  final packSupplementPrices =
                      savedOrder['pack_supplement_prices']
                          as Map<String, dynamic>?;
                  if (packSupplementPrices != null) {
                    packSupplementPrices.forEach((variantName, qtyPrices) {
                      if (qtyPrices is Map) {
                        qtyPrices.forEach((qtyIndex, supplementPrices) {
                          if (supplementPrices is Map) {
                            supplementPrices.forEach((supplementName, price) {
                              packSupplementsPrice += (price as num).toDouble();
                            });
                          }
                        });
                      }
                    });
                  }

                  // Total = (basePrice + globalSupplements) * quantity + packSupplements
                  return (basePrice + globalSupplementsPrice) * quantity +
                      packSupplementsPrice;
                }()
              : RegularItemHelper.calculatePrice(
                  item: params.menuItem,
                  pricing: pricing,
                  supplementsPrice: supplementsPrice,
                  drinksPrice: 0.0, // Drinks handled separately
                  quantity: quantity,
                );

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

          savedOrdersList.add({
            'variantId': variantId,
            'displayName': variant.name,
            'quantity': quantity,
            'totalPrice': totalPrice,
            'orderIndex': orderIndex,
          });
        }
      }
    }
  }

  // Calculate total price using RegularItemHelper for non-special packs
  double currentOrderPrice = 0.0;

  if (params.savedOrders.isEmpty) {
    // ✅ FIX: Filter out pack supplements - only include global supplements
    // Pack supplements should NOT be multiplied by quantity (they're per-item, calculated once)
    // If pack supplements are in selectedSupplements, they'll be multiplied which is wrong
    final globalSupplementsOnly = params.selectedSupplements.where((s) {
      return !s.id.startsWith('pack_');
    }).toList();

    final supplementsPrice =
        globalSupplementsOnly.fold(0.0, (sum, s) => sum + s.price);
    double mainItemTotal = 0.0;

    if (params.selectedVariants.isNotEmpty) {
      if (params.isSpecialPack) {
        // Special pack: use pricing.price as base price
        double basePrice = params.menuItem.price;
        if (params.selectedPricingPerVariant.isNotEmpty) {
          final firstPricing = params.selectedPricingPerVariant.values.first;
          if (firstPricing.price > 0) {
            basePrice = firstPricing.price;
          }
        }
        if (basePrice <= 0) {
          basePrice = 200.0;
        }

        // ✅ FIX: Calculate pack supplements price (per-item supplements)
        // Pack supplements are per-pack-item, so they should be multiplied by quantity
        // Each pack (quantity) gets its own pack supplements
        double packSupplementsPricePerPack = 0.0;
        if (params.enhancedMenuItem != null &&
            params.packSupplementSelections.isNotEmpty) {
          for (final variantId in params.selectedVariants) {
            final variant = params.enhancedMenuItem!.variants.firstWhere(
                (v) => v.id == variantId,
                orElse: () => params.enhancedMenuItem!.variants.first);
            final variantSupplements =
                params.packSupplementSelections[variantId];
            if (variantSupplements != null && variantSupplements.isNotEmpty) {
              final supplementsFromDesc =
                  SpecialPackHelper.parseSupplements(variant.description);
              variantSupplements.forEach((qtyIndex, supplementSet) {
                for (final supplementName in supplementSet) {
                  final supplementPrice =
                      supplementsFromDesc[supplementName] ?? 0.0;
                  // Calculate price per pack (one pack's supplements)
                  packSupplementsPricePerPack += supplementPrice;
                }
              });
            }
          }
        }

        // ✅ FIX: Total = (basePrice + globalSupplements) * quantity + (packSupplements * quantity)
        // Global supplements are multiplied by quantity (they apply to each pack)
        // Pack supplements are also multiplied by quantity (each pack gets its own pack supplements)
        mainItemTotal = (basePrice + supplementsPrice) * params.quantity +
            (packSupplementsPricePerPack * params.quantity);
      } else {
        // ✅ FIX: Regular items and LTO regular: use RegularItemHelper
        // For regular items, only one variant is allowed, so no loop needed
        if (params.selectedVariants.isNotEmpty) {
          final variantId = params.selectedVariants.first; // Only process first (and only) variant
          final pricing = params.selectedPricingPerVariant[variantId];
          final variantQuantity =
              params.variantQuantities?[variantId] ?? params.quantity;

          mainItemTotal = RegularItemHelper.calculatePrice(
            item: params.menuItem,
            pricing: pricing,
            supplementsPrice: supplementsPrice,
            drinksPrice: 0.0, // Drinks added separately
            quantity: variantQuantity,
          );
        }
      }
    }

    final paidDrinksPrice =
        params.paidDrinkQuantities.entries.fold(0.0, (sum, entry) {
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
      return sum + (drink.price * entry.value);
    });

    currentOrderPrice = mainItemTotal + paidDrinksPrice;
  }

  // Calculate saved variant orders total
  double savedVariantOrdersPrice = 0.0;
  for (final variantEntry in params.savedVariantOrders.entries) {
    for (final savedOrder in variantEntry.value) {
      if (params.isSpecialPack &&
          variantEntry.key == 'pack' &&
          savedOrder.containsKey('total_price')) {
        savedVariantOrdersPrice +=
            (savedOrder['total_price'] as num).toDouble();
      } else {
        final pricing = MenuItemPricing.fromJson(
            savedOrder['pricing'] as Map<String, dynamic>);
        final quantity = savedOrder['quantity'] as int;
        final supplements = (savedOrder['supplements'] as List?)
                ?.map((s) =>
                    MenuItemSupplement.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [];
        final supplementsPrice =
            supplements.fold(0.0, (sum, s) => sum + s.price);

        // Use RegularItemHelper for non-special packs
        if (!params.isSpecialPack) {
          final variantPrice = RegularItemHelper.calculatePrice(
            item: params.menuItem,
            pricing: pricing,
            supplementsPrice: supplementsPrice,
            drinksPrice: 0.0, // Drinks handled separately
            quantity: quantity,
          );
          savedVariantOrdersPrice += variantPrice;
        } else {
          // Special pack: use pricing.price as base price
          final basePrice = pricing.price;
          savedVariantOrdersPrice += (basePrice + supplementsPrice) * quantity;
        }
      }
    }
  }

  final savedOrdersPrice =
      params.savedOrders.fold(0.0, (sum, order) => sum + order.totalPrice);

  final totalPrice =
      currentOrderPrice + savedVariantOrdersPrice + savedOrdersPrice;

  return SpecialPackAddToCartWidget(
    // Quantity selector
    quantity: params.quantity,
    onDecrease: params.quantity > 1 ? params.onQuantityDecrease : null,
    onIncrease: params.onQuantityIncrease,
    // Save & Add Another
    canSaveAndAddAnother: hasVariantSelections || hasPackItemSelections,
    onSaveAndAddAnother: params.saveAndAddAnotherOrder,
    // Saved orders
    savedOrdersList: savedOrdersList,
    onRemoveSavedOrder: params.removeSavedVariantOrder,
    // Free drinks (empty for special packs and LTO items - shown in selector/container instead)
    freeDrinks: freeDrinks,
    maxFreeDrinksQuantity: params.getFreeDrinksQuantity(),
    freeDrinkQuantities: params.drinkQuantities,
    onFreeDrinkQuantityChanged: params.onFreeDrinkQuantityChanged,
    buildDrinkImage: (drink) => buildDrinkImage(
      drink: drink,
      drinkImageCache: params.drinkImageCache,
      onCacheUpdate: (drinkId) {
        params.drinkImageCache.remove(drinkId);
      },
      supabase: Supabase.instance.client,
    ),
    onFreeDrinkSelected: params.onFreeDrinkSelected,
    onFreeDrinkDeselected: params.onFreeDrinkDeselected,
    // Paid drinks
    paidDrinksSection: params.paidDrinksSection,
    // Confirm/Add to Cart
    totalPrice: totalPrice,
    isEditing: params.existingCartItem != null,
    onAddToCart: params.addToCart,
    onConfirmOrder: params.existingCartItem != null
        ? params.submitOrder
        : params.navigateToConfirmFlow,
  );
}

/// Build scrollable add to cart section (free drinks, quantity, save button, paid drinks)
/// Excludes the confirm/add to cart button which is in the fixed bottom container
Widget buildScrollableAddToCartSection(BuildAddToCartSectionParams params) {
  if (params.enhancedMenuItem == null) {
    return const SizedBox.shrink();
  }

  // Check if we have selections to save
  final isLTORegular = params.menuItem.isLimitedOffer && !params.isSpecialPack;
  final hasVariantSelections = params.selectedVariants.isNotEmpty &&
      (isLTORegular || params.selectedPricingPerVariant.isNotEmpty);
  final hasPackItemSelections =
      PackStateHelper.hasPackSelections(params.packItemSelections);

  // Get free drinks (exclude for special packs and LTO items - they're shown in selector/container instead)
  final freeDrinkIds = (params.isSpecialPack || isLTORegular) ? <String>[] : params.getFreeDrinkIds();
  final freeDrinks = freeDrinkIds.isEmpty
      ? <MenuItem>[]
      : params.restaurantDrinks
          .where((drink) => freeDrinkIds.contains(drink.id))
          .toList();

  return SpecialPackScrollableAddToCartWidget(
    // Quantity selector
    quantity: params.quantity,
    onDecrease: params.quantity > 1 ? params.onQuantityDecrease : null,
    onIncrease: params.onQuantityIncrease,
    // Save & Add Another
    canSaveAndAddAnother: hasVariantSelections || hasPackItemSelections,
    onSaveAndAddAnother: params.saveAndAddAnotherOrder,
    // Free drinks (empty for special packs and LTO items - shown in selector/container instead)
    freeDrinks: freeDrinks,
    maxFreeDrinksQuantity: params.getFreeDrinksQuantity(),
    freeDrinkQuantities: params.drinkQuantities,
    onFreeDrinkQuantityChanged: params.onFreeDrinkQuantityChanged,
    buildDrinkImage: (drink) => buildDrinkImage(
      drink: drink,
      drinkImageCache: params.drinkImageCache,
      onCacheUpdate: (drinkId) {
        params.drinkImageCache.remove(drinkId);
      },
      supabase: Supabase.instance.client,
    ),
    onFreeDrinkSelected: params.onFreeDrinkSelected,
    onFreeDrinkDeselected: params.onFreeDrinkDeselected,
    // Paid drinks
    paidDrinksSection: params.paidDrinksSection,
    isEditing: params.existingCartItem != null,
  );
}

/// Build confirm/add to cart button only (for fixed bottom container)
Widget buildConfirmAddToCartButton(BuildAddToCartSectionParams params) {
  if (params.enhancedMenuItem == null) {
    return const SizedBox.shrink();
  }

  // Calculate total price
  double currentOrderPrice = 0.0;
  if (params.savedOrders.isEmpty) {
    final globalSupplementsOnly = params.selectedSupplements.where((s) {
      return !s.id.startsWith('pack_');
    }).toList();
    final supplementsPrice =
        globalSupplementsOnly.fold(0.0, (sum, s) => sum + s.price);
    double mainItemTotal = 0.0;

    if (params.selectedVariants.isNotEmpty) {
      if (params.isSpecialPack) {
        double basePrice = params.menuItem.price;
        if (params.selectedPricingPerVariant.isNotEmpty) {
          final firstPricing = params.selectedPricingPerVariant.values.first;
          if (firstPricing.price > 0) {
            basePrice = firstPricing.price;
          }
        }
        if (basePrice <= 0) {
          basePrice = 200.0;
        }

        double packSupplementsPricePerPack = 0.0;
        if (params.enhancedMenuItem != null &&
            params.packSupplementSelections.isNotEmpty) {
          for (final variantId in params.selectedVariants) {
            final variant = params.enhancedMenuItem!.variants.firstWhere(
                (v) => v.id == variantId,
                orElse: () => params.enhancedMenuItem!.variants.first);
            final variantSupplements =
                params.packSupplementSelections[variantId];
            if (variantSupplements != null && variantSupplements.isNotEmpty) {
              final supplementsFromDesc =
                  SpecialPackHelper.parseSupplements(variant.description);
              variantSupplements.forEach((qtyIndex, supplementSet) {
                for (final supplementName in supplementSet) {
                  final supplementPrice =
                      supplementsFromDesc[supplementName] ?? 0.0;
                  packSupplementsPricePerPack += supplementPrice;
                }
              });
            }
          }
        }

        mainItemTotal = (basePrice + supplementsPrice) * params.quantity +
            (packSupplementsPricePerPack * params.quantity);
      } else {
        if (params.selectedVariants.isNotEmpty) {
          final variantId = params.selectedVariants.first;
          final pricing = params.selectedPricingPerVariant[variantId];
          final variantQuantity =
              params.variantQuantities?[variantId] ?? params.quantity;

          mainItemTotal = RegularItemHelper.calculatePrice(
            item: params.menuItem,
            pricing: pricing,
            supplementsPrice: supplementsPrice,
            drinksPrice: 0.0,
            quantity: variantQuantity,
          );
        }
      }
    }

    final paidDrinksPrice =
        params.paidDrinkQuantities.entries.fold(0.0, (sum, entry) {
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
      return sum + (drink.price * entry.value);
    });

    currentOrderPrice = mainItemTotal + paidDrinksPrice;
  }

  double savedVariantOrdersPrice = 0.0;
  if (params.hasSavedVariantOrders()) {
    for (final variantEntry in params.savedVariantOrders.entries) {
      final variantId = variantEntry.key;
      final savedOrders = variantEntry.value;

      for (final savedOrder in savedOrders) {
        final quantity = savedOrder['quantity'] as int;
        final supplements = (savedOrder['supplements'] as List?)
                ?.map((s) =>
                    MenuItemSupplement.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [];
        final supplementsPrice =
            supplements.fold(0.0, (sum, s) => sum + s.price);

        if (params.isSpecialPack && variantId == 'pack') {
          double totalPrice;
          if (savedOrder.containsKey('total_price')) {
            totalPrice = (savedOrder['total_price'] as num).toDouble();
          } else {
            final pricing = MenuItemPricing.fromJson(
                savedOrder['pricing'] as Map<String, dynamic>);
            final basePrice = pricing.price;
            final globalSupplementsOnly = supplements.where((s) {
              return !s.id.startsWith('pack_');
            }).toList();
            final globalSupplementsPrice =
                globalSupplementsOnly.fold(0.0, (sum, s) => sum + s.price);

            double packSupplementsPrice = 0.0;
            final packSupplementPrices =
                savedOrder['pack_supplement_prices'] as Map<String, dynamic>?;
            if (packSupplementPrices != null) {
              packSupplementPrices.forEach((variantName, qtyPrices) {
                if (qtyPrices is Map) {
                  qtyPrices.forEach((qtyIndex, supplementPrices) {
                    if (supplementPrices is Map) {
                      supplementPrices.forEach((supplementName, price) {
                        packSupplementsPrice += (price as num).toDouble();
                      });
                    }
                  });
                }
              });
            }

            totalPrice = (basePrice + globalSupplementsPrice) * quantity +
                packSupplementsPrice;
          }
          savedVariantOrdersPrice += totalPrice;
        } else {
          final pricing = MenuItemPricing.fromJson(
              savedOrder['pricing'] as Map<String, dynamic>);
          if (!params.isSpecialPack) {
            final variantPrice = RegularItemHelper.calculatePrice(
              item: params.menuItem,
              pricing: pricing,
              supplementsPrice: supplementsPrice,
              drinksPrice: 0.0,
              quantity: quantity,
            );
            savedVariantOrdersPrice += variantPrice;
          } else {
            final basePrice = pricing.price;
            savedVariantOrdersPrice += (basePrice + supplementsPrice) * quantity;
          }
        }
      }
    }
  }

  final savedOrdersPrice =
      params.savedOrders.fold(0.0, (sum, order) => sum + order.totalPrice);

  final totalPrice =
      currentOrderPrice + savedVariantOrdersPrice + savedOrdersPrice;

  return SpecialPackConfirmAddToCartButton(
    totalPrice: totalPrice,
    isEditing: params.existingCartItem != null,
    onAddToCart: params.addToCart,
    onConfirmOrder: params.existingCartItem != null
        ? params.submitOrder
        : params.navigateToConfirmFlow,
    quantity: params.quantity,
    onDecrease: params.quantity > 1 ? params.onQuantityDecrease : null,
    onIncrease: params.onQuantityIncrease,
  );
}

/// Helper function to make values JSON-encodable
dynamic _makeJsonEncodable(dynamic value) {
  if (value == null) return null;

  if (value is String || value is num || value is bool) {
    return value;
  }

  if (value is Map) {
    final result = <String, dynamic>{};
    value.forEach((key, val) {
      try {
        final stringKey = key.toString();
        result[stringKey] = _makeJsonEncodable(val);
      } catch (e) {
        // Skip entries that can't be converted
      }
    });
    return result;
  }

  if (value is List) {
    return value.map((item) => _makeJsonEncodable(item)).toList();
  }

  // For any other type, convert to string
  return value.toString();
}
