import 'package:flutter/foundation.dart';

import '../../../models/menu_item.dart';
import '../../../models/menu_item_pricing.dart';

/// Helper class for Limited Time Offer (LTO) logic
class LTOHelper {
  /// Check if menu item is a Limited Time Offer
  static bool isLTO(MenuItem item) {
    return item.isLimitedOffer;
  }

  /// Check if LTO offer is currently active
  static bool isOfferActive(MenuItem item) {
    if (!item.isLimitedOffer) return false;

    final now = DateTime.now();
    final startAt = item.offerStartAt;
    final endAt = item.offerEndAt;

    if (startAt != null && now.isBefore(startAt)) {
      if (kDebugMode) {
        debugPrint('⏰ LTO offer not started yet: ${item.name}');
      }
      return false;
    }

    if (endAt != null && now.isAfter(endAt)) {
      if (kDebugMode) {
        debugPrint('⏰ LTO offer expired: ${item.name}');
      }
      return false;
    }

    return true;
  }

  /// Get offer types for LTO
  static List<String> getOfferTypes(MenuItem item) {
    if (!item.isLimitedOffer) return [];

    // Check pricing options for offer types
    if (item.pricingOptions.isNotEmpty) {
      final firstPricing = item.pricingOptions.first;
      if (firstPricing['offer_types'] is List) {
        return (firstPricing['offer_types'] as List)
            .map((e) => e.toString())
            .toList();
      }
    }

    // Fallback to item-level offer types
    if (item.offerTypes.isNotEmpty) {
      return item.offerTypes;
    }

    return [];
  }

  /// Check if LTO has specific offer type
  static bool hasOfferType(MenuItem item, String offerType) {
    final offerTypes = getOfferTypes(item);
    return offerTypes.contains(offerType);
  }

  /// Get special price discount percentage
  static double? getDiscountPercentage(MenuItem item) {
    if (!item.hasOfferType('special_price')) return null;

    // Check pricing options for discount
    if (item.pricingOptions.isNotEmpty) {
      final firstPricing = item.pricingOptions.first;
      final originalPrice = firstPricing['original_price'];
      final currentPrice = item.price;

      if (originalPrice != null && originalPrice > currentPrice) {
        final discount = ((originalPrice - currentPrice) / originalPrice) * 100;
        return discount.roundToDouble();
      }
    }

    return item.discountPercentage;
  }

  /// Get free drinks info for LTO
  static (List<String> freeDrinkIds, int quantity) getFreeDrinks(
      MenuItem item) {
    if (!item.hasOfferType('free_drinks')) {
      return ([], 0);
    }

    // Check pricing options for free drinks
    if (item.pricingOptions.isNotEmpty) {
      final firstPricing = item.pricingOptions.first;

      if (firstPricing['free_drinks_list'] is List) {
        final drinkIds = (firstPricing['free_drinks_list'] as List)
            .map((e) => e.toString())
            .toList();
        final quantity = firstPricing['free_drinks_quantity'] as int? ?? 0;
        return (drinkIds, quantity);
      }
    }

    // Fallback to item-level free drinks
    return (item.offerFreeDrinksList, item.offerFreeDrinksQuantity);
  }

  /// Get special delivery discount info
  static (String type, double value)? getSpecialDeliveryDiscount(
      MenuItem item) {
    if (!item.hasOfferType('special_delivery')) {
      return null;
    }

    // Check pricing options for special delivery
    if (item.pricingOptions.isNotEmpty) {
      final firstPricing = item.pricingOptions.first;

      if (firstPricing['offer_details'] is Map) {
        final offerDetails = firstPricing['offer_details'] as Map;
        final deliveryType = offerDetails['delivery_type']?.toString();
        final deliveryValue = offerDetails['delivery_value'];

        if (deliveryType != null && deliveryValue != null) {
          return (deliveryType, (deliveryValue as num).toDouble());
        }
      }
    }

    // Fallback to item-level offer details
    if (item.offerDetails.isNotEmpty) {
      final deliveryType = item.offerDetails['delivery_type']?.toString();
      final deliveryValue = item.offerDetails['delivery_value'];

      if (deliveryType != null && deliveryValue != null) {
        return (deliveryType, (deliveryValue as num).toDouble());
      }
    }

    return null;
  }

  /// Get complete LTO offer summary
  static List<String> getOfferSummary(MenuItem item) {
    if (!item.isLimitedOffer) return [];

    final summary = <String>[];

    // Discount percentage
    final discount = getDiscountPercentage(item);
    if (discount != null && discount > 0) {
      summary.add('${discount.toStringAsFixed(0)}% REMISE');
    }

    // Free drinks
    final (freeDrinks, quantity) = getFreeDrinks(item);
    if (freeDrinks.isNotEmpty && quantity > 0) {
      summary.add(
          '$quantity BOISSON${quantity > 1 ? 'S' : ''} GRATUITE${quantity > 1 ? 'S' : ''}');
    }

    // Special delivery
    final deliveryDiscount = getSpecialDeliveryDiscount(item);
    if (deliveryDiscount != null) {
      final (type, value) = deliveryDiscount;
      if (type == 'free') {
        summary.add('LIVRAISON GRATUITE');
      } else if (type == 'percentage') {
        summary.add('${value.toStringAsFixed(0)}% LIVRAISON');
      } else if (type == 'fixed') {
        summary.add('LIVRAISON -${value.toStringAsFixed(0)} DA');
      }
    }

    return summary;
  }

  /// Format LTO offer text for display
  static String formatOfferText(MenuItem item) {
    final summary = getOfferSummary(item);
    if (summary.isEmpty) return '';
    return summary.join(' • ');
  }

  /// Validate if free drinks must be selected for LTO
  static bool isFreeDrinksRequired(MenuItem item, MenuItemPricing? pricing) {
    if (!item.hasOfferType('free_drinks')) return false;

    // Check pricing for free drinks requirement
    if (pricing != null && pricing.freeDrinksIncluded) {
      return pricing.freeDrinksQuantity > 0;
    }

    // Fallback to item-level
    return item.offerFreeDrinksQuantity > 0;
  }

  /// Check if regular LTO item requires size selection
  /// Regular LTO: sizes are optional extra charges, default offer is always selected
  ///
  /// @deprecated Use PopupTypeHelper.isSizeRequired() instead
  /// This method will be removed in a future version
  @Deprecated('Use PopupTypeHelper.isSizeRequired() instead')
  static bool isSizeRequired(MenuItem item, bool isSpecialPack) {
    if (!item.isLimitedOffer || isSpecialPack) return true;
    // Regular LTO: sizes are optional extra charges
    return false;
  }

  /// Get base price for regular LTO items
  /// For regular LTO: always return widget.menuItem.price (the discounted offer price)
  /// For non-LTO: return pricing.price if available, else widget.menuItem.price
  ///
  /// @deprecated Use RegularItemHelper.getBasePrice() instead
  /// This method will be removed in a future version
  @Deprecated('Use RegularItemHelper.getBasePrice() instead')
  static double getBasePrice({
    required MenuItem item,
    required bool isLTO,
    required bool isSpecialPack,
    required MenuItemPricing? pricing,
  }) {
    if (isLTO && !isSpecialPack) {
      // Regular LTO: base price is the offer price
      return item.price;
    } else {
      // Non-LTO or Special Pack: pricing.price is the base price
      return pricing?.price ?? item.price;
    }
  }

  /// Get extra charge for regular LTO items
  /// For regular LTO: return pricing.price as extra charge
  /// For non-LTO: return 0.0 (no extra charge)
  ///
  /// @deprecated Use RegularItemHelper.getSizeExtraCharge() instead
  /// This method will be removed in a future version
  @Deprecated('Use RegularItemHelper.getSizeExtraCharge() instead')
  static double getExtraCharge({
    required bool isLTO,
    required bool isSpecialPack,
    required MenuItemPricing? pricing,
  }) {
    if (isLTO && !isSpecialPack) {
      // Regular LTO: pricing.price is extra charge
      return pricing?.price ?? 0.0;
    } else {
      // Non-LTO or Special Pack: no extra charge
      return 0.0;
    }
  }

  /// Calculate total price for regular LTO item
  ///
  /// @deprecated Use RegularItemHelper.calculatePrice() instead
  /// This method will be removed in a future version
  @Deprecated('Use RegularItemHelper.calculatePrice() instead')
  static double calculateRegularLTOPrice({
    required MenuItem item,
    required MenuItemPricing? pricing,
    required double supplementsPrice,
    required double drinksPrice,
    required int quantity,
  }) {
    final basePrice = getBasePrice(
      item: item,
      isLTO: true,
      isSpecialPack: false,
      pricing: null,
    );
    final extraCharge = getExtraCharge(
      isLTO: true,
      isSpecialPack: false,
      pricing: pricing,
    );

    return (basePrice + extraCharge + supplementsPrice) * quantity +
        drinksPrice;
  }

  /// Get offer details for special delivery calculation
  static Map<String, dynamic> getOfferDetails(MenuItem item) {
    if (!item.isLimitedOffer) return {};

    // Check pricing options for offer details
    if (item.pricingOptions.isNotEmpty) {
      final firstPricing = item.pricingOptions.first;
      if (firstPricing['offer_details'] is Map) {
        return Map<String, dynamic>.from(firstPricing['offer_details'] as Map);
      }
    }

    // Fallback to item-level offer details
    return item.offerDetails;
  }

  /// Check if offer is valid for current time
  static bool isValidOfferPeriod(MenuItem item) {
    if (!item.isLimitedOffer) return true;

    final now = DateTime.now();
    if (item.offerStartAt != null && now.isBefore(item.offerStartAt!)) {
      return false;
    }
    if (item.offerEndAt != null && now.isAfter(item.offerEndAt!)) {
      return false;
    }

    return true;
  }

  /// Get offer time remaining
  static Duration? getTimeRemaining(MenuItem item) {
    if (!item.isLimitedOffer || item.offerEndAt == null) return null;

    final now = DateTime.now();
    final end = item.offerEndAt!;

    if (now.isAfter(end)) return null;

    return end.difference(now);
  }

  /// Extract LTO data for cart customizations
  /// Returns a map with 'lto_offer_types' and 'lto_offer_details' if item is LTO
  /// This data is needed by CartProvider to calculate special delivery discounts
  static Map<String, dynamic> getLTOCartCustomizations({
    required MenuItem item,
    MenuItemPricing? pricing,
  }) {
    if (!item.isLimitedOffer) return {};

    final Map<String, dynamic> ltoData = {};

    // Get offer types - prioritize pricing, then item-level
    List<String> offerTypes = [];
    if (pricing != null && pricing.offerTypes.isNotEmpty) {
      offerTypes = pricing.offerTypes;
    } else if (item.pricingOptions.isNotEmpty) {
      final firstPricing = item.pricingOptions.first;
      if (firstPricing['offer_types'] is List) {
        offerTypes = (firstPricing['offer_types'] as List)
            .map((e) => e.toString())
            .toList();
      }
    } else if (item.offerTypes.isNotEmpty) {
      offerTypes = item.offerTypes;
    }

    if (offerTypes.isNotEmpty) {
      ltoData['lto_offer_types'] = offerTypes;
    }

    // Get offer details - prioritize pricing, then item-level
    Map<String, dynamic> offerDetails = {};
    if (pricing != null && pricing.offerDetails.isNotEmpty) {
      offerDetails = Map<String, dynamic>.from(pricing.offerDetails);
    } else if (item.pricingOptions.isNotEmpty) {
      final firstPricing = item.pricingOptions.first;
      if (firstPricing['offer_details'] is Map) {
        offerDetails = Map<String, dynamic>.from(
            firstPricing['offer_details'] as Map);
      }
    } else if (item.offerDetails.isNotEmpty) {
      offerDetails = Map<String, dynamic>.from(item.offerDetails);
    }

    if (offerDetails.isNotEmpty) {
      ltoData['lto_offer_details'] = offerDetails;
    }

    if (kDebugMode && ltoData.isNotEmpty) {
      debugPrint('🎯 LTOHelper.getLTOCartCustomizations:');
      debugPrint('   Item: ${item.name}');
      debugPrint('   Offer Types: $offerTypes');
      debugPrint('   Offer Details: $offerDetails');
    }

    return ltoData;
  }
}
