import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/restaurant.dart';

/// Persistent cache service for restaurants data
///
/// Features:
/// - Persistent delivery fee range caching
/// - Restaurant snapshot caching (first 20 for instant display)
/// - Cache validity checks (6 hours)
/// - Graceful error handling
/// - Automatic cache expiry
class RestaurantsCacheService {
  static const String _keyDeliveryFeeRange = 'restaurants:feeRange';
  static const String _keyRestaurantsList = 'restaurants:list';
  static const String _keyLastUpdate = 'restaurants:lastUpdate';
  static const Duration _cacheValidity = Duration(hours: 6);

  /// Save delivery fee range to persistent storage
  Future<void> saveDeliveryFeeRange(Map<String, double> range) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyDeliveryFeeRange, json.encode(range));
      debugPrint('💾 Saved delivery fee range to cache: $range');
    } catch (e) {
      debugPrint('❌ Error saving delivery fee range: $e');
    }
  }

  /// Get cached delivery fee range from persistent storage
  Future<Map<String, double>?> getDeliveryFeeRange() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getString(_keyDeliveryFeeRange);
      if (cached != null) {
        final decoded = json.decode(cached) as Map<String, dynamic>;
        final range = decoded.map((k, v) => MapEntry(k, (v as num).toDouble()));
        debugPrint('✅ Loaded delivery fee range from cache: $range');
        return range;
      }
    } catch (e) {
      debugPrint('❌ Error reading cached delivery fee range: $e');
    }
    return null;
  }

  /// Save restaurants snapshot (first 20 for instant display on cold start)
  Future<void> saveRestaurantsSnapshot(List<Restaurant> restaurants) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      // Only cache first 20 restaurants for instant display
      final snapshot = restaurants.take(20).map((r) => r.toJson()).toList();
      await prefs.setString(_keyRestaurantsList, json.encode(snapshot));
      await prefs.setInt(_keyLastUpdate, DateTime.now().millisecondsSinceEpoch);
      debugPrint('💾 Saved ${snapshot.length} restaurants to cache');
    } catch (e) {
      debugPrint('❌ Error saving restaurants snapshot: $e');
    }
  }

  /// Get cached restaurants snapshot from persistent storage
  Future<List<Restaurant>?> getRestaurantsSnapshot() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check cache validity (6 hours)
      final lastUpdate = prefs.getInt(_keyLastUpdate);
      if (lastUpdate != null) {
        final age = DateTime.now().millisecondsSinceEpoch - lastUpdate;
        if (age > _cacheValidity.inMilliseconds) {
          debugPrint('🗑️ Restaurants cache expired (age: ${age ~/ 1000}s)');
          return null;
        }
      }

      final cached = prefs.getString(_keyRestaurantsList);
      if (cached != null) {
        final List<dynamic> decoded = json.decode(cached);
        final restaurants =
            decoded.map((json) => Restaurant.fromJson(json)).toList();
        debugPrint('✅ Loaded ${restaurants.length} restaurants from cache');
        return restaurants;
      }
    } catch (e) {
      debugPrint('❌ Error reading cached restaurants: $e');
    }
    return null;
  }

  /// Get cache age in seconds (for debugging)
  Future<int?> getCacheAge() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdate = prefs.getInt(_keyLastUpdate);
      if (lastUpdate != null) {
        final age = DateTime.now().millisecondsSinceEpoch - lastUpdate;
        return age ~/ 1000; // Return age in seconds
      }
    } catch (e) {
      debugPrint('❌ Error getting cache age: $e');
    }
    return null;
  }

  /// Check if cache is valid
  Future<bool> isCacheValid() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdate = prefs.getInt(_keyLastUpdate);
      if (lastUpdate != null) {
        final age = DateTime.now().millisecondsSinceEpoch - lastUpdate;
        return age <= _cacheValidity.inMilliseconds;
      }
    } catch (e) {
      debugPrint('❌ Error checking cache validity: $e');
    }
    return false;
  }

  /// Clear all cached data
  Future<void> clearAll() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyDeliveryFeeRange);
      await prefs.remove(_keyRestaurantsList);
      await prefs.remove(_keyLastUpdate);
      debugPrint('🗑️ Cleared all restaurants cache');
    } catch (e) {
      debugPrint('❌ Error clearing cache: $e');
    }
  }

  /// Get cache statistics for debugging
  Future<Map<String, dynamic>> getCacheStats() async {
    final isValid = await isCacheValid();
    final age = await getCacheAge();
    final hasRestaurants = await getRestaurantsSnapshot() != null;
    final hasFeeRange = await getDeliveryFeeRange() != null;

    return {
      'isValid': isValid,
      'ageSeconds': age,
      'hasRestaurants': hasRestaurants,
      'hasFeeRange': hasFeeRange,
      'validityHours': _cacheValidity.inHours,
    };
  }
}
