import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../models/menu_item.dart';
import '../../../../menu_item_full_popup/helpers/special_pack_helper.dart';
import '../Common/edit_ingredients_dialog.dart';

/// Widget for displaying and editing global main ingredients in special pack
class LTOGlobalIngredientsWidget extends StatelessWidget {
  final MenuItem menuItem;
  final Function(String?) onUpdateGlobalIngredients;

  const LTOGlobalIngredientsWidget({
    required this.menuItem,
    required this.onUpdateGlobalIngredients,
    super.key,
  });

  Future<void> _editGlobalIngredients(BuildContext context) async {
    // Get current global ingredients
    final globalIngredients = SpecialPackHelper.getGlobalIngredients(menuItem);

    // Join ingredients with comma for main ingredients field
    final mainIngredientsText = globalIngredients.join(', ');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => LTOEditIngredientsDialog(
        initialMainIngredients: mainIngredientsText,
        initialIngredients: [], // Empty list - we only show main ingredients
        showMainIngredients: true, // Show main ingredients only
      ),
    );

    if (result == null) return;

    final updatedMainIngredients = result['mainIngredients'] as String?;

    // Call update callback
    onUpdateGlobalIngredients(updatedMainIngredients);
  }

  @override
  Widget build(BuildContext context) {
    // Get global ingredients
    final globalIngredients = SpecialPackHelper.getGlobalIngredients(menuItem);

    if (globalIngredients.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title with Manage button
        Row(
          children: [
            Expanded(
              child: Text(
                'Main Global Ingredients',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            // Manage button
            InkWell(
              onTap: () => _editGlobalIngredients(context),
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
        // Ingredients chips
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: globalIngredients.map((ingredient) {
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
      ],
    );
  }
}
