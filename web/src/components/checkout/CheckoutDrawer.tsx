'use client';

import { useEffect, useMemo, useState } from 'react';
import { ar, formatDa } from '@/lib/i18n/ar';
import { resolveOrderFailureMessage } from '@/lib/i18n/orderErrors';
import {
  formatCustomerCoords,
  type CustomerLocation,
} from '@/lib/location/customerLocation';
import type { CreatedWebOrder } from '@/lib/orders/createdWebOrder';
import { SAHLA_COLORS } from '@/lib/theme';
import type { WebCartLine } from '@/lib/cart/useWebCart';
import { TableOrderInfoBox } from '@/components/table/TableOrderInfoBox';

type Props = {
  open: boolean;
  slug: string;
  restaurantName: string;
  items: WebCartLine[];
  subtotal: number;
  orderBlockMessage?: string | null;
  customerLocation: CustomerLocation | null;
  locationLoading: boolean;
  locationError: string | null;
  onRequestLocation: () => void;
  deliveryFee: number;
  feeLoading: boolean;
  feeReady: boolean;
  feeError: string | null;
  tableMode?: boolean;
  tableNumber?: string | null;
  tableLabel?: string | null;
  tableSessionExpired?: boolean;
  tableSessionMessage?: string | null;
  onOpen?: () => void;
  onClose: () => void;
  onBack?: () => void;
  onSuccess: (payload: CreatedWebOrder) => void;
};

export function CheckoutDrawer({
  open,
  slug,
  restaurantName,
  items,
  subtotal,
  orderBlockMessage,
  customerLocation,
  locationLoading,
  locationError,
  onRequestLocation,
  deliveryFee,
  feeLoading,
  feeReady,
  feeError,
  tableMode = false,
  tableNumber,
  tableLabel,
  tableSessionExpired = false,
  tableSessionMessage,
  onOpen,
  onClose,
  onBack,
  onSuccess,
}: Props) {
  const [fulfillmentType, setFulfillmentType] = useState<'delivery' | 'pickup'>('delivery');
  const [phone, setPhone] = useState('');
  const [guestName, setGuestName] = useState('');
  const [notes, setNotes] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [clientRequestId, setClientRequestId] = useState(() => crypto.randomUUID());

  const total = useMemo(
    () => subtotal + (tableMode || fulfillmentType === 'pickup' ? 0 : deliveryFee),
    [subtotal, deliveryFee, fulfillmentType, tableMode],
  );

  useEffect(() => {
    if (!open) return;
    onOpen?.();
    setClientRequestId(crypto.randomUUID());
    setError(null);
    if (fulfillmentType === 'delivery' && !customerLocation && !locationLoading) {
      onRequestLocation();
    }
  }, [open, onOpen, fulfillmentType, customerLocation, locationLoading, onRequestLocation]);

  const submit = async () => {
    setSubmitting(true);
    setError(null);
    let order: CreatedWebOrder | null = null;

    try {
      const csrf = document.cookie
        .split(';')
        .map((c) => c.trim())
        .find((c) => c.startsWith('sahla_table_csrf='))
        ?.split('=')[1];

      const response = tableMode
        ? await fetch('/api/public/table/orders', {
            method: 'POST',
            credentials: 'include',
            headers: {
              'Content-Type': 'application/json',
              ...(csrf ? { 'X-Table-CSRF': decodeURIComponent(csrf) } : {}),
            },
            body: JSON.stringify({
              client_request_id: clientRequestId,
              guest_phone: phone.trim() || null,
              guest_name: guestName.trim() || null,
              special_instructions: notes || null,
              payment_method: 'cash',
              items: items.map((item) => ({
                menu_item_id: item.menu_item_id,
                quantity: item.quantity,
                pricing_size: item.pricing_size ?? null,
                variant_name: item.variant_name ?? null,
                supplement_names: item.supplement_names ?? [],
                special_instructions: item.special_instructions ?? null,
                client_unit_price: item.unit_price,
                client_total_price: item.total_price,
              })),
            }),
          })
        : await fetch(`/api/public/restaurants/${slug}/orders`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          client_request_id: clientRequestId,
          fulfillment_type: fulfillmentType,
          guest_phone: phone,
          guest_name: guestName || null,
          special_instructions: notes || null,
          payment_method: 'cash',
          delivery_address:
            fulfillmentType === 'delivery' && customerLocation
              ? {
                  fullAddress: ar.locationSet,
                  latitude: customerLocation.latitude,
                  longitude: customerLocation.longitude,
                }
              : null,
          items: items.map((item) => ({
            menu_item_id: item.menu_item_id,
            quantity: item.quantity,
            pricing_size: item.pricing_size ?? null,
            variant_name: item.variant_name ?? null,
            supplement_names: item.supplement_names ?? [],
            special_instructions: item.special_instructions ?? null,
            client_unit_price: item.unit_price,
            client_total_price: item.total_price,
          })),
        }),
      });

      let payload: { success?: boolean; error?: string; message?: string; data?: CreatedWebOrder } = {};
      try {
        payload = await response.json();
      } catch {
        payload = {};
      }

      if (!response.ok || !payload.success || !payload.data?.order_number) {
        throw new Error(resolveOrderFailureMessage(payload));
      }

      order = payload.data;
    } catch (e) {
      setError(e instanceof Error ? e.message : ar.orderError);
      setSubmitting(false);
      return;
    }

    setSubmitting(false);
    onSuccess(order);
  };

  if (!open) return null;

  const canSubmit =
    !orderBlockMessage &&
    !tableSessionExpired &&
    (tableMode ||
      (phone.trim().length >= 9 &&
        (fulfillmentType === 'pickup' ||
          (customerLocation != null &&
            feeReady &&
            !feeLoading &&
            !feeError &&
            !locationError))));

  return (
    <div
      className="fixed inset-0 z-[100] flex flex-col justify-end"
      role="dialog"
      aria-modal="true"
      aria-label={ar.checkout}
    >
      <button type="button" className="absolute inset-0 bg-black/45" aria-label={ar.close} onClick={onClose} />

      <div className="relative flex max-h-[min(94dvh,100%)] flex-col overflow-hidden rounded-t-3xl bg-white shadow-2xl">
        <div className="flex shrink-0 justify-center pt-2">
          <span className="h-1 w-10 rounded-full bg-gray-300" aria-hidden />
        </div>

        <div className="flex shrink-0 items-center gap-3 border-b px-4 pb-3 pt-1">
          {onBack ? (
            <button
              type="button"
              className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-gray-100 active:bg-gray-200"
              onClick={onBack}
              aria-label={ar.backToCart}
            >
              ←
            </button>
          ) : (
            <button
              type="button"
              className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-gray-100 active:bg-gray-200"
              onClick={onClose}
              aria-label={ar.close}
            >
              ✕
            </button>
          )}
          <div className="min-w-0 flex-1 text-start">
            <h2 className="text-xl font-bold text-gray-900">{ar.checkout}</h2>
            <p className="text-sm text-gray-500">{restaurantName}</p>
          </div>
          {onBack ? (
            <button
              type="button"
              className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-gray-100 active:bg-gray-200"
              onClick={onClose}
              aria-label={ar.close}
            >
              ✕
            </button>
          ) : null}
        </div>

        <div className="min-h-0 flex-1 overflow-y-auto overscroll-contain px-4 py-4">
          {tableMode ? (
            <TableOrderInfoBox
              className="mb-4"
              tableNumber={tableNumber ?? '—'}
              tableLabel={tableLabel}
              showMinimumOrder={false}
            />
          ) : (
            <div className="grid grid-cols-2 gap-3">
            {(
              [
                {
                  mode: 'delivery' as const,
                  label: ar.delivery,
                  hint: ar.deliveryHint,
                  icon: '🛵',
                },
                {
                  mode: 'pickup' as const,
                  label: ar.pickup,
                  hint: ar.pickupHint,
                  icon: '🏪',
                },
              ] as const
            ).map(({ mode, label, hint, icon }) => {
              const selected = fulfillmentType === mode;
              return (
                <button
                  key={mode}
                  type="button"
                  onClick={() => setFulfillmentType(mode)}
                  className={`rounded-2xl border-2 px-3 py-3 text-start transition active:scale-[0.99] ${
                    selected
                      ? 'border-orange-500 bg-orange-50 shadow-sm'
                      : 'border-gray-200 bg-white hover:border-gray-300'
                  }`}
                >
                  <span className="text-2xl" aria-hidden>
                    {icon}
                  </span>
                  <p className="mt-1 text-sm font-bold text-gray-900">{label}</p>
                  <p className="mt-0.5 text-[11px] leading-snug text-gray-500">{hint}</p>
                </button>
              );
            })}
          </div>
          )}

          {tableSessionExpired && tableSessionMessage ? (
            <div className="mt-4 rounded-xl border border-amber-200 bg-amber-50 px-3 py-2.5 text-sm text-amber-900">
              {tableSessionMessage}
            </div>
          ) : null}

          {orderBlockMessage ? (
            <div className="mt-4 flex items-start gap-2 rounded-xl border border-red-200 bg-red-50 px-3 py-2.5">
              <span className="mt-0.5 text-base leading-none" aria-hidden>
                🕐
              </span>
              <p className="text-start text-sm font-semibold leading-snug text-red-700">
                {orderBlockMessage}
              </p>
            </div>
          ) : null}

          <div className="mt-4 space-y-3">
            {tableMode ? null : (
              <>
            <div>
              <label className="mb-1 block text-sm font-semibold text-gray-900">{ar.phone} *</label>
              <input
                value={phone}
                onChange={(e) => setPhone(e.target.value)}
                className="w-full rounded-xl border border-gray-300 px-3 py-3 text-base outline-none focus:border-orange-400 focus:ring-2 focus:ring-orange-100"
                placeholder="05 XX XX XX XX"
                inputMode="tel"
                dir="ltr"
              />
            </div>

            <div>
              <label className="mb-1 block text-sm font-semibold text-gray-900">{ar.yourName}</label>
              <input
                value={guestName}
                onChange={(e) => setGuestName(e.target.value)}
                className="w-full rounded-xl border border-gray-300 px-3 py-2.5 text-sm outline-none focus:border-orange-400 focus:ring-2 focus:ring-orange-100"
              />
            </div>
              </>
            )}

            {tableMode || fulfillmentType === 'pickup' ? null : (
              <div>
                <label className="mb-1 block text-sm font-semibold text-gray-900">{ar.address} *</label>
                <div className="rounded-xl border border-gray-200 bg-gray-50 p-3">
                  {locationLoading ? (
                    <p className="text-sm text-gray-600">{ar.locationPending}</p>
                  ) : customerLocation ? (
                    <div className="flex items-start gap-3">
                      <span className="text-xl" aria-hidden>
                        📍
                      </span>
                      <div className="min-w-0 flex-1">
                        <p className="text-sm font-semibold text-gray-900">{ar.locationSet}</p>
                        <p className="mt-0.5 text-xs text-gray-500" dir="ltr">
                          {formatCustomerCoords(customerLocation)}
                        </p>
                      </div>
                    </div>
                  ) : (
                    <p className="text-sm text-gray-600">{locationError ?? ar.locationRequired}</p>
                  )}
                  <button
                    type="button"
                    onClick={onRequestLocation}
                    disabled={locationLoading}
                    className="mt-3 text-sm font-semibold text-orange-600 underline-offset-2 hover:underline disabled:opacity-50"
                  >
                    {customerLocation ? ar.refreshLocation : ar.useMyLocation}
                  </button>
                </div>
              </div>
            )}

            <div>
              <label className="mb-1 block text-sm font-semibold text-gray-900">{ar.orderNotes}</label>
              <textarea
                value={notes}
                onChange={(e) => setNotes(e.target.value)}
                className="w-full rounded-xl border border-gray-300 px-3 py-2.5 text-sm outline-none focus:border-orange-400 focus:ring-2 focus:ring-orange-100"
                rows={2}
                dir="rtl"
              />
            </div>
          </div>

          <div className="mt-4 rounded-2xl border border-gray-200 bg-white p-3 text-sm shadow-[0_2px_10px_rgba(0,0,0,0.04)]">
            <div className="flex justify-between gap-3">
              <span>{ar.subtotal}</span>
              <span>{formatDa(subtotal)}</span>
            </div>
            {tableMode || fulfillmentType === 'pickup' ? null : (
              <>
                <div className="mt-1 flex justify-between gap-3">
                  <span>{ar.deliveryFee}</span>
                  <span>{feeLoading ? ar.feeLoading : formatDa(deliveryFee)}</span>
                </div>
                {feeError ? <p className="mt-2 text-xs text-red-600">{feeError}</p> : null}
              </>
            )}
            <div className="mt-2 flex justify-between gap-3 font-bold">
              <span>{ar.total}</span>
              <span>{formatDa(total)}</span>
            </div>
          </div>

          {error ? (
            <div className="mt-3 rounded-xl border border-red-200 bg-red-50 px-3 py-2.5 text-sm leading-relaxed text-red-700">
              {error}
            </div>
          ) : null}
        </div>

        <div className="shrink-0 border-t bg-white px-4 py-3 pb-[max(0.75rem,env(safe-area-inset-bottom))] shadow-[0_-4px_16px_rgba(0,0,0,0.06)]">
          <button
            type="button"
            disabled={submitting || !canSubmit}
            onClick={submit}
            className="w-full rounded-full py-3.5 font-semibold text-white disabled:opacity-50 active:opacity-90"
            style={{ backgroundColor: SAHLA_COLORS.primary }}
          >
            {submitting
              ? ar.loading
              : orderBlockMessage
                ? ar.orderingUnavailable
                : ar.placeOrder}
          </button>
        </div>
      </div>
    </div>
  );
}
