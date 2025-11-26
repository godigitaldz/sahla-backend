import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../cart_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../models/menu_item.dart';
import '../../models/restaurant.dart';
import '../../utils/price_formatter.dart';
import '../../utils/responsive_sizing.dart';
import '../../widgets/menu_item_full_popup/menu_item_popup_factory.dart';

class OrderDetailsSummary extends StatelessWidget {
  final VoidCallback onCheckout;
  final bool showPriceSummary;

  const OrderDetailsSummary({
    required this.onCheckout,
    super.key,
    this.showPriceSummary = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return Consumer<CartProvider>(
      builder: (context, cartProvider, child) {
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                spreadRadius: 1,
                blurRadius: 10,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment:
                isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // Header - RTL aware layout
              Row(
                textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      l10n.orderSummary,
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveSizing.fontSize(20, context),
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                      textAlign: isRTL ? TextAlign.right : TextAlign.left,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${cartProvider.itemCount} ${l10n.items}',
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveSizing.fontSize(12, context),
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[700],
                      ),
                      textAlign: isRTL ? TextAlign.right : TextAlign.left,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // Order Items Details with grouping by popup session
              ...() {
                final widgets = <Widget>[];
                final items = cartProvider.items;
                final used = <int>{};

                for (var i = 0; i < items.length; i++) {
                  if (used.contains(i)) continue;
                  final item = items[i];
                  final groupId = item.customizations?['popup_session_id'];
                  final isSpecialPack =
                      item.customizations?['is_special_pack'] == true;
                  final isRegular = !isSpecialPack;

                  // ✅ FIX: For regular items (LTO and normal), always use unified container
                  // Group regular items by popup_session_id OR by menu item name (like special packs)
                  if (groupId == null && !isSpecialPack) {
                    // Regular item without groupId - check if there are other items with same name to group
                    final group = <CartItem>[item];
                    used.add(i);

                    // Look for other regular items with same name to group together
                    for (var j = i + 1; j < items.length; j++) {
                      if (used.contains(j)) continue;
                      final other = items[j];
                      final otherIsSpecialPack =
                          other.customizations?['is_special_pack'] == true;
                      final otherGroupId =
                          other.customizations?['popup_session_id'];

                      // Group regular items with same name (unified display)
                      if (!otherIsSpecialPack && otherGroupId == null &&
                          _getBaseMenuItemName(item.name) == _getBaseMenuItemName(other.name)) {
                        group.add(other);
                        used.add(j);
                      }
                    }

                    if (group.length == 1) {
                      widgets.add(_buildOrderItemSummary(
                          context, item, widgets.length + 1, cartProvider));
                    } else {
                      widgets.add(_buildGroupedOrderItem(
                          context, group, widgets.length + 1));
                    }
                    continue;
                  }

                  // collect group members
                  final group = <CartItem>[item];
                  used.add(i);

                  // ✅ FIX: Group by popup_session_id OR by menu item name for both special packs and regular items
                  // This ensures all items of the same type are grouped together in unified container
                  for (var j = i + 1; j < items.length; j++) {
                    if (used.contains(j)) continue;
                    final other = items[j];
                    final otherIsSpecialPack =
                        other.customizations?['is_special_pack'] == true;
                    final otherGroupId =
                        other.customizations?['popup_session_id'];

                    // Group if:
                    // 1. Same popup_session_id, OR
                    // 2. Both are special packs AND same name, OR
                    // 3. Both are regular items AND same name (for unified display)
                    final shouldGroup =
                        (groupId != null && otherGroupId == groupId) ||
                            (isSpecialPack &&
                                otherIsSpecialPack &&
                                _getBaseMenuItemName(item.name) == _getBaseMenuItemName(other.name)) ||
                            (isRegular &&
                                !otherIsSpecialPack &&
                                _getBaseMenuItemName(item.name) == _getBaseMenuItemName(other.name) &&
                                (groupId == null || otherGroupId == groupId));

                    if (shouldGroup) {
                      group.add(other);
                      used.add(j);
                    }
                  }

                  if (group.length == 1) {
                    widgets.add(_buildOrderItemSummary(
                        context, item, widgets.length + 1, cartProvider));
                  } else {
                    widgets.add(_buildGroupedOrderItem(
                        context, group, widgets.length + 1));
                  }
                }

                return widgets;
              }(),

              if (cartProvider.items.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Text(
                      l10n.noItemsInOrder,
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveSizing.fontSize(16, context),
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
                ),

              if (showPriceSummary) ...[
                const SizedBox(height: 18), // Reduced by ~10%

                // Price Summary Section
                Container(
                  padding: const EdgeInsets.all(14.4), // Reduced by ~10%
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                  ),
                  child: _buildPriceSummary(context, cartProvider),
                ),

                const SizedBox(height: 18), // Reduced by ~10%

                // Checkout Button - RTL aware layout
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: onCheckout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange[600],
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      shadowColor: Colors.orange[600]!.withValues(alpha: 0.3),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (isRTL) ...[
                          Text(
                            l10n.confirmOrder,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(
                            Icons.local_shipping_outlined,
                            size: 20,
                            color: Colors.white,
                          ),
                        ] else ...[
                          const Icon(
                            Icons.local_shipping_outlined,
                            size: 20,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            l10n.confirmOrder,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildOrderItemSummary(BuildContext context, CartItem cartItem,
      int orderNumber, CartProvider cartProvider) {
    final l10n = AppLocalizations.of(context)!;
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return Container(
      margin: const EdgeInsets.only(bottom: 14.4), // Reduced by ~10% (16 * 0.9)
      padding: const EdgeInsets.all(14.4), // Reduced by ~10% (16 * 0.9)
      decoration: BoxDecoration(
        color:
            Colors.grey[200], // ✅ Changed to light grey for better visibility
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment:
            isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Header with Item Name and Action Buttons - RTL aware layout
          Row(
            textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${l10n.orderNumber}$orderNumber: ${_getBaseMenuItemName(cartItem.name)}',
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveSizing.fontSize(16, context),
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  textAlign: isRTL ? TextAlign.right : TextAlign.left,
                  textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                ),
              ),
              // Action Buttons - RTL aware positioning
              // ✅ FIX: Hide edit button for regular items (both LTO and normal)
              // Only show edit button for special packs
              Builder(
                builder: (context) {
                  final isSpecialPack = cartItem.customizations?['is_special_pack'] == true;
                  return Row(
                children: [
                  if (isRTL) ...[
                    // Remove Button
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: Material(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _showRemoveDialog(
                              context, cartItem, cartProvider),
                          child: Icon(
                            Icons.delete,
                            size: 16,
                            color: Colors.red[600],
                          ),
                        ),
                      ),
                    ),
                    if (isSpecialPack) ...[
                      const SizedBox(width: 8),
                      // Edit Button (only for special packs)
                      SizedBox(
                        width: 32,
                        height: 32,
                        child: Material(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _editOrderItem(context, cartItem),
                            child: Icon(
                              Icons.edit,
                              size: 16,
                              color: Colors.blue[600],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ] else ...[
                    // Edit Button (only for special packs)
                    if (isSpecialPack)
                      Container(
                        width: 32,
                        height: 32,
                        margin: const EdgeInsets.only(right: 8),
                        child: Material(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(8),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () => _editOrderItem(context, cartItem),
                            child: Icon(
                              Icons.edit,
                              size: 16,
                              color: Colors.blue[600],
                            ),
                          ),
                        ),
                      ),
                    // Remove Button
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: Material(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: () => _showRemoveDialog(
                              context, cartItem, cartProvider),
                          child: Icon(
                            Icons.delete,
                            size: 16,
                            color: Colors.red[600],
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              );
                },
              ),
            ],
          ),

          const SizedBox(height: 10.8), // Reduced by ~10%

          // Customization Details - RTL aware
          if (_hasCustomizations(cartItem)) ...[
            // Variant and Size (or Pack Selections for special packs)
            if (cartItem.customizations != null) ...[
              // ✅ FIX: For special packs, show selections with ingredients
              if (cartItem.customizations!['is_special_pack'] == true)
                ..._buildPackItemsWithIngredients(cartItem, context)
              else ...[
                // Check if we have multiple variants (unified saved orders)
                if (cartItem.customizations!['variants'] != null &&
                    (cartItem.customizations!['variants'] as List).isNotEmpty)
                  ..._buildMultipleVariants(
                      cartItem.customizations!['variants'] as List,
                      cartItem.customizations!,
                      context)
                else ...[
                  _buildDetailRow(
                      l10n.variant,
                      _getVariantText(
                        cartItem.customizations!,
                        quantity: cartItem.quantity,
                      ),
                      context),
                  _buildDetailRow(
                      l10n.size,
                      _getSizeText(cartItem.customizations!,
                          quantity: cartItem.quantity),
                      context),
                ],
              ],
            ],

            // ✅ FIX: Supplements - For special packs, show only global supplements with prices
            // For regular items, show all supplements
            if (cartItem.customizations != null && _hasSupplements(cartItem.customizations))
              _buildDetailRow(
                l10n.supplements,
                cartItem.customizations!['is_special_pack'] == true
                    ? _getGlobalSupplementsText(
                        cartItem.customizations!, context)
                    : _getSupplementsText(cartItem.customizations!),
                context,
              ),

            // Main Pack Ingredients (shown above drinks for special packs - NOT customizable)
            if (cartItem.customizations != null &&
                cartItem.customizations!['is_special_pack'] == true &&
                _hasGlobalPackIngredients(cartItem.customizations))
              _buildDetailRow(
                  l10n.mainIngredients,
                  _formatGlobalPackIngredients(cartItem.customizations!),
                  context),

            // Drinks
            if (_hasDrinks(cartItem))
              _buildDetailRow(
                  l10n.drinks, _formatDrinks(cartItem, context), context),

            // Regular Ingredient Preferences (non-pack items)
            if (cartItem.customizations != null &&
                cartItem.customizations!['is_special_pack'] != true &&
                _hasIngredientPreferences(cartItem.customizations))
              _buildDetailRow(
                  l10n.ingredients,
                  _getIngredientPreferencesText(cartItem.customizations!),
                  context),

            // Removed Ingredients (for regular items)
            if (cartItem.customizations != null &&
                cartItem.customizations!['is_special_pack'] != true) ...[
              Builder(
                builder: (context) {
                  final removedIngredients =
                      cartItem.customizations?['removed_ingredients'] as List?;
                  if (removedIngredients != null &&
                      removedIngredients.isNotEmpty) {
                    final removedText = removedIngredients
                        .where((ing) => ing.toString().trim().isNotEmpty)
                        .join(', ');
                    if (removedText.isNotEmpty) {
                      return _buildDetailRow(
                          l10n.removedIngredients, removedText, context);
                    }
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ],

          // Special Instructions - RTL aware
          if (cartItem.specialInstructions?.isNotEmpty == true) ...[
            const SizedBox(height: 7.2), // Reduced by ~10%
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10.8), // Reduced by ~10%
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment:
                    isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.specialInstructions,
                    style: GoogleFonts.poppins(
                      fontSize: ResponsiveSizing.fontSize(12, context),
                      fontWeight: FontWeight.w600,
                      color: Colors.blue[700],
                    ),
                    textAlign: isRTL ? TextAlign.right : TextAlign.left,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    cartItem.specialInstructions!,
                    style: GoogleFonts.poppins(
                      fontSize: ResponsiveSizing.fontSize(12, context),
                      color: Colors.blue[600],
                    ),
                    textAlign: isRTL ? TextAlign.right : TextAlign.left,
                  ),
                ],
              ),
            ),
          ],

          // Restaurant Info and Price on same line - RTL responsive
          const SizedBox(height: 10.8), // Space before bottom row
          Row(
            textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Restaurant name with icon (if available)
              if (cartItem.restaurantName != null)
                Expanded(
                  child: Row(
                    textDirection:
                        isRTL ? TextDirection.rtl : TextDirection.ltr,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.restaurant, size: 14, color: Colors.grey[600]),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          cartItem.restaurantName!,
                          style: GoogleFonts.poppins(
                            fontSize: ResponsiveSizing.fontSize(12, context),
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: isRTL ? TextAlign.right : TextAlign.left,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                )
              else
                const Spacer(),

              // Price
              Text(
                PriceFormatter.formatWithSettings(
                    context, cartItem.totalPrice.toString()),
                style: GoogleFonts.poppins(
                  fontSize: ResponsiveSizing.fontSize(16, context),
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[600],
                ),
                textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Extracts the base menu item name from CartItem name
  /// Removes variant suffix (e.g., "Tacos - Poulet" -> "Tacos")
  String _getBaseMenuItemName(String itemName) {
    // Format is typically "Menu Item - Variant" or "Menu Item Variant"
    // Extract the base name by removing everything after " - " or just the variant part
    if (itemName.contains(' - ')) {
      return itemName.split(' - ').first.trim();
    }
    // If no " - " separator, return as-is (might already be just the base name)
    return itemName;
  }

  Widget _buildGroupedOrderItem(
      BuildContext context, List<CartItem> group, int orderNumber) {
    final l10n = AppLocalizations.of(context)!;
    final isRTL = Directionality.of(context) == TextDirection.rtl;
    final first = group.first;

    // Aggregate drinks (unique with counts)
    final Map<String, int> drinkCounts = {};
    final Map<String, String> drinkNamesById =
        {}; // Build name map from drinks list
    final Map<String, double> drinkPricesById = {}; // Build price map
    final Map<String, bool> isFreeById = {}; // Track free drinks

    // Collect separate free and paid quantities
    final Map<String, int> freeDrinkQuantities = {};
    final Map<String, int> paidDrinkQuantities = {};

    // Detect item type from first item
    final isLTO = first.customizations?['is_limited_offer'] == true ||
        first.customizations?['menu_item']?['is_limited_offer'] == true;
    final isSpecialPack = first.customizations?['is_special_pack'] == true;

    // ✅ FIX: For special packs, free drinks are per-item (each pack includes its own free drink)
    // Paid drinks are global (only in first item)
    if (isSpecialPack) {
      // Accumulate free drinks from ALL items (each pack has its own free drink)
      // Paid drinks only come from the first item (they're global)
      for (final item in group) {
        final freeQuantitiesFromCustomizations = item
            .customizations?['free_drink_quantities'] as Map<String, dynamic>?;

        freeQuantitiesFromCustomizations?.forEach((id, qty) {
          final q = qty is int ? qty : int.tryParse(qty.toString()) ?? 0;
          if (q > 0) {
            freeDrinkQuantities[id] = (freeDrinkQuantities[id] ?? 0) + q;
          }
        });
      }

      // Paid drinks only from first item (they're global)
      final firstItem = group.first;
      final paidQuantitiesFromCustomizations = firstItem
          .customizations?['paid_drink_quantities'] as Map<String, dynamic>?;

      paidQuantitiesFromCustomizations?.forEach((id, qty) {
        final q = qty is int ? qty : int.tryParse(qty.toString()) ?? 0;
        if (q > 0) {
          paidDrinkQuantities[id] =
              q; // Don't accumulate - paid drinks are global
        }
      });

      // Fallback: accumulate drink_quantities from all items for free drinks
      // But only count paid drinks from first item
      for (final item in group) {
        final q = item.drinkQuantities ?? {};
        q.forEach((id, qty) {
          // Check if this is a free drink (in free_drink_quantities) or paid (only first item)
          final isFreeDrink =
              item.customizations?['free_drink_quantities']?[id] != null;
          if (isFreeDrink) {
            drinkCounts[id] = (drinkCounts[id] ?? 0) + qty;
          } else if (item == firstItem) {
            // Paid drinks only from first item
            drinkCounts[id] = qty;
          }
        });
      }
    } else {
      // For regular items (LTO and regular), accumulate free drinks from all items
      // But paid drinks are GLOBAL - only take from first item (don't accumulate)
      final firstItem = group.first;

      for (final item in group) {
        // Collect separate free and paid quantities if available
        final freeQuantitiesFromCustomizations = item
            .customizations?['free_drink_quantities'] as Map<String, dynamic>?;
        final paidQuantitiesFromCustomizations = item
            .customizations?['paid_drink_quantities'] as Map<String, dynamic>?;

        // Free drinks: accumulate from all items (each item has its own free drinks)
        freeQuantitiesFromCustomizations?.forEach((id, qty) {
          final q = qty is int ? qty : int.tryParse(qty.toString()) ?? 0;
          if (q > 0) {
            freeDrinkQuantities[id] = (freeDrinkQuantities[id] ?? 0) + q;
          }
        });

        // ✅ FIX: Paid drinks are GLOBAL - only take from first item (don't accumulate)
        if (item == firstItem) {
          paidQuantitiesFromCustomizations?.forEach((id, qty) {
            final q = qty is int ? qty : int.tryParse(qty.toString()) ?? 0;
            if (q > 0) {
              paidDrinkQuantities[id] =
                  q; // Don't accumulate - paid drinks are global
            }
          });
        }

        // Fallback: use merged drink_quantities if separate quantities not available
        // For free drinks: accumulate from all items
        // For paid drinks: only from first item
        final q = item.drinkQuantities ?? {};
        q.forEach((id, qty) {
          // Check if this is a free drink (in free_drink_quantities) or paid (only first item)
          final isFreeDrink =
              item.customizations?['free_drink_quantities']?[id] != null;
          if (isFreeDrink) {
            // Free drinks: accumulate from all items
            drinkCounts[id] = (drinkCounts[id] ?? 0) + qty;
          } else if (item == firstItem) {
            // Paid drinks: only from first item (don't accumulate)
            drinkCounts[id] = qty;
          }
        });
      }
    }

    // Build name and price maps from drinks list - for special packs, check all items to get all drink names
    // (since each pack item can have its own free drinks)
    final itemsToCheckForDrinkNames = group;
    for (final item in itemsToCheckForDrinkNames) {
      // Build name and price maps from drinks list in customizations
      final drinksList = item.customizations?['drinks'];
      if (drinksList is List) {
        for (final d in drinksList) {
          if (d is Map) {
            final id = d['id']?.toString() ?? '';
            final name = (d['name']?.toString().isNotEmpty == true)
                ? d['name'].toString()
                : id;
            if (id.isNotEmpty && !drinkNamesById.containsKey(id)) {
              drinkNamesById[id] = name;
            }
          }
        }
      }
    }

    // ✅ FIX: Resolve drink names for drinks in free_drink_quantities or paid_drink_quantities
    // that might not be in the drinks list yet (e.g., calculated from pricing)
    // Collect all drink IDs that need names resolved
    final drinkIdsNeedingNames = <String>{};

    // Collect IDs from free_drink_quantities
    for (final item in group) {
      final freeQuantities = item.customizations?['free_drink_quantities'] as Map<String, dynamic>?;
      freeQuantities?.forEach((id, qty) {
        if (id.isNotEmpty && !drinkNamesById.containsKey(id)) {
          drinkIdsNeedingNames.add(id);
        }
      });

      // Collect IDs from paid_drink_quantities
      final paidQuantities = item.customizations?['paid_drink_quantities'] as Map<String, dynamic>?;
      paidQuantities?.forEach((id, qty) {
        if (id.isNotEmpty && !drinkNamesById.containsKey(id)) {
          drinkIdsNeedingNames.add(id);
        }
      });

      // Collect IDs from drinkQuantities
      final quantities = item.drinkQuantities ?? {};
      quantities.forEach((id, qty) {
        if (id.isNotEmpty && !drinkNamesById.containsKey(id)) {
          drinkIdsNeedingNames.add(id);
        }
      });
    }

    // Try to resolve names for drinks that need them by checking all items' drinks lists
    for (final drinkId in drinkIdsNeedingNames) {
      for (final checkItem in group) {
        final checkDrinksList = checkItem.customizations?['drinks'];
        if (checkDrinksList is List) {
          for (final d in checkDrinksList) {
            if (d is Map) {
              final id = d['id']?.toString() ?? '';
              if (id == drinkId) {
                final drinkName = (d['name']?.toString().isNotEmpty == true)
                    ? d['name'].toString()
                    : null;
                if (drinkName != null && drinkName != drinkId) {
                  drinkNamesById[drinkId] = drinkName;
                  break;
                }
              }
            }
          }
        }
        if (drinkNamesById.containsKey(drinkId)) break;
      }
    }

    // Continue with original logic to extract prices and determine free/paid status
    for (final item in itemsToCheckForDrinkNames) {
      // Build name and price maps from drinks list in customizations
      final drinksList = item.customizations?['drinks'];
      if (drinksList is List) {
        for (final d in drinksList) {
          if (d is Map) {
            final id = d['id']?.toString() ?? '';
            final name = (d['name']?.toString().isNotEmpty == true)
                ? d['name'].toString()
                : id;
            if (id.isNotEmpty && !drinkNamesById.containsKey(id)) {
              drinkNamesById[id] = name;
            }

            // Extract price
            // ✅ FIX: For paid drinks, ensure we use the correct price (not 0)
            // If drink is in paid_drink_quantities, it should have a price > 0
            final drinkPrice = (d['price'] as num?)?.toDouble() ?? 0.0;
            if (id.isNotEmpty) {
              // Check if this drink is a paid drink (in paid_drink_quantities)
              final isPaidDrink = paidDrinkQuantities.containsKey(id) &&
                  (paidDrinkQuantities[id] ?? 0) > 0;

              if (isPaidDrink && drinkPrice > 0) {
                // ✅ FIX: Paid drink with valid price - always use it (overwrite if needed)
                drinkPricesById[id] = drinkPrice;
              } else if (!drinkPricesById.containsKey(id)) {
                // Only set price if not already set (for free drinks or first occurrence)
                drinkPricesById[id] = drinkPrice;
              } else if (drinkPrice > 0 && (drinkPricesById[id] ?? 0.0) == 0.0) {
                // ✅ FIX: If we have a 0 price but encounter a non-zero price, overwrite it
                // This handles cases where a drink appears as free first, then as paid
                drinkPricesById[id] = drinkPrice;
              }
            }

            // Determine if drink is free - comprehensive detection logic
            bool isFree = false;

            // Priority 1: Check explicit is_free flag FIRST
            if (d['is_free'] == true || d['isFree'] == true) {
              isFree = true;
            }
            // Priority 2: Check if price is 0
            else if (drinkPrice == 0.0) {
              isFree = true;
            } else if (isLTO || isSpecialPack) {
              // For LTO/special packs, check multiple locations for free drinks data
              // Location 1: Direct free_drinks_list in customizations
              final freeDrinksList1 =
                  item.customizations?['free_drinks_list'] as List?;
              if (freeDrinksList1 != null && freeDrinksList1.contains(id)) {
                isFree = true;
              }

              // Location 2: In pricing object
              final pricing = item.customizations?['pricing'] as Map?;
              if (pricing != null) {
                final freeDrinksList2 = pricing['free_drinks_list'] as List?;
                if (freeDrinksList2 != null && freeDrinksList2.contains(id)) {
                  isFree = true;
                }
              }

              // Location 3: In menu_item object
              final menuItem = item.customizations?['menu_item'] as Map?;
              if (menuItem != null) {
                final freeDrinksList3 = menuItem['free_drinks_list'] as List?;
                if (freeDrinksList3 != null && freeDrinksList3.contains(id)) {
                  isFree = true;
                }
              }
            }
            if (id.isNotEmpty && !isFreeById.containsKey(id)) {
              isFreeById[id] = isFree;
            }
          }
        }
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14.4),
      padding: const EdgeInsets.all(14.4),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment:
            isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  '${l10n.orderNumber}$orderNumber: ${_getBaseMenuItemName(first.name)}',
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveSizing.fontSize(16, context),
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10.8),

          // ✅ FIX: For special packs, unify all items in one container without white separations
          // For regular items, show each item in its own white container
          if (isSpecialPack) ...[
            // Special pack: unified display without white separations
            ...group.asMap().entries.map((entry) {
              final index = entry.key;
              final ci = entry.value;
              final isLast = index == group.length - 1;

              return Column(
                crossAxisAlignment:
                    isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Item details without white container
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: isRTL
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            // For special packs, show pack items with ingredients
                            if (ci.customizations?['is_special_pack'] == true)
                              ..._buildPackItemsWithIngredients(ci, context)
                            else ...[
                              Text(
                                [
                                  _getVariantText(ci.customizations ?? {},
                                      quantity: ci.quantity),
                                  _getSizeText(ci.customizations ?? {},
                                      quantity: ci.quantity)
                                ].where((t) => t.trim().isNotEmpty).join(', '),
                                style: GoogleFonts.poppins(
                                  fontSize:
                                      ResponsiveSizing.fontSize(14, context),
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // Edit and Remove buttons
                      // ✅ FIX: Hide edit button for regular items (both LTO and normal)
                      // Only show edit button for special packs
                      Builder(
                        builder: (context) {
                          final ciIsSpecialPack = ci.customizations?['is_special_pack'] == true;
                          return Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Edit Button (only for special packs)
                              if (ciIsSpecialPack)
                                Container(
                                  width: 32,
                                  height: 32,
                                  margin: const EdgeInsets.only(right: 8),
                                  child: Material(
                                    color: Colors.blue[50],
                                    borderRadius: BorderRadius.circular(8),
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(8),
                                      onTap: () => _editOrderItem(context, ci),
                                      child: Icon(
                                        Icons.edit,
                                        size: 16,
                                        color: Colors.blue[600],
                                      ),
                                    ),
                                  ),
                                ),
                              SizedBox(
                            width: 32,
                            height: 32,
                            child: Material(
                              color: Colors.red[50],
                              borderRadius: BorderRadius.circular(8),
                              child: InkWell(
                                borderRadius: BorderRadius.circular(8),
                                onTap: () {
                                  final cartProvider =
                                      Provider.of<CartProvider>(context,
                                          listen: false);
                                  _showRemoveDialog(context, ci, cartProvider);
                                },
                                      child: Icon(
                                        Icons.delete,
                                        size: 16,
                                        color: Colors.red[600],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                      ),
                    ],
                  ),
                  // Divider between items (not a white container)
                  if (!isLast)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(
                        height: 1,
                        thickness: 1,
                        color: Colors.grey[300],
                      ),
                    ),
                ],
              );
            }),
            // Drinks section for special packs
            if (drinkCounts.isNotEmpty ||
                freeDrinkQuantities.isNotEmpty ||
                paidDrinkQuantities.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _buildDetailRow(
                  l10n.drinks,
                  _formatDrinksFromCounts(
                    drinkCounts,
                    drinkNamesById,
                    drinkPricesById,
                    isFreeById,
                    context,
                    freeQuantities: freeDrinkQuantities.isNotEmpty
                        ? freeDrinkQuantities
                        : null,
                    paidQuantities: paidDrinkQuantities.isNotEmpty
                        ? paidDrinkQuantities
                        : null,
                  ),
                  context,
                ),
              ),
            // Unified price for all items at the bottom
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (first.restaurantName != null) ...[
                  Expanded(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.restaurant,
                            size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            first.restaurantName!,
                            style: GoogleFonts.poppins(
                              fontSize: ResponsiveSizing.fontSize(12, context),
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: isRTL ? TextAlign.right : TextAlign.left,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ] else
                  const Spacer(),
                Text(
                  '${l10n.total}:',
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveSizing.fontSize(16, context),
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  PriceFormatter.formatWithSettings(
                      context,
                      group
                          .fold<double>(
                              0.0, (sum, item) => sum + item.totalPrice)
                          .toString()),
                  style: GoogleFonts.poppins(
                    fontSize: ResponsiveSizing.fontSize(16, context),
                    fontWeight: FontWeight.bold,
                    color: Colors.orange[600],
                  ),
                ),
              ],
            ),
          ] else ...[
            // ✅ FIX: Regular items (LTO and normal): unified display like special packs
            // Show all items in one container without white separations
            ...group.asMap().entries.map((entry) {
              final index = entry.key;
              final ci = entry.value;
              final isLast = index == group.length - 1;

              return Column(
                crossAxisAlignment:
                    isRTL ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // Item details without white container
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: isRTL
                              ? CrossAxisAlignment.end
                              : CrossAxisAlignment.start,
                          children: [
                            // Variant and size
                            Text(
                              [
                                _getVariantText(ci.customizations ?? {},
                                    quantity: ci.quantity),
                                _getSizeText(ci.customizations ?? {},
                                    quantity: ci.quantity)
                              ].where((t) => t.trim().isNotEmpty).join(', '),
                              style: GoogleFonts.poppins(
                                fontSize:
                                    ResponsiveSizing.fontSize(14, context),
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            // Regular items: show supplements
                            if (_hasSupplements(ci.customizations)) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${l10n.supplements}: ${_getSupplementsText(ci.customizations ?? {})}',
                                style: GoogleFonts.poppins(
                                  fontSize:
                                      ResponsiveSizing.fontSize(12, context),
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                            // Regular items: show ingredient preferences
                            if (_hasIngredientPreferences(ci.customizations)) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${l10n.ingredients}: ${_getIngredientPreferencesText(ci.customizations ?? {})}',
                                style: GoogleFonts.poppins(
                                  fontSize:
                                      ResponsiveSizing.fontSize(12, context),
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                            // Removed ingredients
                            Builder(
                              builder: (context) {
                                final removedIngredients = ci.customizations?['removed_ingredients'] as List?;
                                if (removedIngredients != null &&
                                    removedIngredients.isNotEmpty) {
                                  final removedText = removedIngredients
                                      .where((ing) => ing.toString().trim().isNotEmpty)
                                      .join(', ');
                                  if (removedText.isNotEmpty) {
                                    return Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        'Removed: $removedText',
                                        style: GoogleFonts.poppins(
                                          fontSize:
                                              ResponsiveSizing.fontSize(12, context),
                                          color: Colors.grey[700],
                                        ),
                                      ),
                                    );
                                  }
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ],
                        ),
                      ),
                      // Price only (no individual delete button for regular items)
                      Text(
                        PriceFormatter.formatWithSettings(
                            context, ci.totalPrice.toString()),
                        style: GoogleFonts.poppins(
                          fontSize:
                              ResponsiveSizing.fontSize(14, context),
                          fontWeight: FontWeight.w600,
                          color: Colors.orange[600],
                        ),
                      ),
                    ],
                  ),
                  // Divider between items (not a white container)
                  if (!isLast)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Divider(
                        height: 1,
                        color: Colors.grey[300],
                      ),
                    ),
                ],
              );
            }).toList(),
            // Drinks section for regular items
            if (drinkCounts.isNotEmpty ||
                freeDrinkQuantities.isNotEmpty ||
                paidDrinkQuantities.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _buildDetailRow(
                  l10n.drinks,
                  _formatDrinksFromCounts(
                    drinkCounts,
                    drinkNamesById,
                    drinkPricesById,
                    isFreeById,
                    context,
                    freeQuantities: freeDrinkQuantities.isNotEmpty
                        ? freeDrinkQuantities
                        : null,
                    paidQuantities: paidDrinkQuantities.isNotEmpty
                        ? paidDrinkQuantities
                        : null,
                  ),
                  context,
                ),
              ),
            // Total price for regular items group
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Row(
              textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Restaurant name with icon (if available)
                if (first.restaurantName != null)
                  Expanded(
                    child: Row(
                      textDirection:
                          isRTL ? TextDirection.rtl : TextDirection.ltr,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.restaurant,
                            size: 14, color: Colors.grey[600]),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            first.restaurantName!,
                            style: GoogleFonts.poppins(
                              fontSize: ResponsiveSizing.fontSize(12, context),
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: isRTL ? TextAlign.right : TextAlign.left,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  const Spacer(),
                // Total label and price
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Total:',
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveSizing.fontSize(16, context),
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      PriceFormatter.formatWithSettings(
                        context,
                        group
                            .fold<double>(
                              0.0,
                              (sum, item) => sum + item.totalPrice,
                            )
                            .toString(),
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: ResponsiveSizing.fontSize(18, context),
                        fontWeight: FontWeight.bold,
                        color: Colors.orange[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
            // ✅ FIX: Global delete button for regular items (LTO and normal)
            // Single delete button that removes the entire order
            const SizedBox(height: 12),
            Row(
              textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Material(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(8),
                      onTap: () {
                        final cartProvider =
                            Provider.of<CartProvider>(context, listen: false);
                        _showRemoveGroupDialog(context, group, cartProvider);
                      },
                      child: Icon(
                        Icons.delete,
                        size: 20,
                        color: Colors.red[600],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _formatDrinksFromCounts(
    Map<String, int> counts,
    Map<String, String> drinkNamesById,
    Map<String, double> drinkPricesById,
    Map<String, bool> isFreeById,
    BuildContext context, {
    Map<String, int>? freeQuantities,
    Map<String, int>? paidQuantities,
  }) {
    if (counts.isEmpty &&
        (freeQuantities == null || freeQuantities.isEmpty) &&
        (paidQuantities == null || paidQuantities.isEmpty)) {
      return '';
    }

    // If separate free and paid quantities are provided, use them directly
    if (freeQuantities != null || paidQuantities != null) {
      final freeDrinks = <MapEntry<String, int>>[];
      final paidDrinks = <MapEntry<String, int>>[];

      // Add free drinks
      (freeQuantities ?? {}).forEach((id, qty) {
        if (id.isNotEmpty && qty > 0) {
          freeDrinks.add(MapEntry(id, qty));
        }
      });

      // Add paid drinks
      (paidQuantities ?? {}).forEach((id, qty) {
        if (id.isNotEmpty && qty > 0) {
          paidDrinks.add(MapEntry(id, qty));
        }
      });

      // Format free drinks with badge
      final l10n = AppLocalizations.of(context)!;
      final freeSection = freeDrinks.map((entry) {
        final id = entry.key;
        final qty = entry.value;
        final drinkName = drinkNamesById[id] ?? id;
        return '$drinkName x$qty 🎁 ${l10n.free}';
      }).join('\n');

      // Format paid drinks with prices
      final paidSection = paidDrinks.map((entry) {
        final id = entry.key;
        final qty = entry.value;
        final drinkName = drinkNamesById[id] ?? id;
        final price = drinkPricesById[id] ?? 0.0;
        final totalPrice = price * qty;
        return '$drinkName x$qty (+${PriceFormatter.formatWithSettings(context, totalPrice.toString())})';
      }).join('\n');

      // Return formatted string with proper grouping
      if (freeDrinks.isNotEmpty && paidDrinks.isNotEmpty) {
        return '$freeSection\n$paidSection';
      } else if (freeDrinks.isNotEmpty) {
        return freeSection;
      } else if (paidDrinks.isNotEmpty) {
        return paidSection;
      }
      return '';
    }

    // Fallback: Use counts and isFreeById (for backward compatibility)
    // Separate free and paid drinks
    final freeDrinks = <MapEntry<String, int>>[];
    final paidDrinks = <MapEntry<String, int>>[];

    counts.forEach((id, qty) {
      if (id.isNotEmpty && qty > 0) {
        final isFree = isFreeById[id] ?? false;
        if (isFree) {
          freeDrinks.add(MapEntry(id, qty));
        } else {
          paidDrinks.add(MapEntry(id, qty));
        }
      }
    });

    // Format free drinks with badge
    final l10n = AppLocalizations.of(context)!;
    final freeSection = freeDrinks.map((entry) {
      final id = entry.key;
      final qty = entry.value;
      final drinkName = drinkNamesById[id] ?? id;
      return '$drinkName x$qty 🎁 ${l10n.free}';
    }).join('\n');

    // Format paid drinks with prices
    final paidSection = paidDrinks.map((entry) {
      final id = entry.key;
      final qty = entry.value;
      final drinkName = drinkNamesById[id] ?? id;
      final price = drinkPricesById[id] ?? 0.0;
      final totalPrice = price * qty;
      return '$drinkName x$qty (+${PriceFormatter.formatWithSettings(context, totalPrice.toString())})';
    }).join('\n');

    // Return formatted string with proper grouping
    // If both free and paid drinks exist, separate them for clarity
    if (freeDrinks.isNotEmpty && paidDrinks.isNotEmpty) {
      return '$freeSection\n$paidSection';
    } else if (freeDrinks.isNotEmpty) {
      return freeSection;
    } else if (paidDrinks.isNotEmpty) {
      return paidSection;
    }

    return '';
  }

  Widget _buildDetailRow(String label, String value, BuildContext context) {
    if (value.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context)!;
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isRTL) ...[
            SizedBox(
              width: 96,
              child: Text(
                '$label:',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Builder(
                builder: (_) {
                  final singleLine = label == l10n.supplements;
                  return Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                    maxLines: singleLine ? 1 : null,
                    overflow: singleLine
                        ? TextOverflow.ellipsis
                        : TextOverflow.visible,
                    softWrap: !singleLine,
                    textAlign: TextAlign.left,
                    textDirection: TextDirection.ltr,
                  );
                },
              ),
            ),
          ] else ...[
            SizedBox(
              width: 96,
              child: Text(
                '$label:',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                textDirection: TextDirection.ltr,
              ),
            ),
            Expanded(
              child: Builder(
                builder: (_) {
                  final singleLine = label == l10n.supplements;
                  return Text(
                    value,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                    maxLines: singleLine ? 1 : null,
                    overflow: singleLine
                        ? TextOverflow.ellipsis
                        : TextOverflow.visible,
                    softWrap: !singleLine,
                    textDirection: TextDirection.ltr,
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPriceSummary(BuildContext context, CartProvider cartProvider) {
    final subtotal = cartProvider.subtotal;
    final discountAmount = cartProvider.discountAmount;
    final subtotalAfterDiscount = subtotal - discountAmount;
    final deliveryFee = cartProvider.deliveryFee;
    final serviceFee = cartProvider.serviceFee;
    final total = cartProvider.totalOrderAmount;

    return Column(
      children: [
        _buildPriceRow('Subtotal', subtotal),
        if (discountAmount > 0) ...[
          _buildPriceRow('Discount', -discountAmount, isDiscount: true),
          _buildPriceRow('Subtotal after discount', subtotalAfterDiscount),
        ],
        _buildPriceRow('Delivery Fee', deliveryFee),
        _buildPriceRow('Service Fee', serviceFee),
        const Divider(height: 16),
        _buildPriceRow('Total', total, isTotal: true),
      ],
    );
  }

  Widget _buildPriceRow(String label, double amount,
      {bool isTotal = false, bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.poppins(
              fontSize: isTotal ? 16 : 14,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
              color: isTotal ? Colors.black87 : Colors.grey[600],
            ),
          ),
          Text(
            '\$${amount.toStringAsFixed(2)}',
            style: GoogleFonts.poppins(
              fontSize: isTotal ? 18 : 14,
              fontWeight: FontWeight.bold,
              color: isTotal
                  ? Colors.orange[600]
                  : isDiscount
                      ? Colors.green[600]
                      : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods for handling edit and remove actions
  void _editOrderItem(BuildContext context, CartItem cartItem) {
    debugPrint(
        '🛒 OrderDetailsSummary: _editOrderItem called for ${cartItem.name}');
    debugPrint(
        '🛒 OrderDetailsSummary: CartItem quantity: ${cartItem.quantity}');
    debugPrint('🛒 OrderDetailsSummary: CartItem price: ${cartItem.price}');

    // Validate cart item data
    if (!_validateCartItemData(cartItem)) {
      final l10n = AppLocalizations.of(context)!;
      _showErrorMessage(context, l10n.invalidCartItemData);
      return;
    }

    // ✅ FIX: Extract actual menu item ID from customizations (not cart item ID)
    final menuItemId = cartItem.customizations?['menu_item_id'] as String?;
    final restaurantId = cartItem.customizations?['restaurant_id'] as String?;

    if (menuItemId == null || menuItemId.isEmpty) {
      debugPrint('❌ OrderDetailsSummary: No menu_item_id in customizations');
      _showErrorMessage(context, 'Cannot edit: Missing menu item information');
      return;
    }

    debugPrint('🛒 OrderDetailsSummary: Extracted menu_item_id: $menuItemId');
    debugPrint(
        '🛒 OrderDetailsSummary: Extracted restaurant_id: $restaurantId');

    // Create a minimal MenuItem from CartItem data with correct menu item ID
    final menuItem = MenuItem(
      id: menuItemId, // ✅ FIX: Use actual menu item ID from customizations
      restaurantId: restaurantId ?? cartItem.restaurantName ?? '',
      restaurantName: cartItem.restaurantName,
      name: cartItem.name,
      description: 'Edit your order item',
      image: cartItem.image ?? '',
      price: cartItem.price,
      category: cartItem.customizations?['is_special_pack'] == true
          ? 'Special Pack'
          : 'Order Item',
      cuisineTypeId: null,
      categoryId: null,
      cuisineType: null,
      categoryObj: null,
      isAvailable: true,
      isFeatured: false,
      preparationTime: 15,
      rating: 4.5,
      reviewCount: 0,
      mainIngredients: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Create a minimal Restaurant object with correct restaurant ID
    final restaurant = Restaurant(
      id: restaurantId ?? 'current_restaurant',
      ownerId: 'current_owner',
      name: cartItem.restaurantName ?? 'Restaurant',
      description: 'Restaurant',
      image: null,
      phone: 'Phone',
      addressLine1: 'Address',
      addressLine2: null,
      city: 'City',
      state: 'State',
      postalCode: null,
      latitude: 0.0,
      longitude: 0.0,
      rating: 4.5,
      reviewCount: 0,
      deliveryFee: 2.99,
      minimumOrder: 0.0,
      estimatedDeliveryTime: 30,
      isOpen: true,
      isFeatured: false,
      isVerified: true,
      openingHours: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      wilaya: null,
      logoUrl: null,
    );

    debugPrint(
        '🛒 OrderDetailsSummary: Showing MenuItemPopupFactory for ${menuItem.name}');

    // Show the full menu item popup in edit mode
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MenuItemPopupFactory(
        menuItem: menuItem,
        restaurant: restaurant,
        existingCartItem: cartItem,
        onItemAddedToCart: (updatedItem) {
          debugPrint(
              '🛒 OrderDetailsSummary: MenuItemPopupFactory callback called');
          debugPrint(
              '🛒 OrderDetailsSummary: Updated item - quantity: ${updatedItem.quantity}');
          debugPrint(
              '🛒 OrderDetailsSummary: Updated item - unitPrice: ${updatedItem.unitPrice}');
          debugPrint(
              '🛒 OrderDetailsSummary: Updated item - totalPrice: ${updatedItem.totalPrice}');

          // ✅ FIX: For special packs, CartItem.price should be totalPrice / quantity
          // because unitPrice doesn't include pack supplements and drinks
          // For regular items, use unitPrice
          final isSpecialPack =
              updatedItem.customizations?['is_special_pack'] == true;
          final cartItemPrice = isSpecialPack && updatedItem.quantity > 0
              ? updatedItem.totalPrice / updatedItem.quantity
              : updatedItem.unitPrice;

          // Convert OrderItem back to CartItem
          final updatedCartItem = CartItem(
            id: cartItem.id, // Preserve original CartItem ID
            name: updatedItem.menuItem?.name ?? cartItem.name,
            price:
                cartItemPrice, // ✅ FIX: Use calculated price (totalPrice/quantity for special packs)
            quantity: updatedItem.quantity,
            image: updatedItem.menuItem?.image ?? cartItem.image,
            restaurantName: cartItem.restaurantName,
            customizations: updatedItem.customizations
                ?.toMap(), // Use toMap() instead of toJson()
            specialInstructions: updatedItem.specialInstructions,
            drinkQuantities:
                cartItem.drinkQuantities, // Preserve drink quantities
          );

          debugPrint('🛒 OrderDetailsSummary: Created updated CartItem');
          debugPrint(
              '🛒 OrderDetailsSummary: CartItem - id: ${updatedCartItem.id}');
          debugPrint(
              '🛒 OrderDetailsSummary: CartItem - name: ${updatedCartItem.name}');
          debugPrint(
              '🛒 OrderDetailsSummary: CartItem - quantity: ${updatedCartItem.quantity}');
          debugPrint(
              '🛒 OrderDetailsSummary: CartItem - price: ${updatedCartItem.price}');
          debugPrint(
              '🛒 OrderDetailsSummary: CartItem - restaurantName: ${updatedCartItem.restaurantName}');
          debugPrint(
              '🛒 OrderDetailsSummary: CartItem - customizations: ${updatedCartItem.customizations}');
          debugPrint(
              '🛒 OrderDetailsSummary: CartItem - specialInstructions: ${updatedCartItem.specialInstructions}');
          debugPrint(
              '🛒 OrderDetailsSummary: CartItem - drinkQuantities: ${updatedCartItem.drinkQuantities}');

          // Compare original vs updated
          debugPrint(
              '🛒 OrderDetailsSummary: Original CartItem - id: ${cartItem.id}');
          debugPrint(
              '🛒 OrderDetailsSummary: Original CartItem - name: ${cartItem.name}');
          debugPrint(
              '🛒 OrderDetailsSummary: Original CartItem - quantity: ${cartItem.quantity}');
          debugPrint(
              '🛒 OrderDetailsSummary: Original CartItem - price: ${cartItem.price}');
          debugPrint(
              '🛒 OrderDetailsSummary: Original CartItem - customizations: ${cartItem.customizations}');

          // ✅ FIX: Don't update cart here - EditOrderBridge already updated it
          // The callback is just for notification/UI refresh
          // Only update if customizations are not null (fallback for legacy flow)
          if (updatedCartItem.customizations != null) {
            try {
              final cartProvider =
                  Provider.of<CartProvider>(context, listen: false);
              debugPrint('🛒 OrderDetailsSummary: Got CartProvider');
              debugPrint(
                  '🛒 OrderDetailsSummary: Cart items before update: ${cartProvider.items.length}');
              debugPrint(
                  '🛒 OrderDetailsSummary: Updating item with ID: ${cartItem.id}');

              // Check if item still exists (might have been updated by EditOrderBridge)
              final existingItem = cartProvider.items.firstWhere(
                (item) => item.id == cartItem.id,
                orElse: () => updatedCartItem,
              );

              // Only update if the item was not already updated by EditOrderBridge
              if (existingItem.customizations == null ||
                  existingItem.customizations!.isEmpty) {
                cartProvider.updateCartItem(cartItem.id, updatedCartItem);
                debugPrint('🛒 OrderDetailsSummary: Cart updated via callback');
              } else {
                debugPrint('🛒 OrderDetailsSummary: Cart already updated by EditOrderBridge, skipping');
              }

              debugPrint(
                  '🛒 OrderDetailsSummary: Cart items after update: ${cartProvider.items.length}');
              debugPrint('🛒 OrderDetailsSummary: Cart updated successfully');
            } catch (e) {
              debugPrint('🛒 OrderDetailsSummary: Error updating cart: $e');
            }
          } else {
            debugPrint('🛒 OrderDetailsSummary: Skipping cart update - customizations are null');
            debugPrint('🛒 OrderDetailsSummary: Cart was already updated by EditOrderBridge');
          }

          // ✅ FIX: Don't close popup here - it's already closed by EditOrderBridge
          // The popup should already be closed, so just return
          debugPrint('🛒 OrderDetailsSummary: Callback complete (popup already closed)');
        },
        onDataChanged: () {
          // Note: Order details summary doesn't need to refresh external data
          // The review update is handled automatically by the Supabase triggers
        },
      ),
    );
  }

  void _showRemoveDialog(
      BuildContext context, CartItem cartItem, CartProvider cartProvider) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.removeItem,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          '${l10n.removeItemConfirmation} "${cartItem.name}" ${l10n.fromYourOrder}',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.cancel,
              style: GoogleFonts.poppins(),
            ),
          ),
          TextButton(
            onPressed: () {
              cartProvider.removeFromCart(cartItem.id);
              Navigator.pop(context);
            },
            child: Text(
              l10n.remove,
              style: GoogleFonts.poppins(
                  color: Colors.red[600], fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  /// ✅ FIX: Show dialog to remove entire order group (for regular items)
  void _showRemoveGroupDialog(
      BuildContext context, List<CartItem> group, CartProvider cartProvider) {
    final l10n = AppLocalizations.of(context)!;
    final first = group.first;
    final itemName = _getBaseMenuItemName(first.name);
    final totalItems = group.length;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.removeItem,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          totalItems == 1
              ? '${l10n.removeItemConfirmation} "$itemName" ${l10n.fromYourOrder}'
              : '${l10n.removeItemConfirmation} all $totalItems items of "$itemName" ${l10n.fromYourOrder}',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.cancel,
              style: GoogleFonts.poppins(),
            ),
          ),
          TextButton(
            onPressed: () {
              // Remove all items in the group
              // The removeFromCart method will handle paid drinks recalculation
              for (final item in group) {
                cartProvider.removeFromCart(item.id);
              }
              Navigator.pop(context);
            },
            child: Text(
              l10n.remove,
              style: GoogleFonts.poppins(
                  color: Colors.red[600], fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to check if item has any customizations
  bool _hasCustomizations(CartItem cartItem) {
    return (cartItem.customizations != null &&
            cartItem.customizations!.isNotEmpty) ||
        (cartItem.drinkQuantities != null &&
            cartItem.drinkQuantities!.isNotEmpty) ||
        (cartItem.specialInstructions != null &&
            cartItem.specialInstructions!.isNotEmpty);
  }

  // Helper methods for extracting customization details
  String _getVariantText(Map<String, dynamic> customizations, {int? quantity}) {
    final variant = customizations['variant'] as Map<String, dynamic>?;
    final name = (variant?['name'] ?? '').toString();

    // If there is no size/portion, and we have a quantity, prefix with "Nx"
    final hasSize = (customizations['size']?.toString().isNotEmpty == true) ||
        (customizations['portion']?.toString().isNotEmpty == true);

    if (!hasSize && (quantity != null) && quantity > 1 && name.isNotEmpty) {
      return '${quantity}x $name';
    }
    return name;
  }

  String _getSizeText(Map<String, dynamic> customizations, {int? quantity}) {
    final size = customizations['size'] as String?;
    final portion = customizations['portion'] as String?; // ignored for display
    final base = (size ?? portion ?? '').toString();
    if (quantity != null && quantity > 0 && base.isNotEmpty) {
      return '$base × $quantity';
    }
    return base;
  }

  bool _hasSupplements(Map<String, dynamic>? customizations) {
    if (customizations == null) return false;
    final supplements = customizations['supplements'] as List?;
    return supplements != null && supplements.isNotEmpty;
  }

  String _getSupplementsText(Map<String, dynamic> customizations) {
    final supplements = customizations['supplements'] as List?;
    if (supplements == null || supplements.isEmpty) return '';

    return supplements
        .map((s) {
          if (s is Map<String, dynamic>) {
            return s['name'] ?? '';
          }
          return s.toString();
        })
        .where((name) => name.isNotEmpty)
        .join(', ');
  }

  /// ✅ FIX: Get only global supplements with prices for special packs
  /// Global supplements have IDs starting with "global_"
  String _getGlobalSupplementsText(
      Map<String, dynamic> customizations, BuildContext context) {
    final supplements = customizations['supplements'] as List?;
    if (supplements == null || supplements.isEmpty) return '';

    // Filter to only global supplements (IDs start with "global_")
    final globalSupplements = supplements
        .where((s) {
          if (s is Map<String, dynamic>) {
            final id = s['id']?.toString() ?? '';
            return id.startsWith('global_');
          }
          return false;
        })
        .map((s) {
          if (s is Map<String, dynamic>) {
            final name = s['name']?.toString() ?? '';
            final price = (s['price'] as num?)?.toDouble() ?? 0.0;
            if (name.isNotEmpty) {
              if (price > 0) {
                return '$name (+${PriceFormatter.formatWithSettings(context, price.toString())})';
              } else {
                return name;
              }
            }
          }
          return '';
        })
        .where((text) => text.isNotEmpty)
        .toList();

    return globalSupplements.join(', ');
  }

  bool _hasDrinks(CartItem cartItem) {
    if (cartItem.drinkQuantities?.isNotEmpty == true) return true;
    final drinks = cartItem.customizations?['drinks'];
    return drinks is List && drinks.isNotEmpty;
  }

  String _formatDrinks(CartItem cartItem, BuildContext context) {
    final quantities = cartItem.drinkQuantities ?? const <String, int>{};
    final drinksList = cartItem.customizations?['drinks'];
    final nameById = <String, String>{};
    final sizeById = <String, String>{};
    final priceById = <String, double>{};

    // Build separate quantity maps for free and paid drinks
    // This handles the case where the same drink appears as both free and paid
    final freeDrinkQuantities = <String, int>{};
    final paidDrinkQuantities = <String, int>{};

    // Detect item type
    final isLTO = cartItem.customizations?['is_limited_offer'] == true ||
        cartItem.customizations?['menu_item']?['is_limited_offer'] == true;
    final isSpecialPack = cartItem.customizations?['is_special_pack'] == true;

    // ✅ FIX: First, build name map from drinks list
    if (drinksList is List) {
      for (final d in drinksList) {
        if (d is Map) {
          final id = d['id']?.toString() ?? '';
          if (id.isEmpty) continue;
          final name = (d['name']?.toString().isNotEmpty == true)
              ? d['name'].toString()
              : id;
          if (!nameById.containsKey(id)) {
            nameById[id] = name;
          }
        }
      }
    }

    // ✅ FIX: Resolve drink names for drinks in free_drink_quantities or paid_drink_quantities
    // that might not be in the drinks list yet (e.g., calculated from pricing)
    final drinkIdsNeedingNames = <String>{};

    // Collect IDs from free_drink_quantities
    final freeQuantities = cartItem.customizations?['free_drink_quantities'] as Map<String, dynamic>?;
    freeQuantities?.forEach((id, qty) {
      if (id.isNotEmpty && !nameById.containsKey(id)) {
        drinkIdsNeedingNames.add(id);
      }
    });

    // Collect IDs from paid_drink_quantities
    final paidQuantities = cartItem.customizations?['paid_drink_quantities'] as Map<String, dynamic>?;
    paidQuantities?.forEach((id, qty) {
      if (id.isNotEmpty && !nameById.containsKey(id)) {
        drinkIdsNeedingNames.add(id);
      }
    });

    // Collect IDs from drinkQuantities
    quantities.forEach((id, qty) {
      if (id.isNotEmpty && !nameById.containsKey(id)) {
        drinkIdsNeedingNames.add(id);
      }
    });

    // Try to resolve names from drinks list
    for (final drinkId in drinkIdsNeedingNames) {
      if (drinksList is List) {
        for (final d in drinksList) {
          if (d is Map) {
            final id = d['id']?.toString() ?? '';
            if (id == drinkId) {
              final drinkName = (d['name']?.toString().isNotEmpty == true)
                  ? d['name'].toString()
                  : null;
              if (drinkName != null && drinkName != drinkId) {
                nameById[drinkId] = drinkName;
                break;
              }
            }
          }
        }
      }
    }

    // Process drinks list to build free/paid quantities separately
    // When same drink appears as both free and paid, we need to count them separately
    // The drinks list has separate entries for free vs paid drinks
    if (drinksList is List) {
      // First pass: build maps of free vs paid drink entries
      final freeDrinkEntries = <String, Map>{};
      final paidDrinkEntries = <String, Map>{};

      for (final d in drinksList) {
        if (d is Map) {
          final id = d['id']?.toString() ?? '';
          if (id.isEmpty) continue;

          // ✅ FIX: Ensure name is in nameById (might have been added above)
          final name = (d['name']?.toString().isNotEmpty == true)
              ? d['name'].toString()
              : (nameById[id] ?? id);
          if (!nameById.containsKey(id)) {
            nameById[id] = name;
          }

          // Extract price
          // ✅ FIX: For paid drinks, ensure we use the correct price (not 0)
          final drinkPrice = (d['price'] as num?)?.toDouble() ?? 0.0;

          // Check if this drink is a paid drink (will be checked later from paid_drink_quantities)
          // For now, prioritize non-zero prices over zero prices
          if (!priceById.containsKey(id)) {
            priceById[id] = drinkPrice;
          } else if (drinkPrice > 0 && priceById[id] == 0.0) {
            // ✅ FIX: If we have a 0 price but encounter a non-zero price, overwrite it
            // This handles cases where a drink appears as free first, then as paid
            priceById[id] = drinkPrice;
          } else if (drinkPrice > priceById[id]!) {
            // If new price is greater, use it
            priceById[id] = drinkPrice;
          }

          // Determine if drink is free
          bool isFree = false;
          if (d['is_free'] == true || d['isFree'] == true) {
            isFree = true;
          } else if (drinkPrice == 0.0) {
            isFree = true;
          } else if (isLTO || isSpecialPack) {
            final freeDrinksList1 =
                cartItem.customizations?['free_drinks_list'] as List?;
            if (freeDrinksList1 != null && freeDrinksList1.contains(id)) {
              isFree = true;
            }
            final pricing = cartItem.customizations?['pricing'] as Map?;
            if (pricing != null) {
              final freeDrinksList2 = pricing['free_drinks_list'] as List?;
              if (freeDrinksList2 != null && freeDrinksList2.contains(id)) {
                isFree = true;
              }
            }
            final menuItem = cartItem.customizations?['menu_item'] as Map?;
            if (menuItem != null) {
              final freeDrinksList3 = menuItem['free_drinks_list'] as List?;
              if (freeDrinksList3 != null && freeDrinksList3.contains(id)) {
                isFree = true;
              }
            }
            final variant = cartItem.customizations?['variant'] as Map?;
            if (variant != null) {
              final variantPricing =
                  cartItem.customizations?['variant_pricing'] as Map?;
              if (variantPricing != null) {
                final variantFreeDrinks =
                    variantPricing['free_drinks_list'] as List?;
                if (variantFreeDrinks != null &&
                    variantFreeDrinks.contains(id)) {
                  isFree = true;
                }
              }
            }
          }

          // Extract size
          String size = '';
          if (d['size'] != null) {
            size = d['size'].toString();
          } else if (d['portion'] != null) {
            size = d['portion'].toString();
          } else if (d['menu_item_pricing'] is List) {
            final rows = (d['menu_item_pricing'] as List).cast<Map?>();
            Map? def = rows.firstWhere((p) => p?['is_default'] == true,
                orElse: () => null);
            def ??= rows.isNotEmpty ? rows.first : null;
            if (def != null && def['size'] != null) {
              size = def['size'].toString();
            }
          } else if (d['pricing'] is Map && (d['pricing']['size'] != null)) {
            size = d['pricing']['size'].toString();
          } else if (name.contains('(') && name.contains(')')) {
            final match = RegExp(r"\(([^)]+)\)").firstMatch(name);
            if (match != null) size = match.group(1) ?? '';
          } else {
            final cap = RegExp(r"(\d+(?:[\.,]\d+)?\s*(?:ml|l|cl))",
                    caseSensitive: false)
                .firstMatch(name);
            if (cap != null) size = cap.group(0) ?? '';
          }
          if (size.isNotEmpty) sizeById[id] = size;

          // Store entry in appropriate map
          if (isFree) {
            freeDrinkEntries[id] = d;
          } else {
            paidDrinkEntries[id] = d;
          }
        }
      }

      // Second pass: Use quantities from drink_quantities map
      // But prefer separate free_drink_quantities and paid_drink_quantities if available
      final freeQuantitiesFromCustomizations = cartItem
          .customizations?['free_drink_quantities'] as Map<String, dynamic>?;
      final paidQuantitiesFromCustomizations = cartItem
          .customizations?['paid_drink_quantities'] as Map<String, dynamic>?;

      // If separate quantities are available, use them (they preserve free quantities)
      if (freeQuantitiesFromCustomizations != null ||
          paidQuantitiesFromCustomizations != null) {
        freeQuantitiesFromCustomizations?.forEach((id, qty) {
          if (id.isNotEmpty) {
            final q = qty is int ? qty : int.tryParse(qty.toString()) ?? 0;
            if (q > 0) freeDrinkQuantities[id] = q;
          }
        });
        paidQuantitiesFromCustomizations?.forEach((id, qty) {
          if (id.isNotEmpty) {
            final q = qty is int ? qty : int.tryParse(qty.toString()) ?? 0;
            if (q > 0) {
              paidDrinkQuantities[id] = q;
              // ✅ FIX: Ensure paid drinks have correct price in priceById
              // If price is currently 0, try to find it from drinks list
              if ((priceById[id] ?? 0.0) == 0.0) {
                // First, check if we have a paid drink entry (from first pass)
                if (paidDrinkEntries.containsKey(id)) {
                  final paidEntry = paidDrinkEntries[id];
                  if (paidEntry is Map) {
                    final drinkPrice = (paidEntry['price'] as num?)?.toDouble() ?? 0.0;
                    if (drinkPrice > 0) {
                      priceById[id] = drinkPrice;
                    }
                  }
                }

                // If still 0, look for this drink in the drinks list with a non-zero price
                // This handles cases where the drink appears multiple times (free and paid)
                if ((priceById[id] ?? 0.0) == 0.0) {
                  for (final d in drinksList) {
                    if (d is Map) {
                      final drinkId = d['id']?.toString() ?? '';
                      if (drinkId == id) {
                        final drinkPrice = (d['price'] as num?)?.toDouble() ?? 0.0;
                        // ✅ FIX: For paid drinks, use any entry with price > 0, even if is_free is set
                        // The paid_drink_quantities is the source of truth for whether it's paid
                        if (drinkPrice > 0) {
                          priceById[id] = drinkPrice;
                          break;
                        }
                      }
                    }
                  }
                }
              }
            }
          }
        });
      } else {
        // Fallback: Use merged drink_quantities and split based on entries
        quantities.forEach((id, totalQty) {
          if (id.isNotEmpty && totalQty > 0) {
            final hasFreeEntry = freeDrinkEntries.containsKey(id);
            final hasPaidEntry = paidDrinkEntries.containsKey(id);

            if (hasFreeEntry && hasPaidEntry) {
              // Same drink appears as both free and paid
              // Since drink_quantities only has merged quantity (paid overwrites free),
              // we can only show paid quantity reliably
              paidDrinkQuantities[id] = totalQty;
              // Free quantity was lost in merge, so we can't display it
            } else if (hasFreeEntry) {
              // Only free entry exists
              freeDrinkQuantities[id] = totalQty;
            } else if (hasPaidEntry) {
              // Only paid entry exists
              paidDrinkQuantities[id] = totalQty;
            } else {
              // No entry in drinks list, try to infer from price
              final drinkPrice = priceById[id] ?? 0.0;
              bool isFree = drinkPrice == 0.0;
              if (isLTO || isSpecialPack) {
                final freeDrinksList1 =
                    cartItem.customizations?['free_drinks_list'] as List?;
                if (freeDrinksList1 != null && freeDrinksList1.contains(id)) {
                  isFree = true;
                }
              }
              if (isFree) {
                freeDrinkQuantities[id] = totalQty;
              } else {
                paidDrinkQuantities[id] = totalQty;
              }
            }
          }
        });
      }
    } else {
      // No drinks list, use quantities map and infer from price
      quantities.forEach((id, qty) {
        if (id.isNotEmpty && qty > 0) {
          final drinkPrice = priceById[id] ?? 0.0;
          bool isFree = drinkPrice == 0.0;
          if (isLTO || isSpecialPack) {
            final freeDrinksList1 =
                cartItem.customizations?['free_drinks_list'] as List?;
            if (freeDrinksList1 != null && freeDrinksList1.contains(id)) {
              isFree = true;
            }
          }
          if (isFree) {
            freeDrinkQuantities[id] = qty;
          } else {
            paidDrinkQuantities[id] = qty;
          }
        }
      });
    }

    // Build free and paid drink lists
    final freeDrinks =
        freeDrinkQuantities.entries.where((e) => e.value > 0).toList();
    final paidDrinks =
        paidDrinkQuantities.entries.where((e) => e.value > 0).toList();

    // Format free drinks with badge - show first, grouped together
    final l10n = AppLocalizations.of(context)!;
    final freeSection = freeDrinks.map((entry) {
      final id = entry.key;
      final qty = entry.value;
      final baseName = nameById[id] ?? id;
      final size = sizeById[id];
      final display =
          (size != null && size.isNotEmpty) ? '$baseName ($size)' : baseName;
      return '$display x$qty 🎁 ${l10n.free}';
    }).join('\n');

    // Format paid drinks with prices - show after free drinks
    final paidSection = paidDrinks.map((entry) {
      final id = entry.key;
      final qty = entry.value;
      final baseName = nameById[id] ?? id;
      final size = sizeById[id];
      final price = priceById[id] ?? 0.0;
      final display =
          (size != null && size.isNotEmpty) ? '$baseName ($size)' : baseName;
      final totalPrice = price * qty;
      return '$display x$qty (+${PriceFormatter.formatWithSettings(context, totalPrice.toString())})';
    }).join('\n');

    // Return formatted string with proper grouping
    // If both free and paid drinks exist, separate them for clarity
    if (freeDrinks.isNotEmpty && paidDrinks.isNotEmpty) {
      return '$freeSection\n$paidSection';
    } else if (freeDrinks.isNotEmpty) {
      return freeSection;
    } else if (paidDrinks.isNotEmpty) {
      return paidSection;
    }

    return '';
  }

  bool _hasIngredientPreferences(Map<String, dynamic>? customizations) {
    if (customizations == null) return false;
    final preferences = customizations['ingredient_preferences'] as Map?;
    return preferences != null && preferences.isNotEmpty;
  }

  String _getIngredientPreferencesText(Map<String, dynamic> customizations) {
    final preferences = customizations['ingredient_preferences'] as Map?;
    if (preferences == null || preferences.isEmpty) return '';

    final parts = <String>[];
    preferences.forEach((ingredient, preference) {
      if (preference.toString().isNotEmpty) {
        parts.add('$ingredient: ${preference.toString().split('.').last}');
      }
    });
    return parts.join(', ');
  }

  // Data validation methods
  bool _validateCartItemData(CartItem cartItem) {
    if (cartItem.name.isEmpty) {
      debugPrint('🚨 CartItem validation failed: Empty name');
      return false;
    }

    if (cartItem.price <= 0) {
      debugPrint(
          '🚨 CartItem validation failed: Invalid price ${cartItem.price}');
      return false;
    }

    if (cartItem.quantity <= 0) {
      debugPrint(
          '🚨 CartItem validation failed: Invalid quantity ${cartItem.quantity}');
      return false;
    }

    if (cartItem.id.isEmpty) {
      debugPrint('🚨 CartItem validation failed: Empty id');
      return false;
    }

    debugPrint('✅ CartItem validation passed: ${cartItem.name}');
    return true;
  }

  void _showErrorMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: GoogleFonts.poppins(),
        ),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Builds pack items with their ingredients and supplements displayed inline
  List<Widget> _buildPackItemsWithIngredients(
      CartItem cartItem, BuildContext context) {
    final widgets = <Widget>[];
    final packSelections = cartItem.customizations!['pack_selections'] as Map?;
    final packIngredientPrefs =
        cartItem.customizations!['pack_ingredient_preferences'] as Map?;
    final packSupplementSelections =
        cartItem.customizations!['pack_supplement_selections'] as Map?;

    debugPrint('🥗 Building pack items with ingredients and supplements:');
    debugPrint('   Pack selections: $packSelections');
    debugPrint('   Pack ingredient prefs: $packIngredientPrefs');
    debugPrint('   Pack supplement selections: $packSupplementSelections');

    if (packSelections == null || packSelections.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return [_buildDetailRow(l10n.itemsLabel, l10n.noItemsSelected, context)];
    }

    // Build each variant with its quantities and ingredients
    packSelections.forEach((variantName, selections) {
      final name = variantName.toString();

      if (selections is Map && selections.isNotEmpty) {
        // Sort by quantity index
        // FIX: Handle both String and int keys (JSON may serialize int keys as strings)
        final sortedEntries = selections.entries.toList()
          ..sort((a, b) {
            final aKey = a.key is int
                ? a.key as int
                : int.tryParse(a.key.toString()) ?? 0;
            final bKey = b.key is int
                ? b.key as int
                : int.tryParse(b.key.toString()) ?? 0;
            return aKey.compareTo(bKey);
          });

        // Group by quantity for items with multiple quantities
        for (final entry in sortedEntries) {
          // FIX: Handle both String and int keys (JSON may serialize int keys as strings)
          final quantityIndex = entry.key is int
              ? entry.key as int
              : int.tryParse(entry.key.toString()) ?? 0;
          final selection = entry.value as String;

          // Build the item text
          final meaningful = selection.trim().isNotEmpty &&
              selection.trim().toLowerCase() != 'not selected';

          String itemText;
          if (sortedEntries.length > 1) {
            // Multiple quantities - show with index
            itemText = meaningful
                ? '$name (${quantityIndex + 1}): $selection'
                : '$name (${quantityIndex + 1})';
          } else {
            // Single quantity
            itemText = meaningful ? '$name: $selection' : name;
          }

          // Check for ingredients for this specific item and quantity
          // Note: quantity index is stored as string in the map
          debugPrint(
              '   Looking for ingredients: [$name][${quantityIndex.toString()}]');
          final ingredientPrefs =
              packIngredientPrefs?[name]?[quantityIndex.toString()] as Map?;
          debugPrint('   Found ingredient prefs: $ingredientPrefs');
          if (ingredientPrefs != null && ingredientPrefs.isNotEmpty) {
            // Has ingredients - format them
            final ingredientParts = <String>[];
            ingredientPrefs.forEach((ingredient, pref) {
              final prefStr = pref.toString();
              if (prefStr == 'wanted') {
                ingredientParts.add('+ $ingredient');
              } else if (prefStr == 'less') {
                ingredientParts.add('~ $ingredient');
              } else if (prefStr == 'none') {
                ingredientParts.add('✗ $ingredient');
              }
            });

            if (ingredientParts.isNotEmpty) {
              itemText += '\n  ${ingredientParts.join(', ')}';
            }
          }

          // Check for supplements for this specific item and quantity
          final supplements = packSupplementSelections?[name]
              ?[quantityIndex.toString()] as List?;
          final supplementPrices =
              cartItem.customizations!['pack_supplement_prices'] as Map?;
          final variantSupplementPrices = supplementPrices?[name] as Map?;
          final quantitySupplementPrices =
              variantSupplementPrices?[quantityIndex.toString()] as Map?;

          if (supplements != null && supplements.isNotEmpty) {
            final supplementParts = <String>[];
            for (final supplement in supplements) {
              final price =
                  quantitySupplementPrices?[supplement] as double? ?? 0.0;
              if (price > 0) {
                supplementParts.add(
                    '+ $supplement (+${PriceFormatter.formatWithSettings(context, price.toString())})');
              } else {
                supplementParts.add('+ $supplement');
              }
            }
            if (supplementParts.isNotEmpty) {
              itemText += '\n  ${supplementParts.join(', ')}';
            }
          }

          widgets.add(_buildDetailRow('', itemText, context));
        }
      } else {
        // No selections - just show the variant name
        widgets.add(_buildDetailRow('', name, context));
      }
    });

    return widgets.isEmpty
        ? [_buildDetailRow('Items', 'No items selected', context)]
        : widgets;
  }

  /// Builds multiple variants display for unified saved orders
  List<Widget> _buildMultipleVariants(List variantsList,
      Map<String, dynamic> customizations, BuildContext context) {
    final widgets = <Widget>[];
    final l10n = AppLocalizations.of(context)!;

    // Get all variants from the list
    for (final variantData in variantsList) {
      final variant = variantData as Map<String, dynamic>?;
      if (variant == null || variant.isEmpty) continue;

      final variantName = (variant['name'] ?? '').toString();
      if (variantName.isEmpty) continue;

      // Build variant text with size if available
      final variantText = variantName;

      // Note: Size information is stored per saved order, not per variant in unified items
      // For unified items, we show variants without individual sizes since sizes are combined
      // The size is shown separately if there's a single size across all variants

      widgets.add(_buildDetailRow('', variantText, context));
    }

    // Show size if available (from unified customizations)
    final size = customizations['size'] as String?;
    final portion = customizations['portion'] as String?;
    if (size != null && size.isNotEmpty) {
      widgets.add(_buildDetailRow(l10n.size, size, context));
    } else if (portion != null && portion.isNotEmpty) {
      widgets.add(_buildDetailRow(l10n.size, portion, context));
    }

    return widgets.isEmpty
        ? [_buildDetailRow('Variants', 'No variants', context)]
        : widgets;
  }

  /// Checks if cart item has global pack ingredients (main ingredients for the pack)
  bool _hasGlobalPackIngredients(Map<String, dynamic>? customizations) {
    // Global pack ingredients are now descriptive only (not customizable)
    // They're displayed from the menu item data in the popup
    // No need to show them separately in cart since they're not customizations
    return false;
  }

  /// Formats global pack ingredients (main ingredients - not preferences)
  String _formatGlobalPackIngredients(Map<String, dynamic> customizations) {
    // Global pack ingredients are no longer customizable preferences
    // They're just informational text shown in the popup
    return '';
  }
}
