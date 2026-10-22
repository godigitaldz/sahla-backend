-- Phase 1: opaque web order tracking tokens (hash-only storage).
-- Next.js service-role issues tokens and reads redacted projections.
-- Do not grant anon/authenticated SELECT on this table or on private order rows.

BEGIN;

CREATE TABLE IF NOT EXISTS public.web_order_tracking_links (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  token_hash text NOT NULL UNIQUE,
  token_prefix text,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL,
  revoked_at timestamptz,
  last_seen_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_web_order_tracking_links_order
  ON public.web_order_tracking_links(order_id);

CREATE INDEX IF NOT EXISTS idx_web_order_tracking_links_active
  ON public.web_order_tracking_links(expires_at)
  WHERE revoked_at IS NULL;

ALTER TABLE public.web_order_tracking_links ENABLE ROW LEVEL SECURITY;

-- No anon/authenticated policies: only service_role (bypasses RLS) may access.
REVOKE ALL ON TABLE public.web_order_tracking_links FROM PUBLIC;
REVOKE ALL ON TABLE public.web_order_tracking_links FROM anon, authenticated;
GRANT ALL ON TABLE public.web_order_tracking_links TO service_role;

COMMIT;

NOTIFY pgrst, 'reload schema';

-- Verification
-- select to_regclass('public.web_order_tracking_links');
-- select count(*) from public.web_order_tracking_links;
