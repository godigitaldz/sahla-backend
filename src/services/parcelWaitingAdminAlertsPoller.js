import { supabaseAdmin } from '../config/supabase.js';
import { getActiveAdminUserIds } from './adminRecipients.js';
import { sendPushWithDispatch } from './notificationDispatchService.js';
import { pushSendSucceeded } from '../modules/notifications/pushSendResult.js';

const PARCEL_WAITING_THRESHOLD_MS = 15 * 60_000;
const PARCEL_WAITING_ALERT_TYPE = 'admin_parcel_waiting_15m';

function safeIsoDate(msAgo = 0) {
  return new Date(Date.now() - msAgo).toISOString();
}

/**
 * Checks for parcel orders that have been pending/waiting without assignment for >= 15 minutes,
 * and notifies active admins.
 *
 * @param {Object} options
 * @param {Object} [options.logger=console]
 * @returns {Promise<Object>}
 */
export async function runParcelWaitingAdminAlertsOnce({ logger = console } = {}) {
  const stats = {
    parcel_due: 0,
    sent_alerts: 0,
    error: null,
  };

  const enabled = !['0', 'false', 'no', 'off'].includes(
    String(process.env.ENABLE_PARCEL_WAITING_ADMIN_ALERTS ?? 'true').trim().toLowerCase(),
  );
  if (!enabled) {
    stats.skipped = true;
    return stats;
  }

  try {
    const thresholdIso = safeIsoDate(PARCEL_WAITING_THRESHOLD_MS);
    const { data: waitingParcels, error: queryErr } = await supabaseAdmin
      .from('orders')
      .select('id, order_number, created_at, parcel_sender_id, fulfillment_type')
      .eq('status', 'pending')
      .or('fulfillment_type.eq.parcel,parcel_sender_id.not.is.null')
      .lte('created_at', thresholdIso)
      .limit(50);

    if (queryErr) {
      logger.error?.('[parcel-waiting-alerts] query failed:', queryErr.message);
      stats.error = queryErr.message;
      return stats;
    }

    stats.parcel_due = (waitingParcels ?? []).length;
    if (stats.parcel_due === 0) return stats;

    const candidateIds = (waitingParcels ?? []).map((o) => String(o?.id ?? '')).filter(Boolean);
    if (candidateIds.length === 0) return stats;

    const adminIds = await getActiveAdminUserIds(logger);
    if (adminIds.length === 0) return stats;

    const dedupeSinceIso = safeIsoDate(24 * 3600_000);
    const [logsRes, dispatchesRes] = await Promise.all([
      supabaseAdmin
        .from('push_notifications_log')
        .select('data')
        .eq('status', 'sent')
        .gte('created_at', dedupeSinceIso)
        .in('data->>order_id', candidateIds),
      supabaseAdmin
        .from('notification_dispatch_log')
        .select('dispatch_key, order_id, status')
        .eq('status', 'sent')
        .in('order_id', candidateIds),
    ]);

    const alreadyAlertedIds = new Set(
      (logsRes.data ?? [])
        .filter((l) => l?.data?.flow === PARCEL_WAITING_ALERT_TYPE)
        .map((l) => l?.data?.order_id)
        .filter(Boolean),
    );

    const sentDispatchKeys = new Set(
      (dispatchesRes.data ?? []).map((r) => r.dispatch_key).filter(Boolean),
    );

    for (const order of waitingParcels) {
      const orderId = String(order.id);
      const dispatchKey = `order:${orderId}:parcel_waiting:15m:admin`;
      if (alreadyAlertedIds.has(orderId) || sentDispatchKeys.has(dispatchKey)) continue;

      const orderNumber = String(order.order_number ?? orderId);
      const res = await sendPushWithDispatch({
        dispatchKey,
        orderId,
        cohort: 'admin',
        userIds: adminIds,
        title: 'طلب طرد بانتظار مندوب',
        body: `طلب الطرد #${orderNumber} قيد الانتظار منذ أكثر من 15 دقيقة دون تعيين مندوب.`,
        data: {
          type: 'admin_order_alert',
          flow: PARCEL_WAITING_ALERT_TYPE,
          order_id: orderId,
          order_number: orderNumber,
          source: 'backend_parcel_waiting_alerts',
        },
        logger,
      });

      if (pushSendSucceeded(res) && !res.skipped) {
        stats.sent_alerts += 1;
        alreadyAlertedIds.add(orderId);
        sentDispatchKeys.add(dispatchKey);
      }
    }

    return stats;
  } catch (err) {
    logger.error?.('[parcel-waiting-alerts] unexpected error:', err);
    stats.error = err?.message ?? String(err);
    return stats;
  }
}
