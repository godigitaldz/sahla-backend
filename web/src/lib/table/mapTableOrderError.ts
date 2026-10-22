import { ar } from '@/lib/i18n/ar';

export function mapTableOrderErrorCode(code: string | undefined | null): string {
  const key = String(code ?? '').toLowerCase();

  if (key.includes('outside_restaurant_range')) return ar.tableOrderOutsideRange;
  if (key.includes('restaurant_location_unavailable')) return ar.tableOrderRestaurantLocationMissing;
  if (key.includes('table_ordering_disabled')) return ar.tableOrderDisabled;
  if (key.includes('restaurant_not_available')) return ar.tableOrderWebMenuDisabled;
  if (key.includes('invalid_table_code')) return ar.tableOrderInvalidCode;
  if (key.includes('table_inactive')) return ar.tableOrderTableInactive;
  if (key.includes('forbidden_origin')) return ar.tableOrderScanFailed;
  if (key.includes('location_locked') || key.includes('rate_limited')) return ar.tableOrderRateLimited;
  if (key.includes('exchange_table_presence_by_location')) return ar.tableOrderServiceUnavailable;
  if (key.includes('could not find the function')) return ar.tableOrderServiceUnavailable;

  return ar.tableOrderScanFailed;
}

export function tableOrderMaxDistanceMeters(): number {
  const raw = Number(process.env.TABLE_ORDER_MAX_DISTANCE_METERS);
  if (Number.isFinite(raw) && raw >= 25 && raw <= 10000) return raw;
  return 10000;
}
