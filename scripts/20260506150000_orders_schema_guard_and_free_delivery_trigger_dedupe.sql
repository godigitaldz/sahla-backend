-- Orders schema guard + free-delivery trigger dedupe.
-- Purpose:
-- 1) Prevent PostgREST insert failure for clients sending zone_geojson.
-- 2) Avoid double-application of free-delivery logic when legacy + new triggers coexist.
--
-- Safe to run multiple times.

BEGIN;

ALTER TABLE IF EXISTS public.orders
  ADD COLUMN IF NOT EXISTS zone_geojson jsonb;

COMMENT ON COLUMN public.orders.zone_geojson IS
'Backward-compat payload field accepted from clients during order insert.';

-- Keep only one canonical free-delivery trigger implementation.
-- If legacy trigger exists, remove it to avoid duplicate fee mutation.
DROP TRIGGER IF EXISTS trg_apply_free_delivery_zone_on_orders ON public.orders;

COMMIT;
