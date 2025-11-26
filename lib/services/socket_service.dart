import "dart:async";

import "package:flutter/widgets.dart";
import "package:supabase_flutter/supabase_flutter.dart";

/// Simplified real-time service (no Socket.IO/Redis). Exposes no-op streams for compatibility.
class SocketService extends ChangeNotifier {
  factory SocketService() => _instance;
  SocketService._internal();
  static final SocketService _instance = SocketService._internal();

  // Supabase client (use for presence if needed)
  SupabaseClient get _supabase => Supabase.instance.client;

  // Connection state
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isDisposed = false;

  // Stream controllers for different event types
  final StreamController<Map<String, dynamic>> _orderUpdatesController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _deliveryLocationController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _typingController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _presenceController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _messageController =
      StreamController<Map<String, dynamic>>.broadcast();

  // Getters for streams
  Stream<Map<String, dynamic>> get orderUpdatesStream =>
      _orderUpdatesController.stream;
  Stream<Map<String, dynamic>> get deliveryLocationStream =>
      _deliveryLocationController.stream;
  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationController.stream;
  Stream<Map<String, dynamic>> get typingStream => _typingController.stream;
  Stream<Map<String, dynamic>> get presenceStream => _presenceController.stream;
  Stream<Map<String, dynamic>> get messageStream => _messageController.stream;

  // Connection state getters
  bool get isConnected => _isConnected && !_isDisposed;
  bool get isConnecting => _isConnecting && !_isDisposed;

  /// Initialize (no-op, kept for API compatibility)
  Future<void> initialize() async {
    if (_isDisposed || _isConnected || _isConnecting) return;
    _isConnecting = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) notifyListeners();
    });
    _isConnected = false; // No socket connection
    _isConnecting = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) notifyListeners();
    });
  }

  // No-op API surface for compatibility with existing callers
  void joinUserRoom(String userId) {}
  void joinOrderRoom(String orderId) {}
  void leaveOrderRoom(String orderId) {}
  void sendOrderStatusChange(String orderId, String status,
      {String? customerId}) {}
  void sendDeliveryLocationUpdate(
      String orderId, double latitude, double longitude) {}
  void sendTypingIndicator(String conversationId, {required bool isTyping}) {}
  void sendUserPresence(String status) {
    // Optionally use Supabase presence here if needed in the future
    final _ = _supabase; // silence unused warning
  }

  void sendNotification(String userId, String title, String message,
      {Map<String, dynamic>? data}) {}
  void joinConversationRoom(String conversationId) {}
  void sendMessage(String conversationId, String message,
      {String? messageType}) {}
  Future<void> reconnect() async {}

  /// Disconnect (no-op)
  void disconnect() {
    _isConnected = false;
    _isConnecting = false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_isDisposed) notifyListeners();
    });
  }

  /// Dispose resources
  @override
  void dispose() {
    _isDisposed = true;
    _orderUpdatesController.close();
    _deliveryLocationController.close();
    _notificationController.close();
    _typingController.close();
    _presenceController.close();
    _messageController.close();
    super.dispose();
  }
}
