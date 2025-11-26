import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../../config/menu_item_form_controller.dart';
import '../../../l10n/app_localizations.dart';
import '../../../models/category.dart';
import '../../../models/cuisine_type.dart';
import '../../../models/menu_item_variant.dart';
import '../../pill_dropdown.dart';
import 'limited_time_offer_section.dart';
import 'supplements_section.dart';
import 'variant_pricing_section.dart';

/// Widget for the Basic Information step of the Add New Menu Item form
///
/// This step collects:
/// - Cuisine type and category
/// - Menu item name
/// - Variants and pricing
/// - Main ingredients
/// - Preparation time
/// - Ingredient list
/// - Supplements
class BasicInformationStep extends StatelessWidget {
  final List<CuisineType> cuisineTypes;
  final List<Category> filteredCategories;
  final String? selectedCuisineTypeId;
  final String? selectedCategoryId;
  final bool isLoadingCuisines;
  final bool isLoadingCategories;
  final ValueChanged<String?> onCuisineChanged;
  final ValueChanged<String?> onCategoryChanged;

  /// Can accept a single variant ID (String) or multiple (List<String>)
  final void Function(dynamic variantIds) onAddPricing;
  final void Function(MenuItemVariant variant, int quantity)? onEditPackItem;
  final void Function(String supplementId) onManageSupplementVariants;
  final VoidCallback onAddSupplement;
  final VoidCallback? onSelectFreeDrinks;
  final String? restaurantId;
  final bool showOnlySupplements; // If true, show only supplements section

  const BasicInformationStep({
    required this.cuisineTypes,
    required this.filteredCategories,
    required this.selectedCuisineTypeId,
    required this.selectedCategoryId,
    required this.isLoadingCuisines,
    required this.isLoadingCategories,
    required this.onCuisineChanged,
    required this.onCategoryChanged,
    required this.onAddPricing,
    required this.onManageSupplementVariants,
    required this.onAddSupplement,
    this.onEditPackItem,
    this.onSelectFreeDrinks,
    this.restaurantId,
    this.showOnlySupplements = false,
    super.key,
  });

  static const _primaryColor = Color(0xFFd47b00);

  static BoxDecoration _getCardDecoration() {
    return BoxDecoration(
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
  }

  Widget _buildPriceText(BuildContext context, double price, {Color? color}) {
    return Text(
      '+${price.toStringAsFixed(0)} ${AppLocalizations.of(context)!.currency}',
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: color ?? _primaryColor,
      ),
    );
  }

  static Widget _buildItemCard({
    required Widget child,
    Color? backgroundColor,
    Color? borderColor,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor ?? Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor ?? Colors.grey[300]!),
      ),
      child: child,
    );
  }

  static Widget _buildActionButton({
    required String label,
    required VoidCallback onPressed,
    IconData? icon,
    Color? backgroundColor,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon ?? Icons.add, size: 16),
      label: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? _primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  static List<String> _getVariantNames(
    List<String> variantIds,
    List<MenuItemVariant> variants,
  ) {
    return variantIds
        .map((id) {
          try {
            return variants.firstWhere((v) => v.id == id).name;
          } catch (e) {
            return null;
          }
        })
        .whereType<String>()
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Consumer<MenuItemFormController>(
        builder: (context, formController, child) {
          // If showOnlySupplements is true, show only supplements section
          if (showOnlySupplements) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 16),
                _buildSectionTitle(AppLocalizations.of(context)!.supplements),
                const SizedBox(height: 8),
                SupplementsSection(
                  cardDecoration: _getCardDecoration(),
                  onManageVariants: onManageSupplementVariants,
                  onAddSupplement: onAddSupplement,
                  buildPriceText: (context, price, {color}) =>
                      _buildPriceText(context, price, color: color),
                  buildItemCard: _buildItemCard,
                  buildActionButton: _buildActionButton,
                  getVariantNames: _getVariantNames,
                  restaurantId: restaurantId,
                ),
              ],
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildCategoryDropdown(context),
              const SizedBox(height: 16),
              _buildCuisineTypeDropdown(context),
              const SizedBox(height: 16),
              // LIMITED TIME OFFER SECTION
              LimitedTimeOfferSection(
                controller: formController,
                primaryColor: _primaryColor,
                restaurantId: restaurantId,
              ),
              const SizedBox(height: 16),
              _buildTextField(
                label:
                    '${AppLocalizations.of(context)!.menuItemName} (${AppLocalizations.of(context)!.category}) *',
                hint: AppLocalizations.of(context)!.enterTheNameOfYourMenuItem,
                value: formController.dishName,
                onChanged: formController.setDishName,
                validator: formController.getDishNameError,
                icon: Icons.restaurant,
              ),
              const SizedBox(height: 16),
              // Show base price field for:
              // 1. Special packs (always)
              // 2. LTO items with special_price offer type (for discount calculation)
              if (formController.isSpecialPack ||
                  (formController.isLimitedOffer &&
                      formController.offerTypes.contains('special_price'))) ...[
                _buildTextField(
                  label: formController.isLimitedOffer &&
                          !formController.isSpecialPack
                      ? '${AppLocalizations.of(context)!.price} (Base Price - ${AppLocalizations.of(context)!.currency}) *'
                      : '${AppLocalizations.of(context)!.price} (${AppLocalizations.of(context)!.currency}) *',
                  hint: 'e.g., 2500',
                  value: formController.packPrice,
                  onChanged: formController.setPackPrice,
                  validator: () {
                    if (formController.packPrice.isEmpty) {
                      return formController.isLimitedOffer &&
                              !formController.isSpecialPack
                          ? 'Base price is required for special price offer'
                          : 'Pack price is required';
                    }
                    final price = double.tryParse(formController.packPrice);
                    if (price == null || price <= 0) {
                      return 'Please enter a valid price';
                    }
                    return null;
                  },
                  icon: Icons.payments,
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 16),
              ],
              VariantPricingSection(
                onAddPricing: onAddPricing,
                onEditPackItem: onEditPackItem,
                restaurantId: restaurantId,
              ),
              const SizedBox(height: 16),
              // Free Drinks Section (only for special packs WITHOUT LTO free drinks)
              // Hide if LTO is active with free drinks to avoid duplication
              if (formController.isSpecialPack &&
                  !(formController.isLimitedOffer &&
                      formController.offerTypes.contains('free_drinks'))) ...[
                _buildFreeDrinksSection(
                    context, formController, onSelectFreeDrinks),
                const SizedBox(height: 16),
              ],
              // Global Pack Ingredients Section (only for special packs - replaces main ingredients)
              if (formController.isSpecialPack) ...[
                _buildGlobalIngredientsSection(context, formController),
                const SizedBox(height: 16),
              ],
              // Main Ingredients (only for non-pack items)
              if (!formController.isSpecialPack) ...[
                _buildTextField(
                  label: AppLocalizations.of(context)!.mainIngredients,
                  hint: AppLocalizations.of(context)!
                      .listMainIngredientsIfNoDescription,
                  value: formController.mainIngredients,
                  onChanged: formController.setMainIngredients,
                  icon: Icons.restaurant_menu,
                  maxLines: 1,
                ),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 16),
              _buildTextField(
                label:
                    '${AppLocalizations.of(context)!.preparationTime} (${AppLocalizations.of(context)!.minutes}) *',
                hint: 'e.g., 15',
                value: formController.preparationTime,
                onChanged: formController.setPreparationTime,
                validator: formController.getPreparationTimeError,
                icon: Icons.timer,
                keyboardType: TextInputType.number,
              ),
              // Ingredients section (only for non-pack items)
              // Special packs use per-item ingredients and global pack ingredients instead
              if (!formController.isSpecialPack) ...[
                const SizedBox(height: 16),
                _buildSectionTitle(AppLocalizations.of(context)!.ingredients),
                const SizedBox(height: 8),
                _buildListField(
                  label: AppLocalizations.of(context)!.ingredients,
                  items: formController.ingredients,
                  onAdd: formController.addIngredient,
                  onRemove: formController.removeIngredient,
                  hint: AppLocalizations.of(context)!.addIngredient,
                  icon: Icons.list,
                ),
              ],
              // Dish Supplements section (only for non-pack items)
              // Special packs use per-item supplements and global pack supplements instead
              if (!formController.isSpecialPack) ...[
                const SizedBox(height: 16),
                _buildSectionTitle(AppLocalizations.of(context)!.supplements),
                const SizedBox(height: 8),
                SupplementsSection(
                  cardDecoration: _getCardDecoration(),
                  onManageVariants: onManageSupplementVariants,
                  onAddSupplement: onAddSupplement,
                  buildPriceText: (context, price, {color}) =>
                      _buildPriceText(context, price, color: color),
                  buildItemCard: _buildItemCard,
                  buildActionButton: _buildActionButton,
                  getVariantNames: _getVariantNames,
                  restaurantId: restaurantId,
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Colors.black,
      ),
    );
  }

  Widget _buildCuisineTypeDropdown(BuildContext context) {
    final isDisabled = selectedCategoryId == null || isLoadingCuisines;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${AppLocalizations.of(context)!.cuisineType} *',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Opacity(
          opacity: isDisabled ? 0.5 : 1.0,
          child: IgnorePointer(
            ignoring: isDisabled,
            child: PillDropdown<String>(
              value: selectedCuisineTypeId,
              hint: isDisabled
                  ? AppLocalizations.of(context)!.pleaseSelectCategoryFirst
                  : AppLocalizations.of(context)!.selectCuisineType,
              items: isLoadingCuisines
                  ? [
                      DropdownMenuItem<String>(
                        value: null,
                        child: Row(
                          children: [
                            const Icon(Icons.restaurant, size: 18),
                            const SizedBox(width: 12),
                            Text(AppLocalizations.of(context)!.loadingCuisines),
                          ],
                        ),
                      )
                    ]
                  : cuisineTypes.map((cuisine) {
                      return DropdownMenuItem<String>(
                        value: cuisine.id,
                        child: Row(
                          children: [
                            const Icon(Icons.restaurant, size: 18),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                cuisine.name,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
              onChanged: isDisabled ? null : onCuisineChanged,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return AppLocalizations.of(context)!.pleaseSelectCuisineType;
                }
                return null;
              },
            ),
          ),
        ),
        if (selectedCategoryId == null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              AppLocalizations.of(context)!.pleaseSelectCategoryFirst,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryDropdown(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${AppLocalizations.of(context)!.category} *',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        PillDropdown<String>(
          value: selectedCategoryId,
          hint: AppLocalizations.of(context)!.selectCategory,
          items: isLoadingCategories
              ? [
                  DropdownMenuItem<String>(
                    value: null,
                    child: Row(
                      children: [
                        const Icon(Icons.category, size: 18),
                        const SizedBox(width: 12),
                        Text(AppLocalizations.of(context)!.loadingCategories),
                      ],
                    ),
                  )
                ]
              : filteredCategories.map((category) {
                  return DropdownMenuItem<String>(
                    value: category.id,
                    child: Row(
                      children: [
                        const Icon(Icons.category, size: 18),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            category.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
          onChanged: isLoadingCategories ? null : onCategoryChanged,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return AppLocalizations.of(context)!.pleaseSelectCategory;
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required String value,
    required ValueChanged<String> onChanged,
    String? Function()? validator,
    IconData? icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
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
            initialValue: value,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[400],
              ),
              prefixIcon:
                  icon != null ? Icon(icon, color: Colors.black87) : null,
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
                borderSide: BorderSide(color: Colors.orange[600]!, width: 1.5),
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
            ),
            maxLines: maxLines,
            keyboardType: keyboardType,
            onChanged: onChanged,
            validator: (_) => validator?.call(),
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildListField({
    required String label,
    required List<String> items,
    required ValueChanged<String> onAdd,
    required ValueChanged<String> onRemove,
    required String hint,
    required IconData icon,
  }) {
    final controller = TextEditingController();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
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
                  controller: controller,
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[400],
                    ),
                    prefixIcon: Icon(icon, color: Colors.black87),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide:
                          BorderSide(color: Colors.grey[300]!, width: 1),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide:
                          BorderSide(color: Colors.grey[300]!, width: 1),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(26),
                      borderSide:
                          BorderSide(color: Colors.orange[600]!, width: 1.5),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 18),
                  ),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (value) {
                    if (value.trim().isNotEmpty) {
                      onAdd(value.trim());
                      controller.clear();
                    }
                  },
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: _primaryColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: IconButton(
                onPressed: () {
                  if (controller.text.trim().isNotEmpty) {
                    onAdd(controller.text.trim());
                    controller.clear();
                  }
                },
                icon: const Icon(Icons.add_circle, color: _primaryColor),
                iconSize: 32,
              ),
            ),
          ],
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: items.map((item) {
              return Chip(
                label: Text(
                  item,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
                deleteIcon: const Icon(Icons.close, size: 18),
                onDeleted: () => onRemove(item),
                backgroundColor: _primaryColor.withValues(alpha: 0.1),
                deleteIconColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  /// Builds the free drinks section for special packs
  static Widget _buildFreeDrinksSection(
    BuildContext context,
    MenuItemFormController formController,
    VoidCallback? onSelectFreeDrinks,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: _getCardDecoration(),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Free Drinks Included',
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Select which drinks are included with this pack',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),
            // Display selected drinks count
            if (formController.freeDrinkIds.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle,
                        color: Colors.green[700], size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '${formController.freeDrinkIds.length} drink${formController.freeDrinkIds.length > 1 ? 's' : ''} selected',
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.green[700],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            // Select drinks button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onSelectFreeDrinks,
                icon: Icon(
                  formController.freeDrinkIds.isEmpty ? Icons.add : Icons.edit,
                  size: 18,
                ),
                label: Text(
                  formController.freeDrinkIds.isEmpty
                      ? 'Select Free Drinks'
                      : 'Change Selection',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _primaryColor,
                  side: const BorderSide(color: _primaryColor),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds the global ingredients section for special packs
  static Widget _buildGlobalIngredientsSection(
    BuildContext context,
    MenuItemFormController formController,
  ) {
    final controller = TextEditingController();

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.restaurant_menu, color: Colors.grey[700], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Global Pack Ingredients',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Main ingredients for the whole pack (displayed above drinks, not customizable by customers)',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[700],
                fontStyle: FontStyle.italic,
              ),
            ),
            const SizedBox(height: 12),
            // Input field
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: 'Add main ingredient (e.g., Sauce, Ketchup)...',
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
                    onSubmitted: (value) {
                      if (value.trim().isNotEmpty) {
                        formController.addGlobalPackIngredient(value.trim());
                        controller.clear();
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    onPressed: () {
                      if (controller.text.trim().isNotEmpty) {
                        formController
                            .addGlobalPackIngredient(controller.text.trim());
                        controller.clear();
                      }
                    },
                    icon: Icon(Icons.add_circle, color: Colors.grey[700]),
                    iconSize: 32,
                    tooltip: 'Add main ingredient',
                  ),
                ),
              ],
            ),
            // Display added ingredients
            if (formController.globalPackIngredients.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children:
                    formController.globalPackIngredients.map((ingredient) {
                  return Chip(
                    label: Text(
                      ingredient,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    deleteIcon: const Icon(Icons.close, size: 16),
                    onDeleted: () =>
                        formController.removeGlobalPackIngredient(ingredient),
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
    );
  }
}
