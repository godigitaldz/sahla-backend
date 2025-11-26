import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../cart_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/menu_item.dart';
import '../../../models/order_item.dart';
import '../../../models/restaurant.dart';
import '../../../services/menu_item_display_service.dart';
import '../../../widgets/cart_screen/floating_cart_icon.dart';
import '../menu_item_popup_factory.dart';

class PopupHelper {
  /// Extract original item ID from variant ID
  /// Variant IDs format: "original_id_variant_0_Small"
  static String _getOriginalItemId(String itemId) {
    if (itemId.contains('_variant_')) {
      // Extract the part before "_variant_"
      final parts = itemId.split('_variant_');
      return parts.first;
    }
    return itemId;
  }

  /// Check if the item ID is a variant ID
  static bool _isVariantItem(String itemId) {
    return itemId.contains('_variant_');
  }

  /// Extract variant name from the menu item ID
  /// Variant IDs format: "original_id_variant_0_Small" or "original_id_variant_0_Large_Size"
  static String? _extractVariantName(String itemId) {
    if (itemId.contains('_variant_')) {
      final parts = itemId.split('_variant_');
      if (parts.length >= 2) {
        // Get the part after "_variant_0_" (the variant name with underscores)
        final variantPart = parts[1];
        // Split by underscore and skip the index (first part)
        final variantNameParts = variantPart.split('_');
        if (variantNameParts.length >= 2) {
          // Join everything after the index, replacing underscores with spaces
          return variantNameParts.sublist(1).join(' ');
        }
      }
    }
    return null;
  }

  /// Show the full-width rounded menu item popup
  static Future<void> showMenuItemPopup({
    required BuildContext context,
    required MenuItem menuItem,
    Restaurant? restaurant,
    Function(OrderItem)? onItemAddedToCart,
    VoidCallback? onDataChanged,
  }) async {
    debugPrint(
        '🍽️ PopupHelper.showMenuItemPopup() called for: ${menuItem.name}');

    // Check if this is a variant item
    MenuItem itemToShow = menuItem;
    String? preSelectedVariantName;

    if (_isVariantItem(menuItem.id)) {
      debugPrint('🔍 Detected variant item, fetching original item...');
      final originalItemId = _getOriginalItemId(menuItem.id);
      debugPrint('🔍 Original item ID: $originalItemId');

      // Extract the variant name from the menu item ID
      preSelectedVariantName = _extractVariantName(menuItem.id);
      debugPrint('🎯 Extracted variant name: $preSelectedVariantName');

      // Fetch the original item with all variants
      final menuItemService = MenuItemDisplayService();
      final originalItem =
          await menuItemService.getMenuItemById(originalItemId);

      if (originalItem != null) {
        debugPrint(
            '✅ Original item fetched successfully with ${originalItem.variants.length} variants');
        itemToShow = originalItem;
      } else {
        debugPrint(
            '⚠️ Could not fetch original item, using variant item as fallback');
        preSelectedVariantName =
            null; // Clear variant name if we couldn't fetch original
      }
    }

    if (!context.mounted) return;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          MenuItemPopupFactory(
            menuItem: itemToShow,
            restaurant: restaurant,
            preSelectedVariantName: preSelectedVariantName,
            onItemAddedToCart: onItemAddedToCart ??
                (OrderItem orderItem) {
                  // Default cart integration using CartProvider
                  final cartProvider =
                      Provider.of<CartProvider>(context, listen: false);
                  // Guard against zero price coming from any upstream path
                  final safeUnitPrice = orderItem.unitPrice > 0
                      ? orderItem.unitPrice
                      : ((orderItem.menuItem?.price ?? 0) > 0
                          ? (orderItem.menuItem?.price ?? 0)
                          : 350.0);
                  final cartItem = CartItem(
                    id: orderItem.id,
                    name: orderItem.menuItem?.name ?? 'Unknown Item',
                    price: safeUnitPrice,
                    quantity: orderItem.quantity,
                    image: orderItem.menuItem?.image,
                    restaurantName: orderItem.menuItem?.restaurantName,
                    customizations: orderItem.customizations?.toMap(),
                    specialInstructions: orderItem.specialInstructions,
                  );
                  cartProvider.addToCart(cartItem);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '${orderItem.menuItem?.name ?? AppLocalizations.of(context)!.item} ${AppLocalizations.of(context)!.addedToCart}'),
                      duration: const Duration(seconds: 2),
                      backgroundColor: Colors.green[600],
                    ),
                  );
                },
            onDataChanged: onDataChanged,
          ),
          // Cart icon overlapping the popup - positioned just above fixed bottom container
          // Fixed bottom container is ~120px high, cart icon is 65px, so position at 125px
          const PositionedDirectional(
            end: 8.0,
            bottom:
                100.0, // Just above fixed bottom container (120px) + small gap (5px)
            child: FloatingCartIcon(),
          ),
        ],
      ),
    );
  }

  /// Show popup with enhanced menu item data
  static Future<void> showEnhancedMenuItemPopup({
    required BuildContext context,
    required MenuItem menuItem,
    Restaurant? restaurant,
    Function(OrderItem)? onItemAddedToCart,
    VoidCallback? onDataChanged,
  }) async {
    debugPrint(
        '🍽️ PopupHelper.showEnhancedMenuItemPopup() called for: ${menuItem.name}');

    // Check if this is a variant item
    MenuItem itemToShow = menuItem;
    String? preSelectedVariantName;

    if (_isVariantItem(menuItem.id)) {
      debugPrint('🔍 Detected variant item, fetching original item...');
      final originalItemId = _getOriginalItemId(menuItem.id);
      debugPrint('🔍 Original item ID: $originalItemId');

      // Extract the variant name from the menu item ID
      preSelectedVariantName = _extractVariantName(menuItem.id);
      debugPrint('🎯 Extracted variant name: $preSelectedVariantName');

      // Fetch the original item with all variants
      final menuItemService = MenuItemDisplayService();
      final originalItem =
          await menuItemService.getMenuItemById(originalItemId);

      if (originalItem != null) {
        debugPrint(
            '✅ Original item fetched successfully with ${originalItem.variants.length} variants');
        itemToShow = originalItem;
      } else {
        debugPrint(
            '⚠️ Could not fetch original item, using variant item as fallback');
        preSelectedVariantName =
            null; // Clear variant name if we couldn't fetch original
      }
    }

    if (!context.mounted) return;
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          MenuItemPopupFactory(
            menuItem: itemToShow,
            restaurant: restaurant,
            preSelectedVariantName: preSelectedVariantName,
            onItemAddedToCart: onItemAddedToCart ??
                (OrderItem orderItem) {
                  // Default cart integration using CartProvider
                  final cartProvider =
                      Provider.of<CartProvider>(context, listen: false);
                  final cartItem = CartItem(
                    id: orderItem.id,
                    name: orderItem.menuItem?.name ??
                        AppLocalizations.of(context)!.unknownItem,
                    price: orderItem.unitPrice,
                    quantity: orderItem.quantity,
                    image: orderItem.menuItem?.image,
                    restaurantName: orderItem.menuItem?.restaurantName,
                    customizations: orderItem.customizations?.toMap(),
                    specialInstructions: orderItem.specialInstructions,
                  );
                  cartProvider.addToCart(cartItem);

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '${orderItem.menuItem?.name ?? AppLocalizations.of(context)!.item} ${AppLocalizations.of(context)!.addedToCart}'),
                      duration: const Duration(seconds: 2),
                      backgroundColor: Colors.green[600],
                    ),
                  );
                },
            onDataChanged: onDataChanged,
          ),
          // Cart icon overlapping the popup - positioned just above fixed bottom container
          // Fixed bottom container is ~120px high, cart icon is 65px, so position at 125px
          const PositionedDirectional(
            end: 8.0,
            bottom:
                125.0, // Just above fixed bottom container (120px) + small gap (5px)
            child: FloatingCartIcon(),
          ),
        ],
      ),
    );
  }
}
