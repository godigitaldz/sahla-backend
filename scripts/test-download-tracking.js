import { spawn } from 'node:child_process';
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'node:fs';
import { resolve, extname } from 'node:path';
import http from 'node:http';
import WebSocket from 'ws';

const PORT = 3571;
const CHROME_PORT = 9224;
const ARTIFACTS = resolve('test-artifacts');
if (!existsSync(ARTIFACTS)) mkdirSync(ARTIFACTS, { recursive: true });
const events = [];
const mime = { '.html': 'text/html; charset=utf-8', '.js': 'application/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.webp': 'image/webp', '.png': 'image/png', '.svg': 'image/svg+xml', '.json': 'application/json' };
const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);
  if (url.pathname === '/__test_reset') {
    res.writeHead(200, { 'content-type': 'text/html' }); res.end('<!doctype html><title>reset</title>'); return;
  }
  if (url.pathname === '/api/track/download' && req.method === 'POST') {
    const chunks = [];
    for await (const chunk of req) chunks.push(chunk);
    try { events.push(JSON.parse(Buffer.concat(chunks).toString('utf8'))); } catch {}
    res.writeHead(204); res.end(); return;
  }
  let file = url.pathname === '/open' || url.pathname.startsWith('/open/')
    ? 'public/open.html'
    : url.pathname === '/download' || url.pathname.startsWith('/download/')
      ? 'public/download.html'
      : url.pathname === '/' ? 'public/index.html' : `public/${url.pathname.replace(/^\//, '')}`;
  if (url.pathname === '/config.js') {
    const source = readFileSync('public/config.js', 'utf8') + '\nwindow.CONFIG.OPEN_TIMEOUT_MS = 60000;';
    res.writeHead(200, { 'content-type': mime['.js'] }); res.end(source); return;
  }
  if (!existsSync(file)) { res.writeHead(404); res.end('not found'); return; }
  res.writeHead(200, { 'content-type': mime[extname(file)] || 'application/octet-stream', 'cache-control': 'no-cache' });
  if (url.pathname === '/download.js') {
    // The test hook records the exact native navigation URL. Suppress the OS
    // handoff only in this local test copy so CDP can inspect the same page.
    const source = readFileSync(file, 'utf8').replace('window.location.href = url;', 'if (!window.__CDP_SIMULATION__) window.location.href = url;');
    res.end(source); return;
  }
  res.end(readFileSync(file));
});
server.listen(PORT);

const sleep = (ms) => new Promise((resolveSleep) => setTimeout(resolveSleep, ms));
const chrome = spawn('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', [
  '--headless=new', '--disable-gpu', `--remote-debugging-port=${CHROME_PORT}`,
  '--no-first-run', '--no-default-browser-check', 'about:blank',
]);

async function waitForChrome() {
  for (let i = 0; i < 30; i += 1) {
    await sleep(250);
    try {
      const response = await fetch(`http://127.0.0.1:${CHROME_PORT}/json/version`);
      const data = await response.json();
      if (data.webSocketDebuggerUrl) return data;
    } catch {}
  }
  throw new Error('Chrome DevTools did not start');
}

let ws;
let nextId = 1;
const pending = new Map();
const chromeInfo = await waitForChrome();
const tab = await (await fetch(`http://127.0.0.1:${CHROME_PORT}/json/new?about:blank`, { method: 'PUT' })).json();
ws = new WebSocket(tab.webSocketDebuggerUrl);
await new Promise((resolveOpen) => ws.once('open', resolveOpen));
ws.on('message', (raw) => {
  const msg = JSON.parse(raw);
  if (!msg.id || !pending.has(msg.id)) return;
  const item = pending.get(msg.id); pending.delete(msg.id);
  msg.error ? item.reject(new Error(msg.error.message)) : item.resolve(msg.result);
});
const cdp = (method, params = {}) => new Promise((resolveCall, rejectCall) => {
  const id = nextId++; pending.set(id, { resolve: resolveCall, reject: rejectCall });
  ws.send(JSON.stringify({ id, method, params }));
});
await cdp('Page.enable'); await cdp('Runtime.enable'); await cdp('Network.enable');
// Keep custom-scheme/store attempts inside the simulated browser instead of
// handing them to the desktop OS while still recording the requested URL.
await cdp('Network.setBlockedURLs', { urls:['sahla://*', 'intent://*', 'https://apps.apple.com/*', 'https://play.google.com/*', 'https://fonts.googleapis.com/*', 'https://fonts.gstatic.com/*'] });
await cdp('Page.addScriptToEvaluateOnNewDocument', { source: `
  window.__NAVIGATION_LOG__ = [];
  window.__CDP_SIMULATION__ = true;
  window.__TRACK_CAPTURE__ = [];
  window.__SD_ON_NAVIGATE__ = function(url) { window.__NAVIGATION_LOG__.push(String(url)); };
  var mode = 'success';
  try { mode = localStorage.getItem('__download_tracking_mode') || 'success'; } catch (_) {}
  var originalFetch = window.fetch.bind(window);
  if (mode === 'success' || mode === 'storage-throws') {
    try { Object.defineProperty(navigator, 'sendBeacon', { configurable:true, value:function(url, body) {
      if (String(url).includes('/api/track/download')) {
        Promise.resolve(body && body.text ? body.text() : String(body)).then(function(text) {
          try { window.__TRACK_CAPTURE__.push(JSON.parse(text)); } catch (_) {}
          originalFetch(url, { method:'POST', headers:{'content-type':'application/json'}, body:text }).catch(function(){});
        });
        return true;
      }
      return false;
    }}); } catch (_) {}
  }
  if (mode === 'storage-throws') {
    try { Object.defineProperty(Storage.prototype, 'getItem', { configurable:true, value:function(){ throw new DOMException('blocked','SecurityError'); } }); } catch (_) {}
    try { Object.defineProperty(Storage.prototype, 'setItem', { configurable:true, value:function(){ throw new DOMException('blocked','SecurityError'); } }); } catch (_) {}
    try { Object.defineProperty(Storage.prototype, 'removeItem', { configurable:true, value:function(){ throw new DOMException('blocked','SecurityError'); } }); } catch (_) {}
  }
  if (mode === 'beacon-undefined') {
    try { Object.defineProperty(navigator, 'sendBeacon', { configurable:true, value:undefined }); } catch (_) {}
  } else if (['http-500','hanging','blocked'].includes(mode)) {
    try { Object.defineProperty(navigator, 'sendBeacon', { configurable:true, value:function(){ return false; } }); } catch (_) {}
  }
  window.fetch = function(input, init) {
    if (String(input).includes('/api/track/download')) {
      if (mode === 'http-500') return Promise.resolve(new Response(null, { status:500 }));
      if (mode === 'hanging') return new Promise(function(){});
      if (mode === 'blocked') return Promise.reject(new TypeError('offline/blocked'));
    }
    return originalFetch(input, init);
  };
  try { Location.prototype.replace = function(url) { window.__NAVIGATION_LOG__.push(String(url)); }; } catch (_) {}
` });

const uAs = [
  ['iPhone Safari', 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1', true, 'ios', false],
  ['iPhone Instagram', 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Instagram 332.0', true, 'ios', true],
  ['iPhone Snapchat', 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Snapchat/12.88', true, 'ios', true],
  ['Android Chrome', 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Mobile Safari/537.36', true, 'android', false],
  ['Android Instagram WebView', 'Mozilla/5.0 (Linux; Android 14; Pixel 8; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/125.0 Mobile Safari/537.36 Instagram 332.0', true, 'android', true],
  ['Desktop Chrome', 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0 Safari/537.36', false, 'desktop', false],
];
const routes = ['/open', '/open?utm_source=ig', '/download', '/#download'];
const matrix = [];

try {
  for (const [name, ua, mobile, platform, inApp] of uAs) {
    await cdp('Emulation.setDeviceMetricsOverride', { width: mobile ? 390 : 1440, height: 844, deviceScaleFactor: 2, mobile, hasTouch: mobile });
    await cdp('Emulation.setUserAgentOverride', { userAgent: ua });
    for (const route of routes) {
      events.length = 0;
      await cdp('Page.navigate', { url: `http://localhost:${PORT}/__test_reset` }); await sleep(80);
      await cdp('Runtime.evaluate', { expression: `localStorage.clear(); sessionStorage.clear(); localStorage.setItem('__download_tracking_mode','success');` });
      await cdp('Page.navigate', { url: `http://localhost:${PORT}${route}` });
      for (let readyAttempt = 0; readyAttempt < 30; readyAttempt += 1) {
        const ready = await cdp('Runtime.evaluate', { expression: `typeof window.detectPlatform === 'function'`, returnByValue:true });
        if (ready.result?.value) break;
        await sleep(100);
      }
      const first = await cdp('Runtime.evaluate', { expression: `({href:location.href,ready:document.readyState,hasTrack:typeof window.track,hasSmart:typeof window.SmartDownload,session:window.safeSession?.get('sd_download_tracking_session'), platform:window.detectPlatform?.(), inApp:window.detectInApp?.()})`, returnByValue:true });
      await cdp('Runtime.evaluate', { expression: 'window.SmartDownload?.render()' }); await sleep(300);
      const expectedEvents = ['page_view', 'platform_detected', ...(inApp ? ['inapp_detected'] : []), ...(platform === 'desktop' ? [] : ['app_open_attempt'])];
      for (let eventAttempt = 0; eventAttempt < 25; eventAttempt += 1) {
        const captured = await cdp('Runtime.evaluate', { expression:`(window.__TRACK_CAPTURE__ || []).map((e) => e.event)`, returnByValue:true });
        if (expectedEvents.every((name) => (captured.result?.value || []).includes(name))) break;
        await sleep(100);
      }
      const capturedPayloads = await cdp('Runtime.evaluate', { expression:`window.__TRACK_CAPTURE__ || []`, returnByValue:true });
      const payloads = capturedPayloads.result?.value || [];
      const sessionIds = [...new Set(payloads.map((e) => e.sessionId))];
      const count = (eventName) => payloads.filter((e) => e.event === eventName).length;
      const issues = [];
      if (first.result?.value?.platform !== platform) issues.push(`platform ${first.result?.value?.platform} ${JSON.stringify(first.result?.value)}`);
      if (sessionIds.length !== 1 || !sessionIds[0]) issues.push('session id missing or unstable');
      if (count('page_view') !== 1) issues.push(`page_view count ${count('page_view')}`);
      if (count('platform_detected') !== 1) issues.push(`platform_detected count ${count('platform_detected')}`);
      if (inApp && count('inapp_detected') !== 1) issues.push(`inapp_detected count ${count('inapp_detected')}`);
      if (route.includes('utm_source=ig') && !payloads.some((e) => e.source?.utm_source === 'ig')) issues.push('utm_source missing');
      matrix.push({ route, ua:name, status:issues.length ? `FAIL: ${issues.join(', ')}` : 'PASS [SIMULATED]' });
      if (issues.length) console.error(`[SIMULATED] ${route} × ${name}: ${issues.join('; ')}`);
    }
  }

  // Compare redirect/navigation logs while the telemetry endpoint is healthy and failing.
  await cdp('Emulation.setDeviceMetricsOverride', { width:390, height:844, deviceScaleFactor:2, mobile:true, hasTouch:true });
  await cdp('Emulation.setUserAgentOverride', { userAgent:uAs[0][1] });
  const modes = ['success','http-500','hanging','blocked','beacon-undefined','storage-throws'];
  let baseline = null;
  const failureRows = [];
  for (const mode of modes) {
    await cdp('Page.navigate', { url:`http://localhost:${PORT}/__test_reset` }); await sleep(80);
    await cdp('Runtime.evaluate', { expression:`localStorage.clear(); sessionStorage.clear(); localStorage.setItem('__download_tracking_mode',${JSON.stringify(mode)});` });
    await cdp('Page.navigate', { url:`http://localhost:${PORT}/open` }); await sleep(500);
    const nav = await cdp('Runtime.evaluate', { expression:'window.__NAVIGATION_LOG__ || []', returnByValue:true });
    const normalized = (nav.result?.value || []).map(String);
    if (mode === 'success') baseline = normalized;
    const same = JSON.stringify(normalized) === JSON.stringify(baseline);
    failureRows.push({ mode, navigation:normalized.join(' → '), result:same ? 'IDENTICAL [SIMULATED]' : 'DIFFERS [SIMULATED]' });
    if (!same) console.error(`[SIMULATED] Navigation differed for tracking mode ${mode}`);
  }

  const screenshot = await cdp('Page.captureScreenshot', { format:'png' });
  writeFileSync(resolve(ARTIFACTS, 'download-tracking-failure-matrix.png'), Buffer.from(screenshot.data, 'base64'));
  console.log('\n[SIMULATED] Download tracking route/device matrix'); console.table(matrix);
  console.log('\n[SIMULATED] Redirect behavior during endpoint failure'); console.table(failureRows);
  if (matrix.some((row) => row.status.startsWith('FAIL')) || failureRows.some((row) => row.result.startsWith('DIFFERS'))) process.exitCode = 1;
} finally {
  ws?.close(); chrome.kill(); server.close();
}
