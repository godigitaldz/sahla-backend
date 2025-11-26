import 'dart:async';

/// Request deduplication to prevent duplicate concurrent requests
class RequestDedupe<K, V> {
  final Map<K, Future<V>> _inflight = {};

  /// Execute request with deduplication
  /// If a request with the same key is already in flight, returns the existing future
  Future<V> execute(K key, Future<V> Function() runner) async {
    // Check if request is already in flight
    if (_inflight.containsKey(key)) {
      return _inflight[key]!;
    }

    // Create new request
    final future = runner().whenComplete(() {
      _inflight.remove(key);
    });

    _inflight[key] = future;
    return future;
  }

  /// Cancel request by key
  void cancel(K key) {
    _inflight.remove(key);
  }

  /// Clear all inflight requests
  void clear() {
    _inflight.clear();
  }

  /// Get number of inflight requests
  int get inflightCount => _inflight.length;

  /// Check if key is inflight
  bool isInflight(K key) => _inflight.containsKey(key);
}
