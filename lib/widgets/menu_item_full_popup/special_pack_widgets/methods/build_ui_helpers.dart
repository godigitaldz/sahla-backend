import 'package:flutter/material.dart';

import '../../../../models/menu_item.dart';
import '../../../../models/restaurant.dart';
import '../../shared_widgets/menu_item_image_section.dart';

/// Build pack info bar widget
Widget buildPackInfoBar({
  required MenuItem menuItem,
  required Restaurant? restaurant,
  required double? updatedRating,
  required int? updatedReviewCount,
}) {
  return MenuItemInfoContainer(
    menuItem: menuItem,
    restaurant: restaurant,
    updatedRating: updatedRating,
    updatedReviewCount: updatedReviewCount,
  );
}
