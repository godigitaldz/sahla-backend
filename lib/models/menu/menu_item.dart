import '../category.dart';
import '../cuisine_type.dart';

/// Enhanced MenuItem model with adaptive loading and performance optimization
class MenuItem {
  final String id;
  final String restaurantId;
  final String? restaurantName; // Made nullable to handle null values
  final String name;
  final String description;
  final String image; // Primary/first image (for backward compatibility)
  final List<String> images; // All images array for gallery support
  final double price;
  final String category; // Legacy field for backward compatibility
  final String? cuisineTypeId; // New cuisine type ID
  final String? categoryId; // New category ID
  final CuisineType? cuisineType; // Full cuisine type object
  final Category? categoryObj; // Full category object
  final bool isAvailable;
  final bool isFeatured;
  final int preparationTime; // minutes
  final double rating; // for UI display
  final int reviewCount; // for UI display
  final String? mainIngredients; // main ingredients from database
  final DateTime createdAt;
  final DateTime updatedAt;

  // Dietary and attribute fields
  final List<String> ingredients; // ingredients array
  final bool isSpicy;
  final int spiceLevel; // 0-5
  final bool isTraditional;
  final bool isVegetarian;
  final bool isVegan;
  final bool isGlutenFree;
  final bool isDairyFree;
  final bool isLowSodium;

  // JSONB fields
  final List<Map<String, dynamic>> variants;
  final List<Map<String, dynamic>> pricingOptions;
  final List<Map<String, dynamic>> supplements;

  // Free drinks fields removed - now stored in menu_item_pricing table
  // See MenuItemPricing model for free drinks data

  // Limited Time Offer fields
  final bool isLimitedOffer;
  final List<String> offerTypes;
  final DateTime? offerStartAt;
  final DateTime? offerEndAt;
  final double? originalPrice;
  final Map<String, dynamic> offerDetails;

  // Nutrition fields
  final int? calories;
  final double? protein;
  final double? carbs;
  final double? fat;
  final double? fiber;
  final double? sugar;

  // Performance optimization fields
  final DateTime? _lastImageLoadTime;
  final String? _cachedImageUrl;
  final bool _isImageOptimized;
  final int _imageLoadCount;
  final double _averageLoadTime;

  MenuItem({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.description,
    required this.image,
    required this.price,
    required this.category,
    required this.isAvailable,
    required this.isFeatured,
    required this.preparationTime,
    required this.rating,
    required this.reviewCount,
    required this.createdAt,
    required this.updatedAt,
    this.images = const [],
    this.restaurantName,
    this.cuisineTypeId,
    this.categoryId,
    this.cuisineType,
    this.categoryObj,
    this.mainIngredients,
    this.ingredients = const [],
    this.isSpicy = false,
    this.spiceLevel = 0,
    this.isTraditional = false,
    this.isVegetarian = false,
    this.isVegan = false,
    this.isGlutenFree = false,
    this.isDairyFree = false,
    this.isLowSodium = false,
    this.variants = const [],
    this.pricingOptions = const [],
    this.supplements = const [],
    this.isLimitedOffer = false,
    this.offerTypes = const [],
    this.offerStartAt,
    this.offerEndAt,
    this.originalPrice,
    this.offerDetails = const {},
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
    this.fiber,
    this.sugar,
    DateTime? lastImageLoadTime,
    String? cachedImageUrl,
    bool isImageOptimized = false,
    int imageLoadCount = 0,
    double averageLoadTime = 0.0,
  })  : _lastImageLoadTime = lastImageLoadTime,
        _cachedImageUrl = cachedImageUrl,
        _isImageOptimized = isImageOptimized,
        _imageLoadCount = imageLoadCount,
        _averageLoadTime = averageLoadTime;

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    // Performance: Removed PerformanceMonitoringService overhead (saves 1-2ms per item)
    // Performance monitoring should be done at the service level, not per-model

    // Performance: Pre-compute images list outside constructor
    final List<String> imagesList;
    if (json['images'] != null && json['images'] is List) {
      imagesList = (json['images'] as List)
          .map((e) => e.toString())
          .where((img) => img.isNotEmpty)
          .toList();
    } else if (json['image'] != null && json['image'].toString().isNotEmpty) {
      imagesList = [json['image'].toString()];
    } else {
      imagesList = const [];
    }

    return MenuItem(
      id: json['id'] ?? '',
      restaurantId: json['restaurant_id'] ?? '',
      restaurantName: json['restaurant_name'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      image: json['image'] ?? '',
      images: imagesList,
      price: (json['price'] ?? 0.0).toDouble(),
      category: json['category'] ?? '', // Legacy field
      cuisineTypeId: json['cuisine_type_id'],
      categoryId: json['category_id'],
      // Performance: Lazy-load nested objects only when needed
      cuisineType: json['cuisine_type'] != null
          ? CuisineType.fromJson(json['cuisine_type'])
          : null,
      categoryObj: json['category_obj'] != null
          ? Category.fromJson(json['category_obj'])
          : null,
      isAvailable: json['is_available'] ?? true,
      isFeatured: json['is_featured'] ?? false,
      preparationTime: json['preparation_time'] ?? 15,
      rating: (json['rating'] ?? 0.0).toDouble(),
      reviewCount: json['review_count'] ?? 0,
      mainIngredients: json['main_ingredients'],
      ingredients: json['ingredients'] != null
          ? List<String>.from(json['ingredients'])
          : const [],
      isSpicy: json['is_spicy'] ?? false,
      spiceLevel: json['spice_level'] ?? 0,
      isTraditional: json['is_traditional'] ?? false,
      isVegetarian: json['is_vegetarian'] ?? false,
      isVegan: json['is_vegan'] ?? false,
      isGlutenFree: json['is_gluten_free'] ?? false,
      isDairyFree: json['is_dairy_free'] ?? false,
      isLowSodium: json['is_low_sodium'] ?? false,
      variants: json['variants'] != null
          ? List<Map<String, dynamic>>.from(json['variants'])
          : const [],
      pricingOptions: json['pricing_options'] != null
          ? List<Map<String, dynamic>>.from(json['pricing_options'])
          : const [],
      supplements: json['supplements'] != null
          ? List<Map<String, dynamic>>.from(json['supplements'])
          : const [],
      isLimitedOffer: json['is_limited_offer'] ?? false,
      offerTypes: json['offer_types'] != null
          ? List<String>.from(json['offer_types'])
          : const [],
      // Performance: Safe DateTime parsing with try-catch
      offerStartAt: _parseDateTimeSafe(json['offer_start_at']),
      offerEndAt: _parseDateTimeSafe(json['offer_end_at']),
      originalPrice: json['original_price'] != null
          ? (json['original_price'] as num).toDouble()
          : null,
      offerDetails: json['offer_details'] != null
          ? Map<String, dynamic>.from(json['offer_details'])
          : const {},
      calories: json['calories'],
      protein:
          json['protein'] != null ? (json['protein'] as num).toDouble() : null,
      carbs: json['carbs'] != null ? (json['carbs'] as num).toDouble() : null,
      fat: json['fat'] != null ? (json['fat'] as num).toDouble() : null,
      fiber: json['fiber'] != null ? (json['fiber'] as num).toDouble() : null,
      sugar: json['sugar'] != null ? (json['sugar'] as num).toDouble() : null,
      createdAt: _parseDateTimeSafe(json['created_at']) ?? DateTime.now(),
      updatedAt: _parseDateTimeSafe(json['updated_at']) ?? DateTime.now(),
      lastImageLoadTime: DateTime.now(),
      cachedImageUrl: json['image'],
      isImageOptimized: false,
      imageLoadCount: 0,
      averageLoadTime: 0.0,
    );
  }

  /// Performance: Safe DateTime parsing helper (avoids exceptions)
  static DateTime? _parseDateTimeSafe(dynamic value) {
    if (value == null) return null;
    try {
      return DateTime.parse(value.toString());
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    // Performance: Removed PerformanceMonitoringService overhead
    return {
      'id': id,
      'restaurant_id': restaurantId,
      'restaurant_name': restaurantName,
      'name': name,
      'description': description,
      'image': image,
      'images': images,
      'price': price,
      'category': category, // Legacy field
      'cuisine_type_id': cuisineTypeId,
      'category_id': categoryId,
      // cuisine_type and category_obj are excluded - database only stores IDs
      'is_available': isAvailable,
      'is_featured': isFeatured,
      'preparation_time': preparationTime,
      'rating': rating,
      'review_count': reviewCount,
      'main_ingredients': mainIngredients,
      'ingredients': ingredients,
      'is_spicy': isSpicy,
      'spice_level': spiceLevel,
      'is_traditional': isTraditional,
      'is_vegetarian': isVegetarian,
      'is_vegan': isVegan,
      'is_gluten_free': isGlutenFree,
      'is_dairy_free': isDairyFree,
      'is_low_sodium': isLowSodium,
      'variants': variants,
      'pricing_options': pricingOptions,
      'supplements': supplements,
      'is_limited_offer': isLimitedOffer,
      'offer_types': offerTypes,
      'offer_start_at': offerStartAt?.toIso8601String(),
      'offer_end_at': offerEndAt?.toIso8601String(),
      'original_price': originalPrice,
      'offer_details': offerDetails,
      'calories': calories,
      'protein': protein,
      'carbs': carbs,
      'fat': fat,
      'fiber': fiber,
      'sugar': sugar,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      // Performance optimization fields are excluded from database serialization
      // These are client-side only fields for tracking image load performance
    };
  }

  MenuItem copyWith({
    String? id,
    String? restaurantId,
    String? restaurantName,
    String? name,
    String? description,
    String? image,
    List<String>? images,
    double? price,
    String? category, // Legacy field
    String? cuisineTypeId,
    String? categoryId,
    CuisineType? cuisineType,
    Category? categoryObj,
    bool? isAvailable,
    bool? isFeatured,
    int? preparationTime,
    double? rating,
    int? reviewCount,
    String? mainIngredients,
    List<String>? ingredients,
    bool? isSpicy,
    int? spiceLevel,
    bool? isTraditional,
    bool? isVegetarian,
    bool? isVegan,
    bool? isGlutenFree,
    bool? isDairyFree,
    bool? isLowSodium,
    List<Map<String, dynamic>>? variants,
    List<Map<String, dynamic>>? pricingOptions,
    List<Map<String, dynamic>>? supplements,
    bool? isLimitedOffer,
    List<String>? offerTypes,
    DateTime? offerStartAt,
    DateTime? offerEndAt,
    double? originalPrice,
    Map<String, dynamic>? offerDetails,
    int? calories,
    double? protein,
    double? carbs,
    double? fat,
    double? fiber,
    double? sugar,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastImageLoadTime,
    String? cachedImageUrl,
    bool? isImageOptimized,
    int? imageLoadCount,
    double? averageLoadTime,
  }) {
    return MenuItem(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      restaurantName: restaurantName ?? this.restaurantName,
      name: name ?? this.name,
      description: description ?? this.description,
      image: image ?? this.image,
      images: images ?? this.images,
      price: price ?? this.price,
      category: category ?? this.category, // Legacy field
      cuisineTypeId: cuisineTypeId ?? this.cuisineTypeId,
      categoryId: categoryId ?? this.categoryId,
      cuisineType: cuisineType ?? this.cuisineType,
      categoryObj: categoryObj ?? this.categoryObj,
      isAvailable: isAvailable ?? this.isAvailable,
      isFeatured: isFeatured ?? this.isFeatured,
      preparationTime: preparationTime ?? this.preparationTime,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      mainIngredients: mainIngredients ?? this.mainIngredients,
      ingredients: ingredients ?? this.ingredients,
      isSpicy: isSpicy ?? this.isSpicy,
      spiceLevel: spiceLevel ?? this.spiceLevel,
      isTraditional: isTraditional ?? this.isTraditional,
      isVegetarian: isVegetarian ?? this.isVegetarian,
      isVegan: isVegan ?? this.isVegan,
      isGlutenFree: isGlutenFree ?? this.isGlutenFree,
      isDairyFree: isDairyFree ?? this.isDairyFree,
      isLowSodium: isLowSodium ?? this.isLowSodium,
      variants: variants ?? this.variants,
      pricingOptions: pricingOptions ?? this.pricingOptions,
      supplements: supplements ?? this.supplements,
      isLimitedOffer: isLimitedOffer ?? this.isLimitedOffer,
      offerTypes: offerTypes ?? this.offerTypes,
      offerStartAt: offerStartAt ?? this.offerStartAt,
      offerEndAt: offerEndAt ?? this.offerEndAt,
      originalPrice: originalPrice ?? this.originalPrice,
      offerDetails: offerDetails ?? this.offerDetails,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fat: fat ?? this.fat,
      fiber: fiber ?? this.fiber,
      sugar: sugar ?? this.sugar,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastImageLoadTime: lastImageLoadTime ?? _lastImageLoadTime,
      cachedImageUrl: cachedImageUrl ?? _cachedImageUrl,
      isImageOptimized: isImageOptimized ?? _isImageOptimized,
      imageLoadCount: imageLoadCount ?? _imageLoadCount,
      averageLoadTime: averageLoadTime ?? _averageLoadTime,
    );
  }

  @override
  String toString() {
    return 'MenuItem(id: $id, name: $name, price: $price, category: $category)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MenuItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  /// Get optimized image URL based on network conditions
  String? getOptimizedImageUrl(String networkQuality) {
    // Use cached URL if available and recent
    if (_cachedImageUrl != null &&
        _lastImageLoadTime != null &&
        DateTime.now().difference(_lastImageLoadTime).inMinutes < 30) {
      return _cachedImageUrl;
    }

    // Return appropriate image based on network quality
    switch (networkQuality) {
      case 'fast':
        return image.isNotEmpty ? image : null;
      case 'moderate':
        return image.isNotEmpty ? image : null; // Still load images on moderate
      case 'slow':
        return null; // Skip images on slow networks
      case 'verySlow':
        return null; // Skip images on very slow networks
      case 'offline':
        return _cachedImageUrl; // Use cached version when offline
      default:
        return image.isNotEmpty ? image : null;
    }
  }

  /// Check if image should be loaded based on network conditions
  bool shouldLoadImage(String networkQuality) {
    switch (networkQuality) {
      case 'offline':
        return _cachedImageUrl != null;
      case 'slow':
      case 'verySlow':
        return false; // Skip images on slow networks
      default:
        return image.isNotEmpty;
    }
  }

  /// Get adaptive cache duration based on network quality
  Duration getAdaptiveCacheDuration(String networkQuality) {
    switch (networkQuality) {
      case 'fast':
        return const Duration(hours: 2);
      case 'moderate':
        return const Duration(hours: 1);
      case 'slow':
        return const Duration(minutes: 30);
      case 'verySlow':
        return const Duration(minutes: 15);
      case 'offline':
        return const Duration(hours: 24);
      default:
        return const Duration(hours: 1);
    }
  }

  /// Update image optimization status
  MenuItem updateImageOptimization(String? newCachedUrl, double loadTime,
      {required bool optimized}) {
    final newLoadCount = _imageLoadCount + 1;
    final newAverageTime =
        (_averageLoadTime * _imageLoadCount + loadTime) / newLoadCount;

    return copyWith(
      cachedImageUrl: newCachedUrl,
      isImageOptimized: optimized,
      lastImageLoadTime: DateTime.now(),
      imageLoadCount: newLoadCount,
      averageLoadTime: newAverageTime,
    );
  }

  /// Get performance metrics for this menu item
  Map<String, dynamic> getPerformanceMetrics() {
    return {
      'image_load_count': _imageLoadCount,
      'average_load_time': _averageLoadTime,
      'is_image_optimized': _isImageOptimized,
      'last_image_load_time': _lastImageLoadTime?.toIso8601String(),
      'has_cached_image': _cachedImageUrl != null,
    };
  }

  /// Check if this menu item should be prioritized for loading
  bool shouldPrioritizeLoading(String networkQuality) {
    // Prioritize featured items on slow networks
    if (networkQuality == 'slow' || networkQuality == 'verySlow') {
      return isFeatured;
    }

    // Prioritize high-rated items on moderate networks
    if (networkQuality == 'moderate') {
      return rating >= 4.0 || isFeatured;
    }

    // Load all items on fast networks
    return true;
  }

  // ========== Limited Time Offer Helper Methods ==========
  // NOTE: LTO data is now stored in pricing_options JSONB (same pattern as special packs)

  // Performance: Cache for active LTO pricing to avoid repeated iterations
  static final Map<String, _LTOCacheEntry> _ltoCache = {};

  /// Get first active LTO pricing option (if any)
  /// Performance: Memoized with 10-second cache to avoid repeated DateTime parsing
  Map<String, dynamic>? get _activeLTOPricing {
    if (pricingOptions.isEmpty) return null;

    // Check cache first (10-second TTL)
    final cached = _ltoCache[id];
    if (cached != null &&
        DateTime.now().difference(cached.timestamp).inSeconds < 10) {
      return cached.pricing;
    }

    // Compute active LTO pricing
    final now = DateTime.now();
    Map<String, dynamic>? activePricing;

    for (final pricing in pricingOptions) {
      final isLTO = pricing['is_limited_offer'] == true;
      if (!isLTO) continue;

      // Performance: Safe DateTime parsing with null fallback
      final startAt = pricing['offer_start_at'] != null
          ? _parseDateTimeSafe(pricing['offer_start_at'])
          : null;
      final endAt = pricing['offer_end_at'] != null
          ? _parseDateTimeSafe(pricing['offer_end_at'])
          : null;

      final startOk = startAt == null || now.isAfter(startAt);
      final endOk = endAt == null || now.isBefore(endAt);

      if (startOk && endOk) {
        activePricing = pricing;
        break; // Found active LTO, no need to continue
      }
    }

    // Cache the result
    _ltoCache[id] = _LTOCacheEntry(activePricing, now);

    return activePricing;
  }

  /// Check if offer is currently active based on dates (reads from pricing_options)
  bool get isOfferActive {
    return _activeLTOPricing != null;
  }

  /// Get effective price (offer price if active, otherwise regular price)
  double get effectivePrice {
    final ltoPricing = _activeLTOPricing;
    if (ltoPricing == null) return price;

    final pricingPrice = ltoPricing['price']?.toDouble() ?? 0.0;
    final pricingSize = ltoPricing['size']?.toString() ?? '';

    // Special Pack pricing: pricing_options.price contains the FULL PACK PRICE
    // Regular LTO pricing: pricing_options.price contains the EXTRA CHARGE
    // We differentiate by checking if size is 'Pack'
    if (pricingSize.toLowerCase() == 'pack') {
      // Special pack: return the full pack price directly
      return pricingPrice;
    } else {
      // Regular LTO: Final price = base price + extra charge
      return price + pricingPrice;
    }
  }

  /// Check if specific offer type is included (reads from pricing_options)
  bool hasOfferType(String type) {
    final ltoPricing = _activeLTOPricing;
    if (ltoPricing == null) return false;

    final offerTypes = ltoPricing['offer_types'] as List?;
    return offerTypes?.contains(type) ?? false;
  }

  /// Get discount percentage for special_price offers (reads from pricing_options)
  double? get discountPercentage {
    final ltoPricing = _activeLTOPricing;
    if (ltoPricing == null) return null;

    if (!hasOfferType('special_price')) return null;

    final originalPrice = ltoPricing['original_price'];
    final offerPrice = ltoPricing['price'];

    if (originalPrice == null || originalPrice <= 0 || offerPrice == null) {
      return null;
    }

    return (originalPrice - offerPrice) / originalPrice * 100;
  }

  /// Get free drinks list from offer_details (for LTO free drinks) (reads from pricing_options)
  List<String> get offerFreeDrinksList {
    final ltoPricing = _activeLTOPricing;
    if (ltoPricing == null || !hasOfferType('free_drinks')) return [];

    final drinksList = ltoPricing['offer_details']?['free_drinks_list'];
    return drinksList != null ? List<String>.from(drinksList as List) : [];
  }

  /// Get free drinks quantity from offer_details (for LTO free drinks) (reads from pricing_options)
  int get offerFreeDrinksQuantity {
    final ltoPricing = _activeLTOPricing;
    if (ltoPricing == null || !hasOfferType('free_drinks')) return 0;

    return ltoPricing['offer_details']?['free_drinks_quantity'] ?? 0;
  }

  /// Get offer start date (reads from pricing_options)
  /// Performance: Uses cached _activeLTOPricing and safe DateTime parsing
  DateTime? get offerStartAtFromPricing {
    final ltoPricing = _activeLTOPricing;
    if (ltoPricing == null) return null;

    return _parseDateTimeSafe(ltoPricing['offer_start_at']);
  }

  /// Get offer end date (reads from pricing_options)
  /// Performance: Uses cached _activeLTOPricing and safe DateTime parsing
  DateTime? get offerEndAtFromPricing {
    final ltoPricing = _activeLTOPricing;
    if (ltoPricing == null) return null;

    return _parseDateTimeSafe(ltoPricing['offer_end_at']);
  }

  /// Get original price from pricing_options (before discount)
  double? get originalPriceFromPricing {
    final ltoPricing = _activeLTOPricing;
    if (ltoPricing == null) return null;

    final origPrice = ltoPricing['original_price'];
    if (origPrice == null) return null;

    return (origPrice as num).toDouble();
  }

  /// Performance: Clear LTO cache for specific item or all items
  static void clearLTOCache([String? itemId]) {
    if (itemId != null) {
      _ltoCache.remove(itemId);
    } else {
      _ltoCache.clear();
    }
  }
}

/// Performance: Internal cache entry for LTO pricing memoization
class _LTOCacheEntry {
  final Map<String, dynamic>? pricing;
  final DateTime timestamp;

  _LTOCacheEntry(this.pricing, this.timestamp);
}
