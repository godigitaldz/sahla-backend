import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/category.dart';
import '../../pill_dropdown.dart';
import 'variant_pricing_section.dart';

/// Widget for the Drink Variants & Pricing step
///
/// This specialized step is shown when adding a drink menu item.
/// Drinks are simpler than food items:
/// - No cuisine type (drinks are universal)
/// - No drink name field (variants ARE the drink names)
/// - No supplements (drinks don't have add-ons)
/// - No images (uses smart detection from bucket)
/// - Each variant represents a different drink (e.g., Coca Cola, Fanta)
/// - Each variant can have multiple sizes (0.33L, 0.5L, 1L, etc.)
class DrinkVariantsPricingStep extends StatelessWidget {
  /// Can accept a single variant ID (String) or multiple (List<String>)
  final void Function(dynamic variantIds) onAddPricing;
  final List<Category> filteredCategories;
  final String? selectedCategoryId;
  final bool isLoadingCategories;
  final ValueChanged<String?> onCategoryChanged;

  const DrinkVariantsPricingStep({
    required this.onAddPricing,
    required this.filteredCategories,
    required this.selectedCategoryId,
    required this.isLoadingCategories,
    required this.onCategoryChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle(AppLocalizations.of(context)!.addNewDrinksMenu),
          const SizedBox(height: 20),
          _buildCategoryDropdown(context),
          const SizedBox(height: 24),
          _buildInfoBox(
            AppLocalizations.of(context)!.addDrinksByCreatingVariants,
            Icons.info_outline,
            Colors.blue,
          ),
          const SizedBox(height: 16),
          VariantPricingSection(onAddPricing: onAddPricing),
          const SizedBox(height: 24),
          _buildSmartDetectionInfo(context),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      ),
    );
  }

  Widget _buildCategoryDropdown(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${AppLocalizations.of(context)!.category} *',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        PillDropdown<String>(
          value: selectedCategoryId,
          hint: AppLocalizations.of(context)!.selectCategory,
          items: isLoadingCategories
              ? [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Row(
                      children: [
                        const Icon(Icons.local_drink, size: 18),
                        const SizedBox(width: 12),
                        Text(AppLocalizations.of(context)!.loadingCategories),
                      ],
                    ),
                  )
                ]
              : filteredCategories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category.id,
                    child: Row(
                      children: [
                        const Icon(Icons.local_drink, size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            category.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
          onChanged: isLoadingCategories ? null : onCategoryChanged,
        ),
      ],
    );
  }

  Widget _buildInfoBox(String text, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black87,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmartDetectionInfo(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue[600]),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  AppLocalizations.of(context)!.smartDetectionActive,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue[800],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.smartDetectionDescription,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.blue[700],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
