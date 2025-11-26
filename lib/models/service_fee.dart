import 'delivery_personnel.dart';
import 'order.dart';
import 'task.dart';

enum ServiceFeePaymentStatus {
  pending,
  paid,
  failed,
  refunded,
}

enum ServiceFeePaymentMethod {
  credit,
  cash,
  bankTransfer,
}

class ServiceFee {
  final String id;
  final String deliveryPersonId;
  final String? orderId;
  final String? taskId;
  final double grossEarnings;
  final double serviceFeeRate;
  final double serviceFeeAmount;
  final double netEarnings;
  final ServiceFeePaymentStatus paymentStatus;
  final ServiceFeePaymentMethod? paymentMethod;
  final String? paymentReference;
  final DateTime? paidAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DeliveryPersonnel? deliveryPerson;
  final Order? order;
  final Task? task;

  ServiceFee({
    required this.id,
    required this.deliveryPersonId,
    required this.grossEarnings,
    required this.serviceFeeRate,
    required this.serviceFeeAmount,
    required this.netEarnings,
    required this.paymentStatus,
    required this.createdAt,
    required this.updatedAt,
    this.orderId,
    this.taskId,
    this.paymentMethod,
    this.paymentReference,
    this.paidAt,
    this.deliveryPerson,
    this.order,
    this.task,
  });

  factory ServiceFee.fromJson(Map<String, dynamic> json) {
    return ServiceFee(
      id: json['id'] ?? '',
      deliveryPersonId: json['delivery_person_id'] ?? '',
      orderId: json['order_id'],
      taskId: json['task_id'],
      grossEarnings: (json['gross_earnings'] ?? 0.0).toDouble(),
      serviceFeeRate: (json['service_fee_rate'] ?? 0.15).toDouble(),
      serviceFeeAmount: (json['service_fee_amount'] ?? 0.0).toDouble(),
      netEarnings: (json['net_earnings'] ?? 0.0).toDouble(),
      paymentStatus: _parsePaymentStatus(json['payment_status']),
      paymentMethod: json['payment_method'] != null
          ? _parsePaymentMethod(json['payment_method'])
          : null,
      paymentReference: json['payment_reference'],
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at']) : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      deliveryPerson: json['delivery_personnel'] != null
          ? DeliveryPersonnel.fromJson(json['delivery_personnel'])
          : null,
      order: json['orders'] != null ? Order.fromJson(json['orders']) : null,
      task: json['tasks'] != null ? Task.fromMap(json['tasks']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'delivery_person_id': deliveryPersonId,
      'order_id': orderId,
      'task_id': taskId,
      'gross_earnings': grossEarnings,
      'service_fee_rate': serviceFeeRate,
      'service_fee_amount': serviceFeeAmount,
      'net_earnings': netEarnings,
      'payment_status': paymentStatus.name,
      'payment_method': paymentMethod?.name,
      'payment_reference': paymentReference,
      'paid_at': paidAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'delivery_personnel': deliveryPerson?.toJson(),
      'orders': order?.toJson(),
      'tasks': task?.toInsertMap(),
    };
  }

  static ServiceFeePaymentStatus _parsePaymentStatus(String? status) {
    switch (status) {
      case 'paid':
        return ServiceFeePaymentStatus.paid;
      case 'failed':
        return ServiceFeePaymentStatus.failed;
      case 'refunded':
        return ServiceFeePaymentStatus.refunded;
      default:
        return ServiceFeePaymentStatus.pending;
    }
  }

  static ServiceFeePaymentMethod _parsePaymentMethod(String method) {
    switch (method) {
      case 'cash':
        return ServiceFeePaymentMethod.cash;
      case 'bank_transfer':
        return ServiceFeePaymentMethod.bankTransfer;
      default:
        return ServiceFeePaymentMethod.credit;
    }
  }

  /// Check if service fee is paid
  bool get isPaid => paymentStatus == ServiceFeePaymentStatus.paid;

  /// Check if service fee is pending
  bool get isPending => paymentStatus == ServiceFeePaymentStatus.pending;

  /// Get formatted gross earnings
  String get formattedGrossEarnings => '${grossEarnings.toStringAsFixed(2)} DA';

  /// Get formatted service fee amount
  String get formattedServiceFeeAmount =>
      '${serviceFeeAmount.toStringAsFixed(2)} DA';

  /// Get formatted net earnings
  String get formattedNetEarnings => '${netEarnings.toStringAsFixed(2)} DA';

  /// Get service fee percentage
  String get serviceFeePercentage =>
      '${(serviceFeeRate * 100).toStringAsFixed(1)}%';

  /// Get payment status display text
  String get paymentStatusText {
    switch (paymentStatus) {
      case ServiceFeePaymentStatus.paid:
        return 'Paid';
      case ServiceFeePaymentStatus.failed:
        return 'Failed';
      case ServiceFeePaymentStatus.refunded:
        return 'Refunded';
      case ServiceFeePaymentStatus.pending:
        return 'Pending';
    }
  }

  /// Get payment method display text
  String get paymentMethodText {
    if (paymentMethod == null) return 'Not specified';
    switch (paymentMethod!) {
      case ServiceFeePaymentMethod.credit:
        return 'Credit';
      case ServiceFeePaymentMethod.cash:
        return 'Cash';
      case ServiceFeePaymentMethod.bankTransfer:
        return 'Bank Transfer';
    }
  }
}
