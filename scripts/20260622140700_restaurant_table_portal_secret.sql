-- Per-restaurant staff portal password (hashed). Each restaurant has its own code + secret.

ALTER TABLE public.restaurants
  ADD COLUMN IF NOT EXISTS table_portal_secret_hash bytea;

COMMENT ON COLUMN public.restaurants.table_portal_code IS
  'Unique slug for /table-orders/{code}. One code per restaurant.';
COMMENT ON COLUMN public.restaurants.table_portal_secret_hash IS
  'SHA-256 hash of that restaurant''s portal password. Set via Performance admin only.';

NOTIFY pgrst, 'reload schema';
