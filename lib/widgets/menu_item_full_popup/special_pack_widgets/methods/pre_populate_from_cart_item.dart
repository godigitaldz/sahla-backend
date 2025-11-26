import 'package:flutter/foundation.dart';

import '../../../../cart_provider.dart';
import '../../../../models/enhanced_menu_item.dart';
import '../../../../models/ingredient_preference.dart';
import '../../../../models/menu_item.dart';
import '../../../../models/menu_item_pricing.dart';
import '../../../../models/menu_item_supplement.dart';
import '../../../../models/menu_item_variant.dart';

/// Parameters for pre-populate from cart item operations
class PrePopulateFromCartItemParams {
  final CartItem cartItem;
  final EnhancedMenuItem? enhancedMenuItem;
  final List<MenuItem> restaurantDrinks;
  final Set<String> selectedVariants;
  final Map<String, int> variantQuantities;
  final Map<String, MenuItemPricing> selectedPricingPerVariant;
  final List<MenuItemSupplement> selectedSupplements;
  final List<MenuItem> selectedDrinks;
  final Map<String, int> drinkQuantities;
  final Map<String, int> paidDrinkQuantities;
  final Map<String, String> drinkSizesById;
  final List<String> removedIngredients;
  final Map<String, IngredientPreference> ingredientPreferences;
  final String specialNote;
  final int quantity;
  final bool isSpecialPack;

  // Pack-specific state
  final Map<String, Map<int, String>> packItemSelections;
  final Map<String, Map<int, Map<String, IngredientPreference>>>
      packIngredientPreferences;
  final Map<String, Map<int, Set<String>>> packSupplementSelections;

  // Callbacks
  final Function(String) addVariant;
  final Function(String, int) setVariantQuantity;
  final Function(String, MenuItemPricing) setPricingForVariant;
  final Function(MenuItemSupplement) addSupplement;
  final Function(MenuItem) addDrink;
  final Function(String, int) setDrinkQuantity;
  final Function(String, int) setPaidDrinkQuantity;
  final Function(String, String) setDrinkSize;
  final Function(String) addRemovedIngredient;
  final Function(String, IngredientPreference) setIngredientPreference;
  final Function(String) setSpecialNote;
  final Function(int) setQuantity;

  // Pack-specific callbacks
  final Function(String, int, String) setPackItemSelection;
  final Function(String, int, String, IngredientPreference)
      setPackIngredientPreference;
  final Function(String, int, String) addPackSupplementSelection;

  // Helper functions
  final List<String> Function(String?) parsePackItemOptions;

  PrePopulateFromCartItemParams({
    required this.cartItem,
    required this.enhancedMenuItem,
    required this.restaurantDrinks,
    required this.selectedVariants,
    required this.variantQuantities,
    required this.selectedPricingPerVariant,
    required this.selectedSupplements,
    required this.selectedDrinks,
    required this.drinkQuantities,
    required this.paidDrinkQuantities,
    required this.drinkSizesById,
    required this.removedIngredients,
    required this.ingredientPreferences,
    required this.specialNote,
    required this.quantity,
    required this.isSpecialPack,
    required this.packItemSelections,
    required this.packIngredientPreferences,
    required this.packSupplementSelections,
    required this.addVariant,
    required this.setVariantQuantity,
    required this.setPricingForVariant,
    required this.addSupplement,
    required this.addDrink,
    required this.setDrinkQuantity,
    required this.setPaidDrinkQuantity,
    required this.setDrinkSize,
    required this.addRemovedIngredient,
    required this.setIngredientPreference,
    required this.setSpecialNote,
    required this.setQuantity,
    required this.setPackItemSelection,
    required this.setPackIngredientPreference,
    required this.addPackSupplementSelection,
    required this.parsePackItemOptions,
  });
}

/// Pre-populate form fields from an existing cart item
/// ✅ COMPREHENSIVE EDIT LOGIC: Handles all item types (regular, LTO, special packs)
void prePopulateFromCartItem(PrePopulateFromCartItemParams params) {
  debugPrint('🛒 prePopulateFromCartItem called with: ${params.cartItem.name}');
  debugPrint('🛒 CartItem customizations: ${params.cartItem.customizations}');
  debugPrint('🛒 Is special pack: ${params.isSpecialPack}');

  final customizations = params.cartItem.customizations;

  if (customizations == null) {
    debugPrint('🛒 No customizations found, returning');
    return;
  }

  // ✅ STEP 1: Determine item type and handle accordingly
  final isSpecialPackFromCustomizations =
      customizations['is_special_pack'] == true;
  final isSpecialPack = params.isSpecialPack || isSpecialPackFromCustomizations;

  if (isSpecialPack) {
    debugPrint('🛒 Restoring special pack item');
    _restoreSpecialPackItem(params, customizations);
  } else {
    debugPrint('🛒 Restoring regular/LTO item');
    _restoreRegularItem(params, customizations);
  }

  // ✅ STEP 2: Restore common fields (applies to both types)
  _restoreCommonFields(params, customizations);

  debugPrint('✅ Pre-populated form with existing cart item data');
}

/// Restore regular/LTO item data
void _restoreRegularItem(
  PrePopulateFromCartItemParams params,
  Map<String, dynamic> customizations,
) {
  if (params.enhancedMenuItem == null) {
    debugPrint('⚠️ Cannot restore regular item: enhancedMenuItem is null');
    return;
  }

  // ✅ Restore variant(s)
  final variantData = customizations['variant'];
  if (variantData != null) {
    try {
      final variant = MenuItemVariant.fromJson(variantData);
      final variants =
          params.enhancedMenuItem!.variants.where((v) => v.id == variant.id);

      if (variants.isNotEmpty) {
        final variantId = variants.first.id;
        params.addVariant(variantId);

        // Restore variant quantity
        final mainItemQty = customizations['main_item_quantity'];
        final qty = (mainItemQty is int)
            ? mainItemQty
            : int.tryParse(mainItemQty?.toString() ?? '1') ?? 1;
        params.setVariantQuantity(variantId, qty);

        debugPrint('✅ Restored variant: ${variant.name} (qty: $qty)');
      }
    } catch (e) {
      debugPrint('❌ Error restoring variant: $e');
    }
  } else {
    // ✅ FIX: If variant is null but we have variants available, auto-select first variant
    // This ensures the form sections are visible when editing
    if (params.enhancedMenuItem!.variants.isNotEmpty) {
      final firstVariant = params.enhancedMenuItem!.variants.first;
      params.addVariant(firstVariant.id);
      debugPrint(
          '✅ Auto-selected first variant (variant was null): ${firstVariant.name}');

      // Set default quantity
      final mainItemQty = customizations['main_item_quantity'];
      final qty = (mainItemQty is int)
          ? mainItemQty
          : int.tryParse(mainItemQty?.toString() ?? '1') ?? 1;
      params.setVariantQuantity(firstVariant.id, qty);
    }
  }

  // ✅ Restore pricing/size for the variant
  final size = customizations['size'] as String?;
  final portion = customizations['portion'] as String?;

  // ✅ FIX: Ensure we have a selected variant before trying to restore pricing
  if (params.selectedVariants.isEmpty &&
      params.enhancedMenuItem!.variants.isNotEmpty) {
    final firstVariant = params.enhancedMenuItem!.variants.first;
    params.addVariant(firstVariant.id);
    debugPrint(
        '✅ Auto-selected variant for pricing restoration: ${firstVariant.name}');
  }

  if (size != null && params.selectedVariants.isNotEmpty) {
    final variantId = params.selectedVariants.first;
    final pricings = params.enhancedMenuItem!.pricing.where((p) =>
        p.size == size && p.portion == portion && p.variantId == variantId);

    if (pricings.isNotEmpty) {
      params.setPricingForVariant(variantId, pricings.first);
      debugPrint('✅ Restored pricing: size=$size, portion=$portion');
    } else {
      // Fallback: use default pricing for this variant
      final variantPricings = params.enhancedMenuItem!.pricing
          .where((p) => p.variantId == variantId);
      if (variantPricings.isNotEmpty) {
        params.setPricingForVariant(variantId, variantPricings.first);
        debugPrint('⚠️ Using fallback pricing for variant $variantId');
      }
    }
  } else if (params.selectedVariants.isNotEmpty) {
    // ✅ FIX: If no size/portion but variant is selected, set default pricing
    final variantId = params.selectedVariants.first;
    final variantPricings =
        params.enhancedMenuItem!.pricing.where((p) => p.variantId == variantId);
    if (variantPricings.isNotEmpty) {
      params.setPricingForVariant(variantId, variantPricings.first);
      debugPrint(
          '✅ Set default pricing for variant $variantId (no size/portion in customizations)');
    }
  }
}

/// Restore special pack item data
void _restoreSpecialPackItem(
  PrePopulateFromCartItemParams params,
  Map<String, dynamic> customizations,
) {
  if (params.enhancedMenuItem == null) {
    debugPrint('⚠️ Cannot restore special pack: enhancedMenuItem is null');
    return;
  }

  // ✅ Restore pack selections (stored with variant names as keys)
  final packSelectionsRaw = customizations['pack_selections'];
  if (packSelectionsRaw != null) {
    try {
      // ✅ FIX: Handle both Map<String, dynamic> and Map<int, String> formats
      // When stored, it might be Map<int, String> but JSON serialization converts keys to strings
      Map<String, dynamic> packSelections;
      if (packSelectionsRaw is Map) {
        // Convert to Map<String, dynamic> handling both int and string keys
        packSelections = <String, dynamic>{};
        packSelectionsRaw.forEach((key, value) {
          final keyStr = key.toString();
          packSelections[keyStr] = value;
        });
      } else {
        packSelections = packSelectionsRaw as Map<String, dynamic>;
      }

      debugPrint(
          '🛒 Restoring pack selections: ${packSelections.keys.join(', ')}');

      // Convert variant names back to variant IDs
      for (final variantNameEntry in packSelections.entries) {
        final variantName = variantNameEntry.key;
        final selectionsValue = variantNameEntry.value;

        // ✅ FIX: Handle both Map<int, String> and Map<String, dynamic> formats
        Map<dynamic, dynamic>? selectionsMap;
        if (selectionsValue is Map) {
          selectionsMap = selectionsValue;
        } else {
          continue;
        }

        if (selectionsMap.isEmpty) continue;

        // Find variant by name
        final variant = params.enhancedMenuItem!.variants.firstWhere(
          (v) => v.name == variantName,
          orElse: () => MenuItemVariant(
            id: '',
            name: variantName,
            menuItemId: params.enhancedMenuItem!.id,
            description: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        if (variant.id.isEmpty) {
          debugPrint('⚠️ Variant not found: $variantName');
          continue;
        }

        // Add variant to selected variants
        params.addVariant(variant.id);

        // Restore selections: Map<quantity_index, option>
        // Handle both int and string keys
        selectionsMap.forEach((qtyIndexKey, option) {
          final qtyIndex = qtyIndexKey is int
              ? qtyIndexKey
              : int.tryParse(qtyIndexKey.toString()) ?? 0;
          final optionStr = option.toString();

          if (optionStr.isNotEmpty && optionStr != 'Not Selected') {
            params.setPackItemSelection(variant.id, qtyIndex, optionStr);
          }
        });

        debugPrint('✅ Restored pack selections for ${variant.name}');
      }
    } catch (e) {
      debugPrint('❌ Error restoring pack selections: $e');
      debugPrint('   packSelectionsRaw type: ${packSelectionsRaw.runtimeType}');
    }
  }

  // ✅ Restore pack ingredient preferences
  final packIngredientPrefsRaw = customizations['pack_ingredient_preferences'];
  if (packIngredientPrefsRaw != null) {
    try {
      debugPrint('🛒 Restoring pack ingredient preferences');

      // ✅ FIX: Handle both Map<String, dynamic> and other formats
      Map<String, dynamic> packIngredientPrefs;
      if (packIngredientPrefsRaw is Map) {
        packIngredientPrefs = <String, dynamic>{};
        packIngredientPrefsRaw.forEach((key, value) {
          packIngredientPrefs[key.toString()] = value;
        });
      } else {
        packIngredientPrefs = packIngredientPrefsRaw as Map<String, dynamic>;
      }

      for (final variantNameEntry in packIngredientPrefs.entries) {
        final variantName = variantNameEntry.key;
        final prefsValue = variantNameEntry.value;

        // ✅ FIX: Handle both Map<int, Map> and Map<String, Map> formats
        Map<dynamic, dynamic>? prefsMap;
        if (prefsValue is Map) {
          prefsMap = prefsValue;
        } else {
          continue;
        }

        if (prefsMap.isEmpty) continue;

        // Find variant by name
        final variant = params.enhancedMenuItem!.variants.firstWhere(
          (v) => v.name == variantName,
          orElse: () => MenuItemVariant(
            id: '',
            name: variantName,
            menuItemId: params.enhancedMenuItem!.id,
            description: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        if (variant.id.isEmpty) continue;

        // Restore preferences: Map<quantity_index, Map<ingredient, preference>>
        // Handle both int and string keys for quantity index
        prefsMap.forEach((qtyIndexKey, ingredientPrefs) {
          final qtyIndex = qtyIndexKey is int
              ? qtyIndexKey
              : int.tryParse(qtyIndexKey.toString()) ?? 0;

          if (ingredientPrefs is Map) {
            ingredientPrefs.forEach((ingredient, prefStr) {
              try {
                final pref = _parseIngredientPreference(prefStr.toString());
                // ✅ FIX: Use variant.name instead of variant.id for consistency with UI
                // The UI reads preferences using variant names (see _buildPackItemIngredients)
                params.setPackIngredientPreference(
                    variant.name, qtyIndex, ingredient.toString(), pref);
                debugPrint(
                    '✅ Restored ingredient preference: [$variantName][$qtyIndex] $ingredient = $pref');
              } catch (e) {
                debugPrint('❌ Error restoring pack ingredient preference: $e');
              }
            });
          }
        });
      }

      debugPrint('✅ Restored pack ingredient preferences');
    } catch (e) {
      debugPrint('❌ Error restoring pack ingredient preferences: $e');
    }
  }

  // ✅ Restore pack supplement selections
  final packSupplementSelectionsRaw =
      customizations['pack_supplement_selections'];

  int restoredPackSupplementsCount = 0;

  if (packSupplementSelectionsRaw != null) {
    try {
      debugPrint(
          '🛒 Restoring pack supplement selections from pack_supplement_selections');

      // ✅ FIX: Handle both Map<String, dynamic> and other formats
      Map<String, dynamic> packSupplementSelections;
      if (packSupplementSelectionsRaw is Map) {
        packSupplementSelections = <String, dynamic>{};
        packSupplementSelectionsRaw.forEach((key, value) {
          packSupplementSelections[key.toString()] = value;
        });
      } else {
        packSupplementSelections =
            packSupplementSelectionsRaw as Map<String, dynamic>;
      }

      debugPrint(
          '   packSupplementSelections keys: ${packSupplementSelections.keys.join(', ')}');

      for (final variantNameEntry in packSupplementSelections.entries) {
        final variantName = variantNameEntry.key;
        final supplementsValue = variantNameEntry.value;

        debugPrint('   Processing variant: $variantName');

        // ✅ FIX: Handle both Map<int, List> and Map<String, List> formats
        Map<dynamic, dynamic>? supplementsMap;
        if (supplementsValue is Map) {
          supplementsMap = supplementsValue;
        } else {
          debugPrint('   ⚠️ supplementsValue is not a Map: $supplementsValue');
          continue;
        }

        if (supplementsMap.isEmpty) {
          debugPrint('   ⚠️ supplementsMap is empty for $variantName');
          continue;
        }

        // Find variant by name
        final variant = params.enhancedMenuItem!.variants.firstWhere(
          (v) => v.name == variantName,
          orElse: () => MenuItemVariant(
            id: '',
            name: variantName,
            menuItemId: params.enhancedMenuItem!.id,
            description: '',
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );

        if (variant.id.isEmpty) {
          debugPrint('   ⚠️ Variant not found: $variantName');
          continue;
        }

        debugPrint('   Found variant: ${variant.id} (${variant.name})');

        // Restore selections: Map<quantity_index, List<supplement_name>>
        // Handle both int and string keys for quantity index
        supplementsMap.forEach((qtyIndexKey, supplementList) {
          final qtyIndex = qtyIndexKey is int
              ? qtyIndexKey
              : int.tryParse(qtyIndexKey.toString()) ?? 0;

          debugPrint(
              '     qtyIndex: $qtyIndex, supplementList: $supplementList');

          if (supplementList is List && supplementList.isNotEmpty) {
            for (final supplementName in supplementList) {
              params.addPackSupplementSelection(
                  variant.id, qtyIndex, supplementName.toString());
              restoredPackSupplementsCount++;
              debugPrint(
                  '       ✅ Restored: $supplementName for ${variant.name}[$qtyIndex]');
            }
          } else {
            debugPrint(
                '       ⚠️ supplementList is not a List or is empty: $supplementList');
          }
        });
      }

      debugPrint(
          '✅ Restored $restoredPackSupplementsCount pack supplement selections from pack_supplement_selections');
    } catch (e) {
      debugPrint('❌ Error restoring pack supplement selections: $e');
    }
  } else {
    // ✅ FALLBACK: If pack_supplement_selections is not available, try to reconstruct from supplements array
    // This handles old cart items that might not have pack_supplement_selections
    debugPrint(
        '🛒 pack_supplement_selections not found, trying to reconstruct from supplements array');

    final supplements = customizations['supplements'] as List?;
    if (supplements != null && params.enhancedMenuItem != null) {
      for (final supplementData in supplements) {
        try {
          if (supplementData is Map<String, dynamic>) {
            final supplement = MenuItemSupplement.fromJson(supplementData);

            // Only process pack supplements (IDs starting with "pack_")
            if (supplement.id.startsWith('pack_')) {
              // Extract variant ID and supplement name from supplement ID
              // Format: "pack_{variantId}_{supplementName}"
              // Note: variantId can contain spaces, so we need to find the last "_"
              final idWithoutPrefix =
                  supplement.id.substring(5); // Remove "pack_"
              final lastUnderscoreIndex = idWithoutPrefix.lastIndexOf('_');

              if (lastUnderscoreIndex > 0 &&
                  lastUnderscoreIndex < idWithoutPrefix.length - 1) {
                final variantId =
                    idWithoutPrefix.substring(0, lastUnderscoreIndex);
                final supplementName =
                    idWithoutPrefix.substring(lastUnderscoreIndex + 1);

                debugPrint(
                    '       Extracted from ${supplement.id}: variantId=$variantId, supplementName=$supplementName');

                // Find variant by ID
                final variant = params.enhancedMenuItem!.variants.firstWhere(
                  (v) => v.id == variantId,
                  orElse: () => params.enhancedMenuItem!.variants.first,
                );

                // Add to pack supplement selections (qtyIndex 0 for now)
                params.addPackSupplementSelection(
                    variant.id, 0, supplementName);
                restoredPackSupplementsCount++;
                debugPrint(
                    '       ✅ Reconstructed: $supplementName for ${variant.name}[0] from supplements array');
              } else {
                debugPrint(
                    '       ⚠️ Could not parse pack supplement ID: ${supplement.id}');
              }
            }
          }
        } catch (e) {
          debugPrint('❌ Error reconstructing pack supplement: $e');
        }
      }

      if (restoredPackSupplementsCount > 0) {
        debugPrint(
            '✅ Reconstructed $restoredPackSupplementsCount pack supplement selections from supplements array');
      }
    }
  }
}

/// Restore common fields (applies to both regular and special pack items)
void _restoreCommonFields(
  PrePopulateFromCartItemParams params,
  Map<String, dynamic> customizations,
) {
  // ✅ Restore supplements (global supplements, not pack-specific)
  final supplements = customizations['supplements'] as List?;
  if (supplements != null) {
    int restoredCount = 0;
    for (final supplementData in supplements) {
      try {
        if (supplementData is Map<String, dynamic>) {
          final supplement = MenuItemSupplement.fromJson(supplementData);

          if (params.isSpecialPack) {
            // ✅ FIX: For special packs, only restore GLOBAL supplements to selectedSupplements
            // Pack supplements (IDs starting with "pack_") should NOT be added to selectedSupplements
            // They should only be in packSupplementSelections (which is restored separately)
            if (supplement.id.startsWith('global_')) {
              // This is a global supplement - add it to selectedSupplements
              params.addSupplement(supplement);
              restoredCount++;
              debugPrint(
                  '✅ Restored global supplement: ${supplement.name} (${supplement.price})');
            } else {
              // This is a pack supplement - don't add it to selectedSupplements
              // It should already be in packSupplementSelections (restored separately)
              debugPrint(
                  '⚠️ Skipping pack supplement in supplements array: ${supplement.name} (should be in packSupplementSelections)');
            }
          } else {
            // For regular items, try to find it in enhancedMenuItem.supplements
            if (params.enhancedMenuItem != null) {
              final existingSupplements = params.enhancedMenuItem!.supplements
                  .where((s) => s.id == supplement.id);
              if (existingSupplements.isNotEmpty) {
                params.addSupplement(existingSupplements.first);
                restoredCount++;
              }
            }
          }
        }
      } catch (e) {
        debugPrint('❌ Error restoring supplement: $e');
      }
    }
    debugPrint('✅ Restored $restoredCount global supplements');
  }

  // ✅ Restore drinks (free and paid)
  final drinks = customizations['drinks'] as List?;
  final drinkQuantities =
      customizations['drink_quantities'] as Map<String, dynamic>?;
  final freeDrinkQuantities =
      customizations['free_drink_quantities'] as Map<String, dynamic>?;
  final paidDrinkQuantities =
      customizations['paid_drink_quantities'] as Map<String, dynamic>?;

  if (drinks != null) {
    for (final drinkData in drinks) {
      try {
        if (drinkData is Map<String, dynamic>) {
          final drink = MenuItem.fromJson(drinkData);
          final existingDrinks =
              params.restaurantDrinks.where((d) => d.id == drink.id);

          if (existingDrinks.isNotEmpty) {
            final existingDrink = existingDrinks.first;
            final isFree = drinkData['is_free'] == true ||
                (drinkData['price'] as num?)?.toDouble() == 0.0;

            // Restore drink size
            final size = drinkData['size'] as String?;
            if (size != null && size.isNotEmpty) {
              params.setDrinkSize(drink.id, size);
            }

            // Restore drink quantity based on type (free vs paid)
            int quantity = 0;
            if (isFree) {
              // Free drink: get quantity from free_drink_quantities or drink_quantities
              if (freeDrinkQuantities != null &&
                  freeDrinkQuantities.containsKey(drink.id)) {
                quantity = (freeDrinkQuantities[drink.id] is int)
                    ? freeDrinkQuantities[drink.id] as int
                    : int.tryParse(freeDrinkQuantities[drink.id].toString()) ??
                        0;
              } else if (drinkQuantities != null &&
                  drinkQuantities.containsKey(drink.id)) {
                quantity = (drinkQuantities[drink.id] is int)
                    ? drinkQuantities[drink.id] as int
                    : int.tryParse(drinkQuantities[drink.id].toString()) ?? 0;
              }

              if (quantity > 0) {
                params.addDrink(existingDrink);
                params.setDrinkQuantity(drink.id, quantity);
              }
            } else {
              // Paid drink: get quantity from paid_drink_quantities
              if (paidDrinkQuantities != null &&
                  paidDrinkQuantities.containsKey(drink.id)) {
                quantity = (paidDrinkQuantities[drink.id] is int)
                    ? paidDrinkQuantities[drink.id] as int
                    : int.tryParse(paidDrinkQuantities[drink.id].toString()) ??
                        0;
              } else if (drinkQuantities != null &&
                  drinkQuantities.containsKey(drink.id)) {
                // Fallback: check if it's in drink_quantities but not in free
                final freeQty = freeDrinkQuantities?[drink.id];
                if (freeQty == null || freeQty == 0) {
                  quantity = (drinkQuantities[drink.id] is int)
                      ? drinkQuantities[drink.id] as int
                      : int.tryParse(drinkQuantities[drink.id].toString()) ?? 0;
                }
              }

              if (quantity > 0) {
                params.setPaidDrinkQuantity(drink.id, quantity);
              }
            }
          }
        }
      } catch (e) {
        debugPrint('❌ Error restoring drink: $e');
      }
    }
    debugPrint(
        '✅ Restored drinks (free: ${params.drinkQuantities.length}, paid: ${params.paidDrinkQuantities.length})');
  }

  // ✅ Restore removed ingredients
  final removedIngredients = customizations['removed_ingredients'] as List?;
  if (removedIngredients != null) {
    for (final ingredient in removedIngredients) {
      params.addRemovedIngredient(ingredient.toString());
    }
    debugPrint('✅ Restored ${removedIngredients.length} removed ingredients');
  }

  // ✅ Restore ingredient preferences (global, not pack-specific)
  final ingredientPreferences =
      customizations['ingredient_preferences'] as Map<String, dynamic>?;
  if (ingredientPreferences != null) {
    ingredientPreferences.forEach((ingredient, preference) {
      try {
        final pref = _parseIngredientPreference(preference.toString());
        params.setIngredientPreference(ingredient, pref);
      } catch (e) {
        debugPrint('❌ Error restoring ingredient preference: $e');
      }
    });
    debugPrint(
        '✅ Restored ${ingredientPreferences.length} ingredient preferences');
  }

  // ✅ Restore special instructions
  if (params.cartItem.specialInstructions != null &&
      params.cartItem.specialInstructions!.isNotEmpty) {
    params.setSpecialNote(params.cartItem.specialInstructions!);
    debugPrint('✅ Restored special note');
  }

  // ✅ Restore quantity: prefer saved customizations main_item_quantity
  // Only set quantity if it hasn't been set from existingCartItem in initState
  if (params.quantity == 1) {
    try {
      final rawQty = customizations['main_item_quantity'];
      final parsed =
          rawQty is int ? rawQty : int.tryParse(rawQty?.toString() ?? '');
      final finalQty =
          (parsed != null && parsed > 0) ? parsed : params.cartItem.quantity;
      params.setQuantity(finalQty);
      debugPrint('✅ Restored quantity: $finalQty');
    } catch (_) {
      params.setQuantity(params.cartItem.quantity);
      debugPrint(
          '✅ Restored quantity from cartItem: ${params.cartItem.quantity}');
    }
  } else {
    debugPrint('ℹ️ Quantity already set to ${params.quantity}, skipping');
  }
}

/// Parse ingredient preference from string
IngredientPreference _parseIngredientPreference(String prefString) {
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
