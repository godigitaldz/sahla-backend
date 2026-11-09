import { pushSendSucceeded } from '../modules/notifications/pushSendResult.js';
import { supabaseAdmin } from '../config/supabase.js';
import { getActiveAdminUserIds } from './adminRecipients.js';
import { sendPushWithDispatch } from './notificationDispatchService.js';

const DEFAULT_PREPARING_ASSIGNED_DELAY_MINUTES = 20;
const LOOKBACK_HOURS = 24;

function parseEnabled(value, defaultTrue = true) {
  if (value == null) return defaultTrue;
  const normalized = String(value).trim().toLowerCase();
  if (['0', 'false', 'no', 'off'].includes(normalized)) return false;
  if (['1', 'true', 'yes', 'on'].includes(normalized)) return true;
  return defaultTrue;
}

function safeIsoDate(msAgo = 0) {
  return new Date(Date.now() - msAgo).toISOString();
}

/**
 * Checks for orders currently in 'preparing' or 'ready' that have a courier assigned
 * but have not been picked up within the threshold (default: 20 minutes since courier assignment).
 *
 * Sends:
 * 1. Admin escalation push alert (سائق معيَّن ولم يستلم).
 * 2. Courier reminder push (تذكير بالاستلام).
 *
 * Uses durable idempotency keys to ensure notifications are not spammed.
 *
 * @param {Object} [options]
 * @param {Object} [options.logger=console]
 * @returns {Promise<Object>} stats
 */
export async function runPreparingAssignedDelayAdminAlertsOnce({ logger = console } = {}) {
  const stats = {
    candidates: 0,
    sent_admin_alerts: 0,
    sent_courier_reminders: 0,
    skipped_no_recipients: false,
    error: null,
  };

  if (!parseEnabled(process.env.ENABLE_PREPARING_ASSIGNED_ADMIN_ALERTS, true)) {
    return stats;
  }

  const thresholdMinutes =
    Number(process.env.PREPARING_ASSIGNED_ALERT_THRESHOLD_MINUTES) ||
    DEFAULT_PREPARING_ASSIGNED_DELAY_MINUTES;

  const thresholdMs = thresholdMinutes * 60_000;
  const thresholdIso = safeIsoDate(thresholdMs);
  const lookbackIso = safeIsoDate(LOOKBACK_HOURS * 3600_000);
  const now = Date.now();

  try {
    const adminIds = await getActiveAdminUserIds(logger).catch(() => []);

    // Query active food orders in preparing/ready with courier assigned
    const { data: orders, error: ordersErr } = await supabaseAdmin
      .from('orders')
      .select(`
        id,
        order_number,
        status,
        delivery_person_id,
        courier_assigned_at,
        updated_at,
        restaurant_id,
        restaurant:restaurant_id (
          id,
          name
        ),
        courier:delivery_person_id (
          id,
          user_id,
          delivery_name
        )
      `)
      .in('status', ['preparing', 'ready'])
      .not('delivery_person_id', 'is', null)
      .is('parcel_sender_id', null)
      .gte('created_at', lookbackIso)
      .or(`courier_assigned_at.lte.${thresholdIso},and(courier_assigned_at.is.null,updated_at.lte.${thresholdIso})`)
      .order('created_at', { ascending: true })
      .limit(60);

    if (ordersErr) {
      logger.error?.('[preparing-assigned-delay] query failed:', ordersErr.message);
      stats.error = ordersErr.message;
      return stats;
    }

    const candidates = orders ?? [];
    stats.candidates = candidates.length;
    if (candidates.length === 0) {
      return stats;
    }

    for (const order of candidates) {
      const orderId = String(order.id || '');
      const orderNumber = String(order.order_number || orderId);
      const restaurantName = order.restaurant?.name || 'المطعم';
      const courierName = order.courier?.delivery_name || 'السائق';
      const courierUserId = order.courier?.user_id;

      const assignedMs = Date.parse(String(order.courier_assigned_at || order.updated_at || ''));
      const ageMinutes = Number.isFinite(assignedMs)
        ? Math.max(thresholdMinutes, Math.floor((now - assignedMs) / 60_000))
        : thresholdMinutes;

      // 1. Admin Alert
      if (adminIds.length > 0) {
        const adminDispatchKey = `order:${orderId}:preparing_assigned:20m:admin`;
        const adminSent = await sendPushWithDispatch({
          dispatchKey: adminDispatchKey,
          orderId,
          cohort: 'admin',
          userIds: adminIds,
          title: 'سائق معيَّن ولم يستلم',
          body: `الطلب #${orderNumber} (${restaurantName}) مُعيَّن للسائق (${courierName}) منذ ${ageMinutes} دقيقة ولم يتم استلامه بعد.`,
          data: {
            type: 'admin_order_alert',
            stage: 'preparing_assigned_no_pickup',
            flow: 'admin_preparing_assigned_20m',
            order_id: orderId,
            order_number: orderNumber,
            assigned_age_minutes: String(ageMinutes),
          },
        });

        if (pushSendSucceeded(adminSent)) {
          stats.sent_admin_alerts += 1;
        }
      } else {
        stats.skipped_no_recipients = true;
      }

      // 2. Courier Pickup Reminder Push
      if (courierUserId) {
        const courierDispatchKey = `order:${orderId}:preparing_assigned:20m:courier`;
        const courierSent = await sendPushWithDispatch({
          dispatchKey: courierDispatchKey,
          orderId,
          cohort: 'delivery_man',
          userIds: [courierUserId],
          title: 'تذكير باستلام الطلب',
          body: `الطلب #${orderNumber} جاهز أو قيد التحضير في (${restaurantName})، يرجى استلامه من المطعم.`,
          data: {
            type: 'courier_order_pickup_reminder',
            flow: 'courier_preparing_assigned_pickup_reminder',
            order_id: orderId,
            order_number: orderNumber,
          },
        });

        if (pushSendSucceeded(courierSent)) {
          stats.sent_courier_reminders += 1;
        }
      }
    }

    return stats;
  } catch (error) {
    logger.error?.('[preparing-assigned-delay] unexpected error:', error);
    stats.error = error?.message ?? String(error);
    return stats;
  }
}
