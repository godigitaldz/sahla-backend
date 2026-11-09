/**
 * Sahla Autonomous Background Poller & Working Hours - Cloudflare Cron Worker
 *
 * Responsibilities:
 * 1. Fires on scheduled cron triggers EVERY MINUTE ("* * * * *").
 * 2. Authenticates with sahla-backend using CRON_SECRET.
 * 3. Autonomous 24/7 background execution WITHOUT requiring admin dashboard to be open:
 *    - Order lifecycle self-heal & bootstrapping.
 *    - Pending order alerts & escalations (2m, 5m, 10m/12m rebroadcast, 15m auto-cancel).
 *    - Preparing unassigned order courier rebroadcast (every 3m) & admin alert (5m).
 *    - Preparing assigned courier delay alerts (20m without pickup).
 *    - Pickup delay alerts & parcel wait alerts.
 *    - Web order push outbox drainer.
 *    - Shift working hours enforcement & morning greeting push notification delivery.
 */

async function invokeEndpoint(env, endpointPath, triggerSource = 'cron') {
  const backendUrl = (env.BACKEND_URL || 'https://sahla-backend.vercel.app').replace(/\/+$/, '');
  const targetUrl = `${backendUrl}${endpointPath}`;
  const cronSecret = String(env.CRON_SECRET || '').trim();

  if (!cronSecret) {
    const errorMsg = 'CRON_SECRET environment variable is missing in Cloudflare Worker';
    console.error(`[Worker Error] ${errorMsg}`);
    return {
      success: false,
      error: errorMsg,
      timestamp: new Date().toISOString(),
    };
  }

  const reqHeaders = {
    'Content-Type': 'application/json',
    'Authorization': `Bearer ${cronSecret}`,
    'X-Source': `cloudflare-worker-${triggerSource}`,
    'User-Agent': 'Sahla-Cloudflare-Cron-Worker/2.0',
  };

  try {
    const response = await fetch(targetUrl, {
      method: 'POST',
      headers: reqHeaders,
      body: JSON.stringify({
        triggered_by: `cloudflare_worker_${triggerSource}`,
        timestamp: new Date().toISOString(),
      }),
    });

    const status = response.status;
    const bodyText = await response.text();
    let parsedBody;
    try {
      parsedBody = JSON.parse(bodyText);
    } catch {
      parsedBody = { raw_body: bodyText };
    }

    if (!response.ok) {
      console.error(`[Worker Error] Backend returned HTTP ${status} for ${endpointPath}:`, parsedBody);
      return {
        success: false,
        status,
        endpoint: endpointPath,
        error: parsedBody?.error || `HTTP ${status}`,
        details: parsedBody,
      };
    }

    console.log(`[Worker Success] Polled ${endpointPath} (${triggerSource}) HTTP ${status}`);
    return {
      success: true,
      status,
      endpoint: endpointPath,
      data: parsedBody,
    };
  } catch (err) {
    console.error(`[Worker Network Error] Failed to reach ${endpointPath}:`, err);
    return {
      success: false,
      endpoint: endpointPath,
      error: err.message || String(err),
      timestamp: new Date().toISOString(),
    };
  }
}

export async function runCronTick(env, triggerSource = 'cron') {
  return invokeEndpoint(env, '/api/internal/pending-orders-poll', triggerSource);
}

export async function runWorkingHoursSync(env, triggerSource = 'cron') {
  return invokeEndpoint(env, '/api/internal/delivery-personnel/sync-working-hours', triggerSource);
}

export default {
  /**
   * Cron Trigger handler (runs every minute "* * * * *")
   */
  async scheduled(event, env, ctx) {
    const scheduledTime = new Date(event.scheduledTime || Date.now());
    console.log(`[Worker Cron Trigger] Fired at ${scheduledTime.toISOString()}`);

    // Main poller: runs working hours sync, lifecycle self-heal, pending escalations,
    // preparing unassigned rebroadcast, and preparing assigned alerts in one atomic tick.
    ctx.waitUntil(runCronTick(env, 'cron'));
  },

  /**
   * HTTP Fetch handler for manual triggers & health check
   */
  async fetch(request, env, ctx) {
    const url = new URL(request.url);

    if (url.pathname === '/health' || url.pathname === '/status') {
      return new Response(
        JSON.stringify({
          status: 'ok',
          service: 'sahla-autonomous-background-poller',
          backend_url: env.BACKEND_URL || 'https://sahla-backend.vercel.app',
          has_secret: Boolean(env.CRON_SECRET),
          now: new Date().toISOString(),
        }, null, 2),
        { headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Trigger full poller tick on demand: GET / or GET /poll or POST /poll
    if (url.pathname === '/' || url.pathname === '/poll') {
      const result = await runCronTick(env, 'manual_http');
      return new Response(
        JSON.stringify(result, null, 2),
        {
          status: result.success ? 200 : 500,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    // Trigger working hours sync explicitly: GET /sync or POST /sync
    if (url.pathname === '/sync') {
      const result = await runWorkingHoursSync(env, 'manual_http');
      return new Response(
        JSON.stringify(result, null, 2),
        {
          status: result.success ? 200 : 500,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    return new Response(
      JSON.stringify({ error: 'Not Found', usage: 'GET /health, GET /poll, or GET /sync' }),
      { status: 404, headers: { 'Content-Type': 'application/json' } }
    );
  },
};
