'use client';

import React, { useState, useEffect, useRef, useMemo } from 'react';
import Image from 'next/image';
import Link from 'next/link';
import './landing.css';

const APP_STORE_URL = 'https://apps.apple.com/us/app/sahla-food-grocery/id6760480928';
const GOOGLE_PLAY_URL = 'https://play.google.com/store/apps/details?id=com.godigital.sahla&pcampaignid=web_share';
const INSTAGRAM_URL = 'https://www.instagram.com/sahla.algerie/';
const FACEBOOK_URL = 'https://www.facebook.com/profile.php?id=61569261354562';
const TIKTOK_URL = 'https://www.tiktok.com/@sahla.algerie';
const PHONE_NUMBER = '+213555271684';
const PHONE_DISPLAY = '+213 555 27 16 84';
const WHATSAPP_URL = 'https://wa.me/qr/QLW7CVMHUBNAA1';

type Language = 'ar' | 'fr' | 'en';

interface RestaurantItem {
  id: string;
  name: string;
  nameAr?: string;
  nameLatin?: string;
  tagAr: string;
  tagFr: string;
  tagEn: string;
  rating: number;
  reviewCount?: number;
  minimumOrder?: number;
  deliveryFee?: number;
  deliveryTime: string;
  deliveryTimeEn: string;
  logo: string;
  cover: string;
  slug: string | null;
  isOpen?: boolean;
  isFeatured?: boolean;
  isNew?: boolean;
  cuisineTypeIds?: string[];
}

interface CuisineCategory {
  id: string;
  name: string;
  nameAr: string;
  icon: string | null;
  sortOrder: number;
}

const INITIAL_CUISINES: CuisineCategory[] = [
  {
    id: 'all',
    name: 'All',
    nameAr: 'الكل',
    icon: '',
    sortOrder: 0,
  },
  {
    id: '13a11997-2175-4057-9129-4f4b639d8db6',
    name: 'Healthy',
    nameAr: 'صحي',
    icon: 'https://pub-66ae0208f9aa4258a7d4e176cd1b62df.r2.dev/Healthy.png',
    sortOrder: 1,
  },
  {
    id: 'e5021b58-9273-4d84-a56a-05da539f79db',
    name: 'Fast Food',
    nameAr: 'أكل سريع',
    icon: 'https://pub-66ae0208f9aa4258a7d4e176cd1b62df.r2.dev/Fast%20Food.png',
    sortOrder: 2,
  },
  {
    id: '150e05cb-24c5-49bd-8dfa-cab1d5b870ba',
    name: 'Desserts',
    nameAr: 'حلويات',
    icon: 'https://pub-66ae0208f9aa4258a7d4e176cd1b62df.r2.dev/Desserts.png',
    sortOrder: 3,
  },
  {
    id: '8e37ad82-4332-48d7-a248-d7aee9f0daec',
    name: 'Traditional',
    nameAr: 'تقليدي',
    icon: 'https://pub-66ae0208f9aa4258a7d4e176cd1b62df.r2.dev/traditional.png',
    sortOrder: 4,
  },
  {
    id: 'd3e000fb-6124-4758-a2b7-3f14b92c35d1',
    name: 'Grills',
    nameAr: 'مشاوي',
    icon: 'https://pub-66ae0208f9aa4258a7d4e176cd1b62df.r2.dev/grills.png',
    sortOrder: 5,
  },
];

function getGreeting(lang: Language): string {
  const now = new Date();
  const utc = now.getTime() + now.getTimezoneOffset() * 60000;
  const algDate = new Date(utc + 3600000); // Africa/Algiers UTC+1
  const hour = algDate.getHours();

  if (hour >= 5 && hour < 12) {
    return lang === 'ar' ? 'صباح الخير' : lang === 'fr' ? 'Bonjour' : 'Good Morning';
  } else if (hour >= 12 && hour < 18) {
    return lang === 'ar' ? 'مساء الخير' : lang === 'fr' ? 'Bon après-midi' : 'Good Afternoon';
  } else {
    return lang === 'ar' ? 'مساء الخير' : lang === 'fr' ? 'Bonsoir' : 'Good Evening';
  }
}

const FEATURED_RESTAURANTS: RestaurantItem[] = [
  {
    id: 'o-chicken-biskra',
    name: 'O-Chicken Biskra',
    tagAr: 'دجاج مشوي • أطباق • سندويتشات وعروض يومية',
    tagFr: 'Poulet Rôti • Plats • Sandwiches & Box',
    tagEn: 'Roasted Chicken • Platters • Sandwiches',
    rating: 5.0,
    deliveryTime: '20-30 دقيقة',
    deliveryTimeEn: '20-30 min',
    logo: 'https://pub-e75807f307834b89a8e0a2463ebb914f.r2.dev/847939330_18564854512076917_9054660436327542566_n.jpg',
    cover: 'https://pub-011aba279eb84591b0d96b9b9415ce2e.r2.dev/0-chicken.jpeg',
    slug: 'o-chicken-biskra',
  },
  {
    id: 'brothers-food',
    name: 'Brothers Food',
    tagAr: 'برغر • طاكوس • ملفوف • كالزون',
    tagFr: 'Burgers • Tacos • Malfouf • Calzone',
    tagEn: 'Burgers • Tacos • Malfouf • Calzone',
    rating: 4.9,
    deliveryTime: '25-35 دقيقة',
    deliveryTimeEn: '25-35 min',
    logo: 'https://pub-e75807f307834b89a8e0a2463ebb914f.r2.dev/brothers%20food.jpg',
    cover: 'https://pub-011aba279eb84591b0d96b9b9415ce2e.r2.dev/brothera%20food.jpg',
    slug: 'brothers-food',
  },
  {
    id: 'mr-burger',
    name: 'Mr Burger',
    tagAr: 'برغر • مطلوع • مقلوب • طاكوس',
    tagFr: 'Burgers • Matloua • Makloub • Tacos',
    tagEn: 'Burgers • Matloua • Makloub • Tacos',
    rating: 4.9,
    deliveryTime: '25-35 دقيقة',
    deliveryTimeEn: '25-35 min',
    logo: 'https://pub-e75807f307834b89a8e0a2463ebb914f.r2.dev/mr%20burger.jpg',
    cover: 'https://pub-011aba279eb84591b0d96b9b9415ce2e.r2.dev/mr%20burger.jpg',
    slug: 'mr-burger',
  },
  {
    id: 'cleopatra-food',
    name: 'Cleopatra Food',
    tagAr: 'برغر شيكن • طاكوس • شاباتي • بيتزا',
    tagFr: 'Burgers Crispy • Tacos • Chapati • Pizza',
    tagEn: 'Crispy Burgers • Tacos • Chapati • Pizza',
    rating: 4.7,
    deliveryTime: '25-35 دقيقة',
    deliveryTimeEn: '25-35 min',
    logo: 'https://pub-e75807f307834b89a8e0a2463ebb914f.r2.dev/cleobatra.jpg',
    cover: 'https://pub-011aba279eb84591b0d96b9b9415ce2e.r2.dev/cleopatrea.jpg',
    slug: 'cleopatra-food',
  },
  {
    id: 'chees-up',
    name: 'Chees-Up',
    tagAr: 'سندويتشات أجبان • طاكوس 5 أجبان • مطلوع',
    tagFr: 'Sandwiches Gourmets • Tacos 5 Fromages',
    tagEn: 'Gourmet Sandwiches • 5-Cheese Tacos',
    rating: 5.0,
    deliveryTime: '25-35 دقيقة',
    deliveryTimeEn: '25-35 min',
    logo: 'https://pub-e75807f307834b89a8e0a2463ebb914f.r2.dev/Chees-Up.jpg',
    cover: 'https://pub-011aba279eb84591b0d96b9b9415ce2e.r2.dev/Cheeseup.jpg',
    slug: 'chees-up',
  },
  {
    id: 'dar-djeddi',
    name: 'دار جدي للمأكولات التقليدية',
    tagAr: 'أطباق تقليدية • زفيطي • شخشوخة • كسكسي',
    tagFr: 'Plats Traditionnels • Zviti • Chakhchoukha',
    tagEn: 'Traditional Algerian • Zviti • Couscous',
    rating: 5.0,
    deliveryTime: '30-45 دقيقة',
    deliveryTimeEn: '30-45 min',
    logo: 'https://wtowqpejzxlsmgywkjvn.supabase.co/storage/v1/object/public/restaurant-logos/4132efc9-eab0-4f73-93ac-d85ff026fc3b_restaurant-logos_1777266444275.jpg',
    cover: 'https://pub-011aba279eb84591b0d96b9b9415ce2e.r2.dev/dar%20djeddi.jpg',
    slug: 'dar-djeddi',
  },
  {
    id: 'savini-07',
    name: 'SAVINI 07',
    tagAr: 'تشيز كيك • كريب ووافل • حلويات وميلك شيك',
    tagFr: 'Cheesecakes • Crêpes & Gaufres • Pâtisseries',
    tagEn: 'Cheesecake • Crepes & Waffles • Desserts',
    rating: 5.0,
    deliveryTime: '20-30 دقيقة',
    deliveryTimeEn: '20-30 min',
    logo: 'https://pub-e75807f307834b89a8e0a2463ebb914f.r2.dev/SAVINI%2007.jpg',
    cover: 'https://pub-011aba279eb84591b0d96b9b9415ce2e.r2.dev/savini.png',
    slug: 'savini-07',
  },
  {
    id: 'unlock-food',
    name: 'Unlock Food',
    tagAr: 'بوكسات عائلية • كريسبي • برغر وشاورما',
    tagFr: 'Box Familiales • Poulet Crispy • Burgers',
    tagEn: 'Family Boxes • Crispy Chicken • Burgers',
    rating: 4.8,
    deliveryTime: '25-35 دقيقة',
    deliveryTimeEn: '25-35 min',
    logo: 'https://pub-e75807f307834b89a8e0a2463ebb914f.r2.dev/unlock.jpg',
    cover: 'https://pub-011aba279eb84591b0d96b9b9415ce2e.r2.dev/unlock.jpg',
    slug: 'unlock-food',
  },
  {
    id: 'diety-food-biskra',
    name: 'Diety Food Biskra',
    tagAr: 'أكل صحي • وجبات دايت ورياضيين • سلطات',
    tagFr: 'Repas Sains • Plats Fitness & Diététiques',
    tagEn: 'Healthy Food • Fitness & Diet Meals',
    rating: 5.0,
    deliveryTime: '25-35 دقيقة',
    deliveryTimeEn: '25-35 min',
    logo: 'https://pub-e75807f307834b89a8e0a2463ebb914f.r2.dev/Diety%20Food%20Biskra.jpg',
    cover: 'https://pub-011aba279eb84591b0d96b9b9415ce2e.r2.dev/diety.png',
    slug: 'diety-food-biskra',
  },
  {
    id: 'seven-eleven',
    name: 'Seven Eleven',
    tagAr: 'بيتزا إيطالية • كالزون • ملفوف وتيراميسو',
    tagFr: 'Pizzas • Calzones • Malfouf & Tiramisu',
    tagEn: 'Italian Pizza • Calzone • Malfouf & Desserts',
    rating: 5.0,
    deliveryTime: '25-35 دقيقة',
    deliveryTimeEn: '25-35 min',
    logo: 'https://pub-e75807f307834b89a8e0a2463ebb914f.r2.dev/Seven%20Eleven.jpg',
    cover: 'https://pub-e75807f307834b89a8e0a2463ebb914f.r2.dev/Seven%20Eleven.jpg',
    slug: null,
  },
  {
    id: 'islam-diet',
    name: 'Islam Diet',
    tagAr: 'وجبات صحية بروتينية • دجاج وتونة وسلطات',
    tagFr: 'Plats Diététiques & Protéinés • Poulet & Thon',
    tagEn: 'High-Protein Healthy Bowls • Chicken & Tuna',
    rating: 5.0,
    deliveryTime: '25-35 دقيقة',
    deliveryTimeEn: '25-35 min',
    logo: 'https://pub-e75807f307834b89a8e0a2463ebb914f.r2.dev/islam%20diet.jpg',
    cover: 'https://pub-011aba279eb84591b0d96b9b9415ce2e.r2.dev/islam%20diet.png',
    slug: 'islam-diet',
  },
  {
    id: 'morphine-food',
    name: 'Morphine Food',
    tagAr: 'سندويتشات • برغر • طاكوس • بوتين',
    tagFr: 'Sandwiches • Burgers • Tacos • Poutine',
    tagEn: 'Sandwiches • Burgers • Tacos • Poutine',
    rating: 5.0,
    deliveryTime: '25-35 دقيقة',
    deliveryTimeEn: '25-35 min',
    logo: 'https://pub-e75807f307834b89a8e0a2463ebb914f.r2.dev/Morphine.jpg',
    cover: 'https://pub-011aba279eb84591b0d96b9b9415ce2e.r2.dev/Morphine.jpg',
    slug: 'morphine-food',
  },
  {
    id: 'daily-dose',
    name: 'Daily Dose',
    tagAr: 'قهوة مختصة • بان كيك ووافل • حلويات',
    tagFr: 'Café Spécialisé • Pancakes & Gaufres • Desserts',
    tagEn: 'Specialty Coffee • Pancakes & Waffles • Sweets',
    rating: 4.9,
    deliveryTime: '20-30 دقيقة',
    deliveryTimeEn: '20-30 min',
    logo: 'https://pub-e75807f307834b89a8e0a2463ebb914f.r2.dev/Daily%20Dose.jpg',
    cover: 'https://pub-011aba279eb84591b0d96b9b9415ce2e.r2.dev/daily.jpg',
    slug: 'daily-dose',
  },
];

const CONTENT = {
  ar: {
    nav: {
      services: 'أشهر المطاعم',
      whySahla: 'علاش ساهلة؟',
      howItWorks: 'كيف تطلب',
      partners: 'انضم إلينا',
      call: 'اتصل بنا',
    },
    hero: {
      badge: 'تطبيق توصيل الطعام الأول في مدينتك',
      title1: 'خليك في بلاصتك...',
      titleHighlight: 'حنا نجيو لعندك!',
      subtitle:
        'أي وقت... أي مكان. كل ما تشتهيه من أشهى وجباتك وأطباقك المفضلة يوصلك سخون وسريع حتى لباب دارك مع ساهلة.',
      chipSpeed: '⚡ توصيل في أقل من 45 دقيقة',
      chipTracking: '📍 تتبع مسار طلبك لحظة بلحظة',
      chipQuality: '💵 دفع سهل نقداً عند الاستلام',
      downloadAppStore: 'App Store',
      downloadGooglePlay: 'Google Play',
    },
    restaurants: {
      locationSubtitle: 'نقدم لكم أفضل الإختيارات في ولاية بسكرة',
      customerCare: 'خدمة العملاء',
      searchPlaceholder: 'البحث في المطاعم...',
      appSectionTitle: 'استمتع بأفضل اختياراتنا لك',
      openNowBadge: 'مفتوح الآن 🟢',
      statusOpen: 'مفتوح الآن',
      viewReviews: 'عرض جميع المراجعات',
      currency: 'دج',
      minOrderSuffix: 'الحد الأدنى',
      cuisineFallback: 'أشهى الوجبات',
      emptySearchTitle: 'لا توجد مطاعم مطابقة',
      emptySearchDesc: 'جرب البحث باسم مطعم آخر أو اختر تصنيفاً مختلفاً من الأعلى',
      resetFilters: 'عرض جميع المطاعم',
      bottomNavHome: 'الرئيسية',
      bottomNavOrders: 'الطلبات',
      bottomNavHelp: 'المساعدة',
      viewMenu: 'تصفح المنيو',
      openApp: 'اطلب الآن',
    },
    whySahla: {
      eyebrow: 'لماذا يفضلنا المئات؟',
      title: 'مميزات تصنع الفارق في كل طلب',
      card1Title: 'سرعة توصيل قياسية',
      card1Desc: 'خوارزميات ذكية ترشح أقرب عامل توصيل لك وللمطعم لتصلك الوجبة في أسرع وقت ممكن.',
      card2Title: 'عمال توصيل معتمدون وموثوقون',
      card2Desc: 'فريق توصيل محترف ومدرب يتمتع بأعلى معايير الأمانة واللباقة وسرعة الاستجابة.',
      card3Title: 'خدمة زبائن محلية متواصلة',
      card3Desc: 'فريق دعم محلي جزائري جاهز لمساعدتك وحل أي استفسار على مدار أيام الأسبوع.',
    },
    howItWorks: {
      eyebrow: 'بسيطة في 3 خطوات',
      title: 'كيف تطلب من ساهلة؟',
      step1Title: '1. اختر مطعمك المفضل',
      step1Desc: 'تصفح المطاعم ومحلات الأكل القريبة منك حسب نوع الأكل أو التقييمات.',
      step2Title: '2. حدد وجبتك وأكد الطلب',
      step2Desc: 'أضف ما تشتهيه إلى السلة وأكد طلبك بضغطة واحدة مع إضافة ملاحظاتك.',
      step3Title: '3. استلم واستمتع بأكلك سخون',
      step3Desc: 'تابع مسار عامل التوصيل على الخريطة واستلم طلبك عند باب دارك بكل سهولة.',
    },
    partners: {
      restaurantPill: 'لأصحاب المطاعم',
      restaurantTitle: 'ضاعف مبيعات مطعمك وانضم لشبكة ساهلة فود',
      restaurantDesc:
        'اربط مطعمك بمئات الزبائن في مدينتك، حسّن مبيعاتك اليومية واستفد من أسطول توصيل محترف دون أي أعباء تشغيلية إضافية.',
      restaurantBtn: 'سجل مطعمك الآن',
      driverPill: 'لعمال التوصيل',
      driverTitle: 'انضم لفريق توصيل ساهلة وحقق دخلاً يومياً ممتازاً',
      driverDesc:
        'كن سيد نفسك مع أوقات عمل حرة ومرنة. اربح مع كل وجبة توصلها واستفد من دعم مستمر ومكافآت على مدار الشهر.',
      driverBtn: 'انضم كعامل توصيل',
    },
    download: {
      title: 'جاهز للطلب؟ حمّل التطبيق الآن!',
      desc: 'انضم إلى مئات المستخدمين الذين يستمتعون بأشهى المأكولات وأسرع توصيل. متوفر مجاناً على iOS و Android.',
      scanText: 'امسح الكود بكاميرا هاتفك للتحميل المباشر',
    },
    contact: {
      title: 'تواصل معنا',
      phone: 'اتصال هاتفي',
      whatsapp: 'واتساب ساهلة',
      email: 'البريد الإلكتروني',
      socialTitle: 'تابعنا على مواقع التواصل',
      chatWhatsapp: 'تواصل معنا على واتساب',
      callUs: 'اتصل بنا مباشرة',
    },
    footer: {
      desc: 'ساهلة — تطبيق توصيل الطعام الجزائري الرائد. خليك في بلاصتك.. حنا نجيو لعندك!',
      company: 'الشركة',
      services: 'أشهر المطاعم',
      legal: 'الشروط والسياسات',
      privacy: 'سياسة الخصوصية',
      terms: 'شروط الخدمة',
      deleteAccount: 'حذف الحساب',
      contact: 'اتصل بنا',
      copyright: '© 2026 ساهلة (Sahla Delivery). جميع الحقوق محفوظة.',
    },
    iosAnnouncement: {
      bannerTag: 'تنبيه لمستخدمي iPhone',
      bannerText: 'تطبيق App Store يخضع لتحديث مؤقت وسيتوفر قريباً! يمكنك تصفح المطاعم والطلب مباشرة عبر موقعنا الآن دون تحميل.',
      bannerCta: 'تصفح واطلب الآن',
      badgeText: 'قيد التحديث ⏳',
      modalTitle: 'تطبيق App Store قيد التحديث ⏳',
      modalDesc: 'تطبيق Sahla يخضع حالياً لتحديثات دورية على متجر App Store من قِبل Apple وسيكون متاحاً للتحميل قريباً جداً.',
      modalHighlight: 'لا داعي للانتظار! يمكنك تصفح جميع مطاعمك المفضلة واختيار وجباتك وتأكيد طلبك مباشرة عبر موقعنا بكل سهولة وسرعة وبدون الحاجة لتطبيق.',
      modalWebCta: '🍔 تصفح المطاعم والطلب عبر الويب',
      modalWhatsappCta: '💬 طلب سريع عبر واتساب',
      modalClose: 'إغلاق',
      heroWebOrderBadge: '🌐 جديد: الطلب متاح مباشرة عبر الويب',
      heroWebOrderText: 'تصفح المطاعم واطلب وجبتك المفضلة الآن ←',
    },
  },
  fr: {
    nav: {
      services: 'Restaurants',
      whySahla: 'Pourquoi Sahla ?',
      howItWorks: 'Comment ça marche',
      partners: 'Partenaires',
      call: 'Appelez-nous',
    },
    hero: {
      badge: 'Livraison de repas n°1 dans votre ville',
      title1: 'Restez chez vous...',
      titleHighlight: 'On vient chez vous !',
      subtitle:
        'À tout moment, partout. Tous vos plats et repas favoris livrés chauds et rapides jusqu’à votre porte avec Sahla.',
      chipSpeed: '⚡ Livraison en moins de 45 min',
      chipTracking: '📍 Suivi GPS en temps réel',
      chipQuality: '💵 Espèces à la livraison',
      downloadAppStore: 'App Store',
      downloadGooglePlay: 'Google Play',
    },
    restaurants: {
      locationSubtitle: 'Les meilleures sélections à Biskra',
      customerCare: 'Service Client',
      searchPlaceholder: 'Rechercher un restaurant...',
      appSectionTitle: 'Nos meilleures sélections pour vous',
      openNowBadge: 'ouverts maintenant 🟢',
      statusOpen: 'Ouvert',
      viewReviews: 'Voir les avis',
      currency: 'DA',
      minOrderSuffix: 'Min',
      cuisineFallback: 'Repas savoureux',
      emptySearchTitle: 'Aucun restaurant trouvé',
      emptySearchDesc: 'Essayez un autre mot-clé ou changez de catégorie',
      resetFilters: 'Voir tous les restaurants',
      bottomNavHome: 'Accueil',
      bottomNavOrders: 'Commandes',
      bottomNavHelp: 'Aide',
      viewMenu: 'Voir le menu',
      openApp: 'Commander',
    },
    whySahla: {
      eyebrow: 'Pourquoi des centaines nous font confiance ?',
      title: 'Une qualité de service irréprochable',
      card1Title: 'Vitesse de livraison record',
      card1Desc: 'Des algorithmes intelligents qui sélectionnent le livreur le plus proche pour chaque course.',
      card2Title: 'Livreurs formés et vérifiés',
      card2Desc: 'Une équipe dévouée, polie et respectueuse des délais et de la manipulation soignée de vos repas.',
      card3Title: 'Service client local 7j/7',
      card3Desc: 'Une assistance réactive basée en Algérie prête à vous répondre à tout moment.',
    },
    howItWorks: {
      eyebrow: 'En 3 étapes faciles',
      title: 'Comment commander sur Sahla ?',
      step1Title: '1. Choisissez votre restaurant',
      step1Desc: 'Parcourez les meilleurs établissements près de chez vous.',
      step2Title: '2. Composez votre commande',
      step2Desc: 'Sélectionnez vos plats et validez en un clin d’œil.',
      step3Title: '3. Recevez et dégustez !',
      step3Desc: 'Suivez le livreur sur la carte et savourez votre repas bien chaud.',
    },
    partners: {
      restaurantPill: 'Pour les restaurateurs',
      restaurantTitle: 'Boostez vos ventes avec le réseau Sahla Food',
      restaurantDesc:
        'Touchez des centaines de nouveaux clients et confiez vos livraisons à une flotte professionnelle clé en main.',
      restaurantBtn: 'Devenir partenaire',
      driverPill: 'Pour les livreurs',
      driverTitle: 'Rejoignez l’équipe de livraison Sahla avec des revenus attractifs',
      driverDesc:
        'Travaillez en toute liberté d’horaires avec des gains quotidiens et des primes régulières.',
      driverBtn: 'Devenir livreur',
    },
    download: {
      title: 'Prêt à commander ? Téléchargez l’application !',
      desc: 'Disponible gratuitement sur iPhone et Android. Rejoignez des centaines d’utilisateurs conquis.',
      scanText: 'Scannez le QR code avec votre téléphone pour installer l’app',
    },
    contact: {
      title: 'Contactez-nous',
      phone: 'Téléphone',
      whatsapp: 'WhatsApp direct',
      email: 'E-mail support',
      socialTitle: 'Suivez-nous sur les réseaux',
      chatWhatsapp: 'Discuter sur WhatsApp',
      callUs: 'Appelez-nous directement',
    },
    footer: {
      desc: 'Sahla — L’application algérienne de référence pour la livraison de repas à domicile. Restez chez vous, on vient chez vous !',
      company: 'Entreprise',
      services: 'Restaurants',
      legal: 'Légal',
      privacy: 'Politique de confidentialité',
      terms: 'Conditions d’utilisation',
      deleteAccount: 'Supprimer mon compte',
      contact: 'Contactez-nous',
      copyright: '© 2026 Sahla Delivery. Tous droits réservés.',
    },
    iosAnnouncement: {
      bannerTag: 'Avis utilisateurs iPhone',
      bannerText: 'L’application App Store est temporairement en mise à jour. Commandez directement sur notre site web sans application !',
      bannerCta: 'Commander sur le Web',
      badgeText: 'En mise à jour ⏳',
      modalTitle: 'Application App Store en mise à jour ⏳',
      modalDesc: 'L’application Sahla sur l’App Store est temporairement en cours de mise à jour Apple et sera disponible très bientôt.',
      modalHighlight: 'Pas besoin d’attendre ! Vous pouvez parcourir tous nos restaurants partenaires et commander directement en ligne sans application.',
      modalWebCta: '🍔 Voir les restaurants & commander',
      modalWhatsappCta: '💬 Commander via WhatsApp',
      modalClose: 'Fermer',
      heroWebOrderBadge: '🌐 Nouveau : Commande directe sur le Web',
      heroWebOrderText: 'Choisissez votre restaurant et commandez ←',
    },
  },
  en: {
    nav: {
      services: 'Restaurants',
      whySahla: 'Why Sahla?',
      howItWorks: 'How It Works',
      partners: 'Partners',
      call: 'Call Us',
    },
    hero: {
      badge: '#1 Food Delivery App in Your City',
      title1: 'Stay where you are...',
      titleHighlight: 'We deliver to you!',
      subtitle:
        'Any time, any place. Your favorite meals and dishes delivered piping hot and fast to your doorstep with Sahla.',
      chipSpeed: '⚡ Under 45-min fast delivery',
      chipTracking: '📍 Live GPS order tracking',
      chipQuality: '💵 Cash on delivery accepted',
      downloadAppStore: 'App Store',
      downloadGooglePlay: 'Google Play',
    },
    restaurants: {
      locationSubtitle: 'The finest selections in Biskra',
      customerCare: 'Customer Care',
      searchPlaceholder: 'Search restaurants...',
      appSectionTitle: 'Enjoy our best picks for you',
      openNowBadge: 'open now 🟢',
      statusOpen: 'Open Now',
      viewReviews: 'View all reviews',
      currency: 'DA',
      minOrderSuffix: 'Min order',
      cuisineFallback: 'Delicious Food',
      emptySearchTitle: 'No restaurants found',
      emptySearchDesc: 'Try another search keyword or switch category',
      resetFilters: 'View all restaurants',
      bottomNavHome: 'Home',
      bottomNavOrders: 'Orders',
      bottomNavHelp: 'Support',
      viewMenu: 'View Menu',
      openApp: 'Order Now',
    },
    whySahla: {
      eyebrow: 'Why Hundreds Choose Us',
      title: 'Distinct Quality in Every Single Order',
      card1Title: 'Record-Breaking Speed',
      card1Desc: 'Smart dispatch matching that picks the closest courier for lightning-fast arrival.',
      card2Title: 'Trusted & Verified Couriers',
      card2Desc: 'Professional delivery couriers trained for utmost courtesy, care, and speed.',
      card3Title: 'Dedicated Local Customer Support',
      card3Desc: 'Algerian support team ready to assist you seven days a week.',
    },
    howItWorks: {
      eyebrow: 'Simple in 3 Steps',
      title: 'How to Order with Sahla',
      step1Title: '1. Pick Your Restaurant',
      step1Desc: 'Browse top rated eateries, trending spots, and local favorites nearby.',
      step2Title: '2. Customize & Confirm',
      step2Desc: 'Select your meals, add special requests, and confirm with one tap.',
      step3Title: '3. Receive & Enjoy',
      step3Desc: 'Track your delivery courier on the map and enjoy a warm, satisfying meal at home.',
    },
    partners: {
      restaurantPill: 'For Restaurant Owners',
      restaurantTitle: 'Scale Your Restaurant with Sahla Food',
      restaurantDesc:
        'Connect with hundreds of local diners, grow revenue, and rely on an automated delivery fleet.',
      restaurantBtn: 'Partner With Us',
      driverPill: 'For Delivery Couriers',
      driverTitle: 'Join the Sahla Delivery Team & Earn Great Daily Income',
      driverDesc:
        'Enjoy flexible working hours, competitive per-delivery earnings, and weekly bonus incentives.',
      driverBtn: 'Become a Delivery Courier',
    },
    download: {
      title: 'Ready to order? Get the Sahla app now!',
      desc: 'Join hundreds enjoying the easiest and fastest food delivery. Available free for iOS and Android.',
      scanText: 'Scan this QR code with your phone camera to download directly',
    },
    contact: {
      title: 'Contact Us',
      phone: 'Phone Call',
      whatsapp: 'WhatsApp Direct',
      email: 'Email Support',
      socialTitle: 'Follow Us on Social Media',
      chatWhatsapp: 'Chat on WhatsApp',
      callUs: 'Call Us Directly',
    },
    footer: {
      desc: 'Sahla — Algeria’s leading food delivery app. Stay where you are, we come to you!',
      company: 'Company',
      services: 'Restaurants',
      legal: 'Legal',
      privacy: 'Privacy Policy',
      terms: 'Terms of Service',
      deleteAccount: 'Delete Account',
      contact: 'Contact Us',
      copyright: '© 2026 Sahla Delivery. All rights reserved.',
    },
    iosAnnouncement: {
      bannerTag: 'Notice for iPhone Users',
      bannerText: 'The App Store app is temporarily updating. You can order directly via our website right now without an app!',
      bannerCta: 'Order on the Web',
      badgeText: 'Updating ⏳',
      modalTitle: 'App Store App Updating Soon ⏳',
      modalDesc: 'The Sahla iOS app on the App Store is temporarily undergoing updates and will be available shortly.',
      modalHighlight: 'No need to wait! Browse all partner restaurants and order your favorite meals directly on our website.',
      modalWebCta: '🍔 Browse Restaurants & Order on Web',
      modalWhatsappCta: '💬 Order via WhatsApp',
      modalClose: 'Close',
      heroWebOrderBadge: '🌐 New: Direct Web Ordering Available',
      heroWebOrderText: 'Pick your restaurant and order now ←',
    },
  },
};

export default function HomePage() {
  const [lang, setLang] = useState<Language>('ar');
  const [showBanner, setShowBanner] = useState<boolean>(true);
  const [showAppStoreModal, setShowAppStoreModal] = useState<boolean>(false);
  const [restaurants, setRestaurants] = useState<RestaurantItem[]>(
    FEATURED_RESTAURANTS.filter((r) => r.isOpen !== false)
  );
  const [cuisines, setCuisines] = useState<CuisineCategory[]>(INITIAL_CUISINES);
  const [selectedCuisineId, setSelectedCuisineId] = useState<string>('all');

  useEffect(() => {
    let isMounted = true;
    async function loadRestaurants() {
      try {
        const res = await fetch('/api/public/restaurants');
        if (!res.ok) return;
        const data = await res.json();
        if (isMounted) {
          if (Array.isArray(data?.restaurants) && data.restaurants.length > 0) {
            setRestaurants(data.restaurants.filter((r: any) => r.isOpen !== false));
          }
          if (Array.isArray(data?.cuisines) && data.cuisines.length > 0) {
            setCuisines([
              {
                id: 'all',
                name: 'All',
                nameAr: 'الكل',
                icon: '',
                sortOrder: 0,
              },
              ...data.cuisines,
            ]);
          }
        }
      } catch (err) {
        // Fallback to static initial list
      }
    }
    loadRestaurants();
    return () => {
      isMounted = false;
    };
  }, []);

  const filteredRestaurants = useMemo(() => {
    let list = restaurants.filter((r) => r.isOpen !== false);

    if (selectedCuisineId !== 'all') {
      list = list.filter((r) => r.cuisineTypeIds?.includes(selectedCuisineId));
    }

    return list;
  }, [restaurants, selectedCuisineId]);

  useEffect(() => {
    const saved = localStorage.getItem('sahla_user_lang') as Language;
    if (saved && (saved === 'ar' || saved === 'fr' || saved === 'en')) {
      setLang(saved);
    }
    const bannerDismissed = sessionStorage.getItem('sahla_hide_ios_banner');
    if (bannerDismissed === '1') {
      setShowBanner(false);
    }
  }, []);

  const handleDismissBanner = () => {
    setShowBanner(false);
    sessionStorage.setItem('sahla_hide_ios_banner', '1');
  };

  useEffect(() => {
    const handleKeyDown = (e: KeyboardEvent) => {
      if (e.key === 'Escape') {
        setShowAppStoreModal(false);
      }
    };
    if (showAppStoreModal) {
      window.addEventListener('keydown', handleKeyDown);
      document.body.style.overflow = 'hidden';
    } else {
      document.body.style.overflow = '';
    }
    return () => {
      window.removeEventListener('keydown', handleKeyDown);
      document.body.style.overflow = '';
    };
  }, [showAppStoreModal]);

  const handleLanguageChange = (newLang: Language) => {
    setLang(newLang);
    localStorage.setItem('sahla_user_lang', newLang);
  };

  const t = CONTENT[lang];
  const isRtl = lang === 'ar';

  return (
    <main className="landing-page" dir={isRtl ? 'rtl' : 'ltr'}>
      {/* ----------------------------------------
          IOS APP STORE TEMPORARY ANNOUNCEMENT BAR
          ---------------------------------------- */}
      {showBanner && (
        <div className="ios-announcement-banner" role="alert">
          <div className="ios-banner-container">
            {/* Top Left: Notice Badge */}
            <div className="ios-banner-left">
              <span className="ios-banner-tag">
                <span className="ios-banner-pulse" />
                {t.iosAnnouncement.bannerTag}
              </span>
            </div>

            {/* Middle: Context Text */}
            <div className="ios-banner-center">
              <span className="ios-banner-message">{t.iosAnnouncement.bannerText}</span>
            </div>

            {/* Top Right: Close Button */}
            <div className="ios-banner-right">
              <button
                type="button"
                className="ios-banner-close-btn"
                onClick={handleDismissBanner}
                aria-label="Dismiss banner"
              >
                ✕
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ----------------------------------------
          POLISHED HEADER / NAVBAR
          ---------------------------------------- */}
      <header className="site-header">
        <div className="header-container">
          {/* Logo with proper proportions */}
          <Link href="/" className="brand-logo-link" aria-label="Sahla Home">
            <Image
              src="/logo.webp"
              alt="Sahla Delivery"
              width={130}
              height={40}
              priority
              className="header-logo-img"
            />
          </Link>

          {/* Desktop Navigation */}
          <nav className="header-nav" aria-label="Main Navigation">
            <a href="#services">{t.nav.services}</a>
            <a href="#why-sahla">{t.nav.whySahla}</a>
            <a href="#how-it-works">{t.nav.howItWorks}</a>
            <a href="#partners">{t.nav.partners}</a>
            <a href="#contact">{t.contact.title}</a>
          </nav>

          {/* Header Actions */}
          <div className="header-actions">
            {/* Sleek Segmented Language Pill */}
            <div className="lang-segmented-control" role="group" aria-label="Language Selector">
              <button
                type="button"
                className={`lang-segment-btn ${lang === 'ar' ? 'active' : ''}`}
                onClick={() => handleLanguageChange('ar')}
                aria-pressed={lang === 'ar'}
              >
                عربي
              </button>
              <button
                type="button"
                className={`lang-segment-btn ${lang === 'fr' ? 'active' : ''}`}
                onClick={() => handleLanguageChange('fr')}
                aria-pressed={lang === 'fr'}
              >
                FR
              </button>
              <button
                type="button"
                className={`lang-segment-btn ${lang === 'en' ? 'active' : ''}`}
                onClick={() => handleLanguageChange('en')}
                aria-pressed={lang === 'en'}
              >
                EN
              </button>
            </div>

            {/* CALL US Primary CTA Button */}
            <a
              href={`tel:${PHONE_NUMBER}`}
              className="header-cta-btn header-call-cta"
              aria-label={t.contact.callUs}
              title={PHONE_DISPLAY}
            >
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.4" strokeLinecap="round" strokeLinejoin="round">
                <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z" />
              </svg>
              <span>{t.nav.call}</span>
            </a>
          </div>
        </div>
      </header>

      {/* ----------------------------------------
          HERO SECTION (FOCUSED & POWERFUL)
          ---------------------------------------- */}
      <section className="hero-section">
        <div className="hero-glow-blob" />
        <div className="hero-container hero-container-single">
          <div className="hero-content hero-content-center">
            <div className="hero-pill-badge">
              <span className="hero-pill-indicator" />
              <span>{t.hero.badge}</span>
            </div>

            <h1 className="hero-title">
              {t.hero.title1}{' '}
              <span className="hero-highlight">{t.hero.titleHighlight}</span>
            </h1>

            <p className="hero-subtitle">{t.hero.subtitle}</p>

            <div className="hero-trust-chips">
              <span className="trust-chip">{t.hero.chipSpeed}</span>
              <span className="trust-chip">{t.hero.chipTracking}</span>
              <span className="trust-chip">{t.hero.chipQuality}</span>
            </div>

            {/* Guaranteed Same-Row Store Buttons on Mobile & Desktop */}
            <div className="hero-download-group" id="download-app">
              {/* App Store Button (with Updating Badge & Modal trigger) */}
              <button
                type="button"
                onClick={() => setShowAppStoreModal(true)}
                className="store-btn store-btn-appstore"
                aria-label="Download on App Store (Updating)"
                dir="ltr"
              >
                <span className="store-badge-tempo">{t.iosAnnouncement.badgeText}</span>
                <svg className="store-btn-icon" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 6.85c.67-.82 1.13-1.96 1.01-3.1-.98.04-2.17.65-2.87 1.47-.62.72-1.16 1.88-1.01 2.99 1.1.09 2.2-.54 2.87-1.36z" />
                </svg>
                <div className="store-btn-meta" dir="ltr">
                  <span className="store-btn-label">Download on</span>
                  <span className="store-btn-name">App Store</span>
                </div>
              </button>

              {/* Google Play Button */}
              <a
                href={GOOGLE_PLAY_URL}
                target="_blank"
                rel="noreferrer"
                className="store-btn store-btn-google"
                aria-label="Get it on Google Play"
                dir="ltr"
              >
                <svg className="store-btn-icon" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M3,20.5V3.5C3,2.91 3.34,2.39 3.84,2.15L13.69,12L3.84,21.85C3.34,21.6 3,21.09 3,20.5M16.81,15.12L6.05,21.34L14.54,12.85L16.81,15.12M20.16,10.81C20.5,11.08 20.75,11.5 20.75,12C20.75,12.5 20.53,12.9 20.18,13.18L17.89,14.5L15.39,12L17.89,9.5L20.16,10.81M6.05,2.66L16.81,8.88L14.54,11.15L6.05,2.66Z" />
                </svg>
                <div className="store-btn-meta" dir="ltr">
                  <span className="store-btn-label">Get it on</span>
                  <span className="store-btn-name">Google Play</span>
                </div>
              </a>
            </div>

            {/* Direct Web Ordering Banner right in Hero */}
            <div className="hero-web-order-card">
              <a href="#services" className="hero-web-order-link">
                <span className="hero-web-order-pill">{t.iosAnnouncement.heroWebOrderBadge}</span>
                <span className="hero-web-order-prompt">{t.iosAnnouncement.heroWebOrderText}</span>
              </a>
            </div>
          </div>
        </div>
      </section>

      {/* ----------------------------------------
          APP-MATCHING RESTAURANTS & FOOD DISCOVERY SECTION
          ---------------------------------------- */}
      <section className="app-food-discovery-section" id="services">
        <div className="app-discovery-container">
          {/* Top Bar: Location Tag */}
          <div className="app-top-info-row">
            <span className="app-location-tag">
              {t.restaurants.locationSubtitle}
            </span>
          </div>

          {/* Dynamic Greeting (صباح الخير / مساء الخير) */}
          <div className="app-greeting-row">
            <h1 className="app-greeting-title">{getGreeting(lang)}</h1>
          </div>

          {/* Horizontal Pinned Cuisines / Category Scroll */}
          <div className="app-categories-scroll-wrapper">
            <div className="app-categories-scroll" role="tablist" aria-label="Food Categories">
              {cuisines.map((c) => {
                const isSelected = selectedCuisineId === c.id;
                return (
                  <button
                    key={c.id}
                    type="button"
                    role="tab"
                    aria-selected={isSelected}
                    className={`app-category-pill-item ${isSelected ? 'active' : ''}`}
                    onClick={() => setSelectedCuisineId(c.id)}
                  >
                    <div className="app-category-avatar-wrap">
                      {c.id === 'all' ? (
                        <svg
                          width="26"
                          height="26"
                          viewBox="0 0 24 24"
                          fill="none"
                          stroke={isSelected ? '#064E3B' : '#4B5563'}
                          strokeWidth="2.2"
                          strokeLinecap="round"
                          strokeLinejoin="round"
                        >
                          <path d="M3 2v7c0 1.1.9 2 2 2h4a2 2 0 0 0 2-2V2" />
                          <path d="M7 2v20" />
                          <path d="M21 15V2a5 5 0 0 0-5 5v6c0 1.1.9 2 2 2h3Zm0 0v7" />
                        </svg>
                      ) : c.icon ? (
                        // eslint-disable-next-line @next/next/no-img-element
                        <img
                          src={c.icon}
                          alt={c.nameAr}
                          className="app-category-avatar-img"
                          loading="lazy"
                        />
                      ) : (
                        <span className="app-category-avatar-fallback">🍽️</span>
                      )}
                    </div>
                    <span className="app-category-label">
                      {lang === 'ar' ? c.nameAr : c.name}
                    </span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Section Headline */}
          <div className="app-discovery-head">
            <h2 className="app-discovery-title">
              {t.restaurants.appSectionTitle}
            </h2>
            <span className="app-discovery-count-pill">
              {filteredRestaurants.length > 0
                ? `${filteredRestaurants.length} ${t.restaurants.openNowBadge}`
                : lang === 'ar'
                ? 'يُفتح على 11:00 🕒'
                : lang === 'fr'
                ? 'Ouvre à 11:00 🕒'
                : 'Opens at 11:00 🕒'}
            </span>
          </div>

          {/* Vertical App-Matching Restaurant Feed */}
          <div className="app-restaurants-vertical-list">
            {filteredRestaurants.length === 0 ? (
              <div className="app-restaurants-empty-state">
                <span className="app-empty-icon">🕒</span>
                <h3>
                  {lang === 'ar'
                    ? 'المطاعم مغلقة حالياً'
                    : lang === 'fr'
                    ? 'Les restaurants sont actuellement fermés'
                    : 'Restaurants are currently closed'}
                </h3>
                <p>
                  {lang === 'ar'
                    ? 'يبدأ استقبال وتوصيل الطلبات يومياً عند الساعة 11:00 صباحاً بتوقيت بسكرة.'
                    : lang === 'fr'
                    ? 'Les commandes et livraisons débutent quotidiennement à partir de 11:00 (heure de Biskra).'
                    : 'Order delivery resumes daily starting at 11:00 AM (Biskra local time).'}
                </p>
                {selectedCuisineId !== 'all' && (
                  <button
                    type="button"
                    className="app-reset-filter-btn"
                    onClick={() => setSelectedCuisineId('all')}
                  >
                    {t.restaurants.resetFilters}
                  </button>
                )}
              </div>
            ) : (
              filteredRestaurants.map((resto) => {
                const displayName =
                  lang === 'ar' && resto.nameAr
                    ? resto.nameAr
                    : lang === 'fr' && resto.nameLatin
                    ? resto.nameLatin
                    : resto.name;
                const time =
                  lang === 'ar' ? resto.deliveryTime : resto.deliveryTimeEn;
                const linkHref = resto.slug ? `/restaurants/${resto.slug}` : '#download-app';
                const deliveryFee = resto.deliveryFee || 150;
                const reviewCount = resto.reviewCount || 0;

                return (
                  <Link
                    key={resto.id}
                    href={linkHref}
                    className="app-restaurant-card-row"
                    title={displayName}
                  >
                    {/* Media Column (Image + Floating Logo) */}
                    <div className="app-card-media-box">
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img
                        src={resto.cover}
                        alt={displayName}
                        loading="lazy"
                        className="app-card-cover-photo"
                      />
                      <div className="app-card-cover-dim" />

                      {/* Floating Mini Logo */}
                      <div className="app-card-mini-logo">
                        {/* eslint-disable-next-line @next/next/no-img-element */}
                        <img src={resto.logo} alt="" className="app-card-mini-logo-img" />
                      </div>
                    </div>

                    {/* Info Column */}
                    <div className="app-card-info-box">
                      <div className="app-card-title-row">
                        <h3 className="app-card-name">{displayName}</h3>
                      </div>

                      {/* Live Open Status */}
                      <div className="app-card-live-status">
                        <span className="app-live-pulse-dot" />
                        <span>{t.restaurants.statusOpen}</span>
                      </div>

                      {/* Rating & Reviews */}
                      <div className="app-card-rating-line">
                        <span className="app-star-icon">★</span>
                        <span className="app-rating-val">{resto.rating.toFixed(1)}</span>
                        <span className="app-review-cnt">
                          ({reviewCount > 0 ? `+${reviewCount}` : '+0'})
                        </span>
                        <span className="app-reviews-view-text">({t.restaurants.viewReviews})</span>
                      </div>

                      {/* Delivery Row: Fee | Time */}
                      <div className="app-card-delivery-meta">
                        <span className="app-meta-fee">
                          🛵 {deliveryFee} {t.restaurants.currency}
                        </span>
                        <span className="app-meta-sep">•</span>
                        <span className="app-meta-time">
                          🕒 {time}
                        </span>
                      </div>
                    </div>
                  </Link>
                );
              })
            )}
          </div>
        </div>
      </section>

      {/* ----------------------------------------
          WHY SAHLA (3 CORE PILLARS)
          ---------------------------------------- */}
      <section className="why-section" id="why-sahla">
        <div className="section-head-center">
          <span className="section-eyebrow">{t.whySahla.eyebrow}</span>
          <h2 className="section-main-title">{t.whySahla.title}</h2>
        </div>

        <div className="why-grid">
          <div className="why-card">
            <div className="why-icon">⚡</div>
            <h3>{t.whySahla.card1Title}</h3>
            <p>{t.whySahla.card1Desc}</p>
          </div>

          <div className="why-card">
            <div className="why-icon">🛵</div>
            <h3>{t.whySahla.card2Title}</h3>
            <p>{t.whySahla.card2Desc}</p>
          </div>

          <div className="why-card">
            <div className="why-icon">💬</div>
            <h3>{t.whySahla.card3Title}</h3>
            <p>{t.whySahla.card3Desc}</p>
          </div>
        </div>
      </section>

      {/* ----------------------------------------
          HOW IT WORKS (3 STEPS)
          ---------------------------------------- */}
      <section className="how-section" id="how-it-works">
        <div className="section-head-center">
          <span className="section-eyebrow">{t.howItWorks.eyebrow}</span>
          <h2 className="section-main-title">{t.howItWorks.title}</h2>
        </div>

        <div className="steps-grid">
          <div className="step-card">
            <div className="step-badge">1</div>
            <h3>{t.howItWorks.step1Title}</h3>
            <p>{t.howItWorks.step1Desc}</p>
          </div>

          <div className="step-card">
            <div className="step-badge">2</div>
            <h3>{t.howItWorks.step2Title}</h3>
            <p>{t.howItWorks.step2Desc}</p>
          </div>

          <div className="step-card">
            <div className="step-badge">3</div>
            <h3>{t.howItWorks.step3Title}</h3>
            <p>{t.howItWorks.step3Desc}</p>
          </div>
        </div>
      </section>

      {/* ----------------------------------------
          PARTNERS & RECRUITMENT
          ---------------------------------------- */}
      <section className="partners-section" id="partners">
        <div className="partners-grid">
          {/* Restaurant Partner */}
          <div className="partner-card">
            <div className="partner-card-pattern" />
            <div className="partner-card-head">
              <span className="partner-pill">{t.partners.restaurantPill}</span>
              <h3>{t.partners.restaurantTitle}</h3>
              <p>{t.partners.restaurantDesc}</p>
            </div>
            <a
              href="mailto:partner@sahla-delivery.com?subject=Restaurant%20Partnership"
              className="partner-btn"
            >
              <span>{t.partners.restaurantBtn}</span>
              <span aria-hidden="true">{isRtl ? '←' : '→'}</span>
            </a>
          </div>

          {/* Delivery Driver */}
          <div className="partner-card partner-card-driver">
            <div className="partner-card-pattern" />
            <div className="partner-card-head">
              <span className="partner-pill">{t.partners.driverPill}</span>
              <h3>{t.partners.driverTitle}</h3>
              <p>{t.partners.driverDesc}</p>
            </div>
            <a
              href="mailto:careers@sahla-delivery.com?subject=Delivery%20Courier%20Application"
              className="partner-btn"
            >
              <span>{t.partners.driverBtn}</span>
              <span aria-hidden="true">{isRtl ? '←' : '→'}</span>
            </a>
          </div>
        </div>
      </section>

      {/* ----------------------------------------
          UNIFIED ORANGE SECTION (DOWNLOAD CTA + SOCIAL + CONTACT + LEGAL)
          ---------------------------------------- */}
      <footer className="unified-orange-footer" id="contact">
        <div className="unified-footer-container" id="download-cta">
          {/* Main Download CTA Heading & Subtitle */}
          <div className="footer-cta-header">
            <h2 className="footer-cta-title">{t.download.title}</h2>
            <p className="footer-cta-desc">{t.download.desc}</p>
          </div>

          {/* Follow Us On Social Media (Moved ABOVE Google Play / App Store) */}
          <div className="footer-social-wrap">
            <span className="footer-social-title">{t.contact.socialTitle}</span>
            <div className="footer-social-bar">
              {/* Instagram */}
              <a
                href={INSTAGRAM_URL}
                target="_blank"
                rel="noreferrer"
                className="social-btn social-btn-instagram"
                aria-label="Instagram @sahla.algerie"
                title="Instagram"
              >
                <svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor">
                  <path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073zm0 5.838c-3.403 0-6.162 2.759-6.162 6.162s2.759 6.163 6.162 6.163 6.162-2.759 6.162-6.163c0-3.403-2.759-6.162-6.162-6.162zm0 10.162c-2.209 0-4-1.79-4-4 0-2.209 1.791-4 4-4s4 1.791 4 4c0 2.21-1.791 4-4 4zm6.406-11.845c-.796 0-1.441.645-1.441 1.44s.645 1.44 1.441 1.44c.795 0 1.439-.645 1.439-1.44s-.644-1.44-1.439-1.44z" />
                </svg>
              </a>

              {/* Facebook */}
              <a
                href={FACEBOOK_URL}
                target="_blank"
                rel="noreferrer"
                className="social-btn social-btn-facebook"
                aria-label="Facebook Sahla"
                title="Facebook"
              >
                <svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor">
                  <path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z" />
                </svg>
              </a>

              {/* TikTok */}
              <a
                href={TIKTOK_URL}
                target="_blank"
                rel="noreferrer"
                className="social-btn social-btn-tiktok"
                aria-label="TikTok @sahla.algerie"
                title="TikTok"
              >
                <svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor">
                  <path d="M19.59 6.69a4.83 4.83 0 0 1-3.77-4.25V2h-3.45v13.67a2.89 2.89 0 0 1-5.2 1.74 2.89 2.89 0 0 1 2.31-4.64 2.93 2.93 0 0 1 .88.13V9.4a6.84 6.84 0 0 0-1-.05A6.33 6.33 0 0 0 3 15.68 6.34 6.34 0 0 0 9.35 22a6.33 6.33 0 0 0 6.33-6.32V9.38a8.16 8.16 0 0 0 4.91 1.63V7.55a4.8 4.8 0 0 1-1-.86z" />
                </svg>
              </a>

              {/* WhatsApp */}
              <a
                href={WHATSAPP_URL}
                target="_blank"
                rel="noreferrer"
                className="social-btn social-btn-whatsapp"
                aria-label="WhatsApp Sahla"
                title="WhatsApp"
              >
                <svg viewBox="0 0 24 24" width="20" height="20" fill="currentColor">
                  <path d="M.057 24l1.687-6.163c-1.041-1.804-1.588-3.849-1.587-5.946.003-6.556 5.338-11.891 11.893-11.891 3.181.001 6.167 1.24 8.413 3.488 2.245 2.248 3.481 5.236 3.48 8.414-.003 6.557-5.338 11.892-11.893 11.892-1.99-.001-3.951-.5-5.688-1.448l-6.305 1.654zm6.597-3.807c1.676.995 3.276 1.591 5.392 1.592 5.448 0 9.886-4.434 9.889-9.885.002-5.462-4.415-9.89-9.881-9.892-5.452 0-9.887 4.434-9.889 9.884-.001 2.225.651 3.891 1.746 5.634l-.999 3.648 3.742-.981zm11.387-5.464c-.074-.124-.272-.198-.57-.347-.297-.149-1.758-.868-2.031-.967-.272-.099-.47-.149-.669.149-.198.297-.768.967-.941 1.165-.173.198-.347.223-.644.074-.297-.149-1.255-.462-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.297-.347.446-.521.151-.172.2-.296.3-.495.099-.198.05-.372-.025-.521-.075-.148-.669-1.611-.916-2.206-.242-.579-.487-.501-.669-.51l-.57-.01c-.198 0-.52.074-.792.372s-1.04 1.016-1.04 2.479 1.065 2.876 1.213 3.074c.149.198 2.095 3.2 5.076 4.487.709.306 1.263.489 1.694.626.712.226 1.36.194 1.872.118.571-.085 1.758-.719 2.006-1.413.248-.695.248-1.29.173-1.414z" />
                </svg>
              </a>
            </div>
          </div>

          {/* Store Download Buttons (Google Play & App Store) */}
          <div className="hero-download-group footer-download-group">
            <button
              type="button"
              onClick={() => setShowAppStoreModal(true)}
              className="store-btn store-btn-appstore"
              aria-label="Download on App Store (Updating)"
              dir="ltr"
            >
              <span className="store-badge-tempo">{t.iosAnnouncement.badgeText}</span>
              <svg className="store-btn-icon" viewBox="0 0 24 24" fill="currentColor">
                <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 6.85c.67-.82 1.13-1.96 1.01-3.1-.98.04-2.17.65-2.87 1.47-.62.72-1.16 1.88-1.01 2.99 1.1.09 2.2-.54 2.87-1.36z" />
              </svg>
              <div className="store-btn-meta" dir="ltr">
                <span className="store-btn-label">Download on</span>
                <span className="store-btn-name">App Store</span>
              </div>
            </button>

            <a
              href={GOOGLE_PLAY_URL}
              target="_blank"
              rel="noreferrer"
              className="store-btn store-btn-google"
              aria-label="Get it on Google Play"
              dir="ltr"
            >
              <svg className="store-btn-icon" viewBox="0 0 24 24" fill="currentColor">
                <path d="M3,20.5V3.5C3,2.91 3.34,2.39 3.84,2.15L13.69,12L3.84,21.85C3.34,21.6 3,21.09 3,20.5M16.81,15.12L6.05,21.34L14.54,12.85L16.81,15.12M20.16,10.81C20.5,11.08 20.75,11.5 20.75,12C20.75,12.5 20.53,12.9 20.18,13.18L17.89,14.5L15.39,12L17.89,9.5L20.16,10.81M6.05,2.66L16.81,8.88L14.54,11.15L6.05,2.66Z" />
              </svg>
              <div className="store-btn-meta" dir="ltr">
                <span className="store-btn-label">Get it on</span>
                <span className="store-btn-name">Google Play</span>
              </div>
            </a>
          </div>

          {/* Elegant Subtle Divider */}
          <div className="unified-footer-divider" />

          {/* Contact Pills & Legal Links */}
          <div className="footer-secondary-bar">
            {/* Direct Contact Pills */}
            <div className="footer-contact-pills">
              <a href={`tel:${PHONE_NUMBER}`} className="footer-pill-btn" title={t.contact.callUs}>
                <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
                  <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z" />
                </svg>
                <span dir="ltr">{PHONE_DISPLAY}</span>
              </a>

              <a
                href={WHATSAPP_URL}
                target="_blank"
                rel="noreferrer"
                className="footer-pill-btn footer-pill-whatsapp"
                title={t.contact.chatWhatsapp}
              >
                <svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor">
                  <path d="M.057 24l1.687-6.163c-1.041-1.804-1.588-3.849-1.587-5.946.003-6.556 5.338-11.891 11.893-11.891 3.181.001 6.167 1.24 8.413 3.488 2.245 2.248 3.481 5.236 3.48 8.414-.003 6.557-5.338 11.892-11.893 11.892-1.99-.001-3.951-.5-5.688-1.448l-6.305 1.654zm6.597-3.807c1.676.995 3.276 1.591 5.392 1.592 5.448 0 9.886-4.434 9.889-9.885.002-5.462-4.415-9.89-9.881-9.892-5.452 0-9.887 4.434-9.889 9.884-.001 2.225.651 3.891 1.746 5.634l-.999 3.648 3.742-.981zm11.387-5.464c-.074-.124-.272-.198-.57-.347-.297-.149-1.758-.868-2.031-.967-.272-.099-.47-.149-.669.149-.198.297-.768.967-.941 1.165-.173.198-.347.223-.644.074-.297-.149-1.255-.462-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.297-.347.446-.521.151-.172.2-.296.3-.495.099-.198.05-.372-.025-.521-.075-.148-.669-1.611-.916-2.206-.242-.579-.487-.501-.669-.51l-.57-.01c-.198 0-.52.074-.792.372s-1.04 1.016-1.04 2.479 1.065 2.876 1.213 3.074c.149.198 2.095 3.2 5.076 4.487.709.306 1.263.489 1.694.626.712.226 1.36.194 1.872.118.571-.085 1.758-.719 2.006-1.413.248-.695.248-1.29.173-1.414z" />
                </svg>
                <span>{t.contact.whatsapp}</span>
              </a>
            </div>

            {/* Legal Links */}
            <div className="footer-legal-links">
              <Link href="/privacy">{t.footer.privacy}</Link>
              <span className="footer-legal-dot">•</span>
              <Link href="/terms">{t.footer.terms}</Link>
              <span className="footer-legal-dot">•</span>
              <Link href="/delete-account">{t.footer.deleteAccount}</Link>
            </div>
          </div>

          {/* Bottom Bar: Copyright & Language Switcher */}
          <div className="footer-bottom-bar">
            <p className="footer-copyright-text">{t.footer.copyright}</p>
            <div className="lang-segmented-control footer-lang-control" role="group" aria-label="Footer Language Selector">
              <button
                type="button"
                className={`lang-segment-btn ${lang === 'ar' ? 'active' : ''}`}
                onClick={() => handleLanguageChange('ar')}
              >
                العربية
              </button>
              <button
                type="button"
                className={`lang-segment-btn ${lang === 'fr' ? 'active' : ''}`}
                onClick={() => handleLanguageChange('fr')}
              >
                Français
              </button>
              <button
                type="button"
                className={`lang-segment-btn ${lang === 'en' ? 'active' : ''}`}
                onClick={() => handleLanguageChange('en')}
              >
                English
              </button>
            </div>
          </div>
        </div>
      </footer>

      {/* ----------------------------------------
          FLOATING QUICK WHATSAPP CHAT BUTTON
          ---------------------------------------- */}
      <a
        href={WHATSAPP_URL}
        target="_blank"
        rel="noreferrer"
        className="floating-whatsapp-btn"
        aria-label={t.contact.chatWhatsapp}
        title={t.contact.chatWhatsapp}
      >
        <span className="floating-whatsapp-pulse" />
        <svg viewBox="0 0 24 24" width="28" height="28" fill="currentColor">
          <path d="M.057 24l1.687-6.163c-1.041-1.804-1.588-3.849-1.587-5.946.003-6.556 5.338-11.891 11.893-11.891 3.181.001 6.167 1.24 8.413 3.488 2.245 2.248 3.481 5.236 3.48 8.414-.003 6.557-5.338 11.892-11.893 11.892-1.99-.001-3.951-.5-5.688-1.448l-6.305 1.654zm6.597-3.807c1.676.995 3.276 1.591 5.392 1.592 5.448 0 9.886-4.434 9.889-9.885.002-5.462-4.415-9.89-9.881-9.892-5.452 0-9.887 4.434-9.889 9.884-.001 2.225.651 3.891 1.746 5.634l-.999 3.648 3.742-.981zm11.387-5.464c-.074-.124-.272-.198-.57-.347-.297-.149-1.758-.868-2.031-.967-.272-.099-.47-.149-.669.149-.198.297-.768.967-.941 1.165-.173.198-.347.223-.644.074-.297-.149-1.255-.462-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.297-.347.446-.521.151-.172.2-.296.3-.495.099-.198.05-.372-.025-.521-.075-.148-.669-1.611-.916-2.206-.242-.579-.487-.501-.669-.51l-.57-.01c-.198 0-.52.074-.792.372s-1.04 1.016-1.04 2.479 1.065 2.876 1.213 3.074c.149.198 2.095 3.2 5.076 4.487.709.306 1.263.489 1.694.626.712.226 1.36.194 1.872.118.571-.085 1.758-.719 2.006-1.413.248-.695.248-1.29.173-1.414z" />
        </svg>
        <span className="floating-whatsapp-tooltip">{t.contact.chatWhatsapp}</span>
      </a>

      {/* ----------------------------------------
          IOS APP STORE TEMPORARY NOTICE MODAL
          ---------------------------------------- */}
      {showAppStoreModal && (
        <div
          className="ios-modal-backdrop"
          role="dialog"
          aria-modal="true"
          onClick={() => setShowAppStoreModal(false)}
        >
          <div
            className="ios-modal-card"
            onClick={(e) => e.stopPropagation()}
            dir={isRtl ? 'rtl' : 'ltr'}
          >
            <div className="ios-modal-icon-wrap">
              <span className="ios-modal-icon">🍎</span>
              <span className="ios-modal-subicon">⏳</span>
            </div>

            <h3 className="ios-modal-title">{t.iosAnnouncement.modalTitle}</h3>
            <p className="ios-modal-desc">{t.iosAnnouncement.modalDesc}</p>

            <div className="ios-modal-highlight-box">
              <span className="ios-highlight-star">✨</span>
              <p>{t.iosAnnouncement.modalHighlight}</p>
            </div>

            <div className="ios-modal-buttons">
              <a
                href="#services"
                className="ios-modal-primary-btn"
                onClick={() => setShowAppStoreModal(false)}
              >
                <span>{t.iosAnnouncement.modalWebCta}</span>
                <span aria-hidden="true">{isRtl ? '←' : '→'}</span>
              </a>

              <a
                href={WHATSAPP_URL}
                target="_blank"
                rel="noreferrer"
                className="ios-modal-secondary-btn"
              >
                <span>{t.iosAnnouncement.modalWhatsappCta}</span>
              </a>

              <button
                type="button"
                className="ios-modal-close-link"
                onClick={() => setShowAppStoreModal(false)}
              >
                {t.iosAnnouncement.modalClose}
              </button>
            </div>
          </div>
        </div>
      )}

      {/* ----------------------------------------
          MOBILE APP EXPERIENCE DOCK (BOTTOM BAR)
          ---------------------------------------- */}
      <nav className="app-mobile-bottom-dock" aria-label="App Navigation">
        <a href="#services" className="app-dock-item active">
          <span className="app-dock-icon">🏠</span>
          <span className="app-dock-label">{t.restaurants.bottomNavHome}</span>
        </a>

        <a href="#services" className="app-dock-item">
          <span className="app-dock-icon">📋</span>
          <span className="app-dock-label">{t.restaurants.bottomNavOrders}</span>
        </a>

        <a
          href={WHATSAPP_URL}
          target="_blank"
          rel="noreferrer"
          className="app-dock-item"
        >
          <span className="app-dock-icon">🎧</span>
          <span className="app-dock-label">{t.restaurants.bottomNavHelp}</span>
        </a>
      </nav>
    </main>
  );
}
