/// Configuration model for special pack ingredients
///
/// Supports flexible ingredient configuration per pack item:
/// - Item-specific ingredients (per variant)
/// - Quantity-specific ingredients (for items with qty > 1)
/// - Global ingredients (applies to entire pack)
class PackIngredientConfig {
  /// Map of variant name to its ingredient configuration
  /// Format: {'Pizza': ['Cheese', 'Tomato'], 'Burger': ['Lettuce', 'Onion']}
  final Map<String, List<String>> variantIngredients;

  /// Global ingredients (apply to all items in pack)
  /// Format: ['Salt', 'Pepper', 'Spices']
  final List<String> globalIngredients;

  /// Whether to show global ingredients at the end (after all items)
  final bool showGlobalAtEnd;

  PackIngredientConfig({
    this.variantIngredients = const {},
    this.globalIngredients = const [],
    this.showGlobalAtEnd = true,
  });

  factory PackIngredientConfig.fromJson(Map<String, dynamic> json) {
    final variantIngredientsMap = <String, List<String>>{};

    if (json['variant_ingredients'] is Map) {
      (json['variant_ingredients'] as Map).forEach((key, value) {
        if (value is List) {
          variantIngredientsMap[key.toString()] =
              value.map((e) => e.toString()).toList();
        }
      });
    }

    return PackIngredientConfig(
      variantIngredients: variantIngredientsMap,
      globalIngredients: json['global_ingredients'] is List
          ? (json['global_ingredients'] as List)
              .map((e) => e.toString())
              .toList()
          : [],
      showGlobalAtEnd: json['show_global_at_end'] ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'variant_ingredients': variantIngredients,
      'global_ingredients': globalIngredients,
      'show_global_at_end': showGlobalAtEnd,
    };
  }

  PackIngredientConfig copyWith({
    Map<String, List<String>>? variantIngredients,
    List<String>? globalIngredients,
    bool? showGlobalAtEnd,
  }) {
    return PackIngredientConfig(
      variantIngredients: variantIngredients ?? this.variantIngredients,
      globalIngredients: globalIngredients ?? this.globalIngredients,
      showGlobalAtEnd: showGlobalAtEnd ?? this.showGlobalAtEnd,
    );
  }

  /// Check if a variant has specific ingredients configured
  bool hasVariantIngredients(String variantName) {
    final ingredients = variantIngredients[variantName];
    return ingredients != null && ingredients.isNotEmpty;
  }

  /// Get ingredients for a specific variant
  List<String> getVariantIngredients(String variantName) {
    return variantIngredients[variantName] ?? [];
  }

  /// Check if there are any global ingredients
  bool get hasGlobalIngredients => globalIngredients.isNotEmpty;

  /// Check if there are any ingredients configured at all
  bool get hasAnyIngredients =>
      variantIngredients.isNotEmpty || globalIngredients.isNotEmpty;
}

/// User's ingredient preferences for a special pack
/// Tracks preferences per variant and per quantity instance
class PackIngredientPreferences {
  /// Variant-specific ingredient preferences
  /// Format: {
  ///   'Pizza': {
  ///     0: {'Cheese': 'wanted', 'Tomato': 'neutral'}
  ///   },
  ///   'Burger': {
  ///     0: {'Lettuce': 'wanted', 'Onion': 'unwanted'},
  ///     1: {'Lettuce': 'neutral', 'Onion': 'wanted'}
  ///   }
  /// }
  final Map<String, Map<int, Map<String, String>>> variantPreferences;

  /// Global ingredient preferences (not tied to specific items)
  /// Format: {'Salt': 'unwanted', 'Pepper': 'wanted'}
  final Map<String, String> globalPreferences;

  PackIngredientPreferences({
    this.variantPreferences = const {},
    this.globalPreferences = const {},
  });

  factory PackIngredientPreferences.fromJson(Map<String, dynamic> json) {
    final variantPrefs = <String, Map<int, Map<String, String>>>{};

    // Parse variant preferences
    if (json['variant_preferences'] is Map) {
      (json['variant_preferences'] as Map).forEach((variantName, quantityMap) {
        if (quantityMap is Map) {
          final qtyPrefs = <int, Map<String, String>>{};
          quantityMap.forEach((qtyIndex, ingredientsMap) {
            if (ingredientsMap is Map) {
              final ingPrefs = <String, String>{};
              ingredientsMap.forEach((ingredient, preference) {
                ingPrefs[ingredient.toString()] = preference.toString();
              });
              qtyPrefs[int.parse(qtyIndex.toString())] = ingPrefs;
            }
          });
          variantPrefs[variantName.toString()] = qtyPrefs;
        }
      });
    }

    // Parse global preferences
    final globalPrefs = <String, String>{};
    if (json['global_preferences'] is Map) {
      (json['global_preferences'] as Map).forEach((ingredient, preference) {
        globalPrefs[ingredient.toString()] = preference.toString();
      });
    }

    return PackIngredientPreferences(
      variantPreferences: variantPrefs,
      globalPreferences: globalPrefs,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'variant_preferences': variantPreferences,
      'global_preferences': globalPreferences,
    };
  }

  /// Get preference for a specific ingredient in a specific variant quantity
  String? getVariantIngredientPreference(
    String variantName,
    int quantityIndex,
    String ingredient,
  ) {
    return variantPreferences[variantName]?[quantityIndex]?[ingredient];
  }

  /// Set preference for a specific ingredient in a specific variant quantity
  void setVariantIngredientPreference(
    String variantName,
    int quantityIndex,
    String ingredient,
    String preference,
  ) {
    if (!variantPreferences.containsKey(variantName)) {
      variantPreferences[variantName] = {};
    }
    final variantPrefs = variantPreferences[variantName];
    if (variantPrefs != null && !variantPrefs.containsKey(quantityIndex)) {
      variantPrefs[quantityIndex] = {};
    }
    final quantityPrefs = variantPreferences[variantName]?[quantityIndex];
    if (quantityPrefs != null) {
      quantityPrefs[ingredient] = preference;
    }
  }

  /// Get global ingredient preference
  String? getGlobalIngredientPreference(String ingredient) {
    return globalPreferences[ingredient];
  }

  /// Set global ingredient preference
  void setGlobalIngredientPreference(String ingredient, String preference) {
    if (preference == 'neutral') {
      globalPreferences.remove(ingredient);
    } else {
      globalPreferences[ingredient] = preference;
    }
  }

  /// Check if any preferences are set
  bool get hasAnyPreferences =>
      variantPreferences.isNotEmpty || globalPreferences.isNotEmpty;

  /// Clear all preferences
  void clear() {
    variantPreferences.clear();
    globalPreferences.clear();
  }
}
