class MenuItemVariant {
  final String id;
  final String menuItemId;
  final String name;
  final String? description;
  final bool isDefault;
  final int displayOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  MenuItemVariant({
    required this.id,
    required this.menuItemId,
    required this.name,
    required this.createdAt,
    required this.updatedAt,
    this.description,
    this.isDefault = false,
    this.displayOrder = 0,
  });

  factory MenuItemVariant.fromJson(Map<String, dynamic> json) {
    return MenuItemVariant(
      id: json['id'] ?? '',
      menuItemId: json['menu_item_id'] ?? '',
      name: json['name'] ?? '',
      description: json['description'],
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
      'menu_item_id': menuItemId,
      'name': name,
      'description': description,
      'is_default': isDefault,
      'display_order': displayOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  MenuItemVariant copyWith({
    String? id,
    String? menuItemId,
    String? name,
    String? description,
    bool? isDefault,
    int? displayOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MenuItemVariant(
      id: id ?? this.id,
      menuItemId: menuItemId ?? this.menuItemId,
      name: name ?? this.name,
      description: description ?? this.description,
      isDefault: isDefault ?? this.isDefault,
      displayOrder: displayOrder ?? this.displayOrder,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'MenuItemVariant(id: $id, name: $name, isDefault: $isDefault)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MenuItemVariant && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
