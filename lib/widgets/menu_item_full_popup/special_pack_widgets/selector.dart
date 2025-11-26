import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';

/// Main pack selector container widget
class SpecialPackSelector extends StatelessWidget {
  final String packBaseName;
  final bool hasAnyPackIngredients;
  final Widget ingredientLegend;
  final List<Widget> packItems;
  final Widget? unifiedPackItemsOptionsContainer; // ✅ NEW: Unified items and options container
  final bool hasGlobalIngredients;
  final Widget? globalIngredientsSection;
  final Widget? unifiedSupplementsContainer;
  final bool hasFreeDrinks;
  final Widget? freeDrinksSection;
  final Widget? specialNoteField;
  final Widget? quantitySelector;
  final Widget infoContainer;
  final Widget? priceSection; // LTO price section

  const SpecialPackSelector({
    required this.packBaseName,
    required this.hasAnyPackIngredients,
    required this.ingredientLegend,
    required this.packItems,
    required this.hasGlobalIngredients,
    required this.hasFreeDrinks,
    required this.infoContainer,
    this.quantitySelector,
    super.key,
    this.unifiedPackItemsOptionsContainer, // ✅ NEW: Unified items and options container
    this.globalIngredientsSection,
    this.unifiedSupplementsContainer,
    this.freeDrinksSection,
    this.specialNoteField,
    this.priceSection,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info container: prep time | reviews | restaurant
        infoContainer,
        const SizedBox(height: 12),

        // Pack's base name (moved outside container)
        Text(
          packBaseName,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),

        // LTO price section (if available) - between name and "Customize your order"
        if (priceSection != null) priceSection!,

        const SizedBox(height: 4),

        // Customize your order subtitle
        Text(
          AppLocalizations.of(context)!.customizeOrder,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),

        const SizedBox(height: 12),

        // Pack items container
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
            // PERFORMANCE FIX: Removed boxShadow to reduce repaint cost during scrolling
            // Visual depth is maintained via background color contrast
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ✅ NEW: Unified pack items and options container (replaces individual pack items)
                if (unifiedPackItemsOptionsContainer != null) ...[
                  unifiedPackItemsOptionsContainer!,
                ] else ...[
                  // Fallback: Pack items with dividers (old style)
                  ...packItems,
                ],

                // Global ingredients section (applies to entire pack)
                if (hasGlobalIngredients &&
                    globalIngredientsSection != null) ...[
                  const SizedBox(height: 16),
                  Divider(height: 1, color: Colors.grey[200]),
                  const SizedBox(height: 16),
                  globalIngredientsSection!,
                ],

                // Color legend for ingredient preferences
                if (hasAnyPackIngredients) ...[
                  const SizedBox(height: 16),
                  Divider(height: 1, color: Colors.grey[200]),
                  const SizedBox(height: 16),
                  ingredientLegend,
                ],

                // Unified supplements container (all supplements from all pack items)
                if (unifiedSupplementsContainer != null) ...[
                  const SizedBox(height: 16),
                  Divider(height: 1, color: Colors.grey[200]),
                  const SizedBox(height: 16),
                  unifiedSupplementsContainer!,
                ],

                // Special note field (above free drinks)
                if (specialNoteField != null) ...[
                  const SizedBox(height: 16),
                  Divider(height: 1, color: Colors.grey[200]),
                  const SizedBox(height: 16),
                  specialNoteField!,
                ],

                // Free drinks section (if pack includes free drinks)
                if (hasFreeDrinks && freeDrinksSection != null) ...[
                  if (specialNoteField != null) ...[
                    const SizedBox(height: 16),
                    Divider(height: 1, color: Colors.grey[200]),
                    const SizedBox(height: 16),
                  ] else ...[
                    const SizedBox(height: 16),
                    Divider(height: 1, color: Colors.grey[200]),
                    const SizedBox(height: 16),
                  ],
                  freeDrinksSection!,
                ],

                // Pack items quantity selector (if provided, now handled in unified add to cart widget)
                if (quantitySelector != null) ...[
                  const SizedBox(height: 16),
                  Divider(height: 1, color: Colors.grey[200]),
                  const SizedBox(height: 16),
                  quantitySelector!,
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
