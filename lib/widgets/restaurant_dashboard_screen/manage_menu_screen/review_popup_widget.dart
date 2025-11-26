import 'package:flutter/material.dart';

import '../../../models/menu_item.dart';
import '../../menu_item_full_popup/helpers/special_pack_helper.dart';
import 'edit_review_item_popup/regular_item_review.dart';
import 'edit_review_item_popup/special_pack_review.dart';

/// Review Popup Widget
/// Displays detailed information about a Limited Time Offer item
/// Conditionally renders regular item or special pack review based on item type
class ReviewPopupWidget extends StatefulWidget {
  final MenuItem ltoItem;

  const ReviewPopupWidget({
    required this.ltoItem,
    super.key,
  });

  @override
  State<ReviewPopupWidget> createState() => _ReviewPopupWidgetState();
}

class _ReviewPopupWidgetState extends State<ReviewPopupWidget> {
  /// Check if this LTO item is a special pack
  bool get _isSpecialPack {
    // Check by category first
    if (SpecialPackHelper.isSpecialPack(widget.ltoItem)) {
      return true;
    }
    // Check if there's a pricing option with size == 'Pack' and is_limited_offer == true
    for (final pricing in widget.ltoItem.pricingOptions) {
      if (pricing['is_limited_offer'] == true) {
        final size = pricing['size']?.toString().toLowerCase();
        if (size == 'pack') {
          return true;
        }
      }
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    // Directly return the review widget - it already has its own DraggableScrollableSheet
    // No need to wrap it again, which would cause nested scrollable sheets and white gaps
    return _isSpecialPack
        ? LTOSpecialPackReview(
            ltoItem: widget.ltoItem,
          )
        : RegularItemReview(
            ltoItem: widget.ltoItem,
          );
  }
}
