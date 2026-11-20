/**
 * =============================================================================
 * Smart Download Configuration
 * =============================================================================
 * Single Source of Truth for App Identifiers, Deep Links, Fallbacks & Branding.
 * Configured specifically for Sahla (Algeria).
 * =============================================================================
 */

const CONFIG = {
  // App Identifiers & Web Domain
  APP_NAME: "Sahla",
  DOMAIN: "sahla-backend.vercel.app",

  // iOS App Configuration (App Store ID: 6834895657, New Team: 9P628XCQ94)
  IOS_APP_STORE_URL: "https://apps.apple.com/dz/app/sahla-algerie/id6834895657",
  IOS_BUNDLE_ID: "com.sahla.sahlaalgerie",
  IOS_TEAM_ID: "9P628XCQ94",
  IOS_URI_SCHEME: "sahla://",

  // Android App Configuration (Package: com.godigital.sahla)
  ANDROID_PLAY_STORE_URL: "https://play.google.com/store/apps/details?id=com.godigital.sahla",
  ANDROID_PACKAGE: "com.godigital.sahla",
  ANDROID_URI_SCHEME: "sahla://",
  ANDROID_SHA256_CERT_FINGERPRINT: "35:5A:0E:B6:87:F5:F1:98:3C:59:0D:0A:86:52:83:5B:02:CD:AC:9C:22:A7:6D:5C:9C:BC:E4:51:DA:96:93:F4",

  // Optional Android Alternative Stores / Direct APK (shown as secondary options if filled)
  OPTIONAL_ANDROID_FALLBACKS: {
    appGallery: "",
    directApk: ""
  },

  // Deep Link Route inside the App & Timeout Duration
  DEEP_LINK_PATH: "/open",
  OPEN_TIMEOUT_MS: 3000,

  // Branding & Assets
  BRAND: {
    primaryColor: "#FEB405",
    primaryDarkColor: "#E09E00",
    backgroundColor: "#FFFFFF",
    textColor: "#1F2937",
    logoPath: "logo.webp",
    appName: "Sahla",
    tagline: "أفضل المأكولات والمطاعم في ولاية بسكرة تصلك لباب منزلك بكل سهولة وسرعة",
    screenshots: [
      "hero-image.png",
      "main.webp"
    ]
  }
};

// Expose configuration globally on window and export for CommonJS/ESM environments
if (typeof window !== "undefined") {
  window.CONFIG = CONFIG;
}
if (typeof module !== "undefined" && module.exports) {
  module.exports = CONFIG;
}
