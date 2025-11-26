import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/menu_item_variant.dart';

/// Item container widget for special pack popup
/// This widget displays a pack item with options, ingredients, and supplements
class SpecialPackItemContainer extends StatelessWidget {
  final MenuItemVariant item;
  final int quantity;
  final List<String> options;
  final List<String> ingredients;
  final Map<String, double> supplements;
  final Map<int, String> selectedOptions; // Map<quantityIndex, selectedOption>
  final Map<int, Set<String>>
      selectedSupplements; // Map<quantityIndex, Set<supplementName>>
  final Map<int, Map<String, dynamic>>
      ingredientPreferences; // Map<quantityIndex, Map<ingredient, preference>>
  final Function(String variantId, int quantityIndex, String option)
      onOptionSelected;
  final Function(String variantId, int quantityIndex, String supplementName,
      bool isSelected) onSupplementToggled;
  final Function(String variantName, int quantityIndex, String ingredient)
      onIngredientTapped;
  final Widget Function(
          String variantName, int quantityIndex, List<String> ingredients)
      buildIngredients;
  final Widget Function(String variantId, String variantName, int quantityIndex,
      Map<String, double> supplements) buildSupplements;
  final String menuItemId;

  const SpecialPackItemContainer({
    required this.item,
    required this.quantity,
    required this.options,
    required this.ingredients,
    required this.supplements,
    required this.selectedOptions,
    required this.selectedSupplements,
    required this.ingredientPreferences,
    required this.onOptionSelected,
    required this.onSupplementToggled,
    required this.onIngredientTapped,
    required this.buildIngredients,
    required this.buildSupplements,
    required this.menuItemId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Item name with quantity
        Row(
          children: [
            Expanded(
              child: Text(
                item.name,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            // Simple white quantity badge with border
            if (quantity > 1) ...[
              const SizedBox(width: 10),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(
                    color: Colors.grey[300]!,
                    width: 1,
                  ),
                ),
                child: Text(
                  '${quantity}x',
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
        if (options.isNotEmpty) ...[
          const SizedBox(height: 12),
          // For multiple quantities, show separate rows
          if (quantity > 1) ...[
            ...List.generate(quantity, (qtyIndex) {
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
                  // PERFORMANCE FIX: Wrap is acceptable for option lists (typically <10 items)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: options.map((option) {
                      final isSelected = selectedOptions[qtyIndex] == option;
                      // PERFORMANCE FIX: Wrap in RepaintBoundary to isolate repaints
                      return RepaintBoundary(
                        child: GestureDetector(
                          onTap: () {
                            onOptionSelected(item.id, qtyIndex, option);
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
                                fontWeight: isSelected
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                                color:
                                    isSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  // Ingredients for this quantity
                  if (ingredients.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    buildIngredients(item.name, qtyIndex, ingredients),
                  ],

                  // Supplements for this quantity
                  if (supplements.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    buildSupplements(item.id, item.name, qtyIndex, supplements),
                  ],
                ],
              );
            }),
          ] else ...[
            // Single quantity, show options without label
            // PERFORMANCE FIX: Wrap is acceptable for option lists (typically <10 items)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: options.map((option) {
                final isSelected = selectedOptions[0] == option;
                // PERFORMANCE FIX: Wrap in RepaintBoundary to isolate repaints
                return RepaintBoundary(
                  child: GestureDetector(
                    onTap: () {
                      onOptionSelected(item.id, 0, option);
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
                  ),
                );
              }).toList(),
            ),
            // Ingredients for single quantity
            if (ingredients.isNotEmpty) ...[
              const SizedBox(height: 10),
              buildIngredients(item.name, 0, ingredients),
            ],

            // Supplements for single quantity
            if (supplements.isNotEmpty) ...[
              const SizedBox(height: 10),
              buildSupplements(item.id, item.name, 0, supplements),
            ],
          ],
        ] else if (ingredients.isNotEmpty || supplements.isNotEmpty) ...[
          // No options but has ingredients or supplements - show directly
          const SizedBox(height: 10),
          if (quantity > 1) ...[
            // Multiple quantities - show for each
            ...List.generate(quantity, (qtyIndex) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (qtyIndex > 0) const SizedBox(height: 12),
                  Text(
                    '${item.name} ${qtyIndex + 1}:',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (ingredients.isNotEmpty) ...[
                    buildIngredients(item.name, qtyIndex, ingredients),
                  ],
                  if (supplements.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    buildSupplements(item.id, item.name, qtyIndex, supplements),
                  ],
                ],
              );
            }),
          ] else ...[
            // Single quantity
            if (ingredients.isNotEmpty) ...[
              buildIngredients(item.name, 0, ingredients),
            ],
            if (supplements.isNotEmpty) ...[
              const SizedBox(height: 10),
              buildSupplements(item.id, item.name, 0, supplements),
            ],
          ],
        ],
      ],
    );
  }
}
