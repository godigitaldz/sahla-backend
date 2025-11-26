import 'package:flutter/material.dart';

import '../../../../models/menu_item.dart';
import '../../../menu_item_full_popup/helpers/special_pack_helper.dart';
import '../edit_review_item_popup/regular_item_review.dart';
import '../edit_review_item_popup/special_pack_review.dart';

/// Menu Item Details Handler
/// Handles opening the appropriate review widget for menu items
class MenuItemDetailsHandler {
  /// Show menu item details based on item type
  static void showMenuItemDetails(BuildContext context, MenuItem item) {
    // Check if this is a special pack
    final isSpecialPack = SpecialPackHelper.isSpecialPack(item);

    if (isSpecialPack) {
      // Open special pack review for special pack items
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) {
          return LTOSpecialPackReview(
            ltoItem: item,
          );
        },
      );
    } else {
      // Open regular item review for non-special pack items
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (BuildContext context) {
          return RegularItemReview(
            ltoItem: item,
          );
        },
      );
    }
  }
}
