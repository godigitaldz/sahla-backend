import 'package:flutter/foundation.dart';

import '../../../../cart_provider.dart';
import '../../../../models/enhanced_menu_item.dart';
import '../../../../models/ingredient_preference.dart';
import '../../../../models/menu_item.dart';
import '../../../../models/menu_item_pricing.dart';
import '../../../../models/menu_item_supplement.dart';
import '../../helpers/regular_item_helper.dart';
import '../../helpers/special_pack_helper.dart';
import 'edit_order_manager.dart';

/// 🔗 **Edit Order Integration Layer**
///
/// Bridges the new EditOrderStateManager with existing popup widget architecture.
/// Provides backward compatibility and smooth migration path.
///
/// **Responsibilities:**
/// - Initialize EditOrderStateManager from CartItem
/// - Sync manager state with popup widget state variables
/// - Handle bidirectional updates between manager and widget
/// - Maintain backward compatibility with existing code
///
/// **Author:** Senior Flutter Engineer
/// **Date:** 2025-11-07

/// 🏗️ **Edit Order Bridge**
///
/// Provides helper methods to integrate EditOrderStateManager with MenuItemPopupWidget
class EditOrderBridge {
  /// Convert pack ingredient preferences from popup state to manager format
  /// Handles type conversion from dynamic maps to properly typed maps
  static Map<int, Map<String, IngredientPreference>>
      _convertPackIngredientPreferences(
    dynamic prefsRaw,
  ) {
    if (prefsRaw == null) return {};

    final converted = <int, Map<String, IngredientPreference>>{};

    // Handle Map<dynamic, dynamic> or Map<int, Map<String, IngredientPreference>>
    if (prefsRaw is Map) {
      prefsRaw.forEach((qtyIndexKey, ingredientMapRaw) {
        final qtyIndex = qtyIndexKey is int
            ? qtyIndexKey
            : int.tryParse(qtyIndexKey.toString()) ?? 0;

        if (ingredientMapRaw is Map) {
          final convertedMap = <String, IngredientPreference>{};

          ingredientMapRaw.forEach((ingredient, pref) {
            // Convert ingredient to string
            final ingredientStr = ingredient.toString();

            // Handle IngredientPreference enum or string representation
            IngredientPreference prefEnum;
            if (pref is IngredientPreference) {
              prefEnum = pref;
            } else if (pref is String) {
              prefEnum = _parseIngredientPreference(pref);
            } else {
              // Try to convert to string first
              final prefStr = pref.toString();
              prefEnum = _parseIngredientPreference(prefStr);
            }

            convertedMap[ingredientStr] = prefEnum;
          });

          if (convertedMap.isNotEmpty) {
            converted[qtyIndex] = convertedMap;
          }
        }
      });
    }

    return converted;
  }

  /// Convert pack supplement selections from popup state to manager format
  /// Handles type conversion from dynamic maps to properly typed maps
  static Map<int, Set<String>> _convertPackSupplementSelections(
    dynamic suppsRaw,
  ) {
    if (suppsRaw == null) return {};

    final converted = <int, Set<String>>{};

    // Handle Map<dynamic, dynamic> or Map<int, Set<String>>
    if (suppsRaw is Map) {
      suppsRaw.forEach((qtyIndexKey, supplementSetRaw) {
        final qtyIndex = qtyIndexKey is int
            ? qtyIndexKey
            : int.tryParse(qtyIndexKey.toString()) ?? 0;

        if (supplementSetRaw is Set) {
          converted[qtyIndex] =
              supplementSetRaw.map((e) => e.toString()).toSet();
        } else if (supplementSetRaw is List) {
          converted[qtyIndex] =
              supplementSetRaw.map((e) => e.toString()).toSet();
        } else if (supplementSetRaw is Iterable) {
          converted[qtyIndex] =
              supplementSetRaw.map((e) => e.toString()).toSet();
        }
      });
    }

    return converted;
  }

  /// Parse ingredient preference from string
  static IngredientPreference _parseIngredientPreference(String prefString) {
    final prefLower = prefString.toLowerCase().trim();
    switch (prefLower) {
      case 'wanted':
        return IngredientPreference.wanted;
      case 'less':
        return IngredientPreference.less;
      case 'none':
      case 'unwanted':
        return IngredientPreference.none;
      default:
        return IngredientPreference.neutral;
    }
  }

  /// Initialize EditOrderStateManager and sync with popup widget state
  ///
  /// **Parameters:**
  /// - `cartItem`: The cart item being edited
  /// - `enhancedMenuItem`: Enhanced menu item data
  /// - `restaurantDrinks`: Available restaurant drinks
  /// - `sessionId`: Popup session ID
  /// - `popupState`: Current popup widget state variables
  /// - `allCartItems`: Optional: All cart items to find global paid drinks
  ///
  /// **Returns:**
  /// - EditOrderStateManager with pre-populated state
  static EditOrderStateManager initializeFromCartItem({
    required CartItem cartItem,
    required EnhancedMenuItem? enhancedMenuItem,
    required List<MenuItem> restaurantDrinks,
    required String sessionId,
    required PopupStateVariables popupState,
    List<CartItem>?
        allCartItems, // Optional: All cart items to find global paid drinks
  }) {
    debugPrint('🔗 EditOrderBridge: Initializing from cart item');

    // Create manager and sync from cart item
    final manager = EditOrderSynchronizer.syncFromCartItem(
      cartItem: cartItem,
      enhancedMenuItem: enhancedMenuItem,
      restaurantDrinks: restaurantDrinks,
      sessionId: sessionId,
      allCartItems:
          allCartItems, // Pass all cart items to find global paid drinks
    );

    // Sync manager state to popup widget state
    syncManagerToPopupState(manager, popupState);

    debugPrint('✅ EditOrderBridge: Initialization complete');
    return manager;
  }

  /// Sync EditOrderStateManager state to popup widget state variables
  ///
  /// This allows the existing popup UI to continue working with its current
  /// state variables while being backed by the new manager.
  static void syncManagerToPopupState(
    EditOrderStateManager manager,
    PopupStateVariables popupState,
  ) {
    debugPrint('🔗 EditOrderBridge: Syncing manager → popup state');

    // Sync drinks
    popupState.drinkQuantities.clear();
    popupState.drinkQuantities.addAll(manager.globalFreeDrinkQuantities);

    popupState.paidDrinkQuantities.clear();
    popupState.paidDrinkQuantities.addAll(manager.globalPaidDrinkQuantities);

    popupState.drinkSizesById.clear();
    popupState.drinkSizesById.addAll(manager.drinkSizesById);

    popupState.selectedDrinks.clear();
    popupState.selectedDrinks.addAll(manager.selectedDrinks);

    // ✅ FIX: Debug logging for drink sync
    debugPrint(
        '🔗 EditOrderBridge: Synced drinks - free: ${popupState.drinkQuantities.length}, paid: ${popupState.paidDrinkQuantities.length}, selected: ${popupState.selectedDrinks.length}');
    if (popupState.paidDrinkQuantities.isNotEmpty) {
      debugPrint(
          '   💰 Paid drinks quantities: ${popupState.paidDrinkQuantities.entries.map((e) => '${e.key}:${e.value}').join(', ')}');
    }
    if (popupState.selectedDrinks.isNotEmpty) {
      debugPrint(
          '   🥤 Selected drinks: ${popupState.selectedDrinks.map((d) => '${d.name} (${d.id})').join(', ')}');
    }

    // Sync active orders to popup state
    for (final entry in manager.activeOrders.entries) {
      final variantId = entry.key;
      final orderState = entry.value;

      // Add variant to selected variants
      popupState.selectedVariants.add(variantId);

      // Set pricing
      if (orderState.pricing != null) {
        popupState.selectedPricingPerVariant[variantId] = orderState.pricing!;
      }

      // Set quantity
      popupState.quantity = orderState.quantity;

      // ✅ SYNC: Sync supplements (global supplements for regular items, global_ supplements for special packs)
      popupState.selectedSupplements.clear();
      popupState.selectedSupplements.addAll(orderState.supplements);
      debugPrint(
          '✅ EditOrderBridge: Synced ${orderState.supplements.length} supplements');

      // ✅ SYNC: Sync ingredients
      popupState.removedIngredients.clear();
      popupState.removedIngredients.addAll(orderState.removedIngredients);
      debugPrint(
          '✅ EditOrderBridge: Synced ${orderState.removedIngredients.length} removed ingredients');

      popupState.ingredientPreferences.clear();
      popupState.ingredientPreferences.addAll(orderState.ingredientPreferences);
      debugPrint(
          '✅ EditOrderBridge: Synced ${orderState.ingredientPreferences.length} ingredient preferences');

      // ✅ FIX: Use variant NAME for packIngredientPreferences (UI uses variant names)
      // But use variant ID for packItemSelections (UI uses variant IDs)
      final variantName = orderState.variant.name;

      // Sync pack item selections (uses variant ID)
      if (!popupState.packItemSelections.containsKey(variantId)) {
        popupState.packItemSelections[variantId] = {};
      }
      popupState.packItemSelections[variantId]!.clear();
      popupState.packItemSelections[variantId]!
          .addAll(orderState.packItemSelections);

      // ✅ FIX: Sync pack ingredient preferences (uses variant NAME - UI reads using variantName)
      if (!popupState.packIngredientPreferences.containsKey(variantName)) {
        popupState.packIngredientPreferences[variantName] = {};
      }
      popupState.packIngredientPreferences[variantName]!.clear();
      popupState.packIngredientPreferences[variantName]!.addAll(
        orderState.packIngredientPreferences.map(
          (key, value) => MapEntry(key, Map.from(value)),
        ),
      );

      // ✅ DEBUG: Log pack ingredient preferences sync
      final totalPackPrefs =
          orderState.packIngredientPreferences.values.fold<int>(
        0,
        (sum, prefs) => sum + prefs.length,
      );
      debugPrint(
          '✅ EditOrderBridge: Synced $totalPackPrefs pack ingredient preferences for variant $variantName (ID: $variantId)');
      if (totalPackPrefs > 0) {
        orderState.packIngredientPreferences.forEach((qtyIndex, prefs) {
          prefs.forEach((ingredient, pref) {
            debugPrint(
                '   [$variantName][$qtyIndex] $ingredient: ${pref.toString().split('.').last}');
          });
        });
      }

      // ✅ FIX: Sync pack supplement selections (UI uses variant ID, not variant name)
      if (!popupState.packSupplementSelections.containsKey(variantId)) {
        popupState.packSupplementSelections[variantId] = {};
      }
      popupState.packSupplementSelections[variantId]!.clear();
      popupState.packSupplementSelections[variantId]!.addAll(
        orderState.packSupplementSelections.map(
          (key, value) => MapEntry(key, Set.from(value)),
        ),
      );
      debugPrint(
          '✅ EditOrderBridge: Synced ${orderState.packSupplementSelections.values.fold<int>(0, (sum, supps) => sum + supps.length)} pack supplement selections for variant $variantId');

      // Set special note
      popupState.specialNote = orderState.specialNote;
    }

    // Sync saved orders
    popupState.savedVariantOrders.clear();
    for (final entry in manager.savedVariantOrders.entries) {
      popupState.savedVariantOrders[entry.key] =
          entry.value.map((order) => order.toJson()).toList();
    }

    debugPrint('✅ EditOrderBridge: Sync manager → popup complete');
  }

  /// Sync popup widget state variables to EditOrderStateManager
  ///
  /// This captures current popup state and stores it in the manager.
  /// Call this before saving an order or submitting to cart.
  static void syncPopupStateToManager(
    PopupStateVariables popupState,
    EditOrderStateManager manager,
    EnhancedMenuItem? enhancedMenuItem,
  ) {
    debugPrint('🔗 EditOrderBridge: Syncing popup state → manager');

    // Sync drinks
    manager.globalFreeDrinkQuantities.clear();
    manager.globalFreeDrinkQuantities.addAll(popupState.drinkQuantities);

    // ✅ FIX: Sync paid drinks and remove any with quantity 0
    manager.globalPaidDrinkQuantities.clear();
    for (final entry in popupState.paidDrinkQuantities.entries) {
      if (entry.value > 0) {
        manager.globalPaidDrinkQuantities[entry.key] = entry.value;
      }
    }
    debugPrint(
        '🔗 EditOrderBridge: Synced paid drinks: ${manager.globalPaidDrinkQuantities.length} drinks (${manager.globalPaidDrinkQuantities.entries.map((e) => '${e.key}:${e.value}').join(', ')})');

    manager.drinkSizesById.clear();
    manager.drinkSizesById.addAll(popupState.drinkSizesById);

    manager.selectedDrinks.clear();
    manager.selectedDrinks.addAll(popupState.selectedDrinks);

    // Sync active orders from popup state
    for (final variantId in popupState.selectedVariants) {
      if (enhancedMenuItem == null) continue;

      final variant = enhancedMenuItem.variants.firstWhere(
        (v) => v.id == variantId,
        orElse: () => enhancedMenuItem.variants.first,
      );

      // ✅ FIX: Use variant NAME for packIngredientPreferences (UI uses variant names)
      // But use variant ID for packItemSelections (UI uses variant IDs)
      final variantName = variant.name;

      final orderState = VariantOrderState(
        variantId: variantId,
        variant: variant,
        pricing: popupState.selectedPricingPerVariant[variantId],
        quantity: popupState.quantity,
        supplements: List.from(popupState.selectedSupplements),
        removedIngredients: List.from(popupState.removedIngredients),
        ingredientPreferences: Map.from(popupState.ingredientPreferences),
        specialNote: popupState.specialNote,
        // ✅ FIX: Use variantId for packItemSelections (UI uses variant IDs)
        packItemSelections: popupState.packItemSelections[variantId] != null
            ? Map.from(popupState.packItemSelections[variantId]!)
            : {},
        // ✅ FIX: Use variantName for packIngredientPreferences (UI uses variant names)
        // Properly convert nested maps and IngredientPreference values
        packIngredientPreferences: _convertPackIngredientPreferences(
          popupState.packIngredientPreferences[variantName],
        ),
        // ✅ FIX: Use variantId for packSupplementSelections (UI uses variant IDs)
        // Properly convert nested sets from dynamic types
        packSupplementSelections: _convertPackSupplementSelections(
          popupState.packSupplementSelections[variantId],
        ),
      );

      final syncedPackSupplements = orderState.packSupplementSelections.values
          .fold<int>(0, (sum, supps) => sum + supps.length);
      debugPrint(
          '🔗 EditOrderBridge: Synced variant $variantId ($variantName) - packSupplements: $syncedPackSupplements items');
      manager.setActiveOrder(variantId, orderState);
    }

    debugPrint('✅ EditOrderBridge: Sync popup → manager complete');
  }

  /// Update cart with edited order
  ///
  /// Replaces the original cart item with updated data from manager.
  static void updateCartWithEditedOrder({
    required CartProvider cartProvider,
    required EditOrderStateManager manager,
    required MenuItem menuItem,
    required EnhancedMenuItem? enhancedMenuItem,
    required List<MenuItem> restaurantDrinks,
  }) {
    if (!manager.isEditMode || manager.originalCartItem == null) {
      debugPrint('⚠️ EditOrderBridge: Not in edit mode, skipping cart update');
      return;
    }

    debugPrint('🔗 EditOrderBridge: Updating cart with edited order');

    final exportData = manager.export();
    final originalCartItem = manager.originalCartItem!;

    // Ensure we have at least one active order
    if (exportData.activeOrders.isEmpty) {
      debugPrint(
          '⚠️ EditOrderBridge: No active orders found, cannot update cart');
      return;
    }

    // Build customizations from manager state
    // Preserve original customizations for flags like is_special_pack
    final customizations = _buildCustomizations(
      exportData: exportData,
      menuItem: menuItem,
      enhancedMenuItem: enhancedMenuItem,
      originalCustomizations: originalCartItem.customizations,
    );

    // ✅ FIX: Determine if this is the first item (paid drinks should only be charged once)
    // First item is determined by having the smallest ID (earliest created) or being first in the list
    final restaurantId = menuItem.restaurantId;
    final allRestaurantItems = cartProvider.items
        .where((item) => item.customizations?['restaurant_id'] == restaurantId)
        .toList();

    // Sort by ID to find the first item (items with smaller IDs are created first)
    allRestaurantItems.sort((a, b) {
      try {
        final aIdNum = int.tryParse(a.id.split('_').first) ?? 0;
        final bIdNum = int.tryParse(b.id.split('_').first) ?? 0;
        return aIdNum.compareTo(bIdNum);
      } catch (_) {
        return a.id.compareTo(b.id);
      }
    });

    final isFirstItem = allRestaurantItems.isNotEmpty &&
        allRestaurantItems.first.id == originalCartItem.id;

    // ✅ FIX: Recalculate original item's price from its customizations
    // This is the TRUE baseline price, regardless of what was stored
    // (The stored price might be incorrect due to previous bugs)
    double originalRecalculatedPrice = originalCartItem.price;
    debugPrint('🔍 DEBUG: === ANALYZING ORIGINAL CART ITEM PRICE ===');
    debugPrint('🔍 DEBUG: Original cart item ID: ${originalCartItem.id}');
    debugPrint(
        '🔍 DEBUG: Original cart item stored price: ${originalCartItem.price}');
    if (originalCartItem.customizations != null && enhancedMenuItem != null) {
      debugPrint(
          '🔍 DEBUG: Original pack_supplement_selections: ${originalCartItem.customizations!['pack_supplement_selections']}');
      debugPrint(
          '🔍 DEBUG: Original pack_supplement_prices: ${originalCartItem.customizations!['pack_supplement_prices']}');

      originalRecalculatedPrice = _recalculateCartItemPriceFromCustomizations(
        customizations: originalCartItem.customizations!,
        menuItem: menuItem,
        enhancedMenuItem: enhancedMenuItem,
        restaurantDrinks: restaurantDrinks,
        isFirstItem: isFirstItem,
        includePaidDrinks: isFirstItem,
      );
      debugPrint(
          '🔍 DEBUG: Original cart item RECALCULATED price from customizations: $originalRecalculatedPrice');
      final priceDiff =
          (originalCartItem.price - originalRecalculatedPrice).abs();
      if (priceDiff > 0.01) {
        debugPrint(
            '⚠️ DEBUG: ❌ PRICE MISMATCH! Stored price (${originalCartItem.price}) != Recalculated price ($originalRecalculatedPrice), difference: $priceDiff');
        debugPrint(
            '🔍 DEBUG: ⚠️ Using RECALCULATED price ($originalRecalculatedPrice) as baseline for comparison');
      } else {
        debugPrint('✅ DEBUG: Original price matches recalculated price');
      }
    }
    debugPrint('🔍 DEBUG: === END ORIGINAL CART ITEM PRICE ANALYSIS ===');

    // ✅ FIX: Recalculate price from customizations (includes paid drinks for first item)
    // This ensures the price matches what will be calculated when the cart is loaded
    final recalculatedPrice = _recalculateCartItemPriceFromCustomizations(
      customizations: customizations,
      menuItem: menuItem,
      enhancedMenuItem: enhancedMenuItem,
      restaurantDrinks: restaurantDrinks,
      isFirstItem: isFirstItem,
      includePaidDrinks: isFirstItem, // Include paid drinks only for first item
    );

    debugPrint(
        '💰 EditOrderBridge: Recalculated price from customizations: $recalculatedPrice (isFirstItem: $isFirstItem, paidDrinks: ${exportData.globalPaidDrinkQuantities.length})');

    // ✅ FIX: When stored price differs from recalculated price, use stored price as baseline
    // This ensures we match what the user sees in the cart (popup uses stored price as baseline)
    // Calculate price change based on removed/added supplements from the stored price
    double finalPrice = recalculatedPrice;
    final storedPriceDiff =
        (originalCartItem.price - originalRecalculatedPrice).abs();

    debugPrint('🔍 DEBUG: === PRICE COMPARISON ===');
    debugPrint('🔍 DEBUG: Original stored price: ${originalCartItem.price}');
    debugPrint(
        '🔍 DEBUG: Original recalculated price: $originalRecalculatedPrice');
    debugPrint('🔍 DEBUG: New calculated price: $recalculatedPrice');
    debugPrint('🔍 DEBUG: Stored vs recalculated difference: $storedPriceDiff');

    if (storedPriceDiff > 0.01) {
      // Stored price differs from recalculated - use stored price as baseline
      // Calculate price change from stored price based on supplement changes
      final priceChange = recalculatedPrice -
          originalRecalculatedPrice; // Change based on customizations
      finalPrice = originalCartItem.price +
          priceChange; // Apply same change to stored price
      debugPrint(
          '🔍 DEBUG: ⚠️ Price mismatch detected - using stored price as baseline');
      debugPrint('🔍 DEBUG: Price change from customizations: $priceChange');
      debugPrint(
          '🔍 DEBUG: Final price = stored (${originalCartItem.price}) + change ($priceChange) = $finalPrice');
    } else {
      // Prices match - use recalculated price directly
      finalPrice = recalculatedPrice;
      final newPriceDiff =
          (originalRecalculatedPrice - recalculatedPrice).abs();
      if (newPriceDiff > 0.01) {
        final priceChange = recalculatedPrice - originalRecalculatedPrice;
        debugPrint(
            '🔍 DEBUG: ✅ Price changed by ${priceChange > 0 ? '+' : ''}$priceChange (from $originalRecalculatedPrice to $recalculatedPrice)');
      } else {
        debugPrint('🔍 DEBUG: ✅ Price unchanged: $recalculatedPrice');
      }
    }
    debugPrint('🔍 DEBUG: Final saved price: $finalPrice');
    debugPrint('🔍 DEBUG: === END PRICE COMPARISON ===');

    // Use the final calculated price
    final adjustedRecalculatedPrice = finalPrice;

    final firstOrder = exportData.activeOrders.values.first;

    // Create updated cart item
    final updatedCartItem = CartItem(
      id: originalCartItem.id, // Preserve original ID
      name: originalCartItem.name,
      price:
          adjustedRecalculatedPrice, // Use adjusted price (matches popup calculation)
      quantity: firstOrder.quantity,
      image: menuItem.image,
      restaurantName: menuItem.restaurantName,
      customizations:
          customizations, // Always non-null from _buildCustomizations
      drinkQuantities: {
        ...exportData.globalFreeDrinkQuantities,
        ...exportData.globalPaidDrinkQuantities,
      },
      specialInstructions: firstOrder.specialNote,
    );

    // Update current cart item
    cartProvider.updateCartItem(originalCartItem.id, updatedCartItem);

    // Calculate paid drinks price for debug logging
    double paidDrinksPriceForLog = 0.0;
    if (isFirstItem) {
      for (final entry in exportData.globalPaidDrinkQuantities.entries) {
        final drinkId = entry.key;
        final quantity = entry.value;
        if (quantity > 0) {
          final drink = restaurantDrinks.firstWhere(
            (d) => d.id == drinkId,
            orElse: () =>
                restaurantDrinks.isNotEmpty ? restaurantDrinks.first : menuItem,
          );
          paidDrinksPriceForLog += drink.price * quantity;
        }
      }
    }

    debugPrint(
        '🔗 EditOrderBridge: Updated current item (isFirstItem: $isFirstItem, price: $adjustedRecalculatedPrice, paidDrinksPrice: $paidDrinksPriceForLog)');
    debugPrint(
        '🔍 DEBUG: ✅ Saved price: $adjustedRecalculatedPrice (was ${originalCartItem.price}, recalculated: $recalculatedPrice, adjusted: $adjustedRecalculatedPrice)');

    // ✅ FIX: Sync paid drinks globally across ALL cart items from the same restaurant
    // Paid drinks are global - when one item is edited, all items should reflect the same paid drinks
    // Also recalculate prices for other items to ensure paid drinks are only charged once
    final otherRestaurantItems = allRestaurantItems
        .where((item) => item.id != originalCartItem.id)
        .toList();

    debugPrint(
        '🔗 EditOrderBridge: Syncing paid drinks to ${otherRestaurantItems.length} other items from same restaurant');
    debugPrint(
        '   First item ID: ${allRestaurantItems.isNotEmpty ? allRestaurantItems.first.id : 'none'}');

    for (final otherItem in otherRestaurantItems) {
      // ✅ FIX: Preserve ALL pack data from original item (selections, preferences, supplements)
      // Only update drinks (paid drinks are global, free drinks are per-item)
      final otherCustomizations =
          Map<String, dynamic>.from(otherItem.customizations ?? {});

      debugPrint('   🔍 DEBUG: Processing other item ${otherItem.id}');
      debugPrint('   🔍 DEBUG: Other item original price: ${otherItem.price}');
      debugPrint(
          '   🔍 DEBUG: Other item pack_supplement_selections: ${otherItem.customizations?['pack_supplement_selections']}');
      debugPrint(
          '   🔍 DEBUG: Other item pack_supplement_prices keys: ${(otherItem.customizations?['pack_supplement_prices'] as Map?)?.keys.join(', ') ?? 'null'}');

      // ✅ FIX: Preserve size and portion from original item (needed for correct base price calculation)
      // If not set, use defaults from enhancedMenuItem pricing
      final originalSize = otherItem.customizations?['size'] as String?;
      final originalPortion = otherItem.customizations?['portion'] as String?;
      if (originalSize != null && originalSize.isNotEmpty) {
        otherCustomizations['size'] = originalSize;
      } else if (enhancedMenuItem != null &&
          enhancedMenuItem.pricing.isNotEmpty) {
        // Set default size if missing
        otherCustomizations['size'] = enhancedMenuItem.pricing.first.size;
        debugPrint(
            '   ✅ Set default size for ${otherItem.id}: ${enhancedMenuItem.pricing.first.size}');
      }
      if (originalPortion != null && originalPortion.isNotEmpty) {
        otherCustomizations['portion'] = originalPortion;
      } else if (enhancedMenuItem != null &&
          enhancedMenuItem.pricing.isNotEmpty) {
        // Set default portion if missing
        otherCustomizations['portion'] = enhancedMenuItem.pricing.first.portion;
        debugPrint(
            '   ✅ Set default portion for ${otherItem.id}: ${enhancedMenuItem.pricing.first.portion}');
      }

      // ✅ FIX: Preserve pack data from original item (these are per-item, not global)
      // We should NOT overwrite these when syncing paid drinks
      if (otherItem.customizations != null) {
        // Preserve pack_selections (each item has its own selections)
        if (otherItem.customizations!.containsKey('pack_selections')) {
          otherCustomizations['pack_selections'] =
              otherItem.customizations!['pack_selections'];
        }
        // Preserve pack_ingredient_preferences (each item has its own preferences)
        if (otherItem.customizations!
            .containsKey('pack_ingredient_preferences')) {
          otherCustomizations['pack_ingredient_preferences'] =
              otherItem.customizations!['pack_ingredient_preferences'];
        }
        // Preserve pack_supplement_selections (each item has its own selections)
        if (otherItem.customizations!
            .containsKey('pack_supplement_selections')) {
          otherCustomizations['pack_supplement_selections'] =
              otherItem.customizations!['pack_supplement_selections'];
          debugPrint(
              '   🔍 DEBUG: Preserved pack_supplement_selections for ${otherItem.id}: ${otherItem.customizations!['pack_supplement_selections']}');
        }
        // ✅ FIX: Don't preserve pack_supplement_prices - always recalculate from selections
        // This ensures prices are always correct and match the current selections
        // We'll recalculate pack_supplement_prices from pack_supplement_selections below
      }

      // ✅ FIX: Preserve free drinks for this item (free drinks are per-item, not global)
      final otherFreeDrinkQuantities =
          (otherCustomizations['free_drink_quantities']
                  as Map<String, dynamic>?) ??
              <String, dynamic>{};
      final otherFreeDrinksMap = Map<String, int>.from(
        otherFreeDrinkQuantities.map((k, v) =>
            MapEntry(k, v is int ? v : int.tryParse(v.toString()) ?? 0)),
      );

      // ✅ FIX: Update paid_drink_quantities in customizations (paid drinks are global)
      // Only include drinks with quantity > 0
      final filteredPaidDrinkQuantitiesForCustomizations = <String, int>{};
      for (final entry in exportData.globalPaidDrinkQuantities.entries) {
        if (entry.value > 0) {
          filteredPaidDrinkQuantitiesForCustomizations[entry.key] = entry.value;
        }
      }
      otherCustomizations['paid_drink_quantities'] =
          filteredPaidDrinkQuantitiesForCustomizations;

      // ✅ FIX: Preserve free_drink_quantities for this item (free drinks are per-item)
      otherCustomizations['free_drink_quantities'] =
          Map<String, int>.from(otherFreeDrinksMap);

      debugPrint(
          '   🔍 DEBUG: Updated paid_drink_quantities: ${exportData.globalPaidDrinkQuantities.length} drinks');
      debugPrint(
          '   🔍 DEBUG: Preserved free_drink_quantities: ${otherFreeDrinksMap.length} drinks');

      // ✅ FIX: Update paid drinks in drinks list, but preserve free drinks
      // Ensure all drinks are properly synchronized with global paid drinks
      final drinks = <Map<String, dynamic>>[];
      final processedDrinkIds = <String>{};

      // First, add all existing free drinks (preserve per-item free drinks)
      final existingDrinks = (otherCustomizations['drinks'] as List?) ?? [];
      for (final d in existingDrinks) {
        if (d is Map<String, dynamic>) {
          final drinkId = d['id']?.toString() ?? '';
          if (drinkId.isNotEmpty && !processedDrinkIds.contains(drinkId)) {
            processedDrinkIds.add(drinkId);

            // Check if this is a free drink (should be preserved per-item)
            if (otherFreeDrinksMap.containsKey(drinkId)) {
              // This is a free drink for this item - preserve it
              // ✅ FIX: Deeply convert nested structures to ensure JSON serialization
              final updatedDrink = <String, dynamic>{};
              d.forEach((key, value) {
                if (value == null) {
                  updatedDrink[key] = null;
                } else if (value is Map) {
                  // Convert nested maps
                  updatedDrink[key] = Map<String, dynamic>.from(
                    value.map((k, v) => MapEntry(
                          k.toString(),
                          v is Map ? Map<String, dynamic>.from(v) : v,
                        )),
                  );
                } else if (value is List) {
                  // Convert lists, ensuring nested maps are converted
                  updatedDrink[key] = value.map((item) {
                    if (item is Map) {
                      return Map<String, dynamic>.from(item);
                    }
                    return item;
                  }).toList();
                } else {
                  updatedDrink[key] = value;
                }
              });
              updatedDrink['price'] = 0.0;
              updatedDrink['is_free'] = true;
              drinks.add(updatedDrink);
            }
            // Note: Paid drinks will be added below from global state
          }
        }
      }

      // ✅ FIX: Add all global paid drinks (paid drinks are global, not per-item)
      // Only add drinks with quantity > 0
      for (final entry in exportData.globalPaidDrinkQuantities.entries) {
        final drinkId = entry.key;
        final quantity = entry.value;

        if (quantity > 0) {
          final drink = restaurantDrinks.firstWhere(
            (d) => d.id == drinkId,
            orElse: () =>
                restaurantDrinks.isNotEmpty ? restaurantDrinks.first : menuItem,
          );

          // ✅ FIX: Ensure proper JSON serialization of drink data
          // Deeply convert all nested structures to JSON-safe formats
          final drinkJson = drink.toJson();
          final drinkData = <String, dynamic>{};

          // Convert all nested maps and lists to JSON-safe formats
          drinkJson.forEach((key, value) {
            if (value == null) {
              drinkData[key] = null;
            } else if (value is Map) {
              // Convert nested maps
              drinkData[key] = Map<String, dynamic>.from(
                value.map((k, v) => MapEntry(
                      k.toString(),
                      v is Map ? Map<String, dynamic>.from(v) : v,
                    )),
              );
            } else if (value is List) {
              // Convert lists, ensuring nested maps are converted
              drinkData[key] = value.map((item) {
                if (item is Map) {
                  return Map<String, dynamic>.from(item);
                }
                return item;
              }).toList();
            } else {
              drinkData[key] = value;
            }
          });

          // Add our custom fields
          drinkData['size'] = exportData.drinkSizesById[drinkId] ?? '';
          drinkData['is_free'] = false;
          drinkData['price'] = drink.price;

          // Remove drink from processed list if it was there as a free drink
          processedDrinkIds.remove(drinkId);
          drinks.add(drinkData);
          processedDrinkIds.add(drinkId);

          debugPrint(
              '   ✅ Added global paid drink ${drink.name} (ID: $drinkId, qty: $quantity) to item ${otherItem.id}');
        } else {
          // Remove paid drink with quantity 0 from the drinks list
          processedDrinkIds.remove(drinkId);
          debugPrint(
              '   ⏭️ Removed paid drink $drinkId (quantity: 0) from item ${otherItem.id}');
        }
      }

      // ✅ FIX: Ensure drinks list is properly sorted (paid drinks first, then free drinks)
      drinks.sort((a, b) {
        final aIsFree = a['is_free'] == true;
        final bIsFree = b['is_free'] == true;
        if (aIsFree && !bIsFree) return 1;
        if (!aIsFree && bIsFree) return -1;
        return 0;
      });

      otherCustomizations['drinks'] = drinks;

      // ✅ FIX: Update drinkQuantities - merge this item's free drinks with global paid drinks
      // Only include paid drinks with quantity > 0
      final filteredPaidDrinkQuantities = <String, int>{};
      for (final entry in exportData.globalPaidDrinkQuantities.entries) {
        if (entry.value > 0) {
          filteredPaidDrinkQuantities[entry.key] = entry.value;
        }
      }
      final updatedDrinkQuantities = <String, int>{
        ...otherFreeDrinksMap, // Preserve this item's free drinks
        ...filteredPaidDrinkQuantities, // Only add paid drinks with quantity > 0
      };

      // ✅ FIX: Preserve pack_supplement_prices from other item's customizations
      // DO NOT recalculate prices for other items - they should keep their own prices
      // We're only syncing paid drinks (which are global), not per-item supplements
      final otherItemIsFirst = allRestaurantItems.isNotEmpty &&
          otherItem.id == allRestaurantItems.first.id;

      double recalculatedPrice = otherItem.price; // Default to original price

      // ✅ FIX: Preserve existing pack_supplement_prices from other item's customizations
      // Only recalculate price based on existing customizations (don't change pack data)
      if (otherCustomizations['is_special_pack'] == true &&
          enhancedMenuItem != null) {
        // ✅ CRITICAL FIX: Filter pack_supplement_prices to only include supplements that are in pack_supplement_selections
        // This ensures prices match the actual selections for this item
        final originalPackSupplementPrices = otherItem
            .customizations?['pack_supplement_prices'] as Map<String, dynamic>?;
        final preservedPackSupplementSelections =
            otherCustomizations['pack_supplement_selections']
                as Map<String, dynamic>?;

        debugPrint(
            '   🔍 DEBUG: Filtering pack_supplement_prices for ${otherItem.id}');
        debugPrint(
            '   🔍 DEBUG: Original pack_supplement_prices keys: ${originalPackSupplementPrices?.keys.join(', ') ?? 'null'}');
        debugPrint(
            '   🔍 DEBUG: Preserved pack_supplement_selections keys: ${preservedPackSupplementSelections?.keys.join(', ') ?? 'null'}');

        if (originalPackSupplementPrices != null &&
            originalPackSupplementPrices.isNotEmpty &&
            preservedPackSupplementSelections != null &&
            preservedPackSupplementSelections.isNotEmpty) {
          // Filter prices to only include supplements that are in the selections
          final filteredPackSupplementPrices =
              <String, Map<String, Map<String, double>>>{};

          preservedPackSupplementSelections
              .forEach((variantName, variantSelections) {
            if (variantSelections is Map) {
              debugPrint(
                  '   🔍 DEBUG: Processing variant $variantName for ${otherItem.id}');
              debugPrint('   🔍 DEBUG: Variant selections: $variantSelections');

              // ✅ FIX: Try to find variant prices using the variant name as key
              // The key might be stored with different formatting, so we need to check both
              dynamic variantPricesRaw =
                  originalPackSupplementPrices[variantName];
              if (variantPricesRaw == null) {
                // Try to find by iterating over keys (case-insensitive or with different formatting)
                for (final key in originalPackSupplementPrices.keys) {
                  if (key.toString().toLowerCase() ==
                      variantName.toString().toLowerCase()) {
                    variantPricesRaw = originalPackSupplementPrices[key];
                    debugPrint(
                        '   🔍 DEBUG: Found variant prices using alternative key: $key (searching for: $variantName)');
                    break;
                  }
                }
              }

              final variantPrices = variantPricesRaw is Map
                  ? Map<String, dynamic>.from(variantPricesRaw)
                  : null;
              debugPrint(
                  '   🔍 DEBUG: Variant prices from original for $variantName: ${variantPrices != null ? 'Found (${variantPrices.keys.length} qtyIndices)' : 'null/not a Map'}');
              if (variantPrices != null && variantPrices.isNotEmpty) {
                debugPrint(
                    '   🔍 DEBUG: Variant prices keys: ${variantPrices.keys.join(', ')}');
              }

              if (variantPrices != null && variantPrices.isNotEmpty) {
                final variantPricesMap = <String, Map<String, double>>{};

                variantSelections.forEach((qtyIndexKey, supplementList) {
                  debugPrint(
                      '   🔍 DEBUG: Processing qtyIndex $qtyIndexKey for variant $variantName');
                  debugPrint(
                      '   🔍 DEBUG: Supplement list: $supplementList (type: ${supplementList.runtimeType})');

                  if (supplementList is List && supplementList.isNotEmpty) {
                    final qtyIndex = qtyIndexKey.toString();
                    final qtyPrices =
                        variantPrices[qtyIndex] as Map<String, dynamic>?;
                    debugPrint(
                        '   🔍 DEBUG: Qty prices for $qtyIndex: ${qtyPrices?.keys.join(', ') ?? 'null'}');

                    if (qtyPrices != null && qtyPrices.isNotEmpty) {
                      final suppPricesMap = <String, double>{};

                      // Only include prices for supplements that are in the selection list
                      for (final supplementName in supplementList) {
                        final supplementNameStr = supplementName.toString();
                        final price = qtyPrices[supplementNameStr];
                        debugPrint(
                            '   🔍 DEBUG: Checking supplement $supplementNameStr: price=$price');
                        if (price != null) {
                          final priceValue = price is num
                              ? price.toDouble()
                              : (double.tryParse(price.toString()) ?? 0.0);
                          if (priceValue > 0) {
                            suppPricesMap[supplementNameStr] = priceValue;
                            debugPrint(
                                '   🔍 DEBUG: ✅ Added $supplementNameStr: $priceValue to filtered prices');
                          }
                        } else {
                          debugPrint(
                              '   🔍 DEBUG: ⚠️ No price found for $supplementNameStr in qtyPrices');
                        }
                      }

                      if (suppPricesMap.isNotEmpty) {
                        variantPricesMap[qtyIndex] = suppPricesMap;
                        debugPrint(
                            '   🔍 DEBUG: ✅ Added qtyIndex $qtyIndex with ${suppPricesMap.length} supplements');
                      } else {
                        debugPrint(
                            '   🔍 DEBUG: ⚠️ No supplements added for qtyIndex $qtyIndex');
                      }
                    } else {
                      debugPrint(
                          '   🔍 DEBUG: ⚠️ No qtyPrices found for qtyIndex $qtyIndex');
                    }
                  } else {
                    debugPrint(
                        '   🔍 DEBUG: ⚠️ Supplement list is empty or not a List for qtyIndex $qtyIndexKey');
                  }
                });

                if (variantPricesMap.isNotEmpty) {
                  filteredPackSupplementPrices[variantName.toString()] =
                      variantPricesMap;
                  debugPrint(
                      '   🔍 DEBUG: ✅ Added variant $variantName with ${variantPricesMap.length} qtyIndices');
                } else {
                  debugPrint(
                      '   🔍 DEBUG: ⚠️ No qtyIndices added for variant $variantName');
                }
              } else {
                debugPrint(
                    '   🔍 DEBUG: ⚠️ No variant prices found for variant $variantName');
              }
            }
          });

          // Set filtered pack_supplement_prices in customizations
          if (filteredPackSupplementPrices.isNotEmpty) {
            otherCustomizations['pack_supplement_prices'] =
                filteredPackSupplementPrices;
            debugPrint(
                '   ✅ Filtered pack_supplement_prices for ${otherItem.id}: ${filteredPackSupplementPrices.keys.join(', ')} (matched to selections)');
            // Debug: Show detailed breakdown
            filteredPackSupplementPrices.forEach((variantName, qtyPrices) {
              qtyPrices.forEach((qtyIndex, suppPrices) {
                suppPrices.forEach((suppName, suppPrice) {
                  debugPrint(
                      '   🔍 DEBUG: Filtered price - [$variantName][$qtyIndex] $suppName: $suppPrice');
                });
              });
            });
          } else {
            // No matching prices for selections, remove pack_supplement_prices
            otherCustomizations.remove('pack_supplement_prices');
            debugPrint(
                '   ✅ Removed pack_supplement_prices for ${otherItem.id} (no matching selections)');
          }
        } else if (originalPackSupplementPrices != null &&
            originalPackSupplementPrices.isNotEmpty) {
          // Has prices but no selections - preserve all prices (backward compatibility)
          final preservedPackSupplementPrices =
              <String, Map<String, Map<String, double>>>{};
          originalPackSupplementPrices.forEach((variantName, qtyPrices) {
            if (qtyPrices is Map) {
              final variantPricesMap = <String, Map<String, double>>{};
              qtyPrices.forEach((qtyIndex, supplementPrices) {
                if (supplementPrices is Map) {
                  final suppPricesMap = <String, double>{};
                  supplementPrices.forEach((supplementName, price) {
                    final priceValue = price is num
                        ? price.toDouble()
                        : (double.tryParse(price.toString()) ?? 0.0);
                    suppPricesMap[supplementName.toString()] = priceValue;
                  });
                  if (suppPricesMap.isNotEmpty) {
                    variantPricesMap[qtyIndex.toString()] = suppPricesMap;
                  }
                }
              });
              if (variantPricesMap.isNotEmpty) {
                preservedPackSupplementPrices[variantName.toString()] =
                    variantPricesMap;
              }
            }
          });
          if (preservedPackSupplementPrices.isNotEmpty) {
            otherCustomizations['pack_supplement_prices'] =
                preservedPackSupplementPrices;
            debugPrint(
                '   ✅ Preserved pack_supplement_prices for ${otherItem.id}: ${preservedPackSupplementPrices.keys.join(', ')} (no selections to filter)');
          }
        } else {
          // No pack_supplement_prices to preserve
          debugPrint(
              '   ✅ No pack_supplement_prices to preserve for ${otherItem.id}');
        }

        // ✅ FIX: When syncing paid drinks to other items:
        // - If this is the FIRST item: adjust price based on paid drinks difference (not full recalculation)
        //   This preserves the original price calculation method and only adjusts for paid drinks
        // - If this is NOT the first item: preserve price (paid drinks don't affect non-first items)
        if (otherItemIsFirst) {
          // First item needs to include paid drinks in its price
          // Instead of full recalculation (which might use different logic than original),
          // calculate the paid drinks price difference and adjust the original price

          // Calculate current paid drinks price from updated customizations
          double currentPaidDrinksPrice = 0.0;
          final paidDrinkQuantities =
              otherCustomizations['paid_drink_quantities']
                  as Map<String, dynamic>?;
          if (paidDrinkQuantities != null && paidDrinkQuantities.isNotEmpty) {
            for (final entry in paidDrinkQuantities.entries) {
              final qty = entry.value is int
                  ? entry.value as int
                  : (int.tryParse(entry.value.toString()) ?? 0);
              if (qty > 0) {
                final drink = restaurantDrinks.firstWhere(
                  (d) => d.id == entry.key,
                  orElse: () => restaurantDrinks.isNotEmpty
                      ? restaurantDrinks.first
                      : menuItem,
                );
                currentPaidDrinksPrice += drink.price * qty;
              }
            }
          }

          // Calculate original paid drinks price from original customizations
          double originalPaidDrinksPrice = 0.0;
          final originalPaidDrinkQuantities =
              otherItem.customizations?['paid_drink_quantities']
                  as Map<String, dynamic>?;
          if (originalPaidDrinkQuantities != null &&
              originalPaidDrinkQuantities.isNotEmpty) {
            for (final entry in originalPaidDrinkQuantities.entries) {
              final qty = entry.value is int
                  ? entry.value as int
                  : (int.tryParse(entry.value.toString()) ?? 0);
              if (qty > 0) {
                final drink = restaurantDrinks.firstWhere(
                  (d) => d.id == entry.key,
                  orElse: () => restaurantDrinks.isNotEmpty
                      ? restaurantDrinks.first
                      : menuItem,
                );
                originalPaidDrinksPrice += drink.price * qty;
              }
            }
          }

          // Adjust original price by the paid drinks difference
          final paidDrinksDifference =
              currentPaidDrinksPrice - originalPaidDrinksPrice;
          recalculatedPrice = otherItem.price + paidDrinksDifference;

          debugPrint(
              '   💰 Adjusted price for FIRST item ${otherItem.id}: ${otherItem.price} + ($currentPaidDrinksPrice - $originalPaidDrinksPrice) = $recalculatedPrice');
        } else {
          // Non-first items don't include paid drinks in price
          recalculatedPrice = otherItem.price;
          debugPrint(
              '   💰 Preserved original price for ${otherItem.id}: $recalculatedPrice (not first item, paid drinks don\'t affect price)');
        }
      }

      // Create updated item with synchronized paid drinks and recalculated price
      final updatedOtherItem = otherItem.copyWith(
        customizations: otherCustomizations,
        drinkQuantities: updatedDrinkQuantities,
        price: recalculatedPrice, // Use recalculated price
      );

      cartProvider.updateCartItem(otherItem.id, updatedOtherItem);
      debugPrint(
          '   ✅ Updated item ${otherItem.id} with global paid drinks (preserved ${otherFreeDrinksMap.length} free drinks, isFirst: $otherItemIsFirst, price: $recalculatedPrice)');
    }

    debugPrint(
        '✅ EditOrderBridge: Cart updated successfully (${otherRestaurantItems.length + 1} items total)');
  }

  /// Recalculate CartItem price from customizations
  ///
  /// This helper function recalculates the price of a cart item based on its customizations,
  /// including base price, global supplements, pack supplements, and paid drinks (if applicable).
  static double _recalculateCartItemPriceFromCustomizations({
    required Map<String, dynamic> customizations,
    required MenuItem menuItem,
    required EnhancedMenuItem? enhancedMenuItem,
    required List<MenuItem> restaurantDrinks,
    required bool isFirstItem,
    required bool includePaidDrinks,
  }) {
    // ✅ FIX: Always use enhancedMenuItem.pricing as the source of truth for base price
    // The menuItem parameter might have the wrong price (from cart item), so we ignore it
    double basePrice = 0.0;
    double globalSupplementsPrice = 0.0;
    double packSupplementsPrice = 0.0;
    double paidDrinksPrice = 0.0;

    // ✅ FIX: Check if this is a special pack or regular item
    final isSpecialPack = customizations['is_special_pack'] == true ||
        SpecialPackHelper.isSpecialPack(menuItem);

    // ✅ FIX: Get base price and size extra charge using RegularItemHelper for regular items
    // For special packs: pricing.price is the base price
    // For regular items: menuItem.price is base, pricing.price is size extra charge
    MenuItemPricing? selectedPricing;

    if (enhancedMenuItem != null && enhancedMenuItem.pricing.isNotEmpty) {
      // Try to match size/portion from customizations
      final size = customizations['size'] as String?;
      final portion = customizations['portion'] as String?;

      if (size != null &&
          portion != null &&
          size.isNotEmpty &&
          portion.isNotEmpty) {
        try {
          selectedPricing = enhancedMenuItem.pricing.firstWhere(
            (p) => p.size == size && p.portion == portion,
          );
          debugPrint(
              '💰 _recalculateCartItemPriceFromCustomizations: Found matching pricing for size=$size, portion=$portion');
        } catch (_) {
          // No matching pricing found, use first pricing (default)
          selectedPricing = enhancedMenuItem.pricing.first;
          debugPrint(
              '💰 _recalculateCartItemPriceFromCustomizations: No matching pricing found, using first pricing (size=$size, portion=$portion)');
        }
      } else {
        // Size/portion not set or empty, use first pricing (default)
        selectedPricing = enhancedMenuItem.pricing.first;
        debugPrint(
            '💰 _recalculateCartItemPriceFromCustomizations: Size/portion not set, using first pricing');
      }
    }

    // ✅ FIX: Use RegularItemHelper for regular items, direct pricing for special packs
    if (isSpecialPack) {
      // Special Pack: pricing.price is the base price
      basePrice = selectedPricing?.price ?? menuItem.price;
      if (basePrice <= 0) {
        basePrice = menuItem.price;
      }
      debugPrint(
          '💰 _recalculateCartItemPriceFromCustomizations: Special pack - basePrice=$basePrice');
    } else {
      // Regular item: use RegularItemHelper to get base price and size extra charge
      basePrice = RegularItemHelper.getBasePrice(
        item: menuItem,
        pricing: selectedPricing,
      );
      final sizeExtra = RegularItemHelper.getSizeExtraCharge(
        item: menuItem,
        pricing: selectedPricing,
      );
      // Add size extra to base price for total base
      basePrice += sizeExtra;
      final isLTO = menuItem.isLimitedOffer;
      final itemType = isLTO ? 'LTO regular' : 'Regular';
      debugPrint(
          '💰 _recalculateCartItemPriceFromCustomizations: $itemType item - basePrice=${RegularItemHelper.getBasePrice(item: menuItem, pricing: selectedPricing)}, sizeExtra=$sizeExtra, totalBase=$basePrice');
    }

    debugPrint(
        '💰 _recalculateCartItemPriceFromCustomizations: Starting - basePrice=$basePrice, isFirstItem=$isFirstItem');

    // Get global supplements from pricing offer_details
    if (enhancedMenuItem != null && enhancedMenuItem.pricing.isNotEmpty) {
      final pricing = enhancedMenuItem.pricing.first;
      final offerDetails = pricing.offerDetails;
      if (offerDetails.isNotEmpty &&
          offerDetails.containsKey('global_supplements')) {
        final globalSupplementsMap =
            offerDetails['global_supplements'] as Map<String, dynamic>?;
        if (globalSupplementsMap != null && globalSupplementsMap.isNotEmpty) {
          globalSupplementsMap.forEach((name, price) {
            final priceValue = price is num
                ? price.toDouble()
                : (double.tryParse(price.toString()) ?? 0.0);
            globalSupplementsPrice += priceValue;
          });
        }
      }
    }

    // Calculate pack supplement prices from pack_supplement_prices in customizations
    // ✅ FIX: Only include prices for supplements that are actually selected in pack_supplement_selections
    // This ensures we don't include prices for variants that weren't selected for this specific item
    final packSupplementSelections =
        customizations['pack_supplement_selections'] as Map<String, dynamic>?;
    final packSupplementPrices =
        customizations['pack_supplement_prices'] as Map<String, dynamic>?;

    debugPrint(
        '   🔍 DEBUG _recalculateCartItemPriceFromCustomizations: Calculating pack supplements price');
    debugPrint(
        '   🔍 DEBUG: pack_supplement_selections keys: ${packSupplementSelections?.keys.join(', ') ?? 'null'}');
    debugPrint(
        '   🔍 DEBUG: pack_supplement_prices keys: ${packSupplementPrices?.keys.join(', ') ?? 'null'}');

    if (packSupplementPrices != null && packSupplementPrices.isNotEmpty) {
      // If we have selections, only sum prices for selected supplements
      if (packSupplementSelections != null &&
          packSupplementSelections.isNotEmpty) {
        debugPrint('   🔍 DEBUG: Using selections to filter prices');
        packSupplementSelections.forEach((variantName, variantSelections) {
          if (variantSelections is Map) {
            debugPrint(
                '   🔍 DEBUG: Processing variant $variantName in price calculation');
            debugPrint('   🔍 DEBUG: Variant selections: $variantSelections');

            // ✅ FIX: Try to find variant prices using the variant name as key
            // The key might be stored with different formatting, so we need to check both
            dynamic variantPricesRaw = packSupplementPrices[variantName];
            if (variantPricesRaw == null) {
              // Try to find by iterating over keys (case-insensitive or with different formatting)
              for (final key in packSupplementPrices.keys) {
                if (key.toString().toLowerCase() ==
                    variantName.toString().toLowerCase()) {
                  variantPricesRaw = packSupplementPrices[key];
                  debugPrint(
                      '   🔍 DEBUG: Found variant prices using alternative key: $key (searching for: $variantName)');
                  break;
                }
              }
            }

            final variantPrices = variantPricesRaw is Map
                ? Map<String, dynamic>.from(variantPricesRaw)
                : null;
            debugPrint(
                '   🔍 DEBUG: Variant prices for $variantName: ${variantPrices != null ? 'Found (${variantPrices.keys.length} qtyIndices)' : 'null/not a Map'}');
            if (variantPrices != null && variantPrices.isNotEmpty) {
              debugPrint(
                  '   🔍 DEBUG: Variant prices keys: ${variantPrices.keys.join(', ')}');
            }

            if (variantPrices != null && variantPrices.isNotEmpty) {
              variantSelections.forEach((qtyIndexKey, supplementList) {
                final qtyIndex = qtyIndexKey.toString();
                final qtyPrices =
                    variantPrices[qtyIndex] as Map<String, dynamic>?;
                debugPrint(
                    '   🔍 DEBUG: Processing qtyIndex $qtyIndex for variant $variantName');
                debugPrint(
                    '   🔍 DEBUG: Supplement list: $supplementList (type: ${supplementList.runtimeType})');
                debugPrint(
                    '   🔍 DEBUG: Qty prices: ${qtyPrices?.keys.join(', ') ?? 'null'}');

                if (qtyPrices != null && supplementList is List) {
                  // Only sum prices for supplements that are actually in the selection list
                  for (final supplementName in supplementList) {
                    final supplementNameStr = supplementName.toString();
                    final price = qtyPrices[supplementNameStr];
                    debugPrint(
                        '   🔍 DEBUG: Checking supplement $supplementNameStr in price calculation: price=$price');
                    if (price != null) {
                      final priceValue = price is num
                          ? price.toDouble()
                          : (double.tryParse(price.toString()) ?? 0.0);
                      if (priceValue > 0) {
                        packSupplementsPrice += priceValue;
                        debugPrint(
                            '      ✅ [$variantName][$qtyIndex] $supplementNameStr: $priceValue (total packSupps: $packSupplementsPrice)');
                      }
                    } else {
                      debugPrint(
                          '   🔍 DEBUG: ⚠️ No price found for $supplementNameStr in qtyPrices');
                    }
                  }
                } else {
                  debugPrint(
                      '   🔍 DEBUG: ⚠️ Qty prices is null or supplement list is not a List');
                }
              });
            } else {
              debugPrint(
                  '   🔍 DEBUG: ⚠️ No variant prices found for variant $variantName in price calculation');
            }
          }
        });
      } else {
        debugPrint(
            '   🔍 DEBUG: No selections found, using fallback (sum all prices)');
        // Fallback: If no selections, sum all prices (backward compatibility)
        packSupplementPrices.forEach((variantName, qtyPrices) {
          if (qtyPrices is Map) {
            qtyPrices.forEach((qtyIndex, supplementPrices) {
              if (supplementPrices is Map) {
                supplementPrices.forEach((supplementName, price) {
                  final priceValue = price is num
                      ? price.toDouble()
                      : (double.tryParse(price.toString()) ?? 0.0);
                  packSupplementsPrice += priceValue;
                  debugPrint(
                      '      ✅ [$variantName][$qtyIndex] $supplementName: $priceValue (fallback, total: $packSupplementsPrice)');
                });
              }
            });
          }
        });
      }
    } else {
      debugPrint(
          '   🔍 DEBUG: No pack_supplement_prices found in customizations');
    }

    // ✅ FIX: Calculate paid drinks price (only if this is the first item and includePaidDrinks is true)
    // Paid drinks are global and should only be included in the first item's price
    if (isFirstItem && includePaidDrinks) {
      // ✅ FIX: Check both paid_drink_quantities AND drinks list to ensure all paid drinks are included
      // This handles cases where multiple paid drinks are added but not all are in paid_drink_quantities
      final paidDrinkQuantities =
          customizations['paid_drink_quantities'] as Map<String, dynamic>?;
      final drinksList = customizations['drinks'] as List<dynamic>?;

      // Build a comprehensive map of all paid drinks from both sources
      final allPaidDrinks = <String, int>{};

      // First, add from paid_drink_quantities
      if (paidDrinkQuantities != null && paidDrinkQuantities.isNotEmpty) {
        paidDrinkQuantities.forEach((drinkId, quantity) {
          final qty = quantity is int
              ? quantity
              : (int.tryParse(quantity.toString()) ?? 0);
          if (qty > 0) {
            allPaidDrinks[drinkId.toString()] = qty;
          }
        });
      }

      // Then, check drinks list for any drinks marked as paid (is_free != true) that aren't in paid_drink_quantities
      if (drinksList != null && drinksList.isNotEmpty) {
        for (final drinkData in drinksList) {
          if (drinkData is Map<String, dynamic>) {
            final drinkId = drinkData['id']?.toString() ?? '';
            final isFree = drinkData['is_free'] == true;
            final price = drinkData['price'] is num
                ? (drinkData['price'] as num).toDouble()
                : (double.tryParse(drinkData['price']?.toString() ?? '0') ??
                    0.0);

            // If drink is not free and has a price > 0, it's a paid drink
            if (drinkId.isNotEmpty && !isFree && price > 0) {
              // Get quantity from paid_drink_quantities if available, otherwise count occurrences
              final existingQty = allPaidDrinks[drinkId] ?? 0;
              if (existingQty == 0) {
                // Count how many times this drink appears in the list (if not in paid_drink_quantities)
                final count = drinksList
                    .where((d) =>
                        d is Map<String, dynamic> &&
                        (d['id']?.toString() ?? '') == drinkId &&
                        d['is_free'] != true)
                    .length;
                if (count > 0) {
                  allPaidDrinks[drinkId] = count;
                }
              }
            }
          }
        }
      }

      if (allPaidDrinks.isNotEmpty) {
        debugPrint(
            '   🔍 DEBUG: Calculating paid drinks price for first item (${allPaidDrinks.length} paid drinks from ${paidDrinkQuantities?.length ?? 0} quantities + ${drinksList?.length ?? 0} drinks list)');
        allPaidDrinks.forEach((drinkId, quantity) {
          if (quantity > 0) {
            final drink = restaurantDrinks.firstWhere(
              (d) => d.id == drinkId,
              orElse: () => restaurantDrinks.isNotEmpty
                  ? restaurantDrinks.first
                  : menuItem,
            );
            final drinkPrice = drink.price * quantity;
            paidDrinksPrice += drinkPrice;
            debugPrint(
                '   🔍 DEBUG: Paid drink ${drink.name} (ID: $drinkId): ${drink.price} × $quantity = $drinkPrice (total paid drinks: $paidDrinksPrice)');
          }
        });
      } else {
        debugPrint(
            '   🔍 DEBUG: No paid drinks found in customizations (paid_drink_quantities and drinks list checked)');
      }
    } else {
      if (!isFirstItem) {
        debugPrint(
            '   🔍 DEBUG: Skipping paid drinks price (not first item, isFirstItem=$isFirstItem)');
      } else if (!includePaidDrinks) {
        debugPrint(
            '   🔍 DEBUG: Skipping paid drinks price (includePaidDrinks=false)');
      }
    }

    final totalPrice = basePrice +
        globalSupplementsPrice +
        packSupplementsPrice +
        paidDrinksPrice;

    debugPrint(
        '💰 _recalculateCartItemPriceFromCustomizations: base=$basePrice, globalSupps=$globalSupplementsPrice, packSupps=$packSupplementsPrice, paidDrinks=$paidDrinksPrice, total=$totalPrice');

    return totalPrice;
  }

  /// Build customizations map from export data
  static Map<String, dynamic> _buildCustomizations({
    required EditOrderExportData exportData,
    required MenuItem menuItem,
    required EnhancedMenuItem? enhancedMenuItem,
    Map<String, dynamic>? originalCustomizations,
  }) {
    final customizations = <String, dynamic>{
      'menu_item_id': menuItem.id,
      'restaurant_id': menuItem.restaurantId,
    };

    // Preserve is_special_pack flag if it exists, or set it based on menu item type
    final isSpecialPack = originalCustomizations?['is_special_pack'] as bool? ??
        SpecialPackHelper.isSpecialPack(menuItem);
    if (isSpecialPack) {
      customizations['is_special_pack'] = true;
    }

    // Add variant data if available
    if (exportData.activeOrders.isNotEmpty) {
      final firstOrder = exportData.activeOrders.values.first;

      // For special packs with multiple variants, variant should be null
      // For regular items, set the variant
      if (!isSpecialPack || exportData.activeOrders.length == 1) {
        customizations['variant'] = firstOrder.variant.toJson();
      } else {
        customizations['variant'] = null; // Multiple variants for special pack
      }

      customizations['main_item_quantity'] = firstOrder.quantity;

      if (firstOrder.pricing != null) {
        customizations['size'] = firstOrder.pricing!.size;
        customizations['portion'] = firstOrder.pricing!.portion;
      }

      // ✅ FIX: Collect supplements from ALL active orders (for special packs with multiple variants)
      // Use a Set with IDs to avoid duplicates
      final allSupplementsMap = <String, MenuItemSupplement>{};
      final allRemovedIngredients = <String>{};
      final allIngredientPreferences = <String, IngredientPreference>{};

      for (final order in exportData.activeOrders.values) {
        // Add supplements (deduplicate by ID)
        for (final supplement in order.supplements) {
          allSupplementsMap[supplement.id] = supplement;
        }
        allRemovedIngredients.addAll(order.removedIngredients);
        allIngredientPreferences.addAll(order.ingredientPreferences);
      }

      customizations['supplements'] =
          allSupplementsMap.values.map((s) => s.toJson()).toList();
      customizations['removed_ingredients'] = allRemovedIngredients.toList();
      // Convert ingredient preferences to JSON-serializable format
      customizations['ingredient_preferences'] = Map<String, String>.from(
        allIngredientPreferences.map(
          (key, value) => MapEntry(
            key,
            value.toString().split('.').last,
          ),
        ),
      );

      // ✅ FIX: Merge pack data from ALL active orders (for special packs with multiple variants)
      final packSelectionsMap = <String, Map<String, dynamic>>{};
      final packIngredientPrefsMap =
          <String, Map<String, Map<String, String>>>{};
      final packSupplementSelectionsMap = <String, Map<String, List<String>>>{};
      final packSupplementPricesMap =
          <String, Map<String, Map<String, double>>>{};

      debugPrint(
          '🔗 EditOrderBridge: Building customizations from ${exportData.activeOrders.length} active orders');

      for (final order in exportData.activeOrders.values) {
        final variantName = order.variant.name;
        final variant = order.variant;
        debugPrint(
            '   Processing variant: $variantName (ID: ${order.variantId})');

        // Merge pack item selections (always include, even if empty)
        packSelectionsMap[variantName] = Map<String, dynamic>.from(
          order.packItemSelections.map(
            (key, value) => MapEntry(
              key.toString(),
              value.toString(),
            ),
          ),
        );
        if (order.packItemSelections.isNotEmpty) {
          debugPrint(
              '     ✅ Added pack selections: ${order.packItemSelections.length} items');
        }

        // Merge pack ingredient preferences (always include structure, even if empty)
        packIngredientPrefsMap[variantName] =
            Map<String, Map<String, String>>.from(
          order.packIngredientPreferences.map(
            (qtyIndex, prefs) => MapEntry(
              qtyIndex.toString(),
              Map<String, String>.from(
                prefs.map(
                  (ingredient, pref) => MapEntry(
                    ingredient,
                    pref.toString().split('.').last,
                  ),
                ),
              ),
            ),
          ),
        );
        if (order.packIngredientPreferences.isNotEmpty) {
          final totalPrefs = order.packIngredientPreferences.values.fold<int>(
            0,
            (sum, prefs) => sum + prefs.length,
          );
          debugPrint(
              '     ✅ Added pack ingredient preferences: $totalPrefs preferences');
        }

        // Merge pack supplement selections (always include structure, even if empty)
        final variantSupplementSelections = Map<String, List<String>>.from(
          order.packSupplementSelections.map(
            (qtyIndex, supplements) => MapEntry(
              qtyIndex.toString(),
              supplements.map((s) => s.toString()).toList(),
            ),
          ),
        );
        packSupplementSelectionsMap[variantName] = variantSupplementSelections;

        // ✅ FIX: Calculate and store pack supplement prices
        if (order.packSupplementSelections.isNotEmpty) {
          final totalSupps = order.packSupplementSelections.values.fold<int>(
            0,
            (sum, supps) => sum + supps.length,
          );
          debugPrint(
              '     ✅ Added pack supplement selections: $totalSupps supplements for $variantName');

          // Get supplement prices from variant description
          final supplementsFromDesc =
              SpecialPackHelper.parseSupplements(variant.description);

          // Build prices map for this variant
          final variantPricesMap = <String, Map<String, double>>{};
          order.packSupplementSelections.forEach((qtyIndex, supplementSet) {
            final qtyPricesMap = <String, double>{};
            for (final supplementName in supplementSet) {
              final supplementPrice =
                  supplementsFromDesc[supplementName] ?? 0.0;
              qtyPricesMap[supplementName] = supplementPrice;
            }
            if (qtyPricesMap.isNotEmpty) {
              variantPricesMap[qtyIndex.toString()] = qtyPricesMap;
            }
          });

          if (variantPricesMap.isNotEmpty) {
            packSupplementPricesMap[variantName] = variantPricesMap;
            debugPrint('     ✅ Added pack supplement prices for $variantName');
          }

          // Debug: print each supplement
          order.packSupplementSelections.forEach((qtyIndex, supps) {
            debugPrint('       [$variantName][$qtyIndex]: ${supps.join(', ')}');
          });
        } else {
          debugPrint(
              '     ⚠️ No pack supplement selections for variant $variantName');
        }
      }

      // Set pack data (always include all variants, even if some have empty data)
      // This ensures all variants' data is preserved, not just the ones with data
      if (packSelectionsMap.isNotEmpty) {
        customizations['pack_selections'] = packSelectionsMap;
      }
      if (packIngredientPrefsMap.isNotEmpty) {
        customizations['pack_ingredient_preferences'] = packIngredientPrefsMap;
      }
      if (packSupplementSelectionsMap.isNotEmpty) {
        customizations['pack_supplement_selections'] =
            packSupplementSelectionsMap;
      }
      // ✅ FIX: Include pack_supplement_prices for proper price calculation
      if (packSupplementPricesMap.isNotEmpty) {
        customizations['pack_supplement_prices'] = packSupplementPricesMap;
        debugPrint(
            '✅ EditOrderBridge: Added pack_supplement_prices to customizations');
      }

      debugPrint(
          '🔗 EditOrderBridge: Final pack data - selections: ${packSelectionsMap.keys.join(', ')}, prefs: ${packIngredientPrefsMap.keys.join(', ')}, supps: ${packSupplementSelectionsMap.keys.join(', ')}');
      debugPrint(
          '🔗 EditOrderBridge: Pack selections count: ${packSelectionsMap.length}, Ingredient prefs count: ${packIngredientPrefsMap.length}, Supplement selections count: ${packSupplementSelectionsMap.length}');
    }

    // ✅ FIX: Add drink data with proper JSON serialization
    // Ensure all drink data is properly converted to JSON-safe formats
    final drinksList = <Map<String, dynamic>>[];
    for (final drink in exportData.selectedDrinks) {
      final drinkJson = drink.toJson();

      // ✅ FIX: Deeply convert all nested structures to JSON-safe formats
      // This ensures offer_details, variants, pricing_options, etc. are all properly serialized
      final drinkData = <String, dynamic>{};
      drinkJson.forEach((key, value) {
        if (value == null) {
          drinkData[key] = null;
        } else if (value is Map) {
          // Convert nested maps
          drinkData[key] = Map<String, dynamic>.from(
            value.map((k, v) => MapEntry(
                  k.toString(),
                  v is Map ? Map<String, dynamic>.from(v) : v,
                )),
          );
        } else if (value is List) {
          // Convert lists, ensuring nested maps are converted
          drinkData[key] = value.map((item) {
            if (item is Map) {
              return Map<String, dynamic>.from(item);
            }
            return item;
          }).toList();
        } else {
          drinkData[key] = value;
        }
      });

      // Add our custom fields
      drinkData['size'] = exportData.drinkSizesById[drink.id] ?? '';

      // ✅ FIX: Determine if drink is free or paid
      // Priority: paid_drink_quantities > free_drink_quantities
      // A drink in paid_drink_quantities should be marked as paid with correct price
      final isInPaidQuantities =
          exportData.globalPaidDrinkQuantities.containsKey(drink.id) &&
              (exportData.globalPaidDrinkQuantities[drink.id] ?? 0) > 0;
      final isInFreeQuantities =
          exportData.globalFreeDrinkQuantities.containsKey(drink.id) &&
              (exportData.globalFreeDrinkQuantities[drink.id] ?? 0) > 0;

      if (isInPaidQuantities) {
        // ✅ FIX: Drink is paid - ensure is_free = false and price is correct
        drinkData['is_free'] = false;
        // Ensure price is set correctly (use drink.price from MenuItem, not from drinkData)
        drinkData['price'] = drink.price;
        debugPrint(
            '💰 EditOrderBridge: Building PAID drink ${drink.name} (ID: ${drink.id}) with price ${drink.price}');
      } else if (isInFreeQuantities) {
        // Drink is free
        drinkData['is_free'] = true;
        drinkData['price'] = 0.0;
        debugPrint(
            '🥤 EditOrderBridge: Building FREE drink ${drink.name} (ID: ${drink.id})');
      } else {
        // ✅ FIX: Drink has no quantity - default to free if it was originally free, otherwise paid
        // Check if drink has a price > 0 to determine if it should be paid
        final drinkPrice = drink.price;
        if (drinkPrice > 0) {
          drinkData['is_free'] = false;
          drinkData['price'] = drinkPrice;
        } else {
          drinkData['is_free'] = true;
          drinkData['price'] = 0.0;
        }
      }

      drinksList.add(drinkData);
    }
    customizations['drinks'] = drinksList;

    // ✅ FIX: Ensure all drink quantities are properly converted to JSON-safe formats
    // Filter out drinks with quantity 0 to avoid JSON encoding issues
    final freeDrinkQuantities = <String, int>{};
    for (final entry in exportData.globalFreeDrinkQuantities.entries) {
      if (entry.value > 0) {
        freeDrinkQuantities[entry.key] = entry.value;
      }
    }
    customizations['free_drink_quantities'] = freeDrinkQuantities;

    final paidDrinkQuantities = <String, int>{};
    for (final entry in exportData.globalPaidDrinkQuantities.entries) {
      if (entry.value > 0) {
        paidDrinkQuantities[entry.key] = entry.value;
      }
    }
    customizations['paid_drink_quantities'] = paidDrinkQuantities;

    debugPrint(
        '🔗 EditOrderBridge: Built customizations with ${paidDrinkQuantities.length} paid drinks (quantities: ${paidDrinkQuantities.entries.map((e) => '${e.key}:${e.value}').join(', ')})');

    return customizations;
  }
}

/// 📦 **Popup State Variables**
///
/// Container for all popup widget state variables that need to be synced
/// with EditOrderStateManager.
class PopupStateVariables {
  // Variant state
  final Set<String> selectedVariants;
  final Map<String, MenuItemPricing> selectedPricingPerVariant;

  // Supplements
  final List<MenuItemSupplement> selectedSupplements;

  // Ingredients
  final List<String> removedIngredients;
  final Map<String, IngredientPreference> ingredientPreferences;

  // Drinks
  final List<MenuItem> selectedDrinks;
  final Map<String, int> drinkQuantities;
  final Map<String, int> paidDrinkQuantities;
  final Map<String, String> drinkSizesById;

  // Pack state
  final Map<String, Map<int, String>> packItemSelections;
  final Map<String, Map<int, Map<String, IngredientPreference>>>
      packIngredientPreferences;
  final Map<String, Map<int, Set<String>>> packSupplementSelections;

  // Saved orders
  final Map<String, List<Map<String, dynamic>>> savedVariantOrders;

  // General
  int quantity;
  String specialNote;

  PopupStateVariables({
    required this.selectedVariants,
    required this.selectedPricingPerVariant,
    required this.selectedSupplements,
    required this.removedIngredients,
    required this.ingredientPreferences,
    required this.selectedDrinks,
    required this.drinkQuantities,
    required this.paidDrinkQuantities,
    required this.drinkSizesById,
    required this.packItemSelections,
    required this.packIngredientPreferences,
    required this.packSupplementSelections,
    required this.savedVariantOrders,
    required this.quantity,
    required this.specialNote,
  });
}
