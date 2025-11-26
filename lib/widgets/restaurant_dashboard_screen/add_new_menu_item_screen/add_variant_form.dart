import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../config/menu_item_form_controller.dart';
import '../../../l10n/app_localizations.dart';

/// A form widget for adding new menu item variants.
///
/// This widget manages its own text controller and provides a clean interface
/// for adding variants with validation and auto-clearing functionality.
///
/// Features:
/// - Text input with validation
/// - Add button with icon
/// - Auto-clears input after successful submission
/// - Proper controller disposal
/// - Helpful hints and descriptions
///
/// Example usage:
/// ```dart
/// AddVariantForm(
///   formController: menuItemFormController,
///   onVariantAdded: () => print('Variant added!'),
/// )
/// ```
class AddVariantForm extends StatefulWidget {
  /// The form controller that manages menu item state
  final MenuItemFormController formController;

  /// Optional callback when a variant is successfully added
  final VoidCallback? onVariantAdded;

  /// Primary color for the form (defaults to orange)
  final Color? primaryColor;

  /// If true, shows "Add Pack Item" instead of "Add Variant"
  final bool isPackItem;

  const AddVariantForm({
    required this.formController,
    this.onVariantAdded,
    this.primaryColor,
    this.isPackItem = false,
    super.key,
  });

  @override
  State<AddVariantForm> createState() => _AddVariantFormState();
}

class _AddVariantFormState extends State<AddVariantForm> {
  late final TextEditingController _variantNameController;
  late final TextEditingController _quantityController;
  static const _defaultPrimaryColor = Color(0xFFd47b00);

  @override
  void initState() {
    super.initState();
    _variantNameController = TextEditingController();
    _quantityController =
        TextEditingController(text: '1'); // Default quantity is 1
  }

  @override
  void dispose() {
    _variantNameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Color get _primaryColor => widget.primaryColor ?? _defaultPrimaryColor;

  /// Adds a variant from the text input
  void _addVariantFromInput() {
    final value = _variantNameController.text.trim();
    if (value.isNotEmpty) {
      // For pack items, include quantity in description
      String? description;
      if (widget.isPackItem) {
        final quantity = int.tryParse(_quantityController.text.trim()) ?? 1;
        description = 'qty:$quantity'; // Store quantity in description
      }

      widget.formController.addVariant(
        value,
        description,
        isDefault: widget.formController.variants.isEmpty,
      );
      _variantNameController.clear();
      _quantityController.text = '1'; // Reset quantity to 1
      widget.onVariantAdded?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPackItem = widget.isPackItem;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isPackItem
                ? 'Add Pack Item'
                : AppLocalizations.of(context)!.addNewVariant,
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isPackItem
                ? 'Add individual items included in this pack'
                : AppLocalizations.of(context)!.createDifferentVersionsOfDish,
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
          ),
          const SizedBox(height: 12),
          // Item name input field
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: TextFormField(
              controller: _variantNameController,
              decoration: InputDecoration(
                hintText: isPackItem
                    ? 'Item name (e.g., Burger, Fries, Drink)'
                    : '${AppLocalizations.of(context)!.variantName} (e.g., Classic)',
                hintStyle: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[400],
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                  borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                  borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(26),
                  borderSide:
                      BorderSide(color: Colors.orange[600]!, width: 1.5),
                ),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              ),
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _addVariantFromInput(),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Quantity selector and add button row
          Row(
            children: [
              // Quantity selector (only for pack items)
              if (isPackItem) ...[
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(25),
                    border: Border.all(color: Colors.grey[300]!, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Decrement button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            final currentValue =
                                int.tryParse(_quantityController.text) ?? 1;
                            if (currentValue > 1) {
                              setState(() {
                                _quantityController.text =
                                    (currentValue - 1).toString();
                              });
                            }
                          },
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(25),
                            bottomLeft: Radius.circular(25),
                          ),
                          child: Container(
                            width: 36,
                            height: 44,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.remove,
                              size: 18,
                              color: _primaryColor,
                            ),
                          ),
                        ),
                      ),
                      // Quantity display (without x)
                      Container(
                        width: 50,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border.symmetric(
                            vertical:
                                BorderSide(color: Colors.grey[200]!, width: 1),
                          ),
                        ),
                        child: Text(
                          '${int.tryParse(_quantityController.text) ?? 1}',
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      // Increment button
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            final currentValue =
                                int.tryParse(_quantityController.text) ?? 1;
                            if (currentValue < 99) {
                              setState(() {
                                _quantityController.text =
                                    (currentValue + 1).toString();
                              });
                            }
                          },
                          borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(25),
                            bottomRight: Radius.circular(25),
                          ),
                          child: Container(
                            width: 36,
                            height: 44,
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.add,
                              size: 18,
                              color: _primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
              ],
              // Add button (full width if no quantity selector)
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: _primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(25),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: _addVariantFromInput,
                      borderRadius: BorderRadius.circular(25),
                      child: Container(
                        height: 44,
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.add_circle,
                                color: _primaryColor, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              isPackItem
                                  ? 'Add Item'
                                  : AppLocalizations.of(context)!.addVariant,
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _primaryColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isPackItem
                ? 'Use +/- to set quantity, then enter item name'
                : AppLocalizations.of(context)!
                    .eachVariantCanHaveDifferentSizes,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey[500],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}
