import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/menu_item_supplement.dart';
import '../../../utils/price_formatter.dart';

/// Unified supplements container widget for special pack popup and regular items
/// Displays all supplements in a vertical list
/// Format: "Supplement Name (Item Name)" | Price | Select Button (for packs)
/// Format: "Supplement Name" | Price | Select Button (for regular items)
class UnifiedSupplementsContainer extends StatelessWidget {
  /// List of supplements to display (for pack items)
  /// Each entry contains: (variantId, variantName, quantityIndex, supplementName, supplementPrice)
  final List<({
    String variantId,
    String variantName,
    int quantityIndex,
    String supplementName,
    double supplementPrice,
  })>? packSupplements;

  /// Selected supplements map (for pack items)
  /// Format: Map<variantId, Map<quantityIndex, Set<supplementName>>>
  final Map<String, Map<int, Set<String>>>? packSelectedSupplements;

  /// Callback when a supplement is tapped (for pack items)
  final void Function(String variantId, int quantityIndex, String supplementName)?
      onPackSupplementTapped;

  /// List of supplements to display (for regular items)
  final List<MenuItemSupplement>? regularSupplements;

  /// Selected supplements list (for regular items)
  final List<MenuItemSupplement>? regularSelectedSupplements;

  /// Callback when a supplement is tapped (for regular items)
  final void Function(MenuItemSupplement supplement)? onRegularSupplementTapped;

  const UnifiedSupplementsContainer({
    this.packSupplements,
    this.packSelectedSupplements,
    this.onPackSupplementTapped,
    this.regularSupplements,
    this.regularSelectedSupplements,
    this.onRegularSupplementTapped,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Check if we have pack supplements or regular supplements
    final hasPackSupplements = packSupplements != null && packSupplements!.isNotEmpty;
    final hasRegularSupplements = regularSupplements != null && regularSupplements!.isNotEmpty;

    if (!hasPackSupplements && !hasRegularSupplements) {
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
                l10n.addSupplements,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                l10n.optional,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Display pack supplements
          if (hasPackSupplements && packSelectedSupplements != null && onPackSupplementTapped != null)
            ...packSupplements!.asMap().entries.map((entryMap) {
              final index = entryMap.key;
              final entry = entryMap.value;
              // Check if this supplement is selected
              final isSelected = packSelectedSupplements![entry.variantId]
                      ?[entry.quantityIndex]
                      ?.contains(entry.supplementName) ??
                  false;

              final priceText = PriceFormatter.formatWithSettings(
                context,
                entry.supplementPrice.toString(),
              );

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (index > 0) ...[
                    const SizedBox(height: 19),
                    Divider(height: 1, color: Colors.grey[200]),
                    const SizedBox(height: 19),
                  ],
                  Row(
                    children: [
                      // Supplement name with item name in parentheses on the left
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final fullText = '${entry.supplementName} (${entry.variantName})';
                            // Calculate font size to fit 23 characters in available width
                            final targetChars = 23;
                            final baseFontSize = 13.0;
                            final availableWidth = constraints.maxWidth;
                            // Estimate character width (approximate: 0.6 * fontSize for Poppins)
                            final charWidth = baseFontSize * 0.6;
                            final targetWidth = targetChars * charWidth;

                            // Calculate responsive font size
                            double fontSize = baseFontSize;
                            if (availableWidth < targetWidth) {
                              fontSize = (availableWidth / targetChars) / 0.6;
                              fontSize = fontSize.clamp(10.0, 13.0); // Min 10, Max 13
                            }

                            return Text(
                              fullText,
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
                        '+$priceText',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFfc9d2d),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Select button on the right
                      GestureDetector(
                        onTap: () => onPackSupplementTapped!(
                          entry.variantId,
                          entry.quantityIndex,
                          entry.supplementName,
                        ),
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
          // Display regular item supplements
          if (hasRegularSupplements && regularSelectedSupplements != null && onRegularSupplementTapped != null)
            ...regularSupplements!.asMap().entries.map((entryMap) {
              final index = entryMap.key;
              final supp = entryMap.value;
              final isSelected = regularSelectedSupplements!.any((s) =>
                  s.id == supp.id || (s.name == supp.name && s.menuItemId == supp.menuItemId));

              final priceText = PriceFormatter.formatWithSettings(
                context,
                supp.price.toString(),
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
                      // Supplement name on the left
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // Calculate font size to fit 23 characters in available width
                            final targetChars = 23;
                            final baseFontSize = 13.0;
                            final availableWidth = constraints.maxWidth;
                            // Estimate character width (approximate: 0.6 * fontSize for Poppins)
                            final charWidth = baseFontSize * 0.6;
                            final targetWidth = targetChars * charWidth;

                            // Calculate responsive font size
                            double fontSize = baseFontSize;
                            if (availableWidth < targetWidth) {
                              fontSize = (availableWidth / targetChars) / 0.6;
                              fontSize = fontSize.clamp(10.0, 13.0); // Min 10, Max 13
                            }

                            return Text(
                              supp.name,
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
                        '+$priceText',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFfc9d2d),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Select button on the right
                      GestureDetector(
                        onTap: () => onRegularSupplementTapped!(supp),
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
