-- Alter menu_item_supplements table to allow null menu_item_id
-- This allows supplements to be created at the restaurant level first
-- before being linked to specific menu items
-- Make menu_item_id nullable
ALTER TABLE public.menu_item_supplements
ALTER COLUMN menu_item_id DROP NOT NULL;
-- Add comment explaining the nullable menu_item_id
COMMENT ON COLUMN public.menu_item_supplements.menu_item_id IS 'Reference to menu item. NULL when supplement is created at restaurant level (restaurant_supplements table). Updated when supplement is used in a menu item.';
