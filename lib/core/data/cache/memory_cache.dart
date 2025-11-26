import 'dart:collection';

/// Memory cache with TTL and LRU eviction
class MemoryCache<K, V> {
  final Map<K, _CacheEntry<V>> _cache = {};
  final LinkedHashSet<K> _accessOrder = LinkedHashSet();
  final Duration _defaultTtl;
  final int? _maxSize;

  MemoryCache({
    Duration? defaultTtl,
    int? maxSize,
  })  : _defaultTtl = defaultTtl ?? const Duration(minutes: 5),
        _maxSize = maxSize;

  /// Get value from cache
  V? get(K key) {
    final entry = _cache[key];
    if (entry == null) return null;

    // Check expiry
    if (entry.isExpired) {
      _cache.remove(key);
      _accessOrder.remove(key);
      return null;
    }

    // Update access order (LRU)
    _accessOrder.remove(key);
    _accessOrder.add(key);

    return entry.value;
  }

  /// Put value in cache
  void put(K key, V value, {Duration? ttl}) {
    // Evict if at capacity
    if (_maxSize != null &&
        _cache.length >= _maxSize &&
        !_cache.containsKey(key)) {
      _evictOldest();
    }

    // Remove from access order if exists
    _accessOrder.remove(key);

    // Add to cache
    _cache[key] = _CacheEntry(
      value: value,
      expiresAt: DateTime.now().add(ttl ?? _defaultTtl),
    );

    // Add to access order
    _accessOrder.add(key);
  }

  /// Remove value from cache
  void remove(K key) {
    _cache.remove(key);
    _accessOrder.remove(key);
  }

  /// Clear all entries
  void clear() {
    _cache.clear();
    _accessOrder.clear();
  }

  /// Check if key exists and is not expired
  bool containsKey(K key) {
    final entry = _cache[key];
    if (entry == null) return false;
    if (entry.isExpired) {
      _cache.remove(key);
      _accessOrder.remove(key);
      return false;
    }
    return true;
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    final expiredCount = _cache.values.where((e) => e.isExpired).length;
    return {
      'size': _cache.length,
      'max_size': _maxSize,
      'expired_count': expiredCount,
      'valid_count': _cache.length - expiredCount,
    };
  }

  /// Evict oldest entry (LRU)
  void _evictOldest() {
    if (_accessOrder.isEmpty) return;
    final oldestKey = _accessOrder.first;
    _cache.remove(oldestKey);
    _accessOrder.remove(oldestKey);
  }
}

/// Cache entry with expiry
class _CacheEntry<V> {
  final V value;
  final DateTime expiresAt;

  _CacheEntry({
    required this.value,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
