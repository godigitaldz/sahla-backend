import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/menu_item_supplement.dart';
import '../../../services/restaurant_supplement_service.dart';
import '../../../utils/price_formatter.dart';

/// Widget to display supplement suggestions as selectable chips
/// Loads supplements from restaurant_supplements table (restaurant-level supplements only)
class SupplementSuggestionsWidget extends StatefulWidget {
  final String? restaurantId;
  final Function(MenuItemSupplement) onSupplementSelected;
  final bool isSpecialPack; // If true, adds to global pack supplements

  const SupplementSuggestionsWidget({
    required this.onSupplementSelected,
    this.restaurantId,
    this.isSpecialPack = false,
    super.key,
  });

  @override
  State<SupplementSuggestionsWidget> createState() =>
      _SupplementSuggestionsWidgetState();
}

class _SupplementSuggestionsWidgetState
    extends State<SupplementSuggestionsWidget> {
  List<MenuItemSupplement> _suggestions = [];
  bool _isLoading = true;
  final Set<String> _selectedIds = {}; // Track selected supplement IDs
  final RestaurantSupplementService _restaurantSupplementService =
      RestaurantSupplementService();

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void didUpdateWidget(SupplementSuggestionsWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload suggestions if restaurantId changed from null/empty to a valid ID
    // or if restaurantId changed to a different value
    if (oldWidget.restaurantId != widget.restaurantId) {
      if (widget.restaurantId != null && widget.restaurantId!.isNotEmpty) {
        debugPrint(
            '🔄 RestaurantId changed from ${oldWidget.restaurantId} to ${widget.restaurantId}, reloading suggestions...');
        _loadSuggestions();
      } else if (oldWidget.restaurantId != null &&
          oldWidget.restaurantId!.isNotEmpty &&
          (widget.restaurantId == null || widget.restaurantId!.isEmpty)) {
        // RestaurantId was cleared, clear suggestions
        debugPrint('🔄 RestaurantId was cleared, clearing suggestions...');
        setState(() {
          _suggestions = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadSuggestions() async {
    if (widget.restaurantId == null || widget.restaurantId!.isEmpty) {
      debugPrint(
          '⚠️ SupplementSuggestionsWidget: restaurantId is null or empty');
      setState(() => _isLoading = false);
      return;
    }

    try {
      setState(() => _isLoading = true);

      debugPrint(
          '🔍 Loading supplement suggestions for restaurant: ${widget.restaurantId}');

      // Load supplements from restaurant_supplements table
      // This will only return restaurant-level supplements (null menu_item_id)
      // which are available for selection and linking to menu items
      final supplementsList =
          await _restaurantSupplementService.getRestaurantSupplements(
        widget.restaurantId!,
      );

      debugPrint(
          '📊 Raw supplements loaded: ${supplementsList.length} (restaurantId: ${widget.restaurantId})');

      // Filter to only show available supplements as suggestions
      final availableSupplements = supplementsList.where((supplement) {
        final isAvailable = supplement.isAvailable;
        debugPrint(
            '   - ${supplement.name}: available=$isAvailable, menuItemId="${supplement.menuItemId}"');
        return isAvailable;
      }).toList();

      debugPrint(
          '📊 Available supplements: ${availableSupplements.length} out of ${supplementsList.length}');

      // Remove duplicates by name (keep first occurrence)
      final uniqueSupplements = <String, MenuItemSupplement>{};
      for (final supplement in availableSupplements) {
        if (!uniqueSupplements.containsKey(supplement.name.toLowerCase())) {
          uniqueSupplements[supplement.name.toLowerCase()] = supplement;
        }
      }

      debugPrint(
          '✅ Loaded ${uniqueSupplements.length} unique available supplement suggestions');
      debugPrint(
          '📊 Final suggestions list: ${uniqueSupplements.values.map((s) => s.name).join(", ")}');

      setState(() {
        _suggestions = uniqueSupplements.values.toList();
        _isLoading = false;
      });

      // Debug: Log final state
      if (_suggestions.isEmpty) {
        debugPrint(
            '⚠️ No suggestions to display after loading (available: ${availableSupplements.length}, total: ${supplementsList.length})');
        if (supplementsList.isNotEmpty) {
          debugPrint(
              '   📋 All loaded supplements: ${supplementsList.map((s) => '${s.name} (available: ${s.isAvailable}, menuItemId: "${s.menuItemId}")').join(", ")}');
        }
      } else {
        debugPrint(
            '✅ Suggestions widget should display ${_suggestions.length} chips');
      }
    } catch (e) {
      debugPrint('❌ Error loading supplement suggestions: $e');
      setState(() {
        _suggestions = [];
        _isLoading = false;
      });
    }
  }

  void _onChipTap(MenuItemSupplement supplement) {
    setState(() {
      _selectedIds.add(supplement.id);
    });
    widget.onSupplementSelected(supplement);
  }

  @override
  Widget build(BuildContext context) {
    // Show a subtle loading indicator while loading
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: SizedBox(
          height: 20,
          width: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[400]!),
          ),
        ),
      );
    }

    if (_suggestions.isEmpty) {
      // Debug: Show why suggestions are empty
      debugPrint(
          '⚠️ SupplementSuggestionsWidget: No suggestions to display (restaurantId: ${widget.restaurantId}, isLoading: $_isLoading)');
      return const SizedBox.shrink();
    }

    debugPrint(
        '✅ SupplementSuggestionsWidget: Building UI with ${_suggestions.length} suggestions');

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Suggestions',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _suggestions.map((supplement) {
              final isSelected = _selectedIds.contains(supplement.id);
              final formattedPrice = PriceFormatter.formatWithSettings(
                context,
                supplement.price.toString(),
              );

              return GestureDetector(
                onTap: isSelected ? null : () => _onChipTap(supplement),
                child: Chip(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          supplement.name,
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isSelected ? Colors.white : Colors.black87,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        formattedPrice,
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w400,
                          color: isSelected ? Colors.white70 : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                  backgroundColor:
                      isSelected ? const Color(0xFFd47b00) : Colors.grey[100],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: isSelected
                          ? const Color(0xFFd47b00)
                          : Colors.grey[300]!,
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
