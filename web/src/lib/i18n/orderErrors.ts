import { ar } from '@/lib/i18n/ar';
import type { AvailabilityState } from '@/lib/restaurant/restaurantAvailability';

const ORDER_ERROR_MESSAGES: Record<string, string> = {
  restaurant_closed: ar.restaurantClosedGeneric,
  restaurant_on_break: ar.restaurantOnBreakGeneric,
  restaurant_on_vacation: ar.restaurantOnVacationGeneric,
  restaurant_not_found: 'المطعم غير متاح حالياً.',
  restaurant_not_open: ar.restaurantClosedGeneric,
  invalid_phone: 'رقم الهاتف غير صالح.',
  invalid_body: 'تعذّر قراءة الطلب. حدّث الصفحة وحاول مجدداً.',
  delivery_address_required: ar.locationRequired,
  rate_limited: 'محاولات كثيرة. انتظر قليلاً ثم حاول مجدداً.',
  commission_tax_mismatch: ar.orderError,
  order_items_required: 'أضف عناصر إلى سلتك قبل تأكيد الطلب.',
  menu_item_not_from_restaurant: ar.orderError,
  web_order_fallback_customer_id_missing:
    'تعذّر ربط الطلب بحساب زبون. اطلب من المسؤول ضبط manual_order_fallback_customer_id في الإعدادات.',
  guest_phone_required: 'أدخل رقم هاتفك للمتابعة.',
  invalid_fulfillment_type: ar.orderError,
  order_failed: ar.orderError,
  unknown_error: ar.orderError,
  order_response_invalid: ar.orderError,
  order_conflict: ar.orderError,
  price_manipulation_rejected: 'تغيّرت الأسعار. حدّث الصفحة وأعد إضافة العناصر إلى السلة.',
  duplicate_order_recent: 'تم إرسال طلبك بالفعل. انتظر دقيقة قبل إرسال طلب جديد.',
  invalid_session: 'انتهت جلسة الطاولة. أعد مسح رمز QR.',
  session_expired: 'انتهت جلسة الطاولة. أعد مسح رمز QR.',
  table_not_found: ar.orderError,
  table_ordering_disabled: 'طلب الطاولة غير مفعّل لهذا المطعم.',
};

export function resolveOrderFailureMessage(payload: {
  error?: string | null;
  message?: string | null;
}): string {
  const error = payload.error?.trim() ?? '';
  const message = payload.message?.trim() ?? '';

  if (error.includes('منع الطلب المكرر')) return error;
  if (message && message !== ar.orderError) return message;
  return translateOrderError(error || null, message || null);
}

export function availabilityUserMessage(state: AvailabilityState): string | null {
  if (state.canOrder) return null;

  if (state.kind === 'vacation') {
    return state.vacationReturnLabel
      ? `المطعم في إجازة. يعود ${state.vacationReturnLabel}`
      : ar.restaurantOnVacationGeneric;
  }

  if (state.kind === 'break' && state.breakEndsAt) {
    return `المطعم في فترة الراحة، العودة على ${state.breakEndsAt}`;
  }

  if (state.opensAt) {
    return `مغلق، يفتح الساعة ${state.opensAt}`;
  }

  return ar.restaurantClosedGeneric;
}

export function availabilityErrorCode(state: AvailabilityState): string {
  if (state.kind === 'vacation') return 'restaurant_on_vacation';
  if (state.kind === 'break') return 'restaurant_on_break';
  return 'restaurant_closed';
}

export function translateOrderError(
  code: string | null | undefined,
  fallbackMessage?: string | null,
): string {
  if (fallbackMessage?.trim()) return fallbackMessage.trim();
  if (!code) return ar.orderError;
  if (code.includes('orders_fulfillment_type_check')) {
    return 'طلب الطاولة غير مفعّل في قاعدة البيانات بعد. اطلب من المسؤول تطبيق migration الطاولة.';
  }
  return ORDER_ERROR_MESSAGES[code] ?? ar.orderError;
}
