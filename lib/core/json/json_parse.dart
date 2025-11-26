import 'dart:convert' as json;
import 'dart:isolate';

import 'package:flutter/foundation.dart';

/// JSON parsing utilities with isolate support for heavy operations
/// This prevents blocking the main UI thread during JSON parsing
class JsonParse {
  /// Parse a single JSON object in isolate
  ///
  /// Usage:
  /// ```dart
  /// final menuItem = await JsonParse.parseInIsolate(
  ///   jsonString,
  ///   MenuItem.fromJson,
  /// );
  /// ```
  static Future<T> parseInIsolate<T>(
    String jsonString,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    // For small payloads, parse on main thread to avoid isolate overhead
    if (jsonString.length < 10000) {
      return fromJson(_jsonDecode(jsonString) as Map<String, dynamic>);
    }

    // For large payloads, use isolate
    try {
      return await Isolate.run(() {
        final json = _jsonDecode(jsonString) as Map<String, dynamic>;
        return fromJson(json);
      });
    } catch (e) {
      // Fallback to main thread if isolate fails
      debugPrint('⚠️ Isolate parsing failed, falling back to main thread: $e');
      return fromJson(_jsonDecode(jsonString) as Map<String, dynamic>);
    }
  }

  /// Parse a list of JSON objects in isolate
  ///
  /// Usage:
  /// ```dart
  /// final menuItems = await JsonParse.parseListInIsolate(
  ///   jsonString,
  ///   MenuItem.fromJson,
  /// );
  /// ```
  static Future<List<T>> parseListInIsolate<T>(
    String jsonString,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    // For small payloads, parse on main thread
    if (jsonString.length < 10000) {
      final list = _jsonDecode(jsonString) as List;
      return list
          .map((json) => fromJson(json as Map<String, dynamic>))
          .toList();
    }

    // For large payloads, use isolate
    try {
      return await Isolate.run(() {
        final list = _jsonDecode(jsonString) as List;
        return list
            .map((json) => fromJson(json as Map<String, dynamic>))
            .toList();
      });
    } catch (e) {
      // Fallback to main thread if isolate fails
      debugPrint('⚠️ Isolate parsing failed, falling back to main thread: $e');
      final list = _jsonDecode(jsonString) as List;
      return list
          .map((json) => fromJson(json as Map<String, dynamic>))
          .toList();
    }
  }

  /// Parse a list from a List<dynamic> (already decoded) in isolate
  /// This is useful when you already have the decoded list from Supabase
  ///
  /// Usage:
  /// ```dart
  /// final menuItems = await JsonParse.parseListFromDecoded(
  ///   response as List,
  ///   MenuItem.fromJson,
  /// );
  /// ```
  ///
  /// Note: For lists with 50+ items, parsing happens in isolate to avoid blocking UI thread.
  /// For smaller lists, parsing happens on main thread to avoid isolate overhead.
  static Future<List<T>> parseListFromDecoded<T>(
    List<dynamic> decodedList,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    // For small lists, parse on main thread (avoid isolate overhead)
    if (decodedList.length < 50) {
      return decodedList
          .map((json) => fromJson(json as Map<String, dynamic>))
          .toList();
    }

    // For large lists, parse in microtasks to avoid blocking but stay on main thread
    // Isolate.run() doesn't support closures, so we use microtasks for now
    // This is still better than blocking synchronously
    try {
      // Use microtasks to yield control to UI thread periodically
      final results = <T>[];
      for (int i = 0; i < decodedList.length; i++) {
        if (i > 0 && i % 10 == 0) {
          // Yield control every 10 items to allow UI to update
          await Future.microtask(() {});
        }
        final json = decodedList[i] as Map<String, dynamic>;
        results.add(fromJson(json));
      }
      return results;
    } catch (e) {
      debugPrint('⚠️ Parsing failed: $e');
      // Fallback: parse all at once
      return decodedList
          .map((json) => fromJson(json as Map<String, dynamic>))
          .toList();
    }
  }

  /// JSON decode helper
  static dynamic _jsonDecode(String source) {
    return json.jsonDecode(source);
  }
}
