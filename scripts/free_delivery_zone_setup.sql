-- Free Delivery Zone setup (DB source of truth)
-- Scope: all restaurants
-- Safe to re-run: uses IF NOT EXISTS and idempotent upserts.

BEGIN;

CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE IF NOT EXISTS public.free_delivery_zones (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  is_active boolean NOT NULL DEFAULT true,
  priority integer NOT NULL DEFAULT 100,
  geom geometry(MultiPolygon, 4326) NOT NULL,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS free_delivery_zones_geom_gix
  ON public.free_delivery_zones USING GIST (geom);

CREATE INDEX IF NOT EXISTS free_delivery_zones_active_priority_idx
  ON public.free_delivery_zones (is_active, priority);

CREATE TABLE IF NOT EXISTS public.free_delivery_zone_audit (
  id bigserial PRIMARY KEY,
  order_id uuid NULL,
  in_zone boolean NOT NULL,
  zone_id uuid NULL,
  zone_name text NULL,
  shadow_mode boolean NOT NULL DEFAULT false,
  delivery_fee_before numeric NULL,
  delivery_fee_after numeric NULL,
  delivery_fee_discount_before numeric NULL,
  delivery_fee_discount_after numeric NULL,
  observed_at timestamptz NOT NULL DEFAULT now(),
  details jsonb NOT NULL DEFAULT '{}'::jsonb
);

CREATE INDEX IF NOT EXISTS free_delivery_zone_audit_order_id_idx
  ON public.free_delivery_zone_audit(order_id);

INSERT INTO public.system_config (config_key, config_value, config_type, is_active, description)
VALUES
  ('free_delivery_zone_enabled', 'false', 'boolean', true, 'Enable free delivery zone virtual promo logic'),
  ('free_delivery_zone_shadow_mode', 'true', 'boolean', true, 'When true, only audit free-delivery-zone matches without mutating order fees')
ON CONFLICT (config_key) DO NOTHING;

-- One multipolygon built from your provided Polygon features.
INSERT INTO public.free_delivery_zones (name, is_active, priority, geom, metadata)
SELECT
  'Sahla Free Delivery Zone - Initial',
  true,
  10,
  ST_Multi(
    ST_Collect(
      ST_GeomFromText(
        'POLYGON((
          5.751564234491241 34.83932108345725,
          5.758131096542968 34.83932108345725,
          5.758131096542968 34.84496020074073,
          5.751564234491241 34.84496020074073,
          5.751564234491241 34.83932108345725
        ))',
        4326
      ),
      ST_GeomFromText(
        'POLYGON((
          5.7451483409567174 34.850940760236995,
          5.7451483409567174 34.84362054033065,
          5.7514123772321 34.84362054033065,
          5.7514123772321 34.850940760236995,
          5.7451483409567174 34.850940760236995
        ))',
        4326
      )
    )
  ),
  jsonb_build_object(
    'source', 'manual_geojson',
    'feature_ids', jsonb_build_array(0, 1),
    'notes', 'LineString features were intentionally ignored for containment logic'
  )
WHERE NOT EXISTS (
  SELECT 1
  FROM public.free_delivery_zones z
  WHERE z.name = 'Sahla Free Delivery Zone - Initial'
);

COMMIT;
