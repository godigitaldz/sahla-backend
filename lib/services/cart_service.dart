import 'package:flutter/foundation.dart';

import '../cart_provider.dart';
import '../models/menu_item.dart';
import 'api_client.dart';

class CartService {
  static final CartService _instance = CartService._internal();
  factory CartService() => _instance;
  CartService._internal();

  /// Add a menu item to cart with customizations
  void addMenuItemToCart({
    required CartProvider cartProvider,
    required MenuItem menuItem,
    required String restaurantId,
    int quantity = 1,
    Map<String, dynamic> customizations = const {},
    String? specialInstructions,
  }) {
    try {
      // Calculate total price including supplements
      final double supplementsPrice =
          _calculateSupplementsPrice(customizations);
      final double unitPrice = menuItem.price + supplementsPrice;

      final cartItem = CartItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: menuItem.name,
        price: unitPrice,
        quantity: quantity,
        image: menuItem.image,
        restaurantName: menuItem.restaurantName,
        customizations: customizations,
        specialInstructions: specialInstructions,
      );

      cartProvider.addToCart(cartItem);

      debugPrint('🛒 CartService: Added ${menuItem.name} to cart');
    } catch (e) {
      debugPrint('❌ CartService: Error adding item to cart: $e');
      rethrow;
    }
  }

  /// Add multiple items to cart (for bulk operations)
  void addMultipleItemsToCart({
    required CartProvider cartProvider,
    required List<MenuItem> menuItems,
    required String restaurantId,
    Map<String, int> quantities = const {},
    Map<String, Map<String, dynamic>> customizations = const {},
  }) {
    try {
      for (final menuItem in menuItems) {
        final quantity = quantities[menuItem.id] ?? 1;
        final itemCustomizations = customizations[menuItem.id] ?? {};

        addMenuItemToCart(
          cartProvider: cartProvider,
          menuItem: menuItem,
          restaurantId: restaurantId,
          quantity: quantity,
          customizations: itemCustomizations,
        );
      }

      debugPrint('🛒 CartService: Added ${menuItems.length} items to cart');
    } catch (e) {
      debugPrint('❌ CartService: Error adding multiple items to cart: $e');
      rethrow;
    }
  }

  /// Update item quantity in cart
  void updateItemQuantity({
    required CartProvider cartProvider,
    required String orderItemId,
    required int newQuantity,
  }) {
    try {
      cartProvider.updateQuantity(orderItemId, newQuantity);
      debugPrint('🛒 CartService: Updated item quantity to $newQuantity');
    } catch (e) {
      debugPrint('❌ CartService: Error updating item quantity: $e');
      rethrow;
    }
  }

  /// Remove item from cart
  void removeItemFromCart({
    required CartProvider cartProvider,
    required String orderItemId,
  }) {
    try {
      cartProvider.removeFromCart(orderItemId);
      debugPrint('🛒 CartService: Removed item from cart');
    } catch (e) {
      debugPrint('❌ CartService: Error removing item from cart: $e');
      rethrow;
    }
  }

  /// Clear entire cart
  void clearCart({
    required CartProvider cartProvider,
  }) {
    try {
      cartProvider.clearCart();
      debugPrint('🛒 CartService: Cleared cart');
    } catch (e) {
      debugPrint('❌ CartService: Error clearing cart: $e');
      rethrow;
    }
  }

  /// Get cart summary information
  Map<String, dynamic> getCartSummary(CartProvider cartProvider) {
    return {
      'itemCount': cartProvider.itemCount,
      'totalPrice': cartProvider.totalPrice,
      'isEmpty': cartProvider.isEmpty,
      'isNotEmpty': cartProvider.isNotEmpty,
    };
  }

  /// Check if cart can accept items from a specific restaurant
  bool canAddToCart({
    required CartProvider cartProvider,
    required String restaurantId,
  }) {
    // Check if cart is empty or all items are from the same restaurant
    if (cartProvider.isEmpty) return true;

    // Check if all items are from the same restaurant
    final firstRestaurantName = cartProvider.items.first.restaurantName;
    return firstRestaurantName == null ||
        cartProvider.items
            .every((item) => item.restaurantName == firstRestaurantName);
  }

  /// Get item quantity for a specific menu item
  int getItemQuantity({
    required CartProvider cartProvider,
    required String menuItemId,
  }) {
    // Find items with matching menu item ID in customizations
    int totalQuantity = 0;
    for (final item in cartProvider.items) {
      if (item.customizations != null &&
          item.customizations!['menu_item_id'] == menuItemId) {
        totalQuantity += item.quantity;
      }
    }
    return totalQuantity;
  }

  /// Calculate supplements price from customizations
  double _calculateSupplementsPrice(Map<String, dynamic> customizations) {
    double supplementsPrice = 0.0;

    if (customizations.containsKey('supplements')) {
      final supplements = customizations['supplements'] as List?;
      if (supplements != null) {
        for (final supplement in supplements) {
          if (supplement is Map && supplement.containsKey('price')) {
            supplementsPrice += (supplement['price'] as num).toDouble();
          }
        }
      }
    }

    return supplementsPrice;
  }

  /// Calculate cart totals using Node.js backend business logic
  Future<Map<String, dynamic>> calculateCartTotals({
    required List<CartItem> cartItems,
    required String restaurantId,
    required String userId,
    String? promoCode,
  }) async {
    try {
      // Convert cart items to API format
      final cartItemsData = cartItems
          .map((item) => {
                'menuItemId':
                    item.id, // Assuming CartItem has menuItemId or similar
                'quantity': item.quantity,
                'selectedVariants': item.customizations?['variants'] ?? [],
                'selectedSupplements':
                    item.customizations?['supplements'] ?? [],
              })
          .toList();

      final response =
          await ApiClient.post('/api/business/cart/calculate', data: {
        'cartItems': cartItemsData,
        'restaurantId': restaurantId,
        'userId': userId,
        'promoCode': promoCode,
      });

      if (!response['success']) {
        throw Exception(
            'Failed to calculate cart totals: ${response['error']}');
      }

      return response['data'];
    } catch (e) {
      debugPrint('❌ CartService: Error calculating cart totals: $e');
      throw Exception('Failed to calculate cart totals: $e');
    }
  }

  /// Validate cart before checkout using Node.js backend
  Future<Map<String, dynamic>> validateCart({
    required List<CartItem> cartItems,
    required String restaurantId,
  }) async {
    try {
      // Convert cart items to API format
      final cartItemsData = cartItems
          .map((item) => {
                'menuItemId': item.id,
                'quantity': item.quantity,
                'selectedVariants': item.customizations?['variants'] ?? [],
                'selectedSupplements':
                    item.customizations?['supplements'] ?? [],
              })
          .toList();

      final response =
          await ApiClient.post('/api/business/cart/validate', data: {
        'cartItems': cartItemsData,
        'restaurantId': restaurantId,
      });

      if (!response['success']) {
        throw Exception('Cart validation failed: ${response['error']}');
      }

      return response['data'];
    } catch (e) {
      debugPrint('❌ CartService: Error validating cart: $e');
      throw Exception('Failed to validate cart: $e');
    }
  }

  /// Get optimized delivery assignment using Node.js backend
  Future<Map<String, dynamic>> getDeliveryAssignment({
    required String orderId,
    required Map<String, dynamic> deliveryAddress,
  }) async {
    try {
      final response =
          await ApiClient.post('/api/business/delivery/assign', data: {
        'orderId': orderId,
        'deliveryAddress': deliveryAddress,
      });

      if (!response['success']) {
        throw Exception(
            'Failed to get delivery assignment: ${response['error']}');
      }

      return response['data'];
    } catch (e) {
      debugPrint('❌ CartService: Error getting delivery assignment: $e');
      throw Exception('Failed to get delivery assignment: $e');
    }
  }
}
