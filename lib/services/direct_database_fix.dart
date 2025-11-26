import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DirectDatabaseFix {
  static final DirectDatabaseFix _instance = DirectDatabaseFix._internal();
  factory DirectDatabaseFix() => _instance;
  DirectDatabaseFix._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Directly add missing extra_range_fee configuration
  Future<bool> addExtraRangeFeeConfiguration() async {
    try {
      debugPrint('🔧 Adding missing extra_range_fee configuration...');

      // Insert extra_range_fee configuration
      await _supabase.from('system_config').upsert({
        'config_key': 'extra_range_fee',
        'config_value': '2.5',
        'config_type': 'number',
        'category': 'fees',
        'description': 'Fee per 100m beyond last range',
        'is_active': true,
        'updated_at': DateTime.now().toIso8601String(),
      }, onConflict: 'config_key');

      debugPrint('✅ Successfully added extra_range_fee configuration');

      // Verify the configuration was added
      final result = await _supabase
          .from('system_config')
          .select(
              'config_key, config_value, config_type, category, description')
          .eq('config_key', 'extra_range_fee')
          .single();

      debugPrint(
          '✅ Verification: ${result['config_key']} = ${result['config_value']} ${result['config_type']}');

      return true;
    } catch (e) {
      debugPrint('❌ Error adding extra_range_fee configuration: $e');
      return false;
    }
  }

  /// Check if extra_range_fee exists in database
  Future<bool> checkExtraRangeFeeExists() async {
    try {
      await _supabase
          .from('system_config')
          .select('config_key')
          .eq('config_key', 'extra_range_fee')
          .single();

      debugPrint('✅ extra_range_fee configuration exists');
      return true;
    } catch (e) {
      debugPrint('❌ extra_range_fee configuration does not exist');
      return false;
    }
  }

  /// Get all fee-related configurations
  Future<Map<String, dynamic>> getAllFeeConfigurations() async {
    try {
      final result = await _supabase
          .from('system_config')
          .select(
              'config_key, config_value, config_type, category, description')
          .eq('category', 'fees');

      final feeConfigs = <String, dynamic>{};
      for (final config in result) {
        feeConfigs[config['config_key']] = {
          'value': config['config_value'],
          'type': config['config_type'],
          'description': config['description'],
        };
      }

      debugPrint('📊 Fee configurations found: ${feeConfigs.keys.join(', ')}');
      return feeConfigs;
    } catch (e) {
      debugPrint('❌ Error fetching fee configurations: $e');
      return {};
    }
  }
}
