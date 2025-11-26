import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'database_config_service.dart';
import 'service_fee_service.dart';

/// Delivery fee range configuration
class DeliveryFeeRange {
  final double maxDistance; // in km
  final double fee; // in DA

  DeliveryFeeRange({
    required this.maxDistance,
    required this.fee,
  });

  Map<String, dynamic> toJson() => {
        'maxDistance': maxDistance,
        'fee': fee,
      };

  factory DeliveryFeeRange.fromJson(Map<String, dynamic> json) =>
      DeliveryFeeRange(
        maxDistance: json['maxDistance']?.toDouble() ?? 0.0,
        fee: json['fee']?.toDouble() ?? 0.0,
      );
}

/// System configuration service that manages global system settings
/// and integrates with existing fee services
class SystemConfigService extends ChangeNotifier {
  static final SystemConfigService _instance = SystemConfigService._internal();
  factory SystemConfigService() => _instance;
  SystemConfigService._internal();

  SupabaseClient get client => Supabase.instance.client;
  final ServiceFeeService _serviceFeeService = ServiceFeeService();
  final DatabaseConfigService _dbConfigService = DatabaseConfigService();

  // System Configuration
  int _maxDeliveryRadius = 50;
  int _maxRestaurantRadius = 30;
  double _serviceFee = 0.50;
  int _orderTimeout = 30;
  int _maxRetryAttempts = 3;

  // Distance-based Delivery Fee Configuration
  List<DeliveryFeeRange> _deliveryFeeRanges = [
    DeliveryFeeRange(maxDistance: 2.0, fee: 30.0), // 0-2km = 30 DA
    DeliveryFeeRange(maxDistance: 5.0, fee: 50.0), // 2-5km = 50 DA
    DeliveryFeeRange(maxDistance: 10.0, fee: 80.0), // 5-10km = 80 DA
  ];
  double _extraRangeFee = 5.0; // 5 DA for every extra 100m beyond ranges

  // Cache Settings
  bool _cacheEnabled = true;
  int _cacheExpiryHours = 24;
  bool _autoClearCache = true;

  // Security Settings
  bool _sessionTimeout = true;
  int _sessionTimeoutMinutes = 60;

  // Performance Settings
  bool _imageOptimization = true;
  bool _lazyLoading = true;
  int _maxImageSize = 5; // MB
  bool _cdnEnabled = false;

  // Getters
  int get maxDeliveryRadius => _maxDeliveryRadius;
  int get maxRestaurantRadius => _maxRestaurantRadius;
  double get serviceFee => _serviceFee;
  int get orderTimeout => _orderTimeout;
  int get maxRetryAttempts => _maxRetryAttempts;
  List<DeliveryFeeRange> get deliveryFeeRanges =>
      List.unmodifiable(_deliveryFeeRanges);
  double get extraRangeFee => _extraRangeFee;
  bool get cacheEnabled => _cacheEnabled;
  int get cacheExpiryHours => _cacheExpiryHours;
  bool get autoClearCache => _autoClearCache;
  bool get sessionTimeout => _sessionTimeout;
  int get sessionTimeoutMinutes => _sessionTimeoutMinutes;
  bool get imageOptimization => _imageOptimization;
  bool get lazyLoading => _lazyLoading;
  int get maxImageSize => _maxImageSize;
  bool get cdnEnabled => _cdnEnabled;

  // Initialize the service
  Future<void> initialize() async {
    // First try to load from database
    try {
      final dbAvailable = await isDatabaseAvailable();
      if (dbAvailable) {
        await loadFromDatabase();
        debugPrint('🚀 SystemConfigService initialized from database');
        return;
      }
    } catch (e) {
      debugPrint('⚠️ Failed to load from database: $e');
    }

    // Fallback to local settings
    await _loadSettings();
    debugPrint('🚀 SystemConfigService initialized from local settings');
  }

  // Load settings from SharedPreferences
  Future<void> _loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load system configuration
      _maxDeliveryRadius = prefs.getInt('max_delivery_radius') ?? 50;
      _maxRestaurantRadius = prefs.getInt('max_restaurant_radius') ?? 30;
      _serviceFee = prefs.getDouble('service_fee') ?? 0.50;
      _orderTimeout = prefs.getInt('order_timeout') ?? 30;
      _maxRetryAttempts = prefs.getInt('max_retry_attempts') ?? 3;

      // Load distance-based delivery fee configuration
      final deliveryFeeRangesJson = prefs.getString('delivery_fee_ranges');
      if (deliveryFeeRangesJson != null) {
        final List<dynamic> rangesList = jsonDecode(deliveryFeeRangesJson);
        _deliveryFeeRanges = rangesList
            .map((range) =>
                DeliveryFeeRange.fromJson(range as Map<String, dynamic>))
            .toList();
      }
      _extraRangeFee = prefs.getDouble('extra_range_fee') ?? 5.0;

      // Load cache settings
      _cacheEnabled = prefs.getBool('cache_enabled') ?? true;
      _cacheExpiryHours = prefs.getInt('cache_expiry_hours') ?? 24;
      _autoClearCache = prefs.getBool('auto_clear_cache') ?? true;

      // Load security settings
      _sessionTimeout = prefs.getBool('session_timeout') ?? true;
      _sessionTimeoutMinutes = prefs.getInt('session_timeout_minutes') ?? 60;

      // Load performance settings
      _imageOptimization = prefs.getBool('image_optimization') ?? true;
      _lazyLoading = prefs.getBool('lazy_loading') ?? true;
      _maxImageSize = prefs.getInt('max_image_size') ?? 5;
      _cdnEnabled = prefs.getBool('cdn_enabled') ?? false;

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading system settings: $e');
    }
  }

  // Save settings to SharedPreferences
  Future<void> _saveSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Save system configuration
      await prefs.setInt('max_delivery_radius', _maxDeliveryRadius);
      await prefs.setInt('max_restaurant_radius', _maxRestaurantRadius);
      await prefs.setDouble('service_fee', _serviceFee);
      await prefs.setInt('order_timeout', _orderTimeout);
      await prefs.setInt('max_retry_attempts', _maxRetryAttempts);

      // Save distance-based delivery fee configuration
      final deliveryFeeRangesJson = jsonEncode(
          _deliveryFeeRanges.map((range) => range.toJson()).toList());
      await prefs.setString('delivery_fee_ranges', deliveryFeeRangesJson);
      await prefs.setDouble('extra_range_fee', _extraRangeFee);

      // Save cache settings
      await prefs.setBool('cache_enabled', _cacheEnabled);
      await prefs.setInt('cache_expiry_hours', _cacheExpiryHours);
      await prefs.setBool('auto_clear_cache', _autoClearCache);

      // Save security settings
      await prefs.setBool('session_timeout', _sessionTimeout);
      await prefs.setInt('session_timeout_minutes', _sessionTimeoutMinutes);

      // Save performance settings
      await prefs.setBool('image_optimization', _imageOptimization);
      await prefs.setBool('lazy_loading', _lazyLoading);
      await prefs.setInt('max_image_size', _maxImageSize);
      await prefs.setBool('cdn_enabled', _cdnEnabled);

      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error saving system settings: $e');
    }
  }

  // Calculate delivery fee based on distance
  // Calculates fee for any distance, no matter how large
  double calculateDeliveryFee(double distanceKm) {
    // Only validate that distance is positive
    if (distanceKm <= 0) {
      debugPrint(
          '⚠️ Invalid distance for delivery fee calculation: $distanceKm km (must be > 0)');
      return 0.0;
    }

    // If no ranges configured, return 0.0
    if (_deliveryFeeRanges.isEmpty) {
      debugPrint('⚠️ No delivery fee ranges configured');
      return 0.0;
    }

    // Sort ranges by maxDistance to ensure proper order
    final sortedRanges = List<DeliveryFeeRange>.from(_deliveryFeeRanges)
      ..sort((a, b) => a.maxDistance.compareTo(b.maxDistance));

    // Find the appropriate range for the distance
    for (final range in sortedRanges) {
      if (distanceKm <= range.maxDistance) {
        debugPrint(
            '💰 Delivery fee for ${distanceKm.toStringAsFixed(2)} km: ${range.fee} DA (range: 0-${range.maxDistance} km)');
        return range.fee;
      }
    }

    // If distance exceeds all ranges, calculate extra fee
    final lastRange = sortedRanges.last;
    final extraDistance = distanceKm - lastRange.maxDistance;
    final extraFee = (extraDistance * 10) *
        _extraRangeFee; // 10 * 100m = 1km, so multiply by 10
    final totalFee = lastRange.fee + extraFee;

    debugPrint(
        '💰 Delivery fee for ${distanceKm.toStringAsFixed(2)} km: $totalFee DA (base: ${lastRange.fee} DA + extra: $extraFee DA for ${extraDistance.toStringAsFixed(2)} km beyond ${lastRange.maxDistance} km)');
    return totalFee;
  }

  // Update delivery fee ranges
  Future<void> updateDeliveryFeeRanges(List<DeliveryFeeRange> newRanges) async {
    _deliveryFeeRanges = newRanges;
    await _saveSettings();
    debugPrint('✅ Delivery fee ranges updated');
  }

  // Update extra range fee
  Future<void> updateExtraRangeFee(double newFee) async {
    _extraRangeFee = newFee;
    await _saveSettings();
    debugPrint('✅ Extra range fee updated to: $newFee DA per 100m');
  }

  // Update service fee and sync with service fee service
  Future<bool> updateServiceFee(double newFee, String adminId) async {
    try {
      _serviceFee = newFee;
      await _saveSettings();

      // Persist immediately to database (best-effort)
      try {
        final persisted = await _dbConfigService.setConfig(
          'service_fee',
          newFee,
          description: 'Platform service fee in DA',
          category: 'fees',
        );
        if (!persisted) {
          debugPrint(
              '⚠️ Service fee saved locally but database update deferred');
        } else {
          debugPrint('✅ Service fee updated in database: $newFee');
        }
      } catch (e) {
        debugPrint('⚠️ Non-blocking DB error while updating service fee: $e');
      }

      // Update service fee service with new service fee configuration
      await _serviceFeeService.updateServiceFeeConfig(
        adminId: adminId,
        customerServiceFee: newFee,
      );

      debugPrint('✅ Service fee updated to: $newFee DA');
      return true;
    } catch (e) {
      debugPrint('❌ Error updating service fee: $e');
      return false;
    }
  }

  // Update max delivery radius
  Future<void> updateMaxDeliveryRadius(int newRadius) async {
    _maxDeliveryRadius = newRadius;
    await _saveSettings();
    debugPrint('✅ Max delivery radius updated to: $newRadius km');
  }

  // Update max restaurant radius
  Future<void> updateMaxRestaurantRadius(int newRadius) async {
    _maxRestaurantRadius = newRadius;
    await _saveSettings();
    debugPrint('✅ Max restaurant radius updated to: $newRadius km');
  }

  // Update order timeout
  Future<void> updateOrderTimeout(int newTimeout) async {
    _orderTimeout = newTimeout;
    await _saveSettings();
    debugPrint('✅ Order timeout updated to: $newTimeout minutes');
  }

  // Update max retry attempts
  Future<void> updateMaxRetryAttempts(int newAttempts) async {
    _maxRetryAttempts = newAttempts;
    await _saveSettings();
    debugPrint('✅ Max retry attempts updated to: $newAttempts');
  }

  // Update cache settings
  Future<void> updateCacheSettings({
    bool? enabled,
    int? expiryHours,
    bool? autoClear,
  }) async {
    if (enabled != null) _cacheEnabled = enabled;
    if (expiryHours != null) _cacheExpiryHours = expiryHours;
    if (autoClear != null) _autoClearCache = autoClear;

    await _saveSettings();
    debugPrint('✅ Cache settings updated');
  }

  // Update security settings
  Future<void> updateSecuritySettings({
    bool? sessionTimeout,
    int? timeoutMinutes,
  }) async {
    if (sessionTimeout != null) _sessionTimeout = sessionTimeout;
    if (timeoutMinutes != null) _sessionTimeoutMinutes = timeoutMinutes;

    await _saveSettings();
    debugPrint('✅ Security settings updated');
  }

  // Update performance settings
  Future<void> updatePerformanceSettings({
    bool? imageOptimization,
    bool? lazyLoading,
    int? maxImageSize,
    bool? cdnEnabled,
  }) async {
    if (imageOptimization != null) _imageOptimization = imageOptimization;
    if (lazyLoading != null) _lazyLoading = lazyLoading;
    if (maxImageSize != null) _maxImageSize = maxImageSize;
    if (cdnEnabled != null) _cdnEnabled = cdnEnabled;

    await _saveSettings();
    debugPrint('✅ Performance settings updated');
  }

  // Get current fee configuration for display
  Map<String, dynamic> getFeeConfiguration() {
    return {
      'service_fee': _serviceFee,
      'service_fee_formatted': '${_serviceFee.toStringAsFixed(2)} DA',
      'delivery_fee_ranges':
          _deliveryFeeRanges.map((range) => range.toJson()).toList(),
      'extra_range_fee': _extraRangeFee,
    };
  }

  // Get system configuration summary
  Map<String, dynamic> getSystemConfiguration() {
    return {
      'max_delivery_radius': _maxDeliveryRadius,
      'max_restaurant_radius': _maxRestaurantRadius,
      'service_fee': _serviceFee,
      'delivery_fee_ranges':
          _deliveryFeeRanges.map((range) => range.toJson()).toList(),
      'extra_range_fee': _extraRangeFee,
      'order_timeout': _orderTimeout,
      'max_retry_attempts': _maxRetryAttempts,
      'cache_enabled': _cacheEnabled,
      'cache_expiry_hours': _cacheExpiryHours,
      'auto_clear_cache': _autoClearCache,
      'session_timeout': _sessionTimeout,
      'session_timeout_minutes': _sessionTimeoutMinutes,
      'image_optimization': _imageOptimization,
      'lazy_loading': _lazyLoading,
      'max_image_size': _maxImageSize,
      'cdn_enabled': _cdnEnabled,
    };
  }

  // Reset all settings to defaults
  Future<void> resetToDefaults() async {
    _maxDeliveryRadius = 50;
    _maxRestaurantRadius = 30;
    _serviceFee = 0.50;
    _orderTimeout = 30;
    _maxRetryAttempts = 3;
    _deliveryFeeRanges = [
      DeliveryFeeRange(maxDistance: 2.0, fee: 30.0),
      DeliveryFeeRange(maxDistance: 5.0, fee: 50.0),
      DeliveryFeeRange(maxDistance: 10.0, fee: 80.0),
    ];
    _extraRangeFee = 5.0;
    _cacheEnabled = true;
    _cacheExpiryHours = 24;
    _autoClearCache = true;
    _sessionTimeout = true;
    _sessionTimeoutMinutes = 60;
    _imageOptimization = true;
    _lazyLoading = true;
    _maxImageSize = 5;
    _cdnEnabled = false;

    await _saveSettings();
    debugPrint('✅ System settings reset to defaults');
  }

  // Validate fee configuration
  bool validateFeeConfiguration() {
    return _serviceFee > 0 &&
        _serviceFee <= 100 &&
        _deliveryFeeRanges.isNotEmpty &&
        _deliveryFeeRanges
            .every((range) => range.fee > 0 && range.maxDistance > 0) &&
        _extraRangeFee > 0;
  }

  // Get fee breakdown for orders with distance-based delivery fee
  Map<String, dynamic> calculateOrderFees({
    required double subtotal,
    required double taxAmount,
    required double distanceKm,
  }) {
    final deliveryFee = calculateDeliveryFee(distanceKm);
    final totalWithoutFees = subtotal + taxAmount;
    final customerTotal = totalWithoutFees + deliveryFee + _serviceFee;

    return {
      'subtotal': subtotal,
      'tax_amount': taxAmount,
      'delivery_fee': deliveryFee,
      'service_fee': _serviceFee,
      'customer_total': customerTotal,
      'platform_revenue': deliveryFee + _serviceFee,
      'distance_km': distanceKm,
      'breakdown': {
        'subtotal': subtotal,
        'tax': taxAmount,
        'delivery': deliveryFee,
        'service': _serviceFee,
        'total': customerTotal,
        'distance': distanceKm,
      },
    };
  }

  // Database Integration Methods

  /// Load all configurations from database
  Future<void> loadFromDatabase() async {
    try {
      // Check if database table exists
      final tableExists = await _dbConfigService.isTableExists();
      if (!tableExists) {
        debugPrint(
            '⚠️ System config table does not exist. Using local settings.');
        return;
      }

      // Load configurations by category
      final feeConfigs = await _dbConfigService.getConfigsByCategory('fees');
      final systemConfigs =
          await _dbConfigService.getConfigsByCategory('system');
      final performanceConfigs =
          await _dbConfigService.getConfigsByCategory('performance');

      // Update fee configurations
      if (feeConfigs['service_fee'] != null) {
        _serviceFee = (feeConfigs['service_fee'] as num).toDouble();
      }
      // Prefer unified object in one row if present
      if (feeConfigs['delivery_fee_config'] != null &&
          feeConfigs['delivery_fee_config'] is Map) {
        final cfg = feeConfigs['delivery_fee_config'] as Map;
        final ranges = (cfg['ranges'] as List? ?? const [])
            .map((r) =>
                DeliveryFeeRange.fromJson((r as Map).cast<String, dynamic>()))
            .toList();
        if (ranges.isNotEmpty) {
          _deliveryFeeRanges = ranges;
        }
        final extra = cfg['extra_range_fee'];
        if (extra is num) {
          _extraRangeFee = extra.toDouble();
        }
      } else {
        // Backward compatibility with legacy, separate rows
        if (feeConfigs['delivery_fee_ranges'] != null) {
          final ranges = (feeConfigs['delivery_fee_ranges'] as List)
              .map((r) => DeliveryFeeRange.fromJson(r as Map<String, dynamic>))
              .toList();
          _deliveryFeeRanges = ranges;
        }
        if (feeConfigs['extra_range_fee'] != null) {
          _extraRangeFee = (feeConfigs['extra_range_fee'] as num).toDouble();
        }
      }

      // Update system configurations
      if (systemConfigs['max_delivery_radius'] != null) {
        _maxDeliveryRadius =
            (systemConfigs['max_delivery_radius'] as num).toInt();
      }
      if (systemConfigs['max_restaurant_radius'] != null) {
        _maxRestaurantRadius =
            (systemConfigs['max_restaurant_radius'] as num).toInt();
      }
      if (systemConfigs['order_timeout'] != null) {
        _orderTimeout = (systemConfigs['order_timeout'] as num).toInt();
      }
      if (systemConfigs['max_retry_attempts'] != null) {
        _maxRetryAttempts =
            (systemConfigs['max_retry_attempts'] as num).toInt();
      }

      // Update performance configurations
      if (performanceConfigs['image_optimization'] != null) {
        _imageOptimization = performanceConfigs['image_optimization'] as bool;
      }
      if (performanceConfigs['lazy_loading'] != null) {
        _lazyLoading = performanceConfigs['lazy_loading'] as bool;
      }
      if (performanceConfigs['max_image_size'] != null) {
        _maxImageSize = (performanceConfigs['max_image_size'] as num).toInt();
      }
      if (performanceConfigs['cdn_enabled'] != null) {
        _cdnEnabled = performanceConfigs['cdn_enabled'] as bool;
      }

      // Update service fee in ServiceFeeService
      final currentUser = client.auth.currentUser;
      if (currentUser != null) {
        await _serviceFeeService.updateServiceFeeConfig(
          adminId: currentUser.id,
          customerServiceFee: _serviceFee,
          deliveryDeduction: _serviceFee * 0.1, // 10% of service fee
          restaurantDeduction: _serviceFee * 0.05, // 5% of service fee
        );
      }

      debugPrint('✅ System configurations loaded from database');
      notifyListeners();
    } catch (e) {
      debugPrint('❌ Error loading configurations from database: $e');
    }
  }

  /// Save all configurations to database
  Future<bool> saveToDatabase() async {
    try {
      final configs = {
        'service_fee': _serviceFee,
        // Unified one-row delivery fee configuration
        'delivery_fee_config': {
          'ranges': _deliveryFeeRanges.map((r) => r.toJson()).toList(),
          'extra_range_fee': _extraRangeFee,
        },
        'max_delivery_radius': _maxDeliveryRadius,
        'max_restaurant_radius': _maxRestaurantRadius,
        'order_timeout': _orderTimeout,
        'max_retry_attempts': _maxRetryAttempts,
        'image_optimization': _imageOptimization,
        'lazy_loading': _lazyLoading,
        'max_image_size': _maxImageSize,
        'cdn_enabled': _cdnEnabled,
      };

      final success = await _dbConfigService.updateConfigs(configs);
      if (success) {
        debugPrint('✅ System configurations saved to database');
        // Best-effort cleanup of legacy keys to keep a single row
        try {
          await _dbConfigService.deleteConfig('delivery_fee_ranges');
          await _dbConfigService.deleteConfig('extra_range_fee');
        } catch (_) {}
      } else {
        debugPrint('❌ Failed to save configurations to database');
      }
      return success;
    } catch (e) {
      debugPrint('❌ Error saving configurations to database: $e');
      return false;
    }
  }

  /// Initialize database with default configurations
  Future<bool> initializeDatabase() async {
    try {
      final success = await _dbConfigService.initializeDefaults();
      if (success) {
        await loadFromDatabase();
        debugPrint('✅ Database initialized with default configurations');
      } else {
        debugPrint('❌ Failed to initialize database');
      }
      return success;
    } catch (e) {
      debugPrint('❌ Error initializing database: $e');
      return false;
    }
  }

  /// Force refresh from database
  Future<void> refreshFromDatabase() async {
    await _dbConfigService.forceRefresh();
    await loadFromDatabase();
  }

  /// Check if database is available
  Future<bool> isDatabaseAvailable() async {
    return _dbConfigService.isTableExists();
  }

  /// Get configuration value from database
  Future<dynamic> getDatabaseConfig(String key) async {
    return _dbConfigService.getConfig(key);
  }

  /// Set configuration value in database
  Future<bool> setDatabaseConfig(String key, dynamic value,
      {String? description, String? category}) async {
    return _dbConfigService.setConfig(key, value,
        description: description, category: category);
  }

  /// Test database connection and diagnose issues
  Future<Map<String, dynamic>> testDatabaseConnection() async {
    try {
      // Test basic connection
      final response = await client.from('system_config').select('id').limit(1);

      return {
        'connected': true,
        'table_exists': true,
        'message': 'Database connection successful',
        'sample_data': response.isNotEmpty ? response.first : null,
      };
    } catch (e) {
      return {
        'connected': false,
        'table_exists': false,
        'error': e.toString(),
        'message': 'Database connection failed: $e',
      };
    }
  }

  /// Test inserting a simple configuration
  Future<Map<String, dynamic>> testInsertConfig() async {
    try {
      final testConfig = {
        'config_key': 'test_config',
        'config_value': 'test_value',
        'config_type': 'string',
        'category': 'test',
        'description': 'Test configuration',
      };

      await client.from('system_config').insert(testConfig);

      return {
        'success': true,
        'message': 'Test configuration inserted successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to insert test configuration: $e',
      };
    }
  }

  /// Test updating a configuration
  Future<Map<String, dynamic>> testUpdateConfig() async {
    try {
      // First, try to delete any existing test config
      await client
          .from('system_config')
          .delete()
          .eq('config_key', 'test_config');

      // Then insert a new one
      final insertData = {
        'config_key': 'test_config',
        'config_value': 'test_value',
        'config_type': 'string',
        'category': 'test',
        'description': 'Test configuration',
      };

      await client.from('system_config').insert(insertData);

      // Now update it
      final updateData = {
        'config_key': 'test_config',
        'config_value': 'updated_value',
        'config_type': 'string',
        'updated_at': DateTime.now().toIso8601String(),
      };

      await client.from('system_config').upsert(updateData);

      return {
        'success': true,
        'message': 'Test configuration updated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
        'message': 'Failed to update test configuration: $e',
      };
    }
  }

  /// Clean up test data
  Future<void> cleanupTestData() async {
    try {
      await client
          .from('system_config')
          .delete()
          .eq('config_key', 'test_config');
    } catch (e) {
      // Ignore cleanup errors
    }
  }

  /// Fix missing extra range fee configuration in database
  Future<bool> fixExtraRangeFeeConfiguration() async {
    try {
      // Check if extra_range_fee exists
      try {
        await client
            .from('system_config')
            .select('config_key, config_value')
            .eq('config_key', 'extra_range_fee')
            .single();
        debugPrint('✅ extra_range_fee configuration already exists');
      } catch (e) {
        // Insert extra_range_fee configuration if it doesn't exist
        await client.from('system_config').insert({
          'config_key': 'extra_range_fee',
          'config_value': '2.0',
          'config_type': 'number',
          'category': 'fees',
          'description': 'Fee per 100m beyond last range',
          'is_active': true,
        });
        debugPrint('✅ Added missing extra_range_fee configuration');
      }

      // Ensure delivery_fee_ranges has proper structure
      try {
        final deliveryRangesResult = await client
            .from('system_config')
            .select('config_key, config_value')
            .eq('config_key', 'delivery_fee_ranges')
            .single();

        // Parse existing ranges and ensure they have proper structure
        final existingRanges = deliveryRangesResult['config_value'] as List;
        final updatedRanges = <Map<String, dynamic>>[];

        for (final range in existingRanges) {
          if (range is Map<String, dynamic>) {
            // Ensure the range has both maxDistance and fee
            updatedRanges.add({
              'maxDistance':
                  range['maxDistance'] ?? range['max_distance'] ?? 5.0,
              'fee': range['fee'] ?? 200.0,
            });
          }
        }

        // Update the delivery_fee_ranges with proper structure
        await client.from('system_config').update({
          'config_value': updatedRanges,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('config_key', 'delivery_fee_ranges');

        debugPrint('✅ Updated delivery_fee_ranges with proper structure');
      } catch (e) {
        debugPrint('⚠️ Could not update delivery_fee_ranges: $e');
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error fixing extra range fee configuration: $e');
      return false;
    }
  }
}
