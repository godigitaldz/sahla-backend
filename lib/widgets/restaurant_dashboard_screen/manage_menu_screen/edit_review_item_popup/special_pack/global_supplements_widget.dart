import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../models/menu_item.dart';
import '../../../../../utils/price_formatter.dart';
import '../../../../menu_item_full_popup/helpers/special_pack_helper.dart';

/// Widget for displaying and managing global supplements in special pack
class LTOGlobalSupplementsWidget extends StatelessWidget {
  final MenuItem menuItem;
  final Function(Map<String, double>) onUpdateGlobalSupplements;
  final Function(String, Map<String, double>) onAddGlobalSupplement;
  final Function(String, Map<String, double>) onDeleteGlobalSupplement;
  final Function(String, Map<String, double>, bool)
      onToggleGlobalSupplementVisibility;

  const LTOGlobalSupplementsWidget({
    required this.menuItem,
    required this.onUpdateGlobalSupplements,
    required this.onAddGlobalSupplement,
    required this.onDeleteGlobalSupplement,
    required this.onToggleGlobalSupplementVisibility,
    super.key,
  });

  Future<void> _addSupplement(BuildContext context) async {
    final nameController = TextEditingController();
    final priceController = TextEditingController(text: '0.0');

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Add Global Supplement',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Name field
                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Supplement Name',
                    hintText: 'Enter supplement name',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFd47b00),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Price field
                TextField(
                  controller: priceController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Price',
                    hintText: '0.0',
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey[400],
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(
                        color: Color(0xFFd47b00),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final priceText = priceController.text.trim();
                final price = double.tryParse(priceText) ?? 0.0;

                if (name.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a supplement name'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                Navigator.of(dialogContext).pop({
                  'name': name,
                  'price': price,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFd47b00),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Add',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (result == null) return;

    final name = result['name'] as String;
    final price = result['price'] as double;

    onAddGlobalSupplement(name, {name: price});
  }

  @override
  Widget build(BuildContext context) {
    // Get global supplements
    final globalSupplements = SpecialPackHelper.getGlobalSupplements(menuItem);

    // Get hidden global supplements
    final hiddenGlobalSupplements =
        SpecialPackHelper.getHiddenGlobalSupplements(menuItem);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section title with Add button
        Row(
          children: [
            Expanded(
              child: Text(
                'Main Global Supplements',
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
            ),
            // Add Supplement button
            InkWell(
              onTap: () => _addSupplement(context),
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
        if (globalSupplements.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Colors.grey[200]!,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: Colors.grey[500],
                ),
                const SizedBox(width: 8),
                Text(
                  'No global supplements added yet',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          )
        else
          Column(
            children: globalSupplements.entries.map((entry) {
              final name = entry.key;
              final price = entry.value;
              final isAvailable = !hiddenGlobalSupplements.contains(name);
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
                      onTap: () => onToggleGlobalSupplementVisibility(
                        name,
                        {name: price},
                        !isAvailable,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: isAvailable
                              ? Colors.grey[200]!
                              : Colors.orange[50]!,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          isAvailable ? Icons.visibility : Icons.visibility_off,
                          size: 16,
                          color: isAvailable
                              ? Colors.grey[700]!
                              : Colors.orange[700]!,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Delete button
                    InkWell(
                      onTap: () => onDeleteGlobalSupplement(
                        name,
                        {name: price},
                      ),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.red[50]!,
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
      ],
    );
  }
}
