/**
 * Sahla Delivery Personnel Working Hours - Cloudflare Cron Worker
 *
 * Responsibilities:
 * 1. Fires on scheduled cron triggers (e.g. every 5 minutes: "0/5 * * * *").
 * 2. Authenticates with sahla-backend using CRON_SECRET.
 * 3. Enforces courier availability according to Africa/Algiers shift hours:
 *    - Outside shift (e.g. 22:00 -> 11:00): sets is_available = false for couriers and tracks auto-closed IDs.
 *    - Inside shift (e.g. 11:00 -> 22:00): restores is_available = true ONLY for couriers who were auto-closed.
 * 4. Zero client app modifications required.
 */

async function invokeWorkingHoursSync(env, triggerSource = 'cron') {
  const backendUrl = (env.BACKEND_URL || 'https://sahla-delivery.com').replace(/\/+$/, '');
  const syncEndpoint = `${backendUrl}/api/internal/delivery-personnel/sync-working-hours`;
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
    'User-Agent': 'Sahla-Cloudflare-Cron-Worker/1.0',
  };

  try {
    const response = await fetch(syncEndpoint, {
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
      console.error(`[Worker Error] Backend returned HTTP ${status}:`, parsedBody);
      return {
        success: false,
        status,
        error: parsedBody?.error || `HTTP ${status}`,
        details: parsedBody,
      };
    }

    console.log(`[Worker Success] Working hours synced (${triggerSource}):`, {
      algiers_time: parsedBody.algiers_time,
      is_open: parsedBody.is_default_shift_open,
      closed: parsedBody.closed_count,
      opened: parsedBody.opened_count,
      auto_closed_pool: parsedBody.auto_closed_pool_count,
    });

    return {
      success: true,
      status,
      data: parsedBody,
    };
  } catch (err) {
    console.error(`[Worker Network Error] Failed to reach backend:`, err);
    return {
      success: false,
      error: err.message || String(err),
      timestamp: new Date().toISOString(),
    };
  }
}

export default {
  /**
   * Cron Trigger handler
   */
  async scheduled(event, env, ctx) {
    console.log(`[Worker Cron Trigger] Scheduled event fired at ${new Date(event.scheduledTime).toISOString()}`);
    ctx.waitUntil(invokeWorkingHoursSync(env, 'cron'));
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
          service: 'sahla-delivery-working-hours-worker',
          backend_url: env.BACKEND_URL || 'https://sahla-delivery.com',
          has_secret: Boolean(env.CRON_SECRET),
          now: new Date().toISOString(),
        }, null, 2),
        { headers: { 'Content-Type': 'application/json' } }
      );
    }

    // Trigger sync on demand: GET / or POST /sync
    if (url.pathname === '/' || url.pathname === '/sync') {
      const result = await invokeWorkingHoursSync(env, 'manual_http');
      return new Response(
        JSON.stringify(result, null, 2),
        {
          status: result.success ? 200 : 500,
          headers: { 'Content-Type': 'application/json' },
        }
      );
    }

    return new Response(
      JSON.stringify({ error: 'Not Found', usage: 'GET /health or GET /sync' }),
      { status: 404, headers: { 'Content-Type': 'application/json' } }
    );
  },
};
