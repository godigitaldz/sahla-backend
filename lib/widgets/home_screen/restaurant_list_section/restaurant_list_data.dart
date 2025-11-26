/// Data class for Selector optimization
///
/// Only rebuilds when restaurant list or loading state changes.
/// This class is used with Provider's `Selector` to minimize unnecessary rebuilds
/// by comparing only the length of the restaurant list and the loading state,
/// rather than doing deep equality checks on the entire list.
///
/// Performance optimization: Uses length comparison instead of full list comparison
/// for faster equality checks (O(1) vs O(n)).
class RestaurantListData {
  final List<dynamic> restaurants;
  final bool isLoading;

  RestaurantListData({
    required this.restaurants,
    required this.isLoading,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RestaurantListData &&
          runtimeType == other.runtimeType &&
          restaurants.length == other.restaurants.length &&
          isLoading == other.isLoading;

  @override
  int get hashCode => restaurants.length.hashCode ^ isLoading.hashCode;
}
