type UpstashConfig = { url: string; token: string };

export function getUpstashConfig(): UpstashConfig | null {
  const url = process.env.UPSTASH_REDIS_REST_URL?.trim();
  const token = process.env.UPSTASH_REDIS_REST_TOKEN?.trim();
  if (!url || !token) return null;
  return { url: url.replace(/\/+$/, ''), token };
}

export type UpstashIncrResult =
  | { ok: true; count: number }
  | { ok: false; reason: 'missing_env' | 'request_failed' | 'invalid_response' };

/**
 * INCR + EXPIRE NX via Upstash REST /pipeline.
 * Missing env → ok:false reason missing_env (callers decide fail-open).
 * Configured but failed → ok:false (callers fail-closed for tracking).
 */
export async function upstashPipelineIncrWithExpire(
  key: string,
  windowSec: number,
  fetchImpl: typeof fetch = fetch,
): Promise<UpstashIncrResult> {
  const cfg = getUpstashConfig();
  if (!cfg) return { ok: false, reason: 'missing_env' };

  try {
    const response = await fetchImpl(`${cfg.url}/pipeline`, {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${cfg.token}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify([
        ['INCR', key],
        ['EXPIRE', key, String(windowSec), 'NX'],
      ]),
    });

    if (!response.ok) {
      return { ok: false, reason: 'request_failed' };
    }

    const payload = (await response.json()) as unknown;
    if (!Array.isArray(payload) || payload.length < 1) {
      return { ok: false, reason: 'invalid_response' };
    }

    const incrResult = (payload[0] as { result?: unknown } | null)?.result;
    const count =
      typeof incrResult === 'number' ? incrResult : Number(incrResult ?? NaN);
    if (!Number.isFinite(count)) {
      return { ok: false, reason: 'invalid_response' };
    }

    return { ok: true, count };
  } catch {
    return { ok: false, reason: 'request_failed' };
  }
}
