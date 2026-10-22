import {
  getUpstashConfig,
  upstashPipelineIncrWithExpire,
} from '@/server/rateLimit/upstashPipeline';

/** Fail-open when Upstash unset; fail-closed when configured but broken. */
export async function allowTrackingFetchByIp(ip: string): Promise<boolean> {
  const result = await upstashPipelineIncrWithExpire(
    `web:track:ip:${ip || 'unknown'}`,
    60,
  );
  if (result.ok === false && result.reason === 'missing_env') return true;
  if (!result.ok) return false;
  return result.count <= 60;
}

export async function allowTrackingFetchByTokenPrefix(prefix: string): Promise<boolean> {
  const safe = (prefix || 'unknown').slice(0, 12);
  const result = await upstashPipelineIncrWithExpire(`web:track:tok:${safe}`, 60);
  if (result.ok === false && result.reason === 'missing_env') return true;
  if (!result.ok) return false;
  return result.count <= 30;
}

export function isUpstashConfiguredForTracking(): boolean {
  return getUpstashConfig() != null;
}
