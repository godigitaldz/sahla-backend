# Smart App Download & Deep Linking System — Sahla (Algeria)

Production-ready smart download gateway and deep linking infrastructure for **Sahla** (`https://sahla-backend.vercel.app/#download` as well as `/download` and `/open`).

When a visitor lands on the page, the system detects their device and environment:
1. **Normal Mobile Browsers (Safari, Chrome):** Attempts native app launch handshake, monitors visibility, and falls back to App Store / Google Play within `2200ms` if the app is not installed.
2. **In-App Social Media WebViews (Instagram, Snapchat, TikTok, Facebook, etc.):** In-app browsers block scripted redirects and custom schemes. The page activates a dedicated In-App mode with zero timeouts, zero auto-redirects, real tap `<a href>` store badges, platform-tailored open-in-browser steps, and a 1-tap copy link button.
3. **Desktop:** Renders client-side QR code SVG and "Send link to my phone" tool with zero auto-redirection.

---

## ⚠️ CRITICAL NOTICE: Custom Domain Required for Universal Links & App Links

> [!IMPORTANT]
> **Universal Links (iOS) and Android App Links will NOT function reliably on a shared domain like `*.vercel.app`.**
> 
> - **Apple's CDN Validation:** Apple resolves Associated Domains via `https://app-site-association.cdn-apple.com/a/v1/<domain>`. Apple frequently throttles, flags, or refuses to cache AASA files on shared platform subdomains (like `*.vercel.app` or `*.herokuapp.com`). Furthermore, iOS requires matching applinks entitlements to an authoritative domain owned by the developer.
> - **Google Digital Asset Links:** Google's Intent verification bot checks domain ownership against Google Search Console and DNS records.
> 
> **Solution:** Attach a custom subdomain that you own (e.g., `get.sahla.dz`, `app.sahla.dz`, or `go.sahla-app.com`) to this Vercel project:
> 
> ### Steps to Attach Custom Domain on Vercel:
> 1. Open the [Vercel Dashboard](https://vercel.com) &rarr; Select the `sahla-backend` project.
> 2. Go to **Settings** &rarr; **Domains**.
> 3. Enter your domain (e.g., `get.sahla.dz`).
> 4. In your DNS provider (Cloudflare, cPanel, or registrar), add the required DNS record:
>    - **CNAME Record:** `get.sahla.dz` &rarr; `cname.vercel-dns.com`
> 5. Wait for Vercel to issue the automatic Let's Encrypt SSL certificate.
> 6. Update `HOST` in `public/config.js` and `public/download.js` to `get.sahla.dz`.
> 7. Update your iOS entitlements (`applinks:get.sahla.dz`) and AndroidManifest.xml (`android:host="get.sahla.dz"`).

---

## 📱 Production Identity & Deep Link Tokens

| Parameter | Production Value | Source / Verification |
| :--- | :--- | :--- |
| **App Name** | `Sahla` (`سهلة`) | Official Brand |
| **Host Domain** | `sahla-backend.vercel.app` (or custom `get.sahla.dz`) | Config `HOST` |
| **iOS Bundle Identifier** | `com.sahla.sahlaalgerie` | App Store Release Target |
| **Apple Developer Team ID** | `9P628XCQ94` | Apple Developer Membership |
| **Apple App Store URL** | `https://apps.apple.com/dz/app/sahla-algerie/id6834895657` | Apple App Store (ID `6834895657`) |
| **Android Package Name** | `com.godigital.sahla` | `build.gradle.kts` / AndroidManifest.xml |
| **Google Play Store URL** | `https://play.google.com/store/apps/details?id=com.godigital.sahla` | Google Play Store |
| **Custom URI Scheme** | `sahla://` | `Info.plist` & `AndroidManifest.xml` |
| **Release Signing Fingerprint (SHA256)** | `35:5A:0E:B6:87:F5:F1:98:3C:59:0D:0A:86:52:83:5B:02:CD:AC:9C:22:A7:6D:5C:9C:BC:E4:51:DA:96:93:F4` | Keystore `/Users/macamine/sahla-release-key.jks` |
| **Debug Signing Fingerprint (SHA256)** | `83:F0:97:BF:F1:C0:B6:48:C2:0E:7F:08:C0:BB:1C:E7:6D:25:F8:45:2B:71:73:DA:E3:69:6D:8D:A6:89:11:7B` | Local `~/.android/debug.keystore` |
| **Deep Link In-App Path** | `/open` | App router (`DEEP_LINK_PATH`) |
| **Open Timeout** | `2200ms` | Config `OPEN_TIMEOUT_MS` |

---

## 📁 File Structure

```text
sahla-backend/
├── public/
│   ├── .well-known/
│   │   ├── apple-app-site-association   # iOS Universal Links & Credentials (served as application/json)
│   │   └── assetlinks.json              # Android App Links Digital Asset Verification (served as application/json)
│   ├── config.js                        # Single source of truth configuration
│   ├── download.css                     # Mobile-first stylesheet (light/dark, RTL Arabic, WCAG AA)
│   ├── download.js                      # Core engine: detection, in-app isolation, QR SVG, loop guard, analytics
│   ├── download.html                    # Dedicated standalone download landing page
│   ├── open.html                        # Universal Link /open fallback redirect page
│   └── index.html                       # Main site with integrated #download hash route
├── web/public/                          # Static mirror for Next.js build
├── src/
│   └── index.js                         # Express server with .well-known handlers & /api/send-link
├── scripts/
│   └── test-download-page.js            # Automated CDP verification across 6 test scenarios
├── vercel.json                          # Vercel deployment routes, rewrites, and MIME headers
└── README.md                            # Documentation and verification matrix
```

---

## 🌐 Web Server & Hosting Verification

The `.well-known` endpoints are configured and served with `Content-Type: application/json; charset=utf-8` with HTTP 200 and no redirects:

```bash
# Verify Apple App Site Association
curl -i https://sahla-backend.vercel.app/.well-known/apple-app-site-association

# Verify Android Digital Asset Links
curl -i https://sahla-backend.vercel.app/.well-known/assetlinks.json
```

### Vercel Header Configuration (`vercel.json`)
```json
{
  "version": 2,
  "headers": [
    {
      "source": "/.well-known/apple-app-site-association",
      "headers": [
        { "key": "Content-Type", "value": "application/json" },
        { "key": "Cache-Control", "value": "public, max-age=3600" }
      ]
    },
    {
      "source": "/.well-known/assetlinks.json",
      "headers": [
        { "key": "Content-Type", "value": "application/json" },
        { "key": "Cache-Control", "value": "public, max-age=3600" }
      ]
    }
  ]
}
```

---

## 📲 Native App Entitlements & Manifest

### iOS Setup
In Xcode under **Signing & Capabilities** &rarr; **Associated Domains** (or `Runner.entitlements`):
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.associated-domains</key>
    <array>
        <string>applinks:sahla-backend.vercel.app</string>
        <string>applinks:sahla-app.com</string>
        <!-- Add your custom domain here, e.g. -->
        <!-- <string>applinks:get.sahla.dz</string> -->
    </array>
</dict>
</plist>
```

In `Info.plist` (for custom URI scheme `sahla://` fallback):
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.sahla.sahlaalgerie</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>sahla</string>
        </array>
    </dict>
</array>
```

### Android Setup
In `android/app/src/main/AndroidManifest.xml` inside `<activity android:name=".MainActivity">`:
```xml
<!-- Android App Links (Domain Verification with autoVerify="true") -->
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="https" android:host="sahla-backend.vercel.app" android:pathPrefix="/open"/>
    <data android:scheme="https" android:host="sahla-backend.vercel.app" android:pathPrefix="/download"/>
    <data android:scheme="https" android:host="sahla-app.com"/>
    <!-- Add your custom domain here, e.g. -->
    <!-- <data android:scheme="https" android:host="get.sahla.dz"/> -->
</intent-filter>

<!-- Custom URI Scheme Fallback (sahla://open) -->
<intent-filter>
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="sahla" android:host="open"/>
</intent-filter>
```

---

## 🛡️ Social In-App Browser Hardening (Instagram, Snapchat, TikTok, etc.)

In-app WebViews inside social networks implement strict security sandboxes:
- Scripted navigations (`window.location.replace` or `window.location.href = 'sahla://'`) are rejected or trigger broken prompts.
- Page visibility events do not trigger reliably, causing timers to fire redirects into dead ends.
- Universal Links are intentionally intercepted or prevented from breaking out of the host app.

### How Sahla Handles In-App Browsers:
1. **Detection:** Checks UA for `Instagram|FBAN|FBAV|FB_IAB|Snapchat|TikTok|musical_ly|Bytedance|LinkedInApp|Line/|MicroMessenger|Twitter|Pinterest|Barcelona` as well as generic webview flags.
2. **Halt Scripted Navigation:** `startFlow()` halts immediately upon detecting an in-app browser. **No timers, no scheme attempts, and no location.replace.**
3. **Direct User Taps:** Renders real `<a href="STORE_URL" target="_blank" rel="noopener">` store buttons (App Store first on iOS, Google Play first on Android). Real user taps are respected by WebViews.
4. **Platform-Tailored Instructions:**
   - **Instagram iOS:** Instructs the user to tap `⋯` in the top right, then choose «فتح في Safari».
   - **Snapchat iOS:** Instructs the user to tap the share/browser icon `⎋` in the **bottom toolbar**.
   - **Android WebViews:** Displays an **«افتح في Chrome»** button using an intent URI:
     `intent://sahla-backend.vercel.app/#download#Intent;scheme=https;package=com.android.chrome;S.browser_fallback_url=<encoded current URL>;end`
   - **iOS WebViews:** Displays a secondary «فتح في Safari (اختياري)» button using `x-safari-https://`.
5. **Copy Download Link:** One-tap button using `navigator.clipboard.writeText` with legacy `document.execCommand` fallback and Arabic success toast.

---

## 📊 Automated Verification Results Matrix

Verified across 6 distinct user agents using Google Chrome DevTools Protocol (`node scripts/test-download-page.js`):

| # | Test Scenario | Platform Detected | In-App Detected | Warning Banner | Auto-Redirect Timer | Rendered Actions & Fallbacks |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **1** | **iOS Safari** (Normal Browser) | `ios` | `No` | Hidden | Active (`2200ms`) | Status Card (Opening spinner), App Store & Google Play Badges |
| **2** | **iOS Instagram** (In-App WebView) | `ios` | `Yes (Instagram)` | **Visible** | **None (Halted)** | Safari link, Copy Link button, App Store (primary) & Google Play Badges |
| **3** | **iOS Snapchat** (In-App WebView) | `ios` | `Yes (Snapchat)` | **Visible** | **None (Halted)** | Bottom toolbar instruction, Safari link, Copy Link, App Store & Google Play Badges |
| **4** | **Android Chrome** (Normal Browser) | `android` | `No` | Hidden | Active (`2200ms`) | Status Card (Opening spinner), Google Play & App Store Badges |
| **5** | **Android Instagram** (In-App WebView) | `android` | `Yes (Instagram)` | **Visible** | **None (Halted)** | **"افتح في Chrome" button**, Copy Link, Google Play (primary) & App Store Badges |
| **6** | **Desktop** (Chrome / Safari) | `desktop` | `No` | Hidden | **None (Halted)** | Client-side QR Code SVG, "Send link to my phone", Copy Link |

---

## 📋 Manual Test Checklist for Physical Devices

Use this checklist to test the smart download flow on physical hardware:

### 1. iOS — Instagram / Threads
- [ ] Share `https://sahla-backend.vercel.app/#download` in an Instagram Direct Message or bio link.
- [ ] Tap the link to open in Instagram's in-app browser.
- [ ] **Verify:** Warning banner is visible at the top: «المتصفح الداخلي يحجب فتح وتثبيت التطبيقات...».
- [ ] **Verify:** Instructions say: «اضغط على ⋯ في أعلى الشاشة، ثم اختر «فتح في Safari»».
- [ ] **Verify:** NO modal prompt appears saying "This site is trying to open another application".
- [ ] **Verify:** NO automatic redirect occurs; the page remains on the landing view.
- [ ] Tap the App Store badge &rarr; opens the official App Store page for Sahla directly.
- [ ] Tap «نسخ رابط التحميل» &rarr; toast displays «تم نسخ الرابط بنجاح! ✓».

### 2. iOS — Snapchat
- [ ] Send `https://sahla-backend.vercel.app/#download` in a Snapchat chat.
- [ ] Tap to open inside Snapchat's browser.
- [ ] **Verify:** Warning banner mentions Snapchat.
- [ ] **Verify:** Instructions point to the icon in the **bottom toolbar**.
- [ ] **Verify:** No automatic redirect or broken error screen.
- [ ] Tap App Store badge &rarr; loads App Store.

### 3. iOS — Safari (Normal Browser)
- [ ] **If App Installed:**
  - [ ] Opening `https://sahla-backend.vercel.app/#download` triggers prompt or opens Sahla app immediately.
- [ ] **If App NOT Installed:**
  - [ ] Opening `/#download` displays «جاري فتح تطبيق سهلة…» with spinner.
  - [ ] After 2.2 seconds, status text updates to «جاري تحويلك إلى App Store…».
  - [ ] Browser navigates directly to `https://apps.apple.com/dz/app/sahla-algerie/id6834895657`.
  - [ ] Pressing "Back" in Safari returns to `#download` and displays the fallback card («لم يفتح التطبيق تلقائياً؟») with «حاول مرة أخرى» button without looping.

### 4. Android — Instagram / TikTok / Facebook
- [ ] Open link in Instagram or TikTok on an Android phone.
- [ ] **Verify:** Warning banner appears with «المتصفح الداخلي لتطبيق Instagram يحجب تثبيت التطبيقات...».
- [ ] **Verify:** «افتح في Chrome» button is prominently displayed.
- [ ] Tap «افتح في Chrome» &rarr; immediately breaks out of WebView into Google Chrome.
- [ ] Tap Google Play badge &rarr; opens Google Play Store directly.

### 5. Android — Google Chrome (Normal Browser)
- [ ] Open `https://sahla-backend.vercel.app/#download` in Chrome.
- [ ] **If App Installed:** Chrome handles Intent and launches Sahla app.
- [ ] **If App NOT Installed:** Intent automatically falls back via `browser_fallback_url` to Google Play Store.

### 6. Desktop Browser
- [ ] Open `https://sahla-backend.vercel.app/#download` on PC or Mac.
- [ ] **Verify:** No redirect occurs.
- [ ] **Verify:** QR code is clearly rendered in the sidebar.
- [ ] Scan QR code with phone camera &rarr; opens mobile download flow with preserved parameters.
- [ ] Fill in phone/email and submit &rarr; confirms sending link.
