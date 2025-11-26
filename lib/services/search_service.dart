import 'package:flutter/foundation.dart';

import 'supabase_service.dart';

class SearchService extends ChangeNotifier {
  List<dynamic> _searchResults = [];
  List<String> _popularLocations = [];
  List<Map<String, dynamic>> _categories = [];
  bool _isLoading = false;
  String _lastQuery = '';

  List<dynamic> get searchResults => _searchResults;
  List<String> get popularLocations => _popularLocations;
  List<Map<String, dynamic>> get categories => _categories;
  bool get isLoading => _isLoading;
  String get lastQuery => _lastQuery;

  // Search cars with filters
  Future<void> searchCars({
    String? query,
    String? category,
    String? location,
    String? useType,
    double? minPrice,
    double? maxPrice,
    DateTime? startDate,
    DateTime? endDate,
    int? passengers,
    String? transmission,
    String? fuelType,
    double? minRating,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      _isLoading = true;
      _lastQuery = query ?? '';
      notifyListeners();

      _searchResults = await SupabaseService.searchCars(
        query: query,
        category: category,
        location: location,
        useType: useType,
        minPrice: minPrice,
        maxPrice: maxPrice,
        startDate: startDate,
        endDate: endDate,
        passengers: passengers,
        transmission: transmission,
        fuelType: fuelType,
        minRating: minRating,
        limit: limit,
        offset: offset,
      );
    } catch (e) {
      debugPrint('Error searching cars: $e');
      _searchResults = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Load popular locations
  Future<void> loadPopularLocations() async {
    try {
      _popularLocations = await SupabaseService.getPopularLocations();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading popular locations: $e');
    }
  }

  // Load categories
  Future<void> loadCategories() async {
    try {
      _categories = await SupabaseService.getCategories();
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading categories: $e');
    }
  }

  // Simple text search
  Future<void> simpleSearch(String query) async {
    if (query.trim().isEmpty) {
      _searchResults = [];
      notifyListeners();
      return;
    }

    await searchCars(query: query.trim());
  }

  // Search by location
  Future<void> searchByLocation(String location) async {
    await searchCars(location: location);
  }

  // Search by category
  Future<void> searchByCategory(String categoryId) async {
    await searchCars(category: categoryId);
  }

  // Search by price range
  Future<void> searchByPriceRange(double minPrice, double maxPrice) async {
    await searchCars(minPrice: minPrice, maxPrice: maxPrice);
  }

  // Search by date range
  Future<void> searchByDateRange(DateTime startDate, DateTime endDate) async {
    await searchCars(startDate: startDate, endDate: endDate);
  }

  // Search by passengers
  Future<void> searchByPassengers(int passengers) async {
    await searchCars(passengers: passengers);
  }

  // Search by transmission
  Future<void> searchByTransmission(String transmission) async {
    await searchCars(transmission: transmission);
  }

  // Search by fuel type
  Future<void> searchByFuelType(String fuelType) async {
    await searchCars(fuelType: fuelType);
  }

  // Search by rating
  Future<void> searchByRating(double minRating) async {
    await searchCars(minRating: minRating);
  }

  // Clear search results
  void clearResults() {
    _searchResults.clear();
    _lastQuery = '';
    notifyListeners();
  }

  // Get search statistics
  Map<String, int> get searchStats {
    return {
      'total_results': _searchResults.length,
      'available_restaurants': _searchResults
          .where((restaurant) => restaurant['isOpen'] == true)
          .length,
      'featured_restaurants': _searchResults
          .where((restaurant) => restaurant['isFeatured'] == true)
          .length,
    };
  }

  // Get unique locations from search results
  List<String> get uniqueLocations {
    return _searchResults
        .map((restaurant) => (restaurant['address'] ?? '').toString())
        .where((location) => location.isNotEmpty)
        .toSet()
        .toList();
  }

  // Get unique categories from search results
  List<String> get uniqueCategories {
    return _searchResults
        .map((restaurant) => (restaurant['cuisineType'] ?? '').toString())
        .where((category) => category.isNotEmpty)
        .toSet()
        .toList();
  }

  // Get price range from search results
  Map<String, double> get priceRange {
    if (_searchResults.isEmpty) {
      return {'min': 0.0, 'max': 0.0};
    }

    final prices = _searchResults
        .map((restaurant) =>
            double.tryParse((restaurant['averagePrice'] ?? '').toString()) ??
            0.0)
        .where((price) => price > 0)
        .toList();

    if (prices.isEmpty) {
      return {'min': 0.0, 'max': 0.0};
    }

    return {
      'min': prices.reduce((a, b) => a < b ? a : b),
      'max': prices.reduce((a, b) => a > b ? a : b),
    };
  }

  // Get average rating from search results
  double get averageRating {
    if (_searchResults.isEmpty) return 0.0;

    final ratings = _searchResults
        .map((restaurant) => restaurant['rating'] ?? 0)
        .where((rating) => rating > 0)
        .toList();

    if (ratings.isEmpty) return 0.0;

    return ratings.reduce((a, b) => a + b) / ratings.length;
  }

  // Filter results by price
  List<dynamic> filterByPrice(double minPrice, double maxPrice) {
    return _searchResults.where((restaurant) {
      final price =
          double.tryParse((restaurant['averagePrice'] ?? '').toString()) ?? 0.0;
      return price >= minPrice && price <= maxPrice;
    }).toList();
  }

  // Filter results by rating
  List<dynamic> filterByRating(double minRating) {
    return _searchResults
        .where((restaurant) => (restaurant['rating'] ?? 0) >= minRating)
        .toList();
  }

  // Filter results by availability
  List<dynamic> filterByAvailability({required bool available}) {
    return _searchResults
        .where((restaurant) => (restaurant['isOpen'] ?? false) == available)
        .toList();
  }

  // Sort results by price (low to high)
  List<dynamic> sortByPriceLowToHigh() {
    final sorted = List<dynamic>.from(_searchResults);
    sorted.sort((a, b) {
      final priceA = double.tryParse((a['price'] ?? '').toString()) ?? 0.0;
      final priceB = double.tryParse((b['price'] ?? '').toString()) ?? 0.0;
      return priceA.compareTo(priceB);
    });
    return sorted;
  }

  // Sort results by price (high to low)
  List<dynamic> sortByPriceHighToLow() {
    final sorted = List<dynamic>.from(_searchResults);
    sorted.sort((a, b) {
      final priceA = double.tryParse((a['price'] ?? '').toString()) ?? 0.0;
      final priceB = double.tryParse((b['price'] ?? '').toString()) ?? 0.0;
      return priceB.compareTo(priceA);
    });
    return sorted;
  }

  // Sort results by rating (high to low)
  List<dynamic> sortByRating() {
    final sorted = List<dynamic>.from(_searchResults);
    sorted.sort((a, b) => (b['rating'] ?? 0).compareTo(a['rating'] ?? 0));
    return sorted;
  }

  // Sort results by name (A to Z)
  List<dynamic> sortByName() {
    final sorted = List<dynamic>.from(_searchResults);
    sorted.sort((a, b) => (a['name'] ?? '').compareTo(b['name'] ?? ''));
    return sorted;
  }

  // Get search suggestions based on current results
  List<String> getSearchSuggestions(String partialQuery) {
    if (partialQuery.isEmpty) return [];

    final suggestions = <String>[];

    // Add location suggestions
    for (final location in _popularLocations) {
      if (location.toLowerCase().contains(partialQuery.toLowerCase())) {
        suggestions.add(location);
      }
    }

    // Add restaurant name suggestions
    for (final restaurant in _searchResults) {
      if (restaurant.name.toLowerCase().contains(partialQuery.toLowerCase())) {
        suggestions.add(restaurant.name);
      }
    }

    // Add category suggestions
    for (final category in _categories) {
      final name = category['name']?.toString() ?? '';
      if (name.toLowerCase().contains(partialQuery.toLowerCase())) {
        suggestions.add(name);
      }
    }

    return suggestions.take(5).toList();
  }

  // Initialize search service
  Future<void> initialize() async {
    await Future.wait([
      loadPopularLocations(),
      loadCategories(),
    ]);
  }

  // Clear all data
  void clear() {
    _searchResults.clear();
    _popularLocations.clear();
    _categories.clear();
    _lastQuery = '';
    notifyListeners();
  }
}
