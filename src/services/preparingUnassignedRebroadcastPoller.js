import { supabaseAdmin } from '../config/supabase.js';
import { getActiveAdminUserIds } from './adminRecipients.js';
import {
  getOnlineAvailableCourierUserIds,
  isCourierDeliverableOrder,
} from '../modules/notifications/orderRebroadcastRecipients.js';
import {
  PREPARING_UNASSIGNED_EPISODE_MAX_SECONDS,
} from '../modules/orders/domain/preparingUnassignedEpisode.js';

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
      .select('id, order_number, status, delivery_person_id, fulfillment_type, parcel_sender_id, created_at, updated_at, courier_unassigned_episode_at')
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

    // Fetch dedupe logs from last 30 minutes
    const dedupeSinceIso = safeIsoDate(30 * 60_000);
    const { data: recentLogs, error: logError } = await supabaseAdmin
      .from('push_notifications_log')
      .select('data, created_at')
      .eq('status', 'sent')
      .gte('created_at', dedupeSinceIso);

    if (logError) {
      logger.warn?.('[preparing-unassigned-rebroadcast] log query failed, continuing:', logError.message);
    }

    const logs = recentLogs ?? [];
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

      // Check last courier rebroadcast time for this order
      const lastCourierPush = logs
        .filter((l) => l?.data?.order_id === orderId && l?.data?.flow === COURIER_UNASSIGNED_FLOW)
        .sort((a, b) => Date.parse(b.created_at) - Date.parse(a.created_at))[0];

      const lastPushAgeMs = lastCourierPush ? now - Date.parse(lastCourierPush.created_at) : Number.POSITIVE_INFINITY;

      if (lastPushAgeMs >= COURIER_REBROADCAST_INTERVAL_MS && courierIds.length > 0) {
        const invokeRes = await supabaseAdmin.functions.invoke('send-push-notification', {
          body: {
            user_ids: courierIds,
            title: 'طلب متاح للتوصيل',
            body: `الطلب #${orderNumber} جاهز أو قيد التحضير وبانتظار مندوب توصيل.`,
            data: {
              type: 'courier_order_available',
              stage: 'preparing_unassigned',
              flow: COURIER_UNASSIGNED_FLOW,
              order_id: orderId,
              order_number: orderNumber,
              source: 'backend_preparing_unassigned_rebroadcast',
            },
            force_activate_inactive_tokens: true,
          },
        });

        if (!invokeRes.error && invokeRes.data?.success === true) {
          stats.sent_courier_rebroadcasts += 1;
        } else {
          logger.error?.(
            `[preparing-unassigned-rebroadcast] courier push failed order=${orderId}: ${invokeRes.error?.message ?? 'unknown'}`,
          );
        }
      }

      // Admin escalation alert at 5 minutes
      if (ageMs >= ADMIN_UNASSIGNED_THRESHOLD_MS && adminIds.length > 0) {
        const alreadyAlerted = logs.some(
          (l) => l?.data?.order_id === orderId && l?.data?.flow === ADMIN_UNASSIGNED_ALERT_TYPE,
        );

        if (!alreadyAlerted) {
          const adminRes = await supabaseAdmin.functions.invoke('send-push-notification', {
            body: {
              user_ids: adminIds,
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
              force_activate_inactive_tokens: true,
            },
          });

          if (!adminRes.error && adminRes.data?.success === true) {
            stats.sent_admin_alerts += 1;
          } else {
            logger.error?.(
              `[preparing-unassigned-rebroadcast] admin alert push failed order=${orderId}: ${adminRes.error?.message ?? 'unknown'}`,
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
