import { supabaseAdmin } from '../config/supabase.js';
import { getActiveAdminUserIds } from './adminRecipients.js';
import { runPickupDelayAdminAlertsOnce } from './pickupDelayAdminAlertsPoller.js';

const DEFAULT_INTERVAL_MS = 60_000;
const FIRST_ADMIN_THRESHOLD_MS = 2 * 60_000;
const SECOND_ADMIN_THRESHOLD_MS = 5 * 60_000;
const DELIVERY_DELAY_THRESHOLD_MS = 15 * 60_000;
const AUTO_CANCEL_THRESHOLD_MS = 10 * 60_000;
const MAX_ORDERS_PER_RUN = 80;
const LOOKBACK_LOG_HOURS = 48;
const ADMIN_FIRST_ALERT_TYPE = 'admin_order_pending_2m';
const ADMIN_SECOND_ALERT_TYPE = 'admin_order_pending_5m';
const ADMIN_DELIVERY_ALERT_TYPE = 'admin_delivery_picked_up_15m';
const CUSTOMER_ESCALATION_ALERT_TYPE = 'customer_order_pending_5m';
const CUSTOMER_AUTO_CANCEL_ALERT_TYPE = 'order_auto_cancelled_10m';

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
    auto_cancelled: 0,
  };

  try {
    const thresholdIso = safeIsoDate(FIRST_ADMIN_THRESHOLD_MS);
    const { data: dueOrders, error: ordersError } = await supabaseAdmin
      .from('orders')
      .select('id, customer_id, order_number, created_at')
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

    if (
      stats.pending_due === 0 &&
      stats.delivery_due === 0
    ) {
      return stats;
    }

    const adminIds = await getActiveAdminUserIds(logger);
    stats.admins = adminIds.length;
    if (adminIds.length === 0) {
      logger.warn?.('[pending-orders-poller] no admin users found; skipping admin alerts');
    }

    const sinceIso = safeIsoDate(LOOKBACK_LOG_HOURS * 60 * 60_000);
    const { data: sentLogs, error: logsError } = await supabaseAdmin
      .from('push_notifications_log')
      .select('data')
      .eq('status', 'sent')
      .gte('created_at', sinceIso);

    if (logsError) {
      logger.error?.(
        '[pending-orders-poller] log dedupe query failed:',
        logsError.message,
      );
      stats.error = logsError.message;
      return stats;
    }

    const sentFirstStageOrderIds = new Set(
      (sentLogs ?? [])
        .filter((row) => String(row?.data?.flow ?? '') === ADMIN_FIRST_ALERT_TYPE)
        .map((row) => row?.data?.order_id)
        .filter((value) => typeof value === 'string'),
    );
    const sentSecondStageOrderIds = new Set(
      (sentLogs ?? [])
        .filter((row) => String(row?.data?.flow ?? '') === ADMIN_SECOND_ALERT_TYPE)
        .map((row) => row?.data?.order_id)
        .filter((value) => typeof value === 'string'),
    );
    const sentCustomerStageOrderIds = new Set(
      (sentLogs ?? [])
        .filter((row) => String(row?.data?.type ?? '') === CUSTOMER_ESCALATION_ALERT_TYPE)
        .map((row) => row?.data?.order_id)
        .filter((value) => typeof value === 'string'),
    );
    const sentAutoCancelOrderIds = new Set(
      (sentLogs ?? [])
        .filter((row) => String(row?.data?.type ?? '') === CUSTOMER_AUTO_CANCEL_ALERT_TYPE)
        .map((row) => row?.data?.order_id)
        .filter((value) => typeof value === 'string'),
    );
    const sentDeliveryAlertOrderIds = new Set(
      (sentLogs ?? [])
        .filter((row) => String(row?.data?.flow ?? '') === ADMIN_DELIVERY_ALERT_TYPE)
        .map((row) => row?.data?.order_id)
        .filter((value) => typeof value === 'string'),
    );

    let sentFirstStageCount = 0;
    let sentSecondStageCount = 0;
    let sentCustomerStageCount = 0;
    let autoCancelledCount = 0;
    let sentDeliveryDelayedCount = 0;

    for (const order of (dueOrders ?? [])) {
      const customerId = String(order.customer_id ?? '');
      const orderId = String(order.id ?? '');
      const orderNumber = String(order.order_number ?? '');
      const createdAt = Date.parse(String(order.created_at ?? ''));
      if (!orderId || !orderNumber || !Number.isFinite(createdAt)) continue;

      const orderAgeMs = Date.now() - createdAt;
      const isFirstStageDue = orderAgeMs >= FIRST_ADMIN_THRESHOLD_MS;
      const isSecondStageDue = orderAgeMs >= SECOND_ADMIN_THRESHOLD_MS;
      const isAutoCancelDue = orderAgeMs >= AUTO_CANCEL_THRESHOLD_MS;

      if (isFirstStageDue && !sentFirstStageOrderIds.has(orderId) && adminIds.length > 0) {
        const adminFirstInvoke = await supabaseAdmin.functions.invoke('send-push-notification', {
          body: {
            user_ids: adminIds,
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
            force_activate_inactive_tokens: true,
          },
        });

        if (!adminFirstInvoke.error && adminFirstInvoke.data?.success === true) {
          if (Number(adminFirstInvoke.data?.summary?.total_sent ?? 0) > 0) {
            sentFirstStageCount += 1;
            sentFirstStageOrderIds.add(orderId);
          }
        } else {
          logger.error?.(
            `[pending-orders-poller] first-stage admin push failed order=${orderId}: ${adminFirstInvoke.error?.message ?? 'unknown_error'
            }`,
          );
        }
      }

      if (isSecondStageDue && !sentSecondStageOrderIds.has(orderId) && adminIds.length > 0) {
        const adminSecondInvoke = await supabaseAdmin.functions.invoke('send-push-notification', {
          body: {
            user_ids: adminIds,
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
            force_activate_inactive_tokens: true,
          },
        });

        if (!adminSecondInvoke.error && adminSecondInvoke.data?.success === true) {
          if (Number(adminSecondInvoke.data?.summary?.total_sent ?? 0) > 0) {
            sentSecondStageCount += 1;
            sentSecondStageOrderIds.add(orderId);
          }
        } else {
          logger.error?.(
            `[pending-orders-poller] second-stage admin push failed order=${orderId}: ${adminSecondInvoke.error?.message ?? 'unknown_error'
            }`,
          );
        }
      }

      if (
        isSecondStageDue &&
        !sentCustomerStageOrderIds.has(orderId) &&
        customerId &&
        sentSecondStageOrderIds.has(orderId)
      ) {
        const customerInvoke = await supabaseAdmin.functions.invoke('send-push-notification', {
          body: {
            user_ids: [customerId],
            title: 'Order Update',
            body: `Your order #${orderNumber} is still pending. Our team is actively following it.`,
            data: {
              type: CUSTOMER_ESCALATION_ALERT_TYPE,
              order_id: orderId,
              order_number: orderNumber,
              source: 'backend_pending_orders_poller',
            },
            force_activate_inactive_tokens: true,
          },
        });

        if (!customerInvoke.error && customerInvoke.data?.success === true) {
          if (Number(customerInvoke.data?.summary?.total_sent ?? 0) > 0) {
            sentCustomerStageCount += 1;
            sentCustomerStageOrderIds.add(orderId);
          }
        } else {
          logger.error?.(
            `[pending-orders-poller] customer escalation push failed order=${orderId}: ${customerInvoke.error?.message ?? 'unknown_error'
            }`,
          );
        }
      }

      if (isAutoCancelDue && customerId && !sentAutoCancelOrderIds.has(orderId)) {
        const { data: cancelledRows, error: cancelError } = await supabaseAdmin
          .from('orders')
          .update({
            status: 'cancelled',
            updated_at: new Date().toISOString(),
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

        const autoCancelInvoke = await supabaseAdmin.functions.invoke('send-push-notification', {
          body: {
            user_ids: [customerId],
            title: 'Order Cancelled',
            body: 'Order cancelled due to stock unavailability.',
            data: {
              type: CUSTOMER_AUTO_CANCEL_ALERT_TYPE,
              order_id: orderId,
              order_number: orderNumber,
              source: 'backend_pending_orders_poller',
            },
            force_activate_inactive_tokens: true,
          },
        });

        if (!autoCancelInvoke.error && autoCancelInvoke.data?.success === true) {
          if (Number(autoCancelInvoke.data?.summary?.total_sent ?? 0) > 0) {
            autoCancelledCount += 1;
            sentAutoCancelOrderIds.add(orderId);
          }
        } else {
          logger.error?.(
            `[pending-orders-poller] auto-cancel notification failed order=${orderId}: ${
              autoCancelInvoke.error?.message ?? 'unknown_error'
            }`,
          );
        }
      }
    }

    for (const order of (dueDeliveryOrders ?? [])) {
      const orderId = String(order.id ?? '');
      const orderNumber = String(order.order_number ?? '');
      if (!orderId || !orderNumber || sentDeliveryAlertOrderIds.has(orderId)) {
        continue;
      }
      if (adminIds.length === 0) continue;

      const deliveryInvoke = await supabaseAdmin.functions.invoke('send-push-notification', {
        body: {
          user_ids: adminIds,
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
          force_activate_inactive_tokens: true,
        },
      });

      if (!deliveryInvoke.error && deliveryInvoke.data?.success === true) {
        if (Number(deliveryInvoke.data?.summary?.total_sent ?? 0) > 0) {
          sentDeliveryDelayedCount += 1;
          sentDeliveryAlertOrderIds.add(orderId);
        }
      } else {
        logger.error?.(
          `[pending-orders-poller] delivery-delayed admin push failed order=${orderId}: ${
            deliveryInvoke.error?.message ?? 'unknown_error'
          }`,
        );
      }
    }

    stats.sent_first_admin = sentFirstStageCount;
    stats.sent_second_admin = sentSecondStageCount;
    stats.sent_delivery_delayed = sentDeliveryDelayedCount;
    stats.sent_customer = sentCustomerStageCount;
    stats.auto_cancelled = autoCancelledCount;

    logger.info?.(
      `[pending-orders-poller] v2_escalation pending_due=${stats.pending_due} delivery_due=${stats.delivery_due} admins=${stats.admins} sent_first_admin=${sentFirstStageCount} sent_second_admin=${sentSecondStageCount} sent_delivery_delayed=${sentDeliveryDelayedCount} sent_customer=${sentCustomerStageCount} auto_cancelled=${autoCancelledCount}`,
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
      '[pending-orders-poller] VERCEL=1: in-process interval disabled; schedule GET /api/internal/pending-orders-poll (GitHub Actions workflow or external cron; Hobby Vercel Cron is daily at most)',
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
