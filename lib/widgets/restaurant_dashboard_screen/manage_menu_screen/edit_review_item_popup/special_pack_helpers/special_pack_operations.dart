import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../../core/data/repositories/menu_item_repository.dart';
import '../../../../../models/menu_item.dart';
import '../../../../../services/menu_item_service.dart';
import '../../../../../utils/safe_parse.dart';
import '../../../../menu_item_full_popup/helpers/special_pack_helper.dart';

/// Edit Dialogs
/// Provides common dialog widgets for editing operations
class EditDialogs {
  /// Edit name dialog
  static Future<String?> showEditNameDialog(
    BuildContext context,
    String currentName,
  ) async {
    final nameController = TextEditingController(text: currentName);

    return showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Edit Name'),
          content: TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Item Name',
              hintText: 'Enter item name',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            maxLines: 2,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final newName = nameController.text.trim();
                if (newName.isNotEmpty) {
                  Navigator.of(dialogContext).pop(newName);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  /// Edit price dialog
  static Future<String?> showEditPriceDialog(
    BuildContext context,
    String title,
    double? currentPrice,
  ) async {
    final priceController = TextEditingController(
      text: currentPrice?.toString() ?? '',
    );

    return showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: priceController,
            decoration: const InputDecoration(
              labelText: 'Price',
              hintText: 'Enter price',
              border: OutlineInputBorder(),
              prefixText: 'DZD ',
            ),
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final newPrice = priceController.text.trim();
                if (newPrice.isNotEmpty) {
                  final priceValue = double.tryParse(newPrice);
                  if (priceValue != null && priceValue >= 0) {
                    Navigator.of(dialogContext).pop(newPrice);
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  /// Edit prep time dialog
  static Future<String?> showEditPrepTimeDialog(
    BuildContext context,
    int currentPrepTime,
  ) async {
    final prepTimeController =
        TextEditingController(text: currentPrepTime.toString());

    return showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Edit Preparation Time'),
          content: TextField(
            controller: prepTimeController,
            decoration: const InputDecoration(
              labelText: 'Preparation Time (minutes)',
              hintText: 'Enter preparation time in minutes',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
            keyboardType: TextInputType.number,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final newPrepTime = prepTimeController.text.trim();
                if (newPrepTime.isNotEmpty) {
                  final prepTimeValue = int.tryParse(newPrepTime);
                  if (prepTimeValue != null && prepTimeValue >= 0) {
                    Navigator.of(dialogContext).pop(newPrepTime);
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  /// Add option dialog
  static Future<String?> showAddOptionDialog(BuildContext context) async {
    final optionController = TextEditingController();

    return showDialog<String>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Add Variant',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          content: TextField(
            controller: optionController,
            autofocus: true,
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.black87,
            ),
            decoration: InputDecoration(
              labelText: 'Variant Name',
              hintText: 'Enter variant name (e.g., Poulet, Viande)',
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
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
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
                final newOption = optionController.text.trim();
                if (newOption.isNotEmpty) {
                  Navigator.of(dialogContext).pop(newOption);
                }
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
  }

  /// Add supplement dialog
  static Future<Map<String, dynamic>?> showAddSupplementDialog(
    BuildContext context,
  ) async {
    final nameController = TextEditingController();
    final priceController = TextEditingController(text: '0.0');

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            'Add Supplement',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          content: StatefulBuilder(
            builder: (BuildContext context, StateSetter setState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: 'Supplement Name',
                      labelStyle: GoogleFonts.poppins(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    style: GoogleFonts.poppins(),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: priceController,
                    decoration: InputDecoration(
                      labelText: 'Price',
                      labelStyle: GoogleFonts.poppins(),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    style: GoogleFonts.poppins(),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  color: Colors.grey[700],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final name = nameController.text.trim();
                final priceStr = priceController.text.trim();

                if (name.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Supplement name cannot be empty'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                final price = double.tryParse(priceStr) ?? 0.0;

                Navigator.of(dialogContext).pop({
                  'name': name,
                  'price': price,
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFd47b00),
              ),
              child: Text(
                'Add',
                style: GoogleFonts.poppins(
                  color: Colors.white,
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

/// Edit Operations Helper
/// Provides common patterns for edit operations (loading dialogs, success/error messages)
class EditOperationsHelper {
  /// Show loading dialog
  static void showLoadingDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  /// Close loading dialog
  static void closeLoadingDialog(BuildContext context) {
    if (context.mounted) {
      Navigator.of(context).pop();
    }
  }

  /// Show success message
  static void showSuccessMessage(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Show error message
  static void showErrorMessage(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  /// Update menu item and handle result
  static Future<bool> updateMenuItem(
    MenuItem item,
    MenuItem Function(MenuItem) updateFn,
  ) async {
    final menuItemService = MenuItemService();
    final updatedMenuItem = updateFn(item);
    return menuItemService.updateMenuItem(updatedMenuItem);
  }
}

/// Global Operations Helper
/// Provides business logic for global supplement and ingredient operations
class GlobalOperationsHelper {
  /// Update global supplements
  static List<Map<String, dynamic>> updatePricingOptionsForSupplements(
    MenuItem item,
    Map<String, double> supplements,
    List<String> hiddenSupplements,
  ) {
    return item.pricingOptions.map((pricing) {
      if (pricing['is_limited_offer'] == true &&
          pricing['size']?.toString().toLowerCase() == 'pack') {
        final updatedPricing = Map<String, dynamic>.from(pricing);
        final offerDetails = Map<String, dynamic>.from(
          pricing['offer_details'] as Map? ?? {},
        );
        offerDetails['global_supplements'] = supplements;
        offerDetails['hidden_global_supplements'] = hiddenSupplements;
        updatedPricing['offer_details'] = offerDetails;
        updatedPricing['updated_at'] = DateTime.now().toIso8601String();
        return updatedPricing;
      }
      return pricing;
    }).toList();
  }

  /// Update global supplements
  static Future<bool> updateGlobalSupplements(
    MenuItem item,
    Map<String, double> supplements,
  ) async {
    // Get current hidden supplements and filter out supplements that no longer exist
    final currentHiddenSupplements =
        SpecialPackHelper.getHiddenGlobalSupplements(item);
    final updatedHiddenSupplements = currentHiddenSupplements
        .where((name) => supplements.containsKey(name))
        .toList();

    final updatedPricingOptions = updatePricingOptionsForSupplements(
        item, supplements, updatedHiddenSupplements);

    final updatedMenuItem = item.copyWith(
      pricingOptions: updatedPricingOptions,
    );

    return EditOperationsHelper.updateMenuItem(
      item,
      (_) => updatedMenuItem,
    );
  }

  /// Delete global supplement
  static Future<bool> deleteGlobalSupplement(
    MenuItem item,
    String name,
    Map<String, double> supplements,
  ) async {
    final updatedSupplements = Map<String, double>.from(supplements);
    updatedSupplements.remove(name);

    // Get current hidden supplements and remove the deleted one
    final currentHiddenSupplements =
        SpecialPackHelper.getHiddenGlobalSupplements(item);
    final updatedHiddenSupplements =
        List<String>.from(currentHiddenSupplements);
    updatedHiddenSupplements.remove(name);

    final updatedPricingOptions = updatePricingOptionsForSupplements(
        item, updatedSupplements, updatedHiddenSupplements);

    final updatedMenuItem = item.copyWith(
      pricingOptions: updatedPricingOptions,
    );

    return EditOperationsHelper.updateMenuItem(
      item,
      (_) => updatedMenuItem,
    );
  }

  /// Toggle global supplement visibility
  static Future<bool> toggleGlobalSupplementVisibility(
    MenuItem item,
    String name,
    bool isAvailable,
  ) async {
    // Get current hidden global supplements
    final currentHiddenSupplements =
        SpecialPackHelper.getHiddenGlobalSupplements(item);
    final updatedHiddenSupplements =
        List<String>.from(currentHiddenSupplements);

    if (isAvailable) {
      // Show: remove from hidden list
      updatedHiddenSupplements.remove(name);
    } else {
      // Hide: add to hidden list
      if (!updatedHiddenSupplements.contains(name)) {
        updatedHiddenSupplements.add(name);
      }
    }

    // Get current supplements
    final currentSupplements = SpecialPackHelper.getGlobalSupplements(item);

    final updatedPricingOptions = updatePricingOptionsForSupplements(
      item,
      currentSupplements,
      updatedHiddenSupplements,
    );

    final updatedMenuItem = item.copyWith(
      pricingOptions: updatedPricingOptions,
    );

    return EditOperationsHelper.updateMenuItem(
      item,
      (_) => updatedMenuItem,
    );
  }

  /// Update global ingredients
  static Future<bool> updateGlobalIngredients(
    MenuItem item,
    String? mainIngredientsText,
  ) async {
    // Parse main ingredients text to list
    final updatedIngredientsList = mainIngredientsText != null
        ? mainIngredientsText
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList()
        : <String>[];

    // Update offer_details with new global_ingredients
    final updatedPricingOptions = item.pricingOptions.map((pricing) {
      if (pricing['is_limited_offer'] == true &&
          pricing['size']?.toString().toLowerCase() == 'pack') {
        final updatedPricing = Map<String, dynamic>.from(pricing);
        final offerDetails = Map<String, dynamic>.from(
          pricing['offer_details'] as Map? ?? {},
        );
        offerDetails['global_ingredients'] = updatedIngredientsList;
        updatedPricing['offer_details'] = offerDetails;
        updatedPricing['updated_at'] = DateTime.now().toIso8601String();
        return updatedPricing;
      }
      return pricing;
    }).toList();

    final updatedMenuItem = item.copyWith(
      pricingOptions: updatedPricingOptions,
    );

    return EditOperationsHelper.updateMenuItem(
      item,
      (_) => updatedMenuItem,
    );
  }
}

/// Reload Helper
/// Provides helper methods for reloading menu items
class ReloadHelper {
  /// Reload menu item from database
  /// Reload menu item with 3-tier caching and request deduplication
  /// PERF: Use repository with forceRefresh instead of clearCache()
  /// This allows stale-while-revalidate pattern and prevents unnecessary cache invalidation
  static Future<MenuItem?> reloadMenuItem(String menuItemId) async {
    try {
      final stopwatch = Stopwatch()..start();

      // PERF: Use repository with forceRefresh parameter instead of clearing cache
      // This allows the repository to use stale-while-revalidate pattern
      // and prevents unnecessary cache invalidation
      final repository = MenuItemRepository();
      final result = await repository.get(menuItemId, forceRefresh: true);

      stopwatch.stop();
      debugPrint('⏱️ Reload menu item took ${stopwatch.elapsedMilliseconds}ms');

      return result.data;
    } catch (e) {
      debugPrint('❌ Error reloading menu item: $e');
      return null;
    }
  }
}

/// State Manager for Review Widgets
/// Manages state and provides getters for review widgets
class ReviewStateManager {
  final MenuItem item;
  final String? currentImageUrl;
  final String? currentName;
  final double? currentPrice;
  final double? currentOriginalPrice;
  final int? currentPrepTime;
  final bool? currentAvailability;
  final DateTime? currentStartDate;
  final DateTime? currentEndDate;

  ReviewStateManager({
    required this.item,
    this.currentImageUrl,
    this.currentName,
    this.currentPrice,
    this.currentOriginalPrice,
    this.currentPrepTime,
    this.currentAvailability,
    this.currentStartDate,
    this.currentEndDate,
  });

  /// Get LTO pricing option (prefer item-level, not size-specific)
  Map<String, dynamic>? get ltoPricing {
    // First, try to find item-level LTO pricing (no size)
    for (final pricing in item.pricingOptions) {
      if (pricing['is_limited_offer'] == true) {
        final size = safeString(pricing['size'], defaultValue: '') ?? '';
        if (size.isEmpty) {
          return pricing; // Item-level pricing
        }
      }
    }
    // Fallback to any LTO pricing if no item-level found
    for (final pricing in item.pricingOptions) {
      if (pricing['is_limited_offer'] == true) {
        return pricing;
      }
    }
    return null;
  }

  /// Get original price (before discount) from item original_price column
  double? get originalPrice {
    return currentOriginalPrice ?? item.originalPrice ?? item.price;
  }

  /// Get discounted price from item price column (not from pricing_options)
  double? get discountedPrice {
    return currentPrice ?? item.price;
  }

  /// Get LTO offer dates (use current state if available)
  DateTime? get offerStartDate {
    if (currentStartDate != null) return currentStartDate;
    final pricing = ltoPricing;
    if (pricing == null) return null;
    final startAt = pricing['offer_start_at'];
    if (startAt == null) return null;
    return safeUtc(startAt);
  }

  DateTime? get offerEndDate {
    if (currentEndDate != null) return currentEndDate;
    final pricing = ltoPricing;
    if (pricing == null) return null;
    final endAt = pricing['offer_end_at'];
    if (endAt == null) return null;
    return safeUtc(endAt);
  }

  /// Get current prep time (use current state if available)
  int get currentPrepTimeValue {
    return currentPrepTime ?? item.preparationTime;
  }

  /// Get current availability (use current state if available)
  bool get currentAvailabilityValue {
    return currentAvailability ?? item.isAvailable;
  }

  /// Get current name (use current state if available)
  String get currentNameValue {
    return currentName ?? item.name;
  }

  /// Get current image URL (use current state if available)
  String get currentImageUrlValue {
    return currentImageUrl ?? item.image;
  }
}
