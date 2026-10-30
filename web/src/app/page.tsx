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
      services: 'أصناف الطعام',
      whySahla: 'علاش ساهلة؟',
      howItWorks: 'كيف تطلب',
      partners: 'انضم إلينا',
      download: 'حمّل التطبيق',
    },
    hero: {
      badge: 'تطبيق توصيل الطعام الأول في مدينتك',
      title1: 'خلي في بلاصتك...',
      titleHighlight: 'حنا نجيو لعندك!',
      subtitle:
        'أي وقت... أي مكان. كل ما تشتهيه من أشهى وجباتك وأطباقك المفضلة يوصلك سخون وسريع حتى لباب دارك مع ساهلة.',
      chipSpeed: '⚡ توصيل في أقل من 30 دقيقة',
      chipTracking: '📍 تتبع مسار طلبك لحظة بلحظة',
      chipQuality: '💵 دفع سهل نقداً عند الاستلام',
      downloadAppStore: 'App Store',
      downloadGooglePlay: 'Google Play',
      badgeTitle: 'تم التوصيل الآن بنجاح!',
      badgeSub: 'وجبة مشويات ساخنة • في 24 دقيقة',
    },
    services: {
      eyebrow: 'ساهلة فود (Sahla Food)',
      title: 'كل ما تشتهيه من أفضل مطاعم مدينتك',
      lead: 'سواء كنت جيعان وتستنى في برغر مقرمش، بيتزا سخونة، أو طبق تقليدي أصيل، ساهلة فود توصلك كل أطباقك المفضلة لباب دارك.',
      c1Title: 'البرغر والوجبات السريعة',
      c1Tag: 'الأكثر طلباً',
      c1Desc:
        'ساندويتشات برغر شهية، تاكوس، شاورما، وبطاطا مقرمشة من أشهر المطاعم المعتمدة والأعلى تقييماً في منطقتك.',
      c1Action: 'استكشف الوجبات السريعة',
      c2Title: 'البيتزا والمأكولات الإيطالية',
      c2Tag: 'ساخنة ومقرمشة',
      c2Desc:
        'تشكيلة واسعة من البيتزا الإيطالية بالجبن الذائب والصلصات الخاصة، تُعد فور طلبك وتصلك بحرارتها.',
      c2Action: 'اطلب بيتزا الآن',
      c3Title: 'الأطباق التقليدية والمشاوي',
      c3Tag: 'نكهة أصيلة',
      c3Desc:
        'مشاوي مشكلة ساخنة، طواجن جزائرية عريقة، وأطباق شعبية غنية بالنكهات والبهارات الأصلية التي تحبها.',
      c3Action: 'تذوق المشاوي والأطباق',
    },
    showcase: {
      eyebrow: 'أي وقت.. أي مكان',
      title: 'تجربة طلب طعام مصممة لراحتك التامة',
      lead: 'صممنا تطبيق ساهلة ليكون الأسهل والأسرع، ليمنحك تجربة خالية من التعقيد من أول ضغطة حتى استلام الوجبة.',
      f1Title: 'قوائم طعام كاملة بالصور والأسعار الحقيقية',
      f1Desc: 'اكتشف قوائم المطاعم بالصور الواضحة والأسعار الرسمية بدون أي رسوم خفية.',
      f2Title: 'تخصيص كامل لوجبتك وملاحظاتك',
      f2Desc: 'اختر الإضافات، الأحجام، والملاحظات الخاصة التي تفضلها في كل وجبة لتصلك كما تحب تماماً.',
      f3Title: 'خريطة تتبع ذكية بنظام GPS مباشر',
      f3Desc: 'راقب تحركات عامل التوصيل على الخريطة دقيقة بدقيقة من وقت خروجه من المطعم حتى وقوفه أمام بابك.',
      f4Title: 'دفع سهل عند الاستلام (كاش)',
      f4Desc: 'ادفع بأمان وراحة بال نقداً عند وصول طلبك واستلامك له باليد.',
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
    footer: {
      desc: 'ساهلة — تطبيق توصيل الطعام الجزائري الرائد. خلي في بلاصتك.. حنا نجيو لعندك!',
      company: 'الشركة',
      services: 'المأكولات',
      legal: 'الشروط والسياسات',
      privacy: 'سياسة الخصوصية',
      terms: 'شروط الخدمة',
      deleteAccount: 'حذف الحساب',
      foodDelivery: 'ساهلة فود (Sahla Food)',
      fastFood: 'وجبات سريعة وبرغر',
      traditionalFood: 'أطباق تقليدية ومشاوي',
      contact: 'اتصل بنا',
      copyright: '© 2026 ساهلة (Sahla Delivery). جميع الحقوق محفوظة.',
    },
  },
  fr: {
    nav: {
      services: 'Plats & Menus',
      whySahla: 'Pourquoi Sahla ?',
      howItWorks: 'Comment ça marche',
      partners: 'Partenaires',
      download: "L'application",
    },
    hero: {
      badge: 'Livraison de repas n°1 dans votre ville',
      title1: 'Restez chez vous...',
      titleHighlight: 'On vient chez vous !',
      subtitle:
        'À tout moment, partout. Tous vos plats et repas favoris livrés chauds et rapides jusqu’à votre porte avec Sahla.',
      chipSpeed: '⚡ Livraison en moins de 30 min',
      chipTracking: '📍 Suivi GPS en temps réel',
      chipQuality: '💵 Espèces à la livraison',
      downloadAppStore: 'App Store',
      downloadGooglePlay: 'Google Play',
      badgeTitle: 'Commande livrée avec succès !',
      badgeSub: 'Grillades chaudes • en 24 minutes',
    },
    services: {
      eyebrow: 'Sahla Food',
      title: 'Tous vos plats préférés des meilleurs restaurants',
      lead: 'Envie d’un bon burger croustillant, d’une pizza au fromage fondant ou d’un plat traditionnel réconfortant ? Sahla Food vous livre tout à domicile.',
      c1Title: 'Burgers & Fast Food',
      c1Tag: 'Les plus demandés',
      c1Desc:
        'Burgers gourmets, tacos, shawarma et frites dorées des restaurants les plus réputés de votre secteur.',
      c1Action: 'Découvrir le fast-food',
      c2Title: 'Pizzas & Saveurs Italiennes',
      c2Tag: 'Chaudes & croustillantes',
      c2Desc:
        'Large choix de pizzas cuites à la commande avec garnitures généreuses et livraison express.',
      c2Action: 'Commander une pizza',
      c3Title: 'Plats Traditionnels & Grillades',
      c3Tag: 'Recettes authentiques',
      c3Desc:
        'Tajines savoureux, grillades au feu de bois et spécialités locales riches en épices et traditions.',
      c3Action: 'Goûter les grillades',
    },
    showcase: {
      eyebrow: 'N’importe où, n’importe quand',
      title: 'Une expérience conçue pour votre sérénité',
      lead: 'Sahla vous offre l’expérience de commande la plus fluide et rapide d’Algérie.',
      f1Title: 'Menus clairs avec photos et prix nets',
      f1Desc: 'Consultez les cartes détaillées des restaurants sans frais cachés.',
      f2Title: 'Personnalisation totale de vos plats',
      f2Desc: 'Ajoutez vos sauces, suppléments et consignes de préparation.',
      f3Title: 'Suivi direct par GPS en temps réel',
      f3Desc: 'Observez la progression du livreur jusqu’à votre porte.',
      f4Title: 'Paiement sécurisé en espèces à la livraison',
      f4Desc: 'Réglez en toute confiance à la réception de votre repas.',
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
    footer: {
      desc: 'Sahla — L’application algérienne de référence pour la livraison de repas à domicile. Restez chez vous, on vient chez vous !',
      company: 'Entreprise',
      services: 'Menu',
      legal: 'Légal',
      privacy: 'Politique de confidentialité',
      terms: 'Conditions d’utilisation',
      deleteAccount: 'Supprimer mon compte',
      foodDelivery: 'Sahla Food',
      fastFood: 'Fast Food & Burgers',
      traditionalFood: 'Plats traditionnels & Grillades',
      contact: 'Contactez-nous',
      copyright: '© 2026 Sahla Delivery. Tous droits réservés.',
    },
  },
  en: {
    nav: {
      services: 'Food & Menus',
      whySahla: 'Why Sahla?',
      howItWorks: 'How It Works',
      partners: 'Partners',
      download: 'Get the App',
    },
    hero: {
      badge: '#1 Food Delivery App in Your City',
      title1: 'Stay where you are...',
      titleHighlight: 'We deliver to you!',
      subtitle:
        'Any time, any place. Your favorite meals and dishes delivered piping hot and fast to your doorstep with Sahla.',
      chipSpeed: '⚡ Under 30-min fast delivery',
      chipTracking: '📍 Live GPS order tracking',
      chipQuality: '💵 Cash on delivery accepted',
      downloadAppStore: 'App Store',
      downloadGooglePlay: 'Google Play',
      badgeTitle: 'Order Delivered Successfully!',
      badgeSub: 'Hot grilled skewers • in 24 mins',
    },
    services: {
      eyebrow: 'Sahla Food',
      title: 'All Your Food Cravings from the Best Restaurants',
      lead: 'Whether you crave a juicy gourmet burger, a steaming cheesy pizza, or authentic grilled specialties, Sahla Food brings it warm and fresh to your door.',
      c1Title: 'Burgers & Fast Food',
      c1Tag: 'Most Popular',
      c1Desc:
        'Mouthwatering burgers, tacos, shawarma, and crispy fries from the most loved spots in your area.',
      c1Action: 'Explore Burgers & Fast Food',
      c2Title: 'Pizza & Italian Delights',
      c2Tag: 'Hot & Crispy',
      c2Desc:
        'Crispy crust pizzas baked fresh upon ordering, loaded with premium toppings and melted cheese.',
      c2Action: 'Order Pizza Now',
      c3Title: 'Traditional Dishes & Grills',
      c3Tag: 'Authentic Flavor',
      c3Desc:
        'Sizzling mixed grills, traditional slow-cooked tajines, and savory heritage dishes packed with flavor.',
      c3Action: 'Taste Traditional Dishes',
    },
    showcase: {
      eyebrow: 'Any Time.. Any Place',
      title: 'An Experience Crafted for Your Utmost Comfort',
      lead: 'We built Sahla to be fast, intuitive, and hassle-free from your first tap until the meal arrives.',
      f1Title: 'Clear menus with photos and transparent prices',
      f1Desc: 'Explore complete restaurant menus with accurate pricing and exclusive promotions with zero hidden fees.',
      f2Title: 'Full meal customization & order notes',
      f2Desc: 'Add toppings, pick sides, and leave specific kitchen instructions for the chef.',
      f3Title: 'Smart live GPS map tracking',
      f3Desc: 'Follow your delivery courier on the map from kitchen pickup right to your doorstep.',
      f4Title: 'Convenient Cash on Delivery',
      f4Desc: 'Pay safely in cash when your order is delivered into your hands.',
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
    footer: {
      desc: 'Sahla — Algeria’s leading food delivery app. Stay where you are, we come to you!',
      company: 'Company',
      services: 'Food Services',
      legal: 'Legal',
      privacy: 'Privacy Policy',
      terms: 'Terms of Service',
      deleteAccount: 'Delete Account',
      foodDelivery: 'Sahla Food',
      fastFood: 'Fast Food & Burgers',
      traditionalFood: 'Traditional & Grills',
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

            <a href="#download-app" className="header-cta-btn" aria-label={t.nav.download}>
              <span>{t.nav.download}</span>
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2.5" strokeLinecap="round" strokeLinejoin="round">
                <path d="M12 5v14M19 12l-7 7-7-7" />
              </svg>
            </a>
          </div>
        </div>
      </header>

      {/* ----------------------------------------
          HERO SECTION (MAIN WEB ENTRY)
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

            {/* Guaranteed Same-Row Store Buttons on Mobile & Desktop */}
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

          {/* Hero Visual Card with Real Authentic Brand Courier Image */}
          <div className="hero-visual-card">
            <div className="hero-main-photo-wrapper">
              <Image
                src="/brand/hero_courier.png"
                alt="Sahla Delivery courier delivering fresh hot food"
                fill
                priority
                sizes="(max-width: 768px) 100vw, 480px"
                className="hero-main-photo"
              />

              {/* Floating Live Badge cleanly integrated INSIDE the photo card bottom */}
              <div className="hero-floating-badge">
                <div className="floating-badge-icon">🛵</div>
                <div className="floating-badge-text">
                  <span className="floating-badge-title">{t.hero.badgeTitle}</span>
                  <span className="floating-badge-sub">{t.hero.badgeSub}</span>
                </div>
              </div>
            </div>
          </div>
        </div>
      </section>

      {/* ----------------------------------------
          SAHLA FOOD SECTION (Food Only)
          ---------------------------------------- */}
      <section className="services-section" id="services">
        <div className="section-head-center">
          <span className="section-eyebrow">{t.services.eyebrow}</span>
          <h2 className="section-main-title">{t.services.title}</h2>
          <p className="section-lead">{t.services.lead}</p>
        </div>

        <div className="services-grid">
          {/* Category 1: Burgers & Fast Food */}
          <div className="service-card">
            <div className="service-icon-box" aria-hidden="true">
              🍔
            </div>
            <span className="service-tag">{t.services.c1Tag}</span>
            <h3 className="service-name">{t.services.c1Title}</h3>
            <p className="service-desc">{t.services.c1Desc}</p>
            <a href="#download-app" className="service-action-link">
              <span>{t.services.c1Action}</span>
              <span aria-hidden="true">{isRtl ? '←' : '→'}</span>
            </a>
          </div>

          {/* Category 2: Pizza & Italian */}
          <div className="service-card">
            <div className="service-icon-box" aria-hidden="true">
              🍕
            </div>
            <span className="service-tag">{t.services.c2Tag}</span>
            <h3 className="service-name">{t.services.c2Title}</h3>
            <p className="service-desc">{t.services.c2Desc}</p>
            <a href="#download-app" className="service-action-link">
              <span>{t.services.c2Action}</span>
              <span aria-hidden="true">{isRtl ? '←' : '→'}</span>
            </a>
          </div>

          {/* Category 3: Traditional & Grills */}
          <div className="service-card">
            <div className="service-icon-box" aria-hidden="true">
              🥩
            </div>
            <span className="service-tag">{t.services.c3Tag}</span>
            <h3 className="service-name">{t.services.c3Title}</h3>
            <p className="service-desc">{t.services.c3Desc}</p>
            <a href="#download-app" className="service-action-link">
              <span>{t.services.c3Action}</span>
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
                src="/brand/coverage_map.jpg"
                alt="Sahla Live Delivery Coverage"
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
          FOOTER
          ---------------------------------------- */}
      <footer className="site-footer">
        <div className="footer-top">
          <div className="footer-brand">
            <Image
              src="/logo.webp"
              alt="Sahla Delivery"
              width={140}
              height={44}
              className="footer-logo-img"
            />
            <p>{t.footer.desc}</p>
          </div>

          <div className="footer-column">
            <h4>{t.footer.services}</h4>
            <ul className="footer-links-list">
              <li><a href="#services">{t.footer.foodDelivery}</a></li>
              <li><a href="#services">{t.footer.fastFood}</a></li>
              <li><a href="#services">{t.footer.traditionalFood}</a></li>
            </ul>
          </div>

          <div className="footer-column">
            <h4>{t.footer.company}</h4>
            <ul className="footer-links-list">
              <li><a href="#why-sahla">{t.nav.whySahla}</a></li>
              <li><a href="#how-it-works">{t.nav.howItWorks}</a></li>
              <li><a href="#partners">{t.nav.partners}</a></li>
              <li><a href="mailto:support@sahla-delivery.com">{t.footer.contact}</a></li>
            </ul>
          </div>

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
    </main>
  );
}
