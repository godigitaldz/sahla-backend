import { supabaseAdmin } from '../src/config/supabase.js';

const REST_ID = '09ad3d8b-004f-4035-bee8-9c63243c39e9';
const REST_NAME = 'Brothers Food';
const CUISINE_TYPE_ID = 'e5021b58-9273-4d84-a56a-05da539f79db';

async function main() {
  console.log('--- Applying Brothers Food Menu Polish & Migration ---');

  // 1. Retire Pasta
  console.log('1. Retiring Pasta...');
  const { error: errPasta } = await supabaseAdmin
    .from('menu_items')
    .update({ is_available: false, updated_at: new Date().toISOString() })
    .eq('id', '09ad3d8b-0001-4000-8000-0000000000c1')
    .eq('restaurant_id', REST_ID);
  if (errPasta) console.error('Error retiring Pasta:', errPasta);
  else console.log('Pasta retired successfully.');

  // 2. Update Burger
  console.log('2. Updating Burger...');
  const burgerData = [
    { name: 'Poulet', name_ar: 'دجاج', name_latin: 'Poulet', price: 250 },
    { name: 'Viande', name_ar: 'لحم', name_latin: 'Viande', price: 300 },
    { name: 'Crispy', name_ar: 'كريسبي', name_latin: 'Crispy', price: 400 },
    { name: 'Double', name_ar: 'دبل', name_latin: 'Double', price: 450 },
    { name: 'Seryal', name_ar: 'سيريال', name_latin: 'Seryal', price: 600 },
  ];
  const burgerItemId = '09ad3d8b-0004-4000-8000-0000000000c1';
  const burgerVariants = burgerData.map((bd, idx) => ({
    id: `09ad3d8b-1004-4000-8000-${String(idx + 1).padStart(12, '0')}`,
    name: bd.name,
    name_ar: bd.name_ar,
    name_latin: bd.name_latin,
    is_default: idx === 0,
    is_available: true,
    display_order: idx,
    description: '',
    description_ar: '',
    description_latin: '',
    menu_item_id: burgerItemId,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  }));
  const burgerPricing = burgerData.map((bd, idx) => ({
    id: `09ad3d8b-2004-4000-8000-${String(idx + 1).padStart(12, '0')}`,
    size: '',
    size_ar: '',
    size_latin: '',
    portion: '',
    price: bd.price,
    is_default: idx === 0,
    variant_id: burgerVariants[idx].id,
    menu_item_id: burgerItemId,
    display_order: idx,
    offer_types: [],
    offer_details: {},
    free_drinks_list: [],
    is_limited_offer: false,
    free_drinks_included: false,
    free_drinks_quantity: 1,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  }));

  const { error: errBurger } = await supabaseAdmin
    .from('menu_items')
    .update({
      name: 'Burger',
      name_ar: 'برجر',
      name_latin: 'Burger',
      category: 'Burger',
      category_id: '94e67ac0-ff8b-400f-8722-a872cfca15c4',
      cuisine_type_id: CUISINE_TYPE_ID,
      price: 250,
      is_available: true,
      image: 'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/Burger/Chicken_burger.png',
      images: ['https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/Burger/Chicken_burger.png'],
      variants: burgerVariants,
      pricing_options: burgerPricing,
      updated_at: new Date().toISOString(),
    })
    .eq('id', burgerItemId)
    .eq('restaurant_id', REST_ID);
  if (errBurger) console.error('Error updating Burger:', errBurger);
  else console.log('Burger updated successfully.');

  // 3. Update Calzone
  console.log('3. Updating Calzone...');
  const calzoneData = [
    { name: 'Poulet', name_ar: 'دجاج', name_latin: 'Poulet', price: 500 },
    { name: 'Viande', name_ar: 'لحم', name_latin: 'Viande', price: 600 },
    { name: 'Foie', name_ar: 'كبدة', name_latin: 'Foie', price: 700 },
    { name: 'Mix', name_ar: 'ميكس', name_latin: 'Mix', price: 800 },
    { name: 'Seryal', name_ar: 'سيريال', name_latin: 'Seryal', price: 600 },
  ];
  const calzoneItemId = '09ad3d8b-0002-4000-8000-0000000000c1';
  const calzoneVariants = calzoneData.map((cd, idx) => ({
    id: `09ad3d8b-1002-4000-8000-${String(idx + 1).padStart(12, '0')}`,
    name: cd.name,
    name_ar: cd.name_ar,
    name_latin: cd.name_latin,
    is_default: idx === 0,
    is_available: true,
    display_order: idx,
    description: '',
    description_ar: '',
    description_latin: '',
    menu_item_id: calzoneItemId,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  }));
  const calzonePricing = calzoneData.map((cd, idx) => ({
    id: `09ad3d8b-2002-4000-8000-${String(idx + 1).padStart(12, '0')}`,
    size: '',
    size_ar: '',
    size_latin: '',
    portion: '',
    price: cd.price,
    is_default: idx === 0,
    variant_id: calzoneVariants[idx].id,
    menu_item_id: calzoneItemId,
    display_order: idx,
    offer_types: [],
    offer_details: {},
    free_drinks_list: [],
    is_limited_offer: false,
    free_drinks_included: false,
    free_drinks_quantity: 1,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  }));

  const { error: errCalzone } = await supabaseAdmin
    .from('menu_items')
    .update({
      name: 'Calzone',
      name_ar: 'كالزون',
      name_latin: 'Calzone',
      category: 'Calzone',
      category_id: '35dcc8a8-6d56-4b28-98a1-b1b3a430cd76',
      cuisine_type_id: CUISINE_TYPE_ID,
      price: 500,
      is_available: true,
      image: 'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/Calzone.png',
      images: ['https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/Calzone.png'],
      variants: calzoneVariants,
      pricing_options: calzonePricing,
      updated_at: new Date().toISOString(),
    })
    .eq('id', calzoneItemId)
    .eq('restaurant_id', REST_ID);
  if (errCalzone) console.error('Error updating Calzone:', errCalzone);
  else console.log('Calzone updated successfully.');

  // 4. Update Fajitas
  console.log('4. Updating Fajitas...');
  const fajitasItemId = '09ad3d8b-0003-4000-8000-0000000000c1';
  const fajitasData = [
    { name: 'Poulet', name_ar: 'دجاج', name_latin: 'Poulet', price: 250 },
    { name: 'Viande', name_ar: 'لحم', name_latin: 'Viande', price: 350 },
    { name: 'Foie', name_ar: 'كبدة', name_latin: 'Foie', price: 450 },
    { name: 'Mix', name_ar: 'ميكس', name_latin: 'Mix', price: 600 },
  ];
  const fajitasVariants = fajitasData.map((fd, idx) => ({
    id: `09ad3d8b-1003-4000-8000-${String(idx + 1).padStart(12, '0')}`,
    name: fd.name,
    name_ar: fd.name_ar,
    name_latin: fd.name_latin,
    is_default: idx === 0,
    is_available: true,
    display_order: idx,
    description: '',
    description_ar: '',
    description_latin: '',
    menu_item_id: fajitasItemId,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  }));
  const fajitasPricing = fajitasData.map((fd, idx) => ({
    id: `09ad3d8b-2003-4000-8000-${String(idx + 1).padStart(12, '0')}`,
    size: '',
    size_ar: '',
    size_latin: '',
    portion: '',
    price: fd.price,
    is_default: idx === 0,
    variant_id: fajitasVariants[idx].id,
    menu_item_id: fajitasItemId,
    display_order: idx,
    offer_types: [],
    offer_details: {},
    free_drinks_list: [],
    is_limited_offer: false,
    free_drinks_included: false,
    free_drinks_quantity: 1,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  }));

  const { error: errFajitas } = await supabaseAdmin
    .from('menu_items')
    .update({
      name: 'Fajitas',
      name_ar: 'فاجيتاس',
      name_latin: 'Fajitas',
      category: 'Fajitas',
      category_id: '584c8fdb-9d70-4bf1-ae89-40039baaf01e',
      cuisine_type_id: CUISINE_TYPE_ID,
      price: 250,
      is_available: true,
      image: 'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/fajitas.png',
      images: ['https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/fajitas.png'],
      variants: fajitasVariants,
      pricing_options: fajitasPricing,
      updated_at: new Date().toISOString(),
    })
    .eq('id', fajitasItemId)
    .eq('restaurant_id', REST_ID);
  if (errFajitas) console.error('Error updating Fajitas:', errFajitas);
  else console.log('Fajitas updated successfully.');

  // 5. Update Malfouf
  console.log('5. Updating Malfouf...');
  const malfoufItemId = '09ad3d8b-0006-4000-8000-0000000000c1';
  const malfoufData = [
    { name: 'Malfouf Poulet', name_ar: 'ملفوف دجاج', name_latin: 'Malfouf Poulet', price: 300 },
    { name: 'Malfouf Viande', name_ar: 'ملفوف لحم', name_latin: 'Malfouf Viande', price: 350 },
    { name: 'Malfouf Foie', name_ar: 'ملفوف كبدة', name_latin: 'Malfouf Foie', price: 400 },
    { name: 'Malfouf Crispy', name_ar: 'ملفوف كريسبي', name_latin: 'Malfouf Crispy', price: 400 },
    { name: 'Malfouf Mix', name_ar: 'ملفوف ميكس', name_latin: 'Malfouf Mix', price: 500 },
    { name: 'Malfouf Brothers', name_ar: 'ملفوف برادرز', name_latin: 'Malfouf Brothers', price: 750 },
  ];
  const malfoufVariants = malfoufData.map((md, idx) => ({
    id: `09ad3d8b-1006-4000-8000-${String(idx + 1).padStart(12, '0')}`,
    name: md.name,
    name_ar: md.name_ar,
    name_latin: md.name_latin,
    is_default: idx === 0,
    is_available: true,
    display_order: idx,
    description: '',
    description_ar: '',
    description_latin: '',
    menu_item_id: malfoufItemId,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  }));
  const malfoufPricing = malfoufData.map((md, idx) => ({
    id: `09ad3d8b-2006-4000-8000-${String(idx + 1).padStart(12, '0')}`,
    size: '',
    size_ar: '',
    size_latin: '',
    portion: '',
    price: md.price,
    is_default: idx === 0,
    variant_id: malfoufVariants[idx].id,
    menu_item_id: malfoufItemId,
    display_order: idx,
    offer_types: [],
    offer_details: {},
    free_drinks_list: [],
    is_limited_offer: false,
    free_drinks_included: false,
    free_drinks_quantity: 1,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  }));

  const { error: errMalfouf } = await supabaseAdmin
    .from('menu_items')
    .update({
      name: 'Malfouf',
      name_ar: 'ملفوف',
      name_latin: 'Malfouf',
      category: 'Malfouf',
      category_id: 'a84b5880-04bd-4d27-8739-52306b5e53f4',
      cuisine_type_id: CUISINE_TYPE_ID,
      price: 300,
      is_available: true,
      image: 'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/malfouf.png',
      images: ['https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/malfouf.png'],
      variants: malfoufVariants,
      pricing_options: malfoufPricing,
      updated_at: new Date().toISOString(),
    })
    .eq('id', malfoufItemId)
    .eq('restaurant_id', REST_ID);
  if (errMalfouf) console.error('Error updating Malfouf:', errMalfouf);
  else console.log('Malfouf updated successfully.');

  // 6. Update Poutine
  console.log('6. Updating Poutine...');
  const poutineItemId = '09ad3d8b-0005-4000-8000-0000000000c1';
  const poutineVariantsData = [
    { name: 'Chawarma', name_ar: 'شاورما', name_latin: 'Chawarma', m: 400, family: 1800 },
    { name: 'Viande', name_ar: 'لحم', name_latin: 'Viande', m: 450, family: 1900 },
    { name: 'Crispy', name_ar: 'كريسبي', name_latin: 'Crispy', m: 700, family: 2500 },
    { name: 'BR', name_ar: 'بي آر', name_latin: 'BR', m: null, family: 3000 },
  ];
  const poutineVariants = poutineVariantsData.map((pvd, idx) => ({
    id: `09ad3d8b-1005-4000-8000-${String(idx + 1).padStart(12, '0')}`,
    name: pvd.name,
    name_ar: pvd.name_ar,
    name_latin: pvd.name_latin,
    is_default: idx === 0,
    is_available: true,
    display_order: idx,
    description: '',
    description_ar: '',
    description_latin: '',
    menu_item_id: poutineItemId,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  }));
  const poutinePricing = [];
  let pCounter = 1;
  poutineVariantsData.forEach((pvd, idx) => {
    const varId = poutineVariants[idx].id;
    if (pvd.m !== null) {
      poutinePricing.push({
        id: `09ad3d8b-2005-4000-8000-${String(pCounter++).padStart(12, '0')}`,
        size: 'M',
        size_ar: 'عادي',
        size_latin: 'M',
        portion: '',
        price: pvd.m,
        is_default: idx === 0,
        variant_id: varId,
        menu_item_id: poutineItemId,
        display_order: 0,
        offer_types: [],
        offer_details: {},
        free_drinks_list: [],
        is_limited_offer: false,
        free_drinks_included: false,
        free_drinks_quantity: 1,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      });
    }
    if (pvd.family !== null) {
      poutinePricing.push({
        id: `09ad3d8b-2005-4000-8000-${String(pCounter++).padStart(12, '0')}`,
        size: 'Family',
        size_ar: 'عائلي',
        size_latin: 'Family',
        portion: '',
        price: pvd.family,
        is_default: pvd.m === null,
        variant_id: varId,
        menu_item_id: poutineItemId,
        display_order: 1,
        offer_types: [],
        offer_details: {},
        free_drinks_list: [],
        is_limited_offer: false,
        free_drinks_included: false,
        free_drinks_quantity: 1,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      });
    }
  });

  const { error: errPoutine } = await supabaseAdmin
    .from('menu_items')
    .update({
      name: 'Poutine',
      name_ar: 'بوتين',
      name_latin: 'Poutine',
      category: 'Poutine',
      category_id: '767d4c31-c27d-41fa-b7eb-65257a65b62d',
      cuisine_type_id: CUISINE_TYPE_ID,
      price: 400,
      is_available: true,
      image: 'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/Poutine/Mix.png',
      images: ['https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/Poutine/Mix.png'],
      variants: poutineVariants,
      pricing_options: poutinePricing,
      updated_at: new Date().toISOString(),
    })
    .eq('id', poutineItemId)
    .eq('restaurant_id', REST_ID);
  if (errPoutine) console.error('Error updating Poutine:', errPoutine);
  else console.log('Poutine updated successfully.');

  // 7. Update Tacos
  console.log('7. Updating Tacos...');
  const tacosItemId = '09ad3d8b-0007-4000-8000-0000000000c1';
  const tacosData = [
    { name: 'Chawarma', name_ar: 'شاورما', name_latin: 'Chawarma', price: 400 },
    { name: 'Viande', name_ar: 'لحم', name_latin: 'Viande', price: 450 },
    { name: 'Foie', name_ar: 'كبدة', name_latin: 'Foie', price: 500 },
    { name: 'Crispy', name_ar: 'كريسبي', name_latin: 'Crispy', price: 550 },
    { name: 'Mix', name_ar: 'ميكس', name_latin: 'Mix', price: 650 },
    { name: '4 Fromage', name_ar: '4 أجبان', name_latin: '4 Fromage', price: 800 },
  ];
  const tacosVariants = tacosData.map((td, idx) => ({
    id: `09ad3d8b-1007-4000-8000-${String(idx + 1).padStart(12, '0')}`,
    name: td.name,
    name_ar: td.name_ar,
    name_latin: td.name_latin,
    is_default: idx === 0,
    is_available: true,
    display_order: idx,
    description: '',
    description_ar: '',
    description_latin: '',
    menu_item_id: tacosItemId,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  }));
  const tacosPricing = tacosData.map((td, idx) => ({
    id: `09ad3d8b-2007-4000-8000-${String(idx + 1).padStart(12, '0')}`,
    size: '',
    size_ar: '',
    size_latin: '',
    portion: '',
    price: td.price,
    is_default: idx === 0,
    variant_id: tacosVariants[idx].id,
    menu_item_id: tacosItemId,
    display_order: idx,
    offer_types: [],
    offer_details: {},
    free_drinks_list: [],
    is_limited_offer: false,
    free_drinks_included: false,
    free_drinks_quantity: 1,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  }));

  const { error: errTacos } = await supabaseAdmin
    .from('menu_items')
    .update({
      name: 'Tacos',
      name_ar: 'طاكوس',
      name_latin: 'Tacos',
      category: 'Tacos',
      category_id: '34f33e8b-8bf2-4121-b905-3f9b1686d6c1',
      cuisine_type_id: CUISINE_TYPE_ID,
      price: 400,
      is_available: true,
      image: 'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/Tacos/gratine.png',
      images: ['https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/Tacos/gratine.png'],
      variants: tacosVariants,
      pricing_options: tacosPricing,
      updated_at: new Date().toISOString(),
    })
    .eq('id', tacosItemId)
    .eq('restaurant_id', REST_ID);
  if (errTacos) console.error('Error updating Tacos:', errTacos);
  else console.log('Tacos updated successfully.');

  // 8. Upsert Pizza
  console.log('8. Upserting Pizza...');
  const pizzaVarieties = [
    { name: 'Margherita', name_ar: 'مارغريتا', name_latin: 'Margherita', m: 250, l: 650 },
    { name: 'Pizza double fromage', name_ar: 'بيتزا مضاعفة الجبن', name_latin: 'Pizza double fromage', m: 350, l: 750 },
    { name: 'Poulet', name_ar: 'دجاج', name_latin: 'Poulet', m: 450, l: 850 },
    { name: 'Viande', name_ar: 'لحم', name_latin: 'Viande', m: 450, l: 1000 },
    { name: 'Thon', name_ar: 'تونة', name_latin: 'Thon', m: 450, l: 850 },
    { name: 'Poulet Fumé', name_ar: 'دجاج مدخن', name_latin: 'Poulet Fumé', m: 650, l: 1100 },
    { name: '4 Saisons', name_ar: 'الفصول الأربعة', name_latin: '4 Saisons', m: 800, l: 1800 },
    { name: '3 Fromage', name_ar: '3 أجبان', name_latin: '3 Fromage', m: 700, l: 1400 },
    { name: 'Végétarienne', name_ar: 'نباتية', name_latin: 'Végétarienne', m: 400, l: 800 },
    { name: 'Végétarienne Spéciale', name_ar: 'نباتية خاصة', name_latin: 'Végétarienne Spéciale', m: 800, l: 1400 },
    { name: 'Boisée Simple', name_ar: 'بوايزيه بسيطة', name_latin: 'Boisée Simple', m: 400, l: 650 },
    { name: 'Boisée Poulet', name_ar: 'بوايزيه بالدجاج', name_latin: 'Boisée Poulet', m: 550, l: 950 },
    { name: 'Pizza peperoni', name_ar: 'بيتزا بيبيروني', name_latin: 'Pizza peperoni', m: 550, l: 1100 },
  ];
  const pizzaItemId = '09ad3d8b-0008-4000-8000-0000000000c1';
  const pizzaVariants = [];
  const pizzaPricing = [];
  pizzaVarieties.forEach((pv, idx) => {
    const varId = `09ad3d8b-1008-4000-8000-${String(idx + 1).padStart(12, '0')}`;
    pizzaVariants.push({
      id: varId,
      name: pv.name,
      name_ar: pv.name_ar,
      name_latin: pv.name_latin,
      is_default: idx === 0,
      is_available: true,
      display_order: idx,
      description: '',
      description_ar: '',
      description_latin: '',
      menu_item_id: pizzaItemId,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    });
    pizzaPricing.push({
      id: `09ad3d8b-2008-4000-8000-${String(idx * 2 + 1).padStart(12, '0')}`,
      size: 'M',
      size_ar: 'متوسط',
      size_latin: 'M',
      portion: '',
      price: pv.m,
      is_default: true,
      variant_id: varId,
      menu_item_id: pizzaItemId,
      display_order: 0,
      offer_types: [],
      offer_details: {},
      free_drinks_list: [],
      is_limited_offer: false,
      free_drinks_included: false,
      free_drinks_quantity: 1,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    });
    pizzaPricing.push({
      id: `09ad3d8b-2008-4000-8000-${String(idx * 2 + 2).padStart(12, '0')}`,
      size: 'L',
      size_ar: 'كبير',
      size_latin: 'L',
      portion: '',
      price: pv.l,
      is_default: false,
      variant_id: varId,
      menu_item_id: pizzaItemId,
      display_order: 1,
      offer_types: [],
      offer_details: {},
      free_drinks_list: [],
      is_limited_offer: false,
      free_drinks_included: false,
      free_drinks_quantity: 1,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    });
  });

  const { error: errPizza } = await supabaseAdmin
    .from('menu_items')
    .upsert({
      id: pizzaItemId,
      restaurant_id: REST_ID,
      restaurant_name: REST_NAME,
      name: 'Pizza',
      name_ar: 'بيتزا',
      name_latin: 'Pizza',
      category: 'Pizza',
      category_id: 'd54806cf-adb6-43ce-ae11-10d45bd8d479',
      cuisine_type_id: CUISINE_TYPE_ID,
      price: 250,
      is_available: true,
      is_featured: false,
      preparation_time: 15,
      image: 'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/Pizza/Sauce%20toamte/Margerita.png',
      images: ['https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/Pizza/Sauce%20toamte/Margerita.png'],
      variants: pizzaVariants,
      pricing_options: pizzaPricing,
      ingredients: [],
      ingredients_ar: [],
      ingredients_latin: [],
      updated_at: new Date().toISOString(),
    }, { onConflict: 'id' });
  if (errPizza) console.error('Error upserting Pizza:', errPizza);
  else console.log('Pizza upserted successfully.');

  // 9. Upsert Makloub
  console.log('9. Upserting Makloub...');
  const makloubItemId = '09ad3d8b-0009-4000-8000-0000000000c1';
  const makloubData = [
    { name: 'Chawarma', name_ar: 'شاورما', name_latin: 'Chawarma', price: 450 },
    { name: 'Viande', name_ar: 'لحم', name_latin: 'Viande', price: 500 },
    { name: 'Foie', name_ar: 'كبدة', name_latin: 'Foie', price: 600 },
    { name: 'Mix', name_ar: 'ميكس', name_latin: 'Mix', price: 650 },
    { name: 'BR', name_ar: 'بي آر', name_latin: 'BR', price: 800 },
  ];
  const makloubVariants = makloubData.map((md, idx) => ({
    id: `09ad3d8b-1009-4000-8000-${String(idx + 1).padStart(12, '0')}`,
    name: md.name,
    name_ar: md.name_ar,
    name_latin: md.name_latin,
    is_default: idx === 0,
    is_available: true,
    display_order: idx,
    description: '',
    description_ar: '',
    description_latin: '',
    menu_item_id: makloubItemId,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  }));
  const makloubPricing = makloubData.map((md, idx) => ({
    id: `09ad3d8b-2009-4000-8000-${String(idx + 1).padStart(12, '0')}`,
    size: '',
    size_ar: '',
    size_latin: '',
    portion: '',
    price: md.price,
    is_default: idx === 0,
    variant_id: makloubVariants[idx].id,
    menu_item_id: makloubItemId,
    display_order: idx,
    offer_types: [],
    offer_details: {},
    free_drinks_list: [],
    is_limited_offer: false,
    free_drinks_included: false,
    free_drinks_quantity: 1,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  }));

  const { error: errMakloub } = await supabaseAdmin
    .from('menu_items')
    .upsert({
      id: makloubItemId,
      restaurant_id: REST_ID,
      restaurant_name: REST_NAME,
      name: 'Makloub',
      name_ar: 'مقلوب',
      name_latin: 'Makloub',
      category: 'Makloub',
      category_id: '354f5144-06c7-4711-b1c0-73d22d709a2d',
      cuisine_type_id: CUISINE_TYPE_ID,
      price: 450,
      is_available: true,
      is_featured: false,
      preparation_time: 10,
      image: 'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/makloub.png',
      images: ['https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/makloub.png'],
      variants: makloubVariants,
      pricing_options: makloubPricing,
      ingredients: [],
      ingredients_ar: [],
      ingredients_latin: [],
      updated_at: new Date().toISOString(),
    }, { onConflict: 'id' });
  if (errMakloub) console.error('Error upserting Makloub:', errMakloub);
  else console.log('Makloub upserted successfully.');

  // 10. Upsert Plats Variés
  console.log('10. Upserting Plats Variés...');
  const platsItemId = '09ad3d8b-0010-4000-8000-0000000000c1';
  const platsData = [
    { name: 'Chawarma', name_ar: 'شاورما', name_latin: 'Chawarma', price: 600 },
    { name: 'Viande', name_ar: 'لحم', name_latin: 'Viande', price: 700 },
    { name: 'Plat Crispy', name_ar: 'طبق كريسبي', name_latin: 'Plat Crispy', price: 800 },
    { name: 'Crispy', name_ar: 'كريسبي', name_latin: 'Crispy', price: 850 },
    { name: 'Mix', name_ar: 'ميكس', name_latin: 'Mix', price: 1000 },
  ];
  const platsVariants = platsData.map((pd, idx) => ({
    id: `09ad3d8b-1010-4000-8000-${String(idx + 1).padStart(12, '0')}`,
    name: pd.name,
    name_ar: pd.name_ar,
    name_latin: pd.name_latin,
    is_default: idx === 0,
    is_available: true,
    display_order: idx,
    description: '',
    description_ar: '',
    description_latin: '',
    menu_item_id: platsItemId,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  }));
  const platsPricing = platsData.map((pd, idx) => ({
    id: `09ad3d8b-2010-4000-8000-${String(idx + 1).padStart(12, '0')}`,
    size: '',
    size_ar: '',
    size_latin: '',
    portion: '',
    price: pd.price,
    is_default: idx === 0,
    variant_id: platsVariants[idx].id,
    menu_item_id: platsItemId,
    display_order: idx,
    offer_types: [],
    offer_details: {},
    free_drinks_list: [],
    is_limited_offer: false,
    free_drinks_included: false,
    free_drinks_quantity: 1,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  }));

  const { error: errPlats } = await supabaseAdmin
    .from('menu_items')
    .upsert({
      id: platsItemId,
      restaurant_id: REST_ID,
      restaurant_name: REST_NAME,
      name: 'Plats Variés',
      name_ar: 'أطباق متنوعة',
      name_latin: 'Plats Varies',
      category: 'Plats',
      category_id: '2feb3511-4c37-4252-92b3-310936749abe',
      cuisine_type_id: CUISINE_TYPE_ID,
      price: 600,
      is_available: true,
      is_featured: false,
      preparation_time: 12,
      image: 'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/Plats.png',
      images: ['https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/Plats.png'],
      variants: platsVariants,
      pricing_options: platsPricing,
      ingredients: [],
      ingredients_ar: [],
      ingredients_latin: [],
      updated_at: new Date().toISOString(),
    }, { onConflict: 'id' });
  if (errPlats) console.error('Error upserting Plats Variés:', errPlats);
  else console.log('Plats Variés upserted successfully.');

  // 11. Upsert Sandwich
  console.log('11. Upserting Sandwich...');
  const sandwichItemId = '09ad3d8b-0011-4000-8000-0000000000c1';
  const sandwichData = [
    { name: 'Chawarma', name_ar: 'شاورما', name_latin: 'Chawarma', price: 300 },
    { name: 'Viande', name_ar: 'لحم', name_latin: 'Viande', price: 350 },
    { name: 'Crispy', name_ar: 'كريسبي', name_latin: 'Crispy', price: 400 },
    { name: 'Mix', name_ar: 'ميكس', name_latin: 'Mix', price: 450 },
    { name: 'Normal + 4 Fromage', name_ar: 'عادي + 4 أجبان', name_latin: 'Normal + 4 Fromage', price: 400 },
    { name: '+ 4 Fromage', name_ar: '+ 4 أجبان', name_latin: '+ 4 Fromage', price: 700 },
    { name: 'Special', name_ar: 'سبيسيال', name_latin: 'Special', price: 850 },
  ];
  const sandwichVariants = sandwichData.map((sd, idx) => ({
    id: `09ad3d8b-1011-4000-8000-${String(idx + 1).padStart(12, '0')}`,
    name: sd.name,
    name_ar: sd.name_ar,
    name_latin: sd.name_latin,
    is_default: idx === 0,
    is_available: true,
    display_order: idx,
    description: '',
    description_ar: '',
    description_latin: '',
    menu_item_id: sandwichItemId,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  }));
  const sandwichPricing = sandwichData.map((sd, idx) => ({
    id: `09ad3d8b-2011-4000-8000-${String(idx + 1).padStart(12, '0')}`,
    size: '',
    size_ar: '',
    size_latin: '',
    portion: '',
    price: sd.price,
    is_default: idx === 0,
    variant_id: sandwichVariants[idx].id,
    menu_item_id: sandwichItemId,
    display_order: idx,
    offer_types: [],
    offer_details: {},
    free_drinks_list: [],
    is_limited_offer: false,
    free_drinks_included: false,
    free_drinks_quantity: 1,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  }));

  const { error: errSandwich } = await supabaseAdmin
    .from('menu_items')
    .upsert({
      id: sandwichItemId,
      restaurant_id: REST_ID,
      restaurant_name: REST_NAME,
      name: 'Sandwich',
      name_ar: 'سندويش',
      name_latin: 'Sandwich',
      category: 'Sandwich',
      category_id: '842f79fa-b4fc-426d-a73d-11281178bc44',
      cuisine_type_id: CUISINE_TYPE_ID,
      price: 300,
      is_available: true,
      is_featured: false,
      preparation_time: 8,
      image: 'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/sandwich.png',
      images: ['https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/sandwich.png'],
      variants: sandwichVariants,
      pricing_options: sandwichPricing,
      ingredients: [],
      ingredients_ar: [],
      ingredients_latin: [],
      updated_at: new Date().toISOString(),
    }, { onConflict: 'id' });
  if (errSandwich) console.error('Error upserting Sandwich:', errSandwich);
  else console.log('Sandwich upserted successfully.');

  // 12. Upsert Matloua
  console.log('12. Upserting Matloua...');
  const matlouaItemId = '09ad3d8b-0012-4000-8000-0000000000c1';
  const matlouaData = [
    { name: 'Chawarma', name_ar: 'شاورما', name_latin: 'Chawarma', price: 300 },
    { name: 'Viande', name_ar: 'لحم', name_latin: 'Viande', price: 350 },
    { name: 'Foie', name_ar: 'كبدة', name_latin: 'Foie', price: 400 },
    { name: 'Mix', name_ar: 'ميكس', name_latin: 'Mix', price: 500 },
  ];
  const matlouaVariants = matlouaData.map((md, idx) => ({
    id: `09ad3d8b-1012-4000-8000-${String(idx + 1).padStart(12, '0')}`,
    name: md.name,
    name_ar: md.name_ar,
    name_latin: md.name_latin,
    is_default: idx === 0,
    is_available: true,
    display_order: idx,
    description: '',
    description_ar: '',
    description_latin: '',
    menu_item_id: matlouaItemId,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  }));
  const matlouaPricing = matlouaData.map((md, idx) => ({
    id: `09ad3d8b-2012-4000-8000-${String(idx + 1).padStart(12, '0')}`,
    size: '',
    size_ar: '',
    size_latin: '',
    portion: '',
    price: md.price,
    is_default: idx === 0,
    variant_id: matlouaVariants[idx].id,
    menu_item_id: matlouaItemId,
    display_order: idx,
    offer_types: [],
    offer_details: {},
    free_drinks_list: [],
    is_limited_offer: false,
    free_drinks_included: false,
    free_drinks_quantity: 1,
    created_at: new Date().toISOString(),
    updated_at: new Date().toISOString(),
  }));

  const { error: errMatloua } = await supabaseAdmin
    .from('menu_items')
    .upsert({
      id: matlouaItemId,
      restaurant_id: REST_ID,
      restaurant_name: REST_NAME,
      name: 'Matloua',
      name_ar: 'مطلوع',
      name_latin: 'Matloua',
      category: 'Matloua',
      category_id: '0eedae08-bb33-4d3b-987c-80031ba2153a',
      cuisine_type_id: CUISINE_TYPE_ID,
      price: 300,
      is_available: true,
      is_featured: false,
      preparation_time: 10,
      image: 'https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/matloua.png',
      images: ['https://pub-1c3c887b3e4646a1a2129e606543df48.r2.dev/matloua.png'],
      variants: matlouaVariants,
      pricing_options: matlouaPricing,
      ingredients: [],
      ingredients_ar: [],
      ingredients_latin: [],
      updated_at: new Date().toISOString(),
    }, { onConflict: 'id' });
  if (errMatloua) console.error('Error upserting Matloua:', errMatloua);
  else console.log('Matloua upserted successfully.');

  console.log('--- Brothers Food Menu Polish & Migration Complete! ---');
}

main().catch(console.error);
