import 'dart:math';

import '../../models/restaurant.dart';

/// Utility helpers for home screen logic
class HomeUtils {
  /// Normalize category key for consistent comparison
  static String normalizeCategoryKey(String input) {
    return input
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r"[\s-]+"), "_")
        .replaceAll(RegExp("[^a-z0-9_]+"), "");
  }

  /// Remove duplicate restaurants from a list
  static List<Restaurant> removeDuplicateRestaurants(
      List<Restaurant> restaurants) {
    final seenIds = <String>{};
    return restaurants.where((restaurant) {
      if (seenIds.contains(restaurant.id)) {
        return false; // Skip duplicates
      }
      seenIds.add(restaurant.id);
      return true;
    }).toList();
  }

  /// Check if two restaurant lists are different
  static bool hasRestaurantsChanged(
      List<Restaurant> oldList, List<Restaurant> newList) {
    if (oldList.length != newList.length) return true;
    return !oldList.every((r) => newList.any((nr) => nr.id == r.id));
  }

  /// Get unique restaurants from multiple lists
  static List<Restaurant> mergeUniqueRestaurants(List<List<Restaurant>> lists) {
    final allRestaurants = <Restaurant>[];
    final seenIds = <String>{};

    for (final list in lists) {
      for (final restaurant in list) {
        if (seenIds.add(restaurant.id)) {
          allRestaurants.add(restaurant);
        }
      }
    }

    return allRestaurants;
  }

  /// Sort restaurants by rating (highest first)
  static List<Restaurant> sortByRating(List<Restaurant> restaurants) {
    final sorted = List<Restaurant>.from(restaurants);
    sorted.sort((a, b) => b.rating.compareTo(a.rating));
    return sorted;
  }

  /// Search restaurants by name or description
  static List<Restaurant> searchRestaurants(
      List<Restaurant> restaurants, String query) {
    if (query.isEmpty) return restaurants;

    final lowercaseQuery = query.toLowerCase();
    return restaurants.where((restaurant) {
      final name = restaurant.name.toLowerCase();
      final description = restaurant.description.toLowerCase();
      final city = restaurant.city.toLowerCase();

      return name.contains(lowercaseQuery) ||
          description.contains(lowercaseQuery) ||
          city.contains(lowercaseQuery);
    }).toList();
  }

  /// Get restaurants that are currently open
  static List<Restaurant> getOpenRestaurants(List<Restaurant> restaurants) {
    return restaurants.where((restaurant) {
      // Implementation would check restaurant hours
      // For now, assume all restaurants are open
      return true;
    }).toList();
  }

  /// Calculate distance between two coordinates (simplified)
  static double calculateDistance(
      double lat1, double lon1, double lat2, double lon2) {
    // Simplified distance calculation (Haversine formula would be more accurate)
    const double earthRadius = 6371; // km

    final dLat = (lat2 - lat1) * (pi / 180);
    final dLon = (lon2 - lon1) * (pi / 180);

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1 * (pi / 180)) *
            cos(lat2 * (pi / 180)) *
            sin(dLon / 2) *
            sin(dLon / 2);

    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  /// Format distance for display
  static String formatDistance(double distanceInKm) {
    if (distanceInKm < 1) {
      return '${(distanceInKm * 1000).round()}m';
    } else {
      return '${distanceInKm.toStringAsFixed(1)}km';
    }
  }

  /// Get featured restaurants (restaurants that are marked as featured)
  static List<Restaurant> getFeaturedRestaurants(List<Restaurant> restaurants,
      {int limit = 5}) {
    final featured =
        restaurants.where((restaurant) => restaurant.isFeatured).toList();
    return featured.take(limit).toList();
  }

  /// Get top rated restaurants
  static List<Restaurant> getTopRatedRestaurants(List<Restaurant> restaurants,
      {int limit = 10}) {
    final sorted = sortByRating(restaurants);
    return sorted.take(limit).toList();
  }
}
