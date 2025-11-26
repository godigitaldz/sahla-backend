import 'package:flutter/material.dart';

import '../../../../../screens/cart_screen.dart';

/// Navigate to cart screen after dismissing popup
Future<void> navigateToCartScreen(BuildContext context) async {
  if (!context.mounted) return;

  final navigator = Navigator.of(context, rootNavigator: true);
  // Dismiss the bottom sheet popup
  Navigator.of(context).pop();
  // Push cart on root navigator after popup closes
  await Future.microtask(() async {
    await navigator.push(
      MaterialPageRoute(
        builder: (context) => const CartScreen(),
      ),
    );
  });
}
