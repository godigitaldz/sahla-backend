import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../models/menu_item.dart';
import '../../../../../utils/price_formatter.dart';
import '../../../../menu_item_full_popup/helpers/special_pack_helper.dart';
import 'global_ingredients_widget.dart';
import 'global_supplements_widget.dart';

/// Widget for displaying pack contents section in LTO special pack review
class LTOPackContentsWidget extends StatelessWidget {
  final MenuItem menuItem;
  final MenuItem localMenuItem;
  final List<String> Function(String?) parseHiddenOptions;
  final List<String> Function(String?) parseHiddenSupplements;
  final Function(Map<String, dynamic>) onEditVariant;
  final Function(Map<String, dynamic>, bool) onToggleVariantVisibility;
  final Function(Map<String, dynamic>) onDeleteVariant;
  final Function(Map<String, dynamic>) onAddOption;
  final Function(Map<String, dynamic>, String) onToggleOptionVisibility;
  final Function(Map<String, dynamic>, String) onDeleteOption;
  final Function(Map<String, dynamic>) onEditIngredients;
  final Function(Map<String, dynamic>) onAddSupplement;
  final Function(Map<String, dynamic>, Map<String, dynamic>, bool)
      onToggleSupplementVisibility;
  final Function(Map<String, dynamic>, Map<String, dynamic>) onDeleteSupplement;
  final Function(String?) onUpdateGlobalIngredients;
  final Function(Map<String, double>) onUpdateGlobalSupplements;
  final Function(String, Map<String, double>) onAddGlobalSupplement;
  final Function(String, Map<String, double>) onDeleteGlobalSupplement;
  final Function(String, Map<String, double>, bool)
      onToggleGlobalSupplementVisibility;

  const LTOPackContentsWidget({
    required this.menuItem,
    required this.localMenuItem,
    required this.parseHiddenOptions,
    required this.parseHiddenSupplements,
    required this.onEditVariant,
    required this.onToggleVariantVisibility,
    required this.onDeleteVariant,
    required this.onAddOption,
    required this.onToggleOptionVisibility,
    required this.onDeleteOption,
    required this.onEditIngredients,
    required this.onAddSupplement,
    required this.onToggleSupplementVisibility,
    required this.onDeleteSupplement,
    required this.onUpdateGlobalIngredients,
    required this.onUpdateGlobalSupplements,
    required this.onAddGlobalSupplement,
    required this.onDeleteGlobalSupplement,
    required this.onToggleGlobalSupplementVisibility,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (menuItem.variants.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Pack Contents',
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        ...localMenuItem.variants.map((variantJson) {
          final variant = variantJson;
          final variantId = variant['id']?.toString() ?? '';
          final variantName = variant['name'] ?? '';
          final variantDescription = variant['description'] ?? '';
          final quantity = SpecialPackHelper.parseQuantity(variantDescription);
          final allOptions = SpecialPackHelper.parseOptions(variantDescription);
          final hiddenOptions = parseHiddenOptions(variantDescription);
          // Filter out hidden options from display
          final options =
              allOptions.where((o) => !hiddenOptions.contains(o)).toList();
          final variantIngredients = SpecialPackHelper.parseIngredients(
            variantDescription,
          );

          // Get variant-specific pricing (including global pricing, excluding pack pricing)
          final variantPricing = localMenuItem.pricingOptions
              .cast<Map<String, dynamic>>()
              .where((p) {
            // Exclude pack pricing (size == 'Pack')
            final size = p['size']?.toString().toLowerCase() ?? '';
            if (size == 'pack') {
              return false;
            }
            final pVariantId = p['variant_id'];
            // Include if it's for this variant OR if it's global (null/empty)
            return pVariantId == variantId ||
                pVariantId == null ||
                pVariantId == '';
          }).toList();

          // Get variant-specific supplements from supplements array
          final variantSupplementsFromArray =
              localMenuItem.supplements.cast<Map<String, dynamic>>().where((s) {
            final availableFor = s['available_for_variants'];

            // Global supplements: null or empty available_for_variants
            if (availableFor == null) {
              return true; // Global supplement - show it
            }

            if (availableFor is! List) {
              return false; // Invalid format
            }

            final availableForList = List.from(availableFor);

            // Global supplements: empty list
            if (availableForList.isEmpty) {
              return true; // Global supplement - show it
            }

            // Variant-specific supplements: check if assigned to this variant
            final variantIdStr = variantId.toString();
            final variantIdList =
                availableForList.map((e) => e.toString()).toList();
            return variantIdList.contains(variantIdStr);
          }).toList();

          // Parse supplements from variant description
          final variantSupplementsFromDesc =
              SpecialPackHelper.parseSupplements(variantDescription);

          // Parse hidden supplements for this variant
          final hiddenSupplements = parseHiddenSupplements(variantDescription);

          // Use only variant-specific supplements (not global)
          // Note: Global supplements are shown at the pack level, not per variant
          final allSupplementsList = <Map<String, dynamic>>[];

          // Add supplements from array (variant-specific only)
          allSupplementsList.addAll(variantSupplementsFromArray);

          // Add supplements from variant description (variant-specific only)
          // Include hidden supplements but mark them as unavailable so they can be reshown
          variantSupplementsFromDesc.forEach((name, price) {
            // Check if supplement already exists in array supplements
            final exists =
                variantSupplementsFromArray.any((s) => s['name'] == name);
            if (!exists) {
              // Include all supplements, but mark hidden ones as unavailable
              final isHidden = hiddenSupplements.contains(name);
              allSupplementsList.add({
                'name': name,
                'price': price,
                'is_available': !isHidden, // Mark as unavailable if hidden
                'id': 'desc_$name',
              });
            }
          });

          // Note: Global supplements are NOT included here
          // They are shown at the pack level, not per variant

          final variantSupplements = allSupplementsList;

          // Use only variant-specific ingredients (not global)
          // Note: Global ingredients are shown at the pack level, not per variant

          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.grey[300]!,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Variant Header
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.restaurant,
                        size: 18,
                        color: Color(0xFFd47b00),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            quantity > 1
                                ? '($quantity)x $variantName'
                                : variantName,
                            style: GoogleFonts.poppins(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                      // Edit button
                      InkWell(
                        onTap: () => onEditVariant(variant),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.edit,
                            size: 16,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Hide/Show button
                      InkWell(
                        onTap: () {
                          final isAvailable = variant['is_available'] ?? true;
                          onToggleVariantVisibility(variant, !isAvailable);
                        },
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: (variant['is_available'] ?? true)
                                ? Colors.grey[200]
                                : Colors.orange[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            (variant['is_available'] ?? true)
                                ? Icons.visibility
                                : Icons.visibility_off,
                            size: 16,
                            color: (variant['is_available'] ?? true)
                                ? Colors.grey[700]
                                : Colors.orange[700],
                          ),
                        ),
                      ),
                      const SizedBox(width: 4),
                      // Delete button
                      InkWell(
                        onTap: () => onDeleteVariant(variant),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.delete,
                            size: 16,
                            color: Colors.red,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Divider after variant header
                const Divider(
                  height: 24,
                  thickness: 1,
                  color: Colors.grey,
                ),

                // Options (if available)
                if (options.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  // Options section title with Add button
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Variants',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      // Add Variant button
                      InkWell(
                        onTap: () => onAddOption(variant),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFd47b00),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.add_circle_outline,
                                size: 16,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Add Variant',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
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
                  // Options as white containers with delete/hide buttons
                  Column(
                    children: options.map((option) {
                      final isLastOption = options.length == 1;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                option,
                                style: GoogleFonts.poppins(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.black87,
                                ),
                              ),
                            ),
                            // Hide button
                            InkWell(
                              onTap: () => onToggleOptionVisibility(
                                variant,
                                option,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isLastOption
                                      ? Colors.grey[100]
                                      : Colors.grey[200],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.visibility,
                                  size: 16,
                                  color: isLastOption
                                      ? Colors.grey[400]
                                      : Colors.grey[700],
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Delete button
                            InkWell(
                              onTap: () => onDeleteOption(variant, option),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isLastOption
                                      ? Colors.grey[100]
                                      : Colors.red[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  Icons.delete,
                                  size: 16,
                                  color: isLastOption
                                      ? Colors.grey[400]
                                      : Colors.red[700],
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  const Divider(
                    height: 24,
                    thickness: 1,
                    color: Colors.grey,
                  ),
                ],

                // Pricing (if available)
                if (variantPricing.isNotEmpty) ...[
                  // Add spacing if no options section before it
                  if (options.isEmpty) const SizedBox(height: 12),
                  // Pricing section title
                  Text(
                    'Pricing',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: variantPricing.map((pricing) {
                      final price = pricing['price'] ?? 0.0;
                      final size = pricing['size'] ?? '';
                      final portion = pricing['portion'] ?? '';
                      final sizeLabel = size.isNotEmpty
                          ? size
                          : (portion.isNotEmpty ? portion : 'Standard');
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.green[300]!,
                            width: 1,
                          ),
                        ),
                        child: Text(
                          '$sizeLabel: ${PriceFormatter.formatWithSettings(context, price.toString())}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFFd47b00),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  const Divider(
                    height: 24,
                    thickness: 1,
                    color: Colors.grey,
                  ),
                ],

                // Ingredients (if available) - only variant-specific, not global
                if (variantIngredients.isNotEmpty) ...[
                  // Add spacing only if no previous sections exist (no dividers present)
                  if (options.isEmpty && variantPricing.isEmpty)
                    const SizedBox(height: 12),
                  // Ingredients section title with Manage button
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Ingredients',
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      // Manage button
                      InkWell(
                        onTap: () => onEditIngredients(variant),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFd47b00),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Manage',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: variantIngredients.map((ingredient) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          ingredient,
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[700],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  const Divider(
                    height: 24,
                    thickness: 1,
                    color: Colors.grey,
                  ),
                ],

                // Supplements section (always shown)
                // Add spacing only if no previous sections exist (no dividers present)
                if (options.isEmpty &&
                    variantPricing.isEmpty &&
                    variantIngredients.isEmpty)
                  const SizedBox(height: 12),
                // Supplements section title with Add button
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Supplements',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    // Add Supplement button
                    InkWell(
                      onTap: () => onAddSupplement(variant),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFd47b00),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.add,
                              size: 16,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'Add Supplement',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
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
                // Supplements as white containers with delete/hide buttons
                if (variantSupplements.isNotEmpty)
                  Column(
                    children: variantSupplements.map((supplement) {
                      final name = supplement['name'] ?? '';
                      final price = supplement['price'] ?? 0.0;
                      final isAvailable = supplement['is_available'] ?? true;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    name,
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '+${PriceFormatter.formatWithSettings(context, price.toString())}',
                                    style: GoogleFonts.poppins(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFFd47b00),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Hide button
                            InkWell(
                              onTap: () => onToggleSupplementVisibility(
                                variant,
                                supplement,
                                !isAvailable,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: isAvailable
                                      ? Colors.grey[200]
                                      : Colors.orange[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isAvailable
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                  size: 16,
                                  color: isAvailable
                                      ? Colors.grey[700]
                                      : Colors.orange[700],
                                ),
                              ),
                            ),
                            const SizedBox(width: 4),
                            // Delete button
                            InkWell(
                              onTap: () => onDeleteSupplement(
                                variant,
                                supplement,
                              ),
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: Colors.red[50],
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.delete,
                                  size: 16,
                                  color: Colors.red,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 12),
                const Divider(
                  height: 24,
                  thickness: 1,
                  color: Colors.grey,
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 20),

        // Main Global Ingredients section
        const SizedBox(height: 20),
        LTOGlobalIngredientsWidget(
          menuItem: localMenuItem, // Use localMenuItem to get updated data
          onUpdateGlobalIngredients: onUpdateGlobalIngredients,
        ),

        // Main Global Supplements section
        const SizedBox(height: 20),
        LTOGlobalSupplementsWidget(
          menuItem: localMenuItem, // Use localMenuItem to get updated data
          onUpdateGlobalSupplements: onUpdateGlobalSupplements,
          onAddGlobalSupplement: onAddGlobalSupplement,
          onDeleteGlobalSupplement: onDeleteGlobalSupplement,
          onToggleGlobalSupplementVisibility:
              onToggleGlobalSupplementVisibility,
        ),
      ],
    );
  }
}
