import 'package:flutter/material.dart';

import '../../../../models/menu_item.dart';
import '../../../../services/menu_item_service.dart';
import '../../../../utils/safe_parse.dart';
import 'Common/description_section_widget.dart';
import 'Common/edit_ingredients_dialog.dart';
import 'Common/free_drinks_controller_widget.dart';
import 'Common/image_price_widget.dart';
import 'Common/review_sheet_wrapper.dart';
import 'Common/title_container_widget.dart';
import 'regular_item/ingredients_section_widget.dart';
import 'regular_item/pricing_supplements_section_widget.dart';
import 'regular_item/variants_section_widget.dart';
import 'regular_item_helpers/add_dialogs.dart';
import 'regular_item_helpers/operations_helper.dart';

/// Regular Item Review Widget
/// Displays detailed information about a regular Limited Time Offer item
class RegularItemReview extends StatefulWidget {
  final MenuItem ltoItem;
  final ScrollController? scrollController;

  const RegularItemReview({
    required this.ltoItem,
    this.scrollController,
    super.key,
  });

  @override
  State<RegularItemReview> createState() => _RegularItemReviewState();
}

class _RegularItemReviewState extends State<RegularItemReview> {
  String? _selectedVariantId;
  bool _isUpdatingImage = false;
  String? _currentImageUrl;
  String? _currentName;
  double? _currentPrice;
  double? _currentOriginalPrice;
  int? _currentPrepTime;
  bool? _currentAvailability;
  DateTime? _currentStartDate;
  DateTime? _currentEndDate;
  List<String>? _currentIngredients;
  String? _currentMainIngredients;
  final RegularItemOperationsHelper _operationsHelper =
      RegularItemOperationsHelper();

  // Local copy of menu item to update when supplements/pricing are added
  MenuItem get _localMenuItem => _localMenuItemValue ?? widget.ltoItem;
  MenuItem? _localMenuItemValue;

  @override
  void initState() {
    super.initState();
    // Initialize local copy of menu item
    _localMenuItemValue = widget.ltoItem;

    // Select the default variant or first variant
    final localItem = _localMenuItem;
    if (localItem.variants.isNotEmpty) {
      final defaultVariant = localItem.variants.firstWhere(
        (v) => v['is_default'] == true,
        orElse: () => localItem.variants.first,
      );
      _selectedVariantId = defaultVariant['id'];
    }
    _currentImageUrl = localItem.image;
    _currentName = localItem.name;
    _currentPrice = localItem.price;
    _currentOriginalPrice = localItem.originalPrice;
    _currentPrepTime = localItem.preparationTime;
    _currentAvailability = localItem.isAvailable;
    _currentStartDate = _offerStartDate;
    _currentEndDate = _offerEndDate;
    _currentIngredients = List<String>.from(localItem.ingredients);
    _currentMainIngredients = localItem.mainIngredients;
  }

  /// Edit image functionality
  Future<void> _editImage(BuildContext context) async {
    setState(() => _isUpdatingImage = true);
    final newImageUrl =
        await _operationsHelper.editImage(context, widget.ltoItem);
    if (newImageUrl != null && mounted) {
      setState(() {
        _currentImageUrl = newImageUrl;
        _isUpdatingImage = false;
      });
    } else if (mounted) {
      setState(() => _isUpdatingImage = false);
    }
  }

  /// Edit name functionality
  Future<void> _editName(BuildContext context) async {
    setState(() => _isUpdatingImage = true);
    final newName = await _operationsHelper.editName(
      context,
      widget.ltoItem,
      _currentName ?? widget.ltoItem.name,
    );
    if (newName != null && mounted) {
      setState(() {
        _currentName = newName;
        _isUpdatingImage = false;
      });
    } else if (mounted) {
      setState(() => _isUpdatingImage = false);
    }
  }

  /// Edit discounted price functionality
  Future<void> _editDiscountedPrice(BuildContext context) async {
    setState(() => _isUpdatingImage = true);
    final newPrice = await _operationsHelper.editDiscountedPrice(
      context,
      widget.ltoItem,
      _currentPrice,
    );
    if (newPrice != null && mounted) {
      setState(() {
        _currentPrice = newPrice;
        _isUpdatingImage = false;
      });
    } else if (mounted) {
      setState(() => _isUpdatingImage = false);
    }
  }

  /// Edit original price functionality
  Future<void> _editOriginalPrice(BuildContext context) async {
    setState(() => _isUpdatingImage = true);
    final newPrice = await _operationsHelper.editOriginalPrice(
      context,
      widget.ltoItem,
      _currentOriginalPrice,
    );
    if (newPrice != null && mounted) {
      setState(() {
        _currentOriginalPrice = newPrice;
        _isUpdatingImage = false;
      });
    } else if (mounted) {
      setState(() => _isUpdatingImage = false);
    }
  }

  /// Get LTO pricing option (prefer item-level, not size-specific)
  Map<String, dynamic>? get _ltoPricing {
    // First, try to find item-level LTO pricing (no size)
    for (final pricing in widget.ltoItem.pricingOptions) {
      if (pricing['is_limited_offer'] == true) {
        final size = safeString(pricing['size'], defaultValue: '') ?? '';
        if (size.isEmpty) {
          return pricing; // Item-level pricing
        }
      }
    }
    // Fallback to any LTO pricing if no item-level found
    for (final pricing in widget.ltoItem.pricingOptions) {
      if (pricing['is_limited_offer'] == true) {
        return pricing;
      }
    }
    return null;
  }

  /// Get original price (before discount) from item original_price column
  double? get _originalPrice {
    // Use current state value if available, otherwise use item original_price
    return _currentOriginalPrice ??
        widget.ltoItem.originalPrice ??
        widget.ltoItem.price;
  }

  /// Get discounted price from item price column (not from pricing_options)
  double? get _discountedPrice {
    // Use current state value if available, otherwise use item price
    return _currentPrice ?? widget.ltoItem.price;
  }

  /// Get LTO offer dates (use current state if available)
  DateTime? get _offerStartDate {
    if (_currentStartDate != null) return _currentStartDate;
    final ltoPricing = _ltoPricing;
    if (ltoPricing == null) return null;
    final startAt = ltoPricing['offer_start_at'];
    if (startAt == null) return null;
    return safeUtc(startAt);
  }

  DateTime? get _offerEndDate {
    if (_currentEndDate != null) return _currentEndDate;
    final ltoPricing = _ltoPricing;
    if (ltoPricing == null) return null;
    final endAt = ltoPricing['offer_end_at'];
    if (endAt == null) return null;
    return safeUtc(endAt);
  }

  /// Get current prep time (use current state if available)
  int get _currentPrepTimeValue {
    return _currentPrepTime ?? widget.ltoItem.preparationTime;
  }

  /// Get current availability (use current state if available)
  bool get _currentAvailabilityValue {
    return _currentAvailability ?? widget.ltoItem.isAvailable;
  }

  /// Edit prep time functionality
  Future<void> _editPrepTime(BuildContext context) async {
    setState(() => _isUpdatingImage = true);
    final newPrepTime = await _operationsHelper.editPrepTime(
      context,
      widget.ltoItem,
      _currentPrepTimeValue,
    );
    if (newPrepTime != null && mounted) {
      setState(() {
        _currentPrepTime = newPrepTime;
        _isUpdatingImage = false;
      });
    } else if (mounted) {
      setState(() => _isUpdatingImage = false);
    }
  }

  /// Edit ingredients functionality
  Future<void> _editIngredients(BuildContext context) async {
    // Get main ingredients from state or widget
    final mainIngredients =
        _currentMainIngredients ?? widget.ltoItem.mainIngredients;

    // Get regular ingredients from state or widget
    final regularIngredients =
        _currentIngredients ?? widget.ltoItem.ingredients;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (BuildContext dialogContext) {
        return LTOEditIngredientsDialog(
          initialMainIngredients: mainIngredients,
          initialIngredients: regularIngredients,
        );
      },
    );

    if (result == null) return; // User cancelled

    // Update state with new values
    setState(() {
      _currentMainIngredients = result['mainIngredients'] as String?;
      _currentIngredients = result['ingredients'] as List<String>?;
    });

    // Save to database
    try {
      final menuItemService = MenuItemService();
      final updatedMenuItem = widget.ltoItem.copyWith(
        mainIngredients: _currentMainIngredients,
        ingredients: _currentIngredients ?? [],
      );

      final success = await menuItemService.updateMenuItem(updatedMenuItem);

      if (!success) {
        throw Exception('Failed to update menu item');
      }

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ingredients updated successfully'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating ingredients: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  /// Edit variant functionality
  Future<void> _editVariantName(Map<String, dynamic> variant) async {
    await _operationsHelper.editVariantName(
      context,
      widget.ltoItem.id,
      variant,
      onUpdated: () => _reloadMenuItem(),
    );
  }

  /// Add global supplement (available for all variants)
  Future<void> _addGlobalSupplement() async {
    await AddGlobalSupplementDialog.show(
      context,
      widget.ltoItem.id,
      onAdded: () => _reloadMenuItem(),
    );
  }

  /// Add global size with variant selection
  Future<void> _addGlobalSize() async {
    final variants = _localMenuItem.variants.cast<Map<String, dynamic>>();
    await AddGlobalSizeDialog.show(
      context,
      widget.ltoItem.id,
      variants,
      onAdded: () => _reloadMenuItem(),
    );
  }

  /// Add new variant
  Future<void> _addVariant() async {
    await _operationsHelper.addVariant(
      context,
      widget.ltoItem.id,
      onAdded: () => _reloadMenuItem(),
    );
  }

  /// Add pricing functionality
  Future<void> _addPricing(String variantId) async {
    await _operationsHelper.addPricing(
      context,
      widget.ltoItem.id,
      variantId,
      onAdded: () => _reloadMenuItem(),
    );
  }

  /// Add supplement functionality
  Future<void> _addSupplement(String variantId) async {
    await _operationsHelper.addSupplement(
      context,
      widget.ltoItem.id,
      variantId,
      onAdded: () => _reloadMenuItem(),
    );
  }

  /// Reload menu item from database
  Future<void> _reloadMenuItem() async {
    try {
      // PERF: Use forceRefresh parameter instead of clearCache()
      // This allows the repository to use stale-while-revalidate pattern
      // and prevents unnecessary cache invalidation
      final menuItemService = MenuItemService();

      // Reload menu item from database with force refresh
      final updatedItem = await menuItemService
          .getMenuItemById(widget.ltoItem.id, forceRefresh: true);

      if (updatedItem != null && mounted) {
        // Debug: Check supplements after reload
        debugPrint('🔄 Reloaded menu item - checking supplements:');
        for (var i = 0; i < updatedItem.supplements.length; i++) {
          final supp = updatedItem.supplements[i];
          debugPrint(
              '  [$i] ${supp['name']}: available_for_variants = ${supp['available_for_variants']}');
        }

        // Update local menu item copy with fresh data
        setState(() {
          _localMenuItemValue = updatedItem;
        });
      }
    } catch (e) {
      if (mounted) {
        debugPrint('Error reloading menu item: $e');
        // Don't show error to user as it's not critical - supplement was added successfully
      }
    }
  }

  /// Toggle variant visibility
  Future<void> _toggleVariantVisibility(
      Map<String, dynamic> variant, bool isAvailable) async {
    await _operationsHelper.toggleVariantVisibility(
      context,
      widget.ltoItem.id,
      variant,
      isAvailable: isAvailable,
      onUpdated: () => _reloadMenuItem(),
    );
  }

  /// Delete variant functionality
  Future<void> _deleteVariant(Map<String, dynamic> variant) async {
    final variantId = variant['id'] as String? ?? '';
    await _operationsHelper.deleteVariant(
      context,
      widget.ltoItem.id,
      variant,
      onDeleted: () {
        _reloadMenuItem();
        if (mounted) {
          setState(() {
            // Reset selected variant if it was the one being deleted
            if (_selectedVariantId == variantId) {
              _selectedVariantId = null;
            }
          });
        }
      },
    );
  }

  /// Edit pricing functionality
  Future<void> _editPricing(
      Map<String, dynamic> pricing, String variantId) async {
    await _operationsHelper.editPricing(
      context,
      widget.ltoItem.id,
      variantId,
      pricing,
      onUpdated: () => _reloadMenuItem(),
    );
  }

  /// Delete pricing functionality
  Future<void> _deletePricing(String pricingId) async {
    await _operationsHelper.deletePricing(
      context,
      widget.ltoItem.id,
      pricingId,
      onDeleted: () => _reloadMenuItem(),
    );
  }

  /// Delete supplement functionality
  Future<void> _deleteSupplement(String supplementId) async {
    await _operationsHelper.deleteSupplement(
      context,
      widget.ltoItem.id,
      supplementId,
      onDeleted: () => _reloadMenuItem(),
    );
  }

  /// Edit availability functionality
  Future<void> _editAvailability(BuildContext context) async {
    setState(() => _isUpdatingImage = true);
    final newAvailability = await _operationsHelper.editAvailability(
      context,
      widget.ltoItem,
      currentAvailability: _currentAvailabilityValue,
    );
    if (newAvailability != null && mounted) {
      setState(() {
        _currentAvailability = newAvailability;
        _isUpdatingImage = false;
      });
    } else if (mounted) {
      setState(() => _isUpdatingImage = false);
    }
  }

  /// Edit start date functionality
  Future<void> _editStartDate(BuildContext context) async {
    setState(() => _isUpdatingImage = true);
    final newStartDate = await _operationsHelper.editStartDate(
      context,
      widget.ltoItem,
      _offerStartDate,
    );
    if (newStartDate != null && mounted) {
      setState(() {
        _currentStartDate = newStartDate;
        _isUpdatingImage = false;
      });
    } else if (mounted) {
      setState(() => _isUpdatingImage = false);
    }
  }

  /// Edit end date functionality
  Future<void> _editEndDate(BuildContext context) async {
    setState(() => _isUpdatingImage = true);
    final newEndDate = await _operationsHelper.editEndDate(
      context,
      widget.ltoItem,
      _offerEndDate,
    );
    if (newEndDate != null && mounted) {
      setState(() {
        _currentEndDate = newEndDate;
        _isUpdatingImage = false;
      });
    } else if (mounted) {
      setState(() => _isUpdatingImage = false);
    }
  }

  /// Get all ingredients (main ingredients + regular ingredients unified)
  List<String> get _allIngredients {
    final allIngredients = <String>[];
    if (_currentMainIngredients != null &&
        _currentMainIngredients!.isNotEmpty) {
      allIngredients.addAll(
        _currentMainIngredients!
            .split(',')
            .map((ingredient) => ingredient.trim())
            .where((ingredient) => ingredient.isNotEmpty),
      );
    }
    if (_currentIngredients != null) {
      allIngredients.addAll(_currentIngredients!);
    }
    return allIngredients;
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
          // Hero image - full width with no top padding
          // PERF: RepaintBoundary isolates image repaints during scroll
          SliverToBoxAdapter(
            child: RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
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
            ),
          ),

          // Title container
          // PERF: RepaintBoundary isolates title container repaints
          SliverToBoxAdapter(
            child: RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20),
                child: LTOTitleContainerWidget(
                  title: _currentName ?? widget.ltoItem.name,
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
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 20)),

          // Description
          // PERF: RepaintBoundary isolates description repaints
          SliverToBoxAdapter(
            child: RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20),
                child: DescriptionSectionWidget(
                  description: widget.ltoItem.description,
                ),
              ),
            ),
          ),

          // Variants section
          // PERF: RepaintBoundary isolates variants section repaints
          if (widget.ltoItem.variants.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: RepaintBoundary(
                child: Padding(
                  padding: const EdgeInsets.only(left: 20, right: 20),
                  child: VariantsSectionWidget(
                    variants:
                        _localMenuItem.variants.cast<Map<String, dynamic>>(),
                    selectedVariantId: _selectedVariantId,
                    onAddGlobalSupplement: () => _addGlobalSupplement(),
                    onAddSize: () => _addGlobalSize(),
                    onAddVariant: () => _addVariant(),
                    onVariantSelected: (variantId) {
                      setState(() {
                        _selectedVariantId = variantId;
                      });
                    },
                    onEditVariantName: (variant) => _editVariantName(variant),
                    onDeleteVariant: (variant) => _deleteVariant(variant),
                    onToggleVariantVisibility: (variant, isAvailable) =>
                        _toggleVariantVisibility(variant, isAvailable),
                  ),
                ),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 16)),
            // Show pricing and supplements for selected variant
            // PERF: Memoize variant filtering logic to avoid expensive computations on every build
            // PERF: Use RepaintBoundary to isolate repaints of this complex widget
            SliverToBoxAdapter(
              child: RepaintBoundary(
                child: _PricingSupplementsWidget(
                  selectedVariantId: _selectedVariantId,
                  localMenuItem: _localMenuItem,
                  onVariantSelected: (variantId) {
                    setState(() {
                      _selectedVariantId = variantId;
                    });
                  },
                  onEditPricing: _editPricing,
                  onDeletePricing: _deletePricing,
                  onAddPricing: _addPricing,
                  onDeleteSupplement: _deleteSupplement,
                  onAddSupplement: _addSupplement,
                ),
              ),
            ),
          ],

          // Ingredients (Main Ingredients + Ingredients unified)
          // PERF: RepaintBoundary isolates ingredients section repaints
          SliverToBoxAdapter(
            child: RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20),
                child: IngredientsSectionWidget(
                  ingredients: _allIngredients,
                  onEdit: () => _editIngredients(context),
                ),
              ),
            ),
          ),

          // Free Drinks Controller
          // PERF: RepaintBoundary isolates free drinks controller repaints
          SliverToBoxAdapter(
            child: RepaintBoundary(
              child: Padding(
                padding: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
                child: LTOFreeDrinksControllerWidget(
                  menuItem: _localMenuItem,
                  onChanged: () => _reloadMenuItem(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// PERF: Memoized widget for pricing and supplements section
/// This isolates expensive filtering logic and prevents rebuilds on scroll
class _PricingSupplementsWidget extends StatefulWidget {
  final String? selectedVariantId;
  final MenuItem localMenuItem;
  final void Function(String?) onVariantSelected;
  final void Function(Map<String, dynamic>, String) onEditPricing;
  final void Function(String) onDeletePricing;
  final void Function(String) onAddPricing;
  final void Function(String) onDeleteSupplement;
  final void Function(String) onAddSupplement;

  const _PricingSupplementsWidget({
    required this.selectedVariantId,
    required this.localMenuItem,
    required this.onVariantSelected,
    required this.onEditPricing,
    required this.onDeletePricing,
    required this.onAddPricing,
    required this.onDeleteSupplement,
    required this.onAddSupplement,
  });

  @override
  State<_PricingSupplementsWidget> createState() =>
      _PricingSupplementsWidgetState();
}

class _PricingSupplementsWidgetState extends State<_PricingSupplementsWidget> {
  String? _cachedSelectedVariantId;
  List<Map<String, dynamic>>? _cachedVariantPricing;
  List<Map<String, dynamic>>? _cachedVariantSupplements;
  String? _cachedVariantId;
  String? _cachedVariantName;

  @override
  void initState() {
    super.initState();
    _cachedSelectedVariantId = widget.selectedVariantId;
    _updateCache();
  }

  @override
  void didUpdateWidget(_PricingSupplementsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // PERF: Only recompute if variant selection or menu item changed
    if (widget.selectedVariantId != oldWidget.selectedVariantId ||
        widget.localMenuItem.id != oldWidget.localMenuItem.id) {
      _cachedSelectedVariantId = widget.selectedVariantId;
      _updateCache();
    }
  }

  void _updateCache() {
    // Get selected variant (always required now, no global option)
    String? variantId = _cachedSelectedVariantId;
    String? variantName = '';

    if (variantId == null) {
      // Default to first variant if none selected
      if (widget.localMenuItem.variants.isNotEmpty) {
        final defaultVariant = widget.localMenuItem.variants.firstWhere(
          (v) => v['is_default'] == true,
          orElse: () => widget.localMenuItem.variants.first,
        );
        variantId = defaultVariant['id'];
      } else {
        // No variants available
        _cachedVariantId = null;
        _cachedVariantName = null;
        _cachedVariantPricing = null;
        _cachedVariantSupplements = null;
        return;
      }
    }

    final selectedVariant = widget.localMenuItem.variants.firstWhere(
      (v) => v['id'] == variantId,
      orElse: () => widget.localMenuItem.variants.first,
    );

    variantId = selectedVariant['id'];
    variantName = selectedVariant['name'] ?? '';

    // PERF: Memoize expensive filtering operations
    // Get pricing: include both variant-specific AND global (null/empty variant_id)
    final variantPricing = widget.localMenuItem.pricingOptions
        .cast<Map<String, dynamic>>()
        .where((p) {
      final pVariantId = p['variant_id'];
      // Include if it's for this variant OR if it's global (null/empty)
      return pVariantId == variantId || pVariantId == null || pVariantId == '';
    }).toList();

    // Get supplements: include both variant-specific AND global (null/empty available_for_variants)
    final variantSupplements = widget.localMenuItem.supplements
        .cast<Map<String, dynamic>>()
        .where((s) {
      final availableFor = s['available_for_variants'];

      // Global supplements: null or empty available_for_variants
      if (availableFor == null) {
        return true; // Global supplement - show it
      }

      if (availableFor is! List) {
        return false; // Invalid format
      }

      final availableForList = List.from(availableFor);

      // Global supplements: empty list
      if (availableForList.isEmpty) {
        return true; // Global supplement - show it
      }

      // Variant-specific supplements: check if assigned to this variant
      final variantIdStr = variantId.toString();
      final variantIdList = availableForList.map((e) => e.toString()).toList();
      return variantIdList.contains(variantIdStr);
    }).toList();

    // Cache results
    _cachedVariantId = variantId;
    _cachedVariantName = variantName;
    _cachedVariantPricing = variantPricing;
    _cachedVariantSupplements = variantSupplements;
  }

  @override
  Widget build(BuildContext context) {
    // PERF: Return cached data if available, otherwise compute
    if (_cachedVariantId == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(left: 20, right: 20),
      child: PricingSupplementsSectionWidget(
        variantId: _cachedVariantId!,
        variantName: _cachedVariantName ?? '',
        variantPricing: _cachedVariantPricing ?? [],
        variantSupplements: _cachedVariantSupplements ?? [],
        onEditPricing: (pricing, variantId) =>
            widget.onEditPricing(pricing, variantId),
        onDeletePricing: (pricingId) => widget.onDeletePricing(pricingId),
        onAddPricing: (variantId) => widget.onAddPricing(variantId),
        onDeleteSupplement: (supplementId) =>
            widget.onDeleteSupplement(supplementId),
        onAddSupplement: (variantId) => widget.onAddSupplement(variantId),
      ),
    );
  }
}
