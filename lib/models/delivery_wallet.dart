import 'delivery_personnel.dart';

class DeliveryWallet {
  final String id;
  final String deliveryPersonId;
  final double currentBalance;
  final double totalEarned;
  final double totalWithdrawn;
  final double totalServiceFeesPaid;
  final double creditBalance;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DeliveryPersonnel? deliveryPerson;

  DeliveryWallet({
    required this.id,
    required this.deliveryPersonId,
    required this.currentBalance,
    required this.totalEarned,
    required this.totalWithdrawn,
    required this.totalServiceFeesPaid,
    required this.creditBalance,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
    this.deliveryPerson,
  });

  factory DeliveryWallet.fromJson(Map<String, dynamic> json) {
    return DeliveryWallet(
      id: json['id'] ?? '',
      deliveryPersonId: json['delivery_person_id'] ?? '',
      currentBalance: (json['current_balance'] ?? 0.0).toDouble(),
      totalEarned: (json['total_earned'] ?? 0.0).toDouble(),
      totalWithdrawn: (json['total_withdrawn'] ?? 0.0).toDouble(),
      totalServiceFeesPaid: (json['total_service_fees_paid'] ?? 0.0).toDouble(),
      creditBalance: (json['credit_balance'] ?? 0.0).toDouble(),
      isActive: json['is_active'] ?? true,
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
      'current_balance': currentBalance,
      'total_earned': totalEarned,
      'total_withdrawn': totalWithdrawn,
      'total_service_fees_paid': totalServiceFeesPaid,
      'credit_balance': creditBalance,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'delivery_personnel': deliveryPerson?.toJson(),
    };
  }

  /// Get available balance (current balance + credit balance)
  double get availableBalance => currentBalance + creditBalance;

  /// Check if there's sufficient credit for service fee payment
  bool hasSufficientCredit(double amount) => creditBalance >= amount;

  /// Get formatted current balance
  String get formattedCurrentBalance =>
      '${currentBalance.toStringAsFixed(2)} DA';

  /// Get formatted credit balance
  String get formattedCreditBalance => '${creditBalance.toStringAsFixed(2)} DA';

  /// Get formatted total earned
  String get formattedTotalEarned => '${totalEarned.toStringAsFixed(2)} DA';

  /// Get formatted total service fees paid
  String get formattedTotalServiceFeesPaid =>
      '${totalServiceFeesPaid.toStringAsFixed(2)} DA';
}
