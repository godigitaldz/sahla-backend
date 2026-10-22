-- Phase 2A: web order push subscriptions (separate from user_device_tokens).
-- Verification: select to_regclass('public.web_order_push_subscriptions');

BEGIN;

CREATE TABLE IF NOT EXISTS public.web_order_push_subscriptions (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  tracking_link_id uuid NOT NULL REFERENCES public.web_order_tracking_links(id) ON DELETE CASCADE,
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  provider text NOT NULL CHECK (provider IN ('fcm_web')),
  registration_kind text NOT NULL CHECK (registration_kind IN ('fid', 'legacy_token')),
  registration_value text NOT NULL,
  registration_hash text NOT NULL,
  permission_state text,
  user_agent_family text,
  platform_hint text,
  -- Full secure tracking URL (bearer token). Service-role only; never log.
  click_url text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  last_registered_at timestamptz NOT NULL DEFAULT now(),
  revoked_at timestamptz,
  expires_at timestamptz NOT NULL,
  last_success_at timestamptz,
  last_failure_at timestamptz,
  failure_count integer NOT NULL DEFAULT 0,
  UNIQUE (tracking_link_id, registration_hash)
);

CREATE INDEX IF NOT EXISTS idx_web_order_push_subscriptions_order
  ON public.web_order_push_subscriptions(order_id)
  WHERE revoked_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_web_order_push_subscriptions_active
  ON public.web_order_push_subscriptions(expires_at)
  WHERE revoked_at IS NULL;

ALTER TABLE public.web_order_push_subscriptions ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.web_order_push_subscriptions FROM PUBLIC;
REVOKE ALL ON TABLE public.web_order_push_subscriptions FROM anon, authenticated;
GRANT ALL ON TABLE public.web_order_push_subscriptions TO service_role;

COMMIT;

NOTIFY pgrst, 'reload schema';
