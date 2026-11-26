import test, { before, after } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
import express from 'express';

process.env.SUPABASE_URL ||= 'http://127.0.0.1:54321';
process.env.SUPABASE_ANON_KEY ||= 'test-anon-key';
process.env.SUPABASE_SERVICE_ROLE_KEY ||= 'test-service-role-key';

let sanitizeIosAppStoreUrl;
let adminAuthRouter;
let performanceRouter;
let ordersRouter;
let OrderService;
let SupabasePushGateway;

before(async () => {
  ({ sanitizeIosAppStoreUrl } = await import('./publicConfig.js'));
  ({ default: adminAuthRouter } = await import('./adminAuth.js'));
  ({ default: performanceRouter } = await import('./performanceDashboard.js'));
  ({ default: ordersRouter } = await import('./orders.js'));
  ({ OrderService } = await import('../services/orderService.js'));
  ({ SupabasePushGateway } = await import('../modules/notifications/supabasePushGateway.js'));
});

test('F01: AASA files only declare primary iOS team & bundle ID', () => {
  const rootAasa = JSON.parse(
    readFileSync('public/.well-known/apple-app-site-association', 'utf8'),
  );
  const webAasa = JSON.parse(
    readFileSync('web/public/.well-known/apple-app-site-association', 'utf8'),
  );
  const routeTs = readFileSync(
    'web/src/app/.well-known/apple-app-site-association/route.ts',
    'utf8',
  );

  for (const aasa of [rootAasa, webAasa]) {
    assert.deepEqual(aasa.applinks.details[0].appIDs, ['9P628XCQ94.com.sahla.sahlaalgerie']);
    assert.deepEqual(aasa.webcredentials.apps, ['9P628XCQ94.com.sahla.sahlaalgerie']);
  }

  assert.match(routeTs, /9P628XCQ94\.com\.sahla\.sahlaalgerie/);
  assert.doesNotMatch(routeTs, /T8CTMB48BY/);
  assert.doesNotMatch(routeTs, /com\.godigital\.sahla/);
});

test('F02: sanitizeIosAppStoreUrl allows only HTTPS Apple App Store URLs', () => {
  assert.equal(
    sanitizeIosAppStoreUrl('https://apps.apple.com/dz/app/sahla-algerie/id6834895657', null),
    'https://apps.apple.com/dz/app/sahla-algerie/id6834895657',
  );
  assert.equal(
    sanitizeIosAppStoreUrl('https://itunes.apple.com/app/id6834895657', null),
    'https://itunes.apple.com/app/id6834895657',
  );
  assert.equal(
    sanitizeIosAppStoreUrl('itms-services://?action=download-manifest&url=https://evil.example/app.plist', null),
    null,
  );
  assert.equal(
    sanitizeIosAppStoreUrl('https://evil.example/sahla.ipa', 'https://apps.apple.com/dz/app/sahla-algerie/id6834895657'),
    'https://apps.apple.com/dz/app/sahla-algerie/id6834895657',
  );
  assert.equal(sanitizeIosAppStoreUrl('http://apps.apple.com/app/id1', null), null);
});

test('F04 & F13: download gateway removes x-safari-https:// and stubbed #sdSendForm', () => {
  const downloadJs = readFileSync('public/download.js', 'utf8');
  assert.doesNotMatch(downloadJs, /x-safari-https:\/\//);
  assert.doesNotMatch(downloadJs, /sdSendForm/);
  assert.doesNotMatch(downloadJs, /\/api\/send-link/);
});

test('F07: dead unmounted telemetry route file is removed', () => {
  assert.equal(existsSync('src/routes/telemetry.js'), false);
});

test('F08: SupabasePushGateway defaults force_activate_inactive_tokens to false', async () => {
  const gateway = new SupabasePushGateway();
  const originalFetch = global.fetch;
  let capturedBody = null;

  global.fetch = async (_url, init) => {
    capturedBody = JSON.parse(init.body);
    return {
      ok: true,
      status: 200,
      json: async () => ({ success: true, summary: { total_sent: 1 } }),
    };
  };

  try {
    await gateway.sendPush({
      userIds: ['user-1'],
      title: 'Order Update',
      body: 'Ready',
      data: { order_id: '123' },
    });
    assert.equal(capturedBody.force_activate_inactive_tokens, false);
  } finally {
    global.fetch = originalFetch;
  }

  const dashboardJs = readFileSync('src/routes/performanceDashboard.js', 'utf8');
  assert.doesNotMatch(
    dashboardJs,
    /force_activate_inactive_tokens:\s*Boolean\(force_activate_inactive_tokens\)/,
  );
  const perfHtml = readFileSync('public/performance.html', 'utf8');
  assert.match(perfHtml, /const forceActivate = false;/);
});

test('F15: admin-fixed-otp and performance /auth fail closed without configured secrets', async () => {
  const prevOtp = process.env.ADMIN_FIXED_OTP;
  const prevDashPwd = process.env.PERFORMANCE_DASHBOARD_PASSWORD;
  const prevSessionSecret = process.env.PERFORMANCE_SESSION_SECRET;
  const prevServiceKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

  delete process.env.ADMIN_FIXED_OTP;
  delete process.env.PERFORMANCE_DASHBOARD_PASSWORD;
  delete process.env.PERFORMANCE_SESSION_SECRET;

  const app = express();
  app.use(express.json());
  app.use('/api/auth', adminAuthRouter);
  app.use('/api/performance', performanceRouter);
  app.use('/api/orders', ordersRouter);

  const server = app.listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  try {
    const otpRes = await fetch(`${baseUrl}/api/auth/admin-fixed-otp`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ phone: '+213555000000', otp: '05102002' }),
    });
    assert.equal(otpRes.status, 503);

    const perfRes = await fetch(`${baseUrl}/api/performance/auth`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ password: '@Khazani05102002' }),
    });
    assert.equal(perfRes.status, 503);

    // Unauthenticated legacy /api/orders endpoints must fail 401
    const ordersListRes = await fetch(`${baseUrl}/api/orders`);
    assert.equal(ordersListRes.status, 401);

    const orderStatusRes = await fetch(`${baseUrl}/api/orders/order-1/status`, {
      method: 'PATCH',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ status: 'delivered' }),
    });
    assert.equal(orderStatusRes.status, 401);
  } finally {
    server.close();
    if (prevOtp !== undefined) process.env.ADMIN_FIXED_OTP = prevOtp;
    if (prevDashPwd !== undefined) process.env.PERFORMANCE_DASHBOARD_PASSWORD = prevDashPwd;
    if (prevSessionSecret !== undefined) process.env.PERFORMANCE_SESSION_SECRET = prevSessionSecret;
    if (prevServiceKey !== undefined) process.env.SUPABASE_SERVICE_ROLE_KEY = prevServiceKey;
  }
});

test('F09: OrderService rejects invalid quantities and invalid statuses before DB writes', async () => {
  const svc = new OrderService();

  await assert.rejects(
    svc.createOrder({ userId: 'u1', restaurantId: 'r1', items: [] }),
    (err) => err.statusCode === 400,
  );

  await assert.rejects(
    svc.updateOrderStatus('o1', 'hacked_status', 'u1'),
    (err) => err.statusCode === 400,
  );
});

test('F06 & F15: login HTML has no prefilled code and homepage has no Coming Soon mismatch', () => {
  const loginHtml = readFileSync('public/login.html', 'utf8');
  const indexHtml = readFileSync('public/index.html', 'utf8');
  assert.doesNotMatch(loginHtml, /05102002/);
  assert.doesNotMatch(indexHtml, /Coming soon on the App Store/);
});
