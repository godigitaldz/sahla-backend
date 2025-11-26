/// Helper class for smart drink image detection
/// Analyzes drink names and finds best matching images from the drink images bucket
class DrinkImageDetector {
  // Base URL for drink images storage
  static const String _baseUrl =
      'https://your-supabase-project.supabase.co/storage/v1/object/public/drink_images';

  /// Detect and return the appropriate drink image URL
  /// Returns either a full URL or 'DRINK_NAME:drinkName' if no image found
  static String detectDrinkImage(String drinkName, [String? flavor]) {
    final fullDrinkText = flavor != null ? '$drinkName $flavor' : drinkName;
    final drinkNameLower = drinkName.toLowerCase();
    final flavorLower = flavor?.toLowerCase();
    final fullTextLower = fullDrinkText.toLowerCase();

    final drinkImageMap = _getDrinkImageMap();

    // Step 1: Try exact matches first
    if (drinkImageMap.containsKey(drinkNameLower)) {
      return '$_baseUrl/${drinkImageMap[drinkNameLower]}';
    }

    // Step 2: Try flavor-specific combinations
    if (flavorLower != null) {
      final flavorKey = '${drinkNameLower}_$flavorLower';
      if (drinkImageMap.containsKey(flavorKey)) {
        return '$_baseUrl/${drinkImageMap[flavorKey]}';
      }
    }

    // Step 3: Smart keyword detection
    final keywords = _extractDrinkKeywords(fullTextLower);
    for (final keyword in keywords) {
      if (drinkImageMap.containsKey(keyword)) {
        return '$_baseUrl/${drinkImageMap[keyword]}';
      }

      // Try partial matches
      for (final entry in drinkImageMap.entries) {
        if (entry.key.contains(keyword) || keyword.contains(entry.key)) {
          return '$_baseUrl/${entry.value}';
        }
      }
    }

    // Step 4: Brand detection
    final brand = _detectDrinkBrand(fullTextLower);
    if (brand != null && drinkImageMap.containsKey(brand)) {
      return '$_baseUrl/${drinkImageMap[brand]}';
    }

    // Step 5: Category-based fallback
    return _getCategoryFallback(fullTextLower, drinkName);
  }

  /// Get comprehensive drink image mapping
  static Map<String, String> _getDrinkImageMap() {
    return {
      // International Brands - Coca Cola
      'coca': 'coca_cola_100x100.png',
      'coca_cola': 'coca_cola_100x100.png',
      'coca-cola': 'coca_cola_100x100.png',
      'cocacola': 'coca_cola_100x100.png',
      'coke': 'coca_cola_100x100.png',
      'coca_cola_zero': 'coca_cola_zero_100x100.png',
      'coca_zero': 'coca_cola_zero_100x100.png',
      'coke_zero': 'coca_cola_zero_100x100.png',
      'coca_cola_light': 'coca_cola_zero_100x100.png',
      'coke_light': 'coca_cola_zero_100x100.png',
      'coca_cola_cherry': 'coca_cola_cherry_100x100.png',
      'coke_cherry': 'coca_cola_cherry_100x100.png',
      'coca_cola_lemon': 'coca_cola_lemon_100x100.png',
      'coke_lemon': 'coca_cola_lemon_100x100.png',

      // Pepsi
      'pepsi': 'pepsi_100x100.png',
      'pepsi_regular': 'pepsi_100x100.png',
      'pepsi_max': 'pepsi_max_100x100.png',
      'pepsi_zero': 'pepsi_zero_100x100.png',
      'pepsi_light': 'pepsi_zero_100x100.png',

      // Sprite
      'sprite': 'sprite_100x100.png',
      'sprite_regular': 'sprite_100x100.png',
      'sprite_zero': 'sprite_zero_100x100.png',
      'sprite_light': 'sprite_zero_100x100.png',

      // Fanta
      'fanta': 'fanta_100x100.png',
      'fanta_orange': 'fanta_100x100.png',
      'fanta_lemon': 'fanta_lemon_100x100.png',
      'fanta_citron': 'fanta_lemon_100x100.png',

      // Red Bull
      'red': 'red_bull_100x100.png',
      'red_bull': 'red_bull_100x100.png',
      'redbull': 'red_bull_100x100.png',

      // Juices
      'orange': 'orange_juice_100x100.png',
      'orange_juice': 'orange_juice_100x100.png',
      'jus_orange': 'orange_juice_100x100.png',
      'apple': 'apple_juice_100x100.png',
      'apple_juice': 'apple_juice_100x100.png',
      'jus_pomme': 'apple_juice_100x100.png',
      'jus': 'orange_juice_100x100.png',
      'juice': 'orange_juice_100x100.png',

      // Water
      'water': 'water_100x100.png',
      'eau': 'water_100x100.png',
      'mineral': 'mineral_water_100x100.png',
      'mineral_water': 'mineral_water_100x100.png',
      'eau_mineral': 'mineral_water_100x100.png',
      'sparkling': 'sparkling_water_100x100.png',
      'sparkling_water': 'sparkling_water_100x100.png',
      'eau_gazeuse': 'sparkling_water_100x100.png',

      // Algerian Local Brands
      'selecto': 'selecto_100x100.png',
      'ifri': 'ifri_water_100x100.png',
      'ifri_eau': 'ifri_water_100x100.png',
      'rouiba': 'rouiba_100x100.png',
      'ngaous': 'ngaous_100x100.png',
      'n_gaous': 'ngaous_100x100.png',
      'n\'gaous': 'ngaous_100x100.png',
      'hamoud': 'hamoud_100x100.png',
      'biskra': 'biskra_100x100.png',
      'oum': 'oum_100x100.png',
      'oum_eau': 'oum_100x100.png',

      // Coffee & Tea
      'coffee': 'coffee_100x100.png',
      'cafe': 'coffee_100x100.png',
      'tea': 'tea_100x100.png',
      'the': 'tea_100x100.png',

      // Milk & Dairy
      'milk': 'milk_100x100.png',
      'lait': 'milk_100x100.png',
      'yogurt': 'yogurt_100x100.png',
      'yaourt': 'yogurt_100x100.png',
    };
  }

  /// Extract meaningful keywords from drink name/text
  static List<String> _extractDrinkKeywords(String text) {
    final keywords = <String>[];

    // Common drink keywords
    final drinkWords = [
      'coca',
      'cola',
      'pepsi',
      'sprite',
      'fanta',
      'red',
      'bull',
      'orange',
      'apple',
      'juice',
      'jus',
      'water',
      'eau',
      'mineral',
      'sparkling',
      'gazeuse',
      'coffee',
      'cafe',
      'tea',
      'the',
      'milk',
      'lait',
      'selecto',
      'ifri',
      'rouiba',
      'ngaous',
      'hamoud'
    ];

    for (final word in drinkWords) {
      if (text.contains(word)) {
        keywords.add(word);
      }
    }

    // Add modifier keywords
    if (text.contains('zero') ||
        text.contains('light') ||
        text.contains('diet')) {
      keywords.add('zero');
    }
    if (text.contains('cherry') || text.contains('cerise')) {
      keywords.add('cherry');
    }
    if (text.contains('lemon') || text.contains('citron')) {
      keywords.add('lemon');
    }

    return keywords;
  }

  /// Detect drink brand from text
  static String? _detectDrinkBrand(String text) {
    final brands = {
      'coca': 'coca_cola',
      'pepsi': 'pepsi',
      'sprite': 'sprite',
      'fanta': 'fanta',
      'red': 'red_bull',
      'selecto': 'selecto',
      'ifri': 'ifri_water',
      'rouiba': 'rouiba',
      'ngaous': 'ngaous',
    };

    for (final brand in brands.keys) {
      if (text.contains(brand)) {
        return brands[brand];
      }
    }

    return null;
  }

  /// Get category-based fallback image
  static String _getCategoryFallback(String text, String drinkName) {
    if (text.contains('cola') ||
        text.contains('pepsi') ||
        text.contains('sprite') ||
        text.contains('fanta')) {
      return '$_baseUrl/coca_cola_100x100.png';
    }
    if (text.contains('juice') ||
        text.contains('jus') ||
        text.contains('orange') ||
        text.contains('apple')) {
      return '$_baseUrl/orange_juice_100x100.png';
    }
    if (text.contains('water') ||
        text.contains('eau') ||
        text.contains('mineral')) {
      return '$_baseUrl/water_100x100.png';
    }
    if (text.contains('coffee') || text.contains('cafe')) {
      return '$_baseUrl/coffee_100x100.png';
    }
    if (text.contains('tea') || text.contains('the')) {
      return '$_baseUrl/tea_100x100.png';
    }

    // Return special marker for drink name display
    return 'DRINK_NAME:$drinkName';
  }
}
