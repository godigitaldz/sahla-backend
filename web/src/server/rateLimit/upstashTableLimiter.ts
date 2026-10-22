import {
  getUpstashConfig,
  upstashPipelineIncrWithExpire,
} from '@/server/rateLimit/upstashPipeline';

type UpstashConfig = { url: string; token: string };

function getUpstash(): UpstashConfig | null {
  return getUpstashConfig();
}

async function upstashIncrWithExpire(key: string, windowSec: number): Promise<number> {
  const result = await upstashPipelineIncrWithExpire(key, windowSec);
  // Table limiter historically fail-opens; keep that for table flows.
  if (!result.ok) return 0;
  return result.count;
}

async function upstashGet(key: string): Promise<string | null> {
  const cfg = getUpstash();
  if (!cfg) return null;
  const response = await fetch(`${cfg.url}/get/${encodeURIComponent(key)}`, {
    headers: { Authorization: `Bearer ${cfg.token}` },
  });
  if (!response.ok) return null;
  const payload = await response.json();
  return typeof payload?.result === 'string' ? payload.result : null;
}

async function upstashSetEx(key: string, value: string, ttlSec: number): Promise<void> {
  const cfg = getUpstash();
  if (!cfg) return;
  await fetch(cfg.url, {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${cfg.token}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify(['SET', key, value, 'EX', ttlSec]),
  });
}

export async function allowTableScan(ip: string): Promise<boolean> {
  const count = await upstashIncrWithExpire(`table:scan:ip:${ip}`, 15 * 60);
  if (!getUpstash()) return true;
  return count <= 30;
}

export async function allowVenueAttempt(tableCodeHash: string, ip: string): Promise<boolean> {
  const lockKey = `table:venue:lock:${tableCodeHash}:${ip}`;
  const locked = await upstashGet(lockKey);
  if (locked === '1') return false;

  const count = await upstashIncrWithExpire(`table:venue:${tableCodeHash}:ip:${ip}`, 5 * 60);
  if (!getUpstash()) return true;
  if (count > 5) {
    await upstashSetEx(lockKey, '1', 15 * 60);
    return false;
  }
  return true;
}

export async function allowTableOrderByPhone(phone: string): Promise<boolean> {
  const count = await upstashIncrWithExpire(`table:order:phone:${phone}`, 60 * 60);
  if (!getUpstash()) return true;
  return count <= 8;
}

export async function allowTableOrderBySession(sessionId: string): Promise<boolean> {
  const count = await upstashIncrWithExpire(`table:order:session:${sessionId}`, 10 * 60);
  if (!getUpstash()) return true;
  return count <= 3;
}

export async function cacheVenueCodePlaintext(
  restaurantId: string,
  code: string,
  ttlSec: number,
): Promise<void> {
  await upstashSetEx(`table:venue:display:${restaurantId}`, code, ttlSec);
}

export async function getCachedVenueCodePlaintext(restaurantId: string): Promise<string | null> {
  return upstashGet(`table:venue:display:${restaurantId}`);
}
