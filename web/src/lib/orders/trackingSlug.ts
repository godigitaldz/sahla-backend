export function resolveCanonicalTrackingPath(
  routeSlug: string,
  projectionSlug: string,
  token: string,
): { action: 'ok' } | { action: 'redirect'; path: string } | { action: 'not_found' } {
  const canonical = (projectionSlug || '').trim();
  if (!canonical) return { action: 'not_found' };
  if (canonical === routeSlug) return { action: 'ok' };
  return {
    action: 'redirect',
    path: `/restaurants/${encodeURIComponent(canonical)}/track/${token}`,
  };
}
