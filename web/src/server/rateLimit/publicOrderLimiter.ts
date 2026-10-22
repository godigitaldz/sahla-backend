type Bucket = { count: number; resetAt: number };

const ipBuckets = new Map<string, Bucket>();
const phoneBuckets = new Map<string, Bucket>();
/** Idempotency keys already counted — allow retries without burning quota. */
const countedRequestIds = new Map<string, number>();

const IP_MAX = 12;
const IP_WINDOW_MS = 15 * 60 * 1000;
const PHONE_MAX = 8;
const PHONE_WINDOW_MS = 60 * 60 * 1000;
const REQUEST_ID_TTL_MS = 10 * 60 * 1000;

function checkBucket(map: Map<string, Bucket>, key: string, max: number, windowMs: number): boolean {
  const now = Date.now();
  const bucket = map.get(key);

  if (!bucket || bucket.resetAt <= now) {
    map.set(key, { count: 1, resetAt: now + windowMs });
    return true;
  }

  if (bucket.count >= max) return false;
  bucket.count += 1;
  return true;
}

function isRetryForCountedRequest(clientRequestId?: string): boolean {
  if (!clientRequestId) return false;
  const expiresAt = countedRequestIds.get(clientRequestId);
  if (!expiresAt) return false;
  if (expiresAt <= Date.now()) {
    countedRequestIds.delete(clientRequestId);
    return false;
  }
  return true;
}

export function allowPublicOrderRequest(
  ip: string,
  phone: string,
  clientRequestId?: string,
): boolean {
  if (isRetryForCountedRequest(clientRequestId)) return true;

  const ipOk = checkBucket(ipBuckets, ip || 'unknown', IP_MAX, IP_WINDOW_MS);
  const phoneOk = checkBucket(phoneBuckets, phone || 'unknown', PHONE_MAX, PHONE_WINDOW_MS);
  const allowed = ipOk && phoneOk;

  if (allowed && clientRequestId) {
    countedRequestIds.set(clientRequestId, Date.now() + REQUEST_ID_TTL_MS);
  }

  return allowed;
}

/** Test-only reset. */
export function resetPublicOrderRateLimitsForTests(): void {
  ipBuckets.clear();
  phoneBuckets.clear();
  countedRequestIds.clear();
}
