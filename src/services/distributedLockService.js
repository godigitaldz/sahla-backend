const memoryLocks = new Map();

/**
 * Lightweight distributed / window lock to prevent overlapping runs of cron ticks.
 *
 * @param {Object} options
 * @param {string} options.key - Unique key for the lock
 * @param {number} [options.ttlMs=60000] - Duration in ms before the lock expires
 * @param {Object} [options.logger=console] - Logger
 * @returns {Promise<boolean>} - true if lock acquired, false if locked
 */
export async function acquireWindowLock({ key, ttlMs = 60_000, logger = console } = {}) {
  const now = Date.now();
  const expiresAt = memoryLocks.get(key) || 0;
  if (now < expiresAt) {
    logger.info?.(`[distributed-lock] window locked for key="${key}" remaining=${expiresAt - now}ms`);
    return false;
  }
  memoryLocks.set(key, now + ttlMs);
  return true;
}

export function releaseWindowLock(key) {
  memoryLocks.delete(key);
}
