import 'package:supabase_flutter/supabase_flutter.dart';
import 'logging_service.dart';

class OrderAcceptanceService {
  static SupabaseClient get _supabase => Supabase.instance.client;
  static final LoggingService _logger = LoggingService();

  /// Safely accept an order with race condition protection
  static Future<OrderAcceptanceResult> acceptOrder({
    required String orderId,
    required String deliveryPersonId,
  }) async {
    try {
      _logger.startPerformanceTimer('order_acceptance', metadata: {
        'order_id': orderId,
        'delivery_person_id': deliveryPersonId,
      });

      _logger.logUserAction(
        'order_acceptance_started',
        userId: deliveryPersonId,
        data: {
          'order_id': orderId,
          'delivery_person_id': deliveryPersonId,
        },
      );

      // First, debug the order status
      await _debugOrderStatus(orderId);

      // First, check if order is still available
      final availabilityCheck = await _checkOrderAvailability(orderId);
      if (!availabilityCheck.isAvailable) {
        _logger.warning('Order not available for acceptance',
            tag: 'ORDER_ACCEPTANCE',
            additionalData: {
              'order_id': orderId,
              'delivery_person_id': deliveryPersonId,
              'error': availabilityCheck.error,
              'code': availabilityCheck.code,
            });

        _logger.endPerformanceTimer('order_acceptance',
            details: 'Order not available');

        return OrderAcceptanceResult(
          success: false,
          error: availabilityCheck.error ?? 'Order is no longer available',
          code: availabilityCheck.code ?? 'ORDER_NOT_AVAILABLE',
        );
      }

      // Call the database function to safely accept the order
      final response = await _supabase.rpc(
        'accept_order_safely',
        params: {
          'p_order_id': orderId,
          'p_delivery_person_id': deliveryPersonId,
        },
      );

      if (response == null) {
        _logger.error('No response from server for order acceptance',
            tag: 'ORDER_ACCEPTANCE',
            additionalData: {
              'order_id': orderId,
              'delivery_person_id': deliveryPersonId,
            });

        _logger.endPerformanceTimer('order_acceptance',
            details: 'No response from server');

        return OrderAcceptanceResult(
          success: false,
          error: 'No response from server',
          code: 'NO_RESPONSE',
        );
      }

      // Parse the response
      final result = response as Map<String, dynamic>;

      if (result['success'] == true) {
        _logger.logUserAction(
          'order_acceptance_successful',
          userId: deliveryPersonId,
          data: {
            'order_id': orderId,
            'delivery_person_id': deliveryPersonId,
            'message': result['message'],
          },
        );

        _logger.endPerformanceTimer('order_acceptance',
            details: 'Order accepted successfully');

        return OrderAcceptanceResult(
          success: true,
          order: result['order'],
          message: result['message'] ?? 'Order accepted successfully',
        );
      } else {
        _logger.warning('Order acceptance failed',
            tag: 'ORDER_ACCEPTANCE',
            additionalData: {
              'order_id': orderId,
              'delivery_person_id': deliveryPersonId,
              'error': result['error'],
              'code': result['code'],
              'debug_info': result['debug'],
            });

        _logger.endPerformanceTimer('order_acceptance',
            details: 'Order acceptance failed');

        return OrderAcceptanceResult(
          success: false,
          error: result['error'] ?? 'Unknown error',
          code: result['code'] ?? 'UNKNOWN_ERROR',
          debugInfo: result['debug'],
        );
      }
    } catch (e) {
      _logger.error('Network error during order acceptance',
          tag: 'ORDER_ACCEPTANCE',
          error: e,
          additionalData: {
            'order_id': orderId,
            'delivery_person_id': deliveryPersonId,
          });

      _logger.endPerformanceTimer('order_acceptance',
          details: 'Network error occurred');

      return OrderAcceptanceResult(
        success: false,
        error: 'Network error: ${e.toString()}',
        code: 'NETWORK_ERROR',
      );
    }
  }

  /// Check if an order is still available before attempting to accept it
  static Future<OrderAvailabilityResult> _checkOrderAvailability(
      String orderId) async {
    try {
      final response = await _supabase.rpc(
        'check_order_availability',
        params: {'p_order_id': orderId},
      );

      return OrderAvailabilityResult(
        isAvailable: response == true,
        error: response == false ? 'Order is no longer available' : null,
        code: response == false ? 'ORDER_NOT_AVAILABLE' : null,
      );
    } catch (e) {
      return OrderAvailabilityResult(
        isAvailable: false,
        error: 'Failed to check order availability: ${e.toString()}',
        code: 'CHECK_FAILED',
      );
    }
  }

  /// Get available orders with real-time updates
  static Stream<List<Map<String, dynamic>>> getAvailableOrdersStream() {
    return _supabase
        .from('v_available_orders')
        .stream(primaryKey: ['id']).order('created_at', ascending: false);
  }

  /// Get orders assigned to a specific delivery person
  static Stream<List<Map<String, dynamic>>> getDeliveryPersonOrdersStream(
      String deliveryPersonId) {
    return _supabase
        .from('orders')
        .stream(primaryKey: ['id'])
        .eq('delivery_person_id', deliveryPersonId)
        .order('created_at', ascending: false);
  }

  /// Debug function to check order status
  static Future<Map<String, dynamic>> _debugOrderStatus(String orderId) async {
    try {
      final response = await _supabase.rpc(
        'debug_order_status',
        params: {'p_order_id': orderId},
      );
      return response as Map<String, dynamic>;
    } catch (e) {
      return {'error': 'Failed to debug order: ${e.toString()}'};
    }
  }

  /// Get performance analytics for the service
  static Map<String, dynamic> getPerformanceAnalytics() {
    return {
      'service_name': 'OrderAcceptanceService',
      'service_type': 'static_service',
      'description': 'Handles order acceptance with race condition protection',
    };
  }

  /// Clear performance cache
  static void clearPerformanceCache() {
    _logger.info('OrderAcceptanceService performance cache cleared',
        tag: 'ORDER_ACCEPTANCE');
  }
}

class OrderAcceptanceResult {
  final bool success;
  final String? error;
  final String? code;
  final Map<String, dynamic>? order;
  final String? message;
  final Map<String, dynamic>? debugInfo;

  OrderAcceptanceResult({
    required this.success,
    this.error,
    this.code,
    this.order,
    this.message,
    this.debugInfo,
  });

  @override
  String toString() {
    return 'OrderAcceptanceResult(success: $success, error: $error, code: $code, debugInfo: $debugInfo)';
  }
}

class OrderAvailabilityResult {
  final bool isAvailable;
  final String? error;
  final String? code;

  OrderAvailabilityResult({
    required this.isAvailable,
    this.error,
    this.code,
  });
}
