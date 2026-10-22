/**
 * Feature flag for Phase 1 web order tracking.
 * Enable with WEB_ORDER_TRACKING_ENABLED=true (or 1).
 * Disable to fall back to legacy success page without dropping the table.
 */
export function isWebOrderTrackingEnabled(): boolean {
  const raw = process.env.WEB_ORDER_TRACKING_ENABLED?.trim().toLowerCase();
  if (!raw) return false;
  return raw === '1' || raw === 'true' || raw === 'yes' || raw === 'on';
}
