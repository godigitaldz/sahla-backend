import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supa;

import '../../l10n/app_localizations.dart';
import '../../services/restaurant_search_service.dart';

class CuisineSelectorModal extends StatefulWidget {
  final RestaurantSearchService searchService;

  const CuisineSelectorModal({
    required this.searchService,
    super.key,
  });

  @override
  State<CuisineSelectorModal> createState() => _CuisineSelectorModalState();
}

class _CuisineSelectorModalState extends State<CuisineSelectorModal> {
  // Static cache for cuisine types to avoid repeated database calls
  static List<String>? _cachedCuisines;
  static DateTime? _cacheTimestamp;
  static const Duration _cacheDuration =
      Duration(minutes: 10); // Increased cache duration

  // Performance optimizations
  late final Future<List<String>> _cuisinesFuture;

  @override
  void initState() {
    super.initState();
    _cuisinesFuture = _loadCuisines();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    if (l10n == null) {
      return const SizedBox
          .shrink(); // Return empty widget if localization is not available
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.6,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
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
                  Flexible(
                    child: Text(
                      l10n.selectCuisineType,
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed: () {
                          widget.searchService.setCuisineFilter({});
                          Navigator.pop(context);
                        },
                        child: Text(
                          l10n.clear,
                          style: GoogleFonts.inter(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          l10n.done,
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

            // Cuisine list with optimized loading and caching
            Expanded(
              child: FutureBuilder<List<String>>(
                future: _cuisinesFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        valueColor:
                            AlwaysStoppedAnimation<Color>(Color(0xFFFB8C00)),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.restaurant_menu,
                            size: 48,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.noCuisinesAvailable,
                            style: GoogleFonts.inter(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  final cuisines = snapshot.data!;

                  return RepaintBoundary(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: cuisines.length,
                      // Maximum performance optimizations
                      cacheExtent: 500, // Increased cache for better scrolling
                      addAutomaticKeepAlives:
                          false, // Don't keep items alive when scrolled out
                      addRepaintBoundaries:
                          true, // Add repaint boundaries for better performance
                      physics:
                          const BouncingScrollPhysics(), // Better scroll physics
                      itemBuilder: (context, index) {
                        final cuisine = cuisines[index];
                        final isSelected = widget.searchService.selectedCuisines
                            .contains(cuisine);

                        return RepaintBoundary(
                          key: ValueKey('cuisine_$index'),
                          child: _CuisineItem(
                            cuisine: cuisine,
                            isSelected: isSelected,
                            onTap: () => _toggleCuisine(cuisine),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleCuisine(String cuisine) {
    setState(() {
      if (widget.searchService.selectedCuisines.contains(cuisine)) {
        widget.searchService.setCuisineFilter(
            {...widget.searchService.selectedCuisines}..remove(cuisine));
      } else {
        widget.searchService.setCuisineFilter(
            {...widget.searchService.selectedCuisines, cuisine});
      }
    });
  }

  Future<List<String>> _loadCuisines() async {
    // Check cache first
    if (_cachedCuisines != null &&
        _cacheTimestamp != null &&
        DateTime.now().difference(_cacheTimestamp!) < _cacheDuration) {
      debugPrint(
          '🍽️ CuisineSelectorModal: Using cached cuisine types (${_cachedCuisines!.length} items)');
      return _cachedCuisines!;
    }

    return _loadCuisineTypesFromDatabase();
  }

  Future<List<String>> _loadCuisineTypesFromDatabase() async {
    try {
      debugPrint(
          '🍽️ CuisineSelectorModal: Loading cuisine types from database...');
      final client = supa.Supabase.instance.client;

      final cuisineRows = await client
          .from('cuisine_types')
          .select('id,name')
          .eq('is_active', true)
          .order('name')
          .timeout(const Duration(seconds: 10)) as List<dynamic>;

      if (cuisineRows.isNotEmpty) {
        final cuisines = cuisineRows
            .map((row) => (row['name'] as String).trim())
            .toList()
          ..sort();

        // Cache the results
        _cachedCuisines = cuisines;
        _cacheTimestamp = DateTime.now();

        debugPrint(
            '🍽️ CuisineSelectorModal: Loaded ${cuisines.length} cuisine types from database');
        return cuisines;
      }

      // Fallback to sample cuisines if database is empty
      debugPrint(
          '🍽️ CuisineSelectorModal: Database empty, using fallback cuisines');
      return const [
        'Algerian',
        'Fast Food',
        'Italian',
        'Chinese',
        'Indian',
        'Mexican',
        'Japanese',
        'Mediterranean',
        'American',
        'French',
      ];
    } catch (e) {
      debugPrint('❌ CuisineSelectorModal: Error loading cuisines: $e');

      // Return cached data if available, even if expired
      if (_cachedCuisines != null) {
        debugPrint(
            '🍽️ CuisineSelectorModal: Using expired cache due to error');
        return _cachedCuisines!;
      }

      // Final fallback
      return const [
        'Algerian',
        'Fast Food',
        'Italian',
        'Chinese',
        'Indian',
        'Mexican',
        'Japanese',
        'Mediterranean',
        'American',
        'French',
      ];
    }
  }
}

// Optimized cuisine item widget for maximum performance
class _CuisineItem extends StatelessWidget {
  final String cuisine;
  final bool isSelected;
  final VoidCallback onTap;

  const _CuisineItem({
    required this.cuisine,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: isSelected
                  ? const Color(0xFFFB8C00).withValues(alpha: 0.1)
                  : Colors.transparent,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    cuisine,
                    style: GoogleFonts.inter(
                      color:
                          isSelected ? const Color(0xFFFB8C00) : Colors.black,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: isSelected
                      ? const Icon(
                          Icons.check_circle,
                          key: ValueKey('selected'),
                          color: Color(0xFFFB8C00),
                          size: 24,
                        )
                      : const Icon(
                          Icons.circle_outlined,
                          key: ValueKey('unselected'),
                          color: Colors.grey,
                          size: 24,
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
