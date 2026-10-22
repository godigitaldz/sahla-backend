import { getActiveAdminUserIds } from '../../../services/adminRecipients.js';
import { dispatchLogDelivered, pushSendSucceeded, pushTotalSent } from '../../../modules/notifications/pushSendResult.js';
import { supabasePushGateway } from '../../notifications/supabasePushGateway.js';
import {
  getOnlineAvailableCourierUserIds,
  getRestaurantOpsUserIds,
  isCourierDeliverableOrder,
} from '../../notifications/orderRebroadcastRecipients.js';
import {
  shouldRunPendingMilestone,
  shouldRunPickupDelayMilestone,
  shouldRunPreparingAssignedMilestone,
  shouldRunPreparingUnassignedMilestone,
} from '../domain/orderStateMachine.js';
import {
  cancelLifecycleEvents,
  PENDING_10M_CANCEL_EVENT,
  PENDING_15M_CANCEL_EVENT,
  PENDING_AUTO_CANCEL_MINUTES,
  PENDING_10M_RESTAURANT_EVENT,
  PENDING_12M_RESTAURANT_EVENT,
  PENDING_CANCEL_EVENTS,
  PREPARING_UNASSIGNED_5M_EVENT,
  PREPARING_UNASSIGNED_EVENTS,
} from './scheduleOrderLifecycle.js';
import {
  PREPARING_UNASSIGNED_IMMEDIATE_EVENT,
  PREPARING_UNASSIGNED_LIFECYCLE_EVENTS,
  episodeDispatchKey,
  isActiveUnassignedEpisode,
  resolvePreparingUnassignedJobKey,
} from '../domain/preparingUnassignedEpisode.js';
import { orderLifecycleRepository } from '../infrastructure/orderLifecycleRepository.js';

function jobKeyFrom(orderId, eventType) {
  return `order:${orderId}:${eventType}`;
}

const PENDING_SIBLING_EVENTS = [
  'order.pending.2m',
  'order.pending.5m',
  'order.pending.5m.customer',
  PENDING_10M_RESTAURANT_EVENT,
  PENDING_12M_RESTAURANT_EVENT,
  ...PENDING_CANCEL_EVENTS,
];

function isPendingCancelEvent(eventType) {
  return PENDING_CANCEL_EVENTS.includes(eventType);
}

function orderAgeMs(order) {
  const createdMs = Date.parse(String(order?.created_at || ''));
  if (!Number.isFinite(createdMs)) return Number.POSITIVE_INFINITY;
  return Date.now() - createdMs;
}

function pendingAutoCancelThresholdMs() {
  return PENDING_AUTO_CANCEL_MINUTES * 60 * 1000;
}

function dispatchKeyForEvent(eventType, orderId, order = null) {
  const episodeAt = order?.courier_unassigned_episode_at;
  switch (eventType) {
    case 'order.pending.2m':
      return `order:${orderId}:pending:2m:admin`;
    case 'order.pending.5m':
      return `order:${orderId}:pending:5m:admin`;
    case 'order.pending.5m.customer':
      return `order:${orderId}:pending:5m:user`;
    case PENDING_10M_CANCEL_EVENT:
      return `order:${orderId}:pending:10m:user_cancel`;
    case PENDING_15M_CANCEL_EVENT:
      return `order:${orderId}:pending:15m:user_cancel`;
    case 'order.pickup.15m.delay':
      return `order:${orderId}:pickup:25m:admin`;
    case PREPARING_UNASSIGNED_IMMEDIATE_EVENT:
      return episodeDispatchKey(orderId, 'immediate:courier', episodeAt);
    case 'order.preparing.unassigned.2m':
      return episodeDispatchKey(orderId, '2m:courier', episodeAt);
    case PREPARING_UNASSIGNED_5M_EVENT:
      return episodeDispatchKey(orderId, '5m:admin', episodeAt);
    case 'order.preparing.assigned.20m':
      return `order:${orderId}:preparing:assigned:20m:admin`;
    default:
      return null;
  }
}

function isPreparingUnassignedLifecycleEvent(eventType) {
  return PREPARING_UNASSIGNED_LIFECYCLE_EVENTS.includes(eventType);
}

function milestoneSkipReason(eventType, order) {
  if (
    eventType === 'order.pending.2m'
    || eventType === 'order.pending.5m'
    || eventType === 'order.pending.5m.customer'
    || eventType === PENDING_10M_RESTAURANT_EVENT
    || eventType === PENDING_12M_RESTAURANT_EVENT
    || isPendingCancelEvent(eventType)
  ) {
    if (!shouldRunPendingMilestone(order.status)) {
      return `state_mismatch:${order.status}`;
    }
    return null;
  }
  if (eventType === 'order.pickup.15m.delay') {
    if (!shouldRunPickupDelayMilestone(order.status)) {
      return `state_mismatch:${order.status}`;
    }
    return null;
  }
  if (isPreparingUnassignedLifecycleEvent(eventType)) {
    if (!shouldRunPreparingUnassignedMilestone(order)) {
      return `state_mismatch:${order.status}`;
    }
    if (!isActiveUnassignedEpisode(order)) {
      return 'inactive_unassigned_episode';
    }
    return null;
  }
  if (eventType === 'order.preparing.assigned.20m') {
    if (!shouldRunPreparingAssignedMilestone(order)) {
      return `state_mismatch:${order.status}`;
    }
    return null;
  }
  return 'unsupported_event_type';
}

async function markSkipped(jobKey, lastError) {
  await orderLifecycleRepository.markJobState(jobKey, 'skipped', { last_error: lastError });
}

async function sendDedupePush({
  dispatchKey,
  orderId,
  cohort,
  userIds,
  title,
  body,
  data,
}) {
  const ids = [...new Set((userIds || []).map((v) => String(v || '').trim()).filter(Boolean))];
  if (!ids.length) {
    await orderLifecycleRepository.recordDispatchIfNew({
      dispatchKey,
      orderId,
      cohort,
      status: 'skipped',
      providerResponse: { skipped: true, reason: 'no_recipients' },
    });
    return { success: false, skipped: true, reason: 'no_recipients' };
  }

  const inserted = await orderLifecycleRepository.recordDispatchIfNew({
    dispatchKey,
    orderId,
    cohort,
    status: 'skipped',
    providerResponse: { reserved: true },
  });
  if (!inserted) {
    const existing = await orderLifecycleRepository.getDispatchByKey(dispatchKey);
    if (existing?.status === 'sent' && dispatchLogDelivered(existing.provider_response)) {
      return { success: true, skipped: true, reason: 'deduped_dispatch_sent' };
    }
  }
  const sent = await supabasePushGateway.sendPush({ userIds: ids, title, body, data });
  const totalSent = pushTotalSent(sent);
  const edgeReason = String(sent?.raw?.reason ?? sent?.reason ?? '').trim();
  const forceRetryOnZero =
    totalSent <= 0
    && (cohort === 'user' || edgeReason === 'all_target_users_duplicate');
  const finalStatus = pushSendSucceeded(sent) && !forceRetryOnZero ? 'sent' : 'failed';
  await orderLifecycleRepository.updateDispatchStatus(dispatchKey, {
    status: finalStatus,
    providerResponse: { ...sent, total_sent: totalSent },
  });
  if (!pushSendSucceeded(sent) || forceRetryOnZero) {
    throw new Error(sent.error || sent.reason || edgeReason || 'push_send_failed');
  }
  return sent;
}

async function recordEventAndMaybeRetry({
  eventId,
  orderId,
  eventType,
  payload,
  order,
  dispatchKey,
}) {
  const inserted = await orderLifecycleRepository.recordEventIfNew({
    eventId,
    orderId,
    eventType,
    source: 'qstash',
    payload,
    orderNumber: order.order_number,
    currentStatus: order.status,
    customerId: order.customer_id,
    restaurantId: order.restaurant_id,
    deliveryPersonId: order.delivery_person_id,
  });
  if (inserted) return { duplicate: false };

  if (!dispatchKey) {
    return { duplicate: true, allowPush: false };
  }
  const existing = await orderLifecycleRepository.getDispatchByKey(dispatchKey);
  if (existing?.status === 'sent' && dispatchLogDelivered(existing.provider_response)) {
    return { duplicate: true, allowPush: false };
  }
  return { duplicate: true, allowPush: true };
}

export async function handleOrderLifecycleEvent(payload, { logger = console } = {}) {
  const eventId = String(payload?.event_id || '').trim();
  const eventType = String(payload?.event_type || '').trim();
  const orderId = String(payload?.order_id || '').trim();
  if (!eventId || !eventType || !orderId) {
    throw new Error('Invalid lifecycle payload');
  }

  const order = await orderLifecycleRepository.getOrderById(orderId);
  if (!order) {
    await orderLifecycleRepository.markJobState(jobKeyFrom(orderId, eventType), 'failed', {
      last_error: 'order_not_found',
    });
    return { ok: false, error: 'order_not_found' };
  }

  const jobKey = resolvePreparingUnassignedJobKey(orderId, eventType, order)
    || jobKeyFrom(orderId, eventType);

  const skipReason = milestoneSkipReason(eventType, order);
  if (skipReason) {
    if (PENDING_SIBLING_EVENTS.includes(eventType)) {
      await cancelLifecycleEvents(orderId, PENDING_SIBLING_EVENTS).catch(() => {});
    } else if (eventType === 'order.pickup.15m.delay') {
      await cancelLifecycleEvents(orderId, ['order.pickup.15m.delay']).catch(() => {});
    } else if (PREPARING_UNASSIGNED_EVENTS.includes(eventType)) {
      await cancelLifecycleEvents(orderId, PREPARING_UNASSIGNED_EVENTS).catch(() => {});
    } else if (eventType === 'order.preparing.assigned.20m') {
      await cancelLifecycleEvents(orderId, ['order.preparing.assigned.20m']).catch(() => {});
    }
    await markSkipped(jobKey, skipReason);
    return { ok: true, skipped: true };
  }

  const dispatchKey = dispatchKeyForEvent(eventType, orderId, order);
  const { duplicate, allowPush } = await recordEventAndMaybeRetry({
    eventId,
    orderId,
    eventType,
    payload,
    order,
    dispatchKey,
  });
  if (duplicate && !allowPush) {
    await markSkipped(jobKey, 'duplicate_event_id');
    return { ok: true, duplicate: true };
  }

  const adminIds = await getActiveAdminUserIds(logger);
  const orderNumber = String(order.order_number || order.id || '');

  async function sendPendingRestaurantRebroadcast(stageSuffix) {
    if (!isCourierDeliverableOrder(order)) return;
    const rid = String(order.restaurant_id ?? '').trim();
    const restaurantOpsIds = await getRestaurantOpsUserIds(rid, logger);
    if (restaurantOpsIds.length === 0) return;
    await sendDedupePush({
      dispatchKey: `order:${orderId}:pending:${stageSuffix}:restaurant_rebroadcast`,
      orderId,
      cohort: 'restaurant_ops',
      userIds: restaurantOpsIds,
      title: 'طلب قيد الانتظار',
      body: `الطلب #${orderNumber} ما زال قيد الانتظار.`,
      data: {
        type: 'new_order',
        flow: `lifecycle_pending_${stageSuffix}_restaurant_rebroadcast`,
        order_id: orderId,
        order_number: orderNumber,
        ...(rid ? { restaurant_id: rid } : {}),
        source: 'lifecycle_pending_restaurant_rebroadcast',
      },
    });
  }

  if (eventType === 'order.pending.2m') {
    await sendDedupePush({
      dispatchKey: dispatchKeyForEvent(eventType, orderId),
      orderId,
      cohort: 'admin',
      userIds: adminIds,
      title: 'مطعم لم يقبل الطلب — دقيقتان',
      body: `الطلب #${orderNumber} ما زال قيد الانتظار ولم يقبله المطعم بعد مرور دقيقتين.`,
      data: { type: 'admin_order_alert', stage: 'first', order_id: orderId, order_number: orderNumber },
    });
    await sendPendingRestaurantRebroadcast('2m');
    await orderLifecycleRepository.markJobState(jobKey, 'executed');
    return { ok: true };
  }

  if (eventType === 'order.pending.5m') {
    await sendDedupePush({
      dispatchKey: dispatchKeyForEvent(eventType, orderId),
      orderId,
      cohort: 'admin',
      userIds: adminIds,
      title: 'مطعم لم يقبل الطلب — 5 دقائق',
      body: `الطلب #${orderNumber} ما زال قيد الانتظار بعد 5 دقائق دون قبول من المطعم.`,
      data: { type: 'admin_order_alert', stage: 'second', order_id: orderId, order_number: orderNumber },
    });
    await sendPendingRestaurantRebroadcast('5m');
    await orderLifecycleRepository.markJobState(jobKey, 'executed');
    return { ok: true };
  }

  if (eventType === PENDING_10M_RESTAURANT_EVENT) {
    await sendPendingRestaurantRebroadcast('10m');
    await orderLifecycleRepository.markJobState(jobKey, 'executed');
    return { ok: true };
  }

  if (eventType === PENDING_12M_RESTAURANT_EVENT) {
    await sendPendingRestaurantRebroadcast('12m');
    await orderLifecycleRepository.markJobState(jobKey, 'executed');
    return { ok: true };
  }

  if (eventType === 'order.pending.5m.customer') {
    await sendDedupePush({
      dispatchKey: dispatchKeyForEvent(eventType, orderId),
      orderId,
      cohort: 'user',
      userIds: [order.customer_id],
      title: 'طلبك قيد الإنتظار',
      body: 'نعتذر على تأخر قبول الطلب، فريقنا يقوم بمراجعة السبب مع المطعم.',
      data: {
        type: 'customer_order_pending_5m',
        flow: 'customer_order_pending_5m',
        order_id: orderId,
        order_number: orderNumber,
      },
    });
    await orderLifecycleRepository.markJobState(jobKey, 'executed');
    return { ok: true };
  }

  if (isPendingCancelEvent(eventType)) {
    const ageMs = orderAgeMs(order);
    if (ageMs < pendingAutoCancelThresholdMs()) {
      if (eventType === PENDING_10M_CANCEL_EVENT) {
        await orderLifecycleRepository.ensurePending15mCancelSibling(orderId, order.created_at);
      }
      await orderLifecycleRepository.markJobState(jobKey, 'skipped', {
        last_error: 'premature_legacy_10m_before_15m',
      });
      return { ok: true, skipped: true, reason: 'premature_before_15m' };
    }

    const cancelled = await orderLifecycleRepository.transitionPendingToCancelled(
      orderId,
      'timeout_15m',
    );
    if (cancelled) {
      await sendDedupePush({
        dispatchKey: `order:${orderId}:pending:15m:user_cancel`,
        orderId,
        cohort: 'user',
        userIds: [order.customer_id],
        title: 'المطعم تحت الضغط حاليا',
        body: 'نعتذر لعدم قبول طلبكم نرجو منكم التفهم.',
        data: {
          type: 'order_auto_cancelled_15m',
          flow: 'order_auto_cancelled_15m',
          order_id: orderId,
          order_number: orderNumber,
        },
      });
      await orderLifecycleRepository.recordEventIfNew({
        eventId: `${eventId}:cancelled`,
        orderId,
        eventType: 'order_cancelled_timeout',
        source: 'backend',
        payload: { reason: 'timeout_15m' },
      });
      await cancelLifecycleEvents(orderId, PENDING_CANCEL_EVENTS).catch(() => {});
    }
    await orderLifecycleRepository.markJobState(jobKey, cancelled ? 'executed' : 'skipped', {
      last_error: cancelled ? null : 'already_transitioned',
    });
    return { ok: true };
  }

  if (eventType === 'order.pickup.15m.delay') {
    await sendDedupePush({
      dispatchKey: dispatchKeyForEvent(eventType, orderId),
      orderId,
      cohort: 'admin',
      userIds: adminIds,
      title: 'تأخر في التوصيل',
      body: `الطلب #${orderNumber} تجاوز 25 دقيقة منذ استلامه من طرف عامل التوصيل وما زال قيد التوصيل.`,
      data: {
        type: 'admin_order_alert',
        stage: 'delivery_delayed',
        flow: 'admin_delivery_picked_up_25m',
        order_id: orderId,
        order_number: orderNumber,
      },
    });
    await sendDedupePush({
      dispatchKey: `order:${orderId}:pickup:25m:user`,
      orderId,
      cohort: 'user',
      userIds: [order.customer_id],
      title: 'تحديث الطلب',
      body: 'طلبك متأخر قليلًا، فريقنا يتابع حالة التوصيل.',
      data: {
        type: 'order_status',
        status: 'متأخر',
        flow: 'user_delivery_delay_25m',
        order_id: orderId,
        order_number: orderNumber,
      },
    });
    await orderLifecycleRepository.markJobState(jobKey, 'executed');
    return { ok: true };
  }

  async function sendPreparingCourierRebroadcast({
    dispatchSuffix,
    body,
    stage,
    flow,
  }) {
    const courierIds = await getOnlineAvailableCourierUserIds(logger);
    await sendDedupePush({
      dispatchKey: episodeDispatchKey(orderId, dispatchSuffix, order.courier_unassigned_episode_at),
      orderId,
      cohort: 'courier',
      userIds: courierIds,
      title: 'طلب جديد بانتظار التوصيل',
      body,
      data: {
        type: 'order_available',
        stage,
        flow,
        order_id: orderId,
        order_number: orderNumber,
      },
    });
  }

  if (eventType === PREPARING_UNASSIGNED_IMMEDIATE_EVENT) {
    await sendPreparingCourierRebroadcast({
      dispatchSuffix: 'immediate:courier',
      body: `الطلب #${orderNumber} متاح للتوصيل — يلزم تعيين سائق.`,
      stage: 'preparing_unassigned_immediate',
      flow: 'order_preparing_unassigned_immediate',
    });
    await orderLifecycleRepository.markJobState(jobKey, 'executed');
    return { ok: true };
  }

  if (eventType === 'order.preparing.unassigned.2m') {
    await sendPreparingCourierRebroadcast({
      dispatchSuffix: '2m:courier',
      body: `الطلب #${orderNumber} في طور التحضير منذ دقيقتين ويحتاج سائقًا متاحًا.`,
      stage: 'preparing_unassigned_2m',
      flow: 'order_preparing_unassigned_2m',
    });
    await orderLifecycleRepository.markJobState(jobKey, 'executed');
    return { ok: true };
  }

  if (eventType === PREPARING_UNASSIGNED_5M_EVENT) {
    const courierIds = await getOnlineAvailableCourierUserIds(logger);

    await sendDedupePush({
      dispatchKey: dispatchKeyForEvent(eventType, orderId, order),
      orderId,
      cohort: 'admin',
      userIds: adminIds,
      title: 'تحضير بدون سائق',
      body: `الطلب #${orderNumber} قيد التحضير/الجاهزية ولم يُعيَّن أي عامل توصيل — منذ 5 دقائق.`,
      data: {
        type: 'admin_order_alert',
        stage: 'preparing_unassigned_5m',
        flow: 'admin_preparing_unassigned_5m',
        order_id: orderId,
        order_number: orderNumber,
      },
    });

    await sendDedupePush({
      dispatchKey: episodeDispatchKey(orderId, '5m:courier', order.courier_unassigned_episode_at),
      orderId,
      cohort: 'courier',
      userIds: courierIds,
      title: 'طلب جديد بانتظار التوصيل',
      body: `الطلب #${orderNumber} في طور التحضير منذ 5 دقائق ويحتاج سائقًا متاحًا.`,
      data: {
        type: 'order_available',
        stage: 'preparing_unassigned_5m',
        flow: 'order_preparing_unassigned_5m',
        order_id: orderId,
        order_number: orderNumber,
      },
    });

    await orderLifecycleRepository.markJobState(jobKey, 'executed');
    return { ok: true };
  }

  if (eventType === 'order.preparing.assigned.20m') {
    await sendDedupePush({
      dispatchKey: dispatchKeyForEvent(eventType, orderId),
      orderId,
      cohort: 'admin',
      userIds: adminIds,
      title: 'سائق معيَّن ولم يستلم',
      body: `الطلب #${orderNumber} مُعيَّن لسائق منذ 20 دقيقة ولم يتم استلامه من المطعم بعد.`,
      data: {
        type: 'admin_order_alert',
        stage: 'preparing_assigned_no_pickup',
        flow: 'admin_preparing_assigned_20m',
        order_id: orderId,
        order_number: orderNumber,
      },
    });
    await orderLifecycleRepository.markJobState(jobKey, 'executed');
    return { ok: true };
  }

  await markSkipped(jobKey, 'unsupported_event_type');
  return { ok: true, skipped: true };
}
