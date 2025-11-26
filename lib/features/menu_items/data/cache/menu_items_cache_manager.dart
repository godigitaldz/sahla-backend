import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../../models/menu_item.dart';
import '../../domain/models/menu_items_state.dart';

/// Cache manager for menu items using Hive
class MenuItemsCacheManager {
  late Box<CachedMenuItems> _box;
  final _stats = CacheStatistics();
  bool _initialized = false;

  /// Initialize Hive and open box
  Future<void> init() async {
    if (_initialized) return;

    try {
      await Hive.initFlutter();

      // Register adapters if not already registered
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(CachedMenuItemsAdapter());
      }

      try {
        _box = await Hive.openBox<CachedMenuItems>('menu_items_cache');
      } catch (e) {
        // If opening box fails (e.g., corrupted cache), delete and recreate
        debugPrint('⚠️ CacheManager: Error opening box, clearing cache: $e');
        try {
          await Hive.deleteBoxFromDisk('menu_items_cache');
          _box = await Hive.openBox<CachedMenuItems>('menu_items_cache');
        } catch (_) {
          // If deletion fails, try opening without type safety
          _box = await Hive.openBox('menu_items_cache') as Box<CachedMenuItems>;
        }
      }

      _initialized = true;

      // Clean expired entries on init
      await _cleanExpired();

      debugPrint('✅ CacheManager: Initialized (${_box.length} cached items)');
    } catch (e) {
      debugPrint('❌ CacheManager: Initialization failed: $e');
      // Don't rethrow - allow app to continue without cache
      _initialized = false;
    }
  }

  /// Get cached menu items
  Future<CachedMenuItems?> get(String key) async {
    if (!_initialized) await init();

    try {
      final cached = _box.get(key);

      if (cached == null) {
        _stats.recordMiss();
        return null;
      }

      if (cached.isExpired) {
        await _box.delete(key);
        _stats.recordMiss();
        return null;
      }

      // Validate cached data structure
      if (cached.data.items.isEmpty && cached.data.totalCount > 0) {
        // Corrupted cache entry (old format), delete it
        debugPrint('⚠️ CacheManager: Detected corrupted cache entry, clearing');
        await _box.delete(key);
        _stats.recordMiss();
        return null;
      }

      _stats.recordHit();
      return cached;
    } catch (e) {
      // Handle errors from old cache format
      debugPrint('❌ CacheManager: Error reading cache ($key): $e');
      try {
        // Delete corrupted entry
        await _box.delete(key);
      } catch (_) {
        // Ignore deletion errors
      }
      _stats.recordMiss();
      return null;
    }
  }

  /// Set cached menu items
  Future<void> set(
    String key,
    PaginatedResult<MenuItem> data, {
    required Duration ttl,
  }) async {
    if (!_initialized) await init();

    final cached = CachedMenuItems(
      data: data,
      cachedAt: DateTime.now(),
      ttl: ttl,
    );

    await _box.put(key, cached);

    // Enforce size limit (keep only 50 most recent)
    if (_box.length > 50) {
      final oldestKeys = _box.keys.take(_box.length - 50).toList();
      await _box.deleteAll(oldestKeys);
      debugPrint('🗑️ CacheManager: Evicted ${oldestKeys.length} old entries');
    }
  }

  /// Clear all cache
  Future<void> clear() async {
    if (!_initialized) await init();

    await _box.clear();
    debugPrint('🗑️ CacheManager: All cache cleared');
  }

  /// Clean expired entries
  Future<void> _cleanExpired() async {
    final expiredKeys = <String>[];

    for (final key in _box.keys) {
      final cached = _box.get(key);
      if (cached != null && cached.isExpired) {
        expiredKeys.add(key.toString());
      }
    }

    if (expiredKeys.isNotEmpty) {
      await _box.deleteAll(expiredKeys);
      debugPrint(
          '🗑️ CacheManager: Cleaned ${expiredKeys.length} expired entries');
    }
  }

  /// Get cache statistics
  CacheStatistics get statistics => _stats;
}

/// Cached menu items model
@HiveType(typeId: 0)
class CachedMenuItems {
  CachedMenuItems({
    required this.data,
    required this.cachedAt,
    required this.ttl,
  });

  @HiveField(0)
  final PaginatedResult<MenuItem> data;

  @HiveField(1)
  final DateTime cachedAt;

  @HiveField(2)
  final Duration ttl;

  bool get isExpired => DateTime.now().difference(cachedAt) > ttl;
  bool get isValid => !isExpired;
}

/// Hive adapter for CachedMenuItems
class CachedMenuItemsAdapter extends TypeAdapter<CachedMenuItems> {
  @override
  final int typeId = 0;

  @override
  CachedMenuItems read(BinaryReader reader) {
    // Read items count
    final itemsCount = reader.readInt();

    // Read all menu items as JSON maps
    final items = <MenuItem>[];
    for (int i = 0; i < itemsCount; i++) {
      final itemJson = Map<String, dynamic>.from(reader.readMap());
      items.add(MenuItem.fromJson(itemJson));
    }

    // Read pagination metadata
    final nextCursor = reader.readString();
    final hasMore = reader.readBool();
    final totalCount = reader.readInt();

    // Read cache metadata
    final cachedAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    final ttl = Duration(milliseconds: reader.readInt());

    return CachedMenuItems(
      data: PaginatedResult(
        items: items,
        nextCursor: nextCursor.isEmpty ? null : nextCursor,
        hasMore: hasMore,
        totalCount: totalCount,
      ),
      cachedAt: cachedAt,
      ttl: ttl,
    );
  }

  @override
  void write(BinaryWriter writer, CachedMenuItems obj) {
    // Write items count
    writer.writeInt(obj.data.items.length);

    // Write all menu items as JSON maps
    for (final item in obj.data.items) {
      writer.writeMap(item.toJson());
    }

    // Write pagination metadata
    writer.writeString(obj.data.nextCursor ?? '');
    writer.writeBool(obj.data.hasMore);
    writer.writeInt(obj.data.totalCount);

    // Write cache metadata
    writer.writeInt(obj.cachedAt.millisecondsSinceEpoch);
    writer.writeInt(obj.ttl.inMilliseconds);
  }
}

/// Cache statistics tracker
class CacheStatistics {
  int _hits = 0;
  int _misses = 0;

  void recordHit() => _hits++;
  void recordMiss() => _misses++;

  double get hitRate {
    final total = _hits + _misses;
    return total == 0 ? 0 : _hits / total;
  }

  Map<String, dynamic> toJson() => {
        'hits': _hits,
        'misses': _misses,
        'hit_rate': (hitRate * 100).toStringAsFixed(1),
      };
}
