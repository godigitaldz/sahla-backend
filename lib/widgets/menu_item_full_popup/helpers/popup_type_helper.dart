import 'package:flutter/foundation.dart';

import '../../../models/menu_item.dart';
import 'lto_helper.dart';
import 'special_pack_helper.dart';

/// Enum for popup item types
enum PopupItemType {
  specialPack,
  ltoRegular,
  regular,
}

/// Helper class for determining popup item type and behavior
/// Centralizes logic for routing between special pack, LTO, and regular items
class PopupTypeHelper {
  /// Check if item is a special pack
  static bool isSpecialPack(MenuItem item) {
    return SpecialPackHelper.isSpecialPack(item);
  }

  /// Check if item is a Limited Time Offer
  static bool isLTO(MenuItem item) {
    return LTOHelper.isLTO(item);
  }

  /// Check if item is a regular (non-special pack, non-LTO) item
  static bool isRegular(MenuItem item) {
    return !isSpecialPack(item) && !isLTO(item);
  }

  /// Determine the item type for popup routing
  static PopupItemType getItemType(MenuItem item) {
    if (isSpecialPack(item)) {
      return PopupItemType.specialPack;
    }
    if (isLTO(item)) {
      return PopupItemType.ltoRegular;
    }
    return PopupItemType.regular;
  }

  /// Check if size selection is required for this item type
  /// - Special packs: Always require size selection
  /// - LTO regular: Size is optional (extra charge)
  /// - Regular: Size is required
  static bool isSizeRequired(MenuItem item) {
    if (isSpecialPack(item)) {
      return true; // Special packs always require size
    }
    if (isLTO(item)) {
      return false; // LTO regular: size is optional extra charge
    }
    return true; // Regular: size is required
  }

  /// Check if header info (prep time, rating, restaurant) should be shown
  /// Header info is hidden for special packs (shown in info bar instead)
  static bool shouldShowHeaderInfo(MenuItem item) {
    return !isSpecialPack(item); // Only show for non-special packs
  }

  /// Check if LTO badges (price, timer, delivery) should be shown
  /// Only show for LTO items that are NOT special packs
  static bool shouldShowLTOBadges(MenuItem item) {
    return isLTO(item) && !isSpecialPack(item);
  }

  /// Check if free drinks section should be shown inside variant container
  /// - Special packs: Free drinks shown in unified add to cart widget
  /// - LTO regular: Free drinks shown inside variant container
  /// - Regular: No free drinks
  static bool shouldShowFreeDrinksInVariant(MenuItem item) {
    return isLTO(item) && !isSpecialPack(item);
  }

  /// Check if free drinks section should be shown in unified add to cart widget
  /// Only for special packs
  static bool shouldShowFreeDrinksInAddToCart(MenuItem item) {
    return isSpecialPack(item);
  }

  /// Check if pack item selector should be used
  /// Only for special packs
  static bool shouldUsePackItemSelector(MenuItem item) {
    return isSpecialPack(item);
  }

  /// Check if standard variant selector should be used
  /// For LTO regular and regular items
  static bool shouldUseStandardVariantSelector(MenuItem item) {
    return !isSpecialPack(item);
  }

  /// Check if pack-specific state should be initialized
  /// Only for special packs
  static bool shouldInitializePackState(MenuItem item) {
    return isSpecialPack(item);
  }

  /// Get debug label for item type
  static String getItemTypeLabel(MenuItem item) {
    switch (getItemType(item)) {
      case PopupItemType.specialPack:
        return 'Special Pack';
      case PopupItemType.ltoRegular:
        return 'LTO Regular';
      case PopupItemType.regular:
        return 'Regular';
    }
  }

  /// Log item type detection (for debugging)
  static void logItemType(MenuItem item) {
    if (kDebugMode) {
      debugPrint('🔍 PopupTypeHelper: Item "${item.name}"');
      debugPrint('   Type: ${getItemTypeLabel(item)}');
      debugPrint('   isSpecialPack: ${isSpecialPack(item)}');
      debugPrint('   isLTO: ${isLTO(item)}');
      debugPrint('   isRegular: ${isRegular(item)}');
      debugPrint('   isSizeRequired: ${isSizeRequired(item)}');
      debugPrint('   shouldShowHeaderInfo: ${shouldShowHeaderInfo(item)}');
      debugPrint('   shouldShowLTOBadges: ${shouldShowLTOBadges(item)}');
    }
  }
}
