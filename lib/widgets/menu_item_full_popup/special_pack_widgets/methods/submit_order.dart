import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../../cart_provider.dart';
import '../../../../models/enhanced_menu_item.dart';
import '../../../../models/ingredient_preference.dart';
import '../../../../models/menu_item.dart';
import '../../../../models/menu_item_customizations.dart';
import '../../../../models/menu_item_pricing.dart';
import '../../../../models/menu_item_supplement.dart';
import '../../../../models/order_item.dart';
import '../../../../models/restaurant.dart';
import '../../helpers/pack_customizations_builder.dart';
import '../../helpers/regular_item_helper.dart';
import '../../helpers/special_pack_helper.dart';

/// Parameters for submit order operations
class SubmitOrderParams {
  final BuildContext context;
  final CartItem? existingCartItem;
  final String? originalOrderItemId;
  final Function(OrderItem)? onItemAddedToCart;
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
  final String popupSessionId;
  final String? Function() buildSpecialInstructions;
  final List<Map<String, dynamic>> Function() buildDrinksWithSizes;
  final Map<String, dynamic> Function(
          Map<String, Map<int, Map<String, IngredientPreference>>>)
      convertIngredientPreferencesToJson;
  final List<String> Function(String?) parsePackItemOptions;
  final Function(bool) setLoadingState;
  final bool Function() isMounted;

  SubmitOrderParams({
    required this.context,
    required this.existingCartItem,
    required this.originalOrderItemId,
    required this.onItemAddedToCart,
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
    required this.popupSessionId,
    required this.buildSpecialInstructions,
    required this.buildDrinksWithSizes,
    required this.convertIngredientPreferencesToJson,
    required this.parsePackItemOptions,
    required this.setLoadingState,
    required this.isMounted,
  });
}

/// Submit order - handles both editing existing items and adding new items to cart
Future<void> submitOrder(SubmitOrderParams params) async {
  debugPrint('🛒 submitOrder: Starting submit order process');
  debugPrint(
      '🛒 submitOrder: existingCartItem: ${params.existingCartItem?.name}');
  debugPrint(
      '🛒 submitOrder: onItemAddedToCart callback: ${params.onItemAddedToCart != null}');
  debugPrint(
      '🛒 submitOrder: _selectedPricingPerVariant: ${params.selectedPricingPerVariant.keys.toList()}');
  debugPrint('🛒 submitOrder: quantity: ${params.quantity}');

  params.setLoadingState(true);
  final scaffoldMessenger = ScaffoldMessenger.of(params.context);

  try {
    // Use only saved orders if they exist, otherwise use current form
    final allOrders = List<OrderItem>.from(params.savedOrders);
    debugPrint(
        '🛒 submitOrder: savedOrders.isEmpty: ${params.savedOrders.isEmpty}');
    debugPrint('🛒 submitOrder: allOrders.length before: ${allOrders.length}');

    if (params.savedOrders.isEmpty) {
      // Handle multiple variant selections
      if (params.selectedVariants.isEmpty) {
        // No variants selected, create single order
        final int quantityToUse = params.quantity;
        final pricing = params.selectedPricingPerVariant.isNotEmpty
            ? params.selectedPricingPerVariant.values.first
            : null;

        // ✅ FIX: Use RegularItemHelper for regular items to correctly calculate price
        final supplementsPrice = params.selectedSupplements
            .fold(0.0, (sum, s) => sum + s.price);

        // Only charge for PAID drinks, not free drinks
        final drinksTotal =
            params.paidDrinkQuantities.entries.fold(0.0, (sum, entry) {
          if (entry.key.isNotEmpty) {
            final drink =
                params.restaurantDrinks.firstWhere((d) => d.id == entry.key);
            return sum + (drink.price * entry.value);
          }
          return sum;
        });

        final drinksWithSizesForSubmit = params.buildDrinksWithSizes();

        double mainItemTotal;
        double unitPrice;

        if (params.isSpecialPack) {
          // Special pack: pricing.price is the base price
          double basePrice = pricing?.price ?? params.menuItem.price;
          if (basePrice <= 0) {
            basePrice = 350.0;
          }
          mainItemTotal = (basePrice + supplementsPrice) * quantityToUse;
          unitPrice = basePrice + supplementsPrice;
        } else {
          // Regular item: use RegularItemHelper
          mainItemTotal = RegularItemHelper.calculatePrice(
            item: params.menuItem,
            pricing: pricing,
            supplementsPrice: supplementsPrice,
            drinksPrice: 0.0, // Drinks handled separately
            quantity: quantityToUse,
          );
          unitPrice = RegularItemHelper.calculateUnitPrice(
            item: params.menuItem,
            pricing: pricing,
            supplementsPrice: supplementsPrice,
            drinksPrice: 0.0, // Drinks handled separately
          );
        }

        debugPrint('🔄 submitOrder: Creating OrderItem (no variant)');
        debugPrint('  unitPrice: $unitPrice');
        debugPrint('  quantityToUse: $quantityToUse');

        final currentOrder = OrderItem(
          id: params.originalOrderItemId ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          orderId: '',
          menuItemId: params.menuItem.id,
          quantity: quantityToUse,
          unitPrice: unitPrice,
          totalPrice: mainItemTotal + drinksTotal,
          specialInstructions: params.buildSpecialInstructions(),
          customizations: MenuItemCustomizations.fromMap({
            'menu_item_id': params.menuItem.id,
            'restaurant_id': (params.menuItem.restaurantId.isNotEmpty
                    ? params.menuItem.restaurantId
                    : (params.restaurant?.id.toString() ?? ''))
                .trim(),
            'variant': null,
            'size': null,
            'portion': null,
            'supplements':
                params.selectedSupplements.map((s) => s.toJson()).toList(),
            'removed_ingredients': params.removedIngredients,
            'ingredient_preferences': params.ingredientPreferences.map(
                (key, value) =>
                    MapEntry(key, value.toString().split('.').last)),
            'drinks': drinksWithSizesForSubmit,
            'drink_quantities': {
              ...params.drinkQuantities,
              ...params.paidDrinkQuantities,
            },
          }),
          createdAt: DateTime.now(),
          menuItem: params.menuItem,
        );
        allOrders.add(currentOrder);
        debugPrint('🛒 submitOrder: Added current order to allOrders');
        debugPrint(
            '🛒 submitOrder: allOrders.length after: ${allOrders.length}');
      } else {
        // ✅ FIX: For regular items, only handle single variant (multi-variant only for special packs)
        // For special packs: Add each selected variant as a separate order
        // For regular items: Only process the single selected variant
        final variants = params.enhancedMenuItem?.variants ?? [];

        // Calculate paid drinks total ONCE (shared across all variants for special packs, or single variant for regular items)
        final drinksTotal =
            params.paidDrinkQuantities.entries.fold(0.0, (sum, entry) {
          if (entry.key.isNotEmpty) {
            final drink =
                params.restaurantDrinks.firstWhere((d) => d.id == entry.key);
            return sum + (drink.price * entry.value);
          }
          return sum;
        });

        // Build drinks payload ONCE (shared across all variants for special packs, or single variant for regular items)
        final drinksWithSizesForSubmit = params.buildDrinksWithSizes();

        // ✅ FIX: For regular items, only one variant is allowed, so no multi-variant logic needed
        // Determine if multiple variants are selected (only relevant for special packs)
        final isMultipleVariants = params.isSpecialPack && params.selectedVariants.length > 1;
        final firstVariantId = params.selectedVariants.isNotEmpty
            ? params.selectedVariants.first
            : null;

        // ✅ FIX: For regular items, only process the first (and only) selected variant
        final List<String> variantsToProcess = params.isSpecialPack
            ? params.selectedVariants.toList()
            : (params.selectedVariants.isNotEmpty ? [params.selectedVariants.first] : <String>[]);

        for (final variantId in variantsToProcess) {
          final variant = variants.firstWhere((v) => v.id == variantId,
              orElse: () => variants.first);
          final int quantityToUse = params.variantQuantities[variantId] ?? 1;
          final pricing = params.selectedPricingPerVariant[variantId];

          // ✅ FIX: Use RegularItemHelper for regular items to correctly calculate price
          // For regular items: base = item.price, size extra = pricing.price
          // For special packs: base = pricing.price
          final supplementsPrice = params.selectedSupplements
              .fold(0.0, (sum, s) => sum + s.price);

          // ✅ FIX: For regular items, always include drinks (only one variant)
          // For special packs, only add drinks price to the FIRST variant when multiple variants are selected
          final drinksPriceForThisVariant = params.isSpecialPack && isMultipleVariants && variantId != firstVariantId
              ? 0.0
              : drinksTotal;

          double mainItemTotal;
          double unitPrice;

          if (params.isSpecialPack) {
            // Special pack: pricing.price is the base price
            double basePrice = pricing?.price ?? params.menuItem.price;
            if (basePrice <= 0) {
              basePrice = 350.0;
            }
            mainItemTotal = (basePrice + supplementsPrice) * quantityToUse;
            unitPrice = basePrice + supplementsPrice;
          } else {
            // Regular item: use RegularItemHelper
            mainItemTotal = RegularItemHelper.calculatePrice(
              item: params.menuItem,
              pricing: pricing,
              supplementsPrice: supplementsPrice,
              drinksPrice: 0.0, // Drinks handled separately
              quantity: quantityToUse,
            );
            unitPrice = RegularItemHelper.calculateUnitPrice(
              item: params.menuItem,
              pricing: pricing,
              supplementsPrice: supplementsPrice,
              drinksPrice: 0.0, // Drinks handled separately
            );
          }

          debugPrint(
              '🔄 submitOrder: Creating OrderItem for variant ${variant.name}');
          debugPrint('  unitPrice: $unitPrice');
          debugPrint('  quantityToUse: $quantityToUse');
          debugPrint('  drinksPriceForThisVariant: $drinksPriceForThisVariant');

          // Build pack customizations if needed
          Map<String, dynamic>? packSelectionsWithNames;
          Map<String, dynamic>? packIngredientPrefsJson;
          if (params.isSpecialPack) {
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
            packSelectionsWithNames =
                packCustomizations.packSelectionsWithNames;
            packIngredientPrefsJson =
                packCustomizations.packIngredientPrefsJson;
          }

          final currentOrder = OrderItem(
            id: '${params.originalOrderItemId ?? DateTime.now().millisecondsSinceEpoch.toString()}_$variantId',
            orderId: '',
            menuItemId: params.menuItem.id,
            quantity: quantityToUse,
            unitPrice: unitPrice,
            totalPrice: mainItemTotal + drinksPriceForThisVariant,
            specialInstructions: params.buildSpecialInstructions(),
            customizations: MenuItemCustomizations.fromMap({
              'menu_item_id': params.menuItem.id,
              'restaurant_id': (params.menuItem.restaurantId.isNotEmpty
                      ? params.menuItem.restaurantId
                      : (params.restaurant?.id.toString() ?? ''))
                  .trim(),
              'variant': variant.toJson(),
              'size': pricing?.size,
              'portion': pricing?.portion,
              'supplements':
                  params.selectedSupplements.map((s) => s.toJson()).toList(),
              'removed_ingredients': params.removedIngredients,
              'ingredient_preferences': params.ingredientPreferences.map(
                  (key, value) =>
                      MapEntry(key, value.toString().split('.').last)),
              // ✅ FIX: For regular items, always include drinks (only one variant)
              // For special packs, only include drinks in the FIRST variant when multiple variants are selected
              'drinks': (params.isSpecialPack && isMultipleVariants && variantId != firstVariantId)
                  ? <Map<String, dynamic>>[]
                  : drinksWithSizesForSubmit,
              'drink_quantities':
                  (params.isSpecialPack && isMultipleVariants && variantId != firstVariantId)
                      ? <String, int>{}
                      : {
                          ...params.drinkQuantities,
                          ...params.paidDrinkQuantities,
                        },
              if (packSelectionsWithNames != null &&
                  packSelectionsWithNames.isNotEmpty)
                'pack_selections': packSelectionsWithNames,
              if (packIngredientPrefsJson != null &&
                  packIngredientPrefsJson.isNotEmpty)
                'pack_ingredient_preferences': packIngredientPrefsJson,
            }),
            createdAt: DateTime.now(),
            menuItem: params.menuItem,
          );
          allOrders.add(currentOrder);
          debugPrint(
              '🛒 submitOrder: Added variant order for ${variant.name} (unitPrice: $unitPrice, quantity: $quantityToUse, drinksPrice: $drinksPriceForThisVariant)');
        }
        debugPrint(
            '🛒 submitOrder: allOrders.length after adding variants: ${allOrders.length}');
      }
    }

    // Handle editing vs new order
    if (params.existingCartItem != null) {
      // Editing existing item - call callback with updated order
      debugPrint('🛒 submitOrder: Editing existing cart item');
      debugPrint('🛒 submitOrder: mounted: ${params.isMounted()}');
      debugPrint(
          '🛒 submitOrder: onItemAddedToCart != null: ${params.onItemAddedToCart != null}');
      debugPrint(
          '🛒 submitOrder: allOrders.isNotEmpty: ${allOrders.isNotEmpty}');
      debugPrint('🛒 submitOrder: allOrders.length: ${allOrders.length}');

      if (params.isMounted() &&
          params.onItemAddedToCart != null &&
          allOrders.isNotEmpty) {
        // ✅ FIX: For special packs, create ONE unified order item instead of separate variant orders
        // This ensures all pack data (selections, ingredient preferences, supplements) is preserved
        OrderItem orderToReturn;

        if (params.isSpecialPack) {
          // Create unified order for special pack
          debugPrint('🛒 submitOrder: Creating unified order for special pack');

          // ✅ FIX: Calculate unified pricing - prioritize pricing over menuItem.price
          // For special packs, use the pricing price (which is the pack price)
          // Don't use menuItem.price as it might be the CartItem price when editing
          double basePrice = 0.0;
          if (params.selectedPricingPerVariant.isNotEmpty) {
            final firstPricing = params.selectedPricingPerVariant.values.first;
            basePrice = firstPricing.price;
          }
          if (basePrice <= 0) {
            basePrice = params.menuItem.price;
          }
          if (basePrice <= 0) {
            basePrice = 350.0;
          }

          // ✅ FIX: Calculate supplements price - only include global supplements in unit price
          // Pack-specific supplements are stored separately and their prices are included in pack_supplement_prices
          // For special packs, unit price = base price + global supplements only
          // This matches the logic in add_to_cart.dart (line 245-250)

          // ✅ FIX: Filter out pack-specific supplements from selectedSupplements
          // Only count global supplements (those with IDs starting with "global_" or not starting with "pack_")
          final globalSupplementsOnly = params.selectedSupplements.where((s) {
            // Global supplements have IDs like "global_chesse" or are not pack-specific
            return !s.id.startsWith('pack_');
          }).toList();

          final globalSupplementsPrice =
              globalSupplementsOnly.fold(0.0, (sum, s) => sum + s.price);

          // Calculate pack-specific supplements price (these are added to total, not unit price)
          double packSupplementsPrice = 0.0;
          if (params.enhancedMenuItem != null &&
              params.packSupplementSelections.isNotEmpty) {
            debugPrint('💰 Calculating pack supplements price:');
            debugPrint(
                '   packSupplementSelections keys: ${params.packSupplementSelections.keys.join(', ')}');
            debugPrint(
                '   selectedVariants: ${params.selectedVariants.join(', ')}');

            for (final variantId in params.selectedVariants) {
              final variant = params.enhancedMenuItem!.variants.firstWhere(
                  (v) => v.id == variantId,
                  orElse: () => params.enhancedMenuItem!.variants.first);
              final variantSupplements =
                  params.packSupplementSelections[variantId];

              debugPrint('   Checking variant $variantId (${variant.name}):');
              debugPrint('     variantSupplements: $variantSupplements');

              if (variantSupplements != null && variantSupplements.isNotEmpty) {
                final supplementsFromDesc =
                    SpecialPackHelper.parseSupplements(variant.description);

                debugPrint('     supplementsFromDesc: $supplementsFromDesc');

                variantSupplements.forEach((qtyIndex, supplementSet) {
                  debugPrint(
                      '     qtyIndex $qtyIndex: supplements $supplementSet');
                  for (final supplementName in supplementSet) {
                    final supplementPrice =
                        supplementsFromDesc[supplementName] ?? 0.0;
                    packSupplementsPrice += supplementPrice;
                    debugPrint(
                        '       Added $supplementName: $supplementPrice (total: $packSupplementsPrice)');
                  }
                });
              } else {
                debugPrint('     No supplements found for variant $variantId');
              }
            }
          }

          final perUnitPrice = basePrice + globalSupplementsPrice;

          // Calculate total paid drinks price (global, only once)
          final drinksTotal =
              params.paidDrinkQuantities.entries.fold(0.0, (sum, entry) {
            if (entry.key.isNotEmpty) {
              final drink = params.restaurantDrinks.firstWhere(
                  (d) => d.id == entry.key,
                  orElse: () => params.restaurantDrinks.first);
              return sum + (drink.price * entry.value);
            }
            return sum;
          });

          debugPrint('💰 Price calculation:');
          debugPrint('   basePrice: $basePrice');
          debugPrint(
              '   globalSupplementsPrice: $globalSupplementsPrice (${globalSupplementsOnly.length} supplements: ${globalSupplementsOnly.map((s) => s.name).join(', ')})');
          debugPrint('   packSupplementsPrice: $packSupplementsPrice');
          debugPrint('   drinksTotal: $drinksTotal');
          debugPrint('   perUnitPrice: $perUnitPrice');
          debugPrint('   quantity: ${params.quantity}');
          debugPrint(
              '   calculated totalPrice: ${(perUnitPrice * params.quantity) + packSupplementsPrice + drinksTotal}');

          final drinksWithSizesForSubmit = params.buildDrinksWithSizes();

          // Build pack customizations
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

          final packSelectionsWithNames =
              packCustomizations.packSelectionsWithNames;
          final packIngredientPrefsJson =
              packCustomizations.packIngredientPrefsJson;
          final packSupplementSelectionsJson =
              packCustomizations.packSupplementSelectionsJson;
          final packSupplementPricesJson =
              packCustomizations.packSupplementPricesJson;

          // ✅ FIX: Build complete supplements list (global + pack-specific)
          final allSupplements = <MenuItemSupplement>[];

          // Add global supplements
          allSupplements.addAll(params.selectedSupplements);

          // Add pack-specific supplements from packSupplementSelections
          if (params.enhancedMenuItem != null &&
              params.packSupplementSelections.isNotEmpty) {
            for (final variant in params.enhancedMenuItem!.variants) {
              final variantSupplements =
                  params.packSupplementSelections[variant.id];
              if (variantSupplements != null && variantSupplements.isNotEmpty) {
                // Get supplement prices from variant description
                final supplementsFromDesc =
                    SpecialPackHelper.parseSupplements(variant.description);

                // Collect all selected supplements for this variant (across all quantity indices)
                final selectedSupplementNames = <String>{};
                variantSupplements.forEach((qtyIndex, supplementSet) {
                  selectedSupplementNames.addAll(supplementSet);
                });

                // Create MenuItemSupplement objects for each selected supplement
                for (final supplementName in selectedSupplementNames) {
                  final supplementPrice =
                      supplementsFromDesc[supplementName] ?? 0.0;
                  // Create supplement with pack-specific ID format
                  final supplementId = 'pack_${variant.id}_$supplementName';
                  final supplement = MenuItemSupplement(
                    id: supplementId,
                    menuItemId: params.menuItem.id,
                    name: supplementName,
                    description: null,
                    price: supplementPrice,
                    isAvailable: true,
                    displayOrder: 0,
                    createdAt: DateTime.now(),
                    updatedAt: DateTime.now(),
                  );
                  allSupplements.add(supplement);
                }
              }
            }
          }

          // Create unified order with all pack data
          orderToReturn = OrderItem(
            id: params.originalOrderItemId ??
                DateTime.now().millisecondsSinceEpoch.toString(),
            orderId: '',
            menuItemId: params.menuItem.id,
            quantity: params.quantity,
            unitPrice: perUnitPrice,
            // ✅ FIX: Total price = (unit price * quantity) + pack supplements + drinks
            // Pack supplements are not included in unit price, but must be added to total
            totalPrice: (perUnitPrice * params.quantity) +
                packSupplementsPrice +
                drinksTotal,
            specialInstructions: params.buildSpecialInstructions(),
            customizations: MenuItemCustomizations.fromMap({
              'menu_item_id': params.menuItem.id,
              'restaurant_id': (params.menuItem.restaurantId.isNotEmpty
                      ? params.menuItem.restaurantId
                      : (params.restaurant?.id.toString() ?? ''))
                  .trim(),
              'main_item_quantity': params.quantity,
              'variant': null, // No single variant for special packs
              'size': null,
              'portion': null,
              'supplements': allSupplements.map((s) => s.toJson()).toList(),
              'drinks': drinksWithSizesForSubmit,
              'drink_quantities': {
                ...params.drinkQuantities,
                ...params.paidDrinkQuantities,
              },
              'free_drink_quantities':
                  Map<String, int>.from(params.drinkQuantities),
              'paid_drink_quantities':
                  Map<String, int>.from(params.paidDrinkQuantities),
              'removed_ingredients': params.removedIngredients,
              'ingredient_preferences': params.ingredientPreferences.map(
                (key, value) => MapEntry(key, value.toString().split('.').last),
              ),
              if (packSelectionsWithNames.isNotEmpty)
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
              'popup_session_id': params.popupSessionId,
            }),
            createdAt: DateTime.now(),
            menuItem: params.menuItem,
          );

          debugPrint('🛒 submitOrder: Created unified order for special pack');
          debugPrint('  quantity: ${orderToReturn.quantity}');
          debugPrint('  unitPrice: ${orderToReturn.unitPrice}');
          debugPrint('  totalPrice: ${orderToReturn.totalPrice}');
        } else {
          // For regular items or single variant, use first order
          orderToReturn = allOrders.first;
        }

        debugPrint('🛒 submitOrder: Calling onItemAddedToCart callback');
        debugPrint('  order - quantity: ${orderToReturn.quantity}');
        debugPrint('  order - unitPrice: ${orderToReturn.unitPrice}');
        debugPrint('  order - totalPrice: ${orderToReturn.totalPrice}');

        try {
          params.onItemAddedToCart!(orderToReturn);
          debugPrint('🛒 submitOrder: Callback executed successfully');
        } catch (e) {
          debugPrint('🛒 submitOrder: Error in callback: $e');
        }
      } else {
        debugPrint('🛒 submitOrder: Cannot call callback - conditions not met');
      }
    } else {
      // New order - add items to cart
      if (params.isMounted() && allOrders.isNotEmpty) {
        final cartProvider =
            Provider.of<CartProvider>(params.context, listen: false);

        // Add all orders to cart
        for (final orderItem in allOrders) {
          final safeUnitPrice = orderItem.unitPrice > 0
              ? orderItem.unitPrice
              : ((orderItem.menuItem?.price ?? 0) > 0
                  ? (orderItem.menuItem?.price ?? 0)
                  : 350.0);

          final cartItem = CartItem(
            id: orderItem.id,
            name: orderItem.menuItem?.name ?? 'Unknown Item',
            price: safeUnitPrice,
            quantity: orderItem.quantity,
            image: orderItem.menuItem?.image,
            restaurantName: orderItem.menuItem?.restaurantName,
            customizations: orderItem.customizations?.toMap(),
            specialInstructions: orderItem.specialInstructions,
          );

          cartProvider.addToCart(cartItem);
        }

        // Show success message
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              '${allOrders.length} item${allOrders.length > 1 ? 's' : ''} added to cart',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green[600],
          ),
        );

        // Close popup
        Navigator.of(params.context).pop();
      }
    }
  } catch (e) {
    if (params.isMounted()) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text(
            'Failed to proceed to order summary: $e',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (params.isMounted()) {
      params.setLoadingState(false);
    }
  }
}
