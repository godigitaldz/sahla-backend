# Real-Device Testing Matrix & Verification Protocol

**Test Target:** `https://sahla-backend.vercel.app/open?utm_source=ig&debug=1`  
*(Or custom domain `https://get.sahla.dz/open?utm_source=ig&debug=1` once attached)*  
**Expected Build Version in Footer:** `v141da437`  
**Evaluation Label:** **REAL-DEVICE** (All entries below must be filled from physical hardware)

---

## 1. Test Protocol & Pass/Fail Criteria

### Pass Criteria
1. **Initial Page Load:** Page renders cleanly (never blank, white, or stuck in a loading loop).
2. **In-App Banner:** Platform-specific warning banner is visible at the top:
   - Instagram (iOS): Guides user to tap `⋯` &rarr; «فتح في Safari».
   - Snapchat (iOS): Guides user to tap the share/browser icon in the **bottom toolbar**.
   - Android (Instagram/TikTok/FB): Displays the «افتح في Chrome» button.
3. **No Unprompted Navigation:** The page does NOT automatically attempt to open the app or redirect to the store on load. No intrusive system popups appear (*"This site is trying to open another application"*).
4. **Tap Interaction («افتح تطبيق سهلة»):**
   - **If Sahla is installed:** App opens directly via native scheme/intent.
   - **If Sahla is not installed or scheme is blocked by the WebView:** Page remains visible; after 2.2 seconds, the store highlight banner appears («لم يفتح التطبيق؟ حمّله مجاناً من متجر التطبيقات أدناه:») and the store badges are highlighted. The user is **never** forcibly navigated away into a dead end.
5. **Escape Buttons («افتح في Chrome» / «فتح في Safari»):** Tapping successfully launches the external browser.
6. **Store Badges:** Tapping App Store / Google Play badge loads the store listing directly in the same tab.
7. **Query Parameter Preservation:** Preserved throughout (`utm_source=ig` visible in Diagnostics panel and reflected in store referral URLs).

### Fail Criteria
- White or blank screen.
- Spinner spinning indefinitely without rendering buttons.
- Page redirects immediately on load without user tap.
- Intrusive blocked dialog pops up immediately on load.
- Tapping buttons causes silent crash or unhandled error.

> [!NOTE]
> If a particular social WebView (e.g. strict Instagram iOS sandbox) restricts custom URI schemes, «افتح تطبيق سهلة» failing to open the app is **expected behavior**, not a bug. In that case, the test passes if the fallback store buttons, manual copy box, or escape buttons work reliably.

---

## 2. Real-Device Verification Matrix (16 Cells)

| # | OS & Device | App Host | Sahla Installed? | Entry Method (DM, Bio, Story) | Build Tag Verified | «افتح تطبيق سهلة» Tap Result | Escape Button Result | Store Badge Result | Pass / Fail [REAL-DEVICE] | Tester Initials & Date |
| :-: | :--- | :--- | :-: | :--- | :-: | :--- | :--- | :--- | :-: | :--- |
| **1** | **iPhone** (iOS 17+) | Instagram | **Yes** | DM Link | `v141da437` | | | | | |
| **2** | **iPhone** (iOS 17+) | Instagram | **No** | DM Link | `v141da437` | | | | | |
| **3** | **iPhone** (iOS 17+) | Snapchat | **Yes** | Chat Link | `v141da437` | | | | | |
| **4** | **iPhone** (iOS 17+) | Snapchat | **No** | Chat Link | `v141da437` | | | | | |
| **5** | **iPhone** (iOS 17+) | TikTok | **Yes** | Bio / Message | `v141da437` | | | | | |
| **6** | **iPhone** (iOS 17+) | TikTok | **No** | Bio / Message | `v141da437` | | | | | |
| **7** | **iPhone** (iOS 17+) | Facebook / Messenger | **Yes** | Messenger Chat | `v141da437` | | | | | |
| **8** | **iPhone** (iOS 17+) | Facebook / Messenger | **No** | Messenger Chat | `v141da437` | | | | | |
| **9** | **Android** (12-14) | Instagram | **Yes** | DM Link | `v141da437` | | | | | |
| **10** | **Android** (12-14) | Instagram | **No** | DM Link | `v141da437` | | | | | |
| **11** | **Android** (12-14) | Snapchat | **Yes** | Chat Link | `v141da437` | | | | | |
| **12** | **Android** (12-14) | Snapchat | **No** | Chat Link | `v141da437` | | | | | |
| **13** | **Android** (12-14) | TikTok | **Yes** | Bio / Message | `v141da437` | | | | | |
| **14** | **Android** (12-14) | TikTok | **No** | Bio / Message | `v141da437` | | | | | |
| **15** | **Android** (12-14) | Facebook / Messenger | **Yes** | Post / Chat | `v141da437` | | | | | |
| **16** | **Android** (12-14) | Facebook / Messenger | **No** | Post / Chat | `v141da437` | | | | | |

---

## 3. How to Capture Diagnostics on Real Hardware

1. Navigate to: `https://sahla-backend.vercel.app/open?utm_source=ig&debug=1`
2. Scroll to the bottom of the page.
3. Tap on **«🛠️ Sahla Diagnostics (Build v141da437)»** to expand the panel.
4. Verify that:
   - `inAppDetected` is `true` with the correct app name.
   - `storageAvailable` is `true`.
   - `generatedHrefs` displays the expected intent and store URLs.
   - `recentEvents` logs the user taps without errors.
5. Tap **«Copy Diagnostics»** and paste into your test report or take a screenshot.
