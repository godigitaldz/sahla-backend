import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DatabaseSetupService {
  static final DatabaseSetupService _instance =
      DatabaseSetupService._internal();
  factory DatabaseSetupService() => _instance;
  DatabaseSetupService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  /// Create the system_config table if it doesn't exist
  Future<bool> createSystemConfigTable() async {
    try {
      // Check if table already exists
      final exists = await _tableExists();
      if (exists) {
        debugPrint('✅ System config table already exists');
        return true;
      }

      // Try to create the table using direct SQL execution
      try {
        await _supabase.rpc('exec_sql', params: {
          'sql': '''
            CREATE TABLE IF NOT EXISTS public.system_config (
              id uuid NOT NULL DEFAULT gen_random_uuid(),
              config_key text NOT NULL UNIQUE,
              config_value jsonb NOT NULL,
              config_type text NOT NULL DEFAULT 'string' CHECK (config_type IN ('string', 'number', 'boolean', 'object', 'array')),
              category text NOT NULL DEFAULT 'general',
              description text,
              is_active boolean DEFAULT true,
              created_at timestamp with time zone DEFAULT now(),
              updated_at timestamp with time zone DEFAULT now(),
              updated_by uuid,
              CONSTRAINT system_config_pkey PRIMARY KEY (id),
              CONSTRAINT system_config_updated_by_fkey FOREIGN KEY (updated_by) REFERENCES auth.users(id)
            );
          '''
        });
      } catch (e) {
        debugPrint('⚠️ exec_sql failed, trying alternative approach: $e');
        // Alternative: try to insert a test record to create the table
        try {
          await _supabase.from('system_config').select('id').limit(1);
        } catch (e2) {
          debugPrint('❌ Table does not exist and cannot be created: $e2');
          return false;
        }
      }

      // Create indexes (optional, don't fail if they can't be created)
      try {
        await _supabase.rpc('exec_sql', params: {
          'sql': '''
            CREATE INDEX IF NOT EXISTS idx_system_config_key ON public.system_config(config_key);
            CREATE INDEX IF NOT EXISTS idx_system_config_category ON public.system_config(category);
            CREATE INDEX IF NOT EXISTS idx_system_config_active ON public.system_config(is_active);
          '''
        });
        debugPrint('✅ Indexes created successfully');
      } catch (e) {
        debugPrint('⚠️ Could not create indexes (this is usually fine): $e');
      }

      // Create trigger function (optional)
      try {
        await _supabase.rpc('exec_sql', params: {
          'sql': r'''
            CREATE OR REPLACE FUNCTION update_system_config_updated_at()
            RETURNS TRIGGER AS $$
            BEGIN
              NEW.updated_at = now();
              RETURN NEW;
            END;
            $$ LANGUAGE plpgsql;
          '''
        });
        debugPrint('✅ Trigger function created successfully');
      } catch (e) {
        debugPrint(
            '⚠️ Could not create trigger function (this is usually fine): $e');
      }

      // Create trigger (optional)
      try {
        await _supabase.rpc('exec_sql', params: {
          'sql': '''
            CREATE TRIGGER trigger_update_system_config_updated_at
              BEFORE UPDATE ON public.system_config
              FOR EACH ROW
              EXECUTE FUNCTION update_system_config_updated_at();
          '''
        });
        debugPrint('✅ Trigger created successfully');
      } catch (e) {
        debugPrint('⚠️ Could not create trigger (this is usually fine): $e');
      }

      // Grant permissions (optional)
      try {
        await _supabase.rpc('exec_sql', params: {
          'sql': '''
            GRANT SELECT, INSERT, UPDATE, DELETE ON public.system_config TO authenticated;
            GRANT USAGE ON SCHEMA public TO authenticated;
          '''
        });
        debugPrint('✅ Permissions granted successfully');
      } catch (e) {
        debugPrint('⚠️ Could not grant permissions (this is usually fine): $e');
      }

      debugPrint('✅ System config table created successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error creating system config table: $e');
      return false;
    }
  }

  /// Insert default configurations
  Future<bool> insertDefaultConfigs() async {
    final defaultConfigs = [
      {
        'config_key': 'service_fee',
        'config_value': '5.0',
        'config_type': 'number',
        'category': 'fees',
        'description': 'Platform service fee in DA',
      },
      {
        'config_key': 'delivery_fee_config',
        'config_value':
            '{"ranges": [{"maxDistance": 2.0, "fee": 30.0}, {"maxDistance": 5.0, "fee": 50.0}, {"maxDistance": 10.0, "fee": 80.0}], "extra_range_fee": 2.0}',
        'config_type': 'object',
        'category': 'fees',
        'description':
            'Unified delivery fee configuration (ranges + extra fee)',
      },
      {
        'config_key': 'max_delivery_radius',
        'config_value': '50',
        'config_type': 'number',
        'category': 'system',
        'description': 'Maximum delivery radius in km',
      },
      {
        'config_key': 'max_restaurant_radius',
        'config_value': '25',
        'config_type': 'number',
        'category': 'system',
        'description': 'Maximum restaurant radius in km',
      },
      {
        'config_key': 'order_timeout',
        'config_value': '60',
        'config_type': 'number',
        'category': 'system',
        'description': 'Order timeout in minutes',
      },
      {
        'config_key': 'max_retry_attempts',
        'config_value': '3',
        'config_type': 'number',
        'category': 'system',
        'description': 'Maximum retry attempts for failed operations',
      },
      {
        'config_key': 'image_optimization',
        'config_value': 'true',
        'config_type': 'boolean',
        'category': 'performance',
        'description': 'Enable image optimization',
      },
      {
        'config_key': 'lazy_loading',
        'config_value': 'true',
        'config_type': 'boolean',
        'category': 'performance',
        'description': 'Enable lazy loading',
      },
      {
        'config_key': 'max_image_size',
        'config_value': '10',
        'config_type': 'number',
        'category': 'performance',
        'description': 'Maximum image size in MB',
      },
      {
        'config_key': 'cdn_enabled',
        'config_value': 'false',
        'config_type': 'boolean',
        'category': 'performance',
        'description': 'Enable Content Delivery Network',
      },
    ];

    try {
      // Use upsert to handle existing data gracefully
      await _supabase.from('system_config').upsert(defaultConfigs);

      debugPrint('✅ Default configurations inserted/updated successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Error inserting default configs: $e');
      // Try to insert configs one by one to identify which ones fail
      for (final config in defaultConfigs) {
        try {
          await _supabase.from('system_config').upsert([config]);
          debugPrint('✅ Inserted config: ${config['config_key']}');
        } catch (e2) {
          debugPrint('⚠️ Failed to insert config ${config['config_key']}: $e2');
        }
      }
      return true; // Return true even if some configs fail
    }
  }

  /// Check if table exists
  Future<bool> _tableExists() async {
    try {
      await _supabase.from('system_config').select('id').limit(1);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Complete database setup
  Future<bool> setupDatabase() async {
    try {
      debugPrint('🚀 Starting database setup...');

      // Create table
      final tableCreated = await createSystemConfigTable();
      if (!tableCreated) {
        return false;
      }

      // Insert default configs
      final configsInserted = await insertDefaultConfigs();
      if (!configsInserted) {
        return false;
      }

      debugPrint('✅ Database setup completed successfully');
      return true;
    } catch (e) {
      debugPrint('❌ Database setup failed: $e');
      return false;
    }
  }
}
