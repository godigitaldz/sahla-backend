import 'package:dio/dio.dart';

/// Application error handling classes
///
/// This file provides a comprehensive error handling system with specific
/// error types for different scenarios in the application.

/// Base class for all application errors
abstract class AppError implements Exception {
  /// Creates an [AppError] with the given message and optional details
  AppError({
    required this.message,
    this.details,
    this.stackTrace,
    this.context,
    this.statusCode,
    this.errorCode,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  /// User-friendly error message
  final String message;

  /// Additional error details
  final String? details;

  /// Stack trace associated with the error
  final StackTrace? stackTrace;

  /// Context where the error occurred (e.g., 'UserService.login')
  final String? context;

  /// HTTP status code if applicable
  final int? statusCode;

  /// Application-specific error code
  final String? errorCode;

  /// Timestamp when the error occurred
  final DateTime timestamp;

  /// Get the error type as a string (for compatibility with ErrorHandlingService)
  String get errorType;

  /// Get the error severity level
  ErrorSeverity get severity;

  /// Convert to a map for logging/reporting
  Map<String, dynamic> toMap() {
    return {
      'type': errorType,
      'message': message,
      'details': details,
      'context': context,
      'statusCode': statusCode,
      'errorCode': errorCode,
      'timestamp': timestamp.toIso8601String(),
      'severity': severity.name,
    };
  }

  @override
  String toString() {
    final buffer = StringBuffer('$runtimeType: $message');
    if (context != null) {
      buffer.write(' (context: $context)');
    }
    if (statusCode != null) {
      buffer.write(' (status: $statusCode)');
    }
    if (errorCode != null) {
      buffer.write(' (code: $errorCode)');
    }
    if (details != null) {
      buffer.write('\nDetails: $details');
    }
    return buffer.toString();
  }
}

/// Error severity levels
enum ErrorSeverity {
  low,
  medium,
  high,
  critical,
}

/// Network-related errors (no connection, timeout, etc.)
class NetworkError extends AppError {
  NetworkError({
    required super.message,
    super.details,
    super.stackTrace,
    super.context,
    super.errorCode,
    this.isTimeout = false,
    this.isConnectionError = false,
  });

  /// Whether this is a timeout error
  final bool isTimeout;

  /// Whether this is a connection error
  final bool isConnectionError;

  @override
  String get errorType => 'network_error';

  @override
  ErrorSeverity get severity => ErrorSeverity.high;

  /// Create a NetworkError from a DioException
  factory NetworkError.fromDioException(
    dynamic exception, {
    String? context,
    StackTrace? stackTrace,
  }) {
    if (exception is DioException) {
      final isTimeout = exception.type == DioExceptionType.connectionTimeout ||
          exception.type == DioExceptionType.receiveTimeout ||
          exception.type == DioExceptionType.sendTimeout;
      final isConnectionError =
          exception.type == DioExceptionType.connectionError;

      String message;
      if (isTimeout) {
        message = 'Request timeout. Please try again.';
      } else if (isConnectionError) {
        message =
            'Network connection error. Please check your internet connection.';
      } else {
        message = 'Network error occurred. Please check your connection.';
      }

      return NetworkError(
        message: message,
        details: exception.message,
        stackTrace: stackTrace ?? exception.stackTrace,
        context: context,
        isTimeout: isTimeout,
        isConnectionError: isConnectionError,
      );
    }

    return NetworkError(
      message: 'Network error occurred. Please check your connection.',
      details: exception.toString(),
      stackTrace: stackTrace,
      context: context,
    );
  }
}

/// Server-related errors (5xx, API errors, etc.)
class ServerError extends AppError {
  ServerError({
    required super.message,
    super.details,
    super.stackTrace,
    super.context,
    super.statusCode,
    super.errorCode,
  });

  @override
  String get errorType => 'server_error';

  @override
  ErrorSeverity get severity {
    if (statusCode != null) {
      if (statusCode! >= 500) {
        return ErrorSeverity.critical;
      } else if (statusCode! >= 400) {
        return ErrorSeverity.high;
      }
    }
    return ErrorSeverity.high;
  }

  /// Create a ServerError from a DioException
  factory ServerError.fromDioException(
    DioException exception, {
    String? context,
    StackTrace? stackTrace,
  }) {
    final statusCode = exception.response?.statusCode;
    final responseData = exception.response?.data;

    String message;
    if (responseData is Map && responseData.containsKey('error')) {
      message = responseData['error'].toString();
    } else if (exception.message != null) {
      message = exception.message!;
    } else {
      message = 'Server error occurred. Please try again later.';
    }

    return ServerError(
      message: message,
      details: responseData?.toString(),
      stackTrace: stackTrace ?? exception.stackTrace,
      context: context,
      statusCode: statusCode,
    );
  }

  /// Create a ServerError from HTTP response
  factory ServerError.fromResponse(
    int statusCode,
    dynamic responseData, {
    String? context,
    StackTrace? stackTrace,
  }) {
    String message;
    if (responseData is Map && responseData.containsKey('error')) {
      message = responseData['error'].toString();
    } else {
      message = 'Server error occurred. Please try again later.';
    }

    return ServerError(
      message: message,
      details: responseData?.toString(),
      stackTrace: stackTrace,
      context: context,
      statusCode: statusCode,
    );
  }
}

/// Authentication-related errors (401, 403, token expired, etc.)
class AuthError extends AppError {
  AuthError({
    required super.message,
    super.details,
    super.stackTrace,
    super.context,
    super.statusCode,
    super.errorCode,
    this.isTokenExpired = false,
    this.isUnauthorized = false,
    this.isForbidden = false,
  });

  /// Whether the authentication token has expired
  final bool isTokenExpired;

  /// Whether the user is unauthorized (401)
  final bool isUnauthorized;

  /// Whether the user is forbidden (403)
  final bool isForbidden;

  @override
  String get errorType => 'auth_error';

  @override
  ErrorSeverity get severity => ErrorSeverity.high;

  /// Create an AuthError from a status code
  factory AuthError.fromStatusCode(
    int statusCode, {
    String? message,
    String? context,
    StackTrace? stackTrace,
  }) {
    final isUnauthorized = statusCode == 401;
    final isForbidden = statusCode == 403;

    return AuthError(
      message: message ??
          (isUnauthorized
              ? 'Authentication failed. Please log in again.'
              : isForbidden
                  ? 'You do not have permission to perform this action.'
                  : 'Authentication error occurred.'),
      context: context,
      statusCode: statusCode,
      isUnauthorized: isUnauthorized,
      isForbidden: isForbidden,
      stackTrace: stackTrace,
    );
  }
}

/// Validation errors (invalid input, missing required fields, etc.)
class ValidationError extends AppError {
  ValidationError({
    required super.message,
    super.details,
    super.stackTrace,
    super.context,
    super.errorCode,
    this.field,
    this.validationErrors,
  });

  /// The field that failed validation
  final String? field;

  /// Map of field names to validation error messages
  final Map<String, String>? validationErrors;

  @override
  String get errorType => 'validation_error';

  @override
  ErrorSeverity get severity => ErrorSeverity.medium;

  /// Create a ValidationError for a specific field
  factory ValidationError.forField(
    String field,
    String message, {
    String? context,
  }) {
    return ValidationError(
      message: message,
      field: field,
      context: context,
    );
  }

  /// Create a ValidationError with multiple field errors
  factory ValidationError.withErrors(
    Map<String, String> errors, {
    String? message,
    String? context,
  }) {
    return ValidationError(
      message: message ?? 'Validation failed. Please check your input.',
      validationErrors: errors,
      context: context,
    );
  }
}

/// Data-related errors (parsing, missing data, etc.)
class DataError extends AppError {
  DataError({
    required super.message,
    super.details,
    super.stackTrace,
    super.context,
    super.errorCode,
    this.isParseError = false,
    this.isMissingData = false,
  });

  /// Whether this is a parsing error
  final bool isParseError;

  /// Whether required data is missing
  final bool isMissingData;

  @override
  String get errorType => 'data_error';

  @override
  ErrorSeverity get severity => ErrorSeverity.medium;

  /// Create a DataError for parsing failures
  factory DataError.parseError(
    String message, {
    String? details,
    String? context,
    StackTrace? stackTrace,
  }) {
    return DataError(
      message: message,
      details: details,
      context: context,
      stackTrace: stackTrace,
      isParseError: true,
    );
  }

  /// Create a DataError for missing data
  factory DataError.missingData(
    String message, {
    String? context,
  }) {
    return DataError(
      message: message,
      context: context,
      isMissingData: true,
    );
  }
}

/// Cache-related errors
class CacheError extends AppError {
  CacheError({
    required super.message,
    super.details,
    super.stackTrace,
    super.context,
    super.errorCode,
    this.isCacheMiss = false,
    this.isCacheCorrupted = false,
  });

  /// Whether this is a cache miss (not necessarily an error)
  final bool isCacheMiss;

  /// Whether the cache data is corrupted
  final bool isCacheCorrupted;

  @override
  String get errorType => 'cache_error';

  @override
  ErrorSeverity get severity => ErrorSeverity.low;

  /// Create a CacheError for cache misses
  factory CacheError.cacheMiss({
    String? context,
  }) {
    return CacheError(
      message: 'Cache miss occurred.',
      context: context,
      isCacheMiss: true,
    );
  }

  /// Create a CacheError for corrupted cache
  factory CacheError.corrupted({
    String? details,
    String? context,
  }) {
    return CacheError(
      message: 'Cache data is corrupted.',
      details: details,
      context: context,
      isCacheCorrupted: true,
    );
  }
}

/// Unknown/unexpected errors
class UnknownError extends AppError {
  UnknownError({
    required super.message,
    super.details,
    super.stackTrace,
    super.context,
    super.errorCode,
    this.originalError,
  });

  /// The original error that caused this unknown error
  final dynamic originalError;

  @override
  String get errorType => 'unknown_error';

  @override
  ErrorSeverity get severity => ErrorSeverity.medium;

  /// Create an UnknownError from any exception
  factory UnknownError.fromException(
    dynamic exception, {
    String? context,
    StackTrace? stackTrace,
  }) {
    return UnknownError(
      message: 'An unexpected error occurred. Please try again.',
      details: exception.toString(),
      stackTrace: stackTrace,
      context: context,
      originalError: exception,
    );
  }
}

/// Permission/authorization errors
class PermissionError extends AppError {
  PermissionError({
    required super.message,
    super.details,
    super.stackTrace,
    super.context,
    super.errorCode,
    this.permission,
  });

  /// The specific permission that was denied
  final String? permission;

  @override
  String get errorType => 'permission_error';

  @override
  ErrorSeverity get severity => ErrorSeverity.high;

  /// Create a PermissionError for a specific permission
  factory PermissionError.denied(
    String permission, {
    String? context,
  }) {
    return PermissionError(
      message: 'Permission denied: $permission',
      permission: permission,
      context: context,
    );
  }
}

/// Business logic errors (domain-specific errors)
class BusinessError extends AppError {
  BusinessError({
    required super.message,
    super.details,
    super.stackTrace,
    super.context,
    super.errorCode,
    this.businessRule,
  });

  /// The business rule that was violated
  final String? businessRule;

  @override
  String get errorType => 'business_error';

  @override
  ErrorSeverity get severity => ErrorSeverity.medium;

  /// Create a BusinessError for a violated business rule
  factory BusinessError.ruleViolation(
    String rule,
    String message, {
    String? context,
  }) {
    return BusinessError(
      message: message,
      businessRule: rule,
      context: context,
    );
  }
}

/// Extension to convert AppError to ErrorHandlingService error type string
extension AppErrorExtension on AppError {
  /// Convert to ErrorHandlingService error type string
  String toErrorHandlingServiceType() {
    return errorType;
  }
}

/// Helper function to convert any exception to AppError
AppError toAppError(
  dynamic exception, {
  String? context,
  StackTrace? stackTrace,
}) {
  if (exception is AppError) {
    return exception;
  }

  if (exception is DioException) {
    if (exception.type == DioExceptionType.connectionTimeout ||
        exception.type == DioExceptionType.receiveTimeout ||
        exception.type == DioExceptionType.sendTimeout ||
        exception.type == DioExceptionType.connectionError) {
      return NetworkError.fromDioException(
        exception,
        context: context,
        stackTrace: stackTrace,
      );
    }

    final statusCode = exception.response?.statusCode;
    if (statusCode != null) {
      if (statusCode == 401 || statusCode == 403) {
        return AuthError.fromStatusCode(
          statusCode,
          context: context,
          stackTrace: stackTrace ?? exception.stackTrace,
        );
      } else if (statusCode >= 500) {
        return ServerError.fromDioException(
          exception,
          context: context,
          stackTrace: stackTrace,
        );
      } else if (statusCode >= 400) {
        return ServerError.fromDioException(
          exception,
          context: context,
          stackTrace: stackTrace,
        );
      }
    }

    return NetworkError.fromDioException(
      exception,
      context: context,
      stackTrace: stackTrace,
    );
  }

  if (exception is FormatException) {
    return DataError.parseError(
      'Failed to parse data: ${exception.message}',
      details: exception.toString(),
      context: context,
      stackTrace: stackTrace,
    );
  }

  return UnknownError.fromException(
    exception,
    context: context,
    stackTrace: stackTrace,
  );
}
