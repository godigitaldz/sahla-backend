import 'package:flutter/widgets.dart';

import '../l10n/app_localizations.dart';

class PriceFormatter {
  /// Formats a price string by adding spaces between every 3 digits
  /// Example: "1500" becomes "1 500", "150000" becomes "150 000"
  static String formatPrice(String price, {bool useNonBreakingSpace = false}) {
    // Remove any existing spaces and non-digit characters (drop decimals entirely)
    final String cleanPrice = price.replaceAll(RegExp(r'[^\d]'), '');

    // Use only the whole number part; decimals are intentionally ignored globally
    final String wholePart = cleanPrice.isEmpty ? '0' : cleanPrice;

    // Add spaces every 3 digits from right to left
    final buffer = StringBuffer();
    final spaceChar = useNonBreakingSpace ? '\u00A0' : ' ';
    for (int i = 0; i < wholePart.length; i++) {
      if (i > 0 && (wholePart.length - i) % 3 == 0) {
        buffer.write(spaceChar);
      }
      buffer.write(wholePart[i]);
    }
    final formattedWhole = buffer.toString();

    // Always return integer-formatted price (no decimals by policy)
    return formattedWhole;
  }

  /// Formats a price with localized currency
  /// Keeps spacing rule for thousands
  static String formatWithSettings(BuildContext context, String price) {
    final l10n = AppLocalizations.of(context);
    final currency = l10n?.currency ?? 'DA';
    final isArabic = Localizations.localeOf(context).languageCode == 'ar';

    // Normalize by rounding to nearest integer to remove decimals globally
    String normalized = price;
    try {
      final parsed = double.parse(price.replaceAll(',', '.'));
      final roundedInt = parsed.round();
      normalized = roundedInt.toString();
    } catch (_) {
      // Fallback: keep original if parsing fails
    }

    // For Arabic (RTL), use non-breaking spaces to prevent text reflection issues
    final formatted = formatPrice(normalized, useNonBreakingSpace: isArabic);

    if (isArabic) {
      return '$formatted\u00A0$currency'; // \u00A0 is non-breaking space
    }

    return '$formatted $currency';
  }

  /// Legacy helpers kept for backward compatibility (defaults to DA)
  static String formatPriceWithCurrency(String price,
      {String currency = 'DA'}) {
    final String formattedPrice = formatPrice(price);
    return '$formattedPrice $currency';
  }
}
