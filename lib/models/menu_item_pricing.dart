class MenuItemPricing {
  final String id;
  final String menuItemId;
  final String? variantId; // Link to specific variant (null means base pricing)
  final String size; // Small, Medium, Large, etc.
  final String portion; // 1 serving, 2-3 people, etc.
  final double price;
  final bool isDefault;
  final int displayOrder;
  final bool freeDrinksIncluded; // For special packs/combos
  final List<String> freeDrinksList; // List of drink menu item IDs included
  final int freeDrinksQuantity; // Max number of free drinks allowed

  // Limited Time Offer fields
  final bool isLimitedOffer;
  final List<String>
      offerTypes; // ['special_price', 'free_drinks', 'special_delivery']
  final DateTime? offerStartAt;
  final DateTime? offerEndAt;
  final double? originalPrice;
  final Map<String, dynamic> offerDetails;

  final DateTime createdAt;
  final DateTime updatedAt;

  MenuItemPricing({
    required this.id,
    required this.menuItemId,
    required this.size,
    required this.portion,
    required this.price,
    required this.createdAt,
    required this.updatedAt,
    this.variantId, // Optional - links to variant
    this.isDefault = false,
    this.displayOrder = 0,
    this.freeDrinksIncluded = false,
    this.freeDrinksList = const [],
    this.freeDrinksQuantity = 1,
    this.isLimitedOffer = false,
    this.offerTypes = const [],
    this.offerStartAt,
    this.offerEndAt,
    this.originalPrice,
    this.offerDetails = const {},
  });

  factory MenuItemPricing.fromJson(Map<String, dynamic> json) {
    return MenuItemPricing(
      id: json['id'] ?? '',
      menuItemId: json['menu_item_id'] ?? '',
      variantId: json['variant_id'],
      size: json['size'] ?? '',
      portion: json['portion'] ?? '',
      price: (json['price'] ?? 0.0).toDouble(),
      isDefault: json['is_default'] ?? false,
      displayOrder: json['display_order'] ?? 0,
      freeDrinksIncluded: json['free_drinks_included'] ?? false,
      freeDrinksList: json['free_drinks_list'] != null
          ? List<String>.from(json['free_drinks_list'] as List)
          : [],
      freeDrinksQuantity: json['free_drinks_quantity'] ?? 1,
      isLimitedOffer: json['is_limited_offer'] ?? false,
      offerTypes: json['offer_types'] != null
          ? List<String>.from(json['offer_types'] as List)
          : [],
      offerStartAt: json['offer_start_at'] != null
          ? DateTime.parse(json['offer_start_at'])
          : null,
      offerEndAt: json['offer_end_at'] != null
          ? DateTime.parse(json['offer_end_at'])
          : null,
      originalPrice: json['original_price'] != null
          ? (json['original_price'] as num).toDouble()
          : null,
      offerDetails: json['offer_details'] != null
          ? Map<String, dynamic>.from(json['offer_details'])
          : {},
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'menu_item_id': menuItemId,
      'variant_id': variantId,
      'size': size,
      'portion': portion,
      'price': price,
      'is_default': isDefault,
      'display_order': displayOrder,
      'free_drinks_included': freeDrinksIncluded,
      'free_drinks_list': freeDrinksList,
      'free_drinks_quantity': freeDrinksQuantity,
      'is_limited_offer': isLimitedOffer,
      'offer_types': offerTypes,
      'offer_start_at': offerStartAt?.toIso8601String(),
      'offer_end_at': offerEndAt?.toIso8601String(),
      'original_price': originalPrice,
      'offer_details': offerDetails,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  MenuItemPricing copyWith({
    String? id,
    String? menuItemId,
    String? variantId,
    String? size,
    String? portion,
    double? price,
    bool? isDefault,
    int? displayOrder,
    bool? freeDrinksIncluded,
    List<String>? freeDrinksList,
    int? freeDrinksQuantity,
    bool? isLimitedOffer,
    List<String>? offerTypes,
    DateTime? offerStartAt,
    DateTime? offerEndAt,
    double? originalPrice,
    Map<String, dynamic>? offerDetails,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MenuItemPricing(
      id: id ?? this.id,
      menuItemId: menuItemId ?? this.menuItemId,
      variantId: variantId ?? this.variantId,
      size: size ?? this.size,
      portion: portion ?? this.portion,
      price: price ?? this.price,
      isDefault: isDefault ?? this.isDefault,
      displayOrder: displayOrder ?? this.displayOrder,
      freeDrinksIncluded: freeDrinksIncluded ?? this.freeDrinksIncluded,
      freeDrinksList: freeDrinksList ?? this.freeDrinksList,
      freeDrinksQuantity: freeDrinksQuantity ?? this.freeDrinksQuantity,
      isLimitedOffer: isLimitedOffer ?? this.isLimitedOffer,
      offerTypes: offerTypes ?? this.offerTypes,
      offerStartAt: offerStartAt ?? this.offerStartAt,
      offerEndAt: offerEndAt ?? this.offerEndAt,
      originalPrice: originalPrice ?? this.originalPrice,
      offerDetails: offerDetails ?? this.offerDetails,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'MenuItemPricing(id: $id, size: $size, portion: $portion, price: $price)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MenuItemPricing && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
