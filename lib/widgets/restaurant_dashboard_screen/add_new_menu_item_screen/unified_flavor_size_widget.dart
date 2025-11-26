import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../config/menu_item_form_controller.dart';
import '../../../l10n/app_localizations.dart';

/// Unified widget for adding flavors & sizes to menu item variants.
///
/// This widget provides a comprehensive interface to add pricing options
/// (flavors/sizes) to one or more variants at once, replacing the previous
/// per-variant approach for better UX.
class UnifiedFlavorSizeWidget extends StatefulWidget {
  /// Callback when user wants to add pricing to selected variants
  final void Function(List<String> variantIds) onAddPricing;

  /// Optional primary color
  final Color? primaryColor;

  const UnifiedFlavorSizeWidget({
    required this.onAddPricing,
    this.primaryColor,
    super.key,
  });

  @override
  State<UnifiedFlavorSizeWidget> createState() =>
      _UnifiedFlavorSizeWidgetState();
}

class _UnifiedFlavorSizeWidgetState extends State<UnifiedFlavorSizeWidget> {
  static const _defaultPrimaryColor = Color(0xFFd47b00);
  final Set<String> _selectedVariants = {};
  bool _selectAllMode = true; // True means all are selected

  Color get _primaryColor => widget.primaryColor ?? _defaultPrimaryColor;

  @override
  Widget build(BuildContext context) {
    return Consumer<MenuItemFormController>(
      builder: (context, formController, child) {
        // Only show for regular items (not pack items)
        if (formController.isSpecialPack) {
          return const SizedBox.shrink();
        }

        // Only show if there are variants
        if (formController.variants.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Icon(
                    Icons.add_circle_outline,
                    color: _primaryColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.addFlavorAndSize,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Add pricing options to one or more variants at once',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
              const SizedBox(height: 16),
              // Variant selection chips
              _buildVariantSelectionChips(context, formController),
              const SizedBox(height: 16),
              // Add button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    final List<String> variantIds;
                    if (_selectAllMode || _selectedVariants.isEmpty) {
                      // Apply to all variants
                      variantIds =
                          formController.variants.map((v) => v.id).toList();
                    } else {
                      // Apply to selected variants only
                      variantIds = _selectedVariants.toList();
                    }

                    if (variantIds.isNotEmpty) {
                      widget.onAddPricing(variantIds);
                      // Reset selection after adding
                      setState(() {
                        _selectedVariants.clear();
                        _selectAllMode = true;
                      });
                    }
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(
                    'Add Flavor & Size',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVariantSelectionChips(
      BuildContext context, MenuItemFormController formController) {
    if (formController.variants.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Select variants (or leave all selected to apply to all):',
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: formController.variants.map((variant) {
            final isSelected =
                _selectAllMode || _selectedVariants.contains(variant.id);
            return FilterChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    variant.name,
                    style: GoogleFonts.poppins(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (variant.isDefault) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: _primaryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.defaultVariant,
                        style: GoogleFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: _primaryColor,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (_selectAllMode) {
                    // Transitioning from "all selected" mode to specific selection
                    _selectAllMode = false;
                    // Select all except the one being deselected
                    for (final v in formController.variants) {
                      if (v.id != variant.id) {
                        _selectedVariants.add(v.id);
                      }
                    }
                  } else {
                    // Already in specific selection mode
                    if (selected) {
                      _selectedVariants.add(variant.id);
                    } else {
                      _selectedVariants.remove(variant.id);
                      // If all are deselected, go back to "all selected" mode
                      if (_selectedVariants.isEmpty) {
                        _selectAllMode = true;
                      }
                    }
                  }
                });
              },
              selectedColor: _primaryColor.withValues(alpha: 0.15),
              checkmarkColor: _primaryColor,
              backgroundColor: Colors.grey[100],
              labelStyle: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isSelected ? _primaryColor : Colors.black87,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? _primaryColor : Colors.grey[300]!,
                  width: isSelected ? 1.5 : 1,
                ),
              ),
            );
          }).toList(),
        ),
        if (formController.variants.length > 1 && !_selectAllMode)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: TextButton(
              onPressed: () {
                setState(() {
                  _selectedVariants.clear();
                  _selectAllMode = true;
                });
              },
              child: Text(
                'Select all variants',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: _primaryColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
