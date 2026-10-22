-- Join categories for localized public web menu section headers (name_ar / name_latin).
-- Verification:
--   select mi.category, c.name_ar
--   from menu_items mi
--   left join categories c on c.id = mi.category_id
--   where mi.restaurant_id = 'cc2e9989-32cb-42d8-944e-aabcea730933'
--   limit 5;

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

GRANT EXECUTE ON FUNCTION public.get_public_restaurant_menu(text, int, int) TO anon, authenticated, service_role;
