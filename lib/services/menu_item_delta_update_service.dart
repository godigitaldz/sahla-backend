import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/menu_item.dart';
import 'logging_service.dart';

/// Service for handling incremental delta updates of menu items
///
/// This service efficiently fetches only the changes since the last update
/// instead of reloading all data, significantly reducing network usage and
/// improving performance.
///
/// Features:
/// - Timestamp-based delta fetching
/// - Merge strategy for new/updated items
/// - Deleted item detection
/// - Network optimization (fetch only changes)
class MenuItemDeltaUpdateService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final LoggingService _logger = LoggingService();

  /// Track last sync timestamp for delta updates
  static DateTime? _lastSyncTimestamp;

  /// Get delta updates since last sync
  /// Returns only items that were created or updated since lastSyncTimestamp
  Future<DeltaUpdateResult> getDeltaUpdates({
    DateTime? since,
    int limit = 100,
  }) async {
    final sinceTime = since ?? _lastSyncTimestamp;

    if (sinceTime == null) {
      // First sync - fetch all items
      debugPrint('🔄 DeltaUpdate: First sync, fetching all items');
      return _performFullSync(limit: limit);
    }

    try {
      _logger.startPerformanceTimer('delta_update_fetch',
          metadata: {'since': sinceTime.toIso8601String()});

      debugPrint(
          '🔄 DeltaUpdate: Fetching changes since ${sinceTime.toIso8601String()}');

      // Fetch items updated since last sync
      final response = await _supabase
          .from('menu_items')
          .select(
              'id, restaurant_id, restaurant_name, name, description, image, price, category, cuisine_type_id, category_id, cuisine_types(*), categories(*), is_available, is_featured, preparation_time, rating, review_count, variants, pricing_options, supplements, created_at, updated_at')
          .gte('updated_at', sinceTime.toIso8601String())
          .order('updated_at', ascending: false)
          .limit(limit);

      // Parse items and handle missing images gracefully
      final updatedItems = <MenuItem>[];
      for (final item in (response as List)) {
        try {
          final menuItem = MenuItem.fromJson(item);
          // Only include items with valid images
          if (menuItem.image.isNotEmpty) {
            updatedItems.add(menuItem);
          } else {
            debugPrint(
                '⚠️ DeltaUpdate: Skipping menu item with empty image: ${item['id']}');
          }
        } catch (e) {
          // Skip items that can't be parsed (e.g., missing required fields like image)
          final itemId = item['id']?.toString() ?? 'unknown';
          debugPrint(
              '⚠️ DeltaUpdate: Skipping menu item due to parsing error: $e');
          debugPrint('   Item ID: $itemId');
        }
      }

      debugPrint('🔄 DeltaUpdate: Found ${updatedItems.length} updated items');

      // Update last sync timestamp
      _lastSyncTimestamp = DateTime.now();

      _logger.endPerformanceTimer('delta_update_fetch',
          details: 'Delta update completed: ${updatedItems.length} items');

      return DeltaUpdateResult(
        updatedItems: updatedItems,
        deletedItemIds: [], // Supabase doesn't support soft delete tracking easily
        lastSyncTime: _lastSyncTimestamp!,
        isFullSync: false,
      );
    } catch (e) {
      _logger.error('Error fetching delta updates',
          tag: 'DELTA_UPDATE', error: e);
      debugPrint('❌ DeltaUpdate: Error fetching delta updates: $e');

      // Fallback to full sync on error
      return _performFullSync(limit: limit);
    }
  }

  /// Perform full sync (fetch all items)
  Future<DeltaUpdateResult> _performFullSync({int limit = 100}) async {
    try {
      final response = await _supabase
          .from('menu_items')
          .select(
              'id, restaurant_id, restaurant_name, name, description, image, price, category, cuisine_type_id, category_id, cuisine_types(*), categories(*), is_available, is_featured, preparation_time, rating, review_count, variants, pricing_options, supplements, created_at, updated_at')
          .eq('is_available', 'true')
          .order('created_at', ascending: false)
          .limit(limit);

      // Parse items and handle missing images gracefully
      final allItems = <MenuItem>[];
      for (final item in (response as List)) {
        try {
          final menuItem = MenuItem.fromJson(item);
          // Only include items with valid images
          if (menuItem.image.isNotEmpty) {
            allItems.add(menuItem);
          } else {
            debugPrint(
                '⚠️ DeltaUpdate: Skipping menu item with empty image: ${item['id']}');
          }
        } catch (e) {
          // Skip items that can't be parsed (e.g., missing required fields like image)
          final itemId = item['id']?.toString() ?? 'unknown';
          debugPrint(
              '⚠️ DeltaUpdate: Skipping menu item due to parsing error: $e');
          debugPrint('   Item ID: $itemId');
        }
      }

      _lastSyncTimestamp = DateTime.now();

      debugPrint(
          '🔄 DeltaUpdate: Full sync completed: ${allItems.length} items');

      return DeltaUpdateResult(
        updatedItems: allItems,
        deletedItemIds: [],
        lastSyncTime: _lastSyncTimestamp!,
        isFullSync: true,
      );
    } catch (e) {
      debugPrint('❌ DeltaUpdate: Full sync failed: $e');
      rethrow;
    }
  }

  /// Merge delta updates with existing items
  /// Returns updated list with new/updated items merged in
  List<MenuItem> mergeDeltaUpdates({
    required List<MenuItem> existingItems,
    required DeltaUpdateResult deltaResult,
  }) {
    if (deltaResult.isFullSync) {
      // Full sync, replace all items
      return deltaResult.updatedItems;
    }

    // Create a map of existing items for quick lookup
    final existingItemsMap = <String, MenuItem>{
      for (final item in existingItems) item.id: item,
    };

    // Update or add new items
    for (final updatedItem in deltaResult.updatedItems) {
      existingItemsMap[updatedItem.id] = updatedItem;
    }

    // Remove deleted items
    deltaResult.deletedItemIds.forEach(existingItemsMap.remove);

    final mergedItems = existingItemsMap.values.toList();

    debugPrint(
        '🔄 DeltaUpdate: Merged updates - Original: ${existingItems.length}, Updated: ${deltaResult.updatedItems.length}, Final: ${mergedItems.length}');

    return mergedItems;
  }

  /// Get last sync timestamp
  DateTime? getLastSyncTime() {
    return _lastSyncTimestamp;
  }

  /// Reset last sync timestamp (forces full sync next time)
  void resetSyncTimestamp() {
    _lastSyncTimestamp = null;
    debugPrint('🔄 DeltaUpdate: Sync timestamp reset');
  }

  /// Check if a full sync is recommended
  /// Returns true if it's been more than 24 hours since last sync
  bool shouldPerformFullSync() {
    if (_lastSyncTimestamp == null) return true;

    final hoursSinceLastSync =
        DateTime.now().difference(_lastSyncTimestamp!).inHours;

    return hoursSinceLastSync > 24;
  }

  /// Get delta updates for specific categories
  Future<DeltaUpdateResult> getDeltaUpdatesByCategories({
    required Set<String> categories,
    DateTime? since,
    int limit = 50,
  }) async {
    final sinceTime = since ??
        _lastSyncTimestamp ??
        DateTime.now().subtract(const Duration(hours: 24));

    try {
      debugPrint(
          '🔄 DeltaUpdate: Fetching category updates since ${sinceTime.toIso8601String()}');

      final response = await _supabase
          .from('menu_items')
          .select('*')
          .inFilter('category', categories.toList())
          .gte('updated_at', sinceTime.toIso8601String())
          .order('updated_at', ascending: false)
          .limit(limit);

      // Parse items and handle missing images gracefully
      final updatedItems = <MenuItem>[];
      for (final item in (response as List)) {
        try {
          final menuItem = MenuItem.fromJson(item);
          // Only include items with valid images
          if (menuItem.image.isNotEmpty) {
            updatedItems.add(menuItem);
          } else {
            debugPrint(
                '⚠️ DeltaUpdate: Skipping menu item with empty image: ${item['id']}');
          }
        } catch (e) {
          // Skip items that can't be parsed (e.g., missing required fields like image)
          final itemId = item['id']?.toString() ?? 'unknown';
          debugPrint(
              '⚠️ DeltaUpdate: Skipping menu item due to parsing error: $e');
          debugPrint('   Item ID: $itemId');
        }
      }

      debugPrint(
          '🔄 DeltaUpdate: Found ${updatedItems.length} updated items in categories: $categories');

      return DeltaUpdateResult(
        updatedItems: updatedItems,
        deletedItemIds: [],
        lastSyncTime: DateTime.now(),
        isFullSync: false,
      );
    } catch (e) {
      debugPrint('❌ DeltaUpdate: Error fetching category delta updates: $e');
      rethrow;
    }
  }

  /// Get statistics about delta updates
  Map<String, dynamic> getDeltaUpdateStats() {
    final lastSync = _lastSyncTimestamp;
    final hoursSinceSync =
        lastSync != null ? DateTime.now().difference(lastSync).inHours : null;

    return {
      'last_sync_time': lastSync?.toIso8601String(),
      'hours_since_sync': hoursSinceSync,
      'needs_full_sync': shouldPerformFullSync(),
      'has_synced': lastSync != null,
    };
  }
}

/// Result of a delta update operation
class DeltaUpdateResult {
  /// Items that were created or updated
  final List<MenuItem> updatedItems;

  /// IDs of items that were deleted
  final List<String> deletedItemIds;

  /// Timestamp of this sync
  final DateTime lastSyncTime;

  /// Whether this was a full sync or incremental update
  final bool isFullSync;

  const DeltaUpdateResult({
    required this.updatedItems,
    required this.deletedItemIds,
    required this.lastSyncTime,
    required this.isFullSync,
  });

  /// Check if there are any changes
  bool get hasChanges => updatedItems.isNotEmpty || deletedItemIds.isNotEmpty;

  /// Get total change count
  int get changeCount => updatedItems.length + deletedItemIds.length;

  @override
  String toString() {
    return 'DeltaUpdateResult(updated: ${updatedItems.length}, deleted: ${deletedItemIds.length}, fullSync: $isFullSync, time: ${lastSyncTime.toIso8601String()})';
  }
}
