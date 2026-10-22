-- Free delivery zone rollout + regression checks
-- Run after applying:
-- 1) scripts/free_delivery_zone_setup.sql
-- 2) scripts/free_delivery_zone_functions.sql

-- 1) Verify flags.
SELECT config_key, config_value, config_type, is_active
FROM public.system_config
WHERE config_key IN ('free_delivery_zone_enabled', 'free_delivery_zone_shadow_mode')
ORDER BY config_key;

-- 2) Verify zone exists and is valid.
SELECT
  id,
  name,
  is_active,
  priority,
  ST_IsValid(geom) AS geom_is_valid,
  ST_Area(geom::geography) AS area_m2
FROM public.free_delivery_zones
ORDER BY priority ASC, created_at ASC;

-- 3) Spot-check point-in-zone (inside sample).
SELECT *
FROM public.is_point_in_free_delivery_zone(
  34.8420::double precision,
  5.7530::double precision
);

-- 4) Spot-check point-in-zone (outside sample).
SELECT *
FROM public.is_point_in_free_delivery_zone(
  34.8600::double precision,
  5.7300::double precision
);

-- 5) Recent order impact audit.
SELECT
  a.id,
  a.order_id,
  a.in_zone,
  a.zone_name,
  a.shadow_mode,
  a.delivery_fee_before,
  a.delivery_fee_after,
  a.delivery_fee_discount_before,
  a.delivery_fee_discount_after,
  a.observed_at
FROM public.free_delivery_zone_audit a
ORDER BY a.id DESC
LIMIT 100;

-- 6) Compare recent orders for expected semantics.
SELECT
  o.id,
  o.created_at,
  o.delivery_fee,
  o.original_delivery_fee,
  o.delivery_fee_discount,
  o.subtotal_discount,
  o.discount_amount,
  o.delivery_fee_promo_applied,
  o.total_amount
FROM public.orders o
WHERE o.created_at >= now() - interval '24 hours'
ORDER BY o.created_at DESC
LIMIT 200;
