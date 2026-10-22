-- Location-based table presence (replaces venue-code entry for customers).

ALTER TABLE public.table_order_sessions
  ALTER COLUMN venue_window_id DROP NOT NULL;

DO $do$
BEGIN
  IF to_regprocedure('public.haversine_meters(double precision,double precision,double precision,double precision)') IS NULL THEN
    EXECUTE $fn$
      CREATE FUNCTION public.haversine_meters(
        p_lat1 double precision,
        p_lng1 double precision,
        p_lat2 double precision,
        p_lng2 double precision
      )
      RETURNS double precision
      LANGUAGE sql
      IMMUTABLE
      AS $body$
        SELECT CASE
          WHEN p_lat1 IS NULL OR p_lng1 IS NULL OR p_lat2 IS NULL OR p_lng2 IS NULL THEN NULL
          WHEN NOT (p_lat1 BETWEEN -90 AND 90 AND p_lat2 BETWEEN -90 AND 90) THEN NULL
          WHEN NOT (p_lng1 BETWEEN -180 AND 180 AND p_lng2 BETWEEN -180 AND 180) THEN NULL
          ELSE 2 * 6371000 * asin(sqrt(
            power(sin(radians(p_lat2 - p_lat1) / 2), 2) +
            cos(radians(p_lat1)) * cos(radians(p_lat2)) *
            power(sin(radians(p_lng2 - p_lng1) / 2), 2)
          ))
        END;
      $body$;
    $fn$;
  END IF;
END
$do$;

CREATE OR REPLACE FUNCTION public.exchange_table_presence_by_location(
  p_table_code text,
  p_customer_latitude double precision,
  p_customer_longitude double precision,
  p_session_token_hash bytea,
  p_device_binding_hash bytea DEFAULT NULL,
  p_session_ttl_minutes int DEFAULT 30,
  p_max_distance_meters double precision DEFAULT 10000
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_code_hash bytea;
  v_table_code record;
  v_distance_m double precision;
  v_session_id uuid;
  v_now timestamptz := now();
  v_expires timestamptz;
BEGIN
  IF nullif(trim(coalesce(p_table_code, '')), '') IS NULL THEN
    RAISE EXCEPTION 'table_code_required';
  END IF;

  IF p_session_token_hash IS NULL THEN
    RAISE EXCEPTION 'session_token_required';
  END IF;

  IF p_customer_latitude IS NULL OR p_customer_longitude IS NULL
     OR NOT (p_customer_latitude BETWEEN 18 AND 37.5)
     OR NOT (p_customer_longitude BETWEEN -9 AND 12) THEN
    RAISE EXCEPTION 'invalid_customer_location';
  END IF;

  v_code_hash := public.sha256_bytea(trim(p_table_code));

  SELECT
    tc.id AS code_id,
    tc.restaurant_table_id,
    rt.restaurant_id,
    rt.table_number,
    rt.table_label,
    rt.is_active AS table_active,
    r.public_slug,
    r.name AS restaurant_name,
    r.latitude AS restaurant_latitude,
    r.longitude AS restaurant_longitude,
    r.table_ordering_enabled,
    r.is_public_web_enabled,
    r.is_verified
  INTO v_table_code
  FROM public.restaurant_table_codes tc
  JOIN public.restaurant_tables rt ON rt.id = tc.restaurant_table_id
  JOIN public.restaurants r ON r.id = rt.restaurant_id
  WHERE tc.code_hash = v_code_hash
    AND tc.is_active = true
    AND tc.revoked_at IS NULL
    AND rt.deleted_at IS NULL
  LIMIT 1
  FOR UPDATE OF tc;

  IF v_table_code.code_id IS NULL THEN
    RAISE EXCEPTION 'invalid_table_code';
  END IF;

  IF NOT v_table_code.table_ordering_enabled THEN
    RAISE EXCEPTION 'table_ordering_disabled';
  END IF;

  IF NOT v_table_code.is_verified OR NOT v_table_code.is_public_web_enabled THEN
    RAISE EXCEPTION 'restaurant_not_available';
  END IF;

  IF NOT v_table_code.table_active THEN
    RAISE EXCEPTION 'table_inactive';
  END IF;

  IF v_table_code.restaurant_latitude IS NULL OR v_table_code.restaurant_longitude IS NULL THEN
    RAISE EXCEPTION 'restaurant_location_unavailable';
  END IF;

  v_distance_m := public.haversine_meters(
    v_table_code.restaurant_latitude,
    v_table_code.restaurant_longitude,
    p_customer_latitude,
    p_customer_longitude
  );

  IF v_distance_m IS NULL THEN
    RAISE EXCEPTION 'distance_check_failed';
  END IF;

  IF v_distance_m > greatest(coalesce(p_max_distance_meters, 10000), 1) THEN
    RAISE EXCEPTION 'outside_restaurant_range';
  END IF;

  IF p_device_binding_hash IS NOT NULL THEN
    UPDATE public.table_order_sessions s
    SET revoked_at = v_now
    WHERE s.restaurant_table_id = v_table_code.restaurant_table_id
      AND s.device_binding_hash = p_device_binding_hash
      AND s.revoked_at IS NULL
      AND s.expires_at > v_now;
  END IF;

  v_expires := v_now + make_interval(mins => greatest(p_session_ttl_minutes, 5));

  INSERT INTO public.table_order_sessions (
    restaurant_table_id,
    table_code_id,
    venue_window_id,
    session_token_hash,
    expires_at,
    device_binding_hash
  ) VALUES (
    v_table_code.restaurant_table_id,
    v_table_code.code_id,
    NULL,
    p_session_token_hash,
    v_expires,
    p_device_binding_hash
  )
  RETURNING id INTO v_session_id;

  RETURN jsonb_build_object(
    'session_id', v_session_id,
    'expires_at', v_expires,
    'restaurant_slug', v_table_code.public_slug,
    'restaurant_name', v_table_code.restaurant_name,
    'table_number', v_table_code.table_number,
    'table_label', v_table_code.table_label,
    'restaurant_table_id', v_table_code.restaurant_table_id,
    'distance_meters', round(v_distance_m::numeric, 1)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.exchange_table_presence_by_location(
  text, double precision, double precision, bytea, bytea, int, double precision
) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.exchange_table_presence_by_location(
  text, double precision, double precision, bytea, bytea, int, double precision
) TO service_role;

NOTIFY pgrst, 'reload schema';
