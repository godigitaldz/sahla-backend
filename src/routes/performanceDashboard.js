import crypto from 'node:crypto';
import { Router } from 'express';

import { supabaseAdmin } from '../config/supabase.js';
import { runPendingOrdersPollOnce } from '../services/pendingOrdersPoller.js';
import { runPickupDelayAdminAlertsOnce } from '../services/pickupDelayAdminAlertsPoller.js';

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
  const assignedIso = hasCourier ? o.updated_at : null;
  const agoMin = assignedIso != null ? ageMinutes(assignedIso) : null;
  return {
    ...o,
    courier_display_name: name,
    courier_display_phone: phone,
    courier_assigned_at_iso: assignedIso,
    courier_assigned_ago_minutes: agoMin,
    courier_assigned_ago_label: hasCourier ? assignedAgoLabel(agoMin) : null,
    /** Orders have no dedicated assignment timestamp; `updated_at` is a best-effort proxy. */
    courier_assigned_time_exact: false,
  };
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

router.post('/auth', (req, res) => {
  const pwd = String(req.body?.password ?? '');
  if (!safeEqualUtf8(pwd, dashboardPassword())) {
    return res.status(401).json({ success: false, error: 'Invalid password' });
  }
  const token = signSession();
  const secure = !!(process.env.VERCEL || process.env.NODE_ENV === 'production');
  res.cookie(COOKIE_NAME, token, {
    httpOnly: true,
    secure,
    sameSite: 'lax',
    maxAge: 12 * 3600 * 1000,
    path: '/',
  });
  return res.json({ success: true });
});

router.post('/logout', requirePerformanceAuth, (req, res) => {
  res.clearCookie(COOKIE_NAME, { path: '/' });
  return res.json({ success: true });
});

router.get('/meta', requirePerformanceAuth, async (req, res) => {
  try {
    const [rRest, rPer, cDm, cR, reviewer, newReviewsGlobal] = await Promise.all([
      supabaseAdmin.from('restaurants').select('id,name').order('name'),
      supabaseAdmin.from('delivery_personnel').select('user_id'),
      supabaseAdmin
        .from('delivery_man_requests')
        .select('id', { count: 'exact', head: true })
        .eq('status', 'pending'),
      supabaseAdmin
        .from('restaurant_requests')
        .select('id', { count: 'exact', head: true })
        .eq('status', 'pending'),
      resolvePerformanceReviewer(),
      countNewRestaurantReviewsInWindow(null),
    ]);
    if (rRest.error) throw rRest.error;
    if (rPer.error) throw rPer.error;
    if (cDm.error) throw cDm.error;
    if (cR.error) throw cR.error;

    const restaurants = rRest.data || [];
    const personnel = rPer.data || [];
    const pendingDeliveryManRequests = cDm.count ?? 0;
    const pendingRestaurantRequests = cR.count ?? 0;

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

    return res.json({
      success: true,
      restaurants,
      couriers,
      pending_delivery_man_requests: pendingDeliveryManRequests,
      pending_restaurant_requests: pendingRestaurantRequests,
      new_restaurant_reviews_in_window: newReviewsGlobal,
      new_restaurant_reviews_hours: newReviewThresholdHours(),
      admin_phone: reviewer.adminPhone,
      admin_profile: reviewer.adminProfile,
      admin_reviewer_label: reviewer.reviewedBy,
    });
  } catch (e) {
    console.error('performance /meta', e);
    return res.status(500).json({ success: false, error: e.message || 'Query failed' });
  }
});

router.get('/delivery-man-requests', requirePerformanceAuth, async (req, res) => {
  try {
    const status = String(req.query.status || 'pending').trim() || 'pending';
    let q = supabaseAdmin
      .from('delivery_man_requests')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(200);
    if (status !== 'all') q = q.eq('status', status);
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
    const status = String(req.query.status || 'pending').trim() || 'pending';
    let q = supabaseAdmin
      .from('restaurant_requests')
      .select('*')
      .order('created_at', { ascending: false })
      .limit(200);
    if (status !== 'all') q = q.eq('status', status);
    const { data, error } = await q;
    if (error) throw error;
    return res.json({ success: true, requests: data || [] });
  } catch (e) {
    console.error('performance /restaurant-requests', e);
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
        vehicle_brand: vehicleBrand,
        vehicle_model: vehicleModel,
        vehicle_color: request.vehicle_color ?? null,
        vehicle_year: vehicleYear,
        delivery_name: request.full_name,
        work_phone: request.phone,
        is_available: true,
        is_online: true,
        rating: 0,
        total_deliveries: 0,
        created_at: now,
        updated_at: now,
      };
      const { data: ins, error: insE } = await supabaseAdmin
        .from('delivery_personnel')
        .insert(insertPayload)
        .select('id')
        .maybeSingle();
      if (insE) throw insE;
      personnelOk = Boolean(ins?.id);
    } else {
      const { data: upd, error: updE } = await supabaseAdmin
        .from('delivery_personnel')
        .update({
          license_number: request.plate_number,
          vehicle_plate: request.plate_number,
          vehicle_type: request.vehicle_type,
          vehicle_brand: vehicleBrand,
          vehicle_model: vehicleModel,
          vehicle_color: request.vehicle_color ?? null,
          vehicle_year: vehicleYear,
          delivery_name: request.full_name,
          work_phone: request.phone,
          updated_at: now,
        })
        .eq('id', existing.id)
        .select('id');
      if (updE) throw updE;
      personnelOk = Boolean(upd?.length);
    }

    if (!personnelOk) {
      return res.status(500).json({
        success: false,
        error: 'Could not create or update delivery_personnel',
      });
    }

    return res.json({ success: true, reviewed_by: reviewedBy });
  } catch (e) {
    console.error('performance delivery-man approve', e);
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
      return res.status(400).json({ success: false, error: 'reason is required' });
    }
    const { reviewedBy } = await resolvePerformanceReviewer();
    const now = new Date().toISOString();

    const { data: rows, error } = await supabaseAdmin
      .from('delivery_man_requests')
      .update({
        status: 'rejected',
        rejection_reason: reason.slice(0, 2000),
        reviewed_by: reviewedBy,
        reviewed_at: now,
        updated_at: now,
      })
      .eq('id', id)
      .eq('status', 'pending')
      .select('id');
    if (error) throw error;
    if (!rows?.length) {
      return res.status(404).json({ success: false, error: 'Pending delivery request not found' });
    }
    return res.json({ success: true });
  } catch (e) {
    console.error('performance delivery-man reject', e);
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

    const { data: updRows, error: u1 } = await supabaseAdmin
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
    if (!updRows?.length) {
      return res.status(409).json({ success: false, error: 'Request is no longer pending' });
    }

    const { error: u2 } = await supabaseAdmin
      .from('user_profiles')
      .update({ role: 'restaurant_owner', updated_at: now })
      .eq('id', request.user_id);
    if (u2) throw u2;

    const openingHoursJson = openingHoursPayload(request.opening_hours);
    const restaurantPayload = {
      name: request.restaurant_name,
      description: request.restaurant_description,
      address_line1: request.restaurant_address,
      address_line2: request.address_line2 ?? null,
      phone: request.restaurant_phone,
      email: request.email ?? null,
      wilaya: request.wilaya ?? null,
      city: request.city || request.wilaya || '',
      state: request.state || request.wilaya || '',
      postal_code: request.postal_code || '',
      opening_hours: openingHoursJson,
      closing_hours: openingHoursJson,
      logo_url: request.logo_url ?? null,
      cover_image_url: request.cover_image_url ?? null,
      latitude: request.latitude ?? null,
      longitude: request.longitude ?? null,
      owner_id: request.user_id,
      instagram: request.instagram ?? null,
      facebook: request.facebook ?? null,
      tiktok: request.tiktok ?? null,
      is_open: true,
      created_at: now,
      updated_at: now,
    };

    const { error: insE } = await supabaseAdmin.from('restaurants').insert(restaurantPayload);
    if (insE) throw insE;

    return res.json({ success: true, reviewed_by: reviewedBy });
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
      return res.status(400).json({ success: false, error: 'reason is required' });
    }
    const { reviewedBy } = await resolvePerformanceReviewer();
    const now = new Date().toISOString();

    const { data: rows, error } = await supabaseAdmin
      .from('restaurant_requests')
      .update({
        status: 'rejected',
        rejection_reason: reason.slice(0, 2000),
        reviewed_by: reviewedBy,
        reviewed_at: now,
        updated_at: now,
      })
      .eq('id', id)
      .eq('status', 'pending')
      .select('id');
    if (error) throw error;
    if (!rows?.length) {
      return res.status(404).json({ success: false, error: 'Pending restaurant request not found' });
    }
    return res.json({ success: true });
  } catch (e) {
    console.error('performance restaurant reject', e);
    return res.status(500).json({ success: false, error: e.message || 'Reject failed' });
  }
});

router.get('/orders', requirePerformanceAuth, async (req, res) => {
  try {
    let q = supabaseAdmin
      .from('orders')
      .select(
        `
        id,
        order_number,
        status,
        restaurant_id,
        delivery_person_id,
        created_at,
        updated_at,
        total_amount,
        restaurant:restaurants(id,name),
        delivery_personnel(
          id,
          delivery_name,
          work_phone,
          user:user_id(name,phone)
        )
      `,
      )
      .order('created_at', { ascending: false })
      .limit(300);

    const status = String(req.query.status || '').trim();
    const restaurantId = String(req.query.restaurant_id || '').trim();
    if (status) q = q.eq('status', status);
    if (restaurantId) q = q.eq('restaurant_id', restaurantId);

    const { data, error } = await q;
    if (error) throw error;
    const orders = (data || []).map(enrichOrderCourier);
    return res.json({ success: true, orders });
  } catch (e) {
    console.error('performance /orders', e);
    return res.status(500).json({ success: false, error: e.message || 'Query failed' });
  }
});

router.get('/alerts', requirePerformanceAuth, async (req, res) => {
  try {
    const minutes = alertThresholdMinutes();

    const [cDm, cR, newReviewsGlobal] = await Promise.all([
      supabaseAdmin
        .from('delivery_man_requests')
        .select('id', { count: 'exact', head: true })
        .eq('status', 'pending'),
      supabaseAdmin
        .from('restaurant_requests')
        .select('id', { count: 'exact', head: true })
        .eq('status', 'pending'),
      countNewRestaurantReviewsInWindow(null),
    ]);
    if (cDm.error) throw cDm.error;
    if (cR.error) throw cR.error;

    const { data: staleOrders, error: e1 } = await supabaseAdmin
      .from('orders')
      .select(
        `
        id,
        order_number,
        status,
        restaurant_id,
        delivery_person_id,
        created_at,
        updated_at,
        total_amount,
        restaurant:restaurants(id,name),
        delivery_personnel(
          id,
          delivery_name,
          work_phone,
          user:user_id(name,phone)
        )
      `,
      )
      .eq('status', 'pending')
      .order('created_at', { ascending: true })
      .limit(500);
    if (e1) throw e1;

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

    /**
     * Supplementary only: when the performance dashboard is open it polls this route often,
     * so we can piggy-back the same push logic on a throttle. This does NOT replace a real
     * schedule (GitHub Actions / Vercel Cron / external) — alerts stop if nobody loads alerts.
     */
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
      pending_delivery_man_requests: cDm.count ?? 0,
      pending_restaurant_requests: cR.count ?? 0,
      new_restaurant_reviews_in_window: newReviewsGlobal,
      new_restaurant_reviews_hours: newReviewThresholdHours(),
    });
  } catch (e) {
    console.error('performance /alerts', e);
    return res.status(500).json({ success: false, error: e.message || 'Query failed' });
  }
});

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
