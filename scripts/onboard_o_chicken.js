import { createClient } from '@supabase/supabase-js';
import dotenv from 'dotenv';
dotenv.config({ path: './.env.local' });

const supabase = createClient(process.env.SUPABASE_URL, process.env.SUPABASE_SERVICE_ROLE_KEY);

const OWNER_ID = '5e2cf6c6-eaf0-440a-9ac2-42f4be409bc4';
const RESTAURANT_ID = '0c0c1101-0000-4000-8000-000000000002';
const REQUEST_ID = '0c0c1101-0000-4000-8000-000000000001';

const CATEGORIES = {
  PLATS: '2feb3511-4c37-4252-92b3-310936749abe',
  SANDWICH: '842f79fa-b4fc-426d-a73d-11281178bc44',
  CHICKEN_MEAT: 'a2c95081-64f9-40ae-957d-131a351aeb7a',
};

const CUISINES = {
  FAST_FOOD: 'e5021b58-9273-4d84-a56a-05da539f79db',
  GRILLS: 'd3e000fb-6124-4758-a2b7-3f14b92c35d1',
};

const openingHours = {
  monday: { open: '11:00', close: '20:00', isOpen: true, breakEnabled: false, hasBreak: false, breakStart: null, breakEnd: null },
  tuesday: { open: '11:00', close: '20:00', isOpen: true, breakEnabled: false, hasBreak: false, breakStart: null, breakEnd: null },
  wednesday: { open: '11:00', close: '20:00', isOpen: true, breakEnabled: false, hasBreak: false, breakStart: null, breakEnd: null },
  thursday: { open: '11:00', close: '20:00', isOpen: true, breakEnabled: false, hasBreak: false, breakStart: null, breakEnd: null },
  friday: { open: '17:00', close: '20:00', isOpen: true, breakEnabled: false, hasBreak: false, breakStart: null, breakEnd: null },
  saturday: { open: '11:00', close: '20:00', isOpen: true, breakEnabled: false, hasBreak: false, breakStart: null, breakEnd: null },
  sunday: { open: '11:00', close: '20:00', isOpen: true, breakEnabled: false, hasBreak: false, breakStart: null, breakEnd: null },
};

async function onboard() {
  console.log('🚀 Starting O-Chicken Biskra onboarding...');

  // 1. Create or Update Restaurant Request
  const requestData = {
    id: REQUEST_ID,
    user_id: OWNER_ID,
    user_name: 'O-Chicken Biskra Owner',
    user_email: '',
    restaurant_name: 'O-Chicken Biskra',
    restaurant_description: 'دجاج مشوي بمذاق رائع، أطباق، سندويتشات وعروض يومية مميزة',
    restaurant_address: 'الكورس، مقابل ثانوية بوصيعات ومعهد الموسيقى - بسكرة',
    restaurant_phone: '0556150951',
    status: 'approved',
    rejection_reason: null,
    reviewed_by: 'System Admin',
    reviewed_at: new Date().toISOString(),
    wilaya: 'Biskra',
    city: 'Biskra',
    state: 'Biskra',
    logo_url: 'https://pub-e75807f307834b89a8e0a2463ebb914f.r2.dev/847939330_18564854512076917_9054660436327542566_n.jpg',
    cover_image_url: 'https://pub-011aba279eb84591b0d96b9b9415ce2e.r2.dev/0-chicken.jpeg',
    latitude: 34.8464528,
    longitude: 5.6990164,
    opening_hours: openingHours,
    closing_hours: openingHours,
    updated_at: new Date().toISOString(),
  };

  const { data: reqResult, error: reqErr } = await supabase
    .from('restaurant_requests')
    .upsert(requestData, { onConflict: 'id' })
    .select()
    .single();

  if (reqErr) {
    console.error('❌ Error creating/updating restaurant request:', reqErr);
    process.exit(1);
  }
  console.log('✅ Restaurant request created/approved:', reqResult.id, reqResult.restaurant_name);

  // 2. Promote user to restaurant_owner
  const { data: userUpdate, error: userErr } = await supabase
    .from('user_profiles')
    .update({
      role: 'restaurant_owner',
      full_name: 'O-Chicken Biskra',
      name: 'O-Chicken Biskra',
      updated_at: new Date().toISOString(),
    })
    .eq('id', OWNER_ID)
    .select()
    .single();

  if (userErr) {
    console.error('❌ Error promoting user role:', userErr);
    process.exit(1);
  }
  console.log('✅ User promoted to restaurant_owner:', userUpdate.id, userUpdate.role);

  // 3. Create or Update Restaurant
  const restaurantData = {
    id: RESTAURANT_ID,
    owner_id: OWNER_ID,
    name: 'O-Chicken Biskra',
    name_ar: 'أو تشيكن بسكرة',
    name_latin: 'O-Chicken Biskra',
    description: 'دجاج مشوي بمذاق رائع، أطباق، سندويتشات وعروض يومية مميزة',
    phone: '0556150951',
    address_line1: 'الكورس، مقابل ثانوية بوصيعات ومعهد الموسيقى',
    city: 'Biskra',
    state: 'Biskra',
    wilaya: 'Biskra',
    postal_code: '07000',
    latitude: 34.8464528,
    longitude: 5.6990164,
    rating: 5.0,
    review_count: 0,
    delivery_fee: 0,
    minimum_order: 200,
    estimated_delivery_time: 25,
    is_open: true,
    is_featured: true,
    is_verified: true,
    is_new: true,
    public_slug: 'o-chicken-biskra',
    is_public_web_enabled: true,
    logo_url: 'https://pub-e75807f307834b89a8e0a2463ebb914f.r2.dev/847939330_18564854512076917_9054660436327542566_n.jpg',
    image: 'https://pub-011aba279eb84591b0d96b9b9415ce2e.r2.dev/0-chicken.jpeg',
    cover_image_url: 'https://pub-011aba279eb84591b0d96b9b9415ce2e.r2.dev/0-chicken.jpeg',
    opening_hours: openingHours,
    closing_hours: openingHours,
    updated_at: new Date().toISOString(),
  };

  const { data: restResult, error: restErr } = await supabase
    .from('restaurants')
    .upsert(restaurantData, { onConflict: 'id' })
    .select()
    .single();

  if (restErr) {
    console.error('❌ Error creating restaurant:', restErr);
    process.exit(1);
  }
  console.log('✅ Restaurant created/updated:', restResult.id, restResult.name);

  // 4. Menu Items Definition
  const menuItems = [
    // --- PLATS ---
    {
      id: '0c0c1102-0001-4000-8000-000000000001',
      name: 'طبق فريت',
      name_ar: 'طبق فريت',
      name_latin: 'Plat Frites',
      category: 'Plats',
      category_id: CATEGORIES.PLATS,
      cuisine_type_id: CUISINES.FAST_FOOD,
      price: 200,
      image: 'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/o-chicken/frites.png',
      description: 'طبق بطاطا مقلية مقرمشة وساخنة',
      description_ar: 'طبق بطاطا مقلية مقرمشة وساخنة',
      description_latin: 'Portion de frites fraîches et croustillantes',
      preparation_time: 10,
      is_supplement: true,
    },
    {
      id: '0c0c1102-0001-4000-8000-000000000002',
      name: 'طبق فريت أوملات',
      name_ar: 'طبق فريت أوملات',
      name_latin: 'Plat Frites Omelette',
      category: 'Plats',
      category_id: CATEGORIES.PLATS,
      cuisine_type_id: CUISINES.FAST_FOOD,
      price: 250,
      image: 'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/o-chicken/frite_omlates.png',
      description: 'طبق بطاطا مقلية مع أوملات لذيذة',
      description_ar: 'طبق بطاطا مقلية مع أوملات لذيذة',
      description_latin: 'Portion de frites fraîches servie avec omelette savoureuse',
      preparation_time: 15,
      is_supplement: false,
    },
    {
      id: '0c0c1102-0001-4000-8000-000000000003',
      name: 'طبق أرز',
      name_ar: 'طبق أرز',
      name_latin: 'Plat Riz',
      category: 'Plats',
      category_id: CATEGORIES.PLATS,
      cuisine_type_id: CUISINES.FAST_FOOD,
      price: 250,
      image: 'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/Traditional/%D8%B1%D9%88%D8%B2%20%D9%83%D9%88%D8%B4%D8%A9.png',
      description: 'طبق أرز متبل بالنكهة الخاصة لـ O-Chicken',
      description_ar: 'طبق أرز متبل بالنكهة الخاصة لـ O-Chicken',
      description_latin: 'Portion de riz parfumé et assaisonné façon O-Chicken',
      preparation_time: 10,
      is_supplement: true,
    },
    {
      id: '0c0c1102-0001-4000-8000-000000000004',
      name: 'طبق ميلونج فريت و أرز',
      name_ar: 'طبق ميلونج فريت و أرز',
      name_latin: 'Plat Mélange Frites & Riz',
      category: 'Plats',
      category_id: CATEGORIES.PLATS,
      cuisine_type_id: CUISINES.FAST_FOOD,
      price: 220,
      image: 'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/o-chicken/fries-rice.png',
      description: 'طبق مشكل يجمع بين الأرز المتبل والبطاطا المقلية المقرمشة',
      description_ar: 'طبق مشكل يجمع بين الأرز المتبل والبطاطا المقلية المقرمشة',
      description_latin: 'Assiette mixte combinant frites croustillantes et riz assaisonné',
      preparation_time: 12,
      is_supplement: true,
    },
    {
      id: '0c0c1102-0001-4000-8000-000000000005',
      name: 'طبق ميلونج فريت و دجاج',
      name_ar: 'طبق ميلونج فريت و دجاج',
      name_latin: 'Plat Mélange Frites & Poulet',
      category: 'Plats',
      category_id: CATEGORIES.PLATS,
      cuisine_type_id: CUISINES.FAST_FOOD,
      price: 450,
      image: 'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/o-chicken/fries-chicken.png',
      description: 'قطع دجاج مشوية شهية مع البطاطا المقلية المقرمشة والصلصات',
      description_ar: 'قطع دجاج مشوية شهية مع البطاطا المقلية المقرمشة والصلصات',
      description_latin: 'Morceaux de poulet rôti savoureux servis avec frites croustillantes',
      preparation_time: 15,
      is_supplement: false,
    },
    {
      id: '0c0c1102-0001-4000-8000-000000000006',
      name: 'طبق ميلونج أرز و دجاج',
      name_ar: 'طبق ميلونج أرز و دجاج',
      name_latin: 'Plat Mélange Riz & Poulet',
      category: 'Plats',
      category_id: CATEGORIES.PLATS,
      cuisine_type_id: CUISINES.FAST_FOOD,
      price: 500,
      image: 'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/o-chicken/rice-chicken.png',
      description: 'قطع دجاج مشوية طرية وغنية بالنكهة مع طبق الأرز المتبل',
      description_ar: 'قطع دجاج مشوية طرية وغنية بالنكهة مع طبق الأرز المتبل',
      description_latin: 'Poulet rôti tendre accompagné de riz parfumé et assaisonné',
      preparation_time: 15,
      is_supplement: false,
    },
    {
      id: '0c0c1102-0001-4000-8000-000000000007',
      name: 'دجاجة مشوية',
      name_ar: 'دجاجة مشوية',
      name_latin: 'Poulet Rôti',
      category: 'Chicken & Meat',
      category_id: CATEGORIES.CHICKEN_MEAT,
      cuisine_type_id: CUISINES.GRILLS,
      price: 1100,
      image: 'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/o-chicken/chicken.png',
      description: 'دجاجة كاملة مشوية على الطريقة الخاصة بتتبيلة مميزة ومذاق رائع',
      description_ar: 'دجاجة كاملة مشوية على الطريقة الخاصة بتتبيلة مميزة ومذاق رائع',
      description_latin: 'Poulet entier rôti et doré aux épices savoureuses de la maison',
      preparation_time: 20,
      is_supplement: false,
    },

    // --- SANDWICHES ---
    {
      id: '0c0c1102-0001-4000-8000-000000000008',
      name: 'نصف سندويتش دجاج',
      name_ar: 'نصف سندويتش دجاج',
      name_latin: 'Demi Sandwich Poulet',
      category: 'Sandwich',
      category_id: CATEGORIES.SANDWICH,
      cuisine_type_id: CUISINES.FAST_FOOD,
      price: 250,
      image: 'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/o-chicken/sandich-chicken.png',
      description: 'نصف سندويتش محشو بقطع دجاج مشوية طرية مع بطاطا مقلية وصلصة',
      description_ar: 'نصف سندويتش محشو بقطع دجاج مشوية طرية مع بطاطا مقلية وصلصة',
      description_latin: 'Demi sandwich garni de poulet tendre rôti, frites et sauce',
      preparation_time: 10,
      is_supplement: false,
    },
    {
      id: '0c0c1102-0001-4000-8000-000000000009',
      name: 'نصف سندويتش فريت',
      name_ar: 'نصف سندويتش فريت',
      name_latin: 'Demi Sandwich Frites',
      category: 'Sandwich',
      category_id: CATEGORIES.SANDWICH,
      cuisine_type_id: CUISINES.FAST_FOOD,
      price: 120,
      image: 'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/sandwich_classic.png',
      description: 'نصف سندويتش بطاطا مقلية مقرمشة مع الصلصة اللذيذة',
      description_ar: 'نصف سندويتش بطاطا مقلية مقرمشة مع الصلصة اللذيذة',
      description_latin: 'Demi sandwich aux frites croustillantes et sauces',
      preparation_time: 8,
      is_supplement: false,
    },
    {
      id: '0c0c1102-0001-4000-8000-000000000010',
      name: 'نصف سندويتش فريت أوملات',
      name_ar: 'نصف سندويتش فريت أوملات',
      name_latin: 'Demi Sandwich Frites Omelette',
      category: 'Sandwich',
      category_id: CATEGORIES.SANDWICH,
      cuisine_type_id: CUISINES.FAST_FOOD,
      price: 150,
      image: 'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/Sandwich_frite.png',
      description: 'نصف سندويتش بطاطا مقلية مع أوملات طرية وساخنة',
      description_ar: 'نصف سندويتش بطاطا مقلية مع أوملات طرية وساخنة',
      description_latin: 'Demi sandwich frites et omelette savoureuse',
      preparation_time: 10,
      is_supplement: false,
    },
    {
      id: '0c0c1102-0001-4000-8000-000000000011',
      name: 'نصف سندويتش فريت فرماج',
      name_ar: 'نصف سندويتش فريت فرماج',
      name_latin: 'Demi Sandwich Frites Fromage',
      category: 'Sandwich',
      category_id: CATEGORIES.SANDWICH,
      cuisine_type_id: CUISINES.FAST_FOOD,
      price: 150,
      image: 'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/3%20Fromage/Sandiwch%20fromage.png',
      description: 'نصف سندويتش بطاطا مقلية مع جبن ذائب شهي',
      description_ar: 'نصف سندويتش بطاطا مقلية مع جبن ذائب شهي',
      description_latin: 'Demi sandwich frites au fromage fondant et onctueux',
      preparation_time: 10,
      is_supplement: false,
    },

    // --- DAILY LTOS ---
    {
      id: '0c0c1102-0001-4000-8000-000000000012',
      name: 'عرض: دجاجة مع فريت و طبق أرز',
      name_ar: 'عرض: دجاجة مع فريت و طبق أرز',
      name_latin: 'Offre: Poulet Rôti avec Frites et Riz',
      category: 'Chicken & Meat',
      category_id: CATEGORIES.CHICKEN_MEAT,
      cuisine_type_id: CUISINES.GRILLS,
      price: 1500,
      original_price: 1550,
      is_limited_offer: true,
      offer_types: ['lto', 'special_offer', 'discount'],
      is_featured: true,
      image: 'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/o-chicken/chicken-rice-fries.png',
      description: 'عرض يومي خاص: دجاجة كاملة مشوية + طبق بطاطا مقلية + طبق أرز بسعر مميز 1500 دج بدل 1550 دج',
      description_ar: 'عرض يومي خاص: دجاجة كاملة مشوية + طبق بطاطا مقلية + طبق أرز بسعر مميز 1500 دج بدل 1550 دج',
      description_latin: 'Offre spéciale du jour: Poulet entier rôti + plat de frites + plat de riz à 1500 DA au lieu de 1550 DA',
      preparation_time: 20,
      is_supplement: false,
    },
    {
      id: '0c0c1102-0001-4000-8000-000000000013',
      name: 'ميلونج فخذ دجاج مع فريت و أرز',
      name_ar: 'ميلونج فخذ دجاج مع فريت و أرز',
      name_latin: 'Mélange Cuisse de Poulet avec Frites et Riz',
      category: 'Plats',
      category_id: CATEGORIES.PLATS,
      cuisine_type_id: CUISINES.FAST_FOOD,
      price: 500,
      is_limited_offer: true,
      offer_types: ['lto'],
      is_featured: true,
      image: 'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/o-chicken/legs-fries-rice.png',
      description: 'عرض يومي: فخذ دجاج مشوي متبل يقدم مع تشكيلة من البطاطا المقلية والأرز المتبل',
      description_ar: 'عرض يومي: فخذ دجاج مشوي متبل يقدم مع تشكيلة من البطاطا المقلية والأرز المتبل',
      description_latin: 'Offre du jour: Cuisse de poulet rôtie servie avec frites croustillantes et riz parfumé',
      preparation_time: 15,
      is_supplement: false,
    },
    {
      id: '0c0c1102-0001-4000-8000-000000000014',
      name: 'ميلونج صدر دجاج مع فريت و أرز',
      name_ar: 'ميلونج صدر دجاج مع فريت و أرز',
      name_latin: 'Mélange Blanc de Poulet avec Frites et Riz',
      category: 'Plats',
      category_id: CATEGORIES.PLATS,
      cuisine_type_id: CUISINES.FAST_FOOD,
      price: 500,
      is_limited_offer: true,
      offer_types: ['lto'],
      is_featured: true,
      image: 'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/o-chicken/chest-fries-rice.png',
      description: 'عرض يومي: صدر دجاج مشوي طري يقدم مع تشكيلة من البطاطا المقلية والأرز المتبل',
      description_ar: 'عرض يومي: صدر دجاج مشوي طري يقدم مع تشكيلة من البطاطا المقلية والأرز المتبل',
      description_latin: 'Offre du jour: Blanc de poulet rôti servi avec frites croustillantes et riz parfumé',
      preparation_time: 15,
      is_supplement: false,
    },
  ];

  console.log('📦 Upserting menu items...');
  for (const item of menuItems) {
    const variantId = `${item.id}-v0`;
    const pricingOptionId = `${item.id}-p0`;

    const variant = {
      id: variantId,
      menu_item_id: item.id,
      name: item.name,
      name_ar: item.name_ar,
      name_latin: item.name_latin,
      description: item.description,
      description_ar: item.description_ar,
      description_latin: item.description_latin,
      is_default: true,
      is_available: true,
      display_order: 0,
    };

    const pricingOption = {
      id: pricingOptionId,
      variant_id: variantId,
      menu_item_id: item.id,
      size: 'Standard',
      size_ar: 'عادي',
      size_latin: 'Standard',
      price: item.price,
      original_price: item.original_price || null,
      is_limited_offer: item.is_limited_offer || false,
      offer_types: item.offer_types || [],
      is_default: true,
      display_order: 0,
      description: item.description,
      description_ar: item.description_ar,
      description_latin: item.description_latin,
      portion: '',
      offer_details: item.original_price ? { discount_amount: item.original_price - item.price } : {},
      free_drinks_included: false,
      free_drinks_quantity: 0,
      free_drinks_list: [],
    };

    const row = {
      id: item.id,
      restaurant_id: RESTAURANT_ID,
      restaurant_name: 'O-Chicken Biskra',
      name: item.name,
      name_ar: item.name_ar,
      name_latin: item.name_latin,
      description: item.description,
      description_ar: item.description_ar,
      description_latin: item.description_latin,
      category: item.category,
      category_id: item.category_id,
      cuisine_type_id: item.cuisine_type_id,
      price: item.price,
      original_price: item.original_price || null,
      image: item.image,
      images: [item.image],
      is_available: true,
      is_featured: item.is_featured || false,
      preparation_time: item.preparation_time,
      is_spicy: false,
      spice_level: 0,
      is_traditional: false,
      is_vegetarian: false,
      is_vegan: false,
      is_gluten_free: false,
      is_dairy_free: false,
      is_low_sodium: false,
      variants: [variant],
      pricing_options: [pricingOption],
      supplements: [],
      is_limited_offer: item.is_limited_offer || false,
      offer_types: item.offer_types || [],
      tax_free: true,
      available_schedule_enabled: false,
      is_drink: false,
      ingredients: [],
      ingredients_ar: [],
      ingredients_latin: [],
      updated_at: new Date().toISOString(),
    };

    const { error: itemErr } = await supabase
      .from('menu_items')
      .upsert(row, { onConflict: 'id' });

    if (itemErr) {
      console.error(`❌ Error upserting menu item ${item.name}:`, itemErr);
    } else {
      console.log(`  ✅ Menu item: ${item.name} (${item.price} DA) [LTO: ${item.is_limited_offer ? 'YES' : 'NO'}]`);
    }
  }

  // 5. Setup Global Supplements
  console.log('🍟 Setting up global restaurant supplements...');
  const supplementsToCreate = [
    {
      id: '0c0c1103-0001-4000-8000-000000000001',
      name: 'طبق فريت',
      name_ar: 'طبق فريت',
      name_latin: 'Plat Frites',
      price: 200,
    },
    {
      id: '0c0c1103-0001-4000-8000-000000000002',
      name: 'طبق أرز',
      name_ar: 'طبق أرز',
      name_latin: 'Plat Riz',
      price: 250,
    },
    {
      id: '0c0c1103-0001-4000-8000-000000000003',
      name: 'طبق ميلونج فريت و أرز',
      name_ar: 'طبق ميلونج فريت و أرز',
      name_latin: 'Plat Mélange Frites & Riz',
      price: 220,
    },
  ];

  for (const s of supplementsToCreate) {
    // 5a. Upsert in menu_item_supplements
    const suppRow = {
      id: s.id,
      menu_item_id: null,
      name: s.name,
      name_ar: s.name_ar,
      name_latin: s.name_latin,
      description: '',
      description_ar: '',
      description_latin: '',
      price: s.price,
      is_available: true,
      display_order: 0,
      updated_at: new Date().toISOString(),
    };

    const { error: suppErr } = await supabase
      .from('menu_item_supplements')
      .upsert(suppRow, { onConflict: 'id' });

    if (suppErr) {
      console.error(`❌ Error upserting supplement ${s.name}:`, suppErr);
      continue;
    }

    // 5b. Link in restaurant_supplements
    const restSuppRow = {
      id: `0c0c1104-${s.id.slice(9)}`,
      restaurant_id: RESTAURANT_ID,
      supplement_id: s.id,
      updated_at: new Date().toISOString(),
    };

    const { error: linkErr } = await supabase
      .from('restaurant_supplements')
      .upsert(restSuppRow, { onConflict: 'id' });

    if (linkErr) {
      console.error(`❌ Error linking supplement ${s.name} to restaurant:`, linkErr);
    } else {
      console.log(`  ✅ Global supplement configured: ${s.name} (${s.price} DA)`);
    }
  }

  console.log('🎉 O-Chicken Biskra onboarding completed successfully!');
}

onboard();
