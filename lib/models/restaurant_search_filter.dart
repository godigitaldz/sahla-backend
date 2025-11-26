import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import '../utils/safe_parse.dart';

class RestaurantSearchFilter extends Equatable {
  final String? location;
  final Set<String> cuisines;
  final Set<String> categories;
  final double? minRating;
  // Menu item price range
  final RangeValues? priceRange;
  // Restaurant delivery fee range
  final RangeValues? deliveryFeeRange;
  final int? maxDeliveryTime;
  final bool? isOpen;
  final bool? isFeatured;
  final Set<String> dietaryOptions;

  const RestaurantSearchFilter({
    this.location,
    this.cuisines = const {},
    this.categories = const {},
    this.minRating,
    this.priceRange,
    this.deliveryFeeRange,
    this.maxDeliveryTime,
    this.isOpen,
    this.isFeatured,
    this.dietaryOptions = const {},
  });

  factory RestaurantSearchFilter.fromJson(Map<String, dynamic> json) {
    // Helper to parse RangeValues safely
    RangeValues? parseRangeValues(Map<String, dynamic>? rangeJson) {
      if (rangeJson == null) return null;
      final start = safeDouble(rangeJson['start']);
      final end = safeDouble(rangeJson['end']);
      if (start == null || end == null) return null;
      return RangeValues(start, end);
    }

    return RestaurantSearchFilter(
      location: safeString(json["location"]),
      cuisines: Set<String>.from(
        safeList<String>(
          json["cuisines"],
          converter: (item) => item.toString(),
        ),
      ),
      categories: Set<String>.from(
        safeList<String>(
          json["categories"],
          converter: (item) => item.toString(),
        ),
      ),
      minRating: safeDouble(json["minRating"]),
      priceRange: json["priceRange"] != null && json["priceRange"] is Map
          ? parseRangeValues(Map<String, dynamic>.from(json["priceRange"]))
          : null,
      deliveryFeeRange:
          json["deliveryFeeRange"] != null && json["deliveryFeeRange"] is Map
              ? parseRangeValues(
                  Map<String, dynamic>.from(json["deliveryFeeRange"]))
              : null,
      maxDeliveryTime: safeInt(json["maxDeliveryTime"]),
      isOpen: safeBool(json["isOpen"]),
      isFeatured: safeBool(json["isFeatured"]),
      dietaryOptions: Set<String>.from(
        safeList<String>(
          json["dietaryOptions"],
          converter: (item) => item.toString(),
        ),
      ),
    );
  }

  RestaurantSearchFilter copyWith({
    String? location,
    Set<String>? cuisines,
    Set<String>? categories,
    double? minRating,
    RangeValues? priceRange,
    RangeValues? deliveryFeeRange,
    int? maxDeliveryTime,
    bool? isOpen,
    bool? isFeatured,
    Set<String>? dietaryOptions,
  }) {
    return RestaurantSearchFilter(
      location: location ?? this.location,
      cuisines: cuisines ?? this.cuisines,
      categories: categories ?? this.categories,
      minRating: minRating ?? this.minRating,
      priceRange: priceRange ?? this.priceRange,
      deliveryFeeRange: deliveryFeeRange ?? this.deliveryFeeRange,
      maxDeliveryTime: maxDeliveryTime ?? this.maxDeliveryTime,
      isOpen: isOpen ?? this.isOpen,
      isFeatured: isFeatured ?? this.isFeatured,
      dietaryOptions: dietaryOptions ?? this.dietaryOptions,
    );
  }

  bool get hasActiveFilters {
    return location != null ||
        cuisines.isNotEmpty ||
        categories.isNotEmpty ||
        minRating != null ||
        priceRange != null ||
        deliveryFeeRange != null ||
        maxDeliveryTime != null ||
        isOpen != null ||
        isFeatured != null ||
        dietaryOptions.isNotEmpty;
  }

  int get activeFilterCount {
    int count = 0;
    if (location != null) {
      count++;
    }
    if (cuisines.isNotEmpty) {
      count++;
    }
    if (categories.isNotEmpty) {
      count++;
    }
    if (minRating != null) {
      count++;
    }
    if (priceRange != null) {
      count++;
    }
    if (deliveryFeeRange != null) {
      count++;
    }
    if (maxDeliveryTime != null) {
      count++;
    }
    if (isOpen != null) {
      count++;
    }
    if (isFeatured != null) {
      count++;
    }
    if (dietaryOptions.isNotEmpty) {
      count++;
    }
    return count;
  }

  Map<String, dynamic> toJson() {
    return {
      "location": location,
      "cuisines": cuisines.toList(),
      "categories": categories.toList(),
      "minRating": minRating,
      "priceRange": priceRange != null
          ? {
              "start": priceRange!.start,
              "end": priceRange!.end,
            }
          : null,
      "deliveryFeeRange": deliveryFeeRange != null
          ? {
              "start": deliveryFeeRange!.start,
              "end": deliveryFeeRange!.end,
            }
          : null,
      "maxDeliveryTime": maxDeliveryTime,
      "isOpen": isOpen,
      "isFeatured": isFeatured,
      "dietaryOptions": dietaryOptions.toList(),
    };
  }

  @override
  String toString() {
    return "RestaurantSearchFilter("
        "location: $location, "
        "cuisines: $cuisines, "
        "categories: $categories, "
        "minRating: $minRating, "
        "priceRange: $priceRange, "
        "deliveryFeeRange: $deliveryFeeRange, "
        "maxDeliveryTime: $maxDeliveryTime, "
        "isOpen: $isOpen, "
        "isFeatured: $isFeatured, "
        "dietaryOptions: $dietaryOptions"
        ")";
  }

  @override
  List<Object?> get props => [
        location,
        cuisines,
        categories,
        minRating,
        priceRange,
        deliveryFeeRange,
        maxDeliveryTime,
        isOpen,
        isFeatured,
        dietaryOptions,
      ];
}
