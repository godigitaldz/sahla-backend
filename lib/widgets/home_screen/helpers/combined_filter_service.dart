import 'package:flutter/material.dart';

import '../../../providers/home_provider.dart';
import '../../../services/restaurant_search_service.dart';
import '../../filter_chips_section/filter_chips_section.dart';

/// Combined filter service that merges RestaurantSearchService with HomeProvider's delivery fee range
///
/// This service acts as a bridge between:
/// - `RestaurantSearchService` for location, cuisine, category, price filters
/// - `HomeProvider` for delivery fee and other home-specific filters
///
/// It listens to both services and notifies listeners when either changes,
/// ensuring the UI stays synchronized with all filter states.
class CombinedFilterService extends ChangeNotifier implements FilterService {
  CombinedFilterService({
    required this.searchService,
    required this.homeProvider,
  }) {
    // Cache initial filter state
    _cacheCurrentState();

    // Listen to both services for changes
    searchService.addListener(_onSearchServiceChanged);
    homeProvider.addListener(_onHomeProviderChanged);
  }

  final RestaurantSearchService searchService;
  final HomeProvider homeProvider;

  // Performance: Cache filter state to detect actual changes
  String? _cachedLocation;
  Set<String> _cachedCuisines = {};
  Set<String> _cachedCategories = {};
  RangeValues? _cachedPriceRange;
  RangeValues? _cachedDeliveryFeeRange;
  bool? _cachedIsOpen;
  double? _cachedMinRating;

  void _cacheCurrentState() {
    _cachedLocation = searchService.selectedLocation;
    _cachedCuisines = Set.from(searchService.selectedCuisines);
    _cachedCategories = Set.from(searchService.selectedCategories);
    _cachedPriceRange = searchService.priceRange;
    _cachedDeliveryFeeRange = searchService.deliveryFeeRange;
    _cachedIsOpen = searchService.isOpen;
    _cachedMinRating = searchService.minRating;
  }

  bool _hasStateChanged() {
    return _cachedLocation != searchService.selectedLocation ||
        !_cachedCuisines.containsAll(searchService.selectedCuisines) ||
        !searchService.selectedCuisines.containsAll(_cachedCuisines) ||
        !_cachedCategories.containsAll(searchService.selectedCategories) ||
        !searchService.selectedCategories.containsAll(_cachedCategories) ||
        _cachedPriceRange != searchService.priceRange ||
        _cachedDeliveryFeeRange != searchService.deliveryFeeRange ||
        _cachedIsOpen != searchService.isOpen ||
        _cachedMinRating != searchService.minRating;
  }

  void _onSearchServiceChanged() {
    // Performance: Only notify if filter state actually changed
    if (_hasStateChanged()) {
      _cacheCurrentState();
      notifyListeners();
    }
  }

  void _onHomeProviderChanged() {
    // Performance: Only notify if filter state actually changed
    if (_hasStateChanged()) {
      _cacheCurrentState();
      notifyListeners();
    }
  }

  @override
  void dispose() {
    searchService.removeListener(_onSearchServiceChanged);
    homeProvider.removeListener(_onHomeProviderChanged);
    super.dispose();
  }

  @override
  String? get selectedLocation => searchService.selectedLocation;

  @override
  Set<String> get selectedCuisines => searchService.selectedCuisines;

  @override
  Set<String> get selectedCategories => searchService.selectedCategories;

  @override
  RangeValues? get priceRange => searchService.priceRange;

  @override
  RangeValues? get deliveryFeeRange => searchService.deliveryFeeRange;

  @override
  bool? get isOpen => searchService.isOpen;

  @override
  double? get minRating => searchService.minRating;

  @override
  void clearFilters() {
    // Only call homeProvider.clearAllFilters() as it already handles searchService.clearFilters()
    homeProvider.clearAllFilters();
  }

  @override
  void setDeliveryFeeRangeFilter(RangeValues? range) {
    searchService.setDeliveryFeeRangeFilter(range);
  }
}
