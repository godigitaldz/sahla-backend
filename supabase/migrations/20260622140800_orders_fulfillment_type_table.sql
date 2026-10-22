-- Allow fulfillment_type = 'table' for in-restaurant QR orders.
-- Without this, create_public_table_order fails with orders_fulfillment_type_check.

ALTER TABLE public.orders
  DROP CONSTRAINT IF EXISTS orders_fulfillment_type_check;

ALTER TABLE public.orders
  ADD CONSTRAINT orders_fulfillment_type_check
  CHECK (fulfillment_type IN ('delivery', 'pickup', 'table'));

-- Optional: allow web_table source if a source check exists.
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conname = 'orders_source_check'
      AND conrelid = 'public.orders'::regclass
  ) THEN
    ALTER TABLE public.orders DROP CONSTRAINT orders_source_check;
    ALTER TABLE public.orders
      ADD CONSTRAINT orders_source_check
      CHECK (source IN ('app', 'web', 'web_table', 'manual', 'partner'));
  END IF;
END $$;

NOTIFY pgrst, 'reload schema';
