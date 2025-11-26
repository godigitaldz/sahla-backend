import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../cart_provider.dart';
import '../l10n/app_localizations.dart';
import '../models/enhanced_menu_item.dart';
import '../models/ingredient_preference.dart';
import '../models/menu_item.dart';
import '../models/menu_item_customizations.dart';
import '../models/menu_item_pricing.dart';
import '../models/menu_item_supplement.dart';
import '../models/menu_item_variant.dart';
import '../models/order_item.dart';
import '../models/restaurant.dart';
import '../services/enhanced_menu_item_service.dart';
import '../services/socket_service.dart';
import '../utils/bottom_padding.dart';
import '../utils/price_formatter.dart';
import '../widgets/menu_item_full_popup/helpers/popup_type_helper.dart';
import '../widgets/menu_item_full_popup/helpers/regular_item_helper.dart';
import '../widgets/menu_item_full_popup/helpers/special_pack_helper.dart';
import '../widgets/menu_item_full_popup/shared_widgets/drink_quantity_selector.dart';
import '../widgets/menu_item_full_popup/shared_widgets/ingredient_preferences_container.dart';
import '../widgets/menu_item_full_popup/shared_widgets/menu_item_image_section.dart';
import '../widgets/menu_item_full_popup/shared_widgets/unified_sizes_container.dart';
import '../widgets/menu_item_full_popup/shared_widgets/unified_supplements_container.dart';
import '../widgets/menu_item_full_popup/special_pack_widgets/helpers/pack_state_helper.dart';
import '../widgets/menu_item_full_popup/special_pack_widgets/methods/add_to_cart.dart';
import '../widgets/menu_item_full_popup/special_pack_widgets/methods/build_drink_image.dart';
import '../widgets/menu_item_full_popup/special_pack_widgets/methods/build_loading_state.dart';
import '../widgets/menu_item_full_popup/special_pack_widgets/methods/build_pack_item_row.dart';
import '../widgets/menu_item_full_popup/special_pack_widgets/methods/build_ui_helpers.dart';
import '../widgets/menu_item_full_popup/special_pack_widgets/methods/edit_order_integration.dart';
import '../widgets/menu_item_full_popup/special_pack_widgets/methods/edit_order_manager.dart';
import '../widgets/menu_item_full_popup/special_pack_widgets/methods/navigate_to_confirm_flow/add_current_special_pack_selections.dart';
import '../widgets/menu_item_full_popup/special_pack_widgets/methods/navigate_to_confirm_flow/add_current_variant_selections.dart';
import '../widgets/menu_item_full_popup/special_pack_widgets/methods/navigate_to_confirm_flow/add_saved_orders.dart';
import '../widgets/menu_item_full_popup/special_pack_widgets/methods/navigate_to_confirm_flow/add_saved_unified_pack_orders.dart';
import '../widgets/menu_item_full_popup/special_pack_widgets/methods/navigate_to_confirm_flow/add_saved_variant_orders.dart';
import '../widgets/menu_item_full_popup/special_pack_widgets/methods/navigate_to_confirm_flow/add_single_item.dart';
import '../widgets/menu_item_full_popup/special_pack_widgets/methods/navigate_to_confirm_flow/calculate_paid_drinks_price.dart';
import '../widgets/menu_item_full_popup/special_pack_widgets/methods/navigate_to_confirm_flow/navigate_to_cart.dart';
import '../widgets/menu_item_full_popup/special_pack_widgets/methods/navigate_to_confirm_flow/navigate_to_confirm_flow_params.dart';
import '../widgets/menu_item_full_popup/special_pack_widgets/methods/pre_populate_from_cart_item.dart';
import '../widgets/menu_item_full_popup/special_pack_widgets/methods/save_and_add_another_order.dart';
import '../widgets/menu_item_full_popup/special_pack_widgets/methods/submit_order.dart';
import '../widgets/menu_item_full_popup/special_pack_widgets/selector.dart';
import '../widgets/menu_item_full_popup/special_pack_widgets/skeleton_widget.dart';
import '../widgets/menu_item_full_popup/special_pack_widgets/unified_pack_items_options_container.dart';

/// Unified Menu Item Popup Widget
/// Handles all menu item types: special packs, LTO regular items, and regular items
class MenuItemPopupWidget extends StatefulWidget {
  final MenuItem menuItem;
  final Restaurant? restaurant;
  final Function(OrderItem)? onItemAddedToCart;
  final CartItem? existingCartItem; // For editing existing orders
  final String?
      originalOrderItemId; // For preserving order item ID when editing
  final VoidCallback? onDataChanged; // Callback when data changes
  final String?
      preSelectedVariantName; // Pre-selected variant name from tapped card

  const MenuItemPopupWidget({
    required this.menuItem,
    super.key,
    this.restaurant,
    this.onItemAddedToCart,
    this.existingCartItem,
    this.originalOrderItemId,
    this.onDataChanged,
    this.preSelectedVariantName,
  });

  @override
  State<MenuItemPopupWidget> createState() => _MenuItemPopupWidgetState();
}

class _MenuItemPopupWidgetState extends State<MenuItemPopupWidget>
    with TickerProviderStateMixin {
  late EnhancedMenuItemService _menuItemService;
  SharedPreferences? _prefs;

  // Real-time services
  late SocketService _socketService;

  // Subscriptions
  StreamSubscription? _menuItemUpdatesSubscription;

  // Drink image cache for fast loading
  final Map<String, String> _drinkImageCache = {};

  // Error message state
  String? _errorMessage;

  // Current menu item (can be updated when data changes)
  late MenuItem _currentMenuItem;

  // State management
  final Set<String> _selectedVariants = {}; // Multiple variant IDs
  final Map<String, MenuItemPricing> _selectedPricingPerVariant =
      {}; // Per-variant pricing
  final List<MenuItemSupplement> _selectedSupplements = [];
  final List<String> _removedIngredients = [];
  final Map<String, IngredientPreference> _ingredientPreferences = {};
  final List<OrderItem> _savedOrders = [];
  final List<MenuItem> _selectedDrinks = [];
  final Map<String, int> _drinkQuantities =
      {}; // Track quantity for FREE drinks only
  final Map<String, int> _paidDrinkQuantities =
      {}; // Track quantity for PAID drinks
  final Map<String, String> _drinkSizesById =
      {}; // Default size label per drink id
  int _quantity = 1;
  bool _isLoading = false;
  String _specialNote = '';

  // Special pack ingredient preferences
  // Map<variant_id, Map<quantity_index, Map<ingredient, preference>>>
  final Map<String, Map<int, Map<String, IngredientPreference>>>
      _packIngredientPreferences = {};

  // Group all items added from the same popup session
  late final String _popupSessionId;

  // Special pack state
  // Map<variant_id, Map<quantity_index, selected_option>>
  final Map<String, Map<int, String>> _packItemSelections =
      <String, Map<int, String>>{};

  // Map<variant_id, Map<quantity_index, Set<supplement_name>>>
  final Map<String, Map<int, Set<String>>> _packSupplementSelections =
      <String, Map<int, Set<String>>>{};

  // Item type detection using PopupTypeHelper
  bool get _isSpecialPack => PopupTypeHelper.isSpecialPack(widget.menuItem);

  // Progressive loading stages
  bool _isLoadingVariants = false;
  bool _isLoadingSupplements = false;
  bool _isLoadingDrinks = false;
  String? _loadingError;

  // Enhanced menu item data
  EnhancedMenuItem? _enhancedMenuItem;
  List<MenuItem> _restaurantDrinks = [];

  // Animation
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  // Image gallery
  PageController? _imagePageController;
  int _currentImagePage = 0;

  // Updated rating and review count (refreshed after review submission)
  double? _updatedRating;
  int? _updatedReviewCount;

  // Quantity per variant in sliver box
  final Map<String, int> _variantQuantities = {};

  // Note per variant
  final Map<String, String> _variantNotes = {};
  final Map<String, TextEditingController> _variantNoteControllers = {};

  // Special note controller for special packs
  late final TextEditingController _specialNoteController;

  // Saved variant orders (per variant)
  final Map<String, List<Map<String, dynamic>>> _savedVariantOrders = {};

  // 🎯 Edit Order State Manager (for edit mode)
  EditOrderStateManager? _editOrderManager;

  // Color scheme - Orange and White theme
  static const Color primaryOrange = Color(0xFFFF6B35);
  static const Color cardColor = Colors.white;
  static const Color textPrimary = Color(0xFF2E2E2E);
  static const Color textSecondary = Color(0xFF757575);

  // Cache expensive computed values
  String get _prefsKey =>
      'menu_item_popup_${widget.menuItem.id}_${_currentUserId()}';

  @override
  void initState() {
    super.initState();
    _specialNoteController = TextEditingController(text: _specialNote);

    // Initialize current menu item
    _currentMenuItem = widget.menuItem;

    debugPrint('🛒 MenuItemPopupWidget initState called');
    debugPrint(
        '🛒 Item type: ${PopupTypeHelper.getItemTypeLabel(widget.menuItem)}');
    PopupTypeHelper.logItemType(widget.menuItem);
    debugPrint('🛒 existingCartItem: ${widget.existingCartItem?.name}');
    debugPrint(
        '🛒 existingCartItem quantity: ${widget.existingCartItem?.quantity}');
    debugPrint(
        '🛒 existingCartItem customizations: ${widget.existingCartItem?.customizations}');
    debugPrint('🛒 Initial _quantity: $_quantity');

    // Validate input data
    if (!_validateMenuItemData(widget.menuItem)) {
      _handleDataError(
          'MenuItemPopupWidget.initState', 'Invalid MenuItem data');
    }

    if (!_validateRestaurantData(widget.restaurant)) {
      _handleDataError(
          'MenuItemFullPopup.initState', 'Invalid Restaurant data');
    }

    if (widget.existingCartItem != null &&
        !_validateCustomizationData(widget.existingCartItem!.customizations)) {
      _handleDataError(
          'MenuItemFullPopup.initState', 'Invalid CartItem customization data');
    }

    // Set quantity immediately if editing existing cart item
    if (widget.existingCartItem != null) {
      _quantity = widget.existingCartItem!.quantity;
      debugPrint(
          '🛒 MenuItemPopupWidget: Set initial quantity to ${widget.existingCartItem!.quantity}');
      debugPrint(
          '🛒 MenuItemPopupWidget: CartItem details - name: ${widget.existingCartItem!.name}, price: ${widget.existingCartItem!.price}, quantity: ${widget.existingCartItem!.quantity}');
    }

    debugPrint(
        '🛒 MenuItemPopupWidget: Final _quantity after initState: $_quantity');

    _menuItemService = EnhancedMenuItemService();

    // Initialize animations
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    _animationController.forward();

    // Initialize data and services
    _initializeData();
    _initializeRealTimeServices();
  }

  void _initializeRealTimeServices() {
    try {
      // Initialize services
      _socketService = Provider.of<SocketService>(context, listen: false);

      // Set up real-time listeners
      _setupRealTimeListeners();
    } catch (e) {
      debugPrint('❌ Error initializing menu item popup services: $e');
    }
  }

  void _setupRealTimeListeners() {
    // Listen for menu item updates
    _menuItemUpdatesSubscription =
        _socketService.notificationStream.listen((data) {
      if (data['type'] == 'menu_item_update' &&
          data['itemId'] == widget.menuItem.id) {
        _handleMenuItemUpdate(data);
      }
    });
  }

  void _handleMenuItemUpdate(Map<String, dynamic> data) {
    // Handle menu item updates - refresh menu item data when images are updated
    if (data.containsKey('image') || data.containsKey('images')) {
      _refreshMenuItem();
    }
  }

  /// Refresh menu item data when images are edited
  Future<void> _refreshMenuItem() async {
    try {
      debugPrint('🔄 Refreshing menu item data for image updates...');

      // Reload enhanced menu item to get updated image data
      final updatedEnhancedMenuItem = await _menuItemService.getEnhancedMenuItem(
        widget.menuItem.id,
      );

      if (mounted) {
        setState(() {
          _enhancedMenuItem = updatedEnhancedMenuItem;
          _currentMenuItem = updatedEnhancedMenuItem.toMenuItem();
        });
        debugPrint('✅ Menu item refreshed successfully');

        // Call onDataChanged callback if provided
        widget.onDataChanged?.call();
      }
    } catch (e) {
      debugPrint('❌ Error refreshing menu item: $e');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _imagePageController?.dispose();
    // Clean up edit order manager
    _editOrderManager?.clear();

    // Dispose all variant note controllers
    for (final controller in _variantNoteControllers.values) {
      controller.dispose();
    }

    // Dispose special note controller
    _specialNoteController.dispose();

    // Clear all popup state to avoid caching when closing
    _clearPreferences();
    _selectedVariants.clear();
    _selectedPricingPerVariant.clear();
    _selectedSupplements.clear();
    _removedIngredients.clear();
    _ingredientPreferences.clear();
    _savedOrders.clear();
    _selectedDrinks.clear();
    _drinkQuantities.clear();
    _paidDrinkQuantities.clear();
    _drinkSizesById.clear();
    _variantQuantities.clear();
    _variantNotes.clear();
    _savedVariantOrders.clear();
    _packSupplementSelections.clear();
    _enhancedMenuItem = null;
    // PERFORMANCE FIX: Clear cached formatted prices
    _cachedFormattedPrices = null;
    _cachedSavedOrdersHashCode = null;

    // Clean up real-time subscriptions
    _menuItemUpdatesSubscription?.cancel();

    super.dispose();
  }

  Future<void> _initializeData() async {
    _popupSessionId = DateTime.now().millisecondsSinceEpoch.toString();

    // ✅ PERFORMANCE: Load SharedPreferences in background (non-blocking)
    unawaited(SharedPreferences.getInstance().then((prefs) {
      _prefs = prefs;
    }).catchError((_) {}));

    // Drink image cache is managed by buildDrinkImage helper

    // Show UI immediately with basic fallback data
    if (mounted) {
      setState(() {
        _isLoading = false; // Show UI immediately
        _loadingError = null;
        _isLoadingVariants = true; // Show loading indicators for sections
        _isLoadingSupplements = true;
        _isLoadingDrinks = true;

        // Don't pre-populate here - wait for enhancedMenuItem to load
      });
    }

    // ✅ PERFORMANCE: Load enhanced data and drinks in parallel (removed artificial delay)
    try {
      final results = await Future.wait([
        _menuItemService.getEnhancedMenuItem(widget.menuItem.id),
        _loadRestaurantDrinksOptimized(), // Optimized version
      ], eagerError: false);

      _enhancedMenuItem = results[0] as EnhancedMenuItem?;

      if (mounted) {
        setState(() {
          // ✅ NEW EDIT LOGIC: Initialize EditOrderStateManager for edit mode
          if (widget.existingCartItem != null && _enhancedMenuItem != null) {
            debugPrint(
                '🔗 MenuItemPopupWidget: Initializing edit order manager');

            // Create popup state variables container
            final popupState = PopupStateVariables(
              selectedVariants: _selectedVariants,
              selectedPricingPerVariant: _selectedPricingPerVariant,
              selectedSupplements: _selectedSupplements,
              removedIngredients: _removedIngredients,
              ingredientPreferences: _ingredientPreferences,
              selectedDrinks: _selectedDrinks,
              drinkQuantities: _drinkQuantities,
              paidDrinkQuantities: _paidDrinkQuantities,
              drinkSizesById: _drinkSizesById,
              packItemSelections: _packItemSelections,
              packIngredientPreferences: _packIngredientPreferences,
              packSupplementSelections: _packSupplementSelections,
              savedVariantOrders: _savedVariantOrders,
              quantity: _quantity,
              specialNote: _specialNote,
            );

            // Initialize EditOrderStateManager from cart item
            // ✅ FIX: Get all cart items to find global paid drinks
            final cartProvider =
                Provider.of<CartProvider>(context, listen: false);
            final allCartItems = cartProvider.items;

            _editOrderManager = EditOrderBridge.initializeFromCartItem(
              cartItem: widget.existingCartItem!,
              enhancedMenuItem: _enhancedMenuItem,
              restaurantDrinks: _restaurantDrinks,
              sessionId: _popupSessionId,
              popupState: popupState,
              allCartItems:
                  allCartItems, // Pass all cart items to find global paid drinks
            );

            debugPrint('✅ MenuItemPopupWidget: Edit order manager initialized');

            // ✅ FIX: Ensure at least one variant is selected after pre-population
            // This ensures form sections are visible when editing
            if (_selectedVariants.isEmpty &&
                _enhancedMenuItem!.variants.isNotEmpty) {
              final firstVariant = _enhancedMenuItem!.variants.first;
              _selectedVariants.add(firstVariant.id);
              debugPrint(
                  '✅ Auto-selected first variant after pre-population: ${firstVariant.name}');

              // ✅ FIX: Don't auto-select pricing for LTO regular items (size is optional)
              final isLTORegular =
                  widget.menuItem.isLimitedOffer && !_isSpecialPack;
              if (!isLTORegular &&
                  !_selectedPricingPerVariant.containsKey(firstVariant.id)) {
                final variantPricings = _enhancedMenuItem!.pricing
                    .where((p) => p.variantId == firstVariant.id)
                    .toList();
                if (variantPricings.isNotEmpty) {
                  _selectedPricingPerVariant[firstVariant.id] =
                      variantPricings.first;
                }
              }
            }
          } else if (widget.existingCartItem != null &&
              _enhancedMenuItem == null) {
            // Fallback to legacy pre-population if enhancedMenuItem not loaded yet
            debugPrint(
                '⚠️ MenuItemPopupWidget: Using legacy pre-population (enhancedMenuItem not loaded)');
            _prePopulateFromCartItem(widget.existingCartItem!);
          }

          // Set default selections - prioritize pre-selected variant from tapped card
          // Only if NOT editing (editing should use restored data)
          if (widget.existingCartItem == null &&
              widget.preSelectedVariantName != null &&
              _enhancedMenuItem?.variants.isNotEmpty == true) {
            // Find the variant matching the pre-selected name
            final matchingVariants = _enhancedMenuItem!.variants.where((v) =>
                v.name.toLowerCase() ==
                widget.preSelectedVariantName!.toLowerCase());
            if (matchingVariants.isNotEmpty) {
              final variantId = matchingVariants.first.id;
              _selectedVariants.add(variantId);
              // Initialize quantity for this variant if not exists
              if (!_variantQuantities.containsKey(variantId)) {
                _variantQuantities[variantId] = 1;
              }
              debugPrint(
                  '🎯 Pre-selected variant from tapped card: ${matchingVariants.first.name}');
            } else if (_enhancedMenuItem?.defaultVariant != null) {
              // Fallback to default if pre-selected variant not found
              final variantId = _enhancedMenuItem!.defaultVariant!.id;
              _selectedVariants.add(variantId);
              // Initialize quantity for this variant if not exists
              if (!_variantQuantities.containsKey(variantId)) {
                _variantQuantities[variantId] = 1;
              }
              debugPrint(
                  '⚠️ Pre-selected variant "${widget.preSelectedVariantName}" not found, using default');
            }
          } else if (_enhancedMenuItem?.defaultVariant != null) {
            // No pre-selection, use default variant
            final variantId = _enhancedMenuItem!.defaultVariant!.id;
            _selectedVariants.add(variantId);
            // Initialize quantity for this variant if not exists
            if (!_variantQuantities.containsKey(variantId)) {
              _variantQuantities[variantId] = 1;
            }
          }

          // ✅ FIX: Set default pricing for each selected variant (skip for LTO regular items)
          // For LTO regular items, size is optional, so don't auto-select pricing
          final isLTORegular =
              widget.menuItem.isLimitedOffer && !_isSpecialPack;
          if (!isLTORegular) {
            for (final variantId in _selectedVariants) {
              if (_selectedPricingPerVariant.containsKey(variantId)) {
                continue; // Already has pricing (from saved prefs)
              }

              if (_enhancedMenuItem?.pricing.isNotEmpty == true) {
                final variantPricing = _enhancedMenuItem!.pricing
                    .where((p) => p.variantId == variantId)
                    .toList();

                if (variantPricing.isNotEmpty) {
                  _selectedPricingPerVariant[variantId] = variantPricing.first;
                  debugPrint(
                      '🛒 _initializeData: Selected pricing for variant $variantId');
                } else if (_enhancedMenuItem?.defaultPricing != null) {
                  _selectedPricingPerVariant[variantId] =
                      _enhancedMenuItem!.defaultPricing!;
                  debugPrint(
                      '🛒 _initializeData: Using default pricing for variant $variantId');
                } else if (_enhancedMenuItem!.pricing.isNotEmpty) {
                  _selectedPricingPerVariant[variantId] =
                      _enhancedMenuItem!.pricing.first;
                  debugPrint(
                      '🛒 _initializeData: Using first available pricing for variant $variantId');
                }
              }
            }
          }

          debugPrint('🛒 _initializeData: Enhanced menu item loaded');
          debugPrint('  _selectedVariants: $_selectedVariants');
          debugPrint(
              '  _selectedPricingPerVariant: ${_selectedPricingPerVariant.keys.toList()}');

          // ✅ FIX: Auto-select first option for all variants in special pack mode (only for new items)
          // Note: This must be called within setState to update the UI
          if (widget.existingCartItem == null && _enhancedMenuItem != null) {
            final isSpecialPack =
                SpecialPackHelper.isSpecialPack(widget.menuItem);
            if (isSpecialPack) {
              _autoSelectFirstOptionForAllVariants();
            }
          }

          _isLoadingVariants = false;
          _isLoadingSupplements = false;
          _isLoadingDrinks = false;
        });

        // ✅ EDIT LOGIC: Don't auto-select free drinks when editing (user already has selections)
        if (widget.existingCartItem == null) {
          // Auto-select single free drink with max quantity if available (only for new items)
          _autoSelectSingleFreeDrink();
        }
      }

      // ✅ PERFORMANCE: Load saved user preferences in background (non-blocking, deferred)
      unawaited(_mergeSavedPreferences().catchError((_) {}));
    } catch (e) {
      debugPrint('Error loading enhanced menu item: $e');
      if (mounted) {
        setState(() {
          _loadingError = e.toString();
          _isLoadingVariants = false;
          _isLoadingSupplements = false;
          _isLoadingDrinks = false;
        });
      }
    }
  }

  String _currentUserId() {
    try {
      return supa.Supabase.instance.client.auth.currentUser?.id ?? 'guest';
    } catch (_) {
      return 'guest';
    }
  }

  Future<void> _mergeSavedPreferences() async {
    // Disabled: do not merge any saved preferences
    return;
  }

  Future<void> _clearPreferences() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.remove(_prefsKey);
    } catch (_) {}
  }

  // ✅ PERFORMANCE: Optimized version - filter at database level when possible
  Future<void> _loadRestaurantDrinksOptimized() async {
    try {
      final supabase = Supabase.instance.client;

      // ✅ PERFORMANCE: Try to filter drinks at database level (more efficient)
      try {
        final response = await supabase
            .from('menu_items')
            .select('*')
            .eq('restaurant_id', widget.menuItem.restaurantId)
            .eq('is_available', true)
            .or('category.ilike.%drink%,category.ilike.%beverage%,category.ilike.%boisson%')
            .limit(30); // Reduced limit since we're filtering

        _restaurantDrinks =
            (response as List).map((item) => MenuItem.fromJson(item)).toList();
      } catch (_) {
        // Fallback: fetch all and filter in memory (if database doesn't support ilike)
        final response = await supabase
            .from('menu_items')
            .select('*')
            .eq('restaurant_id', widget.menuItem.restaurantId)
            .eq('is_available', true)
            .limit(50);

        final allItems = response as List;
        // Filter drinks by checking category (case-insensitive)
        _restaurantDrinks = allItems
            .where((item) {
              final category =
                  (item['category'] ?? '').toString().toLowerCase();
              return category.contains('drink') ||
                  category.contains('beverage') ||
                  category.contains('boisson');
            })
            .map((item) => MenuItem.fromJson(item))
            .toList();
      }
    } catch (e) {
      _restaurantDrinks = [];
    }
  }

  void _prePopulateFromCartItem(CartItem cartItem) {
    final params = PrePopulateFromCartItemParams(
      cartItem: cartItem,
      enhancedMenuItem: _enhancedMenuItem,
      restaurantDrinks: _restaurantDrinks,
      selectedVariants: _selectedVariants,
      variantQuantities: _variantQuantities,
      selectedPricingPerVariant: _selectedPricingPerVariant,
      selectedSupplements: _selectedSupplements,
      selectedDrinks: _selectedDrinks,
      drinkQuantities: _drinkQuantities,
      paidDrinkQuantities: _paidDrinkQuantities,
      drinkSizesById: _drinkSizesById,
      removedIngredients: _removedIngredients,
      ingredientPreferences: _ingredientPreferences,
      specialNote: _specialNote,
      quantity: _quantity,
      isSpecialPack: _isSpecialPack,
      packItemSelections: _packItemSelections,
      packIngredientPreferences: _packIngredientPreferences,
      packSupplementSelections: _packSupplementSelections,
      addVariant: (variantId) {
        if (!_selectedVariants.contains(variantId)) {
          _selectedVariants.add(variantId);
        }
      },
      setVariantQuantity: (variantId, qty) =>
          _variantQuantities[variantId] = qty,
      setPricingForVariant: (variantId, pricing) =>
          _selectedPricingPerVariant[variantId] = pricing,
      addSupplement: (supplement) {
        if (!_selectedSupplements.any((s) => s.id == supplement.id)) {
          _selectedSupplements.add(supplement);
        }
      },
      addDrink: (drink) {
        if (!_selectedDrinks.any((d) => d.id == drink.id)) {
          _selectedDrinks.add(drink);
        }
      },
      setDrinkQuantity: (drinkId, qty) => _drinkQuantities[drinkId] = qty,
      setPaidDrinkQuantity: (drinkId, qty) =>
          _paidDrinkQuantities[drinkId] = qty,
      setDrinkSize: (drinkId, size) => _drinkSizesById[drinkId] = size,
      addRemovedIngredient: (ingredient) {
        if (!_removedIngredients.contains(ingredient)) {
          _removedIngredients.add(ingredient);
        }
      },
      setIngredientPreference: (ingredient, pref) =>
          _ingredientPreferences[ingredient] = pref,
      setSpecialNote: (note) => _specialNote = note,
      setQuantity: (qty) => _quantity = qty,
      setPackItemSelection: (variantId, qtyIndex, option) {
        if (!_packItemSelections.containsKey(variantId)) {
          _packItemSelections[variantId] = <int, String>{};
        }
        _packItemSelections[variantId]![qtyIndex] = option;
      },
      setPackIngredientPreference: (variantId, qtyIndex, ingredient, pref) {
        if (!_packIngredientPreferences.containsKey(variantId)) {
          _packIngredientPreferences[variantId] =
              <int, Map<String, IngredientPreference>>{};
        }
        if (!_packIngredientPreferences[variantId]!.containsKey(qtyIndex)) {
          _packIngredientPreferences[variantId]![qtyIndex] =
              <String, IngredientPreference>{};
        }
        _packIngredientPreferences[variantId]![qtyIndex]![ingredient] = pref;
      },
      addPackSupplementSelection: (variantId, qtyIndex, supplementName) {
        if (!_packSupplementSelections.containsKey(variantId)) {
          _packSupplementSelections[variantId] = <int, Set<String>>{};
        }
        if (!_packSupplementSelections[variantId]!.containsKey(qtyIndex)) {
          _packSupplementSelections[variantId]![qtyIndex] = <String>{};
        }
        _packSupplementSelections[variantId]![qtyIndex]!.add(supplementName);
      },
      parsePackItemOptions: _parsePackItemOptions,
    );

    prePopulateFromCartItem(params);
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final maxPopupHeight = screenHeight * 0.95; // Max 95% of screen height

    // Get the current locale for RTL support
    final locale = Localizations.localeOf(context);
    final isRTL = locale.languageCode == 'ar' ||
        locale.languageCode == 'he' ||
        locale.languageCode == 'fa' ||
        locale.languageCode == 'ur';

    return Directionality(
      textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: Opacity(
              opacity: _opacityAnimation.value,
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: maxPopupHeight,
                  maxWidth: screenWidth,
                ),
                child: Container(
                  width: screenWidth, // Explicit width for responsiveness
                  decoration: const BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(24),
                      topRight: Radius.circular(24),
                    ),
                  ),
                  child:
                      _isLoading ? _buildLoadingState() : _buildPopupContent(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return buildLoadingState(
      context: context,
      loadingError: _loadingError,
      isLoadingVariants: _isLoadingVariants,
      isLoadingSupplements: _isLoadingSupplements,
      isLoadingDrinks: _isLoadingDrinks,
      onRetry: () {
        setState(() {
          _loadingError = null;
          _isLoading = true;
        });
        _initializeData();
      },
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      primaryOrange: primaryOrange,
    );
  }

  Widget _buildPopupContent() {
    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.04; // 4% of screen width

    // PERFORMANCE FIX: Use CustomScrollView with slivers instead of SingleChildScrollView + Column
    // This eliminates nested scroll conflicts and enables efficient scrolling
    return Stack(
      children: [
        CustomScrollView(
          // PERFORMANCE FIX: Reduce cacheExtent to reasonable value (250px = ~2-3 screens)
          // Large cacheExtent causes excessive memory usage and slower scrolling
          cacheExtent: 250,
          slivers: [
            // Item image and basic info (no padding)
            SliverToBoxAdapter(
              child: _buildItemHeader(),
            ),

            // Content with horizontal padding
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),

                    // Compact Sliver Box - All customizations in expandable rows
                    if (_isLoadingVariants) ...[
                      _buildSliverBoxSkeleton(),
                      const SizedBox(height: 8),
                    ] else if (_enhancedMenuItem != null) ...[
                      _buildCompactSliverBox(),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),

            // Continue with padded content
            SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ✅ FIX: Paid drinks section removed from here - now shown in add to cart widget below "Save & Add Another" button
                    // Restaurant drinks section with shimmer (only show skeleton if loading)
                    if (_isLoadingDrinks) ...[
                      buildDrinksSkeleton(),
                      const SizedBox(height: 8),
                    ],
                  ],
                ),
              ),
            ),

            // Saved orders section - Full width without padding
            if (!_isLoadingVariants)
              SliverToBoxAdapter(
                child: _buildSavedOrdersSection(),
              ),

            // Scrollable add to cart section (free drinks, quantity, save button, paid drinks)
            if (!_isLoadingVariants)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                  child: _buildScrollableAddToCartSection(),
                ),
              ),

            // Bottom padding for safe area (extra padding for fixed add to cart section)
            SliverPadding(
              padding: EdgeInsets.only(
                bottom:
                    BottomPaddingHelper.getBottomPaddingInsets(context).bottom +
                        (_isLoadingVariants
                            ? 0
                            : 120), // Add space for fixed add to cart section
              ),
            ),
          ],
        ),
        // White close button in top left
        Positioned(
          top: 0,
          left: 0,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 4,
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                  customBorder: const CircleBorder(),
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close,
                      color: Colors.black87,
                      size: 24,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
        // Fixed bottom add to cart section (only confirm/add to cart button)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
                child: _isLoadingVariants
                    ? buildPricingSkeleton()
                    : Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Error message display
                          if (_errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 8),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      _errorMessage!,
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.red[700],
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        _errorMessage = null;
                                      });
                                    },
                                    child: Icon(
                                      Icons.close,
                                      size: 16,
                                      color: Colors.red[700],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          // Add to cart button
                          _buildConfirmAddToCartButton(),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildItemHeader() {
    final screenWidth = MediaQuery.of(context).size.width;

    // Ensure page controller is initialized
    _imagePageController ??= PageController();

    // Note: MenuItemImageSection handles image URL formatting internally

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Scrollable image gallery with page indicators and LTO badges
        // Use enhanced menu item if available (has updated image), otherwise use current menu item
        MenuItemImageSection(
          key: ValueKey('${_currentMenuItem.id}_${_currentMenuItem.updatedAt.millisecondsSinceEpoch}'),
          menuItem: _enhancedMenuItem?.toMenuItem() ?? _currentMenuItem,
          imagePageController: _imagePageController,
          currentImagePage: _currentImagePage,
          onPageChanged: (index) {
            setState(() {
              _currentImagePage = index;
            });
          },
          additionalOverlays:
              PopupTypeHelper.shouldShowLTOBadges(
                      _enhancedMenuItem?.toMenuItem() ?? widget.menuItem)
                  ? _buildLTOBadges()
                  : null,
        ),

        // Padded content below image
        Padding(
          padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Add spacing after image
              SizedBox(height: screenWidth * 0.04),

              // Show header info for non-special packs (prep time, rating, restaurant)
              if (PopupTypeHelper.shouldShowHeaderInfo(widget.menuItem))
                _buildHeaderInfo(),
            ],
          ),
        ),
      ],
    );
  }

  /// Build header info (prep time, rating, restaurant) for non-special packs
  Widget _buildHeaderInfo() {
    final screenWidth = MediaQuery.of(context).size.width;
    final locale = Localizations.localeOf(context);
    final isRTL = locale.languageCode == 'ar' ||
        locale.languageCode == 'he' ||
        locale.languageCode == 'fa' ||
        locale.languageCode == 'ur';

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.04,
        vertical: screenWidth * 0.025,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Prep time
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.access_time,
                size: 16,
                color: Colors.black87,
              ),
              const SizedBox(width: 4),
              Text(
                '${widget.restaurant?.estimatedDeliveryTime ?? widget.menuItem.preparationTime} ${AppLocalizations.of(context)!.min}',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),

          // Vertical divider
          Container(
            height: 16,
            width: 1,
            color: Colors.grey[300],
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),

          // Rating with count
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.star,
                size: 16,
                color: Color(0xFFfc9d2d),
              ),
              const SizedBox(width: 4),
              Text(
                '${(_updatedRating ?? (widget.restaurant?.rating ?? widget.menuItem.rating)).toStringAsFixed(1)} (${_updatedReviewCount ?? widget.menuItem.reviewCount})',
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
              ),
            ],
          ),

          // Vertical divider
          Container(
            height: 16,
            width: 1,
            color: Colors.grey[300],
            margin: const EdgeInsets.symmetric(horizontal: 8),
          ),

          // Restaurant name
          Flexible(
            child: Text(
              widget.restaurant?.name ??
                  widget.menuItem.restaurantName ??
                  'Unknown Restaurant',
              style: GoogleFonts.poppins(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Colors.black87,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
            ),
          ),
        ],
      ),
    );
  }

  /// Build LTO price section with original price, discounted price, and yellow off container
  /// Shown for both regular LTO items and special pack LTO items
  /// ✅ FIX: Use originalPriceFromPricing and effectivePrice for correct calculation
  Widget? _buildLTOPriceSection() {
    if (!widget.menuItem.isLimitedOffer) {
      return null;
    }

    // Use originalPriceFromPricing (from pricing_options) for accurate original price
    final originalPrice = widget.menuItem.originalPriceFromPricing;
    // Use effectivePrice (handles regular LTO: base + extra charge, special pack: full price)
    final discountedPrice = widget.menuItem.effectivePrice;
    // Use discountPercentage from menu item (uses same pricing logic)
    final discountPercent = widget.menuItem.discountPercentage;

    // Only show if there's a discount
    if (originalPrice == null || originalPrice <= discountedPrice || discountPercent == null) {
      return null;
    }

    final locale = Localizations.localeOf(context);
    final isRTL = locale.languageCode == 'ar' ||
        locale.languageCode == 'he' ||
        locale.languageCode == 'fa' ||
        locale.languageCode == 'ur';

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Discounted price
          Text(
            PriceFormatter.formatWithSettings(
              context,
              discountedPrice.toStringAsFixed(0),
            ),
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.orange[600],
            ),
          ),
          const SizedBox(width: 8),
          // Original price (strikethrough)
          Text(
            PriceFormatter.formatWithSettings(
              context,
              originalPrice.toStringAsFixed(0),
            ),
            style: GoogleFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
              decoration: TextDecoration.lineThrough,
            ),
          ),
          const SizedBox(width: 8),
          // Yellow off container
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.yellow[600],
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isRTL
                  ? 'خصم ${discountPercent.toInt()}%'
                  : '${discountPercent.toInt()}% off',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.normal,
                color: Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build LTO badges for image overlay (price, timer, delivery)
  /// Only shown for LTO regular items (not special packs)
  List<Widget> _buildLTOBadges() {
    if (!PopupTypeHelper.shouldShowLTOBadges(widget.menuItem)) {
      return [];
    }

    final locale = Localizations.localeOf(context);
    final isRTL = locale.languageCode == 'ar' ||
        locale.languageCode == 'he' ||
        locale.languageCode == 'fa' ||
        locale.languageCode == 'ur';

    final List<Widget> badges = [];

    // 1. Price badge (top-right or top-left for RTL)
    final hasDiscount = widget.menuItem.hasOfferType('special_price');
    final discountPercent = widget.menuItem.discountPercentage;

    badges.add(
      Positioned(
        top: 12,
        right: isRTL ? null : 12,
        left: isRTL ? 12 : null,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: hasDiscount && discountPercent != null
                ? Colors.red[600] // Red for discount
                : Colors.orange[600], // Orange for regular price
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Discounted price
              Text(
                PriceFormatter.formatWithSettings(
                  context,
                  widget.menuItem.price.toStringAsFixed(0),
                ),
                style: GoogleFonts.poppins(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  height: 1.0,
                ),
                textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
              ),
              // Original price (only show if discount exists)
              if (widget.menuItem.originalPrice != null &&
                  widget.menuItem.originalPrice! > widget.menuItem.price) ...[
                const SizedBox(width: 8),
                Text(
                  PriceFormatter.formatWithSettings(
                    context,
                    widget.menuItem.originalPrice!.toStringAsFixed(0),
                  ),
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.0,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: Colors.white.withOpacity(0.9),
                  ),
                  textDirection: isRTL ? TextDirection.rtl : TextDirection.ltr,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    // 2. Countdown timer badge (bottom-left or bottom-right for RTL)
    final offerEndAt = widget.menuItem.offerEndAtFromPricing;
    String countdownText = 'LIMITED';

    if (offerEndAt != null) {
      final now = DateTime.now();
      final difference = offerEndAt.difference(now);

      if (difference.isNegative) {
        countdownText = 'EXPIRED';
      } else {
        final totalHours = difference.inHours;
        final totalMinutes = difference.inMinutes;

        if (totalHours >= 24) {
          final days = difference.inDays;
          countdownText = '$days ${days == 1 ? 'Day' : 'Days'}';
        } else if (totalMinutes >= 60) {
          countdownText = '$totalHours ${totalHours == 1 ? 'Hour' : 'Hours'}';
        } else {
          countdownText = '$totalMinutes ${totalMinutes == 1 ? 'Min' : 'Mins'}';
        }
      }
    }

    badges.add(
      Positioned(
        bottom: 8,
        left: isRTL ? null : 8,
        right: isRTL ? 8 : null,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: Colors.orange[600],
            borderRadius: BorderRadius.circular(6),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.access_time,
                size: 14,
                color: Colors.white,
              ),
              const SizedBox(width: 3),
              Text(
                countdownText,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // 3. Special Delivery badge (bottom-right or bottom-left for RTL)
    if (widget.menuItem.hasOfferType('special_delivery')) {
      final pricingOptions = widget.menuItem.pricingOptions;
      String deliveryText = 'FREE';

      if (pricingOptions.isNotEmpty) {
        final firstPricing = pricingOptions.first;
        final offerDetails =
            firstPricing['offer_details'] as Map<String, dynamic>?;
        if (offerDetails != null) {
          final deliveryType = offerDetails['delivery_type'] as String?;
          final deliveryValue = offerDetails['delivery_value'] as num?;

          if (deliveryType == 'free') {
            deliveryText = 'FREE';
          } else if (deliveryType == 'percentage' && deliveryValue != null) {
            deliveryText = '-${deliveryValue.toInt()}%';
          } else if (deliveryType == 'fixed' && deliveryValue != null) {
            deliveryText = '-${deliveryValue.toInt()} DA';
          }
        }
      }

      badges.add(
        Positioned(
          bottom: 8,
          right: isRTL ? null : 8,
          left: isRTL ? 8 : null,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 4,
            ),
            decoration: BoxDecoration(
              color: Colors.green[600],
              borderRadius: BorderRadius.circular(6),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.moped,
                  size: 14,
                  color: Colors.white,
                ),
                const SizedBox(width: 3),
                Text(
                  deliveryText,
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return badges;
  }

  // ==================== COMPACT SLIVER BOX LAYOUT ====================

  /// Parse options from variant description (format: "qty:2|options:Regular,Spicy,Cheese|ingredients:...")
  List<String> _parsePackItemOptions(String? description) {
    if (description == null || !description.contains('|options:')) {
      return [];
    }

    try {
      final parts = description.split('|options:');
      if (parts.length > 1) {
        // Get the options part and stop at the next separator (|ingredients: or |anything:)
        final optionsPart = parts[1].split('|')[0];
        return optionsPart
            .split(',')
            .map((o) => o.trim())
            .where((o) => o.isNotEmpty)
            .toList();
      }
    } catch (e) {
      debugPrint('❌ Error parsing pack item options: $e');
    }

    return [];
  }

  Widget _buildCompactSliverBox() {
    // Route to appropriate selector based on item type
    if (_isSpecialPack) {
      return _buildSpecialPackSelector();
    } else {
      // For LTO regular and regular items, use standard variant selector
      return _buildRegularVariantSelector();
    }
  }

  /// Build regular variant selector for LTO regular and regular items
  /// Uses chips-style UI for variant, size, ingredient, and supplement selection
  Widget _buildRegularVariantSelector() {
    // Get available variants using RegularItemHelper
    final variants = RegularItemHelper.getAvailableVariants(
      menuItem: widget.menuItem,
      enhancedMenuItem: _enhancedMenuItem,
    );

    if (variants.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Item name at the top (outside container)
        Text(
          widget.menuItem.name,
          style: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        // Customize your order subtitle (outside container)
        Text(
          AppLocalizations.of(context)!.customizeOrder,
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        // Show LTO price section for regular LTO items (under name)
        if (widget.menuItem.isLimitedOffer && !_isSpecialPack) ...[
          Builder(
            builder: (context) {
              final priceSection = _buildLTOPriceSection();
              return priceSection ?? const SizedBox.shrink();
            },
          ),
        ],
        const SizedBox(height: 16),
        // Container with customization options
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[300]!),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Variant selection with chips style (if multiple variants)
                if (variants.length > 1) ...[
                  Text(
                    AppLocalizations.of(context)!.chooseVariant,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: variants.map((variant) {
                        final isSelected =
                            _selectedVariants.contains(variant.id);
                        // PERFORMANCE FIX: Wrap in RepaintBoundary to isolate repaints
                        return RepaintBoundary(
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                // ✅ FIX: For regular items (LTO and normal), only allow single variant selection
                                // For special packs, allow multiple variants
                                if (_isSpecialPack) {
                                  // Special pack: allow multi-select
                                  if (isSelected) {
                                    _selectedVariants.remove(variant.id);
                                    _selectedPricingPerVariant
                                        .remove(variant.id);
                                  } else {
                                    _selectedVariants.add(variant.id);
                                    // Initialize quantity for this variant if not exists
                                    // Use current global quantity for consistency
                                    if (!_variantQuantities
                                        .containsKey(variant.id)) {
                                      _variantQuantities[variant.id] =
                                          _quantity;
                                    }
                                  }
                                } else {
                                  // Regular item: single select only (clear others when selecting new one)
                                  if (isSelected) {
                                    // Deselect current variant
                                    _selectedVariants.clear();
                                    _selectedPricingPerVariant.clear();
                                    _variantQuantities.clear();
                                  } else {
                                    // Select new variant (clear all others first)
                                    _selectedVariants.clear();
                                    _selectedPricingPerVariant.clear();
                                    _variantQuantities.clear();
                                    _selectedVariants.add(variant.id);
                                    // Initialize quantity for this variant
                                    _variantQuantities[variant.id] = _quantity;
                                  }
                                }
                                // Clear error when variant is selected
                                _clearError();
                              });
                            },
                            child: Container(
                              margin: const EdgeInsets.only(right: 8),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFd47b00)
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFd47b00)
                                      : Colors.grey[300]!,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                variant.name,
                                style: GoogleFonts.poppins(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w500,
                                  color: isSelected
                                      ? Colors.white
                                      : Colors.black87,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Divider(height: 1, color: Colors.grey[200]),
                  const SizedBox(height: 16),
                ],

                // Show variant details when a variant is selected, or if only one variant
                if (variants.length == 1 || _selectedVariants.isNotEmpty) ...[
                  ...variants.map((variant) {
                    final isSelected = _selectedVariants.contains(variant.id) ||
                        variants.length == 1;

                    // Only show section if variant is currently selected
                    if (!isSelected && variants.length > 1) {
                      return const SizedBox.shrink();
                    }

                    return _buildRegularItemSection(variant: variant);
                  }),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Build regular item section with chips style
  Widget _buildRegularItemSection({required MenuItemVariant variant}) {
    // Get pricing options for this variant
    final variantPricing = RegularItemHelper.getVariantPricing(
      enhancedMenuItem: _enhancedMenuItem,
      variantId: variant.id,
    );

    // Get ingredients
    final mainIngredients =
        RegularItemHelper.getMainIngredients(_enhancedMenuItem);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Unified sizes container
        if (variantPricing.isNotEmpty) ...[
          UnifiedSizesContainer(
            sizes: variantPricing,
            selectedPricingPerVariant: _selectedPricingPerVariant,
            variantId: variant.id,
            isOptional: widget.menuItem.isLimitedOffer &&
                !_isSpecialPack, // Size is optional for LTO regular items
            showPricePrefix: widget.menuItem.isLimitedOffer &&
                !_isSpecialPack, // Show "+" prefix for LTO items
            showFreeDrinksIcon: !(widget.menuItem.isLimitedOffer &&
                !_isSpecialPack), // Hide icon for LTO items
            onSizeTapped: (variantId, pricing) {
              setState(() {
                final isSelected =
                    _selectedPricingPerVariant[variantId]?.id == pricing.id;
                if (isSelected) {
                  _selectedPricingPerVariant.remove(variantId);
                } else {
                  _selectedPricingPerVariant[variantId] = pricing;
                  // Auto-select variant when size is selected
                  if (!_selectedVariants.contains(variantId)) {
                    _selectedVariants.add(variantId);
                  }
                  // Initialize quantity for this variant if not exists
                  // Use current global quantity for consistency
                  if (!_variantQuantities.containsKey(variantId)) {
                    _variantQuantities[variantId] = _quantity;
                  }
                }
                // Clear error when size is selected
                _clearError();
              });
            },
          ),
          const SizedBox(height: 12),
        ],

        // Ingredient preferences container (show if any variant has optional ingredients)
        if (_hasAnyOptionalIngredients([variant]) ||
            mainIngredients.isNotEmpty) ...[
          const SizedBox(height: 12),
          IngredientPreferencesContainer(
            regularIngredients:
                RegularItemHelper.getOptionalIngredients(_enhancedMenuItem),
            mainIngredients:
                mainIngredients.isNotEmpty ? mainIngredients : null,
            regularIngredientPreferences: _ingredientPreferences,
            onRegularIngredientTapped: (ingredient) {
              setState(() {
                final pref = _ingredientPreferences[ingredient] ??
                    IngredientPreference.neutral;
                switch (pref) {
                  case IngredientPreference.neutral:
                    _ingredientPreferences[ingredient] =
                        IngredientPreference.wanted;
                    break;
                  case IngredientPreference.wanted:
                    _ingredientPreferences[ingredient] =
                        IngredientPreference.less;
                    break;
                  case IngredientPreference.less:
                    _ingredientPreferences[ingredient] =
                        IngredientPreference.none;
                    break;
                  case IngredientPreference.none:
                    _ingredientPreferences[ingredient] =
                        IngredientPreference.neutral;
                    break;
                }
              });
            },
            getBackgroundColor: _getIngredientBackgroundColor,
            getBorderColor: _getIngredientBorderColor,
            getIcon: _getIngredientIcon,
            getIconColor: _getIngredientIconColor,
            getTextColor: _getIngredientTextColor,
          ),
        ],
        // Unified supplements container for regular items (show if this variant has supplements)
        if (_hasAnySupplements([variant])) ...[
          const SizedBox(height: 12),
          UnifiedSupplementsContainer(
            regularSupplements: _getAllRegularSupplements([variant]),
            regularSelectedSupplements: _selectedSupplements.toList(),
            onRegularSupplementTapped: (supplement) {
              setState(() {
                final isSelected = _selectedSupplements.any((s) =>
                    s.id == supplement.id ||
                    (s.name == supplement.name &&
                        s.menuItemId == supplement.menuItemId));
                if (isSelected) {
                  _selectedSupplements.removeWhere((s) =>
                      s.id == supplement.id ||
                      (s.name == supplement.name &&
                          s.menuItemId == supplement.menuItemId));
                } else {
                  _selectedSupplements.add(supplement);
                }
              });
            },
          ),
          const SizedBox(height: 16),
        ],

        // Note field for this variant (above free drinks)
        _buildVariantNoteField(variant),

        // Free drinks section for LTO items (inside container)
        if (widget.menuItem.isLimitedOffer && !_isSpecialPack) ...[
          // Add safe bottom space between note field and divider
          if (_variantNoteControllers.containsKey(variant.id)) ...[
            SizedBox(
              height: MediaQuery.of(context).padding.bottom > 0
                  ? MediaQuery.of(context).padding.bottom
                  : 16,
            ),
          ],
          if (_hasAnySupplements([variant]) ||
              _variantNoteControllers.containsKey(variant.id)) ...[
            Divider(height: 1, color: Colors.grey[200]),
            const SizedBox(height: 16),
          ] else ...[
            const SizedBox(height: 12),
          ],
          if (_buildFreeDrinksSectionForSelector() != null)
            _buildFreeDrinksSectionForSelector()!,
        ],

        const SizedBox(height: 16),
      ],
    );
  }

  /// Build special pack selector UI - All items in one container with chips
  Widget _buildSpecialPackSelector() {
    // ✅ FIX: When editing, widget.menuItem.variants might be empty
    // Use _enhancedMenuItem?.variants instead, or fallback to widget.menuItem.variants
    Set<String> availableVariantIds;

    if (_enhancedMenuItem?.variants.isNotEmpty == true) {
      // Use enhanced menu item variants (preferred - has full data)
      availableVariantIds =
          _enhancedMenuItem!.variants.map((v) => v.id).toSet();
    } else {
      // Fallback to widget.menuItem.variants (for new items)
      availableVariantIds = widget.menuItem.variants
          .where((v) => v['is_available'] != false)
          .map((v) => v['id']?.toString())
          .whereType<String>()
          .toSet();
    }

    // Filter enhanced variants to only show available ones
    final packItems = (_enhancedMenuItem?.variants ?? [])
        .where((v) => availableVariantIds.contains(v.id))
        .toList();

    if (packItems.isEmpty) {
      return const SizedBox.shrink();
    }

    // ✅ NEW: Build unified pack items and options container
    // Collect all pack items with their quantities and options
    final itemQuantities = <String, int>{};
    final itemOptionsMap = <String, List<String>>{};

    for (final item in packItems) {
      final quantity = SpecialPackHelper.parseQuantity(item.description);
      final options = _parsePackItemOptions(item.description);
      itemQuantities[item.id] = quantity;
      itemOptionsMap[item.id] = options;
    }

    // Build unified container
    final unifiedContainer = UnifiedPackItemsOptionsContainer(
      packItems: packItems,
      itemQuantities: itemQuantities,
      itemOptions: itemOptionsMap,
      packItemSelections: _packItemSelections,
      onOptionSelected: (variantId, qtyIndex, option) {
        setState(() {
          if (!_packItemSelections.containsKey(variantId)) {
            _packItemSelections[variantId] = <int, String>{};
          }
          _packItemSelections[variantId]![qtyIndex] = option;
        });
      },
      onVariantAutoSelected: (variantId) {
        setState(() {
          if (!_selectedVariants.contains(variantId)) {
            _selectedVariants.add(variantId);
          }
        });
      },
    );

    // Build fallback pack items widgets (for backward compatibility)
    final packItemsWidgets = packItems.asMap().entries.map((entry) {
      final index = entry.key;
      final item = entry.value;
      final isLast = index == packItems.length - 1;

      final quantity = SpecialPackHelper.parseQuantity(item.description);
      final options = _parsePackItemOptions(item.description);

      return RepaintBoundary(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildPackItemRow(
              item: item,
              quantity: quantity,
              options: options,
            ),
            if (!isLast) ...[
              const SizedBox(height: 16),
              Divider(height: 1, color: Colors.grey[200]),
              const SizedBox(height: 16),
            ],
          ],
        ),
      );
    }).toList();

    return SpecialPackSelector(
      packBaseName: _getPackBaseName(),
      hasAnyPackIngredients: _hasAnyPackIngredients(),
      ingredientLegend: _buildIngredientLegend(),
      packItems: packItemsWidgets, // Fallback (not used when unified container is provided)
      unifiedPackItemsOptionsContainer: unifiedContainer, // ✅ NEW: Unified items and options
      hasGlobalIngredients:
          false, // Global ingredients are now in the ingredient preferences container
      globalIngredientsSection:
          null, // Global ingredients are now in the ingredient preferences container
      unifiedSupplementsContainer: null, // ✅ HIDE: Supplements hidden from special pack popup
      hasFreeDrinks: _hasFreeDrinks(),
      freeDrinksSection:
          _buildFreeDrinksSectionForSelector(), // Now inside selector container
      specialNoteField:
          _buildSpecialNoteField(), // Special note field above free drinks
      quantitySelector: null, // Now handled in unified add to cart widget
      infoContainer: _buildPackInfoBar(),
      priceSection: widget.menuItem.isLimitedOffer
          ? _buildLTOPriceSection()
          : null, // LTO price section for special pack LTO items
    );
  }

  /// Check if pack has global ingredients
  bool _hasGlobalIngredients() {
    final globalIngredients =
        SpecialPackHelper.getGlobalIngredients(widget.menuItem);
    return globalIngredients.isNotEmpty;
  }

  /// Check if pack has any ingredients (item-specific or global)
  bool _hasAnyPackIngredients() {
    // Check if any variant has ingredients
    if (_enhancedMenuItem != null) {
      for (final variant in _enhancedMenuItem!.variants) {
        final ingredients =
            SpecialPackHelper.parseIngredients(variant.description);
        if (ingredients.isNotEmpty) return true;
      }
    }
    // Check for global ingredients
    return _hasGlobalIngredients();
  }

  /// Build unified supplements container with all supplements from all pack items
  Widget _buildUnifiedSupplementsContainer() {
    // Collect all supplements from all pack items
    final List<
        ({
          String variantId,
          String variantName,
          int quantityIndex,
          String supplementName,
          double supplementPrice,
        })> allSupplements = [];

    if (_enhancedMenuItem != null) {
      for (final variant in _enhancedMenuItem!.variants) {
        final allSupplementsMap =
            SpecialPackHelper.parseSupplements(variant.description);
        final hiddenSupplements =
            SpecialPackHelper.parseHiddenSupplements(variant.description);
        final supplements = Map<String, double>.fromEntries(
          allSupplementsMap.entries
              .where((entry) => !hiddenSupplements.contains(entry.key)),
        );
        final quantity = SpecialPackHelper.parseQuantity(variant.description);
        final qty = quantity > 0 ? quantity : 1;

        // Add supplements for each quantity index
        for (int qtyIndex = 0; qtyIndex < qty; qtyIndex++) {
          for (final entry in supplements.entries) {
            allSupplements.add((
              variantId: variant.id,
              variantName: variant.name,
              quantityIndex: qtyIndex,
              supplementName: entry.key,
              supplementPrice: entry.value,
            ));
          }
        }
      }
    }

    if (allSupplements.isEmpty) {
      return const SizedBox.shrink();
    }

    return UnifiedSupplementsContainer(
      packSupplements: allSupplements,
      packSelectedSupplements: _packSupplementSelections,
      onPackSupplementTapped: (variantId, quantityIndex, supplementName) {
        setState(() {
          // Toggle supplement selection
          final wasAdded = PackStateHelper.toggleSupplementSelection(
            _packSupplementSelections,
            variantId,
            quantityIndex,
            supplementName,
          );

          // Get supplement price
          final variant =
              _enhancedMenuItem?.variants.firstWhere((v) => v.id == variantId);
          if (variant != null) {
            final allSupplementsMap =
                SpecialPackHelper.parseSupplements(variant.description);
            final supplementPrice = allSupplementsMap[supplementName] ?? 0.0;

            if (wasAdded) {
              // Supplement was ADDED to pack selections
              // Add to _selectedSupplements for pricing calculation
              final supplement = MenuItemSupplement(
                id: 'pack_${variantId}_$supplementName',
                menuItemId: widget.menuItem.id,
                name: supplementName,
                price: supplementPrice,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );
              _selectedSupplements.add(supplement);
            } else {
              // Supplement was REMOVED from pack selections
              // Also remove from _selectedSupplements if it exists
              _selectedSupplements.removeWhere((s) =>
                  s.name == supplementName &&
                  s.menuItemId == widget.menuItem.id);
            }
          }
        });
      },
    );
  }

  /// Build ingredient preference legend with all ingredients
  Widget _buildIngredientLegend() {
    // Get global ingredients for special pack
    final globalIngredients =
        SpecialPackHelper.getGlobalIngredients(widget.menuItem);

    // Collect all ingredients from all pack items
    final List<({String variantName, int quantityIndex, String ingredient})>
        allIngredients = [];

    if (_enhancedMenuItem != null) {
      for (final variant in _enhancedMenuItem!.variants) {
        final ingredients =
            SpecialPackHelper.parseIngredients(variant.description);
        final quantity = SpecialPackHelper.parseQuantity(variant.description);
        final qty = quantity > 0 ? quantity : 1;

        // Add ingredients for each quantity index
        for (int qtyIndex = 0; qtyIndex < qty; qtyIndex++) {
          for (final ingredient in ingredients) {
            allIngredients.add((
              variantName: variant.name,
              quantityIndex: qtyIndex,
              ingredient: ingredient,
            ));
          }
        }
      }
    }

    return IngredientPreferencesContainer(
      packIngredients: allIngredients.isNotEmpty ? allIngredients : null,
      packIngredientPreferences:
          allIngredients.isNotEmpty ? _packIngredientPreferences : null,
      onIngredientTapped: allIngredients.isNotEmpty
          ? (variantName, quantityIndex, ingredient) {
              setState(() {
                final pref = PackStateHelper.getIngredientPreference(
                      _packIngredientPreferences,
                      variantName,
                      quantityIndex,
                      ingredient,
                    ) ??
                    IngredientPreference.neutral;
                // Cycle through preferences: neutral -> wanted -> less -> none -> neutral
                switch (pref) {
                  case IngredientPreference.neutral:
                    PackStateHelper.setIngredientPreference(
                      _packIngredientPreferences,
                      variantName,
                      quantityIndex,
                      ingredient,
                      IngredientPreference.wanted,
                    );
                    break;
                  case IngredientPreference.wanted:
                    PackStateHelper.setIngredientPreference(
                      _packIngredientPreferences,
                      variantName,
                      quantityIndex,
                      ingredient,
                      IngredientPreference.less,
                    );
                    break;
                  case IngredientPreference.less:
                    PackStateHelper.setIngredientPreference(
                      _packIngredientPreferences,
                      variantName,
                      quantityIndex,
                      ingredient,
                      IngredientPreference.none,
                    );
                    break;
                  case IngredientPreference.none:
                    PackStateHelper.removeIngredientPreference(
                      _packIngredientPreferences,
                      variantName,
                      quantityIndex,
                      ingredient,
                    );
                    break;
                }
              });
            }
          : null,
      getBackgroundColor:
          allIngredients.isNotEmpty ? _getIngredientBackgroundColor : null,
      getBorderColor:
          allIngredients.isNotEmpty ? _getIngredientBorderColor : null,
      getIcon: allIngredients.isNotEmpty ? _getIngredientIcon : null,
      getIconColor: allIngredients.isNotEmpty ? _getIngredientIconColor : null,
      getTextColor: allIngredients.isNotEmpty ? _getIngredientTextColor : null,
      mainIngredients: globalIngredients.isNotEmpty ? globalIngredients : null,
    );
  }

  /// Check if any variant has optional ingredients (for showing ingredient preferences container)
  bool _hasAnyOptionalIngredients(List<MenuItemVariant> variants) {
    final optionalIngredients =
        RegularItemHelper.getOptionalIngredients(_enhancedMenuItem);
    return optionalIngredients.isNotEmpty;
  }

  /// Check if any variant has supplements
  bool _hasAnySupplements(List<MenuItemVariant> variants) {
    for (final variant in variants) {
      final supplements = RegularItemHelper.getVariantSupplements(
        enhancedMenuItem: _enhancedMenuItem,
        variantId: variant.id,
      );
      if (supplements.isNotEmpty) {
        return true;
      }
    }
    return false;
  }

  /// Get all supplements from all variants
  List<MenuItemSupplement> _getAllRegularSupplements(
      List<MenuItemVariant> variants) {
    final allSupplements = <MenuItemSupplement>[];
    for (final variant in variants) {
      final supplements = RegularItemHelper.getVariantSupplements(
        enhancedMenuItem: _enhancedMenuItem,
        variantId: variant.id,
      );
      // Cast dynamic list to MenuItemSupplement list
      for (final supp in supplements) {
        if (supp is MenuItemSupplement) {
          allSupplements.add(supp);
        }
      }
    }
    // Remove duplicates based on id or (name + menuItemId)
    final uniqueSupplements = <MenuItemSupplement>[];
    for (final supp in allSupplements) {
      if (!uniqueSupplements.any((s) =>
          s.id == supp.id ||
          (s.name == supp.name && s.menuItemId == supp.menuItemId))) {
        uniqueSupplements.add(supp);
      }
    }
    return uniqueSupplements;
  }

  /// Check if pack has free drinks included
  /// Free drinks data is stored in menu_item_pricing table
  bool _hasFreeDrinks() {
    if (kDebugMode) {
      debugPrint('🥤 _hasFreeDrinks() called:');
      debugPrint(
          '   _enhancedMenuItem: ${_enhancedMenuItem != null ? "loaded" : "null"}');
      if (_enhancedMenuItem != null) {
        debugPrint(
            '   pricing options count: ${_enhancedMenuItem!.pricing.length}');
        for (final pricing in _enhancedMenuItem!.pricing) {
          debugPrint(
              '   - ${pricing.size}: freeDrinksIncluded=${pricing.freeDrinksIncluded}, list=${pricing.freeDrinksList}');
        }
      }
    }

    if (_enhancedMenuItem == null) return false;

    // Check if any pricing option has free drinks
    final hasDrinks = _enhancedMenuItem!.pricing.any((pricing) =>
        pricing.freeDrinksIncluded && pricing.freeDrinksList.isNotEmpty);

    if (kDebugMode) {
      debugPrint('   Result: $hasDrinks');
    }

    return hasDrinks;
  }

  /// Get list of free drink IDs from pricing options
  List<String> _getFreeDrinkIds() {
    if (_enhancedMenuItem == null) return [];

    // Get free drinks from the default pricing option
    final defaultPricing = _enhancedMenuItem!.pricing.firstWhere(
      (p) => p.isDefault,
      orElse: () => _enhancedMenuItem!.pricing.isNotEmpty
          ? _enhancedMenuItem!.pricing.first
          : MenuItemPricing(
              id: '',
              menuItemId: '',
              size: '',
              portion: '',
              price: 0,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
    );

    return defaultPricing.freeDrinksList;
  }

  /// Build free drinks section widget for special pack selector
  Widget? _buildFreeDrinksSectionForSelector() {
    if (!_hasFreeDrinks()) {
      return null;
    }

    final freeDrinkIds = _getFreeDrinkIds();
    if (freeDrinkIds.isEmpty) {
      return null;
    }

    // Filter restaurant drinks to show only free ones
    final freeDrinks = _restaurantDrinks
        .where((drink) => freeDrinkIds.contains(drink.id))
        .toList();

    if (freeDrinks.isEmpty) {
      return null;
    }

    final maxFreeDrinksQuantity = _getFreeDrinksQuantity();

    return Builder(
      builder: (context) {
        final l10n = AppLocalizations.of(context)!;
        final locale = Localizations.localeOf(context).languageCode;
        final drinkWord = maxFreeDrinksQuantity == 1
            ? (locale == 'fr'
                ? 'boisson'
                : locale == 'ar'
                    ? 'مشروب'
                    : 'drink')
            : (locale == 'fr'
                ? 'boissons'
                : locale == 'ar'
                    ? 'مشروبات'
                    : 'drinks');
        final plural = maxFreeDrinksQuantity == 1
            ? ''
            : (locale == 'fr'
                ? 'es'
                : locale == 'ar'
                    ? ''
                    : 's');

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section title
            Text(
              l10n.freeDrinksIncluded,
              style: GoogleFonts.poppins(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.chooseUpToComplimentaryDrink(
                  maxFreeDrinksQuantity, drinkWord, plural),
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 12),

            // Free drink cards
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: freeDrinks.map((drink) {
                final drinkQuantity = _drinkQuantities[drink.id] ?? 0;
                final isSelected = drinkQuantity > 0;

                return Container(
                  width: 100,
                  height: 126, // Fixed height for consistent card size
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFFd47b00)
                          : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(11),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Background image (full card size)
                        buildDrinkImage(
                          drink: drink,
                          drinkImageCache: _drinkImageCache,
                          onCacheUpdate: (drinkId) {
                            _drinkImageCache.remove(drinkId);
                          },
                          supabase: Supabase.instance.client,
                        ),

                        // Gradient overlay for better text readability
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.6),
                              ],
                              stops: const [0.5, 1.0],
                            ),
                          ),
                        ),

                        // Quantity selector at bottom - always visible
                        Positioned(
                          left: 8,
                          right: 8,
                          bottom: 8,
                          child: Builder(
                            builder: (context) {
                              final totalSelected =
                                  _drinkQuantities.values.fold<int>(
                                0,
                                (sum, qty) => sum + qty,
                              );
                              final canIncrease =
                                  totalSelected < maxFreeDrinksQuantity &&
                                      drinkQuantity < maxFreeDrinksQuantity;

                              return DrinkQuantitySelector(
                                quantity: drinkQuantity,
                                onQuantityChanged: (newQuantity) {
                                  setState(() {
                                    if (newQuantity == 0) {
                                      _selectedDrinks
                                          .removeWhere((d) => d.id == drink.id);
                                      _drinkQuantities.remove(drink.id);
                                    } else if (drinkQuantity == 0) {
                                      _selectedDrinks.add(drink);
                                    }
                                    _drinkQuantities[drink.id] = newQuantity;
                                    // Clear error when free drink is selected
                                    _clearError();
                                  });
                                },
                                canDecrease: drinkQuantity > 0,
                                canIncrease: canIncrease,
                                fontSize: 10,
                                iconSize: 18,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  /// Auto-select first option for all variants in special pack mode
  /// This ensures all variants have at least one option selected to avoid null order process
  /// Note: This method should be called within a setState block to update the UI
  void _autoSelectFirstOptionForAllVariants() {
    if (_enhancedMenuItem == null) {
      return;
    }

    // Iterate through all variants
    for (final variant in _enhancedMenuItem!.variants) {
      // Parse options from variant description
      final options = _parsePackItemOptions(variant.description);

      // Only auto-select if variant has options
      if (options.isEmpty) {
        continue;
      }

      // Check if variant already has selections
      final existingSelections = _packItemSelections[variant.id];

      // If variant has no selections or selections are empty, auto-select first option
      if (existingSelections == null || existingSelections.isEmpty) {
        // Parse quantity from variant description
        final quantity = SpecialPackHelper.parseQuantity(variant.description);
        final qty = quantity > 0 ? quantity : 1;

        // ✅ FIX: Don't auto-select default option when quantity > 1 and has multiple options
        // User should manually select options for each quantity when there are multiple options
        if (qty > 1 && options.length > 1) {
          debugPrint(
              '⏭️ Skipping auto-selection for variant ${variant.name} (qty: $qty, options: ${options.length}) - user must select manually');
          continue;
        }

        // Ensure variant is selected
        if (!_selectedVariants.contains(variant.id)) {
          _selectedVariants.add(variant.id);
          debugPrint('✅ Auto-selected variant: ${variant.name}');
        }

        // Select first option for all quantity indices
        final firstOption = options.first;
        if (!_packItemSelections.containsKey(variant.id)) {
          _packItemSelections[variant.id] = <int, String>{};
        }

        for (int i = 0; i < qty; i++) {
          _packItemSelections[variant.id]![i] = firstOption;
        }

        debugPrint(
            '✅ Auto-selected first option "$firstOption" for variant ${variant.name} (qty: $qty)');
      }
    }
  }

  void _autoSelectSingleFreeDrink() {
    // Don't auto-select when editing existing cart item (preserve existing selections)
    if (widget.existingCartItem != null) {
      return;
    }

    // Only auto-select if no drinks are already selected (avoid overwriting user choices)
    if (_selectedDrinks.isNotEmpty || _drinkQuantities.isNotEmpty) {
      return;
    }

    // Check if special pack has free drinks and restaurant drinks are loaded
    if (!_hasFreeDrinks() ||
        _enhancedMenuItem == null ||
        _restaurantDrinks.isEmpty) {
      return;
    }

    final freeDrinkIds = _getFreeDrinkIds();
    if (freeDrinkIds.isEmpty) {
      return;
    }

    // Filter restaurant drinks to show only free ones
    final freeDrinks = _restaurantDrinks
        .where((drink) => freeDrinkIds.contains(drink.id))
        .toList();

    // Only auto-select if there's exactly ONE free drink option
    if (freeDrinks.length == 1) {
      final drink = freeDrinks.first;
      final maxQuantity = _getFreeDrinksQuantity();

      if (maxQuantity > 0) {
        setState(() {
          _selectedDrinks.add(drink);
          // Use the calculated quantity (already multiplied by item quantity for LTO/regular)
          _drinkQuantities[drink.id] = maxQuantity;
        });

        debugPrint(
            '🍹 Auto-selected single free drink: ${drink.name} with quantity: $maxQuantity (item qty: $_quantity)');
      }
    }
  }

  /// Get free drinks quantity from pricing options
  /// For LTO and regular items: multiplies base quantity by item quantity
  /// For special packs: returns base quantity (special packs handle quantity differently)
  int _getFreeDrinksQuantity() {
    if (_enhancedMenuItem == null) return 1;

    // Get free drinks quantity from the default pricing option
    final defaultPricing = _enhancedMenuItem!.pricing.firstWhere(
      (p) => p.isDefault,
      orElse: () => _enhancedMenuItem!.pricing.isNotEmpty
          ? _enhancedMenuItem!.pricing.first
          : MenuItemPricing(
              id: '',
              menuItemId: '',
              size: '',
              portion: '',
              price: 0,
              freeDrinksQuantity: 1,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
    );

    final baseQuantity = defaultPricing.freeDrinksQuantity;

    // For LTO and regular items: multiply by item quantity
    // For special packs: return base quantity (they handle quantity per item separately)
    if (!_isSpecialPack) {
      // Use the current item quantity or variant quantity if available
      int itemQuantity = _quantity;

      // For regular items with per-variant quantities, use the sum of variant quantities
      if (!_isSpecialPack && _variantQuantities.isNotEmpty) {
        itemQuantity =
            _variantQuantities.values.fold(0, (sum, qty) => sum + qty);
        if (itemQuantity == 0) {
          itemQuantity = _quantity; // Fallback to global quantity
        }
      }

      return baseQuantity * itemQuantity;
    }

    // Special packs: return base quantity (each pack gets its own free drinks)
    return baseQuantity;
  }

  /// Check if there are any saved variant orders
  bool _hasSavedVariantOrders() {
    return _savedVariantOrders.values.any((orders) => orders.isNotEmpty);
  }

  /// Remove a saved variant order
  void _removeSavedVariantOrder(String variantId, int orderIndex) {
    setState(() {
      final removed = PackStateHelper.removeSavedVariantOrder(
        _savedVariantOrders,
        variantId,
        orderIndex,
      );
      if (removed) {
        debugPrint(
            '🗑️ Removed saved variant order at index $orderIndex for variant $variantId');
      }
    });
  }

  /// Save current order and clear all selections to allow user to create another order
  void _saveAndAddAnotherOrder() {
    saveAndAddAnotherOrder(
      SaveAndAddAnotherOrderParams(
        context: context,
        menuItem: widget.menuItem,
        isSpecialPack: _isSpecialPack,
        enhancedMenuItem: _enhancedMenuItem,
        selectedVariants: _selectedVariants,
        selectedPricingPerVariant: _selectedPricingPerVariant,
        quantity: _quantity,
        selectedSupplements: _selectedSupplements,
        removedIngredients: _removedIngredients,
        ingredientPreferences: _ingredientPreferences,
        packItemSelections: _packItemSelections,
        packIngredientPreferences: _packIngredientPreferences,
        packSupplementSelections: _packSupplementSelections,
        selectedDrinks: _selectedDrinks,
        drinkQuantities: _drinkQuantities,
        paidDrinkQuantities: _paidDrinkQuantities,
        drinkSizesById: _drinkSizesById,
        restaurantDrinks: _restaurantDrinks,
        specialNote: _specialNote,
        savedVariantOrders: _savedVariantOrders,
        variantQuantities:
            _variantQuantities, // For regular items with per-variant quantities
        variantNotes: _variantNotes, // For regular items with per-variant notes
        convertIngredientPreferencesToJson: _convertIngredientPreferencesToJson,
        parsePackItemOptions: _parsePackItemOptions,
        clearSelections: () {
          setState(() {
            // Clear variants and pricing (as requested - no defaults)
            _selectedVariants.clear();
            _selectedPricingPerVariant.clear();
            _variantQuantities.clear();
            _variantNotes.clear();
            _variantNoteControllers.clear();

            // Reset general quantity to 1
            _quantity = 1;

            // Clear supplements
            _selectedSupplements.clear();
            _packSupplementSelections.clear();

            // Clear ingredients
            _removedIngredients.clear();
            _ingredientPreferences.clear();
            _packIngredientPreferences.clear();

            // Clear drinks
            _selectedDrinks.clear();
            _drinkQuantities.clear();
            _paidDrinkQuantities.clear();

            // Clear pack item selections
            _packItemSelections.clear();

            // Clear special note
            _specialNote = '';
          });
        },
        autoSelectSingleFreeDrink: _autoSelectSingleFreeDrink,
      ),
    );
  }

  /// Get pack full formatted name
  /// Example: "Offre Spécial (2)x Burger, Pizza et Melfouf"
  /// Returns the complete formatted name like in menu item cards
  String _getPackBaseName() {
    // Return the full formatted name from widget.menuItem
    // This is the name that was formatted by SpecialPackHelper
    final fullName = widget.menuItem.name;

    if (kDebugMode) {
      debugPrint('📝 Pack full name: "$fullName"');
    }

    return fullName;
  }

  /// Build info bar for special packs (prep time | reviews | restaurant)
  Widget _buildPackInfoBar() {
    return buildPackInfoBar(
      menuItem: widget.menuItem,
      restaurant: widget.restaurant,
      updatedRating: _updatedRating,
      updatedReviewCount: _updatedReviewCount,
    );
  }

  /// Build individual pack item row with chips (supports multiple quantities)
  Widget _buildPackItemRow({
    required MenuItemVariant item,
    required int quantity,
    required List<String> options,
  }) {
    // Initialize selections map for this item if not exists (but don't auto-select)
    // This allows users to explicitly select options after clearing
    PackStateHelper.ensurePackItemSelectionsInitialized(
      _packItemSelections,
      item.id,
    );

    return buildPackItemRow(
      BuildPackItemRowParams(
        item: item,
        quantity: quantity,
        options: options,
        packItemSelections: _packItemSelections,
        selectedVariants: _selectedVariants,
        variantQuantities: _variantQuantities,
        selectedPricingPerVariant: _selectedPricingPerVariant,
        enhancedMenuItem: _enhancedMenuItem,
        onStateUpdate: () {
          setState(() {});
        },
        onOptionSelected: (variantId, qtyIndex, option) {
          setState(() {
            if (!_packItemSelections.containsKey(variantId)) {
              _packItemSelections[variantId] = <int, String>{};
            }
            _packItemSelections[variantId]![qtyIndex] = option;
          });
        },
        onVariantAutoSelected: (variantId) {
          setState(() {
            _selectedVariants.add(variantId);
            // Initialize quantity for this variant if not exists
            if (!_variantQuantities.containsKey(variantId)) {
              _variantQuantities[variantId] = 1;
            }

            // ✅ FIX: Set default pricing for this variant if not exists (skip for LTO regular items)
            // For LTO regular items, size is optional, so don't auto-select pricing
            final isLTORegular =
                widget.menuItem.isLimitedOffer && !_isSpecialPack;
            if (!isLTORegular &&
                !_selectedPricingPerVariant.containsKey(variantId) &&
                _enhancedMenuItem != null) {
              if (_enhancedMenuItem!.pricing.isNotEmpty) {
                final variantPricing = _enhancedMenuItem!.pricing
                    .where((p) => p.variantId == variantId)
                    .toList();

                if (variantPricing.isNotEmpty) {
                  _selectedPricingPerVariant[variantId] = variantPricing.first;
                } else if (_enhancedMenuItem!.defaultPricing != null) {
                  _selectedPricingPerVariant[variantId] =
                      _enhancedMenuItem!.defaultPricing!;
                } else if (_enhancedMenuItem!.pricing.isNotEmpty) {
                  _selectedPricingPerVariant[variantId] =
                      _enhancedMenuItem!.pricing.first;
                }
              }
            }
          });
        },
        buildIngredients: (
            {required variantName,
            required quantityIndex,
            required ingredients}) {
          // Initialize preferences map if needed (using variant name as key)
          PackStateHelper.ensureIngredientPreferencesInitialized(
            _packIngredientPreferences,
            variantName,
            quantityIndex,
          );
          // Ingredients are now shown in the unified ingredient preferences container
          return const SizedBox.shrink();
        },
        buildSupplements: (
            {required variantId,
            required variantName,
            required quantityIndex,
            required supplements}) {
          // Initialize supplement selections map if needed
          PackStateHelper.ensureSupplementSelectionsInitialized(
            _packSupplementSelections,
            variantId,
            quantityIndex,
          );
          // Supplements are now shown in the unified supplements container
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildSliverBoxSkeleton() {
    return SpecialPackSkeletonWidget(
      titleWidth: 150,
      titleHeight: 20,
      contentConfig: SkeletonContentConfig.column(
        children: List.generate(
          3,
          (index) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            child: SpecialPackSkeletonWidget(
              showTitle: false,
              contentConfig: SkeletonContentConfig.single(
                itemConfig: SkeletonItemConfig(
                  width: double.infinity,
                  height: 60,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // PERFORMANCE FIX: Cache formatted prices to avoid recalculating on every rebuild
  Map<int, String>? _cachedFormattedPrices;
  int? _cachedSavedOrdersHashCode;

  Widget _buildSavedOrdersSection() {
    if (_savedOrders.isEmpty) return const SizedBox.shrink();

    final screenWidth = MediaQuery.of(context).size.width;
    final horizontalPadding = screenWidth * 0.04; // 4% of screen width

    // PERFORMANCE FIX: Only recalculate formatted prices if saved orders changed
    final currentHashCode = _savedOrders.length.hashCode ^
        _savedOrders.fold(0, (sum, order) => sum ^ order.totalPrice.hashCode);
    if (_cachedFormattedPrices == null ||
        _cachedSavedOrdersHashCode != currentHashCode) {
      _cachedFormattedPrices = _savedOrders.asMap().map((index, order) {
        final priceText = PriceFormatter.formatWithSettings(
          context,
          order.totalPrice.toString(),
        );
        return MapEntry(index, priceText);
      });
      _cachedSavedOrdersHashCode = currentHashCode;
    }
    final formattedPrices = _cachedFormattedPrices!;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            child: Text(
              'Saved Orders',
              style: GoogleFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textPrimary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 32,
            // PERFORMANCE FIX: Horizontal scrolling works within CustomScrollView
            // Use ClampingScrollPhysics for smooth scrolling
            // Add itemExtent to avoid measure storms (approximate width of saved order chip)
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics:
                  const ClampingScrollPhysics(), // Smooth horizontal scrolling
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              itemCount: _savedOrders.length,
              itemExtent: 200, // Approximate width of saved order chip + margin
              cacheExtent: 400, // Cache 2 items ahead
              itemBuilder: (context, index) {
                final order = _savedOrders[index];
                final priceText = formattedPrices[index] ?? '';
                // PERFORMANCE FIX: Wrap in RepaintBoundary to isolate repaints
                return RepaintBoundary(
                  child: Container(
                    margin: const EdgeInsets.only(right: 6),
                    child: GestureDetector(
                      onTap: () => _removeSavedOrder(index),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.orange[600],
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${order.quantity}x ${widget.menuItem.name} ${order.customizations?.selectedVariants.isNotEmpty == true ? order.customizations!.selectedVariants.first : ''} ($priceText)',
                              style: GoogleFonts.poppins(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            const SizedBox(width: 6),
                            const Icon(
                              Icons.close,
                              size: 12,
                              color: Colors.white,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Build scrollable add to cart section (free drinks, quantity, save button, paid drinks)
  /// Excludes the confirm/add to cart button which is in the fixed bottom container
  Widget _buildScrollableAddToCartSection() {
    final params = BuildAddToCartSectionParams(
      enhancedMenuItem: _enhancedMenuItem,
      menuItem: widget.menuItem,
      isSpecialPack: _isSpecialPack,
      selectedVariants: _selectedVariants,
      selectedPricingPerVariant: _selectedPricingPerVariant,
      selectedSupplements: _selectedSupplements,
      restaurantDrinks: _restaurantDrinks,
      paidDrinkQuantities: _paidDrinkQuantities,
      quantity: _quantity,
      packItemSelections: _packItemSelections,
      packSupplementSelections: _packSupplementSelections,
      savedVariantOrders: _savedVariantOrders,
      savedOrders: _savedOrders,
      existingCartItem: widget.existingCartItem,
      getFreeDrinkIds: _getFreeDrinkIds,
      hasSavedVariantOrders: _hasSavedVariantOrders,
      getFreeDrinksQuantity: _getFreeDrinksQuantity,
      removeSavedVariantOrder: _removeSavedVariantOrder,
      saveAndAddAnotherOrder: _saveAndAddAnotherOrder,
      addToCart: _addToCart,
      submitOrder: _submitOrder,
      navigateToConfirmFlow: _navigateToConfirmFlow,
      drinkQuantities: _drinkQuantities,
      drinkImageCache: _drinkImageCache,
      onQuantityDecrease: () {
        setState(() {
          if (_quantity > 1) {
            final oldQuantity = _quantity;
            _quantity = _quantity - 1;
            if (!_isSpecialPack) {
              for (final variantId in _selectedVariants) {
                _variantQuantities[variantId] = _quantity;
              }
            }
            if (!_isSpecialPack &&
                _hasFreeDrinks() &&
                _drinkQuantities.isNotEmpty) {
              final ratio = _quantity / oldQuantity;
              for (final drinkId in _drinkQuantities.keys.toList()) {
                final oldDrinkQty = _drinkQuantities[drinkId] ?? 0;
                if (oldDrinkQty > 0) {
                  final newDrinkQty = (oldDrinkQty * ratio).round();
                  _drinkQuantities[drinkId] = newDrinkQty > 0 ? newDrinkQty : 1;
                }
              }
            }
          }
        });
      },
      onQuantityIncrease: () {
        setState(() {
          final oldQuantity = _quantity;
          _quantity = _quantity + 1;
          if (!_isSpecialPack) {
            for (final variantId in _selectedVariants) {
              _variantQuantities[variantId] = _quantity;
            }
          }
          if (!_isSpecialPack &&
              _hasFreeDrinks() &&
              _drinkQuantities.isNotEmpty) {
            final ratio = _quantity / oldQuantity;
            for (final drinkId in _drinkQuantities.keys.toList()) {
              final oldDrinkQty = _drinkQuantities[drinkId] ?? 0;
              if (oldDrinkQty > 0) {
                final newDrinkQty = (oldDrinkQty * ratio).round();
                _drinkQuantities[drinkId] = newDrinkQty;
              }
            }
          }
        });
      },
      onFreeDrinkQuantityChanged: (drinkId, quantity) {
        setState(() {
          _drinkQuantities[drinkId] = quantity;
        });
      },
      onFreeDrinkSelected: (drink) {
        setState(() {
          _selectedDrinks.add(drink);
          // Clear error when free drink is selected
          _clearError();
        });
      },
      onFreeDrinkDeselected: (drinkId) {
        setState(() {
          _selectedDrinks.removeWhere((d) => d.id == drinkId);
          _drinkQuantities.remove(drinkId);
        });
      },
      buildDrinkImage: (drink) => buildDrinkImage(
        drink: drink,
        drinkImageCache: _drinkImageCache,
        onCacheUpdate: (drinkId) {
          _drinkImageCache.remove(drinkId);
        },
        supabase: Supabase.instance.client,
      ),
      paidDrinksSection: null, // Moved to cart screen
      variantQuantities: _variantQuantities,
    );

    return buildScrollableAddToCartSection(params);
  }

  /// Build confirm/add to cart button only (for fixed bottom container)
  Widget _buildConfirmAddToCartButton() {
    final params = BuildAddToCartSectionParams(
      enhancedMenuItem: _enhancedMenuItem,
      menuItem: widget.menuItem,
      isSpecialPack: _isSpecialPack,
      selectedVariants: _selectedVariants,
      selectedPricingPerVariant: _selectedPricingPerVariant,
      selectedSupplements: _selectedSupplements,
      restaurantDrinks: _restaurantDrinks,
      paidDrinkQuantities: _paidDrinkQuantities,
      quantity: _quantity,
      packItemSelections: _packItemSelections,
      packSupplementSelections: _packSupplementSelections,
      savedVariantOrders: _savedVariantOrders,
      savedOrders: _savedOrders,
      existingCartItem: widget.existingCartItem,
      getFreeDrinkIds: _getFreeDrinkIds,
      hasSavedVariantOrders: _hasSavedVariantOrders,
      getFreeDrinksQuantity: _getFreeDrinksQuantity,
      removeSavedVariantOrder: _removeSavedVariantOrder,
      saveAndAddAnotherOrder: _saveAndAddAnotherOrder,
      addToCart: _addToCart,
      submitOrder: _submitOrder,
      navigateToConfirmFlow: _navigateToConfirmFlow,
      drinkQuantities: _drinkQuantities,
      drinkImageCache: _drinkImageCache,
      onQuantityDecrease: () {
        setState(() {
          if (_quantity > 1) {
            final oldQuantity = _quantity;
            _quantity = _quantity - 1;
            if (!_isSpecialPack) {
              for (final variantId in _selectedVariants) {
                _variantQuantities[variantId] = _quantity;
              }
            }
            if (!_isSpecialPack &&
                _hasFreeDrinks() &&
                _drinkQuantities.isNotEmpty) {
              final ratio = _quantity / oldQuantity;
              for (final drinkId in _drinkQuantities.keys.toList()) {
                final oldDrinkQty = _drinkQuantities[drinkId] ?? 0;
                if (oldDrinkQty > 0) {
                  final newDrinkQty = (oldDrinkQty * ratio).round();
                  _drinkQuantities[drinkId] = newDrinkQty > 0 ? newDrinkQty : 1;
                }
              }
            }
          }
        });
      },
      onQuantityIncrease: () {
        setState(() {
          final oldQuantity = _quantity;
          _quantity = _quantity + 1;
          if (!_isSpecialPack) {
            for (final variantId in _selectedVariants) {
              _variantQuantities[variantId] = _quantity;
            }
          }
          if (!_isSpecialPack &&
              _hasFreeDrinks() &&
              _drinkQuantities.isNotEmpty) {
            final ratio = _quantity / oldQuantity;
            for (final drinkId in _drinkQuantities.keys.toList()) {
              final oldDrinkQty = _drinkQuantities[drinkId] ?? 0;
              if (oldDrinkQty > 0) {
                final newDrinkQty = (oldDrinkQty * ratio).round();
                _drinkQuantities[drinkId] = newDrinkQty;
              }
            }
          }
        });
      },
      onFreeDrinkQuantityChanged: (drinkId, quantity) {},
      onFreeDrinkSelected: (drink) {},
      onFreeDrinkDeselected: (drinkId) {},
      buildDrinkImage: (drink) => const SizedBox.shrink(),
      paidDrinksSection: null,
      variantQuantities: _variantQuantities,
    );

    return buildConfirmAddToCartButton(params);
  }

  /// Clear error message
  void _clearError() {
    if (_errorMessage != null) {
      setState(() {
        _errorMessage = null;
      });
    }
  }

  /// Validate selection before adding to cart or navigating
  bool _validateSelection({required bool checkFreeDrinks}) {
    // Clear any existing error first
    _clearError();

    // Validate: Check if at least one variant with pricing is selected OR there are saved variant orders
    final hasSavedVariantOrders =
        _savedVariantOrders.values.any((orders) => orders.isNotEmpty);

    if (_savedOrders.isEmpty &&
        _selectedVariants.isEmpty &&
        !hasSavedVariantOrders) {
      setState(() {
        _errorMessage =
            'Please select a variant and size or save at least one order';
      });
      // Auto-clear error after 5 seconds
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) {
          _clearError();
        }
      });
      return false;
    }

    // ✅ FIX: Check if selected variants have pricing (only if no saved variant orders)
    // For LTO regular items, size is optional, so skip pricing validation
    final isLTO = widget.menuItem.isLimitedOffer;
    final isLTORegular = isLTO && !_isSpecialPack;

    if (_savedOrders.isEmpty &&
        _selectedVariants.isNotEmpty &&
        !hasSavedVariantOrders &&
        !isLTORegular) {
      // Skip pricing validation for LTO regular items (size is optional)
      bool hasValidPricing = false;
      for (final variantId in _selectedVariants) {
        if (_selectedPricingPerVariant.containsKey(variantId)) {
          hasValidPricing = true;
          break;
        }
      }

      if (!hasValidPricing) {
        setState(() {
          _errorMessage = 'Please select a size for the selected variant';
        });
        // Auto-clear error after 5 seconds
        Future.delayed(const Duration(seconds: 5), () {
          if (mounted) {
            _clearError();
          }
        });
        return false;
      }
    }

    // Validate free drinks selection for LTO items and special packs
    if (checkFreeDrinks &&
        (widget.menuItem.isLimitedOffer || _isSpecialPack) &&
        _savedOrders.isEmpty &&
        !hasSavedVariantOrders) {
      int requiredDrinks = 0;

      // For special packs with variants, check selected variant's requirement
      if (_isSpecialPack && _selectedVariants.isNotEmpty) {
        requiredDrinks = _getSelectedVariantFreeDrinksRequirement();
      } else {
        // For regular LTO items, use default pricing
        final hasFreeDrinks = _checkHasFreeDrinks();
        if (hasFreeDrinks) {
          requiredDrinks = _getRequiredFreeDrinksQuantity();
        }
      }

      // Only validate if free drinks are actually required (quantity > 0)
      if (requiredDrinks > 0) {
        final selectedDrinksCount = _selectedDrinks.fold<int>(
          0,
          (sum, drink) => sum + (_drinkQuantities[drink.id] ?? 0),
        );

        if (selectedDrinksCount == 0) {
          setState(() {
            _errorMessage =
                'Please select your $requiredDrinks complimentary ${requiredDrinks == 1 ? 'drink' : 'drinks'}';
          });
          // Auto-clear error after 5 seconds
          Future.delayed(const Duration(seconds: 5), () {
            if (mounted) {
              _clearError();
            }
          });
          return false;
        }
      }
    }

    return true;
  }

  Future<bool> _addToCart() async {
    return addToCart(
      AddToCartParams(
        context: context,
        menuItem: widget.menuItem,
        restaurant: widget.restaurant,
        isSpecialPack: _isSpecialPack,
        popupSessionId: _popupSessionId,
        savedOrders: _savedOrders,
        selectedVariants: _selectedVariants,
        selectedPricingPerVariant: _selectedPricingPerVariant,
        paidDrinkQuantities: _paidDrinkQuantities,
        selectedDrinks: _selectedDrinks,
        drinkQuantities: _drinkQuantities,
        drinkSizesById: _drinkSizesById,
        quantity: _quantity,
        selectedSupplements: _selectedSupplements,
        removedIngredients: _removedIngredients,
        ingredientPreferences: _ingredientPreferences,
        packItemSelections: _packItemSelections,
        packIngredientPreferences: _packIngredientPreferences,
        packSupplementSelections: _packSupplementSelections,
        savedVariantOrders: _savedVariantOrders,
        enhancedMenuItem: _enhancedMenuItem,
        restaurantDrinks: _restaurantDrinks,
        specialNote: _specialNote,
        validateSelection: _validateSelection,
        buildSpecialInstructions: _buildSpecialInstructions,
        convertIngredientPreferencesToJson: _convertIngredientPreferencesToJson,
        parsePackItemOptions: _parsePackItemOptions,
        clearPreferences: _clearPreferences,
        onComplete: () {
          setState(() {
            _savedOrders.clear();
            _savedVariantOrders.clear();
          });
        },
      ),
    );
  }

  /// Check if the current item has free drinks available
  bool _checkHasFreeDrinks() {
    if (_enhancedMenuItem == null || _enhancedMenuItem!.pricing.isEmpty) {
      return false;
    }

    // Check if any pricing has free drinks
    for (final pricing in _enhancedMenuItem!.pricing) {
      if (pricing.freeDrinksList.isNotEmpty && pricing.freeDrinksQuantity > 0) {
        return true;
      }
    }

    return false;
  }

  /// Get the required free drinks quantity
  /// For LTO and regular items: multiplies base quantity by item quantity
  /// For special packs: returns base quantity
  int _getRequiredFreeDrinksQuantity() {
    if (_enhancedMenuItem == null || _enhancedMenuItem!.pricing.isEmpty) {
      return 0;
    }

    // Get the default pricing or first pricing
    final defaultPricing = _enhancedMenuItem!.pricing.firstWhere(
      (p) => p.isDefault,
      orElse: () => _enhancedMenuItem!.pricing.first,
    );

    final baseQuantity = defaultPricing.freeDrinksQuantity;

    // For LTO and regular items: multiply by item quantity
    // For special packs: return base quantity
    if (!_isSpecialPack) {
      // Use the current item quantity or variant quantity if available
      int itemQuantity = _quantity;

      // For regular items with per-variant quantities, use the sum of variant quantities
      if (_variantQuantities.isNotEmpty) {
        itemQuantity =
            _variantQuantities.values.fold(0, (sum, qty) => sum + qty);
        if (itemQuantity == 0) {
          itemQuantity = _quantity; // Fallback to global quantity
        }
      }

      return baseQuantity * itemQuantity;
    }

    // Special packs: return base quantity
    return baseQuantity;
  }

  /// Check if selected variants require free drinks (for special packs)
  /// Returns the required quantity if any selected variant requires free drinks, 0 otherwise
  int _getSelectedVariantFreeDrinksRequirement() {
    if (_selectedVariants.isEmpty || _selectedPricingPerVariant.isEmpty) {
      return 0;
    }

    // Check each selected variant's pricing
    int maxRequired = 0;
    for (final variantId in _selectedVariants) {
      final pricing = _selectedPricingPerVariant[variantId];
      if (pricing != null && pricing.freeDrinksQuantity > 0) {
        if (pricing.freeDrinksQuantity > maxRequired) {
          maxRequired = pricing.freeDrinksQuantity;
        }
      }
    }

    return maxRequired;
  }

  /// Build drinks payload with sizes (free and paid drinks)
  /// Extracted to remove duplication across multiple methods
  /// ✅ FIX: Paid drinks should come FIRST, then free drinks (matching display order)
  List<Map<String, dynamic>> _buildDrinksWithSizes() {
    // Collect all free drink IDs (from selected drinks + from pricing)
    final allFreeDrinkIds = <String>{};

    // Add manually selected free drinks
    for (final drink in _selectedDrinks) {
      // Only include if NOT a paid drink (paid drinks are tracked separately)
      if (!_paidDrinkQuantities.containsKey(drink.id) ||
          (_paidDrinkQuantities[drink.id] ?? 0) == 0) {
        allFreeDrinkIds.add(drink.id);
      }
    }

    // ✅ FIX: Add free drinks from pricing (even if not manually selected)
    // This ensures free drinks calculated from pricing are included in the drinks list
    if (_enhancedMenuItem != null) {
      for (final variantId in _selectedVariants) {
        final pricing = _selectedPricingPerVariant[variantId];
        if (pricing != null && pricing.freeDrinksIncluded) {
          final freeDrinkIds = pricing.freeDrinksList;
          for (final drinkId in freeDrinkIds) {
            // Only include if NOT a paid drink
            if (!_paidDrinkQuantities.containsKey(drinkId) ||
                (_paidDrinkQuantities[drinkId] ?? 0) == 0) {
              allFreeDrinkIds.add(drinkId);
            }
          }
        }
      }
    }

    return <Map<String, dynamic>>[
      // Paid drinks FIRST
      ..._paidDrinkQuantities.entries
          .map((entry) =>
              _restaurantDrinks.where((d) => d.id == entry.key).map((drink) {
                final map = drink.toJson();
                final sz = _drinkSizesById[drink.id];
                if (sz != null && sz.isNotEmpty) map['size'] = sz;
                map['is_free'] = false;
                return map;
              }))
          .expand((e) => e),
      // Free drinks SECOND - include manually selected + free drinks from pricing
      ...allFreeDrinkIds.map((drinkId) {
        // Try to find drink in selected drinks first (has full data)
        final selectedDrink = _selectedDrinks.firstWhere(
          (d) => d.id == drinkId,
          orElse: () => _restaurantDrinks.firstWhere(
            (d) => d.id == drinkId,
            orElse: () => MenuItem(
              id: drinkId,
              name: 'Unknown Drink',
              description: '',
              price: 0,
              restaurantId: '',
              category: '',
              isAvailable: true,
              image: '',
              isFeatured: false,
              preparationTime: 0,
              rating: 0.0,
              reviewCount: 0,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          ),
        );
        final map = selectedDrink.toJson();
        final sz = _drinkSizesById[drinkId];
        if (sz != null && sz.isNotEmpty) map['size'] = sz;
        map['price'] = 0.0;
        map['is_free'] = true;
        return map;
      }),
    ];
  }

  void _removeSavedOrder(int index) {
    setState(() {
      _savedOrders.removeAt(index);
    });
  }

  Future<void> _navigateToConfirmFlow() async {
    final cartProvider = Provider.of<CartProvider>(context, listen: false);

    // Validate selection (including free drinks check)
    if (!_validateSelection(checkFreeDrinks: true)) {
      return;
    }

    final hasSavedVariantOrders =
        _savedVariantOrders.values.any((orders) => orders.isNotEmpty);

    // Calculate paid drinks price ONCE globally (drinks are global for entire order)
    final totalPaidDrinksPrice = calculatePaidDrinksPrice(
      paidDrinkQuantities: _paidDrinkQuantities,
      restaurantDrinks: _restaurantDrinks,
    );

    // Track if drinks have been added (global flag - drinks only added once)
    bool drinksAdded = false;

    // First add any saved orders to cart if they exist
    if (_savedOrders.isNotEmpty) {
      final savedOrdersHadDrinks = addSavedOrdersToCart(
        savedOrders: _savedOrders,
        cartProvider: cartProvider,
        menuItem: widget.menuItem,
        restaurant: widget.restaurant,
        restaurantDrinks: _restaurantDrinks,
        drinkSizesById: _drinkSizesById,
      );
      if (savedOrdersHadDrinks) {
        drinksAdded = true;
      }
      // Clear saved orders after adding to cart
      _savedOrders.clear();
    } else if (hasSavedVariantOrders) {
      // Convert saved variant orders into cart items
      final variants = _enhancedMenuItem?.variants ?? [];

      // Handle unified pack orders separately from regular variant orders
      if (_isSpecialPack && _savedVariantOrders.containsKey('pack')) {
        // Process unified pack orders
        final savedPackOrders = _savedVariantOrders['pack']!;
        final params = NavigateToConfirmFlowParams(
          cartProvider: cartProvider,
          menuItem: widget.menuItem,
          restaurant: widget.restaurant,
          enhancedMenuItem: _enhancedMenuItem,
          isSpecialPack: _isSpecialPack,
          selectedVariants: _selectedVariants,
          selectedPricingPerVariant: _selectedPricingPerVariant,
          selectedSupplements: _selectedSupplements,
          removedIngredients: _removedIngredients,
          ingredientPreferences: _ingredientPreferences,
          savedOrders: _savedOrders,
          selectedDrinks: _selectedDrinks,
          restaurantDrinks: _restaurantDrinks,
          drinkQuantities: _drinkQuantities,
          paidDrinkQuantities: _paidDrinkQuantities,
          drinkSizesById: _drinkSizesById,
          quantity: _quantity,
          variantQuantities: _variantQuantities,
          packItemSelections: _packItemSelections,
          packIngredientPreferences: _packIngredientPreferences,
          packSupplementSelections: _packSupplementSelections,
          savedVariantOrders: _savedVariantOrders,
          popupSessionId: _popupSessionId,
          buildSpecialInstructions: _buildSpecialInstructions,
          convertIngredientPreferencesToJson:
              _convertIngredientPreferencesToJson,
          parsePackItemOptions: _parsePackItemOptions,
        );
        final savedPackHadDrinks = addSavedUnifiedPackOrdersToCart(
          params: params,
          savedPackOrders: savedPackOrders,
          totalPaidDrinksPrice: totalPaidDrinksPrice,
          buildDrinksWithSizes: _buildDrinksWithSizes,
          isFirstOverallItem: !drinksAdded,
        );
        if (savedPackHadDrinks) {
          drinksAdded = true;
        }
        // Old code removed - now handled by helper
      } else {
        // For regular variant orders, process each variant separately
        final params = NavigateToConfirmFlowParams(
          cartProvider: cartProvider,
          menuItem: widget.menuItem,
          restaurant: widget.restaurant,
          enhancedMenuItem: _enhancedMenuItem,
          isSpecialPack: _isSpecialPack,
          selectedVariants: _selectedVariants,
          selectedPricingPerVariant: _selectedPricingPerVariant,
          selectedSupplements: _selectedSupplements,
          removedIngredients: _removedIngredients,
          ingredientPreferences: _ingredientPreferences,
          savedOrders: _savedOrders,
          selectedDrinks: _selectedDrinks,
          restaurantDrinks: _restaurantDrinks,
          drinkQuantities: _drinkQuantities,
          paidDrinkQuantities: _paidDrinkQuantities,
          drinkSizesById: _drinkSizesById,
          quantity: _quantity,
          variantQuantities: _variantQuantities,
          packItemSelections: _packItemSelections,
          packIngredientPreferences: _packIngredientPreferences,
          packSupplementSelections: _packSupplementSelections,
          savedVariantOrders: _savedVariantOrders,
          popupSessionId: _popupSessionId,
          buildSpecialInstructions: _buildSpecialInstructions,
          convertIngredientPreferencesToJson:
              _convertIngredientPreferencesToJson,
          parsePackItemOptions: _parsePackItemOptions,
        );
        final savedVariantOrdersHadDrinks = addSavedVariantOrdersToCart(
          params: params,
          savedVariantOrders: _savedVariantOrders,
          variants: variants,
        );
        if (savedVariantOrdersHadDrinks) {
          drinksAdded = true;
        }
        // Old code removed - now handled by helper
      }
      _savedVariantOrders.clear();
    }

    // Add current selections (variants) if any are still selected with pricing
    // Always add current selections if they exist (even if saved orders were added)
    // This allows users to have both saved orders AND current unsaved selections in cart
    if (_selectedVariants.isNotEmpty) {
      final variants = _enhancedMenuItem?.variants ?? [];
      final params = NavigateToConfirmFlowParams(
        cartProvider: cartProvider,
        menuItem: widget.menuItem,
        restaurant: widget.restaurant,
        enhancedMenuItem: _enhancedMenuItem,
        isSpecialPack: _isSpecialPack,
        selectedVariants: _selectedVariants,
        selectedPricingPerVariant: _selectedPricingPerVariant,
        selectedSupplements: _selectedSupplements,
        removedIngredients: _removedIngredients,
        ingredientPreferences: _ingredientPreferences,
        savedOrders: _savedOrders,
        selectedDrinks: _selectedDrinks,
        restaurantDrinks: _restaurantDrinks,
        drinkQuantities: _drinkQuantities,
        paidDrinkQuantities: _paidDrinkQuantities,
        drinkSizesById: _drinkSizesById,
        quantity: _quantity,
        variantQuantities: _variantQuantities,
        packItemSelections: _packItemSelections,
        packIngredientPreferences: _packIngredientPreferences,
        packSupplementSelections: _packSupplementSelections,
        savedVariantOrders: _savedVariantOrders,
        popupSessionId: _popupSessionId,
        buildSpecialInstructions: _buildSpecialInstructions,
        convertIngredientPreferencesToJson: _convertIngredientPreferencesToJson,
        parsePackItemOptions: _parsePackItemOptions,
      );

      // For special packs, create ONE unified cart item instead of separate items per variant
      if (_isSpecialPack) {
        drinksAdded = addCurrentSpecialPackSelectionsToCart(
          params: params,
          totalPaidDrinksPrice: totalPaidDrinksPrice,
          buildDrinksWithSizes: _buildDrinksWithSizes,
          buildSpecialInstructions: _buildSpecialInstructions,
          convertIngredientPreferencesToJson:
              _convertIngredientPreferencesToJson,
          parsePackItemOptions: _parsePackItemOptions,
          drinksAdded: drinksAdded,
        );
      } else {
        // For regular items, add each variant separately
        drinksAdded = addCurrentVariantSelectionsToCart(
          params: params,
          variants: variants,
          totalPaidDrinksPrice: totalPaidDrinksPrice,
          buildDrinksWithSizes: _buildDrinksWithSizes,
          buildSpecialInstructions: _buildSpecialInstructions,
          convertIngredientPreferencesToJson:
              _convertIngredientPreferencesToJson,
          parsePackItemOptions: _parsePackItemOptions,
          drinksAdded: drinksAdded,
        );
      }
    } else if (_selectedVariants.isEmpty && !hasSavedVariantOrders) {
      // No variants selected and no saved variants: add single item selection
      final params = NavigateToConfirmFlowParams(
        cartProvider: cartProvider,
        menuItem: widget.menuItem,
        restaurant: widget.restaurant,
        enhancedMenuItem: _enhancedMenuItem,
        isSpecialPack: _isSpecialPack,
        selectedVariants: _selectedVariants,
        selectedPricingPerVariant: _selectedPricingPerVariant,
        selectedSupplements: _selectedSupplements,
        removedIngredients: _removedIngredients,
        ingredientPreferences: _ingredientPreferences,
        savedOrders: _savedOrders,
        selectedDrinks: _selectedDrinks,
        restaurantDrinks: _restaurantDrinks,
        drinkQuantities: _drinkQuantities,
        paidDrinkQuantities: _paidDrinkQuantities,
        drinkSizesById: _drinkSizesById,
        quantity: _quantity,
        variantQuantities: _variantQuantities,
        packItemSelections: _packItemSelections,
        packIngredientPreferences: _packIngredientPreferences,
        packSupplementSelections: _packSupplementSelections,
        savedVariantOrders: _savedVariantOrders,
        popupSessionId: _popupSessionId,
        buildSpecialInstructions: _buildSpecialInstructions,
        convertIngredientPreferencesToJson: _convertIngredientPreferencesToJson,
        parsePackItemOptions: _parsePackItemOptions,
      );

      // Handle multiple variant selections
      if (_selectedVariants.isEmpty) {
        // No variants selected, add single item
        addSingleItemToCart(
          params: params,
          totalPaidDrinksPrice: totalPaidDrinksPrice,
          buildDrinksWithSizes: _buildDrinksWithSizes,
          buildSpecialInstructions: _buildSpecialInstructions,
        );
      } else {
        // Add each selected variant as a separate cart item
        final variants = _enhancedMenuItem?.variants ?? [];
        addCurrentVariantSelectionsToCart(
          params: params,
          variants: variants,
          totalPaidDrinksPrice: totalPaidDrinksPrice,
          buildDrinksWithSizes: _buildDrinksWithSizes,
          buildSpecialInstructions: _buildSpecialInstructions,
          convertIngredientPreferencesToJson:
              _convertIngredientPreferencesToJson,
          parsePackItemOptions: _parsePackItemOptions,
          drinksAdded: false, // This branch doesn't track drinksAdded
        );
      }
    }

    // Navigate to cart: first dismiss popup, then push Cart so back returns to previous screen
    await navigateToCartScreen(context);
  }

  Future<void> _submitOrder() async {
    // ✅ NEW EDIT LOGIC: Use EditOrderBridge for edit mode
    if (_editOrderManager?.isEditMode == true &&
        widget.existingCartItem != null) {
      debugPrint('🔗 MenuItemPopupWidget: Using new edit order system');

      // Sync current popup state to manager before saving
      final popupState = PopupStateVariables(
        selectedVariants: _selectedVariants,
        selectedPricingPerVariant: _selectedPricingPerVariant,
        selectedSupplements: _selectedSupplements,
        removedIngredients: _removedIngredients,
        ingredientPreferences: _ingredientPreferences,
        selectedDrinks: _selectedDrinks,
        drinkQuantities: _drinkQuantities,
        paidDrinkQuantities: _paidDrinkQuantities,
        drinkSizesById: _drinkSizesById,
        packItemSelections: _packItemSelections,
        packIngredientPreferences: _packIngredientPreferences,
        packSupplementSelections: _packSupplementSelections,
        savedVariantOrders: _savedVariantOrders,
        quantity: _quantity,
        specialNote: _specialNote,
      );

      EditOrderBridge.syncPopupStateToManager(
        popupState,
        _editOrderManager!,
        _enhancedMenuItem,
      );

      // Update cart with edited order
      final cartProvider = Provider.of<CartProvider>(context, listen: false);
      EditOrderBridge.updateCartWithEditedOrder(
        cartProvider: cartProvider,
        manager: _editOrderManager!,
        menuItem: widget.menuItem,
        enhancedMenuItem: _enhancedMenuItem,
        restaurantDrinks: _restaurantDrinks,
      );

      // Call callback if provided
      // Fetch the updated cart item to get the correct customizations
      if (widget.onItemAddedToCart != null) {
        final updatedCartItem = cartProvider.items.firstWhere(
          (item) => item.id == widget.existingCartItem!.id,
          orElse: () => widget.existingCartItem!,
        );

        // Create OrderItem from updated CartItem with proper customizations
        final orderItem = OrderItem(
          id: updatedCartItem.id,
          orderId: '',
          menuItemId: widget.menuItem.id,
          menuItem: widget.menuItem,
          quantity: updatedCartItem.quantity,
          unitPrice: updatedCartItem.price,
          totalPrice: updatedCartItem.totalPrice,
          customizations: updatedCartItem.customizations != null
              ? MenuItemCustomizations.fromMap(updatedCartItem.customizations!)
              : null,
          specialInstructions: updatedCartItem.specialInstructions,
          createdAt: DateTime.now(),
        );
        widget.onItemAddedToCart!(orderItem);
      }

      // Close popup
      if (mounted) {
        Navigator.of(context).pop();
      }

      return;
    }

    // Legacy submit logic (for non-edit mode)
    final params = SubmitOrderParams(
      context: context,
      existingCartItem: widget.existingCartItem,
      originalOrderItemId: widget.originalOrderItemId,
      onItemAddedToCart: widget.onItemAddedToCart,
      menuItem: widget.menuItem,
      restaurant: widget.restaurant,
      enhancedMenuItem: _enhancedMenuItem,
      isSpecialPack: _isSpecialPack,
      selectedVariants: _selectedVariants,
      selectedPricingPerVariant: _selectedPricingPerVariant,
      selectedSupplements: _selectedSupplements,
      removedIngredients: _removedIngredients,
      ingredientPreferences: _ingredientPreferences,
      savedOrders: _savedOrders,
      selectedDrinks: _selectedDrinks,
      restaurantDrinks: _restaurantDrinks,
      drinkQuantities: _drinkQuantities,
      paidDrinkQuantities: _paidDrinkQuantities,
      drinkSizesById: _drinkSizesById,
      quantity: _quantity,
      variantQuantities: _variantQuantities,
      packItemSelections: _packItemSelections,
      packIngredientPreferences: _packIngredientPreferences,
      packSupplementSelections: _packSupplementSelections,
      popupSessionId: _popupSessionId,
      buildSpecialInstructions: _buildSpecialInstructions,
      buildDrinksWithSizes: _buildDrinksWithSizes,
      convertIngredientPreferencesToJson: _convertIngredientPreferencesToJson,
      parsePackItemOptions: _parsePackItemOptions,
      setLoadingState: (isLoading) => setState(() => _isLoading = isLoading),
      isMounted: () => mounted,
    );

    await submitOrder(params);
  }

  Color _getIngredientBackgroundColor(IngredientPreference preference) {
    switch (preference) {
      case IngredientPreference.wanted:
        return Colors.green[50]!;
      case IngredientPreference.less:
        return Colors.yellow[50]!;
      case IngredientPreference.none:
        return Colors.red[50]!;
      case IngredientPreference.neutral:
        return Colors.white;
    }
  }

  Color _getIngredientBorderColor(IngredientPreference preference) {
    switch (preference) {
      case IngredientPreference.wanted:
        return Colors.green;
      case IngredientPreference.less:
        return Colors.orange;
      case IngredientPreference.none:
        return Colors.red;
      case IngredientPreference.neutral:
        return Colors.grey[300]!;
    }
  }

  IconData _getIngredientIcon(IngredientPreference preference) {
    switch (preference) {
      case IngredientPreference.wanted:
        return Icons.add_circle;
      case IngredientPreference.less:
        return Icons.remove_circle_outline;
      case IngredientPreference.none:
        return Icons.cancel;
      case IngredientPreference.neutral:
        return Icons.radio_button_unchecked;
    }
  }

  Color _getIngredientIconColor(IngredientPreference preference) {
    switch (preference) {
      case IngredientPreference.wanted:
        return Colors.green;
      case IngredientPreference.less:
        return Colors.orange;
      case IngredientPreference.none:
        return Colors.red;
      case IngredientPreference.neutral:
        return Colors.grey[400]!;
    }
  }

  Color _getIngredientTextColor(IngredientPreference preference) {
    switch (preference) {
      case IngredientPreference.wanted:
        return Colors.green[800]!;
      case IngredientPreference.less:
        return Colors.orange[800]!;
      case IngredientPreference.none:
        return Colors.red[800]!;
      case IngredientPreference.neutral:
        return textPrimary;
    }
  }

  String? _buildSpecialInstructions() {
    final List<String> instructions = [];

    // Add removed ingredients
    if (_removedIngredients.isNotEmpty) {
      instructions.add('Remove: ${_removedIngredients.join(', ')}');
    }

    // Add special note
    if (_specialNote.trim().isNotEmpty) {
      instructions.add('Note: ${_specialNote.trim()}');
    }

    // Add ingredient preferences
    if (_ingredientPreferences.isNotEmpty) {
      final wanted = _ingredientPreferences.entries
          .where((e) => e.value == IngredientPreference.wanted)
          .map((e) => e.key)
          .toList();
      final less = _ingredientPreferences.entries
          .where((e) => e.value == IngredientPreference.less)
          .map((e) => e.key)
          .toList();
      final none = _ingredientPreferences.entries
          .where((e) => e.value == IngredientPreference.none)
          .map((e) => e.key)
          .toList();

      if (wanted.isNotEmpty) {
        instructions.add('Extra: ${wanted.join(', ')}');
      }
      if (less.isNotEmpty) {
        instructions.add('Less: ${less.join(', ')}');
      }
      if (none.isNotEmpty) {
        instructions.add('No: ${none.join(', ')}');
      }
    }

    return instructions.isNotEmpty ? instructions.join(' | ') : null;
  }

  /// Convert pack ingredient preferences to JSON format
  /// Structure: {variant_name: {quantity_index: {ingredient: 'wanted'|'less'|'none'}}}
  Map<String, dynamic> _convertIngredientPreferencesToJson(
      Map<String, Map<int, Map<String, IngredientPreference>>> prefs) {
    final result = <String, dynamic>{};

    debugPrint('🥗 Converting ingredient preferences to JSON:');
    debugPrint('   Input prefs keys: ${prefs.keys.join(', ')}');

    // Since we're already storing by variant name, we can directly convert
    prefs.forEach((variantName, quantityMap) {
      final quantityJson = <String, dynamic>{};
      quantityMap.forEach((qtyIndex, ingredientMap) {
        final ingredientJson = <String, String>{};
        ingredientMap.forEach((ingredient, preference) {
          // Only save non-neutral preferences to reduce data size
          if (preference != IngredientPreference.neutral) {
            final prefStr = preference
                .toString()
                .split('.')
                .last; // 'wanted', 'less', or 'none'
            ingredientJson[ingredient] = prefStr;
            debugPrint('   [$variantName][$qtyIndex] $ingredient: $prefStr');
          }
        });
        if (ingredientJson.isNotEmpty) {
          quantityJson[qtyIndex.toString()] = ingredientJson;
        }
      });
      if (quantityJson.isNotEmpty) {
        result[variantName] = quantityJson;
      }
    });

    debugPrint('   Final JSON: $result');
    return result;
  }

  // ==================== SKELETON LOADER METHODS ====================

  // Data validation methods
  bool _validateMenuItemData(MenuItem menuItem) {
    if (menuItem.price <= 0) {
      debugPrint(
          '🚨 MenuItem validation failed: Invalid price ${menuItem.price}');
      return false;
    }

    if (menuItem.name.isEmpty) {
      debugPrint('🚨 MenuItem validation failed: Empty name');
      return false;
    }

    if (menuItem.restaurantId.isEmpty) {
      debugPrint('🚨 MenuItem validation failed: Empty restaurantId');
      return false;
    }

    if (!menuItem.isAvailable) {
      debugPrint('🚨 MenuItem validation failed: Item not available');
      return false;
    }

    debugPrint('✅ MenuItem validation passed: ${menuItem.name}');
    return true;
  }

  bool _validateRestaurantData(Restaurant? restaurant) {
    if (restaurant == null) {
      debugPrint(
          '⚠️ Restaurant validation: Restaurant is null (using fallback)');
      return true; // Null is acceptable, we'll use fallback
    }

    if (restaurant.deliveryFee < 0) {
      debugPrint(
          '🚨 Restaurant validation failed: Invalid delivery fee ${restaurant.deliveryFee}');
      return false;
    }

    if (restaurant.minimumOrder < 0) {
      debugPrint(
          '🚨 Restaurant validation failed: Invalid minimum order ${restaurant.minimumOrder}');
      return false;
    }

    if (restaurant.estimatedDeliveryTime <= 0) {
      debugPrint(
          '🚨 Restaurant validation failed: Invalid delivery time ${restaurant.estimatedDeliveryTime}');
      return false;
    }

    if (restaurant.name.isEmpty) {
      debugPrint('🚨 Restaurant validation failed: Empty restaurant name');
      return false;
    }

    debugPrint('✅ Restaurant validation passed: ${restaurant.name}');
    return true;
  }

  bool _validateCustomizationData(Map<String, dynamic>? customizations) {
    if (customizations == null) {
      debugPrint('✅ Customization validation: No customizations (valid)');
      return true; // Null is valid
    }

    // Check for required fields if customizations exist
    if (customizations.containsKey('menu_item_id') &&
        customizations['menu_item_id'] == null) {
      debugPrint('🚨 Customization validation failed: menu_item_id is null');
      return false;
    }

    if (customizations.containsKey('restaurant_id') &&
        customizations['restaurant_id'] == null) {
      debugPrint('🚨 Customization validation failed: restaurant_id is null');
      return false;
    }

    debugPrint('✅ Customization validation passed');
    return true;
  }

  void _handleDataError(String context, String error) {
    debugPrint('🚨 Data Error in $context: $error');

    // Show user-friendly error message
    if (mounted) {
      ScaffoldMessenger.of(this.context).showSnackBar(
        SnackBar(
          content: Text(
            'Data validation error: $error',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ==================== REGULAR ITEM HELPER METHODS ====================

  /// Build special note field for special packs
  Widget? _buildSpecialNoteField() {
    if (!_isSpecialPack) {
      return null;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        controller: _specialNoteController,
        onChanged: (value) {
          _specialNote = value;
        },
        minLines: 1,
        maxLines: 3,
        maxLength: 200,
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)!.addSpecialInstructions,
          hintStyle: GoogleFonts.poppins(
            fontSize: 13,
            color: textSecondary,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          counterText: '',
        ),
        style: GoogleFonts.poppins(
          fontSize: 13,
          color: textPrimary,
        ),
      ),
    );
  }

  /// Build note field for variant
  Widget _buildVariantNoteField(MenuItemVariant variant) {
    // Initialize controller if it doesn't exist
    if (!_variantNoteControllers.containsKey(variant.id)) {
      _variantNoteControllers[variant.id] = TextEditingController(
        text: _variantNotes[variant.id] ?? '',
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: TextField(
        controller: _variantNoteControllers[variant.id],
        onChanged: (value) {
          _variantNotes[variant.id] = value;
        },
        minLines: 1,
        maxLines: 3,
        maxLength: 200,
        decoration: InputDecoration(
          hintText: AppLocalizations.of(context)!.addSpecialInstructions,
          hintStyle: GoogleFonts.poppins(
            fontSize: 13,
            color: textSecondary,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          counterText: '',
        ),
        style: GoogleFonts.poppins(
          fontSize: 13,
          color: textPrimary,
        ),
      ),
    );
  }
}
