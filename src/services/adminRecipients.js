import { supabaseAdmin } from '../config/supabase.js';

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

/** Comma/semicolon/whitespace-separated auth user UUIDs for admin order alerts. */
export function parseAdminUserIdsFromEnv() {
  const raw = String(process.env.ADMIN_ORDER_ALERT_USER_IDS || '').trim();
  if (!raw) return [];
  return raw
    .split(/[,;\s]+/)
    .map((value) => value.trim())
    .filter((id) => UUID_RE.test(id));
}

/** Auth user IDs with admin or super-admin role, plus explicitly configured recipients. */
export async function getActiveAdminUserIds(logger = console) {
  const fromEnv = parseAdminUserIdsFromEnv();
  if (fromEnv.length) {
    logger.info?.(`[admin-recipients] using ${fromEnv.length} id(s) from ADMIN_ORDER_ALERT_USER_IDS`);
  }

  const { data, error } = await supabaseAdmin
    .from('user_profiles')
    .select('id')
    .or('role.ilike.admin,role.eq.super_admin');

  if (error) {
    logger.error?.('[admin-recipients] admin query failed:', error.message);
    return fromEnv;
  }

  const fromDb = (data ?? [])
    .map((row) => String(row?.id ?? ''))
    .filter(Boolean);
  const recipients = [...new Set([...fromEnv, ...fromDb])];

  if (!recipients.length) {
    logger.warn?.('[admin-recipients] no admin user ids found');
  }
  return recipients;
}
