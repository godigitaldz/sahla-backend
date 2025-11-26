import "dart:async";
import "package:flutter/foundation.dart";

/// Unified Performance Service
/// Consolidates all performance monitoring, caching, and optimization functionality
/// into a single, efficient service to eliminate redundancy and improve performance
class UnifiedPerformanceService extends ChangeNotifier {
  factory UnifiedPerformanceService() => _instance;
  UnifiedPerformanceService._internal();

  static final UnifiedPerformanceService _instance =
      UnifiedPerformanceService._internal();

  // Performance metrics storage
  final Map<String, PerformanceMetric> _metrics = {};
  final List<PerformanceEvent> _events = [];
  final List<PerformanceIssue> _issues = [];

  // Start operation tracking
  void startOperation(String operationId) {
    _metrics[operationId] = PerformanceMetric(
      operationId: operationId,
      startTime: DateTime.now(),
      endTime: null,
      duration: null,
      memoryUsage: 0,
      cpuUsage: 0,
      networkRequests: 0,
      cacheHits: 0,
      cacheMisses: 0,
    );
  }

  // End operation tracking
  void endOperation(String operationId) {
    final metric = _metrics[operationId];
    if (metric != null) {
      final endTime = DateTime.now();
      final duration = endTime.difference(metric.startTime);

      _metrics[operationId] = PerformanceMetric(
        operationId: operationId,
        startTime: metric.startTime,
        endTime: endTime,
        duration: duration,
        memoryUsage: metric.memoryUsage,
        cpuUsage: metric.cpuUsage,
        networkRequests: metric.networkRequests,
        cacheHits: metric.cacheHits,
        cacheMisses: metric.cacheMisses,
      );
    }
  }

  // Get operation statistics
  Map<String, dynamic> getOperationStats() {
    return {
      "totalOperations": _metrics.length,
      "averageDuration": _metrics.values
              .where((m) => m.duration != null)
              .map((m) => m.duration!.inMilliseconds)
              .fold(0, (a, b) => a + b) /
          _metrics.length,
      "cacheHitRate": _cacheHitCounts.values.fold(0, (a, b) => a + b),
    };
  }

  // Clear statistics
  void clearStats() {
    _metrics.clear();
    _events.clear();
    _issues.clear();
  }

  // Unified cache management
  final Map<String, CacheEntry> _cache = {};
  final Map<String, Timer> _cacheTimers = {};
  final Map<String, int> _cacheHitCounts = {};

  // Image optimization
  final Map<String, ImageCacheEntry> _imageCache = {};

  // Memory management
  int _memoryUsage = 0;
  static const int _maxMemoryUsage = 100 * 1024 * 1024; // 100MB

  // Network optimization
  final Map<String, NetworkRequest> _pendingRequests = {};

  // Performance monitoring
  Timer? _performanceTimer;
  Timer? _memoryTimer;
  Timer? _cacheCleanupTimer;
  bool _isMonitoring = false;

  // Cache configuration
  static const Duration _cacheExpiry = Duration(minutes: 30);

  // Getters
  Map<String, PerformanceMetric> get metrics => Map.unmodifiable(_metrics);
  List<PerformanceEvent> get events => List.unmodifiable(_events);
  List<PerformanceIssue> get issues => List.unmodifiable(_issues);

  // Initialize performance monitoring
  void initialize() {
    if (_isMonitoring) {
      return;
    }

    _isMonitoring = true;

    // Start performance monitoring timer
    _performanceTimer = Timer.periodic(
      const Duration(seconds: 5),
      (timer) => _collectPerformanceMetrics(),
    );

    // Start memory monitoring timer
    _memoryTimer = Timer.periodic(
      const Duration(seconds: 10),
      (timer) => _monitorMemoryUsage(),
    );

    // Start cache cleanup timer
    _cacheCleanupTimer = Timer.periodic(
      const Duration(minutes: 5),
      (timer) => _cleanupExpiredCache(),
    );
  }

  // Dispose resources
  @override
  void dispose() {
    _performanceTimer?.cancel();
    _memoryTimer?.cancel();
    _cacheCleanupTimer?.cancel();
    _isMonitoring = false;
    super.dispose();
  }

  // Collect performance metrics
  void _collectPerformanceMetrics() {
    // Memory usage metrics
    _metrics["memory_usage"] = PerformanceMetric(
      operationId: "memory_usage",
      startTime: DateTime.now(),
      memoryUsage: _memoryUsage,
      cpuUsage: 0,
      networkRequests: 0,
      cacheHits: 0,
      cacheMisses: 0,
    );

    // Memory usage percentage
    _metrics["memory_usage_percentage"] = PerformanceMetric(
      operationId: "memory_usage_percentage",
      startTime: DateTime.now(),
      memoryUsage: (_memoryUsage / _maxMemoryUsage * 100).round(),
      cpuUsage: 0,
      networkRequests: 0,
      cacheHits: 0,
      cacheMisses: 0,
    );

    // Cache size metrics
    _metrics["cache_size"] = PerformanceMetric(
      operationId: "cache_size",
      startTime: DateTime.now(),
      memoryUsage: _cache.length,
      cpuUsage: 0,
      networkRequests: 0,
      cacheHits: 0,
      cacheMisses: 0,
    );

    // Cache hit rate
    _metrics["cache_hit_rate"] = PerformanceMetric(
      operationId: "cache_hit_rate",
      startTime: DateTime.now(),
      memoryUsage: _cacheHitCounts.values.fold(0, (a, b) => a + b),
      cpuUsage: 0,
      networkRequests: 0,
      cacheHits: 0,
      cacheMisses: 0,
    );

    // Frame rate (simplified)
    _metrics["frame_rate"] = PerformanceMetric(
      operationId: "frame_rate",
      startTime: DateTime.now(),
      memoryUsage: 60, // Placeholder
      cpuUsage: 0,
      networkRequests: 0,
      cacheHits: 0,
      cacheMisses: 0,
    );

    // Active network requests
    _metrics["active_network_requests"] = PerformanceMetric(
      operationId: "active_network_requests",
      startTime: DateTime.now(),
      memoryUsage: _pendingRequests.length,
      cpuUsage: 0,
      networkRequests: 0,
      cacheHits: 0,
      cacheMisses: 0,
    );
  }

  // Monitor memory usage
  void _monitorMemoryUsage() {
    // Simplified memory monitoring
    _memoryUsage = _cache.length * 1024; // Estimate
  }

  // Cleanup expired cache
  void _cleanupExpiredCache() {
    final now = DateTime.now();
    _cache.removeWhere((key, entry) {
      if (now.difference(entry.timestamp) > _cacheExpiry) {
        _cacheTimers[key]?.cancel();
        _cacheTimers.remove(key);
        return true;
      }
      return false;
    });
  }

  // Cache operations
  void cache(String key, Object value, {Duration? ttl}) {
    final expiry = ttl ?? _cacheExpiry;
    _cache[key] = CacheEntry(
      key: key,
      value: value,
      timestamp: DateTime.now(),
      ttl: expiry,
    );

    // Set cleanup timer
    _cacheTimers[key] = Timer(expiry, () {
      _cache.remove(key);
      _cacheTimers.remove(key);
    });
  }

  Object? getCached(String key) {
    final entry = _cache[key];
    if (entry != null) {
      _cacheHitCounts[key] = (_cacheHitCounts[key] ?? 0) + 1;
      return entry.value;
    }
    return null;
  }

  void clearCache() {
    _cache.clear();
    for (final timer in _cacheTimers.values) {
      timer.cancel();
    }
    _cacheTimers.clear();
    _cacheHitCounts.clear();
  }

  // Image cache operations
  void cacheImage(String url, String localPath, int size) {
    _imageCache[url] = ImageCacheEntry(
      url: url,
      localPath: localPath,
      timestamp: DateTime.now(),
      size: size,
    );
  }

  String? getCachedImage(String url) {
    final entry = _imageCache[url];
    if (entry != null) {
      return entry.localPath;
    }
    return null;
  }

  // Network request tracking
  void trackRequest(String url, String method) {
    _pendingRequests[url] = NetworkRequest(
      url: url,
      method: method,
      timestamp: DateTime.now(),
      duration: Duration.zero,
      statusCode: 0,
    );
  }

  void completeRequest(String url, int statusCode, Duration duration) {
    final request = _pendingRequests.remove(url);
    if (request != null) {
      // Log completed request
      _events.add(PerformanceEvent(
        id: url,
        type: "network_request",
        timestamp: DateTime.now(),
        data: {
          "url": url,
          "method": request.method,
          "status_code": statusCode,
          "duration_ms": duration.inMilliseconds,
        },
      ));
    }
  }
}

// Supporting classes and enums
class PerformanceMetric {
  PerformanceMetric({
    required this.operationId,
    required this.startTime,
    required this.memoryUsage,
    required this.cpuUsage,
    required this.networkRequests,
    required this.cacheHits,
    required this.cacheMisses,
    this.endTime,
    this.duration,
  });

  final String operationId;
  final DateTime startTime;
  final DateTime? endTime;
  final Duration? duration;
  final int memoryUsage;
  final int cpuUsage;
  final int networkRequests;
  final int cacheHits;
  final int cacheMisses;
}

class PerformanceEvent {
  PerformanceEvent({
    required this.id,
    required this.type,
    required this.timestamp,
    required this.data,
  });

  final String id;
  final String type;
  final DateTime timestamp;
  final Map<String, dynamic> data;
}

class PerformanceIssue {
  PerformanceIssue({
    required this.id,
    required this.type,
    required this.description,
    required this.timestamp,
    required this.data,
  });

  final String id;
  final String type;
  final String description;
  final DateTime timestamp;
  final Map<String, dynamic> data;
}

class CacheEntry {
  CacheEntry({
    required this.key,
    required this.value,
    required this.timestamp,
    required this.ttl,
  });

  final String key;
  final Object value;
  final DateTime timestamp;
  final Duration ttl;
}

class ImageCacheEntry {
  ImageCacheEntry({
    required this.url,
    required this.localPath,
    required this.timestamp,
    required this.size,
  });

  final String url;
  final String localPath;
  final DateTime timestamp;
  final int size;
}

class NetworkRequest {
  NetworkRequest({
    required this.url,
    required this.method,
    required this.timestamp,
    required this.duration,
    required this.statusCode,
  });

  final String url;
  final String method;
  final DateTime timestamp;
  final Duration duration;
  final int statusCode;
}

class PerformanceConfig {
  const PerformanceConfig({
    this.enableCaching = true,
    this.enableMonitoring = true,
    this.cacheExpiry = const Duration(minutes: 30),
    this.maxCacheSize = 100,
  });

  final bool enableCaching;
  final bool enableMonitoring;
  final Duration cacheExpiry;
  final int maxCacheSize;
}
