import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/menu_item.dart';
import '../../../utils/price_formatter.dart';
import '../shared_widgets/drink_quantity_selector.dart';

/// Paid drinks section widget for special pack popup
class SpecialPackPaidDrinks extends StatelessWidget {
  final List<MenuItem> restaurantDrinks;
  final Map<String, int> paidDrinkQuantities;
  final Function(String drinkId, int quantity) onQuantityChanged;
  final Widget Function(MenuItem drink) buildDrinkImage;
  final String? Function(MenuItem drink) getDrinkSize;

  const SpecialPackPaidDrinks({
    required this.restaurantDrinks,
    required this.paidDrinkQuantities,
    required this.onQuantityChanged,
    required this.buildDrinkImage,
    required this.getDrinkSize,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (restaurantDrinks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.drinksByRestaurant,
          style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF1A1A1A), // textPrimary
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 132,
          // PERFORMANCE FIX: Horizontal scrolling works within CustomScrollView
          // Use ClampingScrollPhysics for smooth scrolling
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics:
                const ClampingScrollPhysics(), // Smooth horizontal scrolling
            itemCount: restaurantDrinks.length,
            itemExtent: 118, // Fixed width: 108 + 10 margin
            cacheExtent: 236, // Cache 2 items ahead
            itemBuilder: (context, index) {
              final drink = restaurantDrinks[index];
              final quantity = paidDrinkQuantities[drink.id] ?? 0;
              final drinkSize = getDrinkSize(drink);

              // PERFORMANCE FIX: Price formatting moved inside RepaintBoundary
              // Format only when needed (inside the widget tree) to avoid unnecessary rebuilds

              // PERFORMANCE FIX: Wrap in RepaintBoundary to isolate repaints
              // Removed box shadows to reduce repaint cost during scrolling
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
                        // Background Image - fills entire card
                        buildDrinkImage(drink),

                        // Gradient overlay for better text visibility
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
                              // Top row: Price (left) and Size (right)
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Price chip in top left
                                  // PERFORMANCE FIX: Format price inside Builder to access context
                                  // This ensures formatting only happens when widget is built
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

                                  // Size chip in top right (from pricing_options)
                                  if (drinkSize != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 3,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            Colors.white.withValues(alpha: 0.9),
                                        borderRadius: BorderRadius.circular(8),
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

                              // Quantity Selector at bottom
                              DrinkQuantitySelector(
                                quantity: quantity,
                                onQuantityChanged: (newQuantity) {
                                  onQuantityChanged(drink.id, newQuantity);
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
        const SizedBox(height: 8),
      ],
    );
  }
}
