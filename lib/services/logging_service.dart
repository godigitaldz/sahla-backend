// ignore_for_file: avoid_slow_async_io, use_is_even_rather_than_modulo

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

enum LogLevel { debug, info, warning, error, critical }

class LoggingService {
  static final LoggingService _instance = LoggingService._internal();
  factory LoggingService() => _instance;
  LoggingService._internal();

  static const String _appName = 'SAHLA_DELIVERY_APP';
  static const bool _enableConsoleLogging = true;
  static const bool _enableFileLogging = true;
  static const LogLevel _minLogLevel = LogLevel.debug;
  static const int _maxLogFileSize = 5 * 1024 * 1024; // 5MB
  static const int _maxLogFiles = 5;
  static const int _maxLogsPerMinute = 100;
  static const int _sessionTimeoutMinutes = 30;

  // Session management
  String? _sessionId;
  DateTime? _sessionStartTime;
  DateTime? _lastActivityTime;
  bool _isSessionActive = false;

  // Performance tracking
  final Map<String, Stopwatch> _activeTimers = {};
  final Map<String, List<Duration>> _performanceHistory = {};
  final Map<String, int> _operationCounts = {};

  // Log management
  final List<LogEntry> _logBuffer = [];
  final List<PerformanceMetric> _performanceMetrics = [];
  int _logsThisMinute = 0;
  DateTime _lastMinuteReset = DateTime.now();

  // File logging
  File? _logFile;
  String? _logDirectory;

  /// Initialize the logging service with session management
  Future<void> initialize() async {
    try {
      // Initialize session
      await _initializeSession();

      // Initialize file logging
      if (_enableFileLogging) {
        await _initializeFileLogging();
      }

      // Start session monitoring
      _startSessionMonitoring();

      info('LoggingService initialized successfully', tag: 'INIT');
    } catch (e) {
      developer.log('Failed to initialize LoggingService: $e',
          name: _appName, level: 1000);
    }
  }

  /// Initialize permanent session
  Future<void> _initializeSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Check for existing session
      _sessionId = prefs.getString('logging_session_id');
      final sessionStartTimeStr = prefs.getString('logging_session_start');
      final lastActivityStr = prefs.getString('logging_last_activity');

      if (_sessionId != null && sessionStartTimeStr != null) {
        _sessionStartTime = DateTime.parse(sessionStartTimeStr);
        _lastActivityTime = lastActivityStr != null
            ? DateTime.parse(lastActivityStr)
            : DateTime.now();

        // Check if session is still valid
        final timeSinceLastActivity =
            DateTime.now().difference(_lastActivityTime!);
        if (timeSinceLastActivity.inMinutes < _sessionTimeoutMinutes) {
          _isSessionActive = true;
          info('Resumed existing session: $_sessionId', tag: 'SESSION');
          return;
        }
      }

      // Create new session
      await _createNewSession();
    } catch (e) {
      developer.log('Failed to initialize session: $e',
          name: _appName, level: 1000);
      await _createNewSession();
    }
  }

  /// Create a new permanent session
  Future<void> _createNewSession() async {
    try {
      _sessionId = const Uuid().v4();
      _sessionStartTime = DateTime.now();
      _lastActivityTime = DateTime.now();
      _isSessionActive = true;

      // Save session to persistent storage
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('logging_session_id', _sessionId!);
      await prefs.setString(
          'logging_session_start', _sessionStartTime!.toIso8601String());
      await prefs.setString(
          'logging_last_activity', _lastActivityTime!.toIso8601String());

      info('Created new permanent session: $_sessionId', tag: 'SESSION');
    } catch (e) {
      developer.log('Failed to create new session: $e',
          name: _appName, level: 1000);
    }
  }

  /// Start session monitoring to maintain permanent session
  void _startSessionMonitoring() {
    // Update activity every 5 minutes to keep session alive
    Timer.periodic(const Duration(minutes: 5), (timer) {
      if (_isSessionActive) {
        _updateLastActivity();
      }
    });
  }

  /// Update last activity time
  Future<void> _updateLastActivity() async {
    try {
      _lastActivityTime = DateTime.now();
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          'logging_last_activity', _lastActivityTime!.toIso8601String());
    } catch (e) {
      developer.log('Failed to update last activity: $e',
          name: _appName, level: 1000);
    }
  }

  /// Initialize file logging
  Future<void> _initializeFileLogging() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      _logDirectory = '${directory.path}/logs';

      // Create logs directory if it doesn't exist
      final logDir = Directory(_logDirectory!);
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }

      // Initialize log file
      _logFile = File('$_logDirectory/app_$_sessionId.log');

      // Write session start marker
      await _writeToFile('=== SESSION START: $_sessionId ===');
      await _writeToFile(
          'Session Start Time: ${_sessionStartTime!.toIso8601String()}');
    } catch (e) {
      developer.log('Failed to initialize file logging: $e',
          name: _appName, level: 1000);
    }
  }

  void _log(LogLevel level, String message,
      {String? tag,
      Object? error,
      StackTrace? stackTrace,
      Map<String, dynamic>? additionalData}) {
    if (level.index < _minLogLevel.index) return;

    // Rate limiting
    if (!_checkRateLimit()) return;

    // Update session activity
    _updateLastActivity();

    // Create log entry
    final logEntry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      message: message,
      tag: tag,
      sessionId: _sessionId,
      error: error,
      stackTrace: stackTrace,
      additionalData: additionalData,
    );

    // Add to buffer
    _logBuffer.add(logEntry);
    if (_logBuffer.length > 1000) {
      _logBuffer.removeAt(0); // Keep buffer size manageable
    }

    // Console logging
    if (_enableConsoleLogging) {
      switch (level) {
        case LogLevel.debug:
          developer.log(message, name: _appName, level: 500);
          break;
        case LogLevel.info:
          developer.log(message, name: _appName, level: 800);
          break;
        case LogLevel.warning:
          developer.log(message, name: _appName, level: 900);
          break;
        case LogLevel.error:
        case LogLevel.critical:
          developer.log(message,
              name: _appName,
              level: 1000,
              error: error,
              stackTrace: stackTrace);
          break;
      }
    }

    // File logging
    if (_enableFileLogging && _logFile != null) {
      _writeToFile(logEntry.toString());
    }

    // Error reporting for critical errors
    if (level == LogLevel.critical) {
      _reportCriticalError(message, error, stackTrace);
    }
  }

  /// Check rate limiting
  bool _checkRateLimit() {
    // Reset counter every minute
    if (DateTime.now().difference(_lastMinuteReset).inMinutes >= 1) {
      _logsThisMinute = 0;
      _lastMinuteReset = DateTime.now();
    }

    if (_logsThisMinute >= _maxLogsPerMinute) {
      return false; // Rate limit exceeded
    }

    _logsThisMinute++;
    return true;
  }

  /// Write to log file
  Future<void> _writeToFile(String content) async {
    try {
      if (_logFile != null) {
        // Check file size and rotate if needed
        if (await _logFile!.exists() &&
            await _logFile!.length() > _maxLogFileSize) {
          await _rotateLogFiles();
        }

        await _logFile!.writeAsString('$content\n', mode: FileMode.append);
      }
    } catch (e) {
      developer.log('Failed to write to log file: $e',
          name: _appName, level: 1000);
    }
  }

  /// Rotate log files
  Future<void> _rotateLogFiles() async {
    try {
      if (_logDirectory == null) return;

      final logDir = Directory(_logDirectory!);
      final files = await logDir.list().toList();

      // Sort files by modification time
      files.sort(
          (a, b) => b.statSync().modified.compareTo(a.statSync().modified));

      // Remove oldest files if we exceed max count
      if (files.length >= _maxLogFiles) {
        for (int i = _maxLogFiles - 1; i < files.length; i++) {
          await files[i].delete();
        }
      }

      // Create new log file with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _logFile = File('$_logDirectory/app_${_sessionId}_$timestamp.log');
    } catch (e) {
      developer.log('Failed to rotate log files: $e',
          name: _appName, level: 1000);
    }
  }

  void _reportCriticalError(
      String message, Object? error, StackTrace? stackTrace) {
    // TODO(dev): Implement error reporting service (e.g., Sentry, Firebase Crashlytics)
    developer.log('CRITICAL ERROR: $message',
        name: _appName, level: 1000, error: error, stackTrace: stackTrace);
  }

  // ==================== PERFORMANCE LOGGING ====================

  /// Start performance timer for an operation
  void startPerformanceTimer(String operation,
      {Map<String, dynamic>? metadata}) {
    if (!_isSessionActive) return;

    final stopwatch = Stopwatch()..start();
    _activeTimers[operation] = stopwatch;

    // Initialize operation count
    _operationCounts[operation] = (_operationCounts[operation] ?? 0) + 1;

    debug('Started performance timer: $operation',
        tag: 'PERFORMANCE',
        additionalData: {
          'operation': operation,
          'metadata': metadata,
          'session_id': _sessionId,
        });
  }

  /// End performance timer and log metrics
  void endPerformanceTimer(String operation,
      {String? details, Map<String, dynamic>? metadata}) {
    if (!_isSessionActive) return;

    final stopwatch = _activeTimers.remove(operation);
    if (stopwatch == null) {
      warning('Performance timer not found for operation: $operation',
          tag: 'PERFORMANCE');
      return;
    }

    stopwatch.stop();
    final duration = stopwatch.elapsed;

    // Store performance history
    _performanceHistory.putIfAbsent(operation, () => []).add(duration);

    // Keep only last 100 measurements per operation
    if (_performanceHistory[operation]!.length > 100) {
      _performanceHistory[operation]!.removeAt(0);
    }

    // Create performance metric
    final metric = PerformanceMetric(
      operation: operation,
      duration: duration,
      timestamp: DateTime.now(),
      sessionId: _sessionId,
      details: details,
      metadata: metadata,
    );

    _performanceMetrics.add(metric);

    // Log performance
    logPerformance(operation,
        duration: duration, details: details, metadata: metadata);

    // Log slow operations as warnings
    if (duration.inMilliseconds > 1000) {
      warning(
          'Slow operation detected: $operation took ${duration.inMilliseconds}ms',
          tag: 'PERFORMANCE',
          additionalData: {
            'operation': operation,
            'duration_ms': duration.inMilliseconds,
            'details': details,
            'metadata': metadata,
          });
    }
  }

  /// Log performance metrics with detailed analysis
  void logPerformance(String operation,
      {Duration? duration, String? details, Map<String, dynamic>? metadata}) {
    if (!_isSessionActive) return;

    final durationStr =
        duration != null ? ' (${duration.inMilliseconds}ms)' : '';
    final detailsStr = details != null ? ' - $details' : '';
    final metadataStr = metadata != null ? ' - ${metadata.toString()}' : '';

    info('Performance: $operation$durationStr$detailsStr$metadataStr',
        tag: 'PERFORMANCE',
        additionalData: {
          'operation': operation,
          'duration_ms': duration?.inMilliseconds,
          'details': details,
          'metadata': metadata,
          'session_id': _sessionId,
        });
  }

  /// Get performance statistics for an operation
  Map<String, dynamic> getPerformanceStats(String operation) {
    final history = _performanceHistory[operation];
    if (history == null || history.isEmpty) {
      return {'operation': operation, 'count': 0};
    }

    final durations = history.map((d) => d.inMilliseconds).toList();
    durations.sort();

    final count = durations.length;
    final min = durations.first;
    final max = durations.last;
    final avg = durations.reduce((a, b) => a + b) / count;
    final median = count % 2 == 0
        ? (durations[count ~/ 2 - 1] + durations[count ~/ 2]) / 2
        : durations[count ~/ 2];

    return {
      'operation': operation,
      'count': count,
      'min_ms': min,
      'max_ms': max,
      'avg_ms': avg.round(),
      'median_ms': median.round(),
      'total_time_ms': durations.reduce((a, b) => a + b),
    };
  }

  /// Get all performance statistics
  Map<String, Map<String, dynamic>> getAllPerformanceStats() {
    final stats = <String, Map<String, dynamic>>{};
    for (final operation in _performanceHistory.keys) {
      stats[operation] = getPerformanceStats(operation);
    }
    return stats;
  }

  /// Get session performance summary
  Map<String, dynamic> getSessionPerformanceSummary() {
    final totalOperations = _operationCounts.values.fold(0, (a, b) => a + b);
    final totalTime = _performanceMetrics.fold<Duration>(
        Duration.zero, (sum, metric) => sum + metric.duration);

    final avgOperationTime =
        totalOperations > 0 ? totalTime.inMilliseconds / totalOperations : 0;

    return {
      'session_id': _sessionId,
      'session_start': _sessionStartTime?.toIso8601String(),
      'total_operations': totalOperations,
      'total_time_ms': totalTime.inMilliseconds,
      'avg_operation_time_ms': avgOperationTime.round(),
      'unique_operations': _operationCounts.length,
      'performance_metrics_count': _performanceMetrics.length,
    };
  }

  // ==================== PUBLIC LOGGING METHODS ====================

  void debug(String message,
      {String? tag, Map<String, dynamic>? additionalData}) {
    _log(LogLevel.debug, message, tag: tag, additionalData: additionalData);
  }

  void info(String message,
      {String? tag, Map<String, dynamic>? additionalData}) {
    _log(LogLevel.info, message, tag: tag, additionalData: additionalData);
  }

  void warning(String message,
      {String? tag, Object? error, Map<String, dynamic>? additionalData}) {
    _log(LogLevel.warning, message,
        tag: tag, error: error, additionalData: additionalData);
  }

  void error(String message,
      {String? tag,
      Object? error,
      StackTrace? stackTrace,
      Map<String, dynamic>? additionalData}) {
    _log(LogLevel.error, message,
        tag: tag,
        error: error,
        stackTrace: stackTrace,
        additionalData: additionalData);
  }

  void critical(String message,
      {String? tag,
      Object? error,
      StackTrace? stackTrace,
      Map<String, dynamic>? additionalData}) {
    _log(LogLevel.critical, message,
        tag: tag,
        error: error,
        stackTrace: stackTrace,
        additionalData: additionalData);
  }

  // ==================== CONVENIENCE METHODS ====================

  void logApiCall(String endpoint,
      {String? method,
      int? statusCode,
      String? response,
      Map<String, dynamic>? requestData}) {
    final methodStr = method ?? 'GET';
    final statusStr = statusCode != null ? ' ($statusCode)' : '';
    final responseStr = response != null ? ' - $response' : '';

    final level = statusCode != null && statusCode >= 400
        ? LogLevel.error
        : LogLevel.info;

    _log(level, 'API $methodStr $endpoint$statusStr$responseStr',
        tag: 'API',
        additionalData: {
          'endpoint': endpoint,
          'method': methodStr,
          'status_code': statusCode,
          'response': response,
          'request_data': requestData,
        });
  }

  void logUserAction(String action,
      {String? userId, Map<String, dynamic>? data}) {
    final userStr = userId != null ? ' (User: $userId)' : '';
    final dataStr = data != null ? ' - ${data.toString()}' : '';

    info('User Action: $action$userStr$dataStr', tag: 'USER', additionalData: {
      'action': action,
      'user_id': userId,
      'data': data,
    });
  }

  void logError(String operation, Object error,
      {StackTrace? stackTrace,
      String? tag,
      Map<String, dynamic>? additionalData}) {
    this.error('Error in $operation: $error',
        tag: tag,
        error: error,
        stackTrace: stackTrace,
        additionalData: additionalData);
  }

  // ==================== BUSINESS METRICS ====================

  /// Log delivery metrics for Sahla delivery app
  void logDeliveryMetrics({
    required String deliveryPersonId,
    required String orderId,
    required Duration deliveryTime,
    required double distance,
    required double earnings,
    String? restaurantId,
    String? customerId,
    Map<String, dynamic>? additionalData,
  }) {
    info('Sahla delivery completed', tag: 'SAHLA_DELIVERY', additionalData: {
      'delivery_person_id': deliveryPersonId,
      'order_id': orderId,
      'delivery_time_ms': deliveryTime.inMilliseconds,
      'distance_km': distance,
      'earnings': earnings,
      'restaurant_id': restaurantId,
      'customer_id': customerId,
      'session_id': _sessionId,
      'app_name': 'Sahla Delivery',
      ...?additionalData,
    });
  }

  /// Log order metrics for Sahla delivery app
  void logOrderMetrics({
    required String orderId,
    required String status,
    required double totalAmount,
    String? restaurantId,
    String? customerId,
    String? deliveryPersonId,
    Map<String, dynamic>? additionalData,
  }) {
    info('Sahla order status: $status', tag: 'SAHLA_ORDER', additionalData: {
      'order_id': orderId,
      'status': status,
      'total_amount': totalAmount,
      'restaurant_id': restaurantId,
      'customer_id': customerId,
      'delivery_person_id': deliveryPersonId,
      'session_id': _sessionId,
      'app_name': 'Sahla Delivery',
      ...?additionalData,
    });
  }

  /// Log location tracking metrics for Sahla delivery app
  void logLocationMetrics({
    required String deliveryPersonId,
    required double latitude,
    required double longitude,
    double? accuracy,
    double? speed,
    String? address,
    Map<String, dynamic>? additionalData,
  }) {
    debug('Sahla location update', tag: 'SAHLA_LOCATION', additionalData: {
      'delivery_person_id': deliveryPersonId,
      'latitude': latitude,
      'longitude': longitude,
      'accuracy': accuracy,
      'speed': speed,
      'address': address,
      'session_id': _sessionId,
      'app_name': 'Sahla Delivery',
      ...?additionalData,
    });
  }

  /// Log user journey events
  void logUserJourney(String event,
      {String? screen, String? userId, Map<String, dynamic>? data}) {
    info('User Journey: $event', tag: 'USER_JOURNEY', additionalData: {
      'event': event,
      'screen': screen,
      'user_id': userId,
      'timestamp': DateTime.now().toIso8601String(),
      'session_id': _sessionId,
      ...?data,
    });
  }

  // ==================== SESSION MANAGEMENT ====================

  /// Get current session information
  Map<String, dynamic> getSessionInfo() {
    return {
      'session_id': _sessionId,
      'session_start': _sessionStartTime?.toIso8601String(),
      'last_activity': _lastActivityTime?.toIso8601String(),
      'is_active': _isSessionActive,
      'session_duration_minutes': _sessionStartTime != null
          ? DateTime.now().difference(_sessionStartTime!).inMinutes
          : 0,
    };
  }

  /// Export session data
  Map<String, dynamic> exportSessionData() {
    return {
      'session_info': getSessionInfo(),
      'performance_summary': getSessionPerformanceSummary(),
      'performance_stats': getAllPerformanceStats(),
      'log_count': _logBuffer.length,
      'performance_metrics_count': _performanceMetrics.length,
    };
  }

  /// Clear session data (for testing or reset)
  Future<void> clearSessionData() async {
    _logBuffer.clear();
    _performanceMetrics.clear();
    _performanceHistory.clear();
    _operationCounts.clear();
    _activeTimers.clear();

    info('Session data cleared', tag: 'SESSION');
  }
}

// ==================== DATA MODELS ====================

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String message;
  final String? tag;
  final String? sessionId;
  final Object? error;
  final StackTrace? stackTrace;
  final Map<String, dynamic>? additionalData;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.message,
    this.tag,
    this.sessionId,
    this.error,
    this.stackTrace,
    this.additionalData,
  });

  @override
  String toString() {
    final timestampStr = timestamp.toIso8601String();
    final levelStr = level.name.toUpperCase();
    final tagStr = tag != null ? '[$tag] ' : '';
    final sessionStr = sessionId != null ? '[$sessionId] ' : '';
    final dataStr =
        additionalData != null ? ' | Data: ${jsonEncode(additionalData)}' : '';
    final errorStr = error != null ? ' | Error: $error' : '';

    return '[$timestampStr] $levelStr $sessionStr$tagStr$message$dataStr$errorStr';
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'message': message,
      'tag': tag,
      'session_id': sessionId,
      'error': error?.toString(),
      'stack_trace': stackTrace?.toString(),
      'additional_data': additionalData,
    };
  }
}

class PerformanceMetric {
  final String operation;
  final Duration duration;
  final DateTime timestamp;
  final String? sessionId;
  final String? details;
  final Map<String, dynamic>? metadata;

  PerformanceMetric({
    required this.operation,
    required this.duration,
    required this.timestamp,
    this.sessionId,
    this.details,
    this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'operation': operation,
      'duration_ms': duration.inMilliseconds,
      'timestamp': timestamp.toIso8601String(),
      'session_id': sessionId,
      'details': details,
      'metadata': metadata,
    };
  }

  @override
  String toString() {
    return 'PerformanceMetric(operation: $operation, duration: ${duration.inMilliseconds}ms, timestamp: $timestamp)';
  }
}

// Global logger instance
final logger = LoggingService();
