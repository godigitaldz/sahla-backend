-- =============================================================================
-- WEB ORDER FINANCIALS — VERIFY ONLY (read-only, run BEFORE and AFTER fix)
-- =============================================================================
-- Run each block separately in Supabase SQL Editor.
-- BEFORE fix: expect drift rows in 2c/2d; note commission triggers in 1b.
-- AFTER fix:  2c drift count = 0; 2d sahla_line matches snapshot-only tax.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1a) All non-internal triggers on orders (commission order = alphabetical name)
-- -----------------------------------------------------------------------------
SELECT
  t.tgname AS trigger_name,
  p.proname AS function_name,
  CASE t.tgenabled WHEN 'O' THEN 'enabled' ELSE t.tgenabled::text END AS status,
  pg_get_triggerdef(t.oid, true) AS definition
FROM pg_trigger t
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
JOIN pg_proc p ON p.oid = t.tgfoid
WHERE n.nspname = 'public'
  AND c.relname = 'orders'
  AND NOT t.tgisinternal
ORDER BY t.tgname;

-- -----------------------------------------------------------------------------
-- 1b) Trigger functions that touch service_fee / tax_amount / net
-- -----------------------------------------------------------------------------
SELECT DISTINCT
  p.proname AS function_name,
  CASE
    WHEN pg_get_functiondef(p.oid) ILIKE '%NEW.source IS NOT DISTINCT FROM ''web''%' THEN 'web_skip_present'
    ELSE 'needs_web_skip'
  END AS web_guard_status
FROM pg_trigger t
JOIN pg_proc p ON p.oid = t.tgfoid
JOIN pg_class c ON c.oid = t.tgrelid
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relname = 'orders'
  AND NOT t.tgisinternal
  AND (
    pg_get_functiondef(p.oid) ILIKE '%NEW.service_fee%'
    OR pg_get_functiondef(p.oid) ILIKE '%NEW.tax_amount%'
    OR (
      pg_get_functiondef(p.oid) ILIKE '%NEW.net%'
      AND pg_get_functiondef(p.oid) ILIKE '%subtotal%'
    )
  )
ORDER BY 1;

-- -----------------------------------------------------------------------------
-- 1c) Web fix helpers deployed?
-- -----------------------------------------------------------------------------
SELECT proname, prosecdef AS security_definer
FROM pg_proc
WHERE proname IN (
  'reconcile_web_order_financials',
  'trg_orders_after_reconcile_web_financials',
  'trg_orders_preserve_web_tax',
  'calculate_order_service_fee',
  'create_public_web_order',
  'resolve_web_order_commission_tax'
)
ORDER BY 1;

-- -----------------------------------------------------------------------------
-- 1d) Web preserve / reconcile triggers
-- -----------------------------------------------------------------------------
SELECT tgname, pg_get_triggerdef(oid, true) AS definition
FROM pg_trigger
WHERE tgrelid = 'public.orders'::regclass
  AND NOT tgisinternal
  AND (
    tgname ILIKE '%preserve_web%'
    OR tgname ILIKE '%reconcile_web%'
  )
ORDER BY tgname;

-- -----------------------------------------------------------------------------
-- 2a) Flow preview — checkout snapshot vs persisted columns (recent web orders)
-- -----------------------------------------------------------------------------
SELECT
  o.public_order_code,
  o.order_number,
  o.subtotal,
  o.total_amount,
  o.delivery_fee,
  o.delivery_tax,
  o.service_fee AS db_service_fee,
  (o.pricing_snapshot->'totals'->>'serviceFee')::numeric AS snap_service_fee,
  o.tax_amount AS db_tax_amount,
  (o.pricing_snapshot->'totals'->>'commissionTax')::numeric AS snap_commission_tax,
  o.net AS db_net,
  (o.pricing_snapshot->'totals'->>'net')::numeric AS snap_net,
  round(
    coalesce(o.tax_amount, 0)
    + coalesce(o.delivery_tax, 0)
    + coalesce(o.service_fee, 0)
    - coalesce(o.delivery_fee_discount, 0),
    2
  ) AS sahla_driver_line_da,
  round(
    coalesce((o.pricing_snapshot->'totals'->>'commissionTax')::numeric, 0)
    + coalesce(o.delivery_tax, 0)
    + coalesce((o.pricing_snapshot->'totals'->>'serviceFee')::numeric, 0)
    - coalesce(o.delivery_fee_discount, 0),
    2
  ) AS expected_sahla_line_da,
  o.created_at
FROM public.orders o
WHERE o.source = 'web'
ORDER BY o.created_at DESC
LIMIT 20;

-- -----------------------------------------------------------------------------
-- 2b) Drift count (target 0 after fix)
-- -----------------------------------------------------------------------------
SELECT count(*) AS drift_rows
FROM public.orders o
WHERE o.source = 'web'
  AND o.pricing_snapshot ? 'totals'
  AND (
    abs(o.service_fee - coalesce((o.pricing_snapshot->'totals'->>'serviceFee')::numeric, 0)) > 0.02
    OR abs(o.tax_amount - coalesce((o.pricing_snapshot->'totals'->>'commissionTax')::numeric, 0)) > 0.02
    OR abs(o.net - coalesce((o.pricing_snapshot->'totals'->>'net')::numeric, 0)) > 0.02
  );

-- -----------------------------------------------------------------------------
-- 2c) Drift detail rows only
-- -----------------------------------------------------------------------------
SELECT
  o.public_order_code,
  o.order_number,
  o.service_fee - coalesce((o.pricing_snapshot->'totals'->>'serviceFee')::numeric, 0) AS service_fee_drift,
  o.tax_amount - coalesce((o.pricing_snapshot->'totals'->>'commissionTax')::numeric, 0) AS tax_drift,
  o.net - coalesce((o.pricing_snapshot->'totals'->>'net')::numeric, 0) AS net_drift,
  o.pricing_snapshot->'totals' AS expected_totals
FROM public.orders o
WHERE o.source = 'web'
  AND o.pricing_snapshot ? 'totals'
  AND (
    abs(o.service_fee - coalesce((o.pricing_snapshot->'totals'->>'serviceFee')::numeric, 0)) > 0.02
    OR abs(o.tax_amount - coalesce((o.pricing_snapshot->'totals'->>'commissionTax')::numeric, 0)) > 0.02
    OR abs(o.net - coalesce((o.pricing_snapshot->'totals'->>'net')::numeric, 0)) > 0.02
  )
ORDER BY o.created_at DESC;

-- -----------------------------------------------------------------------------
-- 2d) W-000014 spot check
-- -----------------------------------------------------------------------------
SELECT
  o.public_order_code,
  o.order_number,
  o.subtotal,
  o.total_amount,
  o.service_fee,
  o.tax_amount,
  o.delivery_tax,
  o.net,
  round(
    o.tax_amount + o.delivery_tax + o.service_fee - coalesce(o.delivery_fee_discount, 0),
    2
  ) AS sahla_line_total,
  o.pricing_snapshot->'totals' AS expected_totals
FROM public.orders o
WHERE o.public_order_code = 'W-000014';

-- -----------------------------------------------------------------------------
-- 2e) calculate_order_service_fee has web skip (must compile)
-- -----------------------------------------------------------------------------
SELECT
  CASE
    WHEN pg_get_functiondef('public.calculate_order_service_fee()'::regprocedure)
      ILIKE '%NEW.source IS NOT DISTINCT FROM ''web''%'
    THEN 'ok_web_skip'
    ELSE 'missing_web_skip'
  END AS service_fee_fn_status;

-- -----------------------------------------------------------------------------
-- 2f) Web commission config (resolve_web_order_commission_tax inputs)
-- -----------------------------------------------------------------------------
SELECT config_key, config_value, is_active
FROM public.system_config
WHERE config_key IN (
  'web_order_commission_rate',
  'web_order_commission_cap_da',
  'web_order_new_restaurant_commission_rate',
  'web_order_new_restaurant_commission_cap_da',
  'service_fee',
  'delivery_tax',
  'delivery_tax_cap_da'
)
ORDER BY config_key;
