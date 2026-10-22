-- =============================================================================
-- WEB ORDER TAX / SERVICE_FEE FIX
-- Problem: generic orders BEFORE INSERT triggers apply app commission + service_fee
-- after create_public_web_order inserts source='web' rows (service_fee must stay 0,
-- tax_amount must use web commission resolver, not app restaurant_commission).
--
-- Run SECTION 1 (verify) first in Supabase SQL Editor. Then SECTION 2 (fix).
-- =============================================================================

-- =============================================================================
-- SECTION 1 — VERIFY (read-only, run before fix)
-- =============================================================================

-- 1a) All triggers on orders (find commission trigger that runs after web preserve)
-- SELECT
--   t.tgname AS trigger_name,
--   CASE t.tgenabled WHEN 'O' THEN 'enabled' WHEN 'D' THEN 'disabled' ELSE t.tgenabled::text END AS status,
--   pg_get_triggerdef(t.oid, true) AS definition
-- FROM pg_trigger t
-- JOIN pg_class c ON c.oid = t.tgrelid
-- JOIN pg_namespace n ON n.oid = c.relnamespace
-- WHERE n.nspname = 'public'
--   AND c.relname = 'orders'
--   AND NOT t.tgisinternal
-- ORDER BY t.tgname;

-- 1b) Web preserve trigger function (current deployed body)
-- SELECT pg_get_functiondef('public.trg_orders_preserve_web_tax()'::regprocedure);

-- 1c) Recent web orders vs pricing_snapshot (expected source of truth at checkout)
-- SELECT
--   o.id,
--   o.public_order_code,
--   o.subtotal,
--   o.tax_amount AS db_tax_amount,
--   (o.pricing_snapshot->'totals'->>'commissionTax')::numeric AS snap_commission_tax,
--   o.service_fee AS db_service_fee,
--   (o.pricing_snapshot->'totals'->>'serviceFee')::numeric AS snap_service_fee,
--   o.net AS db_net,
--   (o.pricing_snapshot->'totals'->>'net')::numeric AS snap_net,
--   o.total_amount,
--   o.delivery_fee,
--   o.created_at
-- FROM public.orders o
-- WHERE o.source = 'web'
-- ORDER BY o.created_at DESC
-- LIMIT 20;

-- 1d) Drift rows only (should return 0 rows after fix + backfill)
-- SELECT
--   o.id,
--   o.public_order_code,
--   o.tax_amount - coalesce((o.pricing_snapshot->'totals'->>'commissionTax')::numeric, 0) AS tax_drift,
--   o.service_fee - coalesce((o.pricing_snapshot->'totals'->>'serviceFee')::numeric, 0) AS service_fee_drift,
--   o.net - coalesce((o.pricing_snapshot->'totals'->>'net')::numeric, 0) AS net_drift
-- FROM public.orders o
-- WHERE o.source = 'web'
--   AND o.pricing_snapshot ? 'totals'
--   AND (
--     abs(o.tax_amount - coalesce((o.pricing_snapshot->'totals'->>'commissionTax')::numeric, 0)) > 0.02
--     OR abs(o.service_fee - coalesce((o.pricing_snapshot->'totals'->>'serviceFee')::numeric, 0)) > 0.02
--     OR abs(o.net - coalesce((o.pricing_snapshot->'totals'->>'net')::numeric, 0)) > 0.02
--   )
-- ORDER BY o.created_at DESC;

-- 1e) Example bad row (W-000010 pattern: app service_fee/tax applied to web order)
-- SELECT
--   o.public_order_code,
--   o.subtotal,
--   o.service_fee,
--   o.tax_amount,
--   o.net,
--   o.total_amount,
--   o.pricing_snapshot->'totals' AS expected_totals
-- FROM public.orders o
-- WHERE o.source = 'web'
--   AND o.public_order_code = 'W-000010';

-- 1f) Web commission config (what resolve_web_order_commission_tax uses)
-- SELECT config_key, config_value, is_active
-- FROM public.system_config
-- WHERE config_key IN (
--   'web_order_commission_rate',
--   'web_order_commission_cap_da',
--   'web_order_new_restaurant_commission_rate',
--   'web_order_new_restaurant_commission_cap_da'
-- )
-- ORDER BY config_key;

-- =============================================================================
-- SECTION 2 — FIX (web-only; does not change app order trigger logic)
-- =============================================================================

BEGIN;

-- Recompute web tax/net AFTER generic triggers by running last (trigger name zz_*).
CREATE OR REPLACE FUNCTION public.trg_orders_preserve_web_tax()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
DECLARE
  v_comm record;
  v_is_new boolean := false;
  v_rate numeric;
  v_cap numeric;
BEGIN
  IF NEW.source IS DISTINCT FROM 'web' THEN
    RETURN NEW;
  END IF;

  NEW.service_fee := 0;
  NEW.manual_phone_order := false;

  IF NEW.fulfillment_type = 'pickup' THEN
    NEW.delivery_fee := 0;
    NEW.original_delivery_fee := 0;
    NEW.delivery_tax := 0;
    NEW.net_delivery_amount := 0;
  END IF;

  IF NEW.restaurant_id IS NOT NULL THEN
    SELECT
      coalesce(r.is_new, false),
      r.web_order_commission_rate,
      r.web_order_commission_cap_da
    INTO v_is_new, v_rate, v_cap
    FROM public.restaurants r
    WHERE r.id = NEW.restaurant_id;
  END IF;

  SELECT *
  INTO v_comm
  FROM public.resolve_web_order_commission_tax(
    coalesce(NEW.subtotal, 0),
    v_is_new,
    v_rate,
    v_cap
  );

  NEW.tax_amount := round(coalesce(v_comm.tax_amount, 0)::numeric, 2);

  IF NEW.fulfillment_type = 'pickup' THEN
    NEW.net := round(coalesce(NEW.total_amount, 0)::numeric, 2);
  ELSE
    NEW.net := round(
      coalesce(NEW.total_amount, 0)
      - coalesce(NEW.delivery_fee, 0)
      - NEW.tax_amount,
      2
    );
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_orders_preserve_web_tax ON public.orders;
DROP TRIGGER IF EXISTS trg_orders_zz_preserve_web_tax ON public.orders;

CREATE TRIGGER trg_orders_zz_preserve_web_tax
  BEFORE INSERT OR UPDATE
  ON public.orders
  FOR EACH ROW
  WHEN (NEW.source = 'web')
  EXECUTE FUNCTION public.trg_orders_preserve_web_tax();

-- One-time repair: align persisted rows with checkout pricing_snapshot totals.
UPDATE public.orders o
SET
  service_fee = round(coalesce((o.pricing_snapshot->'totals'->>'serviceFee')::numeric, 0), 2),
  tax_amount = round(coalesce((o.pricing_snapshot->'totals'->>'commissionTax')::numeric, 0), 2),
  net = round(coalesce((o.pricing_snapshot->'totals'->>'net')::numeric, o.net), 2),
  updated_at = now()
WHERE o.source = 'web'
  AND o.pricing_snapshot ? 'totals'
  AND (
    abs(o.service_fee - coalesce((o.pricing_snapshot->'totals'->>'serviceFee')::numeric, 0)) > 0.02
    OR abs(o.tax_amount - coalesce((o.pricing_snapshot->'totals'->>'commissionTax')::numeric, 0)) > 0.02
    OR abs(o.net - coalesce((o.pricing_snapshot->'totals'->>'net')::numeric, 0)) > 0.02
  );

COMMIT;

-- =============================================================================
-- SECTION 3 — VERIFY (run after fix)
-- =============================================================================

-- 3a) Drift should be empty
-- SELECT count(*) AS drift_rows
-- FROM public.orders o
-- WHERE o.source = 'web'
--   AND o.pricing_snapshot ? 'totals'
--   AND (
--     abs(o.service_fee - coalesce((o.pricing_snapshot->'totals'->>'serviceFee')::numeric, 0)) > 0.02
--     OR abs(o.tax_amount - coalesce((o.pricing_snapshot->'totals'->>'commissionTax')::numeric, 0)) > 0.02
--     OR abs(o.net - coalesce((o.pricing_snapshot->'totals'->>'net')::numeric, 0)) > 0.02
--   );

-- 3b) W-000010 repaired (expected: service_fee=0, tax_amount=0, net=380)
-- SELECT public_order_code, service_fee, tax_amount, net, total_amount, delivery_fee
-- FROM public.orders
-- WHERE public_order_code = 'W-000010';

-- 3c) New web insert simulation (optional, rollback after)
-- BEGIN;
--   -- Use create_public_web_order via service role in app; or inspect next real order.
-- ROLLBACK;
