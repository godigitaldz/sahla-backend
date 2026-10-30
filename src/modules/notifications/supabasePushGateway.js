import { pushSendSucceeded, pushTotalSent } from './pushSendResult.js';

function pushFunctionUrl() {
  const base = String(process.env.SUPABASE_URL ?? '').trim().replace(/\/+$/, '');
  if (!base) throw new Error('SUPABASE_URL is not configured');
  return `${base}/functions/v1/send-push-notification`;
}

function pushAuthToken() {
  const internal = String(process.env.PUSH_NOTIFICATION_INTERNAL_SECRET ?? '').trim();
  if (internal) return internal;
  const serviceRole = String(process.env.SUPABASE_SERVICE_ROLE_KEY ?? '').trim();
  if (serviceRole) return serviceRole;
  throw new Error('PUSH_NOTIFICATION_INTERNAL_SECRET or SUPABASE_SERVICE_ROLE_KEY is required');
}

export class SupabasePushGateway {
  async sendPush({ userIds, title, body, data }) {
    const ids = [...new Set((userIds || []).map((v) => String(v || '').trim()).filter(Boolean))];
    if (!ids.length) return { success: false, total_sent: 0, reason: 'no_recipients' };

    const token = pushAuthToken();
    const CHUNK_SIZE = 45;
    let totalSent = 0;
    let lastPayload = null;
    let lastError = null;
    let anySuccess = false;

    for (let i = 0; i < ids.length; i += CHUNK_SIZE) {
      const chunk = ids.slice(i, i + CHUNK_SIZE);
      try {
        const response = await fetch(pushFunctionUrl(), {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${token}`,
            apikey: token,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            user_ids: chunk,
            title,
            body,
            data: data || {},
            force_activate_inactive_tokens: true,
          }),
        });

        const payload = await response.json().catch(() => null);
        lastPayload = payload;

        if (response.ok && payload?.success === true) {
          anySuccess = true;
          totalSent += pushTotalSent({ raw: payload, total_sent: payload?.summary?.total_sent });
        } else {
          lastError = payload?.error || `push_http_${response.status}`;
        }
      } catch (err) {
        lastError = err?.message || 'push_network_error';
      }
    }

    const result = {
      success: anySuccess,
      total_sent: totalSent,
      raw: lastPayload,
      error: anySuccess ? null : lastError,
      status: anySuccess ? 200 : 500,
    };
    return result;
  }
}

export const supabasePushGateway = new SupabasePushGateway();
