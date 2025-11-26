import 'package:flutter/material.dart';

import '../../models/restaurant.dart';

/// Restaurant details header with logo, name, and rating
/// Extracted from RestaurantDetailsScreen for better modularity
class RestaurantDetailsHeader extends StatelessWidget {
  const RestaurantDetailsHeader({
    required this.restaurant,
    super.key,
  });

  final Restaurant restaurant;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    // Responsive expandedHeight: 10% of screen height
    final expandedHeight = screenHeight * 0.10;
    // Image extends beyond expandedHeight - pixel-based logic (80px to 100px)
    final imageExtension = (screenHeight / 8).clamp(80.0, 100.0);

    return SliverAppBar(
      expandedHeight: expandedHeight,
      pinned: true,
      elevation: 0,
      backgroundColor: Colors.white,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.0),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: Colors.black87,
            size: 18,
          ),
          onPressed: () => Navigator.of(context).pop(),
          padding: EdgeInsets.zero,
        ),
      ),
      flexibleSpace: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          return FlexibleSpaceBar(
            background: Hero(
              tag: "restaurant_${restaurant.id}",
              child: Stack(
                clipBehavior: Clip.none,
                fit: StackFit.expand,
                children: [
                  // Orange 600 background - extends beyond all edges for smooth coverage
                  Positioned(
                    top: -20,
                    left: -20,
                    right: -20,
                    bottom: -imageExtension,
                    child: Container(
                      color: Colors.orange[600],
                    ),
                  ),
                  // Background image - extends beyond all edges for smooth coverage
                  Positioned(
                    top: -20,
                    left: -20,
                    right: -20,
                    bottom: -imageExtension,
                    child: Image.asset(
                      'assets/main_restaurants_details.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
