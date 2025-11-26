import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/category.dart';
import '../../../models/cuisine_type.dart';
import '../../pill_dropdown.dart';

/// Cuisine Type Dropdown Widget
class CuisineTypeDropdown extends StatelessWidget {
  final List<CuisineType> cuisineTypes;
  final String? selectedCuisineTypeId;
  final bool isLoading;
  final Function(String?) onChanged;

  const CuisineTypeDropdown({
    required this.cuisineTypes,
    required this.selectedCuisineTypeId,
    required this.isLoading,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFd47b00)),
        ),
      );
    }

    return PillDropdown<String>(
      value: selectedCuisineTypeId,
      items: [
        ...cuisineTypes.map((cuisine) => DropdownMenuItem(
              value: cuisine.id,
              child: Text(
                cuisine.name,
                style: GoogleFonts.poppins(fontSize: 12),
              ),
            )),
        DropdownMenuItem(
          value: 'custom_cuisine',
          child: Row(
            children: [
              const Icon(Icons.add_circle_outline,
                  size: 16, color: Color(0xFFd47b00)),
              const SizedBox(width: 8),
              Text(
                'Add Custom Cuisine',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFFd47b00),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
      onChanged: onChanged,
      hint: 'Cuisine',
    );
  }
}

/// Category Dropdown Widget
class CategoryDropdown extends StatelessWidget {
  final List<Category> categories;
  final String? selectedCategoryId;
  final bool isLoading;
  final Function(String?) onChanged;

  const CategoryDropdown({
    required this.categories,
    required this.selectedCategoryId,
    required this.isLoading,
    required this.onChanged,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFd47b00)),
        ),
      );
    }

    return PillDropdown<String>(
      value: selectedCategoryId,
      items: [
        ...categories.map((category) => DropdownMenuItem(
              value: category.id,
              child: Text(
                category.name,
                style: GoogleFonts.poppins(fontSize: 12),
              ),
            )),
        DropdownMenuItem(
          value: 'custom',
          child: Row(
            children: [
              const Icon(Icons.add_circle_outline,
                  size: 16, color: Color(0xFFd47b00)),
              const SizedBox(width: 8),
              Text(
                'Add Custom Category',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: const Color(0xFFd47b00),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
      onChanged: onChanged,
      hint: 'Category',
    );
  }
}
