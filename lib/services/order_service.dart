import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/order.dart';
import '../models/order_item.dart';
import 'context_aware_service.dart';
import 'context_tracking_service.dart';
import 'delivery_fee_service.dart';
import 'info_service.dart';
import 'logging_service.dart';
import 'queue_service.dart';
import 'system_config_service.dart';

class OrderService extends ChangeNotifier {
  static final OrderService _instance = OrderService._internal();
  factory OrderService() => _instance;
  OrderService._internal();

  SupabaseClient get client => Supabase.instance.client;

  // Context-aware service for tracking and validation
  final ContextAwareService _contextAware = ContextAwareService();

  // System configuration service for fee calculations
  final SystemConfigService _systemConfigService = SystemConfigService();
  final DeliveryFeeService _deliveryFeeService = DeliveryFeeService();
  final LoggingService _logger = LoggingService();

  // Performance tracking
  final Map<String, DateTime> _operationStartTimes = {};
  final Map<String, int> _operationCounts = {};

  // Initialize the service with context tracking
  Future<void> initialize() async {
    try {
      _logger.startPerformanceTimer('order_service_init');
      await _contextAware.initialize();
      _logger.endPerformanceTimer('order_service_init',
          details: 'OrderService initialized successfully');
      debugPrint('🚀 OrderService initialized with context tracking');
      _logger.info('OrderService initialized', tag: 'ORDER');
    } catch (e) {
      _logger.error('Failed to initialize OrderService',
          tag: 'ORDER', error: e);
      rethrow;
    }
  }

  // Check restaurant availability for given time
  Future<bool?> checkRestaurantAvailability({
    required String restaurantId,
    required DateTime orderTime,
  }) async {
    return _contextAware.executeWithContext(
      operation: 'checkRestaurantAvailability',
      service: 'OrderService',
      operationFunction: () async {
        try {
          // Check if restaurant is open at the requested time
          final response = await client
              .from('restaurants')
              .select('opening_hours, is_open')
              .eq('id', restaurantId)
              .single();

          // Note: Supabase single() throws an exception if not found, so this check is unnecessary

          final isOpen = response['is_open'] ?? false;
          if (!isOpen) return false;

          // Check opening hours (simplified - in real app, parse opening_hours JSON)
          final openingHours = response['opening_hours'];
          if (openingHours == null) return true;

          // For now, assume restaurant is available if it's marked as open
          return true;
        } catch (e) {
          debugPrint('Error checking restaurant availability: $e');
          return false;
        }
      },
      metadata: {
        'restaurant_id': restaurantId,
        'order_time': orderTime.toIso8601String(),
      },
    );
  }

  // Calculate order total with delivery fee and tax
  Future<Map<String, double>?> calculateOrderTotal({
    required List<OrderItem> orderItems,
    required String restaurantId,
    required Map<String, dynamic> deliveryAddress,
  }) async {
    return _contextAware.executeWithContext(
      operation: 'calculateOrderTotal',
      service: 'OrderService',
      operationFunction: () async {
        double subtotal = 0.0;

        // Calculate subtotal from order items
        for (final item in orderItems) {
          subtotal += item.totalPrice;
        }

        // Calculate distance-based delivery fee
        double deliveryFee = 0.0;
        if (deliveryAddress.containsKey('latitude') &&
            deliveryAddress.containsKey('longitude')) {
          try {
            deliveryFee = await _deliveryFeeService.calculateDeliveryFee(
              restaurantId: restaurantId,
              customerLatitude: (deliveryAddress['latitude'] as num).toDouble(),
              customerLongitude:
                  (deliveryAddress['longitude'] as num).toDouble(),
            );
          } catch (e) {
            debugPrint('❌ Error calculating distance-based delivery fee: $e');
            // Fallback to restaurant's base delivery fee
            final restaurantResponse = await client
                .from('restaurants')
                .select('delivery_fee')
                .eq('id', restaurantId)
                .single();
            deliveryFee =
                (restaurantResponse['delivery_fee'] ?? 0.0).toDouble();
          }
        } else {
          // Fallback to restaurant's base delivery fee if no location data
          final restaurantResponse = await client
              .from('restaurants')
              .select('delivery_fee')
              .eq('id', restaurantId)
              .single();
          deliveryFee = (restaurantResponse['delivery_fee'] ?? 0.0).toDouble();
        }

        // Calculate tax (simplified - 10% of subtotal)
        const taxRate = 0.10;
        final taxAmount = subtotal * taxRate;

        // Get service fee from system configuration
        final serviceFee = _systemConfigService.serviceFee;

        // Calculate total including service fee
        final totalAmount = subtotal + deliveryFee + taxAmount + serviceFee;

        return {
          'subtotal': subtotal,
          'deliveryFee': deliveryFee,
          'taxAmount': taxAmount,
          'serviceFee': serviceFee,
          'totalAmount': totalAmount,
        };
      },
      metadata: {
        'restaurant_id': restaurantId,
        'order_items_count': orderItems.length,
        'delivery_address': deliveryAddress,
      },
    );
  }

  // Create a new order with context tracking and business rule validation
  Future<Order?> createOrder({
    required String restaurantId,
    required String customerId,
    required List<OrderItem> orderItems,
    required Map<String, dynamic> deliveryAddress,
    required String paymentMethod,
    String? specialInstructions,
    DateTime? estimatedDeliveryTime,
    // Promo code integration
    dynamic appliedPromoCode, // PromoCode object
    double? discountAmount,
    double? originalSubtotal,
  }) async {
    // First, analyze the feature for potential conflicts
    final analysis = await _contextAware.analyzeFeature(
      featureName: 'Create Order',
      services: ['OrderService', 'PaymentService', 'NotificationService'],
      tables: ['orders', 'order_items', 'payments', 'notifications'],
      operations: ['create', 'insert'],
    );

    if (analysis.hasWarnings) {
      debugPrint('⚠️ Warnings detected for order creation:');
      for (final warning in analysis.warnings) {
        debugPrint('   - $warning');
      }
    }

    // Apply business rules before creating order
    final businessRuleValid = await _contextAware.applyBusinessRules(
      category: 'order',
      context: {
        'restaurant_id': restaurantId,
        'customer_id': customerId,
        'order_items_count': orderItems.length,
        'delivery_address': deliveryAddress,
      },
    );

    if (!businessRuleValid) {
      debugPrint('❌ Business rule validation failed for order creation');
      throw Exception('Business rule validation failed');
    }

    return _contextAware.executeDatabaseOperation(
      operation: 'Create Order',
      table: 'orders',
      operationType: 'insert',
      operationFunction: () async {
        try {
          // Generate order number
          final orderNumber = _generateOrderNumber();

          // Calculate order total
          final totalCalculation = await calculateOrderTotal(
            orderItems: orderItems,
            restaurantId: restaurantId,
            deliveryAddress: deliveryAddress,
          );

          if (totalCalculation == null) {
            throw Exception('Failed to calculate order total');
          }

          // Validate discount amount doesn't exceed subtotal
          final finalDiscountAmount = discountAmount ?? 0.0;
          final finalSubtotal =
              originalSubtotal ?? totalCalculation['subtotal'] ?? 0.0;

          if (finalDiscountAmount > finalSubtotal) {
            throw Exception(
                'Discount amount (${finalDiscountAmount.toStringAsFixed(2)}) cannot exceed subtotal (${finalSubtotal.toStringAsFixed(2)})');
          }

          // Calculate total amount with proper null safety
          final baseTotalAmount = totalCalculation['totalAmount'] ?? 0.0;
          final finalTotalAmount = (baseTotalAmount - finalDiscountAmount)
              .clamp(0.0, double.infinity);

          final orderData = {
            'restaurant_id': restaurantId,
            'customer_id': customerId,
            'order_number': orderNumber,
            'status': 'pending',
            'payment_status': 'pending',
            'subtotal': finalSubtotal,
            'delivery_fee': totalCalculation['deliveryFee'] ?? 0.0,
            'tax_amount': totalCalculation['taxAmount'] ?? 0.0,
            'service_fee': totalCalculation['serviceFee'] ?? 0.0,
            'discount_amount': finalDiscountAmount,
            'total_amount': finalTotalAmount,
            'payment_method': paymentMethod,
            'delivery_address': deliveryAddress,
            'special_instructions': specialInstructions,
            'estimated_delivery_time': estimatedDeliveryTime?.toIso8601String(),
            'applied_promo_code_id': appliedPromoCode?.id,
            'applied_promo_code': appliedPromoCode?.code,
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          };

          // Create order
          final orderResponse =
              await client.from('orders').insert(orderData).select().single();

          final order = Order.fromJson(orderResponse);

          // Create order items
          for (final item in orderItems) {
            final orderItemData = {
              'order_id': order.id,
              'menu_item_id': item.menuItemId,
              'quantity': item.quantity,
              'unit_price': item.unitPrice,
              'total_price': item.totalPrice,
              'special_instructions': item.specialInstructions,
              'customizations': item.customizations?.toJson(),
              'created_at': DateTime.now().toIso8601String(),
            };

            await client.from('order_items').insert(orderItemData);
          }

          // Execute the order creation event chain
          await _executeOrderCreationChain(order);

          // Enqueue background processing and notifications
          try {
            final queue = QueueService();
            final processResult = await queue.enqueue(
              taskIdentifier: 'process_order',
              payload: {'order_id': order.id},
            );
            if (!processResult.success) {
              debugPrint(
                  'Failed to enqueue order processing: ${processResult.error}');
            }

            final notificationResult = await queue.enqueue(
              taskIdentifier: 'send_notification',
              payload: {
                'user_id': order.customerId,
                'title': 'Order Placed',
                'message':
                    'Your order #${order.orderNumber} was placed successfully.'
              },
            );
            if (!notificationResult.success) {
              debugPrint(
                  'Failed to enqueue order notification: ${notificationResult.error}');
            }
          } catch (e) {
            debugPrint('Error enqueuing order tasks: $e');
          }

          notifyListeners();
          return order;
        } catch (e) {
          debugPrint('❌ Error creating order: $e');
          if (e.toString().contains('violates foreign key constraint')) {
            throw Exception('Invalid restaurant or menu item ID provided');
          } else if (e.toString().contains('violates not-null constraint')) {
            throw Exception('Required order information is missing');
          } else if (e.toString().contains('violates check constraint')) {
            throw Exception('Order data contains invalid values');
          } else if (e.toString().contains('duplicate key value')) {
            throw Exception('Order number already exists, please try again');
          }
          throw Exception('Failed to create order: ${e.toString()}');
        }
      },
      data: {
        'restaurant_id': restaurantId,
        'customer_id': customerId,
        'order_items_count': orderItems.length,
        'status': 'pending',
      },
      rlsPolicies: {
        'insert': 'auth.uid() = customer_id',
        'select':
            'auth.uid() = customer_id OR auth.uid() = restaurant_owner_id',
        'update':
            'auth.uid() = customer_id OR auth.uid() = restaurant_owner_id',
      },
    );
  }

  // Execute the order creation event chain
  Future<void> _executeOrderCreationChain(Order order) async {
    await _contextAware.executeEventChain(
      chainName: 'Order Creation Flow',
      trigger: 'user_creates_order',
      steps: [
        EventStep(
          service: 'OrderService',
          operation: 'createOrder',
          description: 'Create order record',
          data: order.toJson(),
        ),
        EventStep(
          service: 'PaymentService',
          operation: 'processOrderPayment',
          description: 'Process order payment',
          data: {
            'order_id': order.id,
            'amount': order.totalAmount,
            'customer_id': order.customerId,
            'payment_method': order.paymentMethod,
          },
        ),
        EventStep(
          service: 'NotificationService',
          operation: 'sendOrderNotification',
          description: 'Send confirmation to customer and restaurant',
          data: {
            'order_id': order.id,
            'customer_id': order.customerId,
            'restaurant_id': order.restaurantId,
            'order_number': order.orderNumber,
          },
        ),
        EventStep(
          service: 'RestaurantService',
          operation: 'updateRestaurantStatus',
          description: 'Update restaurant order status',
          data: {
            'restaurant_id': order.restaurantId,
            'has_pending_orders': true,
          },
        ),
      ],
    );
  }

  // Convert enum name to database format (snake_case)
  String _convertStatusToDatabaseFormat(OrderStatus status) {
    switch (status) {
      case OrderStatus.pending:
        return 'pending';
      case OrderStatus.confirmed:
        return 'confirmed';
      case OrderStatus.preparing:
        return 'preparing';
      case OrderStatus.ready:
        return 'ready';
      case OrderStatus.pickedUp:
        return 'picked_up';
      case OrderStatus.delivered:
        return 'delivered';
      case OrderStatus.cancelled:
        return 'cancelled';
    }
  }

  // Update order status with context tracking
  Future<bool> updateOrderStatus({
    required String orderId,
    required OrderStatus status,
    String? notes,
  }) async {
    return await _contextAware.executeWithContext(
          operation: 'updateOrderStatus',
          service: 'OrderService',
          operationFunction: () async {
            try {
              // Convert enum name to database format (snake_case)
              final statusString = _convertStatusToDatabaseFormat(status);

              final updateData = {
                'status': statusString,
                'updated_at': DateTime.now().toIso8601String(),
              };

              if (status == OrderStatus.delivered) {
                updateData['actual_delivery_time'] =
                    DateTime.now().toIso8601String();
              }

              final response = await client
                  .from('orders')
                  .update(updateData)
                  .eq('id', orderId)
                  .neq('status', statusString)
                  .select('id, status, updated_at');

              if (response.isEmpty) {
                throw Exception(
                    'No rows updated (id not found or status unchanged)');
              }

              // Enqueue status notification
              try {
                final order = await getOrderById(orderId);
                if (order != null) {
                  final queue = QueueService();
                  final result = await queue.enqueue(
                    taskIdentifier: 'send_notification',
                    payload: {
                      'user_id': order.customerId,
                      'title': 'Order ${status.name}',
                      'message':
                          'Order #${order.orderNumber} is now ${status.name.replaceAll('_', ' ')}.'
                    },
                  );
                  if (!result.success) {
                    debugPrint(
                        'Failed to enqueue order status notification: ${result.error}');
                  }
                }
              } catch (e) {
                debugPrint('Error enqueuing order status notification: $e');
              }

              notifyListeners();
              return true;
            } catch (e) {
              debugPrint('Error updating order status: $e');
              return false;
            }
          },
          metadata: {
            'order_id': orderId,
            'status': status.name,
            'notes': notes,
          },
        ) ??
        false;
  }

  // Cancel order with refund calculation and business rule validation
  Future<Map<String, dynamic>?> cancelOrder({
    required String orderId,
    required DateTime cancellationDate,
    String? reason,
  }) async {
    // Apply cancellation business rules
    final cancellationValid = await _contextAware.applyBusinessRules(
      category: 'order',
      context: {
        'cancellation_date': cancellationDate.toIso8601String(),
        'order_id': orderId,
        'reason': reason,
      },
    );

    if (!cancellationValid) {
      debugPrint('❌ Cancellation business rule validation failed');
      throw Exception('Cancellation not allowed');
    }

    return _contextAware.executeWithContext(
      operation: 'cancelOrder',
      service: 'OrderService',
      operationFunction: () async {
        try {
          final order = await getOrderById(orderId);
          if (order == null) {
            throw Exception('Order not found');
          }

          // Check if order can be cancelled
          if (order.status == OrderStatus.delivered ||
              order.status == OrderStatus.cancelled) {
            throw Exception('Order cannot be cancelled');
          }

          // Calculate refund based on order status
          double refundPercentage = 0.0;
          String refundReason = '';

          if (order.status == OrderStatus.pending) {
            refundPercentage = 1.0; // 100% refund
            refundReason = 'Order cancelled before confirmation';
          } else if (order.status == OrderStatus.confirmed) {
            refundPercentage = 0.8; // 80% refund
            refundReason = 'Order cancelled after confirmation';
          } else if (order.status == OrderStatus.preparing) {
            refundPercentage = 0.5; // 50% refund
            refundReason = 'Order cancelled during preparation';
          } else {
            refundPercentage = 0.0; // No refund
            refundReason = 'Order cancelled too late';
          }

          final refundAmount = order.totalAmount * refundPercentage;

          // Update order status
          await updateOrderStatus(
            orderId: orderId,
            status: OrderStatus.cancelled,
          );

          return {
            'success': true,
            'refundPercentage': refundPercentage,
            'refundAmount': refundAmount,
            'refundReason': refundReason,
          };
        } catch (e) {
          debugPrint('Error cancelling order: $e');
          return {
            'success': false,
            'error': e.toString(),
          };
        }
      },
      metadata: {
        'order_id': orderId,
        'cancellation_date': cancellationDate.toIso8601String(),
        'reason': reason,
      },
    );
  }

  // Get orders by user ID with context tracking
  Future<List<Order>> getOrdersByUserId(String userId) async {
    final result = await _contextAware.executeWithContext(
      operation: 'getOrdersByUserId',
      service: 'OrderService',
      operationFunction: () async {
        try {
          final response = await client
              .from('orders')
              .select('''
                *,
                restaurants(*),
                order_items(
                  *,
                  menu_item:menu_items(*)
                ),
                delivery_personnel(*)
              ''')
              .eq('customer_id', userId)
              .order('created_at', ascending: false);

          final orders = (response as List<dynamic>)
              .map<Order>(
                  (json) => Order.fromJson(json as Map<String, dynamic>))
              .toList();
          return orders;
        } catch (e) {
          debugPrint('Error getting orders by user ID: $e');
          return [];
        }
      },
      metadata: {
        'user_id': userId,
      },
    );

    // Ensure we always return a strongly typed List<Order>
    if (result is List<Order>) {
      return result;
    }
    if (result is List) {
      try {
        return result
            .map((e) => e is Order
                ? e
                : Order.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (e) {
        debugPrint('Error casting orders list: $e');
        return [];
      }
    }
    return [];
  }

  // Get order by ID with context tracking
  Future<Order?> getOrderById(String orderId) async {
    return _contextAware.executeWithContext(
      operation: 'getOrderById',
      service: 'OrderService',
      operationFunction: () async {
        try {
          // First try the view (faster, includes all related entities)
          try {
            final response = await client
                .from('v_orders_with_entities')
                .select('*')
                .eq('id', orderId)
                .single();

            // Overlay with info registry for non-null canonical attributes
            final info = await InfoService().getEntity(
              namespace: 'lo9ma',
              entity: 'order',
              entityId: orderId,
            );
            final base = Map<String, dynamic>.from(response);
            final merged = InfoService().overlayStrings(
              target: base,
              info: info,
              keys: ['order_number', 'status'],
            );
            return Order.fromJson(merged);
          } catch (viewError) {
            // View might not have the order yet (freshly created orders)
            // Fallback to direct query from orders table
            debugPrint(
                '⚠️ Order not found in view, trying direct query: $viewError');

            final response = await client
                .from('orders')
                .select('''
                  *,
                  restaurants(*),
                  order_items(
                    *,
                    menu_item:menu_items(*)
                  ),
                  delivery_personnel(*)
                ''')
                .eq('id', orderId)
                .single();

            // Overlay with info registry for non-null canonical attributes
            final info = await InfoService().getEntity(
              namespace: 'lo9ma',
              entity: 'order',
              entityId: orderId,
            );
            final base = Map<String, dynamic>.from(response);
            final merged = InfoService().overlayStrings(
              target: base,
              info: info,
              keys: ['order_number', 'status'],
            );
            return Order.fromJson(merged);
          }
        } catch (e) {
          debugPrint('Error getting order by ID: $e');
          return null;
        }
      },
      metadata: {
        'order_id': orderId,
      },
    );
  }

  // Clean up all related data when an order is deleted
  Future<void> cleanupDeletedOrder(String orderId) async {
    return _contextAware.executeWithContext(
      operation: 'cleanupDeletedOrder',
      service: 'OrderService',
      operationFunction: () async {
        try {
          debugPrint(
              '🧹 Starting comprehensive cleanup for deleted order $orderId');

          // Delete order items first (due to foreign key constraints)
          await client.from('order_items').delete().eq('order_id', orderId);

          // Delete delivery assignments
          await client
              .from('delivery_assignments')
              .delete()
              .eq('order_id', orderId);

          // Delete notifications
          await client.from('notifications').delete().eq('order_id', orderId);

          // Delete tracking data
          await client
              .from('delivery_tracking')
              .delete()
              .eq('order_id', orderId);

          // Delete payment records
          await client.from('payments').delete().eq('order_id', orderId);

          // Delete queue items
          await client.from('queue_items').delete().eq('order_id', orderId);

          // Finally delete the order itself
          await client.from('orders').delete().eq('id', orderId);

          debugPrint('✅ Comprehensive cleanup completed for order $orderId');
        } catch (e) {
          debugPrint(
              '❌ Error during comprehensive cleanup of order $orderId: $e');
          rethrow;
        }
      },
      metadata: {
        'order_id': orderId,
      },
    );
  }

  // Get customer orders with context tracking
  Future<List<Order>?> getCustomerOrders({
    OrderStatus? status,
    int limit = 20,
    int offset = 0,
  }) async {
    return _contextAware.executeWithContext(
      operation: 'getCustomerOrders',
      service: 'OrderService',
      operationFunction: () async {
        try {
          final currentUser = client.auth.currentUser;
          if (currentUser == null) return [];

          var query = client.from('orders').select('''
                *,
                restaurants(*),
                user_profiles(*),
                order_items(
                  *,
                  menu_items(*)
                )
              ''').eq('customer_id', currentUser.id);

          if (status != null) {
            query = query.eq('status', status.name);
          }

          final response = await query
              .order('created_at', ascending: false)
              .range(offset, offset + limit - 1);

          final List<Order> orders = [];
          for (final row in response) {
            final map = Map<String, dynamic>.from(row);
            final id = map['id']?.toString();
            if (id != null) {
              final info = await InfoService().getEntity(
                namespace: 'lo9ma',
                entity: 'order',
                entityId: id,
              );
              final merged = InfoService().overlayStrings(
                target: map,
                info: info,
                keys: ['order_number', 'status'],
              );
              orders.add(Order.fromJson(merged));
            } else {
              orders.add(Order.fromJson(map));
            }
          }
          return orders;
        } catch (e) {
          debugPrint('Error fetching customer orders: $e');
          return [];
        }
      },
      metadata: {
        'status': status?.name,
        'limit': limit,
        'offset': offset,
      },
    );
  }

  // Get restaurant orders with context tracking
  Future<List<Order>?> getRestaurantOrders({
    required String restaurantId,
    OrderStatus? status,
    int limit = 20,
    int offset = 0,
  }) async {
    return _contextAware.executeWithContext(
      operation: 'getRestaurantOrders',
      service: 'OrderService',
      operationFunction: () async {
        try {
          var query = client.from('orders').select('''
                *,
                restaurants(*),
                order_items(
                  *,
                  menu_items(*)
                )
              ''').eq('restaurant_id', restaurantId);

          if (status != null) {
            query = query.eq('status', status.name);
          }

          final response = await query
              .order('created_at', ascending: false)
              .range(offset, offset + limit - 1);

          debugPrint(
              '📋 OrderService: getRestaurantOrders query returned ${response.length} records for restaurant $restaurantId');

          // Fetch customer data separately for better control
          final customerIds = response
              .map((order) => order['customer_id'])
              .where((id) => id != null)
              .toSet()
              .toList();

          final Map<String, dynamic> customerData = {};
          if (customerIds.isNotEmpty) {
            try {
              // PERFORMANCE: Use inFilter to fetch only needed customer profiles (server-side filtering)
              final userProfilesResponse = await client
                  .from('user_profiles')
                  .select('*')
                  .inFilter('id', customerIds);

              for (final profile in userProfilesResponse) {
                customerData[profile['id']] = profile;
              }

              if (kDebugMode) {
                debugPrint(
                    'Found ${userProfilesResponse.length} user profiles for ${customerIds.length} customer IDs');
              }

              // If no user profiles found, create dummy data to prevent null errors
              if (userProfilesResponse.isEmpty && customerIds.isNotEmpty) {
                debugPrint(
                    '⚠️ No user profiles found. Creating dummy customer data for orders.');
                for (final customerId in customerIds) {
                  customerData[customerId] = {
                    'id': customerId,
                    'full_name': 'Customer',
                    'name': 'Customer',
                    'phone': null,
                    'address': null,
                    'wilaya': null,
                  };
                }
              }

              // If we didn't get all customer data from user_profiles, create dummy data
              if (userProfilesResponse.length < customerIds.length) {
                final missingIds = customerIds
                    .where((id) => !customerData.containsKey(id))
                    .toList();
                if (missingIds.isNotEmpty) {
                  debugPrint(
                      'Missing customer data for IDs: $missingIds. Creating dummy data.');
                  for (final missingId in missingIds) {
                    customerData[missingId] = {
                      'id': missingId,
                      'full_name': 'Customer',
                      'name': 'Customer',
                      'phone': null,
                      'address': null,
                      'wilaya': null,
                    };
                  }
                }
              }
            } catch (e) {
              debugPrint('Error fetching customer data: $e');
            }
          }

          // Merge customer data with orders
          final ordersWithCustomers = response.map((order) {
            final customerId = order['customer_id'];
            if (customerId != null && customerData.containsKey(customerId)) {
              order['user_profiles'] = customerData[customerId];
            }
            return order;
          }).toList();

          // PERFORMANCE: Batch fetch all InfoService data in parallel instead of sequential
          final orderIds = ordersWithCustomers
              .map((row) => row['id']?.toString())
              .whereType<String>()
              .toList();

          // Parallel fetch all InfoService data
          final infoFutures = orderIds.map((id) {
            return InfoService()
                .getEntity(
              namespace: 'lo9ma',
              entity: 'order',
              entityId: id,
            )
                .catchError((e) {
              if (kDebugMode) {
                debugPrint('InfoService error for order $id: $e');
              }
              return <String, dynamic>{};
            });
          }).toList();

          final infoResults = await Future.wait(infoFutures);

          // Create a map of order ID to info for fast lookup
          final infoMap = <String, Map<String, dynamic>>{};
          for (int i = 0; i < orderIds.length; i++) {
            infoMap[orderIds[i]] = infoResults[i];
          }

          // Parse orders with pre-fetched info data
          final List<Order> orders = [];
          for (final row in ordersWithCustomers) {
            final id = row['id']?.toString();
            if (id != null && infoMap.containsKey(id)) {
              final merged = InfoService().overlayStrings(
                target: Map<String, dynamic>.from(row),
                info: infoMap[id]!,
                keys: ['order_number', 'status'],
              );
              orders.add(Order.fromJson(merged));
            } else {
              orders.add(Order.fromJson(row));
            }
          }

          if (kDebugMode) {
            debugPrint(
                '⚡ Batch loaded ${orders.length} orders with parallel InfoService calls');
          }

          return orders;
        } catch (e) {
          debugPrint(
              '❌ Error fetching restaurant orders for $restaurantId: $e');
          return [];
        }
      },
      metadata: {
        'restaurant_id': restaurantId,
        'status': status?.name,
        'limit': limit,
        'offset': offset,
      },
    );
  }

  // Get active orders count
  Future<int> getActiveOrdersCount(String customerId) async {
    try {
      final orders = await getCustomerOrders(status: OrderStatus.confirmed);
      return orders?.length ?? 0;
    } catch (e) {
      debugPrint('Error getting active orders count: $e');
      return 0;
    }
  }

  // Get pending orders count
  Future<int> getPendingOrdersCount(String customerId) async {
    try {
      final orders = await getCustomerOrders(status: OrderStatus.pending);
      return orders?.length ?? 0;
    } catch (e) {
      debugPrint('Error getting pending orders count: $e');
      return 0;
    }
  }

  // Get total earnings for a restaurant
  Future<double> getTotalEarnings(String restaurantId) async {
    try {
      final response = await client
          .from('orders')
          .select('total_amount')
          .eq('restaurant_id', restaurantId)
          .eq('status', 'delivered');

      double totalEarnings = 0.0;
      for (final order in response) {
        totalEarnings += (order['total_amount'] ?? 0.0).toDouble();
      }

      return totalEarnings;
    } catch (e) {
      debugPrint('Error getting total earnings: $e');
      return 0.0;
    }
  }

  // Generate unique order number
  String _generateOrderNumber() {
    final now = DateTime.now();
    final timestamp = now.millisecondsSinceEpoch.toString().substring(8);
    final random = (now.microsecond % 1000).toString().padLeft(3, '0');
    return 'ORD-$timestamp$random';
  }

  // Get context summary for debugging
  Map<String, dynamic> getContextSummary() {
    return _contextAware.getContextSummary();
  }

  /// Get performance analytics for the service
  Map<String, dynamic> getPerformanceAnalytics() {
    final totalOperations =
        _operationCounts.values.fold(0, (sum, count) => sum + count);
    final averageOperationTime = _operationStartTimes.isNotEmpty
        ? _operationStartTimes.values
                .map((startTime) =>
                    DateTime.now().difference(startTime).inMilliseconds)
                .reduce((a, b) => a + b) /
            _operationStartTimes.length
        : 0.0;

    return {
      'service_name': 'OrderService',
      'total_operations': totalOperations,
      'average_operation_time_ms': averageOperationTime,
      'operation_counts': Map.from(_operationCounts),
    };
  }

  /// Clear performance cache
  void clearPerformanceCache() {
    _operationStartTimes.clear();
    _operationCounts.clear();
    _logger.info('OrderService performance cache cleared', tag: 'ORDER');
  }
}
