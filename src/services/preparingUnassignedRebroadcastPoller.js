import { supabaseAdmin } from '../config/supabase.js';
import { getActiveAdminUserIds } from './adminRecipients.js';
import {
  getOnlineAvailableCourierUserIds,
  isCourierDeliverableOrder,
} from '../modules/notifications/orderRebroadcastRecipients.js';
import {
  PREPARING_UNASSIGNED_EPISODE_MAX_SECONDS,
  episodeDispatchKey,
} from '../modules/orders/domain/preparingUnassignedEpisode.js';
import { sendPushWithDispatch } from './notificationDispatchService.js';
import { pushSendSucceeded } from '../modules/notifications/pushSendResult.js';

const COURIER_REBROADCAST_INTERVAL_MS = 3 * 60_000;
const ADMIN_UNASSIGNED_THRESHOLD_MS = 5 * 60_000;
const ADMIN_UNASSIGNED_ALERT_TYPE = 'admin_preparing_unassigned_5m';
const COURIER_UNASSIGNED_FLOW = 'order_preparing_unassigned_rebroadcast';
const MAX_ORDERS_PER_RUN = 50;

function safeIsoDate(msAgo = 0) {
  return new Date(Date.now() - msAgo).toISOString();
}

/**
 * Rebroadcasts preparing/ready orders with unassigned couriers to online couriers
 * every 3 minutes, and alerts admins if an order remains unassigned after 5 minutes.
 *
 * @param {Object} options
 * @param {Object} [options.logger=console]
 * @returns {Promise<Object>} stats
 */
export async function runPreparingUnassignedRebroadcastOnce({ logger = console } = {}) {
  const stats = {
    unassigned_due: 0,
    couriers_online: 0,
    admins: 0,
    sent_courier_rebroadcasts: 0,
    sent_admin_alerts: 0,
    error: null,
  };

  try {
    const lookbackIso = safeIsoDate(PREPARING_UNASSIGNED_EPISODE_MAX_SECONDS * 1000);
    const { data: unassignedOrders, error: queryError } = await supabaseAdmin
      .from('orders')
      .select('id, order_number, status, restaurant_id, delivery_person_id, fulfillment_type, parcel_sender_id, created_at, updated_at, courier_unassigned_episode_at')
      .in('status', ['preparing', 'ready'])
      .is('delivery_person_id', null)
      .gte('updated_at', lookbackIso)
      .order('updated_at', { ascending: true })
      .limit(MAX_ORDERS_PER_RUN);

    if (queryError) {
      logger.error?.('[preparing-unassigned-rebroadcast] query failed:', queryError.message);
      stats.error = queryError.message;
      return stats;
    }

    const eligibleOrders = (unassignedOrders ?? []).filter((order) => isCourierDeliverableOrder(order));
    stats.unassigned_due = eligibleOrders.length;
    if (eligibleOrders.length === 0) {
      return stats;
    }

    const [courierIds, adminIds] = await Promise.all([
      getOnlineAvailableCourierUserIds(logger).catch(() => []),
      getActiveAdminUserIds(logger).catch(() => []),
    ]);

    stats.couriers_online = courierIds.length;
    stats.admins = adminIds.length;

    const candidateIds = (eligibleOrders ?? []).map((o) => String(o?.id ?? '')).filter(Boolean);
    if (candidateIds.length === 0) return stats;

    // Fetch dedupe logs from last 30 minutes for candidate orders only
    const dedupeSinceIso = safeIsoDate(30 * 60_000);
    const [logsRes, dispatchesRes] = await Promise.all([
      supabaseAdmin
        .from('push_notifications_log')
        .select('data, created_at')
        .eq('status', 'sent')
        .gte('created_at', dedupeSinceIso)
        .in('data->>order_id', candidateIds),
      supabaseAdmin
        .from('notification_dispatch_log')
        .select('dispatch_key, order_id, status')
        .eq('status', 'sent')
        .in('order_id', candidateIds),
    ]);

    if (logsRes.error) {
      logger.warn?.('[preparing-unassigned-rebroadcast] log query failed, continuing:', logsRes.error.message);
    }
    if (dispatchesRes.error) {
      logger.warn?.('[preparing-unassigned-rebroadcast] dispatch query failed, continuing:', dispatchesRes.error.message);
    }

    const logs = logsRes.data ?? [];
    const sentDispatchKeys = new Set((dispatchesRes.data ?? []).map((r) => r.dispatch_key).filter(Boolean));
    const now = Date.now();

    for (const order of eligibleOrders) {
      const orderId = String(order.id ?? '');
      const orderNumber = String(order.order_number ?? orderId);
      const episodeRef = order.courier_unassigned_episode_at || order.updated_at || order.created_at;
      const episodeMs = Date.parse(String(episodeRef ?? ''));
      const ageMs = Number.isFinite(episodeMs) ? now - episodeMs : 0;

      // Skip if beyond max rebroadcast window (25 min)
      if (ageMs >= PREPARING_UNASSIGNED_EPISODE_MAX_SECONDS * 1000) {
        continue;
      }

      // Check last courier rebroadcast time for this order (scheduled or manual)
      const lastCourierPush = logs
        .filter(
          (l) =>
            l?.data?.order_id === orderId &&
            (l?.data?.flow === COURIER_UNASSIGNED_FLOW ||
              l?.data?.flow === 'admin_track_manual_preparing_unassigned_rebroadcast' ||
              l?.data?.type === 'order_available' ||
              l?.data?.type === 'courier_order_available'),
        )
        .sort((a, b) => Date.parse(b.created_at) - Date.parse(a.created_at))[0];

      const lastPushAgeMs = lastCourierPush ? now - Date.parse(lastCourierPush.created_at) : Number.POSITIVE_INFINITY;

      if (lastPushAgeMs >= COURIER_REBROADCAST_INTERVAL_MS && courierIds.length > 0) {
        const bucket = Math.floor(now / COURIER_REBROADCAST_INTERVAL_MS);
        const courierDispatchKey = `order:${orderId}:preparing_unassigned:courier:${bucket}`;

        const invokeRes = await sendPushWithDispatch({
          dispatchKey: courierDispatchKey,
          orderId,
          cohort: 'admin',
          userIds: courierIds,
          title: 'طلب متاح',
          body: `الطلب #${orderNumber} جاهز لتعيين سائق.`,
          data: {
            type: 'order_available',
            stage: 'preparing_unassigned',
            flow: COURIER_UNASSIGNED_FLOW,
            order_id: orderId,
            order_number: orderNumber,
            restaurant_id: String(order.restaurant_id || ''),
            source: 'backend_preparing_unassigned_rebroadcast',
          },
          logger,
        });

        if (pushSendSucceeded(invokeRes) && !invokeRes.skipped) {
          stats.sent_courier_rebroadcasts += 1;
        } else if (!invokeRes?.skipped) {
          logger.error?.(
            `[preparing-unassigned-rebroadcast] courier push failed order=${orderId}: ${invokeRes?.error ?? 'unknown'}`,
          );
        }
      }

      // Admin escalation alert at 5 minutes
      if (ageMs >= ADMIN_UNASSIGNED_THRESHOLD_MS && adminIds.length > 0) {
        const adminKey = episodeDispatchKey(orderId, '5m:admin', order.courier_unassigned_episode_at);
        const alreadyAlertedInLogs = logs.some(
          (l) => l?.data?.order_id === orderId && l?.data?.flow === ADMIN_UNASSIGNED_ALERT_TYPE,
        );
        const alreadyAlertedInDispatch = sentDispatchKeys.has(adminKey);

        if (!alreadyAlertedInLogs && !alreadyAlertedInDispatch) {
          const adminRes = await sendPushWithDispatch({
            dispatchKey: adminKey,
            orderId,
            cohort: 'admin',
            userIds: adminIds,
            title: 'تحضير بدون سائق',
            body: `الطلب #${orderNumber} قيد التحضير/الجاهزية ولم يُعيَّن أي عامل توصيل — منذ 5 دقائق.`,
            data: {
              type: 'admin_order_alert',
              stage: 'preparing_unassigned_5m',
              flow: ADMIN_UNASSIGNED_ALERT_TYPE,
              order_id: orderId,
              order_number: orderNumber,
              source: 'backend_preparing_unassigned_rebroadcast',
            },
            logger,
          });

          if (pushSendSucceeded(adminRes) && !adminRes.skipped) {
            stats.sent_admin_alerts += 1;
            sentDispatchKeys.add(adminKey);
          } else if (!adminRes?.skipped) {
            logger.error?.(
              `[preparing-unassigned-rebroadcast] admin alert push failed order=${orderId}: ${adminRes?.error ?? 'unknown'}`,
            );
          }
        }
      }
    }

    return stats;
  } catch (err) {
    logger.error?.('[preparing-unassigned-rebroadcast] unexpected error:', err);
    stats.error = err?.message ?? String(err);
    return stats;
  }
}
