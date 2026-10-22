-- =============================================================================
-- WEB ORDER SUMMARY + PHONE FIX (v604)
--
-- Problem: manual_phone_order=true (60300) fixed dial but broke restaurant card
-- item summary (Flutter treats manual_phone_order as single aggregate line).
--
-- Fix:
--   1) manual_phone_order=false for source='web' → full order_items summary
--   2) ensure_web_order_customer_id() → customer_id profile.phone = guest_phone
--   3) Keep source='web' + pricing_snapshot preserve/reconcile (fees/tax unchanged)
--
-- Run after v4 fee fix. Supersedes 60300 manual_phone_order approach.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 0) Phone helpers (reuse normalize from 60300 if present)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.normalize_web_guest_phone(p_raw text)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
DECLARE
  v_phone text := trim(coalesce(p_raw, ''));
  v_digits text;
BEGIN
  IF v_phone = '' THEN
    RETURN '';
  END IF;

  v_phone := regexp_replace(v_phone, '\s+', '', 'g');

  IF v_phone LIKE '00213%' THEN
    v_phone := '+213' || substr(v_phone, 6);
  ELSIF v_phone LIKE '+2130%' THEN
    v_phone := '+213' || substr(v_phone, 6);
  ELSIF v_phone LIKE '2130%' THEN
    v_phone := '+213' || substr(v_phone, 5);
  ELSIF v_phone LIKE '213%' AND v_phone NOT LIKE '+%' THEN
    v_phone := '+' || v_phone;
  ELSIF v_phone LIKE '0%' AND length(v_phone) >= 10 THEN
    v_phone := '+213' || substr(v_phone, 2);
  ELSIF v_phone ~ '^[567][0-9]{8}$' THEN
    v_phone := '+213' || v_phone;
  ELSIF v_phone NOT LIKE '+%' AND length(v_phone) >= 9 THEN
    v_phone := '+213' || regexp_replace(v_phone, '^0+', '');
  END IF;

  v_digits := regexp_replace(v_phone, '\D', '', 'g');
  IF v_digits ~ '^213[567][0-9]{8}$' THEN
    RETURN '+' || v_digits;
  END IF;

  RETURN v_phone;
END;
$$;

CREATE OR REPLACE FUNCTION public.resolve_web_order_fallback_customer_id()
RETURNS uuid
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  v_fallback text;
  v_id uuid;
BEGIN
  SELECT coalesce(
    nullif(trim((
      SELECT w.config_value #>> '{}'
      FROM public.system_config w
      WHERE w.config_key = 'web_order_fallback_customer_id'
        AND w.is_active = true
      LIMIT 1
    )), ''),
    nullif(trim((
      SELECT m.config_value #>> '{}'
      FROM public.system_config m
      WHERE m.config_key = 'manual_order_fallback_customer_id'
        AND m.is_active = true
      LIMIT 1
    )), '')
  )
  INTO v_fallback;

  IF v_fallback IS NULL OR v_fallback = '' THEN
    RETURN NULL;
  END IF;

  IF v_fallback !~* '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
    RETURN NULL;
  END IF;

  SELECT up.id INTO v_id
  FROM public.user_profiles up
  WHERE up.id = v_fallback::uuid
  LIMIT 1;

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.find_user_profile_id_by_phone(p_phone text)
RETURNS uuid
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  v_phone text := public.normalize_web_guest_phone(p_phone);
  v_local text;
  v_digits text;
  v_id uuid;
BEGIN
  IF v_phone = '' THEN
    RETURN NULL;
  END IF;

  v_local := v_phone;
  IF v_local LIKE '+213%' THEN
    v_local := '0' || substr(v_local, 5);
  END IF;

  v_digits := regexp_replace(v_phone, '\D', '', 'g');
  IF v_digits LIKE '213%' AND length(v_digits) >= 12 THEN
    v_digits := substr(v_digits, 4);
  ELSIF v_digits LIKE '0%' THEN
    v_digits := substr(v_digits, 2);
  END IF;

  SELECT up.id INTO v_id
  FROM public.user_profiles up
  WHERE up.phone IS NOT NULL
    AND trim(up.phone) <> ''
    AND coalesce(up.is_deactivated, false) = false
    AND (
      trim(up.phone) = v_phone
      OR trim(up.phone) = v_local
      OR regexp_replace(trim(up.phone), '\D', '', 'g') = regexp_replace(v_phone, '\D', '', 'g')
      OR regexp_replace(trim(up.phone), '\D', '', 'g') = v_digits
      OR trim(up.phone) = ('+213' || v_digits)
      OR trim(up.phone) = ('0' || v_digits)
    )
  ORDER BY up.created_at DESC NULLS LAST
  LIMIT 1;

  RETURN v_id;
END;
$$;

-- Stable map phone → profile (avoids duplicate auth rows on concurrent web orders)
CREATE TABLE IF NOT EXISTS public.web_order_guest_identity (
  phone_e164 text PRIMARY KEY,
  user_profile_id uuid NOT NULL REFERENCES public.user_profiles(id) ON DELETE CASCADE,
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX IF NOT EXISTS web_order_guest_identity_user_profile_id_uidx
  ON public.web_order_guest_identity (user_profile_id);

COMMENT ON TABLE public.web_order_guest_identity IS
  'Maps normalized web checkout phone to user_profiles.id for dial + order summary (no manual_phone_order).';

-- ---------------------------------------------------------------------------
-- 1) Find or create customer profile whose phone matches checkout input
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.ensure_web_order_customer_id(
  p_guest_phone text,
  p_guest_name text DEFAULT NULL
)
RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions
AS $$
DECLARE
  v_phone text;
  v_id uuid;
  v_name text;
  v_email text;
  v_instance_id uuid;
BEGIN
  v_phone := public.normalize_web_guest_phone(p_guest_phone);
  IF v_phone = '' THEN
    RETURN public.resolve_web_order_fallback_customer_id();
  END IF;

  v_name := nullif(trim(coalesce(p_guest_name, '')), '');
  IF v_name IS NULL THEN
    v_name := 'Web Guest';
  END IF;

  SELECT w.user_profile_id INTO v_id
  FROM public.web_order_guest_identity w
  WHERE w.phone_e164 = v_phone;

  IF v_id IS NOT NULL THEN
    RETURN v_id;
  END IF;

  v_id := public.find_user_profile_id_by_phone(v_phone);
  IF v_id IS NOT NULL THEN
    INSERT INTO public.web_order_guest_identity (phone_e164, user_profile_id)
    VALUES (v_phone, v_id)
    ON CONFLICT (phone_e164) DO UPDATE
      SET user_profile_id = EXCLUDED.user_profile_id
    RETURNING user_profile_id INTO v_id;
    RETURN v_id;
  END IF;

  v_id := gen_random_uuid();
  v_email := replace(v_id::text, '-', '') || '@webguest.sahla.internal';

  SELECT i.id INTO v_instance_id FROM auth.instances i LIMIT 1;
  IF v_instance_id IS NULL THEN
    v_instance_id := '00000000-0000-0000-0000-000000000000'::uuid;
  END IF;

  BEGIN
    INSERT INTO auth.users (
      instance_id,
      id,
      aud,
      role,
      email,
      encrypted_password,
      email_confirmed_at,
      phone,
      phone_confirmed_at,
      raw_app_meta_data,
      raw_user_meta_data,
      created_at,
      updated_at,
      is_anonymous
    ) VALUES (
      v_instance_id,
      v_id,
      'authenticated',
      'authenticated',
      v_email,
      extensions.crypt(gen_random_uuid()::text, extensions.gen_salt('bf')),
      now(),
      v_phone,
      now(),
      jsonb_build_object('provider', 'web_guest', 'providers', jsonb_build_array('web_guest')),
      jsonb_build_object('phone', v_phone, 'name', v_name, 'web_guest', true),
      now(),
      now(),
      true
    );
  EXCEPTION
    WHEN unique_violation THEN
      v_id := public.find_user_profile_id_by_phone(v_phone);
      IF v_id IS NOT NULL THEN
        INSERT INTO public.web_order_guest_identity (phone_e164, user_profile_id)
        VALUES (v_phone, v_id)
        ON CONFLICT (phone_e164) DO NOTHING;
        RETURN v_id;
      END IF;
      RAISE;
  END;

  BEGIN
    INSERT INTO auth.identities (
      id,
      user_id,
      provider_id,
      identity_data,
      provider,
      last_sign_in_at,
      created_at,
      updated_at
    ) VALUES (
      gen_random_uuid(),
      v_id,
      v_id::text,
      jsonb_build_object('sub', v_id::text, 'phone', v_phone),
      'phone',
      now(),
      now(),
      now()
    );
  EXCEPTION
    WHEN undefined_column OR undefined_table THEN
      NULL;
    WHEN OTHERS THEN
      NULL;
  END;

  INSERT INTO public.user_profiles (
    id,
    role,
    is_verified,
    phone,
    name,
    language_preference,
    created_at,
    updated_at
  ) VALUES (
    v_id,
    'customer',
    true,
    v_phone,
    v_name,
    'ar',
    now(),
    now()
  )
  ON CONFLICT (id) DO UPDATE SET
    phone = EXCLUDED.phone,
    name = CASE
      WHEN trim(coalesce(public.user_profiles.name, '')) = '' THEN EXCLUDED.name
      ELSE public.user_profiles.name
    END,
    updated_at = now();

  INSERT INTO public.web_order_guest_identity (phone_e164, user_profile_id)
  VALUES (v_phone, v_id)
  ON CONFLICT (phone_e164) DO UPDATE
    SET user_profile_id = EXCLUDED.user_profile_id;

  RETURN v_id;
END;
$$;

CREATE OR REPLACE FUNCTION public.resolve_web_order_customer_id(p_guest_phone text)
RETURNS uuid
LANGUAGE sql
STABLE
SET search_path = public
AS $$
  SELECT public.ensure_web_order_customer_id(p_guest_phone, NULL);
$$;

REVOKE ALL ON FUNCTION public.ensure_web_order_customer_id(text, text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.resolve_web_order_fallback_customer_id() FROM PUBLIC;
REVOKE ALL ON FUNCTION public.find_user_profile_id_by_phone(text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.ensure_web_order_customer_id(text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.resolve_web_order_customer_id(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.resolve_web_order_fallback_customer_id() TO service_role;
GRANT EXECUTE ON FUNCTION public.find_user_profile_id_by_phone(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.normalize_web_guest_phone(text) TO service_role;

-- ---------------------------------------------------------------------------
-- 2) Web preserve: fees from snapshot; manual_phone_order stays false
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
    guest_phone = public.normalize_web_guest_phone(o.guest_phone),
    updated_at = now()
  WHERE o.id = p_order_id
    AND o.source = 'web';
END;
$$;

-- ---------------------------------------------------------------------------
-- 3) create_public_web_order — ensure profile phone + manual_phone_order=false
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
  v_guest_phone text;
  v_guest_name text;
BEGIN
  v_guest_phone := public.normalize_web_guest_phone(p_guest_phone);
  v_guest_name := nullif(trim(coalesce(p_guest_name, '')), '');

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

  IF trim(coalesce(v_guest_phone, '')) = '' THEN
    RAISE EXCEPTION 'guest_phone_required';
  END IF;

  IF p_fulfillment_type = 'delivery' AND (
    p_delivery_address IS NULL
    OR p_delivery_address->>'latitude' IS NULL
    OR p_delivery_address->>'longitude' IS NULL
  ) THEN
    RAISE EXCEPTION 'delivery_address_required';
  END IF;

  v_customer_id := public.ensure_web_order_customer_id(v_guest_phone, v_guest_name);
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
    v_guest_phone,
    v_guest_name,
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
-- 4) Backfill existing web orders
-- ---------------------------------------------------------------------------
DO $$
DECLARE
  r record;
  v_customer_id uuid;
BEGIN
  FOR r IN
    SELECT o.id, o.guest_phone, o.guest_name
    FROM public.orders o
    WHERE o.source = 'web'
      AND coalesce(o.guest_phone, '') <> ''
  LOOP
    v_customer_id := public.ensure_web_order_customer_id(r.guest_phone, r.guest_name);

    UPDATE public.orders o
    SET
      customer_id = coalesce(v_customer_id, o.customer_id),
      manual_phone_order = false,
      guest_phone = public.normalize_web_guest_phone(r.guest_phone),
      updated_at = now()
    WHERE o.id = r.id;
  END LOOP;
END $$;

COMMIT;

NOTIFY pgrst, 'reload schema';

-- =============================================================================
-- VERIFY (run after fix)
-- =============================================================================

-- V1) Summary: web orders must NOT be manual_phone_order
-- SELECT count(*) FROM orders WHERE source='web' AND manual_phone_order IS TRUE;

-- V2) Phone: profile phone matches guest_phone (app dials user_profiles.phone)
-- SELECT
--   o.public_order_code,
--   o.manual_phone_order,
--   o.guest_phone,
--   up.phone AS profile_phone,
--   up.name AS profile_name,
--   (SELECT count(*) FROM order_items oi WHERE oi.order_id = o.id) AS item_count
-- FROM orders o
-- JOIN user_profiles up ON up.id = o.customer_id
-- WHERE o.public_order_code = 'W-000014';

-- V3) Fees unchanged vs snapshot
-- SELECT public_order_code, service_fee, tax_amount,
--        pricing_snapshot->'totals' AS expected
-- FROM orders WHERE source='web' ORDER BY created_at DESC LIMIT 5;

-- V4) Guest identity map
-- SELECT * FROM web_order_guest_identity ORDER BY created_at DESC LIMIT 10;
