import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../../models/menu_item.dart';
import '../../../../../services/enhanced_menu_item_service.dart';
import '../../../../../services/menu_item_image_service.dart';
import '../../../../../services/menu_item_service.dart';
import 'add_dialogs.dart';
import 'edit_dialogs.dart';

/// Unified helper class for all operations (edit, date, image)
class RegularItemOperationsHelper {
  final MenuItemService _menuItemService = MenuItemService();
  final EnhancedMenuItemService _enhancedService = EnhancedMenuItemService();
  final ImagePicker _imagePicker = ImagePicker();
  final MenuItemImageService _imageService = MenuItemImageService();

  // ============================================================================
  // EDIT OPERATIONS
  // ============================================================================

  /// Edit name functionality
  Future<String?> editName(
    BuildContext context,
    MenuItem menuItem,
    String currentName,
  ) async {
    final result = await EditNameDialog.show(context, currentName);

    if (result == null || result.isEmpty) {
      return null; // User cancelled or empty name
    }

    try {
      if (!context.mounted) return null;
      // ignore: unawaited_futures
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        final updatedMenuItem = menuItem.copyWith(name: result);
        final success = await _menuItemService.updateMenuItem(updatedMenuItem);

        if (!success) {
          throw Exception('Failed to update menu item');
        }

        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Name updated successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

        return result;
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating name: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return null;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return null;
    }
  }

  /// Edit discounted price functionality
  Future<double?> editDiscountedPrice(
    BuildContext context,
    MenuItem menuItem,
    double? currentPrice,
  ) async {
    final result = await EditPriceDialog.show(
      context,
      currentPrice,
      title: 'Edit Discounted Price',
      labelText: 'Discounted Price',
      hintText: 'Enter discounted price',
    );

    if (result == null || result < 0) {
      if (context.mounted && result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid price value'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return null;
    }

    try {
      if (!context.mounted) return null;
      // ignore: unawaited_futures
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        final updatedMenuItem = menuItem.copyWith(price: result);
        final success = await _menuItemService.updateMenuItem(updatedMenuItem);

        if (!success) {
          throw Exception('Failed to update menu item');
        }

        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Discounted price updated successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

        return result;
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating discounted price: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return null;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return null;
    }
  }

  /// Edit original price functionality
  Future<double?> editOriginalPrice(
    BuildContext context,
    MenuItem menuItem,
    double? currentOriginalPrice,
  ) async {
    final result = await EditPriceDialog.show(
      context,
      currentOriginalPrice,
      title: 'Edit Original Price',
      labelText: 'Original Price (Before Discount)',
      hintText: 'Enter original price',
    );

    if (result == null || result < 0) {
      if (context.mounted && result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid price value'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return null;
    }

    try {
      if (!context.mounted) return null;
      // ignore: unawaited_futures
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        final updatedMenuItem = menuItem.copyWith(originalPrice: result);
        final success = await _menuItemService.updateMenuItem(updatedMenuItem);

        if (!success) {
          throw Exception('Failed to update menu item');
        }

        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Original price updated successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

        return result;
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating original price: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return null;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return null;
    }
  }

  /// Edit prep time functionality
  Future<int?> editPrepTime(
    BuildContext context,
    MenuItem menuItem,
    int currentPrepTime,
  ) async {
    final result = await EditPrepTimeDialog.show(context, currentPrepTime);

    if (result == null || result < 0) {
      if (context.mounted && result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid preparation time value'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
      return null;
    }

    try {
      if (!context.mounted) return null;
      // ignore: unawaited_futures
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        final updatedMenuItem = menuItem.copyWith(preparationTime: result);
        final success = await _menuItemService.updateMenuItem(updatedMenuItem);

        if (!success) {
          throw Exception('Failed to update menu item');
        }

        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Preparation time updated successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

        return result;
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating preparation time: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return null;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return null;
    }
  }

  /// Edit availability functionality
  Future<bool?> editAvailability(
    BuildContext context,
    MenuItem menuItem, {
    required bool currentAvailability,
  }) async {
    final newAvailability = !currentAvailability;

    try {
      if (!context.mounted) return null;
      // ignore: unawaited_futures
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        final updatedMenuItem = menuItem.copyWith(isAvailable: newAvailability);
        final success = await _menuItemService.updateMenuItem(updatedMenuItem);

        if (!success) {
          throw Exception('Failed to update menu item');
        }

        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(newAvailability
                  ? 'Item is now available'
                  : 'Item is now unavailable'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        return newAvailability;
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating availability: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return null;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return null;
    }
  }

  /// Add variant
  Future<void> addVariant(
    BuildContext context,
    String menuItemId, {
    VoidCallback? onAdded,
  }) async {
    await AddVariantDialog.show(context, menuItemId, onAdded: onAdded);
  }

  /// Edit variant name
  Future<void> editVariantName(
    BuildContext context,
    String menuItemId,
    Map<String, dynamic> variant, {
    VoidCallback? onUpdated,
  }) async {
    final nameController = TextEditingController(text: variant['name'] ?? '');

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text('Edit Variant Name'),
          content: TextField(
            controller: nameController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter variant name',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newName = nameController.text.trim();
                if (newName.isEmpty) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    const SnackBar(
                      content: Text('Variant name cannot be empty'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  final variantId = variant['id'] as String? ?? '';
                  await _enhancedService.updateVariant(
                    menuItemId: menuItemId,
                    variantId: variantId,
                    name: newName,
                  );

                  if (context.mounted) {
                    Navigator.of(dialogContext).pop();
                    onUpdated?.call();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Variant name updated successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      SnackBar(
                        content: Text('Error updating variant name: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFd47b00),
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  /// Toggle variant visibility
  Future<void> toggleVariantVisibility(
    BuildContext context,
    String menuItemId,
    Map<String, dynamic> variant, {
    required bool isAvailable,
    VoidCallback? onUpdated,
  }) async {
    try {
      final variantId = variant['id'] as String? ?? '';
      final variantName = variant['name'] ?? '';

      await _enhancedService.updateVariant(
        menuItemId: menuItemId,
        variantId: variantId,
        isAvailable: isAvailable,
      );

      onUpdated?.call();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isAvailable
                  ? '$variantName is now visible'
                  : '$variantName is now hidden',
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating variant: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Delete variant
  Future<void> deleteVariant(
    BuildContext context,
    String menuItemId,
    Map<String, dynamic> variant, {
    VoidCallback? onDeleted,
  }) async {
    final variantName = variant['name'] ?? 'this variant';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Variant'),
        content: Text(
            'Are you sure you want to delete "$variantName"? This will also delete all associated pricing options.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final variantId = variant['id'] as String? ?? '';
      await _enhancedService.deleteVariant(
        menuItemId: menuItemId,
        variantId: variantId,
      );

      onDeleted?.call();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Variant deleted successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting variant: $e')),
        );
      }
    }
  }

  /// Add pricing
  Future<void> addPricing(
    BuildContext context,
    String menuItemId,
    String variantId, {
    VoidCallback? onAdded,
  }) async {
    await AddPricingDialog.show(context, menuItemId, variantId);
    onAdded?.call();
  }

  /// Edit pricing
  Future<void> editPricing(
    BuildContext context,
    String menuItemId,
    String variantId,
    Map<String, dynamic> pricing, {
    VoidCallback? onUpdated,
  }) async {
    await EditPricingDialog.show(context, menuItemId, variantId, pricing);
    onUpdated?.call();
  }

  /// Delete pricing
  Future<void> deletePricing(
    BuildContext context,
    String menuItemId,
    String pricingId, {
    VoidCallback? onDeleted,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Pricing'),
        content:
            const Text('Are you sure you want to delete this pricing option?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _enhancedService.deletePricing(
        menuItemId: menuItemId,
        pricingId: pricingId,
      );

      onDeleted?.call();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Pricing deleted successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting pricing: $e')),
        );
      }
    }
  }

  /// Add supplement
  Future<void> addSupplement(
    BuildContext context,
    String menuItemId,
    String? variantId, {
    VoidCallback? onAdded,
  }) async {
    await AddSupplementDialog.show(
      context,
      menuItemId,
      variantId,
      onAdded: onAdded,
    );
  }

  /// Delete supplement
  Future<void> deleteSupplement(
    BuildContext context,
    String menuItemId,
    String supplementId, {
    VoidCallback? onDeleted,
  }) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Supplement'),
        content: const Text('Are you sure you want to delete this supplement?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _enhancedService.deleteSupplement(
        menuItemId: menuItemId,
        supplementId: supplementId,
      );

      onDeleted?.call();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Supplement deleted successfully')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting supplement: $e')),
        );
      }
    }
  }

  // ============================================================================
  // IMAGE OPERATIONS
  // ============================================================================

  /// Edit image functionality
  Future<String?> editImage(
    BuildContext context,
    MenuItem menuItem,
  ) async {
    try {
      // Show image source selection dialog
      File? pickedImage;

      final source = await showDialog<ImageSource>(
        context: context,
        builder: (BuildContext dialogContext) {
          return AlertDialog(
            title: const Text('Select Image Source'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.camera_alt),
                  title: const Text('Camera'),
                  onTap: () =>
                      Navigator.of(dialogContext).pop(ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Gallery'),
                  onTap: () =>
                      Navigator.of(dialogContext).pop(ImageSource.gallery),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
            ],
          );
        },
      );

      if (source == null) {
        return null; // User cancelled
      }

      // Request permissions and pick image based on selected source
      if (source == ImageSource.camera) {
        final cameraStatus = await Permission.camera.request();
        if (cameraStatus != PermissionStatus.granted) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Camera permission denied'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return null;
        }
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
        if (image != null) {
          pickedImage = File(image.path);
        }
      } else {
        final photosStatus = await Permission.photos.request();
        if (photosStatus != PermissionStatus.granted) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Photos permission denied'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return null;
        }
        final XFile? image = await _imagePicker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 85,
        );
        if (image != null) {
          pickedImage = File(image.path);
        }
      }

      if (pickedImage == null) {
        return null; // User cancelled or error
      }

      // Show loading dialog
      if (!context.mounted) return null;
      // ignore: unawaited_futures
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        // Upload image to Supabase storage
        final imageUrls = await _imageService.uploadMenuItemImages(
          images: [pickedImage],
          menuItemId: menuItem.id,
          restaurantId: menuItem.restaurantId,
          onProgress: (progress) {
            // Progress callback if needed
          },
        );

        if (imageUrls.isEmpty) {
          throw Exception('Failed to upload image');
        }

        final newImageUrl = imageUrls.first;

        // Update menu item in database
        final updatedMenuItem = menuItem.copyWith(
          image: newImageUrl,
        );

        final success = await _menuItemService.updateMenuItem(updatedMenuItem);

        if (!success) {
          throw Exception('Failed to update menu item');
        }

        // Close loading dialog
        if (context.mounted) {
          Navigator.of(context).pop();
        }

        // Show success message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Image updated successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

        return newImageUrl;
      } catch (e) {
        // Close loading dialog
        if (context.mounted) {
          Navigator.of(context).pop();
        }

        // Show error message
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating image: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return null;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return null;
    }
  }

  // ============================================================================
  // DATE OPERATIONS
  // ============================================================================

  /// Edit start date functionality
  Future<DateTime?> editStartDate(
    BuildContext context,
    MenuItem menuItem,
    DateTime? currentStartDate,
  ) async {
    final initialDate = currentStartDate ?? DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );

    if (pickedTime == null) return null;

    final newStartDate = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    try {
      if (!context.mounted) return null;
      // ignore: unawaited_futures
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        // Find LTO pricing
        final ltoPricing = menuItem.pricingOptions.firstWhere(
          (p) => p['is_limited_offer'] == true,
          orElse: () => <String, dynamic>{},
        );

        if (ltoPricing.isEmpty) {
          throw Exception('LTO pricing not found');
        }

        // Update all LTO pricing options with the same start date
        final updatedPricingOptions = menuItem.pricingOptions.map((pricing) {
          if (pricing['is_limited_offer'] == true) {
            final updatedPricing = Map<String, dynamic>.from(pricing);
            updatedPricing['offer_start_at'] = newStartDate.toIso8601String();
            updatedPricing['updated_at'] = DateTime.now().toIso8601String();
            return updatedPricing;
          }
          return pricing;
        }).toList();

        final updatedMenuItem = menuItem.copyWith(
          pricingOptions: updatedPricingOptions,
        );

        final success = await _menuItemService.updateMenuItem(updatedMenuItem);

        if (!success) {
          throw Exception('Failed to update menu item');
        }

        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Start date updated successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

        return newStartDate;
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating start date: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return null;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return null;
    }
  }

  /// Edit end date functionality
  Future<DateTime?> editEndDate(
    BuildContext context,
    MenuItem menuItem,
    DateTime? currentEndDate,
  ) async {
    final initialDate =
        currentEndDate ?? DateTime.now().add(const Duration(days: 7));
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );

    if (pickedTime == null) return null;

    final newEndDate = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    try {
      if (!context.mounted) return null;
      // ignore: unawaited_futures
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        // Find LTO pricing
        final ltoPricing = menuItem.pricingOptions.firstWhere(
          (p) => p['is_limited_offer'] == true,
          orElse: () => <String, dynamic>{},
        );

        if (ltoPricing.isEmpty) {
          throw Exception('LTO pricing not found');
        }

        // Update all LTO pricing options with the same end date
        final updatedPricingOptions = menuItem.pricingOptions.map((pricing) {
          if (pricing['is_limited_offer'] == true) {
            final updatedPricing = Map<String, dynamic>.from(pricing);
            updatedPricing['offer_end_at'] = newEndDate.toIso8601String();
            updatedPricing['updated_at'] = DateTime.now().toIso8601String();
            return updatedPricing;
          }
          return pricing;
        }).toList();

        final updatedMenuItem = menuItem.copyWith(
          pricingOptions: updatedPricingOptions,
        );

        final success = await _menuItemService.updateMenuItem(updatedMenuItem);

        if (!success) {
          throw Exception('Failed to update menu item');
        }

        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('End date updated successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

        return newEndDate;
      } catch (e) {
        if (context.mounted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating end date: $e'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return null;
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
      return null;
    }
  }
}
