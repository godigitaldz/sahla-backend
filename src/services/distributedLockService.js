import crypto from 'node:crypto';
import { supabaseAdmin } from '../config/supabase.js';

const memoryLocks = new Map();

/**
 * Distributed lease-based lock backed by PostgreSQL (and advisory xact serialization).
 * Prevents overlapping cron ticks across serverless containers (Vercel / GitHub Actions).
 * Gracefully falls back to local in-memory lock if database RPC is temporarily unavailable.
 *
 * @param {Object} options
 * @param {string} options.key - Unique key for the lock
 * @param {number} [options.ttlMs=60000] - Duration in ms before the lock expires
 * @param {string} [options.holderId] - Optional identifier for the lock holder
 * @param {Object} [options.logger=console] - Logger
 * @returns {Promise<boolean>} - true if lock acquired, false if locked
 */
export async function acquireWindowLock({
  key,
  ttlMs = 60_000,
  holderId = null,
  logger = console,
} = {}) {
  if (!key || typeof key !== 'string') return false;

  const resolvedHolderId = holderId || `proc-${process.pid}-${crypto.randomUUID().slice(0, 8)}`;

  try {
    const { data: acquired, error } = await supabaseAdmin.rpc('acquire_distributed_lock', {
      p_key: key,
      p_ttl_ms: Math.max(1000, Number(ttlMs) || 60_000),
      p_holder_id: resolvedHolderId,
    });

    if (!error && typeof acquired === 'boolean') {
      if (!acquired) {
        logger.info?.(`[distributed-lock] DB lock busy for key="${key}"`);
      }
      return acquired;
    }

    if (error) {
      logger.warn?.(`[distributed-lock] DB RPC error (${error.message}); using memory lock fallback`);
    }
  } catch (err) {
    logger.warn?.(`[distributed-lock] DB call threw (${err?.message}); using memory lock fallback`);
  }

  // Graceful fallback to in-memory lock if DB is unreachable or migration pending
  const now = Date.now();
  const expiresAt = memoryLocks.get(key) || 0;
  if (now < expiresAt) {
    logger.info?.(`[distributed-lock] memory window locked for key="${key}" remaining=${expiresAt - now}ms`);
    return false;
  }
  memoryLocks.set(key, now + ttlMs);
  return true;
}

/**
 * Releases the distributed lock ahead of TTL expiration.
 *
 * @param {string} key - Lock key to release
 * @param {string} [holderId] - Lock holder id
 * @param {Object} [logger=console] - Logger
 * @returns {Promise<boolean>}
 */
export async function releaseWindowLock(key, holderId = null, logger = console) {
  if (!key) return false;
  memoryLocks.delete(key);

  try {
    const { data: released, error } = await supabaseAdmin.rpc('release_distributed_lock', {
      p_key: key,
      p_holder_id: holderId,
    });
    if (!error && typeof released === 'boolean') {
      return released;
    }
  } catch (err) {
    logger.warn?.(`[distributed-lock] DB release threw (${err?.message})`);
  }
  return true;
}
