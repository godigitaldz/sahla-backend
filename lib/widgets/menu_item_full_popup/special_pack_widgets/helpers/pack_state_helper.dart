import '../../../../models/ingredient_preference.dart';

/// Helper class for managing pack state operations
/// Provides type-safe methods for working with nested Map structures
class PackStateHelper {
  /// Get pack item selection for a variant and quantity index
  static String? getPackItemSelection(
    Map<String, Map<int, String>> packItemSelections,
    String variantId,
    int quantityIndex,
  ) {
    return packItemSelections[variantId]?[quantityIndex];
  }

  /// Set pack item selection for a variant and quantity index
  static void setPackItemSelection(
    Map<String, Map<int, String>> packItemSelections,
    String variantId,
    int quantityIndex,
    String option,
  ) {
    if (!packItemSelections.containsKey(variantId)) {
      packItemSelections[variantId] = {};
    }
    packItemSelections[variantId]![quantityIndex] = option;
  }

  /// Initialize pack item selections map for a variant if it doesn't exist
  static void ensurePackItemSelectionsInitialized(
    Map<String, Map<int, String>> packItemSelections,
    String variantId,
  ) {
    if (!packItemSelections.containsKey(variantId)) {
      packItemSelections[variantId] = {};
    }
  }

  /// Get ingredient preference for a variant, quantity index, and ingredient
  static IngredientPreference? getIngredientPreference(
    Map<String, Map<int, Map<String, IngredientPreference>>>
        packIngredientPreferences,
    String variantId,
    int quantityIndex,
    String ingredient,
  ) {
    return packIngredientPreferences[variantId]?[quantityIndex]?[ingredient];
  }

  /// Get ingredient preferences map for a variant and quantity index
  static Map<String, IngredientPreference> getIngredientPreferencesMap(
    Map<String, Map<int, Map<String, IngredientPreference>>>
        packIngredientPreferences,
    String variantId,
    int quantityIndex,
  ) {
    return packIngredientPreferences[variantId]?[quantityIndex] ?? {};
  }

  /// Set ingredient preference for a variant, quantity index, and ingredient
  static void setIngredientPreference(
    Map<String, Map<int, Map<String, IngredientPreference>>>
        packIngredientPreferences,
    String variantId,
    int quantityIndex,
    String ingredient,
    IngredientPreference preference,
  ) {
    if (!packIngredientPreferences.containsKey(variantId)) {
      packIngredientPreferences[variantId] = {};
    }
    if (!packIngredientPreferences[variantId]!.containsKey(quantityIndex)) {
      packIngredientPreferences[variantId]![quantityIndex] = {};
    }
    packIngredientPreferences[variantId]![quantityIndex]![ingredient] =
        preference;
  }

  /// Remove ingredient preference
  static void removeIngredientPreference(
    Map<String, Map<int, Map<String, IngredientPreference>>>
        packIngredientPreferences,
    String variantId,
    int quantityIndex,
    String ingredient,
  ) {
    packIngredientPreferences[variantId]?[quantityIndex]?.remove(ingredient);
  }

  /// Ensure ingredient preferences map is initialized
  static void ensureIngredientPreferencesInitialized(
    Map<String, Map<int, Map<String, IngredientPreference>>>
        packIngredientPreferences,
    String variantId,
    int quantityIndex,
  ) {
    if (!packIngredientPreferences.containsKey(variantId)) {
      packIngredientPreferences[variantId] = {};
    }
    if (!packIngredientPreferences[variantId]!.containsKey(quantityIndex)) {
      packIngredientPreferences[variantId]![quantityIndex] = {};
    }
  }

  /// Get supplement selections for a variant and quantity index
  static Set<String> getSupplementSelections(
    Map<String, Map<int, Set<String>>> packSupplementSelections,
    String variantId,
    int quantityIndex,
  ) {
    return packSupplementSelections[variantId]?[quantityIndex] ?? {};
  }

  /// Toggle supplement selection for a variant and quantity index
  static bool toggleSupplementSelection(
    Map<String, Map<int, Set<String>>> packSupplementSelections,
    String variantId,
    int quantityIndex,
    String supplementName,
  ) {
    if (!packSupplementSelections.containsKey(variantId)) {
      packSupplementSelections[variantId] = {};
    }
    if (!packSupplementSelections[variantId]!.containsKey(quantityIndex)) {
      packSupplementSelections[variantId]![quantityIndex] = <String>{};
    }
    final currentSet = packSupplementSelections[variantId]![quantityIndex]!;
    if (currentSet.contains(supplementName)) {
      currentSet.remove(supplementName);
      return false; // Removed
    } else {
      currentSet.add(supplementName);
      return true; // Added
    }
  }

  /// Ensure supplement selections map is initialized
  static void ensureSupplementSelectionsInitialized(
    Map<String, Map<int, Set<String>>> packSupplementSelections,
    String variantId,
    int quantityIndex,
  ) {
    if (!packSupplementSelections.containsKey(variantId)) {
      packSupplementSelections[variantId] = {};
    }
    if (!packSupplementSelections[variantId]!.containsKey(quantityIndex)) {
      packSupplementSelections[variantId]![quantityIndex] = <String>{};
    }
  }

  /// Add a saved variant order
  static void addSavedVariantOrder(
    Map<String, List<Map<String, dynamic>>> savedVariantOrders,
    String variantId,
    Map<String, dynamic> order,
  ) {
    if (!savedVariantOrders.containsKey(variantId)) {
      savedVariantOrders[variantId] = [];
    }
    savedVariantOrders[variantId]!.add(order);
  }

  /// Remove a saved variant order
  static bool removeSavedVariantOrder(
    Map<String, List<Map<String, dynamic>>> savedVariantOrders,
    String variantId,
    int orderIndex,
  ) {
    if (!savedVariantOrders.containsKey(variantId)) {
      return false;
    }
    final orders = savedVariantOrders[variantId]!;
    if (orderIndex < 0 || orderIndex >= orders.length) {
      return false;
    }
    orders.removeAt(orderIndex);
    if (orders.isEmpty) {
      savedVariantOrders.remove(variantId);
    }
    return true;
  }

  /// Clear all pack selections while preserving structure
  static void clearPackSelections(
    Map<String, Map<int, String>> packItemSelections,
    Map<String, Map<int, Map<String, IngredientPreference>>>
        packIngredientPreferences,
    Map<String, Map<int, Set<String>>> packSupplementSelections,
  ) {
    packItemSelections.clear();
    packIngredientPreferences.clear();
    packSupplementSelections.clear();
  }

  /// Get count of pack selections across all variants
  static int getPackSelectionsCount(
    Map<String, Map<int, String>> packItemSelections,
  ) {
    return packItemSelections.values
        .fold(0, (sum, selections) => sum + selections.length);
  }

  /// Check if any pack selections exist
  static bool hasPackSelections(
    Map<String, Map<int, String>> packItemSelections,
  ) {
    return packItemSelections.values.any(
      (selections) => selections.isNotEmpty,
    );
  }

  /// Check if pack selections exist for a specific variant
  static bool hasPackSelectionsForVariant(
    Map<String, Map<int, String>> packItemSelections,
    String variantId,
  ) {
    return packItemSelections[variantId]?.isNotEmpty ?? false;
  }
}
