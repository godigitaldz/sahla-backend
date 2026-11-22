import { spawn } from 'node:child_process';
import { existsSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs';
import { resolve } from 'node:path';
import http from 'node:http';
import WebSocket from 'ws';

const PORT = 3573;
const CHROME_PORT = 9226;
const outputDir = resolve('test-artifacts');
if (!existsSync(outputDir)) mkdirSync(outputDir, { recursive: true });
const seededStats = {
  totals: { entered:127, reached_store:54, app_open_attempts:72, likely_opened:23, copy_link:9, escape_tap:14, retry:6, conversion_rate:42.52, likely_opened_rate:18.11 },
  byPlatform: [{key:'ios',sessions:67},{key:'android',sessions:51},{key:'desktop',sessions:9}],
  byInApp: [{key:'Instagram',sessions:44},{key:'none',sessions:48},{key:'Snapchat',sessions:15},{key:'TikTok',sessions:12},{key:'Facebook',sessions:8}],
  bySource: [{source:'instagram',campaign:'summer',sessions:52},{source:'direct',campaign:null,sessions:41},{source:'snapchat',campaign:'creator',sessions:19},{source:'other',campaign:null,sessions:15}],
  byRoute: [{key:'/open',sessions:73},{key:'/#download',sessions:31},{key:'/download',sessions:23}],
  byDay: [
    {day:'2026-11-16',entered:12,reached_store:4,app_open_attempts:7,likely_opened:2},
    {day:'2026-11-17',entered:18,reached_store:7,app_open_attempts:10,likely_opened:3},
    {day:'2026-11-18',entered:21,reached_store:9,app_open_attempts:12,likely_opened:4},
    {day:'2026-11-19',entered:24,reached_store:10,app_open_attempts:13,likely_opened:5},
    {day:'2026-11-20',entered:26,reached_store:11,app_open_attempts:15,likely_opened:4},
    {day:'2026-11-21',entered:26,reached_store:13,app_open_attempts:15,likely_opened:5},
  ],
};

const server = http.createServer(async (req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);
  if (url.pathname.startsWith('/api/performance/')) {
    res.writeHead(200, { 'content-type':'application/json', 'set-cookie':'perf_auth=simulated; Path=/; SameSite=Lax' });
    res.end(JSON.stringify(url.pathname.endsWith('/download-stats') ? {success:true,...seededStats} : {success:true,data:[]}));
    return;
  }
  let file = url.pathname === '/performance' ? 'public/performance.html'
    : url.pathname === '/' ? 'public/index.html' : `public/${url.pathname.replace(/^\//, '')}`;
  if (!existsSync(file)) { res.writeHead(404); res.end('not found'); return; }
  const ext = file.split('.').pop();
  const types = { html:'text/html; charset=utf-8', js:'application/javascript; charset=utf-8', css:'text/css; charset=utf-8', png:'image/png', webp:'image/webp', svg:'image/svg+xml' };
  res.writeHead(200, { 'content-type':types[ext] || 'application/octet-stream', 'cache-control':'no-cache' });
  res.end(readFileSync(file));
});
server.listen(PORT);
const pause = (ms) => new Promise((resolvePause) => setTimeout(resolvePause, ms));
const chrome = spawn('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', [
  '--headless=new','--disable-gpu',`--remote-debugging-port=${CHROME_PORT}`,'--no-first-run','--no-default-browser-check','about:blank',
]);
let ws;
try {
  let version;
  for (let i=0;i<30;i+=1) {
    await pause(250);
    try { version = await (await fetch(`http://127.0.0.1:${CHROME_PORT}/json/version`)).json(); if (version.webSocketDebuggerUrl) break; } catch {}
  }
  if (!version?.webSocketDebuggerUrl) throw new Error('Chrome DevTools did not start');
  const tab = await (await fetch(`http://127.0.0.1:${CHROME_PORT}/json/new?about:blank`,{method:'PUT'})).json();
  ws = new WebSocket(tab.webSocketDebuggerUrl);
  await new Promise((resolveOpen) => ws.once('open', resolveOpen));
  let id=0; const waiting=new Map();
  ws.on('message',(raw)=>{const msg=JSON.parse(raw);if(msg.id&&waiting.has(msg.id)){const p=waiting.get(msg.id);waiting.delete(msg.id);msg.error?p.reject(msg.error):p.resolve(msg.result);}});
  const cdp=(method,params={})=>new Promise((resolveCall,rejectCall)=>{const n=++id;waiting.set(n,{resolve:resolveCall,reject:rejectCall});ws.send(JSON.stringify({id:n,method,params}));});
  await cdp('Page.enable'); await cdp('Runtime.enable'); await cdp('Emulation.setDeviceMetricsOverride',{width:2800,height:1400,deviceScaleFactor:1,mobile:false});
  await cdp('Page.navigate',{url:`http://localhost:${PORT}/`}); await pause(100);
  await cdp('Runtime.evaluate',{expression:`localStorage.setItem('sahla_perf_lang','ar');`});
  await cdp('Page.navigate',{url:`http://localhost:${PORT}/performance`}); await pause(1300);
  await cdp('Runtime.evaluate',{expression:`document.getElementById('gate')?.classList.add('hidden');document.getElementById('app')?.classList.remove('hidden');document.getElementById('app')?.style.setProperty('direction','ltr');document.getElementById('panel-download-funnel')?.style.setProperty('direction','ltr');document.querySelector('.tab[data-tab="download-funnel"]')?.click();`});
  for(let i=0;i<30;i+=1){
    const loaded=await cdp('Runtime.evaluate',{expression:`document.getElementById('dfEntered')?.textContent === '127'`,returnByValue:true});
    if(loaded.result?.value)break;
    await pause(100);
  }
  await pause(250);
  const image=await cdp('Page.captureScreenshot',{format:'png',captureBeyondViewport:true});
  const output=resolve(outputDir,'performance-download-funnel.png');
  writeFileSync(output,Buffer.from(image.data,'base64'));
  const proof=await cdp('Runtime.evaluate',{expression:`({entered:document.getElementById('dfEntered')?.textContent,store:document.getElementById('dfStore')?.textContent,section:document.getElementById('panel-download-funnel')?.className,scrollWidth:document.documentElement.scrollWidth,innerWidth,scrollX,app:document.getElementById('app').getBoundingClientRect().toJSON(),main:document.querySelector('main').getBoundingClientRect().toJSON()})`,returnByValue:true});
  if(proof.result?.value?.entered!=='127')throw new Error(`Seeded funnel failed to render: ${JSON.stringify(proof.result?.value)}`);
  console.log(`[SIMULATED] Saved seeded Performance funnel screenshot: ${output} (${JSON.stringify(proof.result?.value)})`);
} finally {
  ws?.close(); chrome.kill(); server.close();
}
