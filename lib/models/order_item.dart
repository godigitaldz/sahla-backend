import 'menu_item.dart';
import 'menu_item_customizations.dart';

class OrderItem {
  final String id;
  final String orderId;
  final String menuItemId;
  final int quantity;
  final double unitPrice;
  final double totalPrice;
  final String? specialInstructions;
  final MenuItemCustomizations? customizations;
  final DateTime createdAt;
  final MenuItem? menuItem;

  OrderItem({
    required this.id,
    required this.orderId,
    required this.menuItemId,
    required this.quantity,
    required this.unitPrice,
    required this.totalPrice,
    required this.createdAt,
    this.specialInstructions,
    this.customizations,
    this.menuItem,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    return OrderItem(
      id: json['id'] ?? '',
      orderId: json['order_id'] ?? '',
      menuItemId: json['menu_item_id'] ?? '',
      quantity: json['quantity'] ?? 1,
      unitPrice: (json['unit_price'] ?? 0.0).toDouble(),
      totalPrice: (json['total_price'] ?? 0.0).toDouble(),
      specialInstructions: json['special_instructions'],
      customizations: json['customizations'] != null
          ? MenuItemCustomizations.fromJson(json['customizations'])
          : null,
      createdAt: DateTime.parse(json['created_at']),
      menuItem: (json['menu_items'] ?? json['menu_item']) != null
          ? MenuItem.fromJson(json['menu_items'] ?? json['menu_item'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_id': orderId,
      'menu_item_id': menuItemId,
      'quantity': quantity,
      'unit_price': unitPrice,
      'total_price': totalPrice,
      'special_instructions': specialInstructions,
      'customizations': customizations?.toJson(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  OrderItem copyWith({
    String? id,
    String? orderId,
    String? menuItemId,
    int? quantity,
    double? unitPrice,
    double? totalPrice,
    String? specialInstructions,
    MenuItemCustomizations? customizations,
    DateTime? createdAt,
    MenuItem? menuItem,
  }) {
    return OrderItem(
      id: id ?? this.id,
      orderId: orderId ?? this.orderId,
      menuItemId: menuItemId ?? this.menuItemId,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      totalPrice: totalPrice ?? this.totalPrice,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      customizations: customizations ?? this.customizations,
      createdAt: createdAt ?? this.createdAt,
      menuItem: menuItem ?? this.menuItem,
    );
  }

  @override
  String toString() {
    return 'OrderItem(id: $id, menuItemId: $menuItemId, quantity: $quantity, totalPrice: $totalPrice)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is OrderItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
