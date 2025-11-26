import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of a queue operation with detailed information
class QueueResult {
  final bool success;
  final String? error;
  final String? errorCode;
  final int attemptCount;
  final Duration? totalDuration;
  final String method; // 'rpc' or 'direct_insert'

  const QueueResult({
    required this.success,
    required this.attemptCount,
    required this.method,
    this.error,
    this.errorCode,
    this.totalDuration,
  });

  @override
  String toString() {
    return 'QueueResult(success: $success, method: $method, attempts: $attemptCount, error: $error)';
  }
}

/// Configuration for queue retry behavior
class QueueConfig {
  final int maxRetries;
  final Duration initialDelay;
  final double backoffMultiplier;
  final Duration maxDelay;
  final bool enableLogging;

  const QueueConfig({
    this.maxRetries = 3,
    this.initialDelay = const Duration(seconds: 1),
    this.backoffMultiplier = 2.0,
    this.maxDelay = const Duration(seconds: 30),
    this.enableLogging = true,
  });
}

class QueueService {
  final SupabaseClient _client;
  final QueueConfig _config;
  final Random _random = Random();

  QueueService({
    SupabaseClient? client,
    QueueConfig? config,
  })  : _client = client ?? Supabase.instance.client,
        _config = config ?? const QueueConfig();

  /// Enqueue a job with retry logic and detailed error reporting
  Future<QueueResult> enqueue({
    required String taskIdentifier,
    Map<String, dynamic>? payload,
    DateTime? runAt,
    int? maxAttempts,
  }) async {
    final stopwatch = Stopwatch()..start();

    _log('Starting enqueue for task: $taskIdentifier', 'INFO');

    for (int attempt = 1; attempt <= _config.maxRetries; attempt++) {
      try {
        _log('Attempt $attempt/$_config.maxRetries for task: $taskIdentifier',
            'DEBUG');

        // Try RPC method first
        final rpcResult =
            await _tryRpcMethod(taskIdentifier, payload, runAt, maxAttempts);
        if (rpcResult.success) {
          stopwatch.stop();
          _log(
              'Successfully enqueued via RPC: $taskIdentifier (attempt $attempt)',
              'INFO');
          return QueueResult(
            success: true,
            attemptCount: attempt,
            totalDuration: stopwatch.elapsed,
            method: 'rpc',
          );
        }

        // Try direct insert fallback
        final directResult =
            await _tryDirectInsert(taskIdentifier, payload, runAt);
        if (directResult.success) {
          stopwatch.stop();
          _log(
              'Successfully enqueued via direct insert: $taskIdentifier (attempt $attempt)',
              'WARN');
          return QueueResult(
            success: true,
            attemptCount: attempt,
            totalDuration: stopwatch.elapsed,
            method: 'direct_insert',
          );
        }

        // If this is the last attempt, return the error
        if (attempt == _config.maxRetries) {
          stopwatch.stop();
          final error =
              'Failed to enqueue after $_config.maxRetries attempts. Last error: ${directResult.error}';
          _log(error, 'ERROR');
          return QueueResult(
            success: false,
            error: error,
            errorCode: 'MAX_RETRIES_EXCEEDED',
            attemptCount: attempt,
            totalDuration: stopwatch.elapsed,
            method: 'none',
          );
        }

        // Wait before retry with exponential backoff and jitter
        final delay = _calculateDelay(attempt);
        _log('Retrying in ${delay.inMilliseconds}ms for task: $taskIdentifier',
            'DEBUG');
        await Future.delayed(delay);
      } catch (e, stackTrace) {
        _log(
            'Unexpected error in attempt $attempt for task $taskIdentifier: $e',
            'ERROR');
        _log('Stack trace: $stackTrace', 'DEBUG');

        if (attempt == _config.maxRetries) {
          stopwatch.stop();
          return QueueResult(
            success: false,
            error: 'Unexpected error: $e',
            errorCode: 'UNEXPECTED_ERROR',
            attemptCount: attempt,
            totalDuration: stopwatch.elapsed,
            method: 'none',
          );
        }

        // Wait before retry
        final delay = _calculateDelay(attempt);
        await Future.delayed(delay);
      }
    }

    stopwatch.stop();
    return QueueResult(
      success: false,
      error: 'Max retries exceeded',
      errorCode: 'MAX_RETRIES_EXCEEDED',
      attemptCount: _config.maxRetries,
      totalDuration: stopwatch.elapsed,
      method: 'none',
    );
  }

  /// Try the RPC method
  Future<QueueResult> _tryRpcMethod(
    String taskIdentifier,
    Map<String, dynamic>? payload,
    DateTime? runAt,
    int? maxAttempts,
  ) async {
    try {
      final result = await _client.rpc('graphile_worker_add_job', params: {
        'task_identifier': taskIdentifier,
        'payload': payload ?? {},
        'run_at': runAt?.toIso8601String(),
        'max_attempts': maxAttempts,
      });

      if (result != null) {
        return const QueueResult(success: true, attemptCount: 1, method: 'rpc');
      } else {
        return const QueueResult(
          success: false,
          error: 'RPC returned null result',
          errorCode: 'RPC_NULL_RESULT',
          attemptCount: 1,
          method: 'rpc',
        );
      }
    } catch (e) {
      return QueueResult(
        success: false,
        error: 'RPC failed: $e',
        errorCode: 'RPC_ERROR',
        attemptCount: 1,
        method: 'rpc',
      );
    }
  }

  /// Try direct insert method
  Future<QueueResult> _tryDirectInsert(
    String taskIdentifier,
    Map<String, dynamic>? payload,
    DateTime? runAt,
  ) async {
    try {
      await _client.from('graphile_worker.jobs').insert({
        'task_identifier': taskIdentifier,
        'payload': payload ?? {},
        if (runAt != null) 'run_at': runAt.toIso8601String(),
      });

      return const QueueResult(
          success: true, attemptCount: 1, method: 'direct_insert');
    } catch (e) {
      return QueueResult(
        success: false,
        error: 'Direct insert failed: $e',
        errorCode: 'DIRECT_INSERT_ERROR',
        attemptCount: 1,
        method: 'direct_insert',
      );
    }
  }

  /// Calculate delay with exponential backoff and jitter
  Duration _calculateDelay(int attempt) {
    final baseDelay = Duration(
      milliseconds: (_config.initialDelay.inMilliseconds *
              pow(_config.backoffMultiplier, attempt - 1))
          .round(),
    );

    // Cap at max delay
    final cappedDelay =
        baseDelay > _config.maxDelay ? _config.maxDelay : baseDelay;

    // Add jitter (±25% random variation)
    final jitterMs =
        (cappedDelay.inMilliseconds * 0.25 * _random.nextDouble()).round();
    final finalDelay = cappedDelay.inMilliseconds +
        (_random.nextBool() ? jitterMs : -jitterMs);

    return Duration(
        milliseconds: finalDelay.clamp(100, _config.maxDelay.inMilliseconds));
  }

  /// Logging helper
  void _log(String message, String level) {
    if (!_config.enableLogging) return;

    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] [QueueService] [$level] $message';

    switch (level) {
      case 'ERROR':
        debugPrint('❌ $logMessage');
        break;
      case 'WARN':
        debugPrint('⚠️ $logMessage');
        break;
      case 'INFO':
        debugPrint('ℹ️ $logMessage');
        break;
      case 'DEBUG':
        if (kDebugMode) {
          debugPrint('🐛 $logMessage');
        }
        break;
      default:
        debugPrint(logMessage);
    }
  }

  /// Get queue statistics (placeholder for future implementation)
  Future<Map<String, dynamic>> getStats() async {
    try {
      // This could be implemented to query queue statistics from the database
      return {
        'status': 'healthy',
        'timestamp': DateTime.now().toIso8601String(),
        'config': {
          'maxRetries': _config.maxRetries,
          'initialDelay': _config.initialDelay.inMilliseconds,
          'backoffMultiplier': _config.backoffMultiplier,
        }
      };
    } catch (e) {
      _log('Failed to get queue stats: $e', 'ERROR');
      return {'status': 'error', 'error': e.toString()};
    }
  }
}
