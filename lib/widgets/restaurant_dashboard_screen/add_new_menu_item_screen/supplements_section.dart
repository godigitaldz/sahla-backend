import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../config/menu_item_form_controller.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/menu_item_supplement.dart';
import '../../../models/menu_item_variant.dart';
import 'supplement_suggestions_widget.dart';

/// Supplements section widget for the Add Menu Item screen
///
/// Displays and manages menu item supplements with their variants
class SupplementsSection extends StatelessWidget {
  final BoxDecoration cardDecoration;
  final void Function(String supplementId) onManageVariants;
  final VoidCallback onAddSupplement;
  final Widget Function(BuildContext context, double price, {Color? color})
      buildPriceText;
  final Widget Function({
    required Widget child,
    Color? backgroundColor,
    Color? borderColor,
  }) buildItemCard;
  final Widget Function({
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
    Color? backgroundColor,
  }) buildActionButton;
  final List<String> Function(
      List<String> variantIds, List<MenuItemVariant> variants) getVariantNames;
  final String? restaurantId; // For loading supplement suggestions

  static const _primaryColor = Color(0xFFd47b00);

  const SupplementsSection({
    required this.cardDecoration,
    required this.onManageVariants,
    required this.onAddSupplement,
    required this.buildPriceText,
    required this.buildItemCard,
    required this.buildActionButton,
    required this.getVariantNames,
    this.restaurantId,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<MenuItemFormController>(
      builder: (context, formController, child) {
        return Container(
          decoration: cardDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.add_circle, color: _primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.dishSupplements,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ],
                ),
              ),

              // Existing supplements
              if (formController.supplements.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: formController.supplements
                        .map((supplement) => _buildSupplementCard(
                              context,
                              supplement,
                              formController,
                            ))
                        .toList(),
                  ),
                ),

              const SizedBox(height: 12),

              // Add new supplement
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.addSupplement,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      AppLocalizations.of(context)!.supplementExamples,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                    const SizedBox(height: 12),
                    buildActionButton(
                      label: AppLocalizations.of(context)!.addSupplement,
                      onPressed: onAddSupplement,
                    ),
                  ],
                ),
              ),
              // Supplement suggestions chips (only for regular items, not special packs)
              if (!formController.isSpecialPack)
                Builder(
                  builder: (context) {
                    // Debug: Log when rendering suggestions widget
                    debugPrint(
                        '🔍 Rendering SupplementSuggestionsWidget for regular item (restaurantId: $restaurantId)');
                    // Use restaurantId as key to force rebuild when it changes from null to a value
                    return SupplementSuggestionsWidget(
                      key: ValueKey('supplement_suggestions_$restaurantId'),
                      restaurantId: restaurantId,
                      isSpecialPack: false,
                      onSupplementSelected: (supplement) {
                        // Add supplement to form with database-supplied ID when chip is tapped
                        // This will link it to the menu item when saved
                        formController.addExistingSupplement(supplement);
                      },
                    );
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSupplementCard(
    BuildContext context,
    MenuItemSupplement supplement,
    MenuItemFormController formController,
  ) {
    return buildItemCard(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      supplement.name,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                    if (supplement.description != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        supplement.description!,
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              buildPriceText(context, supplement.price),
              const SizedBox(width: 8),
              // Manage variants button
              IconButton(
                onPressed: () => onManageVariants(supplement.id),
                icon: const Icon(
                  Icons.category,
                  size: 18,
                  color: Colors.blue,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                tooltip: 'Manage variants',
              ),
              const SizedBox(width: 4),
              // Remove supplement button
              IconButton(
                onPressed: () => formController.removeSupplement(supplement.id),
                icon: const Icon(
                  Icons.close,
                  size: 20,
                  color: Colors.red,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          // Show supplement variants
          if (supplement.variants.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildSupplementVariants(supplement.variants),
          ],

          // Show variant availability
          if (supplement.availableForVariants.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildVariantAvailability(
              context,
              supplement.availableForVariants,
              formController.variants,
              isAvailableForAll: false,
            ),
          ] else if (formController.variants.isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildVariantAvailability(
              context,
              [],
              formController.variants,
              isAvailableForAll: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSupplementVariants(List<dynamic> variants) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.blue.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.category,
                size: 12,
                color: Colors.blue[600],
              ),
              const SizedBox(width: 4),
              Text(
                'Supplement Variants:',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.blue[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ...variants.map((variant) => Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      variant.name,
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        color: Colors.blue[700],
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '+${variant.price.toStringAsFixed(0)} DA',
                      style: GoogleFonts.poppins(
                        fontSize: 9,
                        color: Colors.blue[600],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildVariantAvailability(
    BuildContext context,
    List<String> availableForVariants,
    List<MenuItemVariant> allVariants, {
    required bool isAvailableForAll,
  }) {
    final color = isAvailableForAll ? Colors.grey : _primaryColor;
    final icon = isAvailableForAll ? Icons.all_inclusive : Icons.check_circle;
    final text = isAvailableForAll
        ? AppLocalizations.of(context)!.availableForAllVariants
        : '${AppLocalizations.of(context)!.availableFor}: ${getVariantNames(availableForVariants, allVariants).join(', ')}';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon,
              size: 12, color: isAvailableForAll ? color : _primaryColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: isAvailableForAll ? Colors.grey[600] : _primaryColor,
            ),
          ),
        ],
      ),
    );
  }
}
