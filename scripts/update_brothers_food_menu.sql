-- ====================================================================
-- MIGRATION: Brothers Food Menu Polish & Expansion
-- Restaurant ID: 09ad3d8b-004f-4035-bee8-9c63243c39e9
-- Generated on: 2026-11-10T06:11:55.386Z
-- ====================================================================

BEGIN;

-- 1. RETIRE PASTA (is_available = false)
UPDATE public.menu_items
SET 
  is_available = false,
  updated_at = NOW()
WHERE id = '09ad3d8b-0001-4000-8000-0000000000c1'
  AND restaurant_id = '09ad3d8b-004f-4035-bee8-9c63243c39e9';

-- 2. UPDATE BURGER
UPDATE public.menu_items
SET
  name = 'Burger',
  name_ar = 'برجر',
  name_latin = 'Burger',
  category = 'Burger',
  category_id = '94e67ac0-ff8b-400f-8722-a872cfca15c4',
  cuisine_type_id = 'e5021b58-9273-4d84-a56a-05da539f79db',
  price = 250,
  is_available = true,
  image = 'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/Burger/Chicken_burger.png',
  images = '["https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/Burger/Chicken_burger.png"]'::jsonb,
  variants = '[{"id":"09ad3d8b-1004-4000-8000-000000000001","name":"Poulet","name_ar":"دجاج","name_latin":"Poulet","is_default":true,"is_available":true,"display_order":0,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0004-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-1004-4000-8000-000000000002","name":"Viande","name_ar":"لحم","name_latin":"Viande","is_default":false,"is_available":true,"display_order":1,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0004-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-1004-4000-8000-000000000003","name":"Crispy","name_ar":"كريسبي","name_latin":"Crispy","is_default":false,"is_available":true,"display_order":2,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0004-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-1004-4000-8000-000000000004","name":"Double","name_ar":"دبل","name_latin":"Double","is_default":false,"is_available":true,"display_order":3,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0004-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-1004-4000-8000-000000000005","name":"Seryal","name_ar":"سيريال","name_latin":"Seryal","is_default":false,"is_available":true,"display_order":4,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0004-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"}]'::jsonb,
  pricing_options = '[{"id":"09ad3d8b-2004-4000-8000-000000000001","size":"","size_ar":"","size_latin":"","portion":"","price":250,"is_default":true,"variant_id":"09ad3d8b-1004-4000-8000-000000000001","menu_item_id":"09ad3d8b-0004-4000-8000-0000000000c1","display_order":0,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-2004-4000-8000-000000000002","size":"","size_ar":"","size_latin":"","portion":"","price":300,"is_default":false,"variant_id":"09ad3d8b-1004-4000-8000-000000000002","menu_item_id":"09ad3d8b-0004-4000-8000-0000000000c1","display_order":1,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-2004-4000-8000-000000000003","size":"","size_ar":"","size_latin":"","portion":"","price":400,"is_default":false,"variant_id":"09ad3d8b-1004-4000-8000-000000000003","menu_item_id":"09ad3d8b-0004-4000-8000-0000000000c1","display_order":2,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-2004-4000-8000-000000000004","size":"","size_ar":"","size_latin":"","portion":"","price":450,"is_default":false,"variant_id":"09ad3d8b-1004-4000-8000-000000000004","menu_item_id":"09ad3d8b-0004-4000-8000-0000000000c1","display_order":3,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-2004-4000-8000-000000000005","size":"","size_ar":"","size_latin":"","portion":"","price":600,"is_default":false,"variant_id":"09ad3d8b-1004-4000-8000-000000000005","menu_item_id":"09ad3d8b-0004-4000-8000-0000000000c1","display_order":4,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"}]'::jsonb,
  updated_at = NOW()
WHERE id = '09ad3d8b-0004-4000-8000-0000000000c1'
  AND restaurant_id = '09ad3d8b-004f-4035-bee8-9c63243c39e9';

-- 3. UPDATE CALZONE
UPDATE public.menu_items
SET
  name = 'Calzone',
  name_ar = 'كالزون',
  name_latin = 'Calzone',
  category = 'Calzone',
  category_id = '35dcc8a8-6d56-4b28-98a1-b1b3a430cd76',
  cuisine_type_id = 'e5021b58-9273-4d84-a56a-05da539f79db',
  price = 500,
  is_available = true,
  image = 'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/Calzone.png',
  images = '["https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/Calzone.png"]'::jsonb,
  variants = '[{"id":"09ad3d8b-1002-4000-8000-000000000001","name":"Poulet","name_ar":"دجاج","name_latin":"Poulet","is_default":true,"is_available":true,"display_order":0,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0002-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-1002-4000-8000-000000000002","name":"Viande","name_ar":"لحم","name_latin":"Viande","is_default":false,"is_available":true,"display_order":1,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0002-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-1002-4000-8000-000000000003","name":"Foie","name_ar":"كبدة","name_latin":"Foie","is_default":false,"is_available":true,"display_order":2,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0002-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-1002-4000-8000-000000000004","name":"Mix","name_ar":"ميكس","name_latin":"Mix","is_default":false,"is_available":true,"display_order":3,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0002-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-1002-4000-8000-000000000005","name":"Seryal","name_ar":"سيريال","name_latin":"Seryal","is_default":false,"is_available":true,"display_order":4,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0002-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"}]'::jsonb,
  pricing_options = '[{"id":"09ad3d8b-2002-4000-8000-000000000001","size":"","size_ar":"","size_latin":"","portion":"","price":500,"is_default":true,"variant_id":"09ad3d8b-1002-4000-8000-000000000001","menu_item_id":"09ad3d8b-0002-4000-8000-0000000000c1","display_order":0,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-2002-4000-8000-000000000002","size":"","size_ar":"","size_latin":"","portion":"","price":600,"is_default":false,"variant_id":"09ad3d8b-1002-4000-8000-000000000002","menu_item_id":"09ad3d8b-0002-4000-8000-0000000000c1","display_order":1,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-2002-4000-8000-000000000003","size":"","size_ar":"","size_latin":"","portion":"","price":700,"is_default":false,"variant_id":"09ad3d8b-1002-4000-8000-000000000003","menu_item_id":"09ad3d8b-0002-4000-8000-0000000000c1","display_order":2,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-2002-4000-8000-000000000004","size":"","size_ar":"","size_latin":"","portion":"","price":800,"is_default":false,"variant_id":"09ad3d8b-1002-4000-8000-000000000004","menu_item_id":"09ad3d8b-0002-4000-8000-0000000000c1","display_order":3,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-2002-4000-8000-000000000005","size":"","size_ar":"","size_latin":"","portion":"","price":600,"is_default":false,"variant_id":"09ad3d8b-1002-4000-8000-000000000005","menu_item_id":"09ad3d8b-0002-4000-8000-0000000000c1","display_order":4,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"}]'::jsonb,
  updated_at = NOW()
WHERE id = '09ad3d8b-0002-4000-8000-0000000000c1'
  AND restaurant_id = '09ad3d8b-004f-4035-bee8-9c63243c39e9';

-- 4. UPDATE FAJITAS
UPDATE public.menu_items
SET
  name = 'Fajitas',
  name_ar = 'فاجيتاس',
  name_latin = 'Fajitas',
  category = 'Fajitas',
  category_id = '584c8fdb-9d70-4bf1-ae89-40039baaf01e',
  cuisine_type_id = 'e5021b58-9273-4d84-a56a-05da539f79db',
  price = 250,
  is_available = true,
  image = 'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/fajitas.png',
  images = '["https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/fajitas.png"]'::jsonb,
  variants = '[{"id":"09ad3d8b-1003-4000-8000-000000000001","name":"Poulet","name_ar":"دجاج","name_latin":"Poulet","is_default":true,"is_available":true,"display_order":0,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0003-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-1003-4000-8000-000000000002","name":"Viande","name_ar":"لحم","name_latin":"Viande","is_default":false,"is_available":true,"display_order":1,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0003-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-1003-4000-8000-000000000003","name":"Foie","name_ar":"كبدة","name_latin":"Foie","is_default":false,"is_available":true,"display_order":2,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0003-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-1003-4000-8000-000000000004","name":"Mix","name_ar":"ميكس","name_latin":"Mix","is_default":false,"is_available":true,"display_order":3,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0003-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"}]'::jsonb,
  pricing_options = '[{"id":"09ad3d8b-2003-4000-8000-000000000001","size":"","size_ar":"","size_latin":"","portion":"","price":250,"is_default":true,"variant_id":"09ad3d8b-1003-4000-8000-000000000001","menu_item_id":"09ad3d8b-0003-4000-8000-0000000000c1","display_order":0,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-2003-4000-8000-000000000002","size":"","size_ar":"","size_latin":"","portion":"","price":350,"is_default":false,"variant_id":"09ad3d8b-1003-4000-8000-000000000002","menu_item_id":"09ad3d8b-0003-4000-8000-0000000000c1","display_order":1,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-2003-4000-8000-000000000003","size":"","size_ar":"","size_latin":"","portion":"","price":450,"is_default":false,"variant_id":"09ad3d8b-1003-4000-8000-000000000003","menu_item_id":"09ad3d8b-0003-4000-8000-0000000000c1","display_order":2,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-2003-4000-8000-000000000004","size":"","size_ar":"","size_latin":"","portion":"","price":600,"is_default":false,"variant_id":"09ad3d8b-1003-4000-8000-000000000004","menu_item_id":"09ad3d8b-0003-4000-8000-0000000000c1","display_order":3,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"}]'::jsonb,
  updated_at = NOW()
WHERE id = '09ad3d8b-0003-4000-8000-0000000000c1'
  AND restaurant_id = '09ad3d8b-004f-4035-bee8-9c63243c39e9';

-- 5. UPDATE MALFOUF
UPDATE public.menu_items
SET
  name = 'Malfouf',
  name_ar = 'ملفوف',
  name_latin = 'Malfouf',
  category = 'Malfouf',
  category_id = 'a84b5880-04bd-4d27-8739-52306b5e53f4',
  cuisine_type_id = 'e5021b58-9273-4d84-a56a-05da539f79db',
  price = 300,
  is_available = true,
  image = 'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/malfouf.png',
  images = '["https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/malfouf.png"]'::jsonb,
  variants = '[{"id":"09ad3d8b-1006-4000-8000-000000000001","name":"Malfouf Poulet","name_ar":"ملفوف دجاج","name_latin":"Malfouf Poulet","is_default":true,"is_available":true,"display_order":0,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0006-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-1006-4000-8000-000000000002","name":"Malfouf Viande","name_ar":"ملفوف لحم","name_latin":"Malfouf Viande","is_default":false,"is_available":true,"display_order":1,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0006-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-1006-4000-8000-000000000003","name":"Malfouf Foie","name_ar":"ملفوف كبدة","name_latin":"Malfouf Foie","is_default":false,"is_available":true,"display_order":2,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0006-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-1006-4000-8000-000000000004","name":"Malfouf Crispy","name_ar":"ملفوف كريسبي","name_latin":"Malfouf Crispy","is_default":false,"is_available":true,"display_order":3,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0006-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-1006-4000-8000-000000000005","name":"Malfouf Mix","name_ar":"ملفوف ميكس","name_latin":"Malfouf Mix","is_default":false,"is_available":true,"display_order":4,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0006-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-1006-4000-8000-000000000006","name":"Malfouf Brothers","name_ar":"ملفوف برادرز","name_latin":"Malfouf Brothers","is_default":false,"is_available":true,"display_order":5,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0006-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"}]'::jsonb,
  pricing_options = '[{"id":"09ad3d8b-2006-4000-8000-000000000001","size":"","size_ar":"","size_latin":"","portion":"","price":300,"is_default":true,"variant_id":"09ad3d8b-1006-4000-8000-000000000001","menu_item_id":"09ad3d8b-0006-4000-8000-0000000000c1","display_order":0,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-2006-4000-8000-000000000002","size":"","size_ar":"","size_latin":"","portion":"","price":350,"is_default":false,"variant_id":"09ad3d8b-1006-4000-8000-000000000002","menu_item_id":"09ad3d8b-0006-4000-8000-0000000000c1","display_order":1,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-2006-4000-8000-000000000003","size":"","size_ar":"","size_latin":"","portion":"","price":400,"is_default":false,"variant_id":"09ad3d8b-1006-4000-8000-000000000003","menu_item_id":"09ad3d8b-0006-4000-8000-0000000000c1","display_order":2,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-2006-4000-8000-000000000004","size":"","size_ar":"","size_latin":"","portion":"","price":400,"is_default":false,"variant_id":"09ad3d8b-1006-4000-8000-000000000004","menu_item_id":"09ad3d8b-0006-4000-8000-0000000000c1","display_order":3,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-2006-4000-8000-000000000005","size":"","size_ar":"","size_latin":"","portion":"","price":500,"is_default":false,"variant_id":"09ad3d8b-1006-4000-8000-000000000005","menu_item_id":"09ad3d8b-0006-4000-8000-0000000000c1","display_order":4,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-2006-4000-8000-000000000006","size":"","size_ar":"","size_latin":"","portion":"","price":750,"is_default":false,"variant_id":"09ad3d8b-1006-4000-8000-000000000006","menu_item_id":"09ad3d8b-0006-4000-8000-0000000000c1","display_order":5,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"}]'::jsonb,
  updated_at = NOW()
WHERE id = '09ad3d8b-0006-4000-8000-0000000000c1'
  AND restaurant_id = '09ad3d8b-004f-4035-bee8-9c63243c39e9';

-- 6. UPDATE POUTINE (M & Family)
UPDATE public.menu_items
SET
  name = 'Poutine',
  name_ar = 'بوتين',
  name_latin = 'Poutine',
  category = 'Poutine',
  category_id = '767d4c31-c27d-41fa-b7eb-65257a65b62d',
  cuisine_type_id = 'e5021b58-9273-4d84-a56a-05da539f79db',
  price = 400,
  is_available = true,
  image = 'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/Poutine/Mix.png',
  images = '["https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/Poutine/Mix.png"]'::jsonb,
  variants = '[{"id":"09ad3d8b-1005-4000-8000-000000000001","name":"Chawarma","name_ar":"شاورما","name_latin":"Chawarma","is_default":true,"is_available":true,"display_order":0,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0005-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.386Z","updated_at":"2026-11-10T06:11:55.386Z"},{"id":"09ad3d8b-1005-4000-8000-000000000002","name":"Viande","name_ar":"لحم","name_latin":"Viande","is_default":false,"is_available":true,"display_order":1,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0005-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.386Z","updated_at":"2026-11-10T06:11:55.386Z"},{"id":"09ad3d8b-1005-4000-8000-000000000003","name":"Crispy","name_ar":"كريسبي","name_latin":"Crispy","is_default":false,"is_available":true,"display_order":2,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0005-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.386Z","updated_at":"2026-11-10T06:11:55.386Z"},{"id":"09ad3d8b-1005-4000-8000-000000000004","name":"BR","name_ar":"بي آر","name_latin":"BR","is_default":false,"is_available":true,"display_order":3,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0005-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.386Z","updated_at":"2026-11-10T06:11:55.386Z"}]'::jsonb,
  pricing_options = '[{"id":"09ad3d8b-2005-4000-8000-000000000001","size":"M","size_ar":"عادي","size_latin":"M","portion":"","price":400,"is_default":true,"variant_id":"09ad3d8b-1005-4000-8000-000000000001","menu_item_id":"09ad3d8b-0005-4000-8000-0000000000c1","display_order":0,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.386Z","updated_at":"2026-11-10T06:11:55.386Z"},{"id":"09ad3d8b-2005-4000-8000-000000000002","size":"Family","size_ar":"عائلي","size_latin":"Family","portion":"","price":1800,"is_default":false,"variant_id":"09ad3d8b-1005-4000-8000-000000000001","menu_item_id":"09ad3d8b-0005-4000-8000-0000000000c1","display_order":1,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.386Z","updated_at":"2026-11-10T06:11:55.386Z"},{"id":"09ad3d8b-2005-4000-8000-000000000003","size":"M","size_ar":"عادي","size_latin":"M","portion":"","price":450,"is_default":false,"variant_id":"09ad3d8b-1005-4000-8000-000000000002","menu_item_id":"09ad3d8b-0005-4000-8000-0000000000c1","display_order":0,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.386Z","updated_at":"2026-11-10T06:11:55.386Z"},{"id":"09ad3d8b-2005-4000-8000-000000000004","size":"Family","size_ar":"عائلي","size_latin":"Family","portion":"","price":1900,"is_default":false,"variant_id":"09ad3d8b-1005-4000-8000-000000000002","menu_item_id":"09ad3d8b-0005-4000-8000-0000000000c1","display_order":1,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.386Z","updated_at":"2026-11-10T06:11:55.386Z"},{"id":"09ad3d8b-2005-4000-8000-000000000005","size":"M","size_ar":"عادي","size_latin":"M","portion":"","price":700,"is_default":false,"variant_id":"09ad3d8b-1005-4000-8000-000000000003","menu_item_id":"09ad3d8b-0005-4000-8000-0000000000c1","display_order":0,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.386Z","updated_at":"2026-11-10T06:11:55.386Z"},{"id":"09ad3d8b-2005-4000-8000-000000000006","size":"Family","size_ar":"عائلي","size_latin":"Family","portion":"","price":2500,"is_default":false,"variant_id":"09ad3d8b-1005-4000-8000-000000000003","menu_item_id":"09ad3d8b-0005-4000-8000-0000000000c1","display_order":1,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.386Z","updated_at":"2026-11-10T06:11:55.386Z"},{"id":"09ad3d8b-2005-4000-8000-000000000007","size":"Family","size_ar":"عائلي","size_latin":"Family","portion":"","price":3000,"is_default":true,"variant_id":"09ad3d8b-1005-4000-8000-000000000004","menu_item_id":"09ad3d8b-0005-4000-8000-0000000000c1","display_order":1,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.386Z","updated_at":"2026-11-10T06:11:55.386Z"}]'::jsonb,
  updated_at = NOW()
WHERE id = '09ad3d8b-0005-4000-8000-0000000000c1'
  AND restaurant_id = '09ad3d8b-004f-4035-bee8-9c63243c39e9';

-- 7. UPDATE TACOS
UPDATE public.menu_items
SET
  name = 'Tacos',
  name_ar = 'طاكوس',
  name_latin = 'Tacos',
  category = 'Tacos',
  category_id = '34f33e8b-8bf2-4121-b905-3f9b1686d6c1',
  cuisine_type_id = 'e5021b58-9273-4d84-a56a-05da539f79db',
  price = 400,
  is_available = true,
  image = 'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/Tacos/gratine.png',
  images = '["https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/Tacos/gratine.png"]'::jsonb,
  variants = '[{"id":"09ad3d8b-1007-4000-8000-000000000001","name":"Chawarma","name_ar":"شاورما","name_latin":"Chawarma","is_default":true,"is_available":true,"display_order":0,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0007-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-1007-4000-8000-000000000002","name":"Viande","name_ar":"لحم","name_latin":"Viande","is_default":false,"is_available":true,"display_order":1,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0007-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-1007-4000-8000-000000000003","name":"Foie","name_ar":"كبدة","name_latin":"Foie","is_default":false,"is_available":true,"display_order":2,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0007-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-1007-4000-8000-000000000004","name":"Crispy","name_ar":"كريسبي","name_latin":"Crispy","is_default":false,"is_available":true,"display_order":3,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0007-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-1007-4000-8000-000000000005","name":"Mix","name_ar":"ميكس","name_latin":"Mix","is_default":false,"is_available":true,"display_order":4,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0007-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-1007-4000-8000-000000000006","name":"4 Fromage","name_ar":"4 أجبان","name_latin":"4 Fromage","is_default":false,"is_available":true,"display_order":5,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0007-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"}]'::jsonb,
  pricing_options = '[{"id":"09ad3d8b-2007-4000-8000-000000000001","size":"","size_ar":"","size_latin":"","portion":"","price":400,"is_default":true,"variant_id":"09ad3d8b-1007-4000-8000-000000000001","menu_item_id":"09ad3d8b-0007-4000-8000-0000000000c1","display_order":0,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-2007-4000-8000-000000000002","size":"","size_ar":"","size_latin":"","portion":"","price":450,"is_default":false,"variant_id":"09ad3d8b-1007-4000-8000-000000000002","menu_item_id":"09ad3d8b-0007-4000-8000-0000000000c1","display_order":1,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-2007-4000-8000-000000000003","size":"","size_ar":"","size_latin":"","portion":"","price":500,"is_default":false,"variant_id":"09ad3d8b-1007-4000-8000-000000000003","menu_item_id":"09ad3d8b-0007-4000-8000-0000000000c1","display_order":2,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-2007-4000-8000-000000000004","size":"","size_ar":"","size_latin":"","portion":"","price":550,"is_default":false,"variant_id":"09ad3d8b-1007-4000-8000-000000000004","menu_item_id":"09ad3d8b-0007-4000-8000-0000000000c1","display_order":3,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-2007-4000-8000-000000000005","size":"","size_ar":"","size_latin":"","portion":"","price":650,"is_default":false,"variant_id":"09ad3d8b-1007-4000-8000-000000000005","menu_item_id":"09ad3d8b-0007-4000-8000-0000000000c1","display_order":4,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-2007-4000-8000-000000000006","size":"","size_ar":"","size_latin":"","portion":"","price":800,"is_default":false,"variant_id":"09ad3d8b-1007-4000-8000-000000000006","menu_item_id":"09ad3d8b-0007-4000-8000-0000000000c1","display_order":5,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"}]'::jsonb,
  updated_at = NOW()
WHERE id = '09ad3d8b-0007-4000-8000-0000000000c1'
  AND restaurant_id = '09ad3d8b-004f-4035-bee8-9c63243c39e9';

-- 8. INSERT OR UPDATE PIZZA (13 varieties, 26 sizes M/L)
INSERT INTO public.menu_items (
  id,
  restaurant_id,
  restaurant_name,
  name,
  name_ar,
  name_latin,
  category,
  category_id,
  cuisine_type_id,
  price,
  is_available,
  is_featured,
  preparation_time,
  image,
  images,
  variants,
  pricing_options,
  ingredients,
  ingredients_ar,
  ingredients_latin,
  created_at,
  updated_at
) VALUES (
  '09ad3d8b-0008-4000-8000-0000000000c1',
  '09ad3d8b-004f-4035-bee8-9c63243c39e9',
  'Brothers Food',
  'Pizza',
  'بيتزا',
  'Pizza',
  'Pizza',
  'd54806cf-adb6-43ce-ae11-10d45bd8d479',
  'e5021b58-9273-4d84-a56a-05da539f79db',
  250,
  true,
  false,
  15,
  'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/Pizza/Sauce%20toamte/Margerita.png',
  '["https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/Pizza/Sauce%20toamte/Margerita.png"]'::jsonb,
  '[{"id":"09ad3d8b-1008-4000-8000-000000000001","name":"Margherita","name_ar":"مارغريتا","name_latin":"Margherita","is_default":true,"is_available":true,"display_order":0,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.382Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-1008-4000-8000-000000000002","name":"Pizza double fromage","name_ar":"بيتزا مضاعفة الجبن","name_latin":"Pizza double fromage","is_default":false,"is_available":true,"display_order":1,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-1008-4000-8000-000000000003","name":"Poulet","name_ar":"دجاج","name_latin":"Poulet","is_default":false,"is_available":true,"display_order":2,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-1008-4000-8000-000000000004","name":"Viande","name_ar":"لحم","name_latin":"Viande","is_default":false,"is_available":true,"display_order":3,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-1008-4000-8000-000000000005","name":"Thon","name_ar":"تونة","name_latin":"Thon","is_default":false,"is_available":true,"display_order":4,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-1008-4000-8000-000000000006","name":"Poulet Fumé","name_ar":"دجاج مدخن","name_latin":"Poulet Fumé","is_default":false,"is_available":true,"display_order":5,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-1008-4000-8000-000000000007","name":"4 Saisons","name_ar":"الفصول الأربعة","name_latin":"4 Saisons","is_default":false,"is_available":true,"display_order":6,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-1008-4000-8000-000000000008","name":"3 Fromage","name_ar":"3 أجبان","name_latin":"3 Fromage","is_default":false,"is_available":true,"display_order":7,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-1008-4000-8000-000000000009","name":"Végétarienne","name_ar":"نباتية","name_latin":"Végétarienne","is_default":false,"is_available":true,"display_order":8,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-1008-4000-8000-000000000010","name":"Végétarienne Spéciale","name_ar":"نباتية خاصة","name_latin":"Végétarienne Spéciale","is_default":false,"is_available":true,"display_order":9,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-1008-4000-8000-000000000011","name":"Boisée Simple","name_ar":"بوايزيه بسيطة","name_latin":"Boisée Simple","is_default":false,"is_available":true,"display_order":10,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-1008-4000-8000-000000000012","name":"Boisée Poulet","name_ar":"بوايزيه بالدجاج","name_latin":"Boisée Poulet","is_default":false,"is_available":true,"display_order":11,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-1008-4000-8000-000000000013","name":"Pizza peperoni","name_ar":"بيتزا بيبيروني","name_latin":"Pizza peperoni","is_default":false,"is_available":true,"display_order":12,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"}]'::jsonb,
  '[{"id":"09ad3d8b-2008-4000-8000-000000000001","size":"M","size_ar":"متوسط","size_latin":"M","portion":"","price":250,"is_default":true,"variant_id":"09ad3d8b-1008-4000-8000-000000000001","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","display_order":0,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-2008-4000-8000-000000000002","size":"L","size_ar":"كبير","size_latin":"L","portion":"","price":650,"is_default":false,"variant_id":"09ad3d8b-1008-4000-8000-000000000001","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","display_order":1,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-2008-4000-8000-000000000003","size":"M","size_ar":"متوسط","size_latin":"M","portion":"","price":350,"is_default":true,"variant_id":"09ad3d8b-1008-4000-8000-000000000002","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","display_order":0,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-2008-4000-8000-000000000004","size":"L","size_ar":"كبير","size_latin":"L","portion":"","price":750,"is_default":false,"variant_id":"09ad3d8b-1008-4000-8000-000000000002","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","display_order":1,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-2008-4000-8000-000000000005","size":"M","size_ar":"متوسط","size_latin":"M","portion":"","price":450,"is_default":true,"variant_id":"09ad3d8b-1008-4000-8000-000000000003","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","display_order":0,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-2008-4000-8000-000000000006","size":"L","size_ar":"كبير","size_latin":"L","portion":"","price":850,"is_default":false,"variant_id":"09ad3d8b-1008-4000-8000-000000000003","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","display_order":1,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-2008-4000-8000-000000000007","size":"M","size_ar":"متوسط","size_latin":"M","portion":"","price":450,"is_default":true,"variant_id":"09ad3d8b-1008-4000-8000-000000000004","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","display_order":0,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-2008-4000-8000-000000000008","size":"L","size_ar":"كبير","size_latin":"L","portion":"","price":1000,"is_default":false,"variant_id":"09ad3d8b-1008-4000-8000-000000000004","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","display_order":1,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-2008-4000-8000-000000000009","size":"M","size_ar":"متوسط","size_latin":"M","portion":"","price":450,"is_default":true,"variant_id":"09ad3d8b-1008-4000-8000-000000000005","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","display_order":0,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-2008-4000-8000-000000000010","size":"L","size_ar":"كبير","size_latin":"L","portion":"","price":850,"is_default":false,"variant_id":"09ad3d8b-1008-4000-8000-000000000005","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","display_order":1,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-2008-4000-8000-000000000011","size":"M","size_ar":"متوسط","size_latin":"M","portion":"","price":650,"is_default":true,"variant_id":"09ad3d8b-1008-4000-8000-000000000006","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","display_order":0,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-2008-4000-8000-000000000012","size":"L","size_ar":"كبير","size_latin":"L","portion":"","price":1100,"is_default":false,"variant_id":"09ad3d8b-1008-4000-8000-000000000006","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","display_order":1,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-2008-4000-8000-000000000013","size":"M","size_ar":"متوسط","size_latin":"M","portion":"","price":800,"is_default":true,"variant_id":"09ad3d8b-1008-4000-8000-000000000007","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","display_order":0,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-2008-4000-8000-000000000014","size":"L","size_ar":"كبير","size_latin":"L","portion":"","price":1800,"is_default":false,"variant_id":"09ad3d8b-1008-4000-8000-000000000007","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","display_order":1,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-2008-4000-8000-000000000015","size":"M","size_ar":"متوسط","size_latin":"M","portion":"","price":700,"is_default":true,"variant_id":"09ad3d8b-1008-4000-8000-000000000008","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","display_order":0,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-2008-4000-8000-000000000016","size":"L","size_ar":"كبير","size_latin":"L","portion":"","price":1400,"is_default":false,"variant_id":"09ad3d8b-1008-4000-8000-000000000008","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","display_order":1,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-2008-4000-8000-000000000017","size":"M","size_ar":"متوسط","size_latin":"M","portion":"","price":400,"is_default":true,"variant_id":"09ad3d8b-1008-4000-8000-000000000009","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","display_order":0,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-2008-4000-8000-000000000018","size":"L","size_ar":"كبير","size_latin":"L","portion":"","price":800,"is_default":false,"variant_id":"09ad3d8b-1008-4000-8000-000000000009","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","display_order":1,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-2008-4000-8000-000000000019","size":"M","size_ar":"متوسط","size_latin":"M","portion":"","price":800,"is_default":true,"variant_id":"09ad3d8b-1008-4000-8000-000000000010","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","display_order":0,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-2008-4000-8000-000000000020","size":"L","size_ar":"كبير","size_latin":"L","portion":"","price":1400,"is_default":false,"variant_id":"09ad3d8b-1008-4000-8000-000000000010","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","display_order":1,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-2008-4000-8000-000000000021","size":"M","size_ar":"متوسط","size_latin":"M","portion":"","price":400,"is_default":true,"variant_id":"09ad3d8b-1008-4000-8000-000000000011","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","display_order":0,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-2008-4000-8000-000000000022","size":"L","size_ar":"كبير","size_latin":"L","portion":"","price":650,"is_default":false,"variant_id":"09ad3d8b-1008-4000-8000-000000000011","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","display_order":1,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-2008-4000-8000-000000000023","size":"M","size_ar":"متوسط","size_latin":"M","portion":"","price":550,"is_default":true,"variant_id":"09ad3d8b-1008-4000-8000-000000000012","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","display_order":0,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-2008-4000-8000-000000000024","size":"L","size_ar":"كبير","size_latin":"L","portion":"","price":950,"is_default":false,"variant_id":"09ad3d8b-1008-4000-8000-000000000012","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","display_order":1,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-2008-4000-8000-000000000025","size":"M","size_ar":"متوسط","size_latin":"M","portion":"","price":550,"is_default":true,"variant_id":"09ad3d8b-1008-4000-8000-000000000013","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","display_order":0,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"},{"id":"09ad3d8b-2008-4000-8000-000000000026","size":"L","size_ar":"كبير","size_latin":"L","portion":"","price":1100,"is_default":false,"variant_id":"09ad3d8b-1008-4000-8000-000000000013","menu_item_id":"09ad3d8b-0008-4000-8000-0000000000c1","display_order":1,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.384Z","updated_at":"2026-11-10T06:11:55.384Z"}]'::jsonb,
  '[]'::jsonb,
  '[]'::jsonb,
  '[]'::jsonb,
  NOW(),
  NOW()
)
ON CONFLICT (id) DO UPDATE SET
  restaurant_name = EXCLUDED.restaurant_name,
  name = EXCLUDED.name,
  name_ar = EXCLUDED.name_ar,
  name_latin = EXCLUDED.name_latin,
  category = EXCLUDED.category,
  category_id = EXCLUDED.category_id,
  cuisine_type_id = EXCLUDED.cuisine_type_id,
  price = EXCLUDED.price,
  is_available = EXCLUDED.is_available,
  image = EXCLUDED.image,
  images = EXCLUDED.images,
  variants = EXCLUDED.variants,
  pricing_options = EXCLUDED.pricing_options,
  updated_at = NOW();

-- 9. INSERT OR UPDATE MAKLOUB
INSERT INTO public.menu_items (
  id,
  restaurant_id,
  restaurant_name,
  name,
  name_ar,
  name_latin,
  category,
  category_id,
  cuisine_type_id,
  price,
  is_available,
  is_featured,
  preparation_time,
  image,
  images,
  variants,
  pricing_options,
  ingredients,
  ingredients_ar,
  ingredients_latin,
  created_at,
  updated_at
) VALUES (
  '09ad3d8b-0009-4000-8000-0000000000c1',
  '09ad3d8b-004f-4035-bee8-9c63243c39e9',
  'Brothers Food',
  'Makloub',
  'مقلوب',
  'Makloub',
  'Makloub',
  '354f5144-06c7-4711-b1c0-73d22d709a2d',
  'e5021b58-9273-4d84-a56a-05da539f79db',
  450,
  true,
  false,
  10,
  'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/makloub.png',
  '["https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/makloub.png"]'::jsonb,
  '[{"id":"09ad3d8b-1009-4000-8000-000000000001","name":"Chawarma","name_ar":"شاورما","name_latin":"Chawarma","is_default":true,"is_available":true,"display_order":0,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0009-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-1009-4000-8000-000000000002","name":"Viande","name_ar":"لحم","name_latin":"Viande","is_default":false,"is_available":true,"display_order":1,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0009-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-1009-4000-8000-000000000003","name":"Foie","name_ar":"كبدة","name_latin":"Foie","is_default":false,"is_available":true,"display_order":2,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0009-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-1009-4000-8000-000000000004","name":"Mix","name_ar":"ميكس","name_latin":"Mix","is_default":false,"is_available":true,"display_order":3,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0009-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-1009-4000-8000-000000000005","name":"BR","name_ar":"بي آر","name_latin":"BR","is_default":false,"is_available":true,"display_order":4,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0009-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"}]'::jsonb,
  '[{"id":"09ad3d8b-2009-4000-8000-000000000001","size":"","size_ar":"","size_latin":"","portion":"","price":450,"is_default":true,"variant_id":"09ad3d8b-1009-4000-8000-000000000001","menu_item_id":"09ad3d8b-0009-4000-8000-0000000000c1","display_order":0,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-2009-4000-8000-000000000002","size":"","size_ar":"","size_latin":"","portion":"","price":500,"is_default":false,"variant_id":"09ad3d8b-1009-4000-8000-000000000002","menu_item_id":"09ad3d8b-0009-4000-8000-0000000000c1","display_order":1,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-2009-4000-8000-000000000003","size":"","size_ar":"","size_latin":"","portion":"","price":600,"is_default":false,"variant_id":"09ad3d8b-1009-4000-8000-000000000003","menu_item_id":"09ad3d8b-0009-4000-8000-0000000000c1","display_order":2,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-2009-4000-8000-000000000004","size":"","size_ar":"","size_latin":"","portion":"","price":650,"is_default":false,"variant_id":"09ad3d8b-1009-4000-8000-000000000004","menu_item_id":"09ad3d8b-0009-4000-8000-0000000000c1","display_order":3,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-2009-4000-8000-000000000005","size":"","size_ar":"","size_latin":"","portion":"","price":800,"is_default":false,"variant_id":"09ad3d8b-1009-4000-8000-000000000005","menu_item_id":"09ad3d8b-0009-4000-8000-0000000000c1","display_order":4,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"}]'::jsonb,
  '[]'::jsonb,
  '[]'::jsonb,
  '[]'::jsonb,
  NOW(),
  NOW()
)
ON CONFLICT (id) DO UPDATE SET
  restaurant_name = EXCLUDED.restaurant_name,
  name = EXCLUDED.name,
  name_ar = EXCLUDED.name_ar,
  name_latin = EXCLUDED.name_latin,
  category = EXCLUDED.category,
  category_id = EXCLUDED.category_id,
  cuisine_type_id = EXCLUDED.cuisine_type_id,
  price = EXCLUDED.price,
  is_available = EXCLUDED.is_available,
  image = EXCLUDED.image,
  images = EXCLUDED.images,
  variants = EXCLUDED.variants,
  pricing_options = EXCLUDED.pricing_options,
  updated_at = NOW();

-- 10. INSERT OR UPDATE PLATS VARIÉS
INSERT INTO public.menu_items (
  id,
  restaurant_id,
  restaurant_name,
  name,
  name_ar,
  name_latin,
  category,
  category_id,
  cuisine_type_id,
  price,
  is_available,
  is_featured,
  preparation_time,
  image,
  images,
  variants,
  pricing_options,
  ingredients,
  ingredients_ar,
  ingredients_latin,
  created_at,
  updated_at
) VALUES (
  '09ad3d8b-0010-4000-8000-0000000000c1',
  '09ad3d8b-004f-4035-bee8-9c63243c39e9',
  'Brothers Food',
  'Plats Variés',
  'أطباق متنوعة',
  'Plats Varies',
  'Plats',
  '2feb3511-4c37-4252-92b3-310936749abe',
  'e5021b58-9273-4d84-a56a-05da539f79db',
  600,
  true,
  false,
  12,
  'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/Plats.png',
  '["https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/Plats.png"]'::jsonb,
  '[{"id":"09ad3d8b-1010-4000-8000-000000000001","name":"Chawarma","name_ar":"شاورما","name_latin":"Chawarma","is_default":true,"is_available":true,"display_order":0,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0010-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-1010-4000-8000-000000000002","name":"Viande","name_ar":"لحم","name_latin":"Viande","is_default":false,"is_available":true,"display_order":1,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0010-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-1010-4000-8000-000000000003","name":"Plat Crispy","name_ar":"طبق كريسبي","name_latin":"Plat Crispy","is_default":false,"is_available":true,"display_order":2,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0010-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-1010-4000-8000-000000000004","name":"Crispy","name_ar":"كريسبي","name_latin":"Crispy","is_default":false,"is_available":true,"display_order":3,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0010-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-1010-4000-8000-000000000005","name":"Mix","name_ar":"ميكس","name_latin":"Mix","is_default":false,"is_available":true,"display_order":4,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0010-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"}]'::jsonb,
  '[{"id":"09ad3d8b-2010-4000-8000-000000000001","size":"","size_ar":"","size_latin":"","portion":"","price":600,"is_default":true,"variant_id":"09ad3d8b-1010-4000-8000-000000000001","menu_item_id":"09ad3d8b-0010-4000-8000-0000000000c1","display_order":0,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-2010-4000-8000-000000000002","size":"","size_ar":"","size_latin":"","portion":"","price":700,"is_default":false,"variant_id":"09ad3d8b-1010-4000-8000-000000000002","menu_item_id":"09ad3d8b-0010-4000-8000-0000000000c1","display_order":1,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-2010-4000-8000-000000000003","size":"","size_ar":"","size_latin":"","portion":"","price":800,"is_default":false,"variant_id":"09ad3d8b-1010-4000-8000-000000000003","menu_item_id":"09ad3d8b-0010-4000-8000-0000000000c1","display_order":2,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-2010-4000-8000-000000000004","size":"","size_ar":"","size_latin":"","portion":"","price":850,"is_default":false,"variant_id":"09ad3d8b-1010-4000-8000-000000000004","menu_item_id":"09ad3d8b-0010-4000-8000-0000000000c1","display_order":3,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-2010-4000-8000-000000000005","size":"","size_ar":"","size_latin":"","portion":"","price":1000,"is_default":false,"variant_id":"09ad3d8b-1010-4000-8000-000000000005","menu_item_id":"09ad3d8b-0010-4000-8000-0000000000c1","display_order":4,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"}]'::jsonb,
  '[]'::jsonb,
  '[]'::jsonb,
  '[]'::jsonb,
  NOW(),
  NOW()
)
ON CONFLICT (id) DO UPDATE SET
  restaurant_name = EXCLUDED.restaurant_name,
  name = EXCLUDED.name,
  name_ar = EXCLUDED.name_ar,
  name_latin = EXCLUDED.name_latin,
  category = EXCLUDED.category,
  category_id = EXCLUDED.category_id,
  cuisine_type_id = EXCLUDED.cuisine_type_id,
  price = EXCLUDED.price,
  is_available = EXCLUDED.is_available,
  image = EXCLUDED.image,
  images = EXCLUDED.images,
  variants = EXCLUDED.variants,
  pricing_options = EXCLUDED.pricing_options,
  updated_at = NOW();

-- 11. INSERT OR UPDATE SANDWICH
INSERT INTO public.menu_items (
  id,
  restaurant_id,
  restaurant_name,
  name,
  name_ar,
  name_latin,
  category,
  category_id,
  cuisine_type_id,
  price,
  is_available,
  is_featured,
  preparation_time,
  image,
  images,
  variants,
  pricing_options,
  ingredients,
  ingredients_ar,
  ingredients_latin,
  created_at,
  updated_at
) VALUES (
  '09ad3d8b-0011-4000-8000-0000000000c1',
  '09ad3d8b-004f-4035-bee8-9c63243c39e9',
  'Brothers Food',
  'Sandwich',
  'سندويش',
  'Sandwich',
  'Sandwich',
  '842f79fa-b4fc-426d-a73d-11281178bc44',
  'e5021b58-9273-4d84-a56a-05da539f79db',
  300,
  true,
  false,
  8,
  'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/sandwich.png',
  '["https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/sandwich.png"]'::jsonb,
  '[{"id":"09ad3d8b-1011-4000-8000-000000000001","name":"Chawarma","name_ar":"شاورما","name_latin":"Chawarma","is_default":true,"is_available":true,"display_order":0,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0011-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-1011-4000-8000-000000000002","name":"Viande","name_ar":"لحم","name_latin":"Viande","is_default":false,"is_available":true,"display_order":1,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0011-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-1011-4000-8000-000000000003","name":"Crispy","name_ar":"كريسبي","name_latin":"Crispy","is_default":false,"is_available":true,"display_order":2,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0011-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-1011-4000-8000-000000000004","name":"Mix","name_ar":"ميكس","name_latin":"Mix","is_default":false,"is_available":true,"display_order":3,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0011-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-1011-4000-8000-000000000005","name":"Normal + 4 Fromage","name_ar":"عادي + 4 أجبان","name_latin":"Normal + 4 Fromage","is_default":false,"is_available":true,"display_order":4,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0011-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.385Z","updated_at":"2026-11-10T06:11:55.385Z"},{"id":"09ad3d8b-1011-4000-8000-000000000006","name":"+ 4 Fromage","name_ar":"+ 4 أجبان","name_latin":"+ 4 Fromage","is_default":false,"is_available":true,"display_order":5,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0011-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.386Z","updated_at":"2026-11-10T06:11:55.386Z"},{"id":"09ad3d8b-1011-4000-8000-000000000007","name":"Special","name_ar":"سبيسيال","name_latin":"Special","is_default":false,"is_available":true,"display_order":6,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0011-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.386Z","updated_at":"2026-11-10T06:11:55.386Z"}]'::jsonb,
  '[{"id":"09ad3d8b-2011-4000-8000-000000000001","size":"","size_ar":"","size_latin":"","portion":"","price":300,"is_default":true,"variant_id":"09ad3d8b-1011-4000-8000-000000000001","menu_item_id":"09ad3d8b-0011-4000-8000-0000000000c1","display_order":0,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.386Z","updated_at":"2026-11-10T06:11:55.386Z"},{"id":"09ad3d8b-2011-4000-8000-000000000002","size":"","size_ar":"","size_latin":"","portion":"","price":350,"is_default":false,"variant_id":"09ad3d8b-1011-4000-8000-000000000002","menu_item_id":"09ad3d8b-0011-4000-8000-0000000000c1","display_order":1,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.386Z","updated_at":"2026-11-10T06:11:55.386Z"},{"id":"09ad3d8b-2011-4000-8000-000000000003","size":"","size_ar":"","size_latin":"","portion":"","price":400,"is_default":false,"variant_id":"09ad3d8b-1011-4000-8000-000000000003","menu_item_id":"09ad3d8b-0011-4000-8000-0000000000c1","display_order":2,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.386Z","updated_at":"2026-11-10T06:11:55.386Z"},{"id":"09ad3d8b-2011-4000-8000-000000000004","size":"","size_ar":"","size_latin":"","portion":"","price":450,"is_default":false,"variant_id":"09ad3d8b-1011-4000-8000-000000000004","menu_item_id":"09ad3d8b-0011-4000-8000-0000000000c1","display_order":3,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.386Z","updated_at":"2026-11-10T06:11:55.386Z"},{"id":"09ad3d8b-2011-4000-8000-000000000005","size":"","size_ar":"","size_latin":"","portion":"","price":400,"is_default":false,"variant_id":"09ad3d8b-1011-4000-8000-000000000005","menu_item_id":"09ad3d8b-0011-4000-8000-0000000000c1","display_order":4,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.386Z","updated_at":"2026-11-10T06:11:55.386Z"},{"id":"09ad3d8b-2011-4000-8000-000000000006","size":"","size_ar":"","size_latin":"","portion":"","price":700,"is_default":false,"variant_id":"09ad3d8b-1011-4000-8000-000000000006","menu_item_id":"09ad3d8b-0011-4000-8000-0000000000c1","display_order":5,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.386Z","updated_at":"2026-11-10T06:11:55.386Z"},{"id":"09ad3d8b-2011-4000-8000-000000000007","size":"","size_ar":"","size_latin":"","portion":"","price":850,"is_default":false,"variant_id":"09ad3d8b-1011-4000-8000-000000000007","menu_item_id":"09ad3d8b-0011-4000-8000-0000000000c1","display_order":6,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.386Z","updated_at":"2026-11-10T06:11:55.386Z"}]'::jsonb,
  '[]'::jsonb,
  '[]'::jsonb,
  '[]'::jsonb,
  NOW(),
  NOW()
)
ON CONFLICT (id) DO UPDATE SET
  restaurant_name = EXCLUDED.restaurant_name,
  name = EXCLUDED.name,
  name_ar = EXCLUDED.name_ar,
  name_latin = EXCLUDED.name_latin,
  category = EXCLUDED.category,
  category_id = EXCLUDED.category_id,
  cuisine_type_id = EXCLUDED.cuisine_type_id,
  price = EXCLUDED.price,
  is_available = EXCLUDED.is_available,
  image = EXCLUDED.image,
  images = EXCLUDED.images,
  variants = EXCLUDED.variants,
  pricing_options = EXCLUDED.pricing_options,
  updated_at = NOW();

-- 12. INSERT OR UPDATE MATLOUA
INSERT INTO public.menu_items (
  id,
  restaurant_id,
  restaurant_name,
  name,
  name_ar,
  name_latin,
  category,
  category_id,
  cuisine_type_id,
  price,
  is_available,
  is_featured,
  preparation_time,
  image,
  images,
  variants,
  pricing_options,
  ingredients,
  ingredients_ar,
  ingredients_latin,
  created_at,
  updated_at
) VALUES (
  '09ad3d8b-0012-4000-8000-0000000000c1',
  '09ad3d8b-004f-4035-bee8-9c63243c39e9',
  'Brothers Food',
  'Matloua',
  'مطلوع',
  'Matloua',
  'Matloua',
  '0eedae08-bb33-4d3b-987c-80031ba2153a',
  'e5021b58-9273-4d84-a56a-05da539f79db',
  300,
  true,
  false,
  10,
  'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/matloua.png',
  '["https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/matloua.png"]'::jsonb,
  '[{"id":"09ad3d8b-1012-4000-8000-000000000001","name":"Chawarma","name_ar":"شاورما","name_latin":"Chawarma","is_default":true,"is_available":true,"display_order":0,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0012-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.386Z","updated_at":"2026-11-10T06:11:55.386Z"},{"id":"09ad3d8b-1012-4000-8000-000000000002","name":"Viande","name_ar":"لحم","name_latin":"Viande","is_default":false,"is_available":true,"display_order":1,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0012-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.386Z","updated_at":"2026-11-10T06:11:55.386Z"},{"id":"09ad3d8b-1012-4000-8000-000000000003","name":"Foie","name_ar":"كبدة","name_latin":"Foie","is_default":false,"is_available":true,"display_order":2,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0012-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.386Z","updated_at":"2026-11-10T06:11:55.386Z"},{"id":"09ad3d8b-1012-4000-8000-000000000004","name":"Mix","name_ar":"ميكس","name_latin":"Mix","is_default":false,"is_available":true,"display_order":3,"description":"","description_ar":"","description_latin":"","menu_item_id":"09ad3d8b-0012-4000-8000-0000000000c1","created_at":"2026-11-10T06:11:55.386Z","updated_at":"2026-11-10T06:11:55.386Z"}]'::jsonb,
  '[{"id":"09ad3d8b-2012-4000-8000-000000000001","size":"","size_ar":"","size_latin":"","portion":"","price":300,"is_default":true,"variant_id":"09ad3d8b-1012-4000-8000-000000000001","menu_item_id":"09ad3d8b-0012-4000-8000-0000000000c1","display_order":0,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.386Z","updated_at":"2026-11-10T06:11:55.386Z"},{"id":"09ad3d8b-2012-4000-8000-000000000002","size":"","size_ar":"","size_latin":"","portion":"","price":350,"is_default":false,"variant_id":"09ad3d8b-1012-4000-8000-000000000002","menu_item_id":"09ad3d8b-0012-4000-8000-0000000000c1","display_order":1,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.386Z","updated_at":"2026-11-10T06:11:55.386Z"},{"id":"09ad3d8b-2012-4000-8000-000000000003","size":"","size_ar":"","size_latin":"","portion":"","price":400,"is_default":false,"variant_id":"09ad3d8b-1012-4000-8000-000000000003","menu_item_id":"09ad3d8b-0012-4000-8000-0000000000c1","display_order":2,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.386Z","updated_at":"2026-11-10T06:11:55.386Z"},{"id":"09ad3d8b-2012-4000-8000-000000000004","size":"","size_ar":"","size_latin":"","portion":"","price":500,"is_default":false,"variant_id":"09ad3d8b-1012-4000-8000-000000000004","menu_item_id":"09ad3d8b-0012-4000-8000-0000000000c1","display_order":3,"offer_types":[],"offer_details":{},"free_drinks_list":[],"is_limited_offer":false,"free_drinks_included":false,"free_drinks_quantity":1,"created_at":"2026-11-10T06:11:55.386Z","updated_at":"2026-11-10T06:11:55.386Z"}]'::jsonb,
  '[]'::jsonb,
  '[]'::jsonb,
  '[]'::jsonb,
  NOW(),
  NOW()
)
ON CONFLICT (id) DO UPDATE SET
  restaurant_name = EXCLUDED.restaurant_name,
  name = EXCLUDED.name,
  name_ar = EXCLUDED.name_ar,
  name_latin = EXCLUDED.name_latin,
  category = EXCLUDED.category,
  category_id = EXCLUDED.category_id,
  cuisine_type_id = EXCLUDED.cuisine_type_id,
  price = EXCLUDED.price,
  is_available = EXCLUDED.is_available,
  image = EXCLUDED.image,
  images = EXCLUDED.images,
  variants = EXCLUDED.variants,
  pricing_options = EXCLUDED.pricing_options,
  updated_at = NOW();

COMMIT;
