import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RealtimeService {
  static final RealtimeService _instance = RealtimeService._internal();
  factory RealtimeService() => _instance;
  RealtimeService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;
  RealtimeChannel? _restaurantChannel;
  RealtimeChannel? _deliveryChannel;

  // Socket.io removed

  final StreamController<Map<String, dynamic>> _restaurantUpdatesController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _deliveryUpdatesController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _menuItemUpdatesController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of restaurant request updates
  Stream<Map<String, dynamic>> get restaurantUpdates =>
      _restaurantUpdatesController.stream;

  /// Stream of delivery man request updates
  Stream<Map<String, dynamic>> get deliveryUpdates =>
      _deliveryUpdatesController.stream;

  /// Stream of menu item updates
  Stream<Map<String, dynamic>> get menuItemUpdates =>
      _menuItemUpdatesController.stream;

  /// Initialize real-time listeners
  Future<void> initialize() async {
    try {
      await _setupRestaurantListener();
      await _setupDeliveryListener();
      await _setupMenuItemListener();
      debugPrint('🔄 RealtimeService initialized successfully');
    } catch (e) {
      debugPrint('❌ Error initializing RealtimeService: $e');
    }
  }

  /// Setup restaurant requests real-time listener
  Future<void> _setupRestaurantListener() async {
    try {
      _restaurantChannel = _supabase
          .channel('restaurant_requests_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'restaurant_requests',
            callback: _handleRestaurantChange,
          )
          .subscribe();

      debugPrint('📡 Restaurant requests real-time listener setup');
    } catch (e) {
      debugPrint('❌ Error setting up restaurant listener: $e');
    }
  }

  /// Setup delivery man requests real-time listener
  Future<void> _setupDeliveryListener() async {
    try {
      _deliveryChannel = _supabase
          .channel('delivery_man_requests_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'delivery_man_requests',
            callback: _handleDeliveryChange,
          )
          .subscribe();

      debugPrint('📡 Delivery man requests real-time listener setup');
    } catch (e) {
      debugPrint('❌ Error setting up delivery listener: $e');
    }
  }

  /// Handle restaurant request changes
  void _handleRestaurantChange(PostgresChangePayload payload) {
    try {
      final changeType = _getChangeType(payload.eventType);
      final data = payload.newRecord;

      final update = {
        'type': 'restaurant_request',
        'action': changeType,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
        'id': data['id'],
      };

      _restaurantUpdatesController.add(update);
      debugPrint('🔄 Restaurant request $changeType: ${data['id']}');
    } catch (e) {
      debugPrint('❌ Error handling restaurant change: $e');
    }
  }

  /// Handle delivery man request changes
  void _handleDeliveryChange(PostgresChangePayload payload) {
    try {
      final changeType = _getChangeType(payload.eventType);
      final data = payload.newRecord;

      final update = {
        'type': 'delivery_man_request',
        'action': changeType,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
        'id': data['id'],
      };

      _deliveryUpdatesController.add(update);
      debugPrint('🔄 Delivery man request $changeType: ${data['id']}');
    } catch (e) {
      debugPrint('❌ Error handling delivery change: $e');
    }
  }

  /// Convert PostgresChangeEvent to readable string
  String _getChangeType(PostgresChangeEvent eventType) {
    switch (eventType) {
      case PostgresChangeEvent.insert:
        return 'created';
      case PostgresChangeEvent.update:
        return 'updated';
      case PostgresChangeEvent.delete:
        return 'deleted';
      case PostgresChangeEvent.all:
        return 'all';
    }
  }

  /// Setup menu item real-time listener
  Future<void> _setupMenuItemListener() async {
    try {
      _supabase
          .channel('menu_items_changes')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: 'menu_items',
            callback: _handleMenuItemChange,
          )
          .subscribe();

      debugPrint('🔄 Menu item listener setup completed');
    } catch (e) {
      debugPrint('❌ Error setting up menu item listener: $e');
    }
  }

  /// Handle menu item changes
  void _handleMenuItemChange(PostgresChangePayload payload) {
    try {
      final changeType = _getChangeType(payload.eventType);
      final data = payload.newRecord;

      final update = {
        'type': 'menu_item',
        'action': changeType,
        'data': data,
        'timestamp': DateTime.now().toIso8601String(),
        'id': data['id'] ?? 'unknown',
      };

      _menuItemUpdatesController.add(update);
      debugPrint('🔄 Menu item $changeType: ${data['id'] ?? 'unknown'}');
    } catch (e) {
      debugPrint('❌ Error handling menu item change: $e');
    }
  }

  // Socket.io helpers removed

  /// Subscribe to specific request updates
  Stream<Map<String, dynamic>> subscribeToRequest(
      String requestId, String type) {
    if (type == 'restaurant') {
      return restaurantUpdates.where((update) =>
          update['id'] == requestId && update['type'] == 'restaurant_request');
    } else if (type == 'delivery') {
      return deliveryUpdates.where((update) =>
          update['id'] == requestId &&
          update['type'] == 'delivery_man_request');
    }

    return const Stream.empty();
  }

  /// Subscribe to status changes only
  Stream<Map<String, dynamic>> subscribeToStatusChanges(String type) {
    if (type == 'restaurant') {
      return restaurantUpdates.where((update) =>
          update['action'] == 'updated' && update['data']['status'] != null);
    } else if (type == 'delivery') {
      return deliveryUpdates.where((update) =>
          update['action'] == 'updated' && update['data']['status'] != null);
    }

    return const Stream.empty();
  }

  /// Subscribe to new requests only
  Stream<Map<String, dynamic>> subscribeToNewRequests(String type) {
    if (type == 'restaurant') {
      return restaurantUpdates.where((update) => update['action'] == 'created');
    } else if (type == 'delivery') {
      return deliveryUpdates.where((update) => update['action'] == 'created');
    }

    return const Stream.empty();
  }

  /// Get connection status
  bool get isConnected {
    return _restaurantChannel != null && _deliveryChannel != null;
  }

  /// Get connection status stream
  Stream<bool> get connectionStatus async* {
    while (true) {
      yield isConnected;
      await Future.delayed(const Duration(seconds: 5));
    }
  }

  /// Reconnect if disconnected
  Future<void> reconnect() async {
    try {
      await _restaurantChannel?.unsubscribe();
      await _deliveryChannel?.unsubscribe();

      await Future.delayed(const Duration(seconds: 1));

      await _setupRestaurantListener();
      await _setupDeliveryListener();

      debugPrint('🔄 RealtimeService reconnected');
    } catch (e) {
      debugPrint('❌ Error reconnecting RealtimeService: $e');
    }
  }

  /// Pause real-time updates
  Future<void> pause() async {
    try {
      await _restaurantChannel?.unsubscribe();
      await _deliveryChannel?.unsubscribe();
      debugPrint('⏸️ RealtimeService paused');
    } catch (e) {
      debugPrint('❌ Error pausing RealtimeService: $e');
    }
  }

  /// Resume real-time updates
  Future<void> resume() async {
    try {
      await _setupRestaurantListener();
      await _setupDeliveryListener();
      debugPrint('▶️ RealtimeService resumed');
    } catch (e) {
      debugPrint('❌ Error resuming RealtimeService: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _restaurantChannel?.unsubscribe();
    _deliveryChannel?.unsubscribe();
    _restaurantUpdatesController.close();
    _deliveryUpdatesController.close();
    debugPrint('🗑️ RealtimeService disposed');
  }
}

/// Real-time update types
enum RealtimeUpdateType {
  restaurantRequest,
  deliveryManRequest,
}

/// Real-time action types
enum RealtimeAction {
  created,
  updated,
  deleted,
}

/// Real-time update data model
class RealtimeUpdate {
  final RealtimeUpdateType type;
  final RealtimeAction action;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final String id;

  const RealtimeUpdate({
    required this.type,
    required this.action,
    required this.data,
    required this.timestamp,
    required this.id,
  });

  factory RealtimeUpdate.fromMap(Map<String, dynamic> map) {
    return RealtimeUpdate(
      type: RealtimeUpdateType.values.firstWhere(
        (e) => e.toString().split('.').last == map['type'],
        orElse: () => RealtimeUpdateType.restaurantRequest,
      ),
      action: RealtimeAction.values.firstWhere(
        (e) => e.toString().split('.').last == map['action'],
        orElse: () => RealtimeAction.created,
      ),
      data: Map<String, dynamic>.from(map['data'] ?? {}),
      timestamp:
          DateTime.parse(map['timestamp'] ?? DateTime.now().toIso8601String()),
      id: map['id'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.toString().split('.').last,
      'action': action.toString().split('.').last,
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'id': id,
    };
  }

  @override
  String toString() {
    return 'RealtimeUpdate(type: $type, action: $action, id: $id, timestamp: $timestamp)';
  }
}
