import 'dart:async';

import 'package:flutter/foundation.dart';

/// Centralized refresh manager to coordinate all refresh operations
/// Prevents excessive background refreshes and provides intelligent refresh triggers
class RefreshManager {
  static final RefreshManager _instance = RefreshManager._internal();
  factory RefreshManager() => _instance;
  RefreshManager._internal();

  // Track refresh states
  final Map<String, DateTime> _lastRefreshTimes = {};
  final Map<String, bool> _isRefreshing = {};
  final Map<String, Timer> _refreshTimers = {};

  // Configuration
  static const Duration _defaultRefreshInterval = Duration(minutes: 3);
  static const Duration _minRefreshCooldown = Duration(seconds: 30);
  static const Duration _maxRefreshInterval = Duration(minutes: 10);

  /// Register a refreshable component
  void registerComponent(
    String componentId, {
    Duration? refreshInterval,
    bool autoStart = true,
  }) {
    final interval = refreshInterval ?? _defaultRefreshInterval;

    if (autoStart) {
      _startPeriodicRefresh(componentId, interval);
    }

    debugPrint(
        '📋 RefreshManager: Registered component $componentId with ${interval.inMinutes}m interval');
  }

  /// Start periodic refresh for a component
  void _startPeriodicRefresh(String componentId, Duration interval) {
    _refreshTimers[componentId]?.cancel();
    _refreshTimers[componentId] = Timer.periodic(interval, (timer) {
      _triggerRefresh(componentId);
    });
  }

  /// Trigger a refresh for a specific component
  Future<void> _triggerRefresh(String componentId) async {
    if (_isRefreshing[componentId] == true) {
      debugPrint(
          '⏸️ RefreshManager: Skipping refresh for $componentId (already refreshing)');
      return;
    }

    final lastRefresh = _lastRefreshTimes[componentId];
    if (lastRefresh != null) {
      final timeSinceLastRefresh = DateTime.now().difference(lastRefresh);
      if (timeSinceLastRefresh < _minRefreshCooldown) {
        debugPrint(
            '⏸️ RefreshManager: Skipping refresh for $componentId (cooldown: ${timeSinceLastRefresh.inSeconds}s)');
        return;
      }
    }

    _isRefreshing[componentId] = true;
    _lastRefreshTimes[componentId] = DateTime.now();

    debugPrint('🔄 RefreshManager: Triggering refresh for $componentId');

    // Notify listeners
    _refreshController.add(componentId);
  }

  /// Manual refresh trigger
  Future<void> triggerManualRefresh(String componentId) async {
    debugPrint('🔄 RefreshManager: Manual refresh triggered for $componentId');
    await _triggerRefresh(componentId);
  }

  /// Check if a component should refresh based on conditions
  bool shouldRefresh(
    String componentId, {
    required bool hasActiveData,
    Duration? maxAge,
  }) {
    final lastRefresh = _lastRefreshTimes[componentId];
    if (lastRefresh == null) return true;

    final age = DateTime.now().difference(lastRefresh);
    final maxAgeThreshold = maxAge ?? _maxRefreshInterval;

    return hasActiveData && age > maxAgeThreshold;
  }

  /// Stop refresh for a component
  void stopRefresh(String componentId) {
    _refreshTimers[componentId]?.cancel();
    _refreshTimers.remove(componentId);
    _isRefreshing[componentId] = false;
    debugPrint('⏹️ RefreshManager: Stopped refresh for $componentId');
  }

  /// Update refresh interval for a component
  void updateRefreshInterval(String componentId, Duration newInterval) {
    _startPeriodicRefresh(componentId, newInterval);
    debugPrint(
        '🔄 RefreshManager: Updated refresh interval for $componentId to ${newInterval.inMinutes}m');
  }

  /// Get refresh status for a component
  Map<String, dynamic> getRefreshStatus(String componentId) {
    return {
      'isRefreshing': _isRefreshing[componentId] ?? false,
      'lastRefresh': _lastRefreshTimes[componentId],
      'hasTimer': _refreshTimers.containsKey(componentId),
    };
  }

  /// Stream controller for refresh events
  final StreamController<String> _refreshController =
      StreamController<String>.broadcast();
  Stream<String> get refreshStream => _refreshController.stream;

  /// Listen to refresh events for a specific component
  StreamSubscription<void> listenToRefresh(
      String componentId, VoidCallback onRefresh) {
    return refreshStream
        .where((id) => id == componentId)
        .listen((_) => onRefresh());
  }

  /// Dispose all resources
  void dispose() {
    for (final timer in _refreshTimers.values) {
      timer.cancel();
    }
    _refreshTimers.clear();
    _isRefreshing.clear();
    _lastRefreshTimes.clear();
    _refreshController.close();
    debugPrint('🗑️ RefreshManager: Disposed all resources');
  }

  /// Get debug information
  Map<String, dynamic> getDebugInfo() {
    return {
      'activeTimers': _refreshTimers.length,
      'refreshingComponents':
          _isRefreshing.entries.where((e) => e.value).length,
      'lastRefreshTimes': _lastRefreshTimes,
    };
  }
}
