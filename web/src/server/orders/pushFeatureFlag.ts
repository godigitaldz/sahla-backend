import { isWebOrderTrackingEnabled } from '@/server/orders/trackingFeatureFlag';

/**
 * Phase 2 browser push for web order tracking.
 * Enable with WEB_ORDER_PUSH_ENABLED=true (or 1).
 * When false: no registration, dispatch, or push send.
 */
export function isWebOrderPushEnabled(): boolean {
  const raw = process.env.WEB_ORDER_PUSH_ENABLED?.trim().toLowerCase();
  if (!raw) return false;
  return raw === '1' || raw === 'true' || raw === 'yes' || raw === 'on';
}

export function webOrderPushProvider(): string {
  return (process.env.WEB_ORDER_PUSH_PROVIDER ?? 'fcm_web').trim() || 'fcm_web';
}

/** Both Phase 1 tracking and Phase 2 push must be enabled for registration/send. */
export function isWebOrderPushOperational(): boolean {
  return isWebOrderTrackingEnabled() && isWebOrderPushEnabled();
}
