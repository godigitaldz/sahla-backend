import 'dart:async';

import 'package:flutter/foundation.dart';

import 'cache/disk_cache.dart';
import 'cache/memory_cache.dart';
import 'request_dedupe.dart';

/// Result with stale flag for stale-while-revalidate
class CacheResult<T> {
  final T data;
  final bool isStale;

  CacheResult({
    required this.data,
    this.isStale = false,
  });
}

/// Base repository with 3-tier caching (Memory → Disk → Network) + stale-while-revalidate
abstract class RepositoryBase<K, V> {
  final MemoryCache<K, V> _memoryCache;
  final DiskCache<K, V> _diskCache;
  final RequestDedupe<K, V> _dedupe;

  RepositoryBase({
    Duration? memoryTtl,
    Duration? diskTtl,
    int? maxMemorySize,
  })  : _memoryCache = MemoryCache<K, V>(
          defaultTtl: memoryTtl ?? const Duration(minutes: 5),
          maxSize: maxMemorySize ?? 100,
        ),
        _diskCache = DiskCache<K, V>(
          defaultTtl: diskTtl ?? const Duration(hours: 24),
        ),
        _dedupe = RequestDedupe<K, V>();

  /// Initialize disk cache
  Future<void> initialize() async {
    await DiskCache.initialize();
  }

  /// Get item with 3-tier cache + stale-while-revalidate
  Future<CacheResult<V>> get(
    K key, {
    bool forceRefresh = false,
  }) async {
    // Force refresh skips cache
    if (forceRefresh) {
      final value = await fetchFromNetwork(key);
      // Cache in memory and disk
      _memoryCache.put(key, value);
      await _diskCache.put(key, value, toJson);
      return CacheResult(data: value, isStale: false);
    }

    // Tier 1: Memory cache
    final memValue = _memoryCache.get(key);
    if (memValue != null) {
      // Return immediately, refresh in background
      unawaited(_refreshInBackground(key));
      return CacheResult(data: memValue, isStale: false);
    }

    // Tier 2: Disk cache
    final diskValue = await _diskCache.get(key, fromJson);
    if (diskValue != null) {
      // Return immediately (stale), refresh in background
      unawaited(_refreshInBackground(key));
      return CacheResult(data: diskValue, isStale: true);
    }

    // Tier 3: Network (with deduplication)
    final result = await _dedupe.execute(
      key,
      () async {
        final value = await fetchFromNetwork(key);
        // Cache in memory and disk
        _memoryCache.put(key, value);
        await _diskCache.put(key, value, toJson);
        return value;
      },
    );

    return CacheResult(data: result, isStale: false);
  }

  /// Refresh in background (stale-while-revalidate)
  Future<void> _refreshInBackground(K key) async {
    try {
      final value = await fetchFromNetwork(key);

      // Update caches
      _memoryCache.put(key, value);
      await _diskCache.put(key, value, toJson);
    } catch (e) {
      // Ignore background refresh errors
      debugPrint('Background refresh failed for key $key: $e');
    }
  }

  /// Fetch from network (implemented by subclasses)
  Future<V> fetchFromNetwork(K key);

  /// Convert to JSON (implemented by subclasses)
  Map<String, dynamic> toJson(V value);

  /// Convert from JSON (implemented by subclasses)
  V fromJson(Map<String, dynamic> json);

  /// Cache item directly (for batch operations)
  Future<void> cacheItem(K key, V value) async {
    _memoryCache.put(key, value);
    await _diskCache.put(key, value, toJson);
  }

  /// Clear all caches
  Future<void> clearCache() async {
    _memoryCache.clear();
    await _diskCache.clear();
    _dedupe.clear();
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getCacheStats() async {
    final memStats = _memoryCache.getStats();
    final diskStats = await _diskCache.getStats();

    return {
      'memory': memStats,
      'disk': diskStats,
      'inflight': _dedupe.inflightCount,
    };
  }
}

/// Unawaited helper
void unawaited(Future<void> future) {
  // Ignore future completion
}
