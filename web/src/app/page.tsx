'use client';

import React, { useState, useEffect } from 'react';
import Image from 'next/image';
import Link from 'next/link';
import './landing.css';

const APP_STORE_URL = 'https://apps.apple.com/us/app/sahla-food-grocery/id6760480928';
const GOOGLE_PLAY_URL = 'https://play.google.com/store/apps/details?id=com.godigital.sahla&pcampaignid=web_share';

type Language = 'ar' | 'fr' | 'en';

const CONTENT = {
  ar: {
    nav: {
      services: 'خدماتنا',
      whySahla: 'علاش ساهلة؟',
      howItWorks: 'كيف تطلب',
      partners: 'انضم إلينا',
      download: 'حمّل التطبيق',
    },
    hero: {
      badge: 'تطبيق التوصيل الأول في مدينتك',
      title1: 'خليك مكانك...',
      titleHighlight: 'حنا نجيو لعندك!',
      subtitle:
        'أي وقت... أي مكان. كل ما تشتهي من أشهى المأكولات والمقاضي يوصلك سخون وسريع حتى لباب دارك مع ساهلة.',
      chipSpeed: '⚡ توصيل في أقل من 30 دقيقة',
      chipTracking: '📍 تتبع مسار طلبك لحظة بلحظة',
      chipQuality: '🍱 حقائب حرارية تحفظ حرارة الوجبة',
      downloadAppStore: 'تحميل من App Store',
      downloadGooglePlay: 'تحميل من Google Play',
      badgeTitle: 'تم التوصيل الآن بنجاح!',
      badgeSub: 'وجبة مشويات ساخنة • في 24 دقيقة',
    },
    services: {
      eyebrow: 'منظومة ساهلة المتكاملة',
      title: 'كل ما تحتاجه في تطبيق واحد',
      lead: 'سواء كنت جيعان وتستنى في وجبة شهية، محتاج مقاضي للدار، أو باغي ترسل طرد مستعجل، ساهلة هنا في خدمتك.',
      foodTitle: 'ساهلة فود (Food)',
      foodTag: '+150 مطعم ومحل',
      foodDesc:
        'أشهى الأطباق من أرقى المطاعم ومحلات الأكل السريع في مدينتك. برغر، بيتزا، طواجن وشعبيات توصلك بحرارتها وجودتها.',
      foodAction: 'استكشف المطاعم',
      marketTitle: 'ساهلة ماركت (Market)',
      marketTag: 'مقاضي وسوبرماركت',
      marketDesc:
        'خضار وفواكه طازجة، مقاضي البيت اليومية، حلويات ومشروبات توصلك في دقائق بلا ما تخرج من دارك وتضيع وقتك.',
      marketAction: 'تسوق الآن',
      ifriliTitle: 'ساهلة إفريلي (Ifrili)',
      ifriliTag: 'مشاوير وطرود خاصة',
      ifriliDesc:
        'خدمتك الشخصية للمشاوير الخاصة: اشريلي، جيبلي، ولا وصّل أماناتك وطرودك لأي عنوان في مدينتك بكل أمان وثقة.',
      ifriliAction: 'اطلب إفريلي',
    },
    showcase: {
      eyebrow: 'أي وقت.. أي مكان',
      title: 'تجربة طلب مصممة لراحتك التامة',
      lead: 'صممنا تطبيق ساهلة ليكون الأسهل والأسرع، ليمنحك تجربة خالية من التعقيد من أول ضغطة حتى استلام الوجبة.',
      f1Title: 'تصفح مرن وقوائم واضحة بالصور',
      f1Desc: 'اكتشف قوائم الطعام الكاملة مع الأسعار الحقيقية والعروض الحصرية بدون أي رسوم خفية.',
      f2Title: 'تخصيص كامل لوجبتك وملاحظاتك',
      f2Desc: 'اختر الإضافات، الأحجام، والملاحظات الخاصة التي تفضلها في كل وجبة لتصلك كما تحب تماماً.',
      f3Title: 'خريطة تتبع ذكية بنظام GPS مباشر',
      f3Desc: 'راقب تحركات الكابتن على الخريطة دقيقة بدقيقة من وقت خروجه من المطعم حتى وقوفه أمام بابك.',
      f4Title: 'دفع سهل عند الاستلام (كاش)',
      f4Desc: 'ادفع بأمان وراحة بال نقداً عند وصول طلبك واستلامك له باليد.',
    },
    whySahla: {
      eyebrow: 'لماذا يفضلنا الآلاف؟',
      title: 'مميزات تصنع الفارق في كل طلب',
      card1Title: 'سرعة توصيل قياسية',
      card1Desc: 'خوارزميات ذكية ترشح أقرب كابتن لك وللمطعم لتصلك الوجبة في أسرع وقت ممكن.',
      card2Title: 'حقائب عازلة متطورة',
      card2Desc: 'نستخدم حقائب حرارية معتمدة تضمن بقاء الطعام ساخناً وطازجاً كما أُعد في المطبخ.',
      card3Title: 'كباتن معتمدون وموثوقون',
      card3Desc: 'فريق توصيل محترف ومدرب يتمتع بأعلى معايير الأمانة واللباقة وسرعة الاستجابة.',
      card4Title: 'خدمة زبائن محلية متواصلة',
      card4Desc: 'فريق دعم محلي جزائري جاهز لمساعدتك وحل أي استفسار على مدار أيام الأسبوع.',
    },
    howItWorks: {
      eyebrow: 'بسيطة في 3 خطوات',
      title: 'كيف تطلب من ساهلة؟',
      step1Title: '1. اختر مطعمك المفضل',
      step1Desc: 'تصفح المطاعم ومحلات الأكل القريبة منك حسب نوع الأكل أو التقييمات.',
      step2Title: '2. حدد وجبتك وأكد الطلب',
      step2Desc: 'أضف ما تشتهيه إلى السلة وأكد طلبك بضغطة واحدة مع إضافة ملاحظاتك.',
      step3Title: '3. استلم واستمتع بأكلك سخون',
      step3Desc: 'تابع مسار الكابتن على الخريطة واستلم طلبك عند باب دارك بكل سهولة.',
    },
    partners: {
      restaurantPill: 'لأصحاب المطاعم والمتاجر',
      restaurantTitle: 'ضاعف مبيعاتك وانضم لشبكة شركاء ساهلة',
      restaurantDesc:
        'اربط مطعمك بآلاف الزبائن في مدينتك، حسّن مبيعاتك اليومية واستفد من أسطول توصيل محترف دون أي أعباء تشغيلية إضافية.',
      restaurantBtn: 'سجل مطعمك الآن',
      driverPill: 'للكباتن وعمال التوصيل',
      driverTitle: 'انضم لأسطول ساهلة وحقق دخلاً يومياً ممتازاً',
      driverDesc:
        'كن سيد نفسك مع أوقات عمل حرة ومرنة. اربح مع كل طلب توصله واستفد من دعم مستمر ومكافآت على مدار الشهر.',
      driverBtn: 'انضم ككابتن توصيل',
    },
    download: {
      title: 'جاهز للطلب؟ حمّل التطبيق الآن!',
      desc: 'انضم إلى آلاف المستخدمين الذين يستمتعون بأشهى المأكولات وأسرع توصيل في مدينتهم. متوفر مجاناً على iOS و Android.',
      scanText: 'امسح الكود بكاميرا هاتفك للتحميل المباشر',
    },
    footer: {
      desc: 'ساهلة — تطبيق التوصيل الجزائري الرائد للمأكولات، المقاضي والطرود. خليك مكانك.. حنا نجيو لعندك!',
      company: 'الشركة',
      services: 'الخدمات',
      legal: 'الشروط والسياسات',
      privacy: 'سياسة الخصوصية',
      terms: 'شروط الخدمة',
      deleteAccount: 'حذف الحساب',
      foodDelivery: 'توصيل المأكولات',
      groceryDelivery: 'توصيل المقاضي',
      ifriliService: 'خدمة إفريلي للطرود',
      contact: 'اتصل بنا',
      copyright: '© 2026 ساهلة (Sahla Delivery). جميع الحقوق محفوظة.',
    },
  },
  fr: {
    nav: {
      services: 'Services',
      whySahla: 'Pourquoi Sahla ?',
      howItWorks: 'Comment ça marche',
      partners: 'Partenaires',
      download: "Télécharger l'app",
    },
    hero: {
      badge: 'Votre application de livraison préférée',
      title1: 'Restez chez vous...',
      titleHighlight: 'On vient chez vous !',
      subtitle:
        'À tout moment, partout. Tous vos plats favoris et vos courses livrés chauds et rapides jusqu’à votre porte.',
      chipSpeed: '⚡ Livraison en moins de 30 min',
      chipTracking: '📍 Suivi GPS en temps réel',
      chipQuality: '🍱 Sacs thermiques isothermes',
      downloadAppStore: 'Sur App Store',
      downloadGooglePlay: 'Sur Google Play',
      badgeTitle: 'Commande livrée avec succès !',
      badgeSub: 'Grillades chaudes • en 24 minutes',
    },
    services: {
      eyebrow: 'L’écosystème Sahla',
      title: 'Tout ce dont vous avez besoin dans une seule app',
      lead: 'Envie d’un repas savoureux, besoin de courses urgentes ou d’expédier un colis ? Sahla s’occupe de tout.',
      foodTitle: 'Sahla Food',
      foodTag: '+150 restaurants',
      foodDesc:
        'Vos plats préférés des meilleurs restaurants de votre ville. Burgers, pizzas, plats traditionnels livrés chauds.',
      foodAction: 'Explorer les restos',
      marketTitle: 'Sahla Market',
      marketTag: 'Courses & Épicerie',
      marketDesc:
        'Fruits, légumes frais, produits du quotidien et supermarché livrés à domicile sans perdre de temps.',
      marketAction: 'Faire ses courses',
      ifriliTitle: 'Sahla Ifrili',
      ifriliTag: 'Courses & Colis express',
      ifriliDesc:
        'Votre assistant personnel pour vos courses privées et livraison de colis en toute sécurité.',
      ifriliAction: 'Commander Ifrili',
    },
    showcase: {
      eyebrow: 'N’importe où, n’importe quand',
      title: 'Une expérience conçue pour votre sérénité',
      lead: 'Sahla vous offre l’expérience de commande la plus fluide et rapide d’Algérie.',
      f1Title: 'Menus clairs avec photos et prix nets',
      f1Desc: 'Consultez les cartes détaillées sans frais cachés.',
      f2Title: 'Personnalisation totale de vos plats',
      f2Desc: 'Ajoutez vos sauces, suppléments et consignes de préparation.',
      f3Title: 'Suivi direct par GPS en temps réel',
      f3Desc: 'Observez la progression du livreur jusqu’à votre porte.',
      f4Title: 'Paiement sécurisé en espèces à la livraison',
      f4Desc: 'Réglez en toute confiance à la réception de votre repas.',
    },
    whySahla: {
      eyebrow: 'Pourquoi nous choisir ?',
      title: 'Une qualité de service irréprochable',
      card1Title: 'Vitesse de livraison record',
      card1Desc: 'Des algorithmes qui sélectionnent le livreur idéal pour chaque course.',
      card2Title: 'Sacs isothermes haute isolation',
      card2Desc: 'Vos repas restent brûlants et croustillants comme à la sortie des cuisines.',
      card3Title: 'Livreurs formés et vérifiés',
      card3Desc: 'Une équipe dévouée, polie et respectueuse des délais.',
      card4Title: 'Service client local 7j/7',
      card4Desc: 'Une assistance réactive basée en Algérie prête à vous répondre.',
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
      restaurantTitle: 'Boostez vos ventes avec le réseau Sahla',
      restaurantDesc:
        'Touchez des milliers de nouveaux clients et confiez vos livraisons à une flotte professionnelle clé en main.',
      restaurantBtn: 'Devenir partenaire',
      driverPill: 'Pour les livreurs',
      driverTitle: 'Rejoignez la flotte Sahla avec des revenus attractifs',
      driverDesc:
        'Travaillez en toute liberté d’horaires avec des gains quotidiens et des primes régulières.',
      driverBtn: 'Devenir livreur',
    },
    download: {
      title: 'Prêt à commander ? Téléchargez l’application !',
      desc: 'Disponible gratuitement sur iPhone et Android. Rejoignez des milliers d’utilisateurs conquis.',
      scanText: 'Scannez le QR code avec votre téléphone pour installer l’app',
    },
    footer: {
      desc: 'Sahla — L’application algérienne de référence pour la livraison de repas, courses et colis.',
      company: 'Entreprise',
      services: 'Services',
      legal: 'Légal',
      privacy: 'Politique de confidentialité',
      terms: 'Conditions d’utilisation',
      deleteAccount: 'Supprimer mon compte',
      foodDelivery: 'Livraison de repas',
      groceryDelivery: 'Livraison de courses',
      ifriliService: 'Service colis Ifrili',
      contact: 'Contactez-nous',
      copyright: '© 2026 Sahla Delivery. Tous droits réservés.',
    },
  },
  en: {
    nav: {
      services: 'Services',
      whySahla: 'Why Sahla?',
      howItWorks: 'How It Works',
      partners: 'Partners',
      download: 'Download App',
    },
    hero: {
      badge: '#1 Delivery App in Your City',
      title1: 'Stay where you are...',
      titleHighlight: 'We deliver to you!',
      subtitle:
        'Any time, any place. Your favorite meals, groceries, and parcels delivered piping hot and fast to your doorstep.',
      chipSpeed: '⚡ Under 30-min fast delivery',
      chipTracking: '📍 Live GPS order tracking',
      chipQuality: '🍱 Heat-insulated thermal bags',
      downloadAppStore: 'Download on App Store',
      downloadGooglePlay: 'Get it on Google Play',
      badgeTitle: 'Order Delivered Successfully!',
      badgeSub: 'Hot grilled skewers • in 24 mins',
    },
    services: {
      eyebrow: 'Integrated Sahla Ecosystem',
      title: 'Everything You Need in One Single App',
      lead: 'Whether you crave a delicious hot meal, need daily household groceries, or want to send an urgent parcel, Sahla is at your service.',
      foodTitle: 'Sahla Food',
      foodTag: '150+ Restaurants',
      foodDesc:
        'Delicious meals from the best local restaurants and burger joints delivered warm and fresh.',
      foodAction: 'Explore Food',
      marketTitle: 'Sahla Market',
      marketTag: 'Groceries & Essentials',
      marketDesc:
        'Fresh fruits, veggies, supermarket essentials, and daily groceries delivered in minutes.',
      marketAction: 'Shop Groceries',
      ifriliTitle: 'Sahla Ifrili',
      ifriliTag: 'Custom Errands & Parcels',
      ifriliDesc:
        'Your personal courier errand service: send packages, pick up forgotten items, or run custom tasks.',
      ifriliAction: 'Order Ifrili',
    },
    showcase: {
      eyebrow: 'Any Time.. Any Place',
      title: 'An Experience Crafted for Your Utmost Comfort',
      lead: 'We built Sahla to be fast, intuitive, and hassle-free from your first tap until the meal arrives.',
      f1Title: 'Clear menus with photos and transparent prices',
      f1Desc: 'Explore complete menus with accurate pricing and exclusive promotions with zero hidden fees.',
      f2Title: 'Full meal customization & order notes',
      f2Desc: 'Add toppings, pick sides, and leave specific kitchen instructions for the chef.',
      f3Title: 'Smart live GPS map tracking',
      f3Desc: 'Follow your delivery courier on the map from kitchen pickup right to your doorstep.',
      f4Title: 'Convenient Cash on Delivery',
      f4Desc: 'Pay safely in cash when your order is delivered into your hands.',
    },
    whySahla: {
      eyebrow: 'Why Thousands Choose Us',
      title: 'Distinct Quality in Every Single Order',
      card1Title: 'Record-Breaking Speed',
      card1Desc: 'Smart dispatch matching that picks the optimal driver for lightning-fast arrival.',
      card2Title: 'Advanced Insulated Bags',
      card2Desc: 'Custom thermal bags ensure your food stays steaming hot and fresh.',
      card3Title: 'Trusted & Verified Couriers',
      card3Desc: 'Professional couriers trained for utmost courtesy, care, and speed.',
      card4Title: 'Dedicated Local Customer Support',
      card4Desc: 'Algerian support team ready to assist you seven days a week.',
    },
    howItWorks: {
      eyebrow: 'Simple in 3 Steps',
      title: 'How to Order with Sahla',
      step1Title: '1. Pick Your Restaurant',
      step1Desc: 'Browse top rated eateries, trending spots, and local favorites nearby.',
      step2Title: '2. Customize & Confirm',
      step2Desc: 'Select your meals, add special requests, and confirm with one tap.',
      step3Title: '3. Receive & Enjoy',
      step3Desc: 'Track your delivery in real-time and enjoy a warm, satisfying meal at home.',
    },
    partners: {
      restaurantPill: 'For Restaurant Owners',
      restaurantTitle: 'Scale Your Restaurant with Sahla',
      restaurantDesc:
        'Connect with thousands of local diners, grow revenue, and rely on an automated delivery fleet.',
      restaurantBtn: 'Partner With Us',
      driverPill: 'For Couriers & Drivers',
      driverTitle: 'Join the Sahla Fleet & Earn Great Daily Income',
      driverDesc:
        'Enjoy flexible working hours, competitive per-delivery earnings, and weekly bonus incentives.',
      driverBtn: 'Become a Driver',
    },
    download: {
      title: 'Ready to order? Get the Sahla app now!',
      desc: 'Join thousands enjoying the easiest and fastest delivery in Algeria. Available free for iOS and Android.',
      scanText: 'Scan this QR code with your phone camera to download directly',
    },
    footer: {
      desc: 'Sahla — Algeria’s leading food, grocery, and on-demand delivery app. Stay where you are, we come to you!',
      company: 'Company',
      services: 'Services',
      legal: 'Legal',
      privacy: 'Privacy Policy',
      terms: 'Terms of Service',
      deleteAccount: 'Delete Account',
      foodDelivery: 'Food Delivery',
      groceryDelivery: 'Grocery Delivery',
      ifriliService: 'Ifrili Parcel Service',
      contact: 'Contact Us',
      copyright: '© 2026 Sahla Delivery. All rights reserved.',
    },
  },
};

export default function HomePage() {
  const [lang, setLang] = useState<Language>('ar');

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

  const t = CONTENT[lang];
  const isRtl = lang === 'ar';

  return (
    <main className="landing-page" dir={isRtl ? 'rtl' : 'ltr'}>
      {/* ----------------------------------------
          HEADER / NAVBAR
          ---------------------------------------- */}
      <header className="site-header">
        <div className="header-container">
          <Link href="/" className="brand-logo-link" aria-label="Sahla Home">
            <Image
              src="/logo.webp"
              alt="Sahla Delivery"
              width={140}
              height={44}
              priority
              className="header-logo-img"
            />
          </Link>

          <nav className="header-nav" aria-label="Main Navigation">
            <a href="#services">{t.nav.services}</a>
            <a href="#why-sahla">{t.nav.whySahla}</a>
            <a href="#how-it-works">{t.nav.howItWorks}</a>
            <a href="#partners">{t.nav.partners}</a>
          </nav>

          <div className="header-actions">
            {/* Language Switcher */}
            <div className="lang-switcher-group" style={{ display: 'flex', gap: '4px' }}>
              <button
                type="button"
                className={`lang-switch-btn ${lang === 'ar' ? 'active' : ''}`}
                onClick={() => handleLanguageChange('ar')}
                style={{
                  background: lang === 'ar' ? 'var(--sahla-yellow)' : '#FFF',
                  fontWeight: lang === 'ar' ? 800 : 600,
                }}
              >
                عربي
              </button>
              <button
                type="button"
                className={`lang-switch-btn ${lang === 'fr' ? 'active' : ''}`}
                onClick={() => handleLanguageChange('fr')}
                style={{
                  background: lang === 'fr' ? 'var(--sahla-yellow)' : '#FFF',
                  fontWeight: lang === 'fr' ? 800 : 600,
                }}
              >
                FR
              </button>
              <button
                type="button"
                className={`lang-switch-btn ${lang === 'en' ? 'active' : ''}`}
                onClick={() => handleLanguageChange('en')}
                style={{
                  background: lang === 'en' ? 'var(--sahla-yellow)' : '#FFF',
                  fontWeight: lang === 'en' ? 800 : 600,
                }}
              >
                EN
              </button>
            </div>

            <a href="#download-app" className="header-cta-btn">
              <span>{t.nav.download}</span>
              <svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                <path d="M12 5v14M19 12l-7 7-7-7" />
              </svg>
            </a>
          </div>
        </div>
      </header>

      {/* ----------------------------------------
          HERO SECTION
          ---------------------------------------- */}
      <section className="hero-section">
        <div className="hero-glow-blob" />
        <div className="hero-container">
          <div className="hero-content">
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

            <div className="hero-download-group" id="download-app">
              {/* App Store Button */}
              <a
                href={APP_STORE_URL}
                target="_blank"
                rel="noreferrer"
                className="store-btn"
                aria-label="Download on App Store"
              >
                <svg className="store-btn-icon" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 6.85c.67-.82 1.13-1.96 1.01-3.1-.98.04-2.17.65-2.87 1.47-.62.72-1.16 1.88-1.01 2.99 1.1.09 2.2-.54 2.87-1.36z" />
                </svg>
                <div className="store-btn-meta">
                  <span className="store-btn-label">Available on</span>
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
              >
                <svg className="store-btn-icon" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M3,20.5V3.5C3,2.91 3.34,2.39 3.84,2.15L13.69,12L3.84,21.85C3.34,21.6 3,21.09 3,20.5M16.81,15.12L6.05,21.34L14.54,12.85L16.81,15.12M20.16,10.81C20.5,11.08 20.75,11.5 20.75,12C20.75,12.5 20.53,12.9 20.18,13.18L17.89,14.5L15.39,12L17.89,9.5L20.16,10.81M6.05,2.66L16.81,8.88L14.54,11.15L6.05,2.66Z" />
                </svg>
                <div className="store-btn-meta">
                  <span className="store-btn-label">Get it on</span>
                  <span className="store-btn-name">Google Play</span>
                </div>
              </a>
            </div>
          </div>

          {/* Hero Visual Card with Real Authentic Brand Image */}
          <div className="hero-visual-card">
            <div className="hero-main-photo-wrapper">
              <Image
                src="/brand/hero_courier.png"
                alt="Sahla Delivery courier delivering fresh hot food"
                fill
                priority
                sizes="(max-width: 768px) 100vw, 470px"
                className="hero-main-photo"
              />
            </div>

            {/* Floating Live Badge */}
            <div className="hero-floating-badge">
              <div className="floating-badge-icon">🛵</div>
              <div className="floating-badge-text">
                <span className="floating-badge-title">{t.hero.badgeTitle}</span>
                <span className="floating-badge-sub">{t.hero.badgeSub}</span>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ----------------------------------------
          SERVICES SECTION (Food, Market, Ifrili)
          ---------------------------------------- */}
      <section className="services-section" id="services">
        <div className="section-head-center">
          <span className="section-eyebrow">{t.services.eyebrow}</span>
          <h2 className="section-main-title">{t.services.title}</h2>
          <p className="section-lead">{t.services.lead}</p>
        </div>

        <div className="services-grid">
          {/* Sahla Food */}
          <div className="service-card">
            <div className="service-icon-box">
              <Image
                src="/services/sahla_food.png"
                alt="Sahla Food"
                width={52}
                height={52}
                className="service-icon-img"
              />
            </div>
            <span className="service-tag">{t.services.foodTag}</span>
            <h3 className="service-name">{t.services.foodTitle}</h3>
            <p className="service-desc">{t.services.foodDesc}</p>
            <a href="#download-app" className="service-action-link">
              <span>{t.services.foodAction}</span>
              <span aria-hidden="true">{isRtl ? '←' : '→'}</span>
            </a>
          </div>

          {/* Sahla Market */}
          <div className="service-card">
            <div className="service-icon-box">
              <Image
                src="/services/sahla_market.png"
                alt="Sahla Market"
                width={52}
                height={52}
                className="service-icon-img"
              />
            </div>
            <span className="service-tag">{t.services.marketTag}</span>
            <h3 className="service-name">{t.services.marketTitle}</h3>
            <p className="service-desc">{t.services.marketDesc}</p>
            <a href="#download-app" className="service-action-link">
              <span>{t.services.marketAction}</span>
              <span aria-hidden="true">{isRtl ? '←' : '→'}</span>
            </a>
          </div>

          {/* Sahla Ifrili */}
          <div className="service-card">
            <div className="service-icon-box">
              <Image
                src="/services/sahla_ifrili.png"
                alt="Sahla Ifrili"
                width={52}
                height={52}
                className="service-icon-img"
              />
            </div>
            <span className="service-tag">{t.services.ifriliTag}</span>
            <h3 className="service-name">{t.services.ifriliTitle}</h3>
            <p className="service-desc">{t.services.ifriliDesc}</p>
            <a href="#download-app" className="service-action-link">
              <span>{t.services.ifriliAction}</span>
              <span aria-hidden="true">{isRtl ? '←' : '→'}</span>
            </a>
          </div>
        </div>
      </section>

      {/* ----------------------------------------
          BRAND SHOWCASE SECTION ("أي وقت.. أي مكان")
          ---------------------------------------- */}
      <section className="brand-showcase-section">
        <div className="showcase-container">
          <div className="showcase-visuals">
            <div className="showcase-img-primary">
              <Image
                src="/brand/app_mockup.jpg"
                alt="Sahla App Experience - Any time, any place"
                fill
                sizes="(max-width: 768px) 90vw, 480px"
                className="showcase-img"
              />
            </div>
            <div className="showcase-img-secondary">
              <Image
                src="/brand/stay_in.jpg"
                alt="Sahla delivery bag - Stay in, we come to you"
                fill
                sizes="(max-width: 768px) 60vw, 320px"
                className="showcase-img"
              />
            </div>
          </div>

          <div className="showcase-content">
            <span className="section-eyebrow" style={{ width: 'fit-content' }}>
              {t.showcase.eyebrow}
            </span>
            <h2 className="section-main-title">{t.showcase.title}</h2>
            <p className="section-lead">{t.showcase.lead}</p>

            <div className="feature-check-list">
              <div className="feature-check-item">
                <div className="feature-check-icon">✓</div>
                <div className="feature-check-text">
                  <h4>{t.showcase.f1Title}</h4>
                  <p>{t.showcase.f1Desc}</p>
                </div>
              </div>

              <div className="feature-check-item">
                <div className="feature-check-icon">✓</div>
                <div className="feature-check-text">
                  <h4>{t.showcase.f2Title}</h4>
                  <p>{t.showcase.f2Desc}</p>
                </div>
              </div>

              <div className="feature-check-item">
                <div className="feature-check-icon">✓</div>
                <div className="feature-check-text">
                  <h4>{t.showcase.f3Title}</h4>
                  <p>{t.showcase.f3Desc}</p>
                </div>
              </div>

              <div className="feature-check-item">
                <div className="feature-check-icon">✓</div>
                <div className="feature-check-text">
                  <h4>{t.showcase.f4Title}</h4>
                  <p>{t.showcase.f4Desc}</p>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ----------------------------------------
          WHY SAHLA (4 ADVANTAGES)
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
            <div className="why-icon">🍱</div>
            <h3>{t.whySahla.card2Title}</h3>
            <p>{t.whySahla.card2Desc}</p>
          </div>

          <div className="why-card">
            <div className="why-icon">🛵</div>
            <h3>{t.whySahla.card3Title}</h3>
            <p>{t.whySahla.card3Desc}</p>
          </div>

          <div className="why-card">
            <div className="why-icon">💬</div>
            <h3>{t.whySahla.card4Title}</h3>
            <p>{t.whySahla.card4Desc}</p>
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
              href="mailto:careers@sahla-delivery.com?subject=Delivery%20Captain%20Application"
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
      <section className="cta-download-section">
        <div className="cta-container">
          <div className="cta-content">
            <h2 className="cta-title">{t.download.title}</h2>
            <p className="cta-desc">{t.download.desc}</p>

            <div className="hero-download-group" style={{ marginTop: '0.5rem' }}>
              <a
                href={APP_STORE_URL}
                target="_blank"
                rel="noreferrer"
                className="store-btn"
                style={{ background: '#000000' }}
              >
                <svg className="store-btn-icon" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 6.85c.67-.82 1.13-1.96 1.01-3.1-.98.04-2.17.65-2.87 1.47-.62.72-1.16 1.88-1.01 2.99 1.1.09 2.2-.54 2.87-1.36z" />
                </svg>
                <div className="store-btn-meta">
                  <span className="store-btn-label">Download on</span>
                  <span className="store-btn-name">App Store</span>
                </div>
              </a>

              <a
                href={GOOGLE_PLAY_URL}
                target="_blank"
                rel="noreferrer"
                className="store-btn"
                style={{ background: 'var(--sahla-green)' }}
              >
                <svg className="store-btn-icon" viewBox="0 0 24 24" fill="currentColor">
                  <path d="M3,20.5V3.5C3,2.91 3.34,2.39 3.84,2.15L13.69,12L3.84,21.85C3.34,21.6 3,21.09 3,20.5M16.81,15.12L6.05,21.34L14.54,12.85L16.81,15.12M20.16,10.81C20.5,11.08 20.75,11.5 20.75,12C20.75,12.5 20.53,12.9 20.18,13.18L17.89,14.5L15.39,12L17.89,9.5L20.16,10.81M6.05,2.66L16.81,8.88L14.54,11.15L6.05,2.66Z" />
                </svg>
                <div className="store-btn-meta">
                  <span className="store-btn-label">Get it on</span>
                  <span className="store-btn-name">Google Play</span>
                </div>
              </a>
            </div>
          </div>

          {/* QR Code Box */}
          <div className="cta-qr-box">
            <div className="cta-qr-code">
              {/* Scalable Vector QR Code Graphic */}
              <svg width="140" height="140" viewBox="0 0 100 100" fill="none">
                <rect width="100" height="100" rx="8" fill="white" />
                {/* Top-Left Finder */}
                <rect x="10" y="10" width="26" height="26" rx="4" fill="#064E3B" />
                <rect x="15" y="15" width="16" height="16" rx="2" fill="white" />
                <rect x="19" y="19" width="8" height="8" rx="1" fill="#FFC700" />
                {/* Top-Right Finder */}
                <rect x="64" y="10" width="26" height="26" rx="4" fill="#064E3B" />
                <rect x="69" y="15" width="16" height="16" rx="2" fill="white" />
                <rect x="73" y="19" width="8" height="8" rx="1" fill="#FFC700" />
                {/* Bottom-Left Finder */}
                <rect x="10" y="64" width="26" height="26" rx="4" fill="#064E3B" />
                <rect x="15" y="69" width="16" height="16" rx="2" fill="white" />
                <rect x="19" y="73" width="8" height="8" rx="1" fill="#FFC700" />
                {/* QR Data Pattern */}
                <rect x="42" y="12" width="6" height="6" rx="1" fill="#111827" />
                <rect x="50" y="18" width="6" height="6" rx="1" fill="#111827" />
                <rect x="42" y="26" width="6" height="6" rx="1" fill="#111827" />
                <rect x="52" y="32" width="6" height="6" rx="1" fill="#064E3B" />
                <rect x="12" y="44" width="6" height="6" rx="1" fill="#111827" />
                <rect x="22" y="48" width="6" height="6" rx="1" fill="#111827" />
                <rect x="32" y="42" width="6" height="6" rx="1" fill="#064E3B" />
                <rect x="44" y="44" width="12" height="12" rx="2" fill="#FFC700" />
                <rect x="62" y="44" width="6" height="6" rx="1" fill="#111827" />
                <rect x="74" y="48" width="6" height="6" rx="1" fill="#111827" />
                <rect x="84" y="42" width="6" height="6" rx="1" fill="#111827" />
                <rect x="42" y="62" width="6" height="6" rx="1" fill="#111827" />
                <rect x="50" y="68" width="6" height="6" rx="1" fill="#064E3B" />
                <rect x="64" y="64" width="8" height="8" rx="1" fill="#111827" />
                <rect x="76" y="70" width="12" height="6" rx="1" fill="#111827" />
                <rect x="64" y="80" width="6" height="10" rx="1" fill="#064E3B" />
                <rect x="78" y="82" width="10" height="6" rx="1" fill="#FFC700" />
                <rect x="42" y="78" width="8" height="8" rx="1" fill="#111827" />
              </svg>
            </div>
            <span className="cta-qr-label">{t.download.scanText}</span>
          </div>
        </div>
      </section>

      {/* ----------------------------------------
          FOOTER
          ---------------------------------------- */}
      <footer className="site-footer">
        <div className="footer-top">
          <div className="footer-brand">
            <Image
              src="/logo.webp"
              alt="Sahla Delivery"
              width={150}
              height={48}
              className="footer-logo-img"
            />
            <p>{t.footer.desc}</p>
          </div>

          <div className="footer-column">
            <h4>{t.footer.services}</h4>
            <ul className="footer-links-list">
              <li><a href="#services">{t.footer.foodDelivery}</a></li>
              <li><a href="#services">{t.footer.groceryDelivery}</a></li>
              <li><a href="#services">{t.footer.ifriliService}</a></li>
            </ul>
          </div>

          <div className="footer-column">
            <h4>{t.footer.legal}</h4>
            <ul className="footer-links-list">
              <li><Link href="/privacy-policy">{t.footer.privacy}</Link></li>
              <li><Link href="/terms-of-service">{t.footer.terms}</Link></li>
              <li><Link href="/delete-account">{t.footer.deleteAccount}</Link></li>
            </ul>
          </div>

          <div className="footer-column">
            <h4>{t.footer.contact}</h4>
            <ul className="footer-links-list">
              <li><a href="mailto:support@sahla-delivery.com">support@sahla-delivery.com</a></li>
              <li><a href="tel:+213000000000">+213 (0) 550 00 00 00</a></li>
              <li>
                <div style={{ display: 'flex', gap: '1rem', marginTop: '0.75rem' }}>
                  <a href="https://facebook.com" target="_blank" rel="noreferrer" aria-label="Facebook">
                    <svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor">
                      <path d="M22 12c0-5.52-4.48-10-10-10S2 6.48 2 12c0 4.84 3.44 8.87 8 9.8V15H8v-3h2V9.5C10 7.57 11.57 6 13.5 6H16v3h-2c-.55 0-1 .45-1 1v2h3v3h-3v6.95c5.05-.5 9-4.76 9-9.95z" />
                    </svg>
                  </a>
                  <a href="https://instagram.com" target="_blank" rel="noreferrer" aria-label="Instagram">
                    <svg width="22" height="22" viewBox="0 0 24 24" fill="currentColor">
                      <path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073zm0 5.838c-3.403 0-6.162 2.759-6.162 6.162s2.759 6.163 6.162 6.163 6.162-2.759 6.162-6.163c0-3.403-2.759-6.162-6.162-6.162zm0 10.162c-2.209 0-4-1.79-4-4 0-2.209 1.791-4 4-4s4 1.791 4 4c0 2.21-1.791 4-4 4zm6.406-11.845c-.796 0-1.441.645-1.441 1.44s.645 1.44 1.441 1.44c.795 0 1.439-.645 1.439-1.44s-.644-1.44-1.439-1.44z" />
                    </svg>
                  </a>
                </div>
              </li>
            </ul>
          </div>
        </div>

        <div className="footer-bottom">
          <p>{t.footer.copyright}</p>
          <p>Made with ❤️ for Algeria</p>
        </div>
      </footer>
    </main>
  );
}
