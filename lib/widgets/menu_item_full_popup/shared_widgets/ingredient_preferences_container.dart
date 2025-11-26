import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../l10n/app_localizations.dart';
import '../../../models/ingredient_preference.dart';

/// Reusable ingredient preferences container widget
/// Displays a legend showing the available ingredient preference options
/// with full localization support (en, fr, ar)
/// Optionally displays all ingredients from pack items or regular items
class IngredientPreferencesContainer extends StatelessWidget {
  /// Optional: List of ingredients to display (for special pack)
  /// Each entry contains: (variantName, quantityIndex, ingredient)
  final List<({String variantName, int quantityIndex, String ingredient})>?
      packIngredients;

  /// Optional: Ingredient preferences map for pack ingredients
  final Map<String, Map<int, Map<String, IngredientPreference>>>?
      packIngredientPreferences;

  /// Optional: Callback when an ingredient is tapped (for pack items)
  final void Function(String variantName, int quantityIndex, String ingredient)?
      onIngredientTapped;

  /// Optional: List of ingredients to display (for regular items)
  final List<String>? regularIngredients;

  /// Optional: Ingredient preferences map for regular items
  final Map<String, IngredientPreference>? regularIngredientPreferences;

  /// Optional: Callback when an ingredient is tapped (for regular items)
  final void Function(String ingredient)? onRegularIngredientTapped;

  /// Optional: Helper functions for pack ingredients
  final Color Function(IngredientPreference)? getBackgroundColor;
  final Color Function(IngredientPreference)? getBorderColor;
  final IconData Function(IngredientPreference)? getIcon;
  final Color Function(IngredientPreference)? getIconColor;
  final Color Function(IngredientPreference)? getTextColor;

  /// Optional: Main ingredients to display at the bottom (for regular items and special packs)
  final List<String>? mainIngredients;

  const IngredientPreferencesContainer({
    this.packIngredients,
    this.packIngredientPreferences,
    this.onIngredientTapped,
    this.regularIngredients,
    this.regularIngredientPreferences,
    this.onRegularIngredientTapped,
    this.getBackgroundColor,
    this.getBorderColor,
    this.getIcon,
    this.getIconColor,
    this.getTextColor,
    this.mainIngredients,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${l10n.ingredientPreferences}:',
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              Text(
                l10n.optional,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            l10n.choosePreferencesForEachItem,
            style: GoogleFonts.poppins(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildLegendItem(
                  context: context,
                  icon: Icons.radio_button_unchecked,
                  iconColor: Colors.grey[400]!,
                  label: l10n.normal,
                ),
                const SizedBox(width: 16),
                _buildLegendItem(
                  context: context,
                  icon: Icons.add_circle,
                  iconColor: Colors.green,
                  label: l10n.more,
                ),
                const SizedBox(width: 16),
                _buildLegendItem(
                  context: context,
                  icon: Icons.remove_circle_outline,
                  iconColor: Colors.orange,
                  label: l10n.less,
                ),
                const SizedBox(width: 16),
                _buildLegendItem(
                  context: context,
                  icon: Icons.cancel,
                  iconColor: Colors.red,
                  label: l10n.no,
                ),
              ],
            ),
          ),
          // Display all ingredients if provided (pack items or regular items)
          if ((packIngredients != null &&
                  packIngredients!.isNotEmpty &&
                  packIngredientPreferences != null &&
                  onIngredientTapped != null) ||
              (regularIngredients != null &&
                  regularIngredients!.isNotEmpty &&
                  regularIngredientPreferences != null &&
                  onRegularIngredientTapped != null)) ...[
            const SizedBox(height: 16),
            Divider(height: 1, color: Colors.grey[300]),
            const SizedBox(height: 12),
            // Display pack ingredients
            if (packIngredients != null &&
                packIngredients!.isNotEmpty &&
                packIngredientPreferences != null &&
                onIngredientTapped != null &&
                getBackgroundColor != null &&
                getBorderColor != null &&
                getIcon != null &&
                getIconColor != null &&
                getTextColor != null)
              ...packIngredients!.map((entry) {
                final pref = packIngredientPreferences![entry.variantName]
                        ?[entry.quantityIndex]?[entry.ingredient] ??
                    IngredientPreference.neutral;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      // Ingredient name on the left
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // Calculate font size to fit 23 characters in available width
                            const targetChars = 23;
                            const baseFontSize = 13.0;
                            final availableWidth = constraints.maxWidth;
                            // Estimate character width (approximate: 0.6 * fontSize for Poppins)
                            const charWidth = baseFontSize * 0.6;
                            const targetWidth = targetChars * charWidth;

                            // Calculate responsive font size
                            double fontSize = baseFontSize;
                            if (availableWidth < targetWidth) {
                              fontSize = (availableWidth / targetChars) / 0.6;
                              fontSize =
                                  fontSize.clamp(10.0, 13.0); // Min 10, Max 13
                            }

                            return Text(
                              entry.ingredient,
                              style: GoogleFonts.poppins(
                                fontSize: fontSize,
                                fontWeight: FontWeight.normal,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Select button on the right
                      GestureDetector(
                        onTap: () => onIngredientTapped!(
                          entry.variantName,
                          entry.quantityIndex,
                          entry.ingredient,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: getBackgroundColor!(pref),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: getBorderColor!(pref),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                getIcon!(pref),
                                size: 14,
                                color: getIconColor!(pref),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _getPreferenceLabel(pref, l10n),
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: getTextColor!(pref),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            // Display regular item ingredients
            if (regularIngredients != null &&
                regularIngredients!.isNotEmpty &&
                regularIngredientPreferences != null &&
                onRegularIngredientTapped != null &&
                getBackgroundColor != null &&
                getBorderColor != null &&
                getIcon != null &&
                getIconColor != null &&
                getTextColor != null)
              ...regularIngredients!.map((ingredient) {
                final pref = regularIngredientPreferences![ingredient] ??
                    IngredientPreference.neutral;

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      // Ingredient name on the left
                      Expanded(
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            // Calculate font size to fit 23 characters in available width
                            const targetChars = 23;
                            const baseFontSize = 13.0;
                            final availableWidth = constraints.maxWidth;
                            // Estimate character width (approximate: 0.6 * fontSize for Poppins)
                            const charWidth = baseFontSize * 0.6;
                            const targetWidth = targetChars * charWidth;

                            // Calculate responsive font size
                            double fontSize = baseFontSize;
                            if (availableWidth < targetWidth) {
                              fontSize = (availableWidth / targetChars) / 0.6;
                              fontSize =
                                  fontSize.clamp(10.0, 13.0); // Min 10, Max 13
                            }

                            return Text(
                              ingredient,
                              style: GoogleFonts.poppins(
                                fontSize: fontSize,
                                fontWeight: FontWeight.normal,
                                color: Colors.black87,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Select button on the right
                      GestureDetector(
                        onTap: () => onRegularIngredientTapped!(ingredient),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: getBackgroundColor!(pref),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: getBorderColor!(pref),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                getIcon!(pref),
                                size: 14,
                                color: getIconColor!(pref),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _getPreferenceLabel(pref, l10n),
                                style: GoogleFonts.poppins(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: getTextColor!(pref),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
          ],
          // Main ingredients chips at the bottom with horizontal scroll
          if (mainIngredients != null && mainIngredients!.isNotEmpty) ...[
            const SizedBox(height: 0),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Main ingredients (display only)
                  ...mainIngredients!.map((ing) {
                    // PERFORMANCE FIX: Wrap in RepaintBoundary to isolate repaints
                    return RepaintBoundary(
                      child: Container(
                        margin: const EdgeInsets.only(right: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.check_circle,
                                size: 12, color: Colors.green[600]),
                            const SizedBox(width: 4),
                            Text(
                              ing,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                color: Colors.black87,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getPreferenceLabel(
    IngredientPreference preference,
    AppLocalizations l10n,
  ) {
    switch (preference) {
      case IngredientPreference.neutral:
        return l10n.normal;
      case IngredientPreference.wanted:
        return l10n.more;
      case IngredientPreference.less:
        return l10n.less;
      case IngredientPreference.none:
        return l10n.no;
    }
  }

  Widget _buildLegendItem({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required String label,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 10,
            color: Colors.grey[700],
          ),
        ),
      ],
    );
  }
}
