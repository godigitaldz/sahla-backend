'use client';

import React, { useState, useEffect, useRef } from 'react';
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
  tagAr: string;
  tagFr: string;
  tagEn: string;
  rating: number;
  deliveryTime: string;
  deliveryTimeEn: string;
  logo: string;
  cover: string;
  slug: string | null;
}

const FEATURED_RESTAURANTS: RestaurantItem[] = [
  {
    id: 'brothers-food',
    name: 'Brothers Food',
    tagAr: 'برغر • طاكوس • بيتزا • ملفوف',
    tagFr: 'Burgers • Tacos • Pizzas • Malfouf',
    tagEn: 'Burgers • Tacos • Pizza • Malfouf',
    rating: 4.9,
    deliveryTime: '30-45 دقيقة',
    deliveryTimeEn: '30-45 min',
    logo: 'https://pub-e75807f307834b89a8e0a2463ebb914f.r2.dev/brothers%20food.jpg',
    cover: 'https://pub-011aba279eb84591b0d96b9b9415ce2e.r2.dev/brothera%20food.jpg',
    slug: 'brothers-food',
  },
  {
    id: 'mr-burger',
    name: 'Mr Burger',
    tagAr: 'برغر وسريع • مطلوع تونيزيا',
    tagFr: 'Burgers & Fast Food',
    tagEn: 'Burgers & Fast Food',
    rating: 4.9,
    deliveryTime: '30-45 دقيقة',
    deliveryTimeEn: '30-45 min',
    logo: 'https://pub-e75807f307834b89a8e0a2463ebb914f.r2.dev/mr%20burger.jpg',
    cover: 'https://pub-011aba279eb84591b0d96b9b9415ce2e.r2.dev/mr%20burger.jpg',
    slug: 'mr-burger',
  },
  {
    id: 'cleopatra-food',
    name: 'Cleopatra Food',
    tagAr: 'برغر شيكن • تاكوس بيراميد',
    tagFr: 'Poulet & Spécialités',
    tagEn: 'Crispy Chicken & Tacos',
    rating: 4.7,
    deliveryTime: '30-45 دقيقة',
    deliveryTimeEn: '30-45 min',
    logo: 'https://pub-e75807f307834b89a8e0a2463ebb914f.r2.dev/cleobatra.jpg',
    cover: 'https://pub-011aba279eb84591b0d96b9b9415ce2e.r2.dev/cleopatrea.jpg',
    slug: 'cleopatra-food',
  },
  {
    id: 'chees-up',
    name: 'Chees-Up',
    tagAr: 'برغر الجبن الذائب • كريسبي',
    tagFr: 'Burgers Gourmet au Fromage',
    tagEn: 'Melty Cheese Burgers',
    rating: 5.0,
    deliveryTime: '30-45 دقيقة',
    deliveryTimeEn: '30-45 min',
    logo: 'https://pub-e75807f307834b89a8e0a2463ebb914f.r2.dev/Chees-Up.jpg',
    cover: 'https://pub-011aba279eb84591b0d96b9b9415ce2e.r2.dev/Cheeseup.jpg',
    slug: 'chees-up',
  },
  {
    id: 'dar-djeddi',
    name: 'دار جدي للمأكولات التقليدية',
    tagAr: 'طواجن جزائرية • شخشوخة ومشاوي',
    tagFr: 'Plats Traditionnels Algériens',
    tagEn: 'Traditional Algerian Dishes',
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
    tagAr: 'بيتزا إيطالية • غراتان وباستا',
    tagFr: 'Pizzas & Saveurs Italiennes',
    tagEn: 'Italian Pizza & Pasta',
    rating: 5.0,
    deliveryTime: '30-45 دقيقة',
    deliveryTimeEn: '30-45 min',
    logo: 'https://pub-e75807f307834b89a8e0a2463ebb914f.r2.dev/SAVINI%2007.jpg',
    cover: 'https://pub-011aba279eb84591b0d96b9b9415ce2e.r2.dev/savini.png',
    slug: 'savini-07',
  },
  {
    id: 'unlock-food',
    name: 'Unlock Food',
    tagAr: 'بوكسات عائلية • كريسبي وبرغر',
    tagFr: 'Family Boxes & Crispy',
    tagEn: 'Family Boxes & Crispy',
    rating: 4.8,
    deliveryTime: '30-45 دقيقة',
    deliveryTimeEn: '30-45 min',
    logo: 'https://pub-e75807f307834b89a8e0a2463ebb914f.r2.dev/unlock.jpg',
    cover: 'https://pub-011aba279eb84591b0d96b9b9415ce2e.r2.dev/unlock.jpg',
    slug: 'unlock-food',
  },
  {
    id: 'diety-food-biskra',
    name: 'Diety Food Biskra',
    tagAr: 'أكل صحي • وجبات دايت وسلطات',
    tagFr: 'Healthy & Diet Food',
    tagEn: 'Healthy & Diet Meals',
    rating: 5.0,
    deliveryTime: '30-45 دقيقة',
    deliveryTimeEn: '30-45 min',
    logo: 'https://pub-e75807f307834b89a8e0a2463ebb914f.r2.dev/Diety%20Food%20Biskra.jpg',
    cover: 'https://pub-011aba279eb84591b0d96b9b9415ce2e.r2.dev/diety.png',
    slug: 'diety-food-biskra',
  },
  {
    id: 'seven-eleven',
    name: 'Seven Eleven',
    tagAr: 'بيتزا بولي • كالزون وشاورما',
    tagFr: 'Pizzas, Calzone & Shawarma',
    tagEn: 'Pizza, Calzone & Shawarma',
    rating: 5.0,
    deliveryTime: '30-45 دقيقة',
    deliveryTimeEn: '30-45 min',
    logo: 'https://pub-e75807f307834b89a8e0a2463ebb914f.r2.dev/Seven%20Eleven.jpg',
    cover: 'https://pub-e75807f307834b89a8e0a2463ebb914f.r2.dev/Seven%20Eleven.jpg',
    slug: null,
  },
  {
    id: 'islam-diet',
    name: 'Islam Diet',
    tagAr: 'شاورما صحي • وجبات رياضيين',
    tagFr: 'Fitness & Healthy Diet',
    tagEn: 'Fitness & Diet Shawarma',
    rating: 5.0,
    deliveryTime: '30-45 دقيقة',
    deliveryTimeEn: '30-45 min',
    logo: 'https://pub-e75807f307834b89a8e0a2463ebb914f.r2.dev/islam%20diet.jpg',
    cover: 'https://pub-011aba279eb84591b0d96b9b9415ce2e.r2.dev/islam%20diet.png',
    slug: 'islam-diet',
  },
  {
    id: 'morphine-food',
    name: 'Morphine Food',
    tagAr: 'وجبات سريعة • سندويتشات مشكلة',
    tagFr: 'Fast Food & Sandwiches',
    tagEn: 'Fast Food & Sandwiches',
    rating: 5.0,
    deliveryTime: '30-45 دقيقة',
    deliveryTimeEn: '30-45 min',
    logo: 'https://pub-e75807f307834b89a8e0a2463ebb914f.r2.dev/Morphine.jpg',
    cover: 'https://pub-011aba279eb84591b0d96b9b9415ce2e.r2.dev/Morphine.jpg',
    slug: 'morphine-food',
  },
  {
    id: 'daily-dose',
    name: 'Daily Dose',
    tagAr: 'قهوة مختصة • حلويات ومشروبات',
    tagFr: 'Café & Desserts',
    tagEn: 'Specialty Coffee & Desserts',
    rating: 4.9,
    deliveryTime: '30-45 دقيقة',
    deliveryTimeEn: '30-45 min',
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
      eyebrow: 'شركاؤنا المميزون',
      title: 'أفضل وأشهر مطاعم مدينتك في مكان واحد',
      lead: 'اسحب وتصفح أشهر المطاعم المعتمدة والشريكة مع ساهلة. اطلب وجبتك المفضلة لتصلك ساخنة وطازجة لباب دارك.',
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
      desc: 'انضم إلى مئات المستخدمين الذين يستمتعون بأشهى المأكولات وأسرع توصيل في مدينتهم. متوفر مجاناً على iOS و Android.',
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
      eyebrow: 'Nos Partenaires d’Excellence',
      title: 'Les Meilleurs Restaurants de Votre Ville',
      lead: 'Faites défiler et découvrez les établissements partenaires officiels. Commandez vos repas préférés livrés chez vous.',
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
      eyebrow: 'Featured Partner Restaurants',
      title: 'Top Rated Eateries in Your City',
      lead: 'Swipe and browse popular verified partner eateries on Sahla. Order your favorite meals delivered fresh to your door.',
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
      desc: 'Join hundreds enjoying the easiest and fastest food delivery in Algeria. Available free for iOS and Android.',
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
  },
};

export default function HomePage() {
  const [lang, setLang] = useState<Language>('ar');
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    const saved = localStorage.getItem('sahla_user_lang') as Language;
    if (saved && (saved === 'ar' || saved === 'fr' || saved === 'en')) {
      setLang(saved);
    }
  }, []);

  const handleLanguageChange = (newLang: Language) => {
    setLang(newLang);
    localStorage.setItem('sahla_user_lang', newLang);
  };

  const scrollCarousel = (direction: 'left' | 'right') => {
    if (scrollRef.current) {
      const scrollAmount = direction === 'left' ? -310 : 310;
      scrollRef.current.scrollBy({ left: scrollAmount, behavior: 'smooth' });
    }
  };

  const t = CONTENT[lang];
  const isRtl = lang === 'ar';

  return (
    <main className="landing-page" dir={isRtl ? 'rtl' : 'ltr'}>
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
              {/* App Store Button */}
              <a
                href={APP_STORE_URL}
                target="_blank"
                rel="noreferrer"
                className="store-btn"
                aria-label="Download on App Store"
                dir="ltr"
              >
                <svg className="store-btn-icon" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 6.85c.67-.82 1.13-1.96 1.01-3.1-.98.04-2.17.65-2.87 1.47-.62.72-1.16 1.88-1.01 2.99 1.1.09 2.2-.54 2.87-1.36z" />
                </svg>
                <div className="store-btn-meta" dir="ltr">
                  <span className="store-btn-label">Download on</span>
                  <span className="store-btn-name">App Store</span>
                </div>
              </a>

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
          </div>
        </div>
      </section>

      {/* ----------------------------------------
          FEATURED PARTNER RESTAURANTS (HORIZONTAL SWIPE)
          ---------------------------------------- */}
      <section className="partners-showcase-section" id="services">
        <div className="partners-showcase-container">
          <div className="section-head-with-controls">
            <div className="section-head-text">
              <span className="section-eyebrow">{t.restaurants.eyebrow}</span>
              <h2 className="section-main-title">{t.restaurants.title}</h2>
              <p className="section-lead">{t.restaurants.lead}</p>
            </div>

            {/* Desktop Navigation Arrows */}
            <div className="carousel-nav-controls" aria-label="Carousel Navigation">
              <button
                type="button"
                className="carousel-nav-btn"
                onClick={() => scrollCarousel(isRtl ? 'right' : 'left')}
                aria-label="Previous"
                title="Previous"
              >
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                  <path d={isRtl ? "M9 18l6-6-6-6" : "M15 18l-6-6 6-6"} />
                </svg>
              </button>
              <button
                type="button"
                className="carousel-nav-btn"
                onClick={() => scrollCarousel(isRtl ? 'left' : 'right')}
                aria-label="Next"
                title="Next"
              >
                <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                  <path d={isRtl ? "M15 18l-6-6 6-6" : "M9 18l6-6-6-6"} />
                </svg>
              </button>
            </div>
          </div>

          {/* Horizontal Scroll / Swipe Track */}
          <div className="restaurants-swipe-wrapper">
            <div
              ref={scrollRef}
              className="restaurants-swipe-track"
              role="region"
              aria-label="Featured Restaurants"
            >
              {FEATURED_RESTAURANTS.map((resto) => {
                const tag = lang === 'ar' ? resto.tagAr : lang === 'fr' ? resto.tagFr : resto.tagEn;
                const time = lang === 'ar' ? resto.deliveryTime : resto.deliveryTimeEn;
                const linkHref = resto.slug ? `/restaurants/${resto.slug}` : '#download-app';

                return (
                  <div key={resto.id} className="restaurant-swipe-card">
                    {/* Cover Image */}
                    <div className="restaurant-card-cover">
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img
                        src={resto.cover}
                        alt={resto.name}
                        loading="lazy"
                        className="restaurant-cover-img"
                      />
                      <div className="restaurant-cover-overlay" />

                      {/* Time Badge */}
                      <div className="restaurant-badge-time">
                        <svg width="12" height="12" viewBox="0 0 24 24" fill="currentColor">
                          <path d="M13 2L3 14h9l-1 8 10-12h-9l1-8z" />
                        </svg>
                        <span>{time}</span>
                      </div>

                      {/* Rating Badge */}
                      <div className="restaurant-badge-rating">
                        <span className="rating-star">★</span>
                        <span>{resto.rating.toFixed(1)}</span>
                      </div>
                    </div>

                    {/* Overlapping Floating Logo */}
                    <div className="restaurant-logo-holder">
                      {/* eslint-disable-next-line @next/next/no-img-element */}
                      <img
                        src={resto.logo}
                        alt={`${resto.name} Logo`}
                        loading="lazy"
                        className="restaurant-logo-img"
                      />
                    </div>

                    {/* Card Body */}
                    <div className="restaurant-card-body">
                      <h3 className="restaurant-name">{resto.name}</h3>
                      <p className="restaurant-tags">{tag}</p>

                      <Link href={linkHref} className="restaurant-action-btn">
                        <span>{resto.slug ? t.restaurants.viewMenu : t.restaurants.openApp}</span>
                        <span aria-hidden="true">{isRtl ? '←' : '→'}</span>
                      </Link>
                    </div>
                  </div>
                );
              })}
            </div>
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
          DOWNLOAD CTA WITH SMART QR CODE
          ---------------------------------------- */}
      <section className="cta-download-section" id="download-cta">
        <div className="cta-container">
          <div className="cta-content">
            <span className="cta-badge">Sahla App</span>
            <h2 className="cta-title">{t.download.title}</h2>
            <p className="cta-desc">{t.download.desc}</p>

            <div className="hero-download-group">
              <a
                href={APP_STORE_URL}
                target="_blank"
                rel="noreferrer"
                className="store-btn"
                aria-label="Download on App Store"
                dir="ltr"
              >
                <svg className="store-btn-icon" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 6.85c.67-.82 1.13-1.96 1.01-3.1-.98.04-2.17.65-2.87 1.47-.62.72-1.16 1.88-1.01 2.99 1.1.09 2.2-.54 2.87-1.36z" />
                </svg>
                <div className="store-btn-meta" dir="ltr">
                  <span className="store-btn-label">Download on</span>
                  <span className="store-btn-name">App Store</span>
                </div>
              </a>

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
          </div>

          <div className="cta-qr-box">
            <div className="cta-qr-code">
              <svg viewBox="0 0 100 100" width="100%" height="100%">
                <rect width="100" height="100" fill="#FFFFFF" />
                {/* QR Outer Corners */}
                <rect x="10" y="10" width="24" height="24" rx="4" fill="#064E3B" />
                <rect x="14" y="14" width="16" height="16" rx="2" fill="#FFFFFF" />
                <rect x="18" y="18" width="8" height="8" rx="1" fill="#064E3B" />

                <rect x="66" y="10" width="24" height="24" rx="4" fill="#064E3B" />
                <rect x="70" y="14" width="16" height="16" rx="2" fill="#FFFFFF" />
                <rect x="74" y="18" width="8" height="8" rx="1" fill="#064E3B" />

                <rect x="10" y="66" width="24" height="24" rx="4" fill="#064E3B" />
                <rect x="14" y="70" width="16" height="16" rx="2" fill="#FFFFFF" />
                <rect x="18" y="74" width="8" height="8" rx="1" fill="#064E3B" />

                {/* Decorative QR Pattern Elements */}
                <rect x="42" y="14" width="6" height="18" rx="2" fill="#064E3B" />
                <rect x="52" y="10" width="6" height="8" rx="2" fill="#FFC700" />
                <rect x="14" y="42" width="18" height="6" rx="2" fill="#064E3B" />
                <rect x="10" y="52" width="8" height="6" rx="2" fill="#FFC700" />

                <rect x="40" y="40" width="20" height="20" rx="4" fill="#FFC700" />
                <circle cx="50" cy="50" r="5" fill="#064E3B" />

                <rect x="66" y="42" width="8" height="18" rx="2" fill="#064E3B" />
                <rect x="78" y="46" width="12" height="6" rx="2" fill="#064E3B" />
                <rect x="42" y="66" width="18" height="8" rx="2" fill="#064E3B" />
                <rect x="46" y="78" width="6" height="12" rx="2" fill="#064E3B" />
                <rect x="66" y="66" width="10" height="10" rx="2" fill="#FFC700" />
                <rect x="80" y="80" width="10" height="10" rx="2" fill="#064E3B" />
              </svg>
            </div>
            <span className="cta-qr-label">{t.download.scanText}</span>
          </div>
        </div>
      </section>

      {/* ----------------------------------------
          FOOTER WITH SOCIAL MEDIA & DIRECT CONTACT
          ---------------------------------------- */}
      <footer className="site-footer" id="contact">
        <div className="footer-top">
          {/* Brand Info & Social Media Links */}
          <div className="footer-brand">
            <Image
              src="/logo.webp"
              alt="Sahla Delivery"
              width={140}
              height={44}
              className="footer-logo-img"
            />
            <p>{t.footer.desc}</p>

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
          </div>

          {/* Quick Links Column */}
          <div className="footer-column">
            <h4>{t.footer.company}</h4>
            <ul className="footer-links-list">
              <li><a href="#services">{t.nav.services}</a></li>
              <li><a href="#why-sahla">{t.nav.whySahla}</a></li>
              <li><a href="#how-it-works">{t.nav.howItWorks}</a></li>
              <li><a href="#partners">{t.nav.partners}</a></li>
            </ul>
          </div>

          {/* Direct Contact Column (Call, WhatsApp, Email) */}
          <div className="footer-column footer-column-contact">
            <h4>{t.contact.title}</h4>
            <ul className="footer-links-list footer-contact-list">
              {/* Phone Call */}
              <li>
                <a href={`tel:${PHONE_NUMBER}`} className="footer-contact-item" title={t.contact.callUs}>
                  <div className="footer-contact-icon">
                    <svg viewBox="0 0 24 24" width="16" height="16" fill="none" stroke="currentColor" strokeWidth="2.2" strokeLinecap="round" strokeLinejoin="round">
                      <path d="M22 16.92v3a2 2 0 0 1-2.18 2 19.79 19.79 0 0 1-8.63-3.07 19.5 19.5 0 0 1-6-6 19.79 19.79 0 0 1-3.07-8.67A2 2 0 0 1 4.11 2h3a2 2 0 0 1 2 1.72 12.84 12.84 0 0 0 .7 2.81 2 2 0 0 1-.45 2.11L8.09 9.91a16 16 0 0 0 6 6l1.27-1.27a2 2 0 0 1 2.11-.45 12.84 12.84 0 0 0 2.81.7A2 2 0 0 1 22 16.92z" />
                    </svg>
                  </div>
                  <div className="footer-contact-meta">
                    <span className="footer-contact-label">{t.contact.phone}</span>
                    <span className="footer-contact-value" dir="ltr">{PHONE_DISPLAY}</span>
                  </div>
                </a>
              </li>

              {/* WhatsApp Direct */}
              <li>
                <a
                  href={WHATSAPP_URL}
                  target="_blank"
                  rel="noreferrer"
                  className="footer-contact-item footer-contact-whatsapp"
                  title={t.contact.chatWhatsapp}
                >
                  <div className="footer-contact-icon footer-whatsapp-icon">
                    <svg viewBox="0 0 24 24" width="16" height="16" fill="currentColor">
                      <path d="M.057 24l1.687-6.163c-1.041-1.804-1.588-3.849-1.587-5.946.003-6.556 5.338-11.891 11.893-11.891 3.181.001 6.167 1.24 8.413 3.488 2.245 2.248 3.481 5.236 3.48 8.414-.003 6.557-5.338 11.892-11.893 11.892-1.99-.001-3.951-.5-5.688-1.448l-6.305 1.654zm6.597-3.807c1.676.995 3.276 1.591 5.392 1.592 5.448 0 9.886-4.434 9.889-9.885.002-5.462-4.415-9.89-9.881-9.892-5.452 0-9.887 4.434-9.889 9.884-.001 2.225.651 3.891 1.746 5.634l-.999 3.648 3.742-.981zm11.387-5.464c-.074-.124-.272-.198-.57-.347-.297-.149-1.758-.868-2.031-.967-.272-.099-.47-.149-.669.149-.198.297-.768.967-.941 1.165-.173.198-.347.223-.644.074-.297-.149-1.255-.462-2.39-1.475-.883-.788-1.48-1.761-1.653-2.059-.173-.297-.018-.458.13-.606.134-.133.297-.347.446-.521.151-.172.2-.296.3-.495.099-.198.05-.372-.025-.521-.075-.148-.669-1.611-.916-2.206-.242-.579-.487-.501-.669-.51l-.57-.01c-.198 0-.52.074-.792.372s-1.04 1.016-1.04 2.479 1.065 2.876 1.213 3.074c.149.198 2.095 3.2 5.076 4.487.709.306 1.263.489 1.694.626.712.226 1.36.194 1.872.118.571-.085 1.758-.719 2.006-1.413.248-.695.248-1.29.173-1.414z" />
                    </svg>
                  </div>
                  <div className="footer-contact-meta">
                    <span className="footer-contact-label">{t.contact.whatsapp}</span>
                    <span className="footer-contact-value">wa.me/sahla</span>
                  </div>
                </a>
              </li>
            </ul>
          </div>

          {/* Legal Column */}
          <div className="footer-column">
            <h4>{t.footer.legal}</h4>
            <ul className="footer-links-list">
              <li><Link href="/privacy">{t.footer.privacy}</Link></li>
              <li><Link href="/terms">{t.footer.terms}</Link></li>
              <li><Link href="/delete-account">{t.footer.deleteAccount}</Link></li>
            </ul>
          </div>
        </div>

        <div className="footer-bottom">
          <p>{t.footer.copyright}</p>
          <div className="lang-segmented-control" role="group" aria-label="Footer Language Selector">
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
    </main>
  );
}
