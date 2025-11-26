import '../../../models/category.dart';
import '../../../models/cuisine_type.dart';

/// Helper methods for form field data lookups in add new menu item screen.
///
/// This file contains reusable helper methods for:
/// - Category lookups
/// - Cuisine type lookups
/// - Other data retrieval operations
///
/// These helpers provide safe null-handling and eliminate duplicate lookup logic.
class FormFieldHelpers {
  FormFieldHelpers._(); // Private constructor to prevent instantiation

  /// Gets a category by ID from a list of categories
  ///
  /// Returns null if:
  /// - The ID is null
  /// - No category with that ID exists
  static Category? getCategoryById(
    String? categoryId,
    List<Category> allCategories,
  ) {
    if (categoryId == null) return null;
    try {
      return allCategories.firstWhere((cat) => cat.id == categoryId);
    } catch (e) {
      return null;
    }
  }

  /// Gets a cuisine type by ID from a list of cuisine types
  ///
  /// Returns null if:
  /// - The ID is null
  /// - The cuisine types list is empty
  /// - No cuisine with that ID exists
  static CuisineType? getCuisineById(
    String? cuisineId,
    List<CuisineType> cuisineTypes,
  ) {
    if (cuisineId == null || cuisineTypes.isEmpty) return null;
    try {
      return cuisineTypes.firstWhere((c) => c.id == cuisineId);
    } catch (e) {
      return null;
    }
  }

  /// Creates a default/fallback Category when one is not found
  static Category createDefaultCategory() {
    return Category(
      id: '',
      cuisineTypeId: '',
      name: '',
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  /// Creates a default/fallback CuisineType when one is not found
  static CuisineType createDefaultCuisineType({String name = 'Unknown'}) {
    return CuisineType(
      id: '',
      name: name,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
