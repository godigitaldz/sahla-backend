// ignore_for_file: prefer_foreach

import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for managing service images from Supabase storage
/// Performance-optimized with aggressive caching and minimal string operations
class ServiceImagesService {
  static SupabaseClient get _supabase => Supabase.instance.client;

  // Performance: Cache for images URLs (unbounded cache OK for small set of categories/cuisines)
  static final Map<String, String> _imageCache = {};

  // Performance: Cache base URLs to avoid repeated _supabase.storage lookups
  static String? _categoriesBaseUrl;
  static String? _cuisinesBaseUrl;
  static String? _promoCodesBaseUrl;

  /// Clear all cached URLs (useful for testing or if images are updated)
  static void clearCache() {
    _imageCache.clear();
    _categoriesBaseUrl = null;
    _cuisinesBaseUrl = null;
    _promoCodesBaseUrl = null;
  }

  static String get _categoriesUrl {
    if (_categoriesBaseUrl == null) {
      final url = _supabase.storage.from('categories').getPublicUrl('');
      // Remove trailing slash only
      _categoriesBaseUrl =
          url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    }
    return _categoriesBaseUrl!;
  }

  static String get _cuisinesUrl {
    if (_cuisinesBaseUrl == null) {
      final url = _supabase.storage.from('cuisines').getPublicUrl('');
      // Remove trailing slash only
      _cuisinesBaseUrl =
          url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    }
    return _cuisinesBaseUrl!;
  }

  static String get _promoCodesUrl {
    if (_promoCodesBaseUrl == null) {
      final url = _supabase.storage.from('promo-codes').getPublicUrl('');
      // Remove trailing slash only
      _promoCodesBaseUrl =
          url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    }
    return _promoCodesBaseUrl!;
  }

  /// Build a locale-aware promo code image URL from the `promo-codes` bucket.
  /// Naming rules:
  /// - English: `${code}_ang.png`
  /// - French:  `${code}_fr.png`
  /// - Arabic:  `${code}_ar.png`
  /// - Universal (fallback): `${code}.png`
  /// All file names are lowercase.
  static String getLocalizedPromoCodeImageUrl(String promoCode, String locale) {
    final normalizedCode = promoCode.toLowerCase();
    final cacheKey = 'promo:$normalizedCode:$locale';
    if (_imageCache.containsKey(cacheKey)) {
      return _imageCache[cacheKey]!;
    }

    // Decide suffix by locale
    String suffix;
    if (locale.startsWith('fr')) {
      suffix = '_fr';
    } else if (locale.startsWith('ar')) {
      suffix = '_ar';
    } else {
      suffix = '_ang';
    }

    final localizedName = '$normalizedCode$suffix.png';
    // Performance: Use cached base URL
    final encodedName = Uri.encodeComponent(localizedName);
    final url = '$_promoCodesUrl/$encodedName';

    _imageCache[cacheKey] = url;
    return url;
  }

  /// Build a universal promo code image URL with smart text detection
  static String getUniversalPromoCodeImageUrl(String promoCode) {
    final cacheKey = 'promo:$promoCode:universal';
    if (_imageCache.containsKey(cacheKey)) {
      return _imageCache[cacheKey]!;
    }

    // Try multiple strategies for smart matching
    final strategies = [
      // Strategy 1: Original casing with spaces replaced by underscores
      promoCode.trim().replaceAll(' ', '_'),
      // Strategy 2: Original casing with & replaced by 'and' and spaces by underscores
      promoCode.trim().replaceAll('&', 'and').replaceAll(' ', '_'),
      // Strategy 3: Smart normalized (handles e=é, etc.)
      _normalizeForSmartMatching(promoCode),
      // Strategy 4: Uppercase with spaces replaced by underscores
      promoCode.trim().toUpperCase().replaceAll(' ', '_'),
      // Strategy 5: Title case with spaces replaced by underscores
      _toTitleCase(promoCode.trim()).replaceAll(' ', '_'),
      // Strategy 6: Lowercase with underscores
      promoCode.trim().toLowerCase().replaceAll(' ', '_'),
      // Strategy 7: Original aggressive normalization
      promoCode
          .trim()
          .toLowerCase()
          .replaceAll('&', 'and')
          .replaceAll(RegExp(r"[\s-]+"), "_")
          .replaceAll(RegExp("[^a-z0-9_]+"), "")
          .replaceAll(RegExp("_+"), "_")
          .replaceAll(RegExp(r"^_+|_+$"), ""),
    ];

    // Return the first strategy result (original casing)
    final objectName = '${strategies.first}.png';
    // Performance: Use cached base URL
    final encodedName = Uri.encodeComponent(objectName);
    final url = '$_promoCodesUrl/$encodedName';

    _imageCache[cacheKey] = url;
    return url;
  }

  /// Build a locale-aware category image URL from the `categories` bucket.
  /// Naming rules:
  /// - English: `${category}_ang.png`
  /// - French:  `${category}_fr.png`
  /// - Arabic:  `${category}_ar.png`
  /// - Universal (fallback): `${category}.png`
  /// All file names are lowercase.
  static String getLocalizedCategoryImageUrl(String category, String locale) {
    // Apply custom character mapping: e=é, é=e, space=_
    String customCharacterMapping(String text) {
      return text
          // Custom mapping: e=é, é=e, space=_
          .replaceAll('e', 'é')
          .replaceAll('é', 'e')
          .replaceAll(' ', '_');
    }

    final normalizedCategory = customCharacterMapping(category.toLowerCase());
    final cacheKey = 'category:$normalizedCategory:$locale';
    if (_imageCache.containsKey(cacheKey)) {
      return _imageCache[cacheKey]!;
    }

    // Decide suffix by locale
    String suffix;
    if (locale.startsWith('fr')) {
      suffix = '_fr';
    } else if (locale.startsWith('ar')) {
      suffix = '_ar';
    } else {
      suffix = '_ang';
    }

    final localizedName = '$normalizedCategory$suffix.png';
    // Performance: Use cached base URL
    final encodedName = Uri.encodeComponent(localizedName);
    final url = '$_categoriesUrl/$encodedName';

    _imageCache[cacheKey] = url;
    return url;
  }

  /// Convert text to title case (first letter of each word capitalized)
  static String _toTitleCase(String text) {
    if (text.isEmpty) return text;

    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  /// Normalize text for smart matching (handles e=é, a=à, etc.)
  static String _normalizeForSmartMatching(String text) {
    return text
        .toLowerCase()
        // French accents
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('à', 'a')
        .replaceAll('á', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('ç', 'c')
        .replaceAll('ù', 'u')
        .replaceAll('ú', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('î', 'i')
        .replaceAll('í', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ô', 'o')
        .replaceAll('ó', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ñ', 'n')
        // Spanish accents
        .replaceAll('ñ', 'n')
        .replaceAll('ü', 'u')
        // German umlauts
        .replaceAll('ä', 'a')
        .replaceAll('ö', 'o')
        .replaceAll('ü', 'u')
        .replaceAll('ß', 'ss')
        // Italian accents
        .replaceAll('à', 'a')
        .replaceAll('è', 'e')
        .replaceAll('é', 'e')
        .replaceAll('ì', 'i')
        .replaceAll('ò', 'o')
        .replaceAll('ù', 'u')
        // Portuguese accents
        .replaceAll('ã', 'a')
        .replaceAll('õ', 'o')
        .replaceAll('ç', 'c')
        // Special characters and symbols
        .replaceAll('&', 'and')
        .replaceAll('+', 'plus')
        .replaceAll('@', 'at')
        .replaceAll('#', 'hash')
        .replaceAll('%', 'percent')
        .replaceAll(r'$', 'dollar')
        .replaceAll('€', 'euro')
        .replaceAll('£', 'pound')
        .replaceAll('¥', 'yen')
        .replaceAll('°', 'degree')
        .replaceAll('™', 'tm')
        .replaceAll('®', 'r')
        .replaceAll('©', 'c')
        // Punctuation and separators
        .replaceAll(' ', '_')
        .replaceAll('-', '_')
        .replaceAll('.', '_')
        .replaceAll(',', '_')
        .replaceAll(':', '_')
        .replaceAll(';', '_')
        .replaceAll('!', '_')
        .replaceAll('?', '_')
        .replaceAll('(', '_')
        .replaceAll(')', '_')
        .replaceAll('[', '_')
        .replaceAll(']', '_')
        .replaceAll('{', '_')
        .replaceAll('}', '_')
        .replaceAll('"', '_')
        .replaceAll("'", '_')
        .replaceAll('`', '_')
        .replaceAll('~', '_')
        .replaceAll('|', '_')
        .replaceAll(r'\', '_')
        .replaceAll('/', '_')
        // Clean up multiple underscores and trim
        .replaceAll(RegExp('[^a-z0-9_]'), '')
        .replaceAll(RegExp('_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  /// Build a universal category image URL with smart text detection
  /// Performance: Optimized with minimal string operations and caching
  static String getUniversalCategoryImageUrl(String category) {
    final cacheKey = 'category:$category:universal';
    if (_imageCache.containsKey(cacheKey)) {
      return _imageCache[cacheKey]!;
    }

    // Performance: Use single-pass custom character mapping (e=é, é=e, space=_)
    final trimmed = category.trim();
    final customMapped = _customCharacterMappingFast(trimmed);
    final objectName = '$customMapped.png';

    // Performance: Use cached base URL instead of repeated storage lookups
    final encodedName = Uri.encodeComponent(objectName);
    final url = '$_categoriesUrl/$encodedName';

    _imageCache[cacheKey] = url;
    return url;
  }

  /// Performance: Fast custom character mapping with minimal operations
  /// Removes accents and replaces spaces with underscores
  static String _customCharacterMappingFast(String text) {
    // Single pass: remove accents (é→e, è→e, etc.) and space→underscore
    final buffer = StringBuffer();
    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      // Remove French accents
      if (char == 'é' || char == 'è' || char == 'ê' || char == 'ë') {
        buffer.write('e');
      } else if (char == 'É' || char == 'È' || char == 'Ê' || char == 'Ë') {
        buffer.write('E');
      } else if (char == 'à' || char == 'á' || char == 'â' || char == 'ä') {
        buffer.write('a');
      } else if (char == 'À' || char == 'Á' || char == 'Â' || char == 'Ä') {
        buffer.write('A');
      } else if (char == ' ') {
        buffer.write('_');
      } else {
        buffer.write(char);
      }
    }
    return buffer.toString();
  }

  /// Build a category image URL preserving original casing and replacing spaces with underscores.
  /// Example: "Fruits De Mer" -> "Fruits_De_Mer.png"
  /// Performance: Optimized with caching and fast character mapping
  static String getCategoryImageUrlWithUnderscores(String category) {
    final cacheKey = 'category:${category}_underscores';
    if (_imageCache.containsKey(cacheKey)) {
      return _imageCache[cacheKey]!;
    }

    final name = _customCharacterMappingFast(category.trim());
    final encodedName = Uri.encodeComponent('$name.png');
    final url = '$_categoriesUrl/$encodedName';

    _imageCache[cacheKey] = url;
    return url;
  }

  /// Build a category image URL preserving original spacing exactly.
  /// Example: "Malfouf (2)" -> "Malfouf (2).png"
  /// Performance: Optimized with caching and fast character mapping
  static String getCategoryImageUrlWithSpaces(String category) {
    final cacheKey = 'category:${category}_spaces';
    if (_imageCache.containsKey(cacheKey)) {
      return _imageCache[cacheKey]!;
    }

    final name = _customCharacterMappingFast(category.trim());
    final encodedName = Uri.encodeComponent('$name.png');
    final url = '$_categoriesUrl/$encodedName';

    _imageCache[cacheKey] = url;
    return url;
  }

  /// Build a locale-aware cuisine image URL from the `cuisines` bucket.
  /// Naming rules:
  /// - English: `${cuisine}_ang.png`
  /// - French:  `${cuisine}_fr.png`
  /// - Arabic:  `${cuisine}_ar.png`
  /// - Universal: `${cuisine}.png`
  /// All file names are lowercase with spaces replaced by underscores.
  static String getLocalizedCuisineImageUrl(String cuisine, String locale) {
    // Normalize cuisine key to match storage naming:
    // - lowercase
    // - replace '&' with 'and'
    // - spaces/hyphens -> '_'
    // - strip non [a-z0-9_]
    // - collapse multiple '_' and trim leading/trailing '_'
    String normalized = cuisine.trim().toLowerCase();
    normalized = normalized.replaceAll('&', 'and');
    normalized = normalized.replaceAll(RegExp(r"[\s-]+"), "_");
    normalized = normalized.replaceAll(RegExp("[^a-z0-9_]+"), "");
    normalized = normalized.replaceAll(RegExp("_+"), "_");
    normalized = normalized.replaceAll(RegExp(r"^_+|_+$"), "");
    final cacheKey = 'cuisine:$normalized:$locale';
    if (_imageCache.containsKey(cacheKey)) {
      return _imageCache[cacheKey]!;
    }

    String suffix;
    if (locale.startsWith('fr')) {
      suffix = '_fr';
    } else if (locale.startsWith('ar')) {
      suffix = '_ar';
    } else {
      suffix = '_ang';
    }

    final localizedName = '$normalized$suffix.png';
    // URL-encode the object name to handle special characters
    final encodedName = Uri.encodeComponent(localizedName);
    final url = _supabase.storage.from('cuisines').getPublicUrl(encodedName);
    _imageCache[cacheKey] = url;
    return url;
  }

  /// Build a universal cuisine image URL with smart text detection - OPTIMIZED
  static String getUniversalCuisineImageUrl(String cuisine) {
    final cacheKey = 'cuisine:$cuisine:universal';
    if (_imageCache.containsKey(cacheKey)) {
      return _imageCache[cacheKey]!;
    }

    // Helper function to normalize accented characters while preserving casing
    String normalizeAccentsPreserveCase(String text) {
      return text
          // French accents (preserve case)
          .replaceAll('É', 'E')
          .replaceAll('È', 'E')
          .replaceAll('Ê', 'E')
          .replaceAll('Ë', 'E')
          .replaceAll('é', 'e')
          .replaceAll('è', 'e')
          .replaceAll('ê', 'e')
          .replaceAll('ë', 'e')
          .replaceAll('À', 'A')
          .replaceAll('Á', 'A')
          .replaceAll('Â', 'A')
          .replaceAll('Ä', 'A')
          .replaceAll('à', 'a')
          .replaceAll('á', 'a')
          .replaceAll('â', 'a')
          .replaceAll('ä', 'a')
          .replaceAll('Ç', 'C')
          .replaceAll('ç', 'c')
          .replaceAll('Ù', 'U')
          .replaceAll('Ú', 'U')
          .replaceAll('Û', 'U')
          .replaceAll('Ü', 'U')
          .replaceAll('ù', 'u')
          .replaceAll('ú', 'u')
          .replaceAll('û', 'u')
          .replaceAll('ü', 'u')
          .replaceAll('Î', 'I')
          .replaceAll('Í', 'I')
          .replaceAll('Ï', 'I')
          .replaceAll('î', 'i')
          .replaceAll('í', 'i')
          .replaceAll('ï', 'i')
          .replaceAll('Ô', 'O')
          .replaceAll('Ó', 'O')
          .replaceAll('Ö', 'O')
          .replaceAll('ô', 'o')
          .replaceAll('ó', 'o')
          .replaceAll('ö', 'o')
          .replaceAll('Ñ', 'N')
          .replaceAll('ñ', 'n');
    }

    // Try multiple strategies for smart matching - RESTORED
    final strategies = [
      // Strategy 1: Original casing with accents normalized and spaces replaced by underscores
      normalizeAccentsPreserveCase(cuisine.trim()).replaceAll(' ', '_'),
      // Strategy 2: Original casing with & replaced by 'And' (capital A) and spaces by underscores
      cuisine.trim().replaceAll('&', 'And').replaceAll(' ', '_'),
      // Strategy 3: Original casing with & replaced by 'and' and spaces by underscores
      cuisine.trim().replaceAll('&', 'and').replaceAll(' ', '_'),
      // Strategy 4: Smart normalized (handles e=é, etc.)
      _normalizeForSmartMatching(cuisine),
      // Strategy 5: Uppercase with spaces replaced by underscores
      cuisine.trim().toUpperCase().replaceAll(' ', '_'),
      // Strategy 6: Title case with spaces replaced by underscores
      _toTitleCase(cuisine.trim()).replaceAll(' ', '_'),
      // Strategy 7: Lowercase with underscores
      cuisine.trim().toLowerCase().replaceAll(' ', '_'),
      // Strategy 8: Original aggressive normalization
      cuisine
          .trim()
          .toLowerCase()
          .replaceAll('&', 'and')
          .replaceAll(RegExp(r"[\s-]+"), "_")
          .replaceAll(RegExp("[^a-z0-9_]+"), "")
          .replaceAll(RegExp("_+"), "_")
          .replaceAll(RegExp(r"^_+|_+$"), ""),
    ];

    // Performance: Choose the best strategy based on cuisine content (no debug logging)
    String selectedStrategy;

    if (cuisine.contains('&')) {
      // For cuisines with "&", use Strategy 2 (& → And conversion)
      // This handles: Milkshakes & Cocktails → Milkshakes_And_Cocktails
      selectedStrategy = strategies[1];
    } else {
      // For other cuisines, use Strategy 1 (accent normalization)
      // This handles: salés → sales
      selectedStrategy = strategies[0];
    }

    // Performance: Use cached base URL instead of repeated storage lookups
    final encodedName = Uri.encodeComponent('$selectedStrategy.png');
    final url = '$_cuisinesUrl/$encodedName';

    _imageCache[cacheKey] = url;
    return url;
  }
}
