import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../config/menu_item_form_controller.dart';
import '../../../models/menu_item_pricing.dart';
import '../../../models/menu_item_variant.dart';
import 'add_variant_form.dart';
import 'supplement_suggestions_widget.dart';
import 'unified_flavor_size_widget.dart';
import 'variant_pricing_widgets.dart';

/// A complete section widget for managing menu item variants and pricing.
///
/// This widget encapsulates all functionality related to:
/// - Displaying existing variants with their pricing options
/// - Adding new variants
/// - Managing variant-specific pricing
///
/// The widget integrates with [MenuItemFormController] for state management
/// and provides callbacks for variant and pricing operations.
///
/// Example usage:
/// ```dart
/// VariantPricingSection(
///   onAddPricing: (variantId) => showPricingDialog(variantId),
/// )
/// ```
class VariantPricingSection extends StatelessWidget {
  /// Callback when user wants to add pricing to variants
  /// Can accept a single variant ID (String) or multiple (List<String>)
  final void Function(dynamic variantIds) onAddPricing;

  /// Optional callback when user wants to edit a pack item
  final void Function(MenuItemVariant variant, int quantity)? onEditPackItem;

  /// Optional callback when a variant is successfully added
  final VoidCallback? onVariantAdded;

  /// Primary color for the section (defaults to orange)
  final Color? primaryColor;

  /// Optional custom box decoration for the container
  final BoxDecoration? decoration;

  /// Restaurant ID for loading supplement suggestions
  final String? restaurantId;

  const VariantPricingSection({
    required this.onAddPricing,
    this.onEditPackItem,
    this.onVariantAdded,
    this.primaryColor,
    this.decoration,
    this.restaurantId,
    super.key,
  });

  static final _defaultDecoration = BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return Consumer<MenuItemFormController>(
      builder: (context, formController, child) {
        final isSpecialPack = formController.isSpecialPack;

        return Container(
          decoration: decoration ?? _defaultDecoration,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top safe area padding
              const SizedBox(height: 16),
              // List of existing variants (items for packs) with pricing
              if (formController.variants.isNotEmpty)
                ...formController.variants.map(
                  (variant) => isSpecialPack
                      ? _buildPackItemCard(variant, formController)
                      : _buildVariantCard(
                          variant,
                          formController.pricingOptions
                              .where((p) => p.variantId == variant.id)
                              .toList(),
                          formController,
                        ),
                ),

              // Unified Add Flavor & Size widget (only for regular items)
              if (!isSpecialPack)
                UnifiedFlavorSizeWidget(
                  onAddPricing: (variantIds) {
                    // Show dialog for all selected variants
                    onAddPricing(variantIds);
                  },
                  primaryColor: primaryColor,
                ),

              // Add new variant form (different label for packs)
              AddVariantForm(
                formController: formController,
                onVariantAdded: onVariantAdded,
                primaryColor: primaryColor,
                isPackItem: isSpecialPack,
              ),
            ],
          ),
        );
      },
    );
  }

  /// Parse quantity from variant description (format: "qty:2" or "qty:2|options:...")
  int _parseQuantity(String? description) {
    if (description == null || !description.startsWith('qty:')) {
      return 1; // Default quantity
    }
    try {
      // Split by colon first: "qty:2|options:..." -> ["qty", "2|options:..."]
      final parts = description.split(':');
      if (parts.length >= 2) {
        // Get the part after "qty:" and before any "|": "2|options:..." -> "2"
        final quantityPart = parts[1].split('|').first.trim();
        return int.parse(quantityPart);
      }
    } catch (e) {
      // If parsing fails, return 1
      debugPrint('⚠️ Failed to parse quantity from: $description');
    }
    return 1;
  }

  /// Builds a simple pack item card (no pricing, just item name and variants)
  Widget _buildPackItemCard(
    MenuItemVariant variant,
    MenuItemFormController formController,
  ) {
    final quantity = _parseQuantity(variant.description);

    return PackItemCard(
      variant: variant,
      quantity: quantity,
      formController: formController,
      onEditPackItem: onEditPackItem,
      primaryColor: primaryColor,
      restaurantId: restaurantId,
    );
  }

  /// Builds a variant card with its pricing options
  Widget _buildVariantCard(
    MenuItemVariant variant,
    List<MenuItemPricing> pricing,
    MenuItemFormController formController,
  ) {
    return VariantItemCard(
      variant: variant,
      pricing: pricing,
      onRemove: () => formController.removeVariant(variant.id),
      onRemovePricing: (pricingId) =>
          formController.removePricingOption(pricingId),
      isLTO: formController.isLimitedOffer,
    );
  }
}

/// Stateful widget for pack item card with options input
class PackItemCard extends StatefulWidget {
  final MenuItemVariant variant;
  final int quantity;
  final MenuItemFormController formController;
  final void Function(MenuItemVariant, int)? onEditPackItem;
  final Color? primaryColor;
  final String? restaurantId; // For loading supplement suggestions

  const PackItemCard({
    required this.variant,
    required this.quantity,
    required this.formController,
    this.onEditPackItem,
    this.primaryColor,
    this.restaurantId,
    super.key,
  });

  @override
  State<PackItemCard> createState() => _PackItemCardState();
}

class _PackItemCardState extends State<PackItemCard> {
  late final TextEditingController _optionController;
  late final TextEditingController _ingredientController;
  late final TextEditingController _supplementController;
  late final TextEditingController _supplementPriceController;
  final List<String> _options = [];
  final List<String> _ingredients = [];
  // Store supplements as Map<name, price>
  final Map<String, double> _supplements = {};
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _optionController = TextEditingController();
    _ingredientController = TextEditingController();
    _supplementController = TextEditingController();
    _supplementPriceController = TextEditingController();
    // Load existing options, ingredients, and supplements if any (stored in description after qty:)
    _loadExistingData();
  }

  void _loadExistingData() {
    // Data might be stored in description as "qty:2|options:Regular,Spicy|ingredients:Cheese,Tomato|supplements:ExtraCheese,Sauce"
    final desc = widget.variant.description;
    if (desc != null) {
      // Load options
      if (desc.contains('|options:')) {
        final optionsPart = desc.split('|options:')[1].split('|')[0];
        final options = optionsPart.split(',');
        setState(() {
          _options.addAll(options.where((o) => o.trim().isNotEmpty));
        });
      }

      // Load ingredients
      if (desc.contains('|ingredients:')) {
        final ingredientsPart = desc.split('|ingredients:')[1].split('|')[0];
        final ingredients = ingredientsPart.split(',');
        setState(() {
          _ingredients.addAll(ingredients.where((i) => i.trim().isNotEmpty));
        });
      }

      // Load supplements (format: "name:price,name:price")
      if (desc.contains('|supplements:')) {
        final supplementsPart = desc.split('|supplements:')[1].split('|')[0];
        final supplements = supplementsPart.split(',');
        setState(() {
          for (final supplement in supplements) {
            final trimmed = supplement.trim();
            if (trimmed.isNotEmpty) {
              // Parse format: "name:price" or just "name" (default price 0)
              if (trimmed.contains(':')) {
                final parts = trimmed.split(':');
                if (parts.length >= 2) {
                  final name = parts[0].trim();
                  final priceStr = parts[1].trim();
                  final price = double.tryParse(priceStr) ?? 0.0;
                  if (name.isNotEmpty) {
                    _supplements[name] = price;
                  }
                }
              } else {
                // Old format without price (default to 0)
                _supplements[trimmed] = 0.0;
              }
            }
          }
        });
      }
    }
  }

  void _addOption() {
    final option = _optionController.text.trim();
    if (option.isNotEmpty && !_options.contains(option)) {
      setState(() {
        _options.add(option);
      });
      _optionController.clear();
      _updateVariantDescription();
    }
  }

  void _removeOption(String option) {
    setState(() {
      _options.remove(option);
    });
    _updateVariantDescription();
  }

  void _addIngredient() {
    final ingredient = _ingredientController.text.trim();
    if (ingredient.isNotEmpty && !_ingredients.contains(ingredient)) {
      setState(() {
        _ingredients.add(ingredient);
      });
      _ingredientController.clear();
      _updateVariantDescription();
    }
  }

  void _removeIngredient(String ingredient) {
    setState(() {
      _ingredients.remove(ingredient);
    });
    _updateVariantDescription();
  }

  void _addSupplement() {
    final supplement = _supplementController.text.trim();
    final priceStr = _supplementPriceController.text.trim();
    final price = double.tryParse(priceStr) ?? 0.0;

    if (supplement.isNotEmpty && !_supplements.containsKey(supplement)) {
      setState(() {
        _supplements[supplement] = price;
      });
      _supplementController.clear();
      _supplementPriceController.clear();
      _updateVariantDescription();
    }
  }

  void _removeSupplement(String supplement) {
    setState(() {
      _supplements.remove(supplement);
    });
    _updateVariantDescription();
  }

  void _updateVariantDescription() {
    // Store data in description: "qty:2|options:Regular,Spicy|ingredients:Cheese,Tomato|supplements:ExtraCheese:50.0,Sauce:30.0"
    final qtyPart = 'qty:${widget.quantity}';
    final optionsPart =
        _options.isNotEmpty ? '|options:${_options.join(',')}' : '';
    final ingredientsPart =
        _ingredients.isNotEmpty ? '|ingredients:${_ingredients.join(',')}' : '';
    // Format supplements as "name:price" pairs
    final supplementsPart = _supplements.isNotEmpty
        ? '|supplements:${_supplements.entries.map((e) => '${e.key}:${e.value}').join(',')}'
        : '';
    final newDescription =
        qtyPart + optionsPart + ingredientsPart + supplementsPart;

    widget.formController.updateVariant(
      widget.variant.id,
      description: newDescription,
    );
  }

  @override
  void dispose() {
    _optionController.dispose();
    _ingredientController.dispose();
    _supplementController.dispose();
    _supplementPriceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(_isExpanded ? 12 : 24),
        border: Border.all(color: Colors.grey[300]!),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Quantity badge
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: Colors.grey[400]!,
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '${widget.quantity}x',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.variant.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
                // Edit button
                if (widget.onEditPackItem != null) ...[
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.grey[700]!,
                        width: 1.5,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => widget.onEditPackItem!(
                            widget.variant, widget.quantity),
                        customBorder: const CircleBorder(),
                        child: Center(
                          child: Icon(Icons.edit,
                              color: Colors.grey[700], size: 16),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
                // Delete button
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.grey[700]!,
                      width: 1.5,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => widget.formController
                          .removeVariant(widget.variant.id),
                      customBorder: const CircleBorder(),
                      child: Center(
                        child: Icon(Icons.delete,
                            color: Colors.grey[700], size: 16),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                // Expand/Collapse button
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.grey[700]!,
                      width: 1.5,
                    ),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      customBorder: const CircleBorder(),
                      child: Center(
                        child: Icon(
                          _isExpanded ? Icons.expand_less : Icons.expand_more,
                          color: Colors.grey[700],
                          size: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Show sections only when expanded
          if (_isExpanded) ...[
            // Variant options input
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Options (e.g., Regular, Spicy, Extra Cheese)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _optionController,
                          decoration: InputDecoration(
                            hintText: 'Add option...',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[400],
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                color: Colors.grey[600]!,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          style: const TextStyle(fontSize: 14),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _addOption(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: _addOption,
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.black87,
                          ),
                          iconSize: 32,
                          tooltip: 'Add option',
                        ),
                      ),
                    ],
                  ),
                  // Display added options
                  if (_options.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _options.map((option) {
                        return Chip(
                          label: Text(
                            option,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => _removeOption(option),
                          backgroundColor: Colors.grey[100],
                          deleteIconColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: Colors.grey[400]!),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),

            // Ingredients input section
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                ),
                color: Colors.white,
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.restaurant_menu,
                          size: 14, color: Colors.black87),
                      const SizedBox(width: 6),
                      Text(
                        'Ingredients (e.g., Cheese, Tomato, Lettuce)',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _ingredientController,
                          decoration: InputDecoration(
                            hintText: 'Add ingredient...',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[400],
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                color: Colors.grey[600]!,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          style: const TextStyle(fontSize: 14),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _addIngredient(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: _addIngredient,
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.black87,
                          ),
                          iconSize: 32,
                          tooltip: 'Add ingredient',
                        ),
                      ),
                    ],
                  ),
                  // Display added ingredients
                  if (_ingredients.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _ingredients.map((ingredient) {
                        return Chip(
                          label: Text(
                            ingredient,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => _removeIngredient(ingredient),
                          backgroundColor: Colors.grey[100],
                          deleteIconColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: Colors.grey[400]!),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),

            // Supplements input section
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.grey[200]!),
                ),
                color: Colors.white,
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.add_circle_outline,
                          size: 14, color: Colors.black87),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Supplements (e.g., Extra Cheese, Sauce, Bacon)',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                            fontStyle: FontStyle.italic,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _supplementController,
                          decoration: InputDecoration(
                            hintText: 'Supplement name...',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[400],
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                color: Colors.grey[600]!,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          style: const TextStyle(fontSize: 14),
                          textInputAction: TextInputAction.next,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: _supplementPriceController,
                          decoration: InputDecoration(
                            hintText: 'Price...',
                            hintStyle: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[400],
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(20),
                              borderSide: BorderSide(
                                color: Colors.grey[600]!,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          style: const TextStyle(fontSize: 14),
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _addSupplement(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          shape: BoxShape.circle,
                        ),
                        child: IconButton(
                          onPressed: _addSupplement,
                          icon: const Icon(
                            Icons.add_circle,
                            color: Colors.black87,
                          ),
                          iconSize: 32,
                          tooltip: 'Add supplement',
                        ),
                      ),
                    ],
                  ),
                  // Supplement suggestions chips for pack items
                  if (widget.restaurantId != null &&
                      widget.restaurantId!.isNotEmpty)
                    SupplementSuggestionsWidget(
                      restaurantId: widget.restaurantId,
                      isSpecialPack:
                          false, // For individual pack items, use regular supplement logic
                      onSupplementSelected: (supplement) {
                        // Add supplement to pack item supplements
                        setState(() {
                          _supplements[supplement.name] = supplement.price;
                        });
                        _updateVariantDescription();
                      },
                    ),
                  // Display added supplements
                  if (_supplements.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _supplements.entries.map((entry) {
                        final supplementName = entry.key;
                        final supplementPrice = entry.value;
                        return Chip(
                          label: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  supplementName,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 1,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${supplementPrice.toStringAsFixed(0)} DZD',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.grey[700],
                                ),
                              ),
                            ],
                          ),
                          deleteIcon: const Icon(Icons.close, size: 16),
                          onDeleted: () => _removeSupplement(supplementName),
                          backgroundColor: Colors.grey[100],
                          deleteIconColor: Colors.black87,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: Colors.grey[400]!),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ],
              ),
            ),
          ], // End of expanded sections
          // Bottom padding only when expanded to ensure rounded corners are fully visible
          if (_isExpanded) const SizedBox(height: 16),
        ],
      ),
    );
  }
}
