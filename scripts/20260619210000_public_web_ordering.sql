-- Public web restaurant ordering: slug, order columns, config, RPC, RLS, trigger guard.
-- Idempotent; safe to re-run.

BEGIN;

CREATE EXTENSION IF NOT EXISTS unaccent;

-- ---------------------------------------------------------------------------
-- Restaurants: public slug + web commission overrides
-- ---------------------------------------------------------------------------
ALTER TABLE public.restaurants
  ADD COLUMN IF NOT EXISTS public_slug text,
  ADD COLUMN IF NOT EXISTS is_public_web_enabled boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS web_order_commission_rate numeric,
  ADD COLUMN IF NOT EXISTS web_order_commission_cap_da numeric;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'restaurants_public_slug_format_chk'
  ) THEN
    ALTER TABLE public.restaurants
      ADD CONSTRAINT restaurants_public_slug_format_chk
      CHECK (
        public_slug IS NULL
        OR public_slug ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
      );
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS restaurants_public_slug_unique_idx
  ON public.restaurants (public_slug)
  WHERE public_slug IS NOT NULL;

CREATE OR REPLACE FUNCTION public.normalize_restaurant_public_slug(input text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT NULLIF(
    trim(both '-' FROM regexp_replace(
      lower(unaccent(coalesce(input, ''))),
      '[^a-z0-9]+', '-', 'g'
    )),
    ''
  );
$$;

CREATE OR REPLACE FUNCTION public.trg_restaurants_normalize_public_slug()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.public_slug IS NOT NULL THEN
    NEW.public_slug := public.normalize_restaurant_public_slug(NEW.public_slug);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_restaurants_normalize_public_slug ON public.restaurants;
CREATE TRIGGER trg_restaurants_normalize_public_slug
  BEFORE INSERT OR UPDATE OF public_slug ON public.restaurants
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_restaurants_normalize_public_slug();

-- ---------------------------------------------------------------------------
-- Orders: web metadata
-- ---------------------------------------------------------------------------
ALTER TABLE public.orders
  ADD COLUMN IF NOT EXISTS source text NOT NULL DEFAULT 'app',
  ADD COLUMN IF NOT EXISTS public_order_code text,
  ADD COLUMN IF NOT EXISTS client_request_id uuid,
  ADD COLUMN IF NOT EXISTS pricing_snapshot jsonb NOT NULL DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS restaurant_slug_snapshot text,
  ADD COLUMN IF NOT EXISTS guest_name text;

CREATE UNIQUE INDEX IF NOT EXISTS orders_client_request_id_uidx
  ON public.orders (client_request_id)
  WHERE client_request_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS orders_public_order_code_uidx
  ON public.orders (public_order_code)
  WHERE public_order_code IS NOT NULL;

CREATE SEQUENCE IF NOT EXISTS public.web_order_code_seq;

-- ---------------------------------------------------------------------------
-- system_config seeds (web commission defaults = 0)
-- ---------------------------------------------------------------------------
INSERT INTO public.system_config (config_key, config_value, config_type, category, is_active, description)
VALUES
  ('web_order_commission_rate', '0'::json, 'number', 'web_orders', true, 'Commission rate on subtotal for source=web orders'),
  ('web_order_commission_cap_da', '0'::json, 'number', 'web_orders', true, 'Cap (DA) on web order commission tax'),
  ('web_order_new_restaurant_commission_rate', '0'::json, 'number', 'web_orders', true, 'Web commission rate when restaurants.is_new=true'),
  ('web_order_new_restaurant_commission_cap_da', '0'::json, 'number', 'web_orders', true, 'Web commission cap (DA) for new restaurants'),
  ('web_order_fallback_customer_id', '""'::json, 'string', 'web_orders', true, 'Fallback user_profiles.id for guest web orders')
ON CONFLICT (config_key) DO NOTHING;

-- Mirror manual fallback when web fallback empty
UPDATE public.system_config w
SET config_value = m.config_value
FROM public.system_config m
WHERE w.config_key = 'web_order_fallback_customer_id'
  AND m.config_key = 'manual_order_fallback_customer_id'
  AND coalesce(nullif(trim(w.config_value #>> '{}'), ''), '') = ''
  AND coalesce(nullif(trim(m.config_value #>> '{}'), ''), '') <> '';

-- ---------------------------------------------------------------------------
-- Config helpers
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.system_config_numeric(p_key text, p_default numeric DEFAULT 0)
RETURNS numeric
LANGUAGE sql
STABLE
AS $$
  SELECT coalesce(
    (
      SELECT nullif(trim(sc.config_value #>> '{}'), '')::numeric
      FROM public.system_config sc
      WHERE sc.config_key = p_key
        AND sc.is_active = true
      LIMIT 1
    ),
    p_default
  );
$$;

CREATE OR REPLACE FUNCTION public.resolve_web_order_commission_tax(
  p_subtotal numeric,
  p_is_new boolean,
  p_restaurant_rate numeric,
  p_restaurant_cap numeric
)
RETURNS TABLE(tax_amount numeric, rate_used numeric, cap_used numeric, config_source text)
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_rate numeric;
  v_cap numeric;
  v_tax numeric;
BEGIN
  IF p_restaurant_rate IS NOT NULL THEN
    v_rate := p_restaurant_rate;
    v_cap := coalesce(p_restaurant_cap, 0);
    config_source := 'restaurant_override';
  ELSIF p_is_new THEN
    v_rate := public.system_config_numeric('web_order_new_restaurant_commission_rate', 0);
    v_cap := public.system_config_numeric('web_order_new_restaurant_commission_cap_da', 0);
    config_source := 'system_config_new';
  ELSE
    v_rate := public.system_config_numeric('web_order_commission_rate', 0);
    v_cap := public.system_config_numeric('web_order_commission_cap_da', 0);
    config_source := 'system_config';
  END IF;

  v_tax := round((greatest(p_subtotal, 0) * greatest(v_rate, 0))::numeric, 2);
  IF v_cap > 0 AND v_tax > v_cap THEN
    v_tax := v_cap;
  END IF;

  tax_amount := v_tax;
  rate_used := v_rate;
  cap_used := v_cap;
  RETURN NEXT;
END;
$$;

CREATE OR REPLACE FUNCTION public.resolve_web_order_customer_id(p_guest_phone text)
RETURNS uuid
LANGUAGE plpgsql
STABLE
SET search_path = public
AS $$
DECLARE
  v_phone text := trim(coalesce(p_guest_phone, ''));
  v_id uuid;
  v_fallback text;
  v_local text;
  v_digits text;
BEGIN
  IF v_phone <> '' THEN
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
      AND (
        trim(up.phone) = v_phone
        OR trim(up.phone) = v_local
        OR regexp_replace(trim(up.phone), '\D', '', 'g') = regexp_replace(v_phone, '\D', '', 'g')
        OR regexp_replace(trim(up.phone), '\D', '', 'g') = v_digits
        OR trim(up.phone) = ('+213' || v_digits)
        OR trim(up.phone) = ('0' || v_digits)
      )
    LIMIT 1;

    IF v_id IS NOT NULL THEN
      RETURN v_id;
    END IF;
  END IF;

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

-- Match Flutter OrderService._generateOrderNumber(): ORD-{last5EpochMs}{3Random} (12 chars, fits varchar(20)).
CREATE OR REPLACE FUNCTION public.generate_web_order_number(p_at timestamptz DEFAULT now())
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  v_ms_text text;
BEGIN
  v_ms_text := floor(extract(epoch FROM p_at) * 1000)::bigint::text;
  RETURN 'ORD-' ||
    substr(v_ms_text, greatest(length(v_ms_text) - 4, 1)) ||
    lpad(floor(random() * 1000)::int::text, 3, '0');
END;
$$;

CREATE OR REPLACE FUNCTION public.generate_web_public_order_code()
RETURNS text
LANGUAGE plpgsql
AS $$
DECLARE
  v_code text;
  v_attempt int := 0;
BEGIN
  LOOP
    v_attempt := v_attempt + 1;
    v_code := 'W-' || lpad(nextval('public.web_order_code_seq')::text, 6, '0');
    IF NOT EXISTS (
      SELECT 1 FROM public.orders o WHERE o.public_order_code = v_code
    ) THEN
      RETURN v_code;
    END IF;
    IF v_attempt >= 5 THEN
      RAISE EXCEPTION 'public_order_code_generation_failed';
    END IF;
  END LOOP;
END;
$$;

-- ---------------------------------------------------------------------------
-- Trigger guard: preserve web commission tax (runs LAST on insert/update)
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
BEGIN
  IF NEW.source IS DISTINCT FROM 'web' THEN
    RETURN NEW;
  END IF;

  NEW.service_fee := 0;
  NEW.manual_phone_order := false;

  IF NEW.fulfillment_type = 'pickup' THEN
    NEW.delivery_fee := 0;
    NEW.original_delivery_fee := 0;
    NEW.delivery_tax := 0;
    NEW.net_delivery_amount := 0;
  END IF;

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

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_orders_preserve_web_tax ON public.orders;
DROP TRIGGER IF EXISTS trg_orders_zz_preserve_web_tax ON public.orders;
CREATE TRIGGER trg_orders_zz_preserve_web_tax
  BEFORE INSERT OR UPDATE
  ON public.orders
  FOR EACH ROW
  WHEN (NEW.source = 'web')
  EXECUTE FUNCTION public.trg_orders_preserve_web_tax();

-- ---------------------------------------------------------------------------
-- Public read: restaurant by slug (SECURITY DEFINER)
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.get_public_restaurant_by_slug(p_slug text)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_slug text := public.normalize_restaurant_public_slug(p_slug);
  v_row jsonb;
BEGIN
  SELECT jsonb_build_object(
    'id', r.id,
    'name', r.name,
    'name_ar', r.name_ar,
    'name_latin', r.name_latin,
    'description', r.description,
    'logo_url', r.logo_url,
    'cover_image_url', r.cover_image_url,
    'phone', r.phone,
    'address_line1', r.address_line1,
    'city', r.city,
    'wilaya', r.wilaya,
    'latitude', r.latitude,
    'longitude', r.longitude,
    'is_open', r.is_open,
    'is_verified', r.is_verified,
    'opening_hours', r.opening_hours,
    'closing_hours', r.closing_hours,
    'vacation_starts_at', r.vacation_starts_at,
    'vacation_returns_at', r.vacation_returns_at,
    'estimated_delivery_time', r.estimated_delivery_time,
    'minimum_order', r.minimum_order,
    'delivery_fee', r.delivery_fee,
    'public_slug', r.public_slug,
    'is_new', coalesce(r.is_new, false)
  )
  INTO v_row
  FROM public.restaurants r
  WHERE r.public_slug = v_slug
    AND r.is_verified = true
    AND r.is_public_web_enabled = true
  LIMIT 1;

  RETURN v_row;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_public_restaurant_menu(
  p_slug text,
  p_limit int DEFAULT 50,
  p_offset int DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_restaurant_id uuid;
  v_items jsonb;
  v_total int;
BEGIN
  SELECT r.id INTO v_restaurant_id
  FROM public.restaurants r
  WHERE r.public_slug = public.normalize_restaurant_public_slug(p_slug)
    AND r.is_verified = true
    AND r.is_public_web_enabled = true
  LIMIT 1;

  IF v_restaurant_id IS NULL THEN
    RETURN jsonb_build_object('items', '[]'::jsonb, 'total', 0);
  END IF;

  SELECT count(*)::int INTO v_total
  FROM public.menu_items mi
  WHERE mi.restaurant_id = v_restaurant_id
    AND mi.is_available = true;

  SELECT coalesce(jsonb_agg(row_to_json(t)::jsonb ORDER BY t.category NULLS LAST, t.name), '[]'::jsonb)
  INTO v_items
  FROM (
    SELECT
      mi.id,
      mi.restaurant_id,
      mi.name,
      mi.name_ar,
      mi.name_latin,
      mi.description,
      mi.description_ar,
      mi.description_latin,
      mi.image,
      mi.images,
      mi.price,
      mi.category,
      mi.category_id,
      c.name AS category_name,
      c.name_ar AS category_name_ar,
      c.name_latin AS category_name_latin,
      mi.is_available,
      mi.preparation_time,
      mi.rating,
      mi.review_count,
      mi.variants,
      mi.pricing_options,
      mi.supplements,
      mi.is_limited_offer,
      mi.offer_start_at,
      mi.offer_end_at,
      mi.original_price,
      mi.offer_details,
      mi.main_ingredients,
      mi.ingredients,
      mi.updated_at
    FROM public.menu_items mi
    LEFT JOIN public.categories c ON c.id = mi.category_id
    WHERE mi.restaurant_id = v_restaurant_id
      AND mi.is_available = true
    ORDER BY mi.category NULLS LAST, mi.name
    LIMIT greatest(p_limit, 1)
    OFFSET greatest(p_offset, 0)
  ) t;

  RETURN jsonb_build_object('items', coalesce(v_items, '[]'::jsonb), 'total', v_total);
END;
$$;

-- ---------------------------------------------------------------------------
-- Create public web order (service role / server only)
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

REVOKE ALL ON FUNCTION public.create_public_web_order FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.get_public_restaurant_by_slug(text) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.get_public_restaurant_menu(text, int, int) TO anon, authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.create_public_web_order TO service_role;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- Verification:
-- SELECT column_name FROM information_schema.columns WHERE table_name='orders' AND column_name IN ('source','public_order_code');
-- SELECT public.get_public_restaurant_by_slug('test-slug');
