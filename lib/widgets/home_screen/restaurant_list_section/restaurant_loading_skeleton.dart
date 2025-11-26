import 'package:flutter/material.dart';

/// Restaurant loading skeleton widget
///
/// Displays a horizontal list of placeholder cards while restaurants are loading
/// Shows 6 skeleton cards with grey background
class RestaurantLoadingSkeleton extends StatelessWidget {
  const RestaurantLoadingSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.only(
          left: MediaQuery.of(context).padding.left + 6,
        ),
        itemCount: 6,
        itemBuilder: (context, index) {
          return Container(
            width: 245,
            margin: EdgeInsets.zero,
            decoration: BoxDecoration(
              color: Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
            ),
          );
        },
      ),
    );
  }
}
