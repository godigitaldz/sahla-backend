import { getSupabaseAdmin } from '@/server/supabase/admin';
import { generateVenueCode, sha256Buffer } from '@/server/table/crypto';
import { cacheVenueCodePlaintext } from '@/server/rateLimit/upstashTableLimiter';

const WINDOW_MS = 5 * 60 * 1000;

export async function ensureActiveVenueWindow(restaurantId: string): Promise<{
  windowEnd: string;
  secondsRemaining: number;
}> {
  const admin = getSupabaseAdmin();
  const now = new Date();
  const nowIso = now.toISOString();

  const { data: existing } = await admin
    .from('restaurant_venue_code_windows')
    .select('id, window_end')
    .eq('restaurant_id', restaurantId)
    .lte('window_start', nowIso)
    .gt('window_end', nowIso)
    .order('window_end', { ascending: false })
    .limit(1)
    .maybeSingle();

  if (existing?.window_end) {
    const end = new Date(existing.window_end);
    return {
      windowEnd: existing.window_end,
      secondsRemaining: Math.max(0, Math.floor((end.getTime() - now.getTime()) / 1000)),
    };
  }

  const code = generateVenueCode();
  const windowStart = now;
  const windowEnd = new Date(now.getTime() + WINDOW_MS);

  const { data: maxVersion } = await admin
    .from('restaurant_venue_code_windows')
    .select('version')
    .eq('restaurant_id', restaurantId)
    .order('version', { ascending: false })
    .limit(1)
    .maybeSingle();

  const version = (maxVersion?.version ?? 0) + 1;

  await admin.from('restaurant_venue_code_windows').insert({
    restaurant_id: restaurantId,
    code_hash: `\\x${sha256Buffer(code).toString('hex')}`,
    window_start: windowStart.toISOString(),
    window_end: windowEnd.toISOString(),
    version,
  });

  await cacheVenueCodePlaintext(restaurantId, code, Math.ceil(WINDOW_MS / 1000));

  return {
    windowEnd: windowEnd.toISOString(),
    secondsRemaining: Math.ceil(WINDOW_MS / 1000),
  };
}

export async function getVenueCodeForStaff(restaurantId: string): Promise<{
  code: string | null;
  windowEnd: string;
  secondsRemaining: number;
}> {
  const meta = await ensureActiveVenueWindow(restaurantId);
  const { getCachedVenueCodePlaintext } = await import('@/server/rateLimit/upstashTableLimiter');
  const code = await getCachedVenueCodePlaintext(restaurantId);
  return { code, ...meta };
}
