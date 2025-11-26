/// LRU (Least Recently Used) Cache implementation with size limits
///
/// This cache automatically evicts the least recently used items when
/// the maximum size is reached, preventing unbounded memory growth.
///
/// Usage:
/// ```dart
/// final cache = LRUCache<String, MenuItem>(maxSize: 50);
/// cache.put('key1', menuItem);
/// final item = cache.get('key1');
/// ```
class LRUCache<K, V> {
  /// Maximum number of entries in the cache
  final int maxSize;

  /// Internal storage for cache entries
  final Map<K, V> _cache = {};

  /// Access order tracking (most recent at end)
  final List<K> _accessOrder = [];

  /// Create an LRU cache with the specified maximum size
  LRUCache(this.maxSize) : assert(maxSize > 0, 'maxSize must be positive');

  /// Get a value from the cache
  ///
  /// Returns the cached value if present, null otherwise.
  /// Updates the access order to mark this item as recently used.
  V? get(K key) {
    if (_cache.containsKey(key)) {
      // Move to end (most recently used)
      _accessOrder.remove(key);
      _accessOrder.add(key);
      return _cache[key];
    }
    return null;
  }

  /// Put a value into the cache
  ///
  /// If the key already exists, it will be updated and moved to the end.
  /// If the cache is full, the least recently used item will be evicted.
  void put(K key, V value) {
    if (_cache.containsKey(key)) {
      // Update existing entry and move to end
      _accessOrder.remove(key);
    } else if (_cache.length >= maxSize) {
      // Evict least recently used item (first in list)
      final oldest = _accessOrder.removeAt(0);
      _cache.remove(oldest);
    }

    _cache[key] = value;
    _accessOrder.add(key);
  }

  /// Check if the cache contains a key
  bool containsKey(K key) => _cache.containsKey(key);

  /// Remove a specific entry from the cache
  V? remove(K key) {
    _accessOrder.remove(key);
    return _cache.remove(key);
  }

  /// Clear all entries from the cache
  void clear() {
    _cache.clear();
    _accessOrder.clear();
  }

  /// Get the current number of entries in the cache
  int get length => _cache.length;

  /// Check if the cache is empty
  bool get isEmpty => _cache.isEmpty;

  /// Check if the cache is at maximum capacity
  bool get isFull => _cache.length >= maxSize;

  /// Get all keys currently in the cache
  Iterable<K> get keys => _cache.keys;

  /// Get all values currently in the cache
  Iterable<V> get values => _cache.values;

  /// Get cache statistics for debugging
  Map<String, dynamic> getStats() {
    return {
      'size': length,
      'maxSize': maxSize,
      'utilization': '${((length / maxSize) * 100).toStringAsFixed(1)}%',
      'isFull': isFull,
    };
  }
}
