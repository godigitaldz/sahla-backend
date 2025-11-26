import 'dart:io';

import 'package:flutter/material.dart';

import '../models/menu_item_pricing.dart';
import '../models/menu_item_supplement.dart';
import '../models/menu_item_variant.dart';
import '../models/supplement_variant.dart';

class MenuItemFormController extends ChangeNotifier {
  // Preparation time constants
  static const int minPreparationTime = 1; // 1 minute
  static const int maxPreparationTime = 300; // 5 hours (300 minutes)
  static const int defaultPreparationTime = 15; // 15 minutes
  static const int drinkPreparationTime = 1; // 1 minute (instant for drinks)

  // Form validation state
  bool _isFormValid = false;
  bool _isSubmitting = false;
  bool _isUploadingImages = false;
  double _uploadProgress = 0.0;

  // Basic form data
  String _dishName = '';
  String _description = '';
  String _mainIngredients = ''; // For when description is null
  String _category = '';
  String _preparationTime = '';
  String _packPrice = ''; // For special packs - fixed price for entire pack
  final List<String> _ingredients = [];
  final List<File> _selectedImages = [];
  final List<String> _existingImageUrls =
      []; // For edit mode - existing images from DB

  // Enhanced features
  final List<MenuItemVariant> _variants = [];
  final List<MenuItemPricing> _pricingOptions = [];
  final List<MenuItemSupplement> _supplements = [];

  // Free drinks for special packs
  final List<String> _freeDrinkIds = [];
  int _freeDrinksQuantity = 1; // Max number of free drinks allowed

  // Global ingredients for special packs (ingredients for the whole pack, not specific items)
  final List<String> _globalPackIngredients = [];

  // Global supplements for special packs (supplements for the whole pack, with prices)
  // Using dynamic to handle runtime type conversion from List (old format) to Map (new format)
  dynamic _globalPackSupplements = <String, double>{};

  // Limited Time Offer state
  bool _isLimitedOffer = false;
  final List<String> _offerTypes = [];
  DateTime? _offerStartAt;
  DateTime? _offerEndAt;
  double? _originalPrice;
  final Map<String, dynamic> _offerDetails = {};

  // Dietary options (Algerian local)
  bool _isHalal = false;
  bool _isTraditional = false;
  bool _isSpicy = false;
  bool _isVegetarian = false;
  bool _isGlutenFree = false;
  bool _isDairyFree = false;
  bool _isLowSodium = false;

  // Availability options
  bool _isAvailable = true;
  bool _isFeatured = false;

  // Nutritional information
  String _calories = '';
  String _protein = '';
  String _carbs = '';
  String _fat = '';
  String _fiber = '';
  String _sugar = '';

  // Additional details
  final String _size = '';
  final String _portion = '';
  final List<String> _tags = [];
  final List<String> _customizationOptions = [];
  final Map<String, double> _addOnPrices = {};

  // Getters
  bool get isFormValid => _isFormValid;
  bool get isSubmitting => _isSubmitting;
  bool get isUploadingImages => _isUploadingImages;
  double get uploadProgress => _uploadProgress;

  // Form field getters
  String get dishName => _dishName;
  String get description => _description;
  String get mainIngredients => _mainIngredients;
  String get category => _category;
  String get preparationTime => _preparationTime;
  String get packPrice => _packPrice;
  List<String> get ingredients => _ingredients;
  List<File> get selectedImages => _selectedImages;
  List<String> get existingImageUrls => _existingImageUrls;

  // Helper to check if current category is a special pack
  bool get isSpecialPack =>
      _category.toLowerCase().contains('pack') ||
      _category.toLowerCase().contains('combo') ||
      _category.toLowerCase().contains('special');

  // Enhanced features getters
  List<MenuItemVariant> get variants => _variants;
  List<MenuItemPricing> get pricingOptions => _pricingOptions;
  List<MenuItemSupplement> get supplements => _supplements;
  List<String> get freeDrinkIds => _freeDrinkIds;
  int get freeDrinksQuantity => _freeDrinksQuantity;
  List<String> get globalPackIngredients => _globalPackIngredients;
  Map<String, double> get globalPackSupplements {
    // Defensive check: ensure we always return a Map
    // Handle cases where runtime type might be List (e.g., from old data or JSON deserialization)
    if (_globalPackSupplements is List) {
      debugPrint(
          '⚠️ Warning: _globalPackSupplements is a List at runtime, converting to Map');
      debugPrint('⚠️ Runtime type: ${_globalPackSupplements.runtimeType}');
      // Convert List to Map with default price 0.0
      final Map<String, double> converted = {};
      try {
        for (final item in (_globalPackSupplements as List)) {
          if (item is String) {
            converted[item] = 0.0;
          }
        }
        // Assign the converted Map back (now that field is dynamic, we can reassign)
        _globalPackSupplements = converted;
        debugPrint(
            '✅ Converted ${converted.length} supplements from List to Map');
        return converted;
      } catch (e) {
        debugPrint('⚠️ Error converting List to Map: $e');
        _globalPackSupplements = <String, double>{};
        return <String, double>{};
      }
    }
    // Ensure it's a Map, convert if needed
    if (_globalPackSupplements is! Map<String, double>) {
      try {
        final Map<String, double> converted = {};
        if (_globalPackSupplements is Map) {
          (_globalPackSupplements as Map).forEach((key, value) {
            converted[key.toString()] = value is num
                ? value.toDouble()
                : (double.tryParse(value.toString()) ?? 0.0);
          });
          _globalPackSupplements = converted;
          return converted;
        }
      } catch (e) {
        debugPrint('⚠️ Error converting to Map: $e');
      }
      _globalPackSupplements = <String, double>{};
      return <String, double>{};
    }
    return _globalPackSupplements as Map<String, double>;
  }

  // Limited Time Offer getters
  bool get isLimitedOffer => _isLimitedOffer;
  List<String> get offerTypes => _offerTypes;
  DateTime? get offerStartAt => _offerStartAt;
  DateTime? get offerEndAt => _offerEndAt;
  double? get originalPrice => _originalPrice;
  Map<String, dynamic> get offerDetails => _offerDetails;

  // Dietary option getters (Algerian local)
  bool get isHalal => _isHalal;
  bool get isTraditional => _isTraditional;
  bool get isSpicy => _isSpicy;
  bool get isVegetarian => _isVegetarian;
  bool get isGlutenFree => _isGlutenFree;
  bool get isDairyFree => _isDairyFree;
  bool get isLowSodium => _isLowSodium;

  // Availability getters
  bool get isAvailable => _isAvailable;
  bool get isFeatured => _isFeatured;

  // Nutritional getters
  String get calories => _calories;
  String get protein => _protein;
  String get carbs => _carbs;
  String get fat => _fat;
  String get fiber => _fiber;
  String get sugar => _sugar;

  // Additional getters
  String get size => _size;
  String get portion => _portion;
  List<String> get tags => _tags;
  List<String> get customizationOptions => _customizationOptions;
  Map<String, double> get addOnPrices => _addOnPrices;

  // Validation methods
  bool _validateRequiredFields() {
    // For drink category, check if we have variants with pricing options
    // Check both the selected category name AND the dish name for drink/beverage keywords
    if (_category.toLowerCase().contains('drink') ||
        _category.toLowerCase().contains('beverage') ||
        _dishName.toLowerCase().contains('drink') ||
        _dishName.toLowerCase().contains('beverage')) {
      // For drinks:
      // - Variants ARE the drink names (Coca Cola, Fanta, etc.)
      // - Must have at least one variant (drink)
      // - Must have at least one pricing option (size)
      // - No dish name required (variants are the names)
      // - No images required (uses smart detection)
      // - No cuisine required (drinks are universal)
      return _variants.isNotEmpty && _pricingOptions.isNotEmpty;
    }

    // For special packs, different validation
    if (isSpecialPack) {
      // For special packs:
      // - Must have pack name (dish name)
      // - Must have pack price (fixed price)
      // - Must have at least one item (variant)
      // - Images required
      // - Preparation time required
      final hasImages =
          _selectedImages.isNotEmpty || _existingImageUrls.isNotEmpty;
      final hasValidPackPrice = _packPrice.isNotEmpty &&
          double.tryParse(_packPrice) != null &&
          double.parse(_packPrice) > 0;
      return _dishName.isNotEmpty &&
          hasValidPackPrice &&
          _variants.isNotEmpty &&
          hasImages &&
          _validatePreparationTime();
    }

    // For other categories, use standard validation
    // In edit mode, accept either new images OR existing image URLs
    final hasImages =
        _selectedImages.isNotEmpty || _existingImageUrls.isNotEmpty;
    return _dishName.isNotEmpty &&
        _validatePreparationTime() && // Use proper preparation time validation
        hasImages &&
        _pricingOptions.isNotEmpty; // Must have at least one pricing option
  }

  bool _validatePreparationTime() {
    if (_preparationTime.isEmpty) return false;
    final time = int.tryParse(_preparationTime);
    return time != null &&
        time >= minPreparationTime &&
        time <= maxPreparationTime;
  }

  void _updateFormValidity() {
    final wasValid = _isFormValid;
    // Check both the selected category name AND the dish name for drink/beverage keywords
    final isDrink = _category.toLowerCase().contains('drink') ||
        _category.toLowerCase().contains('beverage') ||
        _dishName.toLowerCase().contains('drink') ||
        _dishName.toLowerCase().contains('beverage');

    final requiredFieldsValid = _validateRequiredFields();

    _isFormValid = requiredFieldsValid;

    // Debug logging
    debugPrint('🔍 Form Validation Check:');
    debugPrint('  isDrink: $isDrink');
    debugPrint('  requiredFieldsValid: $requiredFieldsValid');
    debugPrint('  _isFormValid: $_isFormValid');
    debugPrint('  dishName: "$_dishName"');
    debugPrint('  category: "$_category"');
    debugPrint(
        '  mainIngredients: "$_mainIngredients" (${_mainIngredients.length} chars)');
    debugPrint('  preparationTime: "$_preparationTime"');
    debugPrint('  images: ${_selectedImages.length}');
    debugPrint('  variants: ${_variants.length}');
    debugPrint('  pricingOptions: ${_pricingOptions.length}');

    // Only notify listeners if validation state actually changed
    if (wasValid != _isFormValid) {
      notifyListeners();
    }
  }

  // Setters with validation
  void setDishName(String value) {
    _dishName = value.trim();
    _updateFormValidity();
    notifyListeners();
  }

  void setDescription(String value) {
    _description = value.trim();
    _updateFormValidity();
    notifyListeners();
  }

  void setMainIngredients(String value) {
    _mainIngredients = value.trim();
    notifyListeners();
  }

  void setCategory(String value) {
    _category = value.trim();
    _updateFormValidity();
    notifyListeners();
  }

  void setPreparationTime(String value) {
    _preparationTime = value.trim();
    _updateFormValidity();
    notifyListeners();
  }

  void setPackPrice(String value) {
    _packPrice = value.trim();
    _updateFormValidity();
    notifyListeners();
  }

  // Dietary options setters (Algerian local)
  void setHalal({required bool value}) {
    _isHalal = value;
    notifyListeners();
  }

  void setTraditional({required bool value}) {
    _isTraditional = value;
    notifyListeners();
  }

  void setSpicy({required bool value}) {
    _isSpicy = value;
    notifyListeners();
  }

  void setVegetarian({required bool value}) {
    _isVegetarian = value;
    notifyListeners();
  }

  void setGlutenFree({required bool value}) {
    _isGlutenFree = value;
    notifyListeners();
  }

  void setDairyFree({required bool value}) {
    _isDairyFree = value;
    notifyListeners();
  }

  void setLowSodium({required bool value}) {
    _isLowSodium = value;
    notifyListeners();
  }

  // Availability setters
  void setAvailable({required bool value}) {
    _isAvailable = value;
    notifyListeners();
  }

  void setFeatured({required bool value}) {
    _isFeatured = value;
    notifyListeners();
  }

  // Nutritional setters
  void setCalories(String value) {
    _calories = value.trim();
    notifyListeners();
  }

  void setProtein(String value) {
    _protein = value.trim();
    notifyListeners();
  }

  void setCarbs(String value) {
    _carbs = value.trim();
    notifyListeners();
  }

  void setFat(String value) {
    _fat = value.trim();
    notifyListeners();
  }

  void setFiber(String value) {
    _fiber = value.trim();
    notifyListeners();
  }

  void setSugar(String value) {
    _sugar = value.trim();
    notifyListeners();
  }

  // Ingredients management
  void addIngredient(String ingredient) {
    if (ingredient.trim().isNotEmpty &&
        !_ingredients.contains(ingredient.trim())) {
      _ingredients.add(ingredient.trim());
      notifyListeners();
    }
  }

  void removeIngredient(String ingredient) {
    _ingredients.remove(ingredient);
    notifyListeners();
  }

  void clearIngredients() {
    _ingredients.clear();
    notifyListeners();
  }

  // Variants management
  void addVariant(String name, String? description, {required bool isDefault}) {
    final variant = MenuItemVariant(
      id: DateTime.now().toString(),
      menuItemId: '', // Will be set when saving
      name: name,
      description: description,
      isDefault: isDefault,
      displayOrder: _variants.length,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _variants.add(variant);
    notifyListeners();
  }

  void removeVariant(String variantId) {
    _variants.removeWhere((v) => v.id == variantId);
    notifyListeners();
  }

  void updateVariant(
    String variantId, {
    String? name,
    String? description,
    bool? isDefault,
  }) {
    final index = _variants.indexWhere((v) => v.id == variantId);
    if (index != -1) {
      final variant = _variants[index];
      _variants[index] = MenuItemVariant(
        id: variant.id,
        menuItemId: variant.menuItemId,
        name: name ?? variant.name,
        description: description ?? variant.description,
        isDefault: isDefault ?? variant.isDefault,
        displayOrder: variant.displayOrder,
        createdAt: variant.createdAt,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  void clearVariants() {
    _variants.clear();
    notifyListeners();
  }

  // Pricing options management
  void addPricingOption(String size, String portion, double price,
      {required bool isDefault,
      String? variantId,
      bool freeDrinksIncluded = false,
      List<String> freeDrinksList = const []}) {
    final pricing = MenuItemPricing(
      id: DateTime.now().toString(),
      menuItemId: '', // Will be set when saving
      variantId: variantId,
      size: size,
      portion: portion,
      price: price,
      isDefault: isDefault,
      displayOrder: _pricingOptions.length,
      freeDrinksIncluded: freeDrinksIncluded,
      freeDrinksList: freeDrinksList,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _pricingOptions.add(pricing);
    _updateFormValidity();
    notifyListeners();
  }

  void removePricingOption(String pricingId) {
    _pricingOptions.removeWhere((p) => p.id == pricingId);
    notifyListeners();
  }

  void clearPricingOptions() {
    _pricingOptions.clear();
    notifyListeners();
  }

  // Supplements management
  void addSupplement(
    String name,
    String? description,
    double price, {
    List<String> availableForVariants = const [],
    String?
        supplementId, // Optional: if provided, use this ID (for restaurant supplements)
    String? menuItemId, // Optional: if provided, use this menu_item_id
    DateTime? createdAt, // Optional: if provided, use this created_at
    DateTime? updatedAt, // Optional: if provided, use this updated_at
  }) {
    final supplement = MenuItemSupplement(
      id: supplementId ?? DateTime.now().toString(),
      menuItemId: menuItemId ?? '', // Will be set when saving
      name: name,
      description: description,
      price: price,
      isAvailable: true,
      displayOrder: _supplements.length,
      availableForVariants: availableForVariants,
      createdAt: createdAt ?? DateTime.now(),
      updatedAt: updatedAt ?? DateTime.now(),
    );
    _supplements.add(supplement);
    notifyListeners();
  }

  /// Add a supplement directly (used when supplement already exists in database)
  void addExistingSupplement(MenuItemSupplement supplement) {
    _supplements.add(supplement);
    notifyListeners();
  }

  void removeSupplement(String supplementId) {
    _supplements.removeWhere((s) => s.id == supplementId);
    notifyListeners();
  }

  void updateSupplementVariants(
      String supplementId, List<String> availableForVariants) {
    final index = _supplements.indexWhere((s) => s.id == supplementId);
    if (index != -1) {
      _supplements[index] = _supplements[index].copyWith(
        availableForVariants: availableForVariants,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  void clearSupplements() {
    _supplements.clear();
    notifyListeners();
  }

  // Free drinks management (for special packs)
  void setFreeDrinks(List<String> drinkIds, {int? quantity}) {
    _freeDrinkIds.clear();
    _freeDrinkIds.addAll(drinkIds);
    if (quantity != null) {
      _freeDrinksQuantity = quantity;
    }
    debugPrint('🥤 setFreeDrinks called:');
    debugPrint('   drinkIds: $drinkIds');
    debugPrint('   quantity: $quantity');
    debugPrint('   _freeDrinkIds after: $_freeDrinkIds');
    notifyListeners();
  }

  void setFreeDrinksQuantity(int quantity) {
    _freeDrinksQuantity = quantity;
    notifyListeners();
  }

  void clearFreeDrinks() {
    _freeDrinkIds.clear();
    _freeDrinksQuantity = 1;
    notifyListeners();
  }

  // Global pack ingredients management
  void addGlobalPackIngredient(String ingredient) {
    if (ingredient.trim().isNotEmpty &&
        !_globalPackIngredients.contains(ingredient)) {
      _globalPackIngredients.add(ingredient.trim());
      notifyListeners();
    }
  }

  void removeGlobalPackIngredient(String ingredient) {
    _globalPackIngredients.remove(ingredient);
    notifyListeners();
  }

  void clearGlobalPackIngredients() {
    _globalPackIngredients.clear();
    notifyListeners();
  }

  // Global pack supplements management
  void addGlobalPackSupplement(String supplement, double price) {
    // Ensure _globalPackSupplements is a Map before adding
    if (_globalPackSupplements is! Map<String, double>) {
      _globalPackSupplements = <String, double>{};
    }
    final supplements = _globalPackSupplements as Map<String, double>;
    if (supplement.trim().isNotEmpty && !supplements.containsKey(supplement)) {
      supplements[supplement.trim()] = price;
      notifyListeners();
    }
  }

  void removeGlobalPackSupplement(String supplement) {
    // Ensure _globalPackSupplements is a Map before removing
    if (_globalPackSupplements is! Map<String, double>) {
      _globalPackSupplements = <String, double>{};
      notifyListeners();
      return;
    }
    final supplements = _globalPackSupplements as Map<String, double>;
    supplements.remove(supplement);
    notifyListeners();
  }

  void clearGlobalPackSupplements() {
    _globalPackSupplements = <String, double>{};
    notifyListeners();
  }

  // ========== Limited Time Offer Management ==========

  /// Enable or disable limited time offer
  void setLimitedOffer({required bool value}) {
    _isLimitedOffer = value;
    if (!value) {
      // Clear all offer data when disabling
      _offerTypes.clear();
      _offerStartAt = null;
      _offerEndAt = null;
      _originalPrice = null;
      _offerDetails.clear();
    }
    notifyListeners();
  }

  /// Toggle an offer type (add if not present, remove if present)
  void toggleOfferType(String type) {
    if (_offerTypes.contains(type)) {
      _offerTypes.remove(type);
      // Clear related data when removing offer type
      if (type == 'special_price') {
        _originalPrice = null;
      } else if (type == 'free_drinks') {
        _offerDetails.remove('free_drinks_list');
        _offerDetails.remove('free_drinks_quantity');
      } else if (type == 'special_delivery') {
        _offerDetails.remove('delivery_type');
        _offerDetails.remove('delivery_value');
      }
    } else {
      _offerTypes.add(type);
      // Set default values when adding offer type
      if (type == 'special_delivery') {
        _offerDetails['delivery_type'] = 'free';
        _offerDetails['delivery_value'] = 0.0;
      }
    }
    notifyListeners();
  }

  /// Set offer date range
  void setOfferDates(DateTime? start, DateTime? end) {
    _offerStartAt = start;
    _offerEndAt = end;
    notifyListeners();
  }

  /// Set original price (for special_price offers)
  void setOriginalPrice(double? price) {
    _originalPrice = price;
    notifyListeners();
  }

  /// Set offer detail value
  void setOfferDetail(String key, dynamic value) {
    _offerDetails[key] = value;
    notifyListeners();
  }

  /// Set LTO free drinks (stored in offer_details)
  void setLTOFreeDrinks(List<String> drinkIds, {int? quantity}) {
    _offerDetails['free_drinks_list'] = drinkIds;
    _offerDetails['free_drinks_quantity'] = quantity ?? 1;

    // Auto-add free_drinks offer type if drinks are selected
    if (drinkIds.isNotEmpty && !_offerTypes.contains('free_drinks')) {
      _offerTypes.add('free_drinks');
    } else if (drinkIds.isEmpty) {
      _offerTypes.remove('free_drinks');
    }

    notifyListeners();
  }

  /// Validate limited time offer data
  String? validateLimitedOffer() {
    if (!_isLimitedOffer) return null;

    if (_offerTypes.isEmpty) {
      return 'Please select at least one offer type';
    }

    if (_offerEndAt == null) {
      return 'Please set an end date for the offer';
    }

    if (_offerStartAt != null && _offerEndAt != null) {
      if (_offerEndAt!.isBefore(_offerStartAt!)) {
        return 'End date must be after start date';
      }
    }

    // Validate base price is set for LTO items with special_price offer type
    // (special packs already have their own price validation)
    if (!isSpecialPack && _offerTypes.contains('special_price')) {
      if (packPrice.isEmpty) {
        return 'Base price is required for special price offer';
      }
      final basePrice = double.tryParse(packPrice);
      if (basePrice == null || basePrice <= 0) {
        return 'Please enter a valid base price for special price offer';
      }
    }

    if (_offerTypes.contains('special_price')) {
      if (_originalPrice == null || _originalPrice! <= 0) {
        return 'Please set the original price for special price offer';
      }

      final currentPrice =
          double.tryParse(packPrice.isNotEmpty ? packPrice : '0');
      if (currentPrice != null && _originalPrice! <= currentPrice) {
        return 'Original price must be greater than offer price';
      }
    }

    if (_offerTypes.contains('special_delivery')) {
      final deliveryType = _offerDetails['delivery_type'] as String? ?? 'free';

      if (deliveryType == 'fixed' || deliveryType == 'percentage') {
        final deliveryValue = _offerDetails['delivery_value'] as double? ?? 0.0;

        if (deliveryValue <= 0) {
          return 'Please set a ${deliveryType == 'fixed' ? 'discount amount' : 'discount percentage'} for special delivery';
        }

        if (deliveryType == 'percentage' && deliveryValue > 100) {
          return 'Percentage discount cannot exceed 100%';
        }
      }
    }

    return null;
  }

  /// Clear all LTO data
  void clearLimitedOffer() {
    _isLimitedOffer = false;
    _offerTypes.clear();
    _offerStartAt = null;
    _offerEndAt = null;
    _originalPrice = null;
    _offerDetails.clear();
    notifyListeners();
  }

  // Supplement variants management
  void addSupplementVariant(
      String supplementId, String name, String? description, double price,
      {required bool isDefault}) {
    final index = _supplements.indexWhere((s) => s.id == supplementId);
    if (index != -1) {
      final supplement = _supplements[index];
      final variant = SupplementVariant(
        id: DateTime.now().toString(),
        supplementId: supplementId,
        name: name,
        description: description,
        price: price,
        isDefault: isDefault,
        displayOrder: supplement.variants.length,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final updatedVariants = List<SupplementVariant>.from(supplement.variants)
        ..add(variant);
      _supplements[index] = supplement.copyWith(
        variants: updatedVariants,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  void removeSupplementVariant(String supplementId, String variantId) {
    final index = _supplements.indexWhere((s) => s.id == supplementId);
    if (index != -1) {
      final supplement = _supplements[index];
      final updatedVariants =
          supplement.variants.where((v) => v.id != variantId).toList();
      _supplements[index] = supplement.copyWith(
        variants: updatedVariants,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  void updateSupplementVariant(String supplementId, String variantId,
      String name, String? description, double price) {
    final index = _supplements.indexWhere((s) => s.id == supplementId);
    if (index != -1) {
      final supplement = _supplements[index];
      final updatedVariants = supplement.variants.map((v) {
        if (v.id == variantId) {
          return v.copyWith(
            name: name,
            description: description,
            price: price,
            updatedAt: DateTime.now(),
          );
        }
        return v;
      }).toList();

      _supplements[index] = supplement.copyWith(
        variants: updatedVariants,
        updatedAt: DateTime.now(),
      );
      notifyListeners();
    }
  }

  // Tags management
  void addTag(String tag) {
    if (tag.trim().isNotEmpty && !_tags.contains(tag.trim())) {
      _tags.add(tag.trim());
      notifyListeners();
    }
  }

  void removeTag(String tag) {
    _tags.remove(tag);
    notifyListeners();
  }

  void clearTags() {
    _tags.clear();
    notifyListeners();
  }

  // Customization options management
  void addCustomizationOption(String option) {
    if (option.trim().isNotEmpty &&
        !_customizationOptions.contains(option.trim())) {
      _customizationOptions.add(option.trim());
      notifyListeners();
    }
  }

  void removeCustomizationOption(String option) {
    _customizationOptions.remove(option);
    notifyListeners();
  }

  void clearCustomizationOptions() {
    _customizationOptions.clear();
    notifyListeners();
  }

  // Add-on prices management
  void setAddOnPrice(String addOn, double price) {
    _addOnPrices[addOn] = price;
    notifyListeners();
  }

  void removeAddOnPrice(String addOn) {
    _addOnPrices.remove(addOn);
    notifyListeners();
  }

  void clearAddOnPrices() {
    _addOnPrices.clear();
    notifyListeners();
  }

  // Image management
  void addImage(File image) {
    _selectedImages.add(image);
    _updateFormValidity();
    notifyListeners();
  }

  void removeImage(File image) {
    _selectedImages.remove(image);
    _updateFormValidity();
    notifyListeners();
  }

  void clearImages() {
    _selectedImages.clear();
    _updateFormValidity();
    notifyListeners();
  }

  // Existing image URLs management (for edit mode)
  void addExistingImageUrl(String url) {
    if (url.isNotEmpty && !_existingImageUrls.contains(url)) {
      _existingImageUrls.add(url);
      _updateFormValidity();
      notifyListeners();
    }
  }

  void removeExistingImageUrl(String url) {
    _existingImageUrls.remove(url);
    _updateFormValidity();
    notifyListeners();
  }

  void clearExistingImageUrls() {
    _existingImageUrls.clear();
    _updateFormValidity();
    notifyListeners();
  }

  // Upload state management
  void setUploadingState({required bool isUploading}) {
    _isUploadingImages = isUploading;
    notifyListeners();
  }

  void setUploadProgress(double progress) {
    _uploadProgress = progress;
    notifyListeners();
  }

  void setSubmittingState({required bool isSubmitting}) {
    _isSubmitting = isSubmitting;
    notifyListeners();
  }

  // Form data preparation - include all enhanced fields
  Map<String, dynamic> getFormData() {
    // For drinks, use the category name or first variant name as the dish name
    final isDrink = _category.toLowerCase().contains('drink') ||
        _category.toLowerCase().contains('beverage') ||
        _dishName.toLowerCase().contains('drink') ||
        _dishName.toLowerCase().contains('beverage');

    final effectiveDishName = isDrink
        ? (_category.isNotEmpty
            ? _category
            : (_variants.isNotEmpty ? _variants.first.name : 'Drinks'))
        : _dishName;

    return {
      'name': effectiveDishName,
      'description': _description.isNotEmpty ? _description : null,
      'main_ingredients': _mainIngredients.isNotEmpty ? _mainIngredients : null,
      'category': _category, // Use the actual selected category, not dish name
      'preparation_time': isDrink
          ? drinkPreparationTime
          : (int.tryParse(_preparationTime) ??
              defaultPreparationTime), // Drinks have instant prep time
      'ingredients': _ingredients,
      'is_available': _isAvailable,
      'is_featured': _isFeatured,
      'is_spicy': _isSpicy,
      'is_traditional': _isTraditional,
      'is_vegetarian': _isVegetarian,
      'is_vegan': false, // Will be calculated based on ingredients
      'is_gluten_free': _isGlutenFree,
      'variants': _variants.map((v) => v.toJson()).toList(),
      'pricing_options': _pricingOptions.map((p) => p.toJson()).toList(),
      'supplements': _supplements.map((s) => s.toJson()).toList(),
    };
  }

  // Reset form
  void resetForm() {
    _dishName = '';
    _description = '';
    _mainIngredients = '';
    _category = '';
    _preparationTime = '';
    _packPrice = '';
    _ingredients.clear();
    _selectedImages.clear();
    _existingImageUrls.clear();
    _variants.clear();
    _pricingOptions.clear();
    _supplements.clear();
    _freeDrinkIds.clear();

    // Reset dietary options
    _isHalal = false;
    _isTraditional = false;
    _isSpicy = false;
    _isVegetarian = false;
    _isGlutenFree = false;
    _isDairyFree = false;
    _isLowSodium = false;

    // Reset availability
    _isAvailable = true;
    _isFeatured = false;

    // Reset Limited Time Offer data
    _isLimitedOffer = false;
    _offerTypes.clear();
    _offerStartAt = null;
    _offerEndAt = null;
    _originalPrice = null;
    _offerDetails.clear();

    _isFormValid = false;
    _isSubmitting = false;
    _isUploadingImages = false;
    _uploadProgress = 0.0;

    notifyListeners();
  }

  // Validation error messages
  String? getDishNameError() {
    if (_dishName.isEmpty) return 'Dish name is required';
    return null;
  }

  String? getDescriptionError() {
    // Description is optional
    return null;
  }

  String? getCategoryError() {
    if (_category.isEmpty) return 'Category is required';
    return null;
  }

  String? getPreparationTimeError() {
    if (_preparationTime.isEmpty) return 'Preparation time is required';
    if (!_validatePreparationTime()) {
      return 'Preparation time must be between $minPreparationTime and $maxPreparationTime minutes';
    }
    return null;
  }

  String? getImagesError() {
    // In edit mode, existing images count too
    if (_selectedImages.isEmpty && _existingImageUrls.isEmpty) {
      return 'At least one image is required';
    }
    return null;
  }

  // Algerian food categories
  static const List<String> categories = [
    'Traditional',
    'Spicy',
    'Dessert',
    'Drink',
    'Fast Food',
    'Seafood',
    'Vegetarian',
  ];

  // Common tags
  static const List<String> commonTags = [
    'Healthy',
    'Spicy',
    'Mild',
    'Fresh',
    'Organic',
    'Local',
    'Seasonal',
    'Comfort Food',
    'Light',
    'Rich',
    'Crispy',
    'Creamy',
    'Grilled',
    'Fried',
    'Baked',
    'Steamed',
  ];
}
