-- Hardening v2: eliminate JSON casts in promo auto-apply predicate.
-- Fixes persistent:
--   22P02 invalid input syntax for type json (input string ended unexpectedly)
-- by avoiding p.conditions::json/jsonb casts inside WHERE.

BEGIN;

CREATE OR REPLACE FUNCTION public.orders_auto_apply_promo()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_promo record;
  v_orig numeric;
  v_base numeric;
  v_disc numeric;
  v_type text;
  v_now timestamptz := now();
  v_user_cnt int;
  v_per_user int;
  v_dt_rate numeric;
  v_dt_cap numeric;
  v_dt numeric;
  v_max_disc numeric;
BEGIN
  IF TG_OP <> 'INSERT' THEN
    RETURN NEW;
  END IF;

  IF NEW.applied_promo_code_id IS NOT NULL OR NEW.customer_id IS NULL THEN
    RETURN NEW;
  END IF;

  SELECT p.* INTO v_promo
  FROM public.promo_codes p
  WHERE p.status = 'active'
    AND (p.start_date IS NULL OR p.start_date <= v_now)
    AND (p.end_date IS NULL OR p.end_date >= v_now)
    AND (p.restaurant_id IS NULL OR p.restaurant_id = NEW.restaurant_id)
    AND (p.usage_limit IS NULL OR p.used_count IS NULL OR p.used_count < p.usage_limit)
    AND COALESCE(NEW.subtotal, 0) >= COALESCE(p.minimum_order_amount, 0)
    AND lower(replace(COALESCE(p.applies_to::text, 'subtotal'), '_', '')) = 'deliveryfee'
    AND (
      p.conditions IS NOT NULL
      AND lower(COALESCE(p.conditions::text, '')) ~ '"auto_apply"\\s*:\\s*(true|"true"|1|"1")'
    )
  ORDER BY p.minimum_order_amount DESC, p.created_at DESC
  LIMIT 1;

  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  SELECT count(*)::int INTO v_user_cnt
  FROM public.orders o
  WHERE o.customer_id = NEW.customer_id
    AND o.applied_promo_code_id = v_promo.id;

  v_per_user := COALESCE(v_promo.user_usage_limit, 1);
  IF v_per_user > 0 AND v_user_cnt >= v_per_user THEN
    RETURN NEW;
  END IF;

  v_orig := COALESCE(NEW.original_delivery_fee, NEW.delivery_fee, 0);
  v_base := COALESCE(NEW.delivery_fee, v_orig, 0);
  v_type := lower(replace(COALESCE(v_promo.type::text, 'percentage'), '_', ''));

  v_disc := 0;
  IF v_type = 'percentage' THEN
    v_disc := round(v_orig * (COALESCE(v_promo.value, 0) / 100.0), 2);
  ELSIF v_type IN ('fixedamount', 'fixed_amount') THEN
    v_disc := COALESCE(v_promo.value, 0);
  ELSIF v_type IN ('freedelivery', 'free_delivery') THEN
    v_disc := v_orig;
  END IF;

  v_max_disc := v_promo.maximum_discount_amount;
  IF v_max_disc IS NOT NULL AND v_max_disc > 0 AND v_disc > v_max_disc THEN
    v_disc := v_max_disc;
  END IF;
  IF v_disc > v_orig THEN
    v_disc := v_orig;
  END IF;
  IF v_disc <= 0 OR v_base <= 0 THEN
    RETURN NEW;
  END IF;
  IF v_disc > v_base THEN
    v_disc := v_base;
  END IF;

  v_disc := round(v_disc, 2);
  NEW.applied_promo_code_id := v_promo.id;
  NEW.applied_promo_code := v_promo.code;
  NEW.delivery_fee_promo_applied := true;
  NEW.delivery_fee_discount := v_disc;
  NEW.delivery_fee := round(GREATEST(0, v_base - v_disc), 2);
  NEW.discount_amount := round(COALESCE(NEW.subtotal_discount, 0) + v_disc, 2);

  v_dt_rate := public.system_config_numeric('delivery_tax', 0.05);
  v_dt_cap := public.system_config_numeric('delivery_tax_cap_da', 35);
  v_dt := round(v_orig * v_dt_rate, 2);
  IF v_dt > v_dt_cap THEN
    v_dt := v_dt_cap;
  END IF;
  NEW.delivery_tax := round(v_dt, 2);
  NEW.net_delivery_amount := round(v_orig - v_disc - NEW.delivery_tax, 2);
  NEW.total_amount := round(
    GREATEST(
      0,
      COALESCE(NEW.subtotal, 0)
      - COALESCE(NEW.subtotal_discount, 0)
      + NEW.delivery_fee
      + COALESCE(NEW.service_fee, 0)
    ),
    2
  );
  RETURN NEW;
END;
$$;

COMMIT;

