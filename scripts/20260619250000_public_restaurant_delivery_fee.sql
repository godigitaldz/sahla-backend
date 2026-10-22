-- Add delivery_fee to public restaurant RPC payload for web info boxes.
BEGIN;

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

GRANT EXECUTE ON FUNCTION public.get_public_restaurant_by_slug(text) TO anon, authenticated, service_role;

NOTIFY pgrst, 'reload schema';

COMMIT;

-- Verification:
-- SELECT public.get_public_restaurant_by_slug('rb-melty') -> 'delivery_fee';
