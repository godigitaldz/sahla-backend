import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'context_aware_service.dart';

class ServiceFeeService extends ChangeNotifier {
  static final ServiceFeeService _instance = ServiceFeeService._internal();
  factory ServiceFeeService() => _instance;
  ServiceFeeService._internal();

  SupabaseClient get client => Supabase.instance.client;

  // Context-aware service for tracking and validation
  final ContextAwareService _contextAware = ContextAwareService();

  // Service fee configuration
  static const double _customerServiceFee = 30.0; // DA
  static const double _deliveryDeduction = 20.0; // DA from delivery fee
  static const double _restaurantDeduction = 20.0; // DA from restaurant payment

  // Initialize the service
  Future<void> initialize() async {
    await _contextAware.initialize();
    debugPrint('🚀 ServiceFeeService initialized with context tracking');
  }

  // Get current service fee configuration
  Map<String, dynamic> getServiceFeeConfig() {
    return {
      'customer_service_fee': _customerServiceFee,
      'delivery_deduction': _deliveryDeduction,
      'restaurant_deduction': _restaurantDeduction,
      'platform_total_fee': _customerServiceFee,
      'delivery_net_fee': _deliveryDeduction,
      'restaurant_net_fee': _restaurantDeduction,
    };
  }

  // Calculate service fees for an order
  Map<String, dynamic> calculateOrderFees({
    required double subtotal,
    required double deliveryFee,
    required double taxAmount,
  }) {
    final totalWithoutServiceFee = subtotal + deliveryFee + taxAmount;
    final customerTotal = totalWithoutServiceFee + _customerServiceFee;

    final deliveryNetFee = deliveryFee - _deliveryDeduction;
    final restaurantNetPayment = subtotal - _restaurantDeduction;

    return {
      'subtotal': subtotal,
      'delivery_fee': deliveryFee,
      'tax_amount': taxAmount,
      'service_fee': _customerServiceFee,
      'customer_total': customerTotal,
      'delivery_net_fee': deliveryNetFee,
      'restaurant_net_payment': restaurantNetPayment,
      'platform_profit':
          _customerServiceFee + _deliveryDeduction + _restaurantDeduction,
      'platform_breakdown': {
        'customer_fee': _customerServiceFee,
        'delivery_deduction': _deliveryDeduction,
        'restaurant_deduction': _restaurantDeduction,
      },
    };
  }

  // Update service fee configuration (admin only)
  Future<bool> updateServiceFeeConfig({
    required String adminId,
    double? customerServiceFee,
    double? deliveryDeduction,
    double? restaurantDeduction,
  }) async {
    return await _contextAware.executeWithContext(
          operation: 'updateServiceFeeConfig',
          service: 'ServiceFeeService',
          operationFunction: () async {
            try {
              // Persist customer service fee into unified system_config
              // Note: other fields remain app-side constants; we can move them later if needed
              final feeToStore = customerServiceFee ?? _customerServiceFee;
              await client.from('system_config').upsert(
                {
                  'config_key': 'service_fee',
                  'config_value': feeToStore,
                  'config_type': 'number',
                  'category': 'fees',
                  'description': 'Platform service fee in DA',
                  'updated_by': adminId,
                  'updated_at': DateTime.now().toIso8601String(),
                },
                onConflict: 'config_key',
              );

              debugPrint('✅ Service fee configuration updated');
              notifyListeners();

              return true;
            } catch (e) {
              debugPrint('❌ Error updating service fee config: $e');
              return false;
            }
          },
          metadata: {
            'admin_id': adminId,
            'customer_service_fee': customerServiceFee,
            'delivery_deduction': deliveryDeduction,
            'restaurant_deduction': restaurantDeduction,
          },
        ) ??
        false;
  }

  // Get service fee analytics
  Future<Map<String, dynamic>?> getServiceFeeAnalytics({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    return _contextAware.executeWithContext(
      operation: 'getServiceFeeAnalytics',
      service: 'ServiceFeeService',
      operationFunction: () async {
        try {
          var query = client
              .from('orders')
              .select('total_amount, delivery_fee, created_at')
              .eq('payment_status', 'paid');

          if (startDate != null) {
            query = query.gte('created_at', startDate.toIso8601String());
          }
          if (endDate != null) {
            query = query.lte('created_at', endDate.toIso8601String());
          }

          final orders = await query;

          double totalPlatformProfit = 0.0;
          int totalOrders = 0;
          double totalCustomerFees = 0.0;
          double totalDeliveryDeductions = 0.0;
          double totalRestaurantDeductions = 0.0;

          for (final _ in orders) {
            totalOrders++;

            // Calculate platform profit for this order
            const platformProfit =
                _customerServiceFee + _deliveryDeduction + _restaurantDeduction;
            totalPlatformProfit += platformProfit;

            totalCustomerFees += _customerServiceFee;
            totalDeliveryDeductions += _deliveryDeduction;
            totalRestaurantDeductions += _restaurantDeduction;
          }

          return {
            'total_orders': totalOrders,
            'total_platform_profit': totalPlatformProfit,
            'average_profit_per_order':
                totalOrders > 0 ? totalPlatformProfit / totalOrders : 0.0,
            'total_customer_fees': totalCustomerFees,
            'total_delivery_deductions': totalDeliveryDeductions,
            'total_restaurant_deductions': totalRestaurantDeductions,
            'profit_breakdown': {
              'customer_fees': totalCustomerFees,
              'delivery_deductions': totalDeliveryDeductions,
              'restaurant_deductions': totalRestaurantDeductions,
            },
          };
        } catch (e) {
          debugPrint('❌ Error fetching service fee analytics: $e');
          return null;
        }
      },
      metadata: {
        'start_date': startDate?.toIso8601String(),
        'end_date': endDate?.toIso8601String(),
      },
    );
  }

  // Apply service fees to an order (called during order creation)
  Future<Map<String, dynamic>?> applyServiceFeesToOrder({
    required String orderId,
    required double subtotal,
    required double deliveryFee,
    required double taxAmount,
  }) async {
    return _contextAware.executeWithContext(
      operation: 'applyServiceFeesToOrder',
      service: 'ServiceFeeService',
      operationFunction: () async {
        try {
          final feeCalculation = calculateOrderFees(
            subtotal: subtotal,
            deliveryFee: deliveryFee,
            taxAmount: taxAmount,
          );

          // Update order with service fees
          await client.from('orders').update({
            'service_fee': feeCalculation['service_fee'],
            'customer_total': feeCalculation['customer_total'],
            'delivery_net_fee': feeCalculation['delivery_net_fee'],
            'restaurant_net_payment': feeCalculation['restaurant_net_payment'],
            'platform_profit': feeCalculation['platform_profit'],
            'updated_at': DateTime.now().toIso8601String(),
          }).eq('id', orderId);

          debugPrint('✅ Service fees applied to order $orderId');
          return feeCalculation;
        } catch (e) {
          debugPrint('❌ Error applying service fees to order: $e');
          return null;
        }
      },
      metadata: {
        'order_id': orderId,
        'subtotal': subtotal,
        'delivery_fee': deliveryFee,
        'tax_amount': taxAmount,
      },
    );
  }

  // Get service fee configuration from database
  Future<Map<String, dynamic>?> getStoredServiceFeeConfig() async {
    return _contextAware.executeWithContext(
      operation: 'getStoredServiceFeeConfig',
      service: 'ServiceFeeService',
      operationFunction: () async {
        try {
          // Read from unified system_config
          final row = await client
              .from('system_config')
              .select('config_value, updated_at, updated_by')
              .eq('config_key', 'service_fee')
              .maybeSingle();

          if (row != null) {
            final value = row['config_value'];
            final fee = value is num
                ? value.toDouble()
                : double.tryParse(value?.toString() ?? '') ??
                    _customerServiceFee;
            return {
              'customer_service_fee': fee,
              'delivery_deduction': _deliveryDeduction,
              'restaurant_deduction': _restaurantDeduction,
              'updated_at': row['updated_at'],
              'admin_id': row['updated_by'],
            };
          }

          // Return default config if no stored config exists
          return getServiceFeeConfig();
        } catch (e) {
          debugPrint('❌ Error fetching stored service fee config: $e');
          return getServiceFeeConfig();
        }
      },
      metadata: {},
    );
  }

  // Get context summary for debugging
  Map<String, dynamic> getContextSummary() {
    return _contextAware.getContextSummary();
  }
}
