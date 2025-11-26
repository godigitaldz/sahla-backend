import '../../../../../models/menu_item.dart';

/// Calculate total paid drinks price globally
/// Paid drinks are global for the entire order, not per item
double calculatePaidDrinksPrice({
  required Map<String, int> paidDrinkQuantities,
  required List<MenuItem> restaurantDrinks,
}) {
  double totalPaidDrinksPrice = 0.0;
  for (final entry in paidDrinkQuantities.entries) {
    if (entry.value > 0) {
      final drink = restaurantDrinks.firstWhere(
        (d) => d.id == entry.key,
        orElse: () => MenuItem(
          id: '',
          name: '',
          description: '',
          price: 0,
          restaurantId: '',
          category: '',
          isAvailable: true,
          image: '',
          isFeatured: false,
          preparationTime: 0,
          rating: 0.0,
          reviewCount: 0,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      if (drink.price > 0) {
        totalPaidDrinksPrice += drink.price * entry.value;
      }
    }
  }
  return totalPaidDrinksPrice;
}
