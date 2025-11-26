enum DiscountType {
  percentage,
  fixedAmount,
  freeDelivery,
  buyOneGetOne,
}

enum DiscountStatus {
  active,
  inactive,
  expired,
  paused,
}

class Discount {
  final String id;
  final String restaurantId;
  final String name;
  final String description;
  final DiscountType type;
  final double value; // Percentage (0-100) or fixed amount
  final double minimumOrderAmount;
  final double maximumDiscountAmount;
  final DateTime startDate;
  final DateTime endDate;
  final DiscountStatus status;
  final int usageLimit;
  final int usedCount;
  final List<String> applicableCategories;
  final List<String> applicableMenuItems;
  final bool isPublic;
  final String? imageUrl;
  final Map<String, dynamic> conditions;
  final DateTime createdAt;
  final DateTime updatedAt;

  Discount({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.description,
    required this.type,
    required this.value,
    required this.minimumOrderAmount,
    required this.maximumDiscountAmount,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.usageLimit,
    required this.usedCount,
    required this.applicableCategories,
    required this.applicableMenuItems,
    required this.isPublic,
    required this.conditions,
    required this.createdAt,
    required this.updatedAt,
    this.imageUrl,
  });

  factory Discount.fromJson(Map<String, dynamic> json) {
    return Discount(
      id: json['id'] ?? '',
      restaurantId: json['restaurant_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      type: DiscountType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'],
        orElse: () => DiscountType.percentage,
      ),
      value: (json['value'] ?? 0.0).toDouble(),
      minimumOrderAmount: (json['minimum_order_amount'] ?? 0.0).toDouble(),
      maximumDiscountAmount:
          (json['maximum_discount_amount'] ?? 0.0).toDouble(),
      startDate: DateTime.parse(
          json['start_date'] ?? DateTime.now().toIso8601String()),
      endDate:
          DateTime.parse(json['end_date'] ?? DateTime.now().toIso8601String()),
      status: DiscountStatus.values.firstWhere(
        (e) => e.toString().split('.').last == json['status'],
        orElse: () => DiscountStatus.active,
      ),
      usageLimit: json['usage_limit'] ?? 0,
      usedCount: json['used_count'] ?? 0,
      applicableCategories:
          List<String>.from(json['applicable_categories'] ?? []),
      applicableMenuItems:
          List<String>.from(json['applicable_menu_items'] ?? []),
      isPublic: json['is_public'] ?? true,
      imageUrl: json['image_url'],
      conditions: Map<String, dynamic>.from(json['conditions'] ?? {}),
      createdAt: DateTime.parse(
          json['created_at'] ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(
          json['updated_at'] ?? DateTime.now().toIso8601String()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'restaurant_id': restaurantId,
      'name': name,
      'description': description,
      'type': type.toString().split('.').last,
      'value': value,
      'minimum_order_amount': minimumOrderAmount,
      'maximum_discount_amount': maximumDiscountAmount,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'status': status.toString().split('.').last,
      'usage_limit': usageLimit,
      'used_count': usedCount,
      'applicable_categories': applicableCategories,
      'applicable_menu_items': applicableMenuItems,
      'is_public': isPublic,
      'image_url': imageUrl,
      'conditions': conditions,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Discount copyWith({
    String? id,
    String? restaurantId,
    String? name,
    String? description,
    DiscountType? type,
    double? value,
    double? minimumOrderAmount,
    double? maximumDiscountAmount,
    DateTime? startDate,
    DateTime? endDate,
    DiscountStatus? status,
    int? usageLimit,
    int? usedCount,
    List<String>? applicableCategories,
    List<String>? applicableMenuItems,
    bool? isPublic,
    String? imageUrl,
    Map<String, dynamic>? conditions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Discount(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      name: name ?? this.name,
      description: description ?? this.description,
      type: type ?? this.type,
      value: value ?? this.value,
      minimumOrderAmount: minimumOrderAmount ?? this.minimumOrderAmount,
      maximumDiscountAmount:
          maximumDiscountAmount ?? this.maximumDiscountAmount,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      status: status ?? this.status,
      usageLimit: usageLimit ?? this.usageLimit,
      usedCount: usedCount ?? this.usedCount,
      applicableCategories: applicableCategories ?? this.applicableCategories,
      applicableMenuItems: applicableMenuItems ?? this.applicableMenuItems,
      isPublic: isPublic ?? this.isPublic,
      imageUrl: imageUrl ?? this.imageUrl,
      conditions: conditions ?? this.conditions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isActive {
    final now = DateTime.now();
    return status == DiscountStatus.active &&
        now.isAfter(startDate) &&
        now.isBefore(endDate) &&
        (usageLimit == 0 || usedCount < usageLimit);
  }

  bool get isExpired {
    return DateTime.now().isAfter(endDate) ||
        (usageLimit > 0 && usedCount >= usageLimit);
  }

  double calculateDiscount(double orderAmount) {
    if (!isActive || orderAmount < minimumOrderAmount) {
      return 0.0;
    }

    double discount = 0.0;

    switch (type) {
      case DiscountType.percentage:
        discount = orderAmount * (value / 100);
        break;
      case DiscountType.fixedAmount:
        discount = value;
        break;
      case DiscountType.freeDelivery:
        // This would be handled separately in delivery fee calculation
        discount = 0.0;
        break;
      case DiscountType.buyOneGetOne:
        // This would be handled in order item calculation
        discount = 0.0;
        break;
    }

    // Apply maximum discount limit
    if (maximumDiscountAmount > 0 && discount > maximumDiscountAmount) {
      discount = maximumDiscountAmount;
    }

    return discount;
  }
}
