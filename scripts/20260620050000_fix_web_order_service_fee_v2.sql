-- =============================================================================
-- WEB ORDER service_fee / tax_amount FIX (v2) — SUPERSEDED BY v3
--
-- If rows still drift after this script, run:
--   scripts/20260620060000_fix_web_order_service_fee_v3.sql
--
-- v3 adds post-insert reconcile (DISABLE TRIGGER USER + pricing_snapshot)
-- because BEFORE INSERT preserve triggers lose to later commission triggers.
-- =============================================================================
-- (e.g. service_fee = 50% subtotal, tax_amount = 5% subtotal) on source='web'
-- rows AFTER create_public_web_order inserts correct values. Customer total is OK
-- but delivery_personnel Sahla tax accrual uses tax_amount + delivery_tax + service_fee.
--
-- Example bad row W-000014: service_fee=800, tax_amount=80, snapshot says 0/0.
--
-- Fix strategy (web-only; app orders untouched):
--   1) Patch commission/financial trigger FUNCTIONS to no-op when source='web'
--   2) Run preserve trigger LAST (name sorts after all trg_orders_*)
--   3) Prefer pricing_snapshot totals (checkout source of truth)
--   4) Backfill drift rows
--
-- Run SECTION 1 verify queries first, then SECTION 2 fix, then SECTION 3 verify.
-- =============================================================================

-- =============================================================================
-- SECTION 1 — VERIFY (read-only)
-- =============================================================================

-- 1a) All non-internal triggers on orders (note names AFTER trg_orders_zz*)
-- SELECT
--   t.tgname AS trigger_name,
--   p.proname AS function_name,
--   CASE t.tgenabled WHEN 'O' THEN 'enabled' ELSE t.tgenabled::text END AS status,
--   pg_get_triggerdef(t.oid, true) AS definition
-- FROM pg_trigger t
-- JOIN pg_class c ON c.oid = t.tgrelid
-- JOIN pg_namespace n ON n.oid = c.relnamespace
-- JOIN pg_proc p ON p.oid = t.tgfoid
-- WHERE n.nspname = 'public'
--   AND c.relname = 'orders'
--   AND NOT t.tgisinternal
-- ORDER BY t.tgname;

-- 1b) Trigger functions that mutate service_fee / tax_amount (candidates to patch)
-- SELECT DISTINCT p.proname, pg_get_functiondef(p.oid) AS body
-- FROM pg_trigger t
-- JOIN pg_proc p ON p.oid = t.tgfoid
-- JOIN pg_class c ON c.oid = t.tgrelid
-- JOIN pg_namespace n ON n.oid = c.relnamespace
-- WHERE n.nspname = 'public'
--   AND c.relname = 'orders'
--   AND NOT t.tgisinternal
--   AND p.proname NOT LIKE '%preserve_web%'
--   AND (
--     pg_get_functiondef(p.oid) ILIKE '%NEW.service_fee%'
--     OR pg_get_functiondef(p.oid) ILIKE '%NEW.tax_amount%'
--   )
-- ORDER BY 1;

-- 1c) Web drift vs pricing_snapshot (expect rows before fix)
-- SELECT
--   o.public_order_code,
--   o.order_number,
--   o.subtotal,
--   o.service_fee AS db_service_fee,
--   (o.pricing_snapshot->'totals'->>'serviceFee')::numeric AS snap_service_fee,
--   o.tax_amount AS db_tax_amount,
--   (o.pricing_snapshot->'totals'->>'commissionTax')::numeric AS snap_commission_tax,
--   o.delivery_tax,
--   o.net AS db_net,
--   (o.pricing_snapshot->'totals'->>'net')::numeric AS snap_net,
--   round(
--     coalesce(o.tax_amount, 0) + coalesce(o.delivery_tax, 0) + coalesce(o.service_fee, 0)
--     - coalesce(o.delivery_fee_discount, 0),
--     2
--   ) AS sahla_line_total,
--   o.created_at
-- FROM public.orders o
-- WHERE o.source = 'web'
-- ORDER BY o.created_at DESC
-- LIMIT 20;

-- 1d) W-000014 specifically
-- SELECT public_order_code, order_number, service_fee, tax_amount, delivery_tax, net, pricing_snapshot->'totals'
-- FROM public.orders WHERE public_order_code = 'W-000014';

-- =============================================================================
-- SECTION 2 — FIX
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 2a) Patch financial trigger functions: skip app commission logic for web rows
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  r record;
  v_def text;
  v_guard text := E'\n  IF NEW.source IS NOT DISTINCT FROM ''web'' THEN\n    RETURN NEW;\n  END IF;\n';
  v_pos int;
BEGIN
  FOR r IN
    SELECT DISTINCT p.oid, p.proname, pg_get_functiondef(p.oid) AS fdef
    FROM pg_trigger t
    JOIN pg_proc p ON p.oid = t.tgfoid
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = 'orders'
      AND NOT t.tgisinternal
      AND p.proname NOT LIKE '%preserve_web%'
      AND (
        pg_get_functiondef(p.oid) ILIKE '%NEW.service_fee%'
        OR pg_get_functiondef(p.oid) ILIKE '%NEW.tax_amount%'
        OR (
          pg_get_functiondef(p.oid) ILIKE '%NEW.net%'
          AND pg_get_functiondef(p.oid) ILIKE '%subtotal%'
        )
      )
  LOOP
    v_def := r.fdef;
    IF v_def ILIKE '%NEW.source IS NOT DISTINCT FROM ''web''%' THEN
      CONTINUE;
    END IF;
    IF v_def ILIKE '%NEW.source = ''web''%' AND v_def ILIKE '%RETURN NEW%' THEN
      CONTINUE;
    END IF;

    v_pos := position(E'BEGIN\n' in v_def);
    IF v_pos = 0 THEN
      v_pos := position('BEGIN' in v_def);
      IF v_pos = 0 THEN
        RAISE NOTICE 'skip % — no BEGIN', r.proname;
        CONTINUE;
      END IF;
      v_def := overlay(v_def placing v_guard from v_pos + 5);
    ELSE
      v_def := overlay(v_def placing v_guard from v_pos + 6);
    END IF;

    EXECUTE v_def;
    RAISE NOTICE 'patched orders trigger function % for web skip', r.proname;
  END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- 2b) Preserve web pricing LAST — pricing_snapshot is checkout source of truth
-- ---------------------------------------------------------------------------
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
  v_snap_service numeric;
  v_snap_tax numeric;
  v_snap_net numeric;
BEGIN
  IF NEW.source IS DISTINCT FROM 'web' THEN
    RETURN NEW;
  END IF;

  NEW.manual_phone_order := false;

  IF NEW.pricing_snapshot ? 'totals' THEN
    v_snap_service := coalesce((NEW.pricing_snapshot->'totals'->>'serviceFee')::numeric, 0);
    v_snap_tax := coalesce((NEW.pricing_snapshot->'totals'->>'commissionTax')::numeric, 0);
    v_snap_net := (NEW.pricing_snapshot->'totals'->>'net')::numeric;

    NEW.service_fee := round(v_snap_service, 2);
    NEW.tax_amount := round(v_snap_tax, 2);

    IF v_snap_net IS NOT NULL THEN
      NEW.net := round(v_snap_net, 2);
    ELSIF NEW.fulfillment_type = 'pickup' THEN
      NEW.net := round(coalesce(NEW.total_amount, 0)::numeric, 2);
    ELSE
      NEW.net := round(
        coalesce(NEW.total_amount, 0)
        - coalesce(NEW.delivery_fee, 0)
        - NEW.tax_amount,
        2
      );
    END IF;
  ELSE
    NEW.service_fee := 0;

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
  END IF;

  IF NEW.fulfillment_type = 'pickup' THEN
    NEW.delivery_fee := 0;
    NEW.original_delivery_fee := 0;
    NEW.delivery_tax := 0;
    NEW.net_delivery_amount := 0;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_orders_preserve_web_tax ON public.orders;
DROP TRIGGER IF EXISTS trg_orders_zz_preserve_web_tax ON public.orders;
DROP TRIGGER IF EXISTS trg_orders_zzz_preserve_web_tax ON public.orders;

-- Sorts after typical trg_orders_* commission triggers (alphabetical BEFORE order).
CREATE TRIGGER trg_orders_zzzzz_preserve_web_tax
  BEFORE INSERT OR UPDATE
  ON public.orders
  FOR EACH ROW
  WHEN (NEW.source = 'web')
  EXECUTE FUNCTION public.trg_orders_preserve_web_tax();

-- ---------------------------------------------------------------------------
-- 2c) Backfill persisted web rows from pricing_snapshot
-- ---------------------------------------------------------------------------
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

-- 3a) Drift count should be 0
-- SELECT count(*) AS drift_rows
-- FROM public.orders o
-- WHERE o.source = 'web'
--   AND o.pricing_snapshot ? 'totals'
--   AND (
--     abs(o.service_fee - coalesce((o.pricing_snapshot->'totals'->>'serviceFee')::numeric, 0)) > 0.02
--     OR abs(o.tax_amount - coalesce((o.pricing_snapshot->'totals'->>'commissionTax')::numeric, 0)) > 0.02
--     OR abs(o.net - coalesce((o.pricing_snapshot->'totals'->>'net')::numeric, 0)) > 0.02
--   );

-- 3b) W-000014 repaired (expected: service_fee=0, tax_amount=0, net=1600, sahla_line=30)
-- SELECT
--   public_order_code,
--   service_fee,
--   tax_amount,
--   delivery_tax,
--   net,
--   round(tax_amount + delivery_tax + service_fee - coalesce(delivery_fee_discount, 0), 2) AS sahla_line_total
-- FROM public.orders
-- WHERE public_order_code = 'W-000014';

-- 3c) Preserve trigger exists and sorts late
-- SELECT tgname, pg_get_triggerdef(oid, true)
-- FROM pg_trigger
-- WHERE tgrelid = 'public.orders'::regclass
--   AND tgname LIKE '%preserve_web%'
--   AND NOT tgisinternal;
