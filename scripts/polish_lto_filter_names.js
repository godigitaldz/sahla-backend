import dotenv from 'dotenv';
dotenv.config({ path: '.env.local' });
import { supabaseAdmin } from '../src/config/supabase.js';

async function polishLtoFilterNames() {
  console.log('🚀 Starting LTO Filter Section Naming Polish...');

  // ============================================================
  // 1. UPSERT CANONICAL KEYWORDS IN public.lto_filter_keywords
  // ============================================================
  console.log('📝 Upserting canonical keywords in lto_filter_keywords...');
  const canonicalKeywords = [
    {
      id: 'burger',
      label_ar: 'برغر',
      label_latin: 'Burger',
      label_en: 'Burger',
      label_fr: 'Burger',
      sort_order: 10,
      is_active: true,
    },
    {
      id: 'pizza',
      label_ar: 'بيتزا',
      label_latin: 'Pizza',
      label_en: 'Pizza',
      label_fr: 'Pizza',
      sort_order: 20,
      is_active: true,
    },
    {
      id: 'tacos',
      label_ar: 'طاكوس',
      label_latin: 'Tacos',
      label_en: 'Tacos',
      label_fr: 'Tacos',
      sort_order: 30,
      is_active: true,
    },
    {
      id: 'malfouf',
      label_ar: 'ملفوف',
      label_latin: 'Malfouf',
      label_en: 'Malfouf',
      label_fr: 'Malfouf',
      sort_order: 40,
      is_active: true,
    },
    {
      id: 'melfouf',
      label_ar: 'ملفوف',
      label_latin: 'Malfouf',
      label_en: 'Malfouf',
      label_fr: 'Malfouf',
      sort_order: 40,
      is_active: true,
    },
    {
      id: 'matloua',
      label_ar: 'مطلوع',
      label_latin: 'Matloua',
      label_en: 'Matloua',
      label_fr: 'Matloua',
      sort_order: 50,
      is_active: true,
    },
    {
      id: 'box',
      label_ar: 'بوكس',
      label_latin: 'Box',
      label_en: 'Box',
      label_fr: 'Box',
      sort_order: 60,
      is_active: true,
    },
    {
      id: 'shawarma',
      label_ar: 'شاورما',
      label_latin: 'Shawarma',
      label_en: 'Shawarma',
      label_fr: 'Chawarma',
      sort_order: 70,
      is_active: true,
    },
    {
      id: 'chawarma',
      label_ar: 'شاورما',
      label_latin: 'Shawarma',
      label_en: 'Shawarma',
      label_fr: 'Chawarma',
      sort_order: 70,
      is_active: true,
    },
    {
      id: 'crispy',
      label_ar: 'كريسبي',
      label_latin: 'Crispy',
      label_en: 'Crispy',
      label_fr: 'Crispy',
      sort_order: 80,
      is_active: true,
    },
    {
      id: 'calzone',
      label_ar: 'كالزون',
      label_latin: 'Calzone',
      label_en: 'Calzone',
      label_fr: 'Calzone',
      sort_order: 90,
      is_active: true,
    },
    {
      id: 'sandwich',
      label_ar: 'ساندويتش',
      label_latin: 'Sandwich',
      label_en: 'Sandwich',
      label_fr: 'Sandwich',
      sort_order: 100,
      is_active: true,
    },
    {
      id: 'poutine',
      label_ar: 'بوتين',
      label_latin: 'Poutine',
      label_en: 'Poutine',
      label_fr: 'Poutine',
      sort_order: 110,
      is_active: true,
    },
    {
      id: 'frites',
      label_ar: 'فريت',
      label_latin: 'Frites',
      label_en: 'Fries',
      label_fr: 'Frites',
      sort_order: 120,
      is_active: true,
    },
    {
      id: 'drink',
      label_ar: 'مشروب',
      label_latin: 'Boisson',
      label_en: 'Drink',
      label_fr: 'Boisson',
      sort_order: 130,
      is_active: true,
    },
    {
      id: 'poulet',
      label_ar: 'دجاج',
      label_latin: 'Poulet',
      label_en: 'Chicken',
      label_fr: 'Poulet',
      sort_order: 140,
      is_active: true,
    },
    {
      id: 'margherita',
      label_ar: 'مارغريتا',
      label_latin: 'Margherita',
      label_en: 'Margherita',
      label_fr: 'Margherita',
      sort_order: 150,
      is_active: true,
    },
  ];

  for (const kw of canonicalKeywords) {
    const { error: kwErr } = await supabaseAdmin
      .from('lto_filter_keywords')
      .upsert(kw, { onConflict: 'id' });
    if (kwErr) console.error(`Error upserting keyword ${kw.id}:`, kwErr);
  }
  console.log('✅ Canonical keywords updated in lto_filter_keywords table.');

  // ============================================================
  // 2. NORMALIZE KEYWORDS PER OFFER IN public.lto_items
  // ============================================================
  console.log('🍱 Updating clean food keywords on all 21 lto_items...');

  const offerKeywordUpdates = [
    // Brothers Food (3 items)
    {
      id: '4586071a-c61c-47f4-8ffb-3f7d6f45ed99',
      keywords: ['malfouf', 'pizza', 'crispy', 'box'],
    }, // عرض بوكس 2 ملفوف + 2 بيتزا 2 سيزون + 2 فريت + 4 كريسبي + مشروب
    {
      id: '6947a3db-c028-478f-b183-4fbcfd51a8a1',
      keywords: ['malfouf', 'shawarma'],
    }, // عرض 2 ملفوف شاورما + 2 ملفوف فيوند + باك فريت و 2 ڨازوز صغيرة.
    {
      id: '46ec300e-7b5b-4fca-949c-2638b0817875',
      keywords: ['matloua', 'pizza', 'shawarma'],
    }, // عرض مطلوع شاورما + بيتزا مارغريت و قازوز 33 سل.

    // Cleopatra Food (1 item)
    {
      id: 'b89d8782-556e-4850-a728-ddea3fa20da2',
      keywords: ['burger', 'tacos'],
    }, // عرض برغر شيكن + بيراميد بولي

    // Islam Diet (2 items)
    {
      id: 'ec172ba9-46f9-42fd-8970-e81a79c4d371',
      keywords: ['malfouf', 'shawarma'],
    }, // عرض 4 ملفوف شاورما صحي
    {
      id: '314f8fdd-67f8-4026-83b1-59cc19ff113d',
      keywords: ['matloua', 'shawarma'],
    }, // عرض 4 مطلوع شاورما صحي

    // Mr Burger (2 items)
    {
      id: '14b081ca-a4e4-4850-b517-c6e00a393de1',
      keywords: ['matloua', 'malfouf', 'shawarma'],
    }, // عرض مطلوع تونيزيا شاورما + ملفوف شاورما.
    {
      id: '3cae1cf6-d385-45ab-b954-fdc91a294e44',
      keywords: ['tacos', 'pizza'],
    }, // عرض طاكوس غراتيني + بيتزا 4 زيزون.

    // Seven Eleven (5 items)
    {
      id: 'e2551ceb-a003-4000-8000-000000000033',
      keywords: ['pizza', 'malfouf', 'shawarma'],
    }, // عرض بيتزا مارغريت و ملفوف شاورما
    {
      id: 'e2551ceb-a001-4000-8000-000000000031',
      keywords: ['malfouf', 'pizza', 'shawarma'],
    }, // عرض 2 ملفوف شاورما و 2 بيتزا مارغريت
    {
      id: 'e2551ceb-a005-4000-8000-000000000035',
      keywords: ['pizza', 'calzone'],
    }, // بيتزا بولي و كالزون
    {
      id: 'e2551ceb-a004-4000-8000-000000000034',
      keywords: ['pizza', 'malfouf', 'tacos', 'shawarma'],
    }, // عرض بيتزا بولي، ملفوف شاورما و طاكوس شاورما
    {
      id: 'e2551ceb-a002-4000-8000-000000000032',
      keywords: ['pizza'],
    }, // عرض 3 بيتزا ماغريت

    // Unlock Food (8 items)
    {
      id: 'a6806f12-f0b0-421b-af06-0019c659651b',
      keywords: ['burger', 'crispy', 'box'],
    }, // عرض بوكس 2 برغر كريسبي + 12 كريسبي + فريت + 2 قازوز
    {
      id: '4688c23c-7064-4822-b0d6-f13d05749b49',
      keywords: ['burger', 'shawarma', 'box'],
    }, // عرض بوكس 2 برغر كلاسيك + 2 شاورما + فريت
    {
      id: '59a9c305-26c0-4358-8fa0-6442616686b2',
      keywords: ['malfouf', 'shawarma', 'crispy', 'box'],
    }, // عرض بوكس 2 ملفوف شاورما + 12 كريسبي + فريت + قازوز
    {
      id: '021eb561-a0a0-4661-884e-7a01e85eff32',
      keywords: ['burger', 'crispy', 'box'],
    }, // عرض بوكس 4 برغر كريسبي أو كلاسيك + فريت
    {
      id: 'c66e708e-0d5b-4435-bdb4-563b19f9c5e2',
      keywords: ['malfouf', 'shawarma', 'crispy', 'box'],
    }, // عرض بوكس 6 ملفوف شاورما + 6 كريسبي + فريت
    {
      id: '4c08ce9b-a661-4d5e-9419-5d824711526f',
      keywords: ['malfouf', 'box'],
    }, // عرض بوكس 4 ملفوف + فريت
    {
      id: '0b87b12b-6fa0-418e-852f-5cd7b99989a6',
      keywords: ['burger', 'crispy', 'box'],
    }, // عرض بوكس 3 برغر كلاسيك + 3 برغر كريسبي + فريت
    {
      id: '3eb833d7-4a01-4187-bb38-5e296a8ff0ba',
      keywords: ['tacos', 'shawarma', 'box'],
    }, // عرض بوكس 3 تاكوس شاورما + فريت
  ];

  for (const upd of offerKeywordUpdates) {
    // When updating keywords with array of strings, the Postgres trigger materialize_lto_item_keywords
    // expands each string into full localized object from lto_filter_keywords
    const { error: updErr } = await supabaseAdmin
      .from('lto_items')
      .update({ keywords: upd.keywords })
      .eq('id', upd.id);

    if (updErr) {
      console.error(`Error updating offer ${upd.id}:`, updErr);
    }
  }

  console.log('🎉 LTO Filter Section Naming Polish Complete!');
}

polishLtoFilterNames().catch(console.error);
