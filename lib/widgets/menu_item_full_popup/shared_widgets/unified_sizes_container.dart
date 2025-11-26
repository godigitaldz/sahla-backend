import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/menu_item_pricing.dart';
import '../../../utils/price_formatter.dart';

/// Unified sizes container widget for regular items and LTO
/// Displays all size options in a vertical list
/// Format: "Size Name" | Price | Select Button
class UnifiedSizesContainer extends StatelessWidget {
  /// List of pricing options to display
  final List<MenuItemPricing> sizes;

  /// Selected pricing per variant
  /// Format: Map<variantId, MenuItemPricing>
  final Map<String, MenuItemPricing> selectedPricingPerVariant;

  /// Variant ID for this container
  final String variantId;

  /// Callback when a size is tapped
  final void Function(String variantId, MenuItemPricing pricing) onSizeTapped;

  /// Whether size is optional (for LTO items) or required (for regular items)
  final bool isOptional;

  /// Whether to show "+" prefix for price (for LTO items) or not (for regular items)
  final bool showPricePrefix;

  /// Whether to show free drinks icon (for regular items) or not (for LTO items)
  final bool showFreeDrinksIcon;

  const UnifiedSizesContainer({
    required this.sizes,
    required this.selectedPricingPerVariant,
    required this.variantId,
    required this.onSizeTapped,
    this.isOptional = false,
    this.showPricePrefix = false,
    this.showFreeDrinksIcon = true,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (sizes.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                l10n.size,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                isOptional ? l10n.optional : l10n.required,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Display all sizes in vertical list
          ...sizes.asMap().entries.map((entryMap) {
            final index = entryMap.key;
            final pricing = entryMap.value;
            final isSelected = selectedPricingPerVariant[variantId]?.id == pricing.id;

            final priceText = PriceFormatter.formatWithSettings(
              context,
              pricing.price.toString(),
            );

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (index > 0) ...[
                  const SizedBox(height: 12),
                  Divider(height: 1, color: Colors.grey[200]),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    // Size name on the left
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          // Calculate font size to fit 23 characters in available width
                          const targetChars = 23;
                          const baseFontSize = 13.0;
                          final availableWidth = constraints.maxWidth;
                          // Estimate character width (approximate: 0.6 * fontSize for Poppins)
                          const charWidth = baseFontSize * 0.6;
                          const targetWidth = targetChars * charWidth;

                          // Calculate responsive font size
                          double fontSize = baseFontSize;
                          if (availableWidth < targetWidth) {
                            fontSize = (availableWidth / targetChars) / 0.6;
                            fontSize = fontSize.clamp(10.0, 13.0); // Min 10, Max 13
                          }

                          return Text(
                            pricing.size,
                            style: GoogleFonts.poppins(
                              fontSize: fontSize,
                              fontWeight: FontWeight.normal,
                              color: Colors.black87,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Price before select button
                    Text(
                      showPricePrefix ? '+$priceText' : priceText,
                      style: GoogleFonts.poppins(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFfc9d2d),
                      ),
                    ),
                    if (showFreeDrinksIcon && pricing.freeDrinksIncluded) ...[
                      const SizedBox(width: 8),
                      Icon(
                        Icons.local_drink,
                        size: 16,
                        color: Colors.green,
                      ),
                    ],
                    const SizedBox(width: 12),
                    // Select button on the right
                    GestureDetector(
                      onTap: () => onSizeTapped(variantId, pricing),
                      child: Icon(
                        isSelected ? Icons.check : Icons.radio_button_unchecked,
                        size: 24,
                        color: isSelected ? const Color(0xFFd47b00) : Colors.black87,
                      ),
                    ),
                  ],
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}
