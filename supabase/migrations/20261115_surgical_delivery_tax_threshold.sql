-- =============================================================================
-- Migration: Surgical Delivery Tax Threshold (<= 180 DA = 0% Tax)
-- Author: Sahla Systems Engineering
-- Date: 2026-11-15
-- Target Function: public.orders_compute_delivery_settlement
-- Invariant: v_orig <= 180 DA -> delivery_tax = 0.00 DA
-- =============================================================================

BEGIN;

-- -----------------------------------------------------------------------------
-- Step 1: Idempotently seed system_config if missing
-- -----------------------------------------------------------------------------
INSERT INTO public.system_config (
  config_key,
  config_value,
  config_type,
  category,
  description,
  is_active
)
VALUES (
  'delivery_tax_free_threshold_da',
  '180'::jsonb,
  'number',
  'fees',
  'Original delivery tariff threshold in DA (<= threshold qualifies for 0% delivery tax)',
  true
)
ON CONFLICT (config_key) DO UPDATE
SET config_value = COALESCE(public.system_config.config_value, '180'::jsonb),
    is_active = true,
    updated_at = now();

-- -----------------------------------------------------------------------------
-- Step 2: Replace orders_compute_delivery_settlement with authoritative policy
-- -----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.orders_compute_delivery_settlement(
  p_delivery_fee numeric,
  p_original_delivery_fee numeric,
  p_delivery_fee_discount numeric,
  p_delivery_fee_promo_applied boolean,
  p_delivery_tax numeric DEFAULT NULL::numeric
)
RETURNS TABLE(delivery_tax numeric, net_delivery_amount numeric)
LANGUAGE plpgsql
STABLE
SET search_path TO 'public'
AS $function$
DECLARE
  v_orig numeric := round(greatest(coalesce(p_original_delivery_fee, p_delivery_fee, 0), 0)::numeric, 2);
  v_fee numeric := round(greatest(coalesce(p_delivery_fee, 0), 0)::numeric, 2);
  v_disc numeric := round(greatest(coalesce(p_delivery_fee_discount, 0), 0)::numeric, 2);
  v_promo boolean := coalesce(p_delivery_fee_promo_applied, false) AND v_disc > 0;
  v_threshold numeric;
  v_dt_rate numeric;
  v_dt_cap numeric;
  v_base numeric;
  v_dt numeric;
BEGIN
  -- Read configuration dynamically with existing defaults preserved
  v_threshold := public.system_config_numeric('delivery_tax_free_threshold_da', 180);
  v_dt_rate := public.system_config_numeric('delivery_tax', 0.15);
  v_dt_cap := public.system_config_numeric('delivery_tax_cap_da', 100);

  -- Existing tax base semantics preserved: promotional uses v_orig, non-promo uses v_fee
  v_base := CASE
    WHEN v_promo THEN v_orig
    ELSE v_fee
  END;

  -- ---------------------------------------------------------------------------
  -- PRIORITY 1 — Threshold Exemption
  -- Evaluated strictly against v_orig (original tariff before discounts).
  -- Takes precedence over explicit positive tax.
  -- ---------------------------------------------------------------------------
  IF v_orig <= v_threshold THEN
    v_dt := 0.00;

  -- ---------------------------------------------------------------------------
  -- PRIORITY 2 — Preserve Explicit Positive Tax
  -- Applies only when original tariff > threshold and not promotional.
  -- ---------------------------------------------------------------------------
  ELSIF p_delivery_tax IS NOT NULL
        AND p_delivery_tax > 0
        AND NOT v_promo THEN
    v_dt := round(p_delivery_tax::numeric, 2);

  -- ---------------------------------------------------------------------------
  -- PRIORITY 3 — Standard Existing Tax Calculation
  -- ---------------------------------------------------------------------------
  ELSE
    v_dt := round((v_base * v_dt_rate)::numeric, 2);
    IF v_dt > v_dt_cap THEN
      v_dt := v_dt_cap;
    END IF;
    v_dt := round(v_dt, 2);
  END IF;

  delivery_tax := v_dt;

  -- Existing net delivery amount calculation preserved
  net_delivery_amount := round(
    (
      CASE
        WHEN v_promo THEN v_orig
        ELSE v_fee
      END - v_dt
    )::numeric,
    2
  );

  RETURN NEXT;
END;
$function$;

COMMIT;
