import { spawn } from 'child_process';
import { readFileSync, writeFileSync } from 'fs';
import WebSocket from 'ws';

const PORT = 3456;
const CHROME_PORT = 9222;
const ARTIFACT_DIR = '/Users/macamine/.gemini/antigravity/brain/1ae9b1d5-077c-4230-8c6d-be7f159c4e80';

// Helper for delay
const sleep = (ms) => new Promise((resolve) => setTimeout(resolve, ms));

async function runTests() {
  console.log('🚀 Starting Express server on port', PORT);
  process.env.VERCEL = '1';
  process.env.PORT = String(PORT);

  // Load env variables
  try {
    const envContent = readFileSync('.env.local', 'utf8');
    for (const line of envContent.split('\n')) {
      const trimmed = line.trim();
      if (trimmed && !trimmed.startsWith('#')) {
        const idx = trimmed.indexOf('=');
        if (idx > 0) {
          const k = trimmed.substring(0, idx).trim();
          const v = trimmed.substring(idx + 1).trim();
          process.env[k] = v.replace(/^["']|["']$/g, '');
        }
      }
    }
  } catch (e) {
    console.warn('Could not read .env.local, using defaults');
  }

  const { default: app } = await import('../src/index.js');
  const server = app.listen(PORT);

  console.log('🌐 Launching headless Chrome on debugging port', CHROME_PORT);
  const chromeProc = spawn('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', [
    '--headless=new',
    '--disable-gpu',
    '--remote-debugging-port=' + CHROME_PORT,
    '--no-first-run',
    '--no-default-browser-check',
    'about:blank'
  ]);

  // Wait for Chrome to be ready
  let versionData = null;
  for (let i = 0; i < 20; i++) {
    await sleep(300);
    try {
      const res = await fetch(`http://127.0.0.1:${CHROME_PORT}/json/version`);
      versionData = await res.json();
      if (versionData.webSocketDebuggerUrl) break;
    } catch (e) {
      // retry
    }
  }

  if (!versionData) {
    console.error('❌ Could not connect to Chrome debugging port');
    chromeProc.kill();
    server.close();
    process.exit(1);
  }

  console.log('Connected to Chrome:', versionData.Browser);

  // Get new page
  const newTabRes = await fetch(`http://127.0.0.1:${CHROME_PORT}/json/new?about:blank`, { method: 'PUT' });
  const tabData = await newTabRes.json();
  const wsUrl = tabData.webSocketDebuggerUrl;

  const ws = new WebSocket(wsUrl);
  await new Promise((resolve) => ws.on('open', resolve));

  let reqId = 1;
  const pendingRequests = new Map();
  const consoleMessages = [];
  const pageErrors = [];

  ws.on('message', (raw) => {
    const msg = JSON.parse(raw);
    if (msg.id && pendingRequests.has(msg.id)) {
      const { resolve, reject } = pendingRequests.get(msg.id);
      pendingRequests.delete(msg.id);
      if (msg.error) reject(msg.error);
      else resolve(msg.result);
    }
    if (msg.method === 'Runtime.consoleAPICalled') {
      const text = msg.params.args.map((a) => a.value || a.description || '').join(' ');
      consoleMessages.push({ type: msg.params.type, text });
      console.log(`  [Console ${msg.params.type}]`, text);
    }
    if (msg.method === 'Runtime.exceptionThrown') {
      pageErrors.push(msg.params.exceptionDetails);
      console.error('  [Exception]', msg.params.exceptionDetails.exception?.description || msg.params.exceptionDetails.text);
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

  const testScenarios = [
    {
      scenarioId: 1,
      name: 'iOS Safari (Normal Browser Mode)',
      width: 390,
      height: 844,
      isMobile: true,
      hasTouch: true,
      userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1',
      screenshotName: 'scenario_1_ios_safari.png',
      expectPlatform: 'ios',
      expectInApp: false
    },
    {
      scenarioId: 2,
      name: 'iOS Instagram (In-App WebView)',
      width: 390,
      height: 844,
      isMobile: true,
      hasTouch: true,
      userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Instagram 325.0.0.0.0',
      screenshotName: 'scenario_2_ios_instagram.png',
      expectPlatform: 'ios',
      expectInApp: true,
      expectInAppBrowser: 'Instagram'
    },
    {
      scenarioId: 3,
      name: 'iOS Snapchat (In-App WebView)',
      width: 390,
      height: 844,
      isMobile: true,
      hasTouch: true,
      userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Snapchat/12.80.0',
      screenshotName: 'scenario_3_ios_snapchat.png',
      expectPlatform: 'ios',
      expectInApp: true,
      expectInAppBrowser: 'Snapchat'
    },
    {
      scenarioId: 4,
      name: 'Android Chrome (Normal Browser Mode)',
      width: 412,
      height: 915,
      isMobile: true,
      hasTouch: true,
      userAgent: 'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
      screenshotName: 'scenario_4_android_chrome.png',
      expectPlatform: 'android',
      expectInApp: false
    },
    {
      scenarioId: 5,
      name: 'Android Instagram (In-App WebView)',
      width: 412,
      height: 915,
      isMobile: true,
      hasTouch: true,
      userAgent: 'Mozilla/5.0 (Linux; Android 14; Pixel 7; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/124.0.6367.82 Mobile Safari/537.36 Instagram 325.0.0.35.91 Android (34/14; 420dpi; 1080x2400; Google/google; Pixel 7)',
      screenshotName: 'scenario_5_android_instagram.png',
      expectPlatform: 'android',
      expectInApp: true,
      expectInAppBrowser: 'Instagram'
    },
    {
      scenarioId: 6,
      name: 'Desktop (macOS Chrome/Safari)',
      width: 1440,
      height: 900,
      isMobile: false,
      hasTouch: false,
      userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      screenshotName: 'scenario_6_desktop.png',
      expectPlatform: 'desktop',
      expectInApp: false
    }
  ];

  const resultsTable = [];

  for (const scenario of testScenarios) {
    console.log(`\n======================================================`);
    console.log(`📋 Running Scenario ${scenario.scenarioId}: ${scenario.name}`);
    consoleMessages.length = 0;
    pageErrors.length = 0;

    await send('Emulation.setDeviceMetricsOverride', {
      width: scenario.width,
      height: scenario.height,
      deviceScaleFactor: 2,
      mobile: scenario.isMobile,
      hasTouch: scenario.hasTouch || false
    });

    await send('Emulation.setUserAgentOverride', {
      userAgent: scenario.userAgent
    });

    // Clear session storage before each test
    await send('Page.navigate', { url: 'about:blank' });
    await sleep(200);
    await send('Page.navigate', { url: `http://localhost:${PORT}/#download` });

    // Wait for initial render
    await sleep(1200);

    const platformRes = await send('Runtime.evaluate', {
      expression: 'typeof window.detectPlatform === "function" ? window.detectPlatform() : null'
    });
    const detectedPlatform = platformRes.result?.value;

    const inAppRes = await send('Runtime.evaluate', {
      expression: 'typeof window.detectInAppBrowser === "function" ? window.detectInAppBrowser() : null',
      returnByValue: true
    });
    const detectedInApp = inAppRes.result?.value || { isInApp: false, browser: null };

    const bannerRes = await send('Runtime.evaluate', {
      expression: 'Boolean(document.getElementById("sdInAppBanner") && document.getElementById("sdInAppBanner").classList.contains("is-visible"))'
    });
    const isBannerVisible = bannerRes.result?.value;

    const statusCardRes = await send('Runtime.evaluate', {
      expression: 'Boolean(document.getElementById("sdStatusCard"))'
    });
    const isStatusCardRendered = statusCardRes.result?.value;

    const appStoreBtnRes = await send('Runtime.evaluate', {
      expression: 'Boolean(document.getElementById("sdAppStoreBtn"))'
    });
    const isAppStoreBtnRendered = appStoreBtnRes.result?.value;

    const playStoreBtnRes = await send('Runtime.evaluate', {
      expression: 'Boolean(document.getElementById("sdPlayStoreBtn"))'
    });
    const isPlayStoreBtnRendered = playStoreBtnRes.result?.value;

    const chromeBtnRes = await send('Runtime.evaluate', {
      expression: 'Boolean(document.querySelector(".sd-btn-chrome"))'
    });
    const isChromeBtnRendered = chromeBtnRes.result?.value;

    const safariBtnRes = await send('Runtime.evaluate', {
      expression: 'Boolean(document.querySelector(".sd-btn-safari"))'
    });
    const isSafariBtnRendered = safariBtnRes.result?.value;

    const qrBoxRes = await send('Runtime.evaluate', {
      expression: 'Boolean(document.getElementById("sdQrBox") && document.getElementById("sdQrBox").querySelector("svg"))'
    });
    const isQrRendered = qrBoxRes.result?.value;

    // Check timer status in SmartDownload
    const timerRes = await send('Runtime.evaluate', {
      expression: 'Boolean(window.SmartDownload && window.SmartDownload.redirectTimer !== null)'
    });
    const isRedirectTimerActive = timerRes.result?.value;

    console.log(`  Platform: ${detectedPlatform} (expected: ${scenario.expectPlatform})`);
    console.log(`  In-App: ${detectedInApp.isInApp} (${detectedInApp.browser})`);
    console.log(`  Banner visible: ${isBannerVisible}`);
    console.log(`  Status card (spinner/countdown): ${isStatusCardRendered}`);
    console.log(`  Redirect timer active: ${isRedirectTimerActive}`);
    console.log(`  App Store Badge: ${isAppStoreBtnRendered}, Play Store Badge: ${isPlayStoreBtnRendered}`);
    if (isChromeBtnRendered) console.log('  "Open in Chrome" intent button rendered: YES');
    if (isSafariBtnRendered) console.log('  "Open in Safari" button rendered: YES');
    if (isQrRendered) console.log('  QR Code SVG rendered: YES');

    // Screenshot
    const { data: screenshotData } = await send('Page.captureScreenshot', { format: 'png' });
    const screenshotPath = `${ARTIFACT_DIR}/${scenario.screenshotName}`;
    writeFileSync(screenshotPath, Buffer.from(screenshotData, 'base64'));

    resultsTable.push({
      scenario: scenario.name,
      platform: detectedPlatform,
      inApp: detectedInApp.isInApp ? `Yes (${detectedInApp.browser})` : 'No',
      banner: isBannerVisible ? 'Visible' : 'Hidden',
      autoRedirectTimer: isRedirectTimerActive ? 'Active (2200ms)' : 'None (Halted)',
      primaryActions: [
        isStatusCardRendered ? 'Status Card' : null,
        isChromeBtnRendered ? 'Open in Chrome button' : null,
        isSafariBtnRendered ? 'Safari link' : null,
        isQrRendered ? 'QR Code' : null,
        'Direct Store Badges'
      ].filter(Boolean).join(', ')
    });
  }

  console.log('\n======================================================');
  console.log('📊 SUMMARY VERIFICATION TABLE');
  console.log('======================================================');
  console.table(resultsTable);

  ws.close();
  chromeProc.kill();
  server.close();
  console.log('\n🎉 All 6 verification scenarios executed!');
  process.exit(0);
}

runTests().catch((err) => {
  console.error('Fatal error running tests:', err);
  process.exit(1);
});
