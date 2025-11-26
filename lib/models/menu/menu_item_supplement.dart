import '../supplement_variant.dart';

class MenuItemSupplement {
  final String id;
  final String menuItemId;
  final String name;
  final String? description;
  final double price;
  final bool isAvailable;
  final int displayOrder;
  final List<String>
      availableForVariants; // New field for variant-specific availability
  final List<SupplementVariant> variants; // Supplement's own variants
  final DateTime createdAt;
  final DateTime updatedAt;

  MenuItemSupplement({
    required this.id,
    required this.menuItemId,
    required this.name,
    required this.price,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.isAvailable = true,
    this.displayOrder = 0,
    this.availableForVariants =
        const [], // Empty list means available for all variants
    this.variants = const [], // Empty list means no variants
  });

  factory MenuItemSupplement.fromJson(Map<String, dynamic> json) {
    return MenuItemSupplement(
      id: json['id'] ?? '',
      menuItemId: json['menu_item_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      price: (json['price'] ?? 0.0).toDouble(),
      isAvailable: json['is_available'] ?? true,
      displayOrder: json['display_order'] ?? 0,
      availableForVariants: json['available_for_variants'] != null
          ? List<String>.from(json['available_for_variants'])
          : [],
      variants: json['variants'] != null
          ? (json['variants'] as List<dynamic>)
              .map((v) => SupplementVariant.fromJson(v as Map<String, dynamic>))
              .toList()
          : [],
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
      'name': name,
      'description': description,
      'price': price,
      'is_available': isAvailable,
      'display_order': displayOrder,
      // available_for_variants and variants fields excluded - not in DB schema
      // These are client-side only for tracking supplement variant relationships
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  MenuItemSupplement copyWith({
    String? id,
    String? menuItemId,
    String? name,
    String? description,
    double? price,
    bool? isAvailable,
    int? displayOrder,
    List<String>? availableForVariants,
    List<SupplementVariant>? variants,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MenuItemSupplement(
      id: id ?? this.id,
      menuItemId: menuItemId ?? this.menuItemId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      isAvailable: isAvailable ?? this.isAvailable,
      displayOrder: displayOrder ?? this.displayOrder,
      availableForVariants: availableForVariants ?? this.availableForVariants,
      variants: variants ?? this.variants,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'MenuItemSupplement(id: $id, name: $name, price: $price)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MenuItemSupplement && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
