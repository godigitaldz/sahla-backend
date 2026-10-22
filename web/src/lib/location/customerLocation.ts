/** Full GPS precision for fee preview + order insert (never round before API). */
export type CustomerLocation = {
  latitude: number;
  longitude: number;
};

export function isValidCustomerLocation(
  value: CustomerLocation | null | undefined,
): value is CustomerLocation {
  if (!value) return false;
  return (
    Number.isFinite(value.latitude) &&
    Number.isFinite(value.longitude) &&
    value.latitude >= 18 &&
    value.latitude <= 37.5 &&
    value.longitude >= -9 &&
    value.longitude <= 12
  );
}

/** UI label only — does not affect fee requests. */
export function formatCustomerCoords(location: CustomerLocation): string {
  return `${location.latitude.toFixed(7)}, ${location.longitude.toFixed(7)}`;
}

const STORAGE_PREFIX = 'sahla_web_customer_location:';

export function readStoredCustomerLocation(slug: string): CustomerLocation | null {
  if (typeof window === 'undefined') return null;
  try {
    const raw = sessionStorage.getItem(`${STORAGE_PREFIX}${slug}`);
    if (!raw) return null;
    const parsed = JSON.parse(raw) as CustomerLocation;
    return isValidCustomerLocation(parsed) ? parsed : null;
  } catch {
    return null;
  }
}

export function storeCustomerLocation(slug: string, location: CustomerLocation): void {
  if (typeof window === 'undefined') return;
  try {
    sessionStorage.setItem(`${STORAGE_PREFIX}${slug}`, JSON.stringify(location));
  } catch {
    /* private browsing */
  }
}
