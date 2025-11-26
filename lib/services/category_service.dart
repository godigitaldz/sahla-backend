import 'package:flutter/foundation.dart' hide Category;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/category.dart';

class CategoryService {
  static final CategoryService _instance = CategoryService._internal();
  factory CategoryService() => _instance;
  CategoryService._internal();

  SupabaseClient get _supabase => Supabase.instance.client;

  /// Get all active categories (including drinks)
  Future<List<Category>> getActiveCategories() async {
    try {
      debugPrint('🔄 CategoryService: Fetching active categories...');
      final response = await _supabase
          .from('categories')
          .select()
          .eq('is_active', 'true')
          .order('display_order')
          .order('name');

      final categories = (response as List)
          .map((json) => Category.fromJson(json))
          .toList(); // Include all categories including drinks
      debugPrint(
          '✅ CategoryService: Successfully loaded ${categories.length} categories (including drinks)');
      return categories;
    } catch (e) {
      debugPrint('❌ CategoryService: Failed to fetch categories: $e');
      throw Exception('Failed to fetch categories: $e');
    }
  }

  /// Get categories by cuisine type ID (including drinks)
  Future<List<Category>> getCategoriesByCuisineTypeId(
      String cuisineTypeId) async {
    try {
      final response = await _supabase
          .from('categories')
          .select()
          .eq('cuisine_type_id', cuisineTypeId)
          .eq('is_active', 'true')
          .order('display_order')
          .order('name');

      return (response as List)
          .map((json) => Category.fromJson(json))
          .toList(); // Include all categories including drinks
    } catch (e) {
      throw Exception('Failed to fetch categories by cuisine type: $e');
    }
  }

  /// Get categories by cuisine type name (including drinks)
  Future<List<Category>> getCategoriesByCuisineTypeName(
      String cuisineTypeName) async {
    try {
      final response = await _supabase
          .from('categories')
          .select('''
            *,
            cuisine_types!inner(name)
          ''')
          .eq('cuisine_types.name', cuisineTypeName)
          .eq('is_active', 'true')
          .order('display_order')
          .order('name');

      return (response as List)
          .map((json) => Category.fromJson(json))
          .toList(); // Include all categories including drinks
    } catch (e) {
      throw Exception('Failed to fetch categories by cuisine type name: $e');
    }
  }

  /// Get all categories (including inactive)
  Future<List<Category>> getAllCategories() async {
    try {
      final response = await _supabase
          .from('categories')
          .select()
          .order('display_order')
          .order('name');

      return (response as List).map((json) => Category.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Failed to fetch all categories: $e');
    }
  }

  /// Get category by ID
  Future<Category?> getCategoryById(String id) async {
    try {
      final response =
          await _supabase.from('categories').select().eq('id', id).single();

      return Category.fromJson(response);
    } catch (e) {
      if (e.toString().contains('PGRST116')) {
        return null; // Not found
      }
      throw Exception('Failed to fetch category: $e');
    }
  }

  /// Get category by name and cuisine type ID
  Future<Category?> getCategoryByNameAndCuisineTypeId(
      String name, String cuisineTypeId) async {
    try {
      final response = await _supabase
          .from('categories')
          .select()
          .eq('name', name)
          .eq('cuisine_type_id', cuisineTypeId)
          .single();

      return Category.fromJson(response);
    } catch (e) {
      if (e.toString().contains('PGRST116')) {
        return null; // Not found
      }
      throw Exception('Failed to fetch category by name and cuisine type: $e');
    }
  }

  /// Create a new category
  Future<Category> createCategory(Category category) async {
    try {
      final response = await _supabase
          .from('categories')
          .insert(category.toJson())
          .select()
          .single();

      return Category.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create category: $e');
    }
  }

  /// Update a category
  Future<Category> updateCategory(Category category) async {
    try {
      final response = await _supabase
          .from('categories')
          .update(category.toJson())
          .eq('id', category.id)
          .select()
          .single();

      return Category.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update category: $e');
    }
  }

  /// Delete a category (soft delete by setting is_active to false)
  Future<void> deleteCategory(String id) async {
    try {
      await _supabase
          .from('categories')
          .update({'is_active': false}).eq('id', id);
    } catch (e) {
      throw Exception('Failed to delete category: $e');
    }
  }

  /// Hard delete a category
  Future<void> hardDeleteCategory(String id) async {
    try {
      await _supabase.from('categories').delete().eq('id', id);
    } catch (e) {
      throw Exception('Failed to hard delete category: $e');
    }
  }

  /// Search categories by name (including drinks)
  Future<List<Category>> searchCategories(String query) async {
    try {
      final response = await _supabase
          .from('categories')
          .select()
          .ilike('name', '%$query%')
          .eq('is_active', 'true')
          .order('display_order')
          .order('name');

      return (response as List)
          .map((json) => Category.fromJson(json))
          .toList(); // Include all categories including drinks
    } catch (e) {
      throw Exception('Failed to search categories: $e');
    }
  }

  /// Search categories by name within a specific cuisine type (including drinks)
  Future<List<Category>> searchCategoriesByCuisineType(
      String query, String cuisineTypeId) async {
    try {
      final response = await _supabase
          .from('categories')
          .select()
          .ilike('name', '%$query%')
          .eq('cuisine_type_id', cuisineTypeId)
          .eq('is_active', 'true')
          .order('display_order')
          .order('name');

      return (response as List)
          .map((json) => Category.fromJson(json))
          .toList(); // Include all categories including drinks
    } catch (e) {
      throw Exception('Failed to search categories by cuisine type: $e');
    }
  }
}
