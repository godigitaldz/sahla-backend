'use client';

import { ar, formatDa } from '@/lib/i18n/ar';
import { type WebRestaurantSchedule } from '@/lib/restaurant/restaurantAvailability';
import { TableOrderInfoBox } from '@/components/table/TableOrderInfoBox';
import { SAHLA_COLORS } from '@/lib/theme';

export type WebRestaurantProfile = WebRestaurantSchedule & {
  id: string;
  name: string;
  name_ar?: string | null;
  name_latin?: string | null;
  logo_url?: string | null;
  public_slug?: string | null;
  delivery_fee?: number | null;
  minimum_order?: number | null;
  estimated_delivery_time?: number | null;
};

type Props = {
  restaurant: WebRestaurantProfile;
  statusMessage?: string | null;
  deliveryFee: number;
  feeLoading: boolean;
  feeReady: boolean;
  feeError: string | null;
  locationLoading: boolean;
  onRequestLocation: () => void;
  tableMode?: boolean;
  tableNumber?: string | null;
  tableLabel?: string | null;
};

function InfoBox({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex min-w-0 flex-1 flex-col items-center justify-center px-1 text-center">
      <span className="text-[9px] font-semibold leading-tight text-gray-600">{label}</span>
      <span className="mt-0.5 text-[11px] font-bold leading-tight text-gray-900">{value}</span>
    </div>
  );
}

function Divider() {
  return <div className="mx-1 h-9 w-px shrink-0 bg-gray-200" aria-hidden />;
}

function DeliveryFeeCell({
  deliveryFee,
  feeLoading,
  feeReady,
  feeError,
  locationLoading,
  onRequestLocation,
}: {
  deliveryFee: number;
  feeLoading: boolean;
  feeReady: boolean;
  feeError: string | null;
  locationLoading: boolean;
  onRequestLocation: () => void;
}) {
  const busy = locationLoading || feeLoading;

  return (
    <div className="flex min-w-0 flex-1 flex-col items-center justify-center px-0.5 text-center">
      <span className="text-[9px] font-semibold leading-tight text-gray-600">
        {ar.deliveryFeeLabel}
      </span>

      {feeReady ? (
        <span className="mt-0.5 text-[11px] font-bold leading-tight text-gray-900">
          {deliveryFee <= 0 ? ar.freeDelivery : formatDa(deliveryFee)}
        </span>
      ) : feeError ? (
        <button
          type="button"
          onClick={onRequestLocation}
          className="mt-1 inline-flex max-w-full items-center justify-center gap-1 rounded-full border border-red-200 bg-red-50 px-2 py-1 text-[9px] font-bold text-red-700 transition active:scale-[0.97]"
        >
          <span aria-hidden>↻</span>
          <span>{ar.retryLocation}</span>
        </button>
      ) : (
        <button
          type="button"
          disabled={busy}
          onClick={onRequestLocation}
          className="mt-1 inline-flex max-w-full items-center justify-center gap-1 rounded-full px-2.5 py-1.5 text-[9px] font-bold text-white shadow-[0_3px_10px_rgba(251,140,0,0.45)] transition active:scale-[0.96] disabled:opacity-70"
          style={{
            background: busy
              ? SAHLA_COLORS.primary
              : `linear-gradient(135deg, ${SAHLA_COLORS.primary} 0%, ${SAHLA_COLORS.primaryDark} 100%)`,
          }}
        >
          <span className="text-[11px] leading-none" aria-hidden>
            📍
          </span>
          <span className="leading-tight">
            {busy ? ar.locationPending : ar.getLocationForFee}
          </span>
        </button>
      )}
    </div>
  );
}

export function RestaurantInfoPanel({
  restaurant,
  statusMessage,
  deliveryFee,
  feeLoading,
  feeReady,
  feeError,
  locationLoading,
  onRequestLocation,
  tableMode = false,
  tableNumber,
  tableLabel,
}: Props) {
  const deliveryMinutes = Math.max(0, Number(restaurant.estimated_delivery_time ?? 30));
  const minimumOrder = Math.max(0, Number(restaurant.minimum_order ?? 0));

  return (
    <div className="mt-4 space-y-2">
      {tableMode ? (
        <TableOrderInfoBox
          tableNumber={tableNumber ?? '—'}
          tableLabel={tableLabel}
          minimumOrder={minimumOrder}
        />
      ) : (
      <div className="rounded-2xl border border-gray-200 bg-white px-2.5 py-3 shadow-[0_2px_10px_rgba(0,0,0,0.04)]">
          <div className="flex items-stretch">
            <DeliveryFeeCell
              deliveryFee={deliveryFee}
              feeLoading={feeLoading}
              feeReady={feeReady}
              feeError={feeError}
              locationLoading={locationLoading}
              onRequestLocation={onRequestLocation}
            />
            <Divider />
            <InfoBox label={ar.minimumOrderLabel} value={formatDa(minimumOrder)} />
            <Divider />
            <InfoBox label={ar.delivery} value={`${deliveryMinutes} ${ar.minuteShort}`} />
          </div>
      </div>
      )}

      {statusMessage ? (
        <div className="flex items-start gap-2 rounded-xl border border-gray-200 bg-white px-3 py-2.5">
          <span className="mt-0.5 text-base leading-none text-red-600" aria-hidden>
            🕐
          </span>
          <p className="text-start text-[12px] font-semibold leading-snug text-red-700">
            {statusMessage}
          </p>
        </div>
      ) : null}
    </div>
  );
}
