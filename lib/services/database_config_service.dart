import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseConfigService {
  static final DatabaseConfigService _instance =
      DatabaseConfigService._internal();
  factory DatabaseConfigService() => _instance;
  DatabaseConfigService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Cache for configurations
  final Map<String, dynamic> _configCache = {};
  DateTime? _lastFetchTime;
  static const Duration _cacheExpiry = Duration(minutes: 5);

  /// Get a configuration value by key
  Future<dynamic> getConfig(String key) async {
    try {
      // Check cache first
      if (_configCache.containsKey(key) &&
          _lastFetchTime != null &&
          DateTime.now().difference(_lastFetchTime!) < _cacheExpiry) {
        return _configCache[key];
      }

      // Fetch from database
      final response = await _supabase
          .from('system_config')
          .select('config_value, config_type')
          .eq('config_key', key)
          .eq('is_active', true)
          .single();

      final value =
          _parseConfigValue(response['config_value'], response['config_type']);
      _configCache[key] = value;
      _lastFetchTime = DateTime.now();

      return value;
    } catch (e) {
      debugPrint('Error fetching config $key: $e');
      return _getDefaultValue(key);
    }
  }

  /// Set a configuration value
  Future<bool> setConfig(String key, dynamic value,
      {String? description, String? category}) async {
    try {
      final configType = _getConfigType(value);
      final configValue = _serializeConfigValue(value);

      await _supabase.from('system_config').upsert(
        {
          'config_key': key,
          'config_value': configValue,
          'config_type': configType,
          'category': category ?? 'general',
          'description': description,
          'updated_by': _supabase.auth.currentUser?.id,
          'updated_at': DateTime.now().toIso8601String(),
        },
        onConflict: 'config_key',
      );

      // Update cache
      _configCache[key] = value;
      _lastFetchTime = DateTime.now();

      return true;
    } catch (e) {
      debugPrint('Error setting config $key: $e');
      return false;
    }
  }

  /// Get all configurations by category
  Future<Map<String, dynamic>> getConfigsByCategory(String category) async {
    try {
      final response = await _supabase
          .from('system_config')
          .select('config_key, config_value, config_type')
          .eq('category', category)
          .eq('is_active', true);

      final Map<String, dynamic> configs = {};
      for (final row in response) {
        final key = row['config_key'] as String;
        final value =
            _parseConfigValue(row['config_value'], row['config_type']);
        configs[key] = value;
        _configCache[key] = value;
      }

      _lastFetchTime = DateTime.now();
      return configs;
    } catch (e) {
      debugPrint('Error fetching configs for category $category: $e');
      return {};
    }
  }

  /// Get all configurations
  Future<Map<String, dynamic>> getAllConfigs() async {
    try {
      final response = await _supabase
          .from('system_config')
          .select('config_key, config_value, config_type, category')
          .eq('is_active', true);

      final Map<String, dynamic> configs = {};
      for (final row in response) {
        final key = row['config_key'] as String;
        final value =
            _parseConfigValue(row['config_value'], row['config_type']);
        configs[key] = value;
        _configCache[key] = value;
      }

      _lastFetchTime = DateTime.now();
      return configs;
    } catch (e) {
      debugPrint('Error fetching all configs: $e');
      return {};
    }
  }

  /// Update multiple configurations
  Future<bool> updateConfigs(Map<String, dynamic> configs) async {
    // First check if table exists
    final tableExists = await isTableExists();
    if (!tableExists) {
      debugPrint(
          '❌ System config table does not exist. Please run database migration.');
      return false;
    }

    final List<Map<String, dynamic>> updates = [];

    for (final entry in configs.entries) {
      final key = entry.key;
      final value = entry.value;
      final configType = _getConfigType(value);
      final configValue = _serializeConfigValue(value);

      updates.add({
        'config_key': key,
        'config_value': configValue,
        'config_type': configType,
        'updated_by': _supabase.auth.currentUser?.id,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    try {
      await _supabase.from('system_config').upsert(
            updates,
            onConflict: 'config_key',
          );

      // Update cache
      _configCache.addAll(configs);
      _lastFetchTime = DateTime.now();

      debugPrint('✅ Successfully updated ${updates.length} configurations');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating configs: $e');
      debugPrint('❌ Error type: ${e.runtimeType}');
      if (e.toString().contains('relation') &&
          e.toString().contains('does not exist')) {
        debugPrint(
            '❌ Database table "system_config" does not exist. Please run the migration.');
      } else if (e.toString().contains('duplicate key')) {
        debugPrint('❌ Duplicate key error - trying individual updates...');
        // Try updating configs one by one
        for (final update in updates) {
          try {
            await _supabase.from('system_config').upsert(
              [update],
              onConflict: 'config_key',
            );
            debugPrint('✅ Updated config: ${update['config_key']}');
          } catch (e2) {
            debugPrint(
                '❌ Failed to update config ${update['config_key']}: $e2');
          }
        }
        return true; // Return true even if some updates fail
      }
      return false;
    }
  }

  /// Delete a configuration
  Future<bool> deleteConfig(String key) async {
    try {
      await _supabase.from('system_config').delete().eq('config_key', key);

      // Remove from cache
      _configCache.remove(key);

      return true;
    } catch (e) {
      debugPrint('Error deleting config $key: $e');
      return false;
    }
  }

  /// Clear cache
  void clearCache() {
    _configCache.clear();
    _lastFetchTime = null;
  }

  /// Force refresh from database
  Future<void> forceRefresh() async {
    clearCache();
    await getAllConfigs();
  }

  /// Parse configuration value based on type
  dynamic _parseConfigValue(dynamic value, String type) {
    switch (type) {
      case 'number':
        return value is num ? value : double.tryParse(value.toString()) ?? 0.0;
      case 'boolean':
        return value is bool ? value : value.toString().toLowerCase() == 'true';
      case 'object':
        return value is Map ? value : jsonDecode(value.toString());
      case 'array':
        return value is List ? value : jsonDecode(value.toString());
      default:
        return value.toString();
    }
  }

  /// Serialize configuration value for storage
  dynamic _serializeConfigValue(dynamic value) {
    if (value is Map || value is List) {
      return value;
    }
    return value;
  }

  /// Get configuration type from value
  String _getConfigType(dynamic value) {
    if (value is num) return 'number';
    if (value is bool) return 'boolean';
    if (value is Map) return 'object';
    if (value is List) return 'array';
    return 'string';
  }

  /// Get default value for a configuration key
  dynamic _getDefaultValue(String key) {
    final defaults = {
      'service_fee': 5.0,
      'delivery_fee_config': {
        'ranges': [
          {'maxDistance': 2.0, 'fee': 30.0},
          {'maxDistance': 5.0, 'fee': 50.0},
          {'maxDistance': 10.0, 'fee': 80.0}
        ],
        'extra_range_fee': 2.0,
      },
      'delivery_fee_ranges': [
        {'maxDistance': 2.0, 'fee': 30.0},
        {'maxDistance': 5.0, 'fee': 50.0},
        {'maxDistance': 10.0, 'fee': 80.0}
      ],
      'extra_range_fee': 2.0,
      'max_delivery_radius': 50,
      'max_restaurant_radius': 25,
      'order_timeout': 60,
      'max_retry_attempts': 3,
      'image_optimization': true,
      'lazy_loading': true,
      'max_image_size': 10,
      'cdn_enabled': false,
      'app_version': '1.0.0',
      'maintenance_mode': false,
      'debug_mode': false,
      'auto_approval': false,
      'push_notifications': true,
      'email_notifications': true,
      'sms_notifications': false,
      'session_timeout': false,
      'session_timeout_minutes': 30,
      'two_factor_auth': false,
      'ip_whitelist': [],
      'cache_enabled': true,
      'cache_expiry_hours': 24,
      'auto_clear_cache': true,
      'backup_enabled': true,
      'backup_frequency': 'daily',
      'backup_retention_days': 30,
      'audit_logging': true,
      'audit_retention_days': 90,
    };

    return defaults[key] ?? '';
  }

  /// Check if database table exists
  Future<bool> isTableExists() async {
    try {
      await _supabase.from('system_config').select('id').limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Initialize default configurations
  Future<bool> initializeDefaults() async {
    try {
      final defaults = {
        'service_fee': 5.0,
        'delivery_fee_config': {
          'ranges': [
            {'maxDistance': 2.0, 'fee': 30.0},
            {'maxDistance': 5.0, 'fee': 50.0},
            {'maxDistance': 10.0, 'fee': 80.0}
          ],
          'extra_range_fee': 2.0,
        },
        'max_delivery_radius': 50,
        'max_restaurant_radius': 25,
        'order_timeout': 60,
        'max_retry_attempts': 3,
        'image_optimization': true,
        'lazy_loading': true,
        'max_image_size': 10,
        'cdn_enabled': false,
      };

      return await updateConfigs(defaults);
    } catch (e) {
      debugPrint('Error initializing defaults: $e');
      return false;
    }
  }
}
