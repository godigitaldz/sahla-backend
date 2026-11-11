-- ============================================================================
-- Menu Updates for Brothers Food (مطعم برادرز فود)
-- Generated: 2026-11-10
-- Restaurant ID: 09ad3d8b-004f-4035-bee8-9c63243c39e9
-- ============================================================================

BEGIN;

-- 1. RETIRER PASTA (Retirée du nouveau menu)
UPDATE public.menu_items
SET is_available = false, updated_at = NOW()
WHERE id = '09ad3d8b-0001-4000-8000-0000000000c1' 
  AND restaurant_id = '09ad3d8b-004f-4035-bee8-9c63243c39e9';

-- 2. CALZONE (Mise à jour: Viande 600 DA, +Foie 700, +Mix 800, +Seryal 600)
UPDATE public.menu_items
SET 
  variants = '[{"id": "09ad3d8b-1002-4000-8000-000000000001", "name": "Poulet", "name_ar": "دجاج", "name_latin": "Poulet", "is_default": true, "display_order": 0, "menu_item_id": "09ad3d8b-0002-4000-8000-0000000000c1", "description": "", "description_ar": "", "description_latin": ""}, {"id": "09ad3d8b-1002-4000-8000-000000000002", "name": "Viande", "name_ar": "لحم", "name_latin": "Viande", "is_default": false, "display_order": 1, "menu_item_id": "09ad3d8b-0002-4000-8000-0000000000c1", "description": "", "description_ar": "", "description_latin": ""}, {"id": "09ad3d8b-1002-4000-8000-000000000003", "name": "Foie", "name_ar": "كبدة", "name_latin": "Foie", "is_default": false, "display_order": 2, "menu_item_id": "09ad3d8b-0002-4000-8000-0000000000c1", "description": "", "description_ar": "", "description_latin": ""}, {"id": "09ad3d8b-1002-4000-8000-000000000004", "name": "Mix", "name_ar": "ميكس", "name_latin": "Mix", "is_default": false, "display_order": 3, "menu_item_id": "09ad3d8b-0002-4000-8000-0000000000c1", "description": "", "description_ar": "", "description_latin": ""}, {"id": "09ad3d8b-1002-4000-8000-000000000005", "name": "Seryal", "name_ar": "سيريال", "name_latin": "Seryal", "is_default": false, "display_order": 4, "menu_item_id": "09ad3d8b-0002-4000-8000-0000000000c1", "description": "", "description_ar": "", "description_latin": ""}]'::jsonb,
  pricing_options = '[{"id": "09ad3d8b-2002-4000-8000-000000000001", "variant_id": "09ad3d8b-1002-4000-8000-000000000001", "size": "", "price": 500, "is_default": true, "display_order": 0, "menu_item_id": "09ad3d8b-0002-4000-8000-0000000000c1", "portion": "", "size_ar": "", "size_latin": "", "description": "", "offer_types": [], "offer_details": {}, "free_drinks_list": [], "is_limited_offer": false, "free_drinks_included": false, "free_drinks_quantity": 1}, {"id": "09ad3d8b-2002-4000-8000-000000000002", "variant_id": "09ad3d8b-1002-4000-8000-000000000002", "size": "", "price": 600, "is_default": false, "display_order": 1, "menu_item_id": "09ad3d8b-0002-4000-8000-0000000000c1", "portion": "", "size_ar": "", "size_latin": "", "description": "", "offer_types": [], "offer_details": {}, "free_drinks_list": [], "is_limited_offer": false, "free_drinks_included": false, "free_drinks_quantity": 1}, {"id": "09ad3d8b-2002-4000-8000-000000000003", "variant_id": "09ad3d8b-1002-4000-8000-000000000003", "size": "", "price": 700, "is_default": false, "display_order": 2, "menu_item_id": "09ad3d8b-0002-4000-8000-0000000000c1", "portion": "", "size_ar": "", "size_latin": "", "description": "", "offer_types": [], "offer_details": {}, "free_drinks_list": [], "is_limited_offer": false, "free_drinks_included": false, "free_drinks_quantity": 1}, {"id": "09ad3d8b-2002-4000-8000-000000000004", "variant_id": "09ad3d8b-1002-4000-8000-000000000004", "size": "", "price": 800, "is_default": false, "display_order": 3, "menu_item_id": "09ad3d8b-0002-4000-8000-0000000000c1", "portion": "", "size_ar": "", "size_latin": "", "description": "", "offer_types": [], "offer_details": {}, "free_drinks_list": [], "is_limited_offer": false, "free_drinks_included": false, "free_drinks_quantity": 1}, {"id": "09ad3d8b-2002-4000-8000-000000000005", "variant_id": "09ad3d8b-1002-4000-8000-000000000005", "size": "", "price": 600, "is_default": false, "display_order": 4, "menu_item_id": "09ad3d8b-0002-4000-8000-0000000000c1", "portion": "", "size_ar": "", "size_latin": "", "description": "", "offer_types": [], "offer_details": {}, "free_drinks_list": [], "is_limited_offer": false, "free_drinks_included": false, "free_drinks_quantity": 1}]'::jsonb,
  price = '500.00',
  name_ar = 'كالزون',
  name_latin = 'Calzone',
  updated_at = NOW()
WHERE id = '09ad3d8b-0002-4000-8000-0000000000c1' 
  AND restaurant_id = '09ad3d8b-004f-4035-bee8-9c63243c39e9';

-- 3. FAJITAS (Correction nom: فاجيتاس, +Mix 600 DA)
UPDATE public.menu_items
SET 
  name = 'Fajitas',
  name_ar = 'فاجيتاس',
  name_latin = 'Fajitas',
  variants = '[{"id": "09ad3d8b-1003-4000-8000-000000000001", "name": "Poulet", "name_ar": "دجاج", "name_latin": "Poulet", "is_default": true, "display_order": 0, "menu_item_id": "09ad3d8b-0003-4000-8000-0000000000c1", "description": "", "description_ar": "", "description_latin": ""}, {"id": "09ad3d8b-1003-4000-8000-000000000002", "name": "Viande", "name_ar": "لحم", "name_latin": "Viande", "is_default": false, "display_order": 1, "menu_item_id": "09ad3d8b-0003-4000-8000-0000000000c1", "description": "", "description_ar": "", "description_latin": ""}, {"id": "09ad3d8b-1003-4000-8000-000000000003", "name": "Foie", "name_ar": "كبدة", "name_latin": "Foie", "is_default": false, "display_order": 2, "menu_item_id": "09ad3d8b-0003-4000-8000-0000000000c1", "description": "", "description_ar": "", "description_latin": ""}, {"id": "09ad3d8b-1003-4000-8000-000000000004", "name": "Mix", "name_ar": "ميكس", "name_latin": "Mix", "is_default": false, "display_order": 3, "menu_item_id": "09ad3d8b-0003-4000-8000-0000000000c1", "description": "", "description_ar": "", "description_latin": ""}]'::jsonb,
  pricing_options = '[{"id": "09ad3d8b-2003-4000-8000-000000000001", "variant_id": "09ad3d8b-1003-4000-8000-000000000001", "size": "", "price": 250, "is_default": true, "display_order": 0, "menu_item_id": "09ad3d8b-0003-4000-8000-0000000000c1", "portion": "", "size_ar": "", "size_latin": "", "description": "", "offer_types": [], "offer_details": {}, "free_drinks_list": [], "is_limited_offer": false, "free_drinks_included": false, "free_drinks_quantity": 1}, {"id": "09ad3d8b-2003-4000-8000-000000000002", "variant_id": "09ad3d8b-1003-4000-8000-000000000002", "size": "", "price": 350, "is_default": false, "display_order": 1, "menu_item_id": "09ad3d8b-0003-4000-8000-0000000000c1", "portion": "", "size_ar": "", "size_latin": "", "description": "", "offer_types": [], "offer_details": {}, "free_drinks_list": [], "is_limited_offer": false, "free_drinks_included": false, "free_drinks_quantity": 1}, {"id": "09ad3d8b-2003-4000-8000-000000000003", "variant_id": "09ad3d8b-1003-4000-8000-000000000003", "size": "", "price": 450, "is_default": false, "display_order": 2, "menu_item_id": "09ad3d8b-0003-4000-8000-0000000000c1", "portion": "", "size_ar": "", "size_latin": "", "description": "", "offer_types": [], "offer_details": {}, "free_drinks_list": [], "is_limited_offer": false, "free_drinks_included": false, "free_drinks_quantity": 1}, {"id": "09ad3d8b-2003-4000-8000-000000000004", "variant_id": "09ad3d8b-1003-4000-8000-000000000004", "size": "", "price": 600, "is_default": false, "display_order": 3, "menu_item_id": "09ad3d8b-0003-4000-8000-0000000000c1", "portion": "", "size_ar": "", "size_latin": "", "description": "", "offer_types": [], "offer_details": {}, "free_drinks_list": [], "is_limited_offer": false, "free_drinks_included": false, "free_drinks_quantity": 1}]'::jsonb,
  price = '250.00',
  updated_at = NOW()
WHERE id = '09ad3d8b-0003-4000-8000-0000000000c1' 
  AND restaurant_id = '09ad3d8b-004f-4035-bee8-9c63243c39e9';

-- 4. BURGER (Mise à jour: Poulet 250, Crispy 400, +Seryal 600)
UPDATE public.menu_items
SET 
  variants = '[{"id": "09ad3d8b-1004-4000-8000-000000000001", "name": "Poulet", "name_ar": "دجاج", "name_latin": "Poulet", "is_default": true, "display_order": 0, "menu_item_id": "09ad3d8b-0004-4000-8000-0000000000c1", "description": "", "description_ar": "", "description_latin": ""}, {"id": "09ad3d8b-1004-4000-8000-000000000002", "name": "Viande", "name_ar": "لحم", "name_latin": "Viande", "is_default": false, "display_order": 1, "menu_item_id": "09ad3d8b-0004-4000-8000-0000000000c1", "description": "", "description_ar": "", "description_latin": ""}, {"id": "09ad3d8b-1004-4000-8000-000000000003", "name": "Crispy", "name_ar": "كريسبي", "name_latin": "Crispy", "is_default": false, "display_order": 2, "menu_item_id": "09ad3d8b-0004-4000-8000-0000000000c1", "description": "", "description_ar": "", "description_latin": ""}, {"id": "09ad3d8b-1004-4000-8000-000000000004", "name": "Double", "name_ar": "دوبل", "name_latin": "Double", "is_default": false, "display_order": 3, "menu_item_id": "09ad3d8b-0004-4000-8000-0000000000c1", "description": "", "description_ar": "", "description_latin": ""}, {"id": "09ad3d8b-1004-4000-8000-000000000005", "name": "Seryal", "name_ar": "سيريال", "name_latin": "Seryal", "is_default": false, "display_order": 4, "menu_item_id": "09ad3d8b-0004-4000-8000-0000000000c1", "description": "", "description_ar": "", "description_latin": ""}]'::jsonb,
  pricing_options = '[{"id": "09ad3d8b-2004-4000-8000-000000000001", "variant_id": "09ad3d8b-1004-4000-8000-000000000001", "size": "", "price": 250, "is_default": true, "display_order": 0, "menu_item_id": "09ad3d8b-0004-4000-8000-0000000000c1", "portion": "", "size_ar": "", "size_latin": "", "description": "", "offer_types": [], "offer_details": {}, "free_drinks_list": [], "is_limited_offer": false, "free_drinks_included": false, "free_drinks_quantity": 1}, {"id": "09ad3d8b-2004-4000-8000-000000000002", "variant_id": "09ad3d8b-1004-4000-8000-000000000002", "size": "", "price": 300, "is_default": false, "display_order": 1, "menu_item_id": "09ad3d8b-0004-4000-8000-0000000000c1", "portion": "", "size_ar": "", "size_latin": "", "description": "", "offer_types": [], "offer_details": {}, "free_drinks_list": [], "is_limited_offer": false, "free_drinks_included": false, "free_drinks_quantity": 1}, {"id": "09ad3d8b-2004-4000-8000-000000000003", "variant_id": "09ad3d8b-1004-4000-8000-000000000003", "size": "", "price": 400, "is_default": false, "display_order": 2, "menu_item_id": "09ad3d8b-0004-4000-8000-0000000000c1", "portion": "", "size_ar": "", "size_latin": "", "description": "", "offer_types": [], "offer_details": {}, "free_drinks_list": [], "is_limited_offer": false, "free_drinks_included": false, "free_drinks_quantity": 1}, {"id": "09ad3d8b-2004-4000-8000-000000000004", "variant_id": "09ad3d8b-1004-4000-8000-000000000004", "size": "", "price": 450, "is_default": false, "display_order": 3, "menu_item_id": "09ad3d8b-0004-4000-8000-0000000000c1", "portion": "", "size_ar": "", "size_latin": "", "description": "", "offer_types": [], "offer_details": {}, "free_drinks_list": [], "is_limited_offer": false, "free_drinks_included": false, "free_drinks_quantity": 1}, {"id": "09ad3d8b-2004-4000-8000-000000000005", "variant_id": "09ad3d8b-1004-4000-8000-000000000005", "size": "", "price": 600, "is_default": false, "display_order": 4, "menu_item_id": "09ad3d8b-0004-4000-8000-0000000000c1", "portion": "", "size_ar": "", "size_latin": "", "description": "", "offer_types": [], "offer_details": {}, "free_drinks_list": [], "is_limited_offer": false, "free_drinks_included": false, "free_drinks_quantity": 1}]'::jsonb,
  price = '250.00',
  name_ar = 'برجر',
  name_latin = 'Burger',
  updated_at = NOW()
WHERE id = '09ad3d8b-0004-4000-8000-0000000000c1' 
  AND restaurant_id = '09ad3d8b-004f-4035-bee8-9c63243c39e9';

-- 5. MALFOUF (Mise à jour: Mix 500, +Brothers 750)
UPDATE public.menu_items
SET 
  variants = '[{"id": "09ad3d8b-1006-4000-8000-000000000001", "name": "Poulet", "name_ar": "دجاج", "name_latin": "Poulet", "is_default": true, "display_order": 0, "menu_item_id": "09ad3d8b-0006-4000-8000-0000000000c1", "description": "", "description_ar": "", "description_latin": ""}, {"id": "09ad3d8b-1006-4000-8000-000000000002", "name": "Viande", "name_ar": "لحم", "name_latin": "Viande", "is_default": false, "display_order": 1, "menu_item_id": "09ad3d8b-0006-4000-8000-0000000000c1", "description": "", "description_ar": "", "description_latin": ""}, {"id": "09ad3d8b-1006-4000-8000-000000000003", "name": "Foie", "name_ar": "كبدة", "name_latin": "Foie", "is_default": false, "display_order": 2, "menu_item_id": "09ad3d8b-0006-4000-8000-0000000000c1", "description": "", "description_ar": "", "description_latin": ""}, {"id": "09ad3d8b-1006-4000-8000-000000000004", "name": "Crispy", "name_ar": "كريسبي", "name_latin": "Crispy", "is_default": false, "display_order": 3, "menu_item_id": "09ad3d8b-0006-4000-8000-0000000000c1", "description": "", "description_ar": "", "description_latin": ""}, {"id": "09ad3d8b-1006-4000-8000-000000000005", "name": "Mix", "name_ar": "ميكس", "name_latin": "Mix", "is_default": false, "display_order": 4, "menu_item_id": "09ad3d8b-0006-4000-8000-0000000000c1", "description": "", "description_ar": "", "description_latin": ""}, {"id": "09ad3d8b-1006-4000-8000-000000000006", "name": "Brothers", "name_ar": "برادرز", "name_latin": "Brothers", "is_default": false, "display_order": 5, "menu_item_id": "09ad3d8b-0006-4000-8000-0000000000c1", "description": "", "description_ar": "", "description_latin": ""}]'::jsonb,
  pricing_options = '[{"id": "09ad3d8b-2006-4000-8000-000000000001", "variant_id": "09ad3d8b-1006-4000-8000-000000000001", "size": "", "price": 300, "is_default": true, "display_order": 0, "menu_item_id": "09ad3d8b-0006-4000-8000-0000000000c1", "portion": "", "size_ar": "", "size_latin": "", "description": "", "offer_types": [], "offer_details": {}, "free_drinks_list": [], "is_limited_offer": false, "free_drinks_included": false, "free_drinks_quantity": 1}, {"id": "09ad3d8b-2006-4000-8000-000000000002", "variant_id": "09ad3d8b-1006-4000-8000-000000000002", "size": "", "price": 350, "is_default": false, "display_order": 1, "menu_item_id": "09ad3d8b-0006-4000-8000-0000000000c1", "portion": "", "size_ar": "", "size_latin": "", "description": "", "offer_types": [], "offer_details": {}, "free_drinks_list": [], "is_limited_offer": false, "free_drinks_included": false, "free_drinks_quantity": 1}, {"id": "09ad3d8b-2006-4000-8000-000000000003", "variant_id": "09ad3d8b-1006-4000-8000-000000000003", "size": "", "price": 400, "is_default": false, "display_order": 2, "menu_item_id": "09ad3d8b-0006-4000-8000-0000000000c1", "portion": "", "size_ar": "", "size_latin": "", "description": "", "offer_types": [], "offer_details": {}, "free_drinks_list": [], "is_limited_offer": false, "free_drinks_included": false, "free_drinks_quantity": 1}, {"id": "09ad3d8b-2006-4000-8000-000000000004", "variant_id": "09ad3d8b-1006-4000-8000-000000000004", "size": "", "price": 400, "is_default": false, "display_order": 3, "menu_item_id": "09ad3d8b-0006-4000-8000-0000000000c1", "portion": "", "size_ar": "", "size_latin": "", "description": "", "offer_types": [], "offer_details": {}, "free_drinks_list": [], "is_limited_offer": false, "free_drinks_included": false, "free_drinks_quantity": 1}, {"id": "09ad3d8b-2006-4000-8000-000000000005", "variant_id": "09ad3d8b-1006-4000-8000-000000000005", "size": "", "price": 500, "is_default": false, "display_order": 4, "menu_item_id": "09ad3d8b-0006-4000-8000-0000000000c1", "portion": "", "size_ar": "", "size_latin": "", "description": "", "offer_types": [], "offer_details": {}, "free_drinks_list": [], "is_limited_offer": false, "free_drinks_included": false, "free_drinks_quantity": 1}, {"id": "09ad3d8b-2006-4000-8000-000000000006", "variant_id": "09ad3d8b-1006-4000-8000-000000000006", "size": "", "price": 750, "is_default": false, "display_order": 5, "menu_item_id": "09ad3d8b-0006-4000-8000-0000000000c1", "portion": "", "size_ar": "", "size_latin": "", "description": "", "offer_types": [], "offer_details": {}, "free_drinks_list": [], "is_limited_offer": false, "free_drinks_included": false, "free_drinks_quantity": 1}]'::jsonb,
  price = '300.00',
  name_ar = 'ملفوف',
  name_latin = 'Malfouf',
  updated_at = NOW()
WHERE id = '09ad3d8b-0006-4000-8000-0000000000c1' 
  AND restaurant_id = '09ad3d8b-004f-4035-bee8-9c63243c39e9';

-- 6. TACOS (Mise à jour: Crispy 550, Mix 650, +4 Fromage 800)
UPDATE public.menu_items
SET 
  variants = '[{"id": "09ad3d8b-1007-4000-8000-000000000001", "name": "Chawarma", "name_ar": "شاورما", "name_latin": "Chawarma", "is_default": true, "display_order": 0, "menu_item_id": "09ad3d8b-0007-4000-8000-0000000000c1", "description": "", "description_ar": "", "description_latin": ""}, {"id": "09ad3d8b-1007-4000-8000-000000000002", "name": "Viande", "name_ar": "لحم", "name_latin": "Viande", "is_default": false, "display_order": 1, "menu_item_id": "09ad3d8b-0007-4000-8000-0000000000c1", "description": "", "description_ar": "", "description_latin": ""}, {"id": "09ad3d8b-1007-4000-8000-000000000003", "name": "Crispy", "name_ar": "كريسبي", "name_latin": "Crispy", "is_default": false, "display_order": 2, "menu_item_id": "09ad3d8b-0007-4000-8000-0000000000c1", "description": "", "description_ar": "", "description_latin": ""}, {"id": "09ad3d8b-1007-4000-8000-000000000004", "name": "Foie", "name_ar": "كبدة", "name_latin": "Foie", "is_default": false, "display_order": 3, "menu_item_id": "09ad3d8b-0007-4000-8000-0000000000c1", "description": "", "description_ar": "", "description_latin": ""}, {"id": "09ad3d8b-1007-4000-8000-000000000005", "name": "Mix", "name_ar": "ميكس", "name_latin": "Mix", "is_default": false, "display_order": 4, "menu_item_id": "09ad3d8b-0007-4000-8000-0000000000c1", "description": "", "description_ar": "", "description_latin": ""}, {"id": "09ad3d8b-1007-4000-8000-000000000006", "name": "4 Fromage", "name_ar": "4 أجبان", "name_latin": "4 Fromage", "is_default": false, "display_order": 5, "menu_item_id": "09ad3d8b-0007-4000-8000-0000000000c1", "description": "", "description_ar": "", "description_latin": ""}]'::jsonb,
  pricing_options = '[{"id": "09ad3d8b-2007-4000-8000-000000000001", "variant_id": "09ad3d8b-1007-4000-8000-000000000001", "size": "", "price": 400, "is_default": true, "display_order": 0, "menu_item_id": "09ad3d8b-0007-4000-8000-0000000000c1", "portion": "", "size_ar": "", "size_latin": "", "description": "", "offer_types": [], "offer_details": {}, "free_drinks_list": [], "is_limited_offer": false, "free_drinks_included": false, "free_drinks_quantity": 1}, {"id": "09ad3d8b-2007-4000-8000-000000000002", "variant_id": "09ad3d8b-1007-4000-8000-000000000002", "size": "", "price": 450, "is_default": false, "display_order": 1, "menu_item_id": "09ad3d8b-0007-4000-8000-0000000000c1", "portion": "", "size_ar": "", "size_latin": "", "description": "", "offer_types": [], "offer_details": {}, "free_drinks_list": [], "is_limited_offer": false, "free_drinks_included": false, "free_drinks_quantity": 1}, {"id": "09ad3d8b-2007-4000-8000-000000000003", "variant_id": "09ad3d8b-1007-4000-8000-000000000003", "size": "", "price": 550, "is_default": false, "display_order": 2, "menu_item_id": "09ad3d8b-0007-4000-8000-0000000000c1", "portion": "", "size_ar": "", "size_latin": "", "description": "", "offer_types": [], "offer_details": {}, "free_drinks_list": [], "is_limited_offer": false, "free_drinks_included": false, "free_drinks_quantity": 1}, {"id": "09ad3d8b-2007-4000-8000-000000000004", "variant_id": "09ad3d8b-1007-4000-8000-000000000004", "size": "", "price": 500, "is_default": false, "display_order": 3, "menu_item_id": "09ad3d8b-0007-4000-8000-0000000000c1", "portion": "", "size_ar": "", "size_latin": "", "description": "", "offer_types": [], "offer_details": {}, "free_drinks_list": [], "is_limited_offer": false, "free_drinks_included": false, "free_drinks_quantity": 1}, {"id": "09ad3d8b-2007-4000-8000-000000000005", "variant_id": "09ad3d8b-1007-4000-8000-000000000005", "size": "", "price": 650, "is_default": false, "display_order": 4, "menu_item_id": "09ad3d8b-0007-4000-8000-0000000000c1", "portion": "", "size_ar": "", "size_latin": "", "description": "", "offer_types": [], "offer_details": {}, "free_drinks_list": [], "is_limited_offer": false, "free_drinks_included": false, "free_drinks_quantity": 1}, {"id": "09ad3d8b-2007-4000-8000-000000000006", "variant_id": "09ad3d8b-1007-4000-8000-000000000006", "size": "", "price": 800, "is_default": false, "display_order": 5, "menu_item_id": "09ad3d8b-0007-4000-8000-0000000000c1", "portion": "", "size_ar": "", "size_latin": "", "description": "", "offer_types": [], "offer_details": {}, "free_drinks_list": [], "is_limited_offer": false, "free_drinks_included": false, "free_drinks_quantity": 1}]'::jsonb,
  price = '400.00',
  name_ar = 'طاكوس',
  name_latin = 'Tacos',
  updated_at = NOW()
WHERE id = '09ad3d8b-0007-4000-8000-0000000000c1' 
  AND restaurant_id = '09ad3d8b-004f-4035-bee8-9c63243c39e9';

-- 7. POUTINE (Restructuration: 2 tailles M & Family, +BR 3000)
UPDATE public.menu_items
SET 
  variants = '[{"id": "09ad3d8b-1005-4000-8000-000000000001", "name": "Chawarma", "name_ar": "شاورما", "name_latin": "Chawarma", "is_default": true, "display_order": 0, "menu_item_id": "09ad3d8b-0005-4000-8000-0000000000c1", "description": "", "description_ar": "", "description_latin": ""}, {"id": "09ad3d8b-1005-4000-8000-000000000002", "name": "Viande", "name_ar": "لحم", "name_latin": "Viande", "is_default": false, "display_order": 1, "menu_item_id": "09ad3d8b-0005-4000-8000-0000000000c1", "description": "", "description_ar": "", "description_latin": ""}, {"id": "09ad3d8b-1005-4000-8000-000000000003", "name": "Crispy", "name_ar": "كريسبي", "name_latin": "Crispy", "is_default": false, "display_order": 2, "menu_item_id": "09ad3d8b-0005-4000-8000-0000000000c1", "description": "", "description_ar": "", "description_latin": ""}, {"id": "09ad3d8b-1005-4000-8000-000000000004", "name": "BR", "name_ar": "بي آر", "name_latin": "BR", "is_default": false, "display_order": 3, "menu_item_id": "09ad3d8b-0005-4000-8000-0000000000c1", "description": "", "description_ar": "", "description_latin": ""}]'::jsonb,
  pricing_options = '[{"id": "09ad3d8b-2005-4000-8000-000000000001", "variant_id": "09ad3d8b-1005-4000-8000-000000000001", "size": "M", "size_ar": "متوسط", "size_latin": "M", "price": 400, "is_default": true, "display_order": 0, "menu_item_id": "09ad3d8b-0005-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2005-4000-8000-000000000002", "variant_id": "09ad3d8b-1005-4000-8000-000000000001", "size": "Family", "size_ar": "عائلي", "size_latin": "Family", "price": 1800, "is_default": false, "display_order": 1, "menu_item_id": "09ad3d8b-0005-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2005-4000-8000-000000000003", "variant_id": "09ad3d8b-1005-4000-8000-000000000002", "size": "M", "size_ar": "متوسط", "size_latin": "M", "price": 450, "is_default": false, "display_order": 2, "menu_item_id": "09ad3d8b-0005-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2005-4000-8000-000000000004", "variant_id": "09ad3d8b-1005-4000-8000-000000000002", "size": "Family", "size_ar": "عائلي", "size_latin": "Family", "price": 1900, "is_default": false, "display_order": 3, "menu_item_id": "09ad3d8b-0005-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2005-4000-8000-000000000005", "variant_id": "09ad3d8b-1005-4000-8000-000000000003", "size": "M", "size_ar": "متوسط", "size_latin": "M", "price": 700, "is_default": false, "display_order": 4, "menu_item_id": "09ad3d8b-0005-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2005-4000-8000-000000000006", "variant_id": "09ad3d8b-1005-4000-8000-000000000003", "size": "Family", "size_ar": "عائلي", "size_latin": "Family", "price": 2500, "is_default": false, "display_order": 5, "menu_item_id": "09ad3d8b-0005-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2005-4000-8000-000000000007", "variant_id": "09ad3d8b-1005-4000-8000-000000000004", "size": "Family", "size_ar": "عائلي", "size_latin": "Family", "price": 3000, "is_default": false, "display_order": 6, "menu_item_id": "09ad3d8b-0005-4000-8000-0000000000c1"}]'::jsonb,
  price = '400.00',
  name_ar = 'بوتين',
  name_latin = 'Poutine',
  updated_at = NOW()
WHERE id = '09ad3d8b-0005-4000-8000-0000000000c1' 
  AND restaurant_id = '09ad3d8b-004f-4035-bee8-9c63243c39e9';

-- 8. PIZZA (13 variétés en tailles M & L = 26 options)
INSERT INTO public.menu_items (
  id, restaurant_id, name, name_latin, name_ar, description, description_latin, description_ar,
  image, price, category, category_id, is_available, is_featured, preparation_time,
  restaurant_name, rating, review_count, cuisine_type_id,
  variants, pricing_options, supplements, images,
  free_drinks_included, free_drinks_list, free_drinks_quantity,
  is_spicy, spice_level, is_traditional, is_vegetarian, is_vegan, is_gluten_free, is_dairy_free, is_low_sodium, is_drink,
  tax_free, available_schedule_enabled
) VALUES (
  '09ad3d8b-0008-4000-8000-0000000000c1', '09ad3d8b-004f-4035-bee8-9c63243c39e9', 'Pizza', 'Pizza', 'بيتزا', '', '', '',
  'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/Pizza/Sauce%20toamte/Margerita.png', '250.00', 'Pizza', 'e2551ceb-8102-4000-8000-000000000002', true, false, 20,
  'Brothers Food', '0.00', 0, 'e5021b58-9273-4d84-a56a-05da539f79db',
  '[{"id": "09ad3d8b-1008-4000-8000-000000000001", "name": "Margherita", "name_ar": "مارغريتا", "name_latin": "Margherita", "is_default": true, "display_order": 0, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-1008-4000-8000-000000000002", "name": "Pizza double fromage", "name_ar": "بيتزا مضاعفة الجبن", "name_latin": "Pizza double fromage", "is_default": false, "display_order": 1, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-1008-4000-8000-000000000003", "name": "Poulet", "name_ar": "دجاج", "name_latin": "Poulet", "is_default": false, "display_order": 2, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-1008-4000-8000-000000000004", "name": "Viande", "name_ar": "لحم", "name_latin": "Viande", "is_default": false, "display_order": 3, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-1008-4000-8000-000000000005", "name": "Thon", "name_ar": "تونة", "name_latin": "Thon", "is_default": false, "display_order": 4, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-1008-4000-8000-000000000006", "name": "Poulet Fumé", "name_ar": "دجاج مدخن", "name_latin": "Poulet Fumé", "is_default": false, "display_order": 5, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-1008-4000-8000-000000000007", "name": "4 Saisons", "name_ar": "الفصول الأربعة", "name_latin": "4 Saisons", "is_default": false, "display_order": 6, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-1008-4000-8000-000000000008", "name": "3 Fromage", "name_ar": "3 أجبان", "name_latin": "3 Fromage", "is_default": false, "display_order": 7, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-1008-4000-8000-000000000009", "name": "Végétarian", "name_ar": "نباتية", "name_latin": "Végétarian", "is_default": false, "display_order": 8, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-1008-4000-8000-000000000010", "name": "Végétarian Spécial", "name_ar": "نباتية خاصة", "name_latin": "Végétarian Spécial", "is_default": false, "display_order": 9, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-1008-4000-8000-000000000011", "name": "Boisée Simple", "name_ar": "بوايزيه بسيطة", "name_latin": "Boisée Simple", "is_default": false, "display_order": 10, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-1008-4000-8000-000000000012", "name": "Boisée Poulet", "name_ar": "بوايزيه بالدجاج", "name_latin": "Boisée Poulet", "is_default": false, "display_order": 11, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-1008-4000-8000-000000000013", "name": "Pizza peperoni", "name_ar": "بيتزا بيبيروني", "name_latin": "Pizza peperoni", "is_default": false, "display_order": 12, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}]'::jsonb,
  '[{"id": "09ad3d8b-2008-4000-8000-000000000001", "variant_id": "09ad3d8b-1008-4000-8000-000000000001", "size": "M", "size_ar": "متوسط", "size_latin": "M", "price": 250, "is_default": true, "display_order": 0, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2008-4000-8000-000000000002", "variant_id": "09ad3d8b-1008-4000-8000-000000000001", "size": "L", "size_ar": "كبير", "size_latin": "L", "price": 650, "is_default": false, "display_order": 1, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2008-4000-8000-000000000003", "variant_id": "09ad3d8b-1008-4000-8000-000000000002", "size": "M", "size_ar": "متوسط", "size_latin": "M", "price": 350, "is_default": true, "display_order": 2, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2008-4000-8000-000000000004", "variant_id": "09ad3d8b-1008-4000-8000-000000000002", "size": "L", "size_ar": "كبير", "size_latin": "L", "price": 750, "is_default": false, "display_order": 3, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2008-4000-8000-000000000005", "variant_id": "09ad3d8b-1008-4000-8000-000000000003", "size": "M", "size_ar": "متوسط", "size_latin": "M", "price": 450, "is_default": true, "display_order": 4, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2008-4000-8000-000000000006", "variant_id": "09ad3d8b-1008-4000-8000-000000000003", "size": "L", "size_ar": "كبير", "size_latin": "L", "price": 850, "is_default": false, "display_order": 5, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2008-4000-8000-000000000007", "variant_id": "09ad3d8b-1008-4000-8000-000000000004", "size": "M", "size_ar": "متوسط", "size_latin": "M", "price": 450, "is_default": true, "display_order": 6, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2008-4000-8000-000000000008", "variant_id": "09ad3d8b-1008-4000-8000-000000000004", "size": "L", "size_ar": "كبير", "size_latin": "L", "price": 1000, "is_default": false, "display_order": 7, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2008-4000-8000-000000000009", "variant_id": "09ad3d8b-1008-4000-8000-000000000005", "size": "M", "size_ar": "متوسط", "size_latin": "M", "price": 450, "is_default": true, "display_order": 8, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2008-4000-8000-000000000010", "variant_id": "09ad3d8b-1008-4000-8000-000000000005", "size": "L", "size_ar": "كبير", "size_latin": "L", "price": 850, "is_default": false, "display_order": 9, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2008-4000-8000-000000000011", "variant_id": "09ad3d8b-1008-4000-8000-000000000006", "size": "M", "size_ar": "متوسط", "size_latin": "M", "price": 650, "is_default": true, "display_order": 10, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2008-4000-8000-000000000012", "variant_id": "09ad3d8b-1008-4000-8000-000000000006", "size": "L", "size_ar": "كبير", "size_latin": "L", "price": 1100, "is_default": false, "display_order": 11, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2008-4000-8000-000000000013", "variant_id": "09ad3d8b-1008-4000-8000-000000000007", "size": "M", "size_ar": "متوسط", "size_latin": "M", "price": 800, "is_default": true, "display_order": 12, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2008-4000-8000-000000000014", "variant_id": "09ad3d8b-1008-4000-8000-000000000007", "size": "L", "size_ar": "كبير", "size_latin": "L", "price": 1800, "is_default": false, "display_order": 13, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2008-4000-8000-000000000015", "variant_id": "09ad3d8b-1008-4000-8000-000000000008", "size": "M", "size_ar": "متوسط", "size_latin": "M", "price": 700, "is_default": true, "display_order": 14, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2008-4000-8000-000000000016", "variant_id": "09ad3d8b-1008-4000-8000-000000000008", "size": "L", "size_ar": "كبير", "size_latin": "L", "price": 1400, "is_default": false, "display_order": 15, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2008-4000-8000-000000000017", "variant_id": "09ad3d8b-1008-4000-8000-000000000009", "size": "M", "size_ar": "متوسط", "size_latin": "M", "price": 400, "is_default": true, "display_order": 16, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2008-4000-8000-000000000018", "variant_id": "09ad3d8b-1008-4000-8000-000000000009", "size": "L", "size_ar": "كبير", "size_latin": "L", "price": 800, "is_default": false, "display_order": 17, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2008-4000-8000-000000000019", "variant_id": "09ad3d8b-1008-4000-8000-000000000010", "size": "M", "size_ar": "متوسط", "size_latin": "M", "price": 800, "is_default": true, "display_order": 18, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2008-4000-8000-000000000020", "variant_id": "09ad3d8b-1008-4000-8000-000000000010", "size": "L", "size_ar": "كبير", "size_latin": "L", "price": 1400, "is_default": false, "display_order": 19, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2008-4000-8000-000000000021", "variant_id": "09ad3d8b-1008-4000-8000-000000000011", "size": "M", "size_ar": "متوسط", "size_latin": "M", "price": 400, "is_default": true, "display_order": 20, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2008-4000-8000-000000000022", "variant_id": "09ad3d8b-1008-4000-8000-000000000011", "size": "L", "size_ar": "كبير", "size_latin": "L", "price": 650, "is_default": false, "display_order": 21, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2008-4000-8000-000000000023", "variant_id": "09ad3d8b-1008-4000-8000-000000000012", "size": "M", "size_ar": "متوسط", "size_latin": "M", "price": 550, "is_default": true, "display_order": 22, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2008-4000-8000-000000000024", "variant_id": "09ad3d8b-1008-4000-8000-000000000012", "size": "L", "size_ar": "كبير", "size_latin": "L", "price": 950, "is_default": false, "display_order": 23, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2008-4000-8000-000000000025", "variant_id": "09ad3d8b-1008-4000-8000-000000000013", "size": "M", "size_ar": "متوسط", "size_latin": "M", "price": 550, "is_default": true, "display_order": 24, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2008-4000-8000-000000000026", "variant_id": "09ad3d8b-1008-4000-8000-000000000013", "size": "L", "size_ar": "كبير", "size_latin": "L", "price": 1100, "is_default": false, "display_order": 25, "menu_item_id": "09ad3d8b-0008-4000-8000-0000000000c1"}]'::jsonb,
  '[]'::jsonb, '["https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/Pizza/Sauce%20toamte/Margerita.png"]'::jsonb,
  false, ARRAY[]::text[], 1,
  false, 0, false, false, false, false, false, false, false,
  false, false
)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  name_ar = EXCLUDED.name_ar,
  name_latin = EXCLUDED.name_latin,
  image = EXCLUDED.image,
  price = EXCLUDED.price,
  category = EXCLUDED.category,
  category_id = EXCLUDED.category_id,
  variants = EXCLUDED.variants,
  pricing_options = EXCLUDED.pricing_options,
  images = EXCLUDED.images,
  is_available = true,
  updated_at = NOW();

-- 9. MAKLOUB / مقلوب (5 variantes)
INSERT INTO public.menu_items (
  id, restaurant_id, name, name_latin, name_ar, description, description_latin, description_ar,
  image, price, category, category_id, is_available, is_featured, preparation_time,
  restaurant_name, rating, review_count, cuisine_type_id,
  variants, pricing_options, supplements, images,
  free_drinks_included, free_drinks_list, free_drinks_quantity,
  is_spicy, spice_level, is_traditional, is_vegetarian, is_vegan, is_gluten_free, is_dairy_free, is_low_sodium, is_drink,
  tax_free, available_schedule_enabled
) VALUES (
  '09ad3d8b-0009-4000-8000-0000000000c1', '09ad3d8b-004f-4035-bee8-9c63243c39e9', 'Makloub', 'Makloub', 'مقلوب', '', '', '',
  'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/makloub.png', '450.00', 'Makloub', '354f5144-06c7-4711-b1c0-73d22d709a2d', true, false, 20,
  'Brothers Food', '0.00', 0, 'e5021b58-9273-4d84-a56a-05da539f79db',
  '[{"id": "09ad3d8b-1009-4000-8000-000000000001", "name": "Chawarma", "name_ar": "شاورما", "name_latin": "Chawarma", "is_default": true, "display_order": 0, "menu_item_id": "09ad3d8b-0009-4000-8000-0000000000c1"}, {"id": "09ad3d8b-1009-4000-8000-000000000002", "name": "Viande", "name_ar": "لحم", "name_latin": "Viande", "is_default": false, "display_order": 1, "menu_item_id": "09ad3d8b-0009-4000-8000-0000000000c1"}, {"id": "09ad3d8b-1009-4000-8000-000000000003", "name": "Foie", "name_ar": "كبدة", "name_latin": "Foie", "is_default": false, "display_order": 2, "menu_item_id": "09ad3d8b-0009-4000-8000-0000000000c1"}, {"id": "09ad3d8b-1009-4000-8000-000000000004", "name": "Mix", "name_ar": "ميكس", "name_latin": "Mix", "is_default": false, "display_order": 3, "menu_item_id": "09ad3d8b-0009-4000-8000-0000000000c1"}, {"id": "09ad3d8b-1009-4000-8000-000000000005", "name": "BR", "name_ar": "بي آر", "name_latin": "BR", "is_default": false, "display_order": 4, "menu_item_id": "09ad3d8b-0009-4000-8000-0000000000c1"}]'::jsonb,
  '[{"id": "09ad3d8b-2009-4000-8000-000000000001", "variant_id": "09ad3d8b-1009-4000-8000-000000000001", "size": "", "price": 450, "is_default": true, "display_order": 0, "menu_item_id": "09ad3d8b-0009-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2009-4000-8000-000000000002", "variant_id": "09ad3d8b-1009-4000-8000-000000000002", "size": "", "price": 500, "is_default": false, "display_order": 1, "menu_item_id": "09ad3d8b-0009-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2009-4000-8000-000000000003", "variant_id": "09ad3d8b-1009-4000-8000-000000000003", "size": "", "price": 600, "is_default": false, "display_order": 2, "menu_item_id": "09ad3d8b-0009-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2009-4000-8000-000000000004", "variant_id": "09ad3d8b-1009-4000-8000-000000000004", "size": "", "price": 650, "is_default": false, "display_order": 3, "menu_item_id": "09ad3d8b-0009-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2009-4000-8000-000000000005", "variant_id": "09ad3d8b-1009-4000-8000-000000000005", "size": "", "price": 800, "is_default": false, "display_order": 4, "menu_item_id": "09ad3d8b-0009-4000-8000-0000000000c1"}]'::jsonb,
  '[]'::jsonb, '["https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/makloub.png"]'::jsonb,
  false, ARRAY[]::text[], 1,
  false, 0, false, false, false, false, false, false, false,
  false, false
)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  name_ar = EXCLUDED.name_ar,
  name_latin = EXCLUDED.name_latin,
  image = EXCLUDED.image,
  price = EXCLUDED.price,
  category = EXCLUDED.category,
  category_id = EXCLUDED.category_id,
  variants = EXCLUDED.variants,
  pricing_options = EXCLUDED.pricing_options,
  images = EXCLUDED.images,
  is_available = true,
  updated_at = NOW();

-- 10. PLATS VARIÉS / أطباق متنوعة (5 variantes sans Plat GR)
INSERT INTO public.menu_items (
  id, restaurant_id, name, name_latin, name_ar, description, description_latin, description_ar,
  image, price, category, category_id, is_available, is_featured, preparation_time,
  restaurant_name, rating, review_count, cuisine_type_id,
  variants, pricing_options, supplements, images,
  free_drinks_included, free_drinks_list, free_drinks_quantity,
  is_spicy, spice_level, is_traditional, is_vegetarian, is_vegan, is_gluten_free, is_dairy_free, is_low_sodium, is_drink,
  tax_free, available_schedule_enabled
) VALUES (
  '09ad3d8b-0010-4000-8000-0000000000c1', '09ad3d8b-004f-4035-bee8-9c63243c39e9', 'Plats', 'Plats', 'أطباق', '', '', '',
  'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/Plats.png', '600.00', 'Plats', '2feb3511-4c37-4252-92b3-310936749abe', true, false, 20,
  'Brothers Food', '0.00', 0, 'e5021b58-9273-4d84-a56a-05da539f79db',
  '[{"id": "09ad3d8b-1010-4000-8000-000000000001", "name": "Chawarma", "name_ar": "شاورما", "name_latin": "Chawarma", "is_default": true, "display_order": 0, "menu_item_id": "09ad3d8b-0010-4000-8000-0000000000c1"}, {"id": "09ad3d8b-1010-4000-8000-000000000002", "name": "Viande", "name_ar": "لحم", "name_latin": "Viande", "is_default": false, "display_order": 1, "menu_item_id": "09ad3d8b-0010-4000-8000-0000000000c1"}, {"id": "09ad3d8b-1010-4000-8000-000000000003", "name": "Plat Crispy", "name_ar": "طبق كريسبي", "name_latin": "Plat Crispy", "is_default": false, "display_order": 2, "menu_item_id": "09ad3d8b-0010-4000-8000-0000000000c1"}, {"id": "09ad3d8b-1010-4000-8000-000000000004", "name": "Crispy", "name_ar": "كريسبي", "name_latin": "Crispy", "is_default": false, "display_order": 3, "menu_item_id": "09ad3d8b-0010-4000-8000-0000000000c1"}, {"id": "09ad3d8b-1010-4000-8000-000000000005", "name": "Mix", "name_ar": "ميكس", "name_latin": "Mix", "is_default": false, "display_order": 4, "menu_item_id": "09ad3d8b-0010-4000-8000-0000000000c1"}]'::jsonb,
  '[{"id": "09ad3d8b-2010-4000-8000-000000000001", "variant_id": "09ad3d8b-1010-4000-8000-000000000001", "size": "", "price": 600, "is_default": true, "display_order": 0, "menu_item_id": "09ad3d8b-0010-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2010-4000-8000-000000000002", "variant_id": "09ad3d8b-1010-4000-8000-000000000002", "size": "", "price": 700, "is_default": false, "display_order": 1, "menu_item_id": "09ad3d8b-0010-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2010-4000-8000-000000000003", "variant_id": "09ad3d8b-1010-4000-8000-000000000003", "size": "", "price": 800, "is_default": false, "display_order": 2, "menu_item_id": "09ad3d8b-0010-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2010-4000-8000-000000000004", "variant_id": "09ad3d8b-1010-4000-8000-000000000004", "size": "", "price": 850, "is_default": false, "display_order": 3, "menu_item_id": "09ad3d8b-0010-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2010-4000-8000-000000000005", "variant_id": "09ad3d8b-1010-4000-8000-000000000005", "size": "", "price": 1000, "is_default": false, "display_order": 4, "menu_item_id": "09ad3d8b-0010-4000-8000-0000000000c1"}]'::jsonb,
  '[]'::jsonb, '["https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/Plats.png"]'::jsonb,
  false, ARRAY[]::text[], 1,
  false, 0, false, false, false, false, false, false, false,
  false, false
)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  name_ar = EXCLUDED.name_ar,
  name_latin = EXCLUDED.name_latin,
  image = EXCLUDED.image,
  price = EXCLUDED.price,
  category = EXCLUDED.category,
  category_id = EXCLUDED.category_id,
  variants = EXCLUDED.variants,
  pricing_options = EXCLUDED.pricing_options,
  images = EXCLUDED.images,
  is_available = true,
  updated_at = NOW();

-- 11. SANDWICH / سندويش (7 variantes)
INSERT INTO public.menu_items (
  id, restaurant_id, name, name_latin, name_ar, description, description_latin, description_ar,
  image, price, category, category_id, is_available, is_featured, preparation_time,
  restaurant_name, rating, review_count, cuisine_type_id,
  variants, pricing_options, supplements, images,
  free_drinks_included, free_drinks_list, free_drinks_quantity,
  is_spicy, spice_level, is_traditional, is_vegetarian, is_vegan, is_gluten_free, is_dairy_free, is_low_sodium, is_drink,
  tax_free, available_schedule_enabled
) VALUES (
  '09ad3d8b-0011-4000-8000-0000000000c1', '09ad3d8b-004f-4035-bee8-9c63243c39e9', 'Sandwich', 'Sandwich', 'سندويش', '', '', '',
  'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/sandwich.png', '300.00', 'Sandwich', '842f79fa-b4fc-426d-a73d-11281178bc44', true, false, 20,
  'Brothers Food', '0.00', 0, 'e5021b58-9273-4d84-a56a-05da539f79db',
  '[{"id": "09ad3d8b-1011-4000-8000-000000000001", "name": "Chawarma", "name_ar": "شاورما", "name_latin": "Chawarma", "is_default": true, "display_order": 0, "menu_item_id": "09ad3d8b-0011-4000-8000-0000000000c1"}, {"id": "09ad3d8b-1011-4000-8000-000000000002", "name": "Viande", "name_ar": "لحم", "name_latin": "Viande", "is_default": false, "display_order": 1, "menu_item_id": "09ad3d8b-0011-4000-8000-0000000000c1"}, {"id": "09ad3d8b-1011-4000-8000-000000000003", "name": "Crispy", "name_ar": "كريسبي", "name_latin": "Crispy", "is_default": false, "display_order": 2, "menu_item_id": "09ad3d8b-0011-4000-8000-0000000000c1"}, {"id": "09ad3d8b-1011-4000-8000-000000000004", "name": "Mix", "name_ar": "ميكس", "name_latin": "Mix", "is_default": false, "display_order": 3, "menu_item_id": "09ad3d8b-0011-4000-8000-0000000000c1"}, {"id": "09ad3d8b-1011-4000-8000-000000000005", "name": "Normal + 4 Fromage", "name_ar": "عادي + 4 أجبان", "name_latin": "Normal + 4 Fromage", "is_default": false, "display_order": 4, "menu_item_id": "09ad3d8b-0011-4000-8000-0000000000c1"}, {"id": "09ad3d8b-1011-4000-8000-000000000006", "name": "+ 4 Fromage", "name_ar": "+ 4 أجبان", "name_latin": "+ 4 Fromage", "is_default": false, "display_order": 5, "menu_item_id": "09ad3d8b-0011-4000-8000-0000000000c1"}, {"id": "09ad3d8b-1011-4000-8000-000000000007", "name": "Special", "name_ar": "خاص", "name_latin": "Special", "is_default": false, "display_order": 6, "menu_item_id": "09ad3d8b-0011-4000-8000-0000000000c1"}]'::jsonb,
  '[{"id": "09ad3d8b-2011-4000-8000-000000000001", "variant_id": "09ad3d8b-1011-4000-8000-000000000001", "size": "", "price": 300, "is_default": true, "display_order": 0, "menu_item_id": "09ad3d8b-0011-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2011-4000-8000-000000000002", "variant_id": "09ad3d8b-1011-4000-8000-000000000002", "size": "", "price": 350, "is_default": false, "display_order": 1, "menu_item_id": "09ad3d8b-0011-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2011-4000-8000-000000000003", "variant_id": "09ad3d8b-1011-4000-8000-000000000003", "size": "", "price": 400, "is_default": false, "display_order": 2, "menu_item_id": "09ad3d8b-0011-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2011-4000-8000-000000000004", "variant_id": "09ad3d8b-1011-4000-8000-000000000004", "size": "", "price": 450, "is_default": false, "display_order": 3, "menu_item_id": "09ad3d8b-0011-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2011-4000-8000-000000000005", "variant_id": "09ad3d8b-1011-4000-8000-000000000005", "size": "", "price": 400, "is_default": false, "display_order": 4, "menu_item_id": "09ad3d8b-0011-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2011-4000-8000-000000000006", "variant_id": "09ad3d8b-1011-4000-8000-000000000006", "size": "", "price": 700, "is_default": false, "display_order": 5, "menu_item_id": "09ad3d8b-0011-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2011-4000-8000-000000000007", "variant_id": "09ad3d8b-1011-4000-8000-000000000007", "size": "", "price": 850, "is_default": false, "display_order": 6, "menu_item_id": "09ad3d8b-0011-4000-8000-0000000000c1"}]'::jsonb,
  '[]'::jsonb, '["https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/sandwich.png"]'::jsonb,
  false, ARRAY[]::text[], 1,
  false, 0, false, false, false, false, false, false, false,
  false, false
)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  name_ar = EXCLUDED.name_ar,
  name_latin = EXCLUDED.name_latin,
  image = EXCLUDED.image,
  price = EXCLUDED.price,
  category = EXCLUDED.category,
  category_id = EXCLUDED.category_id,
  variants = EXCLUDED.variants,
  pricing_options = EXCLUDED.pricing_options,
  images = EXCLUDED.images,
  is_available = true,
  updated_at = NOW();

-- 12. MATLO3 / مطلوع (4 variantes sans 4 Fromage)
INSERT INTO public.menu_items (
  id, restaurant_id, name, name_latin, name_ar, description, description_latin, description_ar,
  image, price, category, category_id, is_available, is_featured, preparation_time,
  restaurant_name, rating, review_count, cuisine_type_id,
  variants, pricing_options, supplements, images,
  free_drinks_included, free_drinks_list, free_drinks_quantity,
  is_spicy, spice_level, is_traditional, is_vegetarian, is_vegan, is_gluten_free, is_dairy_free, is_low_sodium, is_drink,
  tax_free, available_schedule_enabled
) VALUES (
  '09ad3d8b-0012-4000-8000-0000000000c1', '09ad3d8b-004f-4035-bee8-9c63243c39e9', 'Matlo3', 'Matlo3', 'مطلوع', '', '', '',
  'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/matloua.png', '300.00', 'Matlo3', '0eedae08-bb33-4d3b-987c-80031ba2153a', true, false, 20,
  'Brothers Food', '0.00', 0, 'e5021b58-9273-4d84-a56a-05da539f79db',
  '[{"id": "09ad3d8b-1012-4000-8000-000000000001", "name": "Chawarma", "name_ar": "شاورما", "name_latin": "Chawarma", "is_default": true, "display_order": 0, "menu_item_id": "09ad3d8b-0012-4000-8000-0000000000c1"}, {"id": "09ad3d8b-1012-4000-8000-000000000002", "name": "Viande", "name_ar": "لحم", "name_latin": "Viande", "is_default": false, "display_order": 1, "menu_item_id": "09ad3d8b-0012-4000-8000-0000000000c1"}, {"id": "09ad3d8b-1012-4000-8000-000000000003", "name": "Foie", "name_ar": "كبدة", "name_latin": "Foie", "is_default": false, "display_order": 2, "menu_item_id": "09ad3d8b-0012-4000-8000-0000000000c1"}, {"id": "09ad3d8b-1012-4000-8000-000000000004", "name": "Mix", "name_ar": "ميكس", "name_latin": "Mix", "is_default": false, "display_order": 3, "menu_item_id": "09ad3d8b-0012-4000-8000-0000000000c1"}]'::jsonb,
  '[{"id": "09ad3d8b-2012-4000-8000-000000000001", "variant_id": "09ad3d8b-1012-4000-8000-000000000001", "size": "", "price": 300, "is_default": true, "display_order": 0, "menu_item_id": "09ad3d8b-0012-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2012-4000-8000-000000000002", "variant_id": "09ad3d8b-1012-4000-8000-000000000002", "size": "", "price": 350, "is_default": false, "display_order": 1, "menu_item_id": "09ad3d8b-0012-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2012-4000-8000-000000000003", "variant_id": "09ad3d8b-1012-4000-8000-000000000003", "size": "", "price": 400, "is_default": false, "display_order": 2, "menu_item_id": "09ad3d8b-0012-4000-8000-0000000000c1"}, {"id": "09ad3d8b-2012-4000-8000-000000000004", "variant_id": "09ad3d8b-1012-4000-8000-000000000004", "size": "", "price": 500, "is_default": false, "display_order": 3, "menu_item_id": "09ad3d8b-0012-4000-8000-0000000000c1"}]'::jsonb,
  '[]'::jsonb, '["https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/matloua.png"]'::jsonb,
  false, ARRAY[]::text[], 1,
  false, 0, false, false, false, false, false, false, false,
  false, false
)
ON CONFLICT (id) DO UPDATE SET
  name = EXCLUDED.name,
  name_ar = EXCLUDED.name_ar,
  name_latin = EXCLUDED.name_latin,
  image = EXCLUDED.image,
  price = EXCLUDED.price,
  category = EXCLUDED.category,
  category_id = EXCLUDED.category_id,
  variants = EXCLUDED.variants,
  pricing_options = EXCLUDED.pricing_options,
  images = EXCLUDED.images,
  is_available = true,
  updated_at = NOW();

COMMIT;
