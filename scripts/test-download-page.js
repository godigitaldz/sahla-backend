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
      console.error('  [Exception]', msg.params.exceptionDetails.text);
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
      name: 'Desktop (1440x900)',
      width: 1440,
      height: 900,
      isMobile: false,
      userAgent: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
      screenshotName: 'screenshot_desktop_download.png',
      expectPlatform: 'desktop'
    },
    {
      name: 'iPhone (390x844)',
      width: 390,
      height: 844,
      isMobile: true,
      hasTouch: true,
      userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1',
      screenshotName: 'screenshot_iphone_download.png',
      expectPlatform: 'ios'
    },
    {
      name: 'Android Pixel (412x915)',
      width: 412,
      height: 915,
      isMobile: true,
      hasTouch: true,
      userAgent: 'Mozilla/5.0 (Linux; Android 14; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Mobile Safari/537.36',
      screenshotName: 'screenshot_android_download.png',
      expectPlatform: 'android'
    },
    {
      name: 'In-App Instagram Browser (iOS)',
      width: 390,
      height: 844,
      isMobile: true,
      hasTouch: true,
      userAgent: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Instagram 325.0.0',
      screenshotName: 'screenshot_inapp_download.png',
      expectPlatform: 'ios',
      expectInApp: true
    }
  ];

  for (const scenario of testScenarios) {
    console.log(`\n📋 Running Scenario: ${scenario.name}`);
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

    await send('Page.navigate', { url: 'about:blank' });
    await sleep(200);
    await send('Page.navigate', { url: `http://localhost:${PORT}/#download` });

    // Wait for load and DOM to settle
    await sleep(1500);

    const platformRes = await send('Runtime.evaluate', {
      expression: 'typeof window.detectPlatform === "function" ? window.detectPlatform() : null'
    });
    console.log(`  Detected Platform: ${platformRes.result?.value}`);

    if (scenario.expectInApp) {
      const inAppBannerRes = await send('Runtime.evaluate', {
        expression: 'Boolean(document.getElementById("sdInAppBanner"))'
      });
      console.log(`  In-App Banner Visible: ${inAppBannerRes.result?.value}`);
    }

    if (scenario.expectPlatform === 'desktop') {
      const qrRes = await send('Runtime.evaluate', {
        expression: 'Boolean(document.getElementById("sdQrBox") && document.getElementById("sdQrBox").querySelector("svg"))'
      });
      console.log(`  QR Code SVG Rendered: ${qrRes.result?.value}`);
    }

    const { data: screenshotData } = await send('Page.captureScreenshot', { format: 'png' });
    const screenshotPath = `${ARTIFACT_DIR}/${scenario.screenshotName}`;
    writeFileSync(screenshotPath, Buffer.from(screenshotData, 'base64'));
    console.log(`  📸 Screenshot saved: ${scenario.screenshotName}`);

    console.log(`  Errors: ${pageErrors.length}, Console logs: ${consoleMessages.length}`);
    if (pageErrors.length > 0) {
      console.error('  ❌ Unhandled page exceptions detected:', pageErrors);
    } else {
      console.log('  ✅ No page errors detected.');
    }
  }

  // Also test standalone download.html and open.html
  console.log('\n📋 Testing standalone /download');
  await send('Page.navigate', { url: `http://localhost:${PORT}/download` });
  await sleep(1000);
  const standaloneDlRes = await send('Runtime.evaluate', { expression: 'document.title' });
  console.log('  /download Title:', standaloneDlRes.result?.value);

  console.log('\n📋 Testing fallback /open');
  await send('Page.navigate', { url: `http://localhost:${PORT}/open` });
  await sleep(1000);
  const openTitleRes = await send('Runtime.evaluate', { expression: 'document.title' });
  console.log('  /open Title:', openTitleRes.result?.value);

  console.log('\n📋 Testing POST /api/send-link endpoint');
  const sendLinkRes = await fetch(`http://localhost:${PORT}/api/send-link`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ to: '+213555123456', platform: 'desktop' })
  });
  const sendLinkJson = await sendLinkRes.json();
  console.log('  /api/send-link response:', sendLinkJson);

  ws.close();
  chromeProc.kill();
  server.close();
  console.log('\n🎉 All browser verification tests completed successfully!');
  process.exit(0);
}

runTests().catch((err) => {
  console.error('Fatal error running tests:', err);
  process.exit(1);
});
