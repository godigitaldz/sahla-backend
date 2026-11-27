/**
 * Staff Web Push Subscription & Ledger Validator
 *
 * Implements W3C Push API / VAPID subscription parsing and validation.
 * Strictly avoids logging raw endpoints or authentication secrets.
 */

export interface WebPushSubscriptionKeys {
  p256dh: string;
  auth: string;
}

export interface WebPushSubscription {
  endpoint: string;
  keys: WebPushSubscriptionKeys;
  user_id: string;
  user_agent?: string;
  created_at?: string;
}

export type WebPushValidationResult =
  | { valid: true; subscription: WebPushSubscription }
  | { valid: false; code: 'invalid_payload' | 'invalid_endpoint' | 'invalid_keys'; message: string };

const HTTPS_URL_REGEX = /^https:\/\/[^\s$.?#].[^\s]*$/i;

export function validateWebPushSubscription(
  userId: string,
  rawPayload: unknown,
  userAgent?: string,
): WebPushValidationResult {
  if (!userId) {
    return { valid: false, code: 'invalid_payload', message: 'User ID is required.' };
  }

  if (!rawPayload || typeof rawPayload !== 'object') {
    return { valid: false, code: 'invalid_payload', message: 'Subscription payload must be an object.' };
  }

  const candidate = rawPayload as Record<string, unknown>;
  const endpoint = typeof candidate.endpoint === 'string' ? candidate.endpoint.trim() : '';

  if (!endpoint || !HTTPS_URL_REGEX.test(endpoint)) {
    return {
      valid: false,
      code: 'invalid_endpoint',
      message: 'Subscription endpoint must be a valid HTTPS URL.',
    };
  }

  const keys = candidate.keys as Record<string, unknown> | undefined;
  if (!keys || typeof keys !== 'object') {
    return {
      valid: false,
      code: 'invalid_keys',
      message: 'Subscription must include encryption keys (p256dh and auth).',
    };
  }

  const p256dh = typeof keys.p256dh === 'string' ? keys.p256dh.trim() : '';
  const auth = typeof keys.auth === 'string' ? keys.auth.trim() : '';

  if (!p256dh || p256dh.length < 20 || !auth || auth.length < 10) {
    return {
      valid: false,
      code: 'invalid_keys',
      message: 'Subscription encryption keys (p256dh or auth) are invalid or truncated.',
    };
  }

  return {
    valid: true,
    subscription: {
      user_id: userId,
      endpoint,
      keys: { p256dh, auth },
      user_agent: userAgent?.slice(0, 255),
      created_at: new Date().toISOString(),
    },
  };
}

/**
 * Sanitizes push subscription metadata for audit logging without leaking
 * encryption secrets or full endpoint identifiers.
 */
export function sanitizePushLog(subscription: WebPushSubscription): {
  user_id: string;
  endpoint_domain: string;
  keys_present: boolean;
} {
  let endpointDomain = 'unknown';
  try {
    endpointDomain = new URL(subscription.endpoint).hostname;
  } catch {
    // keep unknown
  }

  return {
    user_id: subscription.user_id,
    endpoint_domain: endpointDomain,
    keys_present: Boolean(subscription.keys?.p256dh && subscription.keys?.auth),
  };
}
