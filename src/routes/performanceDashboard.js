import crypto from 'node:crypto';
import { Router } from 'express';

import { supabaseAdmin } from '../config/supabase.js';
import { runPendingOrdersPollOnce } from '../services/pendingOrdersPoller.js';
import { runPickupDelayAdminAlertsOnce } from '../services/pickupDelayAdminAlertsPoller.js';
import { supabasePushGateway } from '../modules/notifications/supabasePushGateway.js';
import {
  getRestaurantOpsUserIds,
  getOnlineAvailableCourierUserIds,
} from '../modules/notifications/orderRebroadcastRecipients.js';
import { getActiveAdminUserIds } from '../services/adminRecipients.js';

const router = Router();

/** Throttle for optional background poll tied to dashboard traffic (see PERFORMANCE_OPEN_DASHBOARD_POLL_MS). */
let _lastDashboardEscalationPollMs = 0;

const COOKIE_NAME = 'perf_auth';

function alertThresholdMinutes() {
  const n = Number(process.env.PERFORMANCE_ALERT_MINUTES);
  return Number.isFinite(n) && n > 0 ? n : 5;
}

/** Reviews created within this window count as "new" for badges (hours). */
function newReviewThresholdHours() {
  const n = Number(process.env.PERFORMANCE_NEW_REVIEW_HOURS);
  return Number.isFinite(n) && n > 0 ? n : 48;
}

function newReviewThresholdIso() {
  return new Date(Date.now() - newReviewThresholdHours() * 3600 * 1000).toISOString();
}

async function countNewRestaurantReviewsInWindow(restaurantId) {
  const iso = newReviewThresholdIso();
  let q = supabaseAdmin
    .from('restaurant_reviews')
    .select('id', { count: 'exact', head: true })
    .gte('created_at', iso);
  const rid = String(restaurantId || '').trim();
  if (rid) q = q.eq('restaurant_id', rid);
  const { count, error } = await q;
  if (error) throw error;
  return count ?? 0;
}

async function countNewDeliveryReviewsInWindow(deliveryPersonId) {
  const iso = newReviewThresholdIso();
  let q = supabaseAdmin
    .from('delivery_reviews')
    .select('id', { count: 'exact', head: true })
    .gte('created_at', iso);
  const did = String(deliveryPersonId || '').trim();
  if (did) q = q.eq('delivery_person_id', did);
  const { count, error } = await q;
  if (error) throw error;
  return count ?? 0;
}

function ageMinutes(iso) {
  if (!iso) return null;
  const t = new Date(iso).getTime();
  if (Number.isNaN(t)) return null;
  return Math.floor((Date.now() - t) / 60000);
}

/** PostgREST may return an embedded row as object or single-element array. */
function unwrapEmbed(v) {
  if (v == null) return null;
  if (Array.isArray(v)) return v[0] ?? null;
  return v;
}

function assignedAgoLabel(minutes) {
  if (minutes == null) return null;
  if (minutes <= 0) return 'just now';
  if (minutes === 1) return '1 min ago';
  return `${minutes} min ago`;
}

function parseSahlaDateRange(fromDateStr, toDateStr) {
  let startIso = null;
  let endIso = null;
  if (fromDateStr && /^\d{4}-\d{2}-\d{2}$/.test(fromDateStr)) {
    startIso = new Date(`${fromDateStr}T00:00:00+01:00`).toISOString();
  }
  if (toDateStr && /^\d{4}-\d{2}-\d{2}$/.test(toDateStr)) {
    endIso = new Date(`${toDateStr}T23:59:59.999+01:00`).toISOString();
  }
  return { startIso, endIso };
}

async function enrichTasksWithCourierDetails(rows) {
  const list = rows || [];
  const ids = [...new Set(list.map((t) => t.delivery_man_id).filter(Boolean))];
  const byPersonnelId = new Map();
  const byUserId = new Map();
  if (ids.length) {
    const slice = ids.slice(0, 400);
    const { data: personnel, error: e1 } = await supabaseAdmin
      .from('delivery_personnel')
      .select(
        `
        id,
        user_id,
        delivery_name,
        work_phone,
        user:user_id(name,phone)
      `,
      )
      .in('id', slice);
    if (e1) throw e1;
    for (const p of personnel || []) {
      byPersonnelId.set(p.id, p);
    }
    const missing = slice.filter((id) => !byPersonnelId.has(id));
    if (missing.length) {
      const { data: profs, error: e2 } = await supabaseAdmin
        .from('user_profiles')
        .select('id,name,phone')
        .in('id', missing);
      if (e2) throw e2;
      for (const p of profs || []) {
        byUserId.set(p.id, p);
      }
    }
  }

  return list.map((t) => {
    let name = t.delivery_man_name || null;
    let phone = t.delivery_man_phone || null;
    const aid = t.delivery_man_id;
    if (aid) {
      const dp = byPersonnelId.get(aid);
      if (dp) {
        const u = unwrapEmbed(dp.user);
        name = u?.name || dp.delivery_name || name;
        phone = u?.phone || dp.work_phone || phone;
      } else {
        const prof = byUserId.get(aid);
        if (prof) {
          name = prof.name || name;
          phone = prof.phone || phone;
        }
      }
    }
    const assignedIso = t.assigned_at || (aid ? t.updated_at : null);
    const agoMin = assignedIso != null ? ageMinutes(assignedIso) : null;
    return {
      ...t,
      courier_display_name: name,
      courier_display_phone: phone,
      courier_assigned_at_iso: assignedIso,
      courier_assigned_ago_minutes: agoMin,
      courier_assigned_ago_label: assignedAgoLabel(agoMin),
      courier_assigned_time_exact: Boolean(t.assigned_at),
    };
  });
}

function enrichOrderCourier(o) {
  const dp = unwrapEmbed(o.delivery_personnel);
  const u = dp ? unwrapEmbed(dp.user) : null;
  const name = u?.name || dp?.delivery_name || null;
  const phone = u?.phone || dp?.work_phone || null;
  const hasCourier = Boolean(o.delivery_person_id);
  const assignedIso = hasCourier ? (o.courier_assigned_at || o.updated_at) : null;
  const agoMin = assignedIso != null ? ageMinutes(assignedIso) : null;
  const cust = unwrapEmbed(o.customer);
  return {
    ...o,
    courier_display_name: name,
    courier_display_phone: phone,
    customer_display_phone: o.guest_phone || cust?.phone || null,
    courier_assigned_at_iso: assignedIso,
    courier_assigned_ago_minutes: agoMin,
    courier_assigned_ago_label: hasCourier ? assignedAgoLabel(agoMin) : null,
    courier_assigned_time_exact: Boolean(o.courier_assigned_at),
  };
}

function buildOrderItemsSummary(items) {
  const list = Array.isArray(items) ? items : [];
  const parts = list
    .map((it) => {
      const qty = Number(it?.quantity);
      const safeQty = Number.isFinite(qty) && qty > 0 ? qty : 1;
      const menu = unwrapEmbed(it?.menu_item);
      const name = String(menu?.name || it?.name || '').trim();
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
  const chunk = 100;
  for (let i = 0; i < ids.length; i += chunk) {
    const slice = ids.slice(i, i + chunk);
    try {
      const { data, error } = await supabaseAdmin
        .from('order_items')
        .select('order_id, quantity, special_instructions, menu_item:menu_items(name)')
        .in('order_id', slice);
      if (!error && data) {
        for (const it of data) {
          const oid = String(it?.order_id || '').trim();
          if (!oid) continue;
          const arr = byOrder.get(oid) || [];
          arr.push(it);
          byOrder.set(oid, arr);
        }
      }
    } catch (itemErr) {
      console.warn('attachOrderItemsSummary failed chunk', itemErr);
    }
  }

  return list.map((o) => ({
    ...o,
    order_items_summary: buildOrderItemsSummary(byOrder.get(String(o.id || '').trim()) || []),
  }));
}

const DEFAULT_PERFORMANCE_ADMIN_PHONE = '+213799790530';

function performanceAdminPhone() {
  return (process.env.PERFORMANCE_ADMIN_PHONE || DEFAULT_PERFORMANCE_ADMIN_PHONE).trim();
}

function phoneDigits(s) {
  return String(s ?? '').replace(/\D/g, '');
}

async function resolvePerformanceReviewer() {
  const configured = performanceAdminPhone();
  const last9 = phoneDigits(configured).slice(-9);
  let adminProfile = null;
  if (last9.length >= 9) {
    const { data: candidates, error } = await supabaseAdmin
      .from('user_profiles')
      .select('id,name,phone')
      .ilike('phone', `%${last9}%`)
      .limit(25);
    if (!error && candidates?.length) {
      const want = phoneDigits(configured);
      adminProfile =
        candidates.find((p) => phoneDigits(p.phone) === want) ||
        candidates.find((p) => phoneDigits(p.phone).endsWith(last9)) ||
        candidates[0];
    }
  }
  const reviewedBy =
    adminProfile?.name?.trim() ||
    process.env.PERFORMANCE_ADMIN_REVIEWER_NAME ||
    `Admin (${configured})`;
  return {
    adminProfile,
    reviewedBy,
    adminId: adminProfile?.id ?? null,
    adminPhone: configured,
  };
}

function isUuid(id) {
  return (
    typeof id === 'string' &&
    /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i.test(id)
  );
}

function openingHoursPayload(h) {
  if (h && typeof h === 'object' && !Array.isArray(h)) return h;
  return {};
}

function dashboardPassword() {
  return process.env.PERFORMANCE_DASHBOARD_PASSWORD || '@Khazani05102002';
}

function sessionSecret() {
  return (
    process.env.PERFORMANCE_SESSION_SECRET ||
    process.env.SUPABASE_SERVICE_ROLE_KEY ||
    'change-PERFORMANCE_SESSION_SECRET'
  );
}

function parseCookies(req) {
  const out = {};
  const raw = req.headers.cookie;
  if (!raw) return out;
  for (const part of raw.split(';')) {
    const idx = part.indexOf('=');
    if (idx === -1) continue;
    const k = part.slice(0, idx).trim();
    const v = decodeURIComponent(part.slice(idx + 1).trim());
    out[k] = v;
  }
  return out;
}

function signSession() {
  const exp = Date.now() + 12 * 3600 * 1000;
  const payload = Buffer.from(JSON.stringify({ exp }), 'utf8').toString('base64url');
  const sig = crypto.createHmac('sha256', sessionSecret()).update(payload).digest('base64url');
  return `${payload}.${sig}`;
}

function verifySession(token) {
  if (!token || typeof token !== 'string') return false;
  const dot = token.indexOf('.');
  if (dot === -1) return false;
  const payloadB64 = token.slice(0, dot);
  const sig = token.slice(dot + 1);
  const expected = crypto.createHmac('sha256', sessionSecret()).update(payloadB64).digest('base64url');
  if (sig.length !== expected.length) return false;
  if (!crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(expected))) return false;
  try {
    const { exp } = JSON.parse(Buffer.from(payloadB64, 'base64url').toString('utf8'));
    return typeof exp === 'number' && Date.now() < exp;
  } catch {
    return false;
  }
}

function requirePerformanceAuth(req, res, next) {
  const cookies = parseCookies(req);
  if (!verifySession(cookies[COOKIE_NAME])) {
    return res.status(401).json({ success: false, error: 'Unauthorized' });
  }
  return next();
}

function safeEqualUtf8(a, b) {
  const ba = Buffer.from(String(a), 'utf8');
  const bb = Buffer.from(String(b), 'utf8');
  if (ba.length !== bb.length) return false;
  return crypto.timingSafeEqual(ba, bb);
}

/* ========================================================================= */
/* Auth & Session Routes                                                     */
/* ========================================================================= */

router.post('/auth', (req, res) => {
  const pwd = String(req.body?.password ?? '');
  if (!safeEqualUtf8(pwd, dashboardPassword())) {
    return res.status(401).json({ success: false, error: 'Invalid password' });
  }
  const token = signSession();
  const secure = !!(process.env.VERCEL || process.env.NODE_ENV === 'production');
  const cookieVal = [
    `${COOKIE_NAME}=${encodeURIComponent(token)}`,
    'Path=/',
    'HttpOnly',
    'SameSite=Lax',
    'Max-Age=43200',
    ...(secure ? ['Secure'] : []),
  ].join('; ');
  res.setHeader('Set-Cookie', cookieVal);
  return res.json({ success: true });
});

router.post('/logout', requirePerformanceAuth, (req, res) => {
  res.setHeader('Set-Cookie', `${COOKIE_NAME}=; Path=/; HttpOnly; SameSite=Lax; Max-Age=0`);
  return res.json({ success: true });
});

/* ========================================================================= */
/* Metadata & Global Counters                                                */
/* ========================================================================= */

router.get('/meta', requirePerformanceAuth, async (req, res) => {
  try {
    const [rRest, rPer, cDm, cR, cPs, reviewer, newReviewsGlobal, newReviewsDelivery] = await Promise.all([
      supabaseAdmin.from('restaurants').select('id,name').order('name'),
      supabaseAdmin.from('delivery_personnel').select('id,user_id,delivery_name,work_phone'),
      supabaseAdmin
        .from('delivery_man_requests')
        .select('id', { count: 'exact', head: true })
        .eq('status', 'pending'),
      supabaseAdmin
        .from('restaurant_requests')
        .select('id', { count: 'exact', head: true })
        .eq('status', 'pending'),
      supabaseAdmin
        .from('parcel_sender_requests')
        .select('id', { count: 'exact', head: true })
        .eq('status', 'pending'),
      resolvePerformanceReviewer(),
      countNewRestaurantReviewsInWindow(null),
      countNewDeliveryReviewsInWindow(null),
    ]);
    if (rRest.error) throw rRest.error;
    if (rPer.error) throw rPer.error;
    if (cDm.error) throw cDm.error;
    if (cR.error) throw cR.error;
    if (cPs.error) throw cPs.error;

    const restaurants = rRest.data || [];
    const personnel = rPer.data || [];
    const pendingDeliveryManRequests = cDm.count ?? 0;
    const pendingRestaurantRequests = cR.count ?? 0;
    const pendingParcelSenderRequests = cPs.count ?? 0;

    const uids = [...new Set(personnel.map((p) => p.user_id).filter(Boolean))];
    let couriers = [];
    if (uids.length) {
      const { data: profs, error: e3 } = await supabaseAdmin
        .from('user_profiles')
        .select('id,name,phone')
        .in('id', uids.slice(0, 500));
      if (e3) throw e3;
      couriers = profs || [];
    }

    const deliveryPersonnelOptions = personnel.map((dp) => {
      const prof = couriers.find((c) => c.id === dp.user_id);
      return {
        id: dp.id,
        user_id: dp.user_id,
        name: dp.delivery_name || prof?.name || dp.id,
        phone: dp.work_phone || prof?.phone || null,
      };
    });

    return res.json({
      success: true,
      restaurants,
      couriers,
      delivery_personnel_options: deliveryPersonnelOptions,
      pending_delivery_man_requests: pendingDeliveryManRequests,
      pending_restaurant_requests: pendingRestaurantRequests,
      pending_parcel_sender_requests: pendingParcelSenderRequests,
      new_restaurant_reviews_in_window: newReviewsGlobal,
      new_reviews_in_window: newReviewsGlobal,
      new_restaurant_reviews_hours: newReviewThresholdHours(),
      new_delivery_reviews_in_window: newReviewsDelivery,
      admin_phone: reviewer.adminPhone,
      admin_profile: reviewer.adminProfile,
      admin_reviewer_label: reviewer.reviewedBy,
    });
  } catch (e) {
    console.error('performance /meta', e);
    return res.status(500).json({ success: false, error: e.message || 'Query failed' });
  }
});

/* ========================================================================= */
/* Partner Requests: Delivery Man, Restaurant, Parcel Sender                 */
/* ========================================================================= */

router.get('/delivery-man-requests', requirePerformanceAuth, async (req, res) => {
  try {
    let q = supabaseAdmin
      .from('delivery_man_requests')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(200);
    const status = String(req.query.status || '').trim();
    if (status) q = q.eq('status', status);
    const { data, error } = await q;
    if (error) throw error;
    return res.json({ success: true, requests: data || [] });
  } catch (e) {
    console.error('performance /delivery-man-requests', e);
    return res.status(500).json({ success: false, error: e.message || 'Query failed' });
  }
});

router.get('/restaurant-requests', requirePerformanceAuth, async (req, res) => {
  try {
    let q = supabaseAdmin
      .from('restaurant_requests')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(200);
    const status = String(req.query.status || '').trim();
    if (status) q = q.eq('status', status);
    const { data, error } = await q;
    if (error) throw error;
    return res.json({ success: true, requests: data || [] });
  } catch (e) {
    console.error('performance /restaurant-requests', e);
    return res.status(500).json({ success: false, error: e.message || 'Query failed' });
  }
});

router.get('/parcel-sender-requests', requirePerformanceAuth, async (req, res) => {
  try {
    let q = supabaseAdmin
      .from('parcel_sender_requests')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(200);
    const status = String(req.query.status || '').trim();
    if (status) q = q.eq('status', status);
    const { data, error } = await q;
    if (error) throw error;
    return res.json({ success: true, requests: data || [] });
  } catch (e) {
    console.error('performance /parcel-sender-requests', e);
    return res.status(500).json({ success: false, error: e.message || 'Query failed' });
  }
});

router.post('/delivery-man-requests/:id/approve', requirePerformanceAuth, async (req, res) => {
  try {
    const id = req.params.id;
    if (!isUuid(id)) {
      return res.status(400).json({ success: false, error: 'Invalid id' });
    }
    const { reviewedBy } = await resolvePerformanceReviewer();
    const now = new Date().toISOString();

    const { data: request, error: fetchErr } = await supabaseAdmin
      .from('delivery_man_requests')
      .select('*')
      .eq('id', id)
      .eq('status', 'pending')
      .maybeSingle();
    if (fetchErr) throw fetchErr;
    if (!request) {
      return res.status(404).json({ success: false, error: 'Pending delivery request not found' });
    }

    const { data: updatedReq, error: u1 } = await supabaseAdmin
      .from('delivery_man_requests')
      .update({
        status: 'approved',
        reviewed_by: reviewedBy,
        reviewed_at: now,
        updated_at: now,
      })
      .eq('id', id)
      .eq('status', 'pending')
      .select('id');
    if (u1) throw u1;
    if (!updatedReq?.length) {
      return res.status(409).json({ success: false, error: 'Request is no longer pending' });
    }

    const { data: roleRows, error: u2 } = await supabaseAdmin
      .from('user_profiles')
      .update({ role: 'delivery_man', updated_at: now })
      .eq('id', request.user_id)
      .select('id, role');
    if (u2) throw u2;
    if (!roleRows?.length || roleRows[0].role !== 'delivery_man') {
      return res.status(500).json({ success: false, error: 'Failed to set user role to delivery_man' });
    }

    const vehicleModel = request.vehicle_model ?? null;
    const vehicleBrand =
      vehicleModel != null && String(vehicleModel).trim()
        ? String(vehicleModel).trim().split(/\s+/)[0]
        : null;
    const vehicleYearParsed =
      request.vehicle_year != null ? parseInt(String(request.vehicle_year), 10) : null;
    const vehicleYear = Number.isFinite(vehicleYearParsed) ? vehicleYearParsed : null;

    const { data: existing, error: exErr } = await supabaseAdmin
      .from('delivery_personnel')
      .select('id')
      .eq('user_id', request.user_id)
      .maybeSingle();
    if (exErr) throw exErr;

    let personnelOk = false;
    if (!existing) {
      const insertPayload = {
        user_id: request.user_id,
        license_number: request.plate_number,
        vehicle_plate: request.plate_number,
        vehicle_type: request.vehicle_type,
        vehicle_model: vehicleModel,
        vehicle_brand: vehicleBrand,
        vehicle_year: vehicleYear,
        vehicle_color: request.vehicle_color ?? null,
        wilaya: request.wilaya ?? null,
        delivery_name: request.full_name?.trim() || null,
        work_phone: request.phone?.trim() || null,
        is_available: true,
        is_online: true,
        rating: 5.0,
        total_deliveries: 0,
        created_at: now,
        updated_at: now,
      };
      const { data: ins, error: inErr } = await supabaseAdmin
        .from('delivery_personnel')
        .insert(insertPayload)
        .select('id');
      if (inErr) throw inErr;
      personnelOk = Boolean(ins?.length);
    } else {
      const updatePayload = {
        license_number: request.plate_number,
        vehicle_plate: request.plate_number,
        vehicle_type: request.vehicle_type,
        vehicle_model: vehicleModel,
        vehicle_brand: vehicleBrand,
        vehicle_year: vehicleYear,
        vehicle_color: request.vehicle_color ?? null,
        wilaya: request.wilaya ?? null,
        delivery_name: request.full_name?.trim() || null,
        work_phone: request.phone?.trim() || null,
        is_available: true,
        is_online: true,
        updated_at: now,
      };
      const { data: up, error: upErr } = await supabaseAdmin
        .from('delivery_personnel')
        .update(updatePayload)
        .eq('user_id', request.user_id)
        .select('id');
      if (upErr) throw upErr;
      personnelOk = Boolean(up?.length);
    }

    if (!personnelOk) {
      return res.status(500).json({ success: false, error: 'Failed to create or update delivery_personnel' });
    }

    return res.json({ success: true });
  } catch (e) {
    console.error('performance delivery approve', e);
    return res.status(500).json({ success: false, error: e.message || 'Approve failed' });
  }
});

router.post('/delivery-man-requests/:id/reject', requirePerformanceAuth, async (req, res) => {
  try {
    const id = req.params.id;
    if (!isUuid(id)) {
      return res.status(400).json({ success: false, error: 'Invalid id' });
    }
    const reason = String(req.body?.reason ?? '').trim();
    if (!reason) {
      return res.status(400).json({ success: false, error: 'Rejection reason is required' });
    }
    const { reviewedBy } = await resolvePerformanceReviewer();
    const now = new Date().toISOString();

    const { data: updatedReq, error } = await supabaseAdmin
      .from('delivery_man_requests')
      .update({
        status: 'rejected',
        rejection_reason: reason,
        reviewed_by: reviewedBy,
        reviewed_at: now,
        updated_at: now,
      })
      .eq('id', id)
      .eq('status', 'pending')
      .select('id');
    if (error) throw error;
    if (!updatedReq?.length) {
      return res.status(409).json({ success: false, error: 'Request is no longer pending or not found' });
    }

    return res.json({ success: true });
  } catch (e) {
    console.error('performance delivery reject', e);
    return res.status(500).json({ success: false, error: e.message || 'Reject failed' });
  }
});

router.post('/restaurant-requests/:id/approve', requirePerformanceAuth, async (req, res) => {
  try {
    const id = req.params.id;
    if (!isUuid(id)) {
      return res.status(400).json({ success: false, error: 'Invalid id' });
    }
    const { reviewedBy } = await resolvePerformanceReviewer();
    const now = new Date().toISOString();

    const { data: request, error: fetchErr } = await supabaseAdmin
      .from('restaurant_requests')
      .select('*')
      .eq('id', id)
      .eq('status', 'pending')
      .maybeSingle();
    if (fetchErr) throw fetchErr;
    if (!request) {
      return res.status(404).json({ success: false, error: 'Pending restaurant request not found' });
    }

    const { data: updatedReq, error: u1 } = await supabaseAdmin
      .from('restaurant_requests')
      .update({
        status: 'approved',
        reviewed_by: reviewedBy,
        reviewed_at: now,
        updated_at: now,
      })
      .eq('id', id)
      .eq('status', 'pending')
      .select('id');
    if (u1) throw u1;
    if (!updatedReq?.length) {
      return res.status(409).json({ success: false, error: 'Request is no longer pending' });
    }

    const { data: roleRows, error: u2 } = await supabaseAdmin
      .from('user_profiles')
      .update({ role: 'restaurant_owner', updated_at: now })
      .eq('id', request.user_id)
      .select('id, role');
    if (u2) throw u2;
    if (!roleRows?.length || roleRows[0].role !== 'restaurant_owner') {
      return res.status(500).json({ success: false, error: 'Failed to set user role to restaurant_owner' });
    }

    const restPayload = {
      name: request.restaurant_name,
      description: request.restaurant_description ?? null,
      phone: request.restaurant_phone,
      address: request.restaurant_address,
      latitude: request.latitude != null ? Number(request.latitude) : 0,
      longitude: request.longitude != null ? Number(request.longitude) : 0,
      image_url: request.logo_url ?? null,
      cover_image_url: request.cover_image_url ?? null,
      wilaya: request.wilaya ?? null,
      commune: request.commune ?? null,
      is_active: true,
      is_verified: true,
      owner_id: request.user_id,
      rating: 5.0,
      delivery_time: '30-45 min',
      minimum_order: 0,
      delivery_fee: 0,
      opening_hours: openingHoursPayload(request.opening_hours),
      created_at: now,
      updated_at: now,
    };

    const { data: createdRest, error: crErr } = await supabaseAdmin
      .from('restaurants')
      .insert(restPayload)
      .select('id');
    if (crErr) throw crErr;
    if (!createdRest?.length) {
      return res.status(500).json({ success: false, error: 'Failed to insert restaurant' });
    }

    return res.json({ success: true, restaurant_id: createdRest[0].id });
  } catch (e) {
    console.error('performance restaurant approve', e);
    return res.status(500).json({ success: false, error: e.message || 'Approve failed' });
  }
});

router.post('/restaurant-requests/:id/reject', requirePerformanceAuth, async (req, res) => {
  try {
    const id = req.params.id;
    if (!isUuid(id)) {
      return res.status(400).json({ success: false, error: 'Invalid id' });
    }
    const reason = String(req.body?.reason ?? '').trim();
    if (!reason) {
      return res.status(400).json({ success: false, error: 'Rejection reason is required' });
    }
    const { reviewedBy } = await resolvePerformanceReviewer();
    const now = new Date().toISOString();

    const { data: updatedReq, error } = await supabaseAdmin
      .from('restaurant_requests')
      .update({
        status: 'rejected',
        rejection_reason: reason,
        reviewed_by: reviewedBy,
        reviewed_at: now,
        updated_at: now,
      })
      .eq('id', id)
      .eq('status', 'pending')
      .select('id');
    if (error) throw error;
    if (!updatedReq?.length) {
      return res.status(409).json({ success: false, error: 'Request is no longer pending or not found' });
    }

    return res.json({ success: true });
  } catch (e) {
    console.error('performance restaurant reject', e);
    return res.status(500).json({ success: false, error: e.message || 'Reject failed' });
  }
});

router.post('/parcel-sender-requests/:id/approve', requirePerformanceAuth, async (req, res) => {
  try {
    const id = req.params.id;
    if (!isUuid(id)) return res.status(400).json({ success: false, error: 'Invalid id' });
    const { reviewedBy } = await resolvePerformanceReviewer();
    const now = new Date().toISOString();

    const { data: request, error: fErr } = await supabaseAdmin
      .from('parcel_sender_requests')
      .select('*')
      .eq('id', id)
      .eq('status', 'pending')
      .maybeSingle();
    if (fErr) throw fErr;
    if (!request) return res.status(404).json({ success: false, error: 'Pending request not found' });

    await supabaseAdmin
      .from('parcel_sender_requests')
      .update({
        status: 'approved',
        reviewed_by: reviewedBy,
        reviewed_at: now,
        updated_at: now,
      })
      .eq('id', id);

    const { data: existingSender } = await supabaseAdmin
      .from('parcel_senders')
      .select('id')
      .eq('user_id', request.user_id)
      .maybeSingle();

    if (!existingSender) {
      await supabaseAdmin.from('parcel_senders').insert({
        user_id: request.user_id,
        request_id: request.id,
        name: request.name,
        phone: request.phone,
        wilaya: request.wilaya,
        state: request.state,
        logo_url: request.logo_url,
        cover_image_url: request.cover_image_url,
        is_active: true,
        is_verified: true,
        created_at: now,
        updated_at: now,
      });
    }

    return res.json({ success: true });
  } catch (e) {
    console.error('performance parcel request approve', e);
    return res.status(500).json({ success: false, error: e.message || 'Approve failed' });
  }
});

router.post('/parcel-sender-requests/:id/reject', requirePerformanceAuth, async (req, res) => {
  try {
    const id = req.params.id;
    const reason = String(req.body?.reason || '').trim();
    if (!reason) return res.status(400).json({ success: false, error: 'Reason is required' });
    const { reviewedBy } = await resolvePerformanceReviewer();
    const now = new Date().toISOString();

    const { error } = await supabaseAdmin
      .from('parcel_sender_requests')
      .update({
        status: 'rejected',
        rejection_reason: reason,
        reviewed_by: reviewedBy,
        reviewed_at: now,
        updated_at: now,
      })
      .eq('id', id)
      .eq('status', 'pending');
    if (error) throw error;

    return res.json({ success: true });
  } catch (e) {
    console.error('performance parcel request reject', e);
    return res.status(500).json({ success: false, error: e.message || 'Reject failed' });
  }
});

/* ========================================================================= */
/* Orders & Parcel Orders                                                    */
/* ========================================================================= */

const ORDER_SELECT = `
  id,
  order_number,
  status,
  restaurant_id,
  delivery_person_id,
  customer_id,
  created_at,
  updated_at,
  courier_assigned_at,
  total_amount,
  subtotal,
  delivery_fee,
  original_delivery_fee,
  guest_phone,
  payment_method,
  payment_status,
  delivery_address,
  cancelled_at,
  cancel_reason,
  fulfillment_type,
  parcel_sender_id,
  restaurant:restaurants(id,name),
  customer:customer_id(name,phone),
  delivery_personnel(
    id,
    delivery_name,
    work_phone,
    user:user_id(name,phone)
  )
`;

const PARCEL_ORDER_SELECT = `
  id,
  order_number,
  status,
  restaurant_id,
  delivery_person_id,
  customer_id,
  created_at,
  updated_at,
  courier_assigned_at,
  total_amount,
  subtotal,
  delivery_fee,
  original_delivery_fee,
  guest_phone,
  payment_method,
  payment_status,
  delivery_address,
  cancelled_at,
  cancel_reason,
  fulfillment_type,
  parcel_sender_id,
  parcel_sender:parcel_senders(id,name,phone,wilaya),
  customer:customer_id(name,phone),
  delivery_personnel(
    id,
    delivery_name,
    work_phone,
    user:user_id(name,phone)
  )
`;

router.get('/orders', requirePerformanceAuth, async (req, res) => {
  try {
    let q = supabaseAdmin
      .from('orders')
      .select(ORDER_SELECT)
      .order('created_at', { ascending: false })
      .limit(300);

    const status = String(req.query.status || '').trim();
    const statusIn = String(req.query.status_in || '').trim();
    const restaurantId = String(req.query.restaurant_id || '').trim();
    const fromDate = String(req.query.from_date || '').trim();
    const toDate = String(req.query.to_date || '').trim();

    if (status) {
      q = q.eq('status', status);
    } else if (statusIn) {
      const statuses = statusIn.split(',').map((s) => s.trim()).filter(Boolean);
      if (statuses.length) q = q.in('status', statuses);
    }
    if (restaurantId) q = q.eq('restaurant_id', restaurantId);

    const { startIso, endIso } = parseSahlaDateRange(fromDate, toDate);
    if (startIso) q = q.gte('created_at', startIso);
    if (endIso) q = q.lte('created_at', endIso);

    // Filter out parcel orders when querying regular restaurant orders unless explicitly requested
    if (!req.query.include_parcels) {
      q = q.is('parcel_sender_id', null);
    }

    const { data, error } = await q;
    if (error) throw error;
    const enriched = (data || []).map(enrichOrderCourier);
    const orders = await attachOrderItemsSummary(enriched);
    return res.json({ success: true, orders });
  } catch (e) {
    console.error('performance /orders', e);
    return res.status(500).json({ success: false, error: e.message || 'Query failed' });
  }
});

router.get('/parcel-orders', requirePerformanceAuth, async (req, res) => {
  try {
    let q = supabaseAdmin
      .from('orders')
      .select(PARCEL_ORDER_SELECT)
      .not('parcel_sender_id', 'is', null)
      .order('created_at', { ascending: false })
      .limit(300);

    const status = String(req.query.status || '').trim();
    if (status) q = q.eq('status', status);

    const { data, error } = await q;
    if (error) throw error;
    const enriched = (data || []).map(enrichOrderCourier);
    const orders = await attachOrderItemsSummary(enriched);
    return res.json({ success: true, orders });
  } catch (e) {
    console.error('performance /parcel-orders', e);
    return res.status(500).json({ success: false, error: e.message || 'Query failed' });
  }
});

router.get('/cancelled-orders', requirePerformanceAuth, async (req, res) => {
  try {
    let q = supabaseAdmin
      .from('orders')
      .select(ORDER_SELECT)
      .eq('status', 'cancelled')
      .order('created_at', { ascending: false })
      .limit(300);

    const fromDate = String(req.query.from_date || '').trim();
    const toDate = String(req.query.to_date || '').trim();
    const { startIso, endIso } = parseSahlaDateRange(fromDate, toDate);
    if (startIso) q = q.gte('created_at', startIso);
    if (endIso) q = q.lte('created_at', endIso);

    const { data, error } = await q;
    if (error) throw error;
    const enriched = (data || []).map(enrichOrderCourier);
    const orders = await attachOrderItemsSummary(enriched);
    return res.json({ success: true, orders });
  } catch (e) {
    console.error('performance /cancelled-orders', e);
    return res.status(500).json({ success: false, error: e.message || 'Query failed' });
  }
});

/* ========================================================================= */
/* Order Actions: status, assign, unassign, cancel, collect, accept, pickup, */
/* deliver, rebroadcast                                                      */
/* ========================================================================= */

const handleOrderStatusUpdate = async (req, res) => {
  try {
    const id = req.params.id;
    const status = String(req.body?.status || '').trim();
    if (!status) return res.status(400).json({ success: false, error: 'Status is required' });

    const now = new Date().toISOString();
    const updates = { status, updated_at: now };
    if (status === 'picked_up') updates.picked_up_at = now;
    if (status === 'delivered') updates.delivered_at = now;
    if (status === 'cancelled') updates.cancelled_at = now;

    const { error } = await supabaseAdmin
      .from('orders')
      .update(updates)
      .eq('id', id);
    if (error) throw error;

    return res.json({ success: true });
  } catch (e) {
    console.error('performance order status update', e);
    return res.status(500).json({ success: false, error: e.message || 'Status update failed' });
  }
};
router.post('/orders/:id/status', requirePerformanceAuth, handleOrderStatusUpdate);
router.patch('/orders/:id/status', requirePerformanceAuth, handleOrderStatusUpdate);

router.post('/orders/:id/assign', requirePerformanceAuth, async (req, res) => {
  try {
    const id = req.params.id;
    const deliveryPersonId = String(req.body?.delivery_person_id || '').trim();
    if (!deliveryPersonId) return res.status(400).json({ success: false, error: 'delivery_person_id is required' });

    const now = new Date().toISOString();
    const { error } = await supabaseAdmin
      .from('orders')
      .update({
        delivery_person_id: deliveryPersonId,
        courier_assigned_at: now,
        updated_at: now,
      })
      .eq('id', id);
    if (error) throw error;

    return res.json({ success: true });
  } catch (e) {
    console.error('performance order assign', e);
    return res.status(500).json({ success: false, error: e.message || 'Assign failed' });
  }
});

router.post('/orders/:id/unassign', requirePerformanceAuth, async (req, res) => {
  try {
    const id = req.params.id;
    const now = new Date().toISOString();
    const { error } = await supabaseAdmin
      .from('orders')
      .update({
        delivery_person_id: null,
        courier_assigned_at: null,
        courier_unassigned_episode_at: now,
        updated_at: now,
      })
      .eq('id', id);
    if (error) throw error;

    return res.json({ success: true });
  } catch (e) {
    console.error('performance order unassign', e);
    return res.status(500).json({ success: false, error: e.message || 'Unassign failed' });
  }
});

router.post('/orders/:id/cancel', requirePerformanceAuth, async (req, res) => {
  try {
    const id = req.params.id;
    const title = String(req.body?.notification_title || '').trim();
    const bodyText = String(req.body?.notification_body || '').trim();
    const now = new Date().toISOString();

    const { data: order, error: fErr } = await supabaseAdmin
      .from('orders')
      .select('id, customer_id, order_number')
      .eq('id', id)
      .maybeSingle();
    if (fErr) throw fErr;

    const { error } = await supabaseAdmin
      .from('orders')
      .update({
        status: 'cancelled',
        cancelled_at: now,
        cancel_reason: bodyText || 'Cancelled by admin',
        updated_at: now,
      })
      .eq('id', id);
    if (error) throw error;

    if (order?.customer_id && (title || bodyText)) {
      try {
        await supabasePushGateway.sendPush({
          userIds: [order.customer_id],
          title: title || 'تم إلغاء الطلب',
          body: bodyText || `تم إلغاء طلبك #${order.order_number}`,
          data: {
            type: 'order_cancelled',
            order_id: id,
            order_number: order.order_number,
          },
        });
      } catch (pushErr) {
        console.warn('Cancel order push failed', pushErr);
      }
    }

    return res.json({ success: true });
  } catch (e) {
    console.error('performance order cancel', e);
    return res.status(500).json({ success: false, error: e.message || 'Cancel failed' });
  }
});

router.post('/orders/:id/collect', requirePerformanceAuth, async (req, res) => {
  try {
    const id = req.params.id;
    const now = new Date().toISOString();
    const { error } = await supabaseAdmin
      .from('orders')
      .update({
        payment_status: 'paid',
        collected: true,
        collected_at: now,
        updated_at: now,
      })
      .eq('id', id);
    if (error) throw error;

    return res.json({ success: true });
  } catch (e) {
    console.error('performance order collect', e);
    return res.status(500).json({ success: false, error: e.message || 'Collect failed' });
  }
});

router.post('/orders/:id/accept', requirePerformanceAuth, async (req, res) => {
  try {
    const id = req.params.id;
    const now = new Date().toISOString();
    const { error } = await supabaseAdmin
      .from('orders')
      .update({
        status: 'confirmed',
        accepted_at: now,
        updated_at: now,
      })
      .eq('id', id);
    if (error) throw error;

    return res.json({ success: true });
  } catch (e) {
    console.error('performance order accept', e);
    return res.status(500).json({ success: false, error: e.message || 'Accept failed' });
  }
});

router.post('/orders/:id/pickup', requirePerformanceAuth, async (req, res) => {
  try {
    const id = req.params.id;
    const now = new Date().toISOString();
    const { error } = await supabaseAdmin
      .from('orders')
      .update({
        status: 'picked_up',
        picked_up_at: now,
        actual_pickup_time: now,
        updated_at: now,
      })
      .eq('id', id);
    if (error) throw error;

    return res.json({ success: true });
  } catch (e) {
    console.error('performance order pickup', e);
    return res.status(500).json({ success: false, error: e.message || 'Pickup failed' });
  }
});

router.post('/orders/:id/deliver', requirePerformanceAuth, async (req, res) => {
  try {
    const id = req.params.id;
    const now = new Date().toISOString();
    const { error } = await supabaseAdmin
      .from('orders')
      .update({
        status: 'delivered',
        delivered_at: now,
        actual_delivery_time: now,
        updated_at: now,
      })
      .eq('id', id);
    if (error) throw error;

    return res.json({ success: true });
  } catch (e) {
    console.error('performance order deliver', e);
    return res.status(500).json({ success: false, error: e.message || 'Deliver failed' });
  }
});

router.post('/orders/:id/rebroadcast', requirePerformanceAuth, async (req, res) => {
  try {
    const id = req.params.id;
    const { data: order, error: fErr } = await supabaseAdmin
      .from('orders')
      .select('id, order_number, status, restaurant_id, fulfillment_type, parcel_sender_id')
      .eq('id', id)
      .maybeSingle();
    if (fErr) throw fErr;
    if (!order) return res.status(404).json({ success: false, error: 'Order not found' });

    let recipients = [];
    let kind = 'pending';
    const orderNumber = order.order_number || order.id;

    if (order.status === 'pending') {
      kind = 'restaurant_owner';
      const [restOps, adminIds] = await Promise.all([
        order.restaurant_id ? getRestaurantOpsUserIds(order.restaurant_id) : [],
        getActiveAdminUserIds(),
      ]);
      recipients = [...new Set([...restOps, ...adminIds])];
      if (recipients.length) {
        await supabasePushGateway.sendPush({
          userIds: recipients,
          title: 'طلب جديد بانتظار التأكيد',
          body: `الطلب #${orderNumber} ما زال بانتظار التأكيد.`,
          data: {
            type: 'order_pending_rebroadcast',
            order_id: id,
            order_number: orderNumber,
          },
        });
      }
    } else {
      kind = 'online_couriers';
      recipients = await getOnlineAvailableCourierUserIds();
      if (recipients.length) {
        await supabasePushGateway.sendPush({
          userIds: recipients,
          title: 'طلب متاح للتوصيل',
          body: `الطلب #${orderNumber} جاهز أو قيد التحضير وبانتظار مندوب توصيل.`,
          data: {
            type: 'courier_order_available',
            order_id: id,
            order_number: orderNumber,
          },
        });
      }
    }

    return res.json({
      success: true,
      kind,
      recipients: recipients.length,
      total_sent: recipients.length,
    });
  } catch (e) {
    console.error('performance order rebroadcast', e);
    return res.status(500).json({ success: false, error: e.message || 'Rebroadcast failed' });
  }
});

/* ========================================================================= */
/* Delivery Personnel, Pins, Notes, Mock Orders, Block/Unblock, Reminders    */
/* ========================================================================= */

router.get('/delivery-personnel', requirePerformanceAuth, async (req, res) => {
  try {
    const { data: personnelData, error: pErr } = await supabaseAdmin
      .from('delivery_personnel')
      .select(`
        id,
        user_id,
        license_number,
        vehicle_type,
        vehicle_plate,
        is_available,
        is_online,
        sahla_tax,
        total_deliveries,
        delivery_name,
        work_phone,
        created_at,
        updated_at,
        user:user_id(
          id,
          name,
          phone,
          role
        )
      `)
      .order('created_at', { ascending: false });

    if (pErr) throw pErr;

    const list = personnelData || [];
    const userIds = [...new Set(list.map((p) => p.user_id).filter(Boolean))];

    const tokensByUser = new Map();
    if (userIds.length) {
      const chunk = 200;
      for (let i = 0; i < userIds.length; i += chunk) {
        const slice = userIds.slice(i, i + chunk);
        const { data: tokens, error: tErr } = await supabaseAdmin
          .from('user_device_tokens')
          .select('user_id, platform, is_active')
          .in('user_id', slice);
        if (!tErr && tokens) {
          for (const t of tokens) {
            const uid = String(t.user_id || '').trim();
            if (!uid) continue;
            const arr = tokensByUser.get(uid) || [];
            arr.push(t);
            tokensByUser.set(uid, arr);
          }
        }
      }
    }

    const personnel = list.map((dp) => {
      const u = unwrapEmbed(dp.user);
      const uid = String(dp.user_id || '').trim();
      const userTokens = tokensByUser.get(uid) || [];
      const platforms = [...new Set(userTokens.map((t) => t.platform).filter(Boolean))];
      const isBlocked = (u && u.role !== 'delivery_man');

      return {
        id: dp.id,
        user_id: dp.user_id,
        name: dp.delivery_name || u?.name || '—',
        work_phone: dp.work_phone || u?.phone || '—',
        license_number: dp.license_number,
        vehicle_type: dp.vehicle_type,
        vehicle_plate: dp.vehicle_plate,
        is_available: dp.is_available === true,
        is_online: dp.is_online === true,
        is_blocked: isBlocked,
        sahla_tax: dp.sahla_tax ?? 0,
        delivered_orders_count: dp.total_deliveries ?? 0,
        has_device_token: userTokens.length > 0,
        device_platforms: platforms,
        device_platform: platforms[0] || null,
        created_at: dp.created_at,
        updated_at: dp.updated_at,
      };
    });

    return res.json({ success: true, personnel });
  } catch (e) {
    console.error('performance /delivery-personnel', e);
    return res.status(500).json({ success: false, error: e.message || 'Query failed' });
  }
});

const handleCourierStatus = async (req, res) => {
  try {
    const id = req.params.id;
    const { is_available, is_online } = req.body;
    const updates = { updated_at: new Date().toISOString() };
    if (typeof is_available === 'boolean') updates.is_available = is_available;
    if (typeof is_online === 'boolean') updates.is_online = is_online;

    let q = supabaseAdmin.from('delivery_personnel').update(updates);
    if (isUuid(id)) {
      q = q.or(`id.eq.${id},user_id.eq.${id}`);
    } else {
      q = q.eq('id', id);
    }
    const { error } = await q;
    if (error) throw error;
    return res.json({ success: true });
  } catch (e) {
    console.error('performance courier status', e);
    return res.status(500).json({ success: false, error: e.message || 'Update failed' });
  }
};
router.patch('/delivery-personnel/:id/status', requirePerformanceAuth, handleCourierStatus);
router.post('/delivery-personnel/:id/status', requirePerformanceAuth, handleCourierStatus);

router.post('/delivery-personnel/:id/block', requirePerformanceAuth, async (req, res) => {
  try {
    const id = req.params.id;
    const reason = String(req.body?.reason || '').trim() || null;
    const now = new Date().toISOString();

    let userId = id;
    const { data: dp } = await supabaseAdmin
      .from('delivery_personnel')
      .select('id, user_id')
      .or(`id.eq.${id},user_id.eq.${id}`)
      .maybeSingle();
    if (dp?.user_id) userId = dp.user_id;

    const { error: uErr } = await supabaseAdmin
      .from('user_profiles')
      .update({ role: 'customer', updated_at: now })
      .eq('id', userId);
    if (uErr) throw uErr;

    await supabaseAdmin
      .from('delivery_personnel')
      .update({
        is_available: false,
        is_online: false,
        wallet_blocked_reason: reason,
        updated_at: now,
      })
      .eq('user_id', userId);

    return res.json({ success: true });
  } catch (e) {
    console.error('performance courier block', e);
    return res.status(500).json({ success: false, error: e.message || 'Block failed' });
  }
});

router.post('/delivery-personnel/:id/unblock', requirePerformanceAuth, async (req, res) => {
  try {
    const id = req.params.id;
    const now = new Date().toISOString();

    let userId = id;
    const { data: dp } = await supabaseAdmin
      .from('delivery_personnel')
      .select('id, user_id')
      .or(`id.eq.${id},user_id.eq.${id}`)
      .maybeSingle();
    if (dp?.user_id) userId = dp.user_id;

    const { error: uErr } = await supabaseAdmin
      .from('user_profiles')
      .update({ role: 'delivery_man', updated_at: now })
      .eq('id', userId);
    if (uErr) throw uErr;

    await supabaseAdmin
      .from('delivery_personnel')
      .update({
        wallet_blocked_reason: null,
        updated_at: now,
      })
      .eq('user_id', userId);

    return res.json({ success: true });
  } catch (e) {
    console.error('performance courier unblock', e);
    return res.status(500).json({ success: false, error: e.message || 'Unblock failed' });
  }
});

router.post('/delivery-personnel/:id/mock-order', requirePerformanceAuth, async (req, res) => {
  try {
    const id = req.params.id;
    let userId = id;
    const { data: dp } = await supabaseAdmin
      .from('delivery_personnel')
      .select('id, user_id, delivery_name')
      .or(`id.eq.${id},user_id.eq.${id}`)
      .maybeSingle();
    if (dp?.user_id) userId = dp.user_id;

    const { data: rest } = await supabaseAdmin
      .from('restaurants')
      .select('id, name')
      .limit(1)
      .maybeSingle();

    const orderNumber = 'MOCK-' + Math.floor(100000 + Math.random() * 900000);
    const now = new Date().toISOString();

    const { data: order, error: oErr } = await supabaseAdmin
      .from('orders')
      .insert({
        order_number: orderNumber,
        status: 'preparing',
        restaurant_id: rest?.id || null,
        customer_id: userId,
        delivery_person_id: null,
        total_amount: 500,
        subtotal: 500,
        delivery_fee: 150,
        original_delivery_fee: 150,
        payment_method: 'cash_on_delivery',
        payment_status: 'pending',
        delivery_address: { address: 'Mock delivery address for testing' },
        preparing_started_at: now,
        created_at: now,
        updated_at: now,
      })
      .select()
      .single();
    if (oErr) throw oErr;

    let pushResult = { success: false, total_sent: 0 };
    try {
      pushResult = await supabasePushGateway.sendPush({
        userIds: [userId],
        title: 'طلب جديد متاح للتوصيل (اختباري)',
        body: `طلب اختباري #${orderNumber} جاهز للقبول في قائمة الطلبات المتاحة.`,
        data: {
          type: 'new_order_available',
          order_id: order.id,
          order_number: orderNumber,
          source: 'performance_mock_order',
        },
      });
    } catch (pushErr) {
      console.warn('Mock order push failed', pushErr);
    }

    const sent = pushResult.total_sent || (pushResult.success ? 1 : 0);
    return res.json({
      success: true,
      order,
      broadcast: {
        ok: pushResult.success || sent > 0,
        total_sent: sent,
      },
    });
  } catch (e) {
    console.error('performance mock-order', e);
    return res.status(500).json({ success: false, error: e.message || 'Mock order failed' });
  }
});

router.post('/delivery-personnel/non-available-reminder', requirePerformanceAuth, async (req, res) => {
  try {
    const title = String(req.body?.title || '').trim();
    const bodyText = String(req.body?.body || '').trim();
    if (!title || !bodyText) {
      return res.status(400).json({ success: false, error: 'Title and body are required' });
    }

    const { data: personnel, error } = await supabaseAdmin
      .from('delivery_personnel')
      .select('user_id, is_available, is_online, user:user_id(role)')
      .or('is_available.eq.false,is_available.is.null');

    if (error) throw error;

    const userIds = [
      ...new Set(
        (personnel || [])
          .filter((p) => {
            const u = unwrapEmbed(p.user);
            return u?.role === 'delivery_man';
          })
          .map((p) => String(p.user_id || '').trim())
          .filter(Boolean),
      ),
    ];

    if (!userIds.length) {
      return res.json({ success: true, skipped: true, target_count: 0, total_sent: 0 });
    }

    const pushResult = await supabasePushGateway.sendPush({
      userIds,
      title,
      body: bodyText,
      data: {
        type: 'availability_reminder',
        source: 'performance_dashboard',
      },
    });

    const sent = pushResult.total_sent || (pushResult.success ? userIds.length : 0);
    return res.json({
      success: true,
      skipped: false,
      target_count: userIds.length,
      total_sent: sent,
      result: pushResult,
    });
  } catch (e) {
    console.error('performance non-available-reminder', e);
    return res.status(500).json({ success: false, error: e.message || 'Reminder failed' });
  }
});

router.get('/pinned-delivery-men', requirePerformanceAuth, async (req, res) => {
  try {
    const { data, error } = await supabaseAdmin
      .from('system_config')
      .select('config_value')
      .eq('config_key', 'performance_dashboard_pinned_delivery_user_ids')
      .maybeSingle();
    if (error) throw error;
    let userIds = [];
    if (data?.config_value) {
      userIds = Array.isArray(data.config_value) ? data.config_value : JSON.parse(data.config_value);
    }
    return res.json({ success: true, user_ids: userIds });
  } catch (e) {
    console.error('performance /pinned-delivery-men GET', e);
    return res.status(500).json({ success: false, error: e.message || 'Fetch failed' });
  }
});

router.put('/pinned-delivery-men', requirePerformanceAuth, async (req, res) => {
  try {
    const userIds = Array.isArray(req.body?.user_ids) ? req.body.user_ids.map(String) : [];
    const { error } = await supabaseAdmin
      .from('system_config')
      .upsert({
        config_key: 'performance_dashboard_pinned_delivery_user_ids',
        config_value: userIds,
        config_type: 'array',
        category: 'performance_dashboard',
        is_active: true,
        description: 'Pinned delivery couriers (user_id) for performance dashboard delivery-man tab sort order',
        updated_at: new Date().toISOString(),
      }, { onConflict: 'config_key' });
    if (error) throw error;
    return res.json({ success: true, user_ids: userIds });
  } catch (e) {
    console.error('performance /pinned-delivery-men PUT', e);
    return res.status(500).json({ success: false, error: e.message || 'Save failed' });
  }
});

router.get('/delivery-personnel-notes', requirePerformanceAuth, async (req, res) => {
  try {
    const { data, error } = await supabaseAdmin
      .from('system_config')
      .select('config_value')
      .eq('config_key', 'performance_dashboard_delivery_man_notes')
      .maybeSingle();
    if (error) throw error;
    let notes = {};
    if (data?.config_value) {
      notes = typeof data.config_value === 'object' && !Array.isArray(data.config_value)
        ? data.config_value
        : JSON.parse(data.config_value || '{}');
    }
    return res.json({ success: true, notes });
  } catch (e) {
    console.error('performance /delivery-personnel-notes GET', e);
    return res.status(500).json({ success: false, error: e.message || 'Fetch failed' });
  }
});

router.put('/delivery-personnel-notes', requirePerformanceAuth, async (req, res) => {
  try {
    const userId = String(req.body?.user_id || '').trim();
    const note = String(req.body?.note || '').trim().slice(0, 2000);
    if (!userId) return res.status(400).json({ success: false, error: 'user_id is required' });

    const { data: existing } = await supabaseAdmin
      .from('system_config')
      .select('config_value')
      .eq('config_key', 'performance_dashboard_delivery_man_notes')
      .maybeSingle();

    let current = {};
    if (existing?.config_value) {
      current = typeof existing.config_value === 'object' && !Array.isArray(existing.config_value)
        ? { ...existing.config_value }
        : JSON.parse(existing.config_value || '{}');
    }

    if (note) current[userId] = note;
    else delete current[userId];

    const { error } = await supabaseAdmin
      .from('system_config')
      .upsert({
        config_key: 'performance_dashboard_delivery_man_notes',
        config_value: current,
        config_type: 'object',
        category: 'performance_dashboard',
        is_active: true,
        description: 'Admin notes keyed by delivery courier user_id for performance dashboard Delivery man tab',
        updated_at: new Date().toISOString(),
      }, { onConflict: 'config_key' });
    if (error) throw error;

    return res.json({ success: true, user_id: userId, note, notes: current });
  } catch (e) {
    console.error('performance /delivery-personnel-notes PUT', e);
    return res.status(500).json({ success: false, error: e.message || 'Save failed' });
  }
});

router.post('/force-push-notification', requirePerformanceAuth, async (req, res) => {
  try {
    const {
      send_all_devices,
      user_id,
      device_token,
      title,
      body,
      force_activate_inactive_tokens,
      schedule_send,
      scheduled_for,
      use_campaign,
    } = req.body;

    if (!title || !body) {
      return res.status(400).json({ success: false, error: 'title and body are required' });
    }

    const isCampaign = Boolean(send_all_devices || schedule_send || scheduled_for || use_campaign);

    // Marketing campaigns, scheduled sends, and broadcasts MUST use schedule-push-campaign
    // to protect the database from bulk push load spikes and to guarantee scheduled delivery.
    if (isCampaign) {
      const campaignBody = {
        title: String(title).trim(),
        body: String(body).trim(),
        send_all_devices: Boolean(send_all_devices),
        user_id: user_id ? String(user_id).trim() : undefined,
        device_token: device_token ? String(device_token).trim() : undefined,
        force_activate_inactive_tokens: Boolean(force_activate_inactive_tokens),
        scheduled_for: scheduled_for ? String(scheduled_for).trim() : undefined,
        enqueue_now: !schedule_send,
        data: {
          source: 'performance_dashboard_forced_push',
          type: 'promotion',
          timestamp: new Date().toISOString(),
        },
      };

      const invokeRes = await supabaseAdmin.functions.invoke('schedule-push-campaign', {
        body: campaignBody,
      });

      if (invokeRes.error) {
        let errorDetail = invokeRes.error.message || 'Push schedule failed';
        if (invokeRes.error.context && typeof invokeRes.error.context.text === 'function') {
          try {
            const txt = await invokeRes.error.context.text();
            const parsed = JSON.parse(txt);
            errorDetail = parsed.error || parsed.message || txt;
          } catch (_) {}
        }
        return res.status(500).json({ success: false, error: errorDetail });
      }

      const payload = invokeRes.data || {};
      return res.json({
        success: payload.success !== false,
        campaign_id: payload.campaign_id,
        scheduled_for: payload.scheduled_for,
        delivery_mode: payload.delivery_mode,
        status: payload.status,
        warning: payload.warning,
        total_users: payload.total_users ?? payload.recipients?.users ?? 0,
        summary: {
          total_sent: 0,
          total_failed: 0,
          target_users: payload.total_users ?? payload.recipients?.users ?? 0,
        },
        message: payload.message,
      });
    }

    // Direct targeted push for a single user/device token
    if (device_token) {
      let targetUserId = user_id;
      if (!targetUserId) {
        const { data: tokRow } = await supabaseAdmin
          .from('user_device_tokens')
          .select('user_id')
          .eq('token', String(device_token).trim())
          .maybeSingle();
        targetUserId = tokRow?.user_id;
      }
      if (!targetUserId) {
        return res.status(404).json({ success: false, error: 'Device token not found in database' });
      }
      const sent = await supabasePushGateway.sendPush({
        userIds: [targetUserId],
        title,
        body,
        data: { source: 'force_push_admin' },
      });
      return res.json({
        success: sent.success,
        total_sent: sent.total_sent ?? (sent.success ? 1 : 0),
        summary: { total_sent: sent.total_sent ?? (sent.success ? 1 : 0), total_failed: sent.success ? 0 : 1 },
      });
    }

    if (user_id) {
      const sent = await supabasePushGateway.sendPush({
        userIds: [String(user_id).trim()],
        title,
        body,
        data: { source: 'force_push_admin' },
      });
      return res.json({
        success: sent.success,
        total_sent: sent.total_sent ?? (sent.success ? 1 : 0),
        summary: { total_sent: sent.total_sent ?? (sent.success ? 1 : 0), total_failed: sent.success ? 0 : 1 },
      });
    }

    return res.status(400).json({ success: false, error: 'user_id, device_token, or send_all_devices is required' });
  } catch (e) {
    console.error('performance /force-push-notification', e);
    let errorMsg = e.message || 'Push failed';
    if (e.context && typeof e.context.text === 'function') {
      try {
        const txt = await e.context.text();
        const parsed = JSON.parse(txt);
        errorMsg = parsed.error || parsed.message || txt;
      } catch (_) {}
    }
    return res.status(500).json({ success: false, error: errorMsg });
  }
});

/* ========================================================================= */
/* Restaurant Tables Configuration                                           */
/* ========================================================================= */

router.get('/restaurants/table-ordering-eligible', requirePerformanceAuth, async (req, res) => {
  try {
    const { data, error } = await supabaseAdmin
      .from('restaurants')
      .select('id, name, wilaya, is_public_web_enabled, table_ordering_enabled, is_verified')
      .eq('is_verified', true)
      .order('name');
    if (error) throw error;
    return res.json({ success: true, restaurants: data || [] });
  } catch (e) {
    console.error('performance table-ordering-eligible', e);
    return res.status(500).json({ success: false, error: e.message || 'Query failed' });
  }
});

router.get('/restaurants/:id/tables', requirePerformanceAuth, async (req, res) => {
  try {
    const id = req.params.id;
    const [restRes, tablesRes] = await Promise.all([
      supabaseAdmin
        .from('restaurants')
        .select('id, name, table_portal_code, table_portal_secret_hash, table_ordering_enabled, public_slug')
        .eq('id', id)
        .maybeSingle(),
      supabaseAdmin
        .from('restaurant_tables')
        .select('*')
        .eq('restaurant_id', id)
        .order('table_number'),
    ]);
    if (restRes.error) throw restRes.error;
    if (tablesRes.error) throw tablesRes.error;

    const r = restRes.data;
    const code = r?.table_portal_code || '';
    const portalUrl = code ? `https://sahla-delivery.com/t/${code}` : '';

    return res.json({
      success: true,
      tables: tablesRes.data || [],
      portal_code: code,
      portal_url: portalUrl,
      portal_password_configured: Boolean(r?.table_portal_secret_hash),
    });
  } catch (e) {
    console.error('performance restaurant tables', e);
    return res.status(500).json({ success: false, error: e.message || 'Query failed' });
  }
});

router.patch('/restaurants/:id/table-ordering', requirePerformanceAuth, async (req, res) => {
  try {
    const id = req.params.id;
    const enabled = Boolean(req.body?.table_ordering_enabled);
    const { error } = await supabaseAdmin
      .from('restaurants')
      .update({ table_ordering_enabled: enabled, updated_at: new Date().toISOString() })
      .eq('id', id);
    if (error) throw error;
    return res.json({ success: true, table_ordering_enabled: enabled });
  } catch (e) {
    console.error('performance restaurant table-ordering update', e);
    return res.status(500).json({ success: false, error: e.message || 'Update failed' });
  }
});

router.post('/restaurants/:id/table-portal-password', requirePerformanceAuth, async (req, res) => {
  try {
    const id = req.params.id;
    const password = String(req.body?.password || '').trim();
    if (!password) return res.status(400).json({ success: false, error: 'Password is required' });

    const hash = crypto.createHash('sha256').update(password, 'utf8').digest('hex');
    const { error } = await supabaseAdmin
      .from('restaurants')
      .update({ table_portal_secret_hash: `\\x${hash}`, updated_at: new Date().toISOString() })
      .eq('id', id);
    if (error) throw error;
    return res.json({ success: true });
  } catch (e) {
    console.error('performance table portal password', e);
    return res.status(500).json({ success: false, error: e.message || 'Password update failed' });
  }
});

router.post('/restaurants/:id/regenerate-table-portal-code', requirePerformanceAuth, async (req, res) => {
  try {
    const id = req.params.id;
    const { data: rest, error: fErr } = await supabaseAdmin
      .from('restaurants')
      .select('id, name, public_slug')
      .eq('id', id)
      .maybeSingle();
    if (fErr) throw fErr;

    const base = rest?.public_slug || rest?.name?.toLowerCase().replace(/[^a-z0-9]+/g, '-') || 'portal';
    const rand = crypto.randomBytes(3).toString('hex');
    const newCode = `${base}-${rand}`;

    const { error } = await supabaseAdmin
      .from('restaurants')
      .update({ table_portal_code: newCode, updated_at: new Date().toISOString() })
      .eq('id', id);
    if (error) throw error;

    return res.json({ success: true, portal_code: newCode, portal_url: `https://sahla-delivery.com/t/${newCode}` });
  } catch (e) {
    console.error('performance regenerate portal code', e);
    return res.status(500).json({ success: false, error: e.message || 'Regeneration failed' });
  }
});

router.post('/restaurants/:id/tables', requirePerformanceAuth, async (req, res) => {
  try {
    const restaurantId = req.params.id;
    const tableNumber = parseInt(req.body?.table_number, 10);
    const tableLabel = String(req.body?.table_label || '').trim() || null;
    if (!Number.isFinite(tableNumber) || tableNumber <= 0) {
      return res.status(400).json({ success: false, error: 'Valid table number is required' });
    }

    const { data, error } = await supabaseAdmin
      .from('restaurant_tables')
      .insert({
        restaurant_id: restaurantId,
        table_number: tableNumber,
        table_label: tableLabel,
        is_active: true,
        created_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .select()
      .single();
    if (error) throw error;

    return res.json({ success: true, table: data });
  } catch (e) {
    console.error('performance create table', e);
    return res.status(500).json({ success: false, error: e.message || 'Table creation failed' });
  }
});

router.post('/tables/:id/regenerate-code', requirePerformanceAuth, async (req, res) => {
  try {
    const id = req.params.id;
    const token = crypto.randomBytes(16).toString('hex');
    const qrUrl = `https://sahla-delivery.com/table?t=${token}`;

    const { error } = await supabaseAdmin
      .from('restaurant_tables')
      .update({ token, qr_url: qrUrl, updated_at: new Date().toISOString() })
      .eq('id', id);
    if (error) throw error;

    return res.json({ success: true, qr_url: qrUrl, token });
  } catch (e) {
    console.error('performance table regenerate code', e);
    return res.status(500).json({ success: false, error: e.message || 'Regenerate failed' });
  }
});

router.post('/tables/:id/revoke-sessions', requirePerformanceAuth, async (req, res) => {
  try {
    const id = req.params.id;
    const { error } = await supabaseAdmin
      .from('table_sessions')
      .update({ is_active: false, closed_at: new Date().toISOString() })
      .eq('table_id', id)
      .eq('is_active', true);
    if (error) throw error;

    return res.json({ success: true });
  } catch (e) {
    console.error('performance table revoke sessions', e);
    return res.status(500).json({ success: false, error: e.message || 'Revoke failed' });
  }
});

/* ========================================================================= */
/* Alerts                                                                    */
/* ========================================================================= */

router.get('/alerts', requirePerformanceAuth, async (req, res) => {
  try {
    const minutes = alertThresholdMinutes();

    const [cDm, cR, cPs, newReviewsGlobal, newReviewsDelivery] = await Promise.all([
      supabaseAdmin
        .from('delivery_man_requests')
        .select('id', { count: 'exact', head: true })
        .eq('status', 'pending'),
      supabaseAdmin
        .from('restaurant_requests')
        .select('id', { count: 'exact', head: true })
        .eq('status', 'pending'),
      supabaseAdmin
        .from('parcel_sender_requests')
        .select('id', { count: 'exact', head: true })
        .eq('status', 'pending'),
      countNewRestaurantReviewsInWindow(null),
      countNewDeliveryReviewsInWindow(null),
    ]);
    if (cDm.error) throw cDm.error;
    if (cR.error) throw cR.error;
    if (cPs.error) throw cPs.error;

    const { data: staleOrders, error: e1 } = await supabaseAdmin
      .from('orders')
      .select(ORDER_SELECT)
      .eq('status', 'pending')
      .is('parcel_sender_id', null)
      .order('created_at', { ascending: true })
      .limit(500);
    if (e1) throw e1;

    const { data: waitingParcels, error: wpErr } = await supabaseAdmin
      .from('orders')
      .select(PARCEL_ORDER_SELECT)
      .not('parcel_sender_id', 'is', null)
      .eq('status', 'pending')
      .order('created_at', { ascending: true })
      .limit(300);
    if (wpErr) throw wpErr;

    const openOfferStatuses = ['pending', 'cost_review', 'cost_proposed'];
    const { data: openTasks, error: e2 } = await supabaseAdmin
      .from('tasks')
      .select(
        `
        id,
        status,
        delivery_man_id,
        description,
        location_name,
        assigned_at,
        created_at,
        updated_at
      `,
      )
      .in('status', openOfferStatuses)
      .order('created_at', { ascending: true })
      .limit(700);
    if (e2) throw e2;

    const taskRows = openTasks || [];
    const taskIds = taskRows.map((t) => t.id).filter(Boolean);
    const withProposal = new Set();
    const chunk = 120;
    for (let i = 0; i < taskIds.length; i += chunk) {
      const slice = taskIds.slice(i, i + chunk);
      if (!slice.length) break;
      const { data: propRows, error: e3 } = await supabaseAdmin
        .from('task_cost_proposals')
        .select('task_id')
        .in('task_id', slice);
      if (e3) throw e3;
      for (const row of propRows || []) {
        if (row.task_id) withProposal.add(row.task_id);
      }
    }

    const tasksFiltered = taskRows.filter((t) => !withProposal.has(t.id));
    const tasksWithoutOffers = (await enrichTasksWithCourierDetails(tasksFiltered)).map((t) => ({
      ...t,
      ageMinutes: ageMinutes(t.created_at),
    }))
      .filter((t) => t.ageMinutes != null && t.ageMinutes >= minutes);

    const stalePendingOrders = (staleOrders || []).map((o) => ({
      ...enrichOrderCourier(o),
      ageMinutes: ageMinutes(o.created_at),
    }))
      .filter((o) => o.ageMinutes != null && o.ageMinutes >= minutes);

    const parcelWaitingOrders = (waitingParcels || []).map((o) => ({
      ...enrichOrderCourier(o),
      ageMinutes: ageMinutes(o.created_at),
    }))
      .filter((o) => o.ageMinutes != null && o.ageMinutes >= minutes);

    const pickupDelayMin = Number(process.env.PERFORMANCE_PICKED_UP_DELAY_MINUTES) || 15;
    const { data: delayedPickedUpOrders, error: dpErr } = await supabaseAdmin
      .from('orders')
      .select(ORDER_SELECT)
      .eq('status', 'picked_up')
      .order('updated_at', { ascending: true })
      .limit(300);
    if (dpErr) throw dpErr;

    const pickedUpDeliveryDelayed = (delayedPickedUpOrders || []).map((o) => ({
      ...enrichOrderCourier(o),
      ageMinutes: ageMinutes(o.picked_up_at || o.updated_at),
    })).filter((o) => o.ageMinutes != null && o.ageMinutes >= pickupDelayMin);

    const dashboardPollMs = Number(process.env.PERFORMANCE_OPEN_DASHBOARD_POLL_MS || 0);
    if (Number.isFinite(dashboardPollMs) && dashboardPollMs >= 30_000) {
      const now = Date.now();
      if (now - _lastDashboardEscalationPollMs >= dashboardPollMs) {
        _lastDashboardEscalationPollMs = now;
        setImmediate(async () => {
          try {
            const pending = await runPendingOrdersPollOnce({ logger: console });
            const pickup = await runPickupDelayAdminAlertsOnce({ logger: console });
            console.info?.('[performance/alerts] background escalation poll', { pending, pickup });
          } catch (err) {
            console.error('[performance/alerts] background escalation poll failed', err);
          }
        });
      }
    }

    return res.json({
      success: true,
      thresholdMinutes: minutes,
      stalePendingOrders,
      tasksWithoutOffers,
      parcelWaitingOrders,
      parcel_waiting_minutes: minutes,
      pickedUpDeliveryDelayed,
      picked_up_delay_minutes: pickupDelayMin,
      pending_delivery_man_requests: cDm.count ?? 0,
      pending_restaurant_requests: cR.count ?? 0,
      pending_parcel_sender_requests: cPs.count ?? 0,
      new_restaurant_reviews_in_window: newReviewsGlobal,
      new_restaurant_reviews_hours: newReviewThresholdHours(),
      new_delivery_reviews_in_window: newReviewsDelivery,
    });
  } catch (e) {
    console.error('performance /alerts', e);
    return res.status(500).json({ success: false, error: e.message || 'Query failed' });
  }
});

/* ========================================================================= */
/* Reviews: Restaurant & Delivery                                            */
/* ========================================================================= */

router.get('/reviews', requirePerformanceAuth, async (req, res) => {
  try {
    const restaurantId = String(req.query.restaurant_id || '').trim();
    const limitRaw = Number(req.query.limit);
    const limit = Number.isFinite(limitRaw) && limitRaw > 0 ? Math.min(limitRaw, 500) : 300;

    let q = supabaseAdmin
      .from('restaurant_reviews')
      .select(
        `
        id,
        restaurant_id,
        customer_id,
        order_id,
        rating,
        comment,
        created_at,
        updated_at,
        restaurant:restaurants(id,name),
        user_profiles:customer_id(name)
      `,
      )
      .order('created_at', { ascending: false })
      .limit(limit);
    if (restaurantId) q = q.eq('restaurant_id', restaurantId);
    const { data, error } = await q;
    if (error) throw error;

    const newInWindow = await countNewRestaurantReviewsInWindow(restaurantId || null);

    return res.json({
      success: true,
      reviews: data || [],
      new_reviews_in_window: newInWindow,
      new_reviews_hours: newReviewThresholdHours(),
    });
  } catch (e) {
    console.error('performance /reviews', e);
    return res.status(500).json({ success: false, error: e.message || 'Query failed' });
  }
});

router.get('/delivery-reviews', requirePerformanceAuth, async (req, res) => {
  try {
    const deliveryPersonId = String(req.query.delivery_person_id || '').trim();
    const limitRaw = Number(req.query.limit);
    const limit = Number.isFinite(limitRaw) && limitRaw > 0 ? Math.min(limitRaw, 500) : 300;

    let q = supabaseAdmin
      .from('delivery_reviews')
      .select(
        `
        id,
        delivery_person_id,
        customer_id,
        order_id,
        rating,
        comment,
        created_at,
        updated_at,
        delivery_personnel(
          id,
          delivery_name,
          work_phone,
          user:user_id(name,phone)
        ),
        user_profiles:customer_id(name),
        order:orders(id,order_number)
      `,
      )
      .order('created_at', { ascending: false })
      .limit(limit);

    if (deliveryPersonId) q = q.eq('delivery_person_id', deliveryPersonId);
    const { data, error } = await q;
    if (error) throw error;

    const newInWindow = await countNewDeliveryReviewsInWindow(deliveryPersonId || null);

    return res.json({
      success: true,
      reviews: data || [],
      new_reviews_in_window: newInWindow,
      new_reviews_hours: newReviewThresholdHours(),
    });
  } catch (e) {
    console.error('performance /delivery-reviews', e);
    return res.status(500).json({ success: false, error: e.message || 'Query failed' });
  }
});

/* ========================================================================= */
/* Tasks                                                                     */
/* ========================================================================= */

router.get('/tasks', requirePerformanceAuth, async (req, res) => {
  try {
    let q = supabaseAdmin
      .from('tasks')
      .select(
        `
        id,
        status,
        delivery_man_id,
        description,
        location_name,
        assigned_at,
        created_at,
        updated_at
      `,
      )
      .order('created_at', { ascending: false })
      .limit(300);

    const status = String(req.query.status || '').trim();
    const deliveryManId = String(req.query.delivery_man_id || '').trim();
    if (status) q = q.eq('status', status);
    if (deliveryManId) q = q.eq('delivery_man_id', deliveryManId);

    const { data, error } = await q;
    if (error) throw error;
    const tasks = await enrichTasksWithCourierDetails(data || []);
    return res.json({ success: true, tasks });
  } catch (e) {
    console.error('performance /tasks', e);
    return res.status(500).json({ success: false, error: e.message || 'Query failed' });
  }
});

export default router;
