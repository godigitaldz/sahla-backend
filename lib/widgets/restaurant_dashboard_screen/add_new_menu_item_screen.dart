import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/menu_item_form_controller.dart';
import '../../l10n/app_localizations.dart';
import '../../models/category.dart';
import '../../models/cuisine_type.dart';
import '../../models/enhanced_menu_item.dart';
import '../../models/menu_item.dart';
import '../../models/menu_item_pricing.dart';
import '../../models/menu_item_supplement.dart';
import '../../models/menu_item_variant.dart';
import '../../services/category_service.dart';
import '../../services/cuisine_service.dart';
import '../../services/error_handling_service.dart';
import '../../services/error_logging_service.dart';
import '../../services/menu_item_image_service.dart';
import '../../services/menu_item_service.dart';
import '../../services/restaurant_service.dart';
import '../../services/restaurant_supplement_service.dart';
import '../../utils/bottom_padding.dart';
import '../menu_item_full_popup/helpers/special_pack_helper.dart';
import '../pill_dropdown.dart';
import 'add_new_menu_item_screen/basic_information_step.dart';
import 'add_new_menu_item_screen/custom_header.dart';
import 'add_new_menu_item_screen/drink_image_detector.dart';
import 'add_new_menu_item_screen/drink_variants_pricing_step.dart';
import 'add_new_menu_item_screen/images_review_step.dart';

class AddNewMenuItemScreen extends StatefulWidget {
  final MenuItem? menuItem; // Optional menu item for edit mode
  final String? restaurantId; // Optional restaurant ID for LTO drinks loading
  final String?
      initialCategory; // Optional initial category name (e.g., "Drinks")
  final bool showOnlySupplements; // If true, show only supplements section

  const AddNewMenuItemScreen({
    super.key,
    this.menuItem,
    this.restaurantId,
    this.initialCategory,
    this.showOnlySupplements = false,
  });

  @override
  State<AddNewMenuItemScreen> createState() => _AddNewMenuItemScreenState();
}

class _AddNewMenuItemScreenState extends State<AddNewMenuItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late MenuItemFormController _formController;
  late MenuItemImageService _menuItemImageService;
  late MenuItemService _menuItemService;
  late CuisineService _cuisineService;
  late CategoryService _categoryService;
  late RestaurantSupplementService _restaurantSupplementService;

  // ========== UI Constants ==========
  static const _primaryColor = Color(0xFFd47b00);

  // Current step in the form
  int _currentStep = 0;

  // Cuisine and Category state
  List<CuisineType> _cuisineTypes = [];
  List<Category> _allCategories = []; // All categories loaded first
  List<Category> _filteredCategories = []; // Categories filtered by cuisine
  String? _selectedCuisineTypeId;
  String? _selectedCategoryId;
  bool _isLoadingCuisines = true;
  bool _isLoadingCategories = true;

  // Restaurant ID for current user
  String? _currentRestaurantId;

  // Form sections
  List<String> _formSections = ['Add Menu Item']; // Will be updated in build

  // Edit mode flag
  bool get _isEditMode => widget.menuItem != null;

  // Cache for performance optimization
  bool _cachedIsDrinkCategory = false;
  List<String> _cachedFormSections = [];
  int _cachedTotalSteps = 4;

  // Cache for smart drink detection
  String _cachedDrinkName = '';
  String _cachedDrinkDetectionResult = '';
  bool _cachedImageFound = false;

  // Helper method to check if current category is drink (cached for performance)
  bool get _isDrinkCategory {
    // Check both the selected category name AND the dish name for drink/beverage keywords
    // This ensures it works whether user selects "Drinks" category OR types "drink" in name
    final categoryCheck =
        _formController.category.toLowerCase().contains('drink') ||
            _formController.category.toLowerCase().contains('beverage');
    final dishNameCheck =
        _formController.dishName.toLowerCase().contains('drink') ||
            _formController.dishName.toLowerCase().contains('beverage');
    final currentIsDrink = categoryCheck || dishNameCheck;

    // Only log when the value changes to avoid spam
    if (currentIsDrink != _cachedIsDrinkCategory) {
      debugPrint('🔍 _isDrinkCategory changed: $currentIsDrink');
      debugPrint(
          '   Category: "${_formController.category}" -> $categoryCheck');
      debugPrint(
          '   DishName: "${_formController.dishName}" -> $dishNameCheck');
      _cachedIsDrinkCategory = currentIsDrink;
      _updateCachedSections();
    }
    return currentIsDrink;
  }

  // Update cached sections when category changes
  void _updateCachedSections() {
    _cachedFormSections = List.from(_formSections);
    _cachedTotalSteps = _cachedFormSections.length;
  }

  // Get current step count (cached) - kept for potential future use
  int get _totalSteps => _cachedTotalSteps;

  // ========== Helper Methods for Reusable Widgets ==========

  /// Builds a standard action button
  Widget _buildActionButton({
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
        style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor ?? _primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
      ),
    );
  }

  /// Builds a price display text
  Widget _buildPriceText(double price, {Color? color}) {
    return Text(
      '+${price.toStringAsFixed(0)} DA',
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.bold,
        color: color ?? _primaryColor,
      ),
    );
  }

  // ========== Variant & Pricing Helper Methods ==========

  // ========== Dialog Helper Methods ==========

  /// Builds a simple dialog input field
  Widget _buildDialogTextField({
    required String label,
    required String hint,
    required ValueChanged<String> onChanged,
    TextInputType? keyboardType,
  }) {
    return TextFormField(
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(25)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(25),
          borderSide: const BorderSide(color: _primaryColor, width: 2),
        ),
        filled: true,
        fillColor: Colors.grey[50],
      ),
      keyboardType: keyboardType,
      onChanged: onChanged,
    );
  }

  /// Builds variant selection checkboxes for supplements
  Widget _buildVariantSelection({
    required List<String> selectedVariants,
    required StateSetter setState,
  }) {
    if (_formController.variants.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          '${AppLocalizations.of(context)!.availableForVariants}:',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context)!.selectVariantsForSupplement,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500]),
        ),
        const SizedBox(height: 8),
        ..._formController.variants.map((variant) {
          final isSelected = selectedVariants.contains(variant.id);
          return CheckboxListTile(
            title: Text(variant.name, style: GoogleFonts.poppins(fontSize: 14)),
            subtitle: variant.description != null
                ? Text(
                    variant.description!,
                    style: GoogleFonts.poppins(
                        fontSize: 12, color: Colors.grey[600]),
                  )
                : null,
            value: isSelected,
            onChanged: (bool? value) {
              setState(() {
                if (value == true) {
                  selectedVariants.add(variant.id);
                } else {
                  selectedVariants.remove(variant.id);
                }
              });
            },
            contentPadding: EdgeInsets.zero,
            dense: true,
          );
        }),
      ],
    );
  }

  // Cached smart drink image detector for performance
  (String result, bool imageFound) _getCachedDrinkDetection(String drinkName,
      [String? flavor]) {
    // Clear cache if drink name changed significantly (more than just case changes)
    if (drinkName.toLowerCase() != _cachedDrinkName.toLowerCase()) {
      _cachedDrinkName = drinkName;
      _cachedDrinkDetectionResult =
          DrinkImageDetector.detectDrinkImage(drinkName, flavor);
      _cachedImageFound =
          !_cachedDrinkDetectionResult.startsWith('DRINK_NAME:');
    }
    return (_cachedDrinkDetectionResult, _cachedImageFound);
  }

  @override
  void initState() {
    super.initState();
    _formController = MenuItemFormController();
    _menuItemImageService = MenuItemImageService();
    _menuItemService = MenuItemService();
    _cuisineService = CuisineService();
    _categoryService = CategoryService();
    _restaurantSupplementService = RestaurantSupplementService();

    // Initialize cached values
    _updateCachedSections();

    // Listen to form controller changes for category updates
    _formController.addListener(_onFormControllerChanged);

    // Ensure bucket exists
    _menuItemImageService.ensureBucketExists();

    // Load initial data (categories first, then cuisines)
    _loadInitialData();

    // If in edit mode, pre-populate form fields
    if (_isEditMode) {
      _populateFormForEdit();
    }
  }

  /// Pre-populate form fields when in edit mode
  void _populateFormForEdit() {
    if (widget.menuItem == null) return;

    final item = widget.menuItem!;
    debugPrint('📝 Populating form for edit mode: ${item.name}');

    // Set cuisine and category IDs
    _selectedCuisineTypeId = item.cuisineTypeId;
    _selectedCategoryId = item.categoryId;

    // Populate basic fields using setters
    _formController.setDishName(item.category); // The dish name
    _formController.setDescription(item.description);
    _formController.setMainIngredients(item.mainIngredients ?? '');
    _formController.setPreparationTime(item.preparationTime.toString());
    _formController.setAvailable(value: item.isAvailable);
    _formController.setFeatured(value: item.isFeatured);

    // Populate dietary options
    _formController.setSpicy(value: item.isSpicy);
    _formController.setTraditional(value: item.isTraditional);
    _formController.setVegetarian(value: item.isVegetarian);
    _formController.setGlutenFree(value: item.isGlutenFree);

    // Populate ingredients
    _formController.clearIngredients();
    if (item.ingredients.isNotEmpty) {
      item.ingredients.forEach(_formController.addIngredient);
    }

    // Populate variants
    _formController.clearVariants();
    if (item.variants.isNotEmpty) {
      final variantsList = (item.variants as List<dynamic>)
          .map((v) => MenuItemVariant.fromJson(v as Map<String, dynamic>))
          .toList();
      variantsList.forEach(_formController.variants.add);
    }

    // Populate pricing options
    _formController.clearPricingOptions();
    if (item.pricingOptions.isNotEmpty) {
      final pricingList = (item.pricingOptions as List<dynamic>)
          .map((p) => MenuItemPricing.fromJson(p as Map<String, dynamic>))
          .toList();
      pricingList.forEach(_formController.pricingOptions.add);
    }

    // Populate supplements
    _formController.clearSupplements();
    if (item.supplements.isNotEmpty) {
      final supplementsList = (item.supplements as List<dynamic>)
          .map((s) => MenuItemSupplement.fromJson(s as Map<String, dynamic>))
          .toList();
      supplementsList.forEach(_formController.supplements.add);
    }

    // Populate existing image URL (for edit mode)
    if (item.image.isNotEmpty) {
      debugPrint('📸 Loading existing image URL: ${item.image}');
      _formController.addExistingImageUrl(item.image);
    }

    // Populate global pack ingredients and supplements (for special packs)
    if (_formController.isSpecialPack) {
      // Load global pack ingredients
      _formController.clearGlobalPackIngredients();
      final globalIngredients = SpecialPackHelper.getGlobalIngredients(item);
      if (globalIngredients.isNotEmpty) {
        globalIngredients.forEach(_formController.addGlobalPackIngredient);
        debugPrint(
            '🌿 Loaded ${globalIngredients.length} global pack ingredients');
      }

      // Load global pack supplements
      _formController.clearGlobalPackSupplements();
      final globalSupplements = SpecialPackHelper.getGlobalSupplements(item);
      if (globalSupplements.isNotEmpty) {
        globalSupplements.forEach((name, price) {
          _formController.addGlobalPackSupplement(name, price);
        });
        debugPrint(
            '💊 Loaded ${globalSupplements.length} global pack supplements');
      }
    }

    debugPrint('✅ Form populated successfully for edit mode');
  }

  // Handle form controller changes efficiently
  void _onFormControllerChanged() {
    // Check both the selected category name AND the dish name for drink/beverage keywords
    final currentIsDrink =
        _formController.category.toLowerCase().contains('drink') ||
            _formController.category.toLowerCase().contains('beverage') ||
            _formController.dishName.toLowerCase().contains('drink') ||
            _formController.dishName.toLowerCase().contains('beverage');

    // Only call setState if category actually changed to avoid unnecessary rebuilds
    if (currentIsDrink != _cachedIsDrinkCategory) {
      // Category changed, update cache and reset to first step
      _cachedIsDrinkCategory = currentIsDrink;
      _updateCachedSections();

      // Use WidgetsBinding to ensure setState happens after current build cycle
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentStep = 0;
            // Note: PageController removed as there's no PageView in the UI
          });
        }
      });
    }
  }

  // Load initial data - categories first, then cuisines, then restaurant ID
  Future<void> _loadInitialData() async {
    try {
      debugPrint('🚀 Starting initial data loading...');
      await _loadAllCategories();
      await _loadCuisineTypes();
      await _loadRestaurantId(); // Load restaurant ID for LTO drinks
      debugPrint('✅ Initial data loading completed');
    } catch (e) {
      debugPrint('❌ Error in initial data loading: $e');
      // Show error to user and provide retry option
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.failedToLoadMenuData,
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            action: SnackBarAction(
              label: AppLocalizations.of(context)!.retry,
              textColor: Colors.white,
              onPressed: () {
                _loadInitialData();
              },
            ),
          ),
        );
      }
    }
  }

  // Load current user's restaurant ID
  Future<void> _loadRestaurantId() async {
    try {
      // Use widget.restaurantId if provided, otherwise fetch from service
      if (widget.restaurantId != null) {
        debugPrint('✅ Using provided restaurant ID: ${widget.restaurantId}');
        if (mounted) {
          setState(() {
            _currentRestaurantId = widget.restaurantId;
          });
        }
        return;
      }

      debugPrint('🔄 Loading current user restaurant ID...');
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        debugPrint('⚠️ No authenticated user found');
        return;
      }

      final restaurantService =
          Provider.of<RestaurantService>(context, listen: false);
      final restaurant = await restaurantService.getRestaurantByOwnerId(userId);

      if (restaurant != null) {
        debugPrint('✅ Loaded restaurant ID: ${restaurant.id}');
        if (mounted) {
          setState(() {
            _currentRestaurantId = restaurant.id;
          });
        }
      } else {
        debugPrint('⚠️ No restaurant found for user');
      }
    } catch (e) {
      debugPrint('❌ Error loading restaurant ID: $e');
    }
  }

  // Load all categories first
  Future<void> _loadAllCategories() async {
    try {
      if (mounted) {
        setState(() => _isLoadingCategories = true);
      }
      debugPrint('🔄 Loading categories...');
      final categories = await _categoryService.getActiveCategories();
      debugPrint('✅ Loaded ${categories.length} categories');

      if (mounted) {
        setState(() {
          _allCategories = List<Category>.from(categories);
          _filteredCategories =
              List<Category>.from(categories); // Initially show all categories
          _isLoadingCategories = false;
        });

        // Pre-select initial category if provided
        if (widget.initialCategory != null &&
            widget.initialCategory!.isNotEmpty) {
          _selectInitialCategory(widget.initialCategory!);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCategories = false);
      }
      debugPrint('❌ Error loading categories: $e');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.failedToLoadMenuData}: $e',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  // Load cuisine types
  Future<void> _loadCuisineTypes() async {
    try {
      if (mounted) {
        setState(() => _isLoadingCuisines = true);
      }
      debugPrint('🔄 Loading cuisine types...');
      final cuisines = await _cuisineService.getActiveCuisineTypes();
      debugPrint('✅ Loaded ${cuisines.length} cuisine types');

      if (mounted) {
        setState(() {
          _cuisineTypes = cuisines;
          _isLoadingCuisines = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingCuisines = false);
      }
      debugPrint('❌ Error loading cuisine types: $e');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.failedToLoadMenuData}: $e',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  /// Select initial category if provided (e.g., "Drinks")
  Future<void> _selectInitialCategory(String categoryName) async {
    if (_allCategories.isEmpty) {
      debugPrint(
          '⚠️ Cannot select initial category: categories not loaded yet');
      return;
    }

    // Find category by name (case-insensitive, partial match)
    final categoryNameLower = categoryName.toLowerCase();
    final matchingCategory = _allCategories.firstWhere(
      (category) {
        final catNameLower = category.name.toLowerCase();
        return catNameLower.contains(categoryNameLower) ||
            categoryNameLower.contains(catNameLower) ||
            (categoryNameLower.contains('drink') &&
                (catNameLower.contains('drink') ||
                    catNameLower.contains('beverage') ||
                    catNameLower.contains('boissons')));
      },
      orElse: () => _allCategories.firstWhere(
        (category) => category.name.toLowerCase().contains('drink'),
        orElse: () => _allCategories.first,
      ),
    );

    debugPrint('🎯 Pre-selecting initial category: ${matchingCategory.name}');
    await _onCategoryChanged(matchingCategory.id);
  }

  // Handle category selection (primary selection - user chooses category first)
  Future<void> _onCategoryChanged(String? categoryId) async {
    debugPrint('🔍 _onCategoryChanged called with categoryId: $categoryId');
    debugPrint('🔍 Total categories loaded: ${_allCategories.length}');

    if (categoryId == 'custom') {
      await _showCustomCategoryDialog();
      return;
    }

    // Update form controller with selected category
    if (categoryId != null && _allCategories.isNotEmpty) {
      try {
        final selectedCategory = _allCategories.firstWhere(
          (category) => category.id == categoryId,
        );
        debugPrint('🔍 Selected category name: "${selectedCategory.name}"');
        _formController.setCategory(selectedCategory.name);
        debugPrint(
            '🔍 Category set in form controller: "${_formController.category}"');

        if (mounted) {
          setState(() {
            _selectedCategoryId = categoryId;
            _selectedCuisineTypeId = null; // Reset cuisine selection
            // Force cache update for drink category detection
            _cachedIsDrinkCategory = _isDrinkCategory;
          });
        }

        debugPrint('🔍 Is drink category after setState: $_isDrinkCategory');
        debugPrint('🔍 Cached is drink: $_cachedIsDrinkCategory');

        _autopopulateCuisineFromCategory(categoryId);
      } catch (e) {
        debugPrint('❌ Error finding category with id $categoryId: $e');
        // Still update the selected ID
        if (mounted) {
          setState(() {
            _selectedCategoryId = categoryId;
            _selectedCuisineTypeId = null;
          });
        }
      }
    } else if (categoryId == null) {
      _formController.setCategory('');
      if (mounted) {
        setState(() {
          _selectedCategoryId = categoryId;
          _selectedCuisineTypeId = null;
          _cachedIsDrinkCategory = false;
        });
      }
    } else {
      debugPrint('⚠️ Categories not loaded yet, retrying...');
      // Categories haven't loaded yet, wait and retry
      await Future.delayed(const Duration(milliseconds: 100));
      if (_allCategories.isNotEmpty && mounted) {
        await _onCategoryChanged(categoryId);
      }
    }
  }

  // Auto-populate cuisine type based on selected category
  void _autopopulateCuisineFromCategory(String categoryId) {
    final selectedCategory = _allCategories.firstWhere(
      (category) => category.id == categoryId,
      orElse: () => throw Exception('Category not found'),
    );

    // If category has a specific cuisine type, auto-select it
    if (selectedCategory.cuisineTypeId.isNotEmpty) {
      if (mounted) {
        setState(() {
          _selectedCuisineTypeId = selectedCategory.cuisineTypeId;
        });
      }
    } else {
      // Category has no specific cuisine - user can choose from all cuisines
      if (mounted) {
        setState(() {
          _selectedCuisineTypeId = null;
        });
      }
    }
  }

  // Handle cuisine type selection (secondary - only enabled after category is selected)
  Future<void> _onCuisineTypeChanged(String? cuisineTypeId) async {
    if (cuisineTypeId == 'custom_cuisine') {
      await _showCustomCuisineDialog();
      return;
    }

    if (mounted) {
      setState(() {
        _selectedCuisineTypeId = cuisineTypeId;
      });
    }
  }

  // Show custom category dialog
  Future<void> _showCustomCategoryDialog() async {
    final TextEditingController categoryController = TextEditingController();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            AppLocalizations.of(context)!.add,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          content: TextField(
            controller: categoryController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.category,
              hintText: AppLocalizations.of(context)!.enterRestaurantName,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide(color: Colors.orange[600]!, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                AppLocalizations.of(context)!.cancel,
                style: GoogleFonts.poppins(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final navigator = Navigator.of(context);
                if (categoryController.text.trim().isNotEmpty) {
                  _createCustomCategory(categoryController.text.trim())
                      .then((_) {
                    if (mounted) navigator.pop();
                  });
                } else {
                  navigator.pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                AppLocalizations.of(context)!.add,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Create custom category
  Future<void> _createCustomCategory(String categoryName) async {
    try {
      // Check if category already exists
      final existingCategory = _allCategories.firstWhere(
        (cat) => cat.name.toLowerCase() == categoryName.toLowerCase(),
        orElse: () => Category(
          id: '',
          cuisineTypeId: '',
          name: '',
          description: '',
          isActive: false,
          displayOrder: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      if (existingCategory.name.isNotEmpty) {
        _showErrorSnackBar(
            '${AppLocalizations.of(context)!.category} "$categoryName" ${AppLocalizations.of(context)!.alreadyExists}');
        return;
      }

      // For custom categories, we'll allow them to be created without a specific cuisine
      // The user can then choose a cuisine type if needed
      final newCategory = Category(
        id: '', // Will be set by database
        cuisineTypeId: _selectedCuisineTypeId ??
            '', // Allow null cuisine for custom categories
        name: categoryName,
        description: 'Custom category created by user',
        isActive: true,
        displayOrder: 999, // Put at end
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final createdCategory =
          await _categoryService.createCategory(newCategory);

      if (mounted) {
        setState(() {
          _allCategories.add(createdCategory);
          _filteredCategories.add(createdCategory);
          _selectedCategoryId = createdCategory.id;
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.category} "$categoryName" created successfully!',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.failedToLoadMenuData}: $e',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  // Show custom cuisine dialog
  Future<void> _showCustomCuisineDialog() async {
    final TextEditingController cuisineController = TextEditingController();

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            AppLocalizations.of(context)!.add,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          content: TextField(
            controller: cuisineController,
            decoration: InputDecoration(
              labelText: AppLocalizations.of(context)!.cuisine,
              hintText: 'Enter custom cuisine name',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(25),
                borderSide: BorderSide(color: Colors.orange[600]!, width: 2),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            style: GoogleFonts.poppins(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                AppLocalizations.of(context)!.cancel,
                style: GoogleFonts.poppins(
                  color: Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final navigator = Navigator.of(context);
                if (cuisineController.text.trim().isNotEmpty) {
                  _createCustomCuisine(cuisineController.text.trim()).then((_) {
                    if (mounted) navigator.pop();
                  });
                } else {
                  navigator.pop();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[600],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                AppLocalizations.of(context)!.add,
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // Create custom cuisine
  Future<void> _createCustomCuisine(String cuisineName) async {
    try {
      // Check if cuisine already exists
      final existingCuisine = _cuisineTypes.firstWhere(
        (cuisine) => cuisine.name.toLowerCase() == cuisineName.toLowerCase(),
        orElse: () => CuisineType(
          id: '',
          name: '',
          description: '',
          isActive: false,
          displayOrder: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );

      if (existingCuisine.name.isNotEmpty) {
        _showErrorSnackBar(
            '${AppLocalizations.of(context)!.cuisine} "$cuisineName" ${AppLocalizations.of(context)!.alreadyExists}');
        return;
      }

      final newCuisine = CuisineType(
        id: '', // Will be set by database
        name: cuisineName,
        description: 'Custom cuisine created by user',
        isActive: true,
        displayOrder: 999, // Put at end
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final createdCuisine =
          await _cuisineService.createCuisineType(newCuisine);

      if (mounted) {
        setState(() {
          _cuisineTypes.add(createdCuisine);
          _selectedCuisineTypeId = createdCuisine.id;
        });
      }

      // Refresh all categories to include any new ones
      await _loadAllCategories();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.cuisine} "$cuisineName" created successfully!',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            backgroundColor: Colors.green[600],
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${AppLocalizations.of(context)!.failedToLoadMenuData}: $e',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500),
            ),
            backgroundColor: Colors.red[600],
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _formController.removeListener(_onFormControllerChanged);
    _formController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Initialize form sections with proper localization
    _formSections = [AppLocalizations.of(context)!.addItem];

    // Get the safe area top padding
    final topPadding = MediaQuery.of(context).padding.top;
    // Reduce safe area for iOS (use 40% of the original safe area)
    final reducedTopPadding = Platform.isIOS ? topPadding * 0.9 : topPadding;

    return ChangeNotifierProvider.value(
      value: _formController,
      child: Scaffold(
        key: const ValueKey('add_menu_item_scaffold'),
        backgroundColor: Colors.grey[50],
        body: SafeArea(
          top: false, // Disable default safe area to use custom padding
          bottom:
              false, // Disable bottom safe area - handled by bottom nav container
          child: Column(
            children: [
              // Form Content (Scrollable including header)
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Top padding for iOS
                      SizedBox(height: reducedTopPadding),

                      // Orange & White Header (hide for supplements-only mode)
                      if (!widget.showOnlySupplements) _buildHeader(),
                      // Supplements-only header with back arrow
                      if (widget.showOnlySupplements)
                        _buildSupplementsOnlyHeader(),

                      // Form Content
                      Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Show only supplements section if requested
                            if (widget.showOnlySupplements) ...[
                              _buildSupplementsOnlySection(),
                            ] else if (_isDrinkCategory) ...[
                              // Drinks: Simple form with just category and variants
                              _buildDrinkVariantsPricingStep(),
                              const SizedBox(height: 16),
                            ] else ...[
                              // Food: Full form with images and review
                              _buildBasicInformationStep(),
                              const SizedBox(height: 16),
                              _buildImagesReviewStep(),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Navigation Buttons (hide for supplements-only mode)
              // Hide save button in supplements-only mode
              if (!widget.showOnlySupplements) _buildNavigationButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    // Extracted to CustomHeader widget
    return CustomHeader(
      onBackPressed: () => Navigator.of(context).pop(false),
      title: _isEditMode
          ? AppLocalizations.of(context)!.edit
          : AppLocalizations.of(context)!.addItem,
    );
  }

  void _showManageSupplementVariantsDialog(String supplementId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final supplement = _formController.supplements
                .firstWhere((s) => s.id == supplementId);
            return AlertDialog(
              title: Text(
                'Manage ${supplement.name} Variants',
                style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600,
                  color: Colors.black,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Existing variants
                    if (supplement.variants.isNotEmpty) ...[
                      Text(
                        'Current Variants:',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey[700],
                        ),
                      ),
                      const SizedBox(height: 8),
                      ...supplement.variants.map(
                        (variant) => Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.blue.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: Colors.blue.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      variant.name,
                                      style: GoogleFonts.poppins(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                    if (variant.description != null) ...[
                                      const SizedBox(height: 2),
                                      Text(
                                        variant.description!,
                                        style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.grey[600]),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              _buildPriceText(variant.price,
                                  color: Colors.blue[600]),
                              const SizedBox(width: 8),
                              IconButton(
                                onPressed: () {
                                  _formController.removeSupplementVariant(
                                      supplementId, variant.id);
                                  setState(() {});
                                },
                                icon: const Icon(Icons.close,
                                    size: 16, color: Colors.red),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],

                    // Add new variant button
                    _buildActionButton(
                      label: 'Add Variant',
                      onPressed: () =>
                          _showAddSupplementVariantDialog(supplementId),
                      backgroundColor: Colors.blue,
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Close',
                    style: GoogleFonts.poppins(color: Colors.grey),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddSupplementVariantDialog(String supplementId) {
    String name = '';
    String description = '';
    String price = '';

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Add Supplement Variant',
            style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600, color: Colors.black),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildDialogTextField(
                label:
                    '${AppLocalizations.of(context)!.variants} ${AppLocalizations.of(context)!.name} *',
                hint: 'Light, Heavy, Vegan, etc.',
                onChanged: (value) => name = value,
              ),
              const SizedBox(height: 12),
              _buildDialogTextField(
                label:
                    '${AppLocalizations.of(context)!.description} (${AppLocalizations.of(context)!.optional})',
                hint: 'Light cheese, heavy cheese, etc.',
                onChanged: (value) => description = value,
              ),
              const SizedBox(height: 12),
              _buildDialogTextField(
                label: '${AppLocalizations.of(context)!.price} (DA) *',
                hint: '30',
                onChanged: (value) => price = value,
                keyboardType: TextInputType.number,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel',
                  style: GoogleFonts.poppins(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                if (name.isNotEmpty && price.isNotEmpty) {
                  final priceValue = double.tryParse(price);
                  if (priceValue != null && priceValue > 0) {
                    _formController.addSupplementVariant(
                      supplementId,
                      name.trim(),
                      description.isNotEmpty ? description.trim() : null,
                      priceValue,
                      isDefault: false,
                    );
                    Navigator.of(context).pop();
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue, foregroundColor: Colors.white),
              child: Text('Add', style: GoogleFonts.poppins()),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showAddSupplementDialog() async {
    String name = '';
    String description = '';
    String price = '';
    final List<String> selectedVariants = [];
    bool isSaving = false;

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'Add Supplement',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, color: Colors.black),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDialogTextField(
                      label: 'Supplement Name *',
                      hint: 'Chidar, Extra Cheese, etc.',
                      onChanged: (value) => name = value,
                    ),
                    const SizedBox(height: 12),
                    _buildDialogTextField(
                      label: 'Description (Optional)',
                      hint: 'Fresh cheese, spicy sauce, etc.',
                      onChanged: (value) => description = value,
                    ),
                    const SizedBox(height: 12),
                    _buildDialogTextField(
                      label: 'Price (DA) *',
                      hint: '50',
                      onChanged: (value) => price = value,
                      keyboardType: TextInputType.number,
                    ),
                    _buildVariantSelection(
                      selectedVariants: selectedVariants,
                      setState: setState,
                    ),
                    if (isSaving) ...[
                      const SizedBox(height: 16),
                      const Center(child: CircularProgressIndicator()),
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed:
                      isSaving ? null : () => Navigator.of(context).pop(),
                  child: Text('Cancel',
                      style: GoogleFonts.poppins(color: Colors.grey)),
                ),
                ElevatedButton(
                  onPressed: isSaving
                      ? null
                      : () async {
                          if (name.isNotEmpty && price.isNotEmpty) {
                            final priceValue = double.tryParse(price);
                            if (priceValue != null && priceValue > 0) {
                              setState(() => isSaving = true);

                              try {
                                // Get restaurant ID
                                final restaurantId = _currentRestaurantId;
                                if (restaurantId == null ||
                                    restaurantId.isEmpty) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Restaurant ID not found. Please try again.'),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                  setState(() => isSaving = false);
                                  return;
                                }

                                // Create restaurant supplement (saves to menu_item_supplements with null menu_item_id
                                // and adds to restaurant_supplements)
                                // DO NOT add to form controller - it should stay as restaurant-level supplement
                                // until explicitly selected from suggestions
                                await _restaurantSupplementService
                                    .createRestaurantSupplement(
                                  restaurantId: restaurantId,
                                  name: name.trim(),
                                  price: priceValue,
                                  description: description.isNotEmpty
                                      ? description.trim()
                                      : null,
                                  isAvailable: true,
                                );

                                if (mounted) {
                                  Navigator.of(context).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                          'Supplement added successfully! It will appear in suggestions for future use.'),
                                      backgroundColor: Colors.green,
                                    ),
                                  );
                                }
                              } catch (e) {
                                debugPrint(
                                    '❌ Error creating restaurant supplement: $e');
                                if (mounted) {
                                  setState(() => isSaving = false);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Error: $e'),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            }
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Add', style: GoogleFonts.poppins()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Show dialog to select which drinks are included in the pack
  Future<Map<String, dynamic>?> _showDrinkSelectionDialog(
      List<String> initialSelection) async {
    try {
      // Get current user
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        debugPrint('❌ User not authenticated');
        return null;
      }

      // Get restaurant
      final restaurantService =
          Provider.of<RestaurantService>(context, listen: false);
      final restaurant =
          await restaurantService.getRestaurantByOwnerId(currentUser.id);

      if (restaurant == null) {
        debugPrint('❌ No restaurant found');
        return null;
      }

      // Fetch available drinks from menu
      final drinksResponse = await Supabase.instance.client
          .from('menu_items')
          .select('id, name, image, price')
          .eq('restaurant_id', restaurant.id)
          .eq('is_available', true)
          .or('category.ilike.%drink%,category.ilike.%beverage%')
          .order('name');

      final drinks =
          (drinksResponse as List).map((d) => MenuItem.fromJson(d)).toList();

      if (drinks.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No drinks found in your menu. Add drinks first.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return null;
      }

      // Show selection dialog with quantity
      if (!mounted) return null;
      return await showDialog<Map<String, dynamic>>(
        context: context,
        builder: (BuildContext context) {
          return _FreeDrinksSelectionDialog(
            drinks: drinks,
            initialSelection: initialSelection,
            initialQuantity: _formController.freeDrinksQuantity,
            primaryColor: _primaryColor,
          );
        },
      );
    } catch (e) {
      debugPrint('❌ Error showing drink selection dialog: $e');
      return null;
    }
  }

  /// Show dialog to select free drinks for special packs
  Future<void> _showSelectFreeDrinksDialog() async {
    final result =
        await _showDrinkSelectionDialog(_formController.freeDrinkIds);
    if (result != null) {
      final drinkIds = result['drinkIds'] as List<String>;
      final quantity = result['quantity'] as int;
      _formController.setFreeDrinks(drinkIds, quantity: quantity);
    }
  }

  /// Show dialog to edit pack item name and quantity
  Future<void> _showEditPackItemDialog(
      MenuItemVariant variant, int currentQuantity) async {
    // Create controllers
    final nameController = TextEditingController(text: variant.name);
    final quantityController =
        TextEditingController(text: currentQuantity.toString());

    await showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: Text(
            'Edit Pack Item',
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Item name field
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Item Name *',
                  hintText: 'e.g., Burger, Fries',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: _primaryColor,
                      width: 2,
                    ),
                  ),
                ),
                style: GoogleFonts.poppins(),
              ),
              const SizedBox(height: 16),
              // Quantity field
              TextField(
                controller: quantityController,
                decoration: InputDecoration(
                  labelText: 'Quantity *',
                  hintText: '1',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: _primaryColor,
                      width: 2,
                    ),
                  ),
                ),
                keyboardType: TextInputType.number,
                style: GoogleFonts.poppins(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final newName = nameController.text.trim();
                final newQuantity =
                    int.tryParse(quantityController.text.trim()) ?? 1;

                if (newName.isNotEmpty && newQuantity > 0) {
                  // Close dialog first, then update (prevents GlobalKey conflicts)
                  Navigator.of(dialogContext).pop();

                  // Update variant after dialog is closed
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    _formController.updateVariant(
                      variant.id,
                      name: newName,
                      description: 'qty:$newQuantity',
                    );
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Update',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
          ],
        );
      },
    ).then((_) {
      // Dispose controllers after dialog is fully closed
      nameController.dispose();
      quantityController.dispose();
    });
  }

  void _showAddPricingDialog([List<String>? variantIds]) {
    // Handle backward compatibility: if a single string is passed, convert to list
    final List<String> variants;
    if (variantIds == null) {
      variants = _formController.variants.map((v) => v.id).toList();
    } else {
      variants = variantIds;
    }

    String size = '';
    String price = '';
    bool isDefault = false;

    // Check if Limited Time Offer is active
    final isLTO = _formController.isLimitedOffer;

    // Drink-specific size options
    final drinkSizes = [
      '0.33L',
      '0.5L',
      '1L',
      '1.5L',
      '2L',
      '2.5L',
      '3L',
      'Custom'
    ];

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isDrinkCategory
                        ? 'Add Drink Size & Price'
                        : 'Add Pricing Option',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  if (variants.length > 1) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Applying to ${variants.length} variant${variants.length > 1 ? 's' : ''}',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Show LTO notice if Limited Time Offer is active
                  if (isLTO) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline,
                              color: Colors.orange.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'LTO Mode: Price is optional and adds to base price',
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.orange.shade900,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (_isDrinkCategory) ...[
                    // Drink-specific size dropdown (optional)
                    PillDropdown<String>(
                      label: 'Bottle Size (optional)',
                      value: size.isNotEmpty ? size : null,
                      hint: 'Select size',
                      items: drinkSizes.map((drinkSize) {
                        return DropdownMenuItem(
                          value: drinkSize,
                          child: Text(drinkSize),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => size = value ?? '');
                      },
                    ),
                    const SizedBox(height: 12),
                    if (size == 'Custom')
                      _buildDialogTextField(
                        label: 'Custom Size',
                        hint: 'e.g., 0.25L, 500ml',
                        onChanged: (value) => size = value,
                      ),
                  ] else ...[
                    _buildDialogTextField(
                      label: 'Size (optional)',
                      hint: 'Small, Medium, Large, etc.',
                      onChanged: (value) => size = value,
                    ),
                  ],
                  const SizedBox(height: 12),
                  _buildDialogTextField(
                    label:
                        isLTO ? 'Extra Charge (DA) - Optional' : 'Price (DA) *',
                    hint: isLTO ? '50 (adds to base price)' : '1200',
                    onChanged: (value) => price = value,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Checkbox(
                        value: isDefault,
                        onChanged: (value) =>
                            setState(() => isDefault = value ?? false),
                        activeColor: _primaryColor,
                      ),
                      Text(
                        'Set as default pricing',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    AppLocalizations.of(context)!.cancel,
                    style: GoogleFonts.poppins(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    // For LTO: price is optional (defaults to 0)
                    // For normal: price is required
                    if (isLTO || price.isNotEmpty) {
                      final priceValue =
                          price.isNotEmpty ? double.tryParse(price) : 0.0;
                      if (priceValue != null && priceValue >= 0) {
                        // Apply pricing to all selected variants
                        for (final vId in variants) {
                          _formController.addPricingOption(
                            size.trim(),
                            '',
                            priceValue,
                            isDefault: isDefault && vId == variants.first,
                            variantId: vId,
                            freeDrinksIncluded: false,
                            freeDrinksList: const [],
                          );
                        }
                        Navigator.of(context).pop();
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Add', style: GoogleFonts.poppins()),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDrinkVariantsPricingStep() {
    return DrinkVariantsPricingStep(
      onAddPricing: (variantId) => _showAddPricingDialog([variantId]),
      filteredCategories: _filteredCategories,
      selectedCategoryId: _selectedCategoryId,
      isLoadingCategories: _isLoadingCategories,
      onCategoryChanged: _onCategoryChanged,
    );
  }

  Widget _buildBasicInformationStep() {
    return BasicInformationStep(
      cuisineTypes: _cuisineTypes,
      filteredCategories: _filteredCategories,
      selectedCuisineTypeId: _selectedCuisineTypeId,
      selectedCategoryId: _selectedCategoryId,
      isLoadingCuisines: _isLoadingCuisines,
      isLoadingCategories: _isLoadingCategories,
      onCuisineChanged: _onCuisineTypeChanged,
      onCategoryChanged: _onCategoryChanged,
      onAddPricing: (variantIds) {
        // Handle both String (single variant) and List<String> (multiple variants)
        if (variantIds is List<String>) {
          _showAddPricingDialog(variantIds);
        } else {
          // String or other - convert to list
          _showAddPricingDialog([variantIds.toString()]);
        }
      },
      onEditPackItem: (variant, quantity) =>
          _showEditPackItemDialog(variant, quantity),
      onManageSupplementVariants: _showManageSupplementVariantsDialog,
      onAddSupplement: _showAddSupplementDialog,
      onSelectFreeDrinks: _showSelectFreeDrinksDialog,
      restaurantId:
          _currentRestaurantId, // Use loaded restaurant ID for LTO drinks
    );
  }

  Widget _buildImagesReviewStep() {
    return ImagesReviewStep(
      onPickImage: _pickImage,
      cuisineTypes: _cuisineTypes,
      allCategories: _allCategories,
      selectedCuisineTypeId: _selectedCuisineTypeId,
      selectedCategoryId: _selectedCategoryId,
    );
  }

  /// Build supplements-only header with back arrow and title
  Widget _buildSupplementsOnlyHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: Row(
        children: [
          // Back arrow
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 8),
          // Title
          Text(
            'Supplements',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  /// Build supplements-only section (simplified view for adding supplements)
  Widget _buildSupplementsOnlySection() {
    return BasicInformationStep(
      cuisineTypes: _cuisineTypes,
      filteredCategories: _filteredCategories,
      selectedCuisineTypeId: _selectedCuisineTypeId,
      selectedCategoryId: _selectedCategoryId,
      isLoadingCuisines: _isLoadingCuisines,
      isLoadingCategories: _isLoadingCategories,
      onCuisineChanged: _onCuisineTypeChanged,
      onCategoryChanged: _onCategoryChanged,
      onAddPricing: (variantIds) {
        // Not needed for supplements-only mode
      },
      onEditPackItem: (variant, quantity) {
        // Not needed for supplements-only mode
      },
      onManageSupplementVariants: _showManageSupplementVariantsDialog,
      onAddSupplement: _showAddSupplementDialog,
      onSelectFreeDrinks: _showSelectFreeDrinksDialog,
      restaurantId: _currentRestaurantId,
      showOnlySupplements: true,
    );
  }

  /// Build simple save button for supplements-only mode
  Widget _buildSupplementsOnlySaveButton() {
    return Consumer<MenuItemFormController>(
      builder: (context, formController, child) {
        final bottomPadding = BottomPaddingHelper.getBottomPadding(context);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: bottomPadding + 20,
          ),
          child: SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: formController.supplements.isEmpty
                    ? null
                    : () async {
                        // For supplements-only mode, we need to create a minimal menu item
                        // with the supplements attached. The supplements will be saved
                        // when the user creates the menu item.
                        // Set minimal required fields for supplements-only mode
                        if (_formController.dishName.isEmpty) {
                          // Use first supplement name or default name
                          final supplementName =
                              formController.supplements.isNotEmpty
                                  ? formController.supplements.first.name
                                  : 'Supplement';
                          _formController.setDishName(supplementName);
                        }
                        if (_formController.preparationTime.isEmpty) {
                          _formController.setPreparationTime('1');
                        }
                        // Ensure category is set to Supplements
                        if (_selectedCategoryId == null &&
                            _allCategories.isNotEmpty) {
                          // Find supplements category
                          final suppCategory = _allCategories.firstWhere(
                            (cat) =>
                                cat.name.toLowerCase().contains('supplement'),
                            orElse: () => _allCategories.first,
                          );
                          await _onCategoryChanged(suppCategory.id);
                        }
                        // Ensure at least one pricing option exists (required for form validation)
                        if (_formController.pricingOptions.isEmpty) {
                          // Create a default pricing option with price 0
                          _formController.addPricingOption(
                            'Default',
                            '',
                            0.0,
                            isDefault: true,
                            variantId: null,
                            freeDrinksIncluded: false,
                            freeDrinksList: const [],
                          );
                        }
                        // For supplements-only mode, we need to handle image requirement
                        // The form validation requires at least one image, but for supplements
                        // we can use a placeholder. We'll add a default placeholder image URL
                        if (_formController.selectedImages.isEmpty &&
                            _formController.existingImageUrls.isEmpty) {
                          // Add a placeholder image URL to bypass validation
                          // Use a placeholder URL that will be replaced with actual image later
                          _formController.addExistingImageUrl(
                              'https://via.placeholder.com/150');
                        }
                        // Submit the form to save the menu item and supplements
                        await _submitForm();
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFd47b00),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  'Save Supplements',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavigationButtons() {
    return Consumer<MenuItemFormController>(
      builder: (context, formController, child) {
        // Get bottom padding based on device type
        final bottomPadding = BottomPaddingHelper.getBottomPadding(context);

        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(30),
              topRight: Radius.circular(30),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 15,
                offset: const Offset(0, -3),
              ),
            ],
          ),
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomPadding),
          child: SizedBox(
            width: double.infinity,
            child: Row(
              children: [
                if (_currentStep > 0)
                  Expanded(
                    child: _buildButton(
                      AppLocalizations.of(context)!.previous,
                      Colors.grey[600]!,
                      () {
                        setState(() {
                          if (_currentStep > 0) {
                            _currentStep--;
                          }
                        });
                      },
                    ),
                  ),
                if (_currentStep > 0) const SizedBox(width: 12),
                Expanded(
                  child: _buildButton(
                    _currentStep == _totalSteps - 1
                        ? (_isEditMode
                            ? AppLocalizations.of(context)!.update
                            : AppLocalizations.of(context)!.submit)
                        : AppLocalizations.of(context)!.next,
                    _currentStep == _totalSteps - 1
                        ? (formController.isFormValid
                            ? const Color(0xFFd47b00)
                            : Colors.grey[400]!)
                        : const Color(0xFFd47b00),
                    _currentStep == _totalSteps - 1
                        ? (formController.isFormValid
                            ? () {
                                debugPrint('🔥 Submit button pressed!');
                                debugPrint(
                                    '📊 Form is valid: ${formController.isFormValid}');
                                _submitForm();
                              }
                            : () {
                                debugPrint(
                                    '❌ Submit button pressed but form is not valid');
                                debugPrint(
                                    '📊 Form is valid: ${formController.isFormValid}');
                                debugPrint('📊 Current step: $_currentStep');
                                debugPrint('📊 Total steps: $_totalSteps');

                                // Debug validation details
                                debugPrint('\n🔍 Validation Details:');
                                debugPrint(
                                    '  Dish Name: ${formController.dishName.isEmpty ? "❌ EMPTY" : "✅ ${formController.dishName}"}');
                                debugPrint(
                                    '  Category: ${formController.category.isEmpty ? "❌ EMPTY" : "✅ ${formController.category}"}');
                                debugPrint(
                                    '  Description: ${formController.description.isEmpty ? "❌ EMPTY" : "✅ ${formController.description.length} chars"}');
                                debugPrint(
                                    '  Main Ingredients: ${formController.mainIngredients.isEmpty ? "❌ EMPTY" : "✅ ${formController.mainIngredients.length} chars"}');
                                debugPrint(
                                    '  Prep Time: ${formController.preparationTime.isEmpty ? "❌ EMPTY" : "✅ ${formController.preparationTime} min"}');
                                debugPrint(
                                    '  Images: ${formController.selectedImages.isEmpty ? "❌ NONE" : "✅ ${formController.selectedImages.length} images"}');
                                debugPrint(
                                    '  Variants: ${formController.variants.isEmpty ? "❌ NONE" : "✅ ${formController.variants.length} variants"}');
                                debugPrint(
                                    '  Pricing Options: ${formController.pricingOptions.isEmpty ? "❌ NONE" : "✅ ${formController.pricingOptions.length} options"}');
                                debugPrint('\n💡 Required for non-drinks:');
                                debugPrint('  - Dish name (not empty)');
                                debugPrint('  - Preparation Time (1-300 min)');
                                debugPrint('  - At least 1 image');
                                debugPrint(
                                    '  - At least 1 pricing option (variant + price)');
                              })
                        : () {
                            debugPrint(
                                '➡️ Next button pressed, moving to next step');
                            setState(() {
                              if (_currentStep < _totalSteps - 1) {
                                _currentStep++;
                              }
                            });
                          },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildButton(String text, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(25),
        ),
        elevation: 2,
      ),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  // Image picker method
  Future<void> _pickImage(ImageSource source) async {
    try {
      // Request permissions first
      Permission permission;
      if (source == ImageSource.camera) {
        permission = Permission.camera;
        debugPrint('📸 Requesting camera permission');
      } else {
        // For Android 13+ (API 33+), use photos permission, otherwise use storage
        if (Platform.isAndroid) {
          permission = Permission.photos;
        } else {
          permission = Permission.photos;
        }
        debugPrint('🖼️ Requesting gallery permission');
      }

      // Check and request permission
      PermissionStatus status = await permission.status;
      if (status.isDenied) {
        status = await permission.request();
      }

      if (status.isPermanentlyDenied) {
        // Show dialog to open app settings
        _showPermissionDialog(permission);
        return;
      }

      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  'Permission denied. Please allow access to ${source == ImageSource.camera ? 'camera' : 'photos'} to add images.'),
              backgroundColor: Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      debugPrint(
          '✅ Permission granted, opening ${source == ImageSource.camera ? 'camera' : 'gallery'}');

      final ImagePicker picker = ImagePicker();

      if (source == ImageSource.gallery) {
        // Use pickMultiImage for gallery to allow multiple selection
        final List<XFile> images = await picker.pickMultiImage(
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );

        if (images.isNotEmpty) {
          debugPrint('✅ ${images.length} image(s) selected');
          int successCount = 0;

          for (final image in images) {
            final File imageFile = File(image.path);

            // Check if file exists and is readable - using existsSync for better performance
            if (imageFile.existsSync()) {
              final fileSize = imageFile.lengthSync();
              debugPrint('📁 Image file size: ${fileSize / (1024 * 1024)} MB');

              _formController.addImage(imageFile);
              successCount++;
            }
          }

          if (mounted && successCount > 0) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                    '$successCount image${successCount > 1 ? 's' : ''} added successfully!'),
                backgroundColor: Colors.green,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          debugPrint('❌ No images selected');
        }
      } else {
        // Use pickImage for camera (single image)
        final XFile? image = await picker.pickImage(
          source: source,
          maxWidth: 1920,
          maxHeight: 1080,
          imageQuality: 85,
        );

        if (image != null) {
          debugPrint('✅ Image selected: ${image.path}');
          final File imageFile = File(image.path);

          // Check if file exists and is readable - using existsSync for better performance
          if (imageFile.existsSync()) {
            final fileSize = imageFile.lengthSync();
            debugPrint('📁 Image file size: ${fileSize / (1024 * 1024)} MB');

            _formController.addImage(imageFile);

            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Image added successfully!'),
                  backgroundColor: Colors.green,
                  duration: Duration(seconds: 2),
                ),
              );
            }
          } else {
            throw Exception('Selected image file does not exist');
          }
        } else {
          debugPrint('❌ No image selected');
        }
      }
    } catch (e) {
      debugPrint('❌ Error picking image: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Show permission dialog
  void _showPermissionDialog(Permission permission) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Permission Required'),
          content: Text(
            'This app needs access to ${permission == Permission.camera ? 'camera' : 'photos'} to add images. Please enable it in app settings.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                openAppSettings();
              },
              child: const Text('Open Settings'),
            ),
          ],
        );
      },
    );
  }

  // Form submission
  Future<void> _submitForm() async {
    debugPrint('🚀 Starting form submission...');

    try {
      debugPrint('🔍 Checking form key state...');
      if (_formKey.currentState == null) {
        debugPrint('❌ Form key state is null');
        _showErrorSnackBar('Form not properly initialized');
        return;
      }

      debugPrint('🔍 Running form validation...');
      final isValid = _formKey.currentState!.validate();
      debugPrint('📊 Form validation result: $isValid');

      if (!isValid) {
        debugPrint('❌ Form validation failed');
        return;
      }

      // Validate Limited Time Offer if enabled
      final ltoError = _formController.validateLimitedOffer();
      if (ltoError != null) {
        debugPrint('❌ LTO validation failed: $ltoError');
        _showErrorSnackBar(ltoError);
        return;
      }

      debugPrint('✅ Form validation passed');
    } catch (e) {
      debugPrint('❌ Error during form validation: $e');
      _showErrorSnackBar('Form validation error: $e');
      return;
    }
    _formController.setSubmittingState(isSubmitting: true);

    try {
      // Check if user is authenticated
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        debugPrint('❌ User not authenticated');
        _showErrorSnackBar('Please sign in to add a menu item');
        return;
      }

      final userId = currentUser.id;
      debugPrint('✅ User authenticated: $userId');

      // Show loading dialog (non-blocking)
      // ignore: unawaited_futures
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 20),
                Text(
                  _isEditMode
                      ? 'Updating menu item...'
                      : 'Adding menu item to database...',
                  style: GoogleFonts.poppins(fontSize: 16),
                ),
              ],
            ),
          );
        },
      );

      // Prepare enhanced menu item data
      final formData = _formController.getFormData();

      // Get user's restaurant information
      debugPrint('🔍 Getting user restaurant information...');
      final restaurantService =
          Provider.of<RestaurantService>(context, listen: false);
      final restaurant = await restaurantService.getRestaurantByOwnerId(userId);

      if (restaurant == null) {
        debugPrint('❌ No restaurant found for user');
        _formController.setSubmittingState(isSubmitting: false);
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'No restaurant found. Please visit the dashboard first.'),
              backgroundColor: Colors.red,
            ),
          );
          Navigator.of(context).pop(); // Return to previous screen
        }
        return;
      }

      final restaurantId = restaurant.id;
      final restaurantName = restaurant.name;

      // Check if this is a drink (bulk creation)
      final isDrink = _isDrinkCategory;

      if (isDrink && _formController.variants.isNotEmpty) {
        debugPrint('🥤 Drink category detected - using BULK creation logic');
        debugPrint(
            '🥤 Creating ${_formController.variants.length} drink items...');

        // For drinks: Create one menu item per variant
        final createdDrinkIds = <String>[];

        for (final variant in _formController.variants) {
          debugPrint('🥤 Creating drink: ${variant.name}');

          // Get pricing options for this specific variant
          final variantPricing = _formController.pricingOptions
              .where((p) => p.variantId == variant.id)
              .toList();

          // Create a menu item for this drink
          final drinkMenuItem = MenuItem(
            id: '', // Will be set by database
            restaurantId: restaurantId,
            restaurantName: restaurantName,
            name: variant.name, // Use variant name as the drink name
            description: variant.description ?? '',
            image: '', // Will be set by smart detection
            price: variantPricing.isNotEmpty ? variantPricing.first.price : 0.0,
            category: formData['category'] ?? 'Drinks',
            cuisineTypeId: null, // No cuisine for drinks
            categoryId: _selectedCategoryId,
            isAvailable: true,
            isFeatured: false,
            preparationTime: 1, // Drinks are instant
            rating: 0.0,
            reviewCount: 0,
            mainIngredients: null,
            ingredients: [],
            isSpicy: false,
            spiceLevel: 0,
            isTraditional: false,
            isVegetarian: false,
            isVegan: false,
            isGlutenFree: false,
            isDairyFree: false,
            isLowSodium: false,
            variants: [], // No sub-variants for drinks
            pricingOptions: variantPricing.map((p) => p.toJson()).toList(),
            supplements: [],
            // Free drinks not applicable to drinks, stored in menu_item_pricing for packs
            calories: null,
            protein: null,
            carbs: null,
            fat: null,
            fiber: null,
            sugar: null,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );

          // Create the drink item in database
          final createdDrink =
              await _menuItemService.createMenuItem(drinkMenuItem, []);
          createdDrinkIds.add(createdDrink.id);
          debugPrint(
              '✅ Created drink: ${variant.name} with ID: ${createdDrink.id}');

          // Save pricing for this drink
          if (variantPricing.isNotEmpty) {
            await _saveEnhancedMenuItemDataOptimized(
              createdDrink.id,
              EnhancedMenuItem(
                id: createdDrink.id,
                restaurantId: restaurantId,
                restaurantName: restaurantName,
                name: variant.name,
                description: variant.description,
                mainIngredients: null,
                image: '',
                category: formData['category'] ?? 'Drinks',
                isAvailable: true,
                isFeatured: false,
                preparationTime: 1,
                rating: 0.0,
                reviewCount: 0,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
                variants: [],
                pricing: variantPricing,
                supplements: [],
                ingredients: [],
                allergens: [],
                isSpicy: false,
                spiceLevel: 0,
                isTraditional: false,
                isVegetarian: false,
                isVegan: false,
                isGlutenFree: false,
              ),
            );
          }

          // Handle smart drink image detection for this drink
          _handleDrinkImageDetection(createdDrink, variant.name);
        }

        debugPrint(
            '🎉 All ${createdDrinkIds.length} drinks created successfully!');

        // Close loading dialog
        if (mounted) Navigator.of(context).pop();

        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text('${createdDrinkIds.length} drinks added successfully!'),
              backgroundColor: Colors.green,
            ),
          );
        }

        // Reset form and navigate back
        if (!_isEditMode) {
          _formController.resetForm();
        }
        if (mounted) Navigator.of(context).pop(true);
        return;
      }

      // For non-drinks: Standard single item creation
      debugPrint('📝 Creating standard menu item from form data...');

      // Get image from existing URLs or placeholder for supplements-only mode
      String imageUrl = '';
      if (_formController.existingImageUrls.isNotEmpty) {
        imageUrl = _formController.existingImageUrls.first;
      } else if (widget.showOnlySupplements) {
        // For supplements-only mode, use placeholder if no image
        imageUrl = 'https://via.placeholder.com/150';
      }

      // Check if we're trying to create a menu item with only supplements (no actual menu item data)
      // This shouldn't happen - supplements should be restaurant-level only
      final menuItemName = formData['name'] ?? '';
      if (menuItemName.isEmpty || menuItemName.trim().isEmpty) {
        debugPrint('⚠️ Cannot create menu item with empty name');
        _formController.setSubmittingState(isSubmitting: false);
        if (mounted) {
          Navigator.of(context).pop(); // Close loading dialog
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                  'Please enter a menu item name. Supplements can be added separately.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final enhancedMenuItem = EnhancedMenuItem(
        id: '', // Will be set by database
        restaurantId: restaurantId,
        restaurantName: restaurantName,
        name: menuItemName.trim(),
        description: formData['description'],
        mainIngredients: formData['main_ingredients'],
        image: imageUrl,
        category: formData['category'] ?? '',
        isAvailable: formData['is_available'] ?? true,
        isFeatured: formData['is_featured'] ?? false,
        preparationTime: formData['preparation_time'] ?? 15,
        rating: 0.0,
        reviewCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        variants: (formData['variants'] as List<dynamic>?)
                ?.map(
                    (v) => MenuItemVariant.fromJson(v as Map<String, dynamic>))
                .toList() ??
            [],
        pricing: (formData['pricing_options'] as List<dynamic>?)
                ?.map(
                    (p) => MenuItemPricing.fromJson(p as Map<String, dynamic>))
                .toList() ??
            [],
        supplements: (formData['supplements'] as List<dynamic>?)
                ?.map((s) =>
                    MenuItemSupplement.fromJson(s as Map<String, dynamic>))
                .toList() ??
            [],
        ingredients: (formData['ingredients'] as List<dynamic>?)
                ?.map((i) => i.toString())
                .toList() ??
            [],
        allergens: [], // Removed from form
        isSpicy: formData['is_spicy'] ?? false,
        spiceLevel: 0,
        isTraditional: formData['is_traditional'] ?? false,
        isVegetarian: formData['is_vegetarian'] ?? false,
        isVegan: false,
        isGlutenFree: formData['is_gluten_free'] ?? false,
      );
      debugPrint('✅ EnhancedMenuItem created');

      // Get default pricing from enhanced menu item
      // Priority:
      // 1. Special packs: use pack price
      // 2. LTO with special_price: use pack price (base/discounted price)
      // 3. Regular items: use default variant pricing
      final isSpecialPack = _formController.isSpecialPack;
      final isLTOWithSpecialPrice = _formController.isLimitedOffer &&
          _formController.offerTypes.contains('special_price');
      final double finalPrice;

      // Debug free drinks
      debugPrint('🥤 Free Drinks Debug:');
      debugPrint('   Category: ${_formController.category}');
      debugPrint('   isSpecialPack: $isSpecialPack');
      debugPrint('   isLTOWithSpecialPrice: $isLTOWithSpecialPrice');
      debugPrint('   freeDrinkIds: ${_formController.freeDrinkIds}');
      debugPrint(
          '   freeDrinksQuantity: ${_formController.freeDrinksQuantity}');

      if (isSpecialPack) {
        // Use pack price for special packs
        finalPrice = double.tryParse(_formController.packPrice) ?? 0.0;
        debugPrint('🎁 Using special pack price: $finalPrice DA');

        // Create a default pricing option for special packs with free drinks data
        // This will be saved to menu_item_pricing table
        // IMPORTANT: Create a NEW list copy to avoid reference issues
        final freeDrinksListCopy =
            List<String>.from(_formController.freeDrinkIds);
        debugPrint('🥤 Creating pack pricing with drinks: $freeDrinksListCopy');

        // Prepare offer details with global ingredients and supplements if any
        final Map<String, dynamic> packOfferDetails = {};
        if (_formController.globalPackIngredients.isNotEmpty) {
          packOfferDetails['global_ingredients'] =
              _formController.globalPackIngredients;
          debugPrint(
              '🌿 Adding global ingredients to pack: ${_formController.globalPackIngredients}');
        }
        if (_formController.globalPackSupplements.isNotEmpty) {
          packOfferDetails['global_supplements'] =
              _formController.globalPackSupplements;
          debugPrint(
              '💊 Adding global supplements to pack: ${_formController.globalPackSupplements}');
        }

        final packPricing = MenuItemPricing(
          id: DateTime.now().toIso8601String(), // Temporary ID
          menuItemId: '', // Will be set when saved
          size: 'Pack',
          portion: 'Standard Pack',
          price: finalPrice,
          isDefault: true,
          displayOrder: 0,
          freeDrinksIncluded: freeDrinksListCopy.isNotEmpty,
          freeDrinksList: freeDrinksListCopy,
          freeDrinksQuantity: _formController.freeDrinksQuantity,
          offerDetails: packOfferDetails,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        // Add the pricing option to the enhanced menu item
        enhancedMenuItem.pricing.add(packPricing);
        debugPrint('🎁 Created default pack pricing with free drinks:');
        debugPrint('   freeDrinksIncluded: ${packPricing.freeDrinksIncluded}');
        debugPrint('   freeDrinksList: ${packPricing.freeDrinksList}');
        debugPrint('   freeDrinksQuantity: ${packPricing.freeDrinksQuantity}');
        debugPrint('   offerDetails: ${packPricing.offerDetails}');
        debugPrint(
            '   enhancedMenuItem.pricing count: ${enhancedMenuItem.pricing.length}');
      } else if (isLTOWithSpecialPrice) {
        // Use pack price as base/discounted price for LTO with special_price
        finalPrice = double.tryParse(_formController.packPrice) ?? 0.0;
        debugPrint('🎯 Using LTO base price (discounted): $finalPrice DA');
        debugPrint(
            '🎯 Original price (before discount): ${_formController.originalPrice} DA');
      } else {
        // Use default pricing for regular items
        final defaultPricing = enhancedMenuItem.pricing.isNotEmpty
            ? enhancedMenuItem.pricing.firstWhere(
                (p) => p.isDefault,
                orElse: () => enhancedMenuItem.pricing.first,
              )
            : null;
        finalPrice = defaultPricing?.price ?? 0.0;
        debugPrint('💰 Using default pricing: $finalPrice DA');
      }

      // ========== LIMITED TIME OFFER: Add LTO data to pricing options ==========
      // Store LTO data in pricing_options JSONB (same pattern as special packs)
      if (_formController.isLimitedOffer) {
        debugPrint('🎯 Adding LTO data to pricing options');
        debugPrint('   Offer Types: ${_formController.offerTypes}');

        // Prepare LTO free drinks if applicable
        final ltoDrinkIds = _formController.offerTypes.contains('free_drinks')
            ? (_formController.offerDetails['free_drinks_list']
                        as List<dynamic>? ??
                    [])
                .map((id) => id.toString())
                .toList()
            : <String>[];
        final ltoDrinkQuantity =
            _formController.offerDetails['free_drinks_quantity'] as int? ?? 1;

        if (enhancedMenuItem.pricing.isEmpty) {
          // If no pricing exists, create a default pricing with full LTO data
          debugPrint('🎯 Creating default pricing with LTO data');
          // For special packs, include global ingredients and supplements in offerDetails
          final ltoOfferDetails =
              Map<String, dynamic>.from(_formController.offerDetails);
          if (_formController.isSpecialPack) {
            if (_formController.globalPackIngredients.isNotEmpty) {
              ltoOfferDetails['global_ingredients'] =
                  _formController.globalPackIngredients;
              debugPrint(
                  '   🌿 Adding global ingredients to LTO offerDetails: ${_formController.globalPackIngredients}');
            }
            if (_formController.globalPackSupplements.isNotEmpty) {
              ltoOfferDetails['global_supplements'] =
                  _formController.globalPackSupplements;
              debugPrint(
                  '   💊 Adding global supplements to LTO offerDetails: ${_formController.globalPackSupplements}');
            }
          }

          final ltoPricing = MenuItemPricing(
            id: DateTime.now().toIso8601String(),
            menuItemId: '',
            size: 'Standard',
            portion: 'Standard',
            price: finalPrice,
            isDefault: true,
            displayOrder: 0,
            // LTO fields
            isLimitedOffer: true,
            offerTypes: List<String>.from(_formController.offerTypes),
            offerStartAt: _formController.offerStartAt,
            offerEndAt: _formController.offerEndAt,
            originalPrice: _formController.originalPrice,
            offerDetails: ltoOfferDetails, // Use merged offerDetails
            // Free drinks (if part of LTO)
            freeDrinksIncluded: ltoDrinkIds.isNotEmpty,
            freeDrinksList: ltoDrinkIds,
            freeDrinksQuantity: ltoDrinkQuantity,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
          enhancedMenuItem.pricing.add(ltoPricing);
          debugPrint('   ✅ Created pricing with LTO data');
        } else {
          // Add LTO data to ALL existing pricing options
          debugPrint(
              '🎯 Adding LTO data to ${enhancedMenuItem.pricing.length} existing pricing options');
          for (int i = 0; i < enhancedMenuItem.pricing.length; i++) {
            final pricing = enhancedMenuItem.pricing[i];
            // Merge existing offerDetails (may contain global_ingredients/supplements) with LTO offerDetails
            final mergedOfferDetails =
                Map<String, dynamic>.from(pricing.offerDetails);
            mergedOfferDetails.addAll(_formController.offerDetails);
            debugPrint(
                '   📦 Merged offerDetails for ${pricing.size}: $mergedOfferDetails');

            enhancedMenuItem.pricing[i] = pricing.copyWith(
              isLimitedOffer: true,
              offerTypes: List<String>.from(_formController.offerTypes),
              offerStartAt: _formController.offerStartAt,
              offerEndAt: _formController.offerEndAt,
              originalPrice: _formController.originalPrice,
              offerDetails:
                  mergedOfferDetails, // Use merged offerDetails instead of replacing
              // Free drinks (if part of LTO)
              freeDrinksIncluded:
                  ltoDrinkIds.isNotEmpty ? true : pricing.freeDrinksIncluded,
              freeDrinksList:
                  ltoDrinkIds.isNotEmpty ? ltoDrinkIds : pricing.freeDrinksList,
              freeDrinksQuantity: ltoDrinkIds.isNotEmpty
                  ? ltoDrinkQuantity
                  : pricing.freeDrinksQuantity,
            );
            debugPrint('   ✅ Updated ${pricing.size} pricing with LTO data');
          }
        }
      }

      // Debug pricing options before serialization
      debugPrint('🔍 Pricing options before MenuItem creation:');
      for (final pricing in enhancedMenuItem.pricing) {
        debugPrint('   - ${pricing.size}:');
        debugPrint('     freeDrinksList = ${pricing.freeDrinksList}');
        debugPrint('     isLimitedOffer = ${pricing.isLimitedOffer}');
        if (pricing.isLimitedOffer) {
          debugPrint('     offerTypes = ${pricing.offerTypes}');
          debugPrint('     originalPrice = ${pricing.originalPrice}');
        }
      }

      // Serialize pricing options to JSON
      final pricingOptionsJson =
          enhancedMenuItem.pricing.map((p) => p.toJson()).toList();
      debugPrint('🔍 Pricing options after toJson():');
      for (final pricingJson in pricingOptionsJson) {
        debugPrint('   - ${pricingJson['size']}:');
        debugPrint(
            '     free_drinks_list = ${pricingJson['free_drinks_list']}');
        debugPrint(
            '     is_limited_offer = ${pricingJson['is_limited_offer']}');
        if (pricingJson['is_limited_offer'] == true) {
          debugPrint('     offer_types = ${pricingJson['offer_types']}');
          debugPrint('     original_price = ${pricingJson['original_price']}');
        }
      }

      // Debug LTO values from controller
      debugPrint('🎯 LIMITED TIME OFFER DEBUG:');
      debugPrint('   isLimitedOffer: ${_formController.isLimitedOffer}');
      debugPrint('   offerTypes: ${_formController.offerTypes}');
      debugPrint('   offerStartAt: ${_formController.offerStartAt}');
      debugPrint('   offerEndAt: ${_formController.offerEndAt}');
      debugPrint('   originalPrice: ${_formController.originalPrice}');
      debugPrint('   offerDetails: ${_formController.offerDetails}');

      // Convert EnhancedMenuItem to basic MenuItem for database insertion
      // Ensure image is set (use placeholder if empty for supplements-only mode)
      final finalImage = enhancedMenuItem.image.isNotEmpty
          ? enhancedMenuItem.image
          : (widget.showOnlySupplements
              ? 'https://via.placeholder.com/150'
              : '');

      final menuItem = MenuItem(
        id: enhancedMenuItem.id,
        restaurantId: restaurantId,
        restaurantName: restaurantName,
        name: enhancedMenuItem.name,
        description: enhancedMenuItem.description ?? '',
        image: finalImage,
        price: finalPrice,
        category:
            enhancedMenuItem.category, // This is the actual selected category
        cuisineTypeId: _selectedCuisineTypeId, // Add cuisine type ID
        categoryId: _selectedCategoryId, // Add category ID
        isAvailable: enhancedMenuItem.isAvailable,
        isFeatured: enhancedMenuItem.isFeatured,
        preparationTime: enhancedMenuItem.preparationTime,
        rating: enhancedMenuItem.rating,
        reviewCount: enhancedMenuItem.reviewCount,
        mainIngredients: formData['main_ingredients'],
        ingredients: enhancedMenuItem.ingredients,
        isSpicy: enhancedMenuItem.isSpicy,
        spiceLevel: enhancedMenuItem.isSpicy ? 1 : 0,
        isTraditional: enhancedMenuItem.isTraditional,
        isVegetarian: enhancedMenuItem.isVegetarian,
        isVegan: enhancedMenuItem.isVegan,
        isGlutenFree: enhancedMenuItem.isGlutenFree,
        isDairyFree: false, // Add to form if needed
        isLowSodium: false, // Add to form if needed
        variants: enhancedMenuItem.variants.map((v) => v.toJson()).toList(),
        pricingOptions: pricingOptionsJson,
        supplements:
            enhancedMenuItem.supplements.map((s) => s.toJson()).toList(),
        // Free drinks are now stored in menu_item_pricing table, not here
        // Limited Time Offer fields
        isLimitedOffer: _formController.isLimitedOffer,
        offerTypes: List<String>.from(_formController.offerTypes),
        offerStartAt: _formController.offerStartAt,
        offerEndAt: _formController.offerEndAt,
        originalPrice: _formController.originalPrice,
        offerDetails: Map<String, dynamic>.from(_formController.offerDetails),
        calories: null, // Add to form if needed
        protein: null, // Add to form if needed
        carbs: null, // Add to form if needed
        fat: null, // Add to form if needed
        fiber: null, // Add to form if needed
        sugar: null, // Add to form if needed
        createdAt: enhancedMenuItem.createdAt,
        updatedAt: enhancedMenuItem.updatedAt,
      );

      // Debug MenuItem after creation
      debugPrint('🎯 MENU ITEM AFTER CREATION:');
      debugPrint('   isLimitedOffer: ${menuItem.isLimitedOffer}');
      debugPrint('   offerTypes: ${menuItem.offerTypes}');
      debugPrint('   offerStartAt: ${menuItem.offerStartAt}');
      debugPrint('   offerEndAt: ${menuItem.offerEndAt}');
      debugPrint('   originalPrice: ${menuItem.originalPrice}');
      debugPrint('   offerDetails: ${menuItem.offerDetails}');

      // Create or update based on mode
      final MenuItem processedMenuItem;
      if (_isEditMode) {
        debugPrint('💾 Updating menu item in database...');
        // Use existing item ID for update
        final updatedMenuItem = menuItem.copyWith(id: widget.menuItem!.id);
        final success = await _menuItemService.updateMenuItem(updatedMenuItem);
        if (!success) {
          throw Exception('Failed to update menu item');
        }
        processedMenuItem = updatedMenuItem;
        debugPrint('✅ Menu item updated with ID: ${processedMenuItem.id}');
      } else {
        debugPrint('💾 Adding menu item to database...');
        processedMenuItem = await _menuItemService.createMenuItem(menuItem, []);
        debugPrint('✅ Menu item created with ID: ${processedMenuItem.id}');
      }

      // Save enhanced data (variants, pricing, supplements) - OPTIMIZED
      debugPrint('💾 Saving enhanced menu item data...');

      // OPTIMIZATION: Save all enhanced data in a single database operation
      await _saveEnhancedMenuItemDataOptimized(
          processedMenuItem.id, enhancedMenuItem);

      debugPrint('✅ Enhanced menu item data saved successfully');

      // Store selected images before resetting form (for async upload)
      final selectedImagesForUpload =
          List<File>.from(_formController.selectedImages);
      final existingImageUrls =
          List<String>.from(_formController.existingImageUrls);

      // OPTIMIZATION: Handle image upload asynchronously (non-blocking)
      // - Upload new images if any were selected
      // - Keep existing images if in edit mode
      if (selectedImagesForUpload.isNotEmpty || existingImageUrls.isNotEmpty) {
        _handleImageUploadAsync(processedMenuItem, enhancedMenuItem,
            restaurantId, formData, selectedImagesForUpload, existingImageUrls);
      }

      debugPrint('✅ Enhanced menu item creation completed successfully');

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isEditMode
                ? 'Menu item updated successfully!'
                : 'Menu item added successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }

      debugPrint('🎉 Form submission completed successfully!');

      // Reset form and navigate back
      if (!_isEditMode) {
        _formController.resetForm();
      }
      // Return true to indicate successful save/update
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      debugPrint('❌ Error during form submission: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');

      // Close loading dialog if it's still open
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      _showErrorSnackBar(_isEditMode
          ? 'Error updating menu item: $e'
          : 'Error adding menu item: $e');
    } finally {
      debugPrint('🏁 Form submission process finished');
      _formController.setSubmittingState(isSubmitting: false);
    }
  }

  void _showErrorSnackBar(String message) {
    // Use ErrorHandlingService for consistent error handling
    ErrorHandlingService.showErrorSnackBar(
      context,
      ErrorHandlingService.unknownError,
      customMessage: message,
    );

    // Also log the error
    final errorLoggingService =
        Provider.of<ErrorLoggingService>(context, listen: false);
    errorLoggingService.logWarning(
      'Menu item form error: $message',
      context: 'AddNewMenuItemScreen',
      additionalData: {
        'screen': 'add_new_menu_item_screen',
        'method': '_showErrorSnackBar',
      },
    );
  }

  /// OPTIMIZED: Save all enhanced menu item data in a single operation
  Future<void> _saveEnhancedMenuItemDataOptimized(
    String menuItemId,
    EnhancedMenuItem enhancedMenuItem,
  ) async {
    try {
      debugPrint('🚀 Starting optimized enhanced data save...');

      // Prepare all data for batch operations
      final variantsData = enhancedMenuItem.variants
          .map((variant) => {
                'menu_item_id': menuItemId,
                'name': variant.name,
                'description': variant.description ?? '',
                'is_default': variant.isDefault,
                'display_order': 0,
                'created_at': DateTime.now().toIso8601String(),
                'updated_at': DateTime.now().toIso8601String(),
              })
          .toList();

      final pricingData = enhancedMenuItem.pricing.map((pricing) {
        final pricingDataMap = <String, dynamic>{
          'menu_item_id': menuItemId,
          'size': pricing.size,
          'portion': pricing.portion,
          'price': pricing.price,
          // currency and description fields don't exist in DB schema
          'is_default': pricing.isDefault,
          'free_drinks_included': pricing.freeDrinksIncluded,
          'free_drinks_list': pricing.freeDrinksList,
          'free_drinks_quantity': pricing.freeDrinksQuantity,
          'display_order': pricing.displayOrder,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        };

        // Include LTO fields if applicable
        if (pricing.isLimitedOffer) {
          pricingDataMap['is_limited_offer'] = true;
          pricingDataMap['offer_types'] = pricing.offerTypes;
          if (pricing.offerStartAt != null) {
            pricingDataMap['offer_start_at'] =
                pricing.offerStartAt!.toIso8601String();
          }
          if (pricing.offerEndAt != null) {
            pricingDataMap['offer_end_at'] =
                pricing.offerEndAt!.toIso8601String();
          }
          if (pricing.originalPrice != null) {
            pricingDataMap['original_price'] = pricing.originalPrice;
          }
          // Include offer_details with global_ingredients and global_supplements
          if (pricing.offerDetails.isNotEmpty) {
            pricingDataMap['offer_details'] = pricing.offerDetails;
            debugPrint(
                '   💾 Saving offer_details for ${pricing.size}: ${pricing.offerDetails}');
          }
        }

        return pricingDataMap;
      }).toList();

      // Separate restaurant supplements (link existing) from new supplements (create with null menu_item_id)
      final restaurantSupplements = <MenuItemSupplement>[];
      final newSupplements = <MenuItemSupplement>[];

      for (final supplement in enhancedMenuItem.supplements) {
        // If supplement has a valid UUID ID and empty menuItemId, it's from restaurant_supplements
        // We should link it to the menu item (update existing)
        if (_isValidUUID(supplement.id) && supplement.menuItemId.isEmpty) {
          restaurantSupplements.add(supplement);
        } else {
          // Otherwise, it's a new supplement (timestamp ID) - create with null menu_item_id
          newSupplements.add(supplement);
        }
      }

      // Perform batch inserts using Supabase directly
      final supabase = Supabase.instance.client;

      // Batch insert variants
      if (variantsData.isNotEmpty) {
        await supabase.from('menu_item_variants').insert(variantsData);
        debugPrint('✅ Batch inserted ${variantsData.length} variants');
      }

      // Batch insert pricing
      if (pricingData.isNotEmpty) {
        await supabase.from('menu_item_pricing').insert(pricingData);
        debugPrint('✅ Batch inserted ${pricingData.length} pricing options');
      }

      // Handle supplements: link restaurant supplements and create new ones with null menu_item_id
      if (restaurantSupplements.isNotEmpty) {
        // Link existing restaurant supplements to menu item (update menu_item_id)
        for (final supplement in restaurantSupplements) {
          await _restaurantSupplementService.linkSupplementToMenuItem(
            supplementId: supplement.id,
            menuItemId: menuItemId,
          );
        }
        debugPrint(
            '✅ Linked ${restaurantSupplements.length} restaurant supplements to menu item');
      }

      if (newSupplements.isNotEmpty) {
        // Create new supplements with NULL menu_item_id (restaurant-level supplements)
        final newSupplementsData = newSupplements
            .map((supplement) => {
                  'menu_item_id': null, // NULL - restaurant-level supplement
                  'name': supplement.name,
                  'price': supplement.price,
                  'description': supplement.description ?? '',
                  'is_available': supplement.isAvailable,
                  'display_order': supplement.displayOrder,
                  'created_at': DateTime.now().toIso8601String(),
                  'updated_at': DateTime.now().toIso8601String(),
                })
            .toList();

        await supabase.from('menu_item_supplements').insert(newSupplementsData);
        debugPrint(
            '✅ Batch inserted ${newSupplements.length} new supplements (restaurant-level)');

        // Add new supplements to restaurant_supplements
        final restaurantId = _currentRestaurantId;
        if (restaurantId != null && restaurantId.isNotEmpty) {
          // Get the newly created supplement IDs
          final newSupplementIds = await supabase
              .from('menu_item_supplements')
              .select('id')
              .isFilter('menu_item_id',
                  null) // Only get supplements with null menu_item_id
              .inFilter('name', newSupplements.map((s) => s.name).toList())
              .order('created_at', ascending: false)
              .limit(newSupplements.length);

          for (final row in (newSupplementIds as List)) {
            final supplementId = row['id'] as String;
            await _restaurantSupplementService.ensureSupplementInRestaurant(
              restaurantId: restaurantId,
              supplementId: supplementId,
            );
          }
          debugPrint(
              '✅ Added ${newSupplements.length} new supplements to restaurant_supplements');
        }
      }

      debugPrint('🚀 Optimized enhanced data save completed successfully');
    } catch (e) {
      debugPrint('❌ Error in optimized enhanced data save: $e');
      // Fallback to individual operations if batch fails
      await _saveEnhancedMenuItemDataFallback(menuItemId, enhancedMenuItem);
    }
  }

  /// Fallback method for enhanced data save (individual operations)
  Future<void> _saveEnhancedMenuItemDataFallback(
    String menuItemId,
    EnhancedMenuItem enhancedMenuItem,
  ) async {
    debugPrint('🔄 Using fallback method for enhanced data save...');

    try {
      // Save variants individually
      for (final variant in enhancedMenuItem.variants) {
        await Supabase.instance.client.from('menu_item_variants').insert({
          'menu_item_id': menuItemId,
          'name': variant.name,
          'description': variant.description ?? '',
          'is_default': variant.isDefault,
          'display_order': 0,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      // Get free drinks from controller if it's a special pack
      final isSpecialPack = _formController.isSpecialPack;
      final freeDrinksList =
          isSpecialPack ? _formController.freeDrinkIds : <String>[];
      final hasFreeDrinks = freeDrinksList.isNotEmpty;

      // Save pricing individually
      for (final pricing in enhancedMenuItem.pricing) {
        await Supabase.instance.client.from('menu_item_pricing').insert({
          'menu_item_id': menuItemId,
          'size': pricing.size,
          'portion': pricing.portion,
          'price': pricing.price,
          // currency and description fields don't exist in DB schema
          'is_default': pricing.isDefault,
          'free_drinks_included': hasFreeDrinks,
          'free_drinks_list': freeDrinksList,
          'free_drinks_quantity': _formController.freeDrinksQuantity,
          'display_order': 0,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      // Separate restaurant supplements (link existing) from new supplements (create with null menu_item_id)
      final restaurantSupplements = <MenuItemSupplement>[];
      final newSupplements = <MenuItemSupplement>[];

      for (final supplement in enhancedMenuItem.supplements) {
        // If supplement has a valid UUID ID and empty menuItemId, it's from restaurant_supplements
        // We should link it to the menu item (update existing)
        if (_isValidUUID(supplement.id) && supplement.menuItemId.isEmpty) {
          restaurantSupplements.add(supplement);
        } else {
          // Otherwise, it's a new supplement (timestamp ID) - create with null menu_item_id
          newSupplements.add(supplement);
        }
      }

      // Link restaurant supplements (update existing entries)
      for (final supplement in restaurantSupplements) {
        await _restaurantSupplementService.linkSupplementToMenuItem(
          supplementId: supplement.id,
          menuItemId: menuItemId,
        );
      }

      // Create new supplements with NULL menu_item_id (restaurant-level supplements)
      for (final supplement in newSupplements) {
        await Supabase.instance.client.from('menu_item_supplements').insert({
          'menu_item_id': null, // NULL - restaurant-level supplement
          'name': supplement.name,
          'price': supplement.price,
          'description': supplement.description ?? '',
          'is_available': supplement.isAvailable,
          'display_order': supplement.displayOrder,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });

        // Add supplement to restaurant_supplements
        final restaurantId = _currentRestaurantId;
        if (restaurantId != null && restaurantId.isNotEmpty) {
          // Get the newly created supplement ID
          final newSupplementResponse = await Supabase.instance.client
              .from('menu_item_supplements')
              .select('id')
              .isFilter('menu_item_id',
                  null) // Only get supplements with null menu_item_id
              .eq('name', supplement.name)
              .eq('price', supplement.price)
              .order('created_at', ascending: false)
              .limit(1)
              .single();

          final newSupplementId = newSupplementResponse['id'] as String;
          await _restaurantSupplementService.ensureSupplementInRestaurant(
            restaurantId: restaurantId,
            supplementId: newSupplementId,
          );
        }
      }

      debugPrint('✅ Fallback enhanced data save completed');
    } catch (e) {
      debugPrint('❌ Fallback enhanced data save failed: $e');
      rethrow;
    }
  }

  /// Check if a string is a valid UUID format
  bool _isValidUUID(String? value) {
    if (value == null || value.isEmpty) return false;
    final uuidRegex = RegExp(
      r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
      caseSensitive: false,
    );
    return uuidRegex.hasMatch(value);
  }

  /// Handle smart drink image detection for a single drink
  void _handleDrinkImageDetection(MenuItem drinkItem, String drinkName) {
    Future.microtask(() async {
      try {
        debugPrint('🥤 Starting smart detection for: $drinkName');

        // Smart detect drink image from bucket based on drink name
        final drinkImageResult =
            DrinkImageDetector.detectDrinkImage(drinkName, null);
        debugPrint('🥤 Smart detected drink image: $drinkImageResult');

        // Handle smart detection result
        final drinkImageUrl = drinkImageResult.startsWith('DRINK_NAME:')
            ? '' // Empty image URL will trigger drink name display
            : drinkImageResult;

        if (drinkImageUrl.isNotEmpty) {
          final updatedDrink = MenuItem(
            id: drinkItem.id,
            restaurantId: drinkItem.restaurantId,
            restaurantName: drinkItem.restaurantName,
            name: drinkItem.name,
            description: drinkItem.description,
            image: drinkImageUrl,
            price: drinkItem.price,
            category: drinkItem.category,
            cuisineTypeId: drinkItem.cuisineTypeId,
            categoryId: drinkItem.categoryId,
            isAvailable: drinkItem.isAvailable,
            isFeatured: drinkItem.isFeatured,
            preparationTime: drinkItem.preparationTime,
            rating: drinkItem.rating,
            reviewCount: drinkItem.reviewCount,
            mainIngredients: drinkItem.mainIngredients,
            ingredients: drinkItem.ingredients,
            isSpicy: drinkItem.isSpicy,
            spiceLevel: drinkItem.spiceLevel,
            isTraditional: drinkItem.isTraditional,
            isVegetarian: drinkItem.isVegetarian,
            isVegan: drinkItem.isVegan,
            isGlutenFree: drinkItem.isGlutenFree,
            isDairyFree: drinkItem.isDairyFree,
            isLowSodium: drinkItem.isLowSodium,
            variants: drinkItem.variants,
            pricingOptions: drinkItem.pricingOptions,
            supplements: drinkItem.supplements,
            calories: drinkItem.calories,
            protein: drinkItem.protein,
            carbs: drinkItem.carbs,
            fat: drinkItem.fat,
            fiber: drinkItem.fiber,
            sugar: drinkItem.sugar,
            createdAt: drinkItem.createdAt,
            updatedAt: DateTime.now(),
          );

          await _menuItemService.updateMenuItem(updatedDrink);
          debugPrint('✅ Updated $drinkName with smart detected image');
        } else {
          debugPrint('⚠️ No image found for $drinkName - will show name');
        }
      } catch (e) {
        debugPrint('❌ Error in smart detection for $drinkName: $e');
      }
    });
  }

  /// OPTIMIZED: Handle image upload asynchronously (non-blocking)
  void _handleImageUploadAsync(
    MenuItem createdMenuItem,
    EnhancedMenuItem enhancedMenuItem,
    String restaurantId,
    Map<String, dynamic> formData,
    List<File> selectedImagesForUpload,
    List<String> existingImageUrls,
  ) {
    // Run image upload in background without blocking the main flow
    Future.microtask(() async {
      try {
        debugPrint('📸 Starting async image upload...');

        if (_isDrinkCategory) {
          debugPrint(
              '🥤 Drink category detected - using drink image from bucket');

          // Get the default flavor for drink image
          final defaultFlavor = enhancedMenuItem.variants.isNotEmpty
              ? enhancedMenuItem.variants
                  .firstWhere(
                    (v) => v.isDefault,
                    orElse: () => enhancedMenuItem.variants.first,
                  )
                  .name
              : null;

          // Smart detect drink image from bucket based on drink name and flavor (cached)
          final (drinkImageResult, _) =
              _getCachedDrinkDetection(formData['name'] ?? '', defaultFlavor);
          debugPrint('🥤 Smart detected drink image: $drinkImageResult');

          // Handle smart detection result
          final drinkImageUrl = drinkImageResult.startsWith('DRINK_NAME:')
              ? '' // Empty image URL will trigger drink name display
              : drinkImageResult;

          final updatedMenuItem = MenuItem(
            id: createdMenuItem.id,
            restaurantId: createdMenuItem.restaurantId,
            restaurantName: createdMenuItem.restaurantName,
            name: createdMenuItem.name,
            description: createdMenuItem.description,
            image: drinkImageUrl,
            images: drinkImageUrl.isNotEmpty ? [drinkImageUrl] : [],
            price: createdMenuItem.price,
            category: createdMenuItem.category,
            cuisineTypeId: createdMenuItem.cuisineTypeId,
            categoryId: createdMenuItem.categoryId,
            isAvailable: createdMenuItem.isAvailable,
            isFeatured: createdMenuItem.isFeatured,
            preparationTime: createdMenuItem.preparationTime,
            rating: createdMenuItem.rating,
            reviewCount: createdMenuItem.reviewCount,
            mainIngredients: createdMenuItem.mainIngredients,
            ingredients: createdMenuItem.ingredients,
            isSpicy: createdMenuItem.isSpicy,
            spiceLevel: createdMenuItem.spiceLevel,
            isTraditional: createdMenuItem.isTraditional,
            isVegetarian: createdMenuItem.isVegetarian,
            isVegan: createdMenuItem.isVegan,
            isGlutenFree: createdMenuItem.isGlutenFree,
            isDairyFree: createdMenuItem.isDairyFree,
            isLowSodium: createdMenuItem.isLowSodium,
            variants: createdMenuItem.variants,
            pricingOptions: createdMenuItem.pricingOptions,
            supplements: createdMenuItem.supplements,
            // LTO fields - preserve existing data
            isLimitedOffer: createdMenuItem.isLimitedOffer,
            offerTypes: createdMenuItem.offerTypes,
            offerStartAt: createdMenuItem.offerStartAt,
            offerEndAt: createdMenuItem.offerEndAt,
            originalPrice: createdMenuItem.originalPrice,
            offerDetails: createdMenuItem.offerDetails,
            calories: createdMenuItem.calories,
            protein: createdMenuItem.protein,
            carbs: createdMenuItem.carbs,
            fat: createdMenuItem.fat,
            fiber: createdMenuItem.fiber,
            sugar: createdMenuItem.sugar,
            createdAt: createdMenuItem.createdAt,
            updatedAt: DateTime.now(),
          );

          debugPrint('🔄 Calling updateMenuItem service for drink...');
          final updateSuccess =
              await _menuItemService.updateMenuItem(updatedMenuItem);

          if (updateSuccess) {
            debugPrint('✅ Drink menu item updated with default image (async)');
            debugPrint('✅ Updated drink ID: ${updatedMenuItem.id}');
            debugPrint('✅ Updated drink image: ${updatedMenuItem.image}');
            debugPrint('✅ Updated drink images: ${updatedMenuItem.images}');
          } else {
            debugPrint(
                '❌ Full update failed for drink, trying direct image update...');

            // Fallback: Try direct image-only update
            try {
              await Supabase.instance.client.from('menu_items').update({
                'image': drinkImageUrl,
                'images': drinkImageUrl.isNotEmpty ? [drinkImageUrl] : [],
                'updated_at': DateTime.now().toIso8601String(),
              }).eq('id', createdMenuItem.id);

              debugPrint('✅ Direct drink image update succeeded');
              debugPrint('✅ Image: $drinkImageUrl');
            } catch (directUpdateError) {
              debugPrint(
                  '❌ Direct drink image update also failed: $directUpdateError');
            }
          }
        } else {
          // Upload images for non-drink items
          debugPrint('📸 Starting async image upload for non-drink item...');
          debugPrint(
              '📸 Number of new images to upload: ${selectedImagesForUpload.length}');
          debugPrint(
              '📸 Number of existing images: ${existingImageUrls.length}');

          final List<String> allImageUrls = List.from(existingImageUrls);

          // Only upload new images if any were selected
          if (selectedImagesForUpload.isNotEmpty) {
            final uploadedUrls =
                await _menuItemImageService.uploadMenuItemImages(
              images: selectedImagesForUpload,
              menuItemId: createdMenuItem.id,
              restaurantId: restaurantId,
              onProgress: (progress) {
                // Update progress in background
                debugPrint('📸 Upload progress: ${(progress * 100).toInt()}%');
              },
            );

            debugPrint('✅ Async image upload completed. URLs: $uploadedUrls');
            allImageUrls.addAll(uploadedUrls);
          }

          // Update menu item with image URLs if we have any
          if (allImageUrls.isNotEmpty) {
            debugPrint(
                '🔄 Updating menu item with image URLs (async)... Total images: ${allImageUrls.length}');
            debugPrint('📸 Image URLs to save:');
            for (final url in allImageUrls) {
              debugPrint('   - $url');
            }
            final updatedMenuItem = MenuItem(
              id: createdMenuItem.id,
              restaurantId: createdMenuItem.restaurantId,
              restaurantName: createdMenuItem.restaurantName,
              name: createdMenuItem.name,
              description: createdMenuItem.description,
              image: allImageUrls.first, // Use first image as primary
              images: allImageUrls, // Store all images for gallery
              price: createdMenuItem.price,
              category: createdMenuItem.category,
              cuisineTypeId: createdMenuItem.cuisineTypeId,
              categoryId: createdMenuItem.categoryId,
              isAvailable: createdMenuItem.isAvailable,
              isFeatured: createdMenuItem.isFeatured,
              preparationTime: createdMenuItem.preparationTime,
              rating: createdMenuItem.rating,
              reviewCount: createdMenuItem.reviewCount,
              mainIngredients: createdMenuItem.mainIngredients,
              ingredients: createdMenuItem.ingredients,
              isSpicy: createdMenuItem.isSpicy,
              spiceLevel: createdMenuItem.spiceLevel,
              isTraditional: createdMenuItem.isTraditional,
              isVegetarian: createdMenuItem.isVegetarian,
              isVegan: createdMenuItem.isVegan,
              isGlutenFree: createdMenuItem.isGlutenFree,
              isDairyFree: createdMenuItem.isDairyFree,
              isLowSodium: createdMenuItem.isLowSodium,
              variants: createdMenuItem.variants,
              pricingOptions: createdMenuItem.pricingOptions,
              supplements: createdMenuItem.supplements,
              // LTO fields - preserve existing data
              isLimitedOffer: createdMenuItem.isLimitedOffer,
              offerTypes: createdMenuItem.offerTypes,
              offerStartAt: createdMenuItem.offerStartAt,
              offerEndAt: createdMenuItem.offerEndAt,
              originalPrice: createdMenuItem.originalPrice,
              offerDetails: createdMenuItem.offerDetails,
              calories: createdMenuItem.calories,
              protein: createdMenuItem.protein,
              carbs: createdMenuItem.carbs,
              fat: createdMenuItem.fat,
              fiber: createdMenuItem.fiber,
              sugar: createdMenuItem.sugar,
              createdAt: createdMenuItem.createdAt,
              updatedAt: DateTime.now(),
            );

            debugPrint('🔄 Calling updateMenuItem service...');

            // Try full update first
            final updateSuccess =
                await _menuItemService.updateMenuItem(updatedMenuItem);

            if (updateSuccess) {
              debugPrint('✅ Menu item updated with image URLs (async)');
              debugPrint('✅ Updated item ID: ${updatedMenuItem.id}');
              debugPrint('✅ Updated item image: ${updatedMenuItem.image}');
              debugPrint('✅ Updated item images: ${updatedMenuItem.images}');
            } else {
              debugPrint('❌ Full update failed, trying direct image update...');

              // Fallback: Try direct image-only update
              try {
                await Supabase.instance.client.from('menu_items').update({
                  'image': allImageUrls.first,
                  'images': allImageUrls,
                  'updated_at': DateTime.now().toIso8601String(),
                }).eq('id', createdMenuItem.id);

                debugPrint('✅ Direct image update succeeded');
                debugPrint('✅ Image: ${allImageUrls.first}');
                debugPrint('✅ Images: $allImageUrls');
              } catch (directUpdateError) {
                debugPrint(
                    '❌ Direct image update also failed: $directUpdateError');
              }
            }
          } else {
            debugPrint('⚠️ No image URLs to save - skipping update');
          }
        }
      } catch (e, stackTrace) {
        debugPrint('❌ Error in async image upload: $e');
        debugPrint('❌ Stack trace: $stackTrace');
        // Don't rethrow - this is background operation
      }
    });
  }
}

/// Stateful dialog for selecting free drinks with quantity
class _FreeDrinksSelectionDialog extends StatefulWidget {
  final List<MenuItem> drinks;
  final List<String> initialSelection;
  final int initialQuantity;
  final Color primaryColor;

  const _FreeDrinksSelectionDialog({
    required this.drinks,
    required this.initialSelection,
    required this.initialQuantity,
    required this.primaryColor,
  });

  @override
  State<_FreeDrinksSelectionDialog> createState() =>
      _FreeDrinksSelectionDialogState();
}

class _FreeDrinksSelectionDialogState
    extends State<_FreeDrinksSelectionDialog> {
  late List<String> selectedIds;
  late int quantity;

  @override
  void initState() {
    super.initState();
    selectedIds = List<String>.from(widget.initialSelection);
    quantity = widget.initialQuantity;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        'Select Free Drinks',
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.w600,
          color: Colors.black,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quantity selector
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Max Free Drinks:',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: quantity > 1
                            ? () => setState(() => quantity--)
                            : null,
                        icon: const Icon(Icons.remove_circle_outline),
                        color: widget.primaryColor,
                      ),
                      Text(
                        quantity.toString(),
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      IconButton(
                        onPressed: quantity < 10
                            ? () => setState(() => quantity++)
                            : null,
                        icon: const Icon(Icons.add_circle_outline),
                        color: widget.primaryColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Drinks list
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: widget.drinks.length,
                itemBuilder: (context, index) {
                  final drink = widget.drinks[index];
                  final isSelected = selectedIds.contains(drink.id);
                  return CheckboxListTile(
                    value: isSelected,
                    onChanged: (value) {
                      setState(() {
                        if (value == true) {
                          selectedIds.add(drink.id);
                        } else {
                          selectedIds.remove(drink.id);
                        }
                      });
                    },
                    activeColor: widget.primaryColor,
                    title: Text(
                      drink.name,
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                    subtitle: Text(
                      '${drink.price.toStringAsFixed(0)} DA',
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    secondary: drink.image.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              drink.image,
                              width: 40,
                              height: 40,
                              fit: BoxFit.cover,
                              // PERFORMANCE FIX: Add cacheWidth/cacheHeight for list items
                              // Prevents decoding full-size images which causes scroll jank
                              cacheWidth: 80, // 40dp * 2x for retina
                              cacheHeight: 80,
                              filterQuality: FilterQuality
                                  .low, // Faster decoding for thumbnails
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(Icons.local_drink,
                                      color: Colors.grey[400]),
                            ),
                          )
                        : Icon(Icons.local_drink, color: Colors.grey[400]),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: Text(
            'Cancel',
            style: GoogleFonts.poppins(color: Colors.grey),
          ),
        ),
        ElevatedButton(
          onPressed: selectedIds.isEmpty
              ? null
              : () => Navigator.of(context).pop({
                    'drinkIds': selectedIds,
                    'quantity': quantity,
                  }),
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.primaryColor,
            foregroundColor: Colors.white,
          ),
          child: Text(
            'Done (${selectedIds.length})',
            style: GoogleFonts.poppins(),
          ),
        ),
      ],
    );
  }
}
