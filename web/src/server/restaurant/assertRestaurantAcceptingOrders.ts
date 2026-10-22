import {
  getAvailabilityState,
  type WebRestaurantSchedule,
} from '@/lib/restaurant/restaurantAvailability';
import {
  availabilityErrorCode,
  availabilityUserMessage,
} from '@/lib/i18n/orderErrors';

export function assertRestaurantAcceptingOrders(
  restaurant: WebRestaurantSchedule,
): { ok: true } | { ok: false; error: string; message: string } {
  const state = getAvailabilityState(restaurant);
  if (state.canOrder) return { ok: true };

  return {
    ok: false,
    error: availabilityErrorCode(state),
    message: availabilityUserMessage(state) ?? 'المطعم غير متاح حالياً.',
  };
}
