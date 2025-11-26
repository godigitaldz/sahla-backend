import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';

/// Disk cache using Hive for persistent storage
class DiskCache<K, V> {
  static const String _boxName = 'app_cache';
  static Box? _box;

  final Duration _defaultTtl;

  DiskCache({Duration? defaultTtl})
      : _defaultTtl = defaultTtl ?? const Duration(hours: 24);

  /// Initialize Hive box
  static Future<void> initialize() async {
    await Hive.initFlutter();
    _box = await Hive.openBox(_boxName);
  }

  /// Get value from disk cache
  Future<V?> get(K key, V Function(Map<String, dynamic>) fromJson) async {
    if (_box == null) return null;

    try {
      final encoded = _box!.get(_keyToString(key));
      if (encoded == null) return null;

      final data = jsonDecode(encoded as String) as Map<String, dynamic>;
      final entry = _CacheEntry.fromJson(data);

      // Check expiry
      if (entry.isExpired) {
        await _box!.delete(_keyToString(key));
        return null;
      }

      return fromJson(entry.data);
    } catch (e) {
      return null;
    }
  }

  /// Put value in disk cache
  Future<void> put(K key, V value, Map<String, dynamic> Function(V) toJson,
      {Duration? ttl}) async {
    if (_box == null) return;

    try {
      final entry = _CacheEntry(
        data: toJson(value),
        expiresAt: DateTime.now().add(ttl ?? _defaultTtl),
      );

      await _box!.put(_keyToString(key), jsonEncode(entry.toJson()));
    } catch (e) {
      // Ignore disk write errors
    }
  }

  /// Remove value from disk cache
  Future<void> remove(K key) async {
    if (_box == null) return;
    await _box!.delete(_keyToString(key));
  }

  /// Clear all entries
  Future<void> clear() async {
    if (_box == null) return;
    await _box!.clear();
  }

  /// Check if key exists and is not expired
  Future<bool> containsKey(K key) async {
    if (_box == null) return false;

    try {
      final encoded = _box!.get(_keyToString(key));
      if (encoded == null) return false;

      final data = jsonDecode(encoded as String) as Map<String, dynamic>;
      final entry = _CacheEntry.fromJson(data);

      if (entry.isExpired) {
        await _box!.delete(_keyToString(key));
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Get cache statistics
  Future<Map<String, dynamic>> getStats() async {
    if (_box == null) return {'size': 0};

    int expiredCount = 0;
    int validCount = 0;

    for (final key in _box!.keys) {
      try {
        final encoded = _box!.get(key);
        if (encoded == null) continue;

        final data = jsonDecode(encoded as String) as Map<String, dynamic>;
        final entry = _CacheEntry.fromJson(data);

        if (entry.isExpired) {
          expiredCount++;
        } else {
          validCount++;
        }
      } catch (e) {
        // Invalid entry
        expiredCount++;
      }
    }

    return {
      'size': _box!.length,
      'valid_count': validCount,
      'expired_count': expiredCount,
    };
  }

  String _keyToString(K key) => key.toString();
}

/// Cache entry with expiry
class _CacheEntry {
  final Map<String, dynamic> data;
  final DateTime expiresAt;

  _CacheEntry({
    required this.data,
    required this.expiresAt,
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  Map<String, dynamic> toJson() => {
        'data': data,
        'expires_at': expiresAt.toIso8601String(),
      };

  factory _CacheEntry.fromJson(Map<String, dynamic> json) => _CacheEntry(
        data: json['data'] as Map<String, dynamic>,
        expiresAt: DateTime.parse(json['expires_at'] as String),
      );
}
