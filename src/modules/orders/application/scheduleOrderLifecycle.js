import crypto from 'node:crypto';
import { orderLifecycleRepository } from '../infrastructure/orderLifecycleRepository.js';
import { qstashPublisher } from '../infrastructure/qstashPublisher.js';
import {
  PREPARING_UNASSIGNED_IMMEDIATE_EVENT,
  PREPARING_UNASSIGNED_LIFECYCLE_EVENTS,
  episodeEpochMs,
  episodeJobKey,
} from '../domain/preparingUnassignedEpisode.js';

/** Canonical pending auto-cancel threshold (minutes / seconds). */
export const PENDING_AUTO_CANCEL_MINUTES = 15;
export const PENDING_AUTO_CANCEL_SECONDS = PENDING_AUTO_CANCEL_MINUTES * 60;

export const PENDING_15M_CANCEL_EVENT = 'order.pending.15m.cancel';
/** Legacy in-flight QStash / DB jobs — age-guarded; not scheduled for new orders. */
export const PENDING_10M_CANCEL_EVENT = 'order.pending.10m.cancel';
export const PENDING_10M_RESTAURANT_EVENT = 'order.pending.10m.restaurant_rebroadcast';
export const PENDING_12M_RESTAURANT_EVENT = 'order.pending.12m.restaurant_rebroadcast';

/** Delays in seconds. Legacy event ids kept for in-flight QStash jobs. */
export const EVENT_DELAYS_SECONDS = {
  'order.pending.2m': 2 * 60,
  'order.pending.5m': 5 * 60,
  'order.pending.5m.customer': 5 * 60,
  [PENDING_10M_RESTAURANT_EVENT]: 10 * 60,
  [PENDING_12M_RESTAURANT_EVENT]: 12 * 60,
  'order.preparing.unassigned.immediate': 0,
  'order.preparing.unassigned.2m': 2 * 60,
  'order.preparing.unassigned.5m': 5 * 60,
  [PENDING_10M_CANCEL_EVENT]: 10 * 60,
  [PENDING_15M_CANCEL_EVENT]: PENDING_AUTO_CANCEL_SECONDS,
  'order.pickup.15m.delay': 25 * 60,
  'order.preparing.assigned.20m': 20 * 60,
};

/** Events scheduled for new pending orders (includes cancel). */
export const PENDING_LIFECYCLE_EVENTS = [
  'order.pending.2m',
  'order.pending.5m',
  'order.pending.5m.customer',
  PENDING_10M_RESTAURANT_EVENT,
  PENDING_12M_RESTAURANT_EVENT,
  PENDING_15M_CANCEL_EVENT,
];

/** Both cancel event names — cancel on status leave-pending / sibling cleanup. */
export const PENDING_CANCEL_EVENTS = [
  PENDING_10M_CANCEL_EVENT,
  PENDING_15M_CANCEL_EVENT,
];

export const PREPARING_UNASSIGNED_EVENT = 'order.preparing.unassigned.2m';
export const PREPARING_UNASSIGNED_5M_EVENT = 'order.preparing.unassigned.5m';
/** @deprecated use PREPARING_UNASSIGNED_LIFECYCLE_EVENTS from preparingUnassignedEpisode.js */
export const PREPARING_UNASSIGNED_EVENTS = PREPARING_UNASSIGNED_LIFECYCLE_EVENTS;
export { PREPARING_UNASSIGNED_LIFECYCLE_EVENTS, PREPARING_UNASSIGNED_IMMEDIATE_EVENT };
export const PREPARING_ASSIGNED_EVENT = 'order.preparing.assigned.20m';
export const PICKUP_DELAY_EVENT = 'order.pickup.15m.delay';

const KITCHEN_FLOW_STATUSES = new Set(['preparing', 'ready']);
const TERMINAL_STATUSES = new Set(['delivered', 'cancelled']);

function eventJobKey(orderId, eventType) {
  return `order:${orderId}:${eventType}`;
}

function nextEventId(orderId, eventType) {
  return `${orderId}:${eventType}:${crypto.randomUUID()}`;
}

function delaySecondsUntil(scheduledForIso) {
  const when = Date.parse(scheduledForIso);
  if (!Number.isFinite(when)) return 0;
  return Math.max(0, Math.ceil((when - Date.now()) / 1000));
}

async function scheduleLifecycleEvent({
  orderId,
  eventType,
  expectedStatus,
  lifecycleVersion = 0,
  scheduledForIso = null,
  jobKeyOverride = null,
}) {
  const defaultDelay = EVENT_DELAYS_SECONDS[eventType];
  if (defaultDelay === undefined && !scheduledForIso) {
    throw new Error(`Unknown lifecycle event type: ${eventType}`);
  }

  const scheduledFor = scheduledForIso
    || new Date(Date.now() + (defaultDelay ?? 0) * 1000).toISOString();
  const delaySeconds = delaySecondsUntil(scheduledFor);
  const jobKey = jobKeyOverride || eventJobKey(orderId, eventType);

  const existing = await orderLifecycleRepository.getJobByKey(jobKey);
  if (existing?.state === 'executed') {
    return;
  }
  if (
    existing?.state === 'scheduled'
    && String(existing?.qstash_message_id || '').trim().length > 0
  ) {
    return;
  }

  await orderLifecycleRepository.createLifecycleJob({
    orderId,
    jobKey,
    eventType,
    qstashMessageId: null,
    scheduledFor,
  });

  try {
    const scheduled = await qstashPublisher.scheduleLifecycleMessage({
      eventId: nextEventId(orderId, eventType),
      eventType,
      orderId,
      expectedStatus,
      delaySeconds,
      traceId: crypto.randomUUID(),
      lifecycleVersion,
    });
    await orderLifecycleRepository.attachQstashMessageId(
      jobKey,
      scheduled.messageId,
      scheduled.scheduledFor || scheduledFor,
    );
  } catch (error) {
    await orderLifecycleRepository.markJobState(jobKey, 'failed', {
      last_error: error?.message || 'qstash_publish_failed',
    });
  }
}

export async function schedulePendingLifecycle(orderId, lifecycleVersion = 0) {
  for (const eventType of PENDING_LIFECYCLE_EVENTS) {
    await scheduleLifecycleEvent({
      orderId,
      eventType,
      expectedStatus: 'pending',
      lifecycleVersion,
    });
  }
}

export async function schedulePickupDelayLifecycle(orderId, lifecycleVersion = 0) {
  await scheduleLifecycleEvent({
    orderId,
    eventType: PICKUP_DELAY_EVENT,
    expectedStatus: 'picked_up',
    lifecycleVersion,
  });
}

export async function schedulePreparingUnassignedLifecycle(
  orderId,
  episodeAt,
  lifecycleVersion = 0,
) {
  const epMs = episodeEpochMs(episodeAt);
  if (!epMs) return;

  for (const eventType of PREPARING_UNASSIGNED_LIFECYCLE_EVENTS) {
    const delaySec = EVENT_DELAYS_SECONDS[eventType] ?? 0;
    const scheduledFor = new Date(epMs + delaySec * 1000).toISOString();
    await scheduleLifecycleEvent({
      orderId,
      eventType,
      expectedStatus: 'preparing',
      lifecycleVersion,
      scheduledForIso: scheduledFor,
      jobKeyOverride: episodeJobKey(orderId, eventType, episodeAt),
    });
  }
}

/**
 * Schedule admin alert 20 minutes after courier assignment (courier_assigned_at).
 */
export async function schedulePreparingAssignedLifecycle(
  orderId,
  courierAssignedAt,
  lifecycleVersion = 0,
) {
  const assignedMs = Date.parse(String(courierAssignedAt || ''));
  const baseMs = Number.isFinite(assignedMs) ? assignedMs : Date.now();
  const scheduledFor = new Date(
    baseMs + EVENT_DELAYS_SECONDS[PREPARING_ASSIGNED_EVENT] * 1000,
  ).toISOString();

  await scheduleLifecycleEvent({
    orderId,
    eventType: PREPARING_ASSIGNED_EVENT,
    expectedStatus: 'preparing',
    lifecycleVersion,
    scheduledForIso: scheduledFor,
  });
}

/**
 * Idempotent scheduler for status / courier changes (lifecycle-sync, reconcile, self-heal).
 */
export async function syncLifecycleForOrder(order, lifecycleVersion = 0) {
  const orderId = String(order?.id || '').trim();
  if (!orderId) return { scheduled: [], cancelled: [] };

  const fulfillmentType = String(order?.fulfillment_type || 'delivery').toLowerCase();
  const isCourierDeliverable = fulfillmentType === 'delivery';

  const status = String(order?.status || '').toLowerCase();
  const hasCourier = String(order?.delivery_person_id || '').trim().length > 0;
  const scheduled = [];
  const cancelled = [];

  const pendingEventsToCancel = [
    ...new Set([...PENDING_LIFECYCLE_EVENTS, ...PENDING_CANCEL_EVENTS]),
  ];

  if (!isCourierDeliverable) {
    await cancelLifecycleEvents(orderId, [
      ...pendingEventsToCancel,
      ...PREPARING_UNASSIGNED_EVENTS,
      PREPARING_ASSIGNED_EVENT,
      PICKUP_DELAY_EVENT,
    ]);
    cancelled.push(
      ...pendingEventsToCancel,
      ...PREPARING_UNASSIGNED_EVENTS,
      PREPARING_ASSIGNED_EVENT,
      PICKUP_DELAY_EVENT,
    );
    return { scheduled, cancelled };
  }

  if (status === 'pending') {
    await schedulePendingLifecycle(orderId, lifecycleVersion);
    scheduled.push(...PENDING_LIFECYCLE_EVENTS);
    await cancelLifecycleEvents(orderId, [
      ...PREPARING_UNASSIGNED_EVENTS,
      PREPARING_ASSIGNED_EVENT,
      PICKUP_DELAY_EVENT,
    ]);
    cancelled.push(...PREPARING_UNASSIGNED_EVENTS, PREPARING_ASSIGNED_EVENT, PICKUP_DELAY_EVENT);
    return { scheduled, cancelled };
  }

  await cancelLifecycleEvents(orderId, pendingEventsToCancel);
  cancelled.push(...pendingEventsToCancel);

  if (status === 'picked_up') {
    await schedulePickupDelayLifecycle(orderId, lifecycleVersion);
    scheduled.push(PICKUP_DELAY_EVENT);
    await cancelLifecycleEvents(orderId, [...PREPARING_UNASSIGNED_EVENTS, PREPARING_ASSIGNED_EVENT]);
    cancelled.push(...PREPARING_UNASSIGNED_EVENTS, PREPARING_ASSIGNED_EVENT);
    return { scheduled, cancelled };
  }

  if (TERMINAL_STATUSES.has(status)) {
    await cancelLifecycleEvents(orderId, [
      ...PREPARING_UNASSIGNED_EVENTS,
      PREPARING_ASSIGNED_EVENT,
      PICKUP_DELAY_EVENT,
    ]);
    cancelled.push(...PREPARING_UNASSIGNED_EVENTS, PREPARING_ASSIGNED_EVENT, PICKUP_DELAY_EVENT);
    return { scheduled, cancelled };
  }

  if (KITCHEN_FLOW_STATUSES.has(status)) {
    await cancelLifecycleEvents(orderId, [PICKUP_DELAY_EVENT]);
    cancelled.push(PICKUP_DELAY_EVENT);

    if (!hasCourier) {
      await cancelLifecycleEvents(orderId, [PREPARING_ASSIGNED_EVENT]);
      cancelled.push(PREPARING_ASSIGNED_EVENT);
      const episodeAt = order.courier_unassigned_episode_at;
      if (episodeAt) {
        await schedulePreparingUnassignedLifecycle(
          orderId,
          episodeAt,
          lifecycleVersion,
        );
        scheduled.push(...PREPARING_UNASSIGNED_LIFECYCLE_EVENTS);
      }
    } else {
      await cancelLifecycleEvents(orderId, [...PREPARING_UNASSIGNED_EVENTS]);
      cancelled.push(...PREPARING_UNASSIGNED_EVENTS);
      await schedulePreparingAssignedLifecycle(
        orderId,
        order.courier_assigned_at,
        lifecycleVersion,
      );
      scheduled.push(PREPARING_ASSIGNED_EVENT);
    }
    return { scheduled, cancelled };
  }

  return { scheduled, cancelled };
}

export async function cancelLifecycleEvents(orderId, eventTypes = []) {
  const scheduledJobs = await orderLifecycleRepository.cancelPendingJobs(orderId, eventTypes);
  for (const job of scheduledJobs) {
    if (job.qstash_message_id) {
      await qstashPublisher.cancelMessage(job.qstash_message_id);
    }
    await orderLifecycleRepository.markJobState(job.job_key, 'cancelled', {
      last_error: null,
    });
  }
}
