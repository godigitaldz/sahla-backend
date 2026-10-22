-- =============================================================================
-- TABLE ORDERING — create_public_table_order + financial trigger patches
-- Run after 20260622140000_table_ordering_schema.sql
-- =============================================================================

BEGIN;

-- ---------------------------------------------------------------------------
-- Patch preserve web tax trigger for web_table + table fulfillment
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
  IF NEW.source IS DISTINCT FROM 'web' AND NEW.source IS DISTINCT FROM 'web_table' THEN
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
    ELSIF NEW.fulfillment_type IN ('pickup', 'table') THEN
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

    IF NEW.fulfillment_type IN ('pickup', 'table') THEN
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

  IF NEW.fulfillment_type IN ('pickup', 'table') THEN
    NEW.delivery_fee := 0;
    NEW.original_delivery_fee := 0;
    NEW.delivery_tax := 0;
    NEW.net_delivery_amount := 0;
  END IF;

  IF NEW.fulfillment_type = 'table' THEN
    NEW.dispatch_active := false;
    NEW.dispatch_next_run_at := NULL;
    NEW.delivery_person_id := NULL;
  END IF;

  RETURN NEW;
END;
$$;

-- ---------------------------------------------------------------------------
-- create_public_table_order — session-derived restaurant/table only
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_public_table_order(
  p_session_token_hash bytea,
  p_guest_phone text,
  p_guest_name text,
  p_special_instructions text,
  p_client_request_id uuid,
  p_payment_method text,
  p_subtotal numeric,
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
  v_session record;
  v_restaurant record;
  v_table record;
  v_existing jsonb;
  v_customer_id uuid;
  v_order_id uuid;
  v_order_number text;
  v_public_code text;
  v_commission record;
  v_item jsonb;
  v_now timestamptz := now();
  v_guest_phone text;
  v_guest_name text;
  v_special_instructions text;
  v_updated int;
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
      'table_number', rt.table_number,
      'estimated_delivery_time', null,
      'idempotent', true
    )
    INTO v_existing
    FROM public.orders o
    JOIN public.restaurants r ON r.id = o.restaurant_id
    LEFT JOIN public.restaurant_tables rt ON rt.id = o.table_id
    WHERE o.client_request_id = p_client_request_id
    LIMIT 1;

    IF v_existing IS NOT NULL THEN
      RETURN v_existing;
    END IF;
  END IF;

  SELECT
    s.id AS session_id,
    s.expires_at,
    s.revoked_at,
    s.restaurant_table_id
  INTO v_session
  FROM public.table_order_sessions s
  JOIN public.restaurant_table_codes tc ON tc.id = s.table_code_id
  WHERE s.session_token_hash = p_session_token_hash
  LIMIT 1
  FOR UPDATE OF s;

  IF v_session.session_id IS NULL THEN
    RAISE EXCEPTION 'invalid_session';
  END IF;

  IF v_session.revoked_at IS NOT NULL OR v_session.expires_at <= v_now THEN
    RAISE EXCEPTION 'session_expired';
  END IF;

  UPDATE public.table_order_sessions
  SET last_activity_at = v_now
  WHERE id = v_session.session_id;

  SELECT rt.id, rt.table_number, rt.table_label, rt.restaurant_id
  INTO v_table
  FROM public.restaurant_tables rt
  WHERE rt.id = v_session.restaurant_table_id
    AND rt.deleted_at IS NULL
    AND rt.is_active = true
  LIMIT 1;

  IF v_table.id IS NULL THEN
    RAISE EXCEPTION 'table_not_found';
  END IF;

  SELECT r.*
  INTO v_restaurant
  FROM public.restaurants r
  WHERE r.id = v_table.restaurant_id
  LIMIT 1;

  IF NOT v_restaurant.table_ordering_enabled OR NOT v_restaurant.is_verified OR NOT v_restaurant.is_public_web_enabled THEN
    RAISE EXCEPTION 'table_ordering_disabled';
  END IF;

  IF trim(coalesce(v_guest_phone, '')) = '' THEN
    RAISE EXCEPTION 'guest_phone_required';
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

  v_customer_id := public.ensure_web_order_customer_id(v_guest_phone, v_guest_name);
  IF v_customer_id IS NULL THEN
    RAISE EXCEPTION 'web_order_fallback_customer_id_missing';
  END IF;

  v_order_number := public.generate_web_order_number(v_now);
  v_public_code := public.generate_web_public_order_code();
  v_special_instructions := public.format_table_order_card_special_instructions(
    v_table.table_number,
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
    table_id,
    table_session_id,
    dispatch_active,
    created_at,
    updated_at
  ) VALUES (
    v_table.restaurant_id,
    v_customer_id,
    v_order_number,
    v_public_code,
    p_client_request_id,
    'web_table',
    'pending',
    'pending',
    coalesce(nullif(trim(p_payment_method), ''), 'cash'),
    'table',
    round(p_subtotal::numeric, 2),
    0,
    0,
    0,
    0,
    round(coalesce(v_commission.tax_amount, 0)::numeric, 2),
    0,
    round(p_total_amount::numeric, 2),
    round(p_net::numeric, 2),
    false,
    v_guest_phone,
    v_guest_name,
    '{}'::jsonb,
    NULL,
    v_special_instructions,
    coalesce(p_pricing_snapshot, '{}'::jsonb),
    v_restaurant.public_slug,
    v_table.id,
    v_session.session_id,
    false,
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
        AND mi.restaurant_id = v_table.restaurant_id
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
    'fulfillment_type', 'table',
    'restaurant_name', v_restaurant.name,
    'table_number', v_table.table_number,
    'table_label', v_table.table_label,
    'estimated_delivery_time', null,
    'idempotent', false
  );
END;
$$;

REVOKE ALL ON FUNCTION public.create_public_table_order(bytea, text, text, text, uuid, text, numeric, numeric, numeric, numeric, jsonb, jsonb) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.create_public_table_order(bytea, text, text, text, uuid, text, numeric, numeric, numeric, numeric, jsonb, jsonb) TO service_role;

-- Partner venue code display (staff auth via service role API)
CREATE OR REPLACE FUNCTION public.get_restaurant_venue_code_for_staff(p_restaurant_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_row record;
BEGIN
  SELECT w.window_start, w.window_end, w.version
  INTO v_row
  FROM public.restaurant_venue_code_windows w
  WHERE w.restaurant_id = p_restaurant_id
    AND w.window_start <= now()
    AND w.window_end > now()
  ORDER BY w.window_end DESC
  LIMIT 1;

  IF v_row.window_end IS NULL THEN
    RETURN jsonb_build_object('status', 'no_active_window');
  END IF;

  -- Code plaintext is NOT stored; API layer must have cached it at rotation
  -- or rotate on-demand. Return window metadata only.
  RETURN jsonb_build_object(
    'status', 'active',
    'window_start', v_row.window_start,
    'window_end', v_row.window_end,
    'version', v_row.version,
    'seconds_remaining', greatest(0, extract(epoch from (v_row.window_end - now()))::int)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.get_restaurant_venue_code_for_staff(uuid) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_restaurant_venue_code_for_staff(uuid) TO service_role;

-- Store plaintext venue code only in Redis at rotation time; DB keeps hash only.
-- Admin regenerate returns plaintext once via API.

COMMIT;

NOTIFY pgrst, 'reload schema';
