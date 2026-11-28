import test from 'node:test';
import assert from 'node:assert/strict';
import express from 'express';
import performanceRouter from './performanceDashboard.js';

test('Performance Dashboard DB Phone + Fixed OTP Auth & Role Verification', async (t) => {
  process.env.PERFORMANCE_SESSION_SECRET = 'test-performance-session-secret-1234567890';
  process.env.PERFORMANCE_DASHBOARD_PASSWORD = '@TestDashboardPassword123';

  const app = express();
  app.use(express.json());
  app.use('/api/performance', performanceRouter);

  const server = app.listen(0);
  await new Promise((resolve) => server.once('listening', resolve));
  const baseUrl = `http://127.0.0.1:${server.address().port}`;

  t.after(() => {
    server.close();
  });

  await t.test('1. Admin phone (+213799790530) with correct DB OTP logs in successfully', async () => {
    const res = await fetch(`${baseUrl}/api/performance/auth`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ phone: '+213799790530', otp: '05102002' }),
    });

    assert.equal(res.status, 200);
    const data = await res.json();
    assert.equal(data.success, true);
    assert.equal(data.user.role, 'admin');
    const cookies = res.headers.getSetCookie ? res.headers.getSetCookie() : [res.headers.get('set-cookie')];
    assert.ok(cookies.some((c) => c && c.includes('perf_auth=')));
  });

  await t.test('2. Admin phone in local Algerian format (0799790530) normalizes and logs in', async () => {
    const res = await fetch(`${baseUrl}/api/performance/auth`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ phone: '0799790530', otp: '05102002' }),
    });

    assert.equal(res.status, 200);
    const data = await res.json();
    assert.equal(data.success, true);
    assert.equal(data.user.role, 'admin');
  });

  await t.test('3. Admin phone with wrong OTP returns 401 invalid_otp', async () => {
    const res = await fetch(`${baseUrl}/api/performance/auth`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ phone: '+213799790530', otp: '00000000' }),
    });

    assert.equal(res.status, 401);
    const data = await res.json();
    assert.equal(data.success, false);
    assert.equal(data.error, 'invalid_otp');
  });

  await t.test('4. Non-admin user (+213770721897 - delivery_man) returns 403 unauthorized_role', async () => {
    const res = await fetch(`${baseUrl}/api/performance/auth`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ phone: '+213770721897', otp: '05102002' }),
    });

    assert.equal(res.status, 403);
    const data = await res.json();
    assert.equal(data.success, false);
    assert.equal(data.error, 'unauthorized_role');
    assert.equal(data.role, 'delivery_man');
    assert.ok(data.message.includes('delivery_man'));
  });

  await t.test('5. Non-existent phone returns 404 account_not_found', async () => {
    const res = await fetch(`${baseUrl}/api/performance/auth`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ phone: '+213999999999', otp: '123456' }),
    });

    assert.equal(res.status, 404);
    const data = await res.json();
    assert.equal(data.success, false);
    assert.equal(data.error, 'account_not_found');
  });

  await t.test('6. Missing credentials returns 400', async () => {
    const res = await fetch(`${baseUrl}/api/performance/auth`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ phone: '+213799790530' }),
    });

    assert.equal(res.status, 400);
    const data = await res.json();
    assert.equal(data.success, false);
    assert.equal(data.error, 'missing_credentials');
  });

  await t.test('7. /session endpoint returns logged-in user profile with cookie', async () => {
    const loginRes = await fetch(`${baseUrl}/api/performance/auth`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ phone: '+213799790530', otp: '05102002' }),
    });
    const cookies = loginRes.headers.getSetCookie ? loginRes.headers.getSetCookie() : [loginRes.headers.get('set-cookie')];
    const cookie = cookies.find((c) => c && c.includes('perf_auth='));

    const sessionRes = await fetch(`${baseUrl}/api/performance/session`, {
      headers: { cookie: cookie.split(';')[0] },
    });
    assert.equal(sessionRes.status, 200);
    const sessionData = await sessionRes.json();
    assert.equal(sessionData.success, true);
    assert.equal(sessionData.user.role, 'admin');
    assert.equal(sessionData.user.phone, '+213799790530');
  });
});
