/**
 * Invoke send-web-order-push Edge Function.
 * No FCM credentials on Vercel — secrets stay in Supabase.
 */

function webOrderPushFunctionUrl(): string {
  const base = String(process.env.SUPABASE_URL ?? '').trim().replace(/\/+$/, '');
  if (!base) throw new Error('SUPABASE_URL is not configured');
  return `${base}/functions/v1/send-web-order-push`;
}

function pushAuthToken(): string {
  const internal = String(process.env.PUSH_NOTIFICATION_INTERNAL_SECRET ?? '').trim();
  if (internal) return internal;
  const serviceRole = String(process.env.SUPABASE_SERVICE_ROLE_KEY ?? '').trim();
  if (serviceRole) return serviceRole;
  throw new Error('PUSH_NOTIFICATION_INTERNAL_SECRET or SUPABASE_SERVICE_ROLE_KEY is required');
}

export type InvokeWebOrderPushParams = {
  order_id: string;
  mode?: 'test' | 'dispatch';
  event?: string;
  status?: string;
  title?: string;
  body?: string;
};

export type InvokeWebOrderPushResult = {
  success: boolean;
  total_sent?: number;
  error?: string | null;
  status?: number;
};

export async function invokeWebOrderPush(
  params: InvokeWebOrderPushParams,
): Promise<InvokeWebOrderPushResult> {
  const token = pushAuthToken();
  const response = await fetch(webOrderPushFunctionUrl(), {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${token}`,
      apikey: token,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      order_id: params.order_id,
      mode: params.mode ?? 'dispatch',
      event: params.event,
      status: params.status,
      title: params.title,
      body: params.body,
    }),
  });

  const payload = (await response.json().catch(() => null)) as Record<string, unknown> | null;
  if (!response.ok) {
    return {
      success: false,
      error: String(payload?.error ?? `push_http_${response.status}`),
      status: response.status,
    };
  }

  return {
    success: payload?.success === true,
    total_sent: typeof payload?.total_sent === 'number' ? payload.total_sent : 0,
    error: payload?.error ? String(payload.error) : null,
    status: response.status,
  };
}
