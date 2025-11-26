import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../models/enhanced_menu_item.dart';
import '../../../../models/menu_item_pricing.dart';
import '../../../../models/menu_item_variant.dart';

/// Parameters for buildPackItemRow method
class BuildPackItemRowParams {
  final MenuItemVariant item;
  final int quantity;
  final List<String> options;

  // State maps (read-only for reading, write callbacks for updates)
  final Map<String, Map<int, String>> packItemSelections;
  final Set<String> selectedVariants;
  final Map<String, int> variantQuantities;
  final Map<String, MenuItemPricing> selectedPricingPerVariant;
  final EnhancedMenuItem? enhancedMenuItem;

  // Callbacks for state updates
  final void Function() onStateUpdate;
  final void Function(String variantId, int qtyIndex, String option)
      onOptionSelected;
  final void Function(String variantId) onVariantAutoSelected;

  // Widget builders
  final Widget Function({
    required String variantName,
    required int quantityIndex,
    required List<String> ingredients,
  }) buildIngredients;
  final Widget Function({
    required String variantId,
    required String variantName,
    required int quantityIndex,
    required Map<String, double> supplements,
  }) buildSupplements;

  BuildPackItemRowParams({
    required this.item,
    required this.quantity,
    required this.options,
    required this.packItemSelections,
    required this.selectedVariants,
    required this.variantQuantities,
    required this.selectedPricingPerVariant,
    required this.enhancedMenuItem,
    required this.onStateUpdate,
    required this.onOptionSelected,
    required this.onVariantAutoSelected,
    required this.buildIngredients,
    required this.buildSupplements,
  });
}

/// Build pack item row widget with options, ingredients, and supplements
Widget buildPackItemRow(BuildPackItemRowParams params) {
  // Read current selections (for display only - updates go through callbacks)
  final currentSelection = params.packItemSelections[params.item.id];

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Item name with quantity
      Row(
        children: [
          Expanded(
            child: Text(
              params.item.name,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          // Simple white quantity badge with border
          if (params.quantity > 1) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Text(
                '${params.quantity}x',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
          ],
        ],
      ),

      // Show option rows for each quantity if options exist
      if (params.options.isNotEmpty) ...[
        const SizedBox(height: 12),
        // For multiple quantities, show separate rows
        if (params.quantity > 1) ...[
          ...List.generate(params.quantity, (qtyIndex) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (qtyIndex > 0) const SizedBox(height: 12),
                // Option label
                Text(
                  'Option ${qtyIndex + 1}:',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 8),
                // Option chips
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: params.options.map((option) {
                    final isSelected = currentSelection?[qtyIndex] == option;
                    return GestureDetector(
                      onTap: () {
                        params.onOptionSelected(
                            params.item.id, qtyIndex, option);

                        // Auto-select variant when option is selected (if not already selected)
                        if (!params.selectedVariants.contains(params.item.id)) {
                          params.onVariantAutoSelected(params.item.id);
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFd47b00)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFFd47b00)
                                : Colors.grey[300]!,
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Text(
                          option,
                          style: GoogleFonts.poppins(
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ],
            );
          }),
        ] else ...[
          // Single quantity, show options without label
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: params.options.map((option) {
              final isSelected = currentSelection?[0] == option;
              return GestureDetector(
                onTap: () {
                  params.onOptionSelected(params.item.id, 0, option);

                  // Auto-select variant when option is selected (if not already selected)
                  if (!params.selectedVariants.contains(params.item.id)) {
                    params.onVariantAutoSelected(params.item.id);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color:
                        isSelected ? const Color(0xFFd47b00) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFd47b00)
                          : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    option,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    ],
  );
}
