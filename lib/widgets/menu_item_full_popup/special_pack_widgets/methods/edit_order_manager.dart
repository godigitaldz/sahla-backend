import 'package:flutter/foundation.dart';

import '../../../../cart_provider.dart';
import '../../../../models/enhanced_menu_item.dart';
import '../../../../models/ingredient_preference.dart';
import '../../../../models/menu_item.dart';
import '../../../../models/menu_item_pricing.dart';
import '../../../../models/menu_item_supplement.dart';
import '../../../../models/menu_item_variant.dart';

/// 🎯 **Comprehensive Edit-Response Logic System**
///
/// Manages multi-order editing scenarios with:
/// - Isolated order logic per variant
/// - Synchronized drink handling (free & paid)
/// - Data consistency between cart and popup state
///
/// **Architecture:**
/// - Each order is independently managed with its own variant, ingredients, supplements
/// - Free drinks: Global synchronization across all orders (shared pool)
/// - Paid drinks: Global synchronization with conditional cost propagation (only first order pays)
///
/// **Use Cases:**
/// 1. Edit single order from cart → restore to popup state
/// 2. Edit mode with multiple saved orders → preserve multi-order structure
/// 3. Add new variants while editing → maintain isolation
///
/// **Author:** Senior Flutter Engineer
/// **Date:** 2025-11-07

/// 📦 **Edit Order State Manager**
///
/// Encapsulates all state for editing a single order or multiple orders.
/// Provides isolated state management per order while maintaining global drink sync.
class EditOrderStateManager {
  // ========================================
  // 🔹 ORDER IDENTIFICATION
  // ========================================

  /// Original cart item being edited (if in edit mode)
  final CartItem? originalCartItem;

  /// Session ID to group all orders from the same popup session
  final String sessionId;

  /// Edit mode flag
  bool get isEditMode => originalCartItem != null;

  // ========================================
  // 🔹 ISOLATED ORDER STATE
  // ========================================

  /// Active order state: Per-variant selections
  /// Map<variant_id, VariantOrderState>
  final Map<String, VariantOrderState> activeOrders = {};

  /// Saved orders: Multiple orders per variant
  /// Map<variant_id, List<SavedOrderData>>
  final Map<String, List<SavedOrderData>> savedVariantOrders = {};

  // ========================================
  // 🔹 GLOBAL DRINK STATE (Synchronized)
  // ========================================

  /// Free drinks: Shared pool across all orders
  /// Map<drink_id, quantity>
  final Map<String, int> globalFreeDrinkQuantities = {};

  /// Paid drinks: Global with conditional cost propagation
  /// Map<drink_id, quantity>
  final Map<String, int> globalPaidDrinkQuantities = {};

  /// Drink sizes by ID
  /// Map<drink_id, size_label>
  final Map<String, String> drinkSizesById = {};

  /// Selected drink items (MenuItem objects)
  final List<MenuItem> selectedDrinks = [];

  // ========================================
  // 🔹 CONSTRUCTOR
  // ========================================

  EditOrderStateManager({
    required this.originalCartItem,
    required this.sessionId,
  });

  // ========================================
  // 🔹 ORDER MANAGEMENT
  // ========================================

  /// Create or update an active order for a variant
  void setActiveOrder(String variantId, VariantOrderState orderState) {
    activeOrders[variantId] = orderState;
    debugPrint('✅ EditOrderStateManager: Set active order for variant $variantId');
  }

  /// Get active order for a variant
  VariantOrderState? getActiveOrder(String variantId) {
    return activeOrders[variantId];
  }

  /// Clear active order for a variant
  void clearActiveOrder(String variantId) {
    activeOrders.remove(variantId);
    debugPrint('🗑️ EditOrderStateManager: Cleared active order for variant $variantId');
  }

  /// Save current active order to saved orders
  void saveActiveOrder(String variantId, SavedOrderData orderData) {
    if (!savedVariantOrders.containsKey(variantId)) {
      savedVariantOrders[variantId] = [];
    }
    savedVariantOrders[variantId]!.add(orderData);
    debugPrint('💾 EditOrderStateManager: Saved order for variant $variantId');
  }

  /// Remove a saved order
  bool removeSavedOrder(String variantId, int orderIndex) {
    if (!savedVariantOrders.containsKey(variantId)) return false;
    if (orderIndex < 0 || orderIndex >= savedVariantOrders[variantId]!.length) {
      return false;
    }
    savedVariantOrders[variantId]!.removeAt(orderIndex);
    debugPrint('🗑️ EditOrderStateManager: Removed saved order [$variantId][$orderIndex]');
    return true;
  }

  /// Get all saved orders for a variant
  List<SavedOrderData> getSavedOrders(String variantId) {
    return savedVariantOrders[variantId] ?? [];
  }

  /// Check if there are any saved orders
  bool hasSavedOrders() {
    return savedVariantOrders.values.any((orders) => orders.isNotEmpty);
  }

  // ========================================
  // 🔹 DRINK SYNCHRONIZATION
  // ========================================

  /// Set free drink quantity (synchronized globally)
  void setFreeDrinkQuantity(String drinkId, int quantity) {
    if (quantity > 0) {
      globalFreeDrinkQuantities[drinkId] = quantity;
    } else {
      globalFreeDrinkQuantities.remove(drinkId);
    }
    debugPrint('🥤 EditOrderStateManager: Free drink [$drinkId] = $quantity');
  }

  /// Set paid drink quantity (synchronized globally)
  void setPaidDrinkQuantity(String drinkId, int quantity) {
    if (quantity > 0) {
      globalPaidDrinkQuantities[drinkId] = quantity;
    } else {
      globalPaidDrinkQuantities.remove(drinkId);
    }
    debugPrint('💰 EditOrderStateManager: Paid drink [$drinkId] = $quantity');
  }

  /// Set drink size
  void setDrinkSize(String drinkId, String size) {
    drinkSizesById[drinkId] = size;
  }

  /// Add drink to selected drinks
  void addDrink(MenuItem drink) {
    if (!selectedDrinks.any((d) => d.id == drink.id)) {
      selectedDrinks.add(drink);
    }
  }

  /// Remove drink from selected drinks
  void removeDrink(String drinkId) {
    selectedDrinks.removeWhere((d) => d.id == drinkId);
    globalFreeDrinkQuantities.remove(drinkId);
    globalPaidDrinkQuantities.remove(drinkId);
    drinkSizesById.remove(drinkId);
  }

  /// Get total free drink quantity across all orders
  int getTotalFreeDrinkQuantity(String drinkId) {
    return globalFreeDrinkQuantities[drinkId] ?? 0;
  }

  /// Get total paid drink quantity across all orders
  int getTotalPaidDrinkQuantity(String drinkId) {
    return globalPaidDrinkQuantities[drinkId] ?? 0;
  }

  // ========================================
  // 🔹 DATA EXPORT
  // ========================================

  /// Export state for submission/cart update
  EditOrderExportData export() {
    return EditOrderExportData(
      activeOrders: Map.from(activeOrders),
      savedVariantOrders: Map.from(savedVariantOrders),
      globalFreeDrinkQuantities: Map.from(globalFreeDrinkQuantities),
      globalPaidDrinkQuantities: Map.from(globalPaidDrinkQuantities),
      drinkSizesById: Map.from(drinkSizesById),
      selectedDrinks: List.from(selectedDrinks),
    );
  }

  /// Clear all state
  void clear() {
    activeOrders.clear();
    savedVariantOrders.clear();
    globalFreeDrinkQuantities.clear();
    globalPaidDrinkQuantities.clear();
    drinkSizesById.clear();
    selectedDrinks.clear();
    debugPrint('🧹 EditOrderStateManager: Cleared all state');
  }
}

/// 📋 **Variant Order State**
///
/// Isolated state for a single variant order.
/// Each variant can have multiple orders (saved + active).
class VariantOrderState {
  /// Variant ID
  final String variantId;

  /// Variant object
  final MenuItemVariant variant;

  /// Selected pricing (size/portion)
  MenuItemPricing? pricing;

  /// Quantity for this order
  int quantity;

  /// Selected supplements (global supplements, not pack-specific)
  final List<MenuItemSupplement> supplements;

  /// Removed ingredients
  final List<String> removedIngredients;

  /// Ingredient preferences
  /// Map<ingredient_name, preference>
  final Map<String, IngredientPreference> ingredientPreferences;

  /// Special note for this order
  String specialNote;

  // ========================================
  // 🔹 SPECIAL PACK STATE (if applicable)
  // ========================================

  /// Pack item selections
  /// Map<quantity_index, selected_option>
  final Map<int, String> packItemSelections;

  /// Pack ingredient preferences
  /// Map<quantity_index, Map<ingredient, preference>>
  final Map<int, Map<String, IngredientPreference>> packIngredientPreferences;

  /// Pack supplement selections
  /// Map<quantity_index, Set<supplement_name>>
  final Map<int, Set<String>> packSupplementSelections;

  VariantOrderState({
    required this.variantId,
    required this.variant,
    this.pricing,
    this.quantity = 1,
    List<MenuItemSupplement>? supplements,
    List<String>? removedIngredients,
    Map<String, IngredientPreference>? ingredientPreferences,
    this.specialNote = '',
    Map<int, String>? packItemSelections,
    Map<int, Map<String, IngredientPreference>>? packIngredientPreferences,
    Map<int, Set<String>>? packSupplementSelections,
  })  : supplements = supplements ?? [],
        removedIngredients = removedIngredients ?? [],
        ingredientPreferences = ingredientPreferences ?? {},
        packItemSelections = packItemSelections ?? {},
        packIngredientPreferences = packIngredientPreferences ?? {},
        packSupplementSelections = packSupplementSelections ?? {};

  /// Clone this order state
  VariantOrderState clone() {
    return VariantOrderState(
      variantId: variantId,
      variant: variant,
      pricing: pricing,
      quantity: quantity,
      supplements: List.from(supplements),
      removedIngredients: List.from(removedIngredients),
      ingredientPreferences: Map.from(ingredientPreferences),
      specialNote: specialNote,
      packItemSelections: Map.from(packItemSelections),
      packIngredientPreferences: Map.from(packIngredientPreferences.map(
        (key, value) => MapEntry(key, Map.from(value)),
      )),
      packSupplementSelections: Map.from(packSupplementSelections.map(
        (key, value) => MapEntry(key, Set.from(value)),
      )),
    );
  }

  /// Convert to saved order data
  SavedOrderData toSavedOrder() {
    return SavedOrderData(
      variantId: variantId,
      variantName: variant.name,
      pricing: pricing,
      quantity: quantity,
      supplements: List.from(supplements),
      removedIngredients: List.from(removedIngredients),
      ingredientPreferences: Map.from(ingredientPreferences),
      specialNote: specialNote,
      packItemSelections: Map.from(packItemSelections),
      packIngredientPreferences: Map.from(packIngredientPreferences),
      packSupplementSelections: Map.from(packSupplementSelections),
      timestamp: DateTime.now().millisecondsSinceEpoch,
    );
  }
}

/// 💾 **Saved Order Data**
///
/// Immutable snapshot of an order that has been "saved" for later submission.
/// Used for "Save & Add Another" functionality.
class SavedOrderData {
  final String variantId;
  final String variantName;
  final MenuItemPricing? pricing;
  final int quantity;
  final List<MenuItemSupplement> supplements;
  final List<String> removedIngredients;
  final Map<String, IngredientPreference> ingredientPreferences;
  final String specialNote;
  final Map<int, String> packItemSelections;
  final Map<int, Map<String, IngredientPreference>> packIngredientPreferences;
  final Map<int, Set<String>> packSupplementSelections;
  final int timestamp;

  SavedOrderData({
    required this.variantId,
    required this.variantName,
    required this.pricing,
    required this.quantity,
    required this.supplements,
    required this.removedIngredients,
    required this.ingredientPreferences,
    required this.specialNote,
    required this.packItemSelections,
    required this.packIngredientPreferences,
    required this.packSupplementSelections,
    required this.timestamp,
  });

  /// Convert to JSON-compatible map
  Map<String, dynamic> toJson() {
    return {
      'variant_id': variantId,
      'variant_name': variantName,
      'pricing': pricing?.toJson(),
      'quantity': quantity,
      'supplements': supplements.map((s) => s.toJson()).toList(),
      'removed_ingredients': removedIngredients,
      'ingredient_preferences': ingredientPreferences.map(
        (key, value) => MapEntry(key, value.toString().split('.').last),
      ),
      'note': specialNote,
      'pack_selections': packItemSelections,
      'pack_ingredient_preferences': packIngredientPreferences.map(
        (qtyIndex, prefs) => MapEntry(
          qtyIndex.toString(),
          prefs.map((ingredient, pref) =>
              MapEntry(ingredient, pref.toString().split('.').last)),
        ),
      ),
      'pack_supplement_selections': packSupplementSelections.map(
        (qtyIndex, supplements) =>
            MapEntry(qtyIndex.toString(), supplements.toList()),
      ),
      'timestamp': timestamp,
    };
  }
}

/// 📤 **Edit Order Export Data**
///
/// Complete state export for submission to cart or backend.
class EditOrderExportData {
  final Map<String, VariantOrderState> activeOrders;
  final Map<String, List<SavedOrderData>> savedVariantOrders;
  final Map<String, int> globalFreeDrinkQuantities;
  final Map<String, int> globalPaidDrinkQuantities;
  final Map<String, String> drinkSizesById;
  final List<MenuItem> selectedDrinks;

  EditOrderExportData({
    required this.activeOrders,
    required this.savedVariantOrders,
    required this.globalFreeDrinkQuantities,
    required this.globalPaidDrinkQuantities,
    required this.drinkSizesById,
    required this.selectedDrinks,
  });
}

/// 🔄 **Edit Order Synchronizer**
///
/// Handles synchronization between popup state and cart state during edit mode.
/// Ensures data consistency when editing existing orders.
class EditOrderSynchronizer {
  /// Synchronize popup state with existing cart item
  /// Returns an EditOrderStateManager with pre-populated state
  ///
  /// **Important:** Paid drinks are global and stored only in the first cart item.
  /// This method will look for paid drinks in allCartItems to find the global paid drinks.
  static EditOrderStateManager syncFromCartItem({
    required CartItem cartItem,
    required EnhancedMenuItem? enhancedMenuItem,
    required List<MenuItem> restaurantDrinks,
    required String sessionId,
    List<CartItem>? allCartItems, // Optional: All cart items to find global paid drinks
  }) {
    debugPrint('🔄 EditOrderSynchronizer: Syncing from cart item ${cartItem.name}');

    final manager = EditOrderStateManager(
      originalCartItem: cartItem,
      sessionId: sessionId,
    );

    final customizations = cartItem.customizations;
    if (customizations == null) {
      debugPrint('⚠️ EditOrderSynchronizer: No customizations found');
      return manager;
    }

    // ✅ FIX: Find paid drinks from first cart item (paid drinks are global)
    // If allCartItems is provided, look for paid drinks in the first item from same restaurant
    Map<String, dynamic>? globalPaidDrinkQuantities;
    List<Map<String, dynamic>>? globalPaidDrinks; // Drinks list from first item
    if (allCartItems != null && allCartItems.isNotEmpty) {
      // Find first item from same restaurant (paid drinks are stored in first item)
      final sameRestaurantItems = allCartItems.where(
        (item) => item.restaurantName == cartItem.restaurantName,
      ).toList();

      if (sameRestaurantItems.isNotEmpty) {
        final firstItem = sameRestaurantItems.first;
        final firstItemCustomizations = firstItem.customizations;
        if (firstItemCustomizations != null) {
          // Get paid drink quantities
          globalPaidDrinkQuantities = firstItemCustomizations['paid_drink_quantities']
              as Map<String, dynamic>?;

          // Also get paid drinks from drinks list (for drinks with is_free: false)
          final firstItemDrinks = firstItemCustomizations['drinks'] as List?;
          if (firstItemDrinks != null) {
            globalPaidDrinks = firstItemDrinks
                .where((d) => d is Map<String, dynamic> &&
                    (d['is_free'] != true &&
                     (d['price'] as num?)?.toDouble() != 0.0))
                .cast<Map<String, dynamic>>()
                .toList();
          }

          debugPrint('✅ EditOrderSynchronizer: Found global paid drinks from first cart item');
        }
      }
    }

    // Restore drinks (global state) - use global paid drinks if found
    _restoreDrinks(
      manager: manager,
      customizations: customizations,
      restaurantDrinks: restaurantDrinks,
      globalPaidDrinkQuantities: globalPaidDrinkQuantities,
      globalPaidDrinks: globalPaidDrinks,
    );

    // Determine if this is a special pack or regular item
    final isSpecialPack = customizations['is_special_pack'] == true;

    if (isSpecialPack) {
      _restoreSpecialPackOrders(
        manager: manager,
        customizations: customizations,
        enhancedMenuItem: enhancedMenuItem,
      );
    } else {
      _restoreRegularOrders(
        manager: manager,
        customizations: customizations,
        enhancedMenuItem: enhancedMenuItem,
      );
    }

    // ✅ SYNC: Restore special instructions from cart item (if not already set)
    if (cartItem.specialInstructions != null &&
        cartItem.specialInstructions!.isNotEmpty) {
      // Set special note in active order if available
      if (manager.activeOrders.isNotEmpty) {
        final firstOrder = manager.activeOrders.values.first;
        if (firstOrder.specialNote.isEmpty) {
          firstOrder.specialNote = cartItem.specialInstructions!;
          debugPrint('✅ EditOrderSynchronizer: Restored special instructions from cart item');
        }
      }
    }

    debugPrint('✅ EditOrderSynchronizer: Sync complete');
    return manager;
  }

  /// Restore drinks from customizations
  ///
  /// **Important:** Uses globalPaidDrinkQuantities if provided (from first cart item),
  /// otherwise falls back to paidDrinkQuantities from current item.
  static void _restoreDrinks({
    required EditOrderStateManager manager,
    required Map<String, dynamic> customizations,
    required List<MenuItem> restaurantDrinks,
    Map<String, dynamic>? globalPaidDrinkQuantities, // Paid drinks from first cart item (global)
    List<Map<String, dynamic>>? globalPaidDrinks, // Paid drinks list from first cart item
  }) {
    final drinks = customizations['drinks'] as List?;
    final freeDrinkQuantities =
        customizations['free_drink_quantities'] as Map<String, dynamic>?;

    // ✅ FIX: Use global paid drinks if available, otherwise use current item's paid drinks
    // Paid drinks are global and should always be restored from first item
    final paidDrinkQuantities = globalPaidDrinkQuantities ??
        (customizations['paid_drink_quantities'] as Map<String, dynamic>?);

    if (globalPaidDrinkQuantities != null) {
      debugPrint('✅ EditOrderSynchronizer: Using global paid drinks from first cart item');
    }

    // ✅ FIX: Also restore paid drinks from global paid drinks list if available
    // This ensures paid drinks are visible even if quantities are stored separately
    if (globalPaidDrinks != null) {
      for (final drinkData in globalPaidDrinks) {
        try {
          final drink = MenuItem.fromJson(drinkData);
          final existingDrink = restaurantDrinks.firstWhere(
            (d) => d.id == drink.id,
            orElse: () => drink,
          );

          // ✅ FIX: Always add drink to selectedDrinks, even if quantity is 0
          // This ensures it appears in the UI for the user to set quantity
          manager.addDrink(existingDrink);

          // Restore size
          final size = drinkData['size'] as String?;
          if (size != null && size.isNotEmpty) {
            manager.setDrinkSize(drink.id, size);
          }

          // Restore quantity from global paid drink quantities
          if (paidDrinkQuantities != null && paidDrinkQuantities.containsKey(drink.id)) {
            final quantity = paidDrinkQuantities[drink.id];
            final qty = quantity is int ? quantity : int.tryParse(quantity.toString()) ?? 0;
            if (qty > 0) {
              manager.setPaidDrinkQuantity(drink.id, qty);
              debugPrint(
                  '💰 EditOrderSynchronizer: Restored global PAID drink ${drink.name} (ID: ${drink.id}) = $qty');
            } else {
              // ✅ FIX: Set quantity to 0 if in paid_drink_quantities but quantity is 0
              // This ensures the drink appears in the UI with correct state
              manager.setPaidDrinkQuantity(drink.id, 0);
              debugPrint(
                  '💰 EditOrderSynchronizer: Added global PAID drink ${drink.name} (ID: ${drink.id}) with quantity 0');
            }
          } else {
            // ✅ FIX: If drink is in global paid drinks list but not in paid_drink_quantities,
            // still add it with quantity 0 to ensure it appears in the UI
            manager.setPaidDrinkQuantity(drink.id, 0);
            debugPrint(
                '💰 EditOrderSynchronizer: Added global PAID drink ${drink.name} (ID: ${drink.id}) with quantity 0 (not in paid_drink_quantities)');
          }
        } catch (e) {
          debugPrint('❌ EditOrderSynchronizer: Error restoring global paid drink: $e');
        }
      }
    }

    // Track which paid drinks were already restored from global list
    final restoredPaidDrinkIds = <String>{};
    if (globalPaidDrinks != null) {
      for (final drinkData in globalPaidDrinks) {
        final drinkId = drinkData['id'] as String?;
        if (drinkId != null) {
          restoredPaidDrinkIds.add(drinkId);
        }
      }
    }

    // Restore drinks from current item (free drinks and any paid drinks not in global list)
    if (drinks != null) {
      for (final drinkData in drinks) {
        try {
          if (drinkData is Map<String, dynamic>) {
            final drink = MenuItem.fromJson(drinkData);
            final existingDrink = restaurantDrinks.firstWhere(
              (d) => d.id == drink.id,
              orElse: () => drink,
            );

            final drinkId = drink.id;

            // ✅ FIX: Check paid_drink_quantities FIRST to determine if drink is paid
            // A drink in paid_drink_quantities should be treated as paid regardless of is_free flag
            // This handles cases where a drink was converted from free to paid
            final isInPaidQuantities = paidDrinkQuantities != null &&
                paidDrinkQuantities.containsKey(drinkId) &&
                (paidDrinkQuantities[drinkId] is int
                    ? (paidDrinkQuantities[drinkId] as int) > 0
                    : (int.tryParse(paidDrinkQuantities[drinkId].toString()) ?? 0) > 0);

            // ✅ FIX: Skip paid drinks that were already restored from global list
            if (isInPaidQuantities && restoredPaidDrinkIds.contains(drinkId)) {
              debugPrint(
                  '⏭️ EditOrderSynchronizer: Skipping paid drink $drinkId (already restored from global)');
              continue;
            }

            // Restore size (if not already set from global)
            final size = drinkData['size'] as String?;
            if (size != null &&
                size.isNotEmpty &&
                !manager.drinkSizesById.containsKey(drinkId)) {
              manager.setDrinkSize(drinkId, size);
            }

            // ✅ FIX: Determine if drink is free or paid
            // Priority: paid_drink_quantities > is_free flag > price
            final isFree = !isInPaidQuantities &&
                (drinkData['is_free'] == true ||
                    (drinkData['price'] as num?)?.toDouble() == 0.0);

            // Restore quantity
            if (isFree) {
              // Free drink: get quantity from free_drink_quantities
              final quantity = freeDrinkQuantities?[drinkId];
              if (quantity != null) {
                final qty = quantity is int
                    ? quantity
                    : int.tryParse(quantity.toString()) ?? 0;
                if (qty > 0) {
                  manager.addDrink(existingDrink);
                  manager.setFreeDrinkQuantity(drinkId, qty);
                  debugPrint(
                      '🥤 EditOrderSynchronizer: Restored FREE drink ${drink.name} (ID: $drinkId) = $qty');
                }
              }
            } else {
              // Paid drink: get quantity from paid_drink_quantities
              // Use globalPaidDrinkQuantities if available, otherwise use current item's
              final quantity = paidDrinkQuantities?[drinkId];
              if (quantity != null) {
                final qty = quantity is int
                    ? quantity
                    : int.tryParse(quantity.toString()) ?? 0;
                if (qty > 0) {
                  manager.addDrink(existingDrink);
                  manager.setPaidDrinkQuantity(drinkId, qty);
                  debugPrint(
                      '💰 EditOrderSynchronizer: Restored PAID drink ${drink.name} (ID: $drinkId) = $qty');
                }
              } else {
                // ✅ FIX: If drink is marked as paid (is_free != true and price > 0)
                // but not in paid_drink_quantities, still add it with quantity 0
                // This ensures it appears in the UI for the user to set quantity
                final drinkPrice = (drinkData['price'] as num?)?.toDouble() ?? 0.0;
                if (drinkPrice > 0 && drinkData['is_free'] != true) {
                  manager.addDrink(existingDrink);
                  manager.setPaidDrinkQuantity(drinkId, 0);
                  debugPrint(
                      '💰 EditOrderSynchronizer: Added PAID drink ${drink.name} (ID: $drinkId) with quantity 0 (not in paid_drink_quantities)');
                }
              }
            }
          }
        } catch (e) {
          debugPrint('❌ EditOrderSynchronizer: Error restoring drink: $e');
        }
      }
    }

    debugPrint('✅ EditOrderSynchronizer: Restored drinks (free: ${manager.globalFreeDrinkQuantities.length}, paid: ${manager.globalPaidDrinkQuantities.length})');
  }

  /// Restore special pack orders
  static void _restoreSpecialPackOrders({
    required EditOrderStateManager manager,
    required Map<String, dynamic> customizations,
    required EnhancedMenuItem? enhancedMenuItem,
  }) {
    if (enhancedMenuItem == null) return;

    debugPrint('🔄 EditOrderSynchronizer: Restoring special pack orders');
    debugPrint('   Available variants: ${enhancedMenuItem.variants.map((v) => v.name).join(', ')}');

    // Get raw data once
    final packSelectionsRaw = customizations['pack_selections'] as Map?;
    final packIngredientPrefsRaw = customizations['pack_ingredient_preferences'] as Map?;
    final packSupplementSelectionsRaw = customizations['pack_supplement_selections'] as Map?;

    debugPrint('   🔍 pack_selections keys: ${packSelectionsRaw?.keys.join(', ') ?? 'null'}');
    debugPrint('   🔍 pack_ingredient_preferences keys: ${packIngredientPrefsRaw?.keys.join(', ') ?? 'null'}');
    debugPrint('   🔍 pack_supplement_selections keys: ${packSupplementSelectionsRaw?.keys.join(', ') ?? 'null'}');

    // ✅ FIX: Iterate over ALL variants from enhancedMenuItem, not just ones with pack_selections
    // This ensures we restore data for all variants, even if they don't have pack_selections
    for (final variant in enhancedMenuItem.variants) {
      // Create variant order state for this variant
      final orderState = VariantOrderState(
        variantId: variant.id,
        variant: variant,
        quantity: customizations['main_item_quantity'] ?? 1,
      );

      // ✅ SYNC: Restore pack selections
      if (packSelectionsRaw != null) {
        final selections = packSelectionsRaw[variant.name];
        if (selections is Map) {
          selections.forEach((qtyIndexKey, option) {
            final qtyIndex = qtyIndexKey is int
                ? qtyIndexKey
                : int.tryParse(qtyIndexKey.toString()) ?? 0;
            orderState.packItemSelections[qtyIndex] = option.toString();
          });
          debugPrint('   ✅ Restored pack selections for ${variant.name}: ${orderState.packItemSelections.length} items');
        }
      }

      // ✅ SYNC: Restore pack ingredient preferences
      if (packIngredientPrefsRaw != null) {
        final variantPrefs = packIngredientPrefsRaw[variant.name] as Map?;
        if (variantPrefs != null) {
          debugPrint('   ✅ Found pack ingredient preferences for ${variant.name}');
          variantPrefs.forEach((qtyIndexKey, ingredientPrefs) {
            final qtyIndex = qtyIndexKey is int
                ? qtyIndexKey
                : int.tryParse(qtyIndexKey.toString()) ?? 0;

            if (ingredientPrefs is Map) {
              if (!orderState.packIngredientPreferences.containsKey(qtyIndex)) {
                orderState.packIngredientPreferences[qtyIndex] = {};
              }

              ingredientPrefs.forEach((ingredient, prefStr) {
                try {
                  final pref = _parseIngredientPreference(prefStr.toString());
                  orderState.packIngredientPreferences[qtyIndex]![ingredient.toString()] = pref;
                  debugPrint('     ✅ Restored [$qtyIndex] $ingredient: ${pref.toString().split('.').last}');
                } catch (e) {
                  debugPrint('❌ EditOrderSynchronizer: Error restoring pack ingredient preference: $e');
                }
              });
            }
          });
          final totalPrefs = orderState.packIngredientPreferences.values.fold<int>(
            0,
            (sum, prefs) => sum + prefs.length,
          );
          debugPrint('   ✅ Restored $totalPrefs ingredient preferences for ${variant.name}');
        } else {
          debugPrint('   ⚠️ No pack ingredient preferences found for variant: ${variant.name}');
        }
      } else {
        debugPrint('   ⚠️ pack_ingredient_preferences not found in customizations');
      }

      // ✅ SYNC: Restore pack supplement selections
      if (packSupplementSelectionsRaw != null) {
        final variantSupplements = packSupplementSelectionsRaw[variant.name] as Map?;
        if (variantSupplements != null) {
          debugPrint('   ✅ Found pack supplement selections for ${variant.name}');
          variantSupplements.forEach((qtyIndexKey, supplementList) {
            final qtyIndex = qtyIndexKey is int
                ? qtyIndexKey
                : int.tryParse(qtyIndexKey.toString()) ?? 0;

            if (supplementList is List) {
              if (!orderState.packSupplementSelections.containsKey(qtyIndex)) {
                orderState.packSupplementSelections[qtyIndex] = {};
              }

              for (final supplementName in supplementList) {
                orderState.packSupplementSelections[qtyIndex]!.add(supplementName.toString());
                debugPrint('     ✅ Restored [$qtyIndex] supplement: $supplementName');
              }
            }
          });
          final totalSupps = orderState.packSupplementSelections.values.fold<int>(
            0,
            (sum, supps) => sum + supps.length,
          );
          debugPrint('   ✅ Restored $totalSupps pack supplement selections for ${variant.name}');
        } else {
          debugPrint('   ⚠️ No pack supplement selections found for variant: ${variant.name}');
        }
      } else {
        debugPrint('   ⚠️ pack_supplement_selections not found in customizations');
      }

      // ✅ SYNC: Restore global supplements (supplements with "global_" prefix)
      final supplements = customizations['supplements'] as List?;
      if (supplements != null) {
        for (final suppData in supplements) {
          if (suppData is Map<String, dynamic>) {
            try {
              final supp = MenuItemSupplement.fromJson(suppData);
              // For special packs, only restore GLOBAL supplements
              if (supp.id.startsWith('global_')) {
                orderState.supplements.add(supp);
                debugPrint('✅ EditOrderSynchronizer: Restored global supplement ${supp.name}');
              }
            } catch (e) {
              debugPrint('❌ EditOrderSynchronizer: Error restoring supplement: $e');
            }
          }
        }
      }

      // ✅ SYNC: Restore removed ingredients (global, not pack-specific)
      final removedIngredients = customizations['removed_ingredients'] as List?;
      if (removedIngredients != null) {
        orderState.removedIngredients.addAll(
          removedIngredients.map((e) => e.toString()),
        );
        debugPrint('✅ EditOrderSynchronizer: Restored ${removedIngredients.length} removed ingredients');
      }

      // ✅ SYNC: Restore global ingredient preferences (not pack-specific)
      final ingredientPreferences = customizations['ingredient_preferences'] as Map<String, dynamic>?;
      if (ingredientPreferences != null) {
        ingredientPreferences.forEach((ingredient, preference) {
          try {
            final pref = _parseIngredientPreference(preference.toString());
            orderState.ingredientPreferences[ingredient] = pref;
          } catch (e) {
            debugPrint('❌ EditOrderSynchronizer: Error restoring ingredient preference: $e');
          }
        });
        debugPrint('✅ EditOrderSynchronizer: Restored ${ingredientPreferences.length} ingredient preferences');
      }

      // ✅ SYNC: Restore special note
      final specialNote = customizations['note'] as String?;
      if (specialNote != null && specialNote.isNotEmpty) {
        orderState.specialNote = specialNote;
      }

      // ✅ FIX: Check if variant exists in ANY pack data map (even with empty data)
      // This ensures we preserve all variants that were in the original cart item
      final variantExistsInPackSelections = packSelectionsRaw != null &&
          packSelectionsRaw.containsKey(variant.name);
      final variantExistsInPackIngredientPrefs = packIngredientPrefsRaw != null &&
          packIngredientPrefsRaw.containsKey(variant.name);
      final variantExistsInPackSupplementSelections = packSupplementSelectionsRaw != null &&
          packSupplementSelectionsRaw.containsKey(variant.name);
      final variantExistsInAnyPackData = variantExistsInPackSelections ||
          variantExistsInPackIngredientPrefs ||
          variantExistsInPackSupplementSelections;

      // Add to manager if variant has any data OR if it exists in any pack data map
      // This ensures all variants from the original cart item are preserved
      if (variantExistsInAnyPackData ||
          orderState.packItemSelections.isNotEmpty ||
          orderState.packIngredientPreferences.isNotEmpty ||
          orderState.packSupplementSelections.isNotEmpty ||
          orderState.supplements.isNotEmpty) {
        manager.setActiveOrder(variant.id, orderState);
        debugPrint('✅ EditOrderSynchronizer: Added variant ${variant.name} to manager (exists in pack data: selections=$variantExistsInPackSelections, prefs=$variantExistsInPackIngredientPrefs, supps=$variantExistsInPackSupplementSelections)');
      } else {
        debugPrint('⚠️ EditOrderSynchronizer: Variant ${variant.name} has no data and not in any pack data map, skipping');
      }
    }
  }

  /// Restore regular orders
  static void _restoreRegularOrders({
    required EditOrderStateManager manager,
    required Map<String, dynamic> customizations,
    required EnhancedMenuItem? enhancedMenuItem,
  }) {
    if (enhancedMenuItem == null) return;

    // Restore variant
    final variantData = customizations['variant'];
    if (variantData != null) {
      try {
        final variant = MenuItemVariant.fromJson(variantData);
        final matchingVariant = enhancedMenuItem.variants.firstWhere(
          (v) => v.id == variant.id,
          orElse: () => variant,
        );

        final orderState = VariantOrderState(
          variantId: matchingVariant.id,
          variant: matchingVariant,
          quantity: customizations['main_item_quantity'] ?? 1,
        );

        // Restore pricing
        final size = customizations['size'] as String?;
        final portion = customizations['portion'] as String?;
        if (size != null) {
          final pricing = enhancedMenuItem.pricing.firstWhere(
            (p) => p.size == size && p.portion == portion && p.variantId == matchingVariant.id,
            orElse: () => enhancedMenuItem.pricing.firstWhere(
              (p) => p.variantId == matchingVariant.id,
            ),
          );
          orderState.pricing = pricing;
        }

        // ✅ SYNC: Restore supplements (global supplements for regular items)
        final supplements = customizations['supplements'] as List?;
        if (supplements != null) {
          for (final suppData in supplements) {
            if (suppData is Map<String, dynamic>) {
              try {
                final supp = MenuItemSupplement.fromJson(suppData);
                // For regular items, all supplements are global
                if (enhancedMenuItem.supplements.any((s) => s.id == supp.id)) {
                  orderState.supplements.add(supp);
                  debugPrint('✅ EditOrderSynchronizer: Restored supplement ${supp.name}');
                }
              } catch (e) {
                debugPrint('❌ EditOrderSynchronizer: Error restoring supplement: $e');
              }
            }
          }
        }

        // ✅ SYNC: Restore removed ingredients
        final removedIngredients = customizations['removed_ingredients'] as List?;
        if (removedIngredients != null) {
          orderState.removedIngredients.addAll(
            removedIngredients.map((e) => e.toString()),
          );
          debugPrint('✅ EditOrderSynchronizer: Restored ${removedIngredients.length} removed ingredients');
        }

        // ✅ SYNC: Restore ingredient preferences (global, not pack-specific)
        final ingredientPreferences = customizations['ingredient_preferences'] as Map<String, dynamic>?;
        if (ingredientPreferences != null) {
          ingredientPreferences.forEach((ingredient, preference) {
            try {
              final pref = _parseIngredientPreference(preference.toString());
              orderState.ingredientPreferences[ingredient] = pref;
            } catch (e) {
              debugPrint('❌ EditOrderSynchronizer: Error restoring ingredient preference: $e');
            }
          });
          debugPrint('✅ EditOrderSynchronizer: Restored ${ingredientPreferences.length} ingredient preferences');
        }

        // ✅ SYNC: Restore special note
        final specialNote = customizations['note'] as String?;
        if (specialNote != null && specialNote.isNotEmpty) {
          orderState.specialNote = specialNote;
        }

        manager.setActiveOrder(matchingVariant.id, orderState);
      } catch (e) {
        debugPrint('❌ EditOrderSynchronizer: Error restoring variant: $e');
      }
    }
  }

  /// Parse ingredient preference from string
  static IngredientPreference _parseIngredientPreference(String prefString) {
    final prefLower = prefString.toLowerCase();
    switch (prefLower) {
      case 'wanted':
        return IngredientPreference.wanted;
      case 'less':
        return IngredientPreference.less;
      case 'none':
      case 'unwanted': // Legacy support
        return IngredientPreference.none;
      default:
        return IngredientPreference.neutral;
    }
  }
}
