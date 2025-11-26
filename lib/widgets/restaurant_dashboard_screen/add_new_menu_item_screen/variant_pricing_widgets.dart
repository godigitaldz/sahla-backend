import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/menu_item_pricing.dart';
import '../../../models/menu_item_variant.dart';

/// Widget for displaying a variant item card with pricing options
class VariantItemCard extends StatefulWidget {
  final MenuItemVariant variant;
  final List<MenuItemPricing> pricing;
  final VoidCallback onRemove;
  final void Function(String pricingId) onRemovePricing;
  final bool isLTO;

  const VariantItemCard({
    required this.variant,
    required this.pricing,
    required this.onRemove,
    required this.onRemovePricing,
    this.isLTO = false,
    super.key,
  });

  @override
  State<VariantItemCard> createState() => _VariantItemCardState();
}

class _VariantItemCardState extends State<VariantItemCard> {
  bool _isExpanded = true; // Start expanded by default
  static const _primaryColor = Color(0xFFd47b00);

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildVariantHeader(),
          if (_isExpanded) ...[
            if (widget.pricing.isNotEmpty) _buildPricingList(),
          ],
        ],
      ),
    );
  }

  Widget _buildVariantHeader() {
    return InkWell(
      onTap: () {
        setState(() {
          _isExpanded = !_isExpanded;
        });
      },
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              _isExpanded ? Icons.expand_more : Icons.chevron_right,
              color: Colors.black87,
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.variant.name,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  if (widget.pricing.isNotEmpty && !_isExpanded)
                    Text(
                      '${widget.pricing.length} size${widget.pricing.length > 1 ? 's' : ''}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                ],
              ),
            ),
            if (widget.variant.isDefault)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: _primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  AppLocalizations.of(context)!.defaultVariant,
                  style: GoogleFonts.poppins(
                    fontSize: 10,
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            GestureDetector(
              onTap: () {
                widget.onRemove();
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                child: const Icon(Icons.delete, color: Colors.red, size: 20),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPricingList() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        children: widget.pricing
            .map((p) => PricingOptionItem(
                  pricing: p,
                  onRemove: () => widget.onRemovePricing(p.id),
                  isLTO: widget.isLTO,
                ))
            .toList(),
      ),
    );
  }
}

/// Widget for displaying a single pricing option
class PricingOptionItem extends StatelessWidget {
  final MenuItemPricing pricing;
  final VoidCallback onRemove;
  final bool isLTO;

  const PricingOptionItem({
    required this.pricing,
    required this.onRemove,
    this.isLTO = false,
    super.key,
  });

  static const _primaryColor = Color(0xFFd47b00);

  @override
  Widget build(BuildContext context) {
    // In LTO mode, if price > 0, show as add-on (+X DA)
    // If price == 0 in LTO mode, show "Included"
    final bool isAddOn = isLTO && pricing.price > 0;
    final bool isIncluded = isLTO && pricing.price == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: Colors.grey[300]!, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    pricing.size.isEmpty ? 'Standard' : pricing.size,
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: pricing.size.isEmpty
                          ? Colors.grey[600]
                          : Colors.black87,
                    ),
                  ),
                  if (pricing.portion.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      pricing.portion,
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                  if (pricing.freeDrinksIncluded) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.local_drink,
                          size: 14,
                          color: Colors.green,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Free Drinks',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                isIncluded
                    ? 'Included'
                    : isAddOn
                        ? '+${pricing.price.toStringAsFixed(0)} DA'
                        : '${pricing.price.toStringAsFixed(0)} DA',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isIncluded ? Colors.green : _primaryColor,
                ),
              ),
            ),
            GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                child: const Icon(Icons.close, size: 20, color: Colors.red),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
