import 'delivery_personnel.dart';

enum CreditTransactionType {
  deposit,
  withdrawal,
  serviceFeePayment,
  refund,
}

enum CreditTransactionStatus {
  pending,
  completed,
  failed,
  cancelled,
}

class CreditTransaction {
  final String id;
  final String deliveryPersonId;
  final CreditTransactionType transactionType;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final String? paymentMethod;
  final String? paymentReference;
  final Map<String, dynamic>? bankDetails;
  final String? description;
  final CreditTransactionStatus status;
  final DateTime? processedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DeliveryPersonnel? deliveryPerson;

  CreditTransaction({
    required this.id,
    required this.deliveryPersonId,
    required this.transactionType,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.paymentMethod,
    this.paymentReference,
    this.bankDetails,
    this.description,
    this.processedAt,
    this.deliveryPerson,
  });

  factory CreditTransaction.fromJson(Map<String, dynamic> json) {
    return CreditTransaction(
      id: json['id'] ?? '',
      deliveryPersonId: json['delivery_person_id'] ?? '',
      transactionType: _parseTransactionType(json['transaction_type']),
      amount: (json['amount'] ?? 0.0).toDouble(),
      balanceBefore: (json['balance_before'] ?? 0.0).toDouble(),
      balanceAfter: (json['balance_after'] ?? 0.0).toDouble(),
      paymentMethod: json['payment_method'],
      paymentReference: json['payment_reference'],
      bankDetails: json['bank_details'] != null
          ? Map<String, dynamic>.from(json['bank_details'])
          : null,
      description: json['description'],
      status: _parseStatus(json['status']),
      processedAt: json['processed_at'] != null
          ? DateTime.parse(json['processed_at'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      deliveryPerson: json['delivery_personnel'] != null
          ? DeliveryPersonnel.fromJson(json['delivery_personnel'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'delivery_person_id': deliveryPersonId,
      'transaction_type': transactionType.name,
      'amount': amount,
      'balance_before': balanceBefore,
      'balance_after': balanceAfter,
      'payment_method': paymentMethod,
      'payment_reference': paymentReference,
      'bank_details': bankDetails,
      'description': description,
      'status': status.name,
      'processed_at': processedAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'delivery_personnel': deliveryPerson?.toJson(),
    };
  }

  static CreditTransactionType _parseTransactionType(String? type) {
    switch (type) {
      case 'withdrawal':
        return CreditTransactionType.withdrawal;
      case 'service_fee_payment':
        return CreditTransactionType.serviceFeePayment;
      case 'refund':
        return CreditTransactionType.refund;
      default:
        return CreditTransactionType.deposit;
    }
  }

  static CreditTransactionStatus _parseStatus(String? status) {
    switch (status) {
      case 'completed':
        return CreditTransactionStatus.completed;
      case 'failed':
        return CreditTransactionStatus.failed;
      case 'cancelled':
        return CreditTransactionStatus.cancelled;
      default:
        return CreditTransactionStatus.pending;
    }
  }

  /// Check if transaction is completed
  bool get isCompleted => status == CreditTransactionStatus.completed;

  /// Check if transaction is pending
  bool get isPending => status == CreditTransactionStatus.pending;

  /// Check if transaction is a deposit
  bool get isDeposit => transactionType == CreditTransactionType.deposit;

  /// Check if transaction is a withdrawal
  bool get isWithdrawal => transactionType == CreditTransactionType.withdrawal;

  /// Check if transaction is a service fee payment
  bool get isServiceFeePayment =>
      transactionType == CreditTransactionType.serviceFeePayment;

  /// Get formatted amount with sign
  String get formattedAmount {
    final sign = amount >= 0 ? '+' : '';
    return '$sign${amount.toStringAsFixed(2)} DA';
  }

  /// Get formatted balance before
  String get formattedBalanceBefore => '${balanceBefore.toStringAsFixed(2)} DA';

  /// Get formatted balance after
  String get formattedBalanceAfter => '${balanceAfter.toStringAsFixed(2)} DA';

  /// Get transaction type display text
  String get transactionTypeText {
    switch (transactionType) {
      case CreditTransactionType.deposit:
        return 'Credit Deposit';
      case CreditTransactionType.withdrawal:
        return 'Withdrawal';
      case CreditTransactionType.serviceFeePayment:
        return 'Service Fee Payment';
      case CreditTransactionType.refund:
        return 'Refund';
    }
  }

  /// Get status display text
  String get statusText {
    switch (status) {
      case CreditTransactionStatus.completed:
        return 'Completed';
      case CreditTransactionStatus.failed:
        return 'Failed';
      case CreditTransactionStatus.cancelled:
        return 'Cancelled';
      case CreditTransactionStatus.pending:
        return 'Pending';
    }
  }

  /// Get status color for UI
  String get statusColor {
    switch (status) {
      case CreditTransactionStatus.completed:
        return 'green';
      case CreditTransactionStatus.failed:
        return 'red';
      case CreditTransactionStatus.cancelled:
        return 'orange';
      case CreditTransactionStatus.pending:
        return 'blue';
    }
  }

  /// Get transaction icon
  String get transactionIcon {
    switch (transactionType) {
      case CreditTransactionType.deposit:
        return 'arrow_downward';
      case CreditTransactionType.withdrawal:
        return 'arrow_upward';
      case CreditTransactionType.serviceFeePayment:
        return 'payment';
      case CreditTransactionType.refund:
        return 'undo';
    }
  }
}
