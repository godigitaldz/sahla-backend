import { createClient } from '@supabase/supabase-js';

export type AdminAuthResult =
  | { ok: true; userId: string; role: string }
  | { ok: false; status: number; error: string };

export async function verifyAdminRequest(request: Request): Promise<AdminAuthResult> {
  const authHeader = request.headers.get('authorization');
  const token = authHeader?.startsWith('Bearer ') ? authHeader.slice(7) : null;
  if (!token) {
    return { ok: false, status: 401, error: 'missing_token' };
  }

  const url = process.env.SUPABASE_URL;
  const anonKey = process.env.SUPABASE_ANON_KEY;
  if (!url || !anonKey) {
    return { ok: false, status: 500, error: 'supabase_not_configured' };
  }

  const client = createClient(url, anonKey, {
    auth: { persistSession: false, autoRefreshToken: false },
    global: { headers: { Authorization: `Bearer ${token}` } },
  });

  const { data: userData, error: userError } = await client.auth.getUser(token);
  if (userError || !userData.user) {
    return { ok: false, status: 401, error: 'invalid_token' };
  }

  const { data: profile, error: profileError } = await client
    .from('user_profiles')
    .select('role')
    .eq('id', userData.user.id)
    .maybeSingle();

  if (profileError || !profile) {
    return { ok: false, status: 403, error: 'profile_not_found' };
  }

  const role = String(profile.role ?? '');
  if (role !== 'admin' && role !== 'super_admin') {
    return { ok: false, status: 403, error: 'not_admin' };
  }

  return { ok: true, userId: userData.user.id, role };
}

export async function writeAdminTableAudit(
  adminUserId: string,
  action: string,
  metadata: Record<string, unknown>,
  restaurantId?: string,
  restaurantTableId?: string,
) {
  const { getSupabaseAdmin } = await import('@/server/supabase/admin');
  const admin = getSupabaseAdmin();
  await admin.from('admin_table_audit_log').insert({
    admin_user_id: adminUserId,
    action,
    restaurant_id: restaurantId ?? null,
    restaurant_table_id: restaurantTableId ?? null,
    metadata,
  });
}
