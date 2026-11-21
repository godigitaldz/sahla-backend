# In-App Browser & Download Gateway Audit Report

**Date:** 2026-11-21  
**Target:** `https://sahla-backend.vercel.app` (`/open`, `/download`, `/#download`)  
**Branch:** `fix/inapp-open`  
**Working Mode:** Audit First → Confirm Root Causes → Smallest Safe Changes → Test → Report  

---

## 1. Route Table (Production Verification)

Queried live against production server `sahla-backend.vercel.app`:

| Request URL | Handler | Upstream File | Status | Key Headers | Notes |
| :--- | :--- | :--- | :---: | :--- | :--- |
| `/open` | Express (`src/index.js`) | `public/open.html` | 200 | `content-type: text/html; charset=UTF-8`<br>`cache-control: public, max-age=0`<br>`x-matched-path: /src/index.js` | Serves HTML with `<section id="download">` and loads `config.js`, `download.js`. |
| `/open/` | Vercel Router | N/A | 308 | `location: /open`<br>`cache-control: public, max-age=0, must-revalidate` | Normalizes trailing slash via 308 permanent redirect. |
| `/open?utm_source=ig` | Express (`src/index.js`) | `public/open.html` | 200 | `content-type: text/html; charset=UTF-8`<br>`cache-control: public, max-age=0`<br>`x-matched-path: /src/index.js` | Preserves query string to client-side JS. |
| `/open.html` | Express Static | `public/open.html` | 200 | `content-type: text/html; charset=UTF-8`<br>`cache-control: public, max-age=0` | Direct file access matches `/open`. |
| `/download` | Express (`src/index.js`) | `public/download.html` | 200 | `content-type: text/html; charset=UTF-8`<br>`cache-control: public, max-age=0`<br>`x-matched-path: /src/index.js` | Serves dedicated download page. |
| `/download.html` | Express Static | `public/download.html` | 200 | `content-type: text/html; charset=UTF-8`<br>`cache-control: public, max-age=0` | Direct file access. |
| `/` | Next.js / Static Root | `public/index.html` | 200 | `content-type: text/html; charset=utf-8`<br>`cache-control: public, max-age=0, must-revalidate` | Landing page with `<section id="download">`. |
| `/#download` | Client Hash on `/` | `public/index.html` | 200 | Client hash navigation; server sees `/` | Activates `SmartDownloadApp` via `hashchange` / `init()`. |
| `/.well-known/apple-app-site-association` | Express (`src/index.js`) | `public/.well-known/apple-app-site-association` | 200 | `content-type: application/json; charset=utf-8`<br>`cache-control: public, max-age=3600` | Served as JSON, no redirects. |
| `/.well-known/assetlinks.json` | Express (`src/index.js`) | `public/.well-known/assetlinks.json` | 200 | `content-type: application/json; charset=utf-8`<br>`cache-control: public, max-age=3600` | Served as JSON, no redirects. |

---

## 2. Navigation Calls Audit

Every navigation mechanism in the codebase:

| File | Line (approx) | Expression / Snippet | Context | Requires User Tap? | Behavior in In-App WebView |
| :--- | :---: | :--- | :--- | :---: | :--- |
| `web/src/app/open/route.ts` | 60 | `window.location.href = "${uriScheme}"` | iOS inline HTML | **NO** (on page load) | Blocked by WebKit sandbox; triggers intrusive popup or dropped. |
| `web/src/app/open/route.ts` | 74 | `window.location.replace("${iosStoreUrl}")` | iOS inline HTML `setTimeout(2200)` | **NO** (timer) | Unconditionally fires after timeout into App Store. |
| `web/src/app/open/route.ts` | 97 | `NextResponse.redirect(intentUrl, 302)` | Android Next.js GET handler | **NO** (server HTTP 302) | Blocked in several WebViews; bypasses all client fallback logic. |
| `web/src/app/download/route.ts` | 6 | `NextResponse.redirect("/#download", 302)` | Next.js GET handler | **NO** (server HTTP 302) | Server redirect to hash route. |
| `public/download.js` | 874 | `<a href="${chromeIntentUrl}" target="_blank">` | In-app banner (Android) | **YES** (tap) | WebViews often swallow `target="_blank"`; intent URL hardcoded to `/#download` instead of current route. |
| `public/download.js` | 887 | `<a href="${safariProtocolUrl}" target="_blank">` | In-app banner (iOS) | **YES** (tap) | WebViews often swallow `target="_blank"`. |
| `public/download.js` | 948 | `<a href="${uriScheme / intentUrl}">` | Normal browser manual open | **YES** (tap) | Handled only in normal browser mode. |
| `public/download.js` | 961 | `<a href="${iosUrl}" target="_blank">` | App Store badge | **YES** (tap) | `target="_blank"` can fail inside Instagram/TikTok WebViews. |
| `public/download.js` | 971 | `<a href="${androidUrl}" target="_blank">` | Google Play badge | **YES** (tap) | `target="_blank"` can fail inside Instagram/TikTok WebViews. |
| `public/download.js` | 1292 | `window.location.replace(storeUrl)` | Normal browser `startFlow()` | **NO** (timer) | Fires if visibility did not change in normal browsers. |
| `public/download.js` | 1298 | `window.location.href = uriScheme` | Normal browser iOS `startFlow()` | **NO** (on load) | Normal browsers only (halted in in-app mode). |
| `public/download.js` | 1300 | `window.location.href = intentUrl` | Normal browser Android `startFlow()` | **NO** (on load) | Normal browsers only (halted in in-app mode). |

---

## 3. Storage and Clipboard Audit

| Location | API Call | Wrapped in try/catch? | Risk / Failure Mode |
| :--- | :--- | :---: | :--- |
| `public/download.js:171` | `localStorage.getItem('sahla_lang')` | **YES** | Safe fallback to `'ar'`. |
| `public/download.js:747` | `navigator.clipboard.writeText(text)` | **YES** | Caught, falls back to `execCommand`, but no visible input fallback if both fail. |
| `public/download.js:809` | `sessionStorage.getItem('sd_redirect_ts')` | **YES** | Safe fallback to `false`. |
| `public/download.js:919` | `sessionStorage.getItem('dl_attempted')` | ❌ **NO** | Throws `SecurityError` or `DOMException` in sandboxed WebViews, breaking rendering! |
| `public/download.js:1133` | `sessionStorage.removeItem('dl_attempted')` | ❌ **NO** | Throws in restricted environments. |
| `public/download.js:1134` | `sessionStorage.removeItem('sd_redirect_ts')` | ❌ **NO** | Throws in restricted environments. |
| `public/download.js:1217` | `sessionStorage.getItem('dl_attempted')` | ❌ **NO** | Throws in restricted environments. |
| `public/download.js:1280` | `sessionStorage.setItem('dl_attempted', 'true')` | **YES** | Handled. |
| `public/download.js:1281` | `sessionStorage.setItem('sd_redirect_ts', ...)` | **YES** | Handled. |
| `public/download.js:1326` | `sessionStorage.removeItem('dl_attempted')` | ❌ **NO** | Throws in restricted environments. |
| `public/download.js:1327` | `sessionStorage.removeItem('sd_redirect_ts')` | ❌ **NO** | Throws in restricted environments. |

---

## 4. Findings Verification (F1 - F6)

### Finding F1: `/open` deliberately does nothing in in-app browsers
- **Status:** **CONFIRMED.**
- **Verification:** `download.js` detects `/open` routes, but when `inApp.isInApp` is true, `startFlow()` returns immediately. Furthermore, `statusCardHtml` and `manualOpenBtnHtml` are both cleared to `''`. There is zero attempt or button to open the installed app, leaving the user with only external store and escape links.
- **Remedy:** Introduce a primary user-tap button «افتح سهلة» in in-app mode that attempts `sahla://open` (iOS) or the specific app intent (Android), followed by a non-intrusive store highlight on timeout without auto-redirecting.

### Finding F2: In-app action links are fragile and use `target="_blank"`
- **Status:** **CONFIRMED.**
- **Verification:** Store badges and escape links (`sd-btn-chrome`, `sd-btn-safari`) all specify `target="_blank"`. In Instagram, Facebook, and TikTok WebViews, new-window links (`_blank`) are frequently swallowed or blocked. The Chrome intent URL was constructed using `/#download` rather than preserving the actual pathname and query (e.g. `/open?utm_source=ig`).
- **Remedy:** Remove `target="_blank"` in in-app mode (use same-tab navigation); construct `buildChromeIntent()` from the real `window.location.href`, with proper handling of query and hash fragments.

### Finding F3: Competing Next.js route implementations exist
- **Status:** **CONFIRMED.**
- **Verification:** `web/src/app/open/route.ts` implements an unshielded inline HTML script with auto-redirects, and `web/src/app/download/route.ts` issues a 302 redirect. While current `vercel.json` routes `/open*` to `src/index.js`, any shift in route ordering would expose users to these unshielded endpoints.
- **Remedy:** Neutralize Next.js route handlers by issuing a clean 302 redirect directly to `/open` and `/download` preserving query parameters, ensuring Express and `download.js` remain the single source of truth.

### Finding F4: Unsafe storage access breaks restricted WebViews
- **Status:** **CONFIRMED.**
- **Verification:** `sessionStorage.getItem('dl_attempted')` is executed unguarded on lines 919 and 1217, and `removeItem` on lines 1133 and 1326.
- **Remedy:** Implement `safeSession` wrapper with comprehensive try/catch for `get`, `set`, and `del`.

### Finding F5: Test suite coverage gaps
- **Status:** **CONFIRMED.**
- **Verification:** `scripts/test-download-page.js` only loaded `/#download`, did not test `/open`, lacked tap assertions, and imported `src/index.js` which fails without Supabase environment variables.
- **Remedy:** Rewrite test suite using an isolated static server serving `public/` directly, testing all 4 routes across 9 user agents with navigation interception and tap assertions.

### Finding F6: Ruled-out assumptions re-verified
- **Status:** **CONFIRMED.**
- **Verification:** SHA-256 hashes between local and production files match for `config.js`, `download.js`, `download.css`, and `.well-known` files. Headers on `/open` are `Cache-Control: public, max-age=0`. AASA and assetlinks endpoints respond with HTTP 200 and `application/json`.
