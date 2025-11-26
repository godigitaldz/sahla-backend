import "dart:async";

import "package:connectivity_plus/connectivity_plus.dart";
import "package:flutter/material.dart";

/// Connectivity service for network availability monitoring
///
/// Features:
/// - Real-time network status monitoring
/// - Multiple connectivity type detection (WiFi, Mobile, Ethernet)
/// - Stream-based updates for reactive UI
/// - Singleton pattern for efficient resource usage
/// - Proper cleanup and disposal
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();

  factory ConnectivityService() => _instance;

  ConnectivityService._internal();

  final Connectivity _connectivity = Connectivity();
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  /// Current connectivity status
  bool _isConnected = true;
  bool get isConnected => _isConnected;

  /// Stream controller for connectivity changes
  final StreamController<bool> _connectivityController =
      StreamController<bool>.broadcast();

  /// Stream of connectivity changes
  Stream<bool> get connectivityStream => _connectivityController.stream;

  /// Initialize connectivity monitoring
  Future<void> initialize() async {
    // Check initial status
    await checkConnectivity();

    // Listen to connectivity changes
    _subscription = _connectivity.onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        _updateConnectivityStatus(results);
      },
    );

    debugPrint("🌐 ConnectivityService: Initialized");
  }

  /// Check current connectivity status
  Future<bool> checkConnectivity() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateConnectivityStatus(result);
      return _isConnected;
    } catch (e) {
      debugPrint("❌ ConnectivityService: Error checking connectivity: $e");
      _isConnected = false;
      return false;
    }
  }

  /// Update connectivity status based on result
  void _updateConnectivityStatus(List<ConnectivityResult> results) {
    final wasConnected = _isConnected;

    // Check if any valid connection exists
    _isConnected = results.any((result) =>
        result == ConnectivityResult.wifi ||
        result == ConnectivityResult.mobile ||
        result == ConnectivityResult.ethernet);

    // Notify listeners if status changed
    if (wasConnected != _isConnected) {
      _connectivityController.add(_isConnected);
      debugPrint(
        "🌐 ConnectivityService: Status changed - ${_isConnected ? "Connected" : "Disconnected"}",
      );
    }
  }

  /// Execute an action only if connected to network
  Future<T?> executeIfConnected<T>(Future<T> Function() action) async {
    if (!_isConnected) {
      debugPrint(
          "⚠️ ConnectivityService: No network connection, skipping action");
      return null;
    }

    try {
      return await action();
    } catch (e) {
      debugPrint("❌ ConnectivityService: Error executing action: $e");
      rethrow;
    }
  }

  /// Execute an action with automatic retry on connectivity restore
  Future<T?> executeWithRetry<T>({
    required Future<T> Function() action,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    // If already connected, execute immediately
    if (_isConnected) {
      return action();
    }

    // Wait for connectivity restore
    debugPrint(
      "⏳ ConnectivityService: Waiting for connectivity restore (timeout: ${timeout.inSeconds}s)",
    );

    try {
      await connectivityStream.firstWhere((isConnected) => isConnected).timeout(
            timeout,
          );

      return await action();
    } on TimeoutException {
      debugPrint("⏰ ConnectivityService: Timeout waiting for connectivity");
      return null;
    } catch (e) {
      debugPrint("❌ ConnectivityService: Error in executeWithRetry: $e");
      return null;
    }
  }

  /// Dispose resources
  void dispose() {
    _subscription?.cancel();
    _connectivityController.close();
    debugPrint("🔌 ConnectivityService: Disposed");
  }
}
