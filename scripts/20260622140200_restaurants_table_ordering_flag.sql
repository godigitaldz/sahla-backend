-- Quick patch: enable Performance dashboard "Table ordering" flag on restaurants.
-- Safe to re-run. Run BEFORE or as part of full table ordering rollout.
-- Full feature also needs: scripts/20260622140000_table_ordering_schema.sql

BEGIN;

ALTER TABLE public.restaurants
  ADD COLUMN IF NOT EXISTS table_ordering_enabled boolean NOT NULL DEFAULT false;

COMMENT ON COLUMN public.restaurants.table_ordering_enabled IS
  'When true, dine-in table QR + venue code ordering is allowed for this restaurant.';

COMMIT;

-- Verify:
-- SELECT column_name, data_type, column_default
-- FROM information_schema.columns
-- WHERE table_schema = 'public' AND table_name = 'restaurants'
--   AND column_name = 'table_ordering_enabled';
