import crypto from 'node:crypto';
import { Router } from 'express';

import { supabaseAdmin } from '../config/supabase.js';
import { runPendingOrdersPollOnce } from '../services/pendingOrdersPoller.js';
import { runPickupDelayAdminAlertsOnce } from '../services/pickupDelayAdminAlertsPoller.js';
import { runPreparingUnassignedRebroadcastOnce } from '../services/preparingUnassignedRebroadcastPoller.js';
import { runPreparingAssignedDelayAdminAlertsOnce } from '../services/preparingAssignedDelayAdminAlertsPoller.js';
import { supabasePushGateway } from '../modules/notifications/supabasePushGateway.js';
import {
  getRestaurantOpsUserIds,
  getOnlineAvailableCourierUserIds,
} from '../modules/notifications/orderRebroadcastRecipients.js';
import { getActiveAdminUserIds } from '../services/adminRecipients.js';
import {
  getWorkingHoursConfig,
  saveWorkingHoursConfig,
  getAutoClosedCourierIds,
  updateCourierSchedule,
  syncWorkingHours,
  sendMorningGreetingToAvailableCouriers,
  getAlgiersTime,
  parseTimeToMinutes,
  isTimeInInterval,
} from '../services/deliveryWorkingHoursService.js';

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
      const name = String(menu?.name || menu?.name_ar || it?.name || '').trim();
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
        .select('order_id, quantity, special_instructions, menu_item:menu_items(name, name_ar)')
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

async function attachOrderCancellationRoles(orders) {
  const list = Array.isArray(orders) ? orders : [];
  const ids = [...new Set(list.map((o) => String(o?.id || '').trim()).filter(Boolean))];
  if (!ids.length) return list;

  const roleByOrder = new Map();
  const chunk = 100;
  for (let i = 0; i < ids.length; i += chunk) {
    const slice = ids.slice(i, i + chunk);
    try {
      const { data, error } = await supabaseAdmin
        .from('order_events')
        .select('order_id, changed_by_role, created_at')
        .in('order_id', slice)
        .eq('new_status', 'cancelled')
        .order('created_at', { ascending: false });
      if (!error && data) {
        for (const ev of data) {
          const oid = String(ev.order_id || '').trim();
          if (oid && !roleByOrder.has(oid)) {
            roleByOrder.set(oid, ev.changed_by_role);
          }
        }
      }
    } catch (roleErr) {
      console.warn('attachOrderCancellationRoles failed chunk', roleErr);
    }
  }

  return list.map((o) => {
    const oid = String(o?.id || '').trim();
    return {
      ...o,
      cancelled_by_role: roleByOrder.get(oid) || null,
    };
  });
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
      supabaseAdmin.from('delivery_personnel').select('id,user_id,delivery_name,work_phone,is_available,is_online'),
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

    const allDeliveryPersonnel = personnel.map((dp) => {
      const prof = couriers.find((c) => c.id === dp.user_id);
      const isOnline = dp.is_online === true;
      const isAvailable = dp.is_available === true || String(dp.is_available).toLowerCase() === 'true';
      const statusBadge = isOnline && isAvailable ? ' (متاح)' : (!isOnline ? ' (غير متصل)' : ' (مشغول)');
      const baseName = dp.delivery_name || prof?.name || dp.id;
      return {
        id: dp.id,
        user_id: dp.user_id,
        name: `${baseName}${statusBadge}`,
        raw_name: baseName,
        phone: dp.work_phone || prof?.phone || null,
        is_available: isAvailable,
        is_online: isOnline,
      };
    });

    const sortedCouriers = [...allDeliveryPersonnel].sort((a, b) => {
      const aScore = (a.is_online ? 2 : 0) + (a.is_available ? 1 : 0);
      const bScore = (b.is_online ? 2 : 0) + (b.is_available ? 1 : 0);
      if (aScore !== bScore) return bScore - aScore;
      return (a.raw_name || '').localeCompare(b.raw_name || '');
    });

    return res.json({
      success: true,
      restaurants,
      couriers,
      delivery_personnel_options: allDeliveryPersonnel,
      available_order_couriers: sortedCouriers,
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
      .select('id, current_latitude, current_longitude')
      .eq('user_id', request.user_id)
      .maybeSingle();
    if (exErr) throw exErr;

    const biskraCoords = (() => {
      const minLat = 34.8380;
      const maxLat = 34.8680;
      const minLng = 5.7000;
      const maxLng = 5.7420;
      return {
        lat: Number((minLat + Math.random() * (maxLat - minLat)).toFixed(7)),
        lng: Number((minLng + Math.random() * (maxLng - minLng)).toFixed(7)),
      };
    })();

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
        wilaya: request.wilaya || 'Biskra',
        province: 'Biskra',
        current_latitude: biskraCoords.lat,
        current_longitude: biskraCoords.lng,
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
        wilaya: request.wilaya || 'Biskra',
        province: 'Biskra',
        delivery_name: request.full_name?.trim() || null,
        work_phone: request.phone?.trim() || null,
        is_available: true,
        is_online: true,
        updated_at: now,
      };
      if (!existing.current_latitude || !existing.current_longitude) {
        updatePayload.current_latitude = biskraCoords.lat;
        updatePayload.current_longitude = biskraCoords.lng;
      }
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
    const withItems = await attachOrderItemsSummary(enriched);
    const orders = await attachOrderCancellationRoles(withItems);
    return res.json({ success: true, orders });
  } catch (e) {
    console.error('performance /cancelled-orders', e);
    return res.status(500).json({ success: false, error: e.message || 'Query failed' });
  }
});

router.get('/orders/:id', requirePerformanceAuth, async (req, res) => {
  try {
    const id = req.params.id;
    const { data: order, error } = await supabaseAdmin
      .from('orders')
      .select(`
        *,
        restaurant:restaurants(id, name, phone, city, address_line1, logo_url),
        customer:customer_id(id, name, phone),
        delivery_personnel(
          id,
          delivery_name,
          work_phone,
          vehicle_type,
          vehicle_plate,
          vehicle_model,
          vehicle_color,
          user:user_id(id, name, phone)
        )
      `)
      .eq('id', id)
      .maybeSingle();

    if (error) throw error;
    if (!order) return res.status(404).json({ success: false, error: 'Order not found' });

    const enriched = enrichOrderCourier(order);

    const { data: items, error: itemsErr } = await supabaseAdmin
      .from('order_items')
      .select(`
        id,
        order_id,
        menu_item_id,
        quantity,
        unit_price,
        total_price,
        price,
        special_instructions,
        customizations,
        tax_free,
        created_at,
        menu_item:menu_items(id, name, name_ar, name_latin, image, category)
      `)
      .eq('order_id', id)
      .order('created_at', { ascending: true });

    if (itemsErr) console.warn('Order items error:', itemsErr);

    const { data: events, error: eventsErr } = await supabaseAdmin
      .from('order_events')
      .select('*')
      .eq('order_id', id)
      .order('created_at', { ascending: true });

    if (eventsErr) console.warn('Order events error:', eventsErr);

    return res.json({
      success: true,
      order: {
        ...enriched,
        items: items || [],
        events: events || [],
      },
    });
  } catch (e) {
    console.error('performance /orders/:id', e);
    return res.status(500).json({ success: false, error: e.message || 'Fetch order details failed' });
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

    const { data: updatedOrder, error } = await supabaseAdmin
      .from('orders')
      .update(updates)
      .eq('id', id)
      .select('id, order_number, status, delivery_person_id, fulfillment_type')
      .maybeSingle();
    if (error) throw error;

    if (
      ['preparing', 'ready'].includes(status) &&
      !updatedOrder?.delivery_person_id &&
      String(updatedOrder?.fulfillment_type || 'delivery').toLowerCase() === 'delivery'
    ) {
      getOnlineAvailableCourierUserIds()
        .then(async (recipients) => {
          if (recipients.length > 0) {
            const orderNum = updatedOrder.order_number || updatedOrder.id;
            await supabasePushGateway.sendPush({
              userIds: recipients,
              title: 'طلب متاح للتوصيل',
              body: `الطلب #${orderNum} جاهز أو قيد التحضير وبانتظار مندوب توصيل.`,
              data: {
                type: 'courier_order_available',
                order_id: id,
                order_number: orderNum,
              },
            });
          }
        })
        .catch((e) => console.warn('Couriers broadcast on status change error:', e?.message));
    }

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

    // Immediately trigger autonomous rebroadcast to all online couriers
    setImmediate(async () => {
      try {
        await runPreparingUnassignedRebroadcastOnce({ logger: console });
      } catch (rebroadcastErr) {
        console.warn('Auto-rebroadcast after unassign failed:', rebroadcastErr?.message);
      }
    });

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
      .select('id, order_number, status, restaurant_id, delivery_person_id, fulfillment_type, parcel_sender_id')
      .eq('id', id)
      .maybeSingle();
    if (fErr) throw fErr;
    if (!order) return res.status(404).json({ success: false, error: 'Order not found' });

    const orderNumber = order.order_number || order.id;

    if (order.status === 'pending') {
      const recipients = order.restaurant_id ? await getRestaurantOpsUserIds(order.restaurant_id) : [];
      if (!recipients.length) {
        return res.status(400).json({
          success: false,
          kind: 'restaurant',
          error: 'لم يتم العثور على مستلمي إشعارات للمطعم.',
          recipients: 0,
          total_sent: 0,
        });
      }

      const pushRes = await supabasePushGateway.sendPush({
        userIds: recipients,
        title: 'طلب جديد',
        body: `الطلب #${orderNumber} لا يزال معلقاً.`,
        data: {
          type: 'new_order',
          order_id: String(id),
          order_number: String(orderNumber),
          restaurant_id: String(order.restaurant_id || ''),
          flow: 'admin_track_manual_pending_rebroadcast',
          source: 'performance_dashboard',
          skip_push_dedupe: true,
        },
      });

      return res.json({
        success: true,
        kind: 'restaurant',
        message: 'تم إعادة البث إلى مالك/طاقم المطعم.',
        recipients: recipients.length,
        total_sent: pushRes.total_sent ?? recipients.length,
      });
    }

    if (order.status === 'preparing' || order.status === 'ready') {
      if (order.delivery_person_id) {
        return res.status(400).json({
          success: false,
          error: 'الطلب تم تعيينه لسائق بالفعل.',
        });
      }

      const recipients = await getOnlineAvailableCourierUserIds();
      if (!recipients.length) {
        return res.status(400).json({
          success: false,
          kind: 'courier',
          error: 'لا يوجد سائقو توصيل متاحون.',
          recipients: 0,
          total_sent: 0,
        });
      }

      const pushRes = await supabasePushGateway.sendPush({
        userIds: recipients,
        title: 'طلب متاح للتوصيل',
        body: `الطلب #${orderNumber} جاهز أو قيد التحضير وبانتظار مندوب توصيل.`,
        data: {
          type: 'order_available',
          order_id: String(id),
          order_number: String(orderNumber),
          restaurant_id: String(order.restaurant_id || ''),
          flow: 'admin_track_manual_preparing_unassigned_rebroadcast',
          source: 'performance_dashboard',
          click_action: 'FLUTTER_NOTIFICATION_CLICK',
          skip_push_dedupe: true,
        },
      });

      return res.json({
        success: true,
        kind: 'courier',
        message: 'تم إعادة البث إلى سائقي التوصيل المتاحين.',
        recipients: recipients.length,
        total_sent: pushRes.total_sent ?? recipients.length,
      });
    }

    return res.status(400).json({
      success: false,
      error: 'حالة الطلب الحالية لا تدعم إعادة البث.',
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

    const [tokensResult, workingHoursConfig, autoClosedIds] = await Promise.all([
      (async () => {
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
        return tokensByUser;
      })(),
      getWorkingHoursConfig(),
      getAutoClosedCourierIds(),
    ]);

    const tokensByUser = tokensResult;
    let autoClosedSet = new Set(autoClosedIds);
    const algiersTime = getAlgiersTime();
    const defStartMin = parseTimeToMinutes(workingHoursConfig.default_start, 660);
    const defEndMin = parseTimeToMinutes(workingHoursConfig.default_end, 1320);
    const isDefOpen = isTimeInInterval(algiersTime.totalMinutes, defStartMin, defEndMin);

    // Opportunistic Self-Healing:
    // If shift is OPEN in Algiers but couriers are still in auto-closed pool (e.g. cron was delayed/offline),
    // sync immediately so couriers are restored and the dashboard reflects available status!
    if (isDefOpen && autoClosedIds.length > 0) {
      try {
        await syncWorkingHours({ force: true, logger: console });
        const [refreshedList, refreshedAutoClosed] = await Promise.all([
          supabaseAdmin
            .from('delivery_personnel')
            .select(`
              id,
              user_id,
              delivery_name,
              work_phone,
              license_number,
              vehicle_type,
              vehicle_plate,
              is_available,
              is_online,
              total_deliveries,
              sahla_tax,
              created_at,
              updated_at,
              user:user_id(id, email, phone, name, role)
            `)
            .order('created_at', { ascending: false }),
          getAutoClosedCourierIds(),
        ]);
        if (refreshedList.data) list = refreshedList.data;
        autoClosedIds = refreshedAutoClosed;
        autoClosedSet = new Set(autoClosedIds);
      } catch (syncErr) {
        console.warn('Opportunistic syncWorkingHours failed in /delivery-personnel:', syncErr);
      }
    }

    const personnel = list.map((dp) => {
      const u = unwrapEmbed(dp.user);
      const uid = String(dp.user_id || '').trim();
      const userTokens = tokensByUser.get(uid) || [];
      const platforms = [...new Set(userTokens.map((t) => t.platform).filter(Boolean))];
      const isBlocked = (u && u.role !== 'delivery_man');

      const schedule = (dp.id && workingHoursConfig.courier_schedules?.[dp.id]) ||
                       (uid && workingHoursConfig.courier_schedules?.[uid]) ||
                       null;
      const hasCustom = Boolean(schedule && schedule.enabled !== false);
      const startStr = hasCustom ? (schedule.start || workingHoursConfig.default_start) : workingHoursConfig.default_start;
      const endStr = hasCustom ? (schedule.end || workingHoursConfig.default_end) : workingHoursConfig.default_end;
      const startMin = parseTimeToMinutes(startStr, defStartMin);
      const endMin = parseTimeToMinutes(endStr, defEndMin);
      const isShiftOpen = isTimeInInterval(algiersTime.totalMinutes, startMin, endMin);
      const isAutoClosed = autoClosedSet.has(dp.id) || (uid && autoClosedSet.has(uid));

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
        working_hours: {
          start: startStr,
          end: endStr,
          is_custom: hasCustom,
          is_auto_closed: isAutoClosed,
          is_shift_open: isShiftOpen,
        },
        created_at: dp.created_at,
        updated_at: dp.updated_at,
      };
    });

    return res.json({
      success: true,
      personnel,
      working_hours_config: {
        enabled: workingHoursConfig.enabled,
        default_start: workingHoursConfig.default_start,
        default_end: workingHoursConfig.default_end,
        timezone: workingHoursConfig.timezone,
        algiers_time: algiersTime.timeString,
        algiers_full_time: algiersTime.fullTimeString,
        is_default_open: isDefOpen,
        auto_closed_count: autoClosedIds.length,
      },
    });
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

router.get('/delivery-personnel-working-hours', requirePerformanceAuth, async (req, res) => {
  try {
    const [config, autoClosedIds] = await Promise.all([
      getWorkingHoursConfig(),
      getAutoClosedCourierIds(),
    ]);
    const algiersTime = getAlgiersTime();
    const defStartMin = parseTimeToMinutes(config.default_start, 660);
    const defEndMin = parseTimeToMinutes(config.default_end, 1320);
    const isDefOpen = isTimeInInterval(algiersTime.totalMinutes, defStartMin, defEndMin);

    return res.json({
      success: true,
      config,
      auto_closed_ids: autoClosedIds,
      algiers_now: {
        time: algiersTime.timeString,
        full_time: algiersTime.fullTimeString,
        date: algiersTime.dateString,
        is_default_open: isDefOpen,
      },
    });
  } catch (e) {
    console.error('performance /delivery-personnel-working-hours GET', e);
    return res.status(500).json({ success: false, error: e.message || 'Fetch failed' });
  }
});

router.put('/delivery-personnel-working-hours', requirePerformanceAuth, async (req, res) => {
  try {
    const courierId = req.body?.courier_id || req.body?.user_id;

    if (courierId) {
      const identifier = String(courierId).trim();
      const schedule = req.body?.schedule;

      if (schedule === null || schedule?.revert_to_default === true) {
        const updatedConfig = await updateCourierSchedule(identifier, null);
        return res.json({ success: true, identifier, schedule: null, config: updatedConfig });
      }

      const updatedConfig = await updateCourierSchedule(identifier, {
        start: schedule.start,
        end: schedule.end,
        enabled: schedule.enabled !== false,
      });
      return res.json({
        success: true,
        identifier,
        schedule: updatedConfig.courier_schedules[identifier],
        config: updatedConfig,
      });
    }

    const currentConfig = await getWorkingHoursConfig();
    const updates = {};
    if (typeof req.body?.enabled === 'boolean') updates.enabled = req.body.enabled;
    if (typeof req.body?.default_start === 'string' && req.body.default_start.trim()) {
      updates.default_start = req.body.default_start.trim();
    }
    if (typeof req.body?.default_end === 'string' && req.body.default_end.trim()) {
      updates.default_end = req.body.default_end.trim();
    }

    const saved = await saveWorkingHoursConfig({ ...currentConfig, ...updates });
    return res.json({ success: true, config: saved });
  } catch (e) {
    console.error('performance /delivery-personnel-working-hours PUT', e);
    return res.status(500).json({ success: false, error: e.message || 'Save failed' });
  }
});

router.post('/delivery-personnel-working-hours/sync', requirePerformanceAuth, async (req, res) => {
  try {
    const result = await syncWorkingHours({ force: true, logger: console });
    return res.json({ success: true, ...result });
  } catch (e) {
    console.error('performance /delivery-personnel-working-hours/sync POST', e);
    return res.status(500).json({ success: false, error: e.message || 'Sync failed' });
  }
});

router.post('/delivery-personnel/send-morning-greeting', requirePerformanceAuth, async (req, res) => {
  try {
    const { force = false, user_id = null } = req.body || {};
    const result = await sendMorningGreetingToAvailableCouriers({
      force: Boolean(force),
      targetUserId: user_id ? String(user_id).trim() : null,
      logger: console,
    });
    return res.json({ success: true, ...result });
  } catch (e) {
    console.error('performance /delivery-personnel/send-morning-greeting POST', e);
    return res.status(500).json({ success: false, error: e.message || 'Send failed' });
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
/* Manual Order Creation Endpoints                                          */
/* ========================================================================= */

function calculateHaversineDistanceKm(lat1, lon1, lat2, lon2) {
  const R = 6371;
  const dLat = ((lat2 - lat1) * Math.PI) / 180;
  const dLon = ((lon2 - lon1) * Math.PI) / 180;
  const a =
    Math.sin(dLat / 2) * Math.sin(dLat / 2) +
    Math.cos((lat1 * Math.PI) / 180) *
      Math.cos((lat2 * Math.PI) / 180) *
      Math.sin(dLon / 2) *
      Math.sin(dLon / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
  return Number((R * c).toFixed(2));
}

function estimateSegmentedDeliveryFee(distKm) {
  if (!distKm || distKm <= 0) return 150;
  if (distKm <= 1.5) return 150;
  if (distKm <= 2.0) return 180;
  if (distKm <= 3.5) return 200;
  if (distKm <= 4.0) return 250;
  if (distKm <= 5.0) return 280;
  if (distKm <= 7.0) return 320;
  if (distKm <= 8.0) return 350;
  if (distKm <= 9.0) return 380;
  if (distKm <= 10.0) return 400;
  return Math.round(400 + (distKm - 10) * 35);
}

router.get('/manual-order/restaurants', requirePerformanceAuth, async (req, res) => {
  try {
    const { data: restaurants, error } = await supabaseAdmin
      .from('restaurants')
      .select('id, name, name_ar, phone, address_line1, city, state, latitude, longitude, logo_url, is_open, is_verified')
      .order('name', { ascending: true });

    if (error) throw error;
    return res.json({ success: true, restaurants: restaurants || [] });
  } catch (e) {
    console.error('performance /manual-order/restaurants GET', e);
    return res.status(500).json({ success: false, error: e.message || 'Failed to fetch restaurants' });
  }
});

router.get('/manual-order/menu-items', requirePerformanceAuth, async (req, res) => {
  try {
    const restaurantId = req.query.restaurant_id;
    if (!restaurantId) {
      return res.status(400).json({ success: false, error: 'restaurant_id query param is required' });
    }

    const { data: items, error } = await supabaseAdmin
      .from('menu_items')
      .select('id, restaurant_id, name, name_ar, description, description_ar, price, category, is_available, pricing_options, variants, supplements, tax_free')
      .eq('restaurant_id', restaurantId)
      .eq('is_available', true)
      .neq('name', '__MANUAL_PHONE_ORDER__')
      .order('name', { ascending: true });

    if (error) throw error;
    return res.json({ success: true, items: items || [] });
  } catch (e) {
    console.error('performance /manual-order/menu-items GET', e);
    return res.status(500).json({ success: false, error: e.message || 'Failed to fetch menu items' });
  }
});

router.get('/manual-order/customer-lookup', requirePerformanceAuth, async (req, res) => {
  try {
    const rawPhone = String(req.query.phone || '').trim();
    if (!rawPhone || rawPhone.length < 8) {
      return res.json({ success: true, found: false });
    }

    const digitsOnly = rawPhone.replace(/\D/g, '');
    const clean0 = digitsOnly.startsWith('213') ? '0' + digitsOnly.slice(3) : digitsOnly;
    const last8 = digitsOnly.slice(-8);

    // Search in user_profiles by last 8 digits
    const { data: profiles, error: profileErr } = await supabaseAdmin
      .from('user_profiles')
      .select('id, name, full_name, phone')
      .ilike('phone', `%${last8}%`)
      .limit(1);

    if (!profileErr && profiles && profiles.length > 0) {
      const p = profiles[0];
      const customerName = p.name || p.full_name || '';

      // Check last order for delivery address
      let lastAddress = null;
      try {
        const { data: lastOrder } = await supabaseAdmin
          .from('orders')
          .select('delivery_address')
          .eq('customer_id', p.id)
          .not('delivery_address', 'is', null)
          .order('created_at', { ascending: false })
          .limit(1)
          .maybeSingle();
        if (lastOrder?.delivery_address) {
          lastAddress = lastOrder.delivery_address;
        }
      } catch (_) {}

      return res.json({
        success: true,
        found: true,
        source: 'user_profile',
        customer: {
          id: p.id,
          name: customerName,
          phone: p.phone || rawPhone,
          address: lastAddress,
        },
      });
    }

    // Secondary check: recent orders with this guest phone
    const { data: recentOrders } = await supabaseAdmin
      .from('orders')
      .select('guest_name, delivery_address')
      .ilike('guest_phone', `%${last8}%`)
      .order('created_at', { ascending: false })
      .limit(1);

    if (recentOrders && recentOrders.length > 0) {
      const r = recentOrders[0];
      return res.json({
        success: true,
        found: true,
        source: 'recent_order',
        customer: {
          id: null,
          name: r.guest_name || '',
          phone: rawPhone,
          address: r.delivery_address || null,
        },
      });
    }

    return res.json({ success: true, found: false });
  } catch (e) {
    console.error('performance /manual-order/customer-lookup GET', e);
    return res.status(500).json({ success: false, error: e.message || 'Customer lookup failed' });
  }
});

router.post('/manual-order/validate-promo', requirePerformanceAuth, async (req, res) => {
  try {
    const { code, restaurant_id, subtotal, delivery_fee } = req.body;
    const promoCodeStr = String(code || '').trim().toUpperCase();
    if (!promoCodeStr) {
      return res.status(400).json({ success: false, error: 'Promo code is required' });
    }

    const { data: promo, error: promoErr } = await supabaseAdmin
      .from('promo_codes')
      .select('*')
      .ilike('code', promoCodeStr)
      .maybeSingle();

    if (promoErr) throw promoErr;
    if (!promo) {
      return res.json({ valid: false, message: 'كود الخصم غير موجود' });
    }

    if (promo.status && promo.status !== 'active') {
      return res.json({ valid: false, message: 'كود الخصم غير نشط' });
    }
    if (promo.is_active === false) {
      return res.json({ valid: false, message: 'كود الخصم غير مفعل' });
    }

    const now = new Date();
    if (promo.start_date && new Date(promo.start_date) > now) {
      return res.json({ valid: false, message: 'كود الخصم لم يبدأ بعد' });
    }
    if (promo.end_date && new Date(promo.end_date) < now) {
      return res.json({ valid: false, message: 'كود الخصم منتهي الصلاحية' });
    }

    if (promo.restaurant_id && restaurant_id && promo.restaurant_id !== restaurant_id) {
      return res.json({ valid: false, message: 'كود الخصم غير صالح لهذا المطعم' });
    }

    const sub = Math.max(0, parseFloat(subtotal) || 0);
    const delFee = Math.max(0, parseFloat(delivery_fee) || 0);
    const minOrder = Math.max(0, parseFloat(promo.minimum_order_amount) || 0);
    if (minOrder > 0 && sub < minOrder) {
      return res.json({
        valid: false,
        message: `الحد الأدنى للطلب لتفعيل هذا الكود هو ${minOrder} دج`,
      });
    }

    let discount = 0;
    const promoType = String(promo.type || '').toLowerCase();
    const promoVal = Math.max(0, parseFloat(promo.value) || 0);
    const appliesTo = String(promo.applies_to || 'subtotal').toLowerCase();

    const targetAmount = appliesTo.includes('delivery') ? delFee : sub;

    if (promoType === 'percentage') {
      discount = (targetAmount * promoVal) / 100;
    } else if (promoType === 'fixedamount' || promoType === 'fixed_amount') {
      discount = promoVal;
    } else if (promoType === 'freedelivery' || promoType === 'free_delivery') {
      discount = delFee;
    } else {
      discount = promoVal;
    }

    const maxDiscount = Math.max(0, parseFloat(promo.maximum_discount_amount) || 0);
    if (maxDiscount > 0 && discount > maxDiscount) {
      discount = maxDiscount;
    }

    discount = Math.min(discount, targetAmount);
    discount = Math.round(discount * 100) / 100;

    return res.json({
      valid: true,
      promo: {
        id: promo.id,
        code: promo.code,
        name: promo.name || promo.code,
        type: promo.type,
        value: promo.value,
        applies_to: promo.applies_to,
        discount_amount: discount,
      },
    });
  } catch (e) {
    console.error('performance /manual-order/validate-promo POST', e);
    return res.status(500).json({ success: false, error: e.message || 'Promo validation failed' });
  }
});

router.post('/manual-order/estimate-delivery-fee', requirePerformanceAuth, async (req, res) => {
  try {
    const { restaurant_lat, restaurant_lng, customer_lat, customer_lng } = req.body;
    const rLat = parseFloat(restaurant_lat);
    const rLng = parseFloat(restaurant_lng);
    const cLat = parseFloat(customer_lat);
    const cLng = parseFloat(customer_lng);

    if (!Number.isFinite(rLat) || !Number.isFinite(rLng) || !Number.isFinite(cLat) || !Number.isFinite(cLng)) {
      return res.json({ success: true, distance_km: null, estimated_fee: 150 });
    }

    const distanceKm = calculateHaversineDistanceKm(rLat, rLng, cLat, cLng);
    const estimatedFee = estimateSegmentedDeliveryFee(distanceKm);

    return res.json({
      success: true,
      distance_km: distanceKm,
      estimated_fee: estimatedFee,
    });
  } catch (e) {
    console.error('performance /manual-order/estimate-delivery-fee POST', e);
    return res.status(500).json({ success: false, error: e.message || 'Fee estimation failed' });
  }
});

router.post('/manual-order/create', requirePerformanceAuth, async (req, res) => {
  try {
    const {
      restaurant_id,
      execution_mode, // 'send_to_restaurant' | 'direct_broadcast'
      customer_phone,
      customer_name,
      delivery_address,
      items,
      subtotal: rawSubtotal,
      delivery_fee: rawDeliveryFee,
      service_fee: rawServiceFee,
      promo_code,
      promo_id,
      discount_amount: rawDiscountAmount,
      special_instructions,
      payment_method,
    } = req.body;

    if (!restaurant_id) {
      return res.status(400).json({ success: false, error: 'restaurant_id is required' });
    }
    if (!['send_to_restaurant', 'direct_broadcast'].includes(execution_mode)) {
      return res.status(400).json({
        success: false,
        error: "execution_mode must be either 'send_to_restaurant' or 'direct_broadcast'",
      });
    }
    if (!customer_phone || !String(customer_phone).trim()) {
      return res.status(400).json({ success: false, error: 'Customer phone is required' });
    }
    if (!Array.isArray(items) || items.length === 0) {
      return res.status(400).json({ success: false, error: 'At least one item is required' });
    }

    // Fetch restaurant
    const { data: restaurant, error: restErr } = await supabaseAdmin
      .from('restaurants')
      .select('id, name, name_ar, owner_id, latitude, longitude, phone, address_line1, is_open')
      .eq('id', restaurant_id)
      .maybeSingle();

    if (restErr || !restaurant) {
      return res.status(404).json({ success: false, error: 'Restaurant not found' });
    }

    // Resolve customer ID
    const phoneTrimmed = String(customer_phone).trim();
    const digitsOnly = phoneTrimmed.replace(/\D/g, '');
    const clean0 = digitsOnly.startsWith('213') ? '0' + digitsOnly.slice(3) : digitsOnly;
    const cleanPlus213 = '+' + (digitsOnly.startsWith('0') ? '213' + digitsOnly.slice(1) : digitsOnly);

    let customerId = null;
    const { data: matchedProfiles } = await supabaseAdmin
      .from('user_profiles')
      .select('id, name')
      .or(`phone.eq.${clean0},phone.eq.${cleanPlus213}`)
      .limit(1);

    if (matchedProfiles && matchedProfiles.length > 0) {
      customerId = matchedProfiles[0].id;
    } else {
      // System config fallback ID
      const { data: cfgRow } = await supabaseAdmin
        .from('system_config')
        .select('config_value')
        .eq('config_key', 'manual_order_fallback_customer_id')
        .maybeSingle();

      const fallbackId = cfgRow?.config_value ? String(cfgRow.config_value).trim() : null;
      if (fallbackId) {
        const { data: fbProf } = await supabaseAdmin
          .from('user_profiles')
          .select('id')
          .eq('id', fallbackId)
          .maybeSingle();
        if (fbProf) customerId = fbProf.id;
      }

      if (!customerId && restaurant.owner_id) {
        const { data: ownerProf } = await supabaseAdmin
          .from('user_profiles')
          .select('id')
          .eq('id', restaurant.owner_id)
          .maybeSingle();
        if (ownerProf) customerId = ownerProf.id;
      }

      if (!customerId) {
        customerId = '68b1a9f1-084c-4c2d-bb6e-4f12987d3ab4';
      }
    }

    // Ensure placeholder menu item exists for restaurant (in case items have custom lines)
    let fallbackMenuItemId = null;
    const { data: existingPlaceholder } = await supabaseAdmin
      .from('menu_items')
      .select('id')
      .eq('restaurant_id', restaurant_id)
      .eq('name', '__MANUAL_PHONE_ORDER__')
      .maybeSingle();

    if (existingPlaceholder) {
      fallbackMenuItemId = existingPlaceholder.id;
    } else {
      const { data: createdPlaceholder } = await supabaseAdmin
        .from('menu_items')
        .insert({
          restaurant_id,
          name: '__MANUAL_PHONE_ORDER__',
          description: 'Internal placeholder for manual phone orders',
          price: 0,
          category: 'Other',
          is_available: false,
          is_featured: false,
          preparation_time: 0,
        })
        .select('id')
        .maybeSingle();
      if (createdPlaceholder) {
        fallbackMenuItemId = createdPlaceholder.id;
      }
    }

    // Coordinates enforcement for delivery_address (required by DB constraints)
    const lat = Number.isFinite(parseFloat(delivery_address?.latitude))
      ? parseFloat(delivery_address.latitude)
      : Number.isFinite(parseFloat(restaurant.latitude))
        ? parseFloat(restaurant.latitude)
        : 34.8516;
    const lng = Number.isFinite(parseFloat(delivery_address?.longitude))
      ? parseFloat(delivery_address.longitude)
      : Number.isFinite(parseFloat(restaurant.longitude))
        ? parseFloat(restaurant.longitude)
        : 5.7281;

    const safeDeliveryAddress = {
      source: delivery_address?.source || 'manual_entry',
      fullAddress: String(delivery_address?.fullAddress || delivery_address?.street || 'Selected Location').trim(),
      street: String(delivery_address?.street || delivery_address?.fullAddress || '').trim(),
      city: String(delivery_address?.city || 'Biskra').trim(),
      latitude: lat,
      longitude: lng,
      recipient_name: customer_name ? String(customer_name).trim() : null,
      recipient_phone: phoneTrimmed,
      instructions: delivery_address?.instructions || null,
    };

    // Calculate item totals & financial figures
    let computedSubtotal = 0;
    const processedOrderItems = [];

    for (const it of items) {
      const qty = Math.max(1, parseInt(it.quantity, 10) || 1);
      const unitPrice = Math.max(0, parseFloat(it.unit_price) || 0);
      const totalPrice = Math.round(unitPrice * qty * 100) / 100;
      computedSubtotal += totalPrice;

      const menuItemId = it.menu_item_id || fallbackMenuItemId;
      const itemName = String(it.name || '').trim();
      const itemNotes = String(it.special_instructions || '').trim();

      let finalInstructions = itemNotes;
      if (!it.menu_item_id && itemName) {
        finalInstructions = finalInstructions ? `${itemName} (${finalInstructions})` : itemName;
      }

      processedOrderItems.push({
        menu_item_id: menuItemId,
        quantity: qty,
        unit_price: unitPrice,
        price: unitPrice,
        total_price: totalPrice,
        special_instructions: finalInstructions || null,
        customizations: it.customizations || null,
      });
    }

    const subtotal = Math.round(computedSubtotal * 100) / 100;
    const deliveryFee = Math.max(0, Math.round((parseFloat(rawDeliveryFee) || 0) * 100) / 100);
    const serviceFee = Math.max(0, Math.round((parseFloat(rawServiceFee) || 0) * 100) / 100);
    const discountAmount = Math.max(0, Math.round((parseFloat(rawDiscountAmount) || 0) * 100) / 100);

    const totalAmount = Math.max(0, Math.round((subtotal + deliveryFee + serviceFee - discountAmount) * 100) / 100);

    // Floor to nearest 10 DA for cash payment
    const cashPayableAmount = Math.floor(totalAmount / 10) * 10;
    const cashRoundingAdjustment = Math.round((cashPayableAmount - totalAmount) * 100) / 100;

    // Delivery settlement calculations
    const deliveryTax = Math.min(Math.round(deliveryFee * 0.15 * 100) / 100, 100);
    const netDeliveryAmount = Math.round((deliveryFee - deliveryTax) * 100) / 100;
    const net = Math.round((totalAmount - deliveryFee - serviceFee) * 100) / 100;

    // Generate unique order number
    const nowUtc = new Date();
    const mm = String(nowUtc.getUTCMonth() + 1).padStart(2, '0');
    const dd = String(nowUtc.getUTCDate()).padStart(2, '0');
    const hh = String(nowUtc.getUTCHours()).padStart(2, '0');
    const min = String(nowUtc.getUTCMinutes()).padStart(2, '0');
    const ss = String(nowUtc.getUTCSeconds()).padStart(2, '0');
    const rnd = String(Math.floor(Math.random() * 900) + 100);
    const orderNumber = `ORD-${mm}${dd}${hh}${min}${ss}${rnd}`;

    // Order status determination
    const initialStatus = execution_mode === 'direct_broadcast' ? 'preparing' : 'pending';
    const nowIso = new Date().toISOString();

    let combinedNotes = special_instructions ? String(special_instructions).trim() : '';
    if (combinedNotes) {
      combinedNotes += ` | Phone: ${phoneTrimmed}`;
    } else {
      combinedNotes = `Phone order: ${phoneTrimmed}`;
    }
    if (customer_name) {
      combinedNotes += ` (${String(customer_name).trim()})`;
    }

    const orderRow = {
      restaurant_id,
      customer_id: customerId,
      order_number: orderNumber,
      status: initialStatus,
      payment_status: 'pending',
      payment_method: payment_method || 'cash_on_delivery',
      fulfillment_type: 'delivery',
      subtotal,
      original_delivery_fee: deliveryFee,
      delivery_fee: deliveryFee,
      delivery_tax: deliveryTax,
      net_delivery_amount: netDeliveryAmount,
      tax_amount: 0,
      service_fee: serviceFee,
      discount_amount: discountAmount,
      total_amount: totalAmount,
      cash_rounding_adjustment: cashRoundingAdjustment,
      cash_payable_amount: cashPayableAmount,
      net,
      is_special_delivery: false,
      delivery_address: safeDeliveryAddress,
      special_instructions: combinedNotes,
      manual_phone_order: true,
      guest_phone: phoneTrimmed,
      guest_name: customer_name ? String(customer_name).trim() : null,
      applied_promo_code: promo_code ? String(promo_code).trim() : null,
      applied_promo_code_id: promo_id || null,
      source: 'performance_dashboard_manual',
      preparing_started_at: initialStatus === 'preparing' ? nowIso : null,
      broadcast_at: initialStatus === 'preparing' ? nowIso : null,
      created_at: nowIso,
      updated_at: nowIso,
    };

    // Insert order
    const { data: newOrder, error: orderInsertErr } = await supabaseAdmin
      .from('orders')
      .insert(orderRow)
      .select('*')
      .single();

    if (orderInsertErr) {
      console.error('Failed to insert manual order:', orderInsertErr);
      if (orderInsertErr.message === 'restaurant_closed' || orderInsertErr.message === 'restaurant_on_break') {
        return res.status(400).json({
          success: false,
          error:
            'المطعم مغلق حالياً في جدول ساعات العمل (خارج أوقات الدوام). يرجى التأكد من حالة فتح المطعم أو تطبيق تحديث قاعدة البيانات الخاص بالسماح بالطلبات اليدوية.',
        });
      }
      throw orderInsertErr;
    }

    // Insert order items
    const itemsToInsert = processedOrderItems.map((it) => ({
      ...it,
      order_id: newOrder.id,
      created_at: nowIso,
    }));

    const { error: itemsInsertErr } = await supabaseAdmin
      .from('order_items')
      .insert(itemsToInsert);

    if (itemsInsertErr) {
      console.warn('Failed to insert order items:', itemsInsertErr);
    }

    // Insert order event
    try {
      await supabaseAdmin.from('order_events').insert({
        order_id: newOrder.id,
        order_number: orderNumber,
        event_type: 'created',
        new_status: initialStatus,
        changed_by_role: 'admin',
        customer_id: customerId,
        restaurant_id: restaurant_id,
        source: 'performance_dashboard_manual_order',
        payload_json: {
          execution_mode,
          created_by: 'admin',
          customer_phone: phoneTrimmed,
          customer_name: customer_name || null,
          items_count: processedOrderItems.length,
          total_amount: totalAmount,
        },
      });
    } catch (evErr) {
      console.warn('Failed to insert order event:', evErr);
    }

    // Notifications dispatch based on execution_mode
    const notificationSummary = {
      restaurant_notified: false,
      couriers_notified: false,
      courier_count: 0,
    };

    const restaurantDisplayName = restaurant.name_ar || restaurant.name || 'المطعم';

    if (execution_mode === 'send_to_restaurant') {
      const restOpsUserIds = await getRestaurantOpsUserIds(restaurant_id);
      if (restOpsUserIds.length > 0) {
        try {
          await supabasePushGateway.sendPush({
            userIds: restOpsUserIds,
            title: `طلب جديد بانتظار التأكيد #${orderNumber}`,
            body: `طلب يدوي جديد بقيمة ${totalAmount} دج ينتظر تأكيدك.`,
            data: {
              type: 'new_order',
              order_id: newOrder.id,
              order_number: orderNumber,
              click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
          });
          notificationSummary.restaurant_notified = true;
        } catch (pushErr) {
          console.warn('Failed to push to restaurant ops:', pushErr);
        }
      }
    } else if (execution_mode === 'direct_broadcast') {
      // 1. Broadcast to available couriers
      const courierUserIds = await getOnlineAvailableCourierUserIds();
      notificationSummary.courier_count = courierUserIds.length;
      if (courierUserIds.length > 0) {
        try {
          await supabasePushGateway.sendPush({
            userIds: courierUserIds,
            title: 'طلب متاح للتوصيل',
            body: `طلب جديد من ${restaurantDisplayName} متاح الآن للتوصيل (${totalAmount} دج).`,
            data: {
              type: 'courier_order_available',
              order_id: newOrder.id,
              order_number: orderNumber,
              click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
          });
          notificationSummary.couriers_notified = true;
        } catch (pushErr) {
          console.warn('Failed to push broadcast to couriers:', pushErr);
        }
      }

      // 2. Also notify restaurant ops
      const restOpsUserIds = await getRestaurantOpsUserIds(restaurant_id);
      if (restOpsUserIds.length > 0) {
        try {
          await supabasePushGateway.sendPush({
            userIds: restOpsUserIds,
            title: `طلب جديد مباشر قيد التحضير #${orderNumber}`,
            body: `تم إرسال الطلب #${orderNumber} لمندوبي التوصيل وهو الآن قيد التحضير.`,
            data: {
              type: 'order_status_update',
              order_id: newOrder.id,
              status: 'preparing',
              click_action: 'FLUTTER_NOTIFICATION_CLICK',
            },
          });
          notificationSummary.restaurant_notified = true;
        } catch (pushErr) {
          console.warn('Failed to push notice to restaurant ops:', pushErr);
        }
      }
    }

    return res.json({
      success: true,
      order: newOrder,
      order_number: orderNumber,
      status: initialStatus,
      execution_mode,
      notifications: notificationSummary,
    });
  } catch (e) {
    console.error('performance /manual-order/create POST', e);
    return res.status(500).json({ success: false, error: e.message || 'Order creation failed' });
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

    // Active alert for orders in preparing/ready with courier assigned but NOT picked up within threshold (20 min)
    const preparingAssignedDelayMin = Number(process.env.PERFORMANCE_PREPARING_ASSIGNED_DELAY_MINUTES) || 20;
    const preparingAssignedThresholdIso = new Date(Date.now() - preparingAssignedDelayMin * 60_000).toISOString();
    const { data: delayedPreparingAssigned, error: paErr } = await supabaseAdmin
      .from('orders')
      .select(ORDER_SELECT)
      .in('status', ['preparing', 'ready'])
      .not('delivery_person_id', 'is', null)
      .is('parcel_sender_id', null)
      .or(`courier_assigned_at.lte.${preparingAssignedThresholdIso},and(courier_assigned_at.is.null,updated_at.lte.${preparingAssignedThresholdIso})`)
      .order('created_at', { ascending: true })
      .limit(300);
    if (paErr) throw paErr;

    const preparingAssignedDelayed = (delayedPreparingAssigned || []).map((o) => ({
      ...enrichOrderCourier(o),
      ageMinutes: ageMinutes(o.courier_assigned_at || o.updated_at),
    })).filter((o) => o.ageMinutes != null && o.ageMinutes >= preparingAssignedDelayMin);

    // Active alert for orders in preparing/ready with NO courier assigned within threshold (5 min)
    const preparingUnassignedDelayMin = Number(process.env.PERFORMANCE_PREPARING_UNASSIGNED_DELAY_MINUTES) || 5;
    const preparingUnassignedThresholdIso = new Date(Date.now() - preparingUnassignedDelayMin * 60_000).toISOString();
    const { data: delayedPreparingUnassigned, error: puErr } = await supabaseAdmin
      .from('orders')
      .select(ORDER_SELECT)
      .in('status', ['preparing', 'ready'])
      .is('delivery_person_id', null)
      .is('parcel_sender_id', null)
      .lte('updated_at', preparingUnassignedThresholdIso)
      .order('created_at', { ascending: true })
      .limit(300);
    if (puErr) throw puErr;

    const preparingUnassignedDelayed = (delayedPreparingUnassigned || []).map((o) => ({
      ...enrichOrderCourier(o),
      ageMinutes: ageMinutes(o.courier_unassigned_episode_at || o.updated_at || o.created_at),
    })).filter((o) => o.ageMinutes != null && o.ageMinutes >= preparingUnassignedDelayMin);

    const dashboardPollMs = Number(process.env.PERFORMANCE_OPEN_DASHBOARD_POLL_MS || 0);
    if (Number.isFinite(dashboardPollMs) && dashboardPollMs >= 30_000) {
      const now = Date.now();
      if (now - _lastDashboardEscalationPollMs >= dashboardPollMs) {
        _lastDashboardEscalationPollMs = now;
        setImmediate(async () => {
          try {
            const pending = await runPendingOrdersPollOnce({ logger: console });
            const pickup = await runPickupDelayAdminAlertsOnce({ logger: console });
            const preparingRebroadcast = await runPreparingUnassignedRebroadcastOnce({ logger: console }).catch(() => {});
            const preparingAssignedAlerts = await runPreparingAssignedDelayAdminAlertsOnce({ logger: console }).catch(() => {});
            console.info?.('[performance/alerts] background escalation poll', {
              pending,
              pickup,
              preparingRebroadcast,
              preparingAssignedAlerts,
            });
          } catch (err) {
            console.error('[performance/alerts] background escalation poll failed', err);
          }
        });
      }
    }

    const [
      stalePendingOrdersWithItems,
      parcelWaitingOrdersWithItems,
      pickedUpDelayedWithItems,
      preparingAssignedDelayedWithItems,
      preparingUnassignedDelayedWithItems,
    ] = await Promise.all([
      attachOrderItemsSummary(stalePendingOrders),
      attachOrderItemsSummary(parcelWaitingOrders),
      attachOrderItemsSummary(pickedUpDeliveryDelayed),
      attachOrderItemsSummary(preparingAssignedDelayed),
      attachOrderItemsSummary(preparingUnassignedDelayed),
    ]);

    const activeAlertOrderIds = [
      ...stalePendingOrders.map((o) => o.id),
      ...parcelWaitingOrders.map((o) => o.id),
      ...pickedUpDeliveryDelayed.map((o) => o.id),
      ...preparingAssignedDelayed.map((o) => o.id),
      ...preparingUnassignedDelayed.map((o) => o.id),
    ].filter(Boolean);

    return res.json({
      success: true,
      thresholdMinutes: minutes,
      activeAlertOrderIds,
      stalePendingOrders: stalePendingOrdersWithItems,
      tasksWithoutOffers,
      parcelWaitingOrders: parcelWaitingOrdersWithItems,
      parcel_waiting_minutes: minutes,
      pickedUpDeliveryDelayed: pickedUpDelayedWithItems,
      picked_up_delay_minutes: pickupDelayMin,
      preparingAssignedDelayed: preparingAssignedDelayedWithItems,
      preparing_assigned_delay_minutes: preparingAssignedDelayMin,
      preparingUnassignedDelayed: preparingUnassignedDelayedWithItems,
      preparing_unassigned_delay_minutes: preparingUnassignedDelayMin,
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

/* ========================================================================= */
/* Sahla Payments & Taxes Management                                         */
/* ========================================================================= */

router.get('/sahla-payments', requirePerformanceAuth, async (req, res) => {
  try {
    const { data: couriers, error } = await supabaseAdmin
      .from('delivery_personnel')
      .select(`
        id,
        user_id,
        delivery_name,
        work_phone,
        sahla_tax,
        credit,
        tax_payment,
        pending_collection,
        wallet_financial_mode,
        is_online,
        is_available,
        user:user_id (
          id,
          name,
          phone
        )
      `)
      .or('sahla_tax.gt.0,tax_payment.not.is.null')
      .order('sahla_tax', { ascending: false });

    if (error) throw error;

    const unpaid = [];
    const ongoing = [];

    let totalUnpaidTax = 0;
    let totalOngoingAmount = 0;

    for (const c of couriers || []) {
      const sahlaTax = Number(c.sahla_tax) || 0;
      const credit = Number(c.credit) || 0;
      const netAmount = Math.max(0, sahlaTax - credit);
      const taxPayment = c.tax_payment && typeof c.tax_payment === 'object' ? c.tax_payment : null;
      const paymentStatus = taxPayment ? taxPayment.status : null;
      const isOngoing = paymentStatus === 'pending' || paymentStatus === 'auto_generated';

      const courierName = (c.delivery_name || '').trim() || (c.user?.name || '').trim() || 'Unknown Courier';
      const courierPhone = (c.work_phone || '').trim() || (c.user?.phone || '').trim() || '';

      const pendingOrders = Array.isArray(c.pending_collection?.orders) ? c.pending_collection.orders : [];
      const pendingCount = Number(c.pending_collection?.order_count) || pendingOrders.length || 0;

      if (isOngoing) {
        const paymentAmount = Number(taxPayment.total_amount) || sahlaTax;
        totalOngoingAmount += paymentAmount;
        ongoing.push({
          id: c.id,
          user_id: c.user_id,
          delivery_name: courierName,
          work_phone: courierPhone,
          payment_number: taxPayment.payment_number || 'N/A',
          status: paymentStatus,
          total_amount: paymentAmount,
          total_tax_amount: Number(taxPayment.total_tax_amount) || sahlaTax,
          credit_amount: Number(taxPayment.credit_payment_amount) || credit,
          receipt_url: taxPayment.receipt_url || null,
          submitted_at: taxPayment.submitted_at || null,
          auto_generated_at: taxPayment.auto_generated_at || null,
          orders: Array.isArray(taxPayment.orders) ? taxPayment.orders : [],
          tasks: Array.isArray(taxPayment.tasks) ? taxPayment.tasks : [],
          order_count: Array.isArray(taxPayment.orders) ? taxPayment.orders.length : 0,
          task_count: Array.isArray(taxPayment.tasks) ? taxPayment.tasks.length : 0,
        });
      }

      if (sahlaTax > 0 && !isOngoing) {
        totalUnpaidTax += sahlaTax;
        unpaid.push({
          id: c.id,
          user_id: c.user_id,
          delivery_name: courierName,
          work_phone: courierPhone,
          sahla_tax: sahlaTax,
          credit: credit,
          net_amount: netAmount,
          order_count: pendingCount,
          pending_orders: pendingOrders,
          wallet_financial_mode: c.wallet_financial_mode || 'legacy',
          is_online: Boolean(c.is_online),
          is_available: Boolean(c.is_available),
        });
      }
    }

    return res.json({
      success: true,
      unpaid,
      ongoing,
      summary: {
        total_unpaid_tax: Math.round(totalUnpaidTax * 100) / 100,
        unpaid_count: unpaid.length,
        total_ongoing_amount: Math.round(totalOngoingAmount * 100) / 100,
        ongoing_count: ongoing.length,
      },
    });
  } catch (e) {
    console.error('performance /sahla-payments GET', e);
    return res.status(500).json({ success: false, error: e.message || 'Failed to load Sahla payments' });
  }
});

router.get('/sahla-payments/:id/orders', requirePerformanceAuth, async (req, res) => {
  try {
    const courierId = req.params.id;
    if (!courierId) {
      return res.status(400).json({ success: false, error: 'Courier ID is required' });
    }

    const { data: courier, error: courierErr } = await supabaseAdmin
      .from('delivery_personnel')
      .select(`
        id,
        user_id,
        delivery_name,
        work_phone,
        sahla_tax,
        credit,
        tax_payment,
        pending_collection,
        user:user_id (
          id,
          name,
          phone
        )
      `)
      .eq('id', courierId)
      .maybeSingle();

    if (courierErr || !courier) {
      return res.status(404).json({ success: false, error: 'Courier not found' });
    }

    const courierName = (courier.delivery_name || '').trim() || (courier.user?.name || '').trim() || 'Unknown Courier';
    const courierPhone = (courier.work_phone || '').trim() || (courier.user?.phone || '').trim() || '';

    const taxPayment = courier.tax_payment && typeof courier.tax_payment === 'object' ? courier.tax_payment : null;
    const isOngoing = taxPayment && (taxPayment.status === 'pending' || taxPayment.status === 'auto_generated');

    let orders = [];
    let tasks = [];

    if (isOngoing && Array.isArray(taxPayment.orders) && taxPayment.orders.length > 0) {
      orders = taxPayment.orders;
      tasks = Array.isArray(taxPayment.tasks) ? taxPayment.tasks : [];
    } else {
      if (Array.isArray(courier.pending_collection?.orders) && courier.pending_collection.orders.length > 0) {
        orders = courier.pending_collection.orders;
      }

      if (orders.length === 0) {
        const { data: dbOrders } = await supabaseAdmin
          .from('orders')
          .select(`
            id,
            order_number,
            subtotal,
            delivery_fee,
            tax_amount,
            delivery_tax,
            service_fee,
            delivery_fee_discount,
            total_amount,
            status,
            tax_paid,
            created_at,
            actual_delivery_time,
            restaurant:restaurant_id (
              name
            ),
            customer:customer_id (
              name,
              phone
            )
          `)
          .eq('delivery_person_id', courierId)
          .in('status', ['delivered', 'collected'])
          .or('tax_paid.eq.false,tax_paid.is.null')
          .order('actual_delivery_time', { ascending: false });

        if (dbOrders && dbOrders.length > 0) {
          orders = dbOrders.map((o) => ({
            id: o.id,
            order_id: o.id,
            order_number: o.order_number,
            subtotal: Number(o.subtotal) || 0,
            delivery_fee: Number(o.delivery_fee) || 0,
            tax_amount: Number(o.tax_amount) || 0,
            delivery_tax: Number(o.delivery_tax) || 0,
            service_fee: Number(o.service_fee) || 0,
            delivery_fee_discount: Number(o.delivery_fee_discount) || 0,
            total_amount: Number(o.total_amount) || 0,
            total: (Number(o.tax_amount) || 0) + (Number(o.delivery_tax) || 0) + (Number(o.service_fee) || 0) - (Number(o.delivery_fee_discount) || 0),
            created_at: o.created_at,
            actual_delivery_time: o.actual_delivery_time,
            restaurant: o.restaurant || { name: 'Restaurant' },
            customer: o.customer || { name: 'Customer' },
          }));
        }
      }

      if (courier.user_id) {
        const { data: dbTasks } = await supabaseAdmin
          .from('tasks')
          .select('id, delivery_tax, description, status, created_at, completed_at, tax_paid')
          .eq('delivery_man_id', courier.user_id)
          .eq('status', 'completed')
          .or('tax_paid.eq.false,tax_paid.is.null');

        if (dbTasks && dbTasks.length > 0) {
          tasks = dbTasks.map((t) => ({
            id: t.id,
            task_id: t.id,
            delivery_tax: Number(t.delivery_tax) || 0,
            total: Number(t.delivery_tax) || 0,
            description: t.description || 'Task',
            created_at: t.created_at,
            completed_at: t.completed_at,
          }));
        }
      }
    }

    return res.json({
      success: true,
      courier: {
        id: courier.id,
        delivery_name: courierName,
        work_phone: courierPhone,
        sahla_tax: Number(courier.sahla_tax) || 0,
        credit: Number(courier.credit) || 0,
        is_ongoing: Boolean(isOngoing),
        payment_number: taxPayment?.payment_number || null,
        status: taxPayment?.status || null,
        receipt_url: taxPayment?.receipt_url || null,
      },
      orders,
      tasks,
    });
  } catch (e) {
    console.error('performance /sahla-payments/:id/orders GET', e);
    return res.status(500).json({ success: false, error: e.message || 'Failed to load order details' });
  }
});

router.post('/sahla-payments/:id/approve', requirePerformanceAuth, async (req, res) => {
  try {
    const courierId = req.params.id;
    if (!courierId) {
      return res.status(400).json({ success: false, error: 'Courier ID is required' });
    }

    const { data: courier, error: courierErr } = await supabaseAdmin
      .from('delivery_personnel')
      .select('id, user_id, delivery_name, work_phone, sahla_tax, credit, tax_payment')
      .eq('id', courierId)
      .maybeSingle();

    if (courierErr || !courier) {
      return res.status(404).json({ success: false, error: 'Courier not found' });
    }

    const taxPayment = courier.tax_payment && typeof courier.tax_payment === 'object' ? courier.tax_payment : null;
    const status = taxPayment?.status;
    if (!taxPayment || (status !== 'pending' && status !== 'auto_generated')) {
      return res.status(400).json({ success: false, error: 'No active pending or auto-generated payment found' });
    }

    const orders = Array.isArray(taxPayment.orders) ? taxPayment.orders : [];
    const tasks = Array.isArray(taxPayment.tasks) ? taxPayment.tasks : [];

    const orderIds = orders.map((o) => o.order_id || o.id).filter(Boolean);
    if (orderIds.length > 0) {
      await supabaseAdmin.from('orders').update({ tax_paid: true }).in('id', orderIds);
    }

    const taskIds = tasks.map((t) => t.task_id || t.id).filter(Boolean);
    if (taskIds.length > 0) {
      await supabaseAdmin.from('tasks').update({ tax_paid: true }).in('id', taskIds);
    }

    const now = new Date().toISOString();
    const paymentNumber = taxPayment.payment_number || `SAHLA-${new Date().getFullYear()}-${Math.floor(1000 + Math.random() * 9000)}`;
    const totalTax = Number(taxPayment.total_tax_amount) || Number(courier.sahla_tax) || 0;
    const netAmount = Number(taxPayment.total_amount) || totalTax;
    const credit = Number(courier.credit) || 0;

    await supabaseAdmin.from('delivery_sahla_payment_history').insert({
      delivery_personnel_id: courierId,
      payment_number: paymentNumber,
      status: 'approved',
      settlement_type: taxPayment.generated_by_admin ? 'admin_collect' : 'courier_payment',
      total_tax_amount: totalTax,
      net_amount: netAmount,
      credit_amount: credit,
      receipt_url: taxPayment.receipt_url || null,
      orders_snapshot: orders,
      tasks_snapshot: tasks,
      metadata: {
        approved_by: 'admin_performance_dashboard',
        approved_at: now,
        ...(taxPayment.generated_by_admin ? { generated_by_admin: true } : {}),
      },
      completed_at: now,
    });

    await supabaseAdmin.from('delivery_personnel').update({
      sahla_tax: 0.0,
      credit: 0.0,
      tax: 0.0,
      delivery_tax: 0.0,
      service_fee: 0.0,
      is_online: true,
      tax_payment: null,
      pending_collection: { orders: [], order_count: 0, total_amount: 0.0 },
      updated_at: now,
    }).eq('id', courierId);

    try {
      await supabaseAdmin.rpc('recalculate_delivery_personnel_sahla_totals', {
        p_delivery_person_id: courierId,
      });
    } catch (_) {}

    return res.json({
      success: true,
      message: `Payment ${paymentNumber} approved for ${courier.delivery_name || 'courier'}.`,
      payment_number: paymentNumber,
    });
  } catch (e) {
    console.error('performance /sahla-payments/:id/approve POST', e);
    return res.status(500).json({ success: false, error: e.message || 'Failed to approve payment' });
  }
});

router.post('/sahla-payments/:id/reject', requirePerformanceAuth, async (req, res) => {
  try {
    const courierId = req.params.id;
    const reason = (req.body?.reason || '').trim();

    const { data: courier, error: courierErr } = await supabaseAdmin
      .from('delivery_personnel')
      .select('id, delivery_name, tax_payment')
      .eq('id', courierId)
      .maybeSingle();

    if (courierErr || !courier) {
      return res.status(404).json({ success: false, error: 'Courier not found' });
    }

    const taxPayment = courier.tax_payment && typeof courier.tax_payment === 'object' ? courier.tax_payment : null;
    if (!taxPayment) {
      return res.status(400).json({ success: false, error: 'No active payment to reject' });
    }

    const now = new Date().toISOString();
    const updatedPayment = {
      ...taxPayment,
      status: 'rejected',
      rejected_at: now,
      rejected_by: 'admin_performance_dashboard',
      reject_reason: reason || 'Receipt rejected by admin',
    };

    await supabaseAdmin
      .from('delivery_personnel')
      .update({
        tax_payment: updatedPayment,
        updated_at: now,
      })
      .eq('id', courierId);

    return res.json({
      success: true,
      message: `Payment rejected for ${courier.delivery_name || 'courier'}`,
    });
  } catch (e) {
    console.error('performance /sahla-payments/:id/reject POST', e);
    return res.status(500).json({ success: false, error: e.message || 'Failed to reject payment' });
  }
});

router.post('/sahla-payments/:id/collect', requirePerformanceAuth, async (req, res) => {
  try {
    const courierId = req.params.id;
    const { data: courier, error: courierErr } = await supabaseAdmin
      .from('delivery_personnel')
      .select('id, user_id, delivery_name, work_phone, sahla_tax, credit, pending_collection')
      .eq('id', courierId)
      .maybeSingle();

    if (courierErr || !courier) {
      return res.status(404).json({ success: false, error: 'Courier not found' });
    }

    const sahlaTax = Number(courier.sahla_tax) || 0;
    const credit = Number(courier.credit) || 0;

    let orders = Array.isArray(courier.pending_collection?.orders) ? courier.pending_collection.orders : [];
    if (orders.length === 0) {
      const { data: dbOrders } = await supabaseAdmin
        .from('orders')
        .select('id, order_number, tax_amount, service_fee, delivery_tax, delivery_fee_discount')
        .eq('delivery_person_id', courierId)
        .in('status', ['delivered', 'collected'])
        .or('tax_paid.eq.false,tax_paid.is.null');
      orders = dbOrders || [];
    }

    const orderIds = orders.map((o) => o.order_id || o.id).filter(Boolean);
    if (orderIds.length > 0) {
      await supabaseAdmin.from('orders').update({ tax_paid: true }).in('id', orderIds);
    }

    let taskIds = [];
    let tasks = [];
    if (courier.user_id) {
      const { data: dbTasks } = await supabaseAdmin
        .from('tasks')
        .select('id, delivery_tax')
        .eq('delivery_man_id', courier.user_id)
        .eq('status', 'completed')
        .or('tax_paid.eq.false,tax_paid.is.null');
      tasks = dbTasks || [];
      taskIds = tasks.map((t) => t.id).filter(Boolean);
      if (taskIds.length > 0) {
        await supabaseAdmin.from('tasks').update({ tax_paid: true }).in('id', taskIds);
      }
    }

    const now = new Date().toISOString();
    const paymentNumber = `SAHLA-${new Date().getFullYear()}-${Math.floor(1000 + Math.random() * 9000)}`;

    await supabaseAdmin.from('delivery_sahla_payment_history').insert({
      delivery_personnel_id: courierId,
      payment_number: paymentNumber,
      status: 'approved',
      settlement_type: 'admin_collect',
      total_tax_amount: sahlaTax,
      net_amount: Math.max(0, sahlaTax - credit),
      credit_amount: credit,
      receipt_url: null,
      orders_snapshot: orders,
      tasks_snapshot: tasks,
      metadata: {
        admin_collected: true,
        collected_at: now,
      },
      completed_at: now,
    });

    await supabaseAdmin.from('delivery_personnel').update({
      sahla_tax: 0.0,
      credit: 0.0,
      tax: 0.0,
      delivery_tax: 0.0,
      service_fee: 0.0,
      is_online: true,
      tax_payment: null,
      pending_collection: { orders: [], order_count: 0, total_amount: 0.0 },
      updated_at: now,
    }).eq('id', courierId);

    try {
      await supabaseAdmin.rpc('recalculate_delivery_personnel_sahla_totals', {
        p_delivery_person_id: courierId,
      });
    } catch (_) {}

    return res.json({
      success: true,
      message: `Sahla Tax of ${sahlaTax} DA collected and marked paid for ${courier.delivery_name || 'courier'}.`,
      payment_number: paymentNumber,
    });
  } catch (e) {
    console.error('performance /sahla-payments/:id/collect POST', e);
    return res.status(500).json({ success: false, error: e.message || 'Failed to collect payment' });
  }
});

export default router;
