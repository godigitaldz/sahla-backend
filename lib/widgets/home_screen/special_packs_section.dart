import "dart:async";

import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "package:shimmer/shimmer.dart";
import "package:supabase_flutter/supabase_flutter.dart";

import "../../models/menu_item.dart";
import "../../services/socket_service.dart";
import "../menu_item_full_popup/helpers/popup_helper.dart";
import "../menu_item_full_popup/helpers/special_pack_helper.dart";
import "best_choices_section/cached_menu_item_dimensions.dart";
import "best_choices_section/menu_item_section_card.dart";

/// Result of fetching special pack items
class _FetchResult {
  final List<MenuItem> items;
  final int fetchedCount; // Number of items fetched from database

  _FetchResult({required this.items, required this.fetchedCount});
}

/// Special Packs section - displays special pack menu items in a horizontal scrollable list
class SpecialPacksSection extends StatefulWidget {
  const SpecialPacksSection({super.key});

  @override
  State<SpecialPacksSection> createState() => _SpecialPacksSectionState();
}

class _SpecialPacksSectionState extends State<SpecialPacksSection> {
  // Services
  late SocketService _socketService;
  final _supabase = Supabase.instance.client;

  // State
  bool _isLoading = true;
  bool _hasError = false;
  List<MenuItem> _specialPackItems = [];
  bool _isLoadingMore = false;
  bool _hasMoreData = true;
  int _databaseOffset = 0; // Track database offset (total items fetched)
  static const int _batchSize = 10; // Load 10 special pack cards at a time

  // Scroll controller for lazy loading
  final ScrollController _scrollController = ScrollController();

  // Real-time state - use ValueNotifier to avoid full rebuilds
  final Map<String, ValueNotifier<bool>> _itemAvailabilityNotifiers = {};
  final Map<String, ValueNotifier<double>> _dynamicPriceNotifiers = {};

  // Subscriptions
  StreamSubscription? _menuUpdatesSubscription;
  StreamSubscription? _priceUpdatesSubscription;

  // Performance: Cache MediaQuery and dimensions
  late Size _screenSize;
  late double _cardWidth;
  late double _cardHeight;
  late CachedMenuItemDimensions _dimensions;

  @override
  void initState() {
    super.initState();
    _initializeServices();
    _setupScrollListener();
    _loadSpecialPackItems();
  }

  void _setupScrollListener() {
    _scrollController.addListener(() {
      if (!_scrollController.hasClients) return;

      final position = _scrollController.position;
      final maxScroll = position.maxScrollExtent;

      // Load more when user scrolls to 80% of the list
      if (position.pixels >= maxScroll * 0.8 && _hasMoreData && !_isLoadingMore) {
        _loadMoreItems();
      }
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Performance: Cache MediaQuery lookups once
    _screenSize = MediaQuery.of(context).size;
    _dimensions = CachedMenuItemDimensions.fromScreenWidth(_screenSize.width);
    _cardWidth = _dimensions.cardWidth;
    // Special pack cards use original fixed aspect ratio (1.65), not responsive height
    _cardHeight = _cardWidth * 1.65;
  }

  void _initializeServices() {
    try {
      // Initialize Socket.io service
      _socketService = Provider.of<SocketService>(context, listen: false);

      // Set up real-time listeners
      _setupRealTimeListeners();
    } catch (e) {
      debugPrint("❌ SpecialPacksSection: Error initializing services: $e");
    }
  }

  void _setupRealTimeListeners() {
    // Listen for menu item availability updates
    _menuUpdatesSubscription = _socketService.notificationStream.listen((data) {
      if (data["type"] == "menu_update") {
        _handleMenuUpdate(data);
      }
    });

    // Listen for price updates
    _priceUpdatesSubscription =
        _socketService.notificationStream.listen((data) {
      if (data["type"] == "price_update") {
        _handlePriceUpdate(data);
      }
    });
  }

  void _handleMenuUpdate(Map<String, dynamic> data) {
    final itemId = data["itemId"] as String?;
    final isAvailable = data["isAvailable"] as bool?;

    if (itemId != null &&
        isAvailable != null &&
        _itemAvailabilityNotifiers.containsKey(itemId)) {
      // Performance: Update ValueNotifier directly, no setState needed
      _itemAvailabilityNotifiers[itemId]?.value = isAvailable;
    }
  }

  void _handlePriceUpdate(Map<String, dynamic> data) {
    final itemId = data["itemId"] as String?;
    final newPrice = data["price"]?.toDouble();

    if (itemId != null &&
        newPrice != null &&
        _dynamicPriceNotifiers.containsKey(itemId)) {
      // Performance: Update ValueNotifier directly, no setState needed
      _dynamicPriceNotifiers[itemId]?.value = newPrice;
    }
  }

  /// Load Special Pack items from database (initial load)
  Future<void> _loadSpecialPackItems() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _hasError = false;
      _databaseOffset = 0;
      _hasMoreData = true;
    });

    try {
      debugPrint("🎯 Loading Special Pack items (initial batch)...");

      // Load first batch of 10 items
      final result = await _fetchSpecialPackItems(offset: 0, limit: _batchSize);
      final items = result.items;
      final fetchedCount = result.fetchedCount;

      debugPrint("✅ Loaded ${items.length} Special Pack items (initial batch, fetched $fetchedCount from DB)");

      // Performance: Initialize ValueNotifiers for real-time updates
      // Dispose old notifiers first
      for (final notifier in _itemAvailabilityNotifiers.values) {
        notifier.dispose();
      }
      for (final notifier in _dynamicPriceNotifiers.values) {
        notifier.dispose();
      }
      _itemAvailabilityNotifiers.clear();
      _dynamicPriceNotifiers.clear();

      // Create new notifiers
      for (final item in items) {
        _itemAvailabilityNotifiers[item.id] = ValueNotifier(item.isAvailable);
        _dynamicPriceNotifiers[item.id] = ValueNotifier(item.price);
      }

      if (mounted) {
        setState(() {
          _specialPackItems = items;
          _isLoading = false;
          _hasError = false;
          _databaseOffset = fetchedCount;
          _hasMoreData = items.length >= _batchSize; // More data if we got a full batch
        });
      }
    } catch (e) {
      debugPrint("❌ Error loading Special Pack items: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  /// Fetch Special Pack items from database with pagination
  Future<_FetchResult> _fetchSpecialPackItems({
    required int offset,
    required int limit,
  }) async {
    try {
      // Fetch more items than needed to filter special packs
      // Start with 2x, but increase if we don't get enough special packs
      int fetchLimit = (limit * 2).clamp(10, 100);
      int totalFetched = 0;
      final items = <MenuItem>[];

      // Keep fetching until we have enough special pack items or run out of data
      while (items.length < limit && fetchLimit <= 200) {
        final response = await _supabase
            .from('menu_items')
            .select('*')
            .eq('is_available', true)
            .order('created_at', ascending: false)
            .range(offset + totalFetched, offset + totalFetched + fetchLimit - 1);

        if ((response as List).isEmpty) {
          // No more items in database
          break;
        }

        totalFetched += (response as List).length;

        // Parse items and filter for special packs (excluding LTO items)
        for (final json in (response as List)) {
          try {
            final item = MenuItem.fromJson(json);
            // Only include special pack items with valid images that are NOT LTO
            if (SpecialPackHelper.isSpecialPack(item) &&
                item.image.isNotEmpty &&
                !item.isOfferActive &&
                !item.hasExpiredLTOOffer) {
              items.add(item);
              // Stop when we have enough items
              if (items.length >= limit) break;
            }
          } catch (e) {
            // Skip items that can't be parsed
            debugPrint("⚠️ Skipping special pack item due to parsing error: $e");
          }
        }

        // If we got fewer items than requested, we've reached the end
        if ((response as List).length < fetchLimit) {
          break;
        }

        // If we still need more items, increase fetch limit for next batch
        if (items.length < limit) {
          fetchLimit = ((fetchLimit * 1.5).round()).clamp(10, 200);
        }
      }

      return _FetchResult(items: items, fetchedCount: totalFetched);
    } catch (e) {
      debugPrint("❌ Error fetching Special Pack items: $e");
      return _FetchResult(items: [], fetchedCount: 0);
    }
  }

  /// Load more Special Pack items (lazy loading)
  Future<void> _loadMoreItems() async {
    if (!mounted || _isLoadingMore || !_hasMoreData) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      debugPrint("🎯 Loading more Special Pack items (database offset: $_databaseOffset)...");

      // Fetch next batch
      final result = await _fetchSpecialPackItems(
        offset: _databaseOffset,
        limit: _batchSize,
      );
      final moreItems = result.items;
      final fetchedCount = result.fetchedCount;

      if (moreItems.isEmpty || fetchedCount == 0) {
        // No more items available
        if (mounted) {
          setState(() {
            _hasMoreData = false;
            _isLoadingMore = false;
          });
        }
        return;
      }

      debugPrint("✅ Loaded ${moreItems.length} more Special Pack items (fetched $fetchedCount from DB)");

      // Create notifiers for new items
      for (final item in moreItems) {
        _itemAvailabilityNotifiers[item.id] = ValueNotifier(item.isAvailable);
        _dynamicPriceNotifiers[item.id] = ValueNotifier(item.price);
      }

      if (mounted) {
        setState(() {
          _specialPackItems = [..._specialPackItems, ...moreItems];
          _databaseOffset += fetchedCount;
          _hasMoreData = moreItems.length >= _batchSize; // More data if we got a full batch
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      debugPrint("❌ Error loading more Special Pack items: $e");
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  void _navigateToMenuItemDetails(MenuItem menuItem) {
    // Show the full-width popup
    PopupHelper.showMenuItemPopup(
      context: context,
      menuItem: menuItem,
      onItemAddedToCart: (orderItem) {
        // Show confirmation when item is added to cart
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                "${orderItem.menuItem?.name ?? "Item"} added to cart",
              ),
              duration: const Duration(seconds: 2),
              backgroundColor: Colors.green[600],
            ),
          );
        }
      },
      onDataChanged: () {
        // Refresh special pack items when data changes
        if (mounted) {
          _loadSpecialPackItems();
        }
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _menuUpdatesSubscription?.cancel();
    _priceUpdatesSubscription?.cancel();

    // Performance: Dispose all ValueNotifiers
    for (final notifier in _itemAvailabilityNotifiers.values) {
      notifier.dispose();
    }
    for (final notifier in _dynamicPriceNotifiers.values) {
      notifier.dispose();
    }

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading state
    if (_isLoading) {
      return _buildSkeletonLoading();
    }

    // Show error state
    if (_hasError) {
      return _buildErrorState();
    }

    // Show empty state if no special pack items
    if (_specialPackItems.isEmpty) {
      return const SizedBox.shrink();
    }

    // Show special pack items in horizontal list
    return RepaintBoundary(
      child: Container(
        color: Colors.white,
        padding: const EdgeInsets.only(top: 12, bottom: 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Horizontal scrollable cards with lazy loading
            SizedBox(
              height: _cardHeight,
              child: ListView.builder(
                controller: _scrollController,
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _specialPackItems.length + (_isLoadingMore ? 1 : 0),
                itemExtent: _cardWidth + 8, // Card width + spacing
                itemBuilder: (context, index) {
                  // Show shimmer loading indicator at the end
                  if (index >= _specialPackItems.length) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Shimmer.fromColors(
                        baseColor: Colors.grey[300]!,
                        highlightColor: Colors.grey[100]!,
                        period: const Duration(milliseconds: 1500),
                        child: Container(
                          width: _cardWidth,
                          height: _cardHeight,
                          decoration: BoxDecoration(
                            color: Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    );
                  }

                  final item = _specialPackItems[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index < _specialPackItems.length - 1 ? 8 : 0,
                    ),
                    child: ValueListenableBuilder<bool>(
                      valueListenable: _itemAvailabilityNotifiers[item.id] ??
                          ValueNotifier(item.isAvailable),
                      builder: (context, isAvailable, child) {
                        return ValueListenableBuilder<double>(
                          valueListenable: _dynamicPriceNotifiers[item.id] ??
                              ValueNotifier(item.price),
                          builder: (context, price, child) {
                            // Create a copy of the item with updated availability and price
                            final updatedItem = item.copyWith(
                              isAvailable: isAvailable,
                              price: price,
                            );
                            return MenuItemSectionCard(
                              menuItem: updatedItem,
                              dimensions: _dimensions,
                              onTap: () =>
                                  _navigateToMenuItemDetails(updatedItem),
                            );
                          },
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

  Widget _buildSkeletonLoading() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.only(top: 16, bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Skeleton cards
          SizedBox(
            height: _cardHeight,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: 3,
              itemExtent: _cardWidth + 8,
              itemBuilder: (context, index) {
                return Padding(
                  padding: EdgeInsets.only(right: index < 2 ? 8 : 0),
                  child: Shimmer.fromColors(
                    baseColor: Colors.grey[300]!,
                    highlightColor: Colors.grey[100]!,
                    child: Container(
                      width: _cardWidth,
                      height: _cardHeight,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return const SizedBox.shrink();
  }
}
