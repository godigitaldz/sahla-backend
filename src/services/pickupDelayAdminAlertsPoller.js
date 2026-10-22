import { pushSendSucceeded } from '../modules/notifications/pushSendResult.js';
import { supabaseAdmin } from '../config/supabase.js';
import { getActiveAdminUserIds } from './adminRecipients.js';
import { sendPushWithDispatch } from './notificationDispatchService.js';

const FLOW_5M = 'admin_no_pickup_after_preparing_5m';
const FLOW_10M = 'admin_no_pickup_after_preparing_10m';

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

function minutesEnv(name, fallback) {
  const value = Number(process.env[name]);
  return Number.isFinite(value) && value >= 1 && value <= 120 ? value : fallback;
}

/** Legacy parcel pickup-delay alerts. Restaurant food orders use lifecycle events instead. */
export async function runPickupDelayAdminAlertsOnce({ logger = console } = {}) {
  const stats = { candidates: 0, sent_5m: 0, sent_10m: 0, skipped_no_recipients: false };
  if (!parseEnabled(process.env.ENABLE_PICKUP_DELAY_ADMIN_ALERTS, true)) return stats;

  const userIds = await getActiveAdminUserIds(logger);
  if (!userIds.length) {
    stats.skipped_no_recipients = true;
    return stats;
  }

  const firstMinutes = minutesEnv('PICKUP_DELAY_ADMIN_ALERT_FIRST_MINUTES', 5);
  const secondMinutes = minutesEnv('PICKUP_DELAY_ADMIN_ALERT_SECOND_MINUTES', 10);
  if (secondMinutes <= firstMinutes) {
    stats.error = 'PICKUP_DELAY_ADMIN_ALERT_SECOND_MINUTES must be greater than first';
    return stats;
  }

  const now = Date.now();
  const firstThreshold = firstMinutes * 60_000;
  const secondThreshold = secondMinutes * 60_000;
  try {
    const { data: orders, error } = await supabaseAdmin
      .from('orders')
      .select('id, order_number, preparing_started_at, status')
      .in('status', ['preparing', 'ready'])
      .not('parcel_sender_id', 'is', null)
      .not('preparing_started_at', 'is', null)
      .lte('preparing_started_at', safeIsoDate(firstThreshold))
      .order('preparing_started_at', { ascending: true })
      .limit(100);
    if (error) throw error;

    stats.candidates = orders?.length ?? 0;
    for (const order of orders ?? []) {
      const orderId = String(order.id ?? '');
      const orderNumber = String(order.order_number ?? '');
      const startedAt = Date.parse(String(order.preparing_started_at ?? ''));
      if (!orderId || !Number.isFinite(startedAt)) continue;

      const isSecondStage = now - startedAt >= secondThreshold;
      const stageMinutes = isSecondStage ? secondMinutes : firstMinutes;
      const flow = isSecondStage ? FLOW_10M : FLOW_5M;
      const sent = await sendPushWithDispatch({
        dispatchKey: `pickup-delay:${flow}:${orderId}`,
        orderId,
        cohort: 'admin',
        userIds,
        title: `طرد — تأخر الاستلام ${stageMinutes} دقائق`,
        body: `الطلب #${orderNumber} (طرد) لم يُستلم من التوصيل بعد ${stageMinutes} دقائق من بدء التحضير.`,
        data: {
          type: 'admin_order_alert',
          stage: isSecondStage ? 'no_pickup_after_preparing_10m' : 'no_pickup_after_preparing_5m',
          flow,
          order_id: orderId,
          order_number: orderNumber,
          status: String(order.status ?? ''),
          source: 'pickup_delay_admin_alerts_poller',
        },
      });
      if (pushSendSucceeded(sent)) {
        if (isSecondStage) stats.sent_10m += 1;
        else stats.sent_5m += 1;
      }
    }
    return stats;
  } catch (error) {
    logger.error?.('[pickup-delay-alerts] unexpected error:', error);
    stats.error = error?.message ?? String(error);
    return stats;
  }
}
