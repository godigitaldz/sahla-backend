import 'dart:collection';

import 'package:flutter/material.dart';

import '../restaurant.dart';

/// High-performance immutable state model for the home screen
/// Optimized for minimal rebuilds and maximum performance with thousands of restaurants
@immutable
class HomeState {
  // ==================== LOADING STATES ====================
  final bool isLoading;
  final bool isLoadingRecentlyViewed;
  final bool isLoadingMoreRestaurants;

  // ==================== ERROR STATE ====================
  final bool hasError;
  final String? errorMessage;

  // ==================== DATA COLLECTIONS ====================
  /// Internal immutable storage - never modified after creation
  final List<Restaurant> _restaurants;
  final List<Restaurant> _recentlyViewed;
  final List<Restaurant> _searchResults;
  final List<Map<String, dynamic>> _liveNotifications;

  // ==================== UI STATE ====================
  final bool isSearchMode;
  final bool isMenuOpen;
  final String currentSearchQuery;
  final bool isFilterAnimating;

  // ==================== SCROLL STATE ====================
  // NOTE: scrollOffset removed - now managed by ValueNotifier in HomeProvider
  // This prevents Consumer rebuilds on every scroll event

  // ==================== FILTER STATE ====================
  final String? selectedLocation;
  final Set<String>? selectedCategories;
  final Set<String>? selectedCuisines;
  final RangeValues? priceRange;
  final RangeValues? deliveryFeeRange;
  final bool? isOpen;
  final double? minRating;

  // ==================== REAL-TIME STATE ====================
  final Map<String, int> _onlineDeliveryPartners;

  /// Public unmodifiable views of internal data for safe external access
  List<Restaurant> get restaurants => UnmodifiableListView(_restaurants);
  List<Restaurant> get recentlyViewed => UnmodifiableListView(_recentlyViewed);
  List<Restaurant> get searchResults => UnmodifiableListView(_searchResults);
  List<Map<String, dynamic>> get liveNotifications =>
      UnmodifiableListView(_liveNotifications);
  Map<String, int> get onlineDeliveryPartners =>
      UnmodifiableMapView(_onlineDeliveryPartners);

  /// Default empty collections for const constructors - optimized for performance
  static const List<Restaurant> _emptyRestaurants = [];
  static const List<Map<String, dynamic>> _emptyNotifications = [];
  static const Set<String> _emptySet = {};
  static const Map<String, int> _emptyPartners = {};

  const HomeState({
    // Loading states with sensible defaults
    this.isLoading = true,
    this.isLoadingRecentlyViewed = true,
    this.isLoadingMoreRestaurants = false,

    // Error state
    this.hasError = false,
    this.errorMessage,

    // Data collections - default to empty for performance
    List<Restaurant> restaurants = _emptyRestaurants,
    List<Restaurant> recentlyViewed = _emptyRestaurants,
    List<Restaurant> searchResults = _emptyRestaurants,
    List<Map<String, dynamic>> liveNotifications = _emptyNotifications,

    // UI state
    this.isSearchMode = false,
    this.isMenuOpen = false,
    this.currentSearchQuery = '',
    this.isFilterAnimating = false,

    // Scroll state - removed (now in ValueNotifier)

    // Filter state - nullable for optional filters
    this.selectedLocation,
    Set<String>? selectedCategories,
    Set<String>? selectedCuisines,
    this.priceRange,
    this.deliveryFeeRange,
    this.isOpen,
    this.minRating,

    // Real-time state
    Map<String, int> onlineDeliveryPartners = _emptyPartners,
  })  :
        // Initialize immutable internal state - performance optimized
        _restaurants = restaurants,
        _recentlyViewed = recentlyViewed,
        _searchResults = searchResults,
        _liveNotifications = liveNotifications,
        selectedCategories = selectedCategories ?? _emptySet,
        selectedCuisines = selectedCuisines ?? _emptySet,
        _onlineDeliveryPartners = onlineDeliveryPartners;

  // ==================== COMPUTED PROPERTIES - PERFORMANCE OPTIMIZED ====================

  /// Computed properties for performance - cached getters that avoid recalculation
  bool get hasActiveFilters {
    // Check all filter conditions efficiently - single calculation
    return (selectedLocation?.isNotEmpty ?? false) ||
        (selectedCategories?.isNotEmpty ?? false) ||
        (selectedCuisines?.isNotEmpty ?? false) ||
        priceRange != null ||
        deliveryFeeRange != null ||
        (isOpen != null && isOpen!) ||
        (minRating != null && minRating! > 0) ||
        isSearchMode; // Search query counts as a filter
  }

  int get totalRestaurants => _restaurants.length;

  int get totalRecentlyViewed => _recentlyViewed.length;

  int get totalSearchResults => _searchResults.length;

  int get totalLiveNotifications => _liveNotifications.length;

  bool get isAnyLoading =>
      isLoading || isLoadingRecentlyViewed || isLoadingMoreRestaurants;

  bool get hasData => _restaurants.isNotEmpty || _recentlyViewed.isNotEmpty;

  bool get hasSearchData => isSearchMode && _searchResults.isNotEmpty;

  /// Check if we have any restaurants to display (performance optimized)
  bool get hasRestaurantsToShow {
    if (isSearchMode) {
      return _searchResults.isNotEmpty;
    }
    return _restaurants.isNotEmpty;
  }

  /// Check if any category filters are applied
  bool get hasCategoryFilters => selectedCategories?.isNotEmpty ?? false;

  /// Check if any cuisine filters are applied
  bool get hasCuisineFilters => selectedCuisines?.isNotEmpty ?? false;

  /// Check if location filter is applied
  bool get hasLocationFilter => selectedLocation?.isNotEmpty ?? false;

  /// Check if price filter is applied
  bool get hasPriceFilter => priceRange != null;

  /// Check if delivery fee filter is applied
  bool get hasDeliveryFeeFilter => deliveryFeeRange != null;

  /// Check if open filter is applied
  bool get hasOpenFilter => isOpen == true;

  /// Check if rating filter is applied
  bool get hasRatingFilter => minRating != null && minRating! > 0;

  /// Lightweight, safe copyWith that only updates provided fields and reuses existing collections
  HomeState copyWith({
    bool? isLoading,
    bool? isLoadingRecentlyViewed,
    bool? isLoadingMoreRestaurants,
    bool? hasError,
    String? errorMessage,
    List<Restaurant>? restaurants,
    List<Restaurant>? recentlyViewed,
    List<Restaurant>? searchResults,
    List<Map<String, dynamic>>? liveNotifications,
    bool? isSearchMode,
    bool? isMenuOpen,
    String? currentSearchQuery,
    bool? isFilterAnimating,
    String? selectedLocation,
    Set<String>? selectedCategories,
    Set<String>? selectedCuisines,
    RangeValues? priceRange,
    RangeValues? deliveryFeeRange,
    bool? isOpen,
    double? minRating,
    Map<String, int>? onlineDeliveryPartners,
  }) {
    // Performance optimization: only create new instance if something actually changed
    final newIsLoading = isLoading ?? this.isLoading;
    final newIsLoadingRecentlyViewed =
        isLoadingRecentlyViewed ?? this.isLoadingRecentlyViewed;
    final newIsLoadingMoreRestaurants =
        isLoadingMoreRestaurants ?? this.isLoadingMoreRestaurants;
    final newHasError = hasError ?? this.hasError;
    final newErrorMessage = errorMessage ?? this.errorMessage;
    final newRestaurants = restaurants ?? _restaurants;
    final newRecentlyViewed = recentlyViewed ?? _recentlyViewed;
    final newSearchResults = searchResults ?? _searchResults;
    final newLiveNotifications = liveNotifications ?? _liveNotifications;
    final newIsSearchMode = isSearchMode ?? this.isSearchMode;
    final newIsMenuOpen = isMenuOpen ?? this.isMenuOpen;
    final newCurrentSearchQuery = currentSearchQuery ?? this.currentSearchQuery;
    final newIsFilterAnimating = isFilterAnimating ?? this.isFilterAnimating;
    final newSelectedLocation = selectedLocation ?? this.selectedLocation;
    final newSelectedCategories = selectedCategories ?? this.selectedCategories;
    final newSelectedCuisines = selectedCuisines ?? this.selectedCuisines;
    final newPriceRange = priceRange ?? this.priceRange;
    final newDeliveryFeeRange = deliveryFeeRange ?? this.deliveryFeeRange;
    final newIsOpen = isOpen ?? this.isOpen;
    final newMinRating = minRating ?? this.minRating;
    final newOnlineDeliveryPartners =
        onlineDeliveryPartners ?? _onlineDeliveryPartners;

    // Fast path: return same instance if no changes (memory optimization)
    if (identical(this.isLoading, newIsLoading) &&
        identical(this.isLoadingRecentlyViewed, newIsLoadingRecentlyViewed) &&
        identical(this.isLoadingMoreRestaurants, newIsLoadingMoreRestaurants) &&
        identical(this.hasError, newHasError) &&
        identical(this.errorMessage, newErrorMessage) &&
        identical(_restaurants, newRestaurants) &&
        identical(_recentlyViewed, newRecentlyViewed) &&
        identical(_searchResults, newSearchResults) &&
        identical(_liveNotifications, newLiveNotifications) &&
        identical(this.isSearchMode, newIsSearchMode) &&
        identical(this.isMenuOpen, newIsMenuOpen) &&
        identical(this.currentSearchQuery, newCurrentSearchQuery) &&
        identical(this.isFilterAnimating, newIsFilterAnimating) &&
        identical(this.selectedLocation, newSelectedLocation) &&
        identical(this.selectedCategories, newSelectedCategories) &&
        identical(this.selectedCuisines, newSelectedCuisines) &&
        identical(this.priceRange, newPriceRange) &&
        identical(this.deliveryFeeRange, newDeliveryFeeRange) &&
        identical(this.isOpen, newIsOpen) &&
        identical(this.minRating, newMinRating) &&
        identical(_onlineDeliveryPartners, newOnlineDeliveryPartners)) {
      return this;
    }

    return HomeState(
      isLoading: newIsLoading,
      isLoadingRecentlyViewed: newIsLoadingRecentlyViewed,
      isLoadingMoreRestaurants: newIsLoadingMoreRestaurants,
      hasError: newHasError,
      errorMessage: newErrorMessage,
      restaurants: newRestaurants,
      recentlyViewed: newRecentlyViewed,
      searchResults: newSearchResults,
      liveNotifications: newLiveNotifications,
      isSearchMode: newIsSearchMode,
      isMenuOpen: newIsMenuOpen,
      currentSearchQuery: newCurrentSearchQuery,
      isFilterAnimating: newIsFilterAnimating,
      selectedLocation: newSelectedLocation,
      selectedCategories: newSelectedCategories,
      selectedCuisines: newSelectedCuisines,
      priceRange: newPriceRange,
      deliveryFeeRange: newDeliveryFeeRange,
      isOpen: newIsOpen,
      minRating: newMinRating,
      onlineDeliveryPartners: newOnlineDeliveryPartners,
    );
  }

  /// Optimized equality for provider rebuild detection - fast path comparison
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! HomeState) return false;

    // Fast comparison of primitive fields first (most likely to differ)
    return other.isLoading == isLoading &&
        other.isLoadingRecentlyViewed == isLoadingRecentlyViewed &&
        other.isLoadingMoreRestaurants == isLoadingMoreRestaurants &&
        other.hasError == hasError &&
        other.errorMessage == errorMessage &&
        other.isSearchMode == isSearchMode &&
        other.isMenuOpen == isMenuOpen &&
        other.currentSearchQuery == currentSearchQuery &&
        other.isFilterAnimating == isFilterAnimating &&
        other.selectedLocation == selectedLocation &&
        other.priceRange == priceRange &&
        other.deliveryFeeRange == deliveryFeeRange &&
        other.isOpen == isOpen &&
        other.minRating == minRating &&
        // Collection comparisons (more expensive, check last)
        _setEquals(other.selectedCategories, selectedCategories) &&
        _setEquals(other.selectedCuisines, selectedCuisines) &&
        _listEquals(other._restaurants, _restaurants) &&
        _listEquals(other._recentlyViewed, _recentlyViewed) &&
        _listEquals(other._searchResults, _searchResults) &&
        _notificationListEquals(other._liveNotifications, _liveNotifications) &&
        _mapEquals(other._onlineDeliveryPartners, _onlineDeliveryPartners);
  }

  @override
  int get hashCode {
    return Object.hash(
          isLoading,
          isLoadingRecentlyViewed,
          isLoadingMoreRestaurants,
          hasError,
          errorMessage,
          isSearchMode,
          isMenuOpen,
          currentSearchQuery,
          selectedLocation,
          priceRange,
          deliveryFeeRange,
          isOpen,
          minRating,
          // Collections (use hashAll for performance)
          Object.hashAll(selectedCategories ?? {}),
          Object.hashAll(selectedCuisines ?? {}),
          Object.hashAll(_restaurants),
          Object.hashAll(_recentlyViewed),
          Object.hashAll(_searchResults),
        ) +
        Object.hash(
          Object.hashAll(
              _liveNotifications.map((n) => Object.hashAll(n.entries))),
          Object.hashAll(_onlineDeliveryPartners.entries),
        );
  }

  /// Efficient set comparison for equality checks
  bool _setEquals(Set<String>? a, Set<String>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    return a.containsAll(b) && b.containsAll(a);
  }

  /// Efficient list comparison for equality checks
  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Efficient notification list comparison
  bool _notificationListEquals(
      List<Map<String, dynamic>> a, List<Map<String, dynamic>> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (!_mapEquals(a[i], b[i])) return false;
    }
    return true;
  }

  /// Efficient map comparison
  bool _mapEquals<K, V>(Map<K, V> a, Map<K, V> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (a[key] != b[key]) return false;
    }
    return true;
  }

  @override
  String toString() {
    return 'HomeState(isLoading: $isLoading, restaurants: $totalRestaurants, recentlyViewed: $totalRecentlyViewed, searchMode: $isSearchMode, hasFilters: $hasActiveFilters, hasError: $hasError)';
  }
}
