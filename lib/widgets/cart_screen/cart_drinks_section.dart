import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../cart_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/menu_item.dart';
import '../../services/menu_item_popup_service.dart';
import '../../utils/price_formatter.dart';
import '../../widgets/menu_item_full_popup/special_pack_widgets/methods/build_drink_image.dart';
import '../menu_item_full_popup/shared_widgets/drink_quantity_selector.dart';

final _menuItemPopupService = MenuItemPopupService();

/// Drinks section widget for cart screen
/// Displays paid drinks from cart items wrapped in a white container
class CartDrinksSection extends StatefulWidget {
  const CartDrinksSection({super.key});

  @override
  State<CartDrinksSection> createState() => _CartDrinksSectionState();
}

class _CartDrinksSectionState extends State<CartDrinksSection> {
  List<MenuItem> _restaurantDrinks = [];
  bool _isLoadingDrinks = false;
  final Map<String, String> _drinkImageCache = {};

  @override
  void initState() {
    super.initState();
    _loadRestaurantDrinks();
  }

  Future<void> _loadRestaurantDrinks() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    if (cartProvider.isEmpty) return;

    // Get restaurant ID from first cart item customizations
    final firstItem = cartProvider.items.first;
    final restaurantId = firstItem.customizations?['restaurant_id']?.toString() ?? '';

    if (restaurantId.isEmpty) return;

    setState(() {
      _isLoadingDrinks = true;
    });

    try {
      final drinks = await _menuItemPopupService.loadRestaurantDrinksOptimized(
        restaurantId,
      );
      setState(() {
        _restaurantDrinks = drinks;
        _isLoadingDrinks = false;
      });
    } catch (e) {
      debugPrint('Error loading drinks: $e');
      setState(() {
        _isLoadingDrinks = false;
      });
    }
  }

  Map<String, int> _getPaidDrinkQuantities() {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);
    // ✅ FIX: Get paid drinks from separate store (not from order cards)
    // This avoids conflicts in calculations between cart drinks section and order cards
    return cartProvider.paidDrinkQuantities;
  }

  String? _getDrinkSize(MenuItem drink) {
    // Get drink size from pricing options
    if (drink.pricingOptions.isNotEmpty) {
      final firstPricing = drink.pricingOptions.first;
      return firstPricing['size']?.toString();
    }
    return null;
  }

  void _updatePaidDrinkQuantity(String drinkId, int quantity) {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    // ✅ FIX: Update paid drinks in separate store (not in order cards)
    // This avoids conflicts in calculations between cart drinks section and order cards
    final drink = _restaurantDrinks.firstWhere(
      (d) => d.id == drinkId,
      orElse: () => MenuItem(
        id: drinkId,
        restaurantId: '',
        name: '',
        description: '',
        image: '',
        price: 0,
        category: '',
        isAvailable: true,
        isFeatured: false,
        preparationTime: 0,
        rating: 0.0,
        reviewCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );

    // Update paid drinks in separate store (not in cart items)
    cartProvider.updatePaidDrinkQuantity(drinkId, quantity, drink.price);
  }

  @override
  Widget build(BuildContext context) {
    final cartProvider = Provider.of<CartProvider>(context);

    if (cartProvider.isEmpty) {
      return const SizedBox.shrink();
    }

    final paidDrinkQuantities = _getPaidDrinkQuantities();

    // Show all restaurant drinks (users can select any drink)
    final drinksToShow = _restaurantDrinks;

    if (_isLoadingDrinks) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[300]!),
        ),
        child: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (drinksToShow.isEmpty) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.drinksByRestaurant,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 132,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              itemCount: drinksToShow.length,
              itemExtent: 118,
              cacheExtent: 236,
              itemBuilder: (context, index) {
                final drink = drinksToShow[index];
                final quantity = paidDrinkQuantities[drink.id] ?? 0;
                final drinkSize = _getDrinkSize(drink);

                return RepaintBoundary(
                  child: Container(
                    width: 108,
                    height: 132,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: Colors.grey[300]!,
                        width: 0.5,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          // Background Image
                          buildDrinkImage(
                            drink: drink,
                            drinkImageCache: _drinkImageCache,
                            onCacheUpdate: (drinkId) {
                              _drinkImageCache.remove(drinkId);
                            },
                            supabase: Supabase.instance.client,
                          ),

                          // Gradient overlay
                          Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withValues(alpha: 0.1),
                                  Colors.black.withValues(alpha: 0.6),
                                ],
                              ),
                            ),
                          ),

                          // Content overlay
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Top row: Price and Size
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Price chip
                                    Builder(
                                      builder: (context) {
                                        final priceText =
                                            PriceFormatter.formatWithSettings(
                                          context,
                                          drink.price.toString(),
                                        );
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.orange[600],
                                            borderRadius:
                                                BorderRadius.circular(8),
                                          ),
                                          child: Text(
                                            '+ $priceText',
                                            style: GoogleFonts.poppins(
                                              fontSize: 8,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                            ),
                                          ),
                                        );
                                      },
                                    ),

                                    // Size chip
                                    if (drinkSize != null)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white
                                              .withValues(alpha: 0.9),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          drinkSize,
                                          style: GoogleFonts.poppins(
                                            fontSize: 8,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black87,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),

                                // Quantity Selector
                                DrinkQuantitySelector(
                                  quantity: quantity,
                                  onQuantityChanged: (newQuantity) {
                                    _updatePaidDrinkQuantity(
                                        drink.id, newQuantity);
                                  },
                                  canDecrease: quantity > 0,
                                  canIncrease: quantity < 10,
                                  fontSize: 9,
                                  iconSize: 18,
                                  textColor: const Color(0xFF1A1A1A),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
