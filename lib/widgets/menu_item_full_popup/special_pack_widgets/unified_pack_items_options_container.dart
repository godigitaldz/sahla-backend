import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/menu_item_variant.dart';

/// Unified pack items and options container widget
/// Displays all pack items with their options in a unified container
/// Format: Item Name (with quantity badge) | Options list with select buttons on the right
class UnifiedPackItemsOptionsContainer extends StatelessWidget {
  final List<MenuItemVariant> packItems;
  final Map<String, int> itemQuantities; // Map<variantId, quantity>
  final Map<String, List<String>> itemOptions; // Map<variantId, List<options>>
  final Map<String, Map<int, String>>
      packItemSelections; // Map<variantId, Map<quantityIndex, selectedOption>>
  final Function(String variantId, int quantityIndex, String option)
      onOptionSelected;
  final Function(String variantId) onVariantAutoSelected;

  const UnifiedPackItemsOptionsContainer({
    required this.packItems,
    required this.itemQuantities,
    required this.itemOptions,
    required this.packItemSelections,
    required this.onOptionSelected,
    required this.onVariantAutoSelected,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (packItems.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Pack Items header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Pack Items',
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            Text(
              l10n.required,
              style: GoogleFonts.poppins(
                fontSize: 12,
                fontWeight: FontWeight.normal,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Display all pack items - each as a separate container
        ...packItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final quantity = itemQuantities[item.id] ?? 1;
          final options = itemOptions[item.id] ?? [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (index > 0) const SizedBox(height: 12),
              // Separate container for each pack item
              Container(
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
                    // Item name with quantity badge
                    Row(
                      children: [
                        if (quantity > 1) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${quantity}x',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            item.name,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Options list for this item
                    if (options.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      // For multiple quantities, group options by name and show quantity select points horizontally
                      if (quantity > 1) ...[
                        // ✅ FIX: Check if all quantities have the same option selected (for all options)
                        Builder(
                          builder: (context) {
                            final allSelections = <String?>[];
                            for (int i = 0; i < quantity; i++) {
                              allSelections
                                  .add(packItemSelections[item.id]?[i]);
                            }
                            final allSameOption = allSelections.isNotEmpty &&
                                allSelections.every((sel) =>
                                    sel != null &&
                                    sel == allSelections.first) &&
                                allSelections.first != null;

                            // Group options by option name, show quantity select points horizontally
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children:
                                  options.asMap().entries.map((optionEntry) {
                                final optionIndex = optionEntry.key;
                                final option = optionEntry.value;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (optionIndex > 0) ...[
                                      const SizedBox(height: 19),
                                      Divider(
                                          height: 1, color: Colors.grey[200]),
                                      const SizedBox(height: 19),
                                    ],
                                    Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        // Option name on the left
                                        Expanded(
                                          child: Text(
                                            option,
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.black87,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // ✅ FIX: If all quantities have the same option, show only one select point
                                        // Otherwise, show quantity select points horizontally (Option 1, Option 2, Option 3, etc.)
                                        if (allSameOption &&
                                            allSelections.first == option) ...[
                                          // Show only one select point when all quantities have the same option
                                          GestureDetector(
                                            onTap: () {
                                              // When tapping, set this option for all quantities
                                              for (int i = 0;
                                                  i < quantity;
                                                  i++) {
                                                onOptionSelected(
                                                    item.id, i, option);
                                              }
                                              // Auto-select variant when option is selected
                                              onVariantAutoSelected(item.id);
                                            },
                                            child: const Icon(
                                              Icons.check,
                                              size: 24,
                                              color: Color(0xFFd47b00),
                                            ),
                                          ),
                                        ] else ...[
                                          // Show quantity select points horizontally (Option 1, Option 2, Option 3, etc.)
                                          Wrap(
                                            spacing: 19,
                                            runSpacing: 8,
                                            children: List.generate(quantity,
                                                (qtyIndex) {
                                              final currentSelection =
                                                  packItemSelections[item.id]
                                                      ?[qtyIndex];
                                              final isSelected =
                                                  currentSelection == option;
                                              return GestureDetector(
                                                onTap: () {
                                                  onOptionSelected(item.id,
                                                      qtyIndex, option);
                                                  // Auto-select variant when option is selected
                                                  onVariantAutoSelected(
                                                      item.id);
                                                },
                                                child: Icon(
                                                  isSelected
                                                      ? Icons.check
                                                      : Icons
                                                          .radio_button_unchecked,
                                                  size: 24,
                                                  color: isSelected
                                                      ? const Color(0xFFd47b00)
                                                      : Colors.black87,
                                                ),
                                              );
                                            }),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ] else ...[
                        // Single quantity, show options without label
                        Builder(
                          builder: (context) {
                            final currentSelection =
                                packItemSelections[item.id]?[0];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children:
                                  options.asMap().entries.map((optionEntry) {
                                final optionIndex = optionEntry.key;
                                final option = optionEntry.value;
                                final isSelected = currentSelection == option;
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (optionIndex > 0) ...[
                                      const SizedBox(height: 12),
                                      Divider(
                                          height: 1, color: Colors.grey[200]),
                                      const SizedBox(height: 12),
                                    ],
                                    Row(
                                      children: [
                                        // Option name
                                        Expanded(
                                          child: Text(
                                            option,
                                            style: GoogleFonts.poppins(
                                              fontSize: 13,
                                              fontWeight: FontWeight.normal,
                                              color: Colors.black87,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        // Select button on the right
                                        GestureDetector(
                                          onTap: () {
                                            onOptionSelected(
                                                item.id, 0, option);
                                            // Auto-select variant when option is selected
                                            onVariantAutoSelected(item.id);
                                          },
                                          child: Icon(
                                            isSelected
                                                ? Icons.check
                                                : Icons.radio_button_unchecked,
                                            size: 24,
                                            color: isSelected
                                                ? const Color(0xFFd47b00)
                                                : Colors.black87,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                );
                              }).toList(),
                            );
                          },
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ],
          );
        }),
      ],
    );
  }
}
