-- Phase 2B readiness: enqueue outbox only when active push subscription exists.
-- Mirror of supabase/migrations/20260723120000_web_order_push_outbox_subscription_gate.sql

BEGIN;

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
    INNER JOIN public.web_order_push_subscriptions s ON s.tracking_link_id = l.id
    WHERE l.order_id = NEW.id
      AND l.revoked_at IS NULL
      AND l.expires_at > now()
      AND s.order_id = NEW.id
      AND s.revoked_at IS NULL
      AND s.expires_at > now()
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

COMMIT;

NOTIFY pgrst, 'reload schema';
