import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../../l10n/app_localizations.dart';
import '../../services/restaurant_search_service.dart';

class PriceSelectorModal extends StatelessWidget {
  final RestaurantSearchService searchService;
  final Map<String, double>? cachedPriceRange;

  // Static cache for price range to avoid repeated database calls
  static Map<String, double>? _cachedPriceRange;
  static DateTime? _cacheTimestamp;

  const PriceSelectorModal({
    required this.searchService,
    super.key,
    this.cachedPriceRange,
  });

  @override
  Widget build(BuildContext context) {
    return _PriceSelectorModalStateful(
      searchService: searchService,
      cachedPriceRange: cachedPriceRange,
    );
  }
}

class _PriceSelectorModalStateful extends StatefulWidget {
  final RestaurantSearchService searchService;
  final Map<String, double>? cachedPriceRange;

  const _PriceSelectorModalStateful({
    required this.searchService,
    this.cachedPriceRange,
  });

  @override
  State<_PriceSelectorModalStateful> createState() =>
      _PriceSelectorModalStatefulState();
}

class _PriceSelectorModalStatefulState
    extends State<_PriceSelectorModalStateful> {
  late TextEditingController minController;
  late TextEditingController maxController;
  Map<String, double>? _priceRange;

  @override
  void initState() {
    super.initState();
    _priceRange = widget.cachedPriceRange;
    final currentRange = widget.searchService.priceRange;
    minController = TextEditingController(
      text: currentRange != null ? currentRange.start.toStringAsFixed(0) : '',
    );
    maxController = TextEditingController(
      text: currentRange != null ? currentRange.end.toStringAsFixed(0) : '',
    );
  }

  @override
  void dispose() {
    minController.dispose();
    maxController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    // Load price range if not cached
    if (_priceRange == null) {
      _loadPriceRange().then((range) {
        if (mounted) {
          setState(() {
            _priceRange = range;
          });
        }
      });
      return Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final minOrder = _priceRange!['min']!;
    final maxOrder = _priceRange!['max']!;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.6,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
              child: Row(
                children: [
                  Text(
                    l10n?.priceRange ?? 'Price Range',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          widget.searchService.setPriceRangeFilter(null);
                          minController.clear();
                          maxController.clear();
                          Navigator.pop(context);
                        },
                        child: Text(
                          l10n?.clear ?? 'Clear',
                          style: GoogleFonts.inter(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          // Apply filter when Done is pressed
                          final minText = minController.text.trim();
                          final maxText = maxController.text.trim();

                          debugPrint(
                              '💰 Price filter Done pressed - Min: "$minText", Max: "$maxText"');

                          if (minText.isEmpty && maxText.isEmpty) {
                            debugPrint(
                                '💰 Clearing price filter (both fields empty)');
                            widget.searchService.setPriceRangeFilter(null);
                            Navigator.pop(context);
                            return;
                          }

                          final minValue = minText.isNotEmpty
                              ? double.tryParse(minText)
                              : null;
                          final maxValue = maxText.isNotEmpty
                              ? double.tryParse(maxText)
                              : null;

                          debugPrint(
                              '💰 Parsed values - Min: $minValue, Max: $maxValue');
                          debugPrint(
                              '💰 Valid range - Min: $minOrder, Max: $maxOrder');

                          // If only one value is provided, use the full range for the other
                          final finalMin = minValue ?? minOrder;
                          final finalMax = maxValue ?? maxOrder;

                          // Validate the range
                          if (finalMin > finalMax) {
                            debugPrint(
                                '❌ Invalid range: $finalMin > $finalMax');
                            // Show error or swap values
                            Navigator.pop(context);
                            return;
                          }

                          // Clamp values to valid range
                          final clampedMin = finalMin.clamp(minOrder, maxOrder);
                          final clampedMax = finalMax.clamp(minOrder, maxOrder);

                          debugPrint(
                              '💰 Applying filter: $clampedMin - $clampedMax');

                          widget.searchService.setPriceRangeFilter(
                            RangeValues(clampedMin, clampedMax),
                          );

                          Navigator.pop(context);
                        },
                        child: Text(
                          l10n?.done ?? 'Done',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFFB8C00),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Price range selector
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Min and Max input fields
                  Row(
                    children: [
                      // Min input field
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n?.min ?? 'Min',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: minController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '0',
                                suffixText: 'DA',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Max input field
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n?.max ?? 'Max',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: maxController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                hintText: '0',
                                suffixText: 'DA',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<Map<String, double>> _loadPriceRange() async {
    if (widget.cachedPriceRange != null) {
      return widget.cachedPriceRange!;
    }

    // Check static cache
    if (PriceSelectorModal._cachedPriceRange != null &&
        PriceSelectorModal._cacheTimestamp != null &&
        DateTime.now().difference(PriceSelectorModal._cacheTimestamp!) <
            const Duration(minutes: 15)) {
      return PriceSelectorModal._cachedPriceRange!;
    }

    return _getPriceRangeFromDatabase();
  }

  Future<Map<String, double>> _getPriceRangeFromDatabase() async {
    try {
      final supabase = supa.Supabase.instance.client;

      // Get min and max price from menu_items table
      final response = await supabase
          .from('menu_items')
          .select('price')
          .eq('is_available', true)
          .order('price', ascending: true);

      if (response.isEmpty) {
        return {'min': 0.0, 'max': 10000.0};
      }

      final prices = response
          .map((item) => (item['price'] as num?)?.toDouble() ?? 0.0)
          .where((price) => price > 0)
          .toList();

      if (prices.isEmpty) {
        return {'min': 0.0, 'max': 10000.0};
      }

      final minPrice = prices.first;
      final maxPrice = prices.last;

      final priceRange = {
        'min': minPrice,
        'max': maxPrice,
      };

      // Cache the results
      PriceSelectorModal._cachedPriceRange = priceRange;
      PriceSelectorModal._cacheTimestamp = DateTime.now();

      return priceRange;
    } catch (e) {
      debugPrint('❌ Error getting price range from database: $e');

      if (PriceSelectorModal._cachedPriceRange != null) {
        return PriceSelectorModal._cachedPriceRange!;
      }

      return {'min': 0.0, 'max': 10000.0};
    }
  }
}
