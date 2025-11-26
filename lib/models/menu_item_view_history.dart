import 'package:equatable/equatable.dart';

class MenuItemViewHistory extends Equatable {
  final String id;
  final String userId;
  final String menuItemId;
  final String restaurantId;
  final String menuItemName;
  final String menuItemImage;
  final double menuItemPrice;
  final String restaurantName;
  final DateTime viewedAt;
  final Map<String, dynamic>? metadata;

  const MenuItemViewHistory({
    required this.id,
    required this.userId,
    required this.menuItemId,
    required this.restaurantId,
    required this.menuItemName,
    required this.menuItemImage,
    required this.menuItemPrice,
    required this.restaurantName,
    required this.viewedAt,
    this.metadata,
  });

  factory MenuItemViewHistory.fromJson(Map<String, dynamic> json) {
    return MenuItemViewHistory(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      menuItemId: json['menu_item_id'] as String,
      restaurantId: json['restaurant_id'] as String,
      menuItemName: json['menu_item_name'] as String,
      menuItemImage: json['menu_item_image'] as String,
      menuItemPrice: (json['menu_item_price'] as num).toDouble(),
      restaurantName: json['restaurant_name'] as String,
      viewedAt: DateTime.parse(json['viewed_at'] as String),
      metadata: json['metadata'] != null
          ? Map<String, dynamic>.from(json['metadata'])
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'menu_item_id': menuItemId,
      'restaurant_id': restaurantId,
      'menu_item_name': menuItemName,
      'menu_item_image': menuItemImage,
      'menu_item_price': menuItemPrice,
      'restaurant_name': restaurantName,
      'viewed_at': viewedAt.toIso8601String(),
      'metadata': metadata,
    };
  }

  MenuItemViewHistory copyWith({
    String? id,
    String? userId,
    String? menuItemId,
    String? restaurantId,
    String? menuItemName,
    String? menuItemImage,
    double? menuItemPrice,
    String? restaurantName,
    DateTime? viewedAt,
    Map<String, dynamic>? metadata,
  }) {
    return MenuItemViewHistory(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      menuItemId: menuItemId ?? this.menuItemId,
      restaurantId: restaurantId ?? this.restaurantId,
      menuItemName: menuItemName ?? this.menuItemName,
      menuItemImage: menuItemImage ?? this.menuItemImage,
      menuItemPrice: menuItemPrice ?? this.menuItemPrice,
      restaurantName: restaurantName ?? this.restaurantName,
      viewedAt: viewedAt ?? this.viewedAt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => [
        id,
        userId,
        menuItemId,
        restaurantId,
        menuItemName,
        menuItemImage,
        menuItemPrice,
        restaurantName,
        viewedAt,
        metadata,
      ];

  @override
  String toString() {
    return 'MenuItemViewHistory(id: $id, menuItemName: $menuItemName, restaurantName: $restaurantName, viewedAt: $viewedAt)';
  }
}
