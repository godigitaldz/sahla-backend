import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../l10n/app_localizations.dart';

/// Pricing & Supplements section widget
/// Displays pricing and supplements for a selected variant (including global)
class PricingSupplementsSectionWidget extends StatelessWidget {
  final String variantId;
  final String variantName;
  final List<Map<String, dynamic>> variantPricing;
  final List<Map<String, dynamic>> variantSupplements;
  final Function(Map<String, dynamic>, String) onEditPricing;
  final Function(String) onDeletePricing;
  final Function(String) onAddPricing;
  final Function(String) onDeleteSupplement;
  final Function(String) onAddSupplement;

  const PricingSupplementsSectionWidget({
    required this.variantId,
    required this.variantName,
    required this.variantPricing,
    required this.variantSupplements,
    required this.onEditPricing,
    required this.onDeletePricing,
    required this.onAddPricing,
    required this.onDeleteSupplement,
    required this.onAddSupplement,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
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
          // Title showing selected variant
          Text(
            '$variantName - Pricing & Supplements',
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          // Size chips with edit and delete buttons
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: variantPricing.map((pricingJson) {
                    final pricing = pricingJson;
                    final pricingId = pricing['id'] as String? ?? '';
                    final pricingSize = pricing['size'] ?? '';
                    final pricingPortion = pricing['portion'] ?? '';
                    final pricingPrice = pricing['price'] ?? 0.0;
                    final pricingIsDefault = pricing['is_default'] ?? false;
                    final pricingSizeLabel = pricingSize.isNotEmpty
                        ? pricingSize
                        : (pricingPortion.isNotEmpty
                            ? pricingPortion
                            : AppLocalizations.of(context)!.standard);

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: pricingIsDefault
                              ? Colors.green[300]!
                              : Colors.grey[300]!,
                          width: pricingIsDefault ? 1.5 : 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            pricingSizeLabel,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '${pricingPrice.toStringAsFixed(0)} DZD',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFd47b00),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => onEditPricing(pricing, variantId),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.edit,
                                size: 14,
                                color: Color(0xFFd47b00),
                              ),
                            ),
                          ),
                          InkWell(
                            onTap: () => onDeletePricing(pricingId),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.delete,
                                size: 14,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => onAddPricing(variantId),
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
                      const Icon(
                        Icons.add_circle_outline,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Add Size',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Supplements for this variant/global
          const Divider(
            height: 24,
            thickness: 1,
            color: Colors.grey,
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: variantSupplements.map((supplementJson) {
                    final supplement = supplementJson;
                    final supplementId = supplement['id'] as String? ?? '';
                    final name = supplement['name'] ?? '';
                    final price = supplement['price'] ?? 0.0;
                    final isAvailable = supplement['is_available'] ?? true;

                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isAvailable
                              ? Colors.grey[300]!
                              : Colors.grey[400]!,
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            size: 14,
                            color: isAvailable
                                ? Colors.blue[700]
                                : Colors.grey[600],
                          ),
                          const SizedBox(width: 6),
                          Text(
                            name,
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '+${price.toStringAsFixed(0)} DZD',
                            style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: const Color(0xFFd47b00),
                            ),
                          ),
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: () => onDeleteSupplement(supplementId),
                            child: const Padding(
                              padding: EdgeInsets.all(4),
                              child: Icon(
                                Icons.delete,
                                size: 14,
                                color: Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: () => onAddSupplement(variantId),
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
                      const Icon(
                        Icons.add_circle_outline,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Add Supp',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
