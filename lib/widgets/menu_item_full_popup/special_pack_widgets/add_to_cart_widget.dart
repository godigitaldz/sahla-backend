import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../cart_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/menu_item.dart';
import '../../../utils/price_formatter.dart';
import '../shared_widgets/drink_quantity_selector.dart';

/// Unified add to cart widget for special pack popup
/// Combines: quantity selector, save & add another, saved orders, free drinks, and confirm/add to cart
class SpecialPackAddToCartWidget extends StatelessWidget {
  // Quantity selector
  final int quantity;
  final VoidCallback? onDecrease;
  final VoidCallback onIncrease;

  // Save & Add Another
  final bool canSaveAndAddAnother;
  final VoidCallback onSaveAndAddAnother;

  // Saved orders
  final List<Map<String, dynamic>> savedOrdersList;
  final Function(String variantId, int orderIndex) onRemoveSavedOrder;

  // Free drinks
  final List<MenuItem> freeDrinks;
  final int maxFreeDrinksQuantity;
  final Map<String, int> freeDrinkQuantities;
  final Function(String drinkId, int quantity) onFreeDrinkQuantityChanged;
  final Widget Function(MenuItem drink) buildDrinkImage;
  final Function(MenuItem drink) onFreeDrinkSelected;
  final Function(String drinkId) onFreeDrinkDeselected;

  // Paid drinks
  final Widget? paidDrinksSection;

  // Confirm/Add to Cart
  final double totalPrice;
  final bool isEditing;
  final VoidCallback onAddToCart;
  final VoidCallback onConfirmOrder;

  const SpecialPackAddToCartWidget({
    // Quantity selector
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease, // Save & Add Another
    required this.canSaveAndAddAnother,
    required this.onSaveAndAddAnother, // Saved orders
    required this.savedOrdersList,
    required this.onRemoveSavedOrder, // Free drinks
    required this.freeDrinks,
    required this.maxFreeDrinksQuantity,
    required this.freeDrinkQuantities,
    required this.onFreeDrinkQuantityChanged,
    required this.buildDrinkImage,
    required this.onFreeDrinkSelected,
    required this.onFreeDrinkDeselected,
    required this.totalPrice,
    required this.isEditing,
    required this.onAddToCart,
    required this.onConfirmOrder,
    this.paidDrinksSection, // Paid drinks
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ✅ FIX: Free drinks section FIRST (above quantity selector)
        if (freeDrinks.isNotEmpty) ...[
          _buildFreeDrinksSection(),
          const SizedBox(height: 24),
        ],

        // Quantity selector (hidden in edit mode)
        if (!isEditing) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              _buildQuantitySelector(),
            ],
          ),
        ],

        // Save & Add Another button (hidden in edit mode)
        if (!isEditing) ...[
          const SizedBox(height: 16),
          _buildSaveAndAddAnotherButton(),
        ],

        // ✅ FIX: Paid drinks section (below "Save & Add Another" button)
        if (paidDrinksSection != null) ...[
          const SizedBox(height: 16),
          paidDrinksSection!,
        ],

        // Saved orders (if any)
        if (savedOrdersList.isNotEmpty) ...[
          const SizedBox(height: 16),
          _buildSavedOrders(),
        ],

        // Confirm/Add to Cart section
        const SizedBox(height: 24),
        _buildConfirmAddToCartSection(context, screenWidth),
      ],
    );
  }

  /// Quantity selector widget
  Widget _buildQuantitySelector() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Decrease button
        InkWell(
          onTap: onDecrease,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFfc9d2d),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.remove,
              size: 16,
              color: Colors.white,
            ),
          ),
        ),

        // Quantity display
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Text(
            '$quantity',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),

        // Increase button
        InkWell(
          onTap: onIncrease,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: const Color(0xFFfc9d2d),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.add,
              size: 16,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }

  /// Save & Add Another Order button
  Widget _buildSaveAndAddAnotherButton() {
    return Builder(
      builder: (context) {
        return SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: canSaveAndAddAnother ? onSaveAndAddAnother : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange[600],
              foregroundColor: Colors.white,
              disabledBackgroundColor: Colors.grey[300],
              disabledForegroundColor: Colors.grey[600],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.save, size: 20),
                const SizedBox(width: 8),
                Flexible(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.center,
                    child: Text(
                      AppLocalizations.of(context)!.saveAndAddAnotherOrder,
                      style: GoogleFonts.poppins(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Saved orders section
  Widget _buildSavedOrders() {
    return Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        // PERFORMANCE FIX: Memoize price formatting outside builder to avoid rebuilds
        // For small lists (<10), Wrap is acceptable; for larger lists, consider ListView.builder
        if (savedOrdersList.length > 10) {
          // Use horizontal ListView for large lists
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.savedOrders,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 36,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: savedOrdersList.length,
                  itemExtent: 180, // Approximate width
                  cacheExtent: 360,
                  physics: const ClampingScrollPhysics(),
                  itemBuilder: (context, index) {
                    final orderData = savedOrdersList[index];
                    return _buildSavedOrderChip(orderData, index);
                  },
                ),
              ),
            ],
          );
        }

        // Small list: use Wrap (acceptable for <10 items)
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.savedOrders,
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: savedOrdersList.asMap().entries.map((entry) {
                return _buildSavedOrderChip(entry.value, entry.key);
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  /// Build individual saved order chip (memoized)
  Widget _buildSavedOrderChip(Map<String, dynamic> orderData, int index) {
    // PERFORMANCE FIX: Price formatting is done in Builder below to access context
    // The RepaintBoundary ensures this widget only repaints when its data changes
    return RepaintBoundary(
      child: GestureDetector(
        onTap: () => onRemoveSavedOrder(
          orderData['variantId'] as String,
          orderData['orderIndex'] as int,
        ),
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.orange[600],
            borderRadius: BorderRadius.circular(12),
            // PERFORMANCE FIX: Removed box shadow to reduce repaint cost
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Builder(
                builder: (context) {
                  // Format price with context when available
                  final formattedPrice = PriceFormatter.formatWithSettings(
                    context,
                    orderData['totalPrice'].toString(),
                  );
                  return Text(
                    '${orderData['quantity']}x ${orderData['displayName']} ($formattedPrice)',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  );
                },
              ),
              const SizedBox(width: 6),
              const Icon(
                Icons.close,
                size: 14,
                color: Colors.white,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Free drinks section
  Widget _buildFreeDrinksSection() {
    return Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        final locale = Localizations.localeOf(context).languageCode;
        final drinkWord = maxFreeDrinksQuantity == 1
            ? (locale == 'fr'
                ? 'boisson'
                : locale == 'ar'
                    ? 'مشروب'
                    : 'drink')
            : (locale == 'fr'
                ? 'boissons'
                : locale == 'ar'
                    ? 'مشروبات'
                    : 'drinks');
        final plural = maxFreeDrinksQuantity == 1
            ? ''
            : (locale == 'fr'
                ? 'es'
                : locale == 'ar'
                    ? ''
                    : 's');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section title
            Text(
              l10n.freeDrinksIncluded,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.chooseUpToComplimentaryDrink(
                  maxFreeDrinksQuantity, drinkWord, plural),
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),

            // Free drink cards
            // PERFORMANCE FIX: Wrap is acceptable for small lists (<10 drinks)
            // For larger lists, consider horizontal ListView.builder
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: freeDrinks.map((drink) {
                // PERFORMANCE FIX: Wrap each card in RepaintBoundary to isolate repaints
                return RepaintBoundary(
                  child: _buildFreeDrinkCard(drink),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  /// Free drink card widget
  Widget _buildFreeDrinkCard(MenuItem drink) {
    final drinkQuantity = freeDrinkQuantities[drink.id] ?? 0;
    final isSelected = drinkQuantity > 0;

    return Container(
      width: 100,
      height: 126, // Fixed height for consistent card size
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? const Color(0xFFd47b00) : Colors.grey[300]!,
          width: isSelected ? 2 : 1,
        ),
        // PERFORMANCE FIX: Removed box shadow to reduce repaint cost during scrolling
        // Visual selection is maintained via border width/color
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Background image (full card size)
            buildDrinkImage(drink),

            // Gradient overlay for better text readability
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.6),
                  ],
                  stops: const [0.5, 1.0],
                ),
              ),
            ),

            // Quantity selector at bottom - always visible
            Positioned(
              left: 8,
              right: 8,
              bottom: 8,
              child: Builder(
                builder: (context) {
                  final totalSelected = freeDrinkQuantities.values.fold<int>(
                    0,
                    (sum, qty) => sum + qty,
                  );
                  final canIncrease = totalSelected < maxFreeDrinksQuantity &&
                      drinkQuantity < maxFreeDrinksQuantity;

                  return DrinkQuantitySelector(
                    quantity: drinkQuantity,
                    onQuantityChanged: (newQuantity) {
                      if (newQuantity == 0) {
                        onFreeDrinkDeselected(drink.id);
                      } else if (drinkQuantity == 0) {
                        onFreeDrinkSelected(drink);
                      }
                      onFreeDrinkQuantityChanged(drink.id, newQuantity);
                    },
                    canDecrease: drinkQuantity > 0,
                    canIncrease: canIncrease,
                    fontSize: 10,
                    iconSize: 18,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Confirm/Add to Cart section
  Widget _buildConfirmAddToCartSection(
      BuildContext context, double screenWidth) {
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.008, vertical: screenWidth * 0.04),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Builder(
        builder: (context) {
          // PERFORMANCE FIX: Memoize price formatting once per build
          // PriceFormatter.formatWithSettings is expensive and should not be called multiple times
          final formattedTotalPrice = PriceFormatter.formatWithSettings(
            context,
            totalPrice.toString(),
          );

          if (isEditing) {
            // Show "Save Changes" button in edit mode
            return Stack(
              clipBehavior: Clip.none,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: screenWidth * 0.12,
                  child: ElevatedButton(
                    onPressed: onConfirmOrder,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                          horizontal: screenWidth * 0.05,
                          vertical: screenWidth * 0.03),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.grey[300]!, width: 1),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.shopping_cart,
                                color: Colors.black, size: screenWidth * 0.05),
                            SizedBox(width: screenWidth * 0.02),
                            Text(
                              AppLocalizations.of(context)!.saveChanges,
                              style: GoogleFonts.poppins(
                                fontSize: screenWidth * 0.035,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          formattedTotalPrice,
                          style: GoogleFonts.poppins(
                            fontSize: screenWidth * 0.0324,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Red circle counter badge
                Consumer<CartProvider>(
                  builder: (context, cartProvider, child) {
                    final itemCount = cartProvider.itemCount;
                    if (itemCount == 0) {
                      return const SizedBox.shrink();
                    }
                    return Positioned(
                      top: -6,
                      right: -6,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white,
                            width: 2,
                          ),
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 20,
                          minHeight: 20,
                        ),
                        child: Center(
                          child: Text(
                            itemCount > 99 ? '99+' : '$itemCount',
                            style: GoogleFonts.poppins(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(
                flex: 60,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SizedBox(
                      height: screenWidth * 0.12,
                      child: ElevatedButton(
                        onPressed: onAddToCart,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.04,
                              vertical: screenWidth * 0.02),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(color: Colors.grey[300]!, width: 1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Flexible(
                              child: Text(
                                AppLocalizations.of(context)!.addToCart,
                                style: GoogleFonts.poppins(
                                  fontSize: screenWidth * 0.035,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              formattedTotalPrice,
                              style: GoogleFonts.poppins(
                                fontSize: screenWidth * 0.0324,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    // Red circle counter badge
                    Consumer<CartProvider>(
                      builder: (context, cartProvider, child) {
                        final itemCount = cartProvider.itemCount;
                        if (itemCount == 0) {
                          return const SizedBox.shrink();
                        }
                        return Positioned(
                          top: -6,
                          right: -6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            child: Center(
                              child: Text(
                                itemCount > 99 ? '99+' : '$itemCount',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              SizedBox(width: screenWidth * 0.02),
              Expanded(
                flex: 40,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    SizedBox(
                      height: screenWidth * 0.109,
                      child: ElevatedButton(
                        onPressed: onConfirmOrder,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange[600],
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                              horizontal: screenWidth * 0.04,
                              vertical: screenWidth * 0.02),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.confirmOrder,
                          style: GoogleFonts.poppins(
                            fontSize: screenWidth * 0.035,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                    // Red circle counter badge
                    Consumer<CartProvider>(
                      builder: (context, cartProvider, child) {
                        final itemCount = cartProvider.itemCount;
                        if (itemCount == 0) {
                          return const SizedBox.shrink();
                        }
                        return Positioned(
                          top: -6,
                          right: -6,
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 20,
                              minHeight: 20,
                            ),
                            child: Center(
                              child: Text(
                                itemCount > 99 ? '99+' : '$itemCount',
                                style: GoogleFonts.poppins(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Scrollable add to cart widget (free drinks, quantity, save button, paid drinks)
/// Excludes the confirm/add to cart button which is in the fixed bottom container
class SpecialPackScrollableAddToCartWidget extends StatelessWidget {
  // Quantity selector
  final int quantity;
  final VoidCallback? onDecrease;
  final VoidCallback onIncrease;

  // Save & Add Another
  final bool canSaveAndAddAnother;
  final VoidCallback onSaveAndAddAnother;

  // Free drinks
  final List<MenuItem> freeDrinks;
  final int maxFreeDrinksQuantity;
  final Map<String, int> freeDrinkQuantities;
  final Function(String drinkId, int quantity) onFreeDrinkQuantityChanged;
  final Widget Function(MenuItem drink) buildDrinkImage;
  final Function(MenuItem drink) onFreeDrinkSelected;
  final Function(String drinkId) onFreeDrinkDeselected;

  // Paid drinks
  final Widget? paidDrinksSection;

  final bool isEditing;

  const SpecialPackScrollableAddToCartWidget({
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
    required this.canSaveAndAddAnother,
    required this.onSaveAndAddAnother,
    required this.freeDrinks,
    required this.maxFreeDrinksQuantity,
    required this.freeDrinkQuantities,
    required this.onFreeDrinkQuantityChanged,
    required this.buildDrinkImage,
    required this.onFreeDrinkSelected,
    required this.onFreeDrinkDeselected,
    required this.isEditing,
    this.paidDrinksSection,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Free drinks section FIRST (above quantity selector)
        if (freeDrinks.isNotEmpty) ...[
          _buildFreeDrinksSection(),
          const SizedBox(height: 24),
        ],

        // Paid drinks section
        if (paidDrinksSection != null) ...[
          const SizedBox(height: 16),
          paidDrinksSection!,
        ],
      ],
    );
  }

  /// Free drinks section
  Widget _buildFreeDrinksSection() {
    return Builder(
      builder: (context) {
        if (freeDrinks.isEmpty) {
          return const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppLocalizations.of(context)!.freeDrinksIncluded,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Builder(
              builder: (context) {
                final locale = Localizations.localeOf(context).languageCode;
                final drinkWord = maxFreeDrinksQuantity == 1
                    ? (locale == 'fr'
                        ? 'boisson'
                        : locale == 'ar'
                            ? 'مشروب'
                            : 'drink')
                    : (locale == 'fr'
                        ? 'boissons'
                        : locale == 'ar'
                            ? 'مشروبات'
                            : 'drinks');
                final plural = maxFreeDrinksQuantity == 1
                    ? ''
                    : (locale == 'fr'
                        ? 'es'
                        : locale == 'ar'
                            ? ''
                            : 's');
                return Text(
                  AppLocalizations.of(context)!.chooseUpToComplimentaryDrink(
                    maxFreeDrinksQuantity,
                    drinkWord,
                    plural,
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: freeDrinks.map((drink) {
                  final drinkQuantity = freeDrinkQuantities[drink.id] ?? 0;
                  final isSelected = drinkQuantity > 0;

                  return Container(
                    margin: const EdgeInsets.only(right: 12),
                    width: 100,
                    child: Stack(
                      children: [
                        // Drink image
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            width: 100,
                            height: 100,
                            color: Colors.grey[200],
                            child: isSelected
                                ? Stack(
                                    children: [
                                      buildDrinkImage(drink),
                                      Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.3),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                      ),
                                    ],
                                  )
                                : buildDrinkImage(drink),
                          ),
                        ),

                        // Quantity selector at bottom
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 8,
                          child: Builder(
                            builder: (context) {
                              final totalSelected = freeDrinkQuantities.values
                                  .fold<int>(0, (sum, qty) => sum + qty);
                              final canIncrease =
                                  totalSelected < maxFreeDrinksQuantity &&
                                      drinkQuantity < maxFreeDrinksQuantity;

                              return DrinkQuantitySelector(
                                quantity: drinkQuantity,
                                onQuantityChanged: (newQuantity) {
                                  if (newQuantity == 0) {
                                    onFreeDrinkDeselected(drink.id);
                                  } else if (drinkQuantity == 0) {
                                    onFreeDrinkSelected(drink);
                                  }
                                  onFreeDrinkQuantityChanged(
                                      drink.id, newQuantity);
                                },
                                canDecrease: drinkQuantity > 0,
                                canIncrease: canIncrease,
                                fontSize: 10,
                                iconSize: 18,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Confirm/Add to Cart button widget (for fixed bottom container)
class SpecialPackConfirmAddToCartButton extends StatefulWidget {
  final double totalPrice;
  final bool isEditing;
  final Future<bool> Function() onAddToCart;
  final VoidCallback onConfirmOrder;
  final int quantity;
  final VoidCallback? onDecrease;
  final VoidCallback onIncrease;

  const SpecialPackConfirmAddToCartButton({
    required this.totalPrice,
    required this.isEditing,
    required this.onAddToCart,
    required this.onConfirmOrder,
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
    super.key,
  });

  @override
  State<SpecialPackConfirmAddToCartButton> createState() =>
      _SpecialPackConfirmAddToCartButtonState();
}

class _SpecialPackConfirmAddToCartButtonState
    extends State<SpecialPackConfirmAddToCartButton>
    with TickerProviderStateMixin {
  bool _isAdding = false;
  bool _isSuccess = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _colorAnimation;
  AnimationController? _shakeController;
  Animation<double>? _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.95,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _colorAnimation = ColorTween(
      begin: Colors.orange[600],
      end: Colors.green[600],
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
  }

  @override
  void dispose() {
    _animationController.dispose();
    _shakeController?.dispose();
    super.dispose();
  }

  Future<void> _handleAddToCart() async {
    if (_isAdding || _isSuccess) return;

    setState(() {
      _isAdding = true;
    });

    // Small delay to show loading state
    await Future.delayed(const Duration(milliseconds: 300));

    // Trigger the actual add to cart callback and check result
    final success = await widget.onAddToCart();

    if (mounted) {
      setState(() {
        _isAdding = false;
      });

      if (success) {
        // Show success animation only if validation passed
        setState(() {
          _isSuccess = true;
        });

        // Animate to success state
        await _animationController.forward();

        // Wait a bit to show success state
        await Future.delayed(const Duration(milliseconds: 1200));

        // Reset to normal state
        await _animationController.reverse();

        if (mounted) {
          setState(() {
            _isSuccess = false;
          });
        }
      } else {
        // Show error shake animation and vibration
        await _showErrorFeedback();
      }
    }
  }

  Future<void> _showErrorFeedback() async {
    // Trigger haptic feedback (vibration)
    HapticFeedback.mediumImpact();

    // Shake animation using a temporary animation controller
    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 100),
      vsync: this,
    );

    _shakeAnimation =
        Tween<double>(begin: -10, end: 10).animate(CurvedAnimation(
      parent: _shakeController!,
      curve: Curves.elasticIn,
    ));

    // Trigger rebuild to show shake animation
    setState(() {});

    // Create a shake animation sequence (shake left-right-left-right)
    for (int i = 0; i < 4; i++) {
      await _shakeController!.forward();
      await _shakeController!.reverse();
    }

    _shakeController!.dispose();
    _shakeController = null;
    _shakeAnimation = null;
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return Padding(
      padding: EdgeInsets.symmetric(
          horizontal: screenWidth * 0.008, vertical: screenWidth * 0.02),
      child: Builder(
        builder: (context) {
          final formattedTotalPrice = PriceFormatter.formatWithSettings(
            context,
            widget.totalPrice.toString(),
          );

          if (widget.isEditing) {
            // Show "Save Changes" button in edit mode
            return SizedBox(
              width: double.infinity,
              height: screenWidth * 0.12,
              child: ElevatedButton(
                onPressed: widget.onConfirmOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.05,
                      vertical: screenWidth * 0.03),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.grey[300]!, width: 1),
                  ),
                  elevation: 0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shopping_cart,
                            color: Colors.black, size: screenWidth * 0.05),
                        SizedBox(width: screenWidth * 0.02),
                        Text(
                          AppLocalizations.of(context)!.saveChanges,
                          style: GoogleFonts.poppins(
                            fontSize: screenWidth * 0.035,
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      formattedTotalPrice,
                      style: GoogleFonts.poppins(
                        fontSize: screenWidth * 0.0324,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
          return Row(
            children: [
              // Quantity selector on the left
              if (!widget.isEditing) ...[
                _buildQuantitySelector(screenWidth),
                SizedBox(width: screenWidth * 0.02),
              ],
              // Add to Cart button
              Expanded(
                child: AnimatedBuilder(
                  animation: Listenable.merge([
                    _animationController,
                    if (_shakeController != null) _shakeController!,
                  ]),
                  builder: (context, child) {
                    final shakeOffset = _shakeAnimation?.value ?? 0.0;
                    return Transform.translate(
                      offset: Offset(shakeOffset, 0),
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            SizedBox(
                              height: screenWidth * 0.12,
                              child: ElevatedButton(
                                onPressed: _isAdding || _isSuccess
                                    ? null
                                    : _handleAddToCart,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _isSuccess
                                      ? Colors.green[600]
                                      : (_colorAnimation.value ??
                                          Colors.orange[600]),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  padding: EdgeInsets.symmetric(
                                      horizontal: screenWidth * 0.04,
                                      vertical: screenWidth * 0.02),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  disabledBackgroundColor: _isSuccess
                                      ? Colors.green[600]
                                      : Colors.orange[600],
                                ),
                                child: _isAdding
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation<Color>(
                                              Colors.white),
                                        ),
                                      )
                                    : _isSuccess
                                        ? Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                size: screenWidth * 0.05,
                                                color: Colors.white,
                                              ),
                                              SizedBox(width: screenWidth * 0.02),
                                              Text(
                                                AppLocalizations.of(context)!
                                                    .addedToCart,
                                                style: GoogleFonts.poppins(
                                                  fontSize: screenWidth * 0.035,
                                                  fontWeight: FontWeight.w600,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          )
                                        : Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Flexible(
                                                child: Text(
                                                  AppLocalizations.of(context)!
                                                      .addToCart,
                                                  style: GoogleFonts.poppins(
                                                    fontSize: screenWidth * 0.035,
                                                    fontWeight: FontWeight.w600,
                                                    color: Colors.white,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                formattedTotalPrice,
                                                style: GoogleFonts.poppins(
                                                  fontSize: screenWidth * 0.0324,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                              ),
                            ),
                            // Red circle counter badge
                            Consumer<CartProvider>(
                              builder: (context, cartProvider, child) {
                                final itemCount = cartProvider.itemCount;
                                if (itemCount == 0) {
                                  return const SizedBox.shrink();
                                }
                                return Positioned(
                                  top: -6,
                                  right: -6,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: Colors.white,
                                        width: 2,
                                      ),
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 20,
                                      minHeight: 20,
                                    ),
                                    child: Center(
                                      child: Text(
                                        itemCount > 99 ? '99+' : '$itemCount',
                                        style: GoogleFonts.poppins(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Quantity selector widget
  Widget _buildQuantitySelector(double screenWidth) {
    return Container(
      height: screenWidth * 0.12,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Decrease button
          InkWell(
            onTap: widget.onDecrease,
            child: Icon(
              Icons.remove,
              size: 18,
              color: widget.onDecrease != null
                  ? Colors.grey[700]
                  : Colors.grey[400],
            ),
          ),

          // Quantity display
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '${widget.quantity}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),

          // Increase button
          InkWell(
            onTap: widget.onIncrease,
            child: Icon(
              Icons.add,
              size: 18,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
