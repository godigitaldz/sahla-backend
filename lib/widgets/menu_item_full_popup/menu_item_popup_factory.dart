import 'package:flutter/material.dart';

import '../../cart_provider.dart';
import '../../models/menu_item.dart';
import '../../models/order_item.dart';
import '../../models/restaurant.dart';
import '../../screens/menu_item_popup_widget.dart';

/// Factory widget that returns the unified MenuItemPopupWidget
/// The unified widget handles all item types: special packs, LTO regular items, and regular items
/// Routing logic is now handled internally by MenuItemPopupWidget using PopupTypeHelper
class MenuItemPopupFactory extends StatefulWidget {
  final MenuItem menuItem;
  final Restaurant? restaurant;
  final Function(OrderItem)? onItemAddedToCart;
  final CartItem? existingCartItem;
  final String? originalOrderItemId;
  final VoidCallback? onDataChanged;
  final String? preSelectedVariantName;

  const MenuItemPopupFactory({
    required this.menuItem,
    super.key,
    this.restaurant,
    this.onItemAddedToCart,
    this.existingCartItem,
    this.originalOrderItemId,
    this.onDataChanged,
    this.preSelectedVariantName,
  });

  @override
  State<MenuItemPopupFactory> createState() => _MenuItemPopupFactoryState();
}

class _MenuItemPopupFactoryState extends State<MenuItemPopupFactory> {
  @override
  Widget build(BuildContext context) {
    // Always return the unified MenuItemPopupWidget
    // It handles routing internally based on item type
    return MenuItemPopupWidget(
      menuItem: widget.menuItem,
      restaurant: widget.restaurant,
      onItemAddedToCart: widget.onItemAddedToCart,
      existingCartItem: widget.existingCartItem,
      originalOrderItemId: widget.originalOrderItemId,
      onDataChanged: widget.onDataChanged,
      preSelectedVariantName: widget.preSelectedVariantName,
    );
  }
}
