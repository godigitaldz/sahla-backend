import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';

/// Isolated delivery fee display widget
/// Rebuilds only when delivery fee changes
class DeliveryFeeDisplay extends StatelessWidget {
  const DeliveryFeeDisplay({
    required this.deliveryFee,
    required this.isLoading,
    required this.fontSize,
    required this.iconSize,
    super.key,
  });

  final double? deliveryFee;
  final bool isLoading;
  final double fontSize;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (isLoading) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.delivery_dining,
            size: iconSize,
            color: Colors.grey[700],
          ),
          const SizedBox(width: 4),
          SizedBox(
            width: fontSize,
            height: fontSize,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.grey[700]!,
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          Icons.delivery_dining,
          size: iconSize,
          color: Colors.grey[700],
        ),
        const SizedBox(width: 4),
        Text(
          (deliveryFee == null || deliveryFee == 0.0)
              ? l10n.freeDelivery
              : '${deliveryFee!.toStringAsFixed(0)} DA',
          style: GoogleFonts.poppins(
            fontSize: fontSize,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}
