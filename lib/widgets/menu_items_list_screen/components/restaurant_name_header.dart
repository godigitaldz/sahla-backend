import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';

/// Isolated restaurant name header widget
/// Const widget that never rebuilds
class RestaurantNameHeader extends StatelessWidget {
  const RestaurantNameHeader({
    required this.restaurantName,
    required this.fontSize,
    super.key,
  });

  final String? restaurantName;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Text(
      restaurantName ?? l10n.restaurant,
      style: GoogleFonts.poppins(
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        color: Colors.grey[700],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

