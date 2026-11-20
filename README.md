# Smart App Download & Deep Linking System — Sahla (Algeria)

Production-ready smart download gateway and deep linking infrastructure for **Sahla** (`https://sahla-backend.vercel.app/#download` as well as `/download` and `/open`).

When a visitor lands on the page, the system detects their device, launches the native Sahla app if installed, or redirects directly to the Apple App Store / Google Play Store if not installed.

---

## 📱 Production Identity & Deep Link Tokens

| Parameter | Production Value | Source / Verification |
| :--- | :--- | :--- |
| **App Name** | `Sahla` (`سهلة`) | Official Brand |
| **Domain** | `sahla-backend.vercel.app` & `sahla-app.com` | Backend Vercel / Web |
| **iOS Bundle Identifier** | `com.sahla.sahlaalgerie` | App Store Release |
| **Apple Developer Team ID** | `9P628XCQ94` | Xcode Release Target (`DEVELOPMENT_TEAM`) |
| **Apple App Store URL** | `https://apps.apple.com/dz/app/sahla-algerie/id6834895657` | Apple App Store (ID `6834895657`) |
| **Android Package Name** | `com.godigital.sahla` | `build.gradle.kts` / AndroidManifest.xml |
| **Google Play Store URL** | `https://play.google.com/store/apps/details?id=com.godigital.sahla` | Google Play Store |
| **Custom URI Scheme** | `sahla://` | `Info.plist` & `AndroidManifest.xml` |
| **Release Signing Fingerprint (SHA256)** | `35:5A:0E:B6:87:F5:F1:98:3C:59:0D:0A:86:52:83:5B:02:CD:AC:9C:22:A7:6D:5C:9C:BC:E4:51:DA:96:93:F4` | Keystore `/Users/macamine/sahla-release-key.jks` |
| **Debug Signing Fingerprint (SHA256)** | `83:F0:97:BF:F1:C0:B6:48:C2:0E:7F:08:C0:BB:1C:E7:6D:25:F8:45:2B:71:73:DA:E3:69:6D:8D:A6:89:11:7B` | Local `~/.android/debug.keystore` |
| **Deep Link In-App Path** | `/open` | App router |
| **Open Timeout** | `2200ms` | Configurable |

---

## 📁 File Structure

```text
sahla-backend/
├── public/
│   ├── .well-known/
│   │   ├── apple-app-site-association   # iOS Universal Links & Credentials (JSON)
│   │   └── assetlinks.json              # Android App Links Digital Asset Verification (JSON)
│   ├── config.js                        # Production configuration for Sahla
│   ├── download.css                     # Responsive mobile-first stylesheet (light/dark, WCAG AA)
│   ├── download.js                      # Core controller: platform detection, QR SVG, lifecycle logic
│   ├── download.html                    # Dedicated standalone download landing page
│   ├── open.html                        # Universal Link /open fallback redirect page
│   └── index.html                       # Main site with integrated #download hash route
├── src/
│   └── index.js                         # Express server with .well-known routes & /api/send-link
├── scripts/
│   └── test-download-page.js            # Automated headless Chrome CDP test runner
├── vercel.json                          # Vercel deployment routes, rewrites, and MIME headers
└── README.md                            # Documentation and verification matrix
```

---

## 🌐 Web Server & Hosting Verification

The `.well-known` endpoints are configured and served with `Content-Type: application/json; charset=utf-8`:

```bash
# Verify Apple App Site Association
curl -i https://sahla-backend.vercel.app/.well-known/apple-app-site-association

# Verify Android Digital Asset Links
curl -i https://sahla-backend.vercel.app/.well-known/assetlinks.json
```

### Server Configurations

#### 1. Vercel (`vercel.json`)
Included in root `vercel.json`:
- Explicit route rewrites for `/.well-known/*`, `/open*`, and `/download*`.
- Content-Type headers for `application/json` and cache control `max-age=3600`.

#### 2. Nginx
```nginx
location = /.well-known/apple-app-site-association {
    alias /var/www/sahla-backend/public/.well-known/apple-app-site-association;
    default_type application/json;
    add_header Content-Type application/json;
    add_header Access-Control-Allow-Origin *;
    add_header Cache-Control "public, max-age=3600";
}

location = /.well-known/assetlinks.json {
    alias /var/www/sahla-backend/public/.well-known/assetlinks.json;
    default_type application/json;
    add_header Content-Type application/json;
    add_header Access-Control-Allow-Origin *;
    add_header Cache-Control "public, max-age=3600";
}
```

---

## 📲 Native App Entitlements & Manifest

### iOS Setup
In `Runner.entitlements` and `Runner-Production.entitlements`:
```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:sahla-backend.vercel.app</string>
    <string>applinks:sahla-app.com</string>
</array>
```
In `Info.plist`:
```xml
<key>CFBundleURLSchemes</key>
<array>
    <string>sahla</string>
</array>
```

### Android Setup
In `android/app/src/main/AndroidManifest.xml`:
```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="https" android:host="sahla-backend.vercel.app" android:pathPrefix="/open"/>
    <data android:scheme="https" android:host="sahla-backend.vercel.app" android:pathPrefix="/download"/>
    <data android:scheme="https" android:host="sahla-app.com"/>
    <data android:scheme="https" android:host="www.sahla-app.com"/>
</intent-filter>

<intent-filter>
    <action android:name="android.intent.action.VIEW"/>
    <category android:name="android.intent.category.DEFAULT"/>
    <category android:name="android.intent.category.BROWSABLE"/>
    <data android:scheme="sahla"/>
</intent-filter>
```

---

## 🧪 Testing Checklist & Matrix

1. **Desktop Chrome / Safari / Firefox**:
   - Navigate to `/#download`.
   - Renders QR Code SVG instantly (generated client-side, zero external scripts).
   - "Send link to my phone" input sends SMS or email via `POST /api/send-link`.
2. **iPhone (App Installed)**:
   - Universal Link automatically opens the native Sahla app directly.
3. **iPhone (App Not Installed)**:
   - Shows "جاري فتح تطبيق سهلة…", waits 2.2s, then redirects to `https://apps.apple.com/dz/app/sahla-algerie/id6834895657`.
   - Back button returns to `#download` with manual store buttons without infinite loop.
4. **Android (App Installed)**:
   - Android Intent activates and launches `com.godigital.sahla`.
5. **Android (App Not Installed)**:
   - Intent falls back automatically via `browser_fallback_url` to `https://play.google.com/store/apps/details?id=com.godigital.sahla`.
6. **In-App Social Media Browsers (Instagram, TikTok, FB)**:
   - In-app browser detection shield triggers: displays instructions to tap `⋯` and select "Open in Safari / Chrome", plus a 1-tap "Copy Download Link" button.
7. **iPad / iPadOS 13+**:
   - Correctly identified as `ios` even when requesting desktop website.
8. **Automated Test Runner**:
   - Run `node scripts/test-download-page.js` to execute headless browser verification.
