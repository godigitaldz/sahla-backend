import express from 'express';
import { handleOrderLifecycleEvent } from '../modules/orders/application/handleLifecycleEvent.js';
import {
  syncLifecycleForOrder,
} from '../modules/orders/application/scheduleOrderLifecycle.js';
import { orderLifecycleRepository } from '../modules/orders/infrastructure/orderLifecycleRepository.js';
import { verifyQstashSignature } from '../shared/security/verifyQstashSignature.js';
import { createTraceId, traceLogger } from '../shared/observability/trace.js';
import { runPendingOrdersPollOnce } from '../services/pendingOrdersPoller.js';
import { runPickupDelayAdminAlertsOnce } from '../services/pickupDelayAdminAlertsPoller.js';
import { runParcelWaitingAdminAlertsOnce } from '../services/parcelWaitingAdminAlertsPoller.js';
import { runWebOrderPushOutboxDrainerOnce } from '../services/webOrderPushOutboxDrainer.js';
import { runLifecycleSelfHealOnce } from '../services/lifecycleSelfHealService.js';
import { runLifecycleBootstrapOnce } from '../services/lifecycleBootstrapService.js';
import { runPreparingUnassignedRebroadcastOnce } from '../services/preparingUnassignedRebroadcastPoller.js';
import { acquireWindowLock } from '../services/distributedLockService.js';

const router = express.Router();

function fullRequestUrl(req) {
  const proto = req.headers['x-forwarded-proto'] || req.protocol || 'https';
  const host = req.headers['x-forwarded-host'] || req.get('host');
  return `${proto}://${host}${req.originalUrl}`;
}

router.post('/events/order-lifecycle', express.raw({ type: 'application/json' }), async (req, res) => {
  const rawBody = Buffer.isBuffer(req.body) ? req.body.toString('utf8') : '';
  const signature = req.headers['upstash-signature'];
  const traceId = createTraceId(req.headers['x-trace-id']);
  const log = traceLogger(console, traceId);

  try {
    if (!signature || !rawBody) {
      return res.status(400).json({ success: false, error: 'missing_signature_or_body' });
    }
    await verifyQstashSignature({
      signature: String(signature),
      rawBody,
      url: fullRequestUrl(req),
    });
  } catch (e) {
    log.warn('qstash signature verification failed', { error: e?.message });
    return res.status(401).json({ success: false, error: 'invalid_signature' });
  }

  try {
    const payload = JSON.parse(rawBody);
    const orderId = String(payload?.order_id || '').trim();
    const eventType = String(payload?.event_type || '').trim();
    const jobKey = orderId && eventType ? `order:${orderId}:${eventType}` : null;
    if (jobKey) {
      await orderLifecycleRepository.incrementAttempt(jobKey, null).catch(() => {});
    }
    const result = await handleOrderLifecycleEvent(payload, { logger: console });
    log.info('lifecycle event processed', {
      event_type: eventType,
      order_id: orderId,
      duplicate: Boolean(result?.duplicate),
      skipped: Boolean(result?.skipped),
    });
    return res.json({ success: true, trace_id: traceId, result });
  } catch (e) {
    try {
      const payload = JSON.parse(rawBody);
      const orderId = String(payload?.order_id || '').trim();
      const eventType = String(payload?.event_type || '').trim();
      const jobKey = orderId && eventType ? `order:${orderId}:${eventType}` : null;
      if (jobKey) {
        await orderLifecycleRepository.markJobState(jobKey, 'failed', {
          last_error: e?.message || 'handler_failed',
        });
      }
    } catch {
      // Ignore secondary failures while constructing failure metadata.
    }
    log.error('lifecycle handler failed', { error: e?.message });
    return res.status(500).json({ success: false, error: e.message || 'handler_failed', trace_id: traceId });
  }
});

router.post('/orders/:id/lifecycle/reconcile', express.json(), async (req, res) => {
  const bearer = String(req.headers.authorization || '').replace(/^Bearer\s+/i, '').trim();
  const secret = String(process.env.INTERNAL_API_TOKEN || '').trim();
  if (!secret || bearer !== secret) {
    return res.status(401).json({ success: false, error: 'Unauthorized' });
  }
  const orderId = String(req.params.id || '').trim();
  if (!orderId) {
    return res.status(400).json({ success: false, error: 'order_id_required' });
  }
  try {
    const order = await orderLifecycleRepository.getOrderById(orderId);
    if (!order) {
      return res.status(404).json({ success: false, error: 'order_not_found' });
    }
    const status = String(order.status || '').toLowerCase();
    const lifecycleVersion = Number(order.lifecycle_version || 0);
    const { scheduled, cancelled } = await syncLifecycleForOrder(order, lifecycleVersion);
    return res.json({
      success: true,
      order_id: orderId,
      status,
      scheduled,
      cancelled,
    });
  } catch (e) {
    return res.status(500).json({ success: false, error: e.message || 'reconcile_failed' });
  }
});

/**
 * Real-time scheduler hook. Called from a Supabase AFTER UPDATE trigger when
 * `orders.status` changes (or the courier assignment changes). Schedules /
 * cancels the appropriate QStash lifecycle jobs immediately so we don't wait
 * up to 2 minutes for the cron self-heal pass.
 *
 * Auth: Authorization: Bearer <CRON_SECRET> (same secret as cron route).
 * Idempotent: relies on the existing schedule*Lifecycle upserts.
 */
router.post('/orders/lifecycle-sync', express.json(), async (req, res) => {
  const bearer = String(req.headers.authorization || '')
    .replace(/^Bearer\s+/i, '')
    .trim();
  const secret = String(process.env.CRON_SECRET || '').trim();
  if (!secret || bearer !== secret) {
    return res.status(401).json({ success: false, error: 'Unauthorized' });
  }

  const orderId = String(req.body?.id || req.body?.order_id || '').trim();
  if (!orderId) {
    return res.status(400).json({ success: false, error: 'order_id_required' });
  }

  try {
    const order = await orderLifecycleRepository.getOrderById(orderId);
    if (!order) {
      return res.status(404).json({ success: false, error: 'order_not_found' });
    }
    const status = String(order.status || '').toLowerCase();
    const lifecycleVersion = Number(order.lifecycle_version || 0);
    const hasCourier = String(order.delivery_person_id || '').trim().length > 0;
    const { scheduled, cancelled } = await syncLifecycleForOrder(order, lifecycleVersion);

    return res.json({
      success: true,
      order_id: orderId,
      status,
      has_courier: hasCourier,
      scheduled,
      cancelled,
    });
  } catch (e) {
    return res.status(500).json({ success: false, error: e?.message || 'lifecycle_sync_failed' });
  }
});

router.post('/orders/created', express.json(), async (req, res) => {
  const bearer = String(req.headers.authorization || '').replace(/^Bearer\s+/i, '').trim();
  const secret = String(process.env.INTERNAL_API_TOKEN || '').trim();
  if (!secret || bearer !== secret) {
    return res.status(401).json({ success: false, error: 'Unauthorized' });
  }
  const orderId = String(req.body?.id || req.body?.order_id || '').trim();
  if (!orderId) {
    return res.status(400).json({ success: false, error: 'order_id_required' });
  }
  try {
    const order = await orderLifecycleRepository.getOrderById(orderId);
    if (!order) {
      return res.status(404).json({ success: false, error: 'order_not_found' });
    }
    const status = String(order.status || '').toLowerCase();
    const lifecycleVersion = Number(order.lifecycle_version || 0);
    const { scheduled, cancelled } = await syncLifecycleForOrder(order, lifecycleVersion);
    return res.json({
      success: true,
      order_id: orderId,
      status,
      scheduled,
      cancelled,
    });
  } catch (e) {
    return res.status(500).json({ success: false, error: e.message || 'order_created_hook_failed' });
  }
});

/**
 * Cron entrypoint hit by Vercel Cron + GitHub Actions (every 1–2 minutes).
 *
 * Responsibilities:
 *   1. Self-heal QStash scheduling for orders inserted directly into Supabase
 *      (Flutter bypasses POST /api/orders, so schedulePendingLifecycle was
 *      never called at order creation).
 *   2. Bridge legacy escalation polling for any pending/picked_up order whose
 *      QStash job did not fire (handles QStash outages or backlog).
 *   3. Pickup-delay admin alerts (kept as defense-in-depth).
 *
 * Auth: Authorization: Bearer <CRON_SECRET>. No query-string fallback.
 * Idempotency: per-window distributed lock keyed by 60s bucket.
 */
async function runCronTick(req, res) {
  const bearer = String(req.headers.authorization || '')
    .replace(/^Bearer\s+/i, '')
    .trim();
  const secret = String(process.env.CRON_SECRET || '').trim();
  if (!secret || bearer !== secret) {
    return res.status(401).json({ success: false, error: 'Unauthorized' });
  }

  const traceId = createTraceId(req.headers['x-trace-id']);
  const log = traceLogger(console, traceId);

  const acquired = await acquireWindowLock({
    key: 'pending-orders-poll',
    ttlMs: 60_000,
    logger: log,
  });
  if (!acquired) {
    return res.json({
      success: true,
      trace_id: traceId,
      skipped: true,
      reason: 'window_locked',
    });
  }

  const tickStartedAt = Date.now();
  const totalBudgetMs = Number(process.env.CRON_TICK_BUDGET_MS || 45_000);
  const remainingMs = () => Math.max(0, totalBudgetMs - (Date.now() - tickStartedAt));

  const result = {
    trace_id: traceId,
    self_heal: null,
    lifecycle_bootstrap: null,
    pending_poll: null,
    preparing_unassigned_rebroadcast: null,
    pickup_alerts: null,
    parcel_alerts: null,
    web_order_push_drainer: null,
    errors: [],
    elapsed_ms: 0,
  };

  try {
    const selfHealBudget = Math.min(20_000, remainingMs());
    result.self_heal = await runLifecycleSelfHealOnce({
      budgetMs: selfHealBudget,
      logger: log,
    });
  } catch (e) {
    result.errors.push({ stage: 'self_heal', error: e?.message || String(e) });
    log.error('cron self-heal failed', { error: e?.message });
  }

  if (remainingMs() > 3_000) {
    try {
      result.lifecycle_bootstrap = await runLifecycleBootstrapOnce({ logger: log });
    } catch (e) {
      result.errors.push({ stage: 'lifecycle_bootstrap', error: e?.message || String(e) });
      log.error('cron lifecycle bootstrap failed', { error: e?.message });
    }
  } else {
    result.lifecycle_bootstrap = { skipped: true, reason: 'budget_exhausted' };
  }

  if (remainingMs() > 5_000) {
    try {
      result.pending_poll = await runPendingOrdersPollOnce({ logger: log });
    } catch (e) {
      result.errors.push({ stage: 'pending_poll', error: e?.message || String(e) });
      log.error('cron pending poll failed', { error: e?.message });
    }
  } else {
    result.pending_poll = { skipped: true, reason: 'budget_exhausted' };
  }

  if (remainingMs() > 5_000) {
    try {
      result.preparing_unassigned_rebroadcast = await runPreparingUnassignedRebroadcastOnce({ logger: log });
    } catch (e) {
      result.errors.push({ stage: 'preparing_unassigned_rebroadcast', error: e?.message || String(e) });
      log.error('cron preparing unassigned rebroadcast failed', { error: e?.message });
    }
  } else {
    result.preparing_unassigned_rebroadcast = { skipped: true, reason: 'budget_exhausted' };
  }

  if (remainingMs() > 5_000) {
    try {
      result.pickup_alerts = await runPickupDelayAdminAlertsOnce({ logger: log });
    } catch (e) {
      result.errors.push({ stage: 'pickup_alerts', error: e?.message || String(e) });
      log.error('cron pickup alerts failed', { error: e?.message });
    }
  } else {
    result.pickup_alerts = { skipped: true, reason: 'budget_exhausted' };
  }

  if (remainingMs() > 5_000) {
    try {
      result.parcel_alerts = await runParcelWaitingAdminAlertsOnce({ logger: log });
    } catch (e) {
      result.errors.push({ stage: 'parcel_alerts', error: e?.message || String(e) });
      log.error('cron parcel alerts failed', { error: e?.message });
    }
  } else {
    result.parcel_alerts = { skipped: true, reason: 'budget_exhausted' };
  }

  if (remainingMs() > 5_000) {
    try {
      result.web_order_push_drainer = await runWebOrderPushOutboxDrainerOnce({ logger: log });
    } catch (e) {
      result.errors.push({ stage: 'web_order_push_drainer', error: e?.message || String(e) });
      log.error('cron web order push drainer failed', { error: e?.message });
    }
  } else {
    result.web_order_push_drainer = { skipped: true, reason: 'budget_exhausted' };
  }

  result.elapsed_ms = Date.now() - tickStartedAt;
  return res.json({ success: true, ...result });
}

router.get('/pending-orders-poll', runCronTick);
router.post('/pending-orders-poll', runCronTick);

export default router;
