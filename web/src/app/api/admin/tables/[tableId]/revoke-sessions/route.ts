import { NextRequest, NextResponse } from 'next/server';
import { verifyAdminRequest, writeAdminTableAudit } from '@/server/admin/verifyAdmin';
import { getSupabaseAdmin } from '@/server/supabase/admin';

export async function POST(
  request: NextRequest,
  context: { params: Promise<{ tableId: string }> },
) {
  const auth = await verifyAdminRequest(request);
  if (!auth.ok) {
    return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
  }

  const { tableId } = await context.params;
  const now = new Date().toISOString();
  const admin = getSupabaseAdmin();

  const { data: table } = await admin
    .from('restaurant_tables')
    .select('restaurant_id')
    .eq('id', tableId)
    .maybeSingle();

  await admin
    .from('table_order_sessions')
    .update({ revoked_at: now })
    .eq('restaurant_table_id', tableId)
    .is('revoked_at', null);

  await writeAdminTableAudit(auth.userId, 'sessions_revoked', {}, table?.restaurant_id, tableId);

  return NextResponse.json({ success: true });
}
