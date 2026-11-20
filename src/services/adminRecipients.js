import { supabaseAdmin } from '../config/supabase.js';

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

let cachedAdminIds = null;
let cachedAdminTimestamp = 0;
let adminFetchInFlightPromise = null;
const ADMIN_CACHE_TTL_MS = 300_000; // 5 minutes in-memory cache

let lastAdminResolutionDiagnostic = {
  resolved_at: null,
  from_env_count: 0,
  from_db_count: 0,
  total_count: 0,
  db_error: null,
  cached: false,
};

/** Comma/semicolon/whitespace-separated auth user UUIDs for admin order alerts. */
export function parseAdminUserIdsFromEnv(logger = console) {
  const raw = String(process.env.ADMIN_ORDER_ALERT_USER_IDS || '').trim();
  if (!raw) return [];
  const entries = raw
    .split(/[,;\s]+/)
    .map((value) => value.trim())
    .filter(Boolean);
  const valid = [];
  const invalid = [];
  for (const id of entries) {
    if (UUID_RE.test(id)) {
      valid.push(id);
    } else {
      invalid.push(id);
    }
  }
  if (invalid.length > 0) {
    logger.warn?.(
      `[admin-recipients] ignoring ${invalid.length} invalid UUID(s) in ADMIN_ORDER_ALERT_USER_IDS: ${invalid.join(', ')}`,
    );
  }
  return valid;
}

/** Invalidate cached admin IDs (e.g. for testing or on role updates). */
export function invalidateAdminRecipientsCache() {
  cachedAdminIds = null;
  cachedAdminTimestamp = 0;
  adminFetchInFlightPromise = null;
  lastAdminResolutionDiagnostic = {
    resolved_at: null,
    from_env_count: 0,
    from_db_count: 0,
    total_count: 0,
    db_error: null,
    cached: false,
  };
}

/** Get structured diagnostic info on audience resolution status. */
export function getAdminAudienceDiagnostic() {
  return { ...lastAdminResolutionDiagnostic };
}

/** Auth user IDs with admin or super-admin role, plus explicitly configured recipients. */
export async function getActiveAdminUserIds(logger = console) {
  const now = Date.now();
  if (cachedAdminIds && now - cachedAdminTimestamp < ADMIN_CACHE_TTL_MS) {
    lastAdminResolutionDiagnostic = {
      ...lastAdminResolutionDiagnostic,
      cached: true,
    };
    return cachedAdminIds;
  }

  if (adminFetchInFlightPromise) {
    return adminFetchInFlightPromise;
  }

  adminFetchInFlightPromise = (async () => {
    try {
      const fromEnv = parseAdminUserIdsFromEnv(logger);
      if (fromEnv.length) {
        logger.info?.(`[admin-recipients] using ${fromEnv.length} id(s) from ADMIN_ORDER_ALERT_USER_IDS`);
      }

      const { data, error } = await supabaseAdmin
        .from('user_profiles')
        .select('id')
        .or('role.ilike.admin,role.eq.super_admin');

      if (error) {
        lastAdminResolutionDiagnostic = {
          resolved_at: new Date().toISOString(),
          from_env_count: fromEnv.length,
          from_db_count: 0,
          total_count: (cachedAdminIds || fromEnv).length,
          db_error: error.message,
          cached: Boolean(cachedAdminIds),
        };
        logger.error?.('[admin-recipients] admin query failed:', error.message);
        if (cachedAdminIds?.length) {
          logger.warn?.(
            `[admin-recipients] serving stale cached admin IDs (${cachedAdminIds.length}) due to DB failure`,
          );
          return cachedAdminIds;
        }
        if (fromEnv.length) {
          logger.warn?.(
            `[admin-recipients] serving env admin IDs (${fromEnv.length}) due to DB failure`,
          );
          return fromEnv;
        }
        logger.error?.('[admin-recipients] no fallback admin IDs available after DB query failure');
        return [];
      }

      const fromDb = (data ?? [])
        .map((row) => String(row?.id ?? ''))
        .filter(Boolean);
      const recipients = [...new Set([...fromEnv, ...fromDb])];

      lastAdminResolutionDiagnostic = {
        resolved_at: new Date().toISOString(),
        from_env_count: fromEnv.length,
        from_db_count: fromDb.length,
        total_count: recipients.length,
        db_error: null,
        cached: false,
      };

      if (!recipients.length) {
        logger.warn?.('[admin-recipients] no admin user ids found (0 in DB, 0 in env)');
      }

      cachedAdminIds = recipients;
      cachedAdminTimestamp = Date.now();
      return recipients;
    } finally {
      adminFetchInFlightPromise = null;
    }
  })();

  return adminFetchInFlightPromise;
}
