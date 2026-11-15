import { supabaseAdmin } from '../config/supabase.js';

const cache = new Map();
const inFlightRequests = new Map();
const DEFAULT_TTL_MS = 60_000; // 60 seconds

/**
 * Get a numeric config value from system_config with in-memory caching and coalescing.
 * @param {string} key
 * @param {number} fallback
 * @param {number} ttlMs
 * @returns {Promise<number>}
 */
export async function getCachedSystemConfigNumber(key, fallback = 0, ttlMs = DEFAULT_TTL_MS) {
  const now = Date.now();
  const entry = cache.get(key);
  if (entry && (now - entry.timestamp) < ttlMs) {
    return typeof entry.value === 'number' ? entry.value : fallback;
  }

  if (inFlightRequests.has(key)) {
    return inFlightRequests.get(key);
  }

  const promise = (async () => {
    try {
      const { data, error } = await supabaseAdmin
        .from('system_config')
        .select('config_value')
        .eq('config_key', key)
        .eq('is_active', true)
        .maybeSingle();

      if (error || !data || data.config_value == null) {
        if (entry) return entry.value;
        return fallback;
      }

      let val = Number(data.config_value);
      if (!Number.isFinite(val)) {
        val = fallback;
      }
      cache.set(key, { value: val, timestamp: Date.now() });
      return val;
    } catch (_) {
      if (entry) return entry.value;
      return fallback;
    } finally {
      inFlightRequests.delete(key);
    }
  })();

  inFlightRequests.set(key, promise);
  return promise;
}

/**
 * Get raw config value from system_config with in-memory caching and coalescing.
 * @param {string} key
 * @param {*} fallback
 * @param {number} ttlMs
 * @returns {Promise<*>}
 */
export async function getCachedSystemConfigValue(key, fallback = null, ttlMs = DEFAULT_TTL_MS) {
  const now = Date.now();
  const entry = cache.get(key);
  if (entry && (now - entry.timestamp) < ttlMs) {
    return entry.value !== undefined ? entry.value : fallback;
  }

  if (inFlightRequests.has(key)) {
    return inFlightRequests.get(key);
  }

  const promise = (async () => {
    try {
      const { data, error } = await supabaseAdmin
        .from('system_config')
        .select('config_value, config_type')
        .eq('config_key', key)
        .eq('is_active', true)
        .maybeSingle();

      if (error || !data) {
        if (entry) return entry.value;
        return fallback;
      }

      const val = data.config_value !== undefined ? data.config_value : fallback;
      cache.set(key, { value: val, timestamp: Date.now(), type: data.config_type });
      return val;
    } catch (_) {
      if (entry) return entry.value;
      return fallback;
    } finally {
      inFlightRequests.delete(key);
    }
  })();

  inFlightRequests.set(key, promise);
  return promise;
}

/**
 * Invalidate cache for a specific key, or all keys if omitted.
 * @param {string} [key]
 */
export function invalidateSystemConfigCache(key) {
  if (key) {
    cache.delete(key);
    inFlightRequests.delete(key);
  } else {
    cache.clear();
    inFlightRequests.clear();
  }
}
