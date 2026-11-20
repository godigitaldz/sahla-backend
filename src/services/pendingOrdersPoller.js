import { supabaseAdmin } from '../config/supabase.js';
import { getActiveAdminUserIds } from './adminRecipients.js';
import { getRestaurantOpsUserIds } from '../modules/notifications/orderRebroadcastRecipients.js';
import { runPickupDelayAdminAlertsOnce } from './pickupDelayAdminAlertsPoller.js';
import { runPreparingUnassignedRebroadcastOnce } from './preparingUnassignedRebroadcastPoller.js';
import { sendPushWithDispatch } from './notificationDispatchService.js';
import { pushSendSucceeded } from '../modules/notifications/pushSendResult.js';

const DEFAULT_INTERVAL_MS = 60_000;
const FIRST_ADMIN_THRESHOLD_MS = 2 * 60_000;
const SECOND_ADMIN_THRESHOLD_MS = 5 * 60_000;
const RESTAURANT_10M_THRESHOLD_MS = 10 * 60_000;
const RESTAURANT_12M_THRESHOLD_MS = 12 * 60_000;
const DELIVERY_DELAY_THRESHOLD_MS = 15 * 60_000;
export const AUTO_CANCEL_THRESHOLD_MS = 15 * 60_000;
const MAX_ORDERS_PER_RUN = 80;
const LOOKBACK_LOG_HOURS = 48;
const ADMIN_FIRST_ALERT_TYPE = 'admin_order_pending_2m';
const ADMIN_SECOND_ALERT_TYPE = 'admin_order_pending_5m';
const ADMIN_DELIVERY_ALERT_TYPE = 'admin_delivery_picked_up_15m';
const CUSTOMER_ESCALATION_ALERT_TYPE = 'customer_order_pending_5m';
export const CUSTOMER_AUTO_CANCEL_ALERT_TYPE = 'order_auto_cancelled_15m';

function parseEnabled(value) {
  if (value == null) return true;
  const normalized = String(value).trim().toLowerCase();
  return !['0', 'false', 'no', 'off'].includes(normalized);
}

function safeIsoDate(msAgo = 0) {
  return new Date(Date.now() - msAgo).toISOString();
}

/**
 * One full escalation cycle (pending / delivery-delay / auto-cancel). Safe for Vercel Cron.
 */
export async function runPendingOrdersPollOnce({ logger = console } = {}) {
  const stats = {
    pending_due: 0,
    delivery_due: 0,
    admins: 0,
    sent_first_admin: 0,
    sent_second_admin: 0,
    sent_delivery_delayed: 0,
    sent_customer: 0,
    sent_restaurant_rebroadcasts: 0,
    auto_cancelled: 0,
  };

  try {
    const thresholdIso = safeIsoDate(FIRST_ADMIN_THRESHOLD_MS);
    const { data: dueOrders, error: ordersError } = await supabaseAdmin
      .from('orders')
      .select('id, customer_id, restaurant_id, order_number, created_at')
      .eq('status', 'pending')
      .lte('created_at', thresholdIso)
      .order('created_at', { ascending: true })
      .limit(MAX_ORDERS_PER_RUN);

    if (ordersError) {
      logger.error?.(
        '[pending-orders-poller] pending orders query failed:',
        ordersError.message,
      );
      stats.error = ordersError.message;
      return stats;
    }

    stats.pending_due = (dueOrders ?? []).length;

    const deliveryThresholdIso = safeIsoDate(DELIVERY_DELAY_THRESHOLD_MS);
    const { data: dueDeliveryOrders, error: deliveryOrdersError } =
      await supabaseAdmin
        .from('orders')
        .select('id, order_number, actual_pickup_time, updated_at')
        .eq('status', 'picked_up')
        .or(
          `actual_pickup_time.lte.${deliveryThresholdIso},and(actual_pickup_time.is.null,updated_at.lte.${deliveryThresholdIso})`,
        )
        .order('updated_at', { ascending: true })
        .limit(MAX_ORDERS_PER_RUN);

    if (deliveryOrdersError) {
      logger.error?.(
        '[pending-orders-poller] picked_up orders query failed:',
        deliveryOrdersError.message,
      );
      stats.error = deliveryOrdersError.message;
      return stats;
    }

    stats.delivery_due = (dueDeliveryOrders ?? []).length;

    if (stats.pending_due === 0 && stats.delivery_due === 0) {
      return stats;
    }

    const adminIds = await getActiveAdminUserIds(logger);
    stats.admins = adminIds.length;

    if (adminIds.length === 0) {
      logger.warn?.('[pending-orders-poller] no admin users found; skipping admin alerts');
    }

    const sinceIso = safeIsoDate(LOOKBACK_LOG_HOURS * 60 * 60_000);
    const candidateOrderIds = [
      ...(dueOrders ?? []).map((o) => String(o?.id ?? '')),
      ...(dueDeliveryOrders ?? []).map((o) => String(o?.id ?? '')),
    ].filter(Boolean);

    let sentLogs = [];
    let sentDispatches = [];
    if (candidateOrderIds.length > 0) {
      const [logsRes, dispatchesRes] = await Promise.all([
        supabaseAdmin
          .from('push_notifications_log')
          .select('data')
          .eq('status', 'sent')
          .gte('created_at', sinceIso)
          .in('data->>order_id', candidateOrderIds),
        supabaseAdmin
          .from('notification_dispatch_log')
          .select('dispatch_key, order_id, status')
          .eq('status', 'sent')
          .in('order_id', candidateOrderIds),
      ]);

      if (logsRes.error) {
        logger.error?.(
          '[pending-orders-poller] log dedupe query failed:',
          logsRes.error.message,
        );
      }
      if (dispatchesRes.error) {
        logger.warn?.(
          '[pending-orders-poller] dispatch dedupe query failed:',
          dispatchesRes.error.message,
        );
      }
      sentLogs = logsRes.data ?? [];
      sentDispatches = dispatchesRes.data ?? [];
    }

    const sentDispatchesKeys = new Set(
      sentDispatches.map((r) => r.dispatch_key).filter(Boolean),
    );

    const sentFirstStageOrderIds = new Set([
      ...(sentLogs ?? [])
        .filter((row) => String(row?.data?.flow ?? '') === ADMIN_FIRST_ALERT_TYPE)
        .map((row) => row?.data?.order_id)
        .filter((value) => typeof value === 'string'),
      ...(dueOrders ?? [])
        .map((o) => String(o?.id ?? ''))
        .filter((id) => sentDispatchesKeys.has(`order:${id}:pending:2m:admin`)),
    ]);

    const sentSecondStageOrderIds = new Set([
      ...(sentLogs ?? [])
        .filter((row) => String(row?.data?.flow ?? '') === ADMIN_SECOND_ALERT_TYPE)
        .map((row) => row?.data?.order_id)
        .filter((value) => typeof value === 'string'),
      ...(dueOrders ?? [])
        .map((o) => String(o?.id ?? ''))
        .filter((id) => sentDispatchesKeys.has(`order:${id}:pending:5m:admin`)),
    ]);

    const sentCustomerStageOrderIds = new Set([
      ...(sentLogs ?? [])
        .filter((row) => String(row?.data?.type ?? '') === CUSTOMER_ESCALATION_ALERT_TYPE)
        .map((row) => row?.data?.order_id)
        .filter((value) => typeof value === 'string'),
      ...(dueOrders ?? [])
        .map((o) => String(o?.id ?? ''))
        .filter((id) => sentDispatchesKeys.has(`order:${id}:pending:5m:user`)),
    ]);

    const sentAutoCancelOrderIds = new Set([
      ...(sentLogs ?? [])
        .filter((row) => {
          const type = String(row?.data?.type ?? '');
          return type === CUSTOMER_AUTO_CANCEL_ALERT_TYPE || type === 'order_auto_cancelled_10m';
        })
        .map((row) => row?.data?.order_id)
        .filter((value) => typeof value === 'string'),
      ...(dueOrders ?? [])
        .map((o) => String(o?.id ?? ''))
        .filter(
          (id) =>
            sentDispatchesKeys.has(`order:${id}:pending:15m:user_cancel`) ||
            sentDispatchesKeys.has(`order:${id}:pending:10m:user_cancel`),
        ),
    ]);

    const sentDeliveryAlertOrderIds = new Set([
      ...(sentLogs ?? [])
        .filter((row) => String(row?.data?.flow ?? '') === ADMIN_DELIVERY_ALERT_TYPE)
        .map((row) => row?.data?.order_id)
        .filter((value) => typeof value === 'string'),
      ...(dueDeliveryOrders ?? [])
        .map((o) => String(o?.id ?? ''))
        .filter((id) => sentDispatchesKeys.has(`order:${id}:delivery_delay:15m:admin`)),
    ]);

    const sentRestaurant2mOrderIds = new Set(
      (sentLogs ?? [])
        .filter((row) => {
          const flow = String(row?.data?.flow ?? '');
          return flow === 'pending_restaurant_rebroadcast_2m' || flow === 'lifecycle_pending_2m_restaurant_rebroadcast';
        })
        .map((row) => row?.data?.order_id)
        .filter((value) => typeof value === 'string'),
    );
    const sentRestaurant5mOrderIds = new Set(
      (sentLogs ?? [])
        .filter((row) => {
          const flow = String(row?.data?.flow ?? '');
          return flow === 'pending_restaurant_rebroadcast_5m' || flow === 'lifecycle_pending_5m_restaurant_rebroadcast';
        })
        .map((row) => row?.data?.order_id)
        .filter((value) => typeof value === 'string'),
    );
    const sentRestaurant10mOrderIds = new Set(
      (sentLogs ?? [])
        .filter((row) => {
          const flow = String(row?.data?.flow ?? '');
          return flow === 'pending_restaurant_rebroadcast_10m' || flow === 'lifecycle_pending_10m_restaurant_rebroadcast';
        })
        .map((row) => row?.data?.order_id)
        .filter((value) => typeof value === 'string'),
    );
    const sentRestaurant12mOrderIds = new Set(
      (sentLogs ?? [])
        .filter((row) => {
          const flow = String(row?.data?.flow ?? '');
          return flow === 'pending_restaurant_rebroadcast_12m' || flow === 'lifecycle_pending_12m_restaurant_rebroadcast';
        })
        .map((row) => row?.data?.order_id)
        .filter((value) => typeof value === 'string'),
    );

    let sentFirstStageCount = 0;
    let sentSecondStageCount = 0;
    let sentCustomerStageCount = 0;
    let sentRestaurantRebroadcastCount = 0;
    let autoCancelledCount = 0;
    let sentDeliveryDelayedCount = 0;

    for (const order of dueOrders ?? []) {
      const customerId = String(order.customer_id ?? '');
      const restaurantId = String(order.restaurant_id ?? '').trim();
      const orderId = String(order.id ?? '');
      const orderNumber = String(order.order_number ?? '');
      const createdAt = Date.parse(String(order.created_at ?? ''));
      if (!orderId || !orderNumber || !Number.isFinite(createdAt)) continue;

      const orderAgeMs = Date.now() - createdAt;
      const isFirstStageDue = orderAgeMs >= FIRST_ADMIN_THRESHOLD_MS;
      const isSecondStageDue = orderAgeMs >= SECOND_ADMIN_THRESHOLD_MS;
      const isRestaurant10mDue = orderAgeMs >= RESTAURANT_10M_THRESHOLD_MS;
      const isRestaurant12mDue = orderAgeMs >= RESTAURANT_12M_THRESHOLD_MS;
      const isAutoCancelDue = orderAgeMs >= AUTO_CANCEL_THRESHOLD_MS;

      // Helper for restaurant rebroadcasts
      const sendRestaurantRebroadcast = async (stage, dedupeSet) => {
        if (!restaurantId || dedupeSet.has(orderId)) return;
        try {
          const restOps = await getRestaurantOpsUserIds(restaurantId, logger);
          if (restOps.length === 0) return;
          const rbInvoke = await sendPushWithDispatch({
            dispatchKey: `order:${orderId}:restaurant_rebroadcast:${stage}`,
            orderId,
            cohort: 'admin',
            userIds: restOps,
            title: 'طلب جديد',
            body: `الطلب #${orderNumber} لا يزال معلقاً.`,
            data: {
              type: 'new_order',
              flow: `pending_restaurant_rebroadcast_${stage}`,
              order_id: orderId,
              order_number: orderNumber,
              restaurant_id: restaurantId,
              source: 'backend_pending_orders_poller',
            },
            logger,
          });
          if (pushSendSucceeded(rbInvoke) && !rbInvoke.skipped) {
            sentRestaurantRebroadcastCount += 1;
            dedupeSet.add(orderId);
          }
        } catch (e) {
          logger.warn?.(`[pending-orders-poller] restaurant ${stage} rebroadcast failed for order=${orderId}:`, e?.message);
        }
      };

      if (isFirstStageDue) {
        await sendRestaurantRebroadcast('2m', sentRestaurant2mOrderIds);
      }
      if (isSecondStageDue) {
        await sendRestaurantRebroadcast('5m', sentRestaurant5mOrderIds);
      }
      if (isRestaurant10mDue) {
        await sendRestaurantRebroadcast('10m', sentRestaurant10mOrderIds);
      }
      if (isRestaurant12mDue) {
        await sendRestaurantRebroadcast('12m', sentRestaurant12mOrderIds);
      }

      // First-stage admin alert (2m)
      if (isFirstStageDue && !sentFirstStageOrderIds.has(orderId) && adminIds.length > 0) {
        const adminFirstInvoke = await sendPushWithDispatch({
          dispatchKey: `order:${orderId}:pending:2m:admin`,
          orderId,
          cohort: 'admin',
          userIds: adminIds,
          title: 'New Order Pending',
          body: `Order #${orderNumber} has been pending for more than 2 minutes.`,
          data: {
            type: 'admin_order_alert',
            stage: 'first',
            flow: ADMIN_FIRST_ALERT_TYPE,
            order_id: orderId,
            order_number: orderNumber,
            source: 'backend_pending_orders_poller',
          },
          logger,
        });

        if (pushSendSucceeded(adminFirstInvoke) && !adminFirstInvoke.skipped) {
          sentFirstStageCount += 1;
          sentFirstStageOrderIds.add(orderId);
        } else if (!adminFirstInvoke?.skipped) {
          logger.error?.(
            `[pending-orders-poller] first-stage admin push failed order=${orderId}: ${adminFirstInvoke?.error ?? 'unknown_error'}`,
          );
        }
      }

      // Second-stage admin alert (5m)
      if (isSecondStageDue && !sentSecondStageOrderIds.has(orderId) && adminIds.length > 0) {
        const adminSecondInvoke = await sendPushWithDispatch({
          dispatchKey: `order:${orderId}:pending:5m:admin`,
          orderId,
          cohort: 'admin',
          userIds: adminIds,
          title: 'Order Still Pending',
          body: `Order #${orderNumber} is still pending after 5 minutes.`,
          data: {
            type: 'admin_order_alert',
            stage: 'second',
            flow: ADMIN_SECOND_ALERT_TYPE,
            order_id: orderId,
            order_number: orderNumber,
            source: 'backend_pending_orders_poller',
          },
          logger,
        });

        if (pushSendSucceeded(adminSecondInvoke) && !adminSecondInvoke.skipped) {
          sentSecondStageCount += 1;
          sentSecondStageOrderIds.add(orderId);
        } else if (!adminSecondInvoke?.skipped) {
          logger.error?.(
            `[pending-orders-poller] second-stage admin push failed order=${orderId}: ${adminSecondInvoke?.error ?? 'unknown_error'}`,
          );
        }
      }

      // Customer escalation notification (5m)
      if (
        isSecondStageDue &&
        !sentCustomerStageOrderIds.has(orderId) &&
        customerId &&
        sentSecondStageOrderIds.has(orderId)
      ) {
        const customerInvoke = await sendPushWithDispatch({
          dispatchKey: `order:${orderId}:pending:5m:user`,
          orderId,
          cohort: 'user',
          userIds: [customerId],
          title: 'Order Update',
          body: `Your order #${orderNumber} is still pending. Our team is actively following it.`,
          data: {
            type: CUSTOMER_ESCALATION_ALERT_TYPE,
            order_id: orderId,
            order_number: orderNumber,
            source: 'backend_pending_orders_poller',
          },
          logger,
        });

        if (pushSendSucceeded(customerInvoke) && !customerInvoke.skipped) {
          sentCustomerStageCount += 1;
          sentCustomerStageOrderIds.add(orderId);
        } else if (!customerInvoke?.skipped) {
          logger.error?.(
            `[pending-orders-poller] customer escalation push failed order=${orderId}: ${customerInvoke?.error ?? 'unknown_error'}`,
          );
        }
      }

      // Auto-cancel (15m)
      if (isAutoCancelDue && customerId && !sentAutoCancelOrderIds.has(orderId)) {
        const nowIso = new Date().toISOString();
        const { data: cancelledRows, error: cancelError } = await supabaseAdmin
          .from('orders')
          .update({
            status: 'cancelled',
            cancel_reason: 'timeout_15m',
            cancelled_at: nowIso,
            updated_at: nowIso,
          })
          .eq('id', orderId)
          .eq('status', 'pending')
          .select('id');

        if (cancelError) {
          logger.error?.(
            `[pending-orders-poller] auto-cancel update failed order=${orderId}: ${cancelError.message}`,
          );
          continue;
        }

        const wasCancelled = Array.isArray(cancelledRows) && cancelledRows.length > 0;
        if (!wasCancelled) {
          continue;
        }

        const autoCancelInvoke = await sendPushWithDispatch({
          dispatchKey: `order:${orderId}:pending:15m:user_cancel`,
          orderId,
          cohort: 'user',
          userIds: [customerId],
          title: 'طلبك تم إلغاؤه.',
          body: 'تم إلغاء طلبكم نتيجة لنفاذ الكمية، نرجو منكم التفهم.',
          data: {
            type: CUSTOMER_AUTO_CANCEL_ALERT_TYPE,
            order_id: orderId,
            order_number: orderNumber,
            source: 'backend_pending_orders_poller',
            force_arabic_template: true,
          },
          logger,
        });

        if (pushSendSucceeded(autoCancelInvoke) && !autoCancelInvoke.skipped) {
          autoCancelledCount += 1;
          sentAutoCancelOrderIds.add(orderId);
        } else if (!autoCancelInvoke?.skipped) {
          logger.error?.(
            `[pending-orders-poller] auto-cancel notification failed order=${orderId}: ${
              autoCancelInvoke?.error ?? 'unknown_error'
            }`,
          );
        }
      }
    }

    // Picked-up delivery delayed alert (15m)
    for (const order of dueDeliveryOrders ?? []) {
      const orderId = String(order.id ?? '');
      const orderNumber = String(order.order_number ?? '');
      if (!orderId || !orderNumber || sentDeliveryAlertOrderIds.has(orderId)) {
        continue;
      }
      if (adminIds.length === 0) continue;

      const deliveryInvoke = await sendPushWithDispatch({
        dispatchKey: `order:${orderId}:delivery_delay:15m:admin`,
        orderId,
        cohort: 'admin',
        userIds: adminIds,
        title: 'Delivery Delayed',
        body: `Order #${orderNumber} has been picked up for more than 15 minutes and is not delivered yet.`,
        data: {
          type: 'admin_order_alert',
          stage: 'delivery_delayed',
          flow: ADMIN_DELIVERY_ALERT_TYPE,
          order_id: orderId,
          order_number: orderNumber,
          source: 'backend_pending_orders_poller',
        },
        logger,
      });

      if (pushSendSucceeded(deliveryInvoke) && !deliveryInvoke.skipped) {
        sentDeliveryDelayedCount += 1;
        sentDeliveryAlertOrderIds.add(orderId);
      } else if (!deliveryInvoke?.skipped) {
        logger.error?.(
          `[pending-orders-poller] delivery-delayed admin push failed order=${orderId}: ${
            deliveryInvoke?.error ?? 'unknown_error'
          }`,
        );
      }
    }

    stats.sent_first_admin = sentFirstStageCount;
    stats.sent_second_admin = sentSecondStageCount;
    stats.sent_delivery_delayed = sentDeliveryDelayedCount;
    stats.sent_customer = sentCustomerStageCount;
    stats.sent_restaurant_rebroadcasts = sentRestaurantRebroadcastCount;
    stats.auto_cancelled = autoCancelledCount;

    logger.info?.(
      `[pending-orders-poller] v2_escalation pending_due=${stats.pending_due} delivery_due=${stats.delivery_due} admins=${stats.admins} sent_first_admin=${sentFirstStageCount} sent_second_admin=${sentSecondStageCount} sent_delivery_delayed=${sentDeliveryDelayedCount} sent_customer=${sentCustomerStageCount} sent_restaurant_rebroadcasts=${sentRestaurantRebroadcastCount} auto_cancelled=${autoCancelledCount}`,
    );

    return stats;
  } catch (error) {
    logger.error?.('[pending-orders-poller] unexpected error:', error);
    stats.error = error?.message ?? String(error);
    return stats;
  }
}

export function startPendingOrdersPoller({ logger = console } = {}) {
  const enabled = parseEnabled(process.env.ENABLE_PENDING_ORDERS_POLLER);
  if (!enabled) {
    logger.info?.('[pending-orders-poller] disabled via ENABLE_PENDING_ORDERS_POLLER');
    return { stop: () => { } };
  }

  if (process.env.VERCEL === '1') {
    logger.info?.(
      '[pending-orders-poller] VERCEL=1: in-process interval disabled; scheduled external runner required (QStash Schedule, Supabase pg_cron, or external webhook)',
    );
    return { stop: () => { } };
  }

  const intervalMs = Number(
    process.env.PENDING_ORDERS_POLLER_INTERVAL_MS || DEFAULT_INTERVAL_MS,
  );
  const safeIntervalMs =
    Number.isFinite(intervalMs) && intervalMs >= 15_000
      ? intervalMs
      : DEFAULT_INTERVAL_MS;

  let timer = null;
  let running = false;

  const pollOnce = async () => {
    if (running) return;
    running = true;

    try {
      await runPendingOrdersPollOnce({ logger });
      await runPreparingUnassignedRebroadcastOnce({ logger }).catch(() => {});
      await runPickupDelayAdminAlertsOnce({ logger });
    } catch (error) {
      logger.error?.('[pending-orders-poller] unexpected error:', error);
    } finally {
      running = false;
    }
  };

  timer = setInterval(pollOnce, safeIntervalMs);
  setTimeout(pollOnce, 2_000);
  logger.info?.(`[pending-orders-poller] v2_escalation started interval=${safeIntervalMs}ms`);

  return {
    stop: () => {
      if (timer) {
        clearInterval(timer);
        timer = null;
      }
    },
  };
}
