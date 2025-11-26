import 'package:flutter/foundation.dart';

/// Smart text detector that normalizes common typos, diacritics, and variations
/// to improve search matching and user experience
class SmartTextDetector {
  // Diacritics mapping for common accented characters
  static const Map<String, String> _diacriticsMap = {
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'å': 'a',
    'æ': 'ae',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'ø': 'o',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ý': 'y',
    'ÿ': 'y',
    'ñ': 'n',
    'ç': 'c',
    'À': 'A',
    'Á': 'A',
    'Â': 'A',
    'Ã': 'A',
    'Ä': 'A',
    'Å': 'A',
    'Æ': 'AE',
    'È': 'E',
    'É': 'E',
    'Ê': 'E',
    'Ë': 'E',
    'Ì': 'I',
    'Í': 'I',
    'Î': 'I',
    'Ï': 'I',
    'Ò': 'O',
    'Ó': 'O',
    'Ô': 'O',
    'Õ': 'O',
    'Ö': 'O',
    'Ø': 'O',
    'Ù': 'U',
    'Ú': 'U',
    'Û': 'U',
    'Ü': 'U',
    'Ý': 'Y',
    'Ÿ': 'Y',
    'Ñ': 'N',
    'Ç': 'C',
  };

  // Common typo patterns and their corrections
  static const Map<String, String> _typoPatterns = {
    // Double letter patterns
    'tion': 'tion', 'sion': 'sion', 'cion': 'tion',
    'ttion': 'tion', 'ssion': 'sion',

    // Common misspellings
    'reciepe': 'recipe', 'reciept': 'receipt', 'seperate': 'separate',
    'occured': 'occurred', 'begining': 'beginning', 'accomodate': 'accommodate',
    'definately': 'definitely', 'neccessary': 'necessary',
    'occassion': 'occasion',

    // Food-specific common mistakes
    'crepe': 'crepe', 'crépe': 'crepe', 'crepes': 'crepes', 'crépes': 'crepes',
    'pizza': 'pizza', 'piza': 'pizza', 'pizzza': 'pizza',
    'burger': 'burger', 'burguer': 'burger', 'burgar': 'burger',
    'sandwich': 'sandwich', 'sandwitch': 'sandwich', 'sandwiche': 'sandwich',
    'salad': 'salad', 'salade': 'salad', 'salat': 'salad',
    'pasta': 'pasta', 'pastas': 'pasta', 'pastaa': 'pasta',
    'soup': 'soup', 'soupe': 'soup', 'soop': 'soup',
    'coffee': 'coffee', 'coffe': 'coffee', 'cafe': 'coffee',
    'chicken': 'chicken', 'chiken': 'chicken', 'chikn': 'chicken',
    'beef': 'beef', 'beff': 'beef', 'beefs': 'beef',
    'fish': 'fish', 'fisch': 'fish', 'fishes': 'fish',

    // Algerian/French food terms
    'couscous': 'couscous', 'couscouss': 'couscous', 'couscouse': 'couscous',
    'tajine': 'tajine', 'tagine': 'tajine', 'tajin': 'tajine',
    'merguez': 'merguez', 'merguezs': 'merguez',
    'chorba': 'chorba', 'chorbas': 'chorba', 'chorbe': 'chorba',
    'brik': 'brik', 'bricks': 'brik', 'briq': 'brik',
    'makroudh': 'makroudh', 'makroud': 'makroudh', 'makrout': 'makroudh',
    'chakhchoukha': 'chakhchoukha', 'chakhchouka': 'chakhchoukha',
    'rechta': 'rechta', 'rechtaa': 'rechta',

    // Common letter substitutions
    'ph': 'f', 'gh': 'g', 'ck': 'k', 'qu': 'k',
    'x': 'ks', 'z': 's', 'c': 'k', 'q': 'k',
  };

  // Phonetic patterns for better matching
  static const Map<String, String> _phoneticPatterns = {
    'tion': 'shun',
    'sion': 'shun',
    'cian': 'shun',
    'ough': 'uff',
    'augh': 'aff',
    'eigh': 'ay',
    'ph': 'f',
    'gh': 'f',
    'ck': 'k',
    'qu': 'kw',
    'x': 'ks',
    'z': 's',
  };

  // Common abbreviations and their expansions
  static const Map<String, String> _abbreviations = {
    'pizza': 'pizza',
    'piz': 'pizza',
    'pz': 'pizza',
    'burger': 'burger',
    'burg': 'burger',
    'bg': 'burger',
    'sandwich': 'sandwich',
    'sand': 'sandwich',
    'sw': 'sandwich',
    'salad': 'salad',
    'sal': 'salad',
    'sl': 'salad',
    'pasta': 'pasta',
    'pas': 'pasta',
    'ps': 'pasta',
    'soup': 'soup',
    'sp': 'soup',
    'coffee': 'coffee',
    'caf': 'coffee',
    'cf': 'coffee',
    'chicken': 'chicken',
    'chick': 'chicken',
    'chk': 'chicken',
    'beef': 'beef',
    'bf': 'beef',
    'fish': 'fish',
    'fs': 'fish',
  };

  // Cache for normalized text to avoid reprocessing
  static final Map<String, String> _normalizationCache = {};

  /// Normalize text by removing diacritics and applying common corrections
  static String normalizeText(String text) {
    if (text.isEmpty) return text;

    // Check cache first
    if (_normalizationCache.containsKey(text)) {
      return _normalizationCache[text]!;
    }

    String normalized = text.toLowerCase().trim();

    // Step 1: Remove diacritics
    normalized = _removeDiacritics(normalized);

    // Step 2: Apply typo corrections
    normalized = _applyTypoCorrections(normalized);

    // Step 3: Normalize common patterns
    normalized = _normalizePatterns(normalized);

    // Step 4: Remove extra spaces and special characters
    normalized = _cleanText(normalized);

    // Cache the result
    _normalizationCache[text] = normalized;

    // Only log for non-cached results to reduce spam (and only in debug mode)
    if (kDebugMode && _normalizationCache.length < 100) {
      debugPrint('🔍 SmartTextDetector: "$text" -> "$normalized"');
    }

    return normalized;
  }

  // Cache for search variations to avoid regenerating
  static final Map<String, List<String>> _variationsCache = {};

  /// Clear all caches (useful for memory management)
  static void clearCache() {
    _normalizationCache.clear();
    _variationsCache.clear();
  }

  /// Generate multiple variations of a search term for better matching
  static List<String> generateSearchVariations(String query) {
    if (query.isEmpty) return [query];

    // Check cache first
    if (_variationsCache.containsKey(query)) {
      return _variationsCache[query]!;
    }

    final variations = <String>{};
    final normalized = normalizeText(query);

    // Add the normalized version
    variations.add(normalized);

    // Add original (cleaned)
    variations.add(_cleanText(query.toLowerCase()));

    // Add phonetic variations
    variations.addAll(_generatePhoneticVariations(normalized));

    // Add abbreviation variations
    variations.addAll(_generateAbbreviationVariations(normalized));

    // Add common misspelling variations
    variations.addAll(_generateMisspellingVariations(normalized));

    final result = variations.toList();

    // Cache the result
    _variationsCache[query] = result;

    return result;
  }

  /// Check if two texts are similar using smart matching
  static bool isSimilar(String text1, String text2) {
    if (text1.isEmpty || text2.isEmpty) return false;

    final normalized1 = normalizeText(text1);
    final normalized2 = normalizeText(text2);

    // Exact match after normalization
    if (normalized1 == normalized2) return true;

    // Check if one contains the other
    if (normalized1.contains(normalized2) ||
        normalized2.contains(normalized1)) {
      return true;
    }

    // Check similarity using Levenshtein distance
    final distance = _levenshteinDistance(normalized1, normalized2);
    final maxLength = normalized1.length > normalized2.length
        ? normalized1.length
        : normalized2.length;
    final similarity = 1.0 - (distance / maxLength);

    return similarity > 0.7; // 70% similarity threshold
  }

  /// Find the best match from a list of options
  static String? findBestMatch(String query, List<String> options) {
    if (query.isEmpty || options.isEmpty) return null;

    final normalizedQuery = normalizeText(query);
    String? bestMatch;
    double bestScore = 0.0;

    for (final option in options) {
      final normalizedOption = normalizeText(option);

      // Exact match
      if (normalizedQuery == normalizedOption) {
        return option;
      }

      // Calculate similarity score
      final distance = _levenshteinDistance(normalizedQuery, normalizedOption);
      final maxLength = normalizedQuery.length > normalizedOption.length
          ? normalizedQuery.length
          : normalizedOption.length;
      final similarity = 1.0 - (distance / maxLength);

      if (similarity > bestScore && similarity > 0.6) {
        bestScore = similarity;
        bestMatch = option;
      }
    }

    return bestMatch;
  }

  // Private helper methods

  static String _removeDiacritics(String text) {
    String result = text;
    for (final entry in _diacriticsMap.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }
    return result;
  }

  static String _applyTypoCorrections(String text) {
    String result = text;

    // Apply typo patterns (longer patterns first)
    final sortedPatterns = _typoPatterns.entries.toList()
      ..sort((a, b) => b.key.length.compareTo(a.key.length));

    for (final entry in sortedPatterns) {
      result = result.replaceAll(entry.key, entry.value);
    }

    return result;
  }

  static String _normalizePatterns(String text) {
    String result = text;

    // Normalize common patterns
    for (final entry in _phoneticPatterns.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }

    return result;
  }

  static String _cleanText(String text) {
    return text
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove special characters
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize whitespace
        .trim();
  }

  static List<String> _generatePhoneticVariations(String text) {
    final variations = <String>{};

    for (final entry in _phoneticPatterns.entries) {
      if (text.contains(entry.key)) {
        variations.add(text.replaceAll(entry.key, entry.value));
      }
    }

    return variations.toList();
  }

  static List<String> _generateAbbreviationVariations(String text) {
    final variations = <String>{};

    for (final entry in _abbreviations.entries) {
      if (text.contains(entry.key)) {
        variations.add(text.replaceAll(entry.key, entry.value));
      }
    }

    return variations.toList();
  }

  static List<String> _generateMisspellingVariations(String text) {
    final variations = <String>{};

    // Generate common misspellings
    for (final entry in _typoPatterns.entries) {
      if (text.contains(entry.value)) {
        variations.add(text.replaceAll(entry.value, entry.key));
      }
    }

    return variations.toList();
  }

  static int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final matrix = List.generate(
      s1.length + 1,
      (i) => List.generate(s2.length + 1, (j) => 0),
    );

    for (int i = 0; i <= s1.length; i++) {
      matrix[i][0] = i;
    }

    for (int j = 0; j <= s2.length; j++) {
      matrix[0][j] = j;
    }

    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1, // deletion
          matrix[i][j - 1] + 1, // insertion
          matrix[i - 1][j - 1] + cost, // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[s1.length][s2.length];
  }
}
