import { NextRequest, NextResponse } from 'next/server';
import { verifyAdminRequest } from '@/server/admin/verifyAdmin';
import { getSupabaseAdmin } from '@/server/supabase/admin';

export async function GET(
  request: NextRequest,
  context: { params: Promise<{ restaurantId: string }> },
) {
  const auth = await verifyAdminRequest(request);
  if (!auth.ok) {
    return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
  }

  const { restaurantId } = await context.params;
  const admin = getSupabaseAdmin();

  const { data, error } = await admin
    .from('restaurant_tables')
    .select('id,table_number,table_label,sort_order,is_active,created_at,updated_at')
    .eq('restaurant_id', restaurantId)
    .is('deleted_at', null)
    .order('sort_order', { ascending: true });

  if (error) {
    return NextResponse.json({ success: false, error: error.message }, { status: 500 });
  }

  return NextResponse.json({ success: true, data: data ?? [] });
}

export async function POST(
  request: NextRequest,
  context: { params: Promise<{ restaurantId: string }> },
) {
  const auth = await verifyAdminRequest(request);
  if (!auth.ok) {
    return NextResponse.json({ success: false, error: auth.error }, { status: auth.status });
  }

  const { restaurantId } = await context.params;
  const body = await request.json();
  const tableNumber = String(body.table_number ?? '').trim();
  const tableLabel = body.table_label ? String(body.table_label).trim() : null;

  if (!tableNumber) {
    return NextResponse.json({ success: false, error: 'table_number_required' }, { status: 400 });
  }

  const admin = getSupabaseAdmin();
  const { data: table, error } = await admin
    .from('restaurant_tables')
    .insert({
      restaurant_id: restaurantId,
      table_number: tableNumber,
      table_label: tableLabel,
    })
    .select('id,table_number,table_label')
    .single();

  if (error) {
    return NextResponse.json({ success: false, error: error.message }, { status: 400 });
  }

  const { generateOpaqueTableCode, sha256Buffer } = await import('@/server/table/crypto');
  const opaqueCode = generateOpaqueTableCode();

  const { error: codeError } = await admin.from('restaurant_table_codes').insert({
    restaurant_table_id: table.id,
    code_hash: `\\x${sha256Buffer(opaqueCode).toString('hex')}`,
    code_token: opaqueCode,
    created_by: auth.userId,
  });

  if (codeError) {
    return NextResponse.json({ success: false, error: codeError.message }, { status: 500 });
  }

  const { writeAdminTableAudit } = await import('@/server/admin/verifyAdmin');
  await writeAdminTableAudit(auth.userId, 'table_created', { table_number: tableNumber }, restaurantId, table.id);

  return NextResponse.json({
    success: true,
    data: {
      ...table,
      qr_url: `${process.env.NEXT_PUBLIC_WEB_BASE_URL ?? 'https://sahla-delivery.com'}/t/${opaqueCode}`,
      table_code: opaqueCode,
    },
  });
}
