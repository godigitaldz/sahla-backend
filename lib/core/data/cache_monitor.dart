/// Cache monitor for production tracking
class CacheMonitor {
  static final CacheMonitor _instance = CacheMonitor._internal();
  factory CacheMonitor() => _instance;
  CacheMonitor._internal();

  // Metrics
  int _memoryHits = 0;
  int _memoryMisses = 0;
  int _diskHits = 0;
  int _diskMisses = 0;
  int _networkRequests = 0;
  int _totalRequests = 0;
  final Map<String, int> _operationCounts = {};
  final Map<String, List<Duration>> _operationDurations = {};
  final List<CacheEvent> _events = [];
  final int _maxEvents = 1000; // Keep last 1000 events

  /// Track cache hit
  void trackCacheHit(CacheTier tier, String operation) {
    _totalRequests++;
    _operationCounts[operation] = (_operationCounts[operation] ?? 0) + 1;

    switch (tier) {
      case CacheTier.memory:
        _memoryHits++;
        break;
      case CacheTier.disk:
        _diskHits++;
        break;
      case CacheTier.network:
        _networkRequests++;
        break;
    }

    _addEvent(CacheEvent(
      tier: tier,
      operation: operation,
      isHit: true,
      timestamp: DateTime.now(),
    ));
  }

  /// Track cache miss
  void trackCacheMiss(CacheTier tier, String operation) {
    _totalRequests++;
    _operationCounts[operation] = (_operationCounts[operation] ?? 0) + 1;

    switch (tier) {
      case CacheTier.memory:
        _memoryMisses++;
        break;
      case CacheTier.disk:
        _diskMisses++;
        break;
      case CacheTier.network:
        _networkRequests++;
        break;
    }

    _addEvent(CacheEvent(
      tier: tier,
      operation: operation,
      isHit: false,
      timestamp: DateTime.now(),
    ));
  }

  /// Track operation duration
  void trackOperationDuration(String operation, Duration duration) {
    _operationDurations.putIfAbsent(operation, () => []).add(duration);

    // Keep only last 100 durations per operation
    final durations = _operationDurations[operation]!;
    if (durations.length > 100) {
      durations.removeRange(0, durations.length - 100);
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getStats() {
    final memoryHitRate = (_memoryHits + _memoryMisses) > 0
        ? _memoryHits / (_memoryHits + _memoryMisses)
        : 0.0;

    final diskHitRate = (_diskHits + _diskMisses) > 0
        ? _diskHits / (_diskHits + _diskMisses)
        : 0.0;

    final overallHitRate =
        _totalRequests > 0 ? (_memoryHits + _diskHits) / _totalRequests : 0.0;

    // Calculate average durations
    final avgDurations = <String, double>{};
    _operationDurations.forEach((operation, durations) {
      if (durations.isNotEmpty) {
        final avgMs =
            durations.map((d) => d.inMilliseconds).reduce((a, b) => a + b) /
                durations.length;
        avgDurations[operation] = avgMs;
      }
    });

    return {
      'memory_hits': _memoryHits,
      'memory_misses': _memoryMisses,
      'memory_hit_rate': memoryHitRate,
      'disk_hits': _diskHits,
      'disk_misses': _diskMisses,
      'disk_hit_rate': diskHitRate,
      'network_requests': _networkRequests,
      'total_requests': _totalRequests,
      'overall_hit_rate': overallHitRate,
      'operation_counts': Map.from(_operationCounts),
      'average_durations_ms': avgDurations,
      'event_count': _events.length,
    };
  }

  /// Get recent events
  List<CacheEvent> getRecentEvents({int limit = 100}) {
    final events = _events.reversed.take(limit).toList();
    return events.reversed.toList(); // Return in chronological order
  }

  /// Clear all metrics
  void clear() {
    _memoryHits = 0;
    _memoryMisses = 0;
    _diskHits = 0;
    _diskMisses = 0;
    _networkRequests = 0;
    _totalRequests = 0;
    _operationCounts.clear();
    _operationDurations.clear();
    _events.clear();
  }

  /// Export metrics for production monitoring
  Map<String, dynamic> exportMetrics() {
    final stats = getStats();
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'metrics': stats,
      'recent_events':
          _events.reversed.take(50).map((e) => e.toJson()).toList(),
    };
  }

  void _addEvent(CacheEvent event) {
    _events.add(event);
    if (_events.length > _maxEvents) {
      _events.removeAt(0); // Remove oldest event
    }
  }
}

/// Cache tier enum
enum CacheTier {
  memory,
  disk,
  network,
}

/// Cache event for tracking
class CacheEvent {
  final CacheTier tier;
  final String operation;
  final bool isHit;
  final DateTime timestamp;

  CacheEvent({
    required this.tier,
    required this.operation,
    required this.isHit,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'tier': tier.name,
        'operation': operation,
        'is_hit': isHit,
        'timestamp': timestamp.toIso8601String(),
      };
}
