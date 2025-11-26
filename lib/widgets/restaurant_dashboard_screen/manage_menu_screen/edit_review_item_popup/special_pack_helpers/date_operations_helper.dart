import 'package:flutter/material.dart';

import '../../../../../models/menu_item.dart';
import 'special_pack_operations.dart';

/// Date Operations Helper
/// Provides business logic for date operations
class DateOperationsHelper {
  /// Update LTO start date
  static Future<bool> updateStartDate(
    MenuItem item,
    DateTime newStartDate,
  ) async {
    // Update all LTO pricing options with the same start date
    final updatedPricingOptions = item.pricingOptions.map((pricing) {
      if (pricing['is_limited_offer'] == true) {
        final updatedPricing = Map<String, dynamic>.from(pricing);
        updatedPricing['offer_start_at'] = newStartDate.toIso8601String();
        updatedPricing['updated_at'] = DateTime.now().toIso8601String();
        return updatedPricing;
      }
      return pricing;
    }).toList();

    final updatedMenuItem = item.copyWith(
      pricingOptions: updatedPricingOptions,
    );

    return EditOperationsHelper.updateMenuItem(
      item,
      (_) => updatedMenuItem,
    );
  }

  /// Update LTO end date
  static Future<bool> updateEndDate(
    MenuItem item,
    DateTime newEndDate,
  ) async {
    // Update all LTO pricing options with the same end date
    final updatedPricingOptions = item.pricingOptions.map((pricing) {
      if (pricing['is_limited_offer'] == true) {
        final updatedPricing = Map<String, dynamic>.from(pricing);
        updatedPricing['offer_end_at'] = newEndDate.toIso8601String();
        updatedPricing['updated_at'] = DateTime.now().toIso8601String();
        return updatedPricing;
      }
      return pricing;
    }).toList();

    final updatedMenuItem = item.copyWith(
      pricingOptions: updatedPricingOptions,
    );

    return EditOperationsHelper.updateMenuItem(
      item,
      (_) => updatedMenuItem,
    );
  }

  /// Pick date and time
  static Future<DateTime?> pickDateTime(
    BuildContext context,
    DateTime initialDate,
  ) async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate == null) return null;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
    );

    if (pickedTime == null) return null;

    return DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );
  }
}
