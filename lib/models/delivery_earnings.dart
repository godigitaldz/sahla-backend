import 'delivery_personnel.dart';
import 'order.dart';

enum EarningsType {
  baseFee,
  distanceFee,
  performanceBonus,
  tip,
  penalty,
}

class DeliveryEarnings {
  final String id;
  final String deliveryPersonId;
  final String orderId;
  final double baseFee;
  final double distanceFee;
  final double performanceBonus;
  final double tip;
  final double penalty;
  final double totalEarnings;
  final EarningsType type;
  final String? description;
  final DateTime createdAt;
  final DeliveryPersonnel? deliveryPerson;
  final Order? order;

  DeliveryEarnings({
    required this.id,
    required this.deliveryPersonId,
    required this.orderId,
    required this.baseFee,
    required this.distanceFee,
    required this.performanceBonus,
    required this.tip,
    required this.penalty,
    required this.totalEarnings,
    required this.type,
    required this.createdAt,
    this.description,
    this.deliveryPerson,
    this.order,
  });

  factory DeliveryEarnings.fromJson(Map<String, dynamic> json) {
    return DeliveryEarnings(
      id: json['id'] ?? '',
      deliveryPersonId: json['delivery_person_id'] ?? '',
      orderId: json['order_id'] ?? '',
      baseFee: (json['base_fee'] ?? 0.0).toDouble(),
      distanceFee: (json['distance_fee'] ?? 0.0).toDouble(),
      performanceBonus: (json['performance_bonus'] ?? 0.0).toDouble(),
      tip: (json['tip'] ?? 0.0).toDouble(),
      penalty: (json['penalty'] ?? 0.0).toDouble(),
      totalEarnings: (json['total_earnings'] ?? 0.0).toDouble(),
      type: _parseEarningsType(json['type']),
      description: json['description'],
      createdAt: DateTime.parse(json['created_at']),
      deliveryPerson: json['delivery_personnel'] != null
          ? DeliveryPersonnel.fromJson(json['delivery_personnel'])
          : null,
      order: json['orders'] != null ? Order.fromJson(json['orders']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'delivery_person_id': deliveryPersonId,
      'order_id': orderId,
      'base_fee': baseFee,
      'distance_fee': distanceFee,
      'performance_bonus': performanceBonus,
      'tip': tip,
      'penalty': penalty,
      'total_earnings': totalEarnings,
      'type': type.name,
      'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }

  static EarningsType _parseEarningsType(String? type) {
    switch (type) {
      case 'base_fee':
        return EarningsType.baseFee;
      case 'distance_fee':
        return EarningsType.distanceFee;
      case 'performance_bonus':
        return EarningsType.performanceBonus;
      case 'tip':
        return EarningsType.tip;
      case 'penalty':
        return EarningsType.penalty;
      default:
        return EarningsType.baseFee;
    }
  }

  String get typeDisplay {
    switch (type) {
      case EarningsType.baseFee:
        return 'Base Fee';
      case EarningsType.distanceFee:
        return 'Distance Fee';
      case EarningsType.performanceBonus:
        return 'Performance Bonus';
      case EarningsType.tip:
        return 'Tip';
      case EarningsType.penalty:
        return 'Penalty';
    }
  }

  String get typeColor {
    switch (type) {
      case EarningsType.baseFee:
        return '#d47b00'; // Orange
      case EarningsType.distanceFee:
        return '#2196F3'; // Blue
      case EarningsType.performanceBonus:
        return '#4CAF50'; // Green
      case EarningsType.tip:
        return '#FF9800'; // Orange
      case EarningsType.penalty:
        return '#F44336'; // Red
    }
  }

  bool get isPositive => totalEarnings >= 0;
  bool get isNegative => totalEarnings < 0;

  DeliveryEarnings copyWith({
    String? id,
    String? deliveryPersonId,
    String? orderId,
    double? baseFee,
    double? distanceFee,
    double? performanceBonus,
    double? tip,
    double? penalty,
    double? totalEarnings,
    EarningsType? type,
    String? description,
    DateTime? createdAt,
    DeliveryPersonnel? deliveryPerson,
    Order? order,
  }) {
    return DeliveryEarnings(
      id: id ?? this.id,
      deliveryPersonId: deliveryPersonId ?? this.deliveryPersonId,
      orderId: orderId ?? this.orderId,
      baseFee: baseFee ?? this.baseFee,
      distanceFee: distanceFee ?? this.distanceFee,
      performanceBonus: performanceBonus ?? this.performanceBonus,
      tip: tip ?? this.tip,
      penalty: penalty ?? this.penalty,
      totalEarnings: totalEarnings ?? this.totalEarnings,
      type: type ?? this.type,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      deliveryPerson: deliveryPerson ?? this.deliveryPerson,
      order: order ?? this.order,
    );
  }

  @override
  String toString() {
    return 'DeliveryEarnings(id: $id, deliveryPersonId: $deliveryPersonId, totalEarnings: $totalEarnings)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeliveryEarnings && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
