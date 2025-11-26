import "package:flutter/material.dart";
import "package:google_fonts/google_fonts.dart";

import "../../l10n/app_localizations.dart";
import "../../utils/performance_utils.dart";

// Generic filter service interface for filter chips
abstract class FilterService {
  String? get selectedLocation;
  Set<String> get selectedCuisines;
  Set<String> get selectedCategories;
  RangeValues? get priceRange;
  RangeValues? get deliveryFeeRange;
  bool? get isOpen;
  double? get minRating;

  void clearFilters();
  void setDeliveryFeeRangeFilter(RangeValues? range);
}

class FilterChipsSection extends StatefulWidget {
  const FilterChipsSection({
    required this.searchService,
    required this.onLocationTap,
    required this.onCuisineTap,
    required this.onCategoryTap,
    required this.onPriceTap,
    super.key,
    this.onClearAllTap,
    this.onDeliveryFeeToggle,
  });

  final FilterService searchService;
  final VoidCallback onLocationTap;
  final VoidCallback onCuisineTap;
  final VoidCallback onCategoryTap;
  final VoidCallback onPriceTap;
  final VoidCallback? onClearAllTap;
  final Function({bool isActive})? onDeliveryFeeToggle;

  @override
  State<FilterChipsSection> createState() => _FilterChipsSectionState();
}

class _FilterChipsSectionState extends State<FilterChipsSection> {
  // Performance: Cache debounced callbacks to avoid creating new closures
  late final Function _debouncedLocationTap;
  late final Function _debouncedCuisineTap;
  late final Function _debouncedCategoryTap;
  late final Function _debouncedPriceTap;
  Function? _debouncedClearAllTap;

  @override
  void initState() {
    super.initState();
    _debouncedLocationTap = PerformanceUtils.debounce(
      widget.onLocationTap,
      const Duration(milliseconds: 300),
    );
    _debouncedCuisineTap = PerformanceUtils.debounce(
      widget.onCuisineTap,
      const Duration(milliseconds: 300),
    );
    _debouncedCategoryTap = PerformanceUtils.debounce(
      widget.onCategoryTap,
      const Duration(milliseconds: 300),
    );
    _debouncedPriceTap = PerformanceUtils.debounce(
      widget.onPriceTap,
      const Duration(milliseconds: 300),
    );
  }

  bool _hasActiveFilters() {
    return (widget.searchService.selectedLocation?.isNotEmpty ?? false) ||
        widget.searchService.selectedCuisines.isNotEmpty ||
        widget.searchService.selectedCategories.isNotEmpty ||
        widget.searchService.priceRange != null ||
        widget.searchService.deliveryFeeRange != null ||
        widget.searchService.isOpen != null ||
        widget.searchService.minRating != null;
  }

  @override
  Widget build(BuildContext context) {
    // Performance: Cache AppLocalizations lookup
    final l10n = AppLocalizations.of(context);
    final hasActiveFilters = _hasActiveFilters();

    // Performance: Lazy init clear all debounced callback
    if (hasActiveFilters && _debouncedClearAllTap == null) {
      _debouncedClearAllTap = PerformanceUtils.debounce(
        () {
          if (widget.onClearAllTap != null) {
            widget.onClearAllTap!();
          } else {
            widget.searchService.clearFilters();
          }
        },
        const Duration(milliseconds: 300),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Filter chips row - horizontal scroll with overflow - responsive
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.only(left: 4, right: 14),
            child: Row(
              children: [
                // Clear All button - first chip when there are active filters
                if (hasActiveFilters) ...[
                  RepaintBoundary(
                    child: _ClearAllButton(
                      onTap: () => _debouncedClearAllTap?.call(null),
                    ),
                  ),
                  const SizedBox(width: 11),
                ],
                // Free Delivery - Temporarily hidden
                // Builder(
                //   builder: (context) {
                //     final isActive = searchService.deliveryFeeRange != null &&
                //         searchService.deliveryFeeRange!.start == 0 &&
                //         searchService.deliveryFeeRange!.end == 0;
                //     return _FilterChip(
                //       label: l10n?.freeDelivery ?? 'Free Delivery',
                //       showArrow: false,
                //       isSelected: isActive,
                //       customLabel: Row(
                //         mainAxisSize: MainAxisSize.min,
                //         children: [
                //           Text(
                //             l10n?.freeDelivery ?? 'Free Delivery',
                //             style: GoogleFonts.inter(
                //               color: isActive
                //                   ? Colors.orange.shade600
                //                   : Colors.black,
                //               fontWeight: FontWeight.bold,
                //               fontSize: 11,
                //             ),
                //           ),
                //         ],
                //       ),
                //       onTap: () {
                //         final debouncedFunction = PerformanceUtils.debounce(() {
                //           if (onDeliveryFeeToggle != null) {
                //             onDeliveryFeeToggle!(isActive: !isActive);
                //           } else {
                //             // Fallback to service method if callback not provided
                //             if (isActive) {
                //               searchService.setDeliveryFeeRangeFilter(null);
                //             } else {
                //               searchService.setDeliveryFeeRangeFilter(
                //                   const RangeValues(0, 0));
                //             }
                //           }
                //         }, const Duration(milliseconds: 300));
                //         debouncedFunction(null);
                //       },
                //     );
                //   },
                // ),
                // const SizedBox(width: 6),
                RepaintBoundary(
                  child: _FilterChip(
                    label: l10n?.location ?? 'Location',
                    isSelected:
                        widget.searchService.selectedLocation?.isNotEmpty ?? false,
                    onTap: () => _debouncedLocationTap(null),
                  ),
                ),
                const SizedBox(width: 6),
                RepaintBoundary(
                  child: _FilterChip(
                    label: l10n?.cuisine ?? 'Cuisine',
                    isSelected: widget.searchService.selectedCuisines.isNotEmpty,
                    onTap: () => _debouncedCuisineTap(null),
                  ),
                ),
                const SizedBox(width: 6),
                RepaintBoundary(
                  child: _FilterChip(
                    label: l10n?.category ?? 'Category',
                    isSelected: widget.searchService.selectedCategories.isNotEmpty,
                    onTap: () => _debouncedCategoryTap(null),
                  ),
                ),
                const SizedBox(width: 6),
                RepaintBoundary(
                  child: _FilterChip(
                    label: l10n?.price ?? 'Price',
                    isSelected: widget.searchService.priceRange != null,
                    onTap: () => _debouncedPriceTap(null),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatefulWidget {
  const _FilterChip({
    required this.label,
    required this.onTap,
    this.isSelected = false,
    // ignore: unused_element_parameter
    this.showArrow = true,
    // ignore: unused_element_parameter
    this.customLabel,
  });

  final String label;
  final VoidCallback onTap;
  final bool isSelected;
  final bool showArrow;
  final Widget? customLabel;

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip> {
  // Performance: Cache expensive objects
  static final _borderRadius = BorderRadius.circular(21);
  static final _backgroundColor = Colors.grey[200]!;
  static final _borderColorDefault = Colors.grey[300]!;
  static final _borderColorSelected = Colors.orange[400]!;
  static final _labelStyle = GoogleFonts.inter(
    color: Colors.black,
    fontWeight: FontWeight.bold,
    fontSize: 11,
  );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: _borderRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: _borderRadius,
            border: Border.all(
              color: widget.isSelected ? _borderColorSelected : _borderColorDefault,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.customLabel != null)
                widget.customLabel!
              else
                Text(
                  widget.label,
                  style: _labelStyle,
                ),
              if (widget.showArrow) ...[
                const SizedBox(width: 5),
                const Icon(
                  Icons.keyboard_arrow_down,
                  color: Colors.grey,
                  size: 14,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ClearAllButton extends StatefulWidget {
  const _ClearAllButton({
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  State<_ClearAllButton> createState() => _ClearAllButtonState();
}

class _ClearAllButtonState extends State<_ClearAllButton> {
  // Performance: Cache expensive objects
  static final _borderRadius = BorderRadius.circular(21);
  static final _backgroundColor = Colors.orange[600]!;
  static const _boxShadow = [
    BoxShadow(
      color: Color(0x4DFF9800), // Colors.orange.withOpacity(0.3) pre-computed
      blurRadius: 4,
      offset: Offset(0, 2),
    ),
  ];
  static final _labelStyle = GoogleFonts.inter(
    color: Colors.white,
    fontWeight: FontWeight.w600,
    fontSize: 11,
  );

  @override
  Widget build(BuildContext context) {
    // Performance: Cache AppLocalizations lookup
    final l10n = AppLocalizations.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: _borderRadius,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: _borderRadius,
            boxShadow: _boxShadow,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.clear_all,
                color: Colors.white,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                l10n?.clearAll ?? 'Clear All',
                style: _labelStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
