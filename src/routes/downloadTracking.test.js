import test, { before, after } from 'node:test';
import assert from 'node:assert/strict';
import express from 'express';

process.env.SUPABASE_URL ||= 'http://127.0.0.1:54321';
process.env.SUPABASE_ANON_KEY ||= 'test-anon-key';
process.env.SUPABASE_SERVICE_ROLE_KEY ||= 'test-service-role-key';
process.env.PERFORMANCE_DASHBOARD_PASSWORD = 'local-test-password';
process.env.PERFORMANCE_SESSION_SECRET = 'local-test-session-secret';

let supabaseAdmin;
let inserts = [];
const storedPageViews = new Set();
let rpcResult = null;
let server;
let baseUrl;

before(async () => {
  ({ supabaseAdmin } = await import('../config/supabase.js'));
  const { default: trackingRouter } = await import('./downloadTracking.js');
  const { default: performanceRouter } = await import('./performanceDashboard.js');
  supabaseAdmin.from = (table) => ({
    insert: async (row) => {
      assert.equal(table, 'download_events');
      if (row.event === 'page_view' && storedPageViews.has(row.session_id)) return { error: { code: '23505' } };
      if (row.event === 'page_view') storedPageViews.add(row.session_id);
      inserts.push(row);
      return { error: null };
    },
  });
  supabaseAdmin.rpc = async (name, args) => {
    assert.equal(name, 'download_event_stats');
    assert.equal(args.p_tz, 'Africa/Algiers');
    return { data: rpcResult, error: null };
  };
  const app = express();
  app.set('trust proxy', 1);
  app.use('/api/track', trackingRouter);
  app.use(express.json());
  app.use('/api/performance', performanceRouter);
  server = app.listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  baseUrl = `http://127.0.0.1:${server.address().port}`;
});

after(async () => {
  if (server) await new Promise((resolve) => server.close(resolve));
});

function event(overrides = {}) {
  return {
    event: 'page_view', sessionId: 'session-12345678', platform: 'ios', inApp: 'none',
    route: '/open', source: { utm_source: 'instagram', utm_campaign: 'summer' },
    props: { unexpected: 'discard-me' }, buildVersion: 'abc123', lang: 'ar',
    ...overrides,
  };
}

async function post(payload, options = {}) {
  const response = await fetch(`${baseUrl}/api/track/download`, {
    method: 'POST',
    headers: {
      'content-type': options.contentType || 'application/json',
      'x-forwarded-for': options.ip || '198.51.100.22',
      ...(options.userAgent !== undefined ? { 'user-agent': options.userAgent } : { 'user-agent': 'Mozilla/5.0 Chrome/125' }),
      ...(options.origin !== null ? { origin: options.origin || baseUrl } : {}),
    },
    body: options.raw ?? (typeof payload === 'string' ? payload : JSON.stringify(payload)),
  });
  await new Promise((resolve) => setImmediate(resolve));
  return response;
}

test('ingest stores valid events, drops unknown data, and accepts text/plain beacons', async () => {
  inserts = [];
  storedPageViews.clear();
  let response = await post(event(), { contentType: 'text/plain' });
  assert.equal(response.status, 204);
  assert.equal(inserts.length, 1);
  assert.equal(inserts[0].utm_source, 'instagram');
  assert.deepEqual(inserts[0].props, {});
  assert.equal(inserts[0].is_bot, false);
  assert.equal('ip' in inserts[0] || 'ua' in inserts[0] || 'user_agent' in inserts[0], false);
  response = await post(event(), { contentType: 'text/plain' });
  assert.equal(response.status, 204);
  assert.equal(inserts.length, 1, 'page_view is persisted once per session');
  response = await post(event({ event: 'store_redirect', props: { store: 'appstore', bad: 'x' } }));
  assert.equal(response.status, 204);
  assert.deepEqual(inserts[1].props, { store: 'appstore' });
});

test('invalid events, malformed payloads, and oversized bodies return 204 without inserts', async () => {
  inserts = [];
  storedPageViews.clear();
  assert.equal((await post(event({ event: 'unknown_event' }))).status, 204);
  assert.equal((await post('{broken-json')).status, 204);
  assert.equal((await post(null, { raw: 'x'.repeat(5000) })).status, 204);
  assert.equal(inserts.length, 0);
});

test('foreign origins are silently rejected with 204', async () => {
  inserts = [];
  assert.equal((await post(event({ event: 'copy_link' }), { origin: 'https://not-sahla.example' })).status, 204);
  assert.equal(inserts.length, 0);
});

test('crawler, empty, and headless user agents are marked as bots', async () => {
  inserts = [];
  for (const userAgent of ['Googlebot/2.1', '', 'HeadlessChrome/131']) {
    assert.equal((await post(event({ event: 'platform_detected' }), { userAgent })).status, 204);
  }
  assert.equal(inserts.length, 3);
  assert.ok(inserts.every((row) => row.is_bot));
});

test('ingest rate limit silently drops requests beyond 120 per minute per IP', async () => {
  inserts = [];
  const { resetDownloadRateLimitForTests } = await import('../services/downloadTracking.js');
  resetDownloadRateLimitForTests();
  let last;
  for (let i = 0; i < 121; i += 1) {
    last = await post(event({ event: 'copy_link', sessionId: `rate-${String(i).padStart(8, '0')}` }), { ip: '198.51.100.88' });
  }
  assert.equal(last.status, 204);
  assert.equal(inserts.length, 120);
});

test('stats endpoint requires the Performance cookie and returns the RPC aggregation', async () => {
  const denied = await fetch(`${baseUrl}/api/performance/download-stats?from=2026-11-01&to=2026-11-22`);
  assert.equal(denied.status, 401);

  const login = await fetch(`${baseUrl}/api/performance/auth`, {
    method: 'POST', headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ password: 'local-test-password' }),
  });
  assert.equal(login.status, 200);
  const cookie = login.headers.get('set-cookie').split(';')[0];
  rpcResult = {
    totals: { entered: 3, reached_store: 1, app_open_attempts: 2, likely_opened: 1, conversion_rate: 33.33, likely_opened_rate: 33.33 },
    byPlatform: [{ key: 'ios', sessions: 2 }], byInApp: [], bySource: [], byRoute: [], byDay: [],
  };
  const stats = await fetch(`${baseUrl}/api/performance/download-stats?from=2026-11-01&to=2026-11-22&tz=Africa%2FAlgiers`, {
    headers: { cookie },
  });
  assert.equal(stats.status, 200);
  assert.equal((await stats.json()).totals.conversion_rate, 33.33);
});
