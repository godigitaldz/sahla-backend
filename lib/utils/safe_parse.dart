/// Safe parsing utilities for JSON data
///
/// These utilities provide type-safe parsing with proper null handling,
/// default values, and error recovery. Use them consistently across all
/// model fromJson implementations to prevent runtime crashes.
library;

/// Safely parse an integer from JSON
///
/// Handles:
/// - null values (returns default or null)
/// - String representations of numbers
/// - Double values (truncates to int)
/// - Invalid data (returns default or null)
int? safeInt(dynamic value, {int? defaultValue}) {
  if (value == null) return defaultValue;

  if (value is int) return value;

  if (value is double) return value.toInt();

  if (value is String) {
    final parsed = int.tryParse(value);
    if (parsed != null) return parsed;

    // Try parsing as double first, then convert to int
    final doubleParsed = double.tryParse(value);
    if (doubleParsed != null) return doubleParsed.toInt();
  }

  return defaultValue;
}

/// Safely parse an integer with required value (throws on null/invalid)
///
/// Use this when the field is required in your domain model.
int safeIntRequired(dynamic value, {String fieldName = 'field'}) {
  final parsed = safeInt(value);
  if (parsed == null) {
    throw FormatException(
        'Required integer field "$fieldName" is null or invalid: $value');
  }
  return parsed;
}

/// Safely parse a double from JSON
///
/// Handles:
/// - null values (returns default or null)
/// - String representations of numbers
/// - Integer values (converts to double)
/// - Invalid data (returns default or null)
/// - NaN values (returns default or null)
double? safeDouble(dynamic value, {double? defaultValue}) {
  if (value == null) return defaultValue;

  if (value is double) {
    // Check for NaN or infinity
    if (value.isNaN || value.isInfinite) return defaultValue;
    return value;
  }

  if (value is int) return value.toDouble();

  if (value is String) {
    final parsed = double.tryParse(value);
    if (parsed == null) return defaultValue;

    // Check for NaN or infinity
    if (parsed.isNaN || parsed.isInfinite) return defaultValue;
    return parsed;
  }

  return defaultValue;
}

/// Safely parse a double with required value (throws on null/invalid)
///
/// Use this when the field is required in your domain model.
double safeDoubleRequired(dynamic value, {String fieldName = 'field'}) {
  final parsed = safeDouble(value);
  if (parsed == null) {
    throw FormatException(
        'Required double field "$fieldName" is null or invalid: $value');
  }
  return parsed;
}

/// Safely parse a boolean from JSON
///
/// Handles:
/// - null values (returns default or null)
/// - String representations ("true", "false", "1", "0", "yes", "no")
/// - Integer values (0 = false, non-zero = true)
/// - Invalid data (returns default or null)
bool? safeBool(dynamic value, {bool? defaultValue}) {
  if (value == null) return defaultValue;

  if (value is bool) return value;

  if (value is int) return value != 0;

  if (value is String) {
    final lower = value.toLowerCase().trim();
    if (lower == 'true' || lower == '1' || lower == 'yes') return true;
    if (lower == 'false' || lower == '0' || lower == 'no') return false;
  }

  return defaultValue;
}

/// Safely parse a boolean with required value (throws on null/invalid)
///
/// Use this when the field is required in your domain model.
bool safeBoolRequired(dynamic value,
    {String fieldName = 'field', bool defaultValue = false}) {
  final parsed = safeBool(value, defaultValue: defaultValue);
  if (parsed == null) {
    throw FormatException(
        'Required boolean field "$fieldName" is null or invalid: $value');
  }
  return parsed;
}

/// Safely parse a DateTime from JSON, normalized to UTC
///
/// Handles:
/// - null values (returns null)
/// - ISO 8601 string formats
/// - Unix timestamp (seconds or milliseconds)
/// - Invalid data (returns null or throws)
///
/// All dates are normalized to UTC internally. Use toLocal() at the UI boundary.
DateTime? safeUtc(dynamic value, {DateTime? defaultValue}) {
  if (value == null) return defaultValue;

  if (value is DateTime) {
    // Already a DateTime, ensure it's UTC
    return value.isUtc ? value : value.toUtc();
  }

  if (value is String) {
    try {
      // Try parsing as ISO 8601
      final parsed = DateTime.parse(value);
      // Normalize to UTC
      return parsed.isUtc ? parsed : parsed.toUtc();
    } catch (e) {
      // If string parsing fails, try as timestamp
      final timestamp = int.tryParse(value);
      if (timestamp != null) {
        return _parseTimestamp(timestamp);
      }
      return defaultValue;
    }
  }

  if (value is int) {
    return _parseTimestamp(value);
  }

  return defaultValue;
}

/// Safely parse a DateTime with required value (throws on null/invalid)
///
/// Use this when the field is required in your domain model.
DateTime safeUtcRequired(dynamic value, {String fieldName = 'field'}) {
  final parsed = safeUtc(value);
  if (parsed == null) {
    throw FormatException(
        'Required DateTime field "$fieldName" is null or invalid: $value');
  }
  return parsed;
}

/// Parse a timestamp (seconds or milliseconds) to UTC DateTime
DateTime? _parseTimestamp(int timestamp) {
  try {
    // Determine if timestamp is in seconds or milliseconds
    // Unix timestamps after year 2001 are typically > 1,000,000,000 seconds
    if (timestamp > 1000000000 && timestamp < 2147483647) {
      // Likely seconds
      return DateTime.fromMillisecondsSinceEpoch(timestamp * 1000, isUtc: true);
    } else {
      // Likely milliseconds
      return DateTime.fromMillisecondsSinceEpoch(timestamp, isUtc: true);
    }
  } catch (e) {
    return null;
  }
}

/// Safely parse a string from JSON
///
/// Handles:
/// - null values (returns default or null)
/// - Non-string types (converts to string)
/// - Empty strings (returns default or empty string)
String? safeString(dynamic value,
    {String? defaultValue, bool allowEmpty = true}) {
  if (value == null) return defaultValue;

  if (value is String) {
    return (allowEmpty || value.isNotEmpty) ? value : defaultValue;
  }

  // Convert other types to string
  final stringValue = value.toString();
  return (allowEmpty || stringValue.isNotEmpty) ? stringValue : defaultValue;
}

/// Safely parse a string with required value (throws on null/empty)
///
/// Use this when the field is required in your domain model.
String safeStringRequired(dynamic value, {String fieldName = 'field'}) {
  final parsed = safeString(value, allowEmpty: false);
  if (parsed == null || parsed.isEmpty) {
    throw FormatException(
        'Required string field "$fieldName" is null or empty: $value');
  }
  return parsed;
}

/// Safely parse a list from JSON
///
/// Handles:
/// - null values (returns empty list or null)
/// - Non-list types (returns empty list or null)
/// - List with mixed types (applies converter if provided)
List<T> safeList<T>(dynamic value,
    {List<T> defaultValue = const [], T? Function(dynamic)? converter}) {
  if (value == null) return defaultValue;

  if (value is! List) return defaultValue;

  try {
    if (converter != null) {
      return value.map((item) => converter(item)).whereType<T>().toList();
    }

    // Try to cast directly
    return value.cast<T>();
  } catch (e) {
    return defaultValue;
  }
}

/// Safely parse a map from JSON
///
/// Handles:
/// - null values (returns empty map or null)
/// - Non-map types (returns empty map or null)
Map<String, dynamic> safeMap(dynamic value,
    {Map<String, dynamic> defaultValue = const {}}) {
  if (value == null) return defaultValue;

  if (value is Map) {
    try {
      return Map<String, dynamic>.from(value);
    } catch (e) {
      return defaultValue;
    }
  }

  return defaultValue;
}

/// Safely get a value from a map with type checking
///
/// Returns null if key doesn't exist or type doesn't match
T? safeGet<T>(Map<String, dynamic>? map, String key) {
  if (map == null) return null;

  final value = map[key];
  if (value == null) return null;

  if (value is T) return value;

  return null;
}

/// Compare two doubles with a tolerance
///
/// Use this instead of direct equality for double comparisons
/// to avoid floating-point precision issues.
bool doubleEquals(double a, double b, {double tolerance = 1e-10}) {
  return (a - b).abs() < tolerance;
}

/// Compare two nullable doubles with a tolerance
bool doubleEqualsNullable(double? a, double? b, {double tolerance = 1e-10}) {
  if (a == null && b == null) return true;
  if (a == null || b == null) return false;
  return doubleEquals(a, b, tolerance: tolerance);
}
