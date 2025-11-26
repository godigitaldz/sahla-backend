import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../l10n/app_localizations.dart';

/// Variants section widget
/// Displays the variants list with selection and action buttons
class VariantsSectionWidget extends StatelessWidget {
  final List<Map<String, dynamic>> variants;
  final String? selectedVariantId;
  final VoidCallback onAddGlobalSupplement;
  final VoidCallback onAddSize;
  final VoidCallback onAddVariant;
  final Function(String) onVariantSelected;
  final Function(Map<String, dynamic>) onEditVariantName;
  final Function(Map<String, dynamic>) onDeleteVariant;
  final Function(Map<String, dynamic>, bool) onToggleVariantVisibility;

  const VariantsSectionWidget({
    required this.variants,
    required this.selectedVariantId,
    required this.onAddGlobalSupplement,
    required this.onAddSize,
    required this.onAddVariant,
    required this.onVariantSelected,
    required this.onEditVariantName,
    required this.onDeleteVariant,
    required this.onToggleVariantVisibility,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (variants.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.variants,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            // Add Supp (Global)
            InkWell(
              onTap: onAddGlobalSupplement,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFd47b00),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'Add Supp (Global)',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Add Size (Global with variant selection)
            InkWell(
              onTap: onAddSize,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFd47b00),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'Add Size',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Add Variant
            InkWell(
              onTap: onAddVariant,
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFd47b00),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.add, size: 14, color: Colors.white),
                    const SizedBox(width: 4),
                    Text(
                      'Add Variant',
                      style: GoogleFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        // Variant selection list
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
          ),
          child: Column(
            children: [
              // Variant list items
              ...variants.map((variantJson) {
                final variant = variantJson;
                final variantId = variant['id'];
                final isSelected = selectedVariantId == variantId;
                final isDefault = variant['is_default'] ?? false;
                final variantName = variant['name'] ?? '';
                final isAvailable = variant['is_available'] ?? true;
                final isLast = variants.last == variantJson;

                return Column(
                  children: [
                    InkWell(
                      onTap: () => onVariantSelected(variantId.toString()),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFFd47b00).withOpacity(0.1)
                              : Colors.transparent,
                        ),
                        child: Row(
                          children: [
                            if (isSelected)
                              const Padding(
                                padding: EdgeInsets.only(right: 8),
                                child: Icon(
                                  Icons.check_circle,
                                  size: 18,
                                  color: Color(0xFFd47b00),
                                ),
                              ),
                            Expanded(
                              child: Row(
                                children: [
                                  if (!isAvailable)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 8),
                                      child: Icon(
                                        Icons.visibility_off,
                                        size: 14,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  Expanded(
                                    child: Text(
                                      variantName,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: isSelected
                                            ? const Color(0xFFd47b00)
                                            : (isAvailable
                                                ? Colors.black87
                                                : Colors.grey[600]),
                                        decoration: !isAvailable
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isDefault)
                              Container(
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFd47b00),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  AppLocalizations.of(context)!.defaultVariant,
                                  style: GoogleFonts.poppins(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            IconButton(
                              icon: Icon(
                                isAvailable
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                                size: 18,
                              ),
                              color: isAvailable
                                  ? Colors.grey[600]
                                  : const Color(0xFFd47b00),
                              onPressed: () => onToggleVariantVisibility(
                                  variant, !isAvailable),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              tooltip:
                                  isAvailable ? 'Hide variant' : 'Show variant',
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit, size: 18),
                              color: const Color(0xFFd47b00),
                              onPressed: () => onEditVariantName(variant),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, size: 18),
                              color: Colors.red,
                              onPressed: () => onDeleteVariant(variant),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (!isLast) Divider(height: 1, color: Colors.grey[300]),
                  ],
                );
              }),
            ],
          ),
        ),
      ],
    );
  }
}
