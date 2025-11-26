import '../../services/performance_monitoring_service.dart';
import '../delivery_address.dart';
import '../order_item.dart';
import '../restaurant.dart';
import '../user.dart' as app_user;

/// Enhanced Order model with adaptive loading and performance optimization
enum OrderStatus {
  pending,
  confirmed,
  preparing,
  ready,
  pickedUp,
  delivered,
  cancelled,
}

enum PaymentStatus {
  pending,
  paid,
  failed,
  refunded,
}

class Order {
  final String id;
  final String restaurantId;
  final String customerId;
  final String? deliveryPersonId;
  final String orderNumber;
  final OrderStatus status;
  final PaymentStatus paymentStatus;
  final double subtotal;
  final double deliveryFee;
  final double taxAmount;
  final double serviceFee;
  final double discountAmount;
  final double totalAmount;
  final String paymentMethod;
  final DeliveryAddress deliveryAddress;
  final String? specialInstructions;
  final DateTime? estimatedDeliveryTime;
  final DateTime? actualDeliveryTime;
  final String? appliedPromoCodeId;
  final String? appliedPromoCode;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Restaurant? restaurant;
  final app_user.User? customer;
  final app_user.User? deliveryPerson;
  final List<OrderItem>? orderItems;

  // Performance optimization fields
  final DateTime? _lastStatusUpdateTime;
  final int _statusUpdateCount;
  final double _averageStatusUpdateTime;
  final bool _isRealTimeEnabled;
  final Map<String, dynamic>? _performanceMetrics;

  Order({
    required this.id,
    required this.restaurantId,
    required this.customerId,
    required this.orderNumber,
    required this.status,
    required this.paymentStatus,
    required this.subtotal,
    required this.deliveryFee,
    required this.taxAmount,
    required this.serviceFee,
    required this.discountAmount,
    required this.totalAmount,
    required this.paymentMethod,
    required this.deliveryAddress,
    required this.createdAt,
    required this.updatedAt,
    this.deliveryPersonId,
    this.specialInstructions,
    this.estimatedDeliveryTime,
    this.actualDeliveryTime,
    this.appliedPromoCodeId,
    this.appliedPromoCode,
    this.restaurant,
    this.customer,
    this.deliveryPerson,
    this.orderItems,
    DateTime? lastStatusUpdateTime,
    int statusUpdateCount = 0,
    double averageStatusUpdateTime = 0.0,
    bool isRealTimeEnabled = true,
    Map<String, dynamic>? performanceMetrics,
  })  : _lastStatusUpdateTime = lastStatusUpdateTime,
        _statusUpdateCount = statusUpdateCount,
        _averageStatusUpdateTime = averageStatusUpdateTime,
        _isRealTimeEnabled = isRealTimeEnabled,
        _performanceMetrics = performanceMetrics;

  factory Order.fromJson(Map<String, dynamic> json) {
    // Start performance monitoring for order parsing
    final performanceService = PerformanceMonitoringService();
    performanceService.startOperation('order_parsing');

    try {
      final order = Order(
        id: json['id'] ?? '',
        restaurantId: json['restaurant_id'] ?? '',
        customerId: json['customer_id'] ?? '',
        deliveryPersonId: json['delivery_person_id'],
        orderNumber: json['order_number'] ?? '',
        status: _parseOrderStatus(json['status']),
        paymentStatus: _parsePaymentStatus(json['payment_status']),
        subtotal: (json['subtotal'] ?? 0.0).toDouble(),
        deliveryFee: (json['delivery_fee'] ?? 0.0).toDouble(),
        taxAmount: (json['tax_amount'] ?? 0.0).toDouble(),
        serviceFee: (json['service_fee'] ?? 0.0).toDouble(),
        discountAmount: (json['discount_amount'] ?? 0.0).toDouble(),
        totalAmount: (json['total_amount'] ?? 0.0).toDouble(),
        paymentMethod: json['payment_method'] ?? 'cash',
        deliveryAddress: json['delivery_address'] != null
            ? (json['delivery_address'] is Map
                ? DeliveryAddress.fromJson(
                    Map<String, dynamic>.from(json['delivery_address']))
                : DeliveryAddress.fromJson({}))
            : const DeliveryAddress(
                street: '',
                city: '',
                postalCode: '',
              ),
        specialInstructions: json['special_instructions'],
        estimatedDeliveryTime: json['estimated_delivery_time'] != null
            ? DateTime.parse(json['estimated_delivery_time'])
            : null,
        actualDeliveryTime: json['actual_delivery_time'] != null
            ? DateTime.parse(json['actual_delivery_time'])
            : null,
        appliedPromoCodeId: json['applied_promo_code_id'],
        appliedPromoCode: json['applied_promo_code'],
        createdAt: DateTime.parse(json['created_at']),
        updatedAt: DateTime.parse(json['updated_at']),
        restaurant: (json['restaurants'] ?? json['restaurant']) != null
            ? Restaurant.fromJson(json['restaurants'] ?? json['restaurant'])
            : null,
        customer: json['user_profiles'] != null
            ? app_user.User.fromJson(json['user_profiles'])
            : null,
        deliveryPerson: json['delivery_personnel'] != null &&
                json['delivery_personnel']['user'] != null
            ? app_user.User.fromJson(json['delivery_personnel']['user'])
            : null,
        orderItems: json['order_items'] != null
            ? (json['order_items'] as List)
                .map((item) => OrderItem.fromJson(item))
                .toList()
            : null,
        lastStatusUpdateTime: DateTime.now(),
        statusUpdateCount: 0,
        averageStatusUpdateTime: 0.0,
        isRealTimeEnabled: true,
        performanceMetrics: {},
      );

      performanceService.endOperation('order_parsing');
      return order;
    } catch (e) {
      performanceService.endOperation('order_parsing');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'restaurant_id': restaurantId,
      'customer_id': customerId,
      'delivery_person_id': deliveryPersonId,
      'order_number': orderNumber,
      'status': status.name,
      'payment_status': paymentStatus.name,
      'subtotal': subtotal,
      'delivery_fee': deliveryFee,
      'tax_amount': taxAmount,
      'service_fee': serviceFee,
      'discount_amount': discountAmount,
      'total_amount': totalAmount,
      'payment_method': paymentMethod,
      'delivery_address': deliveryAddress.toJson(),
      'special_instructions': specialInstructions,
      'estimated_delivery_time': estimatedDeliveryTime?.toIso8601String(),
      'actual_delivery_time': actualDeliveryTime?.toIso8601String(),
      'applied_promo_code_id': appliedPromoCodeId,
      'applied_promo_code': appliedPromoCode,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  static OrderStatus _parseOrderStatus(String? status) {
    switch (status) {
      case 'pending':
        return OrderStatus.pending;
      case 'confirmed':
        return OrderStatus.confirmed;
      case 'preparing':
        return OrderStatus.preparing;
      case 'ready':
        return OrderStatus.ready;
      case 'picked_up':
        return OrderStatus.pickedUp;
      case 'delivered':
        return OrderStatus.delivered;
      case 'cancelled':
        return OrderStatus.cancelled;
      default:
        return OrderStatus.pending;
    }
  }

  static PaymentStatus _parsePaymentStatus(String? status) {
    switch (status) {
      case 'pending':
        return PaymentStatus.pending;
      case 'paid':
        return PaymentStatus.paid;
      case 'failed':
        return PaymentStatus.failed;
      case 'refunded':
        return PaymentStatus.refunded;
      default:
        return PaymentStatus.pending;
    }
  }

  // Helper methods
  bool get isPending => status == OrderStatus.pending;
  bool get isConfirmed => status == OrderStatus.confirmed;
  bool get isPreparing => status == OrderStatus.preparing;
  bool get isReady => status == OrderStatus.ready;
  bool get isPickedUp => status == OrderStatus.pickedUp;
  bool get isDelivered => status == OrderStatus.delivered;
  bool get isCancelled => status == OrderStatus.cancelled;

  bool get isPaid => paymentStatus == PaymentStatus.paid;
  bool get isPaymentPending => paymentStatus == PaymentStatus.pending;
  bool get isPaymentFailed => paymentStatus == PaymentStatus.failed;

  bool get isActive =>
      isPending || isConfirmed || isPreparing || isReady || isPickedUp;
  bool get isCompleted => isDelivered;
  bool get isUpcoming => isPending || isConfirmed;

  String get statusDisplay {
    switch (status) {
      case OrderStatus.pending:
        return 'Pending';
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.ready:
        return 'Ready';
      case OrderStatus.pickedUp:
        return 'Picked Up';
      case OrderStatus.delivered:
        return 'Delivered';
      case OrderStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get statusColor {
    switch (status) {
      case OrderStatus.pending:
        return '#FFA500'; // Orange
      case OrderStatus.confirmed:
        return '#4CAF50'; // Green
      case OrderStatus.preparing:
        return '#2196F3'; // Blue
      case OrderStatus.ready:
        return '#9C27B0'; // Purple
      case OrderStatus.pickedUp:
        return '#FF9800'; // Deep Orange
      case OrderStatus.delivered:
        return '#4CAF50'; // Green
      case OrderStatus.cancelled:
        return '#F44336'; // Red
    }
  }

  String get paymentStatusDisplay {
    switch (paymentStatus) {
      case PaymentStatus.pending:
        return 'Pending';
      case PaymentStatus.paid:
        return 'Paid';
      case PaymentStatus.failed:
        return 'Failed';
      case PaymentStatus.refunded:
        return 'Refunded';
    }
  }

  String get deliveryAddressString {
    return deliveryAddress.fullAddress;
  }

  Order copyWith({
    String? id,
    String? restaurantId,
    String? customerId,
    String? deliveryPersonId,
    String? orderNumber,
    OrderStatus? status,
    PaymentStatus? paymentStatus,
    double? subtotal,
    double? deliveryFee,
    double? taxAmount,
    double? discountAmount,
    double? totalAmount,
    String? paymentMethod,
    DeliveryAddress? deliveryAddress,
    String? specialInstructions,
    DateTime? estimatedDeliveryTime,
    DateTime? actualDeliveryTime,
    String? appliedPromoCodeId,
    String? appliedPromoCode,
    DateTime? createdAt,
    DateTime? updatedAt,
    Restaurant? restaurant,
    app_user.User? customer,
    app_user.User? deliveryPerson,
    List<OrderItem>? orderItems,
  }) {
    return Order(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      customerId: customerId ?? this.customerId,
      deliveryPersonId: deliveryPersonId ?? this.deliveryPersonId,
      orderNumber: orderNumber ?? this.orderNumber,
      status: status ?? this.status,
      paymentStatus: paymentStatus ?? this.paymentStatus,
      subtotal: subtotal ?? this.subtotal,
      deliveryFee: deliveryFee ?? this.deliveryFee,
      taxAmount: taxAmount ?? this.taxAmount,
      serviceFee: serviceFee,
      discountAmount: discountAmount ?? this.discountAmount,
      totalAmount: totalAmount ?? this.totalAmount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      estimatedDeliveryTime:
          estimatedDeliveryTime ?? this.estimatedDeliveryTime,
      actualDeliveryTime: actualDeliveryTime ?? this.actualDeliveryTime,
      appliedPromoCodeId: appliedPromoCodeId ?? this.appliedPromoCodeId,
      appliedPromoCode: appliedPromoCode ?? this.appliedPromoCode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      restaurant: restaurant ?? this.restaurant,
      customer: customer ?? this.customer,
      deliveryPerson: deliveryPerson ?? this.deliveryPerson,
      orderItems: orderItems ?? this.orderItems,
      lastStatusUpdateTime: _lastStatusUpdateTime,
      statusUpdateCount: _statusUpdateCount,
      averageStatusUpdateTime: _averageStatusUpdateTime,
      isRealTimeEnabled: _isRealTimeEnabled,
      performanceMetrics: _performanceMetrics,
    );
  }

  @override
  String toString() {
    return 'Order(id: $id, orderNumber: $orderNumber, status: $status, totalAmount: $totalAmount)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Order && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  /// Update order status with performance tracking
  Order updateStatus(OrderStatus newStatus) {
    final performanceService = PerformanceMonitoringService();
    performanceService.startOperation('order_status_update');

    try {
      final now = DateTime.now();
      final updateTime = _lastStatusUpdateTime != null
          ? now.difference(_lastStatusUpdateTime).inMilliseconds.toDouble()
          : 0.0;

      final newUpdateCount = _statusUpdateCount + 1;
      final newAverageTime =
          (_averageStatusUpdateTime * _statusUpdateCount + updateTime) /
              newUpdateCount;

      final updatedOrder = Order(
        id: id,
        restaurantId: restaurantId,
        customerId: customerId,
        deliveryPersonId: deliveryPersonId,
        orderNumber: orderNumber,
        status: newStatus,
        paymentStatus: paymentStatus,
        subtotal: subtotal,
        deliveryFee: deliveryFee,
        taxAmount: taxAmount,
        serviceFee: serviceFee,
        discountAmount: discountAmount,
        totalAmount: totalAmount,
        paymentMethod: paymentMethod,
        deliveryAddress: deliveryAddress,
        specialInstructions: specialInstructions,
        estimatedDeliveryTime: estimatedDeliveryTime,
        actualDeliveryTime: actualDeliveryTime,
        appliedPromoCodeId: appliedPromoCodeId,
        appliedPromoCode: appliedPromoCode,
        createdAt: createdAt,
        updatedAt: now,
        restaurant: restaurant,
        customer: customer,
        deliveryPerson: deliveryPerson,
        orderItems: orderItems,
        lastStatusUpdateTime: now,
        statusUpdateCount: newUpdateCount,
        averageStatusUpdateTime: newAverageTime,
        isRealTimeEnabled: _isRealTimeEnabled,
        performanceMetrics: _performanceMetrics,
      );

      performanceService.endOperation('order_status_update');
      return updatedOrder;
    } catch (e) {
      performanceService.endOperation('order_status_update');
      rethrow;
    }
  }

  /// Check if real-time updates should be enabled based on network conditions
  bool shouldEnableRealTimeUpdates(String networkQuality) {
    // Disable real-time updates on very slow networks to save battery/data
    if (networkQuality == 'verySlow' || networkQuality == 'offline') {
      return false;
    }

    // Enable real-time updates for active orders
    return _isRealTimeEnabled &&
        (status == OrderStatus.pending ||
            status == OrderStatus.confirmed ||
            status == OrderStatus.preparing ||
            status == OrderStatus.ready);
  }

  /// Get adaptive update frequency based on order status and network
  Duration getAdaptiveUpdateFrequency(String networkQuality) {
    // Base frequency on order status
    Duration baseFrequency;
    switch (status) {
      case OrderStatus.pending:
        baseFrequency = const Duration(seconds: 30);
        break;
      case OrderStatus.confirmed:
      case OrderStatus.preparing:
        baseFrequency = const Duration(seconds: 15);
        break;
      case OrderStatus.ready:
      case OrderStatus.pickedUp:
        baseFrequency = const Duration(seconds: 10);
        break;
      case OrderStatus.cancelled:
      case OrderStatus.delivered:
        baseFrequency = const Duration(minutes: 5);
    }

    // Adjust based on network quality
    switch (networkQuality) {
      case 'fast':
        return baseFrequency;
      case 'moderate':
        return Duration(seconds: baseFrequency.inSeconds * 2);
      case 'slow':
        return Duration(seconds: baseFrequency.inSeconds * 3);
      case 'verySlow':
        return Duration(minutes: baseFrequency.inSeconds ~/ 60 * 2);
      case 'offline':
        return const Duration(minutes: 10);
      default:
        return baseFrequency;
    }
  }

  /// Get performance metrics for this order
  Map<String, dynamic> getPerformanceMetrics() {
    return {
      'status_update_count': _statusUpdateCount,
      'average_status_update_time': _averageStatusUpdateTime,
      'is_real_time_enabled': _isRealTimeEnabled,
      'last_status_update_time': _lastStatusUpdateTime?.toIso8601String(),
      'order_age_minutes': DateTime.now().difference(createdAt).inMinutes,
      'status_transitions': _statusUpdateCount,
    };
  }

  /// Check if order should be prioritized for real-time updates
  bool shouldPrioritizeRealTimeUpdates() {
    // Prioritize recent orders and active statuses
    final ageInMinutes = DateTime.now().difference(createdAt).inMinutes;
    return ageInMinutes < 60 && // Orders less than 1 hour old
        (status == OrderStatus.pending ||
            status == OrderStatus.confirmed ||
            status == OrderStatus.preparing);
  }
}
