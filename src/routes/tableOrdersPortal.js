import { Router } from 'express';
import crypto from 'node:crypto';
import { supabaseAdmin } from '../config/supabase.js';
import { syncLifecycleForOrder } from '../modules/orders/application/scheduleOrderLifecycle.js';

const router = Router({ mergeParams: true });

const COOKIE_NAME = 'table_portal_auth';

const TABLE_ORDER_SELECT = `
  id,
  order_number,
  public_order_code,
  status,
  total_amount,
  guest_name,
  guest_phone,
  special_instructions,
  created_at,
  updated_at,
  table_id,
  restaurant_tables ( table_number, table_label )
`;

const TABLE_TRANSITIONS = {
  pending: new Set(['confirmed', 'preparing', 'cancelled']),
  confirmed: new Set(['preparing', 'cancelled']),
  preparing: new Set(['ready', 'cancelled']),
  ready: new Set(['delivered', 'cancelled']),
};

function sessionSecret() {
  return String(
    process.env.TABLE_ORDERS_SESSION_SECRET || process.env.PERFORMANCE_SESSION_SECRET || '',
  ).trim();
}

function webPublicBaseUrl() {
  return String(process.env.WEB_PUBLIC_BASE_URL || 'https://sahla-delivery.com').replace(/\/+$/, '');
}

function normalizePortalCode(raw) {
  return String(raw || '')
    .trim()
    .toLowerCase()
    .replace(/[^a-z0-9-]+/g, '-')
    .replace(/-+/g, '-')
    .replace(/^-|-$/g, '');
}

function parseCookies(req) {
  const out = {};
  const raw = req.headers.cookie;
  if (!raw) return out;
  for (const part of raw.split(';')) {
    const idx = part.indexOf('=');
    if (idx === -1) continue;
    out[part.slice(0, idx).trim()] = decodeURIComponent(part.slice(idx + 1).trim());
  }
  return out;
}

function signSession(payload) {
  const body = Buffer.from(JSON.stringify(payload), 'utf8').toString('base64url');
  const sig = crypto.createHmac('sha256', sessionSecret()).update(body).digest('base64url');
  return `${body}.${sig}`;
}

function verifySession(token) {
  if (!token || typeof token !== 'string') return null;
  const dot = token.indexOf('.');
  if (dot === -1) return null;
  const body = token.slice(0, dot);
  const sig = token.slice(dot + 1);
  const expected = crypto.createHmac('sha256', sessionSecret()).update(body).digest('base64url');
  if (sig.length !== expected.length) return null;
  if (!crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(expected))) return null;
  try {
    const payload = JSON.parse(Buffer.from(body, 'base64url').toString('utf8'));
    if (typeof payload.exp !== 'number' || Date.now() >= payload.exp) return null;
    if (!payload.restaurant_id || !payload.portal_code) return null;
    return payload;
  } catch {
    return null;
  }
}


function sha256Buffer(input) {
  return crypto.createHash('sha256').update(String(input), 'utf8').digest();
}

function byteaToBuffer(value) {
  if (!value) return null;
  if (Buffer.isBuffer(value)) return value;
  const raw = String(value).trim();
  if (!raw) return null;
  if (raw.startsWith('\\x')) return Buffer.from(raw.slice(2), 'hex');
  return Buffer.from(raw, 'base64');
}

function verifyPortalSecret(password, storedHash) {
  const expected = sha256Buffer(password);
  const stored = byteaToBuffer(storedHash);
  if (!stored || stored.length !== expected.length) return false;
  return crypto.timingSafeEqual(stored, expected);
}

function unwrapEmbed(value) {
  if (Array.isArray(value)) return value[0] ?? null;
  return value ?? null;
}

function buildOrderItemsSummary(items) {
  const rows = Array.isArray(items) ? items : [];
  const parts = rows
    .map((it) => {
      const qty = Number(it?.quantity ?? 1);
      const safeQty = Number.isFinite(qty) && qty > 0 ? qty : 1;
      const menu = unwrapEmbed(it?.menu_item);
      const name = String(menu?.name || '').trim();
      if (!name) return null;
      const note = String(it?.special_instructions ?? '').trim();
      return note ? `${safeQty}x ${name} (${note})` : `${safeQty}x ${name}`;
    })
    .filter(Boolean);
  return parts.length ? parts.join(' · ') : '—';
}

async function attachOrderItemsSummary(orders) {
  const list = Array.isArray(orders) ? orders : [];
  const ids = [...new Set(list.map((o) => String(o?.id || '').trim()).filter(Boolean))];
  if (!ids.length) return list.map((o) => ({ ...o, order_items_summary: '—' }));

  const byOrder = new Map();
  const { data, error } = await supabaseAdmin
    .from('order_items')
    .select('order_id, quantity, special_instructions, menu_item:menu_items(name)')
    .in('order_id', ids);
  if (error) throw error;
  for (const it of data || []) {
    const oid = String(it?.order_id || '').trim();
    if (!oid) continue;
    const arr = byOrder.get(oid) || [];
    arr.push(it);
    byOrder.set(oid, arr);
  }

  return list.map((o) => ({
    ...o,
    order_items_summary: buildOrderItemsSummary(byOrder.get(String(o.id || '').trim()) || []),
  }));
}

async function resolveRestaurantByCode(code) {
  const portalCode = normalizePortalCode(code);
  if (!portalCode) return null;

  const { data, error } = await supabaseAdmin
    .from('restaurants')
    .select('id,name,table_portal_code,table_portal_secret_hash,table_ordering_enabled,is_verified,public_slug')
    .eq('table_portal_code', portalCode)
    .maybeSingle();
  if (error) throw error;
  if (!data?.id || !data.table_ordering_enabled || !data.is_verified) return null;
  return { ...data, portal_code: portalCode };
}

function requirePortalAuth(req, res, next) {
  const code = normalizePortalCode(req.params.code);
  const session = verifySession(parseCookies(req)[COOKIE_NAME]);
  if (!session || normalizePortalCode(session.portal_code) !== code) {
    return res.status(401).json({ success: false, error: 'unauthorized' });
  }
  req.portalSession = session;
  req.portalCode = code;
  return next();
}

async function syncLifecycleForOrderRow(orderRow) {
  if (!orderRow?.id) return;
  const { data: full, error } = await supabaseAdmin
    .from('orders')
    .select('id,status,delivery_person_id,lifecycle_version,courier_assigned_at')
    .eq('id', orderRow.id)
    .maybeSingle();
  if (error || !full) return;
  await syncLifecycleForOrder(full, Number(full.lifecycle_version || 0)).catch(() => {});
}

function mapOrderRow(row) {
  const table = unwrapEmbed(row.restaurant_tables);
  return {
    id: row.id,
    order_number: row.order_number,
    public_order_code: row.public_order_code,
    status: row.status,
    total_amount: Number(row.total_amount ?? 0),
    guest_name: row.guest_name,
    guest_phone: row.guest_phone,
    special_instructions: row.special_instructions,
    created_at: row.created_at,
    updated_at: row.updated_at,
    table_number: table?.table_number ?? null,
    table_label: table?.table_label ?? null,
  };
}

router.get('/:code/meta', async (req, res) => {
  try {
    const restaurant = await resolveRestaurantByCode(req.params.code);
    if (!restaurant) {
      return res.status(404).json({ success: false, error: 'restaurant_not_found' });
    }
    return res.json({
      success: true,
      restaurant: {
        id: restaurant.id,
        name: restaurant.name,
        portal_code: restaurant.portal_code,
      },
      portal_password_configured: Boolean(restaurant.table_portal_secret_hash),
    });
  } catch (e) {
    return res.status(500).json({ success: false, error: e.message || 'meta_failed' });
  }
});

router.post('/:code/auth', async (req, res) => {
  try {
    if (!sessionSecret()) {
      return res.status(503).json({ success: false, error: 'portal_auth_not_configured' });
    }

    const restaurant = await resolveRestaurantByCode(req.params.code);
    if (!restaurant) {
      return res.status(404).json({ success: false, error: 'restaurant_not_found' });
    }

    if (!restaurant.table_portal_secret_hash) {
      return res.status(503).json({ success: false, error: 'portal_password_not_set' });
    }

    const pwd = String(req.body?.password ?? '');
    if (!verifyPortalSecret(pwd, restaurant.table_portal_secret_hash)) {
      return res.status(401).json({ success: false, error: 'invalid_password' });
    }

    const token = signSession({
      exp: Date.now() + 12 * 3600 * 1000,
      restaurant_id: restaurant.id,
      portal_code: restaurant.portal_code,
    });
    const secure = !!(process.env.VERCEL || process.env.NODE_ENV === 'production');
    res.cookie(COOKIE_NAME, token, {
      httpOnly: true,
      secure,
      sameSite: 'lax',
      maxAge: 12 * 3600 * 1000,
      path: '/',
    });

    return res.json({
      success: true,
      restaurant: { id: restaurant.id, name: restaurant.name },
    });
  } catch (e) {
    return res.status(500).json({ success: false, error: e.message || 'auth_failed' });
  }
});

router.post('/:code/logout', requirePortalAuth, (req, res) => {
  res.clearCookie(COOKIE_NAME, { path: '/' });
  return res.json({ success: true });
});

router.get('/:code/orders', requirePortalAuth, async (req, res) => {
  try {
    const restaurantId = req.portalSession.restaurant_id;
    const activeOnly = String(req.query.active ?? '1') !== '0';

    let q = supabaseAdmin
      .from('orders')
      .select(TABLE_ORDER_SELECT)
      .eq('restaurant_id', restaurantId)
      .eq('fulfillment_type', 'table')
      .order('created_at', { ascending: false })
      .limit(120);

    if (activeOnly) {
      q = q.in('status', ['pending', 'confirmed', 'preparing', 'ready']);
    }

    const { data, error } = await q;
    if (error) throw error;

    const orders = await attachOrderItemsSummary((data || []).map(mapOrderRow));
    return res.json({ success: true, orders });
  } catch (e) {
    return res.status(500).json({ success: false, error: e.message || 'orders_failed' });
  }
});

router.post('/:code/orders/:orderId/status', requirePortalAuth, async (req, res) => {
  try {
    const orderId = String(req.params.orderId || '').trim();
    const nextStatus = String(req.body?.status || '').trim().toLowerCase();
    const restaurantId = req.portalSession.restaurant_id;

    const { data: order, error: fetchErr } = await supabaseAdmin
      .from('orders')
      .select('id,order_number,status,restaurant_id,fulfillment_type,lifecycle_version,delivery_person_id')
      .eq('id', orderId)
      .eq('restaurant_id', restaurantId)
      .eq('fulfillment_type', 'table')
      .maybeSingle();
    if (fetchErr) throw fetchErr;
    if (!order) {
      return res.status(404).json({ success: false, error: 'order_not_found' });
    }

    const current = String(order.status || '').toLowerCase();
    const allowed = TABLE_TRANSITIONS[current];
    if (!allowed || !allowed.has(nextStatus)) {
      return res.status(409).json({
        success: false,
        error: `cannot_transition_${current}_to_${nextStatus}`,
      });
    }

    const now = new Date().toISOString();
    const updatePayload = { status: nextStatus, updated_at: now };
    if (nextStatus === 'cancelled') {
      updatePayload.cancelled_at = now;
      updatePayload.cancel_reason = JSON.stringify({ source: 'table_orders_portal' });
    }
    if (nextStatus === 'delivered') {
      updatePayload.actual_delivery_time = now;
      updatePayload.delivered_at = now;
    }

    const { data: rows, error: updErr } = await supabaseAdmin
      .from('orders')
      .update(updatePayload)
      .eq('id', orderId)
      .select('id,order_number,status,lifecycle_version,delivery_person_id')
      .limit(1);
    if (updErr) throw updErr;
    if (!rows?.length) {
      return res.status(409).json({ success: false, error: 'status_update_failed' });
    }

    await syncLifecycleForOrderRow(rows[0]);
    return res.json({ success: true, order: rows[0] });
  } catch (e) {
    return res.status(500).json({ success: false, error: e.message || 'status_failed' });
  }
});

export { webPublicBaseUrl, normalizePortalCode };

export default router;
