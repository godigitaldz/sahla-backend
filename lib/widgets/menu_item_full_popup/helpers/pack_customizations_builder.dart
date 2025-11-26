import 'package:flutter/foundation.dart';

import '../../../models/enhanced_menu_item.dart';
import '../../../models/ingredient_preference.dart';
import 'special_pack_helper.dart';

/// Parameters for building pack customizations
class PackCustomizationsParams {
  final EnhancedMenuItem? enhancedMenuItem;
  final Map<String, Map<int, String>> packItemSelections;
  final Map<String, Map<int, Map<String, IngredientPreference>>>
      packIngredientPreferences;
  final Map<String, Map<int, Set<String>>> packSupplementSelections;
  final List<String> Function(String?) parsePackItemOptions;
  final Map<String, dynamic> Function(
          Map<String, Map<int, Map<String, IngredientPreference>>>)
      convertIngredientPreferencesToJson;
  final bool enableDebugLogs;

  PackCustomizationsParams({
    required this.enhancedMenuItem,
    required this.packItemSelections,
    required this.packIngredientPreferences,
    required this.packSupplementSelections,
    required this.parsePackItemOptions,
    required this.convertIngredientPreferencesToJson,
    this.enableDebugLogs = false,
  });
}

/// Result of building pack customizations
class PackCustomizationsResult {
  final Map<String, dynamic> packSelectionsWithNames;
  final Map<String, dynamic>? packIngredientPrefsJson;
  final Map<String, dynamic>? packSupplementSelectionsJson;
  final Map<String, dynamic>? packSupplementPricesJson;

  PackCustomizationsResult({
    required this.packSelectionsWithNames,
    this.packIngredientPrefsJson,
    this.packSupplementSelectionsJson,
    this.packSupplementPricesJson,
  });
}

/// Build pack customizations (selections, ingredient preferences, supplement selections)
/// Extracted from add_to_cart.dart and save_and_add_another_order.dart to remove duplication
PackCustomizationsResult buildPackCustomizations(
    PackCustomizationsParams params) {
  final variants = params.enhancedMenuItem?.variants ?? [];

  // Build pack selections with variant names
  final Map<String, dynamic> packSelectionsWithNames = {};

  if (params.enableDebugLogs) {
    debugPrint('🔍 Building pack selections:');
    debugPrint(
        '   Available variants: ${variants.map((v) => '${v.name} (${v.id})').join(', ')}');
    debugPrint(
        '   Pack selections keys: ${params.packItemSelections.keys.join(', ')}');
  }

  // ✅ FIX: Iterate through ALL variants, not just ones with selections
  for (final variant in variants) {
    // Check if this variant has selections
    final selections = params.packItemSelections[variant.id];
    // Check if this variant has options defined
    final options = params.parsePackItemOptions(variant.description);

    if (params.enableDebugLogs) {
      debugPrint('   Processing variant: ${variant.name} (${variant.id})');
      debugPrint(
          '     Has selections: ${selections != null && selections.isNotEmpty}');
      debugPrint('     Has options: ${options.isNotEmpty}');
    }

    if (selections != null && selections.isNotEmpty) {
      // Variant has selections - include them
      packSelectionsWithNames[variant.name] = selections;
      if (params.enableDebugLogs) {
        debugPrint('   ✓ Added ${variant.name} with selections: $selections');
      }
    } else if (options.isNotEmpty) {
      // Variant has options but no selections - pre-fill by quantity with "Not Selected"
      final int qty = SpecialPackHelper.parseQuantity(variant.description);
      final Map<int, String> emptySelections = <int, String>{};
      for (int i = 0; i < (qty > 0 ? qty : 1); i++) {
        emptySelections[i] = 'Not Selected';
      }
      packSelectionsWithNames[variant.name] = emptySelections;
      if (params.enableDebugLogs) {
        debugPrint(
            '   ⚠️ Added ${variant.name} with NO selections (has options)');
      }
    } else {
      // Variant has no options at all - store quantity as Map with empty strings
      final int qty = SpecialPackHelper.parseQuantity(variant.description);
      final Map<int, String> quantityOnly = <int, String>{};
      for (int i = 0; i < (qty > 0 ? qty : 1); i++) {
        quantityOnly[i] = ''; // Empty string instead of "Not Selected"
      }
      packSelectionsWithNames[variant.name] = quantityOnly;
      if (params.enableDebugLogs) {
        debugPrint(
            '   ℹ️ Added ${variant.name} with quantity only (no options)');
      }
    }
  }

  if (params.enableDebugLogs) {
    debugPrint('✅ Final pack selections with names: $packSelectionsWithNames');
  }

  // Convert pack ingredient preferences to JSON format
  Map<String, dynamic>? packIngredientPrefsJson;
  if (params.packIngredientPreferences.isNotEmpty) {
    if (params.enableDebugLogs) {
      debugPrint('🥗 Converting pack ingredient preferences for save:');
      debugPrint(
          '   packIngredientPreferences keys: ${params.packIngredientPreferences.keys.join(', ')}');
    }
    packIngredientPrefsJson = params
        .convertIngredientPreferencesToJson(params.packIngredientPreferences);
  }

  // Convert pack supplement selections to JSON format
  Map<String, dynamic>? packSupplementSelectionsJson;
  Map<String, dynamic>? packSupplementPricesJson;
  if (params.packSupplementSelections.isNotEmpty) {
    if (params.enableDebugLogs) {
      debugPrint('💊 Converting pack supplement selections for save:');
      debugPrint(
          '   packSupplementSelections keys: ${params.packSupplementSelections.keys.join(', ')}');
    }

    packSupplementSelectionsJson = <String, dynamic>{};
    packSupplementPricesJson = <String, dynamic>{};

    // Iterate through all variants to build supplement data
    for (final variantLoop in variants) {
      final variantIdLoop = variantLoop.id;
      final variantNameLoop = variantLoop.name;
      final variantSupplements = params.packSupplementSelections[variantIdLoop];

      if (variantSupplements != null && variantSupplements.isNotEmpty) {
        // Get supplement prices from variant description
        final supplementsFromDesc =
            SpecialPackHelper.parseSupplements(variantLoop.description);

        // Build selections map: Map<quantity_index, List<supplement_name>>
        final selectionsMap = <int, List<String>>{};
        final pricesMap = <String, Map<int, Map<String, double>>>{};

        variantSupplements.forEach((qtyIndex, supplementSet) {
          if (supplementSet.isNotEmpty) {
            selectionsMap[qtyIndex] = supplementSet.toList();

            // Build prices map for this variant
            if (!pricesMap.containsKey(variantNameLoop)) {
              pricesMap[variantNameLoop] = <int, Map<String, double>>{};
            }
            pricesMap[variantNameLoop]![qtyIndex] = <String, double>{};

            // Add prices for each supplement
            for (final supplementName in supplementSet) {
              final price = supplementsFromDesc[supplementName] ?? 0.0;
              pricesMap[variantNameLoop]![qtyIndex]![supplementName] = price;
            }
          }
        });

        if (selectionsMap.isNotEmpty) {
          // Convert int keys to strings for JSON serialization
          final selectionsMapStr = <String, List<String>>{};
          selectionsMap.forEach((key, value) {
            selectionsMapStr[key.toString()] = value;
          });
          packSupplementSelectionsJson[variantNameLoop] = selectionsMapStr;
          packSupplementPricesJson[variantNameLoop] =
              <String, Map<String, double>>{};
          final pricesForVariant = pricesMap[variantNameLoop];
          final supplementPricesForVariant =
              packSupplementPricesJson[variantNameLoop];
          if (pricesForVariant != null && supplementPricesForVariant != null) {
            pricesForVariant.forEach((key, value) {
              supplementPricesForVariant[key.toString()] = value;
            });
          }
        }
      }
    }

    if (params.enableDebugLogs) {
      debugPrint(
          '   ✓ Pack supplement selections: $packSupplementSelectionsJson');
      debugPrint('   ✓ Pack supplement prices: $packSupplementPricesJson');
    }
  }

  return PackCustomizationsResult(
    packSelectionsWithNames: packSelectionsWithNames,
    packIngredientPrefsJson: packIngredientPrefsJson,
    packSupplementSelectionsJson: packSupplementSelectionsJson,
    packSupplementPricesJson: packSupplementPricesJson,
  );
}
