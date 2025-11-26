import 'dart:convert';

import 'package:equatable/equatable.dart';

import '../utils/safe_parse.dart';

class MenuItemCustomizations extends Equatable {
  final List<String> selectedVariants;
  final List<String> selectedSupplements;
  final String? specialInstructions;
  final Map<String, dynamic>? additionalOptions;

  const MenuItemCustomizations({
    this.selectedVariants = const [],
    this.selectedSupplements = const [],
    this.specialInstructions,
    this.additionalOptions,
  });

  factory MenuItemCustomizations.fromJson(Map<String, dynamic> json) {
    return MenuItemCustomizations(
      selectedVariants: safeList<String>(
        json['selected_variants'],
        converter: (item) => item.toString(),
      ),
      selectedSupplements: safeList<String>(
        json['selected_supplements'],
        converter: (item) => item.toString(),
      ),
      specialInstructions: safeString(json['special_instructions']),
      additionalOptions: safeMap(json['additional_options']),
    );
  }

  // Add fromMap method for backward compatibility
  factory MenuItemCustomizations.fromMap(Map<String, dynamic> map) {
    // Variant can come as a String, Map, or List
    String? resolvedVariant;
    final rawVariant = map['variant'] ?? map['selected_variant'];
    if (rawVariant is String) {
      resolvedVariant = rawVariant;
    } else if (rawVariant is Map) {
      // Prefer name/label, fallback to id
      resolvedVariant =
          (rawVariant['name'] ?? rawVariant['label'] ?? rawVariant['id'])
              ?.toString();
    } else if (rawVariant is List && rawVariant.isNotEmpty) {
      final first = rawVariant.first;
      if (first is String) {
        resolvedVariant = first;
      } else if (first is Map) {
        resolvedVariant =
            (first['name'] ?? first['label'] ?? first['id'])?.toString();
      }
    }

    // Supplements can come as List<String> or List<Map>
    final List<String> resolvedSupplements = [];
    final rawSupplements = map['supplements'] ?? map['selected_supplements'];
    if (rawSupplements is List) {
      for (final s in rawSupplements) {
        if (s is String) {
          if (s.isNotEmpty) resolvedSupplements.add(s);
        } else if (s is Map) {
          final name = (s['name'] ?? s['label'] ?? s['id'])?.toString();
          if (name != null && name.isNotEmpty) resolvedSupplements.add(name);
        } else if (s != null) {
          final name = s.toString();
          if (name.isNotEmpty) resolvedSupplements.add(name);
        }
      }
    }

    final special =
        (map['special_requests'] ?? map['special_instructions'])?.toString();

    return MenuItemCustomizations(
      selectedVariants: resolvedVariant != null && resolvedVariant.isNotEmpty
          ? [resolvedVariant]
          : const [],
      selectedSupplements: resolvedSupplements,
      specialInstructions:
          (special != null && special.isNotEmpty) ? special : null,
      // Keep the full source payload for downstream consumers
      additionalOptions: Map<String, dynamic>.from(map),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'selected_variants': selectedVariants,
      'selected_supplements': selectedSupplements,
      'special_instructions': specialInstructions,
      'additional_options': _makeJsonEncodable(additionalOptions),
    };
  }

  /// Recursively converts a value to JSON-encodable format
  static dynamic _makeJsonEncodable(dynamic value) {
    if (value == null) return null;

    if (value is String || value is num || value is bool) {
      return value;
    }

    if (value is Map) {
      // Convert Map to Map<String, dynamic> and recursively process values
      final result = <String, dynamic>{};
      value.forEach((key, val) {
        try {
          final stringKey = key.toString();
          result[stringKey] = _makeJsonEncodable(val);
        } catch (e) {
          // Skip entries that can't be converted
        }
      });
      return result;
    }

    if (value is List) {
      // Recursively process list items
      return value.map((item) {
        try {
          return _makeJsonEncodable(item);
        } catch (e) {
          return item.toString();
        }
      }).toList();
    }

    // For any other type, try to convert to string
    try {
      // Try to encode and decode to ensure it's JSON-encodable
      final encoded = jsonEncode(value);
      return jsonDecode(encoded);
    } catch (e) {
      // If that fails, convert to string
      return value.toString();
    }
  }

  // Add toMap method for backward compatibility
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{};
    if (selectedVariants.isNotEmpty) {
      map['variant'] = selectedVariants.first;
    }
    if (selectedSupplements.isNotEmpty) {
      map['supplements'] = selectedSupplements;
    }
    if (specialInstructions != null) {
      map['special_requests'] = specialInstructions;
    }
    if (additionalOptions != null) {
      map.addAll(additionalOptions!);
    }
    return map;
  }

  MenuItemCustomizations copyWith({
    List<String>? selectedVariants,
    List<String>? selectedSupplements,
    String? specialInstructions,
    Map<String, dynamic>? additionalOptions,
  }) {
    return MenuItemCustomizations(
      selectedVariants: selectedVariants ?? this.selectedVariants,
      selectedSupplements: selectedSupplements ?? this.selectedSupplements,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      additionalOptions: additionalOptions ?? this.additionalOptions,
    );
  }

  bool get hasCustomizations {
    return selectedVariants.isNotEmpty ||
        selectedSupplements.isNotEmpty ||
        specialInstructions != null ||
        additionalOptions != null;
  }

  String get customizationsSummary {
    final parts = <String>[];
    if (selectedVariants.isNotEmpty) {
      parts.add('Variants: ${selectedVariants.join(', ')}');
    }
    if (selectedSupplements.isNotEmpty) {
      parts.add('Supplements: ${selectedSupplements.join(', ')}');
    }
    if (specialInstructions != null && specialInstructions!.isNotEmpty) {
      parts.add('Instructions: $specialInstructions');
    }
    return parts.join(' | ');
  }

  // Add missing methods for compatibility
  bool get isEmpty =>
      selectedVariants.isEmpty &&
      selectedSupplements.isEmpty &&
      specialInstructions == null;
  bool get isNotEmpty => !isEmpty;

  // Add operator[] for backward compatibility
  dynamic operator [](String key) {
    switch (key) {
      case 'variant':
        return selectedVariants.isNotEmpty ? selectedVariants.first : null;
      case 'size':
        return additionalOptions?['size'];
      case 'supplements':
        return selectedSupplements;
      case 'drinks':
        return additionalOptions?['drinks'];
      case 'ingredient_preferences':
        return additionalOptions?['ingredient_preferences'];
      case 'drink_quantities':
        return additionalOptions?['drink_quantities'];
      case 'restaurant_id':
        return additionalOptions?['restaurant_id'];
      case 'special_requests':
        return specialInstructions;
      case 'additional_price':
        return additionalOptions?['additional_price'] ?? 0.0;
      default:
        return additionalOptions?[key];
    }
  }

  @override
  List<Object?> get props => [
        selectedVariants,
        selectedSupplements,
        specialInstructions,
        additionalOptions,
      ];

  @override
  String toString() {
    return 'MenuItemCustomizations(variants: ${selectedVariants.length}, supplements: ${selectedSupplements.length})';
  }
}
