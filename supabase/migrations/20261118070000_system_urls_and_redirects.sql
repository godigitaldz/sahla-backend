-- =============================================================================
-- Migration: Official Domain URLs & System Config Routing
-- Date: 2026-11-18
-- Domain: https://sahla-backend.vercel.app
-- =============================================================================

BEGIN;

INSERT INTO public.system_config (config_key, config_value, config_type, category, description, is_active, updated_at)
VALUES
  ('privacy_policy_url', '"https://sahla-backend.vercel.app/privacy-policy"'::jsonb, 'string', 'legal', 'Public privacy policy page URL', true, now()),
  ('terms_of_service_url', '"https://sahla-backend.vercel.app/terms-of-service"'::jsonb, 'string', 'legal', 'Public terms of service page URL', true, now()),
  ('user_agreement_url', '"https://sahla-backend.vercel.app/user-agreement"'::jsonb, 'string', 'legal', 'Public user agreement page URL', true, now()),
  ('delete_account_url', '"https://sahla-backend.vercel.app/delete-account"'::jsonb, 'string', 'legal', 'Public account deletion instructions URL', true, now()),
  ('dashboard_url', '"https://sahla-backend.vercel.app/performance"'::jsonb, 'string', 'system', 'Admin performance dashboard URL', true, now()),
  ('admin_dashboard_url', '"https://sahla-backend.vercel.app/performance"'::jsonb, 'string', 'system', 'Admin performance dashboard URL', true, now()),
  ('web_base_url', '"https://sahla-backend.vercel.app"'::jsonb, 'string', 'system', 'Production web and API base domain URL', true, now()),
  ('table_order_base_url', '"https://sahla-backend.vercel.app"'::jsonb, 'string', 'system', 'Table order QR base domain URL', true, now())
ON CONFLICT (config_key) DO UPDATE
  SET config_value = EXCLUDED.config_value,
      config_type = EXCLUDED.config_type,
      category = EXCLUDED.category,
      description = EXCLUDED.description,
      is_active = true,
      updated_at = now();

COMMIT;
