import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../models/menu_item.dart';
import '../../../../services/enhanced_menu_item_service.dart';
import '../../../../services/menu_item_service.dart';
import '../../../menu_item_full_popup/helpers/special_pack_helper.dart';
import 'Common/description_section_widget.dart';
import 'Common/edit_ingredients_dialog.dart';
import 'Common/free_drinks_controller_widget.dart';
import 'Common/image_price_widget.dart';
import 'Common/review_sheet_wrapper.dart';
import 'Common/title_container_widget.dart';
import 'special_pack/pack_contents_widget.dart';
import 'special_pack_helpers/date_operations_helper.dart';
import 'special_pack_helpers/image_operations_helper.dart';
import 'special_pack_helpers/special_pack_operations.dart';
import 'special_pack_helpers/variant_helpers.dart';

/// LTO Special Pack Review Widget
/// Displays detailed information about a special pack Limited Time Offer item
class LTOSpecialPackReview extends StatefulWidget {
  final MenuItem ltoItem;
  final ScrollController? scrollController;

  const LTOSpecialPackReview({
    required this.ltoItem,
    this.scrollController,
    super.key,
  });

  @override
  State<LTOSpecialPackReview> createState() => _LTOSpecialPackReviewState();
}

class _LTOSpecialPackReviewState extends State<LTOSpecialPackReview> {
  bool _isUpdatingImage = false;
  String? _currentImageUrl;
  String? _currentName;
  double? _currentPrice;
  double? _currentOriginalPrice;
  int? _currentPrepTime;
  bool? _currentAvailability;
  DateTime? _currentStartDate;
  DateTime? _currentEndDate;
  final ImagePicker _imagePicker = ImagePicker();
  final EnhancedMenuItemService _enhancedService = EnhancedMenuItemService();

  // Local copy of menu item to update when variants are modified
  MenuItem get _localMenuItem => _localMenuItemValue ?? widget.ltoItem;
  MenuItem? _localMenuItemValue;

  // State manager for getters
  ReviewStateManager get _stateManager => ReviewStateManager(
        item: widget.ltoItem,
        currentImageUrl: _currentImageUrl,
        currentName: _currentName,
        currentPrice: _currentPrice,
        currentOriginalPrice: _currentOriginalPrice,
        currentPrepTime: _currentPrepTime,
        currentAvailability: _currentAvailability,
        currentStartDate: _currentStartDate,
        currentEndDate: _currentEndDate,
      );

  @override
  void initState() {
    super.initState();
    // Initialize local copy of menu item
    _localMenuItemValue = widget.ltoItem;
    _currentImageUrl = widget.ltoItem.image;
    _currentName = widget.ltoItem.name;
    _currentPrice = widget.ltoItem.price;
    _currentOriginalPrice = widget.ltoItem.originalPrice;
    _currentPrepTime = widget.ltoItem.preparationTime;
    _currentAvailability = widget.ltoItem.isAvailable;
    _currentStartDate = _offerStartDate;
    _currentEndDate = _offerEndDate;
  }

  /// Reload menu item from database
  /// PERF: Uses ReloadHelper which now uses repository with 3-tier caching
  /// This provides request deduplication and stale-while-revalidate pattern
  Future<void> _reloadMenuItem() async {
    try {
      final updatedItem = await ReloadHelper.reloadMenuItem(widget.ltoItem.id);
      if (updatedItem != null && mounted) {
        setState(() {
          _localMenuItemValue = updatedItem;
        });
      }
    } catch (e) {
      if (mounted) {
        debugPrint('❌ Error reloading menu item: $e');
        // Don't show error to user as it's not critical
      }
    }
  }

  /// Edit image functionality
  Future<void> _editImage(BuildContext context) async {
    try {
      final source = await ImageOperationsHelper.showImageSourceDialog(context);
      if (source == null) return;

      final hasPermission =
          await ImageOperationsHelper.requestImagePermissions(source);
      if (!hasPermission) {
        EditOperationsHelper.showErrorMessage(
          context,
          source == ImageSource.camera
              ? 'Camera permission is required'
              : 'Photos permission is required',
        );
        return;
      }

      final pickedFile = await _imagePicker.pickImage(source: source);
      if (pickedFile == null) return;

      final pickedImage = File(pickedFile.path);

      setState(() {
        _isUpdatingImage = true;
      });

      if (!context.mounted) return;
      EditOperationsHelper.showLoadingDialog(context);

      try {
        final newImageUrl = await ImageOperationsHelper.uploadAndUpdateImage(
          widget.ltoItem,
          pickedImage,
        );

        setState(() {
          _currentImageUrl = newImageUrl;
          _isUpdatingImage = false;
        });

        EditOperationsHelper.closeLoadingDialog(context);
        EditOperationsHelper.showSuccessMessage(
          context,
          'Image updated successfully',
        );
      } catch (e) {
        EditOperationsHelper.closeLoadingDialog(context);
        EditOperationsHelper.showErrorMessage(
          context,
          'Error updating image: $e',
        );
      } finally {
        if (mounted) {
          setState(() {
            _isUpdatingImage = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUpdatingImage = false;
        });
      }
      EditOperationsHelper.showErrorMessage(context, 'Error: $e');
    }
  }

  /// Edit name functionality
  Future<void> _editName(BuildContext context) async {
    final result = await EditDialogs.showEditNameDialog(
      context,
      _currentName ?? widget.ltoItem.name,
    );

    if (result == null || result.isEmpty) return;

    try {
      setState(() {
        _isUpdatingImage = true;
      });

      if (!context.mounted) return;
      EditOperationsHelper.showLoadingDialog(context);

      try {
        final success = await EditOperationsHelper.updateMenuItem(
          widget.ltoItem,
          (item) => item.copyWith(name: result),
        );

        if (!success) {
          throw Exception('Failed to update menu item');
        }

        setState(() {
          _currentName = result;
          _isUpdatingImage = false;
        });

        EditOperationsHelper.closeLoadingDialog(context);
        EditOperationsHelper.showSuccessMessage(
          context,
          'Name updated successfully',
        );
      } catch (e) {
        EditOperationsHelper.closeLoadingDialog(context);
        EditOperationsHelper.showErrorMessage(
          context,
          'Error updating name: $e',
        );
      } finally {
        if (mounted) {
          setState(() {
            _isUpdatingImage = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUpdatingImage = false;
        });
      }
      EditOperationsHelper.showErrorMessage(context, 'Error: $e');
    }
  }

  /// Edit discounted price functionality
  Future<void> _editDiscountedPrice(BuildContext context) async {
    final result = await EditDialogs.showEditPriceDialog(
      context,
      'Edit Discounted Price',
      _currentPrice ?? widget.ltoItem.price,
    );

    if (result == null || result.isEmpty) return;

    final newPrice = double.tryParse(result);
    if (newPrice == null || newPrice < 0) {
      EditOperationsHelper.showErrorMessage(context, 'Invalid price value');
      return;
    }

    try {
      setState(() {
        _isUpdatingImage = true;
      });

      if (!context.mounted) return;
      EditOperationsHelper.showLoadingDialog(context);

      try {
        final success = await EditOperationsHelper.updateMenuItem(
          widget.ltoItem,
          (item) => item.copyWith(price: newPrice),
        );

        if (!success) {
          throw Exception('Failed to update menu item');
        }

        setState(() {
          _currentPrice = newPrice;
          _isUpdatingImage = false;
        });

        EditOperationsHelper.closeLoadingDialog(context);
        EditOperationsHelper.showSuccessMessage(
          context,
          'Discounted price updated successfully',
        );
      } catch (e) {
        EditOperationsHelper.closeLoadingDialog(context);
        EditOperationsHelper.showErrorMessage(
          context,
          'Error updating discounted price: $e',
        );
      } finally {
        if (mounted) {
          setState(() {
            _isUpdatingImage = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUpdatingImage = false;
        });
      }
      EditOperationsHelper.showErrorMessage(context, 'Error: $e');
    }
  }

  /// Edit original price functionality
  Future<void> _editOriginalPrice(BuildContext context) async {
    final result = await EditDialogs.showEditPriceDialog(
      context,
      'Edit Original Price',
      _currentOriginalPrice ?? widget.ltoItem.originalPrice,
    );

    if (result == null || result.isEmpty) return;

    final newPrice = double.tryParse(result);
    if (newPrice == null || newPrice < 0) {
      EditOperationsHelper.showErrorMessage(context, 'Invalid price value');
      return;
    }

    try {
      setState(() {
        _isUpdatingImage = true;
      });

      if (!context.mounted) return;
      EditOperationsHelper.showLoadingDialog(context);

      try {
        final success = await EditOperationsHelper.updateMenuItem(
          widget.ltoItem,
          (item) => item.copyWith(originalPrice: newPrice),
        );

        if (!success) {
          throw Exception('Failed to update menu item');
        }

        setState(() {
          _currentOriginalPrice = newPrice;
          _isUpdatingImage = false;
        });

        EditOperationsHelper.closeLoadingDialog(context);
        EditOperationsHelper.showSuccessMessage(
          context,
          'Original price updated successfully',
        );
      } catch (e) {
        EditOperationsHelper.closeLoadingDialog(context);
        EditOperationsHelper.showErrorMessage(
          context,
          'Error updating original price: $e',
        );
      } finally {
        if (mounted) {
          setState(() {
            _isUpdatingImage = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUpdatingImage = false;
        });
      }
      EditOperationsHelper.showErrorMessage(context, 'Error: $e');
    }
  }

  /// Edit prep time functionality
  Future<void> _editPrepTime(BuildContext context) async {
    final result = await EditDialogs.showEditPrepTimeDialog(
      context,
      _currentPrepTimeValue,
    );

    if (result == null || result.isEmpty) return;

    final newPrepTime = int.tryParse(result);
    if (newPrepTime == null || newPrepTime < 0) {
      EditOperationsHelper.showErrorMessage(
        context,
        'Invalid preparation time value',
      );
      return;
    }

    try {
      setState(() {
        _isUpdatingImage = true;
      });

      if (!context.mounted) return;
      EditOperationsHelper.showLoadingDialog(context);

      try {
        final success = await EditOperationsHelper.updateMenuItem(
          widget.ltoItem,
          (item) => item.copyWith(preparationTime: newPrepTime),
        );

        if (!success) {
          throw Exception('Failed to update menu item');
        }

        setState(() {
          _currentPrepTime = newPrepTime;
          _isUpdatingImage = false;
        });

        EditOperationsHelper.closeLoadingDialog(context);
        EditOperationsHelper.showSuccessMessage(
          context,
          'Preparation time updated successfully',
        );
      } catch (e) {
        EditOperationsHelper.closeLoadingDialog(context);
        EditOperationsHelper.showErrorMessage(
          context,
          'Error updating preparation time: $e',
        );
      } finally {
        if (mounted) {
          setState(() {
            _isUpdatingImage = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUpdatingImage = false;
        });
      }
      EditOperationsHelper.showErrorMessage(context, 'Error: $e');
    }
  }

  /// Edit availability functionality
  Future<void> _editAvailability(BuildContext context) async {
    final newAvailability = !_currentAvailabilityValue;

    try {
      setState(() {
        _isUpdatingImage = true;
      });

      if (!context.mounted) return;
      EditOperationsHelper.showLoadingDialog(context);

      try {
        final success = await EditOperationsHelper.updateMenuItem(
          widget.ltoItem,
          (item) => item.copyWith(isAvailable: newAvailability),
        );

        if (!success) {
          throw Exception('Failed to update menu item');
        }

        setState(() {
          _currentAvailability = newAvailability;
          _isUpdatingImage = false;
        });

        EditOperationsHelper.closeLoadingDialog(context);
        EditOperationsHelper.showSuccessMessage(
          context,
          newAvailability ? 'Item is now available' : 'Item is now unavailable',
        );
      } catch (e) {
        EditOperationsHelper.closeLoadingDialog(context);
        EditOperationsHelper.showErrorMessage(
          context,
          'Error updating availability: $e',
        );
      } finally {
        if (mounted) {
          setState(() {
            _isUpdatingImage = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUpdatingImage = false;
        });
      }
      EditOperationsHelper.showErrorMessage(context, 'Error: $e');
    }
  }

  /// Edit start date functionality
  Future<void> _editStartDate(BuildContext context) async {
    final initialDate = _offerStartDate ?? DateTime.now();
    final newStartDate = await DateOperationsHelper.pickDateTime(
      context,
      initialDate,
    );

    if (newStartDate == null) return;

    try {
      setState(() {
        _isUpdatingImage = true;
      });

      if (!context.mounted) return;
      EditOperationsHelper.showLoadingDialog(context);

      try {
        final ltoPricing = _ltoPricing;
        if (ltoPricing == null) {
          throw Exception('LTO pricing not found');
        }

        final success = await DateOperationsHelper.updateStartDate(
          widget.ltoItem,
          newStartDate,
        );

        if (!success) {
          throw Exception('Failed to update menu item');
        }

        setState(() {
          _currentStartDate = newStartDate;
          _isUpdatingImage = false;
        });

        EditOperationsHelper.closeLoadingDialog(context);
        EditOperationsHelper.showSuccessMessage(
          context,
          'Start date updated successfully',
        );
      } catch (e) {
        EditOperationsHelper.closeLoadingDialog(context);
        EditOperationsHelper.showErrorMessage(
          context,
          'Error updating start date: $e',
        );
      } finally {
        if (mounted) {
          setState(() {
            _isUpdatingImage = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUpdatingImage = false;
        });
      }
      EditOperationsHelper.showErrorMessage(context, 'Error: $e');
    }
  }

  /// Edit end date functionality
  Future<void> _editEndDate(BuildContext context) async {
    final initialDate =
        _offerEndDate ?? DateTime.now().add(const Duration(days: 7));
    final newEndDate = await DateOperationsHelper.pickDateTime(
      context,
      initialDate,
    );

    if (newEndDate == null) return;

    try {
      setState(() {
        _isUpdatingImage = true;
      });

      if (!context.mounted) return;
      EditOperationsHelper.showLoadingDialog(context);

      try {
        final ltoPricing = _ltoPricing;
        if (ltoPricing == null) {
          throw Exception('LTO pricing not found');
        }

        final success = await DateOperationsHelper.updateEndDate(
          widget.ltoItem,
          newEndDate,
        );

        if (!success) {
          throw Exception('Failed to update menu item');
        }

        setState(() {
          _currentEndDate = newEndDate;
          _isUpdatingImage = false;
        });

        EditOperationsHelper.closeLoadingDialog(context);
        EditOperationsHelper.showSuccessMessage(
          context,
          'End date updated successfully',
        );
      } catch (e) {
        EditOperationsHelper.closeLoadingDialog(context);
        EditOperationsHelper.showErrorMessage(
          context,
          'Error updating end date: $e',
        );
      } finally {
        if (mounted) {
          setState(() {
            _isUpdatingImage = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUpdatingImage = false;
        });
      }
      EditOperationsHelper.showErrorMessage(context, 'Error: $e');
    }
  }

  // Getters using state manager
  Map<String, dynamic>? get _ltoPricing => _stateManager.ltoPricing;
  double? get _originalPrice => _stateManager.originalPrice;
  double? get _discountedPrice => _stateManager.discountedPrice;
  DateTime? get _offerStartDate => _stateManager.offerStartDate;
  DateTime? get _offerEndDate => _stateManager.offerEndDate;
  int get _currentPrepTimeValue => _stateManager.currentPrepTimeValue;
  bool get _currentAvailabilityValue => _stateManager.currentAvailabilityValue;

  // Parsing methods using helper
  List<String> _parseHiddenOptions(String? description) =>
      VariantParsingUtils.parseHiddenOptions(description);
  String? _parseMainIngredients(String? description) =>
      VariantParsingUtils.parseMainIngredients(description);
  List<String> _parseHiddenSupplements(String? description) =>
      VariantParsingUtils.parseHiddenSupplements(description);

  /// Delete option from variant
  Future<void> _deleteOption(
    Map<String, dynamic> variant,
    String optionToDelete,
  ) async {
    // Check if this is the last option
    final variantDescription = variant['description'] ?? '';
    final currentOptions = SpecialPackHelper.parseOptions(variantDescription);

    if (currentOptions.length <= 1) {
      EditOperationsHelper.showErrorMessage(
        context,
        'Cannot delete the last option. At least one option must remain.',
      );
      return;
    }

    try {
      final variantId = variant['id']?.toString() ?? '';
      final newDescription =
          VariantOperationsHelper.buildDescriptionForDeleteOption(
        variantDescription: variantDescription,
        optionToDelete: optionToDelete,
      );

      await _enhancedService.updateVariant(
        menuItemId: widget.ltoItem.id,
        variantId: variantId,
        description: newDescription,
      );

      await _reloadMenuItem();

      if (mounted) {
        EditOperationsHelper.showSuccessMessage(
          context,
          'Option deleted successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        EditOperationsHelper.showErrorMessage(
          context,
          'Error deleting option: $e',
        );
      }
    }
  }

  /// Hide/show option in variant (move between visible and hidden lists)
  Future<void> _toggleOptionVisibility(
    Map<String, dynamic> variant,
    String option,
  ) async {
    try {
      final variantId = variant['id']?.toString() ?? '';
      final variantDescription = variant['description'] ?? '';

      // Parse current values
      final currentOptions = SpecialPackHelper.parseOptions(variantDescription);
      final currentHiddenOptions = _parseHiddenOptions(variantDescription);

      // Check if option is currently visible or hidden
      final isCurrentlyVisible = currentOptions.contains(option);

      // Check if this is the last visible option
      if (isCurrentlyVisible && currentOptions.length <= 1) {
        EditOperationsHelper.showErrorMessage(
          context,
          'Cannot hide the last option. At least one option must remain visible.',
        );
        return;
      }

      final toggleResult = VariantOperationsHelper.toggleOptionVisibility(
        variantDescription: variantDescription,
        option: option,
        currentOptions: currentOptions,
        currentHiddenOptions: currentHiddenOptions,
      );

      if (toggleResult == null) {
        EditOperationsHelper.showErrorMessage(
          context,
          'Option not found',
        );
        return;
      }

      final (updatedOptions, updatedHiddenOptions) = toggleResult;

      // Rebuild description using helper
      final newDescription =
          VariantOperationsHelper.buildDescriptionWithUpdatedOptions(
        variantDescription: variantDescription,
        updatedOptions: updatedOptions,
        updatedHiddenOptions: updatedHiddenOptions,
      );

      await _enhancedService.updateVariant(
        menuItemId: widget.ltoItem.id,
        variantId: variantId,
        description: newDescription,
      );

      await _reloadMenuItem();

      if (mounted) {
        EditOperationsHelper.showSuccessMessage(
          context,
          isCurrentlyVisible
              ? 'Option hidden successfully'
              : 'Option shown successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        EditOperationsHelper.showErrorMessage(
          context,
          'Error toggling option visibility: $e',
        );
      }
    }
  }

  /// Add new option to variant
  Future<void> _addOption(Map<String, dynamic> variant) async {
    final result = await EditDialogs.showAddOptionDialog(context);

    if (result == null || result.isEmpty) return;

    try {
      final variantId = variant['id']?.toString() ?? '';
      final variantDescription = variant['description'] ?? '';
      final currentOptions = SpecialPackHelper.parseOptions(variantDescription);
      final currentHiddenOptions = _parseHiddenOptions(variantDescription);

      // Build description using helper
      final newDescription =
          VariantOperationsHelper.buildDescriptionForAddOption(
        variantDescription: variantDescription,
        newOption: result,
        currentOptions: currentOptions,
        currentHiddenOptions: currentHiddenOptions,
      );

      if (newDescription == null) {
        EditOperationsHelper.showErrorMessage(
          context,
          'This variant already exists',
        );
        return;
      }

      await _enhancedService.updateVariant(
        menuItemId: widget.ltoItem.id,
        variantId: variantId,
        description: newDescription,
      );

      await _reloadMenuItem();

      if (mounted) {
        EditOperationsHelper.showSuccessMessage(
          context,
          'Variant added successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        EditOperationsHelper.showErrorMessage(
          context,
          'Error adding variant: $e',
        );
      }
    }
  }

  /// Edit variant name and quantity
  Future<void> _editVariant(Map<String, dynamic> variant) async {
    final variantId = variant['id']?.toString() ?? '';
    final variantName = variant['name'] ?? '';
    final variantDescription = variant['description'] ?? '';
    final currentQuantity = SpecialPackHelper.parseQuantity(variantDescription);

    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return EditVariantDialog(
          variantName: variantName,
          currentQuantity: currentQuantity,
          variantDescription: variantDescription,
          onSave: (String newName, int newQuantity) async {
            try {
              final newDescription =
                  VariantOperationsHelper.buildDescriptionWithNewQuantity(
                variantDescription: variantDescription,
                newQuantity: newQuantity,
              );

              await _enhancedService.updateVariant(
                menuItemId: widget.ltoItem.id,
                variantId: variantId,
                name: newName,
                description: newDescription,
              );

              if (mounted) {
                await _reloadMenuItem();
                EditOperationsHelper.showSuccessMessage(
                  context,
                  'Variant updated successfully',
                );
              }
            } catch (e) {
              if (mounted) {
                EditOperationsHelper.showErrorMessage(
                  context,
                  'Error updating variant: $e',
                );
              }
            }
          },
        );
      },
    );
  }

  /// Toggle variant visibility
  Future<void> _toggleVariantVisibility(
    Map<String, dynamic> variant,
    bool isAvailable,
  ) async {
    try {
      final variantId = variant['id']?.toString() ?? '';
      final variantName = variant['name'] ?? '';

      await _enhancedService.updateVariant(
        menuItemId: widget.ltoItem.id,
        variantId: variantId,
        isAvailable: isAvailable,
      );

      await _reloadMenuItem();

      if (mounted) {
        EditOperationsHelper.showSuccessMessage(
          context,
          isAvailable
              ? '$variantName is now visible'
              : '$variantName is now hidden',
        );
      }
    } catch (e) {
      if (mounted) {
        EditOperationsHelper.showErrorMessage(
          context,
          'Error updating variant: $e',
        );
      }
    }
  }

  /// Open edit ingredients dialog for a variant
  Future<void> _editIngredients(Map<String, dynamic> variant) async {
    try {
      final variantDescription = variant['description'] ?? '';
      final mainIngredients = _parseMainIngredients(variantDescription);
      final ingredients =
          SpecialPackHelper.parseIngredients(variantDescription);

      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (context) => LTOEditIngredientsDialog(
          initialMainIngredients: mainIngredients,
          initialIngredients: ingredients,
          showMainIngredients: false, // Hide main ingredients for special packs
        ),
      );

      if (result == null) return;

      final updatedMainIngredients = result['mainIngredients'] as String?;
      final updatedIngredients = result['ingredients'] as List<String>?;

      final variantId = variant['id']?.toString() ?? '';

      // Rebuild description with updated ingredients using helper
      final newDescription =
          VariantOperationsHelper.buildDescriptionWithUpdatedIngredients(
        variantDescription: variantDescription,
        mainIngredients: updatedMainIngredients,
        ingredients: updatedIngredients,
      );

      await _enhancedService.updateVariant(
        menuItemId: widget.ltoItem.id,
        variantId: variantId,
        description: newDescription,
      );

      await _reloadMenuItem();

      if (mounted) {
        EditOperationsHelper.showSuccessMessage(
          context,
          'Ingredients updated successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        EditOperationsHelper.showErrorMessage(
          context,
          'Error updating ingredients: $e',
        );
      }
    }
  }

  /// Update global supplements
  Future<void> _updateGlobalSupplements(Map<String, double> supplements) async {
    try {
      final ltoPricing = _ltoPricing;
      if (ltoPricing == null) {
        throw Exception('LTO pricing not found');
      }

      final success = await GlobalOperationsHelper.updateGlobalSupplements(
        widget.ltoItem,
        supplements,
      );

      if (!success) {
        throw Exception('Failed to update menu item');
      }

      await _reloadMenuItem();

      if (mounted) {
        EditOperationsHelper.showSuccessMessage(
          context,
          'Global supplements updated successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        EditOperationsHelper.showErrorMessage(
          context,
          'Error updating global supplements: $e',
        );
      }
    }
  }

  /// Add global supplement
  Future<void> _addGlobalSupplement(
      String name, Map<String, double> supplement) async {
    try {
      final currentSupplements =
          SpecialPackHelper.getGlobalSupplements(widget.ltoItem);
      final updatedSupplements = Map<String, double>.from(currentSupplements);
      updatedSupplements.addAll(supplement);
      await _updateGlobalSupplements(updatedSupplements);
    } catch (e) {
      if (mounted) {
        EditOperationsHelper.showErrorMessage(
          context,
          'Error adding global supplement: $e',
        );
      }
    }
  }

  /// Delete global supplement
  Future<void> _deleteGlobalSupplement(
      String name, Map<String, double> supplement) async {
    try {
      // Get current LTO pricing
      final ltoPricing = _ltoPricing;
      if (ltoPricing == null) {
        throw Exception('LTO pricing not found');
      }

      // Get current supplements and hidden supplements
      final currentSupplements =
          SpecialPackHelper.getGlobalSupplements(widget.ltoItem);
      final currentHiddenSupplements =
          SpecialPackHelper.getHiddenGlobalSupplements(widget.ltoItem);

      // Remove from supplements
      final updatedSupplements = Map<String, double>.from(currentSupplements);
      updatedSupplements.remove(name);

      // Also remove from hidden list if it exists there
      final updatedHiddenSupplements =
          List<String>.from(currentHiddenSupplements);
      updatedHiddenSupplements.remove(name);

      // Update offer_details with updated supplements and hidden list
      final updatedPricingOptions =
          widget.ltoItem.pricingOptions.map((pricing) {
        if (pricing['is_limited_offer'] == true &&
            pricing['size']?.toString().toLowerCase() == 'pack') {
          final updatedPricing = Map<String, dynamic>.from(pricing);
          final offerDetails = Map<String, dynamic>.from(
            pricing['offer_details'] as Map? ?? {},
          );
          offerDetails['global_supplements'] = updatedSupplements;
          offerDetails['hidden_global_supplements'] = updatedHiddenSupplements;
          updatedPricing['offer_details'] = offerDetails;
          updatedPricing['updated_at'] = DateTime.now().toIso8601String();
          return updatedPricing;
        }
        return pricing;
      }).toList();

      // Update menu item
      final menuItemService = MenuItemService();
      final updatedMenuItem = widget.ltoItem.copyWith(
        pricingOptions: updatedPricingOptions,
      );

      final success = await menuItemService.updateMenuItem(updatedMenuItem);

      if (!success) {
        throw Exception('Failed to update menu item');
      }

      await _reloadMenuItem();

      if (mounted) {
        EditOperationsHelper.showSuccessMessage(
          context,
          'Supplement deleted successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        EditOperationsHelper.showErrorMessage(
          context,
          'Error deleting global supplement: $e',
        );
      }
    }
  }

  /// Toggle global supplement visibility
  Future<void> _toggleGlobalSupplementVisibility(
    String name,
    Map<String, double> supplement,
    bool isAvailable,
  ) async {
    try {
      final ltoPricing = _ltoPricing;
      if (ltoPricing == null) {
        throw Exception('LTO pricing not found');
      }

      final success =
          await GlobalOperationsHelper.toggleGlobalSupplementVisibility(
        widget.ltoItem,
        name,
        isAvailable,
      );

      if (!success) {
        throw Exception('Failed to update menu item');
      }

      await _reloadMenuItem();

      if (mounted) {
        EditOperationsHelper.showSuccessMessage(
          context,
          isAvailable ? '$name is now visible' : '$name is now hidden',
        );
      }
    } catch (e) {
      if (mounted) {
        EditOperationsHelper.showErrorMessage(
          context,
          'Error toggling supplement visibility: $e',
        );
      }
    }
  }

  /// Update global ingredients
  Future<void> _updateGlobalIngredients(String? mainIngredientsText) async {
    try {
      final ltoPricing = _ltoPricing;
      if (ltoPricing == null) {
        throw Exception('LTO pricing not found');
      }

      final success = await GlobalOperationsHelper.updateGlobalIngredients(
        widget.ltoItem,
        mainIngredientsText,
      );

      if (!success) {
        throw Exception('Failed to update menu item');
      }

      await _reloadMenuItem();

      if (mounted) {
        EditOperationsHelper.showSuccessMessage(
          context,
          'Global ingredients updated successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        EditOperationsHelper.showErrorMessage(
          context,
          'Error updating global ingredients: $e',
        );
      }
    }
  }

  /// Toggle supplement visibility
  Future<void> _toggleSupplementVisibility(
    Map<String, dynamic> variant,
    Map<String, dynamic> supplement,
    bool isAvailable,
  ) async {
    try {
      final supplementId = supplement['id']?.toString() ?? '';
      final supplementName = supplement['name'] ?? '';
      final variantDescription = variant['description'] ?? '';

      // If supplement is from array (has a real ID), update it via service
      if (supplementId.isNotEmpty &&
          !supplementId.startsWith('desc_') &&
          !supplementId.startsWith('global_')) {
        await _enhancedService.updateSupplement(
          menuItemId: widget.ltoItem.id,
          supplementId: supplementId,
          isAvailable: isAvailable,
        );

        await _reloadMenuItem();

        if (mounted) {
          EditOperationsHelper.showSuccessMessage(
            context,
            isAvailable
                ? '$supplementName is now visible'
                : '$supplementName is now hidden',
          );
        }
      } else if (supplementId.startsWith('desc_')) {
        final variantId = variant['id']?.toString() ?? '';
        final currentHiddenSupplements =
            _parseHiddenSupplements(variantDescription);

        final newDescription = VariantOperationsHelper
            .buildDescriptionForToggleSupplementVisibility(
          variantDescription: variantDescription,
          supplementName: supplementName,
          isAvailable: isAvailable,
          currentHiddenSupplements: currentHiddenSupplements,
        );

        await _enhancedService.updateVariant(
          menuItemId: widget.ltoItem.id,
          variantId: variantId,
          description: newDescription,
        );

        await _reloadMenuItem();

        if (mounted) {
          EditOperationsHelper.showSuccessMessage(
            context,
            isAvailable
                ? '$supplementName is now visible'
                : '$supplementName is now hidden',
          );
        }
      } else {
        if (mounted) {
          EditOperationsHelper.showErrorMessage(
            context,
            'Cannot toggle visibility for global supplements. Remove them from pack pricing instead.',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        EditOperationsHelper.showErrorMessage(
          context,
          'Error updating supplement: $e',
        );
      }
    }
  }

  /// Add supplement to variant
  Future<void> _addSupplement(Map<String, dynamic> variant) async {
    final result = await EditDialogs.showAddSupplementDialog(context);

    if (result == null) return;

    try {
      final variantId = variant['id']?.toString() ?? '';
      final variantDescription = variant['description'] ?? '';
      final supplementName = result['name'] as String;
      final supplementPrice = result['price'] as double;

      // Parse current supplements
      final currentSupplements =
          SpecialPackHelper.parseSupplements(variantDescription);

      // Build description using helper
      final newDescription =
          VariantOperationsHelper.buildDescriptionForAddSupplement(
        variantDescription: variantDescription,
        supplementName: supplementName,
        supplementPrice: supplementPrice,
        currentSupplements: currentSupplements,
      );

      if (newDescription == null) {
        EditOperationsHelper.showErrorMessage(
          context,
          'This supplement already exists',
        );
        return;
      }

      await _enhancedService.updateVariant(
        menuItemId: widget.ltoItem.id,
        variantId: variantId,
        description: newDescription,
      );

      await _reloadMenuItem();

      if (context.mounted) {
        EditOperationsHelper.showSuccessMessage(
          context,
          'Supplement "$supplementName" added successfully',
        );
      }
    } catch (e) {
      if (context.mounted) {
        EditOperationsHelper.showErrorMessage(
          context,
          'Error adding supplement: $e',
        );
      }
    }
  }

  /// Delete supplement from variant
  Future<void> _deleteSupplement(
    Map<String, dynamic> variant,
    Map<String, dynamic> supplement,
  ) async {
    try {
      final supplementId = supplement['id']?.toString() ?? '';
      final supplementName = supplement['name'] ?? '';
      final variantDescription = variant['description'] ?? '';

      // Check if supplement is from variant description
      if (supplementId.startsWith('desc_')) {
        final variantSupplements =
            SpecialPackHelper.parseSupplements(variantDescription);
        if (variantSupplements.containsKey(supplementName)) {
          final variantId = variant['id']?.toString() ?? '';
          final newDescription =
              VariantOperationsHelper.buildDescriptionForDeleteSupplement(
            variantDescription: variantDescription,
            supplementName: supplementName,
          );

          await _enhancedService.updateVariant(
            menuItemId: widget.ltoItem.id,
            variantId: variantId,
            description: newDescription,
          );

          await _reloadMenuItem();

          if (mounted) {
            EditOperationsHelper.showSuccessMessage(
              context,
              'Supplement deleted successfully',
            );
          }
        }
      } else if (supplementId.startsWith('global_')) {
        if (mounted) {
          EditOperationsHelper.showErrorMessage(
            context,
            'Cannot delete global supplements from variant level. Remove them from pack pricing instead.',
          );
        }
      } else {
        await _enhancedService.deleteSupplement(
          menuItemId: widget.ltoItem.id,
          supplementId: supplementId,
        );

        await _reloadMenuItem();

        if (mounted) {
          EditOperationsHelper.showSuccessMessage(
            context,
            'Supplement deleted successfully',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        EditOperationsHelper.showErrorMessage(
          context,
          'Error deleting supplement: $e',
        );
      }
    }
  }

  /// Delete variant functionality
  Future<void> _deleteVariant(Map<String, dynamic> variant) async {
    final variantName = variant['name'] ?? 'this variant';
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Variant'),
        content: Text(
          'Are you sure you want to delete "$variantName"? This will also delete all associated pricing options.',
        ),
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
      final variantId = variant['id']?.toString() ?? '';
      await _enhancedService.deleteVariant(
        menuItemId: widget.ltoItem.id,
        variantId: variantId,
      );

      await _reloadMenuItem();

      if (mounted) {
        EditOperationsHelper.showSuccessMessage(
          context,
          'Variant deleted successfully',
        );
      }
    } catch (e) {
      if (mounted) {
        EditOperationsHelper.showErrorMessage(
          context,
          'Error deleting variant: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isActive = widget.ltoItem.isOfferActive;
    final hasExpired = widget.ltoItem.hasExpiredLTOOffer && !isActive;
    final screenWidth = MediaQuery.of(context).size.width;
    final titleFontSize = (screenWidth * 0.8) / (30 * 0.6);
    final clampedTitleFontSize = titleFontSize.clamp(14.0, 20.0);

    // PERF: Use CustomScrollView with slivers instead of ListView(children)
    // This allows lazy building of sections and better scroll performance
    // Slivers are more efficient for modal bottom sheets with variable content
    return ReviewSheetWrapper(
      scrollController: widget.scrollController,
      builder: (controller) => CustomScrollView(
        controller: widget.scrollController ?? controller,
        physics: const ClampingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        slivers: [
          // Hero image with edit button and price overlay
          // PERF: RepaintBoundary isolates image repaints during scroll
          SliverToBoxAdapter(
            child: RepaintBoundary(
              child: LTOImagePriceWidget(
                imageUrl: _currentImageUrl ?? widget.ltoItem.image,
                discountedPrice: _discountedPrice,
                originalPrice: _originalPrice,
                isUpdatingImage: _isUpdatingImage,
                onEditImage: () => _editImage(context),
                onEditDiscountedPrice: () => _editDiscountedPrice(context),
                onEditOriginalPrice: () => _editOriginalPrice(context),
              ),
            ),
          ),

          // Content section
          // PERF: Use SliverChildBuilderDelegate instead of SliverChildListDelegate
          // This enables lazy building of children and better scroll performance
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  // PERF: Build children lazily based on index
                  // This prevents building all children upfront
                  switch (index) {
                    case 0:
                      return RepaintBoundary(
                        child: LTOTitleContainerWidget(
                          title:
                              SpecialPackHelper.formatPackName(widget.ltoItem),
                          titleFontSize: clampedTitleFontSize,
                          isActive: isActive,
                          hasExpired: hasExpired,
                          rating: widget.ltoItem.rating,
                          availability: _currentAvailabilityValue,
                          startDate: _offerStartDate,
                          endDate: _offerEndDate,
                          prepTime: _currentPrepTimeValue,
                          isUpdating: _isUpdatingImage,
                          onEditName: () => _editName(context),
                          onEditAvailability: () => _editAvailability(context),
                          onEditStartDate: () => _editStartDate(context),
                          onEditEndDate: () => _editEndDate(context),
                          onEditPrepTime: () => _editPrepTime(context),
                          statusLabel: 'Active LTO Pack',
                        ),
                      );
                    case 1:
                      return const SizedBox(height: 20);
                    case 2:
                      return RepaintBoundary(
                        child: DescriptionSectionWidget(
                          description: widget.ltoItem.description,
                        ),
                      );
                    case 3:
                      return RepaintBoundary(
                        child: LTOPackContentsWidget(
                          menuItem: widget.ltoItem,
                          localMenuItem: _localMenuItem,
                          parseHiddenOptions: _parseHiddenOptions,
                          parseHiddenSupplements: _parseHiddenSupplements,
                          onEditVariant: _editVariant,
                          onToggleVariantVisibility: _toggleVariantVisibility,
                          onDeleteVariant: _deleteVariant,
                          onAddOption: _addOption,
                          onToggleOptionVisibility: _toggleOptionVisibility,
                          onDeleteOption: _deleteOption,
                          onEditIngredients: _editIngredients,
                          onAddSupplement: _addSupplement,
                          onToggleSupplementVisibility:
                              _toggleSupplementVisibility,
                          onDeleteSupplement: _deleteSupplement,
                          onUpdateGlobalIngredients: _updateGlobalIngredients,
                          onUpdateGlobalSupplements: _updateGlobalSupplements,
                          onAddGlobalSupplement: _addGlobalSupplement,
                          onDeleteGlobalSupplement: _deleteGlobalSupplement,
                          onToggleGlobalSupplementVisibility:
                              _toggleGlobalSupplementVisibility,
                        ),
                      );
                    case 4:
                      return const SizedBox(height: 20);
                    case 5:
                      return RepaintBoundary(
                        child: LTOFreeDrinksControllerWidget(
                          menuItem: _localMenuItem,
                          onChanged: () => _reloadMenuItem(),
                        ),
                      );
                    default:
                      return const SizedBox.shrink();
                  }
                },
                childCount:
                    6, // Title, spacing, description, pack contents, spacing, free drinks
              ),
            ),
          ),
        ],
      ),
    );
  }
}
