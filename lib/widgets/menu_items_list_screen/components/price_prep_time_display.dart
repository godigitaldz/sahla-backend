import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';

/// Isolated price and prep time display widget
/// Const widget that never rebuilds
class PricePrepTimeDisplay extends StatelessWidget {
  const PricePrepTimeDisplay({
    required this.price,
    required this.prepTime,
    required this.priceFontSize,
    required this.prepFontSize,
    required this.iconSize,
    required this.isRTL,
    super.key,
  });

  final double price;
  final int prepTime;
  final double priceFontSize;
  final double prepFontSize;
  final double iconSize;
  final bool isRTL;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12 * 0.9,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
        children: [
          // Price
          Flexible(
            child: Text(
              '${price.toStringAsFixed(0)} DA',
              style: GoogleFonts.poppins(
                fontSize: priceFontSize,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8 * 0.9),
          // Divider
          Container(
            width: 1,
            height: 12 * 0.9,
            color: Colors.grey[300],
          ),
          const SizedBox(width: 8 * 0.9),
          // Prep time icon
          Icon(
            Icons.access_time,
            size: iconSize,
            color: Colors.grey[700],
          ),
          const SizedBox(width: 4 * 0.9),
          // Prep time text
          Text(
            '$prepTime ${l10n.min}',
            style: GoogleFonts.poppins(
              fontSize: prepFontSize,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
}
