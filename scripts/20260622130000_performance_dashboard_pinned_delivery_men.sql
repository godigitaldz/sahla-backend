-- Performance dashboard: persist pinned delivery couriers (user_id list) in system_config.
-- Verification:
--   select config_key, config_value from public.system_config
--   where config_key = 'performance_dashboard_pinned_delivery_user_ids';

INSERT INTO public.system_config (config_key, config_value, config_type, category, is_active, description)
VALUES (
  'performance_dashboard_pinned_delivery_user_ids',
  '[]'::jsonb,
  'array',
  'performance_dashboard',
  true,
  'Pinned delivery couriers (user_id) for performance dashboard delivery-man tab sort order'
)
ON CONFLICT (config_key) DO NOTHING;
