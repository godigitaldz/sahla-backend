-- =============================================================================
-- WEB ORDER service_fee / tax_amount FIX (v4)
--
-- Run verify first:
--   scripts/20260620060100_verify_web_order_financials.sql
--
-- v3 failed with 55006: ALTER TABLE DISABLE TRIGGER inside AFTER INSERT /
-- backfill loop (orders table locked by active query). v4 removes DISABLE TRIGGER;
-- uses plain UPDATE + web-skip on commission triggers + preserve trigger.
--
-- Flow after deploy:
--   Web checkout → create_public_web_order INSERT (source=web, snapshot totals)
--   → app BEFORE INSERT triggers skip web OR preserve runs late
--   → AFTER INSERT reconcile_web_order_financials (plain UPDATE from snapshot)
--   → persisted service_fee/tax_amount/net match pricing_snapshot
--   → driver Sahla line = commissionTax + delivery_tax + serviceFee - discounts
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) Patch calculate_order_service_fee (known 50% subtotal offender)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.calculate_order_service_fee()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
DECLARE
  v_service_fee_rate numeric(10, 4);
  v_calculated_service_fee numeric(10, 2);
BEGIN
  IF NEW.source IS NOT DISTINCT FROM 'web' THEN
    RETURN NEW;
  END IF;

  IF COALESCE(NEW.manual_phone_order, false)
     OR (NEW.parcel_sender_id IS NOT NULL AND NEW.restaurant_id IS NULL)
  THEN
    NEW.service_fee := 0;
    RETURN NEW;
  END IF;

  SELECT COALESCE((config_value::numeric), 0.05::numeric)
  INTO v_service_fee_rate
  FROM public.system_config
  WHERE config_key = 'service_fee'
    AND is_active = true
  ORDER BY updated_at DESC
  LIMIT 1;

  v_calculated_service_fee := COALESCE(NEW.subtotal, 0) * v_service_fee_rate;
  NEW.service_fee := ROUND(v_calculated_service_fee, 2);

  RETURN NEW;
END;
$function$;

-- ---------------------------------------------------------------------------
-- 2) Safe inject web skip on remaining commission trigger functions
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  r record;
  v_def text;
  v_new_def text;
  v_guard constant text :=
    E'  IF NEW.source IS NOT DISTINCT FROM ''web'' THEN\n    RETURN NEW;\n  END IF;\n\n';
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
      AND p.proname NOT IN (
        'calculate_order_service_fee',
        'trg_orders_preserve_web_tax',
        'trg_orders_after_reconcile_web_financials'
      )
      AND p.proname NOT LIKE '%preserve_web%'
      AND p.proname NOT LIKE '%reconcile_web%'
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

    v_new_def := regexp_replace(
      v_def,
      '(AS \$function\$\s*(?:DECLARE[\s\S]*?;[\s\r\n]*)?BEGIN[\s\r\n]+)(IF )',
      E'\\1' || v_guard || E'\\2',
      'n'
    );

    IF v_new_def = v_def THEN
      v_new_def := regexp_replace(
        v_def,
        '(AS \$\$[\s\r\n]+(?:DECLARE[\s\S]*?;[\s\r\n]*)?BEGIN[\s\r\n]+)(IF )',
        E'\\1' || v_guard || E'\\2',
        'n'
      );
    END IF;

    IF v_new_def = v_def THEN
      RAISE NOTICE 'skip % — could not find BEGIN+IF anchor', r.proname;
      CONTINUE;
    END IF;

    EXECUTE v_new_def;
    RAISE NOTICE 'patched orders trigger function % for web skip', r.proname;
  END LOOP;
END $$;

-- ---------------------------------------------------------------------------
-- 3) BEFORE preserve from pricing_snapshot (late name sorts near end)
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

  IF NEW.guest_phone IS NOT NULL AND trim(NEW.guest_phone) <> '' THEN
    NEW.guest_phone := public.normalize_web_guest_phone(NEW.guest_phone);
  END IF;

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
DROP TRIGGER IF EXISTS trg_orders_zzzzz_preserve_web_tax ON public.orders;
DROP TRIGGER IF EXISTS zzzzzzzzzzz_trg_orders_preserve_web_tax ON public.orders;

CREATE TRIGGER zzzzzzzzzzz_trg_orders_preserve_web_tax
  BEFORE INSERT OR UPDATE
  ON public.orders
  FOR EACH ROW
  WHEN (NEW.source = 'web')
  EXECUTE FUNCTION public.trg_orders_preserve_web_tax();

-- ---------------------------------------------------------------------------
-- 4) Post-insert reconcile — plain UPDATE only (no ALTER TABLE / DISABLE TRIGGER)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.reconcile_web_order_financials(p_order_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_service numeric := 0;
  v_tax numeric := 0;
  v_net numeric;
BEGIN
  SELECT
    round(coalesce((o.pricing_snapshot->'totals'->>'serviceFee')::numeric, 0), 2),
    round(coalesce((o.pricing_snapshot->'totals'->>'commissionTax')::numeric, 0), 2),
    round((o.pricing_snapshot->'totals'->>'net')::numeric, 2)
  INTO v_service, v_tax, v_net
  FROM public.orders o
  WHERE o.id = p_order_id
    AND o.source = 'web'
    AND o.pricing_snapshot ? 'totals';

  IF NOT FOUND THEN
    RETURN;
  END IF;

  UPDATE public.orders o
  SET
    service_fee = v_service,
    tax_amount = v_tax,
    net = coalesce(
      v_net,
      CASE
        WHEN o.fulfillment_type = 'pickup' THEN round(coalesce(o.total_amount, 0), 2)
        ELSE round(coalesce(o.total_amount, 0) - coalesce(o.delivery_fee, 0) - v_tax, 2)
      END
    ),
    manual_phone_order = false,
    updated_at = now()
  WHERE o.id = p_order_id
    AND o.source = 'web';
END;
$$;

REVOKE ALL ON FUNCTION public.reconcile_web_order_financials(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.reconcile_web_order_financials(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.trg_orders_after_reconcile_web_financials()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.reconcile_web_order_financials(NEW.id);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_orders_after_reconcile_web_financials ON public.orders;
DROP TRIGGER IF EXISTS zzzzzzzzzz_orders_after_reconcile_web_financials ON public.orders;

CREATE TRIGGER zzzzzzzzzz_orders_after_reconcile_web_financials
  AFTER INSERT
  ON public.orders
  FOR EACH ROW
  WHEN (NEW.source = 'web')
  EXECUTE FUNCTION public.trg_orders_after_reconcile_web_financials();

-- ---------------------------------------------------------------------------
-- 5) create_public_web_order (RPC path; AFTER INSERT trigger also reconciles)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_public_web_order(
  p_restaurant_slug text,
  p_fulfillment_type text,
  p_guest_phone text,
  p_guest_name text,
  p_delivery_address jsonb,
  p_pickup_address jsonb,
  p_special_instructions text,
  p_client_request_id uuid,
  p_payment_method text,
  p_subtotal numeric,
  p_original_delivery_fee numeric,
  p_delivery_fee numeric,
  p_delivery_tax numeric,
  p_net_delivery_amount numeric,
  p_commission_tax numeric,
  p_total_amount numeric,
  p_net numeric,
  p_pricing_snapshot jsonb,
  p_order_items jsonb
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_restaurant record;
  v_existing jsonb;
  v_customer_id uuid;
  v_order_id uuid;
  v_order_number text;
  v_public_code text;
  v_commission record;
  v_item jsonb;
  v_now timestamptz := now();
  v_eta_minutes int;
  v_estimated_delivery_at timestamptz;
BEGIN
  IF p_client_request_id IS NOT NULL THEN
    SELECT jsonb_build_object(
      'id', o.id,
      'public_order_code', o.public_order_code,
      'order_number', o.order_number,
      'total_amount', o.total_amount,
      'fulfillment_type', o.fulfillment_type,
      'restaurant_name', r.name,
      'estimated_delivery_time', coalesce(r.estimated_delivery_time, 30),
      'idempotent', true
    )
    INTO v_existing
    FROM public.orders o
    JOIN public.restaurants r ON r.id = o.restaurant_id
    WHERE o.client_request_id = p_client_request_id
    LIMIT 1;

    IF v_existing IS NOT NULL THEN
      RETURN v_existing;
    END IF;
  END IF;

  SELECT *
  INTO v_restaurant
  FROM public.restaurants r
  WHERE r.public_slug = public.normalize_restaurant_public_slug(p_restaurant_slug)
    AND r.is_verified = true
    AND r.is_public_web_enabled = true
  LIMIT 1;

  IF v_restaurant.id IS NULL THEN
    RAISE EXCEPTION 'restaurant_not_found';
  END IF;

  IF p_fulfillment_type NOT IN ('delivery', 'pickup') THEN
    RAISE EXCEPTION 'invalid_fulfillment_type';
  END IF;

  IF trim(coalesce(p_guest_phone, '')) = '' THEN
    RAISE EXCEPTION 'guest_phone_required';
  END IF;

  IF p_fulfillment_type = 'delivery' AND (
    p_delivery_address IS NULL
    OR p_delivery_address->>'latitude' IS NULL
    OR p_delivery_address->>'longitude' IS NULL
  ) THEN
    RAISE EXCEPTION 'delivery_address_required';
  END IF;

  v_customer_id := public.resolve_web_order_customer_id(p_guest_phone);
  IF v_customer_id IS NULL THEN
    RAISE EXCEPTION 'web_order_fallback_customer_id_missing';
  END IF;

  SELECT * INTO v_commission
  FROM public.resolve_web_order_commission_tax(
    p_subtotal,
    coalesce(v_restaurant.is_new, false),
    v_restaurant.web_order_commission_rate,
    v_restaurant.web_order_commission_cap_da
  );

  IF abs(coalesce(v_commission.tax_amount, 0) - coalesce(p_commission_tax, 0)) > 0.02 THEN
    RAISE EXCEPTION 'commission_tax_mismatch';
  END IF;

  v_order_number := public.generate_web_order_number(v_now);
  v_public_code := public.generate_web_public_order_code();
  v_eta_minutes := coalesce(v_restaurant.estimated_delivery_time, 30)::int;
  v_estimated_delivery_at := v_now + make_interval(mins => v_eta_minutes);

  INSERT INTO public.orders (
    restaurant_id,
    customer_id,
    order_number,
    public_order_code,
    client_request_id,
    source,
    status,
    payment_status,
    payment_method,
    fulfillment_type,
    subtotal,
    original_delivery_fee,
    delivery_fee,
    delivery_tax,
    net_delivery_amount,
    tax_amount,
    service_fee,
    total_amount,
    net,
    manual_phone_order,
    guest_phone,
    guest_name,
    delivery_address,
    pickup_address,
    special_instructions,
    pricing_snapshot,
    restaurant_slug_snapshot,
    estimated_delivery_time,
    created_at,
    updated_at
  ) VALUES (
    v_restaurant.id,
    v_customer_id,
    v_order_number,
    v_public_code,
    p_client_request_id,
    'web',
    'pending',
    'pending',
    coalesce(nullif(trim(p_payment_method), ''), 'cash'),
    p_fulfillment_type,
    round(p_subtotal::numeric, 2),
    round(coalesce(p_original_delivery_fee, 0)::numeric, 2),
    round(coalesce(p_delivery_fee, 0)::numeric, 2),
    round(coalesce(p_delivery_tax, 0)::numeric, 2),
    round(coalesce(p_net_delivery_amount, 0)::numeric, 2),
    round(coalesce(v_commission.tax_amount, 0)::numeric, 2),
    0,
    round(p_total_amount::numeric, 2),
    round(p_net::numeric, 2),
    false,
    trim(p_guest_phone),
    nullif(trim(coalesce(p_guest_name, '')), ''),
    coalesce(p_delivery_address, '{}'::jsonb),
    p_pickup_address,
    p_special_instructions,
    coalesce(p_pricing_snapshot, '{}'::jsonb),
    v_restaurant.public_slug,
    v_estimated_delivery_at,
    v_now,
    v_now
  )
  RETURNING id INTO v_order_id;

  IF p_order_items IS NULL OR jsonb_typeof(p_order_items) <> 'array' OR jsonb_array_length(p_order_items) = 0 THEN
    RAISE EXCEPTION 'order_items_required';
  END IF;

  FOR v_item IN SELECT value FROM jsonb_array_elements(p_order_items)
  LOOP
    IF (v_item->>'menu_item_id')::uuid IS NULL THEN
      RAISE EXCEPTION 'invalid_menu_item_id';
    END IF;

    IF NOT EXISTS (
      SELECT 1 FROM public.menu_items mi
      WHERE mi.id = (v_item->>'menu_item_id')::uuid
        AND mi.restaurant_id = v_restaurant.id
        AND mi.is_available = true
    ) THEN
      RAISE EXCEPTION 'menu_item_not_from_restaurant';
    END IF;

    INSERT INTO public.order_items (
      order_id,
      menu_item_id,
      quantity,
      unit_price,
      total_price,
      special_instructions,
      customizations,
      created_at
    ) VALUES (
      v_order_id,
      (v_item->>'menu_item_id')::uuid,
      greatest((v_item->>'quantity')::int, 1),
      round((v_item->>'unit_price')::numeric, 2),
      round((v_item->>'total_price')::numeric, 2),
      v_item->>'special_instructions',
      coalesce(v_item->'customizations', '{}'::jsonb),
      v_now
    );
  END LOOP;

  RETURN jsonb_build_object(
    'id', v_order_id,
    'public_order_code', v_public_code,
    'order_number', v_order_number,
    'total_amount', round(p_total_amount::numeric, 2),
    'fulfillment_type', p_fulfillment_type,
    'restaurant_name', v_restaurant.name,
    'estimated_delivery_time', v_eta_minutes,
    'idempotent', false
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_public_web_order TO service_role;

-- ---------------------------------------------------------------------------
-- 6) Backfill — single UPDATE (no loop, no ALTER TABLE)
-- ---------------------------------------------------------------------------
UPDATE public.orders o
SET
  service_fee = round(coalesce((o.pricing_snapshot->'totals'->>'serviceFee')::numeric, 0), 2),
  tax_amount = round(coalesce((o.pricing_snapshot->'totals'->>'commissionTax')::numeric, 0), 2),
  net = round(coalesce((o.pricing_snapshot->'totals'->>'net')::numeric, o.net), 2),
  manual_phone_order = false,
  updated_at = now()
WHERE o.source = 'web'
  AND o.pricing_snapshot ? 'totals'
  AND (
    abs(o.service_fee - coalesce((o.pricing_snapshot->'totals'->>'serviceFee')::numeric, 0)) > 0.02
    OR abs(o.tax_amount - coalesce((o.pricing_snapshot->'totals'->>'commissionTax')::numeric, 0)) > 0.02
    OR abs(o.net - coalesce((o.pricing_snapshot->'totals'->>'net')::numeric, 0)) > 0.02
  );

COMMIT;

NOTIFY pgrst, 'reload schema';

-- After commit, re-run:
--   scripts/20260620060100_verify_web_order_financials.sql (blocks 2b, 2c, 2d)
