import '../../../../models/menu_item.dart';

/// State model for menu items list screen (simplified without Freezed for now)
class MenuItemsState {
  const MenuItemsState({
    this.items = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.error,
    this.cursor,
    this.totalCount = 0,
    this.lastRefresh,
  });

  final List<MenuItem> items;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? error;
  final String? cursor;
  final int totalCount;
  final DateTime? lastRefresh;

  MenuItemsState copyWith({
    List<MenuItem>? items,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? error,
    String? cursor,
    int? totalCount,
    DateTime? lastRefresh,
  }) {
    return MenuItemsState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      error: error ?? this.error,
      cursor: cursor ?? this.cursor,
      totalCount: totalCount ?? this.totalCount,
      lastRefresh: lastRefresh ?? this.lastRefresh,
    );
  }
}

/// Paginated result model for API responses
class PaginatedResult<T> {
  PaginatedResult({
    required this.items,
    this.nextCursor,
    this.hasMore = false,
    this.totalCount = 0,
  });

  final List<T> items;
  final String? nextCursor;
  final bool hasMore;
  final int totalCount;
}
