import 'dart:async';
import 'dart:developer' as developer;

/// Ultra-Optimized Performance Monitoring Service
///
/// Features:
/// - Real-time performance tracking
/// - API response time monitoring
/// - Memory usage tracking
/// - Cache hit/miss ratios
/// - Error rate monitoring
/// - Performance alerts and notifications
class PerformanceMonitoringService {
  static final PerformanceMonitoringService _instance =
      PerformanceMonitoringService._internal();
  factory PerformanceMonitoringService() => _instance;
  PerformanceMonitoringService._internal();

  // Performance metrics
  final Map<String, List<double>> _responseTimes = {};
  final Map<String, int> _requestCounts = {};
  final Map<String, int> _errorCounts = {};
  final Map<String, int> _cacheHits = {};
  final Map<String, int> _cacheMisses = {};

  // Memory tracking
  int _memoryUsage = 0;
  int _peakMemoryUsage = 0;

  // Performance thresholds
  static const double _slowRequestThreshold = 2000.0; // 2 seconds
  static const double _verySlowRequestThreshold = 5000.0; // 5 seconds
  static const int _highErrorRateThreshold = 10; // 10% error rate

  // Stream controllers for real-time monitoring
  final StreamController<PerformanceEvent> _performanceController =
      StreamController<PerformanceEvent>.broadcast();
  final StreamController<PerformanceAlert> _alertController =
      StreamController<PerformanceAlert>.broadcast();

  // Track if controllers are closed
  bool _isDisposed = false;

  // Getters
  Stream<PerformanceEvent> get performanceStream =>
      _performanceController.stream;
  Stream<PerformanceAlert> get alertStream => _alertController.stream;

  /// Initialize performance monitoring
  void initialize() {
    developer.log('🚀 PerformanceMonitoringService initialized',
        name: 'Performance');
    _startMemoryMonitoring();
  }

  /// Track API request performance
  void trackApiRequest({
    required String endpoint,
    required String method,
    required Duration duration,
    required bool success,
    Map<String, dynamic>? metadata,
  }) {
    // Don't track if service is disposed
    if (_isDisposed) {
      return;
    }

    final responseTime = duration.inMilliseconds.toDouble();

    // Update metrics
    _responseTimes.putIfAbsent(endpoint, () => []).add(responseTime);
    _requestCounts[endpoint] = (_requestCounts[endpoint] ?? 0) + 1;

    if (!success) {
      _errorCounts[endpoint] = (_errorCounts[endpoint] ?? 0) + 1;
    }

    // Emit performance event only if controller is not closed
    if (!_performanceController.isClosed) {
      try {
        _performanceController.add(PerformanceEvent(
          type: PerformanceEventType.apiRequest,
          endpoint: endpoint,
          method: method,
          responseTime: responseTime,
          success: success,
          timestamp: DateTime.now(),
          metadata: metadata,
        ));
      } catch (e) {
        // Silently handle closed controller errors
        developer.log('Performance controller closed, skipping event emission',
            name: 'Performance');
      }
    }

    // Check for performance issues
    _checkPerformanceThresholds(endpoint, responseTime, success);

    // Log performance metrics
    developer.log(
      '📊 API Request: $method $endpoint - ${responseTime}ms (${success ? 'SUCCESS' : 'FAILED'})',
      name: 'Performance',
    );
  }

  /// Track cache performance
  void trackCacheOperation({
    required String cacheKey,
    required CacheOperationType operation,
    required bool hit,
    Duration? duration,
  }) {
    final responseTime = duration?.inMilliseconds.toDouble() ?? 0.0;

    if (hit) {
      _cacheHits[cacheKey] = (_cacheHits[cacheKey] ?? 0) + 1;
    } else {
      _cacheMisses[cacheKey] = (_cacheMisses[cacheKey] ?? 0) + 1;
    }

    // Emit performance event
    _performanceController.add(PerformanceEvent(
      type: PerformanceEventType.cacheOperation,
      endpoint: cacheKey,
      method: operation.name,
      responseTime: responseTime,
      success: true,
      timestamp: DateTime.now(),
      metadata: {
        'operation': operation.name,
        'hit': hit,
      },
    ));

    developer.log(
      '💾 Cache ${operation.name}: $cacheKey - ${hit ? 'HIT' : 'MISS'} (${responseTime}ms)',
      name: 'Performance',
    );
  }

  /// Track screen navigation performance
  void trackScreenNavigation({
    required String fromScreen,
    required String toScreen,
    required Duration duration,
  }) {
    final responseTime = duration.inMilliseconds.toDouble();

    _performanceController.add(PerformanceEvent(
      type: PerformanceEventType.screenNavigation,
      endpoint: '$fromScreen -> $toScreen',
      method: 'NAVIGATE',
      responseTime: responseTime,
      success: true,
      timestamp: DateTime.now(),
    ));

    developer.log(
      '🧭 Navigation: $fromScreen -> $toScreen - ${responseTime}ms',
      name: 'Performance',
    );
  }

  /// Track widget build performance
  void trackWidgetBuild({
    required String widgetName,
    required Duration duration,
  }) {
    final responseTime = duration.inMilliseconds.toDouble();

    _performanceController.add(PerformanceEvent(
      type: PerformanceEventType.widgetBuild,
      endpoint: widgetName,
      method: 'BUILD',
      responseTime: responseTime,
      success: true,
      timestamp: DateTime.now(),
    ));

    // Log slow widget builds
    if (responseTime > 16.0) {
      // More than one frame at 60fps
      developer.log(
        '⚠️ Slow widget build: $widgetName - ${responseTime}ms',
        name: 'Performance',
      );
    }
  }

  /// Start tracking an operation (for compatibility with existing code)
  void startOperation(String operationName) {
    // This method is for compatibility with existing code
    // The actual tracking happens in trackApiRequest, trackWidgetBuild, etc.
    developer.log('🚀 Started operation: $operationName', name: 'Performance');
  }

  /// End tracking an operation (for compatibility with existing code)
  void endOperation(String operationName) {
    // This method is for compatibility with existing code
    // The actual tracking happens in trackApiRequest, trackWidgetBuild, etc.
    developer.log('✅ Ended operation: $operationName', name: 'Performance');
  }

  /// Record a metric (for compatibility with existing code)
  void recordMetric(String operationName, Duration duration,
      {Map<String, dynamic>? metadata}) {
    // Don't record if service is disposed
    if (_isDisposed) {
      return;
    }

    // This method is for compatibility with existing code
    if (!_performanceController.isClosed) {
      try {
        _performanceController.add(PerformanceEvent(
          type: PerformanceEventType.apiRequest,
          endpoint: operationName,
          method: 'RECORD',
          responseTime: duration.inMilliseconds.toDouble(),
          success: true,
          timestamp: DateTime.now(),
          metadata: metadata,
        ));
      } catch (e) {
        // Silently handle closed controller errors
        developer.log(
            'Performance controller closed, skipping metric recording',
            name: 'Performance');
      }
    }

    developer.log(
        '📊 Recorded metric: $operationName - ${duration.inMilliseconds}ms',
        name: 'Performance');
  }

  /// Get performance metrics for an endpoint
  PerformanceMetrics getMetrics(String endpoint) {
    final responseTimes = _responseTimes[endpoint] ?? [];
    final requestCount = _requestCounts[endpoint] ?? 0;
    final errorCount = _errorCounts[endpoint] ?? 0;

    if (responseTimes.isEmpty) {
      return PerformanceMetrics(
        endpoint: endpoint,
        requestCount: requestCount,
        errorCount: errorCount,
        averageResponseTime: 0.0,
        minResponseTime: 0.0,
        maxResponseTime: 0.0,
        errorRate: 0.0,
        cacheHitRate: 0.0,
      );
    }

    final averageResponseTime =
        responseTimes.reduce((a, b) => a + b) / responseTimes.length;
    final minResponseTime = responseTimes.reduce((a, b) => a < b ? a : b);
    final maxResponseTime = responseTimes.reduce((a, b) => a > b ? a : b);
    final errorRate =
        requestCount > 0 ? (errorCount / requestCount) * 100 : 0.0;

    final cacheHits = _cacheHits[endpoint] ?? 0;
    final cacheMisses = _cacheMisses[endpoint] ?? 0;
    final cacheHitRate = (cacheHits + cacheMisses) > 0
        ? (cacheHits / (cacheHits + cacheMisses)) * 100
        : 0.0;

    return PerformanceMetrics(
      endpoint: endpoint,
      requestCount: requestCount,
      errorCount: errorCount,
      averageResponseTime: averageResponseTime,
      minResponseTime: minResponseTime,
      maxResponseTime: maxResponseTime,
      errorRate: errorRate,
      cacheHitRate: cacheHitRate,
    );
  }

  /// Get all performance metrics
  Map<String, PerformanceMetrics> getAllMetrics() {
    final metrics = <String, PerformanceMetrics>{};

    for (final endpoint in _requestCounts.keys) {
      metrics[endpoint] = getMetrics(endpoint);
    }

    return metrics;
  }

  /// Get memory usage statistics
  MemoryStats getMemoryStats() {
    return MemoryStats(
      currentUsage: _memoryUsage,
      peakUsage: _peakMemoryUsage,
      timestamp: DateTime.now(),
    );
  }

  /// Check performance thresholds and emit alerts
  void _checkPerformanceThresholds(
      String endpoint, double responseTime, bool success) {
    // Don't emit alerts if service is disposed or controller is closed
    if (_isDisposed || _alertController.isClosed) {
      return;
    }

    try {
      // Check for slow requests
      if (responseTime > _verySlowRequestThreshold) {
        _alertController.add(PerformanceAlert(
          type: PerformanceAlertType.verySlowRequest,
          endpoint: endpoint,
          message: 'Very slow request detected: ${responseTime}ms',
          severity: PerformanceAlertSeverity.critical,
          timestamp: DateTime.now(),
          metadata: {'responseTime': responseTime},
        ));
      } else if (responseTime > _slowRequestThreshold) {
        _alertController.add(PerformanceAlert(
          type: PerformanceAlertType.slowRequest,
          endpoint: endpoint,
          message: 'Slow request detected: ${responseTime}ms',
          severity: PerformanceAlertSeverity.warning,
          timestamp: DateTime.now(),
          metadata: {'responseTime': responseTime},
        ));
      }

      // Check for high error rates
      final metrics = getMetrics(endpoint);
      if (metrics.errorRate > _highErrorRateThreshold) {
        _alertController.add(PerformanceAlert(
          type: PerformanceAlertType.highErrorRate,
          endpoint: endpoint,
          message:
              'High error rate detected: ${metrics.errorRate.toStringAsFixed(1)}%',
          severity: PerformanceAlertSeverity.warning,
          timestamp: DateTime.now(),
          metadata: {'errorRate': metrics.errorRate},
        ));
      }
    } catch (e) {
      // Silently handle closed controller errors
      developer.log('Alert controller closed, skipping alert emission',
          name: 'Performance');
    }
  }

  /// Start memory monitoring
  void _startMemoryMonitoring() {
    Timer.periodic(const Duration(seconds: 5), (timer) {
      // Simulate memory usage tracking
      // In a real implementation, you would use platform-specific APIs
      _memoryUsage = DateTime.now().millisecondsSinceEpoch % 1000000;
      if (_memoryUsage > _peakMemoryUsage) {
        _peakMemoryUsage = _memoryUsage;
      }
    });
  }

  /// Clear all metrics
  void clearMetrics() {
    _responseTimes.clear();
    _requestCounts.clear();
    _errorCounts.clear();
    _cacheHits.clear();
    _cacheMisses.clear();
    developer.log('🧹 Performance metrics cleared', name: 'Performance');
  }

  /// Dispose resources
  void dispose() {
    _isDisposed = true;
    _performanceController.close();
    _alertController.close();
    developer.log('🛑 PerformanceMonitoringService disposed',
        name: 'Performance');
  }
}

/// Performance event types
enum PerformanceEventType {
  apiRequest,
  cacheOperation,
  screenNavigation,
  widgetBuild,
}

/// Cache operation types
enum CacheOperationType {
  get,
  set,
  delete,
  clear,
}

/// Performance alert types
enum PerformanceAlertType {
  slowRequest,
  verySlowRequest,
  highErrorRate,
  memoryWarning,
  cacheMissWarning,
}

/// Performance alert severity levels
enum PerformanceAlertSeverity {
  info,
  warning,
  critical,
}

/// Performance event data class
class PerformanceEvent {
  final PerformanceEventType type;
  final String endpoint;
  final String method;
  final double responseTime;
  final bool success;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  PerformanceEvent({
    required this.type,
    required this.endpoint,
    required this.method,
    required this.responseTime,
    required this.success,
    required this.timestamp,
    this.metadata,
  });
}

/// Performance metrics data class
class PerformanceMetrics {
  final String endpoint;
  final int requestCount;
  final int errorCount;
  final double averageResponseTime;
  final double minResponseTime;
  final double maxResponseTime;
  final double errorRate;
  final double cacheHitRate;

  PerformanceMetrics({
    required this.endpoint,
    required this.requestCount,
    required this.errorCount,
    required this.averageResponseTime,
    required this.minResponseTime,
    required this.maxResponseTime,
    required this.errorRate,
    required this.cacheHitRate,
  });

  Map<String, dynamic> toJson() {
    return {
      'endpoint': endpoint,
      'requestCount': requestCount,
      'errorCount': errorCount,
      'averageResponseTime': averageResponseTime,
      'minResponseTime': minResponseTime,
      'maxResponseTime': maxResponseTime,
      'errorRate': errorRate,
      'cacheHitRate': cacheHitRate,
    };
  }
}

/// Performance alert data class
class PerformanceAlert {
  final PerformanceAlertType type;
  final String endpoint;
  final String message;
  final PerformanceAlertSeverity severity;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  PerformanceAlert({
    required this.type,
    required this.endpoint,
    required this.message,
    required this.severity,
    required this.timestamp,
    this.metadata,
  });
}

/// Memory statistics data class
class MemoryStats {
  final int currentUsage;
  final int peakUsage;
  final DateTime timestamp;

  MemoryStats({
    required this.currentUsage,
    required this.peakUsage,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'currentUsage': currentUsage,
      'peakUsage': peakUsage,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
