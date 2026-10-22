-- Free delivery zone functions + trigger for virtual 100% delivery promo semantics.
-- Requires scripts/free_delivery_zone_setup.sql to be executed first.

BEGIN;

CREATE OR REPLACE FUNCTION public.read_bool_system_config(
  p_key text,
  p_default boolean
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_raw text;
BEGIN
  SELECT lower(trim(coalesce(sc.config_value, '')))
    INTO v_raw
  FROM public.system_config sc
  WHERE sc.config_key = p_key
    AND coalesce(sc.is_active, true) = true
  ORDER BY sc.updated_at DESC NULLS LAST
  LIMIT 1;

  IF v_raw IS NULL OR v_raw = '' THEN
    RETURN p_default;
  END IF;

  IF v_raw IN ('true', '1', 'yes', 'on') THEN
    RETURN true;
  END IF;

  IF v_raw IN ('false', '0', 'no', 'off') THEN
    RETURN false;
  END IF;

  RETURN p_default;
END;
$$;

CREATE OR REPLACE FUNCTION public.is_point_in_free_delivery_zone(
  p_lat double precision,
  p_lng double precision
)
RETURNS TABLE (
  in_zone boolean,
  zone_id uuid,
  zone_name text
)
LANGUAGE sql
STABLE
AS $$
  WITH p AS (
    SELECT ST_SetSRID(ST_MakePoint(p_lng, p_lat), 4326) AS pt
  )
  SELECT
    true AS in_zone,
    z.id AS zone_id,
    z.name AS zone_name
  FROM public.free_delivery_zones z
  CROSS JOIN p
  WHERE z.is_active = true
    AND ST_Covers(z.geom, p.pt)
  ORDER BY z.priority ASC, z.created_at ASC
  LIMIT 1;
$$;

CREATE OR REPLACE FUNCTION public.apply_virtual_free_delivery_promo(
  p_subtotal numeric,
  p_delivery_fee numeric,
  p_original_delivery_fee numeric,
  p_discount_amount numeric,
  p_subtotal_discount numeric,
  p_delivery_fee_discount numeric,
  p_service_fee numeric
)
RETURNS TABLE (
  out_original_delivery_fee numeric,
  out_delivery_fee numeric,
  out_delivery_fee_discount numeric,
  out_subtotal_discount numeric,
  out_discount_amount numeric,
  out_total_amount numeric
)
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_original numeric := greatest(coalesce(p_original_delivery_fee, p_delivery_fee, 0), 0);
  v_subtotal_discount numeric := greatest(coalesce(p_subtotal_discount, 0), 0);
  v_existing_delivery_discount numeric := greatest(coalesce(p_delivery_fee_discount, 0), 0);
  v_discount_amount numeric := greatest(coalesce(p_discount_amount, 0), 0);
BEGIN
  IF v_subtotal_discount = 0 AND v_discount_amount > 0 THEN
    v_subtotal_discount := greatest(v_discount_amount - v_existing_delivery_discount, 0);
  END IF;

  out_original_delivery_fee := v_original;
  out_delivery_fee := 0;
  out_delivery_fee_discount := v_original;
  out_subtotal_discount := v_subtotal_discount;
  out_discount_amount := v_subtotal_discount + out_delivery_fee_discount;
  out_total_amount := greatest(
    0,
    coalesce(p_subtotal, 0) - out_subtotal_discount + out_delivery_fee + coalesce(p_service_fee, 0)
  );
  RETURN NEXT;
END;
$$;

CREATE OR REPLACE FUNCTION public.orders_apply_free_delivery_zone()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  v_enabled boolean;
  v_shadow_mode boolean;
  v_zone record;
  v_lat double precision;
  v_lng double precision;
  v_calc record;
  v_old_delivery_fee numeric := coalesce(NEW.delivery_fee, 0);
  v_old_delivery_fee_discount numeric := coalesce(NEW.delivery_fee_discount, 0);
BEGIN
  v_enabled := public.read_bool_system_config('free_delivery_zone_enabled', false);
  v_shadow_mode := public.read_bool_system_config('free_delivery_zone_shadow_mode', true);

  IF NOT v_enabled THEN
    RETURN NEW;
  END IF;

  v_lat := nullif(coalesce(NEW.delivery_address->>'latitude', NEW.delivery_address->>'lat'), '')::double precision;
  v_lng := nullif(coalesce(NEW.delivery_address->>'longitude', NEW.delivery_address->>'lng'), '')::double precision;

  IF v_lat IS NULL OR v_lng IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_zone
  FROM public.is_point_in_free_delivery_zone(v_lat, v_lng)
  LIMIT 1;

  IF NOT FOUND OR coalesce(v_zone.in_zone, false) = false THEN
    RETURN NEW;
  END IF;

  IF v_shadow_mode THEN
    INSERT INTO public.free_delivery_zone_audit (
      order_id,
      in_zone,
      zone_id,
      zone_name,
      shadow_mode,
      delivery_fee_before,
      delivery_fee_after,
      delivery_fee_discount_before,
      delivery_fee_discount_after,
      details
    )
    VALUES (
      NEW.id,
      true,
      v_zone.zone_id,
      v_zone.zone_name,
      true,
      v_old_delivery_fee,
      v_old_delivery_fee,
      v_old_delivery_fee_discount,
      v_old_delivery_fee_discount,
      jsonb_build_object('action', 'shadow_only', 'table', TG_TABLE_NAME, 'operation', TG_OP)
    );
    RETURN NEW;
  END IF;

  SELECT * INTO v_calc
  FROM public.apply_virtual_free_delivery_promo(
    NEW.subtotal,
    NEW.delivery_fee,
    NEW.original_delivery_fee,
    NEW.discount_amount,
    NEW.subtotal_discount,
    NEW.delivery_fee_discount,
    NEW.service_fee
  );

  NEW.original_delivery_fee := v_calc.out_original_delivery_fee;
  NEW.delivery_fee := v_calc.out_delivery_fee;
  NEW.delivery_fee_discount := v_calc.out_delivery_fee_discount;
  NEW.subtotal_discount := v_calc.out_subtotal_discount;
  NEW.discount_amount := v_calc.out_discount_amount;
  NEW.total_amount := v_calc.out_total_amount;
  NEW.delivery_fee_promo_applied := true;

  INSERT INTO public.free_delivery_zone_audit (
    order_id,
    in_zone,
    zone_id,
    zone_name,
    shadow_mode,
    delivery_fee_before,
    delivery_fee_after,
    delivery_fee_discount_before,
    delivery_fee_discount_after,
    details
  )
  VALUES (
    NEW.id,
    true,
    v_zone.zone_id,
    v_zone.zone_name,
    false,
    v_old_delivery_fee,
    NEW.delivery_fee,
    v_old_delivery_fee_discount,
    NEW.delivery_fee_discount,
    jsonb_build_object('action', 'applied_virtual_promo', 'table', TG_TABLE_NAME, 'operation', TG_OP)
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_orders_apply_free_delivery_zone ON public.orders;

CREATE TRIGGER trg_orders_apply_free_delivery_zone
BEFORE INSERT OR UPDATE OF delivery_address, delivery_fee, original_delivery_fee, discount_amount, subtotal_discount, delivery_fee_discount, subtotal, service_fee
ON public.orders
FOR EACH ROW
EXECUTE FUNCTION public.orders_apply_free_delivery_zone();

COMMIT;
