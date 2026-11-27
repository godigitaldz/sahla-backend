/**
 * Staff Auth Progressive Rate Limiter
 *
 * Utilizes the shared Upstash Redis pipeline store to enforce progressive throttling
 * across IP addresses and usernames. Never applies permanent account lockouts.
 * Returns generic security messages to prevent credential probing.
 */

import {
  getUpstashConfig,
  upstashPipelineIncrWithExpire,
} from '../../rateLimit/upstashPipeline';
import { normalizeUsername } from './usernameAlias';

export interface RateLimitCheckResult {
  allowed: boolean;
  retryAfterSec?: number;
  message?: string;
}

const IP_WINDOW_SEC = 60; // 1 minute
const IP_MAX_ATTEMPTS = 15; // 15 attempts per minute per IP

const USER_WINDOW_SEC = 900; // 15 minutes
const USER_TIER_1_LIMIT = 5; // 5 failures -> 60s delay
const USER_TIER_2_LIMIT = 10; // 10 failures -> full window delay

export async function checkStaffAuthRateLimit(
  username: string,
  clientIp: string,
  fetchImpl: typeof fetch = fetch,
): Promise<RateLimitCheckResult> {
  const normUser = normalizeUsername(username);
  const cleanIp = (clientIp || '127.0.0.1').trim();

  // 1. IP-level rate limiting
  const ipKey = `staff:rl:ip:${cleanIp}`;
  const ipRes = await upstashPipelineIncrWithExpire(ipKey, IP_WINDOW_SEC, fetchImpl);
  if (ipRes.ok && ipRes.count > IP_MAX_ATTEMPTS) {
    return {
      allowed: false,
      retryAfterSec: IP_WINDOW_SEC,
      message: 'Too many requests from this network. Please wait a moment and try again.',
    };
  }

  // 2. Username progressive rate limiting
  if (normUser) {
    const userFailKey = `staff:rl:user_fails:${normUser}`;
    // Read failure count without incrementing during check
    const cfg = getUpstashConfig();
    if (cfg) {
      try {
        const res = await fetchImpl(`${cfg.url}/get/${encodeURIComponent(userFailKey)}`, {
          headers: { Authorization: `Bearer ${cfg.token}` },
        });
        if (res.ok) {
          const data = (await res.json()) as { result?: string | number | null };
          const failCount = Number(data?.result || 0);

          if (failCount >= USER_TIER_2_LIMIT) {
            return {
              allowed: false,
              retryAfterSec: 900,
              message: 'Too many failed login attempts. Please try again in 15 minutes.',
            };
          } else if (failCount >= USER_TIER_1_LIMIT) {
            return {
              allowed: false,
              retryAfterSec: 60,
              message: 'Too many failed login attempts. Please wait 60 seconds before trying again.',
            };
          }
        }
      } catch {
        // Fail open if Redis query encounters transient network issue
      }
    }
  }

  return { allowed: true };
}

export async function recordStaffAuthFailure(
  username: string,
  fetchImpl: typeof fetch = fetch,
): Promise<number> {
  const normUser = normalizeUsername(username);
  if (!normUser) return 0;

  const userFailKey = `staff:rl:user_fails:${normUser}`;
  const res = await upstashPipelineIncrWithExpire(userFailKey, USER_WINDOW_SEC, fetchImpl);
  return res.ok ? res.count : 1;
}

export async function clearStaffAuthFailures(
  username: string,
  fetchImpl: typeof fetch = fetch,
): Promise<void> {
  const normUser = normalizeUsername(username);
  if (!normUser) return;

  const cfg = getUpstashConfig();
  if (!cfg) return;

  const userFailKey = `staff:rl:user_fails:${normUser}`;
  try {
    await fetchImpl(`${cfg.url}/del/${encodeURIComponent(userFailKey)}`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${cfg.token}` },
    });
  } catch {
    // Ignore cache clear error
  }
}
