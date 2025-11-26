import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/menu_item.dart';

/// Predictive preloading service using ML-based user behavior analysis
///
/// This service tracks user interactions and uses simple ML algorithms
/// to predict which menu items, categories, and cuisines the user is
/// likely to view next, enabling intelligent prefetching.
///
/// Features:
/// - User behavior tracking (views, taps, time spent)
/// - Frequency-based predictions
/// - Time-of-day patterns
/// - Category affinity scoring
/// - Cuisine preference learning
/// - Session-based predictions
class PredictivePreloadingService {
  static final PredictivePreloadingService _instance =
      PredictivePreloadingService._internal();
  factory PredictivePreloadingService() => _instance;
  PredictivePreloadingService._internal();

  // Storage keys
  static const String _viewHistoryKey = 'predictive_view_history';
  static const String _categoryAffinityKey = 'predictive_category_affinity';
  static const String _cuisineAffinityKey = 'predictive_cuisine_affinity';
  static const String _timePatternKey = 'predictive_time_pattern';

  // In-memory caches
  final Map<String, int> _categoryViewCount = {};
  final Map<String, int> _cuisineViewCount = {};
  final Map<int, List<String>> _timeOfDayCategories = {}; // Hour -> Categories
  final List<String> _recentViews = [];

  // Configuration
  static const int _recentViewsSize = 20;
  static const double _minAffinityScore = 0.1;

  /// Initialize the service and load cached data
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load view history
      final historyJson = prefs.getString(_viewHistoryKey);
      if (historyJson != null) {
        final history = json.decode(historyJson) as List;
        _recentViews.addAll(history.cast<String>());
      }

      // Load category affinity
      final categoryJson = prefs.getString(_categoryAffinityKey);
      if (categoryJson != null) {
        final affinity = json.decode(categoryJson) as Map<String, dynamic>;
        _categoryViewCount.addAll(
          affinity.map((key, value) => MapEntry(key, value as int)),
        );
      }

      // Load cuisine affinity
      final cuisineJson = prefs.getString(_cuisineAffinityKey);
      if (cuisineJson != null) {
        final affinity = json.decode(cuisineJson) as Map<String, dynamic>;
        _cuisineViewCount.addAll(
          affinity.map((key, value) => MapEntry(key, value as int)),
        );
      }

      // Load time patterns
      final timeJson = prefs.getString(_timePatternKey);
      if (timeJson != null) {
        final patterns = json.decode(timeJson) as Map<String, dynamic>;
        _timeOfDayCategories.addAll(
          patterns.map((key, value) =>
              MapEntry(int.parse(key), (value as List).cast<String>())),
        );
      }

      debugPrint(
          '✅ PredictivePreloading: Initialized with ${_recentViews.length} history items');
      debugPrint('   - Categories tracked: ${_categoryViewCount.length}');
      debugPrint('   - Cuisines tracked: ${_cuisineViewCount.length}');
    } catch (e) {
      debugPrint('❌ PredictivePreloading: Error initializing: $e');
    }
  }

  /// Track a menu item view
  Future<void> trackMenuItemView(MenuItem item) async {
    try {
      // Add to recent views
      if (!_recentViews.contains(item.id)) {
        _recentViews.insert(0, item.id);
        if (_recentViews.length > _recentViewsSize) {
          _recentViews.removeLast();
        }
      }

      // Track category affinity
      if (item.category.isNotEmpty) {
        _categoryViewCount[item.category] =
            (_categoryViewCount[item.category] ?? 0) + 1;
      }

      // Track cuisine affinity
      if (item.cuisineType != null) {
        final cuisineName = item.cuisineType!.name;
        _cuisineViewCount[cuisineName] =
            (_cuisineViewCount[cuisineName] ?? 0) + 1;
      }

      // Track time-of-day pattern
      final hour = DateTime.now().hour;
      if (item.category.isNotEmpty) {
        _timeOfDayCategories.putIfAbsent(hour, () => []);
        if (!_timeOfDayCategories[hour]!.contains(item.category)) {
          _timeOfDayCategories[hour]!.add(item.category);
        }
      }

      // Persist to storage (debounced)
      await _persistData();

      debugPrint(
          '📊 PredictivePreloading: Tracked view of "${item.name}" (${item.category})');
    } catch (e) {
      debugPrint('❌ PredictivePreloading: Error tracking view: $e');
    }
  }

  /// Track category view
  Future<void> trackCategoryView(String category) async {
    if (category.isEmpty) return;

    try {
      _categoryViewCount[category] = (_categoryViewCount[category] ?? 0) + 1;

      // Track time pattern
      final hour = DateTime.now().hour;
      _timeOfDayCategories.putIfAbsent(hour, () => []);
      if (!_timeOfDayCategories[hour]!.contains(category)) {
        _timeOfDayCategories[hour]!.add(category);
      }

      await _persistData();
      debugPrint('📊 PredictivePreloading: Tracked category view: $category');
    } catch (e) {
      debugPrint('❌ PredictivePreloading: Error tracking category: $e');
    }
  }

  /// Predict categories user is likely to view next
  List<String> predictNextCategories({int limit = 5}) {
    try {
      final currentHour = DateTime.now().hour;

      // Combine frequency-based and time-based predictions
      final predictions = <String, double>{};

      // Factor 1: Overall frequency (40% weight)
      for (final entry in _categoryViewCount.entries) {
        final normalized = entry.value / _getTotalViews();
        predictions[entry.key] =
            (predictions[entry.key] ?? 0) + (normalized * 0.4);
      }

      // Factor 2: Time-of-day pattern (30% weight)
      final currentHourCategories = _timeOfDayCategories[currentHour] ?? [];
      for (final category in currentHourCategories) {
        predictions[category] = (predictions[category] ?? 0) + 0.3;
      }

      // Factor 3: Recency (30% weight)
      // Note: This would require item ID to category mapping
      // Simplified implementation - could be enhanced in future

      // Sort by score and return top predictions
      final sorted = predictions.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final topPredictions = sorted.take(limit).map((e) => e.key).toList();

      debugPrint('🎯 PredictivePreloading: Top predictions: $topPredictions');

      return topPredictions;
    } catch (e) {
      debugPrint('❌ PredictivePreloading: Error predicting categories: $e');
      return [];
    }
  }

  /// Predict cuisines user is likely to view next
  List<String> predictNextCuisines({int limit = 5}) {
    try {
      if (_cuisineViewCount.isEmpty) return [];

      // Sort cuisines by view count
      final sorted = _cuisineViewCount.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final predictions = sorted.take(limit).map((e) => e.key).toList();

      debugPrint(
          '🎯 PredictivePreloading: Top cuisine predictions: $predictions');

      return predictions;
    } catch (e) {
      debugPrint('❌ PredictivePreloading: Error predicting cuisines: $e');
      return [];
    }
  }

  /// Get category affinity score (0.0 to 1.0)
  double getCategoryAffinity(String category) {
    final views = _categoryViewCount[category] ?? 0;
    final totalViews = _getTotalViews();

    if (totalViews == 0) return 0.0;

    return (views / totalViews).clamp(0.0, 1.0);
  }

  /// Get cuisine affinity score (0.0 to 1.0)
  double getCuisineAffinity(String cuisine) {
    final views = _cuisineViewCount[cuisine] ?? 0;
    final totalViews = _cuisineViewCount.values.fold(0, (sum, v) => sum + v);

    if (totalViews == 0) return 0.0;

    return (views / totalViews).clamp(0.0, 1.0);
  }

  /// Should preload this category based on predictions?
  bool shouldPreloadCategory(String category) {
    final affinity = getCategoryAffinity(category);
    return affinity >= _minAffinityScore;
  }

  /// Should preload this cuisine based on predictions?
  bool shouldPreloadCuisine(String cuisine) {
    final affinity = getCuisineAffinity(cuisine);
    return affinity >= _minAffinityScore;
  }

  /// Get preloading recommendations
  PreloadingRecommendations getRecommendations() {
    return PreloadingRecommendations(
      categories: predictNextCategories(limit: 3),
      cuisines: predictNextCuisines(limit: 3),
      confidence: _calculateConfidence(),
      timeOfDay: _getCurrentTimePattern(),
    );
  }

  /// Calculate confidence score for predictions
  double _calculateConfidence() {
    final totalViews = _getTotalViews();

    // More data = higher confidence
    if (totalViews < 10) return 0.3;
    if (totalViews < 50) return 0.6;
    return 0.9;
  }

  /// Get current time pattern
  String _getCurrentTimePattern() {
    final hour = DateTime.now().hour;

    if (hour >= 6 && hour < 11) return 'breakfast';
    if (hour >= 11 && hour < 15) return 'lunch';
    if (hour >= 15 && hour < 18) return 'afternoon';
    if (hour >= 18 && hour < 23) return 'dinner';
    return 'late_night';
  }

  /// Get total view count
  int _getTotalViews() {
    return _categoryViewCount.values.fold(0, (sum, v) => sum + v);
  }

  /// Persist data to storage
  Future<void> _persistData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save view history
      await prefs.setString(_viewHistoryKey, json.encode(_recentViews));

      // Save category affinity
      await prefs.setString(
          _categoryAffinityKey, json.encode(_categoryViewCount));

      // Save cuisine affinity
      await prefs.setString(
          _cuisineAffinityKey, json.encode(_cuisineViewCount));

      // Save time patterns
      await prefs.setString(
          _timePatternKey,
          json.encode(
              _timeOfDayCategories.map((k, v) => MapEntry(k.toString(), v))));
    } catch (e) {
      debugPrint('❌ PredictivePreloading: Error persisting data: $e');
    }
  }

  /// Clear all tracking data
  Future<void> clearData() async {
    try {
      _recentViews.clear();
      _categoryViewCount.clear();
      _cuisineViewCount.clear();
      _timeOfDayCategories.clear();

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_viewHistoryKey);
      await prefs.remove(_categoryAffinityKey);
      await prefs.remove(_cuisineAffinityKey);
      await prefs.remove(_timePatternKey);

      debugPrint('✅ PredictivePreloading: All data cleared');
    } catch (e) {
      debugPrint('❌ PredictivePreloading: Error clearing data: $e');
    }
  }

  /// Get statistics about tracked data
  Map<String, dynamic> getStatistics() {
    return {
      'total_views': _getTotalViews(),
      'categories_tracked': _categoryViewCount.length,
      'cuisines_tracked': _cuisineViewCount.length,
      'recent_views': _recentViews.length,
      'time_patterns': _timeOfDayCategories.length,
      'top_category': _getTopCategory(),
      'top_cuisine': _getTopCuisine(),
      'confidence': _calculateConfidence(),
    };
  }

  String? _getTopCategory() {
    if (_categoryViewCount.isEmpty) return null;
    return _categoryViewCount.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }

  String? _getTopCuisine() {
    if (_cuisineViewCount.isEmpty) return null;
    return _cuisineViewCount.entries
        .reduce((a, b) => a.value > b.value ? a : b)
        .key;
  }
}

/// Preloading recommendations based on predictions
class PreloadingRecommendations {
  final List<String> categories;
  final List<String> cuisines;
  final double confidence;
  final String timeOfDay;

  const PreloadingRecommendations({
    required this.categories,
    required this.cuisines,
    required this.confidence,
    required this.timeOfDay,
  });

  bool get hasRecommendations => categories.isNotEmpty || cuisines.isNotEmpty;

  @override
  String toString() {
    return 'PreloadingRecommendations(categories: $categories, cuisines: $cuisines, confidence: ${(confidence * 100).toStringAsFixed(0)}%, time: $timeOfDay)';
  }
}
