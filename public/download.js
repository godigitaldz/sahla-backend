/**
 * =============================================================================
 * Smart Download Configuration & Controller — Sahla (Algeria)
 * =============================================================================
 * Single Source of Truth for App Identifiers, Deep Links, Fallbacks & Branding.
 * Handles device detection, in-app browser isolation, zero-redirect webview mode,
 * client-side QR generation, store redirection, localization, diagnostics, and analytics.
 * Zero external dependencies.
 * =============================================================================
 */

var DEFAULT_CONFIG = {
  APP_NAME: "Sahla",
  // TODO_HOST: Replace with custom production domain (e.g. get.sahla.dz or sahla-app.com)
  HOST: "sahla-backend.vercel.app",
  IOS_APP_STORE_URL: "https://apps.apple.com/dz/app/sahla-algerie/id6834895657",
  IOS_BUNDLE_ID: "com.sahla.sahlaalgerie",
  IOS_TEAM_ID: "9P628XCQ94",
  IOS_URI_SCHEME: "sahla://",
  ANDROID_PLAY_STORE_URL: "https://play.google.com/store/apps/details?id=com.godigital.sahla",
  ANDROID_PACKAGE: "com.godigital.sahla",
  ANDROID_URI_SCHEME: "sahla://",
  ANDROID_SHA256: "35:5A:0E:B6:87:F5:F1:98:3C:59:0D:0A:86:52:83:5B:02:CD:AC:9C:22:A7:6D:5C:9C:BC:E4:51:DA:96:93:F4",
  OPEN_TIMEOUT_MS: 2200,
  OPTIONAL_ANDROID_FALLBACKS: {
    appGallery: "", // TODO_HUAWEI_APPGALLERY: Add Huawei AppGallery URL if available
    directApk: ""   // TODO_DIRECT_APK: Add direct APK download URL if available
  },
  BRAND: {
    primaryColor: "#FFC700",
    primaryDarkColor: "#064E3B",
    logoPath: "logo.webp",
    appName: "Sahla",
    tagline: "أفضل مأكولات ومطاعم بسكرة بين يديك مع توصيل فوري حتى باب منزلك."
  }
};

var CONFIG = Object.assign({}, DEFAULT_CONFIG, (typeof window !== "undefined" && window.CONFIG) || {});

if (typeof window !== "undefined") {
  window.CONFIG = CONFIG;
}

var ACTIVE_CONFIG = CONFIG;

// -----------------------------------------------------------------------------
// Diagnostics Error & Action Ring Buffer (Last 20 events)
// -----------------------------------------------------------------------------
var DIAGNOSTIC_LOG = [];
function logDiagnostic(type, data) {
  try {
    DIAGNOSTIC_LOG.push({
      time: new Date().toISOString().substring(11, 19),
      type,
      data
    });
    if (DIAGNOSTIC_LOG.length > 20) DIAGNOSTIC_LOG.shift();
    if (typeof window !== "undefined" && typeof window.updateDiagnosticsUI === "function") {
      window.updateDiagnosticsUI();
    }
  } catch (e) {}
}

if (typeof window !== "undefined") {
  window.addEventListener('error', function (e) {
    logDiagnostic('window_error', { message: e.message, filename: e.filename, lineno: e.lineno });
  });
  window.addEventListener('unhandledrejection', function (e) {
    logDiagnostic('unhandled_rejection', { reason: String(e.reason) });
  });
}

(function () {
  'use strict';

  function safeNavigate(url) {
    try {
      if (typeof window !== "undefined" && typeof window.__SD_ON_NAVIGATE__ === "function") {
        window.__SD_ON_NAVIGATE__(url);
      }
    } catch (e) {}
    window.location.href = url;
  }

  // ---------------------------------------------------------------------------
  // Safe Storage & Clipboard Helpers
  // ---------------------------------------------------------------------------
  const safeSession = {
    get(k) {
      try {
        return sessionStorage.getItem(k);
      } catch (e) {
        return null;
      }
    },
    set(k, v) {
      try {
        sessionStorage.setItem(k, v);
      } catch (e) {}
    },
    del(k) {
      try {
        sessionStorage.removeItem(k);
      } catch (e) {}
    }
  };

  let fallbackTrackingSessionId = '';
  const trackingOnceInMemory = new Set();

  function getTrackingSessionId() {
    try {
      const existing = safeSession.get('sd_download_tracking_session');
      if (existing) return existing;
    } catch (_) {}
    if (fallbackTrackingSessionId) return fallbackTrackingSessionId;
    try {
      if (window.crypto && typeof window.crypto.randomUUID === 'function') {
        fallbackTrackingSessionId = window.crypto.randomUUID();
      }
    } catch (_) {}
    if (!fallbackTrackingSessionId) {
      fallbackTrackingSessionId = `${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}-${Math.random().toString(36).slice(2)}`;
    }
    try { safeSession.set('sd_download_tracking_session', fallbackTrackingSessionId); } catch (_) {}
    return fallbackTrackingSessionId;
  }

  function capTrackingValue(value, max = 120) {
    return typeof value === 'string' ? value.trim().slice(0, max) : '';
  }

  function sendDownloadTracking(event, props = {}) {
    try {
      if (document.visibilityState === 'prerender') return;
      const sessionId = getTrackingSessionId();
      if (['page_view', 'platform_detected', 'inapp_detected'].includes(event)) {
        const marker = `sd_download_${event}_sent`;
        try {
          if (safeSession.get(marker) === sessionId) return;
          safeSession.set(marker, sessionId);
          if (safeSession.get(marker) !== sessionId) {
            if (trackingOnceInMemory.has(event)) return;
            trackingOnceInMemory.add(event);
          }
        } catch (_) {
          if (trackingOnceInMemory.has(event)) return;
          trackingOnceInMemory.add(event);
        }
      }
      const query = new URLSearchParams(window.location.search || '');
      const allowedProps = {};
      if (props.trigger === 'auto' || props.trigger === 'tap') allowedProps.trigger = props.trigger;
      if (props.store === 'appstore' || props.store === 'playstore') allowedProps.store = props.store;
      if (props.target === 'Safari' || props.target === 'Chrome') allowedProps.target = props.target;
      const buildVersion = document.querySelector('meta[name="build"]')?.getAttribute('content') || '';
      const payload = {
        event,
        sessionId: capTrackingValue(sessionId, 80),
        platform: ['ios', 'android', 'desktop', 'unknown'].includes(props.platform) ? props.platform : 'unknown',
        inApp: ['Instagram', 'Snapchat', 'TikTok', 'Facebook', 'Messenger', 'Other'].includes(props.inApp)
          ? props.inApp : 'none',
        route: capTrackingValue(`${window.location.pathname || '/'}${window.location.hash === '#download' ? '#download' : ''}`, 160) || '/',
        source: {
          utm_source: capTrackingValue(query.get('utm_source') || ''),
          utm_medium: capTrackingValue(query.get('utm_medium') || ''),
          utm_campaign: capTrackingValue(query.get('utm_campaign') || ''),
          ref: capTrackingValue(query.get('ref') || ''),
          campaign: capTrackingValue(query.get('campaign') || ''),
        },
        props: allowedProps,
        ts: new Date().toISOString(),
        buildVersion: capTrackingValue(buildVersion, 40),
        lang: capTrackingValue(document.documentElement.lang || 'ar', 12),
      };
      const endpoint = (window.CONFIG && window.CONFIG.TRACK_ENDPOINT) || '/api/track/download';
      const blob = new Blob([JSON.stringify(payload)], { type: 'application/json' });
      if (navigator.sendBeacon) {
        try {
          if (navigator.sendBeacon(endpoint, blob)) return;
        } catch (_) {}
      }
      if (typeof fetch === 'function') {
        try {
          const pending = fetch(endpoint, {
            method: 'POST', body: blob, keepalive: true, credentials: 'same-origin',
          });
          if (pending && typeof pending.catch === 'function') pending.catch(() => {});
        } catch (_) {}
      }
    } catch (_) {
      // Analytics is best-effort only and must never interrupt download navigation.
    }
  }

  async function copyText(text) {
    try {
      if (navigator.clipboard && navigator.clipboard.writeText) {
        await navigator.clipboard.writeText(text);
        return true;
      }
    } catch (e) {}
    try {
      const t = document.createElement("textarea");
      t.value = text;
      t.setAttribute("readonly", "");
      t.style.cssText = "position:fixed;opacity:0;pointer-events:none;left:-9999px;";
      document.body.appendChild(t);
      t.select();
      const ok = document.execCommand("copy");
      t.remove();
      if (ok) return true;
    } catch (e) {}
    return false; // caller must reveal visible, selectable URL field
  }

  // ---------------------------------------------------------------------------
  // 1. Localization Strings (Arabic First, English & French Fallbacks)
  // ---------------------------------------------------------------------------
  const STRINGS = {
    ar: {
      dir: 'rtl',
      badge: '✨ تطبيق سهلة الرسمي | ولاية بسكرة',
      title: 'حمّل تطبيق سهلة على هاتفك',
      tagline: 'أفضل مأكولات ومطاعم بسكرة بين يديك مع توصيل فوري حتى باب منزلك.',
      backToWeb: 'الرئيسية',
      openingTitle: 'جاري فتح تطبيق سهلة…',
      openingDesc: 'إذا ظهرت لك نافذة تأكيد، اضغط على «سماح» (Allow) لفتح التطبيق.',
      promptTip: '💡 اضغط على «سماح» (Allow) في النافذة المنبثقة',
      redirectingTitleIos: 'جاري تحويلك إلى App Store…',
      redirectingTitleAndroid: 'جاري تحويلك إلى Google Play…',
      redirectingDesc: 'التحضير لصفحة التثبيت في متجر التطبيقات…',
      openedTitle: 'تم فتح التطبيق ✓',
      openedDesc: 'استمتع بأشهى المأكولات! إذا لم يفتح معك، اضغط على الزر أدناه:',
      fallbackTitle: 'لم يفتح التطبيق تلقائياً؟',
      fallbackDesc: 'اضغط «فتح تطبيق سهلة» إذا كان مثبتاً على هاتفك، أو حمّله مجاناً الآن:',
      openAppBtn: 'فتح تطبيق سهلة',
      tryAgain: '↻ حاول مرة أخرى',
      downloadOnAppStoreSub: 'تحميل من',
      appStore: 'App Store',
      getItOnPlayStoreSub: 'احصل عليه من',
      googlePlay: 'Google Play',
      qrLabel: 'امسح الرمز للتحميل المباشر',
      qrSub: 'وجّه كاميرا هاتفك نحو الرمز لتحميل التطبيق مباشرة على هاتفك.',
      copyBtn: 'نسخ الرابط',
      copiedToast: 'تم نسخ الرابط بنجاح! ✓',
      // In-App Browser Strings
      inAppNoticeInstagram: 'المتصفح الداخلي يحجب فتح وتثبيت التطبيقات. اضغط على ⋯ في أعلى الشاشة، ثم اختر «فتح في Safari».',
      inAppNoticeSnapchat: 'المتصفح الداخلي يحجب فتح وتثبيت التطبيقات. اضغط على أيقونة فتح في Safari 🧭 في الشريط السفلي للشاشة.',
      inAppNoticeIosGeneric: (b) => `المتصفح الداخلي لتطبيق ${b} يحجب فتح وتثبيت التطبيقات. اضغط على ⋯ أو أيقونة المشاركة، ثم اختر «فتح في Safari».`,
      inAppNoticeAndroid: (b) => `المتصفح الداخلي لتطبيق ${b} يحجب تثبيت التطبيقات. اضغط على الزر أدناه أو قائمة ⋮ لفتح الرابط في متصفح Chrome.`,
      openInChromeBtn: 'افتح في Chrome',
      copyDownloadLink: 'نسخ رابط التحميل',
      storePromptInApp: 'أو حمّل التطبيق مباشرة من المتجر:',
      inAppStoreHint: 'لم يفتح التطبيق؟ حمّله مجاناً من متجر التطبيقات أدناه:',
      copyManualLabel: 'انسخ الرابط يدويًا:',
      openInPlayMarket: 'أو افتح مباشرة في متجر Play (market://)'
    },
    en: {
      dir: 'ltr',
      badge: '✨ Official Sahla App | Biskra',
      title: 'Get Sahla on your phone',
      tagline: 'The fastest and easiest way to order your favorite meals in Biskra.',
      backToWeb: 'Home',
      openingTitle: 'Opening Sahla…',
      openingDesc: 'If prompted, tap "Allow" to open the app directly on your phone.',
      promptTip: '💡 Tap "Allow" when the prompt appears',
      redirectingTitleIos: 'Taking you to the App Store…',
      redirectingTitleAndroid: 'Taking you to Google Play…',
      redirectingDesc: 'Preparing the installation page…',
      openedTitle: 'Opened ✓',
      openedDesc: 'Enjoy your food! If it didn’t open, tap the button below:',
      fallbackTitle: 'Didn’t open automatically?',
      fallbackDesc: 'Tap "Open Sahla" if installed, or download it free from the store:',
      openAppBtn: 'Open Sahla App',
      tryAgain: '↻ Try again',
      downloadOnAppStoreSub: 'Download on the',
      appStore: 'App Store',
      getItOnPlayStoreSub: 'GET IT ON',
      googlePlay: 'Google Play',
      qrLabel: 'Scan to download on mobile',
      qrSub: 'Point your camera at the QR code to install or open Sahla directly.',
      copyBtn: 'Copy Link',
      copiedToast: 'Link copied to clipboard! ✓',
      inAppNoticeInstagram: 'In-app browsers block app store redirects. Tap ⋯ at the top, then select "Open in Safari".',
      inAppNoticeSnapchat: 'In-app browsers block app store redirects. Tap the share/browser icon ⎋ in the bottom toolbar to open in Safari.',
      inAppNoticeIosGeneric: (b) => `The in-app browser for ${b} blocks store redirects. Tap ⋯ or Share, then select "Open in Safari".`,
      inAppNoticeAndroid: (b) => `The in-app browser blocks app installation. Tap the button below or ⋮ menu to open in Chrome.`,
      openInChromeBtn: 'Open in Chrome',
      copyDownloadLink: 'Copy Download Link',
      storePromptInApp: 'Or download directly from the store:',
      inAppStoreHint: 'Didn’t open? Download free from the store below:',
      copyManualLabel: 'Copy link manually:',
      openInPlayMarket: 'Or open directly in Play Store (market://)'
    },
    fr: {
      dir: 'ltr',
      badge: '✨ Application Officielle Sahla | Biskra',
      title: 'Téléchargez Sahla sur votre mobile',
      tagline: 'Le moyen le plus rapide et facile de commander vos plats préférés à Biskra.',
      backToWeb: 'Accueil',
      openingTitle: 'Ouverture de Sahla…',
      openingDesc: 'Si une confirmation s’affiche, appuyez sur « Ouvrir » ou « Autoriser ».',
      promptTip: '💡 Appuyez sur « Autoriser » dans la fenêtre',
      redirectingTitleIos: 'Redirection vers l’App Store…',
      redirectingTitleAndroid: 'Redirection vers Google Play…',
      redirectingDesc: 'Préparation de la page de téléchargement…',
      openedTitle: 'Application ouverte ✓',
      openedDesc: 'Bon appétit ! Si elle ne s’est pas ouverte, appuyez ci-dessous :',
      fallbackTitle: 'L’application ne s’ouvre pas ?',
      fallbackDesc: 'Appuyez sur « Ouvrir Sahla » ou téléchargez-la gratuitement :',
      openAppBtn: 'Ouvrir l’application Sahla',
      tryAgain: '↻ Réessayer',
      downloadOnAppStoreSub: 'Télécharger dans',
      appStore: 'App Store',
      getItOnPlayStoreSub: 'DISPONIBLE SUR',
      googlePlay: 'Google Play',
      qrLabel: 'Scannez pour ouvrir sur mobile',
      qrSub: 'Pointez votre appareil photo pour télécharger Sahla directement.',
      copyBtn: 'Copier le lien',
      copiedToast: 'Lien copié dans le presse-papiers ! ✓',
      inAppNoticeInstagram: 'Le navigateur intégré bloque les redirections. Appuyez sur ⋯ en haut, puis sélectionnez « Ouvrir dans Safari ».',
      inAppNoticeSnapchat: 'Le navigateur intégré bloque les redirections. Appuyez sur l’icône ⎋ dans la barre inférieure pour ouvrir dans Safari.',
      inAppNoticeIosGeneric: (b) => `Le navigateur intégré de ${b} bloque les redirections. Appuyez sur ⋯ ou Partager, puis « Ouvrir dans Safari ».`,
      inAppNoticeAndroid: (b) => `Le navigateur intégré bloque l’installation. Appuyez ci-dessous ou sur ⋮ pour ouvrir dans Chrome.`,
      openInChromeBtn: 'Ouvrir dans Chrome',
      copyDownloadLink: 'Copier le lien',
      storePromptInApp: 'Ou téléchargez directement depuis le store :',
      inAppStoreHint: 'L’application ne s’est pas ouverte ? Téléchargez-la ci-dessous :',
      copyManualLabel: 'Copiez le lien manuellement :',
      openInPlayMarket: 'Ou ouvrir directement dans le Play Store (market://)'
    }
  };

  function getCurrentLang() {
    try {
      const urlParam = new URLSearchParams(window.location.search).get('lang');
      if (urlParam && STRINGS[urlParam]) return urlParam;
      const stored = localStorage.getItem('sahla_lang');
      if (stored && STRINGS[stored]) return stored;
      const htmlLang = document.documentElement.lang;
      if (htmlLang && STRINGS[htmlLang]) return htmlLang;
    } catch (e) {}
    return 'ar';
  }

  // ---------------------------------------------------------------------------
  // 2. Analytics Lightweight Hook
  // ---------------------------------------------------------------------------
  function track(event, props = {}) {
    const payload = {
      event,
      timestamp: new Date().toISOString(),
      url: window.location.href,
      referrer: document.referrer || null,
      ...props
    };

    logDiagnostic('analytics_event', payload);
    console.log(`[SmartDownload Analytics] ${event}`, payload);

    try {
      if (typeof window.gtag === 'function') window.gtag('event', event, props);
      if (typeof window.plausible === 'function') window.plausible(event, { props });
      if (window.posthog && typeof window.posthog.capture === 'function') window.posthog.capture(event, props);
      if (window.dataLayer && Array.isArray(window.dataLayer)) window.dataLayer.push({ event, ...props });
    } catch (e) {
      console.warn('[SmartDownload Analytics Error]', e);
    }

    try {
      const platform = props.platform || detectPlatform();
      const detectedApp = props.app || (typeof props.inApp === 'string' ? props.inApp : '') || detectInApp()?.app || 'none';
      const inApp = ['Instagram', 'Snapchat', 'TikTok', 'Facebook', 'Messenger'].includes(detectedApp)
        ? detectedApp : detectedApp === 'none' || !detectedApp ? 'none' : 'Other';
      if (event === 'download_page_view') sendDownloadTracking('page_view', { platform, inApp });
      if (event === 'platform_detected') sendDownloadTracking('platform_detected', { platform, inApp });
      if (event === 'inapp_browser_detected') sendDownloadTracking('inapp_detected', { platform, inApp });
      if (event === 'app_open_tap' || event === 'inapp_auto_open_attempt') {
        const trigger = event === 'inapp_auto_open_attempt' || props.type === 'auto_normal' ? 'auto' : 'tap';
        sendDownloadTracking('app_open_attempt', { platform, inApp, trigger });
        if (props.type === 'retry') sendDownloadTracking('retry_tap', { platform, inApp });
      }
      if (event === 'inapp_app_opened' || event === 'app_opened_likely') sendDownloadTracking('app_opened_likely', { platform, inApp });
      if (event === 'inapp_store_fallback' || event === 'app_open_timeout') {
        sendDownloadTracking('store_redirect', {
          platform, inApp,
          store: platform === 'ios' ? 'appstore' : 'playstore',
        });
      }
      if (event === 'copy_link_click') sendDownloadTracking('copy_link', { platform, inApp });
      if (event === 'store_tap') {
        const store = props.store === 'app_store' ? 'appstore' : 'playstore';
        sendDownloadTracking('store_tap', { platform, inApp, store });
      }
      if (event === 'chrome_escape_tap') sendDownloadTracking('escape_tap', { platform, inApp, target: 'Chrome' });
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // 3. Standalone Client-Side QR Generator (Zero Dependencies)
  // ---------------------------------------------------------------------------
  const QRGenerator = (function () {
    const PAD0 = 0xEC;
    const PAD1 = 0x11;

    function QRBitBuffer() {
      this.buffer = [];
      this.length = 0;
    }
    QRBitBuffer.prototype = {
      get: function (index) {
        const bufIndex = Math.floor(index / 8);
        return ((this.buffer[bufIndex] >>> (7 - index % 8)) & 1) === 1;
      },
      put: function (num, length) {
        for (let i = 0; i < length; i++) {
          this.putBit(((num >>> (length - i - 1)) & 1) === 1);
        }
      },
      getLengthInBits: function () {
        return this.length;
      },
      putBit: function (bit) {
        const bufIndex = Math.floor(this.length / 8);
        if (this.buffer.length <= bufIndex) this.buffer.push(0);
        if (bit) this.buffer[bufIndex] |= (0x80 >>> (this.length % 8));
        this.length++;
      }
    };

    const QRMode = { MODE_8BIT_BYTE: 4 };
    const QRErrorCorrectLevel = { L: 1, M: 0, Q: 3, H: 2 };

    const QRUtil = {
      PATTERN_POSITION_TABLE: [
        [], [6, 18], [6, 22], [6, 26], [6, 30], [6, 34],
        [6, 22, 38], [6, 24, 42], [6, 26, 46], [6, 28, 50], [6, 30, 54]
      ],
      G15: (1 << 10) | (1 << 8) | (1 << 5) | (1 << 4) | (1 << 2) | (1 << 1) | (1 << 0),
      G15_MASK: (1 << 14) | (1 << 12) | (1 << 10) | (1 << 4) | (1 << 1),
      getBCHTypeInfo: function (data) {
        let d = data << 10;
        while (QRUtil.getBCHDigit(d) - QRUtil.getBCHDigit(QRUtil.G15) >= 0) {
          d ^= (QRUtil.G15 << (QRUtil.getBCHDigit(d) - QRUtil.getBCHDigit(QRUtil.G15)));
        }
        return ((data << 10) | d) ^ QRUtil.G15_MASK;
      },
      getBCHDigit: function (data) {
        let digit = 0;
        while (data !== 0) {
          digit++;
          data >>>= 1;
        }
        return digit;
      },
      getPatternPosition: function (typeNumber) {
        return QRUtil.PATTERN_POSITION_TABLE[typeNumber - 1] || [];
      },
      getMask: function (maskPattern, i, j) {
        switch (maskPattern) {
          case 0: return (i + j) % 2 === 0;
          case 1: return i % 2 === 0;
          case 2: return j % 3 === 0;
          case 3: return (i + j) % 3 === 0;
          case 4: return (Math.floor(i / 2) + Math.floor(j / 3)) % 2 === 0;
          case 5: return (i * j) % 2 + (i * j) % 3 === 0;
          case 6: return ((i * j) % 2 + (i * j) % 3) % 2 === 0;
          case 7: return ((i * j) % 3 + (i + j) % 2) === 0;
          default: return false;
        }
      },
      getErrorCorrectPolynomial: function (errorCorrectLength) {
        let a = new QRPolynomial([1], 0);
        for (let i = 0; i < errorCorrectLength; i++) {
          a = a.multiply(new QRPolynomial([1, QRMath.gexp(i)], 0));
        }
        return a;
      },
      getLengthInBits: function (mode, type) {
        return (type < 10) ? 8 : 16;
      }
    };

    const QRMath = {
      glog: function (n) {
        if (n < 1) throw new Error("glog(" + n + ")");
        return QRMath.LOG_TABLE[n];
      },
      gexp: function (n) {
        while (n < 0) n += 255;
        while (n >= 255) n -= 255;
        return QRMath.EXP_TABLE[n];
      },
      EXP_TABLE: new Array(256),
      LOG_TABLE: new Array(256)
    };

    for (let i = 0; i < 8; i++) QRMath.EXP_TABLE[i] = 1 << i;
    for (let i = 8; i < 256; i++) {
      QRMath.EXP_TABLE[i] = QRMath.EXP_TABLE[i - 4] ^ QRMath.EXP_TABLE[i - 5] ^ QRMath.EXP_TABLE[i - 6] ^ QRMath.EXP_TABLE[i - 8];
    }
    for (let i = 0; i < 255; i++) QRMath.LOG_TABLE[QRMath.EXP_TABLE[i]] = i;

    function QRPolynomial(num, shift) {
      if (num.length === undefined) throw new Error(num.length + "/" + shift);
      let offset = 0;
      while (offset < num.length && num[offset] === 0) offset++;
      this.num = new Array(num.length - offset + shift);
      for (let i = 0; i < num.length - offset; i++) this.num[i] = num[i + offset];
      for (let i = num.length - offset; i < this.num.length; i++) this.num[i] = 0;
    }
    QRPolynomial.prototype = {
      get: function (index) { return this.num[index]; },
      getLength: function () { return this.num.length; },
      multiply: function (e) {
        const num = new Array(this.getLength() + e.getLength() - 1);
        for (let i = 0; i < this.getLength(); i++) {
          for (let j = 0; j < e.getLength(); j++) {
            num[i + j] ^= QRMath.gexp(QRMath.glog(this.get(i)) + QRMath.glog(e.get(j)));
          }
        }
        return new QRPolynomial(num, 0);
      },
      mod: function (e) {
        if (this.getLength() - e.getLength() < 0) return this;
        const ratio = QRMath.glog(this.get(0)) - QRMath.glog(e.get(0));
        const num = new Array(this.getLength());
        for (let i = 0; i < this.getLength(); i++) num[i] = this.get(i);
        for (let i = 0; i < e.getLength(); i++) num[i] ^= QRMath.gexp(QRMath.glog(e.get(i)) + ratio);
        return new QRPolynomial(num, 0).mod(e);
      }
    };

    function QRRSBlock(totalCount, dataCount) {
      this.totalCount = totalCount;
      this.dataCount = dataCount;
    }
    QRRSBlock.RS_BLOCK_TABLE = [
      [1, 26, 19],
      [1, 44, 34],
      [1, 70, 55],
      [1, 100, 80],
      [1, 134, 108],
      [2, 86, 68],
      [2, 98, 78],
      [2, 121, 97],
      [2, 146, 116],
      [2, 86, 68, 2, 87, 69]
    ];
    QRRSBlock.getRSBlocks = function (typeNumber) {
      const rsBlock = QRRSBlock.RS_BLOCK_TABLE[typeNumber - 1];
      if (!rsBlock) throw new Error("bad rs block @ typeNumber:" + typeNumber);
      const length = rsBlock.length / 3;
      const list = [];
      for (let i = 0; i < length; i++) {
        const count = rsBlock[i * 3 + 0];
        const totalCount = rsBlock[i * 3 + 1];
        const dataCount = rsBlock[i * 3 + 2];
        for (let j = 0; j < count; j++) {
          list.push(new QRRSBlock(totalCount, dataCount));
        }
      }
      return list;
    };

    function QRCodeModel(typeNumber, errorCorrectionLevel) {
      this.typeNumber = typeNumber;
      this.errorCorrectionLevel = errorCorrectionLevel || QRErrorCorrectLevel.M;
      this.modules = null;
      this.moduleCount = 0;
      this.dataCache = null;
      this.dataList = [];
    }
    QRCodeModel.prototype = {
      addData: function (data) {
        this.dataList.push(data);
        this.dataCache = null;
      },
      isDark: function (row, col) {
        if (row < 0 || this.moduleCount <= row || col < 0 || this.moduleCount <= col) {
          throw new Error(row + "," + col);
        }
        return this.modules[row][col];
      },
      getModuleCount: function () {
        return this.moduleCount;
      },
      make: function () {
        if (this.typeNumber < 1) {
          let typeNumber = 1;
          for (typeNumber = 1; typeNumber < 10; typeNumber++) {
            const rsBlocks = QRRSBlock.getRSBlocks(typeNumber);
            let totalDataCount = 0;
            for (let i = 0; i < rsBlocks.length; i++) {
              totalDataCount += rsBlocks[i].dataCount;
            }
            let length = 0;
            for (let i = 0; i < this.dataList.length; i++) {
              length += this.dataList[i].length;
            }
            if (length <= totalDataCount - 3) break;
          }
          this.typeNumber = typeNumber;
        }
        this.makeImpl(false, this.getBestMaskPattern());
      },
      makeImpl: function (test, maskPattern) {
        this.moduleCount = this.typeNumber * 4 + 17;
        this.modules = new Array(this.moduleCount);
        for (let row = 0; row < this.moduleCount; row++) {
          this.modules[row] = new Array(this.moduleCount);
          for (let col = 0; col < this.moduleCount; col++) {
            this.modules[row][col] = null;
          }
        }
        this.setupPositionProbePattern(0, 0);
        this.setupPositionProbePattern(this.moduleCount - 7, 0);
        this.setupPositionProbePattern(0, this.moduleCount - 7);
        this.setupTimingPattern();
        this.setupTypeInfo(test, maskPattern);
        if (this.dataCache == null) {
          this.dataCache = QRCodeModel.createData(this.typeNumber, this.errorCorrectionLevel, this.dataList);
        }
        this.mapData(this.dataCache, maskPattern);
      },
      setupPositionProbePattern: function (row, col) {
        for (let r = -1; r <= 7; r++) {
          if (row + r <= -1 || this.moduleCount <= row + r) continue;
          for (let c = -1; c <= 7; c++) {
            if (col + c <= -1 || this.moduleCount <= col + c) continue;
            if ((0 <= r && r <= 6 && (c === 0 || c === 6)) ||
                (0 <= c && c <= 6 && (r === 0 || r === 6)) ||
                (2 <= r && r <= 4 && 2 <= c && c <= 4)) {
              this.modules[row + r][col + c] = true;
            } else {
              this.modules[row + r][col + c] = false;
            }
          }
        }
      },
      getBestMaskPattern: function () {
        return 0; // standard pattern
      },
      setupTimingPattern: function () {
        for (let r = 8; r < this.moduleCount - 8; r++) {
          if (this.modules[r][6] !== null) continue;
          this.modules[r][6] = (r % 2 === 0);
        }
        for (let c = 8; c < this.moduleCount - 8; c++) {
          if (this.modules[6][c] !== null) continue;
          this.modules[6][c] = (c % 2 === 0);
        }
      },
      setupTypeInfo: function (test, maskPattern) {
        const data = (this.errorCorrectionLevel << 3) | maskPattern;
        const bits = QRUtil.getBCHTypeInfo(data);
        for (let i = 0; i < 15; i++) {
          const mod = (!test && ((bits >> i) & 1) === 1);
          if (i < 6) this.modules[i][8] = mod;
          else if (i < 8) this.modules[i + 1][8] = mod;
          else this.modules[this.moduleCount - 15 + i][8] = mod;
        }
        for (let i = 0; i < 15; i++) {
          const mod = (!test && ((bits >> i) & 1) === 1);
          if (i < 8) this.modules[8][this.moduleCount - i - 1] = mod;
          else if (i < 9) this.modules[8][15 - i - 1 + 1] = mod;
          else this.modules[8][15 - i - 1] = mod;
        }
        this.modules[this.moduleCount - 8][8] = (!test);
      },
      mapData: function (data, maskPattern) {
        let inc = -1;
        let row = this.moduleCount - 1;
        let bitIndex = 7;
        let byteIndex = 0;
        for (let col = this.moduleCount - 1; col > 0; col -= 2) {
          if (col === 6) col--;
          while (true) {
            for (let c = 0; c < 2; c++) {
              if (this.modules[row][col - c] === null) {
                let dark = false;
                if (byteIndex < data.length) {
                  dark = (((data[byteIndex] >>> bitIndex) & 1) === 1);
                }
                const mask = QRUtil.getMask(maskPattern, row, col - c);
                if (mask) dark = !dark;
                this.modules[row][col - c] = dark;
                bitIndex--;
                if (bitIndex === -1) {
                  byteIndex++;
                  bitIndex = 7;
                }
              }
            }
            row += inc;
            if (row < 0 || this.moduleCount <= row) {
              row -= inc;
              inc = -inc;
              break;
            }
          }
        }
      }
    };

    QRCodeModel.createData = function (typeNumber, errorCorrectionLevel, dataList) {
      const rsBlocks = QRRSBlock.getRSBlocks(typeNumber);
      const buffer = new QRBitBuffer();
      for (let i = 0; i < dataList.length; i++) {
        const data = dataList[i];
        buffer.put(QRMode.MODE_8BIT_BYTE, 4);
        buffer.put(data.length, QRUtil.getLengthInBits(QRMode.MODE_8BIT_BYTE, typeNumber));
        for (let j = 0; j < data.length; j++) {
          buffer.put(data.charCodeAt(j), 8);
        }
      }
      let totalDataCount = 0;
      for (let i = 0; i < rsBlocks.length; i++) totalDataCount += rsBlocks[i].dataCount;
      if (buffer.getLengthInBits() > totalDataCount * 8) {
        throw new Error("code length overflow. (" + buffer.getLengthInBits() + ">" + totalDataCount * 8 + ")");
      }
      if (buffer.getLengthInBits() + 4 <= totalDataCount * 8) buffer.put(0, 4);
      while (buffer.getLengthInBits() % 8 !== 0) buffer.putBit(false);
      while (true) {
        if (buffer.getLengthInBits() >= totalDataCount * 8) break;
        buffer.put(PAD0, 8);
        if (buffer.getLengthInBits() >= totalDataCount * 8) break;
        buffer.put(PAD1, 8);
      }
      return QRCodeModel.createBytes(buffer, rsBlocks);
    };

    QRCodeModel.createBytes = function (buffer, rsBlocks) {
      let offset = 0;
      let maxDcCount = 0;
      let maxEcCount = 0;
      const dcdata = new Array(rsBlocks.length);
      const ecdata = new Array(rsBlocks.length);
      for (let r = 0; r < rsBlocks.length; r++) {
        const dcCount = rsBlocks[r].dataCount;
        const ecCount = rsBlocks[r].totalCount - dcCount;
        maxDcCount = Math.max(maxDcCount, dcCount);
        maxEcCount = Math.max(maxEcCount, ecCount);
        dcdata[r] = new Array(dcCount);
        for (let i = 0; i < dcdata[r].length; i++) {
          dcdata[r][i] = 0xff & buffer.buffer[i + offset];
        }
        offset += dcCount;
        const rsPoly = QRUtil.getErrorCorrectPolynomial(ecCount);
        const rawPoly = new QRPolynomial(dcdata[r], rsPoly.getLength() - 1);
        const modPoly = rawPoly.mod(rsPoly);
        ecdata[r] = new Array(rsPoly.getLength() - 1);
        for (let i = 0; i < ecdata[r].length; i++) {
          const modIndex = i + modPoly.getLength() - ecdata[r].length;
          ecdata[r][i] = (modIndex >= 0) ? modPoly.get(modIndex) : 0;
        }
      }
      let totalCodeCount = 0;
      for (let i = 0; i < rsBlocks.length; i++) totalCodeCount += rsBlocks[i].totalCount;
      const data = new Array(totalCodeCount);
      let index = 0;
      for (let i = 0; i < maxDcCount; i++) {
        for (let r = 0; r < rsBlocks.length; r++) {
          if (i < dcdata[r].length) data[index++] = dcdata[r][i];
        }
      }
      for (let i = 0; i < maxEcCount; i++) {
        for (let r = 0; r < rsBlocks.length; r++) {
          if (i < ecdata[r].length) data[index++] = ecdata[r][i];
        }
      }
      return data;
    };

    function generateSVG(text, moduleSize = 5, margin = 2) {
      try {
        const qr = new QRCodeModel(0, QRErrorCorrectLevel.M);
        qr.addData(text);
        qr.make();
        const count = qr.getModuleCount();
        const size = (count + margin * 2) * moduleSize;
        let rects = '';
        for (let r = 0; r < count; r++) {
          for (let c = 0; c < count; c++) {
            if (qr.isDark(r, c)) {
              const x = (c + margin) * moduleSize;
              const y = (r + margin) * moduleSize;
              rects += `<rect x="${x}" y="${y}" width="${moduleSize}" height="${moduleSize}" fill="#111827"/>`;
            }
          }
        }
        return `<svg viewBox="0 0 ${size} ${size}" width="100%" height="100%" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="QR Code to Download Sahla App"><rect width="${size}" height="${size}" fill="#FFFFFF" rx="12"/>${rects}</svg>`;
      } catch (e) {
        console.warn('QR generation error:', e);
        return `<div class="sd-qr-fallback">Scan URL: ${text}</div>`;
      }
    }

    return { generateSVG };
  })();

  // ---------------------------------------------------------------------------
  // 4. In-App & Device Detection (Shared Module)
  // ---------------------------------------------------------------------------
  // Document in a code comment that a WebView sending a plain Safari UA cannot be detected reliably.
  // Never launch custom schemes automatically on uncertain detection.
  const APPS = [
    ["Instagram",  /Instagram/i],
    ["Snapchat",   /Snapchat/i],
    ["TikTok",     /TikTok|musical_ly|BytedanceWebview|trill/i],
    ["Messenger",  /Orca-Android|FBAN\/Messenger|MessengerForiOS/i],
    ["Facebook",   /FBAN|FBAV|FB_IAB|FBIOS/i],
    ["Twitter",    /Twitter/i],
    ["LinkedIn",   /LinkedInApp/i],
    ["Pinterest",  /Pinterest/i],
    ["Line",       /Line\//i],
    ["WeChat",     /MicroMessenger/i],
    ["Threads",    /Barcelona/i],
  ];

  function detectInApp() {
    const ua = (typeof navigator !== "undefined" ? (navigator.userAgent || "") : "");
    for (const [name, re] of APPS) {
      if (re.test(ua)) return { isInApp: true, app: name, certain: true };
    }
    const isIOS = /iPhone|iPad|iPod/i.test(ua) || (typeof navigator !== "undefined" && navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1);
    if (isIOS && /AppleWebKit/i.test(ua) && !/Safari\//i.test(ua) && !/CriOS|FxiOS|EdgiOS/i.test(ua)) {
      return { isInApp: true, app: "iOS WebView", certain: false };
    }
    if (/Android/i.test(ua) && /; wv\)/i.test(ua)) {
      return { isInApp: true, app: "Android WebView", certain: false };
    }
    return { isInApp: false, app: null, certain: true };
  }

  function detectPlatform() {
    const ua = (navigator.userAgent || navigator.vendor || window.opera || '').toLowerCase();
    const platform = (navigator.platform || '').toLowerCase();

    // 1. Client Hints API (Modern Chrome/Edge on Android & Desktop)
    if (navigator.userAgentData && navigator.userAgentData.platform) {
      const uad = navigator.userAgentData.platform.toLowerCase();
      if (/android/i.test(uad)) return 'android';
      if (/ios|iphone|ipad|ipod/i.test(uad)) return 'ios';
    }

    // 2. iOS Detection (iPhone, iPod, iPad, and iPadOS/iPhone desktop-mode Safari)
    const isTouch = navigator.maxTouchPoints > 0;
    const isApplePlatform = /iphone|ipad|ipod/i.test(ua) || /iphone|ipad|ipod/i.test(platform);
    const isAppleDesktopMode = (/macintel|macintosh/i.test(platform) || /macintosh/i.test(ua)) && isTouch;
    if (isApplePlatform || isAppleDesktopMode) {
      return 'ios';
    }

    // 3. Android Detection
    if (/android/i.test(ua) || /android/i.test(platform)) {
      return 'android';
    }

    // 4. Android Desktop Mode (Linux / X11 + touch + mobile screen width)
    const isSmallTouchScreen = isTouch && (typeof window !== 'undefined' && window.innerWidth <= 840);
    if ((/linux|x11/i.test(platform) || /linux|x11/i.test(ua)) && isSmallTouchScreen) {
      return 'android';
    }

    // 5. Desktop (Windows, macOS, Linux desktop)
    if (/macintosh|macintel|win32|win64|windows|linux x86_64/i.test(platform) || /windows nt|macintosh|x11/i.test(ua)) {
      return 'desktop';
    }

    if (isSmallTouchScreen) {
      return 'android';
    }

    return 'unknown';
  }

  // ---------------------------------------------------------------------------
  // 5. Query Parameter & Deep Link Builders
  // ---------------------------------------------------------------------------
  function getPreservedParams() {
    const params = new URLSearchParams(window.location.search);
    const hash = window.location.hash || '';
    const hashQIdx = hash.indexOf('?');
    if (hashQIdx !== -1) {
      const hashParams = new URLSearchParams(hash.substring(hashQIdx + 1));
      for (const [key, val] of hashParams.entries()) {
        if (!params.has(key)) params.set(key, val);
      }
    }
    return params;
  }

  function buildDeepLinkUrl(config, params) {
    const queryString = params.toString();
    const cleanPath = (config.DEEP_LINK_PATH || '/open').replace(/^\//, '');
    const host = config.HOST || config.DOMAIN || window.location.hostname || "sahla-backend.vercel.app";

    const universalLink = `https://${host}/${cleanPath}${queryString ? '?' + queryString : ''}`;
    const uriScheme = `${config.IOS_URI_SCHEME}${cleanPath}${queryString ? '?' + queryString : ''}`;

    return { universalLink, uriScheme, cleanPath, queryString, host };
  }

  function buildStoreUrls(config, params) {
    const queryString = params.toString();

    // Android Google Play Store URL with referrer parameter
    let androidUrl = config.ANDROID_PLAY_STORE_URL;
    if (queryString) {
      const separator = androidUrl.includes('?') ? '&' : '?';
      androidUrl += `${separator}referrer=${encodeURIComponent(queryString)}`;
    }

    // iOS Apple App Store URL with campaign & provider tokens
    let iosUrl = config.IOS_APP_STORE_URL;
    if (queryString) {
      const separator = iosUrl.includes('?') ? '&' : '?';
      const utmCampaign = params.get('utm_campaign') || params.get('campaign') || 'smart_download';
      const ref = params.get('ref') || params.get('invite') || '';
      iosUrl += `${separator}ct=${encodeURIComponent(utmCampaign)}`;
      if (ref) iosUrl += `&pt=${encodeURIComponent(ref)}`;
    }

    return { androidUrl, iosUrl };
  }

  function buildChromeIntent(href) {
    const u = new URL(href);
    const fallback = encodeURIComponent(u.href);
    const dataPath = `${u.host}${u.pathname}${u.search}`;
    return `intent://${dataPath}#Intent;scheme=https;package=com.android.chrome;S.browser_fallback_url=${fallback};end`;
  }

  function showToast(message) {
    let toast = document.getElementById('sdToast');
    if (!toast) {
      toast = document.createElement('div');
      toast.id = 'sdToast';
      toast.className = 'sd-toast';
      toast.setAttribute('role', 'status');
      toast.setAttribute('aria-live', 'polite');
      document.body.appendChild(toast);
    }
    toast.textContent = message;
    toast.classList.add('is-active');
    setTimeout(() => {
      toast.classList.remove('is-active');
    }, 2800);
  }

  // ---------------------------------------------------------------------------
  // 6. Diagnostics Component (?debug=1)
  // ---------------------------------------------------------------------------
  function getBuildHash() {
    const meta = document.querySelector('meta[name="build"]');
    return (meta && meta.content) || 'dev';
  }

  function updateDiagnosticsUI() {
    const pre = document.getElementById('sdDebugPre');
    if (!pre) return;

    const inApp = detectInApp();
    const platform = detectPlatform();
    const params = getPreservedParams();
    const { androidUrl, iosUrl } = buildStoreUrls(ACTIVE_CONFIG, params);
    const { uriScheme, host } = buildDeepLinkUrl(ACTIVE_CONFIG, params);
    const cleanScheme = (ACTIVE_CONFIG.ANDROID_URI_SCHEME || 'sahla://').replace('://', '');
    const cleanPath = (ACTIVE_CONFIG.DEEP_LINK_PATH || '/open').replace(/^\//, '');
    const queryString = params.toString();
    const appIntentUrl = `intent://${cleanPath}${queryString ? '?' + queryString : ''}#Intent;scheme=${cleanScheme};package=${ACTIVE_CONFIG.ANDROID_PACKAGE};S.browser_fallback_url=${encodeURIComponent(androidUrl)};end`;
    const chromeIntentUrl = buildChromeIntent(window.location.href);

    let storageAvail = true;
    try { sessionStorage.setItem('__sd_t', '1'); sessionStorage.removeItem('__sd_t'); } catch (e) { storageAvail = false; }
    const clipboardAvail = Boolean(navigator.clipboard && navigator.clipboard.writeText);

    const info = {
      buildVersion: `v${getBuildHash()}`,
      url: window.location.href,
      pathname: window.location.pathname,
      hash: window.location.hash,
      platform,
      inAppDetected: inApp.isInApp,
      inAppName: inApp.app,
      inAppCertainty: inApp.certain,
      storageAvailable: storageAvail,
      clipboardAvailable: clipboardAvail,
      generatedHrefs: {
        appSchemeOrIntent: platform === 'ios' ? uriScheme : appIntentUrl,
        chromeEscapeIntent: chromeIntentUrl,
        iosAppStore: iosUrl,
        androidPlayStore: androidUrl,
        androidMarketScheme: `market://details?id=${ACTIVE_CONFIG.ANDROID_PACKAGE}`
      },
      userAgent: navigator.userAgent,
      recentEvents: DIAGNOSTIC_LOG
    };

    pre.textContent = JSON.stringify(info, null, 2);
  }

  window.updateDiagnosticsUI = updateDiagnosticsUI;

  // ---------------------------------------------------------------------------
  // 7. Main Controller
  // ---------------------------------------------------------------------------
  class SmartDownloadApp {
    constructor() {
      this.config = ACTIVE_CONFIG;
      this.redirectTimer = null;
      this.appOpened = false;
      this.cleanedUp = false;
    }

    init() {
      const isDownloadRoute = this.checkIsDownloadRoute();
      if (!isDownloadRoute) {
        document.body.classList.remove('route-download');
        return;
      }

      document.body.classList.add('route-download');
      this.render();
      this.startFlow();
    }

    checkIsDownloadRoute() {
      const hash = window.location.hash || '';
      const pathname = window.location.pathname || '';
      return (
        hash.startsWith('#download') ||
        pathname.startsWith('/download') ||
        pathname.startsWith('/open') ||
        (document.getElementById('download') !== null && window.location.hash.includes('download'))
      );
    }

    isBackNavigation() {
      try {
        const navEntries = (window.performance && window.performance.getEntriesByType)
          ? window.performance.getEntriesByType('navigation')
          : [];
        if (navEntries.length > 0 && navEntries[0].type === 'back_forward') {
          return true;
        }

        const lastRedirect = safeSession.get('sd_redirect_ts');
        if (lastRedirect) {
          const elapsed = Date.now() - Number(lastRedirect);
          if (elapsed < 15000) {
            return true;
          }
        }
      } catch (e) {}
      return false;
    }

    render() {
      const lang = getCurrentLang();
      const t = STRINGS[lang] || STRINGS.ar;
      const platform = detectPlatform();
      const inApp = detectInApp();
      const params = getPreservedParams();
      const { androidUrl, iosUrl } = buildStoreUrls(this.config, params);
      const { universalLink, uriScheme, cleanPath, host } = buildDeepLinkUrl(this.config, params);

      track('download_page_view', { platform, isInApp: inApp.isInApp, app: inApp.app });
      sendDownloadTracking('platform_detected', { platform, inApp: inApp.app });
      if (inApp.isInApp) {
        track('inapp_browser_detected', { app: inApp.app, platform });
      }

      const section = document.getElementById('download');
      if (!section) return;

      document.documentElement.dir = t.dir;
      document.documentElement.lang = lang;

      const queryString = params.toString() ? '?' + params.toString() : '';
      const fullDownloadUrl = window.location.href;
      const buildHash = getBuildHash();

      // -----------------------------------------------------------------------
      // MODE A: IN-APP BROWSER (Instagram, Snapchat, TikTok, Facebook, etc.)
      // -----------------------------------------------------------------------
      let inAppBannerHtml = '';
      let statusCardHtml = '';
      let manualOpenBtnHtml = '';
      let inAppStorePromptHtml = '';
      let marketFallbackHtml = '';

      if (inApp.isInApp) {
        // Platform-specific instructions for in-app browsers
        let instructions = '';
        if (platform === 'ios') {
          if (inApp.app === 'Instagram') {
            instructions = t.inAppNoticeInstagram;
          } else if (inApp.app === 'Snapchat') {
            instructions = t.inAppNoticeSnapchat;
          } else {
            instructions = t.inAppNoticeIosGeneric(inApp.app || 'التطبيق');
          }
        } else {
          instructions = t.inAppNoticeAndroid(inApp.app || 'التطبيق');
        }

        // Action buttons inside in-app banner (Same tab, no target="_blank")
        let inAppActionsHtml = '';
        if (platform === 'android') {
          const chromeIntentUrl = buildChromeIntent(window.location.href);
          inAppActionsHtml = `
            <a href="${chromeIntentUrl}" class="sd-inapp-btn sd-btn-chrome" id="sdEscapeBtn" rel="noopener">
              <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"><circle cx="12" cy="12" r="10"/><circle cx="12" cy="12" r="4"/><line x1="21.17" y1="8" x2="12" y2="8"/><line x1="3.95" y1="6.06" x2="8.54" y2="14"/><line x1="10.88" y1="21.94" x2="15.46" y2="14"/></svg>
              <span>${t.openInChromeBtn}</span>
            </a>
            <button class="sd-inapp-btn sd-btn-copy" id="sdInAppCopyBtn" type="button">
              <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
              <span>${t.copyDownloadLink}</span>
            </button>
          `;
        } else {
          // iOS in-app mode: provide copy-link with manual copy fallback rather than undocumented browser schemes.
          inAppActionsHtml = `
            <button class="sd-inapp-btn sd-btn-copy" id="sdInAppCopyBtn" type="button">
              <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
              <span>${t.copyDownloadLink}</span>
            </button>
          `;
        }

        inAppBannerHtml = `
          <div class="sd-inapp-banner is-visible" id="sdInAppBanner" role="alert">
            <div class="sd-inapp-header">
              <svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M10.29 3.86L1.82 18a2 2 0 0 0 1.71 3h16.94a2 2 0 0 0 1.71-3L13.71 3.86a2 2 0 0 0-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg>
              <span>هل تتصفح من داخل تطبيق تواصل؟ (${inApp.app || ''})</span>
            </div>
            <p class="sd-inapp-desc">${instructions}</p>
            <div class="sd-inapp-actions">
              ${inAppActionsHtml}
            </div>
            <div class="sd-manual-copy-box" id="sdManualCopyBox" style="display:none;">
              <label class="sd-manual-copy-label" for="sdManualCopyInput">${t.copyManualLabel}</label>
              <input type="text" class="sd-manual-copy-input" id="sdManualCopyInput" readonly value="${fullDownloadUrl}">
            </div>
          </div>
        `;

        // Tap-initiated "Open Sahla" button in in-app mode
        manualOpenBtnHtml = `
          <button type="button" class="sd-btn-open-app sd-btn-inapp-primary" id="sdInAppOpenAppBtn">
            <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
              <rect x="5" y="2" width="14" height="20" rx="3" ry="3"/>
              <line x1="12" y1="18" x2="12.01" y2="18"/>
            </svg>
            <span>${t.openAppBtn}</span>
          </button>
          <div id="sdInAppStoreHighlight" class="sd-inapp-store-highlight" style="display:none;" role="status">
            <span>${t.inAppStoreHint}</span>
          </div>
        `;

        inAppStorePromptHtml = `<p class="sd-store-prompt">${t.storePromptInApp}</p>`;

        if (platform === 'android') {
          marketFallbackHtml = `
            <div class="sd-market-row">
              <a href="market://details?id=${this.config.ANDROID_PACKAGE}" class="sd-btn-market" id="sdMarketBtn" rel="noopener">${t.openInPlayMarket}</a>
            </div>
          `;
        }
      } else {
        // ---------------------------------------------------------------------
        // MODE B: NORMAL MOBILE BROWSERS (Safari, Chrome, etc.)
        // ---------------------------------------------------------------------
        const isMobile = platform === 'ios' || platform === 'android';
        const isAttempted = safeSession.get('dl_attempted') === 'true' || this.isBackNavigation();

        if (isMobile) {
          statusCardHtml = `
            <div class="sd-status-card" id="sdStatusCard" aria-live="polite">
              ${isAttempted ? `
                <h2 class="sd-status-title" id="sdStatusTitle">${t.fallbackTitle}</h2>
                <p class="sd-status-desc" id="sdStatusDesc">${t.fallbackDesc}</p>
                <div class="sd-retry-row">
                  <button class="sd-btn-retry" id="sdRetryBtn" type="button">${t.tryAgain}</button>
                </div>
              ` : `
                <div class="sd-spinner-wrap" id="sdSpinnerWrap">
                  <div class="sd-spinner"></div>
                  <div class="sd-spinner-inner"></div>
                </div>
                <h2 class="sd-status-title" id="sdStatusTitle">${t.openingTitle}</h2>
                <p class="sd-status-desc" id="sdStatusDesc">${t.openingDesc}</p>
                <div class="sd-prompt-tip" id="sdPromptTip">
                  <span>${t.promptTip}</span>
                </div>
              `}
            </div>
          `;

          // Manual Open App Button in Normal Browser
          const cleanScheme = (this.config.ANDROID_URI_SCHEME || 'sahla://').replace('://', '');
          const intentUrl = `intent://${cleanPath}#Intent;scheme=${cleanScheme};package=${this.config.ANDROID_PACKAGE};S.browser_fallback_url=${encodeURIComponent(androidUrl)};end`;
          manualOpenBtnHtml = `
            <a href="${platform === 'ios' ? uriScheme : intentUrl}" class="sd-btn-open-app" id="sdManualOpenBtn" style="display:flex;">
              <svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round">
                <rect x="5" y="2" width="14" height="20" rx="3" ry="3"/>
                <line x1="12" y1="18" x2="12.01" y2="18"/>
              </svg>
              <span>${t.openAppBtn}</span>
            </a>
          `;
        }
      }

      // Store Badges (No target="_blank" in in-app mode to avoid WebView link swallow)
      const targetAttr = inApp.isInApp ? '' : 'target="_blank"';
      const appStoreBadgeHtml = `
        <a href="${iosUrl}" class="sd-store-badge" id="sdAppStoreBtn" ${targetAttr} rel="noopener" aria-label="Download on Apple App Store">
          <svg class="sd-badge-icon" viewBox="0 0 24 24"><path d="M18.71 19.5c-.83 1.24-1.71 2.45-3.05 2.47-1.34.03-1.77-.79-3.29-.79-1.53 0-2 .77-3.27.82-1.31.05-2.3-1.32-3.14-2.53C4.25 17 2.94 12.45 4.7 9.39c.87-1.52 2.43-2.48 4.12-2.51 1.28-.02 2.5.87 3.29.87.78 0 2.26-1.07 3.81-.91.65.03 2.47.26 3.64 1.98-.09.06-2.17 1.28-2.15 3.81.03 3.02 2.65 4.03 2.68 4.04-.03.07-.42 1.44-1.38 2.83M15.97 6.37c.62-.75 1.04-1.8 0.92-2.85-.9.04-1.99.6-2.61 1.34-.55.63-1.03 1.68-.9 2.7.99.08 2.02-.44 2.59-1.19z"/></svg>
          <div class="sd-badge-text-wrap">
            <span class="sd-badge-sub">${t.downloadOnAppStoreSub}</span>
            <span class="sd-badge-main">${t.appStore}</span>
          </div>
        </a>
      `;

      const playStoreBadgeHtml = `
        <a href="${androidUrl}" class="sd-store-badge" id="sdPlayStoreBtn" ${targetAttr} rel="noopener" aria-label="Get it on Google Play">
          <svg class="sd-badge-icon" viewBox="0 0 24 24"><path d="M3,20.5V3.5C3,2.91 3.34,2.39 3.84,2.15L13.69,12L3.84,21.85C3.34,21.6 3,21.09 3,20.5M16.81,15.12L6.05,21.34L14.54,12.85L16.81,15.12M20.16,10.81C20.5,11.08 20.75,11.5 20.75,12C20.75,12.5 20.53,12.9 20.18,13.18L17.89,14.5L15.39,12L17.89,9.5L20.16,10.81M6.05,2.66L16.81,8.88L14.54,11.15L6.05,2.66Z"/></svg>
          <div class="sd-badge-text-wrap">
            <span class="sd-badge-sub">${t.getItOnPlayStoreSub}</span>
            <span class="sd-badge-main">${t.googlePlay}</span>
          </div>
        </a>
      `;

      const badgesGroupHtml = (platform === 'android')
        ? `${playStoreBadgeHtml}${appStoreBadgeHtml}`
        : `${appStoreBadgeHtml}${playStoreBadgeHtml}`;

      // Optional Android Fallbacks
      let fallbacksHtml = '';
      if (platform === 'android' && this.config.OPTIONAL_ANDROID_FALLBACKS) {
        const { appGallery, directApk } = this.config.OPTIONAL_ANDROID_FALLBACKS;
        if (appGallery || directApk) {
          fallbacksHtml = `
            <div class="sd-fallbacks-row">
              ${appGallery ? `<a href="${appGallery}" class="sd-btn-fallback" target="_blank" rel="noopener">Huawei AppGallery</a>` : ''}
              ${directApk ? `<a href="${directApk}" class="sd-btn-fallback" download>Download APK</a>` : ''}
            </div>
          `;
        }
      }

      // Generate client-side QR SVG pointing to current URL
      const qrSvg = QRGenerator.generateSVG(fullDownloadUrl, 5, 2);

      // Diagnostics Panel HTML (Only if ?debug=1)
      const isDebug = window.location.search.includes('debug=1');
      let debugHtml = '';
      if (isDebug) {
        debugHtml = `
          <details class="sd-debug-panel" id="sdDebugPanel" dir="ltr">
            <summary><strong>🛠️ Sahla Diagnostics (Build v${buildHash})</strong></summary>
            <pre class="sd-debug-pre" id="sdDebugPre">Initializing diagnostics...</pre>
            <div class="sd-debug-actions">
              <button type="button" class="sd-debug-btn" id="sdDebugCopyBtn">Copy Diagnostics</button>
            </div>
          </details>
        `;
      }

      // Assemble full DOM
      section.innerHTML = `
        <div class="sd-container">
          <header class="sd-topbar">
            <a href="#home" class="sd-logo-link" id="sdHomeLink" aria-label="${this.config.APP_NAME}">
              <img src="${this.config.BRAND.logoPath || '/logo.webp'}" alt="${this.config.APP_NAME}" class="sd-logo-img">
            </a>
            <a href="#home" class="sd-back-btn" id="sdBackBtn">
              <span>${t.backToWeb}</span>
              <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round">
                ${t.dir === 'rtl' ? '<path d="M9 18l6-6-6-6"/>' : '<path d="M15 18l-6-6 6-6"/>'}
              </svg>
            </a>
          </header>

          ${inAppBannerHtml}

          <main class="sd-grid">
            <div class="sd-hero">
              <div class="sd-app-icon-wrap">
                <img src="${this.config.BRAND.logoPath || '/logo.webp'}" alt="${this.config.APP_NAME}" class="sd-app-icon-img">
              </div>

              <div class="sd-badge-tag">
                <svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor"><path d="M12 2l3.09 6.26L22 9.27l-5 4.87 1.18 6.88L12 17.77l-6.18 3.25L7 14.14 2 9.27l6.91-1.01L12 2z"/></svg>
                <span>${t.badge}</span>
              </div>

              <h1 class="sd-title">${t.title}</h1>
              <p class="sd-tagline">${t.tagline}</p>

              ${statusCardHtml}
              ${manualOpenBtnHtml}
              ${inAppStorePromptHtml}

              <div class="sd-badges-group">
                ${badgesGroupHtml}
              </div>

              ${marketFallbackHtml}
              ${fallbacksHtml}
            </div>

            <aside class="sd-desktop-card" aria-label="Desktop installation tools">
              <div class="sd-qr-section">
                <div class="sd-qr-box" id="sdQrBox" aria-hidden="true">
                  ${qrSvg}
                </div>
                <h3 class="sd-qr-label">${t.qrLabel}</h3>
                <p class="sd-qr-sub">${t.qrSub}</p>
              </div>

              <div class="sd-send-section">
                <div class="sd-copy-row">
                  <span class="sd-copy-url" id="sdCopyUrl">${fullDownloadUrl}</span>
                  <button type="button" class="sd-btn-copy" id="sdCopyBtn">
                    <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><rect x="9" y="9" width="13" height="13" rx="2" ry="2"/><path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"/></svg>
                    ${t.copyBtn}
                  </button>
                </div>
              </div>
            </aside>
          </main>

          <footer class="sd-footer">
            <span class="sd-build-tag">Sahla v${buildHash}</span>
          </footer>

          ${debugHtml}
        </div>
      `;

      this.bindEvents(fullDownloadUrl, t);
      if (isDebug) {
        updateDiagnosticsUI();
      }
    }

    bindEvents(fullDownloadUrl, t) {
      const platform = detectPlatform();
      const inApp = detectInApp();
      const params = getPreservedParams();
      const queryString = params.toString();
      const { androidUrl, iosUrl } = buildStoreUrls(this.config, params);

      // In-app copy button with visible input fallback
      const inAppCopyBtn = document.getElementById('sdInAppCopyBtn');
      if (inAppCopyBtn) {
        inAppCopyBtn.addEventListener('click', async () => {
          track('copy_link_click', { inApp: true });
          const success = await copyText(fullDownloadUrl);
          if (success) {
            showToast(t.copiedToast);
          } else {
            track('copy_fallback_shown', { url: fullDownloadUrl });
            const box = document.getElementById('sdManualCopyBox');
            const input = document.getElementById('sdManualCopyInput');
            if (box && input) {
              box.style.display = 'block';
              input.focus();
              input.select();
            }
          }
        });
      }

      // Tap-initiated "Open Sahla" in In-App WebView
      const inAppOpenBtn = document.getElementById('sdInAppOpenAppBtn');
      if (inAppOpenBtn) {
        let isTapping = false;
        inAppOpenBtn.addEventListener('click', (e) => {
          e.preventDefault();
          if (isTapping) return;
          isTapping = true;
          track('app_open_tap', { platform, app: inApp.app });

          // 1. Trigger native scheme/intent navigation in same tab
          if (platform === 'ios') {
            const iosAppUrl = `${this.config.IOS_URI_SCHEME}open${queryString ? '?' + queryString : ''}`;
            safeNavigate(iosAppUrl);
          } else {
            const cleanScheme = (this.config.ANDROID_URI_SCHEME || 'sahla://').replace('://', '');
            const cleanPath = (this.config.DEEP_LINK_PATH || '/open').replace(/^\//, '');
            const appIntentUrl = `intent://${cleanPath}${queryString ? '?' + queryString : ''}#Intent;scheme=${cleanScheme};package=${this.config.ANDROID_PACKAGE};S.browser_fallback_url=${encodeURIComponent(androidUrl)};end`;
            safeNavigate(appIntentUrl);
          }

          // 2. Lifecycle detection: if app opens, pagehide / visibilitychange fires
          let timeoutId = null;
          let opened = false;

          const onAppOpened = () => {
            if (opened) return;
            opened = true;
            if (timeoutId) clearTimeout(timeoutId);
            cleanup();
          };

          const onVis = () => { if (document.hidden) onAppOpened(); };
          const onHide = () => onAppOpened();
          const onBlur = () => onAppOpened();

          document.addEventListener('visibilitychange', onVis);
          window.addEventListener('pagehide', onHide);
          window.addEventListener('blur', onBlur);

          const cleanup = () => {
            document.removeEventListener('visibilitychange', onVis);
            window.removeEventListener('pagehide', onHide);
            window.removeEventListener('blur', onBlur);
          };

          // 3. Timeout check: if still visible after tap, show store hint (DO NOT redirect automatically!)
          timeoutId = setTimeout(() => {
            cleanup();
            isTapping = false;
            if (!opened && !document.hidden) {
              track('app_open_timeout', { platform, app: inApp.app });
              const hintEl = document.getElementById('sdInAppStoreHighlight');
              if (hintEl) hintEl.style.display = 'block';
              const badgesWrap = document.querySelector('.sd-badges-group');
              if (badgesWrap) badgesWrap.classList.add('is-highlighted');
            }
          }, 1800);

          window.addEventListener('pageshow', () => {
            isTapping = false;
            cleanup();
            if (timeoutId) clearTimeout(timeoutId);
          }, { once: true });
        });
      }

      // Escape button tracking (Android Chrome Intent)
      const escapeBtn = document.getElementById('sdEscapeBtn');
      if (escapeBtn) {
        escapeBtn.addEventListener('click', () => {
          if (platform === 'android') {
            track('chrome_escape_tap', { platform, url: escapeBtn.getAttribute('href') });
          }
        });
      }

      // Desktop copy button
      const copyBtn = document.getElementById('sdCopyBtn');
      if (copyBtn) {
        copyBtn.addEventListener('click', async () => {
          track('copy_link_click', { inApp: false });
          const success = await copyText(fullDownloadUrl);
          if (success) {
            showToast(t.copiedToast);
          } else {
            track('copy_fallback_shown', { url: fullDownloadUrl });
          }
        });
      }

      // Store buttons tracking
      const appStoreBtn = document.getElementById('sdAppStoreBtn');
      if (appStoreBtn) {
        appStoreBtn.addEventListener('click', () => {
          track('store_tap', { store: 'app_store', inApp: inApp.isInApp });
        });
      }

      const playStoreBtn = document.getElementById('sdPlayStoreBtn');
      if (playStoreBtn) {
        playStoreBtn.addEventListener('click', () => {
          track('store_tap', { store: 'google_play', inApp: inApp.isInApp });
        });
      }

      const marketBtn = document.getElementById('sdMarketBtn');
      if (marketBtn) {
        marketBtn.addEventListener('click', () => {
          track('store_tap', { store: 'android_market', inApp: inApp.isInApp });
        });
      }

      const manualOpenBtn = document.getElementById('sdManualOpenBtn');
      if (manualOpenBtn) {
        manualOpenBtn.addEventListener('click', () => {
          track('app_open_tap', { platform, type: 'normal_manual' });
        });
      }

      // Retry auto-open button
      const retryBtn = document.getElementById('sdRetryBtn');
      if (retryBtn) {
        retryBtn.addEventListener('click', () => {
          safeSession.del('dl_attempted');
          safeSession.del('sd_redirect_ts');
          track('app_open_tap', { platform, type: 'retry' });
          this.render();
          this.startFlow(true);
        });
      }

      // Diagnostics Copy Button
      const debugCopyBtn = document.getElementById('sdDebugCopyBtn');
      if (debugCopyBtn) {
        debugCopyBtn.addEventListener('click', async () => {
          const pre = document.getElementById('sdDebugPre');
          if (pre) {
            await copyText(pre.textContent);
            showToast('Diagnostics copied to clipboard! ✓');
          }
        });
      }

    }

    startFlow(force = false) {
      const platform = detectPlatform();
      const inApp = detectInApp();
      const params = getPreservedParams();
      const lang = getCurrentLang();
      const t = STRINGS[lang] || STRINGS.ar;
      const { androidUrl, iosUrl } = buildStoreUrls(this.config, params);
      const { uriScheme, cleanPath } = buildDeepLinkUrl(this.config, params);

      // -----------------------------------------------------------------------
      // RULE A: IN-APP BROWSER MODE
      // One best-effort app attempt, then the platform store if the app did not open.
      // ?auto=0 disables the automatic flow and leaves the manual controls available.
      // -----------------------------------------------------------------------
      if (inApp.isInApp) {
        track('inapp_browser_detected', { app: inApp.app, platform });
        const autoParam = new URLSearchParams(window.location.search).get('auto');
        const attemptKey = `sd_inapp_autolaunch:${window.location.pathname}`;
        const shouldAttempt = autoParam !== '0' &&
          (autoParam === '1' || this.config.AUTO_OPEN_IN_APP === true) &&
          (autoParam === '1' || safeSession.get(attemptKey) !== '1');
        if (shouldAttempt) {
          safeSession.set(attemptKey, '1');
          track('inapp_auto_open_attempt', { platform, app: inApp.app });
          const queryString = params.toString();
          const storeUrl = platform === 'ios' ? iosUrl : androidUrl;
          let appOpened = false;
          let cleanedUp = false;
          const cleanup = () => {
            if (cleanedUp) return;
            cleanedUp = true;
            document.removeEventListener('visibilitychange', onVisibilityChange);
            window.removeEventListener('pagehide', onPageHide);
          };
          const onAppOpened = () => {
            if (appOpened) return;
            appOpened = true;
            clearTimeout(fallbackTimer);
            cleanup();
            track('inapp_app_opened', { platform, app: inApp.app });
          };
          const onVisibilityChange = () => {
            if (document.hidden) onAppOpened();
          };
          const onPageHide = () => onAppOpened();
          document.addEventListener('visibilitychange', onVisibilityChange);
          window.addEventListener('pagehide', onPageHide);
          const fallbackTimer = setTimeout(() => {
            if (appOpened || document.hidden) return;
            cleanup();
            track('inapp_store_fallback', { platform, app: inApp.app, target: storeUrl });
            window.location.replace(storeUrl);
          }, Number(this.config.OPEN_TIMEOUT_MS) || 3000);

          if (platform === 'ios') {
            safeNavigate(`${this.config.IOS_URI_SCHEME}open${queryString ? '?' + queryString : ''}`);
          } else if (platform === 'android') {
            const cleanScheme = (this.config.ANDROID_URI_SCHEME || 'sahla://').replace('://', '');
            const intentUrl = `intent://${cleanPath}${queryString ? '?' + queryString : ''}#Intent;scheme=${cleanScheme};package=${this.config.ANDROID_PACKAGE};S.browser_fallback_url=${encodeURIComponent(androidUrl)};end`;
            safeNavigate(intentUrl);
          }
        }
        return; // HALT IMMEDIATELY. User controls are rendered for tap interaction.
      }

      // -----------------------------------------------------------------------
      // RULE C: DESKTOP / UNKNOWN
      // ZERO AUTO-NAVIGATION.
      // -----------------------------------------------------------------------
      if (platform !== 'ios' && platform !== 'android') {
        return;
      }

      // -----------------------------------------------------------------------
      // RULE B: NORMAL MOBILE BROWSERS (Safari, Chrome, etc.)
      // -----------------------------------------------------------------------
      if (!force && (safeSession.get('dl_attempted') === 'true' || this.isBackNavigation())) {
        this.updateStatus({
          title: t.fallbackTitle,
          desc: t.fallbackDesc,
          isOpening: false,
          showTip: false,
          showRetry: true
        });
        return;
      }

      this.appOpened = false;
      this.cleanedUp = false;
      track('app_open_tap', { platform, type: 'auto_normal' });

      // Show opening status with prompt tip on initial normal mobile load
      this.updateStatus({
        title: t.openingTitle,
        desc: t.openingDesc,
        isOpening: true,
        showTip: true,
        showRetry: false
      });

      const storeUrl = platform === 'ios' ? iosUrl : androidUrl;
      const cleanScheme = (this.config.ANDROID_URI_SCHEME || 'sahla://').replace('://', '');
      const intentUrl = `intent://${cleanPath}#Intent;scheme=${cleanScheme};package=${this.config.ANDROID_PACKAGE};S.browser_fallback_url=${encodeURIComponent(androidUrl)};end`;

      const timeoutMs = Number(this.config.OPEN_TIMEOUT_MS) || 3000;

      const onAppOpenDetected = () => {
        if (this.appOpened) return;
        this.appOpened = true;
        this.cleanupListeners();
        clearTimeout(this.redirectTimer);
        track('app_opened_likely', { platform, app: inApp.app });

        this.updateStatus({
          title: t.openedTitle,
          desc: t.openedDesc,
          isOpening: false,
          showTip: false,
          showRetry: true
        });
      };

      const handleVisibilityChange = () => {
        if (document.hidden) onAppOpenDetected();
      };
      const handlePageHide = () => onAppOpenDetected();
      const handleBlur = () => onAppOpenDetected();

      document.addEventListener('visibilitychange', handleVisibilityChange);
      window.addEventListener('pagehide', handlePageHide);
      window.addEventListener('blur', handleBlur);

      this.cleanupListeners = () => {
        if (this.cleanedUp) return;
        this.cleanedUp = true;
        document.removeEventListener('visibilitychange', handleVisibilityChange);
        window.removeEventListener('pagehide', handlePageHide);
        window.removeEventListener('blur', handleBlur);
      };

      this.redirectTimer = setTimeout(() => {
        if (this.appOpened || document.hidden) return;

        this.cleanupListeners();
        track('app_open_timeout', { platform, target: storeUrl });

        safeSession.set('dl_attempted', 'true');
        safeSession.set('sd_redirect_ts', String(Date.now()));

        const redirectTitle = platform === 'ios' ? t.redirectingTitleIos : t.redirectingTitleAndroid;
        this.updateStatus({
          title: redirectTitle,
          desc: t.redirectingDesc,
          isOpening: true,
          showTip: false
        });

        setTimeout(() => {
          window.location.replace(storeUrl);
        }, 150);
      }, timeoutMs);

      // Trigger native handshake in normal browsers
      if (platform === 'ios') {
        safeNavigate(uriScheme);
      } else if (platform === 'android') {
        safeNavigate(intentUrl);
      }
    }

    updateStatus({ title, desc, isOpening = false, showTip = false, showRetry = false }) {
      const titleEl = document.getElementById('sdStatusTitle');
      const descEl = document.getElementById('sdStatusDesc');
      const spinnerEl = document.getElementById('sdSpinnerWrap');
      const tipEl = document.getElementById('sdPromptTip');
      const cardEl = document.getElementById('sdStatusCard');

      if (titleEl) titleEl.textContent = title;
      if (descEl) descEl.textContent = desc;
      if (spinnerEl) spinnerEl.style.display = isOpening ? 'block' : 'none';
      if (tipEl) tipEl.style.display = showTip ? 'inline-flex' : 'none';

      if (showRetry && cardEl && !document.getElementById('sdRetryBtn')) {
        const lang = getCurrentLang();
        const t = STRINGS[lang] || STRINGS.ar;
        const retryDiv = document.createElement('div');
        retryDiv.className = 'sd-retry-row';
        retryDiv.innerHTML = `<button class="sd-btn-retry" id="sdRetryBtn" type="button">${t.tryAgain}</button>`;
        cardEl.appendChild(retryDiv);
        const btn = document.getElementById('sdRetryBtn');
        if (btn) {
          btn.addEventListener('click', () => {
            safeSession.del('dl_attempted');
            safeSession.del('sd_redirect_ts');
          track('retry_tap', { platform, app: inApp.app });
            this.render();
            this.startFlow(true);
          });
        }
      }
    }
  }

  // ---------------------------------------------------------------------------
  // 8. Bootstrap
  // ---------------------------------------------------------------------------
  const app = new SmartDownloadApp();

  function onRouteChanged() {
    app.init();
  }

  window.addEventListener('hashchange', onRouteChanged);

  window.addEventListener('pageshow', (e) => {
    if (e.persisted) {
      app.render();
    }
  });

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', onRouteChanged);
  } else {
    onRouteChanged();
  }

  window.SmartDownload = app;
  window.detectPlatform = detectPlatform;
  window.detectInApp = detectInApp;
  window.buildChromeIntent = buildChromeIntent;
  window.safeSession = safeSession;
  window.copyText = copyText;
  window.generateQrSvg = (text, size, margin) => QRGenerator.generateSVG(text, size, margin);
  window.track = track;
})();
