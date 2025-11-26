class SupplementVariant {
  final String id;
  final String supplementId;
  final String name;
  final String? description;
  final double price;
  final bool isDefault;
  final int displayOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  SupplementVariant({
    required this.id,
    required this.supplementId,
    required this.name,
    required this.price,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.isDefault = false,
    this.displayOrder = 0,
  });

  factory SupplementVariant.fromJson(Map<String, dynamic> json) {
    return SupplementVariant(
      id: json['id'] ?? '',
      supplementId: json['supplement_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
      price: (json['price'] ?? 0.0).toDouble(),
      isDefault: json['is_default'] ?? false,
      displayOrder: json['display_order'] ?? 0,
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
      'supplement_id': supplementId,
      'name': name,
      'description': description,
      'price': price,
      'is_default': isDefault,
      'display_order': displayOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  SupplementVariant copyWith({
    String? id,
    String? supplementId,
    String? name,
    String? description,
    double? price,
    bool? isDefault,
    int? displayOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return SupplementVariant(
      id: id ?? this.id,
      supplementId: supplementId ?? this.supplementId,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      isDefault: isDefault ?? this.isDefault,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'SupplementVariant(id: $id, name: $name, price: $price)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SupplementVariant && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
