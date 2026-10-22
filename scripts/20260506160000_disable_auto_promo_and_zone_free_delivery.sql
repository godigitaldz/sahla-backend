-- User-requested rollback:
-- Disable DB-side auto features:
-- 1) auto apply promo when minimum amount is met
-- 2) auto apply free delivery for zone

BEGIN;

-- Disable auto promo trigger.
DROP TRIGGER IF EXISTS trg_orders_01_auto_apply_promo ON public.orders;

-- Disable free-delivery zone triggers (legacy + canonical).
DROP TRIGGER IF EXISTS trg_apply_free_delivery_zone_on_orders ON public.orders;
DROP TRIGGER IF EXISTS trg_orders_apply_free_delivery_zone ON public.orders;

-- Keep flags explicitly off if config rows exist.
UPDATE public.system_config
SET config_value = 'false', updated_at = now()
WHERE config_key IN (
  'free_delivery_zone_enabled',
  'free_delivery_zone_shadow_mode'
);

COMMIT;
