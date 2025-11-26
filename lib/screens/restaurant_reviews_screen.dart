import 'package:flutter/material.dart';

import '../features/reviews/ui/reviews_screen.dart';
import '../models/restaurant.dart';

/// Legacy wrapper for RestaurantReviewsScreen that delegates to the new
/// optimized ReviewsScreen implementation.
///
/// This maintains backward compatibility while leveraging the new
/// production-grade architecture with slivers, pagination, and caching.
class RestaurantReviewsScreen extends StatelessWidget {
  const RestaurantReviewsScreen({
    required this.restaurant,
    super.key,
  });

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    // Delegate to the new optimized ReviewsScreen
    return ReviewsScreen(
      restaurantId: restaurant.id,
      restaurantName: restaurant.name,
    );
  }
}
