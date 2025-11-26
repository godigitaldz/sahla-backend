import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../menu_item_full_popup/helpers/special_pack_helper.dart';

/// Variant Parsing Utilities
/// Provides parsing methods for variant description strings
class VariantParsingUtils {
  /// Parse hidden options from variant description
  /// Format: "qty:2|options:A,B|hidden_options:C,D|ingredients:..."
  /// Returns: ['C', 'D']
  static List<String> parseHiddenOptions(String? description) {
    if (description == null || !description.contains('|hidden_options:')) {
      return [];
    }

    try {
      final parts = description.split('|hidden_options:');
      if (parts.length > 1) {
        // Get the hidden_options part and stop at the next separator
        final hiddenOptionsPart = parts[1].split('|')[0];
        return hiddenOptionsPart
            .split(',')
            .map((o) => o.trim())
            .where((o) => o.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('❌ Error parsing hidden options: $e');
    }
    return [];
  }

  /// Parse main ingredients from variant description
  /// Format: "qty:2|main_ingredients:sauce,frite,spice|ingredients:..."
  /// Returns: "sauce,frite,spice" or null
  static String? parseMainIngredients(String? description) {
    if (description == null || !description.contains('|main_ingredients:')) {
      return null;
    }

    try {
      final parts = description.split('|main_ingredients:');
      if (parts.length > 1) {
        // Get the main_ingredients part and stop at the next separator
        final mainIngredientsPart = parts[1].split('|')[0];
        return mainIngredientsPart.trim().isEmpty
            ? null
            : mainIngredientsPart.trim();
      }
    } catch (e) {
      debugPrint('❌ Error parsing main ingredients: $e');
    }
    return null;
  }

  /// Parse hidden supplements from variant description
  /// Format: "qty:2|options:A,B|hidden_supplements:Supp1,Supp2|ingredients:..."
  /// Returns: ['Supp1', 'Supp2']
  static List<String> parseHiddenSupplements(String? description) {
    if (description == null || !description.contains('|hidden_supplements:')) {
      return [];
    }

    try {
      final parts = description.split('|hidden_supplements:');
      if (parts.length > 1) {
        // Get the hidden_supplements part and stop at the next separator
        final hiddenSupplementsPart = parts[1].split('|')[0];
        return hiddenSupplementsPart
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('❌ Error parsing hidden supplements: $e');
    }
    return [];
  }

  /// Build description string from components
  static String buildDescription({
    required int quantity,
    List<String>? options,
    List<String>? ingredients,
    List<String>? hiddenOptions,
    List<String>? hiddenSupplements,
    String? mainIngredients,
    Map<String, double>? supplements,
  }) {
    final parts = <String>['qty:$quantity'];
    if (options != null && options.isNotEmpty) {
      parts.add('options:${options.join(',')}');
    }
    if (hiddenOptions != null && hiddenOptions.isNotEmpty) {
      parts.add('hidden_options:${hiddenOptions.join(',')}');
    }
    if (hiddenSupplements != null && hiddenSupplements.isNotEmpty) {
      parts.add('hidden_supplements:${hiddenSupplements.join(',')}');
    }
    if (mainIngredients != null && mainIngredients.isNotEmpty) {
      parts.add('main_ingredients:$mainIngredients');
    }
    if (ingredients != null && ingredients.isNotEmpty) {
      parts.add('ingredients:${ingredients.join(',')}');
    }
    if (supplements != null && supplements.isNotEmpty) {
      final supplementParts = <String>[];
      supplements.forEach((name, price) {
        supplementParts.add('$name:$price');
      });
      parts.add('supplements:${supplementParts.join(',')}');
    }
    return parts.join('|');
  }
}

/// Variant Operations Helper
/// Provides business logic for variant operations (option management, description building)
class VariantOperationsHelper {
  /// Build updated description when adding an option
  static String? buildDescriptionForAddOption({
    required String variantDescription,
    required String newOption,
    required List<String> currentOptions,
    required List<String> currentHiddenOptions,
  }) {
    // Check if option already exists (in visible or hidden)
    if (currentOptions.contains(newOption) ||
        currentHiddenOptions.contains(newOption)) {
      return null; // Option already exists
    }

    // Parse current values
    final currentQuantity = SpecialPackHelper.parseQuantity(variantDescription);
    final currentIngredients =
        SpecialPackHelper.parseIngredients(variantDescription);
    final currentHiddenSupplements =
        VariantParsingUtils.parseHiddenSupplements(variantDescription);
    final currentMainIngredients =
        VariantParsingUtils.parseMainIngredients(variantDescription);
    final currentSupplements =
        SpecialPackHelper.parseSupplements(variantDescription);

    // Add the new option
    final updatedOptions = [...currentOptions, newOption];

    // Rebuild description (preserve hidden options, hidden supplements, supplements, and main ingredients)
    return VariantParsingUtils.buildDescription(
      quantity: currentQuantity,
      options: updatedOptions,
      ingredients: currentIngredients,
      hiddenOptions: currentHiddenOptions,
      hiddenSupplements: currentHiddenSupplements,
      mainIngredients: currentMainIngredients,
      supplements: currentSupplements,
    );
  }

  /// Build updated description when deleting an option
  static String buildDescriptionForDeleteOption({
    required String variantDescription,
    required String optionToDelete,
  }) {
    // Parse current values
    final currentQuantity = SpecialPackHelper.parseQuantity(variantDescription);
    final currentOptions = SpecialPackHelper.parseOptions(variantDescription);
    final currentIngredients =
        SpecialPackHelper.parseIngredients(variantDescription);
    final currentHiddenOptions =
        VariantParsingUtils.parseHiddenOptions(variantDescription);
    final currentHiddenSupplements =
        VariantParsingUtils.parseHiddenSupplements(variantDescription);
    final currentMainIngredients =
        VariantParsingUtils.parseMainIngredients(variantDescription);
    final currentSupplements =
        SpecialPackHelper.parseSupplements(variantDescription);

    // Remove the option (also remove from hidden if it was there)
    final updatedOptions =
        currentOptions.where((o) => o != optionToDelete).toList();
    final updatedHiddenOptions =
        currentHiddenOptions.where((o) => o != optionToDelete).toList();

    // Rebuild description (preserve supplements)
    return VariantParsingUtils.buildDescription(
      quantity: currentQuantity,
      options: updatedOptions,
      ingredients: currentIngredients,
      hiddenOptions: updatedHiddenOptions,
      hiddenSupplements: currentHiddenSupplements,
      mainIngredients: currentMainIngredients,
      supplements: currentSupplements,
    );
  }

  /// Build updated description when toggling option visibility
  static (List<String> updatedOptions, List<String> updatedHiddenOptions)?
      toggleOptionVisibility({
    required String variantDescription,
    required String option,
    required List<String> currentOptions,
    required List<String> currentHiddenOptions,
  }) {
    // Check if option is currently visible or hidden
    final isCurrentlyVisible = currentOptions.contains(option);
    final isCurrentlyHidden = currentHiddenOptions.contains(option);

    List<String> updatedOptions;
    List<String> updatedHiddenOptions;

    if (isCurrentlyVisible) {
      // Hide: move from visible to hidden
      // Check if this is the last visible option
      if (currentOptions.length <= 1) {
        return null; // Cannot hide the last option
      }

      // Remove from visible, add to hidden
      updatedOptions = currentOptions.where((o) => o != option).toList();
      updatedHiddenOptions = [...currentHiddenOptions, option];
    } else if (isCurrentlyHidden) {
      // Show: move from hidden to visible
      updatedOptions = [...currentOptions, option];
      updatedHiddenOptions =
          currentHiddenOptions.where((o) => o != option).toList();
    } else {
      return null; // Option not found
    }

    return (updatedOptions, updatedHiddenOptions);
  }

  /// Build updated description with new quantity
  static String buildDescriptionWithNewQuantity({
    required String variantDescription,
    required int newQuantity,
  }) {
    // Parse current values
    final currentOptions = SpecialPackHelper.parseOptions(variantDescription);
    final currentIngredients =
        SpecialPackHelper.parseIngredients(variantDescription);
    final currentHiddenOptions =
        VariantParsingUtils.parseHiddenOptions(variantDescription);
    final currentHiddenSupplements =
        VariantParsingUtils.parseHiddenSupplements(variantDescription);
    final currentMainIngredients =
        VariantParsingUtils.parseMainIngredients(variantDescription);
    final currentSupplements =
        SpecialPackHelper.parseSupplements(variantDescription);

    // Rebuild description with new quantity (preserve hidden options, hidden supplements, supplements, and main ingredients)
    return VariantParsingUtils.buildDescription(
      quantity: newQuantity,
      options: currentOptions,
      ingredients: currentIngredients,
      hiddenOptions: currentHiddenOptions,
      hiddenSupplements: currentHiddenSupplements,
      mainIngredients: currentMainIngredients,
      supplements: currentSupplements,
    );
  }

  /// Build updated description with updated ingredients
  static String buildDescriptionWithUpdatedIngredients({
    required String variantDescription,
    required String? mainIngredients,
    required List<String>? ingredients,
  }) {
    // Parse current values
    final currentQuantity = SpecialPackHelper.parseQuantity(variantDescription);
    final currentOptions = SpecialPackHelper.parseOptions(variantDescription);
    final currentHiddenOptions =
        VariantParsingUtils.parseHiddenOptions(variantDescription);
    final currentHiddenSupplements =
        VariantParsingUtils.parseHiddenSupplements(variantDescription);
    final currentSupplements =
        SpecialPackHelper.parseSupplements(variantDescription);

    // Rebuild description with updated ingredients (preserve hidden supplements and supplements)
    return VariantParsingUtils.buildDescription(
      quantity: currentQuantity,
      options: currentOptions,
      ingredients: ingredients ?? [],
      hiddenOptions: currentHiddenOptions,
      hiddenSupplements: currentHiddenSupplements,
      mainIngredients: mainIngredients,
      supplements: currentSupplements,
    );
  }

  /// Build updated description with updated supplements
  static String buildDescriptionWithUpdatedSupplements({
    required String variantDescription,
    required Map<String, double> supplements,
    required List<String> updatedHiddenSupplements,
  }) {
    // Parse current values
    final currentQuantity = SpecialPackHelper.parseQuantity(variantDescription);
    final currentOptions = SpecialPackHelper.parseOptions(variantDescription);
    final currentHiddenOptions =
        VariantParsingUtils.parseHiddenOptions(variantDescription);
    final currentIngredients =
        SpecialPackHelper.parseIngredients(variantDescription);
    final currentMainIngredients =
        VariantParsingUtils.parseMainIngredients(variantDescription);

    // Rebuild description (preserve hidden options, hidden supplements, and main ingredients)
    return VariantParsingUtils.buildDescription(
      quantity: currentQuantity,
      options: currentOptions,
      ingredients: currentIngredients,
      hiddenOptions: currentHiddenOptions,
      hiddenSupplements: updatedHiddenSupplements,
      mainIngredients: currentMainIngredients,
      supplements: supplements,
    );
  }

  /// Build description for adding supplement to variant
  static String? buildDescriptionForAddSupplement({
    required String variantDescription,
    required String supplementName,
    required double supplementPrice,
    required Map<String, double> currentSupplements,
  }) {
    // Check if supplement already exists
    if (currentSupplements.containsKey(supplementName)) {
      return null; // Supplement already exists
    }

    // Add the new supplement
    final updatedSupplements = Map<String, double>.from(currentSupplements);
    updatedSupplements[supplementName] = supplementPrice;

    // Parse current values
    final currentQuantity = SpecialPackHelper.parseQuantity(variantDescription);
    final currentOptions = SpecialPackHelper.parseOptions(variantDescription);
    final currentHiddenOptions =
        VariantParsingUtils.parseHiddenOptions(variantDescription);
    final currentHiddenSupplements =
        VariantParsingUtils.parseHiddenSupplements(variantDescription);
    final currentIngredients =
        SpecialPackHelper.parseIngredients(variantDescription);
    final currentMainIngredients =
        VariantParsingUtils.parseMainIngredients(variantDescription);

    // Rebuild description (preserve hidden options, hidden supplements, and main ingredients)
    return VariantParsingUtils.buildDescription(
      quantity: currentQuantity,
      options: currentOptions,
      ingredients: currentIngredients,
      hiddenOptions: currentHiddenOptions,
      hiddenSupplements: currentHiddenSupplements,
      mainIngredients: currentMainIngredients,
      supplements: updatedSupplements,
    );
  }

  /// Build description for deleting supplement from variant
  static String buildDescriptionForDeleteSupplement({
    required String variantDescription,
    required String supplementName,
  }) {
    // Parse current values
    final currentQuantity = SpecialPackHelper.parseQuantity(variantDescription);
    final currentOptions = SpecialPackHelper.parseOptions(variantDescription);
    final currentHiddenOptions =
        VariantParsingUtils.parseHiddenOptions(variantDescription);
    final currentHiddenSupplements =
        VariantParsingUtils.parseHiddenSupplements(variantDescription);
    final currentIngredients =
        SpecialPackHelper.parseIngredients(variantDescription);
    final currentMainIngredients =
        VariantParsingUtils.parseMainIngredients(variantDescription);
    final currentSupplements =
        SpecialPackHelper.parseSupplements(variantDescription);

    // Remove supplement from description
    final updatedSupplements = Map<String, double>.from(currentSupplements);
    updatedSupplements.remove(supplementName);

    // Also remove from hidden supplements if it was there
    final updatedHiddenSupplements =
        currentHiddenSupplements.where((s) => s != supplementName).toList();

    // Rebuild description (includes supplements)
    return VariantParsingUtils.buildDescription(
      quantity: currentQuantity,
      options: currentOptions,
      ingredients: currentIngredients,
      hiddenOptions: currentHiddenOptions,
      hiddenSupplements: updatedHiddenSupplements,
      mainIngredients: currentMainIngredients,
      supplements: updatedSupplements,
    );
  }

  /// Build description for toggling supplement visibility
  static String buildDescriptionForToggleSupplementVisibility({
    required String variantDescription,
    required String supplementName,
    required bool isAvailable,
    required List<String> currentHiddenSupplements,
  }) {
    // Parse current values
    final currentQuantity = SpecialPackHelper.parseQuantity(variantDescription);
    final currentOptions = SpecialPackHelper.parseOptions(variantDescription);
    final currentHiddenOptions =
        VariantParsingUtils.parseHiddenOptions(variantDescription);
    final currentIngredients =
        SpecialPackHelper.parseIngredients(variantDescription);
    final currentMainIngredients =
        VariantParsingUtils.parseMainIngredients(variantDescription);
    final currentSupplements =
        SpecialPackHelper.parseSupplements(variantDescription);

    // Update hidden supplements list
    final updatedHiddenSupplements =
        List<String>.from(currentHiddenSupplements);
    if (isAvailable) {
      // Show: remove from hidden list
      updatedHiddenSupplements.remove(supplementName);
    } else {
      // Hide: add to hidden list
      if (!updatedHiddenSupplements.contains(supplementName)) {
        updatedHiddenSupplements.add(supplementName);
      }
    }

    // Rebuild description (includes supplements)
    return VariantParsingUtils.buildDescription(
      quantity: currentQuantity,
      options: currentOptions,
      ingredients: currentIngredients,
      hiddenOptions: currentHiddenOptions,
      hiddenSupplements: updatedHiddenSupplements,
      mainIngredients: currentMainIngredients,
      supplements: currentSupplements,
    );
  }

  /// Build description with updated options and hidden options
  static String buildDescriptionWithUpdatedOptions({
    required String variantDescription,
    required List<String> updatedOptions,
    required List<String> updatedHiddenOptions,
  }) {
    // Parse current values
    final currentQuantity = SpecialPackHelper.parseQuantity(variantDescription);
    final currentIngredients =
        SpecialPackHelper.parseIngredients(variantDescription);
    final currentHiddenSupplements =
        VariantParsingUtils.parseHiddenSupplements(variantDescription);
    final currentMainIngredients =
        VariantParsingUtils.parseMainIngredients(variantDescription);
    final currentSupplements =
        SpecialPackHelper.parseSupplements(variantDescription);

    // Rebuild description (preserve supplements)
    return VariantParsingUtils.buildDescription(
      quantity: currentQuantity,
      options: updatedOptions,
      ingredients: currentIngredients,
      hiddenOptions: updatedHiddenOptions,
      hiddenSupplements: currentHiddenSupplements,
      mainIngredients: currentMainIngredients,
      supplements: currentSupplements,
    );
  }
}

/// Edit Variant Dialog
/// Dialog for editing variant name and quantity
class EditVariantDialog extends StatelessWidget {
  final String variantName;
  final int currentQuantity;
  final String variantDescription;
  final Function(String newName, int newQuantity) onSave;

  const EditVariantDialog({
    required this.variantName,
    required this.currentQuantity,
    required this.variantDescription,
    required this.onSave,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final nameController = TextEditingController(text: variantName);
    int selectedQuantity = currentQuantity;

    return StatefulBuilder(
      builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Edit Variant',
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
                TextField(
                  controller: nameController,
                  autofocus: true,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Variant Name',
                    hintText: 'Enter variant name',
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
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Quantity',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: selectedQuantity > 1
                          ? () {
                              setDialogState(() {
                                selectedQuantity--;
                              });
                            }
                          : null,
                      color: const Color(0xFFd47b00),
                    ),
                    Container(
                      width: 60,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '$selectedQuantity',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () {
                        setDialogState(() {
                          selectedQuantity++;
                        });
                      },
                      color: const Color(0xFFd47b00),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final newName = nameController.text.trim();
                if (newName.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Variant name cannot be empty'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                onSave(newName, selectedQuantity);
                Navigator.of(context).pop();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFd47b00),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'Save',
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
  }
}
