/** Max rebroadcast window per unassigned episode (seconds). */
export const PREPARING_UNASSIGNED_EPISODE_MAX_SECONDS = 25 * 60;

export const PREPARING_UNASSIGNED_IMMEDIATE_EVENT = 'order.preparing.unassigned.immediate';

export const PREPARING_UNASSIGNED_LIFECYCLE_EVENTS = [
  PREPARING_UNASSIGNED_IMMEDIATE_EVENT,
  'order.preparing.unassigned.2m',
  'order.preparing.unassigned.5m',
];

export function episodeEpochMs(episodeAt) {
  const ms = Date.parse(String(episodeAt ?? ''));
  return Number.isFinite(ms) ? ms : null;
}

export function episodeJobKey(orderId, eventType, episodeAt) {
  const epMs = episodeEpochMs(episodeAt);
  if (!epMs) return `order:${orderId}:${eventType}`;
  return `order:${orderId}:${eventType}:ep:${epMs}`;
}

export function episodeAgeSeconds(episodeAt, nowMs = Date.now()) {
  const epMs = episodeEpochMs(episodeAt);
  if (!epMs) return Number.POSITIVE_INFINITY;
  return Math.max(0, Math.floor((nowMs - epMs) / 1000));
}

export function episodeDispatchKey(orderId, suffix, episodeAt) {
  const epMs = episodeEpochMs(episodeAt);
  if (!epMs) return `order:${orderId}:preparing:unassigned:${suffix}`;
  return `order:${orderId}:preparing:unassigned:${suffix}:ep:${epMs}`;
}

export function resolvePreparingUnassignedJobKey(orderId, eventType, order) {
  if (!PREPARING_UNASSIGNED_LIFECYCLE_EVENTS.includes(eventType)) {
    return null;
  }
  return episodeJobKey(orderId, eventType, order?.courier_unassigned_episode_at);
}

export function isActiveUnassignedEpisode(order, nowMs = Date.now()) {
  const status = String(order?.status || '').toLowerCase();
  const hasCourier = String(order?.delivery_person_id || '').trim().length > 0;
  if (hasCourier) return false;
  if (status !== 'preparing' && status !== 'ready') return false;
  const ageSec = episodeAgeSeconds(order?.courier_unassigned_episode_at, nowMs);
  if (!Number.isFinite(ageSec) || ageSec >= PREPARING_UNASSIGNED_EPISODE_MAX_SECONDS) {
    return false;
  }
  return episodeEpochMs(order?.courier_unassigned_episode_at) != null;
}
