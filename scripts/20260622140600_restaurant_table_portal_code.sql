-- Per-restaurant access code for /table-orders/{code} staff portal.

ALTER TABLE public.restaurants
  ADD COLUMN IF NOT EXISTS table_portal_code text;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'restaurants_table_portal_code_format_chk'
  ) THEN
    ALTER TABLE public.restaurants
      ADD CONSTRAINT restaurants_table_portal_code_format_chk
      CHECK (
        table_portal_code IS NULL
        OR table_portal_code ~ '^[a-z0-9]+(?:-[a-z0-9]+)*$'
      );
  END IF;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS restaurants_table_portal_code_uidx
  ON public.restaurants (table_portal_code)
  WHERE table_portal_code IS NOT NULL;

UPDATE public.restaurants
SET table_portal_code = public_slug
WHERE table_portal_code IS NULL
  AND public_slug IS NOT NULL
  AND table_ordering_enabled = true;

-- RB Melty pilot
UPDATE public.restaurants
SET table_portal_code = 'rb-melty'
WHERE id = '42ea804e-0da4-43ea-bcf4-1deabbcc5515'
  AND table_portal_code IS NULL;

NOTIFY pgrst, 'reload schema';
