import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/menu_item.dart';
import '../models/search_result.dart';
import '../models/search_suggestion.dart';
import '../utils/performance_utils.dart';
import 'category_service.dart';
import 'menu_item_service.dart';
// Redis optimized service removed
import 'restaurant_service.dart';

// RestaurantSearchFilter class
class RestaurantSearchFilter {
  final String? cuisine;
  final String? category;
  final double? minPrice;
  final double? maxPrice;
  final double? minRating;
  final double? maxDistance;
  final bool? isOpen;
  final String? sortBy;

  const RestaurantSearchFilter({
    this.cuisine,
    this.category,
    this.minPrice,
    this.maxPrice,
    this.minRating,
    this.maxDistance,
    this.isOpen,
    this.sortBy,
  });

  RestaurantSearchFilter copyWith({
    String? cuisine,
    String? category,
    double? minPrice,
    double? maxPrice,
    double? minRating,
    double? maxDistance,
    bool? isOpen,
    String? sortBy,
  }) {
    return RestaurantSearchFilter(
      cuisine: cuisine ?? this.cuisine,
      category: category ?? this.category,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      minRating: minRating ?? this.minRating,
      maxDistance: maxDistance ?? this.maxDistance,
      isOpen: isOpen ?? this.isOpen,
      sortBy: sortBy ?? this.sortBy,
    );
  }
}

/// 🧠 Smart Search Service with AI-powered features
/// Implements intelligent search with typo correction, synonyms, ranking, and learning
class SmartSearchService extends ChangeNotifier {
  static final SmartSearchService _instance = SmartSearchService._internal();
  factory SmartSearchService() => _instance;
  SmartSearchService._internal() {
    // Initialize debounced search using PerformanceUtils
    _debouncedSearch = PerformanceUtils.debounce(
      (String query,
              {Position? userLocation,
              RestaurantSearchFilter? filters,
              bool isVoiceSearch = false}) =>
          _performSearch(query,
              userLocation: userLocation,
              filters: _convertFilterToMap(filters),
              isVoiceSearch: isVoiceSearch),
      _debounceDelay,
    );
  }

  // Core services
  SharedPreferences? _prefs;
  final RestaurantService _restaurantService = RestaurantService();
  final MenuItemService _menuItemService = MenuItemService();
  final CategoryService _categoryService = CategoryService();

  // Convert RestaurantSearchFilter to Map for internal use
  Map<String, dynamic>? _convertFilterToMap(RestaurantSearchFilter? filter) {
    if (filter == null) return null;
    return {
      'cuisine': filter.cuisine,
      'category': filter.category,
      'minPrice': filter.minPrice,
      'maxPrice': filter.maxPrice,
      'minRating': filter.minRating,
      'maxDistance': filter.maxDistance,
      'isOpen': filter.isOpen,
      'sortBy': filter.sortBy,
    };
  }

  // Search state
  String _currentQuery = '';
  List<SearchResult> _results = [];
  final List<SearchSuggestion> _suggestions = [];
  bool _isSearching = false;
  String? _error;

  // Smart features
  final Map<String, List<String>> _synonyms = {};
  final Map<String, int> _queryPopularity = {};
  final Map<String, List<String>> _userSearchHistory = {};
  final Map<String, Map<String, double>> _personalizedScores = {};
  final Set<String> _noResultQueries = {};

  // Performance optimization
  late Function _debouncedSearch;
  final Map<String, SearchCacheEntry> _searchCache = {};
  static const Duration _cacheExpiry = Duration(minutes: 5);
  static const Duration _debounceDelay =
      Duration(milliseconds: 100); // Reduced for faster response

  // Getters
  String get currentQuery => _currentQuery;
  List<SearchResult> get results => _results;
  List<SearchSuggestion> get suggestions => _suggestions;
  bool get isSearching => _isSearching;
  String? get error => _error;

  /// Initialize the smart search service
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadSynonyms();
      await _loadUserData();

      // Debug: Check if there are any menu items in the database
      await _debugCheckMenuItems();

      debugPrint('🧠 Smart Search Service initialized');
    } catch (e) {
      debugPrint('❌ Error initializing Smart Search Service: $e');
    }
  }

  /// 🔍 Debug method to check if menu items exist in the database
  Future<void> _debugCheckMenuItems() async {
    try {
      debugPrint('🔍 Checking if menu items exist in database...');

      // Try to get featured menu items
      final featuredItems = await _menuItemService.getFeaturedMenuItems();
      debugPrint('📊 Featured menu items found: ${featuredItems.length}');

      if (featuredItems.isNotEmpty) {
        debugPrint('✅ Sample featured menu items:');
        featuredItems.take(3).forEach((item) {
          debugPrint('   - ${item.name} (${item.category}) - \$${item.price}');
        });
      } else {
        debugPrint(
            '⚠️ No featured menu items found. Trying direct database query...');

        // Try direct database query
        final supabase = Supabase.instance.client;
        final response = await supabase
            .from('menu_items')
            .select('id, name, category, price, is_available')
            .limit(5);

        debugPrint(
            '🗄️ Direct database query result: ${response.length} items');
        if (response.isNotEmpty) {
          debugPrint('✅ Sample menu items from database:');
          for (final item in response) {
            debugPrint(
                '   - ${item['name']} (${item['category']}) - \$${item['price']} - Available: ${item['is_available']}');
          }
        } else {
          debugPrint('❌ No menu items found in database at all!');
          debugPrint('🔧 Creating sample menu items for testing...');
          await _createSampleMenuItems();
        }
      }
    } catch (e) {
      debugPrint('❌ Error checking menu items: $e');
    }
  }

  /// 🔧 Create sample menu items for testing if none exist
  Future<void> _createSampleMenuItems() async {
    try {
      final supabase = Supabase.instance.client;

      // Check if restaurants table exists and has data
      final restaurantsResponse =
          await supabase.from('restaurants').select('id').limit(1);

      if (restaurantsResponse.isEmpty) {
        debugPrint(
            '⚠️ No restaurants found. Cannot create menu items without restaurants.');
        return;
      }

      final restaurantId = restaurantsResponse.first['id'];

      final sampleMenuItems = [
        {
          'name': 'Margherita Pizza',
          'description':
              'Classic pizza with tomato sauce, mozzarella, and fresh basil',
          'price': 12.99,
          'category': 'Pizza',
          'restaurant_id': restaurantId,
          'is_available': true,
          'is_featured': true,
          'image':
              'https://images.unsplash.com/photo-1565299624946-b28f40a0ca4b?w=400',
        },
        {
          'name': 'Chicken Burger',
          'description':
              'Grilled chicken breast with lettuce, tomato, and mayo',
          'price': 8.99,
          'category': 'Burgers',
          'restaurant_id': restaurantId,
          'is_available': true,
          'is_featured': true,
          'image':
              'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=400',
        },
        {
          'name': 'Caesar Salad',
          'description':
              'Fresh romaine lettuce with caesar dressing and croutons',
          'price': 7.99,
          'category': 'Salads',
          'restaurant_id': restaurantId,
          'is_available': true,
          'is_featured': false,
          'image':
              'https://images.unsplash.com/photo-1546793665-c74683f339c1?w=400',
        },
        {
          'name': 'Pepperoni Pizza',
          'description': 'Classic pepperoni pizza with mozzarella cheese',
          'price': 14.99,
          'category': 'Pizza',
          'restaurant_id': restaurantId,
          'is_available': true,
          'is_featured': true,
          'image':
              'https://images.unsplash.com/photo-1565299507177-b0ac66763828?w=400',
        },
        {
          'name': 'Pasta Carbonara',
          'description': 'Creamy pasta with bacon, eggs, and parmesan cheese',
          'price': 11.99,
          'category': 'Pasta',
          'restaurant_id': restaurantId,
          'is_available': true,
          'is_featured': false,
          'image':
              'https://images.unsplash.com/photo-1621996346565-e3dbc353d2e5?w=400',
        },
      ];

      await supabase.from('menu_items').insert(sampleMenuItems);

      debugPrint('✅ Created ${sampleMenuItems.length} sample menu items');
    } catch (e) {
      debugPrint('❌ Error creating sample menu items: $e');
    }
  }

  /// 🔍 Main search method with intelligent processing
  Future<void> search(
    String query, {
    Position? userLocation,
    Map<String, dynamic>? filters,
    bool isVoiceSearch = false,
  }) async {
    if (query.trim().isEmpty) {
      _clearResults();
      return;
    }

    // For single character searches, start immediately
    if (query.trim().length == 1) {
      await _performSearch(query,
          userLocation: userLocation,
          filters: filters,
          isVoiceSearch: isVoiceSearch);
      return;
    }

    // For longer queries, use debounced search
    _debouncedSearch(query,
        userLocation: userLocation,
        filters: filters,
        isVoiceSearch: isVoiceSearch);
  }

  /// 🎯 Perform the actual search with smart processing
  Future<void> _performSearch(
    String rawQuery, {
    Position? userLocation,
    Map<String, dynamic>? filters,
    bool isVoiceSearch = false,
  }) async {
    try {
      _setSearching(true);
      _currentQuery = rawQuery;

      // 1. Query Processing Pipeline
      final processedQuery =
          _processQuery(rawQuery, isVoiceSearch: isVoiceSearch);

      // 2. Check cache first
      final cacheKey = _generateCacheKey(processedQuery, userLocation, filters);
      if (_searchCache.containsKey(cacheKey) &&
          !_searchCache[cacheKey]!.isExpired) {
        _results = _searchCache[cacheKey]!.results;
        _setSearching(false);
        return;
      }

      // 3. Multi-level search
      final searchResults = await _performMultiLevelSearch(processedQuery,
          userLocation: userLocation, filters: filters);

      // 4. Intelligent ranking
      final rankedResults = await _rankResults(searchResults, processedQuery,
          userLocation: userLocation);

      // 5. Cache results
      _searchCache[cacheKey] = SearchCacheEntry(
        results: rankedResults,
        timestamp: DateTime.now(),
      );

      // 6. Update search analytics
      await _updateSearchAnalytics(rawQuery, rankedResults.isNotEmpty);

      _results = rankedResults;
      _setSearching(false);
    } catch (e) {
      _error = 'Search failed: $e';
      _setSearching(false);
      debugPrint('❌ Search error: $e');
    }
  }

  /// 📝 Process and normalize the search query
  ProcessedQuery _processQuery(String rawQuery, {bool isVoiceSearch = false}) {
    String normalized = rawQuery.toLowerCase().trim();

    // Handle voice search specifics
    if (isVoiceSearch) {
      normalized = _processVoiceQuery(normalized);
    }

    // Normalization steps
    normalized = _removeAccents(normalized);
    normalized = _handlePluralSingular(normalized);

    // Typo correction
    final correctedQuery = _correctTypos(normalized);

    // Synonym expansion
    final expandedTerms = _expandSynonyms(correctedQuery);

    // Intent detection
    final intent = _detectIntent(normalized);

    return ProcessedQuery(
      original: rawQuery,
      normalized: normalized,
      corrected: correctedQuery,
      expandedTerms: expandedTerms,
      intent: intent,
    );
  }

  /// 🔧 Multi-level search across different content types
  Future<List<SearchResult>> _performMultiLevelSearch(
    ProcessedQuery query, {
    Position? userLocation,
    Map<String, dynamic>? filters,
  }) async {
    final results = <SearchResult>[];

    // For single character searches, limit results for better performance
    final bool isSingleChar = query.original.trim().length == 1;

    // Search restaurants
    final restaurants = await _searchRestaurants(query,
        userLocation: userLocation, filters: filters);
    if (isSingleChar) {
      results.addAll(restaurants.take(10)); // Limit to 10 for single char
    } else {
      results.addAll(restaurants);
    }

    // Search menu items
    final menuItems = await _searchMenuItems(query,
        userLocation: userLocation, filters: filters);
    if (isSingleChar) {
      results.addAll(menuItems.take(10)); // Limit to 10 for single char
    } else {
      results.addAll(menuItems);
    }

    // Search categories (always search all categories as they're limited)
    final categories = await _searchCategories(query);
    results.addAll(categories);

    // Search deals and promotions
    final deals = await _searchDeals(query, userLocation: userLocation);
    if (isSingleChar) {
      results.addAll(deals.take(5)); // Limit to 5 for single char
    } else {
      results.addAll(deals);
    }

    return results;
  }

  /// 🏪 Search restaurants with intelligent matching
  Future<List<SearchResult>> _searchRestaurants(
    ProcessedQuery query, {
    Position? userLocation,
    Map<String, dynamic>? filters,
  }) async {
    try {
      // Use RestaurantService like the home screen does
      final restaurants = await _restaurantService
          .searchRestaurants(query.corrected, limit: 50);

      // Convert Restaurant objects to SearchResult objects
      return restaurants
          .map((restaurant) => SearchResult(
                id: restaurant.id,
                type: SearchResultType.restaurant,
                title: restaurant.name,
                subtitle: '${restaurant.city} • ${restaurant.state}',
                imageUrl: restaurant.image,
                rating: restaurant.rating,
                distance: userLocation != null &&
                        restaurant.latitude != null &&
                        restaurant.longitude != null
                    ? _calculateDistance(
                        userLocation.latitude,
                        userLocation.longitude,
                        restaurant.latitude!,
                        restaurant.longitude!,
                      )
                    : null,
                isAvailable: restaurant.isOpen,
                data: restaurant.toJson(),
                relevanceScore:
                    _calculateTextRelevance(query.corrected, restaurant.name),
              ))
          .toList();
    } catch (e) {
      debugPrint('❌ Error searching restaurants: $e');
      return [];
    }
  }

  /// 🍕 Search menu items across all restaurants
  Future<List<SearchResult>> _searchMenuItems(
    ProcessedQuery query, {
    Position? userLocation,
    Map<String, dynamic>? filters,
  }) async {
    try {
      debugPrint('🔍 Searching menu items for query: "${query.corrected}"');

      // Try multiple approaches to find menu items
      List<MenuItem> menuItems = [];

      // Approach 1: Use MenuItemService
      try {
        menuItems = await _menuItemService.searchMenuItems(query.corrected);
        debugPrint('📱 MenuItemService found ${menuItems.length} items');
      } catch (e) {
        debugPrint('⚠️ MenuItemService search failed: $e');
      }

      // Approach 2: If no results, try getting featured items and filter manually
      if (menuItems.isEmpty) {
        debugPrint('🔄 Trying featured items approach...');
        try {
          final featuredItems = await _menuItemService.getFeaturedMenuItems();
          debugPrint('📊 Found ${featuredItems.length} featured items');

          if (featuredItems.isNotEmpty) {
            final searchTerm = query.corrected.toLowerCase();
            menuItems = featuredItems.where((item) {
              return item.name.toLowerCase().contains(searchTerm) ||
                  item.description.toLowerCase().contains(searchTerm) ||
                  item.category.toLowerCase().contains(searchTerm);
            }).toList();
            debugPrint('🔍 Manual filtering found ${menuItems.length} items');
          }
        } catch (e) {
          debugPrint('⚠️ Featured items approach failed: $e');
        }
      }

      // Approach 3: If still no results, try direct database query
      if (menuItems.isEmpty && query.corrected.length >= 2) {
        debugPrint('🔄 Trying direct database search...');
        try {
          menuItems = await _searchMenuItemsDirectly(query.corrected);
          debugPrint(
              '🗄️ Direct database search found ${menuItems.length} items');
        } catch (e) {
          debugPrint('⚠️ Direct database search failed: $e');
        }
      }

      debugPrint(
          '🍕 Found ${menuItems.length} menu items for query: "${query.corrected}"');

      if (menuItems.isEmpty) {
        debugPrint(
            '⚠️ No menu items found. Trying to get all menu items to check if any exist...');
        // Try to get some menu items to see if there are any in the database
        final allItems = await _menuItemService.getFeaturedMenuItems();
        debugPrint(
            '📊 Total featured menu items in database: ${allItems.length}');
        if (allItems.isNotEmpty) {
          debugPrint('📝 Sample menu item: ${allItems.first.name}');
        }
      }

      // Convert MenuItem objects to SearchResult objects
      final results = menuItems
          .map<SearchResult>((item) => SearchResult(
                id: item.id,
                type: SearchResultType.menuItem,
                title: item.name,
                subtitle:
                    '${item.restaurantName ?? 'Restaurant'} • ${item.category}',
                imageUrl: item.image,
                price: item.price,
                rating: item.rating,
                isAvailable: item.isAvailable,
                data: item.toJson(),
                relevanceScore:
                    _calculateTextRelevance(query.corrected, item.name),
              ))
          .toList();

      debugPrint('✅ Converted ${results.length} menu items to search results');

      // Debug: Show sample menu item results
      if (results.isNotEmpty) {
        debugPrint('🍕 Sample menu item results:');
        results.take(3).forEach((result) {
          debugPrint(
              '   - ${result.title} (Type: ${result.type}, ID: ${result.id})');
        });
      }

      return results;
    } catch (e) {
      debugPrint('❌ Error searching menu items: $e');
      return [];
    }
  }

  /// 📂 Search categories for quick navigation
  Future<List<SearchResult>> _searchCategories(ProcessedQuery query) async {
    try {
      // Use CategoryService to get real categories
      final categories = await _categoryService.getActiveCategories();

      final matchingCategories = categories.where((category) {
        return category.name.toLowerCase().contains(query.corrected) ||
            query.expandedTerms
                .any((term) => category.name.toLowerCase().contains(term));
      }).toList();

      return matchingCategories
          .map((category) => SearchResult(
                id: category.id,
                type: SearchResultType.category,
                title: category.name,
                subtitle: 'Browse ${category.name} restaurants',
                imageUrl: category.icon,
                relevanceScore:
                    _calculateTextRelevance(query.corrected, category.name),
                data: category.toJson(),
              ))
          .toList();
    } catch (e) {
      debugPrint('❌ Error searching categories: $e');
      return [];
    }
  }

  /// 🎁 Search deals and promotions
  Future<List<SearchResult>> _searchDeals(
    ProcessedQuery query, {
    Position? userLocation,
  }) async {
    try {
      // Deal search via Redis removed - returning empty list
      // Deals should be searched directly from Supabase if needed
      return [];
    } catch (e) {
      debugPrint('❌ Error searching deals: $e');
      return [];
    }
  }

  /// 🎯 Intelligent ranking algorithm
  Future<List<SearchResult>> _rankResults(
    List<SearchResult> results,
    ProcessedQuery query, {
    Position? userLocation,
  }) async {
    for (final result in results) {
      double score = 0.0;

      // 1. Text relevance (30%)
      score += result.relevanceScore * 0.3;

      // 2. Geo-proximity (25%)
      if (userLocation != null && result.distance != null) {
        final proximityScore = _calculateProximityScore(result.distance!);
        score += proximityScore * 0.25;
      }

      // 3. Popularity/Trending (20%)
      final popularityScore = await _getPopularityScore(result);
      score += popularityScore * 0.2;

      // 4. Personalization (15%)
      final personalizationScore =
          _getPersonalizationScore(result, query.original);
      score += personalizationScore * 0.15;

      // 5. Availability & Quality (10%)
      if (result.isAvailable) score += 0.05;
      if (result.rating != null && result.rating! >= 4.0) score += 0.05;

      result.finalScore = score;
    }

    // Sort by final score (descending)
    results.sort((a, b) => b.finalScore.compareTo(a.finalScore));

    return results;
  }

  /// 💡 Generate search suggestions with autocomplete
  Future<List<SearchSuggestion>> generateSuggestions(
      String partialQuery) async {
    if (partialQuery.length < 2) return [];

    final suggestions = <SearchSuggestion>[];

    // 1. Popular searches
    final popularQueries = _getPopularQueries(partialQuery);
    suggestions.addAll(popularQueries);

    // 2. User history
    final historyMatches = _getUserHistoryMatches(partialQuery);
    suggestions.addAll(historyMatches);

    // 3. Restaurant/item name matches
    final nameMatches = await _getNameMatches(partialQuery);
    suggestions.addAll(nameMatches);

    // 4. Category matches
    final categoryMatches = _getCategoryMatches(partialQuery);
    suggestions.addAll(categoryMatches);

    // Remove duplicates and limit results
    final uniqueSuggestions = suggestions.toSet().toList();
    uniqueSuggestions.sort((a, b) => b.score.compareTo(a.score));

    return uniqueSuggestions.take(8).toList();
  }

  /// 📊 Track search analytics and learning
  Future<void> _updateSearchAnalytics(String query, bool hasResults) async {
    try {
      // Update query popularity
      _queryPopularity[query] = (_queryPopularity[query] ?? 0) + 1;

      // Track no-result queries for improvement
      if (!hasResults) {
        _noResultQueries.add(query);
      }

      // Update user search history
      final userId = await _getUserId();
      if (userId != null) {
        _userSearchHistory[userId] ??= [];
        _userSearchHistory[userId]!.add(query);

        // Keep only last 50 searches per user
        if (_userSearchHistory[userId]!.length > 50) {
          _userSearchHistory[userId]!.removeAt(0);
        }
      }

      // Save to persistent storage
      await _saveUserData();
    } catch (e) {
      debugPrint('❌ Error updating search analytics: $e');
    }
  }

  /// 🔤 Typo correction using edit distance
  String _correctTypos(String query) {
    final commonWords = [
      'pizza',
      'burger',
      'sushi',
      'pasta',
      'salad',
      'chicken',
      'beef',
      'restaurant',
      'delivery',
      'food',
      'meal',
      'lunch',
      'dinner'
    ];

    final words = query.split(' ');
    final correctedWords = <String>[];

    for (final word in words) {
      String bestMatch = word;
      int minDistance = 2; // Only correct if distance <= 2

      for (final commonWord in commonWords) {
        final distance = _levenshteinDistance(word, commonWord);
        if (distance < minDistance) {
          minDistance = distance;
          bestMatch = commonWord;
        }
      }

      correctedWords.add(bestMatch);
    }

    return correctedWords.join(' ');
  }

  /// 📚 Expand query with synonyms
  List<String> _expandSynonyms(String query) {
    final terms = [query];
    final words = query.split(' ');

    for (final word in words) {
      if (_synonyms.containsKey(word)) {
        terms.addAll(_synonyms[word]!);
      }
    }

    return terms.toSet().toList();
  }

  /// 🎯 Detect user intent from query
  SearchIntent _detectIntent(String query) {
    // Intent patterns
    if (RegExp(r'\b(near|nearby|close|around)\b').hasMatch(query)) {
      return SearchIntent.location;
    }
    if (RegExp(r'\b(cheap|budget|affordable|deal|discount)\b')
        .hasMatch(query)) {
      return SearchIntent.price;
    }
    if (RegExp(r'\b(fast|quick|express|urgent)\b').hasMatch(query)) {
      return SearchIntent.speed;
    }
    if (RegExp(r'\b(healthy|diet|vegan|vegetarian|gluten)\b').hasMatch(query)) {
      return SearchIntent.dietary;
    }
    if (RegExp(r'\b(popular|trending|best|top|recommended)\b')
        .hasMatch(query)) {
      return SearchIntent.popularity;
    }

    return SearchIntent.general;
  }

  /// 🗣️ Process voice search queries
  String _processVoiceQuery(String voiceQuery) {
    // Handle common voice search patterns
    final String processed = voiceQuery
        .replaceAll(RegExp(r'\bi want\b'), '')
        .replaceAll(RegExp(r'\border\b'), '')
        .replaceAll(RegExp(r'\bfind\b'), '')
        .replaceAll(RegExp(r'\bsearch for\b'), '')
        .replaceAll(RegExp(r'\bshow me\b'), '')
        .trim();

    return processed.isEmpty ? voiceQuery : processed;
  }

  /// 📏 Calculate text relevance score
  double _calculateTextRelevance(String query, String text) {
    if (text.toLowerCase().contains(query.toLowerCase())) {
      // Exact match gets higher score
      if (text.toLowerCase() == query.toLowerCase()) return 1.0;
      // Starts with query gets medium-high score
      if (text.toLowerCase().startsWith(query.toLowerCase())) return 0.8;
      // Contains query gets medium score
      return 0.6;
    }

    // Fuzzy matching for partial relevance
    final words = query.split(' ');
    int matchCount = 0;
    for (final word in words) {
      if (text.toLowerCase().contains(word.toLowerCase())) {
        matchCount++;
      }
    }

    return matchCount / words.length * 0.4;
  }

  /// 📍 Calculate proximity score based on distance
  double _calculateProximityScore(double distanceKm) {
    if (distanceKm <= 1) return 1.0;
    if (distanceKm <= 3) return 0.8;
    if (distanceKm <= 5) return 0.6;
    if (distanceKm <= 10) return 0.4;
    return 0.2;
  }

  /// 📈 Get popularity score for result
  Future<double> _getPopularityScore(SearchResult result) async {
    try {
      // Popularity score from Redis removed - returning default
      // Popularity can be calculated from Supabase analytics if needed
      return 0.5;
    } catch (e) {
      debugPrint('❌ Error getting popularity score: $e');
    }

    return 0.5; // Default neutral score
  }

  /// 👤 Get personalization score based on user history
  double _getPersonalizationScore(SearchResult result, String query) {
    final userId = _getCurrentUserId();
    if (userId == null) return 0.5;

    // Check if user has interacted with this item/restaurant before
    final userScores = _personalizedScores[userId];
    if (userScores != null) {
      final itemScore = userScores[result.id];
      if (itemScore != null) {
        return itemScore;
      }
    }

    // Check search history for similar queries
    final userHistory = _userSearchHistory[userId];
    if (userHistory != null) {
      final similarQueries = userHistory
          .where((historyQuery) =>
              historyQuery.toLowerCase().contains(query.toLowerCase()) ||
              query.toLowerCase().contains(historyQuery.toLowerCase()))
          .length;

      return (similarQueries / userHistory.length).clamp(0.0, 1.0);
    }

    return 0.5; // Default neutral score
  }

  /// 🔧 Helper methods

  void _setSearching(bool searching) {
    _isSearching = searching;
    notifyListeners();
  }

  void _clearResults() {
    _results.clear();
    _currentQuery = '';
    _error = null;
    notifyListeners();
  }

  String _generateCacheKey(
      ProcessedQuery query, Position? location, Map<String, dynamic>? filters) {
    final locationStr = location != null
        ? '${location.latitude},${location.longitude}'
        : 'no_location';
    final filtersStr = filters != null ? jsonEncode(filters) : 'no_filters';
    return '${query.corrected}_${locationStr}_$filtersStr';
  }

  String _removeAccents(String text) {
    return text
        .replaceAll(RegExp('[àáâãäå]'), 'a')
        .replaceAll(RegExp('[èéêë]'), 'e')
        .replaceAll(RegExp('[ìíîï]'), 'i')
        .replaceAll(RegExp('[òóôõö]'), 'o')
        .replaceAll(RegExp('[ùúûü]'), 'u');
  }

  String _handlePluralSingular(String text) {
    // Simple plural/singular handling
    if (text.endsWith('s') && text.length > 3) {
      return text.substring(0, text.length - 1);
    }
    return text;
  }

  int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    final matrix =
        List.generate(s1.length + 1, (i) => List.filled(s2.length + 1, 0));

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
          matrix[i - 1][j] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j - 1] + cost,
        ].reduce(min);
      }
    }

    return matrix[s1.length][s2.length];
  }

  List<SearchSuggestion> _getPopularQueries(String partial) {
    return _queryPopularity.entries
        .where((entry) =>
            entry.key.toLowerCase().startsWith(partial.toLowerCase()))
        .map((entry) => SearchSuggestion(
              text: entry.key,
              type: SuggestionType.popular,
              score: entry.value.toDouble(),
            ))
        .toList();
  }

  List<SearchSuggestion> _getUserHistoryMatches(String partial) {
    final userId = _getCurrentUserId();
    if (userId == null) return [];

    final history = _userSearchHistory[userId] ?? [];
    return history
        .where((query) => query.toLowerCase().startsWith(partial.toLowerCase()))
        .map((query) => SearchSuggestion(
              text: query,
              type: SuggestionType.history,
              score: 0.8,
            ))
        .toList();
  }

  Future<List<SearchSuggestion>> _getNameMatches(String partial) async {
    // This would typically query your search index
    // For now, return empty list
    return [];
  }

  List<SearchSuggestion> _getCategoryMatches(String partial) {
    final categories = [
      'Pizza',
      'Burger',
      'Sushi',
      'Chinese',
      'Italian',
      'Mexican'
    ];
    return categories
        .where((category) =>
            category.toLowerCase().startsWith(partial.toLowerCase()))
        .map((category) => SearchSuggestion(
              text: category,
              type: SuggestionType.category,
              score: 0.7,
            ))
        .toList();
  }

  Future<void> _loadSynonyms() async {
    // Load synonyms from local storage or API
    _synonyms.addAll({
      'pizza': ['pie', 'flatbread'],
      'burger': ['sandwich', 'hamburger'],
      'soda': ['soft drink', 'cola', 'pop'],
      'chicken': ['poultry', 'fowl'],
      'beef': ['meat', 'steak'],
      'fast': ['quick', 'rapid', 'express'],
      'cheap': ['budget', 'affordable', 'inexpensive'],
    });
  }

  Future<void> _loadUserData() async {
    if (_prefs == null) return;

    // Load query popularity
    final popularityJson = _prefs!.getString('query_popularity');
    if (popularityJson != null) {
      final Map<String, dynamic> data = jsonDecode(popularityJson);
      _queryPopularity.addAll(data.map((k, v) => MapEntry(k, v as int)));
    }

    // Load user search history
    final historyJson = _prefs!.getString('user_search_history');
    if (historyJson != null) {
      final Map<String, dynamic> data = jsonDecode(historyJson);
      _userSearchHistory
          .addAll(data.map((k, v) => MapEntry(k, List<String>.from(v))));
    }
  }

  Future<void> _saveUserData() async {
    if (_prefs == null) return;

    // Save query popularity
    await _prefs!.setString('query_popularity', jsonEncode(_queryPopularity));

    // Save user search history
    await _prefs!
        .setString('user_search_history', jsonEncode(_userSearchHistory));
  }

  Future<String?> _getUserId() async {
    // Get current user ID from your auth service
    return _prefs?.getString('user_id');
  }

  String? _getCurrentUserId() {
    // Get current user ID synchronously
    return _prefs?.getString('user_id');
  }

  /// 📍 Calculate distance between two points in kilometers
  double _calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    const double earthRadius = 6371; // Earth's radius in kilometers

    final double dLat = _degreesToRadians(lat2 - lat1);
    final double dLon = _degreesToRadians(lon2 - lon1);

    final double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(lat1)) *
            cos(_degreesToRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * (pi / 180);
  }

  /// 🗄️ Direct database search for menu items when other methods fail
  Future<List<MenuItem>> _searchMenuItemsDirectly(String query) async {
    try {
      final supabase = Supabase.instance.client;

      debugPrint('🔍 Performing direct database search for: "$query"');

      final response = await supabase
          .from('menu_items')
          .select('''
            *,
            restaurant:restaurants(id, name, phone, email, rating, logo_url)
          ''')
          .or('name.ilike.%$query%,description.ilike.%$query%,category.ilike.%$query%')
          .eq('is_available', true)
          .limit(50);

      debugPrint('🗄️ Direct database response: ${response.length} items');

      final menuItems = (response as List)
          .map((json) {
            try {
              final item = MenuItem.fromJson(json);
              // Only include items with valid images
              return item.image.isNotEmpty ? item : null;
            } catch (e) {
              debugPrint('⚠️ Error parsing menu item: $e');
              return null;
            }
          })
          .whereType<MenuItem>()
          .toList();

      debugPrint('✅ Successfully parsed ${menuItems.length} menu items');
      return menuItems;
    } catch (e) {
      debugPrint('❌ Direct database search error: $e');
      return [];
    }
  }

  /// 🧹 Cleanup resources
  @override
  void dispose() {
    super.dispose();
  }
}

/// 📋 Data models for smart search

class ProcessedQuery {
  final String original;
  final String normalized;
  final String corrected;
  final List<String> expandedTerms;
  final SearchIntent intent;

  ProcessedQuery({
    required this.original,
    required this.normalized,
    required this.corrected,
    required this.expandedTerms,
    required this.intent,
  });
}

class SearchCacheEntry {
  final List<SearchResult> results;
  final DateTime timestamp;

  SearchCacheEntry({
    required this.results,
    required this.timestamp,
  });

  bool get isExpired =>
      DateTime.now().difference(timestamp) > SmartSearchService._cacheExpiry;
}

enum SearchIntent {
  general,
  location,
  price,
  speed,
  dietary,
  popularity,
}

// Enums moved to separate model files to avoid duplication
