import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/promo_code.dart';
import '../services/delivery_fee_service.dart';
import '../services/system_config_service.dart';

class CartItem {
  final String id;
  final String name;
  final double price;
  final int quantity;
  final String? image;
  final String? restaurantName;
  final Map<String, dynamic>? customizations;
  final String? specialInstructions;
  final Map<String, int>? drinkQuantities;

  CartItem({
    required this.id,
    required this.name,
    required this.price,
    required this.quantity,
    this.image,
    this.restaurantName,
    this.customizations,
    this.specialInstructions,
    this.drinkQuantities,
  });

  double get totalPrice => price * quantity;

  CartItem copyWith({
    String? id,
    String? name,
    double? price,
    int? quantity,
    String? image,
    String? restaurantName,
    Map<String, dynamic>? customizations,
    String? specialInstructions,
    Map<String, int>? drinkQuantities,
  }) {
    return CartItem(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      quantity: quantity ?? this.quantity,
      image: image ?? this.image,
      restaurantName: restaurantName ?? this.restaurantName,
      customizations: customizations ?? this.customizations,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      drinkQuantities: drinkQuantities ?? this.drinkQuantities,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'quantity': quantity,
      'image': image,
      'restaurantName': restaurantName,
      'customizations': customizations,
      'specialInstructions': specialInstructions,
      'drinkQuantities': drinkQuantities,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    // Debug: Log the raw price value
    final rawPrice = map['price'];
    debugPrint(
        '🛒 CartItem.fromMap: Raw price value: $rawPrice (type: ${rawPrice.runtimeType})');

    // Improved price parsing with better error handling
    double parsedPrice = 0.0;
    if (rawPrice is num) {
      parsedPrice = rawPrice.toDouble();
    } else if (rawPrice is String) {
      parsedPrice = double.tryParse(rawPrice) ?? 0.0;
    } else if (rawPrice != null) {
      // Try to convert to string first, then parse
      parsedPrice = double.tryParse(rawPrice.toString()) ?? 0.0;
    }

    debugPrint('🛒 CartItem.fromMap: Parsed price: $parsedPrice');

    return CartItem(
      id: (map['id'] ?? '').toString(),
      name: (map['name'] ?? '').toString(),
      price: parsedPrice,
      quantity: map['quantity'] is int
          ? map['quantity'] as int
          : int.tryParse(map['quantity']?.toString() ?? '1') ?? 1,
      image: map['image']?.toString(),
      restaurantName: map['restaurantName']?.toString(),
      customizations: map['customizations'] is Map<String, dynamic>
          ? Map<String, dynamic>.from(map['customizations'])
          : null,
      specialInstructions: map['specialInstructions']?.toString(),
      drinkQuantities: map['drinkQuantities'] is Map
          ? Map<String, int>.from((map['drinkQuantities'] as Map).map((k, v) =>
              MapEntry(k.toString(),
                  (v is int) ? v : int.tryParse(v.toString()) ?? 0)))
          : null,
    );
  }
}

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];
  SharedPreferences? _prefs;
  PromoCode? _appliedPromoCode;

  // Delivery fee service
  final DeliveryFeeService _deliveryFeeService = DeliveryFeeService();

  // Current delivery location
  double? _deliveryLatitude;
  double? _deliveryLongitude;
  String? _deliveryAddress;
  String? _currentRestaurantId;

  // Cached delivery fee
  double? _cachedDeliveryFee;

  // ✅ FIX: Separate paid drinks store (independent from order cards)
  // This avoids conflicts in calculations between cart drinks section and order cards
  final Map<String, int> _paidDrinkQuantities = {};
  final Map<String, double> _paidDrinkPrices = {}; // Store drink prices separately

  List<CartItem> get items => List.unmodifiable(_items);

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  PromoCode? get appliedPromoCode => _appliedPromoCode;

  // ✅ FIX: Get paid drinks quantities (separate from order cards)
  Map<String, int> get paidDrinkQuantities => Map<String, int>.from(_paidDrinkQuantities);

  // ✅ FIX: Get paid drinks total (separate calculation)
  double get paidDrinksTotal {
    double total = 0.0;
    _paidDrinkQuantities.forEach((drinkId, quantity) {
      final price = _paidDrinkPrices[drinkId] ?? 0.0;
      total += price * quantity;
    });
    return total;
  }

  // ✅ FIX: Subtotal excludes paid drinks (paid drinks are calculated separately)
  // Items should not include paid drinks price to avoid double-counting
  double get subtotal => _items.fold(0.0, (sum, item) => sum + item.totalPrice);

  double get discountAmount {
    if (_appliedPromoCode == null) return 0.0;
    return _appliedPromoCode!.calculateDiscount(subtotal);
  }

  double get totalPrice {
    final total = subtotal - discountAmount;

    debugPrint(
        '🛒 CartProvider.totalPrice: subtotal=$subtotal, discount=$discountAmount, total=$total');
    for (final item in _items) {
      debugPrint(
          '  - ${item.name}: ${item.price} x ${item.quantity} = ${item.totalPrice}');
    }
    debugPrint('  - Applied promo: ${_appliedPromoCode?.code ?? 'None'}');

    return total > 0 ? total : 0.0; // Ensure total is never negative
  }

  // Service fee calculation using SystemConfigService
  double get serviceFee {
    final systemConfigService = SystemConfigService();
    return systemConfigService.serviceFee;
  }

  // Delivery fee calculation using distance-based logic
  double? get deliveryLatitude => _deliveryLatitude;
  double? get deliveryLongitude => _deliveryLongitude;
  String? get deliveryAddress => _deliveryAddress;

  double get deliveryFee {
    // First, check if any cart item has special_delivery offer
    final specialDeliveryDiscount = _calculateSpecialDeliveryDiscount();

    // Return cached fee if available
    if (_cachedDeliveryFee != null) {
      final baseFee = (_cachedDeliveryFee! * 100).round() / 100;
      final adjustedFee = baseFee - specialDeliveryDiscount;

      // Ensure delivery fee never goes negative
      return adjustedFee > 0 ? adjustedFee : 0.0;
    }

    // Fallback to fixed fee if no location data
    const fallbackFee = 2.99;
    final adjustedFee = fallbackFee - specialDeliveryDiscount;
    return adjustedFee > 0 ? adjustedFee : 0.0;
  }

  /// Set delivery fee from real-time updates
  void setDeliveryFee(double fee) {
    // Round to 2 decimal places before storing
    _cachedDeliveryFee = (fee * 100).round() / 100;
    notifyListeners();
  }

  // Total order amount including all fees
  // ✅ FIX: Include paid drinks separately (not in subtotal to avoid conflicts)
  double get totalOrderAmount {
    final subtotalAfterDiscount = subtotal - discountAmount;
    final paidDrinksTotal = this.paidDrinksTotal; // Separate paid drinks calculation
    final baseDeliveryFee = _cachedDeliveryFee;
    final specialDeliveryDiscount = _calculateSpecialDeliveryDiscount();
    final adjustedDeliveryFee = (deliveryFee * 100).round() / 100;
    final total = subtotalAfterDiscount + paidDrinksTotal + adjustedDeliveryFee + serviceFee;

    debugPrint('💰 CartProvider.totalOrderAmount calculation:');
    debugPrint('   subtotal: $subtotal');
    debugPrint('   paid_drinks_total: $paidDrinksTotal');
    debugPrint('   discount: $discountAmount');
    debugPrint('   subtotal_after_discount: $subtotalAfterDiscount');
    debugPrint('   base_delivery_fee: $baseDeliveryFee');
    debugPrint('   special_delivery_discount: $specialDeliveryDiscount');
    debugPrint('   adjusted_delivery_fee: $adjustedDeliveryFee');
    debugPrint('   service_fee: $serviceFee');
    debugPrint('   total: ${(total * 100).round() / 100}');

    // Round to 2 decimal places to avoid floating point issues
    return (total * 100).round() / 100;
  }

  // Get detailed fee breakdown
  // ✅ FIX: Include paid drinks separately in breakdown
  Map<String, double> get feeBreakdown {
    final subtotalAfterDiscount = subtotal - discountAmount;
    final paidDrinksTotal = this.paidDrinksTotal; // Separate paid drinks calculation
    final specialDeliveryDiscount = _calculateSpecialDeliveryDiscount();
    final baseDeliveryFee = _cachedDeliveryFee ?? 2.99;
    final adjustedDeliveryFee = deliveryFee;

    return {
      'subtotal': (subtotal * 100).round() / 100,
      'paid_drinks_total': (paidDrinksTotal * 100).round() / 100,
      'discount': (discountAmount * 100).round() / 100,
      'subtotal_after_discount': (subtotalAfterDiscount * 100).round() / 100,
      'base_delivery_fee': baseDeliveryFee,
      'special_delivery_discount': specialDeliveryDiscount,
      'delivery_fee': adjustedDeliveryFee > 0 ? adjustedDeliveryFee : 0.0,
      'service_fee': (serviceFee * 100).round() / 100,
      'total': totalOrderAmount,
    };
  }

  /// Get special delivery discount details for UI display
  Map<String, dynamic>? get specialDeliveryDiscountDetails {
    for (final item in _items) {
      final customizations = item.customizations;
      if (customizations == null) continue;

      final isLimitedOffer =
          customizations['is_limited_offer'] as bool? ?? false;
      if (!isLimitedOffer) continue;

      final offerTypes = customizations['lto_offer_types'] as List?;
      if (offerTypes == null || !offerTypes.contains('special_delivery')) {
        continue;
      }

      final offerDetails = customizations['lto_offer_details'] as Map?;
      if (offerDetails == null) continue;

      final deliveryType = offerDetails['delivery_type'] as String?;
      final deliveryValue = offerDetails['delivery_value'] as num?;

      if (deliveryType == null || deliveryValue == null) continue;

      return {
        'type': deliveryType,
        'value': deliveryValue,
      };
    }
    return null;
  }

  // Note: Use PriceFormatter.formatWithSettings(context, price.toString()) for display formatting

  /// Infer restaurant id from cart items' customizations
  String? get inferredRestaurantId {
    for (final item in _items) {
      final rid = item.customizations?['restaurant_id']?.toString().trim();
      if (rid != null && rid.isNotEmpty) {
        return rid;
      }
    }
    return null;
  }

  /// Update delivery location and calculate delivery fee
  Future<void> updateDeliveryLocation({
    required double latitude,
    required double longitude,
    String? restaurantId,
    String? address,
  }) async {
    _deliveryLatitude = latitude;
    _deliveryLongitude = longitude;
    _deliveryAddress = address;
    _currentRestaurantId = restaurantId ?? inferredRestaurantId;

    // Calculate new delivery fee
    await _calculateDeliveryFee();

    notifyListeners();
  }

  /// Calculate delivery fee based on current location
  Future<void> _calculateDeliveryFee() async {
    if (_deliveryLatitude == null ||
        _deliveryLongitude == null ||
        _currentRestaurantId == null) {
      _cachedDeliveryFee = 2.99; // Default fallback
      return;
    }

    try {
      final fee = await _deliveryFeeService.calculateDeliveryFee(
        restaurantId: _currentRestaurantId!,
        customerLatitude: _deliveryLatitude!,
        customerLongitude: _deliveryLongitude!,
      );

      _cachedDeliveryFee = fee;
      debugPrint('💰 Updated delivery fee: $fee DA');
    } catch (e) {
      debugPrint('❌ Error calculating delivery fee: $e');
      _cachedDeliveryFee = 2.99; // Fallback
    }
  }

  /// Calculate special delivery discount from cart items
  double _calculateSpecialDeliveryDiscount() {
    debugPrint('🚚 _calculateSpecialDeliveryDiscount: Starting calculation');

    double maxDiscount = 0.0;

    for (final item in _items) {
      final customizations = item.customizations;
      if (customizations == null) continue;

      // Check if this item has special_delivery offer
      final isLimitedOffer =
          customizations['is_limited_offer'] as bool? ?? false;
      if (!isLimitedOffer) continue;

      final offerTypes = customizations['lto_offer_types'] as List?;
      if (offerTypes == null || !offerTypes.contains('special_delivery')) {
        continue;
      }

      // Get offer_details
      final offerDetails = customizations['lto_offer_details'] as Map?;
      if (offerDetails == null) continue;

      final deliveryType = offerDetails['delivery_type'] as String?;
      final deliveryValue = offerDetails['delivery_value'] as num?;

      debugPrint('🚚 Found special_delivery offer for ${item.name}');
      debugPrint('   delivery_type: $deliveryType');
      debugPrint('   delivery_value: $deliveryValue');

      if (deliveryType == null || deliveryValue == null) continue;

      // Calculate discount based on type
      double discount = 0.0;

      if (deliveryType == 'free') {
        // Free delivery - set discount to current delivery fee
        discount = _cachedDeliveryFee ?? 2.99;
        debugPrint('   Applying FREE delivery discount: $discount DA');
      } else if (deliveryType == 'percentage') {
        // Percentage discount (e.g., 50% off)
        final percentage = deliveryValue.toDouble();
        final currentFee = _cachedDeliveryFee ?? 2.99;
        discount = currentFee * (percentage / 100);
        debugPrint(
            '   Applying PERCENTAGE discount: $percentage% = $discount DA');
      } else if (deliveryType == 'fixed') {
        // Fixed amount discount (e.g., -100 DA)
        discount = deliveryValue.toDouble();
        debugPrint('   Applying FIXED discount: $discount DA');
      }

      // Track maximum discount (in case multiple items have different offers)
      if (discount > maxDiscount) {
        maxDiscount = discount;
      }
    }

    debugPrint('🚚 Maximum special_delivery discount: $maxDiscount DA');
    return maxDiscount;
  }

  /// Check if delivery is available to current location
  Future<bool> isDeliveryAvailable() async {
    if (_deliveryLatitude == null ||
        _deliveryLongitude == null ||
        _currentRestaurantId == null) {
      return false;
    }

    try {
      return await _deliveryFeeService.isDeliveryAvailable(
        restaurantId: _currentRestaurantId!,
        customerLatitude: _deliveryLatitude!,
        customerLongitude: _deliveryLongitude!,
      );
    } catch (e) {
      debugPrint('❌ Error checking delivery availability: $e');
      return false;
    }
  }

  /// Get estimated delivery time
  Future<int> getEstimatedDeliveryTime() async {
    if (_deliveryLatitude == null ||
        _deliveryLongitude == null ||
        _currentRestaurantId == null) {
      return 30; // Default 30 minutes
    }

    try {
      return await _deliveryFeeService.getEstimatedDeliveryTime(
        restaurantId: _currentRestaurantId!,
        customerLatitude: _deliveryLatitude!,
        customerLongitude: _deliveryLongitude!,
      );
    } catch (e) {
      debugPrint('❌ Error getting delivery time: $e');
      return 30;
    }
  }

  /// Clear delivery fee cache
  void clearDeliveryFeeCache() {
    _cachedDeliveryFee = null;
    _deliveryFeeService.clearCache();
    notifyListeners();
  }

  bool get isEmpty => _items.isEmpty;

  bool get isNotEmpty => _items.isNotEmpty;

  /// Initialize from SharedPreferences for current session (user or guest)
  Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
    await _loadCartFromStorage();
  }

  /// Apply a promo code to the cart
  bool applyPromoCode(PromoCode promoCode, String? restaurantId) {
    // Validate promo code against current cart
    final validationResult =
        getPromoCodeValidationDetails(promoCode, restaurantId);
    if (!validationResult["isValid"]) {
      debugPrint(
          '❌ Promo code ${promoCode.code} is not valid for current cart: ${validationResult["errorMessage"]}');
      return false;
    }

    _appliedPromoCode = promoCode;
    notifyListeners();
    _persistCart();
    debugPrint('✅ Applied promo code: ${promoCode.code}');
    return true;
  }

  /// Apply a promo code to the cart with detailed error information
  Map<String, dynamic> applyPromoCodeWithDetails(
      PromoCode promoCode, String? restaurantId) {
    // Validate promo code against current cart
    final validationResult =
        getPromoCodeValidationDetails(promoCode, restaurantId);
    if (!validationResult["isValid"]) {
      debugPrint(
          '❌ Promo code ${promoCode.code} is not valid for current cart: ${validationResult["errorMessage"]}');
      return validationResult;
    }

    _appliedPromoCode = promoCode;
    notifyListeners();
    _persistCart();
    debugPrint('✅ Applied promo code: ${promoCode.code}');
    return {"isValid": true, "errorMessage": null};
  }

  /// Remove the applied promo code
  void removePromoCode() {
    _appliedPromoCode = null;
    notifyListeners();
    _persistCart();
    debugPrint('🗑️ Removed promo code');
  }

  /// Validate if a promo code is applicable to the current cart
  bool isPromoCodeValid(PromoCode promoCode, String? restaurantId) {
    final result = getPromoCodeValidationDetails(promoCode, restaurantId);
    return result["isValid"];
  }

  /// Get detailed validation results for a promo code
  Map<String, dynamic> getPromoCodeValidationDetails(
      PromoCode promoCode, String? restaurantId) {
    // Check if promo code is active
    if (!promoCode.isActive) {
      debugPrint('❌ Promo code ${promoCode.code} is not active');
      return {
        "isValid": false,
        "errorMessage": "This promo code is not currently active or has expired"
      };
    }

    // Check restaurant restriction - enhanced validation
    if (promoCode.restaurantId != null &&
        restaurantId != null &&
        promoCode.restaurantId != restaurantId) {
      debugPrint(
          '❌ Promo code ${promoCode.code} is not valid for restaurant $restaurantId');
      return {
        "isValid": false,
        "errorMessage":
            "This promo code is not valid for the selected restaurant"
      };
    }

    // Check minimum order amount
    if (subtotal < promoCode.minimumOrderAmount) {
      debugPrint(
          '❌ Order subtotal $subtotal is below minimum ${promoCode.minimumOrderAmount} for promo ${promoCode.code}');
      return {
        "isValid": false,
        "errorMessage":
            "Minimum order amount of \$${promoCode.minimumOrderAmount.toStringAsFixed(2)} required for this promo code"
      };
    }

    // Check if cart is empty
    if (_items.isEmpty) {
      debugPrint('❌ Cannot apply promo code to empty cart');
      return {
        "isValid": false,
        "errorMessage": "Add items to your cart before applying a promo code"
      };
    }

    // Validate discount amount doesn't exceed subtotal
    final calculatedDiscount = promoCode.calculateDiscount(subtotal);
    if (calculatedDiscount > subtotal) {
      debugPrint(
          '❌ Calculated discount $calculatedDiscount exceeds subtotal $subtotal for promo ${promoCode.code}');
      return {
        "isValid": false,
        "errorMessage": "Discount amount exceeds order total"
      };
    }

    // Check applicable categories (if specified)
    if (promoCode.applicableCategories.isNotEmpty) {
      // This would require checking cart items against categories
      // For now, we'll implement basic validation
      debugPrint(
          '⚠️ Category validation not fully implemented for promo ${promoCode.code}');
    }

    // Check applicable menu items (if specified)
    if (promoCode.applicableMenuItems.isNotEmpty) {
      // This would require checking cart items against specific menu items
      debugPrint(
          '⚠️ Menu item validation not fully implemented for promo ${promoCode.code}');
    }

    return {"isValid": true, "errorMessage": null};
  }

  String _currentUserId() {
    try {
      return Supabase.instance.client.auth.currentUser?.id ?? 'guest';
    } catch (_) {
      return 'guest';
    }
  }

  String _cartKeyForUser(String userId) => 'cart_items_$userId';

  Future<void> _loadCartFromStorage() async {
    final uid = _currentUserId();
    final key = _cartKeyForUser(uid);
    final jsonString = _prefs?.getString(key);
    if (jsonString == null || jsonString.isEmpty) {
      notifyListeners();
      return;
    }
    try {
      final Map<String, dynamic> cartData = json.decode(jsonString);
      final List<dynamic> itemsData = cartData['items'] ?? [];
      final Map<String, dynamic>? promoData = cartData['promoCode'];

      _items
        ..clear()
        ..addAll(
            itemsData.whereType<Map<String, dynamic>>().map(CartItem.fromMap));

      // Load promo code if exists
      if (promoData != null) {
        try {
          _appliedPromoCode = PromoCode.fromJson(promoData);
        } catch (e) {
          debugPrint('❌ Error loading promo code from storage: $e');
          _appliedPromoCode = null;
        }
      }

      // ✅ FIX: Load paid drinks separately (not from order cards)
      if (cartData.containsKey('paidDrinkQuantities')) {
        final paidQuantities = cartData['paidDrinkQuantities'] as Map<String, dynamic>?;
        if (paidQuantities != null) {
          _paidDrinkQuantities.clear();
          paidQuantities.forEach((id, qty) {
            final q = qty is int ? qty : int.tryParse(qty.toString()) ?? 0;
            if (q > 0) {
              _paidDrinkQuantities[id] = q;
            }
          });
        }
      }
      if (cartData.containsKey('paidDrinkPrices')) {
        final paidPrices = cartData['paidDrinkPrices'] as Map<String, dynamic>?;
        if (paidPrices != null) {
          _paidDrinkPrices.clear();
          paidPrices.forEach((id, price) {
            final p = price is double ? price : double.tryParse(price.toString()) ?? 0.0;
            if (p > 0) {
              _paidDrinkPrices[id] = p;
            }
          });
        }
      }

      // ✅ FIX: Extract paid drinks from items if not already loaded (backward compatibility)
      if (_paidDrinkQuantities.isEmpty && _items.isNotEmpty) {
        for (final item in _items) {
          _extractPaidDrinksFromItem(item);
          if (_paidDrinkQuantities.isNotEmpty) break; // Only need first item
        }
      }

      notifyListeners();
    } catch (_) {
      // Corrupt cache; clear
      await _prefs?.remove(key);
      notifyListeners();
    }
  }

  Future<void> _persistCart() async {
    _prefs ??= await SharedPreferences.getInstance();
    final uid = _currentUserId();
    final key = _cartKeyForUser(uid);

    final cartData = {
      'items': _items.map((e) => e.toMap()).toList(),
      'promoCode': _appliedPromoCode?.toJson(),
      // ✅ FIX: Save paid drinks separately (not in order cards)
      'paidDrinkQuantities': _paidDrinkQuantities,
      'paidDrinkPrices': _paidDrinkPrices,
    };

    final jsonString = json.encode(cartData);
    await _prefs!.setString(key, jsonString);
  }

  void addToCart(CartItem item) {
    debugPrint(
        '🛒 CartProvider.addToCart: Adding ${item.name} with price ${item.price} x ${item.quantity} = ${item.totalPrice}');

    // ✅ FIX: Extract paid drinks from item and store separately (avoid conflicts)
    _extractPaidDrinksFromItem(item);

    // Check if item already exists with same customizations
    final existingIndex = _items.indexWhere((existingItem) =>
        existingItem.id == item.id &&
        _mapsEqual(existingItem.customizations, item.customizations) &&
        _mapsEqual(existingItem.drinkQuantities, item.drinkQuantities) &&
        existingItem.specialInstructions == item.specialInstructions);

    if (existingIndex != -1) {
      // Update quantity of existing item
      debugPrint('🛒 CartProvider.addToCart: Updating existing item quantity');
      _items[existingIndex] = _items[existingIndex].copyWith(
        quantity: _items[existingIndex].quantity + item.quantity,
      );
    } else {
      // Add new item
      debugPrint('🛒 CartProvider.addToCart: Adding new item');
      _items.add(item);
    }
    notifyListeners();
    _persistCart();
  }

  // ✅ FIX: Extract paid drinks from item and store separately
  void _extractPaidDrinksFromItem(CartItem item) {
    final paidQuantities = item.customizations?['paid_drink_quantities'] as Map<String, dynamic>?;
    if (paidQuantities != null) {
      // Get drink prices from item's drinks list
      final drinksList = item.customizations?['drinks'] as List?;
      final drinkPrices = <String, double>{};
      if (drinksList != null) {
        for (final d in drinksList) {
          if (d is Map) {
            final drinkId = d['id']?.toString() ?? '';
            final isFree = d['is_free'] == true || (d['price'] as num?)?.toDouble() == 0.0;
            if (!isFree && drinkId.isNotEmpty) {
              final price = (d['price'] as num?)?.toDouble() ?? 0.0;
              if (price > 0) {
                drinkPrices[drinkId] = price;
              }
            }
          }
        }
      }

      // Update paid drinks store (only from first item to avoid conflicts)
      if (_paidDrinkQuantities.isEmpty || _items.isEmpty) {
        paidQuantities.forEach((id, qty) {
          final q = qty is int ? qty : int.tryParse(qty.toString()) ?? 0;
          if (q > 0) {
            _paidDrinkQuantities[id] = q;
            // Store price if available
            if (drinkPrices.containsKey(id)) {
              _paidDrinkPrices[id] = drinkPrices[id]!;
            }
          }
        });
      }
    }
  }

  // ✅ FIX: Update paid drink quantity (separate from order cards)
  void updatePaidDrinkQuantity(String drinkId, int quantity, double price) {
    if (quantity > 0) {
      _paidDrinkQuantities[drinkId] = quantity;
      _paidDrinkPrices[drinkId] = price;
    } else {
      _paidDrinkQuantities.remove(drinkId);
      _paidDrinkPrices.remove(drinkId);
    }
    notifyListeners();
    _persistCart();
  }

  void removeFromCart(String itemId) {
    final removed = _items.firstWhere((item) => item.id == itemId,
        orElse: () => CartItem(id: '', name: '', price: 0, quantity: 0));

    // ✅ FIX: Check if removed item had paid drinks (was the first item)
    final removedPaidDrinkQuantities = (removed.customizations?['paid_drink_quantities']
        as Map<String, dynamic>?) ?? <String, dynamic>{};
    final hadPaidDrinks = removedPaidDrinkQuantities.isNotEmpty &&
        removedPaidDrinkQuantities.values.any((qty) => (qty is int ? qty : int.tryParse(qty.toString()) ?? 0) > 0);

    // ✅ FIX: Get restaurant ID from removed item
    final restaurantId = removed.restaurantName != null
        ? _items.where((item) => item.restaurantName == removed.restaurantName).isNotEmpty
            ? removed.restaurantName
            : null
        : null;

    // Remove the item
    _items.removeWhere((item) => item.id == itemId);

    // ✅ FIX: If removed item had paid drinks, move them to the next item from the same restaurant
    if (hadPaidDrinks && restaurantId != null) {
      _recalculatePaidDrinksAfterRemoval(removed, restaurantId);
    }

    notifyListeners();
    _persistCart();
    // Clear saved preferences for the removed menu item if possible
    // Requires menu_item_id in customizations; safe no-op if absent
    if (removed.id.isNotEmpty) {
      final menuItemId = _extractMenuItemIdFromCartItem(removed);
      if (menuItemId != null && menuItemId.isNotEmpty) {
        Future.microtask(() => _clearPrefsForMenuItemId(menuItemId));
      }
    }
  }

  /// ✅ FIX: Recalculate paid drinks after removing an item
  /// If the removed item had paid drinks (was the first item), move them to the next item from the same restaurant
  void _recalculatePaidDrinksAfterRemoval(CartItem removedItem, String? restaurantId) {
    if (restaurantId == null) return;

    // Get all remaining items from the same restaurant
    final remainingItems = _items.where((item) =>
        item.restaurantName == restaurantId
    ).toList();

    if (remainingItems.isEmpty) {
      debugPrint('🔄 CartProvider: No remaining items from restaurant $restaurantId, paid drinks removed');
      return;
    }

    // Get paid drinks from removed item
    final removedPaidDrinkQuantities = (removedItem.customizations?['paid_drink_quantities']
        as Map<String, dynamic>?) ?? <String, dynamic>{};
    final paidDrinkQuantities = <String, int>{};
    removedPaidDrinkQuantities.forEach((id, qty) {
      final q = qty is int ? qty : int.tryParse(qty.toString()) ?? 0;
      if (q > 0) {
        paidDrinkQuantities[id] = q;
      }
    });

    if (paidDrinkQuantities.isEmpty) {
      debugPrint('🔄 CartProvider: No paid drinks to move');
      return;
    }

    // Calculate paid drinks price from removed item's drinks list
    double paidDrinksPrice = 0.0;
    final removedDrinks = (removedItem.customizations?['drinks'] as List?) ?? [];
    for (final d in removedDrinks) {
      if (d is Map) {
        final drinkId = d['id']?.toString() ?? '';
        final isFree = d['is_free'] == true || (d['price'] as num?)?.toDouble() == 0.0;
        if (!isFree && paidDrinkQuantities.containsKey(drinkId)) {
          final price = (d['price'] as num?)?.toDouble() ?? 0.0;
          final qty = paidDrinkQuantities[drinkId] ?? 0;
          paidDrinksPrice += price * qty;
        }
      }
    }

    debugPrint('🔄 CartProvider: Moving paid drinks to next item from restaurant $restaurantId');
    debugPrint('   Paid drinks: $paidDrinkQuantities');
    debugPrint('   Paid drinks price: $paidDrinksPrice');

    // Find the first item from the same restaurant (this will be the new "first" item)
    final firstRemainingItem = remainingItems.first;

    // Update the first remaining item to include paid drinks
    final firstItemCustomizations = Map<String, dynamic>.from(firstRemainingItem.customizations ?? {});

    // Update paid_drink_quantities
    firstItemCustomizations['paid_drink_quantities'] = paidDrinkQuantities;

    // Update drinks list - add paid drinks, preserve free drinks
    final existingDrinks = (firstItemCustomizations['drinks'] as List?) ?? [];
    final updatedDrinks = <Map<String, dynamic>>[];
    final processedDrinkIds = <String>{};

    // First, preserve existing free drinks
    for (final d in existingDrinks) {
      if (d is Map) {
        final drinkId = d['id']?.toString() ?? '';
        if (drinkId.isNotEmpty) {
          final isFree = d['is_free'] == true || (d['price'] as num?)?.toDouble() == 0.0;
          if (isFree && !paidDrinkQuantities.containsKey(drinkId)) {
            updatedDrinks.add(Map<String, dynamic>.from(d));
            processedDrinkIds.add(drinkId);
          }
        }
      }
    }

    // Add paid drinks from removed item
    for (final d in removedDrinks) {
      if (d is Map) {
        final drinkId = d['id']?.toString() ?? '';
        if (drinkId.isNotEmpty && paidDrinkQuantities.containsKey(drinkId) && !processedDrinkIds.contains(drinkId)) {
          final drinkData = Map<String, dynamic>.from(d);
          drinkData['is_free'] = false;
          drinkData['price'] = (d['price'] as num?)?.toDouble() ?? 0.0;
          updatedDrinks.add(drinkData);
          processedDrinkIds.add(drinkId);
        }
      }
    }

    firstItemCustomizations['drinks'] = updatedDrinks;

    // Update drinkQuantities
    final existingFreeDrinks = (firstItemCustomizations['free_drink_quantities'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final freeDrinkQuantities = <String, int>{};
    existingFreeDrinks.forEach((id, qty) {
      final q = qty is int ? qty : int.tryParse(qty.toString()) ?? 0;
      if (q > 0) {
        freeDrinkQuantities[id] = q;
      }
    });

    final updatedDrinkQuantities = <String, int>{
      ...freeDrinkQuantities,
      ...paidDrinkQuantities,
    };

    // Update price: add paid drinks price to the first item
    final newPrice = firstRemainingItem.price + paidDrinksPrice;

    // Update the first item
    final updatedFirstItem = firstRemainingItem.copyWith(
      customizations: firstItemCustomizations,
      drinkQuantities: updatedDrinkQuantities,
      price: newPrice,
    );

    final firstItemIndex = _items.indexWhere((item) => item.id == firstRemainingItem.id);
    if (firstItemIndex != -1) {
      _items[firstItemIndex] = updatedFirstItem;
      debugPrint('🔄 CartProvider: Updated first item ${updatedFirstItem.id} with paid drinks (new price: $newPrice)');
    }

    // Remove paid drinks from other items (paid drinks should only be in the first item)
    for (int i = 0; i < remainingItems.length; i++) {
      final item = remainingItems[i];
      if (item.id != firstRemainingItem.id) {
        final itemCustomizations = Map<String, dynamic>.from(item.customizations ?? {});

        // Remove paid_drink_quantities from other items
        if (itemCustomizations.containsKey('paid_drink_quantities')) {
          itemCustomizations.remove('paid_drink_quantities');
        }

        // Remove paid drinks from drinks list
        final itemDrinks = (itemCustomizations['drinks'] as List?) ?? [];
        final updatedItemDrinks = itemDrinks.where((d) {
          if (d is Map) {
            final drinkId = d['id']?.toString() ?? '';
            final isFree = d['is_free'] == true || (d['price'] as num?)?.toDouble() == 0.0;
            // Keep only free drinks (not paid drinks)
            return isFree || !paidDrinkQuantities.containsKey(drinkId);
          }
          return true;
        }).map((d) => Map<String, dynamic>.from(d as Map)).toList();

        itemCustomizations['drinks'] = updatedItemDrinks;

        // Update drinkQuantities - remove paid drinks
        final itemDrinkQuantities = Map<String, int>.from(item.drinkQuantities ?? {});
        paidDrinkQuantities.keys.forEach((id) => itemDrinkQuantities.remove(id));

        // Calculate price adjustment: remove paid drinks price
        double itemPaidDrinksPrice = 0.0;
        for (final d in itemDrinks) {
          if (d is Map) {
            final drinkId = d['id']?.toString() ?? '';
            final isFree = d['is_free'] == true || (d['price'] as num?)?.toDouble() == 0.0;
            if (!isFree && paidDrinkQuantities.containsKey(drinkId)) {
              final price = (d['price'] as num?)?.toDouble() ?? 0.0;
              final qty = paidDrinkQuantities[drinkId] ?? 0;
              itemPaidDrinksPrice += price * qty;
            }
          }
        }

        final updatedItemPrice = (item.price - itemPaidDrinksPrice).clamp(0.0, double.infinity);

        final itemIndex = _items.indexWhere((cartItem) => cartItem.id == item.id);
        if (itemIndex != -1) {
          final updatedItem = item.copyWith(
            customizations: itemCustomizations,
            drinkQuantities: itemDrinkQuantities.isEmpty ? null : itemDrinkQuantities,
            price: updatedItemPrice,
          );
          _items[itemIndex] = updatedItem;
          debugPrint('🔄 CartProvider: Removed paid drinks from item ${updatedItem.id} (new price: $updatedItemPrice)');
        }
      }
    }
  }

  void updateCartItem(String itemId, CartItem updatedItem) {
    final index = _items.indexWhere((item) => item.id == itemId);
    if (index != -1) {
      _items[index] = updatedItem;
      notifyListeners();
      _persistCart();
    }
  }

  void updateQuantity(String itemId, int quantity) {
    if (quantity <= 0) {
      removeFromCart(itemId);
      return;
    }

    final index = _items.indexWhere((item) => item.id == itemId);
    if (index != -1) {
      _items[index] = _items[index].copyWith(quantity: quantity);
      notifyListeners();
      _persistCart();
    }
  }

  void clearCart() {
    final itemsCopy = List<CartItem>.from(_items);
    _items.clear();
    _appliedPromoCode = null; // Clear promo code when clearing cart
    notifyListeners();
    _persistCart();
    // Clear saved preferences for all menu items that were in the cart
    for (final item in itemsCopy) {
      final menuItemId = _extractMenuItemIdFromCartItem(item);
      if (menuItemId != null && menuItemId.isNotEmpty) {
        Future.microtask(() => _clearPrefsForMenuItemId(menuItemId));
      }
    }
  }

  bool _mapsEqual(Map<String, dynamic>? map1, Map<String, dynamic>? map2) {
    if (map1 == null && map2 == null) return true;
    if (map1 == null || map2 == null) return false;
    if (map1.length != map2.length) return false;

    for (final key in map1.keys) {
      if (!map2.containsKey(key) || map1[key] != map2[key]) {
        return false;
      }
    }
    return true;
  }

  String? _extractMenuItemIdFromCartItem(CartItem item) {
    try {
      final customizations = item.customizations;
      if (customizations == null) return null;
      final raw = customizations['menu_item_id'];
      if (raw == null) return null;
      return raw.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _clearPrefsForMenuItemId(String menuItemId) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      final key = 'menu_item_prefs_$_currentUserId()_$menuItemId';
      await _prefs!.remove(key);
    } catch (_) {
      // Ignore storage errors
    }
  }
}
