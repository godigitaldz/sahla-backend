import { NextRequest, NextResponse } from 'next/server';
import { verifyAdminRequest, writeAdminTableAudit } from '@/server/admin/verifyAdmin';
import { generateOpaqueTableCode, sha256Buffer } from '@/server/table/crypto';
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
  const admin = getSupabaseAdmin();
  const now = new Date().toISOString();

  await admin
    .from('restaurant_table_codes')
    .update({ is_active: false, revoked_at: now })
    .eq('restaurant_table_id', tableId)
    .eq('is_active', true);

  await admin
    .from('table_order_sessions')
    .update({ revoked_at: now })
    .eq('restaurant_table_id', tableId)
    .is('revoked_at', null);

  const opaqueCode = generateOpaqueTableCode();
  const { data: maxVersion } = await admin
    .from('restaurant_table_codes')
    .select('version')
    .eq('restaurant_table_id', tableId)
    .order('version', { ascending: false })
    .limit(1)
    .maybeSingle();

  const { error: insertError } = await admin.from('restaurant_table_codes').insert({
    restaurant_table_id: tableId,
    code_hash: `\\x${sha256Buffer(opaqueCode).toString('hex')}`,
    code_token: opaqueCode,
    version: (maxVersion?.version ?? 0) + 1,
    created_by: auth.userId,
  });

  if (insertError) {
    return NextResponse.json({ success: false, error: insertError.message }, { status: 500 });
  }

  const { data: table } = await admin
    .from('restaurant_tables')
    .select('restaurant_id, table_number')
    .eq('id', tableId)
    .maybeSingle();

  await writeAdminTableAudit(auth.userId, 'table_code_regenerated', {}, table?.restaurant_id, tableId);

  return NextResponse.json({
    success: true,
    data: {
      qr_url: `${process.env.NEXT_PUBLIC_WEB_BASE_URL ?? 'https://sahla-delivery.com'}/t/${opaqueCode}`,
      table_code: opaqueCode,
      table_number: table?.table_number,
    },
  });
}
