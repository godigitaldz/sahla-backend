/// Result wrapper for paginated data.
class PagedResult<T> {
  const PagedResult({
    required this.items,
    required this.hasMore,
    this.nextPage,
    this.totalCount,
  });

  final List<T> items;
  final bool hasMore;
  final int? nextPage;
  final int? totalCount;

  PagedResult<T> copyWith({
    List<T>? items,
    bool? hasMore,
    int? nextPage,
    int? totalCount,
  }) {
    return PagedResult<T>(
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      nextPage: nextPage ?? this.nextPage,
      totalCount: totalCount ?? this.totalCount,
    );
  }
}

