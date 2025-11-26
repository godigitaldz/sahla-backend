import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import '../../domain/models/menu_items_state.dart';
import '../../domain/repositories/menu_items_repository.dart';

/// Provider for menu items state management
final menuItemsProvider =
    StateNotifierProvider<MenuItemsNotifier, MenuItemsState>((ref) {
  final repository = ref.watch(menuItemsRepositoryProvider);
  return MenuItemsNotifier(repository);
});

/// Notifier for managing menu items state
class MenuItemsNotifier extends StateNotifier<MenuItemsState> {
  MenuItemsNotifier(this._repository) : super(const MenuItemsState());

  final MenuItemsRepository _repository;

  // Store current filters for loadMore
  String? _currentQuery;
  Set<String>? _currentCategories;
  Set<String>? _currentCuisines;
  RangeValues? _currentPriceRange;

  /// Load initial page of menu items
  Future<void> loadInitial({
    String? query,
    Set<String>? categories,
    Set<String>? cuisines,
    RangeValues? priceRange, // Flutter's RangeValues
  }) async {
    if (state.isLoading) return;

    // Store current filters
    _currentQuery = query;
    _currentCategories = categories;
    _currentCuisines = cuisines;
    _currentPriceRange = priceRange;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final result = await _repository.fetchMenuItems(
        limit: 20,
        cursor: null,
        query: query,
        categories: categories,
        cuisines: cuisines,
        priceRange: priceRange,
      );

      if (mounted) {
        state = state.copyWith(
          items: result.items,
          cursor: result.nextCursor,
          hasMore: result.hasMore,
          totalCount: result.totalCount,
          isLoading: false,
          lastRefresh: DateTime.now(),
        );
      }

      debugPrint(
          '✅ MenuItemsProvider: Loaded ${result.items.length} items (cursor: ${result.nextCursor})');
    } catch (e, stack) {
      if (mounted) {
        state = state.copyWith(
          error: e.toString(),
          isLoading: false,
        );
      }

      // Report to Sentry
      await Sentry.captureException(
        e,
        stackTrace: stack,
        hint: Hint.withMap({
          'query': query,
          'categories': categories?.join(','),
          'cuisines': cuisines?.join(','),
        }),
      );

      debugPrint('❌ MenuItemsProvider: Error loading initial items: $e');
    }
  }

  /// Load next page of menu items (uses same filters as loadInitial)
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;

    state = state.copyWith(isLoadingMore: true);

    try {
      final result = await _repository.fetchMenuItems(
        limit: 20,
        cursor: state.cursor,
        query: _currentQuery,
        categories: _currentCategories,
        cuisines: _currentCuisines,
        priceRange: _currentPriceRange,
      );

      if (mounted) {
        state = state.copyWith(
          items: [...state.items, ...result.items],
          cursor: result.nextCursor,
          hasMore: result.hasMore,
          isLoadingMore: false,
        );
      }

      debugPrint(
          '✅ MenuItemsProvider: Loaded ${result.items.length} more items (total: ${state.items.length})');
    } catch (e, stack) {
      if (mounted) {
        state = state.copyWith(isLoadingMore: false);
      }

      await Sentry.captureException(e, stackTrace: stack);
      debugPrint('❌ MenuItemsProvider: Error loading more items: $e');
    }
  }

  /// Refresh menu items with stale-while-revalidate pattern
  Future<void> refresh() async {
    final oldItems = state.items;
    final itemCount = state.items.length.clamp(20, 60);

    try {
      final result = await _repository.fetchMenuItems(
        limit: itemCount,
        cursor: null,
        query: _currentQuery,
        categories: _currentCategories,
        cuisines: _currentCuisines,
        priceRange: _currentPriceRange,
      );

      if (mounted) {
        state = state.copyWith(
          items: result.items,
          cursor: result.nextCursor,
          hasMore: result.hasMore,
          totalCount: result.totalCount,
          lastRefresh: DateTime.now(),
        );
      }

      debugPrint('✅ MenuItemsProvider: Refreshed ${result.items.length} items');
    } catch (e) {
      // Restore old items on error (stale-while-revalidate)
      if (mounted) {
        state = state.copyWith(items: oldItems);
      }

      debugPrint('⚠️ MenuItemsProvider: Refresh failed, kept cached items');
    }
  }

  /// Update filters and reload
  Future<void> updateFilters({
    String? query,
    Set<String>? categories,
    Set<String>? cuisines,
    RangeValues? priceRange, // Flutter's RangeValues
  }) async {
    await loadInitial(
      query: query,
      categories: categories,
      cuisines: cuisines,
      priceRange: priceRange,
    );
  }

  /// Clear all items and reset state
  void clear() {
    _currentQuery = null;
    _currentCategories = null;
    _currentCuisines = null;
    _currentPriceRange = null;
    state = const MenuItemsState();
    debugPrint('🗑️ MenuItemsProvider: State cleared');
  }
}

// RangeValues from Flutter Material is now used directly
