import 'menu_item.dart';
import 'menu_item_pricing.dart';
import 'menu_item_supplement.dart';
import 'menu_item_variant.dart';

class EnhancedMenuItem {
  final String id;
  final String restaurantId;
  final String? restaurantName;
  final String name;
  final String? description;
  final String?
      mainIngredients; // When description is null, show main ingredients
  final String image;
  final String category; // Updated Algerian categories
  final bool isAvailable;
  final bool isFeatured;
  final int preparationTime;
  final double rating;
  final int reviewCount;
  final DateTime createdAt;
  final DateTime updatedAt;

  // New fields for enhanced functionality
  final List<MenuItemVariant> variants;
  final List<MenuItemPricing> pricing;
  final List<MenuItemSupplement> supplements;
  final List<String> ingredients;
  final List<String> allergens;
  final bool isSpicy;
  final int spiceLevel; // 0-5 scale
  final bool isTraditional;
  final bool isVegetarian;
  final bool isVegan;
  final bool isGlutenFree;

  EnhancedMenuItem({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.image,
    required this.category,
    required this.isAvailable,
    required this.isFeatured,
    required this.preparationTime,
    required this.rating,
    required this.reviewCount,
    required this.createdAt,
    required this.updatedAt,
    this.restaurantName,
    this.description,
    this.mainIngredients,
    this.variants = const [],
    this.pricing = const [],
    this.supplements = const [],
    this.ingredients = const [],
    this.allergens = const [],
    this.isSpicy = false,
    this.spiceLevel = 0,
    this.isTraditional = false,
    this.isVegetarian = false,
    this.isVegan = false,
    this.isGlutenFree = false,
  });

  factory EnhancedMenuItem.fromJson(Map<String, dynamic> json) {
    return EnhancedMenuItem(
      id: json['id'] ?? '',
      restaurantId: json['restaurant_id'] ?? '',
      restaurantName: json['restaurant_name'],
      name: json['name'] ?? '',
      description: json['description'],
      mainIngredients: json['main_ingredients'],
      image: json['image'] ?? '',
      category: json['category'] ?? '',
      isAvailable: json['is_available'] ?? true,
      isFeatured: json['is_featured'] ?? false,
      preparationTime: json['preparation_time'] ?? 15,
      rating: (json['rating'] ?? 0.0).toDouble(),
      reviewCount: json['review_count'] ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
      variants: json['variants'] != null
          ? (json['variants'] as List)
              .map((v) => MenuItemVariant.fromJson(v))
              .toList()
          : [],
      pricing: (json['pricing_options'] ?? json['pricing']) != null
          ? ((json['pricing_options'] ?? json['pricing']) as List)
              .map((p) => MenuItemPricing.fromJson(p))
              .toList()
          : [],
      supplements: json['supplements'] != null
          ? (json['supplements'] as List)
              .map((s) => MenuItemSupplement.fromJson(s))
              .toList()
          : [],
      ingredients: json['ingredients'] != null
          ? List<String>.from(json['ingredients'])
          : [],
      allergens: [], // Allergens field doesn't exist in DB, always empty
      isSpicy: json['is_spicy'] ?? false,
      spiceLevel: json['spice_level'] ?? 0,
      isTraditional: json['is_traditional'] ?? false,
      isVegetarian: json['is_vegetarian'] ?? false,
      isVegan: json['is_vegan'] ?? false,
      isGlutenFree: json['is_gluten_free'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'restaurant_id': restaurantId,
      'restaurant_name': restaurantName,
      'name': name,
      'description': description,
      'main_ingredients': mainIngredients,
      'image': image,
      'category': category,
      'is_available': isAvailable,
      'is_featured': isFeatured,
      'preparation_time': preparationTime,
      'rating': rating,
      'review_count': reviewCount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'variants': variants.map((v) => v.toJson()).toList(),
      'pricing_options':
          pricing.map((p) => p.toJson()).toList(), // Match DB column name
      'supplements': supplements.map((s) => s.toJson()).toList(),
      'ingredients': ingredients,
      // allergens field doesn't exist in DB schema - removing
      'is_spicy': isSpicy,
      'spice_level': spiceLevel,
      'is_traditional': isTraditional,
      'is_vegetarian': isVegetarian,
      'is_vegan': isVegan,
      'is_gluten_free': isGlutenFree,
    };
  }

  EnhancedMenuItem copyWith({
    String? id,
    String? restaurantId,
    String? restaurantName,
    String? name,
    String? description,
    String? mainIngredients,
    String? image,
    String? category,
    bool? isAvailable,
    bool? isFeatured,
    int? preparationTime,
    double? rating,
    int? reviewCount,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<MenuItemVariant>? variants,
    List<MenuItemPricing>? pricing,
    List<MenuItemSupplement>? supplements,
    List<String>? ingredients,
    List<String>? allergens,
    bool? isSpicy,
    int? spiceLevel,
    bool? isTraditional,
    bool? isVegetarian,
    bool? isVegan,
    bool? isGlutenFree,
  }) {
    return EnhancedMenuItem(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      restaurantName: restaurantName ?? this.restaurantName,
      name: name ?? this.name,
      description: description ?? this.description,
      mainIngredients: mainIngredients ?? this.mainIngredients,
      image: image ?? this.image,
      category: category ?? this.category,
      isAvailable: isAvailable ?? this.isAvailable,
      isFeatured: isFeatured ?? this.isFeatured,
      preparationTime: preparationTime ?? this.preparationTime,
      rating: rating ?? this.rating,
      reviewCount: reviewCount ?? this.reviewCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      variants: variants ?? this.variants,
      pricing: pricing ?? this.pricing,
      supplements: supplements ?? this.supplements,
      ingredients: ingredients ?? this.ingredients,
      allergens: allergens ?? this.allergens,
      isSpicy: isSpicy ?? this.isSpicy,
      spiceLevel: spiceLevel ?? this.spiceLevel,
      isTraditional: isTraditional ?? this.isTraditional,
      isVegetarian: isVegetarian ?? this.isVegetarian,
      isVegan: isVegan ?? this.isVegan,
      isGlutenFree: isGlutenFree ?? this.isGlutenFree,
    );
  }

  // Helper methods
  String get displayDescription =>
      description ?? mainIngredients ?? 'No description available';

  MenuItemVariant? get defaultVariant => variants.firstWhere(
        (v) => v.isDefault,
        orElse: () => variants.isNotEmpty
            ? variants.first
            : MenuItemVariant(
                id: '',
                menuItemId: id,
                name: 'Default',
                createdAt: DateTime.now(),
                updatedAt: DateTime.now()),
      );

  MenuItemPricing? get defaultPricing => pricing.firstWhere(
        (p) => p.isDefault,
        orElse: () => pricing.isNotEmpty
            ? pricing.first
            : MenuItemPricing(
                id: '',
                menuItemId: id,
                size: 'Regular',
                portion: '1 serving',
                price: 0.0,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now()),
      );

  // Convert to regular MenuItem for compatibility
  MenuItem toMenuItem() {
    return MenuItem(
      id: id,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      name: name,
      description: displayDescription,
      image: image,
      price: defaultPricing?.price ?? 0.0,
      category: category,
      isAvailable: isAvailable,
      isFeatured: isFeatured,
      preparationTime: preparationTime,
      rating: rating,
      reviewCount: reviewCount,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }

  @override
  String toString() {
    return 'EnhancedMenuItem(id: $id, name: $name, category: $category, variants: ${variants.length}, pricing: ${pricing.length})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EnhancedMenuItem && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
