-- IMPORTANT: Run alter_menu_item_supplements_allow_null.sql FIRST
-- to make menu_item_id nullable in menu_item_supplements table
-- This is required because supplements are created with null menu_item_id
-- when added at restaurant level, then linked to menu items later
-- Create restaurant_supplements table
-- This table links restaurants to their available supplements
-- Each row represents a supplement available for a restaurant
CREATE TABLE IF NOT EXISTS public.restaurant_supplements (
    id uuid NOT NULL DEFAULT gen_random_uuid(),
    restaurant_id uuid NOT NULL,
    supplement_id uuid NOT NULL,
    created_at timestamp with time zone NULL DEFAULT now(),
    updated_at timestamp with time zone NULL DEFAULT now(),
    CONSTRAINT restaurant_supplements_pkey PRIMARY KEY (id),
    CONSTRAINT restaurant_supplements_restaurant_id_fkey FOREIGN KEY (restaurant_id) REFERENCES public.restaurants(id) ON DELETE CASCADE,
    CONSTRAINT restaurant_supplements_supplement_id_fkey FOREIGN KEY (supplement_id) REFERENCES public.menu_item_supplements(id) ON DELETE CASCADE,
    CONSTRAINT restaurant_supplements_unique UNIQUE (restaurant_id, supplement_id)
) TABLESPACE pg_default;
-- Create index for faster lookups
CREATE INDEX IF NOT EXISTS restaurant_supplements_restaurant_id_idx ON public.restaurant_supplements(restaurant_id);
CREATE INDEX IF NOT EXISTS restaurant_supplements_supplement_id_idx ON public.restaurant_supplements(supplement_id);
-- Create updated_at trigger function (if not exists)
CREATE OR REPLACE FUNCTION update_updated_at_column() RETURNS TRIGGER AS $$ BEGIN NEW.updated_at = now();
RETURN NEW;
END;
$$ language 'plpgsql';
-- Create trigger to automatically update updated_at
DROP TRIGGER IF EXISTS update_restaurant_supplements_updated_at ON public.restaurant_supplements;
CREATE TRIGGER update_restaurant_supplements_updated_at BEFORE
UPDATE ON public.restaurant_supplements FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
-- Add comment to table
COMMENT ON TABLE public.restaurant_supplements IS 'Links restaurants to their available supplements. Supplements are created in menu_item_supplements with null menu_item_id, then linked here. When a supplement is used in a menu item, menu_item_id is updated in menu_item_supplements.';
-- Add comments to columns
COMMENT ON COLUMN public.restaurant_supplements.restaurant_id IS 'Reference to the restaurant that owns this supplement';
COMMENT ON COLUMN public.restaurant_supplements.supplement_id IS 'Reference to the supplement in menu_item_supplements table';
