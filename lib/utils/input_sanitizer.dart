import 'dart:io';

class InputSanitizer {
  /// Sanitize text input to prevent XSS attacks
  static String sanitizeText(String input) {
    return input
        .trim()
        .replaceAll(RegExp('<script.*?</script>', caseSensitive: false), '')
        .replaceAll(RegExp('[<>]'), '')
        .replaceAll(RegExp('javascript:'), '')
        .replaceAll(RegExp('data:'), '')
        .replaceAll(RegExp('vbscript:'), '');
  }

  /// Validate if file is a valid image
  static bool isValidImageFile(File file) {
    final extension = file.path.split('.').last.toLowerCase();
    return ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(extension);
  }

  /// Validate file size (max size in bytes)
  static bool isValidFileSize(File file, int maxSizeBytes) {
    return file.lengthSync() <= maxSizeBytes;
  }

  /// Sanitize phone number
  static String sanitizePhoneNumber(String phone) {
    return phone.replaceAll(RegExp(r'[^\d\+\-\(\)\s]'), '');
  }

  /// Validate phone number format
  static bool isValidPhoneNumber(String phone) {
    final sanitized = sanitizePhoneNumber(phone);
    return RegExp(r'^[\d\s\+\-\(\)]{10,15}$').hasMatch(sanitized);
  }

  /// Sanitize URL
  static String sanitizeUrl(String url) {
    return url
        .trim()
        .replaceAll(RegExp('javascript:'), '')
        .replaceAll(RegExp('data:'), '')
        .replaceAll(RegExp('vbscript:'), '');
  }

  /// Validate URL format
  static bool isValidUrl(String url) {
    final sanitized = sanitizeUrl(url);
    return RegExp(r'^https?:\/\/').hasMatch(sanitized);
  }

  /// Sanitize restaurant name
  static String sanitizeRestaurantName(String name) {
    return name
        .trim()
        .replaceAll(RegExp('[<>]'), '')
        .replaceAll(RegExp('<script.*?</script>', caseSensitive: false), '');
  }

  /// Validate restaurant name
  static bool isValidRestaurantName(String name) {
    final sanitized = sanitizeRestaurantName(name);
    return sanitized.isNotEmpty &&
        sanitized.length >= 2 &&
        sanitized.length <= 100;
  }

  /// Sanitize address
  static String sanitizeAddress(String address) {
    return address
        .trim()
        .replaceAll(RegExp('[<>]'), '')
        .replaceAll(RegExp('<script.*?</script>', caseSensitive: false), '');
  }

  /// Validate address
  static bool isValidAddress(String address) {
    final sanitized = sanitizeAddress(address);
    return sanitized.isNotEmpty && sanitized.length >= 10;
  }

  /// Sanitize description
  static String sanitizeDescription(String description) {
    return description
        .trim()
        .replaceAll(RegExp('[<>]'), '')
        .replaceAll(RegExp('<script.*?</script>', caseSensitive: false), '');
  }

  /// Validate description length
  static bool isValidDescription(String description) {
    final sanitized = sanitizeDescription(description);
    return sanitized.length <= 500; // Max 500 characters
  }
}
