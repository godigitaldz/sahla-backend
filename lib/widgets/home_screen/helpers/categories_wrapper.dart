import 'package:flutter/material.dart';

import '../categories_section.dart';

/// Categories section wrapper widget
///
/// PERFORMANCE OPTIMIZED: No Consumer! Props passed from parent to avoid rebuilds on scroll
/// This widget now only rebuilds when its actual data changes, not on every scroll event
class CategoriesWrapper extends StatelessWidget {
  const CategoriesWrapper({
    required this.selectedCategories,
    required this.selectedCuisines,
    required this.onCategoryToggle,
    super.key,
  });

  final Set<String> selectedCategories;
  final Set<String> selectedCuisines;
  final Function(String) onCategoryToggle;

  @override
  Widget build(BuildContext context) {
    // NO Consumer - just build with provided props!
    return CategoriesSection(
      horizontalPadding: 0,
      selectedCategories: selectedCategories,
      onCategoryToggle: onCategoryToggle,
      selectedCuisines: selectedCuisines,
      normalizeCategoryKey: (String input) => input
          .trim()
          .toLowerCase()
          .replaceAll(RegExp(r"[\\s-]+"), "_")
          .replaceAll(RegExp("[^a-z0-9_]+"), ""),
    );
  }
}
