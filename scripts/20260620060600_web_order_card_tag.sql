-- =============================================================================
-- WEB ORDER CARD TAG (v606) — SQL-only special marker on restaurant cards
--
-- Flutter partner app shows order-level notes when special_instructions is set.
-- Prefix every web order with:  طلب ويب (W-000019)
--
--   1) format_web_order_card_special_instructions() — build tagged notes
--   2) create_public_web_order — tag on insert (customer notes preserved below)
--   3) Backfill all existing source='web' orders (idempotent)
--
-- Run after v605. No Flutter / web deploy required to verify on existing orders.
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- 1) Helpers
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.web_order_card_tag_is_present(p_notes text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
SET search_path = public
AS $$
  SELECT coalesce(
    nullif(trim(coalesce(p_notes, '')), '') ~* '^\s*طلب ويب\s*\('
    OR nullif(trim(coalesce(p_notes, '')), '') ~* '^\s*Web order\s*\(',
    false
  );
$$;

CREATE OR REPLACE FUNCTION public.format_web_order_card_special_instructions(
  p_public_order_code text,
  p_customer_notes text DEFAULT NULL
)
RETURNS text
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public
AS $$
DECLARE
  v_code text := nullif(trim(coalesce(p_public_order_code, '')), '');
  v_tag text;
  v_notes text := nullif(trim(coalesce(p_customer_notes, '')), '');
BEGIN
  IF public.web_order_card_tag_is_present(v_notes) THEN
    RETURN v_notes;
  END IF;

  v_tag := 'طلب ويب (' || coalesce(v_code, 'Web') || ')';

  IF v_notes IS NULL THEN
    RETURN v_tag;
  END IF;

  RETURN v_tag || E'\n' || v_notes;
END;
$$;

-- ---------------------------------------------------------------------------
-- 2) create_public_web_order — tag special_instructions for partner card
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
  v_special_instructions text;
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
  v_special_instructions := public.format_web_order_card_special_instructions(
    v_public_code,
    p_special_instructions
  );

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
    v_special_instructions,
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
      public.normalize_web_order_item_customizations(
        coalesce(v_item->'customizations', '{}'::jsonb)
      ),
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
-- 3) Backfill existing web orders (idempotent)
-- ---------------------------------------------------------------------------
UPDATE public.orders o
SET
  special_instructions = public.format_web_order_card_special_instructions(
    o.public_order_code,
    o.special_instructions
  ),
  updated_at = now()
WHERE o.source = 'web'
  AND NOT public.web_order_card_tag_is_present(o.special_instructions);

COMMIT;

NOTIFY pgrst, 'reload schema';

-- =============================================================================
-- VERIFY (run after fix — no new order needed)
-- =============================================================================

-- V1) W-000019 should show tag + original customer notes
-- SELECT
--   public_order_code,
--   order_number,
--   special_instructions
-- FROM public.orders
-- WHERE public_order_code = 'W-000019';

-- V2) All web orders tagged
-- SELECT count(*) AS untagged
-- FROM public.orders
-- WHERE source = 'web'
--   AND NOT public.web_order_card_tag_is_present(special_instructions);

-- V3) Helper smoke test
-- SELECT public.format_web_order_card_special_instructions(
--   'W-000019',
--   'asdasdasdasdasd'
-- );
