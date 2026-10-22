-- Enable digital (public web) menu for all restaurants.
-- Sets unique public_slug where missing, then is_public_web_enabled = true.
-- Menu URL: https://sahla-delivery.com/restaurants/{public_slug}
-- Note: get_public_restaurant_by_slug still requires is_verified = true for live ordering.

BEGIN;

-- Manual slugs for Arabic / empty-unaccent names (override before auto pass)
UPDATE public.restaurants SET public_slug = 'sultan-restaurant', updated_at = now()
WHERE id = '3dbc157b-b021-4f76-9a30-7c533b024e3c' AND public_slug IS NULL;

UPDATE public.restaurants SET public_slug = 'khaymat-zarari', updated_at = now()
WHERE id = '3c679e98-d0ee-4d3f-9cf9-31178a7738b1' AND public_slug IS NULL;

UPDATE public.restaurants SET public_slug = 'banona-traditional', updated_at = now()
WHERE id = '1fcb6355-6108-4693-bf83-5434f5a068e2' AND public_slug IS NULL;

UPDATE public.restaurants SET public_slug = 'emprator-rice', updated_at = now()
WHERE id = '2a746794-86ff-4757-b2c7-7ee22730ff10' AND public_slug IS NULL;

UPDATE public.restaurants SET public_slug = 'al-mansour-pizza', updated_at = now()
WHERE id = '72c09d5a-7305-479c-9ac1-39078d4c634f' AND public_slug IS NULL;

-- Auto-generate slugs from name_latin / name; fallback to r-{id8}
WITH base AS (
  SELECT
    r.id,
    COALESCE(
      NULLIF(public.normalize_restaurant_public_slug(r.name_latin), ''),
      NULLIF(public.normalize_restaurant_public_slug(r.name), ''),
      'r-' || substr(replace(r.id::text, '-', ''), 1, 8)
    ) AS base_slug
  FROM public.restaurants r
  WHERE r.public_slug IS NULL
),
numbered AS (
  SELECT
    b.id,
    b.base_slug,
    row_number() OVER (PARTITION BY b.base_slug ORDER BY b.id) AS rn
  FROM base b
),
final_slug AS (
  SELECT
    id,
    CASE
      WHEN rn = 1 THEN base_slug
      ELSE base_slug || '-' || rn::text
    END AS slug
  FROM numbered
)
UPDATE public.restaurants r
SET
  public_slug = f.slug,
  updated_at = now()
FROM final_slug f
WHERE r.id = f.id;

-- Enable web menu for every restaurant that now has a slug
UPDATE public.restaurants
SET
  is_public_web_enabled = true,
  updated_at = now()
WHERE public_slug IS NOT NULL;

COMMIT;

NOTIFY pgrst, 'reload schema';

-- Verification + URL list
SELECT
  r.name,
  r.is_verified,
  r.is_public_web_enabled,
  r.public_slug,
  'https://sahla-delivery.com/restaurants/' || r.public_slug AS menu_url
FROM public.restaurants r
WHERE r.public_slug IS NOT NULL
ORDER BY r.name;
