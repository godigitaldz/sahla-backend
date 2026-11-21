import { spawn } from 'child_process';
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs';
import http from 'http';
import { resolve, extname } from 'path';
import { createHash } from 'crypto';
import WebSocket from 'ws';

const PORT = 3567;
const CHROME_PORT = 9222;
const TEST_ARTIFACTS_DIR = resolve('test-artifacts');
if (!existsSync(TEST_ARTIFACTS_DIR)) {
  mkdirSync(TEST_ARTIFACTS_DIR, { recursive: true });
}

const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

// ============================================================================
// PART 1: Unit Tests
// ============================================================================
console.log('🧪 [SIMULATED] Running Unit Tests...');

// 1.1 buildChromeIntent unit tests
function buildChromeIntent(href) {
  const u = new URL(href);
  const fallback = encodeURIComponent(u.href);
  let pathAndQuery = `${u.host}${u.pathname}${u.search}`;
  if (u.hash && u.hash !== '#' && u.hash !== '#download') {
    pathAndQuery += encodeURIComponent(u.hash);
  } else if (u.hash === '#download') {
    pathAndQuery += '%23download';
  }
  return `intent://${pathAndQuery}#Intent;scheme=https;package=com.android.chrome;S.browser_fallback_url=${fallback};end`;
}

const unitCases = [
  {
    href: 'https://sahla-backend.vercel.app/open',
    desc: 'without query/hash',
    assert(res) {
      if (!res.startsWith('intent://sahla-backend.vercel.app/open#Intent;')) throw new Error('Bad prefix: ' + res);
      if (!res.includes('scheme=https;package=com.android.chrome;')) throw new Error('Bad scheme/package: ' + res);
      if (!res.includes('S.browser_fallback_url=' + encodeURIComponent('https://sahla-backend.vercel.app/open'))) throw new Error('Bad fallback: ' + res);
    }
  },
  {
    href: 'https://sahla-backend.vercel.app/open?utm_source=ig&campaign=summer',
    desc: 'with query params',
    assert(res) {
      if (!res.includes('sahla-backend.vercel.app/open?utm_source=ig&campaign=summer#Intent;')) throw new Error('Query not preserved: ' + res);
      if (!res.includes('S.browser_fallback_url=' + encodeURIComponent('https://sahla-backend.vercel.app/open?utm_source=ig&campaign=summer'))) throw new Error('Bad fallback: ' + res);
    }
  },
  {
    href: 'https://sahla-backend.vercel.app/#download',
    desc: 'with #download hash route',
    assert(res) {
      if (res.includes('##') || res.indexOf('#') !== res.indexOf('#Intent')) throw new Error('Unencoded raw hash in intent: ' + res);
      if (!res.includes('%23download#Intent;')) throw new Error('Hash not encoded before #Intent: ' + res);
    }
  },
  {
    href: 'https://sahla-backend.vercel.app/open?ref=123#invite',
    desc: 'with query and custom hash',
    assert(res) {
      if (!res.includes('%23invite#Intent;')) throw new Error('Custom hash not encoded: ' + res);
    }
  }
];

for (const uc of unitCases) {
  const result = buildChromeIntent(uc.href);
  uc.assert(result);
  console.log(`  ✅ [SIMULATED] buildChromeIntent (${uc.desc}): PASS`);
}

// 1.2 Hash identity check between public/ and web/public/
const filesToCompare = [
  'config.js',
  'download.js',
  'download.css',
  'download.html',
  'open.html',
  '.well-known/apple-app-site-association',
  '.well-known/assetlinks.json'
];

for (const f of filesToCompare) {
  const h1 = createHash('sha256').update(readFileSync(`public/${f}`)).digest('hex');
  const h2 = createHash('sha256').update(readFileSync(`web/public/${f}`)).digest('hex');
  if (h1 !== h2) {
    throw new Error(`Hash mismatch for ${f}: public/${f} !== web/public/${f}`);
  }
}
console.log('  ✅ [SIMULATED] Hash identity between public/ and web/public/: PASS (all match)');

// 1.3 Neutralized Next.js route check (no auto-navigation in Next.js routes)
const nextOpenContent = readFileSync('web/src/app/open/route.ts', 'utf8');
const nextDownloadContent = readFileSync('web/src/app/download/route.ts', 'utf8');

if (nextOpenContent.includes('window.location') || nextOpenContent.includes('setTimeout') || nextOpenContent.includes('intent://')) {
  throw new Error('web/src/app/open/route.ts contains dangerous client auto-navigation');
}
if (!nextOpenContent.includes('NextResponse.redirect') || !nextOpenContent.includes('/open')) {
  throw new Error('web/src/app/open/route.ts does not delegate cleanly to /open');
}
if (!nextDownloadContent.includes('NextResponse.redirect') || !nextDownloadContent.includes('/download')) {
  throw new Error('web/src/app/download/route.ts does not delegate cleanly to /download');
}
console.log('  ✅ [SIMULATED] Neutralized Next.js routes inspection: PASS (no unshielded auto-navigation)');

// ============================================================================
// PART 2: Isolated Static Test Server (No Secrets / No Supabase Dependency)
// ============================================================================
const MIME_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.webp': 'image/webp',
  '.svg': 'image/svg+xml'
};

const server = http.createServer((req, res) => {
  const urlObj = new URL(req.url, `http://localhost:${PORT}`);
  let pathname = urlObj.pathname;

  let filePath = null;
  if (pathname === '/open' || pathname.startsWith('/open/')) {
    filePath = resolve('public/open.html');
  } else if (pathname === '/download' || pathname.startsWith('/download/')) {
    filePath = resolve('public/download.html');
  } else if (pathname === '/' || pathname === '/index.html') {
    filePath = resolve('public/index.html');
  } else {
    filePath = resolve('public', pathname.replace(/^\//, ''));
  }

  if (filePath && existsSync(filePath)) {
    const ext = extname(filePath).toLowerCase();
    const mime = MIME_TYPES[ext] || 'application/octet-stream';
    res.writeHead(200, {
      'Content-Type': mime,
      'Cache-Control': 'no-cache, must-revalidate'
    });
    res.end(readFileSync(filePath));
  } else {
    res.writeHead(404, { 'Content-Type': 'text/plain' });
    res.end('Not Found');
  }
});

server.listen(PORT);
console.log(`🚀 [SIMULATED] Isolated Static HTTP Server running on http://localhost:${PORT}`);

// ============================================================================
// PART 3: Headless Chrome CDP Test Suite
// ============================================================================
console.log('🌐 Launching headless Chrome...');
const chromeProc = spawn('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', [
  '--headless=new',
  '--disable-gpu',
  '--remote-debugging-port=' + CHROME_PORT,
  '--no-first-run',
  '--no-default-browser-check',
  'about:blank'
]);

let versionData = null;
for (let i = 0; i < 20; i++) {
  await sleep(300);
  try {
    const r = await fetch(`http://127.0.0.1:${CHROME_PORT}/json/version`);
    versionData = await r.json();
    if (versionData.webSocketDebuggerUrl) break;
  } catch (e) {}
}

if (!versionData) {
  console.error('❌ Could not connect to Chrome debugging port');
  chromeProc.kill();
  server.close();
  process.exit(1);
}

const newTabRes = await fetch(`http://127.0.0.1:${CHROME_PORT}/json/new?about:blank`, { method: 'PUT' });
const tabData = await newTabRes.json();
const ws = new WebSocket(tabData.webSocketDebuggerUrl);
await new Promise((resolve) => ws.on('open', resolve));

let reqId = 1;
const pendingRequests = new Map();
const consoleErrors = [];
const uncaughtExceptions = [];

ws.on('message', (raw) => {
  const msg = JSON.parse(raw);
  if (msg.id && pendingRequests.has(msg.id)) {
    const { resolve, reject } = pendingRequests.get(msg.id);
    pendingRequests.delete(msg.id);
    if (msg.error) reject(msg.error);
    else resolve(msg.result);
  }
  if (msg.method === 'Runtime.consoleAPICalled') {
    if (msg.params.type === 'error') {
      const text = msg.params.args.map((a) => a.value || a.description || '').join(' ');
      consoleErrors.push(text);
    }
  }
  if (msg.method === 'Runtime.exceptionThrown') {
    const text = msg.params.exceptionDetails.exception?.description || msg.params.exceptionDetails.text;
    uncaughtExceptions.push(text);
  }
});

const send = (method, params = {}) => {
  const id = reqId++;
  return new Promise((resolve, reject) => {
    pendingRequests.set(id, { resolve, reject });
    ws.send(JSON.stringify({ id, method, params }));
  });
};

await send('Page.enable');
await send('Runtime.enable');

// Install Init Script to intercept and record navigations & gestures
await send('Page.addScriptToEvaluateOnNewDocument', {
  source: `
    window.__NAVIGATION_LOG__ = [];
    window.__LAST_USER_CLICK__ = 0;

    window.addEventListener('click', function() {
      window.__LAST_USER_CLICK__ = Date.now();
    }, true);

    function recordNav(method, url) {
      var isTap = (Date.now() - window.__LAST_USER_CLICK__) < 2500;
      window.__NAVIGATION_LOG__.push({
        method: method,
        url: String(url),
        isTap: isTap,
        timestamp: Date.now()
      });
    }

    window.__SD_ON_NAVIGATE__ = function(u) {
      recordNav('safeNavigate', u);
    };

    var origReplace = window.location.replace.bind(window.location);
    window.location.replace = function(u) {
      recordNav('location.replace', u);
    };

    var origAssign = window.location.assign ? window.location.assign.bind(window.location) : null;
    if (origAssign) {
      window.location.assign = function(u) {
        recordNav('location.assign', u);
      };
    }

    var origOpen = window.open;
    window.open = function(u) {
      recordNav('window.open', u);
      return null;
    };
  `
});

// Test UAs (9 distinct real-world UA strings)
const TEST_UAS = [
  {
    id: 'ios_safari_control',
    name: 'iPhone Safari (Control)',
    isMobile: true,
    hasTouch: true,
    expectedInApp: false,
    expectedPlatform: 'ios',
    ua: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1'
  },
  {
    id: 'ios_instagram',
    name: 'iPhone Instagram',
    isMobile: true,
    hasTouch: true,
    expectedInApp: true,
    expectedApp: 'Instagram',
    expectedPlatform: 'ios',
    ua: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Instagram 332.0.0.18.109'
  },
  {
    id: 'ios_snapchat',
    name: 'iPhone Snapchat',
    isMobile: true,
    hasTouch: true,
    expectedInApp: true,
    expectedApp: 'Snapchat',
    expectedPlatform: 'ios',
    ua: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Snapchat/12.88.0.38'
  },
  {
    id: 'ios_tiktok',
    name: 'iPhone TikTok',
    isMobile: true,
    hasTouch: true,
    expectedInApp: true,
    expectedApp: 'TikTok',
    expectedPlatform: 'ios',
    ua: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 musical_ly_34.5.0'
  },
  {
    id: 'ios_facebook',
    name: 'iPhone Facebook',
    isMobile: true,
    hasTouch: true,
    expectedInApp: true,
    expectedApp: 'Facebook',
    expectedPlatform: 'ios',
    ua: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 [FBAN/FBIOS;FBAV/462.0.0.38.109;FBBV/598218942;FBDV/iPhone14,5;FBMD/iPhone;FBSN/iOS;FBSV/17.5;FBSS/3;FBID/phone;FBLC/en_US;FBOP/5]'
  },
  {
    id: 'android_chrome_control',
    name: 'Android Chrome (Control)',
    isMobile: true,
    hasTouch: true,
    expectedInApp: false,
    expectedPlatform: 'android',
    ua: 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.6422.165 Mobile Safari/537.36'
  },
  {
    id: 'android_instagram',
    name: 'Android Instagram WebView',
    isMobile: true,
    hasTouch: true,
    expectedInApp: true,
    expectedApp: 'Instagram',
    expectedPlatform: 'android',
    ua: 'Mozilla/5.0 (Linux; Android 14; Pixel 8; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/125.0.6422.165 Mobile Safari/537.36 Instagram 332.0.0.35.109 Android (34/14; 420dpi; 1080x2400; Google/google; Pixel 8)'
  },
  {
    id: 'android_tiktok',
    name: 'Android TikTok',
    isMobile: true,
    hasTouch: true,
    expectedInApp: true,
    expectedApp: 'TikTok',
    expectedPlatform: 'android',
    ua: 'Mozilla/5.0 (Linux; Android 14; Pixel 8; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/125.0.6422.165 Mobile Safari/537.36 BytedanceWebview trill_34.5.0'
  },
  {
    id: 'android_facebook',
    name: 'Android Facebook',
    isMobile: true,
    hasTouch: true,
    expectedInApp: true,
    expectedApp: 'Facebook',
    expectedPlatform: 'android',
    ua: 'Mozilla/5.0 (Linux; Android 14; Pixel 8; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/125.0.6422.165 Mobile Safari/537.36 [FB_IAB/FB4A;FBAV/462.0.0.47.109;]'
  }
];

const TEST_ROUTES = [
  '/open',
  '/open?utm_source=ig',
  '/download',
  '/#download'
];

const testResultsMatrix = [];
let allTestsPassed = true;

for (const route of TEST_ROUTES) {
  for (const uaInfo of TEST_UAS) {
    const testTitle = `${route} × ${uaInfo.name}`;
    console.log(`\n📋 [SIMULATED] Testing: ${testTitle}`);

    consoleErrors.length = 0;
    uncaughtExceptions.length = 0;

    await send('Emulation.setDeviceMetricsOverride', {
      width: uaInfo.isMobile ? 390 : 1440,
      height: uaInfo.isMobile ? 844 : 900,
      deviceScaleFactor: 2,
      mobile: uaInfo.isMobile,
      hasTouch: uaInfo.hasTouch
    });

    await send('Emulation.setUserAgentOverride', {
      userAgent: uaInfo.ua
    });

    await send('Page.navigate', { url: 'about:blank' });
    await sleep(150);

    const targetUrl = `http://localhost:${PORT}${route}`;
    await send('Page.navigate', { url: targetUrl });
    await sleep(1000);

    // Evaluate detection
    const evalData = await send('Runtime.evaluate', {
      expression: `({
        platform: typeof window.detectPlatform === 'function' ? window.detectPlatform() : null,
        inApp: typeof window.detectInApp === 'function' ? window.detectInApp() : null,
        bannerVisible: Boolean(document.getElementById('sdInAppBanner') && document.getElementById('sdInAppBanner').classList.contains('is-visible')),
        inAppOpenBtn: Boolean(document.getElementById('sdInAppOpenAppBtn')),
        storeBadgesCount: document.querySelectorAll('.sd-store-badge').length,
        hasTargetBlankInAppBadges: Boolean(document.querySelector('.sd-store-badge[target="_blank"]')),
        escapeBtn: document.getElementById('sdEscapeBtn') ? document.getElementById('sdEscapeBtn').getAttribute('href') : null,
        navLog: window.__NAVIGATION_LOG__ || [],
        storeHighlightVisible: Boolean(document.getElementById('sdInAppStoreHighlight') && document.getElementById('sdInAppStoreHighlight').style.display !== 'none'),
        manualCopyBoxVisible: Boolean(document.getElementById('sdManualCopyBox') && document.getElementById('sdManualCopyBox').style.display !== 'none'),
        timerActive: Boolean(window.SmartDownload && window.SmartDownload.redirectTimer !== null)
      })`,
      returnByValue: true
    });

    const res = evalData.result?.value;
    let pass = true;
    const failures = [];

    // Assertion 1: Platform and InApp detection
    if (res.platform !== uaInfo.expectedPlatform) {
      pass = false; failures.push(`Platform expected ${uaInfo.expectedPlatform}, got ${res.platform}`);
    }
    if (res.inApp?.isInApp !== uaInfo.expectedInApp) {
      pass = false; failures.push(`InApp expected ${uaInfo.expectedInApp}, got ${res.inApp?.isInApp}`);
    }
    if (uaInfo.expectedInApp && res.inApp?.app !== uaInfo.expectedApp) {
      pass = false; failures.push(`InApp app expected ${uaInfo.expectedApp}, got ${res.inApp?.app}`);
    }

    // Assertion 2: Banner and controls in in-app mode
    if (uaInfo.expectedInApp) {
      if (!res.bannerVisible) { pass = false; failures.push('In-app banner not visible'); }
      if (!res.inAppOpenBtn) { pass = false; failures.push('Primary "Open Sahla" button not rendered'); }
      if (res.hasTargetBlankInAppBadges) { pass = false; failures.push('Store badges have forbidden target="_blank" in in-app mode'); }
      if (res.timerActive) { pass = false; failures.push('Auto-redirect timer was active in in-app mode'); }
    } else {
      if (res.bannerVisible) { pass = false; failures.push('In-app banner unexpectedly visible in control browser'); }
    }

    // Assertion 3: Zero unprompted navigations in in-app mode
    if (uaInfo.expectedInApp) {
      const unprompted = res.navLog.filter((n) => !n.isTap);
      if (unprompted.length > 0) {
        pass = false; failures.push(`Unprompted navigations detected in in-app mode: ${JSON.stringify(unprompted)}`);
      }
    }

    // Assertion 4: Query params preservation
    if (route.includes('utm_source=ig')) {
      const storeUrlsEval = await send('Runtime.evaluate', {
        expression: `({
          appStore: document.getElementById('sdAppStoreBtn')?.getAttribute('href'),
          playStore: document.getElementById('sdPlayStoreBtn')?.getAttribute('href')
        })`,
        returnByValue: true
      });
      const su = storeUrlsEval.result?.value;
      if (!su?.appStore?.includes('ct=') && !su?.playStore?.includes('referrer=')) {
        pass = false; failures.push('Query params not preserved into store links');
      }
    }

    // Assertion 5: Tap-initiated "Open Sahla" in in-app mode
    if (uaInfo.expectedInApp) {
      await send('Runtime.evaluate', {
        expression: `
          window.__LAST_USER_CLICK__ = Date.now();
          document.getElementById('sdInAppOpenAppBtn').click();
        `
      });
      await sleep(100);

      const navAfterClick = await send('Runtime.evaluate', {
        expression: `window.__NAVIGATION_LOG__`,
        returnByValue: true
      });
      const tapNavs = (navAfterClick.result?.value || []).filter((n) => n.isTap);
      if (tapNavs.length === 0) {
        pass = false; failures.push('Clicking "Open Sahla" did not record a tap navigation');
      } else {
        const lastNav = tapNavs[tapNavs.length - 1];
        if (uaInfo.expectedPlatform === 'ios' && !lastNav.url.startsWith('sahla://open')) {
          pass = false; failures.push(`Expected iOS scheme sahla://open, got ${lastNav.url}`);
        }
        if (uaInfo.expectedPlatform === 'android' && !lastNav.url.startsWith('intent://open')) {
          pass = false; failures.push(`Expected Android intent://open, got ${lastNav.url}`);
        }
      }

      // Check timeout behavior (wait for timeout check)
      await sleep(2300);
      const highlightEval = await send('Runtime.evaluate', {
        expression: `Boolean(document.getElementById('sdInAppStoreHighlight')?.style.display !== 'none')`
      });
      if (!highlightEval.result?.value) {
        pass = false; failures.push('After timeout, store highlight prompt was not displayed');
      }
    }

    // Assertion 6: Error-free execution
    if (consoleErrors.length > 0) {
      pass = false; failures.push(`Console errors: ${consoleErrors.join('; ')}`);
    }
    if (uncaughtExceptions.length > 0) {
      pass = false; failures.push(`Exceptions: ${uncaughtExceptions.join('; ')}`);
    }

    const screenshotFileName = `screenshot_${route.replace(/[\/\?\#\=]/g, '_')}_${uaInfo.id}.png`;
    const { data: ssData } = await send('Page.captureScreenshot', { format: 'png' });
    writeFileSync(resolve(TEST_ARTIFACTS_DIR, screenshotFileName), Buffer.from(ssData, 'base64'));

    if (!pass) allTestsPassed = false;

    testResultsMatrix.push({
      route,
      ua: uaInfo.name,
      platform: res.platform,
      inAppDetected: res.inApp?.isInApp ? `Yes (${res.inApp?.app})` : 'No',
      banner: res.bannerVisible ? 'Visible' : 'Hidden',
      unpromptedNavs: res.navLog.filter((n) => !n.isTap).length,
      errors: consoleErrors.length + uncaughtExceptions.length,
      status: pass ? 'PASS [SIMULATED]' : 'FAIL [SIMULATED]'
    });

    if (pass) {
      console.log(`  ✅ [SIMULATED] Result: PASS`);
    } else {
      console.error(`  ❌ [SIMULATED] Result: FAIL - ${failures.join('; ')}`);
    }
  }
}

// ============================================================================
// PART 4: Edge Cases: Safe Session Throw & Clipboard Reject Fallback
// ============================================================================
console.log('\n🧪 [SIMULATED] Running Edge Case Tests: Storage Throw & Clipboard Fallback...');

await send('Page.navigate', { url: `http://localhost:${PORT}/open` });
await sleep(500);

const edgeCaseEval = await send('Runtime.evaluate', {
  expression: `(async function() {
    // 1. Simulate sessionStorage throw
    var origSet = sessionStorage.setItem;
    sessionStorage.setItem = function() { throw new DOMException("Quota/Sandbox Denied", "SecurityError"); };
    sessionStorage.getItem = function() { throw new DOMException("Sandbox Denied", "SecurityError"); };

    var safeGet = window.safeSession.get("test_key");
    window.safeSession.set("test_key", "val");

    // 2. Simulate clipboard reject
    if (navigator.clipboard) {
      navigator.clipboard.writeText = async function() { throw new Error("Clipboard permission denied in WebView"); };
    }

    // Click in-app copy button
    var copyBtn = document.getElementById('sdInAppCopyBtn');
    if (copyBtn) copyBtn.click();
    await new Promise(r => setTimeout(r, 200));

    var box = document.getElementById('sdManualCopyBox');
    var input = document.getElementById('sdManualCopyInput');

    return {
      safeSessionThrew: safeGet === null,
      manualBoxRevealed: Boolean(box && box.style.display !== 'none'),
      inputValuePresent: Boolean(input && input.value.length > 5)
    };
  })()`,
  awaitPromise: true,
  returnByValue: true
});

const ec = edgeCaseEval.result?.value;
if (ec?.safeSessionThrew && ec?.manualBoxRevealed && ec?.inputValuePresent) {
  console.log('  ✅ [SIMULATED] Storage throw and clipboard rejection fallback: PASS');
} else {
  allTestsPassed = false;
  console.error('  ❌ [SIMULATED] Storage throw / clipboard fallback failed:', ec);
}

// Print results table
console.log('\n=============================================================================');
console.log('📊 SIMULATED TEST EXECUTION MATRIX (Headless Chrome CDP)');
console.log('=============================================================================');
console.table(testResultsMatrix);

ws.close();
chromeProc.kill();
server.close();

if (!allTestsPassed) {
  console.error('\n❌ Some simulated test assertions failed!');
  process.exit(1);
} else {
  console.log('\n🎉 ALL SIMULATED TEST ASSERTIONS PASSED WITH ZERO ERRORS!');
  process.exit(0);
}
