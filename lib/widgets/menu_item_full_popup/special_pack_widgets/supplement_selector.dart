import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/menu_item_supplement.dart';
import '../shared_widgets/supplement_chip_widget.dart';

// ============================================================================
// Global Ingredients
// ============================================================================

/// Global ingredients section widget for special pack popup
class SpecialPackGlobalIngredients extends StatelessWidget {
  final List<String> globalIngredients;

  const SpecialPackGlobalIngredients({
    required this.globalIngredients,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.mainPackIngredients,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: globalIngredients.map((ingredient) {
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 12,
                    color: Colors.green[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    ingredient,
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

// ============================================================================
// Global Supplements
// ============================================================================

/// Global supplements section widget for special pack popup
class SpecialPackGlobalSupplements extends StatelessWidget {
  final List<MenuItemSupplement> supplements;
  final List<MenuItemSupplement> selectedSupplements;
  final Function(MenuItemSupplement supplement, bool isSelected)
      onSupplementToggled;

  const SpecialPackGlobalSupplements({
    required this.supplements,
    required this.selectedSupplements,
    required this.onSupplementToggled,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (supplements.isEmpty) {
      return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.addSupplements,
          style: GoogleFonts.poppins(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          // PERFORMANCE FIX: Use ListView.builder instead of ListView.separated
          // to support itemExtent for uniform horizontal items (avoids measure storms)
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.zero,
            itemCount: supplements.length * 2 - 1, // Items + separators
            // PERFORMANCE FIX: Increased itemExtent to 180px to prevent overflow
            // Ensures supplement name, icon, and price are always fully visible
            // Calculation: icon (16) + spacing (6) + name (up to 100) + spacing (6) + price (up to 30) + padding (24) = ~182px
            itemExtent:
                180, // Safe width to accommodate longest supplement names and prices
            cacheExtent: 360, // Cache 2 items ahead
            physics: const ClampingScrollPhysics(), // Smooth scrolling
            itemBuilder: (context, index) {
              // Even indices are items, odd indices are separators
              if (index.isOdd) {
                return const SizedBox(width: 8);
              }
              final itemIndex = index ~/ 2;
              final supp = supplements[itemIndex];
              final isSelected = selectedSupplements.any((s) =>
                  s.id == supp.id ||
                  (s.name == supp.name && s.menuItemId == supp.menuItemId));

              // PERFORMANCE FIX: Wrap in RepaintBoundary to isolate repaints
              return RepaintBoundary(
                child: SupplementChipWidget(
                  supplementName: supp.name,
                  supplementPrice: supp.price,
                  isSelected: isSelected,
                  onTap: () => onSupplementToggled(supp, isSelected),
                  unselectedColor: Colors.white,
                  fontSize: 12,
                  iconSize: 16,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
