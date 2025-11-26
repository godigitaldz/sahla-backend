import 'package:flutter/material.dart';

import '../../../providers/home_provider.dart';
import '../../filter_chips_section/filter_chips_section.dart';
import 'combined_filter_service.dart';

/// Widget that wraps FilterChipsSection with CombinedFilterService and handles change notifications
///
/// This wrapper:
/// - Listens to the combined filter service for changes
/// - Rebuilds FilterChipsSection when filters change
/// - Provides callbacks for filter interactions (location, cuisine, category, price)
/// - Handles clear all and delivery fee toggle actions
class FilterChipsSectionWrapper extends StatefulWidget {
  const FilterChipsSectionWrapper({
    required this.combinedFilterService,
    required this.homeProvider,
    required this.onLocationTap,
    required this.onCuisineTap,
    required this.onCategoryTap,
    required this.onPriceTap,
    super.key,
  });

  final CombinedFilterService combinedFilterService;
  final HomeProvider homeProvider;
  final VoidCallback onLocationTap;
  final VoidCallback onCuisineTap;
  final VoidCallback onCategoryTap;
  final VoidCallback onPriceTap;

  @override
  State<FilterChipsSectionWrapper> createState() =>
      _FilterChipsSectionWrapperState();
}

class _FilterChipsSectionWrapperState extends State<FilterChipsSectionWrapper> {
  @override
  void initState() {
    super.initState();
    // Listen to the combined filter service for changes
    widget.combinedFilterService.addListener(_onFilterServiceChanged);
  }

  @override
  void dispose() {
    widget.combinedFilterService.removeListener(_onFilterServiceChanged);
    super.dispose();
  }

  void _onFilterServiceChanged() {
    // Trigger a rebuild when the filter service changes
    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) => FilterChipsSection(
        searchService: widget.combinedFilterService,
        onLocationTap: widget.onLocationTap,
        onCuisineTap: widget.onCuisineTap,
        onCategoryTap: widget.onCategoryTap,
        onPriceTap: widget.onPriceTap,
        onClearAllTap: () {
          widget.combinedFilterService.clearFilters();
        },
        onDeliveryFeeToggle: ({bool? isActive}) {
          if (isActive == true) {
            widget.combinedFilterService
                .setDeliveryFeeRangeFilter(const RangeValues(0, 0));
          } else {
            widget.combinedFilterService.setDeliveryFeeRangeFilter(null);
          }
        },
      );
}
