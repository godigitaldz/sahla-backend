import "dart:async";
import "dart:math";

import "package:flutter/material.dart";

/// Configuration for retry mechanism
class RetryConfig {
  /// Maximum number of retry attempts
  final int maxAttempts;

  /// Initial delay before first retry
  final Duration initialDelay;

  /// Maximum delay between retries
  final Duration maxDelay;

  /// Multiplier for exponential backoff
  final double multiplier;

  /// Jitter factor to randomize delays (0.0 to 1.0)
  final double jitterFactor;

  const RetryConfig({
    this.maxAttempts = 3,
    this.initialDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 10),
    this.multiplier = 2.0,
    this.jitterFactor = 0.2,
  });

  /// Default config for network requests
  static const network = RetryConfig(
    maxAttempts: 3,
    initialDelay: Duration(milliseconds: 500),
    maxDelay: Duration(seconds: 5),
    multiplier: 2.0,
    jitterFactor: 0.2,
  );

  /// Aggressive config for critical operations
  static const aggressive = RetryConfig(
    maxAttempts: 5,
    initialDelay: Duration(milliseconds: 200),
    maxDelay: Duration(seconds: 8),
    multiplier: 1.5,
    jitterFactor: 0.3,
  );

  /// Conservative config for non-critical operations
  static const conservative = RetryConfig(
    maxAttempts: 2,
    initialDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 3),
    multiplier: 2.0,
    jitterFactor: 0.1,
  );
}

/// Result of a retry operation
class RetryResult<T> {
  final T? data;
  final bool success;
  final int attempts;
  final Exception? error;

  const RetryResult({
    required this.success,
    required this.attempts,
    this.data,
    this.error,
  });

  factory RetryResult.success(T data, int attempts) {
    return RetryResult(
      data: data,
      success: true,
      attempts: attempts,
    );
  }

  factory RetryResult.failure(Exception error, int attempts) {
    return RetryResult(
      success: false,
      attempts: attempts,
      error: error,
    );
  }
}

/// Utility class for retry mechanism with exponential backoff
///
/// Features:
/// - Exponential backoff with configurable multiplier
/// - Jitter to prevent thundering herd
/// - Maximum delay cap
/// - Detailed logging for debugging
/// - Type-safe result handling
/// - Predicate-based retry conditions
class RetryHelper {
  /// Execute an action with exponential backoff retry
  ///
  /// Returns [RetryResult] with success status and data/error
  static Future<RetryResult<T>> execute<T>({
    required Future<T> Function() action,
    RetryConfig config = RetryConfig.network,
    bool Function(Exception)? shouldRetry,
    void Function(int attempt, Exception error)? onRetry,
  }) async {
    Exception? lastError;
    int attempt = 0;

    while (attempt < config.maxAttempts) {
      attempt++;

      try {
        debugPrint("🔄 RetryHelper: Attempt $attempt/${config.maxAttempts}");

        final result = await action();
        debugPrint("✅ RetryHelper: Success on attempt $attempt");

        return RetryResult.success(result, attempt);
      } on Exception catch (e) {
        lastError = e;
        debugPrint(
          "❌ RetryHelper: Attempt $attempt failed - ${e.toString()}",
        );

        // Check if we should retry this error
        if (shouldRetry != null && !shouldRetry(e)) {
          debugPrint("⛔ RetryHelper: Error is not retryable, stopping");
          return RetryResult.failure(e, attempt);
        }

        // Don't delay after the last attempt
        if (attempt < config.maxAttempts) {
          final delay = _calculateDelay(
            attempt: attempt,
            config: config,
          );

          debugPrint(
            "⏳ RetryHelper: Waiting ${delay.inMilliseconds}ms before retry",
          );

          // Call onRetry callback if provided
          onRetry?.call(attempt, e);

          await Future.delayed(delay);
        }
      }
    }

    debugPrint(
      "❌ RetryHelper: All $attempt attempts failed. Last error: ${lastError.toString()}",
    );

    return RetryResult.failure(
      lastError ?? Exception("Unknown error"),
      attempt,
    );
  }

  /// Execute with retry and return null on failure (simpler API)
  static Future<T?> executeOrNull<T>({
    required Future<T> Function() action,
    RetryConfig config = RetryConfig.network,
    bool Function(Exception)? shouldRetry,
  }) async {
    final result = await execute(
      action: action,
      config: config,
      shouldRetry: shouldRetry,
    );

    return result.success ? result.data : null;
  }

  /// Calculate delay with exponential backoff and jitter
  static Duration _calculateDelay({
    required int attempt,
    required RetryConfig config,
  }) {
    // Calculate exponential delay
    final exponentialDelay = (config.initialDelay.inMilliseconds *
            pow(config.multiplier, attempt - 1))
        .toDouble();

    // Cap at max delay
    final cappedDelay = min(
      exponentialDelay,
      config.maxDelay.inMilliseconds.toDouble(),
    );

    // Add jitter (randomize ± jitterFactor)
    final jitter = _calculateJitter(
      cappedDelay,
      config.jitterFactor,
    );

    final finalDelay = cappedDelay + jitter;

    return Duration(milliseconds: finalDelay.round());
  }

  /// Calculate jitter value
  static double _calculateJitter(double delay, double jitterFactor) {
    final random = Random();
    final maxJitter = delay * jitterFactor;
    final jitterValue = (random.nextDouble() * 2 - 1) * maxJitter;
    return jitterValue.toDouble(); // Random between -maxJitter and +maxJitter
  }

  /// Check if exception is retryable (common network errors)
  static bool isNetworkError(Exception error) {
    final errorString = error.toString().toLowerCase();

    return errorString.contains("socket") ||
        errorString.contains("network") ||
        errorString.contains("timeout") ||
        errorString.contains("connection") ||
        errorString.contains("failed host lookup");
  }

  /// Check if exception is a timeout error
  static bool isTimeoutError(Exception error) {
    return error is TimeoutException ||
        error.toString().toLowerCase().contains("timeout");
  }
}
