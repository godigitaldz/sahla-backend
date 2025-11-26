import 'package:flutter/foundation.dart';

class ErrorLoggingService extends ChangeNotifier {
  static final ErrorLoggingService _instance = ErrorLoggingService._internal();
  factory ErrorLoggingService() => _instance;
  ErrorLoggingService._internal();

  // Error log storage (in a real app, this would be sent to a logging service)
  final List<ErrorLog> _errorLogs = [];

  // Log levels
  static const String _levelError = 'ERROR';
  static const String _levelWarning = 'WARNING';
  static const String _levelInfo = 'INFO';

  /// Log an error with context
  void logError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    String? context,
    Map<String, dynamic>? additionalData,
  }) {
    final errorLog = ErrorLog(
      timestamp: DateTime.now(),
      level: _levelError,
      message: message,
      error: error,
      stackTrace: stackTrace,
      context: context,
      additionalData: additionalData,
    );

    _errorLogs.add(errorLog);
    _printErrorLog(errorLog);
    notifyListeners();

    // In a real app, you would send this to a logging service
    // _sendToLoggingService(errorLog);
  }

  /// Log a warning
  void logWarning(
    String message, {
    String? context,
    Map<String, dynamic>? additionalData,
  }) {
    final errorLog = ErrorLog(
      timestamp: DateTime.now(),
      level: _levelWarning,
      message: message,
      context: context,
      additionalData: additionalData,
    );

    _errorLogs.add(errorLog);
    _printErrorLog(errorLog);
    notifyListeners();
  }

  /// Log info
  void logInfo(
    String message, {
    String? context,
    Map<String, dynamic>? additionalData,
  }) {
    final errorLog = ErrorLog(
      timestamp: DateTime.now(),
      level: _levelInfo,
      message: message,
      context: context,
      additionalData: additionalData,
    );

    _errorLogs.add(errorLog);
    _printErrorLog(errorLog);
    notifyListeners();
  }

  /// Log Flutter error details
  void logFlutterError(FlutterErrorDetails details) {
    logError(
      'Flutter Error: ${details.exception}',
      error: details.exception,
      stackTrace: details.stack,
      context: 'Flutter Error Boundary',
      additionalData: {
        'library': details.library,
        'context': details.context?.toString(),
      },
    );
  }

  /// Log API errors
  void logApiError(
    String endpoint,
    int? statusCode,
    String message, {
    Map<String, dynamic>? requestData,
    Map<String, dynamic>? responseData,
  }) {
    logError(
      'API Error: $message',
      context: 'API Call',
      additionalData: {
        'endpoint': endpoint,
        'statusCode': statusCode,
        'requestData': requestData,
        'responseData': responseData,
      },
    );
  }

  /// Log network errors
  void logNetworkError(
    String message, {
    String? url,
    String? method,
    Map<String, dynamic>? additionalData,
  }) {
    logError(
      'Network Error: $message',
      context: 'Network',
      additionalData: {
        'url': url,
        'method': method,
        ...?additionalData,
      },
    );
  }

  /// Log validation errors
  void logValidationError(
    String field,
    String message, {
    String? screen,
    Map<String, dynamic>? formData,
  }) {
    logWarning(
      'Validation Error: $message',
      context: 'Form Validation',
      additionalData: {
        'field': field,
        'screen': screen,
        'formData': formData,
      },
    );
  }

  /// Get all error logs
  List<ErrorLog> getErrorLogs() {
    return List.unmodifiable(_errorLogs);
  }

  /// Clear error logs
  void clearErrorLogs() {
    _errorLogs.clear();
    notifyListeners();
  }

  /// Get error logs by level
  List<ErrorLog> getErrorLogsByLevel(String level) {
    return _errorLogs.where((log) => log.level == level).toList();
  }

  /// Get recent error logs (last N logs)
  List<ErrorLog> getRecentErrorLogs(int count) {
    final startIndex = _errorLogs.length - count;
    if (startIndex < 0) return _errorLogs;
    return _errorLogs.sublist(startIndex);
  }

  void _printErrorLog(ErrorLog log) {
    if (kDebugMode) {
      print('=== ERROR LOG ===');
      print('Timestamp: ${log.timestamp}');
      print('Level: ${log.level}');
      print('Message: ${log.message}');
      if (log.context != null) print('Context: ${log.context}');
      if (log.error != null) print('Error: ${log.error}');
      if (log.stackTrace != null) print('Stack Trace: ${log.stackTrace}');
      if (log.additionalData != null) {
        print('Additional Data: ${log.additionalData}');
      }
      print('================');
    }
  }

  // In a real app, you would implement this to send logs to a service
  // void _sendToLoggingService(ErrorLog log) {
  //   // Send to Firebase Crashlytics, Sentry, or other logging service
  // }
}

class ErrorLog {
  final DateTime timestamp;
  final String level;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;
  final String? context;
  final Map<String, dynamic>? additionalData;

  ErrorLog({
    required this.timestamp,
    required this.level,
    required this.message,
    this.error,
    this.stackTrace,
    this.context,
    this.additionalData,
  });

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level,
      'message': message,
      'error': error?.toString(),
      'stackTrace': stackTrace?.toString(),
      'context': context,
      'additionalData': additionalData,
    };
  }

  @override
  String toString() {
    return 'ErrorLog(timestamp: $timestamp, level: $level, message: $message, context: $context)';
  }
}
