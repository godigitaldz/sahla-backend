import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/menu_item.dart';

/// Service for smart sorting of menu items based on popularity and quality metrics
class MenuItemSortingService {
  static final _supabase = Supabase.instance.client;

  // Cache for menu item statistics
  static Map<String, _MenuItemStats>? _cachedStats;
  static DateTime? _cacheTimestamp;
  static const _cacheDuration = Duration(minutes: 15);

  /// Sort menu items by smart detection considering reviews, orders, and ratings
  ///
  /// Scoring algorithm:
  /// - 40% weight: Number of orders (popularity)
  /// - 30% weight: Average rating (quality)
  /// - 20% weight: Number of reviews (engagement)
  /// - 10% weight: Recency (days since created, newer is better)
  static Future<List<MenuItem>> sortMenuItemsBySmartDetection(
    List<MenuItem> items,
  ) async {
    if (items.isEmpty) {
      debugPrint('📊 MenuItemSorting: No items to sort');
      return items;
    }

    debugPrint(
        '📊 MenuItemSorting: Starting smart sort for ${items.length} items');

    try {
      // Get or fetch statistics
      final stats = await _getMenuItemStatistics(items);

      if (stats.isEmpty) {
        debugPrint(
            '⚠️ MenuItemSorting: No statistics available, returning original order');
        return items;
      }

      // Calculate scores for each item
      final itemScores = <String, double>{};

      for (final item in items) {
        final itemStats = stats[item.id];
        if (itemStats != null) {
          final score = _calculateScore(itemStats);
          itemScores[item.id] = score;
          debugPrint(
              '  📈 ${item.name}: score=$score (orders=${itemStats.orderCount}, rating=${itemStats.avgRating}, reviews=${itemStats.reviewCount})');
        } else {
          // Default score for items without stats
          itemScores[item.id] = 0.0;
        }
      }

      // Sort items by score (descending)
      final sortedItems = List<MenuItem>.from(items);
      sortedItems.sort((a, b) {
        final scoreA = itemScores[a.id] ?? 0.0;
        final scoreB = itemScores[b.id] ?? 0.0;
        return scoreB.compareTo(scoreA); // Descending order
      });

      debugPrint('✅ MenuItemSorting: Sorted ${sortedItems.length} items');

      // Show top 3 items
      final topCount = sortedItems.length < 3 ? sortedItems.length : 3;
      for (var i = 0; i < topCount; i++) {
        final item = sortedItems[i];
        final score = itemScores[item.id]?.toStringAsFixed(3) ?? '0.000';
        debugPrint(
            '  ${i == 0 ? "🥇" : i == 1 ? "🥈" : "🥉"} #${i + 1}: ${item.name} (score=$score)');
      }

      return sortedItems;
    } catch (e, stackTrace) {
      debugPrint('❌ MenuItemSorting: Error during smart sort: $e');
      debugPrint('Stack trace: $stackTrace');
      return items; // Return original order on error
    }
  }

  /// Get menu item statistics from cache or database
  static Future<Map<String, _MenuItemStats>> _getMenuItemStatistics(
    List<MenuItem> items,
  ) async {
    // Check cache validity
    if (_cachedStats != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
      debugPrint('✅ MenuItemSorting: Using cached statistics');
      return _cachedStats!;
    }

    debugPrint('🔄 MenuItemSorting: Fetching fresh statistics from database');

    try {
      final itemIds = items.map((item) => item.id).toList();
      final stats = <String, _MenuItemStats>{};

      // Fetch order counts for menu items
      debugPrint(
          '🔍 MenuItemSorting: Fetching orders for ${itemIds.length} items...');
      final orderData = await _supabase
          .from('order_items')
          .select('menu_item_id')
          .inFilter('menu_item_id', itemIds);

      debugPrint(
          '📦 MenuItemSorting: Fetched ${(orderData as List).length} order records');

      final orderCounts = <String, int>{};
      for (final row in orderData) {
        final itemId = row['menu_item_id'] as String;
        orderCounts[itemId] = (orderCounts[itemId] ?? 0) + 1;
      }

      debugPrint(
          '📊 MenuItemSorting: Calculated orders for ${orderCounts.length} items');

      // Fetch review data for menu items
      debugPrint(
          '🔍 MenuItemSorting: Fetching reviews for ${itemIds.length} items...');
      final reviewData = await _supabase
          .from('menu_item_reviews')
          .select('menu_item_id, rating')
          .inFilter('menu_item_id', itemIds);

      debugPrint(
          '📦 MenuItemSorting: Fetched ${(reviewData as List).length} review records');

      final reviewStats = <String, List<double>>{};
      for (final row in reviewData) {
        final itemId = row['menu_item_id'] as String;
        final rating = (row['rating'] as num?)?.toDouble() ?? 0.0;
        reviewStats.putIfAbsent(itemId, () => []).add(rating);
      }

      // Calculate average ratings and review counts
      final avgRatings = <String, double>{};
      final reviewCounts = <String, int>{};

      reviewStats.forEach((itemId, ratings) {
        if (ratings.isNotEmpty) {
          avgRatings[itemId] = ratings.reduce((a, b) => a + b) / ratings.length;
          reviewCounts[itemId] = ratings.length;
        }
      });

      // Combine all statistics
      for (final item in items) {
        final createdAt = item.createdAt;
        final daysSinceCreated = DateTime.now().difference(createdAt).inDays;

        stats[item.id] = _MenuItemStats(
          itemId: item.id,
          orderCount: orderCounts[item.id] ?? 0,
          avgRating:
              avgRatings[item.id] ?? item.rating, // Fallback to item's rating
          reviewCount: reviewCounts[item.id] ??
              item.reviewCount, // Fallback to item's review count
          daysSinceCreated: daysSinceCreated,
        );
      }

      // Cache the results
      _cachedStats = stats;
      _cacheTimestamp = DateTime.now();

      // Summary statistics
      final itemsWithOrders =
          stats.values.where((s) => s.orderCount > 0).length;
      final itemsWithReviews =
          stats.values.where((s) => s.reviewCount > 0).length;
      final totalOrders =
          stats.values.fold<int>(0, (sum, s) => sum + s.orderCount);
      final totalReviews =
          stats.values.fold<int>(0, (sum, s) => sum + s.reviewCount);

      debugPrint(
          '✅ MenuItemSorting: Fetched statistics for ${stats.length} items');
      debugPrint(
          '   📊 Items with orders: $itemsWithOrders (total orders: $totalOrders)');
      debugPrint(
          '   📊 Items with reviews: $itemsWithReviews (total reviews: $totalReviews)');

      return stats;
    } catch (e, stackTrace) {
      debugPrint('❌ MenuItemSorting: Error fetching statistics: $e');
      debugPrint('Stack trace: $stackTrace');
      return {};
    }
  }

  /// Calculate composite score for a menu item
  ///
  /// Score formula:
  /// - 40% weight: Order count (normalized)
  /// - 30% weight: Rating (0-5 scale)
  /// - 20% weight: Review count (normalized)
  /// - 10% weight: Recency score (newer items get boost)
  static double _calculateScore(_MenuItemStats stats) {
    // Normalize order count (cap at 100 orders for scaling)
    final normalizedOrders = (stats.orderCount / 100.0).clamp(0.0, 1.0);

    // Normalize rating (already on 0-5 scale, convert to 0-1)
    final normalizedRating = (stats.avgRating / 5.0).clamp(0.0, 1.0);

    // Normalize review count (cap at 50 reviews for scaling)
    final normalizedReviews = (stats.reviewCount / 50.0).clamp(0.0, 1.0);

    // Recency score (items less than 30 days old get a boost)
    final recencyScore = stats.daysSinceCreated < 30
        ? (1.0 - (stats.daysSinceCreated / 30.0)).clamp(0.0, 1.0)
        : 0.0;

    // Weighted composite score
    final score = (normalizedOrders * 0.40) +
        (normalizedRating * 0.30) +
        (normalizedReviews * 0.20) +
        (recencyScore * 0.10);

    return score;
  }

  /// Clear cached statistics (call when data changes)
  static void clearCache() {
    _cachedStats = null;
    _cacheTimestamp = null;
    debugPrint('🗑️ MenuItemSorting: Cache cleared');
  }
}

/// Internal class to hold menu item statistics
class _MenuItemStats {
  final String itemId;
  final int orderCount;
  final double avgRating;
  final int reviewCount;
  final int daysSinceCreated;

  _MenuItemStats({
    required this.itemId,
    required this.orderCount,
    required this.avgRating,
    required this.reviewCount,
    required this.daysSinceCreated,
  });
}
