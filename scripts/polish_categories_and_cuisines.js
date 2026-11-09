import dotenv from 'dotenv';
dotenv.config({ path: '.env.local' });
import { supabaseAdmin } from '../src/config/supabase.js';

async function polish() {
  console.log('🚀 Starting Category and Cuisine Polish...');

  // ==========================================
  // 1. CREATE / ENSURE HEALTHY MEALS CATEGORY
  // ==========================================
  const healthyCuisineId = '13a11997-2175-4057-9129-4f4b639d8db6';
  const healthyCatId = 'a1010000-0000-4000-8000-000000000001';

  const { data: existingHealthyCat } = await supabaseAdmin
    .from('categories')
    .select('id')
    .eq('id', healthyCatId)
    .maybeSingle();

  if (!existingHealthyCat) {
    console.log('✨ Creating Healthy Meals category for Healthy cuisine...');
    const { error: insErr } = await supabaseAdmin.from('categories').insert({
      id: healthyCatId,
      name: 'Healthy Meals',
      name_ar: 'وجبات صحية',
      name_latin: 'Healthy Meals',
      cuisine_type_id: healthyCuisineId,
      icon: 'https://pub-66ae0208f9aa4258a7d4e176cd1b62df.r2.dev/Healthy.png',
      is_active: true,
      display_order: 1,
      show_in_menu_list_section: true,
    });
    if (insErr) console.error('Error inserting healthy category:', insErr);
    else console.log('✅ Healthy Meals category created successfully.');
  } else {
    await supabaseAdmin
      .from('categories')
      .update({
        name: 'Healthy Meals',
        name_ar: 'وجبات صحية',
        name_latin: 'Healthy Meals',
        cuisine_type_id: healthyCuisineId,
        is_active: true,
        display_order: 1,
        show_in_menu_list_section: true,
      })
      .eq('id', healthyCatId);
    console.log('✅ Healthy Meals category updated.');
  }

  // ==========================================
  // 2. POLISH FAST FOOD CATEGORIES
  // ==========================================
  const fastFoodCuisineId = 'e5021b58-9273-4d84-a56a-05da539f79db';

  // Deactivate empty Fast Food categories
  const fastFoodEmptyCatIds = [
    '96d1c4d7-7d55-4517-99ec-cb51ecf81929', // Burrito (0 items)
    'b7e8f9a0-1c2d-4e3f-9a8b-7c6d5e4f3a2b', // Sushi (0 items)
    '7d3f4a2c-1b8e-4e9a-a2c3-9f8e7d6c5b4a', // Quessadilla (0 items)
    '0afea1cf-7592-47e1-8487-cb3a59670da4', // Special Packs (0 items)
    '4c8f1e2a-9b0d-4c7e-8a3f-c9f4a2b10e01', // Duplicate Box
  ];

  console.log('🧹 Deactivating empty/duplicate Fast Food categories...');
  await supabaseAdmin
    .from('categories')
    .update({ is_active: false, show_in_menu_list_section: false })
    .in('id', fastFoodEmptyCatIds);

  // Set clean display orders for active Fast Food categories
  const fastFoodCategoryOrders = [
    { name: 'Burger', order: 1 },
    { name: 'Pizza', order: 2 },
    { name: 'Tacos', order: 3 },
    { name: 'Malfouf', order: 4 },
    { name: 'Matloua', order: 5 },
    { name: 'Sandwich', order: 6 },
    { name: 'Panini', order: 7 },
    { name: 'Calzone', order: 8 },
    { name: 'Makloub', order: 9 },
    { name: 'Nos Boxs', order: 10 },
    { name: 'Gratin', order: 11 },
    { name: 'Pasta', order: 12 },
    { name: 'Crispy', order: 13 },
    { name: 'Poutine', order: 14 },
    { name: 'Fajitas', order: 15 },
    { name: 'Salade', order: 16 },
    { name: 'Chapati', order: 17 },
    { name: 'Panuozzo', order: 18 },
  ];

  console.log('🔢 Setting clean display orders for Fast Food categories...');
  for (const item of fastFoodCategoryOrders) {
    await supabaseAdmin
      .from('categories')
      .update({
        display_order: item.order,
        is_active: true,
        show_in_menu_list_section: true,
      })
      .eq('cuisine_type_id', fastFoodCuisineId)
      .eq('name', item.name);
  }

  // Ensure Fast Food Plats category is attached to Fast Food
  const platsCatId = '2feb3511-4c37-4252-92b3-310936749abe';
  await supabaseAdmin
    .from('categories')
    .update({
      cuisine_type_id: fastFoodCuisineId,
      display_order: 19,
      is_active: true,
      show_in_menu_list_section: true,
    })
    .eq('id', platsCatId);

  // ==========================================
  // 3. POLISH TRADITIONAL CATEGORIES
  // ==========================================
  const traditionalCuisineId = '8e37ad82-4332-48d7-a248-d7aee9f0daec';

  console.log('🍲 Aligning Traditional categories...');
  // Attach Chicken & Meat to Traditional
  await supabaseAdmin
    .from('categories')
    .update({
      cuisine_type_id: traditionalCuisineId,
      display_order: 2,
      is_active: true,
      show_in_menu_list_section: true,
      name_ar: 'دجاج ولحوم',
    })
    .eq('id', 'a2c95081-64f9-40ae-957d-131a351aeb7a');

  // Attach Soupe to Traditional
  await supabaseAdmin
    .from('categories')
    .update({
      cuisine_type_id: traditionalCuisineId,
      display_order: 3,
      is_active: true,
      show_in_menu_list_section: true,
      name_ar: 'شربة',
    })
    .eq('id', 'f632e223-d09c-45bf-b0fd-62626bf15ec6');

  // Bourak in Traditional
  await supabaseAdmin
    .from('categories')
    .update({
      cuisine_type_id: traditionalCuisineId,
      display_order: 4,
      is_active: true,
      show_in_menu_list_section: true,
      name_ar: 'بوراك',
    })
    .eq('id', 'af874476-ba53-481a-ae72-eed267cd9f04');

  // Main Traditional category
  await supabaseAdmin
    .from('categories')
    .update({
      display_order: 1,
      is_active: true,
      show_in_menu_list_section: true,
      name_ar: 'تقليدي',
    })
    .eq('id', 'ae2d2029-cb25-4905-b358-62c608695b6c');

  // ==========================================
  // 4. POLISH DESSERTS CATEGORIES
  // ==========================================
  const dessertsCuisineId = '150e05cb-24c5-49bd-8dfa-cab1d5b870ba';

  console.log('🍰 Polishing Desserts categories...');
  // Deactivate broken San Sebastien
  await supabaseAdmin
    .from('categories')
    .update({ is_active: false, show_in_menu_list_section: false })
    .eq('id', '842fcb8a-039b-429f-bcfa-f96a739f1203');

  const dessertOrders = [
    { name: 'ارز باللبن', order: 1 },
    { name: 'Crepes', order: 2 },
    { name: 'Gaufres', order: 3 },
    { name: 'Pancakes', order: 4 },
    { name: 'Cakes', order: 5 },
    { name: 'Cheesecake', order: 6 },
    { name: 'Tiramisu', order: 7 },
    { name: 'Cookies & Biscuits', order: 8 },
    { name: 'Tarte', order: 9 },
    { name: 'Desserts Crémeux', order: 10 },
    { name: 'Milkshakes', order: 11 },
    { name: 'Jus', order: 12 },
    { name: 'Boxs', order: 13 },
    { name: 'Cake Dubai', order: 14 },
    { name: 'Delice Wonder', order: 15 },
    { name: 'La Snickers', order: 16 },
  ];

  for (const item of dessertOrders) {
    await supabaseAdmin
      .from('categories')
      .update({
        display_order: item.order,
        is_active: true,
        show_in_menu_list_section: true,
      })
      .eq('cuisine_type_id', dessertsCuisineId)
      .eq('name', item.name);
  }

  // ==========================================
  // 5. DEACTIVATE ORPHAN / UNUSED CATEGORIES
  // ==========================================
  console.log('🧹 Deactivating remaining orphan categories...');
  await supabaseAdmin
    .from('categories')
    .update({ is_active: false, show_in_menu_list_section: false })
    .in('id', [
      'ed9cef8b-7d40-460d-b5ea-70e96032c7e7', // Orphan Entrées (0 items)
      '35dcc8a8-6d56-4b28-98a1-b1b3a430cd76', // Orphan Calzone duplicate
    ]);

  // ==========================================
  // 6. POLISH CUISINE TYPES
  // ==========================================
  console.log('🏷️ Polishing cuisine_types table...');
  // Deactivate unused/empty cuisines
  await supabaseAdmin
    .from('cuisine_types')
    .update({ is_active: false })
    .in('name', [
      'seafood',
      'salés',
      'Tunisien',
      'Turkey',
      'Entrées',
      'El Souri',
      'Italien',
    ]);

  // Ensure pinned cuisines have clean names and sort order
  const pinnedCuisines = [
    {
      id: healthyCuisineId,
      order: 1,
      name_ar: 'صحي',
      name_latin: 'Healthy',
      pinned: true,
    },
    {
      id: fastFoodCuisineId,
      order: 2,
      name_ar: 'أكل سريع',
      name_latin: 'Fast Food',
      pinned: true,
    },
    {
      id: dessertsCuisineId,
      order: 3,
      name_ar: 'حلويات',
      name_latin: 'Desserts',
      pinned: true,
    },
    {
      id: traditionalCuisineId,
      order: 4,
      name_ar: 'تقليدي',
      name_latin: 'Traditional',
      pinned: true,
    },
    {
      id: 'd3e000fb-6124-4758-a2b7-3f14b92c35d1', // Grills
      order: 5,
      name_ar: 'مشاوي',
      name_latin: 'Grills',
      pinned: true,
    },
  ];

  for (const pc of pinnedCuisines) {
    await supabaseAdmin
      .from('cuisine_types')
      .update({
        is_active: true,
        pinned_to_home_category_row: true,
        home_category_row_sort_order: pc.order,
        name_ar: pc.name_ar,
        name_latin: pc.name_latin,
      })
      .eq('id', pc.id);
  }

  // ==========================================
  // 7. POLISH MENU ITEMS IDS & CATEGORIES
  // (strictly category_id, category, cuisine_type_id only - NO touch to price, variants, sizes, logic)
  // ==========================================
  console.log('🍕 Polishing menu items category and cuisine alignments...');

  // A) Fast Food Pasta: move Fast Food restaurant pasta items to Fast Food Pasta category
  const fastFoodPastaCatId = 'e1f2a3b4-c5d6-4e7f-8a9b-0c1d2e3f4a5b';
  const fastFoodPastaItemIds = [
    '31c78771-0008-4000-8000-0000000000c1', // Brothers Food
    '0b8e7278-654d-4e08-a53c-a75ea9c5a153', // Mr Burger
    'c990cf1b-8a5d-4ed7-84f5-67d3aeae5066', // Unlock Food
  ];
  await supabaseAdmin
    .from('menu_items')
    .update({
      category_id: fastFoodPastaCatId,
      category: 'Pasta',
      cuisine_type_id: fastFoodCuisineId,
    })
    .in('id', fastFoodPastaItemIds);
  console.log('  -> Updated 3 Fast Food pasta items.');

  // B) Fast Food Panuozzo: Oliva Food
  const fastFoodPanuozzoCatId = '80bdc0b3-6931-434c-aa42-8bb9bf423e3c';
  await supabaseAdmin
    .from('menu_items')
    .update({
      category_id: fastFoodPanuozzoCatId,
      category: 'Panuozzo',
      cuisine_type_id: fastFoodCuisineId,
    })
    .eq('id', 'fe38a1d8-d824-4d74-b3c6-5f7f5eb958cd');
  console.log('  -> Updated 1 Panuozzo item.');

  // C) Fast Food Calzone: Oliva Food & Quick Food items
  const fastFoodCalzoneCatId = '22a8cb5b-87c8-41c2-837f-bdccf8fa330e';
  await supabaseAdmin
    .from('menu_items')
    .update({
      category_id: fastFoodCalzoneCatId,
      category: 'Calzone',
      cuisine_type_id: fastFoodCuisineId,
    })
    .in('id', [
      'c4f5e1af-2410-4d66-93d3-9aaeb6af1b01', // Oliva Food
      '7a7f45b5-e621-4f18-bb9f-818612185c69', // Quick food
      '4366ba7b-6002-4fc8-a89e-4a6c8e3b1ba2', // Quick food
    ]);
  console.log('  -> Updated 3 Calzone items.');

  // D) Morphine Food Puccia, Soufflee, Snack
  const sandwichCatId = '842f79fa-b4fc-426d-a73d-11281178bc44';
  await supabaseAdmin
    .from('menu_items')
    .update({
      category_id: sandwichCatId,
      category: 'Sandwich',
      cuisine_type_id: fastFoodCuisineId,
    })
    .eq('id', 'cd7de7a2-0003-4c1e-8000-000000000001'); // Puccia

  await supabaseAdmin
    .from('menu_items')
    .update({
      category_id: fastFoodCalzoneCatId,
      category: 'Calzone',
      cuisine_type_id: fastFoodCuisineId,
    })
    .eq('id', 'cd7de7a2-0004-4c1e-8000-000000000001'); // Soufflee

  await supabaseAdmin
    .from('menu_items')
    .update({
      category_id: sandwichCatId,
      category: 'Sandwich',
      cuisine_type_id: fastFoodCuisineId,
    })
    .eq('id', 'cd7de7a2-0005-4c1e-8000-000000000001'); // Snack
  console.log('  -> Updated Morphine Food sandwich/calzone items.');

  // E) Box merge: Unlock food box -> Nos Boxs
  const nosBoxsCatId = 'd231e942-019e-4df4-a190-8fb542ddebcd';
  await supabaseAdmin
    .from('menu_items')
    .update({
      category_id: nosBoxsCatId,
      category: 'Nos Boxs',
      cuisine_type_id: fastFoodCuisineId,
    })
    .eq('id', '2032d847-fec3-4481-912f-6c1bf875d658');
  console.log('  -> Merged Unlock Food box item into Nos Boxs.');

  // F) Oliva Food Plat: change cuisine from Grills to Fast Food
  await supabaseAdmin
    .from('menu_items')
    .update({
      category_id: platsCatId,
      category: 'Plats',
      cuisine_type_id: fastFoodCuisineId,
    })
    .eq('id', '0e0e26e0-c732-4c79-9e40-07941fc3afac');
  console.log('  -> Updated Oliva Food Plat to Fast Food.');

  // G) Traditional Bourak: link to Bourak category
  const bourakCatId = 'af874476-ba53-481a-ae72-eed267cd9f04';
  await supabaseAdmin
    .from('menu_items')
    .update({
      category_id: bourakCatId,
      category: 'Bourak',
      cuisine_type_id: traditionalCuisineId,
    })
    .eq('id', '8c7e8931-46a2-45eb-a655-1c2d59cef8dc');
  console.log('  -> Linked Bourak item to Bourak category.');

  // H) Traditional dishes that were in Plats: link to Traditional category
  const traditionalCatId = 'ae2d2029-cb25-4905-b358-62c608695b6c';
  const traditionalInPlatsIds = [
    '2b5f544c-5e9c-4f4e-9ddd-a411b2faa8c6', // أرز (دار جدي)
    'e3249945-4339-4dcd-b070-7964dc28e50b', // شكشوكة (دار جدي)
    '2274176b-2741-48fa-9fe6-0bdd032f0b4c', // Gratin Aubergine (زراري)
    '88ae9332-ea79-4c63-9d7e-dc09cfd433ce', // Chiflor (زراري)
    '111aa2eb-0595-40c2-9103-19fb7a68908d', // بيري (دار جدي)
  ];
  await supabaseAdmin
    .from('menu_items')
    .update({
      category_id: traditionalCatId,
      category: 'Traditional',
      cuisine_type_id: traditionalCuisineId,
    })
    .in('id', traditionalInPlatsIds);
  console.log('  -> Linked 5 Traditional dishes to Traditional category.');

  // I) Healthy items: link all 11 healthy dishes to Healthy Meals category
  const healthyItemIds = [
    'a1010001-0000-4000-8000-000000000001', // وجبة دجاج
    'a1010002-0000-4000-8000-000000000001', // وجبة دجاج متبل
    'a1010003-0000-4000-8000-000000000001', // وجبة تونة
    'a1010004-0000-4000-8000-000000000001', // وجبة كبدة دجاج
    'a1010005-0000-4000-8000-000000000001', // وجبة لحم
    '6d68cb9d-e4a9-4572-a73b-b4aaca00afb5', // سباغيتي
    '7b1d9cc1-795a-49c0-adfb-b0e780c80f4f', // أرز
    '3b6ed942-7d57-4861-b21f-1de11d515bbe', // بطاطا بيري
    '8e3e203a-c9ab-441a-a7e4-f0aafe94f3ee', // بطاطا سوطي
    '2200860d-561c-4d50-a945-d57a6f60cb87', // برغل
    'e960b685-0004-4c1e-8000-000000000001', // Healthy Plates
    '3ce821f0-6fad-4ada-8d42-64a918ef3097', // باستا (Diety Food)
  ];
  await supabaseAdmin
    .from('menu_items')
    .update({
      category_id: healthyCatId,
      category: 'Healthy Meals',
      cuisine_type_id: healthyCuisineId,
    })
    .in('id', healthyItemIds);
  console.log('  -> Linked 12 items to Healthy Meals category under Healthy.');

  // J) Desserts in Oliva Food:
  const dessertsCremeuxCatId = '92ecbdf7-69e6-4ec5-a769-70d15af12752';
  const tiramisuCatId = '53847970-7432-4d45-8c75-45608efca6f0';

  await supabaseAdmin
    .from('menu_items')
    .update({
      category_id: tiramisuCatId,
      category: 'Tiramisu',
      cuisine_type_id: dessertsCuisineId,
    })
    .eq('id', '39220969-6e75-40f6-9de2-03c5ec6c0582'); // Tiramissu

  await supabaseAdmin
    .from('menu_items')
    .update({
      category_id: dessertsCremeuxCatId,
      category: 'Desserts Crémeux',
      cuisine_type_id: dessertsCuisineId,
    })
    .in('id', [
      '781f5c72-c040-4450-b452-99a576778889', // Flan
      'a464f2ce-4fff-4c1e-af37-c6a9a960d52f', // Mousse Au Chocolat
      'a865af6a-177e-4d9d-b867-5192a9cf5ffa', // Salade De Fruits
    ]);
  console.log('  -> Linked 4 Oliva Food desserts to Desserts cuisine.');

  // K) Milkshakes in Daily Dose & SAVINI 07:
  const milkshakesCatId = '1f46cba8-1001-4c1e-9000-000000000007';
  await supabaseAdmin
    .from('menu_items')
    .update({
      category_id: milkshakesCatId,
      category: 'Milkshakes',
      cuisine_type_id: dessertsCuisineId,
    })
    .in('id', [
      '528800b8-368d-a417-5227-18b7e414cdcf', // Daily Dose
      '1ed231b6-5763-4f50-8d1f-c00316efdcf9', // SAVINI 07
    ]);
  console.log('  -> Linked 2 Milkshake items to Desserts Milkshakes category.');

  console.log('🎉 Category and Cuisine Polish Complete!');
}

polish().catch(console.error);
