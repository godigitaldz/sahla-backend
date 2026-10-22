-- Phase 1: opaque web order tracking tokens (hash-only storage).
-- Mirror of scripts/20260721120000_web_order_tracking_links.sql

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

REVOKE ALL ON TABLE public.web_order_tracking_links FROM PUBLIC;
REVOKE ALL ON TABLE public.web_order_tracking_links FROM anon, authenticated;
GRANT ALL ON TABLE public.web_order_tracking_links TO service_role;

COMMIT;

NOTIFY pgrst, 'reload schema';
