enum PromoCodeType {
  percentage,
  fixedAmount,
  freeDelivery,
  buyOneGetOne,
}

enum PromoCodeStatus {
  active,
  inactive,
  expired,
  paused,
}

class PromoCode {
  final String id;
  final String code;
  final String? restaurantId; // Nullable as per schema
  final String name;
  final String? description;
  final PromoCodeType type;
  final double value; // Percentage (0-100) or fixed amount
  final double minimumOrderAmount;
  final double? maximumDiscountAmount; // Nullable as per schema
  final DateTime startDate;
  final DateTime endDate;
  final PromoCodeStatus status;
  final int? usageLimit; // Nullable as per schema
  final int? usedCount; // Nullable as per schema
  final int? userUsageLimit; // Nullable, defaults to 1 as per schema
  final List<String> applicableCategories;
  final List<String> applicableMenuItems; // Now UUID strings
  final bool? isPublic; // Nullable, defaults to true as per schema
  final String? imageUrl;
  final Map<String, dynamic>? conditions; // Nullable as per schema
  final DateTime createdAt;
  final DateTime updatedAt;

  PromoCode({
    required this.id,
    required this.code,
    required this.name,
    required this.type,
    required this.value,
    required this.minimumOrderAmount,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.applicableCategories,
    required this.applicableMenuItems,
    required this.createdAt,
    required this.updatedAt,
    this.restaurantId,
    this.description,
    this.maximumDiscountAmount,
    this.usageLimit,
    this.usedCount,
    this.userUsageLimit,
    this.isPublic,
    this.imageUrl,
    this.conditions,
  });

  factory PromoCode.fromJson(Map<String, dynamic> json) {
    // Performance: Parse enum types once using optimized helper
    final typeStr = json['type'] as String?;
    final type = _parsePromoCodeType(typeStr);

    final statusStr = json['status'] as String?;
    final status = _parsePromoCodeStatus(statusStr);

    return PromoCode(
      id: json['id'] ?? '',
      code: json['code'] ?? '',
      restaurantId: json['restaurant_id'],
      name: json['name'] ?? '',
      description: json['description'],
      type: type,
      value: (json['value'] ?? 0.0).toDouble(),
      minimumOrderAmount: (json['minimum_order_amount'] ?? 0.0).toDouble(),
      maximumDiscountAmount: json['maximum_discount_amount']?.toDouble(),
      // Performance: Safe DateTime parsing with fallback
      startDate: _parseDateTimeSafe(json['start_date']) ?? DateTime.now(),
      endDate: _parseDateTimeSafe(json['end_date']) ?? DateTime.now(),
      status: status,
      usageLimit: json['usage_limit'],
      usedCount: json['used_count'],
      userUsageLimit: json['user_usage_limit'] ?? 1,
      // Performance: Use const empty lists when possible
      applicableCategories: json['applicable_categories'] != null
          ? List<String>.from(json['applicable_categories'])
          : const [],
      applicableMenuItems: json['applicable_menu_items'] != null
          ? List<String>.from(json['applicable_menu_items'])
          : const [],
      isPublic: json['is_public'] ?? true,
      imageUrl: json['image_url'],
      conditions: json['conditions'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(json['conditions'])
          : null,
      createdAt: _parseDateTimeSafe(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDateTimeSafe(json['updated_at']) ?? DateTime.now(),
    );
  }

  /// Performance: Safe DateTime parsing helper (avoids exceptions)
  static DateTime? _parseDateTimeSafe(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value.toString());
    } catch (e) {
      return null;
    }
  }

  /// Performance: Optimized enum parsing without string splitting
  static PromoCodeType _parsePromoCodeType(String? typeStr) {
    if (typeStr == null) return PromoCodeType.percentage;

    switch (typeStr.toLowerCase()) {
      case 'percentage':
        return PromoCodeType.percentage;
      case 'fixedamount':
      case 'fixed_amount':
        return PromoCodeType.fixedAmount;
      case 'freedelivery':
      case 'free_delivery':
        return PromoCodeType.freeDelivery;
      case 'buyonegetone':
      case 'buy_one_get_one':
        return PromoCodeType.buyOneGetOne;
      default:
        return PromoCodeType.percentage;
    }
  }

  /// Performance: Optimized enum parsing without string splitting
  static PromoCodeStatus _parsePromoCodeStatus(String? statusStr) {
    if (statusStr == null) return PromoCodeStatus.active;

    switch (statusStr.toLowerCase()) {
      case 'active':
        return PromoCodeStatus.active;
      case 'inactive':
        return PromoCodeStatus.inactive;
      case 'expired':
        return PromoCodeStatus.expired;
      case 'paused':
        return PromoCodeStatus.paused;
      default:
        return PromoCodeStatus.active;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
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
      'user_usage_limit': userUsageLimit,
      'applicable_categories': applicableCategories,
      'applicable_menu_items': applicableMenuItems,
      'is_public': isPublic,
      'image_url': imageUrl,
      'conditions': conditions,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  PromoCode copyWith({
    String? id,
    String? code,
    String? restaurantId,
    String? name,
    String? description,
    PromoCodeType? type,
    double? value,
    double? minimumOrderAmount,
    double? maximumDiscountAmount,
    DateTime? startDate,
    DateTime? endDate,
    PromoCodeStatus? status,
    int? usageLimit,
    int? usedCount,
    int? userUsageLimit,
    List<String>? applicableCategories,
    List<String>? applicableMenuItems,
    bool? isPublic,
    String? imageUrl,
    Map<String, dynamic>? conditions,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PromoCode(
      id: id ?? this.id,
      code: code ?? this.code,
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
      userUsageLimit: userUsageLimit ?? this.userUsageLimit,
      applicableCategories: applicableCategories ?? this.applicableCategories,
      applicableMenuItems: applicableMenuItems ?? this.applicableMenuItems,
      isPublic: isPublic ?? this.isPublic,
      imageUrl: imageUrl ?? this.imageUrl,
      conditions: conditions ?? this.conditions,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  /// Performance: Cache for isActive checks to avoid repeated DateTime.now() calls
  static final Map<String, _PromoCodeActiveCache> _activeCache = {};

  bool get isActive {
    // Performance: Check cache first (5-second TTL)
    final cached = _activeCache[id];
    if (cached != null &&
        DateTime.now().difference(cached.timestamp).inSeconds < 5) {
      return cached.isActive;
    }

    // Compute isActive
    final now = DateTime.now();
    final result = status == PromoCodeStatus.active &&
        now.isAfter(startDate) &&
        now.isBefore(endDate) &&
        (usageLimit == null ||
            usageLimit == 0 ||
            usedCount == null ||
            (usageLimit != null &&
                usedCount != null &&
                usedCount! < usageLimit!));

    // Cache the result
    _activeCache[id] = _PromoCodeActiveCache(isActive: result, timestamp: now);

    return result;
  }

  bool get isExpired {
    // Performance: Use cached DateTime.now() if available
    final cached = _activeCache[id];
    final now = (cached != null &&
            DateTime.now().difference(cached.timestamp).inSeconds < 5)
        ? cached.timestamp
        : DateTime.now();

    return now.isAfter(endDate) ||
        (usageLimit != null &&
            usageLimit! > 0 &&
            usedCount != null &&
            usedCount! >= usageLimit!);
  }

  /// Performance: Clear active cache for specific promo code or all
  static void clearActiveCache([String? promoCodeId]) {
    if (promoCodeId != null) {
      _activeCache.remove(promoCodeId);
    } else {
      _activeCache.clear();
    }
  }

  double calculateDiscount(double orderAmount) {
    if (!isActive || orderAmount < minimumOrderAmount) {
      return 0.0;
    }

    double discount = 0.0;

    switch (type) {
      case PromoCodeType.percentage:
        discount = orderAmount * (value / 100);
        break;
      case PromoCodeType.fixedAmount:
        discount = value;
        break;
      case PromoCodeType.freeDelivery:
        // Free delivery is handled separately in delivery fee calculation
        // Return 0 here as the discount is applied to delivery fee, not order total
        discount = 0.0;
        break;
      case PromoCodeType.buyOneGetOne:
        // BOGO is handled in order item calculation
        // Return 0 here as the discount is applied to specific items
        discount = 0.0;
        break;
    }

    // Apply maximum discount limit and ensure discount doesn't exceed order amount
    if (maximumDiscountAmount != null && maximumDiscountAmount! > 0) {
      discount =
          discount > maximumDiscountAmount! ? maximumDiscountAmount! : discount;
    }

    // Ensure discount never exceeds the order amount
    discount = discount > orderAmount ? orderAmount : discount;

    // Ensure discount is never negative
    discount = discount < 0 ? 0 : discount;

    return discount;
  }
}

/// Performance: Internal cache entry for promo code active status memoization
class _PromoCodeActiveCache {
  final bool isActive;
  final DateTime timestamp;

  _PromoCodeActiveCache({required this.isActive, required this.timestamp});
}
