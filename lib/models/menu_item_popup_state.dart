import 'enhanced_menu_item.dart';
import 'ingredient_preference.dart';
import 'menu_item.dart';
import 'menu_item_pricing.dart';
import 'menu_item_supplement.dart';
import 'order_item.dart';

/// State model for MenuItemFullPopup
/// Contains all state variables that were previously in _MenuItemFullPopupState
class MenuItemPopupState {
  // Variant and pricing state
  final Set<String> selectedVariants;
  final Map<String, MenuItemPricing> selectedPricingPerVariant;
  final Map<String, int> variantQuantities;

  // Supplement state
  final List<MenuItemSupplement> selectedSupplements;

  // Ingredient customization state
  final List<String> removedIngredients;
  final Map<String, IngredientPreference> ingredientPreferences;

  // Pack-specific state
  final Map<String, Map<int, Map<String, IngredientPreference>>>
      packIngredientPreferences;
  final Map<String, Map<int, String>> packItemSelections;

  // Drinks state
  final List<MenuItem> selectedDrinks;
  final Map<String, int> drinkQuantities; // FREE drinks
  final Map<String, int> paidDrinkQuantities; // PAID drinks
  final Map<String, String> drinkSizesById;

  // Saved orders
  final List<OrderItem> savedOrders;
  final Map<String, List<Map<String, dynamic>>> savedVariantOrders;

  // General state
  int quantity;
  String specialNote;
  final Map<String, String> variantNotes;

  // Loading state
  bool isLoading;
  bool isLoadingVariants;
  bool isLoadingSupplements;
  bool isLoadingDrinks;
  String? loadingError;

  // Data state
  EnhancedMenuItem? enhancedMenuItem;
  List<MenuItem> restaurantDrinks;

  // Image gallery state
  int currentImagePage;

  // Updated rating
  double? updatedRating;
  int? updatedReviewCount;

  // Expanded variant tracking
  int? expandedVariantIndex;

  // Cache
  final Map<String, String> drinkImageCache;

  MenuItemPopupState({
    this.selectedVariants = const {},
    this.selectedPricingPerVariant = const {},
    this.variantQuantities = const {},
    this.selectedSupplements = const [],
    this.removedIngredients = const [],
    this.ingredientPreferences = const {},
    this.packIngredientPreferences = const {},
    this.packItemSelections = const {},
    this.selectedDrinks = const [],
    this.drinkQuantities = const {},
    this.paidDrinkQuantities = const {},
    this.drinkSizesById = const {},
    this.savedOrders = const [],
    this.savedVariantOrders = const {},
    this.quantity = 1,
    this.specialNote = '',
    this.variantNotes = const {},
    this.isLoading = false,
    this.isLoadingVariants = false,
    this.isLoadingSupplements = false,
    this.isLoadingDrinks = false,
    this.loadingError,
    this.enhancedMenuItem,
    this.restaurantDrinks = const [],
    this.currentImagePage = 0,
    this.updatedRating,
    this.updatedReviewCount,
    this.expandedVariantIndex,
    this.drinkImageCache = const {},
  });

  MenuItemPopupState copyWith({
    Set<String>? selectedVariants,
    Map<String, MenuItemPricing>? selectedPricingPerVariant,
    Map<String, int>? variantQuantities,
    List<MenuItemSupplement>? selectedSupplements,
    List<String>? removedIngredients,
    Map<String, IngredientPreference>? ingredientPreferences,
    Map<String, Map<int, Map<String, IngredientPreference>>>?
        packIngredientPreferences,
    Map<String, Map<int, String>>? packItemSelections,
    List<MenuItem>? selectedDrinks,
    Map<String, int>? drinkQuantities,
    Map<String, int>? paidDrinkQuantities,
    Map<String, String>? drinkSizesById,
    List<OrderItem>? savedOrders,
    Map<String, List<Map<String, dynamic>>>? savedVariantOrders,
    int? quantity,
    String? specialNote,
    Map<String, String>? variantNotes,
    bool? isLoading,
    bool? isLoadingVariants,
    bool? isLoadingSupplements,
    bool? isLoadingDrinks,
    String? loadingError,
    bool clearLoadingError = false,
    EnhancedMenuItem? enhancedMenuItem,
    List<MenuItem>? restaurantDrinks,
    int? currentImagePage,
    double? updatedRating,
    int? updatedReviewCount,
    int? expandedVariantIndex,
    Map<String, String>? drinkImageCache,
  }) {
    return MenuItemPopupState(
      selectedVariants: selectedVariants ?? this.selectedVariants,
      selectedPricingPerVariant:
          selectedPricingPerVariant ?? this.selectedPricingPerVariant,
      variantQuantities: variantQuantities ?? this.variantQuantities,
      selectedSupplements: selectedSupplements ?? this.selectedSupplements,
      removedIngredients: removedIngredients ?? this.removedIngredients,
      ingredientPreferences:
          ingredientPreferences ?? this.ingredientPreferences,
      packIngredientPreferences:
          packIngredientPreferences ?? this.packIngredientPreferences,
      packItemSelections: packItemSelections ?? this.packItemSelections,
      selectedDrinks: selectedDrinks ?? this.selectedDrinks,
      drinkQuantities: drinkQuantities ?? this.drinkQuantities,
      paidDrinkQuantities: paidDrinkQuantities ?? this.paidDrinkQuantities,
      drinkSizesById: drinkSizesById ?? this.drinkSizesById,
      savedOrders: savedOrders ?? this.savedOrders,
      savedVariantOrders: savedVariantOrders ?? this.savedVariantOrders,
      quantity: quantity ?? this.quantity,
      specialNote: specialNote ?? this.specialNote,
      variantNotes: variantNotes ?? this.variantNotes,
      isLoading: isLoading ?? this.isLoading,
      isLoadingVariants: isLoadingVariants ?? this.isLoadingVariants,
      isLoadingSupplements: isLoadingSupplements ?? this.isLoadingSupplements,
      isLoadingDrinks: isLoadingDrinks ?? this.isLoadingDrinks,
      loadingError:
          clearLoadingError ? null : (loadingError ?? this.loadingError),
      enhancedMenuItem: enhancedMenuItem ?? this.enhancedMenuItem,
      restaurantDrinks: restaurantDrinks ?? this.restaurantDrinks,
      currentImagePage: currentImagePage ?? this.currentImagePage,
      updatedRating: updatedRating ?? this.updatedRating,
      updatedReviewCount: updatedReviewCount ?? this.updatedReviewCount,
      expandedVariantIndex: expandedVariantIndex ?? this.expandedVariantIndex,
      drinkImageCache: drinkImageCache ?? this.drinkImageCache,
    );
  }
}
