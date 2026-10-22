-- Phase 2B: durable web order push outbox (mirror of supabase/migrations).
-- Verification: select to_regclass('public.web_order_push_outbox');

BEGIN;

CREATE TABLE IF NOT EXISTS public.web_order_push_outbox (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL REFERENCES public.orders(id) ON DELETE CASCADE,
  event text NOT NULL,
  status text NOT NULL,
  dedupe_key text NOT NULL UNIQUE,
  payload_json jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz,
  attempt_count integer NOT NULL DEFAULT 0,
  last_error text,
  next_retry_at timestamptz
);

CREATE INDEX IF NOT EXISTS idx_web_order_push_outbox_pending
  ON public.web_order_push_outbox(next_retry_at, created_at)
  WHERE processed_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_web_order_push_outbox_order
  ON public.web_order_push_outbox(order_id);

ALTER TABLE public.web_order_push_outbox ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON TABLE public.web_order_push_outbox FROM PUBLIC;
REVOKE ALL ON TABLE public.web_order_push_outbox FROM anon, authenticated;
GRANT ALL ON TABLE public.web_order_push_outbox TO service_role;

CREATE OR REPLACE FUNCTION public.enqueue_web_order_push_outbox()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_event text;
  v_status text;
  v_dedupe text;
BEGIN
  IF TG_OP <> 'UPDATE' THEN
    RETURN NEW;
  END IF;

  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
    RETURN NEW;
  END IF;

  v_status := lower(coalesce(NEW.status, ''));

  v_event := CASE v_status
    WHEN 'confirmed' THEN 'order_confirmed'
    WHEN 'preparing' THEN 'order_preparing'
    WHEN 'ready' THEN 'order_ready'
    WHEN 'picked_up' THEN 'order_picked_up'
    WHEN 'delivered' THEN 'order_delivered'
    WHEN 'collected' THEN 'order_collected'
    WHEN 'cancelled' THEN 'order_cancelled'
    ELSE NULL
  END;

  IF v_event IS NULL THEN
    RETURN NEW;
  END IF;

  IF lower(coalesce(NEW.source, '')) NOT IN ('web', 'web_table') THEN
    RETURN NEW;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.web_order_tracking_links l
    WHERE l.order_id = NEW.id
      AND l.revoked_at IS NULL
      AND l.expires_at > now()
  ) THEN
    RETURN NEW;
  END IF;

  v_dedupe := format(
    'web-order-push:%s:%s:%s:%s',
    NEW.id,
    v_event,
    v_status,
    coalesce(NEW.lifecycle_version, 0)
  );

  INSERT INTO public.web_order_push_outbox (order_id, event, status, dedupe_key, payload_json)
  VALUES (
    NEW.id,
    v_event,
    v_status,
    v_dedupe,
    jsonb_build_object('event', v_event, 'status', v_status)
  )
  ON CONFLICT (dedupe_key) DO NOTHING;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_enqueue_web_order_push_outbox ON public.orders;
CREATE TRIGGER trg_enqueue_web_order_push_outbox
  AFTER UPDATE OF status ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.enqueue_web_order_push_outbox();

COMMIT;

NOTIFY pgrst, 'reload schema';
