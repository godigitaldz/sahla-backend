import '../../../../../cart_provider.dart';
import '../../../../../models/menu_item.dart';
import '../../../../../models/order_item.dart';
import '../../../../../models/restaurant.dart';

/// Add saved orders to cart
/// Returns true if drinks were added, false otherwise
bool addSavedOrdersToCart({
  required List<OrderItem> savedOrders,
  required CartProvider cartProvider,
  required MenuItem menuItem,
  required Restaurant? restaurant,
  required List<MenuItem> restaurantDrinks,
  required Map<String, String> drinkSizesById,
}) {
  if (savedOrders.isEmpty) {
    return false;
  }

  bool drinksAdded = false;

  for (final saved in savedOrders) {
    final savedQty = saved.quantity > 0 ? saved.quantity : 1;
    final savedUnitPrice = saved.totalPrice / savedQty;
    final savedRestaurantIdRaw =
        (saved.customizations?['restaurant_id']?.toString() ?? '').trim();
    final fallbackRestaurantIdRaw = (menuItem.restaurantId.isNotEmpty
            ? menuItem.restaurantId
            : (restaurant?.id.toString() ?? ''))
        .trim();
    final restaurantIdToUse = savedRestaurantIdRaw.isNotEmpty
        ? savedRestaurantIdRaw
        : fallbackRestaurantIdRaw;

    // Preserve drink quantities from saved customizations
    // For LTO and regular items: multiply free drinks by saved order quantity
    final Map<String, int> savedDrinkQuantities = {};
    final dq = saved.customizations?['drink_quantities'];
    final freeDq = saved.customizations?['free_drink_quantities'];
    final paidDq = saved.customizations?['paid_drink_quantities'];

    final isSpecialPack = saved.customizations?['is_special_pack'] == true;
    // For LTO and regular items (non-special pack): multiply free drinks by quantity
    // Special packs handle quantity per item separately

    if (!isSpecialPack && savedQty > 1) {
      // For LTO/regular items: multiply free drinks by quantity
      if (freeDq is Map) {
        freeDq.forEach((k, v) {
          final key = k.toString();
          final val = v is int ? v : int.tryParse(v.toString()) ?? 0;
          if (val > 0) {
            savedDrinkQuantities[key] = val * savedQty;
          }
        });
      } else if (dq is Map) {
        // Fallback: if free_drink_quantities not available, assume all drinks are free
        dq.forEach((k, v) {
          final key = k.toString();
          final val = v is int ? v : int.tryParse(v.toString()) ?? 0;
          if (val > 0) savedDrinkQuantities[key] = val * savedQty;
        });
      }

      // Add paid drinks (not multiplied - paid drinks are global)
      if (paidDq is Map) {
        paidDq.forEach((k, v) {
          final key = k.toString();
          final val = v is int ? v : int.tryParse(v.toString()) ?? 0;
          if (val > 0) {
            savedDrinkQuantities[key] = (savedDrinkQuantities[key] ?? 0) + val;
          }
        });
      }
    } else {
      // Special packs or quantity = 1: use as-is
      if (dq is Map) {
        dq.forEach((k, v) {
          final key = k.toString();
          final val = v is int ? v : int.tryParse(v.toString()) ?? 0;
          if (val > 0) savedDrinkQuantities[key] = val;
        });
      }
    }

    final drinksListFromSaved = savedDrinkQuantities.keys.map((id) {
      final match = restaurantDrinks.where((d) => d.id == id);
      final name = match.isNotEmpty ? (match.first.name) : id;
      final size = drinkSizesById[id];
      final map = {
        'id': id,
        'name': name,
      };
      if (size != null && size.isNotEmpty) map['size'] = size;
      return map;
    }).toList();

    final cartItemSaved = CartItem(
      id: saved.id,
      name: saved.menuItem?.name ?? menuItem.name,
      price: savedUnitPrice,
      quantity: savedQty,
      image: saved.menuItem?.image ?? menuItem.image,
      restaurantName: saved.menuItem?.restaurantName ?? menuItem.restaurantName,
      customizations: {
        ...?saved.customizations?.toMap(),
        'restaurant_id': restaurantIdToUse,
        // Provide drinks list so OrderDetailsSummary can resolve names
        if (drinksListFromSaved.isNotEmpty) 'drinks': drinksListFromSaved,
      },
      drinkQuantities: savedDrinkQuantities,
      specialInstructions: saved.specialInstructions,
    );

    cartProvider.addToCart(cartItemSaved);

    if (savedDrinkQuantities.isNotEmpty) {
      drinksAdded = true;
    }
  }

  return drinksAdded;
}
