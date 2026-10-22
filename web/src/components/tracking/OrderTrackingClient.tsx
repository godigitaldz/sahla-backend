'use client';

import { useCallback, useEffect, useRef, useState } from 'react';
import { useRouter } from 'next/navigation';
import { ar, formatDa } from '@/lib/i18n/ar';
import type { TrackingOrderProjection } from '@/server/orders/trackingProjection';
import type { TrackingStepId } from '@/lib/orders/trackingTimeline';
import { resolveCanonicalTrackingPath } from '@/lib/orders/trackingSlug';
import { TrackNotificationsPanel } from '@/components/tracking/TrackNotificationsPanel';

type Props = {
  slug: string;
  token: string;
  pushEnabled?: boolean;
};

type LoadState =
  | { kind: 'loading' }
  | { kind: 'ready'; data: TrackingOrderProjection }
  | { kind: 'error'; code: 'not_found' | 'expired' | 'unavailable' | 'rate_limited' | 'offline' | 'unknown' };

const ACTIVE_POLL_MS = 12_000;
const TERMINAL_POLL_MS = 60_000;

function statusLabel(status: string): string {
  switch (status.toLowerCase()) {
    case 'pending':
      return ar.trackStatusPending;
    case 'confirmed':
      return ar.trackStatusConfirmed;
    case 'preparing':
      return ar.trackStatusPreparing;
    case 'ready':
      return ar.trackStatusReady;
    case 'picked_up':
      return ar.trackStatusPickedUp;
    case 'delivered':
      return ar.trackStatusDelivered;
    case 'collected':
      return ar.trackStatusCollected;
    case 'cancelled':
      return ar.trackStatusCancelled;
    default:
      return status;
  }
}

function stepLabel(id: TrackingStepId): string {
  switch (id) {
    case 'placed':
      return ar.trackStepPlaced;
    case 'preparing':
      return ar.trackStepPreparing;
    case 'on_the_way':
      return ar.trackStepOnTheWay;
    case 'delivered':
      return ar.trackStepDelivered;
    case 'accepted':
      return ar.trackStepAccepted;
    case 'ready':
      return ar.trackStepReady;
    case 'collected':
      return ar.trackStepCollected;
    default:
      return id;
  }
}

function fulfillmentLabel(type: string): string {
  if (type === 'pickup') return ar.pickup;
  if (type === 'table') return ar.tableOrderTypeValue;
  return ar.delivery;
}

function formatUpdatedAt(iso: string): string {
  try {
    const d = new Date(iso);
    if (!Number.isFinite(d.getTime())) return '';
    return d.toLocaleString('ar-DZ', {
      hour: '2-digit',
      minute: '2-digit',
      day: 'numeric',
      month: 'short',
    });
  } catch {
    return '';
  }
}

export function OrderTrackingClient({ slug, token, pushEnabled = false }: Props) {
  const router = useRouter();
  const [state, setState] = useState<LoadState>({ kind: 'loading' });
  const [manualBusy, setManualBusy] = useState(false);
  const [cancelBusy, setCancelBusy] = useState(false);
  const [confirmCancelOpen, setConfirmCancelOpen] = useState(false);
  const [cancelMessage, setCancelMessage] = useState<string | null>(null);
  const consecutiveErrors = useRef(0);
  const visibleRef = useRef(true);
  const onlineRef = useRef(typeof navigator === 'undefined' ? true : navigator.onLine);
  const redirectedRef = useRef(false);

  const fetchTracking = useCallback(async () => {
    if (typeof navigator !== 'undefined' && !navigator.onLine) {
      setState((prev) =>
        prev.kind === 'ready' ? prev : { kind: 'error', code: 'offline' },
      );
      return;
    }

    try {
      const res = await fetch(`/api/public/orders/track/${encodeURIComponent(token)}`, {
        method: 'GET',
        cache: 'no-store',
        headers: { Accept: 'application/json' },
      });

      const payload = (await res.json().catch(() => null)) as {
        success?: boolean;
        error?: string;
        data?: TrackingOrderProjection;
      } | null;

      if (res.status === 429) {
        consecutiveErrors.current += 1;
        setState({ kind: 'error', code: 'rate_limited' });
        return;
      }
      if (res.status === 410) {
        consecutiveErrors.current = 0;
        setState({
          kind: 'error',
          code: payload?.error === 'expired' ? 'expired' : 'unavailable',
        });
        return;
      }
      if (res.status === 404 || !payload?.success || !payload.data) {
        consecutiveErrors.current += 1;
        setState({ kind: 'error', code: 'not_found' });
        return;
      }

      consecutiveErrors.current = 0;

      const slugAction = resolveCanonicalTrackingPath(slug, payload.data.restaurant.slug, token);
      if (slugAction.action === 'not_found') {
        setState({ kind: 'error', code: 'not_found' });
        return;
      }
      if (slugAction.action === 'redirect' && !redirectedRef.current) {
        redirectedRef.current = true;
        router.replace(slugAction.path);
        return;
      }

      setState({ kind: 'ready', data: payload.data });
    } catch {
      consecutiveErrors.current += 1;
      setState((prev) => {
        if (prev.kind === 'ready') return prev;
        return {
          kind: 'error',
          code: typeof navigator !== 'undefined' && !navigator.onLine ? 'offline' : 'unknown',
        };
      });
    }
  }, [token, slug, router]);

  useEffect(() => {
    const id = window.setTimeout(() => {
      void fetchTracking();
    }, 0);
    return () => window.clearTimeout(id);
  }, [fetchTracking]);

  useEffect(() => {
    const onVisibility = () => {
      visibleRef.current = document.visibilityState === 'visible';
      if (visibleRef.current) void fetchTracking();
    };
    const onOnline = () => {
      onlineRef.current = true;
      void fetchTracking();
    };
    const onOffline = () => {
      onlineRef.current = false;
    };
    document.addEventListener('visibilitychange', onVisibility);
    window.addEventListener('online', onOnline);
    window.addEventListener('offline', onOffline);
    return () => {
      document.removeEventListener('visibilitychange', onVisibility);
      window.removeEventListener('online', onOnline);
      window.removeEventListener('offline', onOffline);
    };
  }, [fetchTracking]);

  useEffect(() => {
    if (state.kind === 'error' && (state.code === 'expired' || state.code === 'not_found')) {
      return;
    }

    const terminal = state.kind === 'ready' && state.data.terminal;
    const baseMs = terminal ? TERMINAL_POLL_MS : ACTIVE_POLL_MS;
    const backoff = Math.min(4, consecutiveErrors.current);
    const delay = baseMs * (backoff === 0 ? 1 : 2 ** backoff);

    const id = window.setInterval(() => {
      if (!visibleRef.current || !onlineRef.current) return;
      if (terminal && state.kind === 'ready') return;
      void fetchTracking();
    }, delay);

    return () => window.clearInterval(id);
  }, [state, fetchTracking]);

  const onManualRefresh = async () => {
    setManualBusy(true);
    await fetchTracking();
    setManualBusy(false);
  };

  const onCancelOrder = async () => {
    if (cancelBusy) return;
    setCancelBusy(true);
    setCancelMessage(null);
    try {
      const res = await fetch(`/api/public/orders/track/${encodeURIComponent(token)}/cancel`, {
        method: 'POST',
        headers: { Accept: 'application/json' },
        cache: 'no-store',
      });
      const payload = (await res.json().catch(() => null)) as {
        success?: boolean;
        error?: string;
      } | null;

      if (res.ok && payload?.success) {
        setConfirmCancelOpen(false);
        setCancelMessage(ar.trackCancelSuccess);
        await fetchTracking();
        return;
      }

      if (res.status === 409 || payload?.error === 'not_cancellable') {
        setCancelMessage(ar.trackCancelNotAllowed);
        setConfirmCancelOpen(false);
        await fetchTracking();
        return;
      }

      setCancelMessage(ar.trackCancelFailed);
    } catch {
      setCancelMessage(ar.trackCancelFailed);
    } finally {
      setCancelBusy(false);
    }
  };

  const menuSlug =
    state.kind === 'ready' && state.data.restaurant.slug
      ? state.data.restaurant.slug
      : slug;
  const menuHref = `/restaurants/${encodeURIComponent(menuSlug)}`;

  if (state.kind === 'loading') {
    return (
      <div className="flex min-h-screen flex-col items-center justify-center bg-white px-6 text-center">
        <p className="text-sm text-gray-600">{ar.trackLoading}</p>
      </div>
    );
  }

  if (state.kind === 'error') {
    const message =
      state.code === 'expired'
        ? ar.trackExpired
        : state.code === 'not_found'
          ? ar.trackInvalid
          : state.code === 'rate_limited'
            ? ar.trackRateLimited
            : state.code === 'offline'
              ? ar.trackOffline
              : ar.trackUnavailable;

    return (
      <div className="flex min-h-screen flex-col items-center justify-center bg-white px-6 text-center">
        <h1 className="text-xl font-bold text-gray-900">{ar.trackTitle}</h1>
        <p className="mt-3 max-w-md text-sm text-gray-600">{message}</p>
        {state.code !== 'expired' && state.code !== 'not_found' ? (
          <button
            type="button"
            onClick={() => void onManualRefresh()}
            className="mt-6 rounded-full bg-orange-500 px-6 py-3 text-sm font-semibold text-white"
          >
            {ar.trackRetry}
          </button>
        ) : null}
        <a
          href={menuHref}
          className="mt-4 text-sm font-semibold text-orange-600 underline-offset-2 hover:underline"
        >
          {ar.trackBackToMenu}
        </a>
      </div>
    );
  }

  const data = state.data;
  const updatedLabel = formatUpdatedAt(data.updated_at);
  const canCancel = data.status.toLowerCase() === 'pending' && !data.terminal && !data.timeline.cancelled;

  return (
    <div className="mx-auto flex min-h-screen w-full max-w-lg flex-col bg-white px-4 pb-10 pt-6 text-right">
      <div className="flex items-start justify-between gap-3">
        <div>
          <p className="text-xs text-gray-500">{ar.trackTitle}</p>
          <h1 className="mt-1 text-2xl font-bold text-orange-600">{data.order_number}</h1>
          <p className="mt-1 text-sm text-gray-700">{data.restaurant.name}</p>
        </div>
        <button
          type="button"
          onClick={() => void onManualRefresh()}
          disabled={manualBusy}
          className="rounded-full border border-gray-200 px-3 py-1.5 text-xs font-semibold text-gray-700 disabled:opacity-50"
        >
          {ar.trackRefresh}
        </button>
      </div>

      <div className="mt-5 rounded-2xl border border-orange-100 bg-orange-50 px-4 py-3">
        <p className="text-lg font-bold text-orange-700">
          {data.timeline.cancelled ? ar.trackStatusCancelled : statusLabel(data.status)}
        </p>
        {updatedLabel ? (
          <p className="mt-1 text-xs text-orange-800/80">
            {ar.trackLastUpdated}: {updatedLabel}
          </p>
        ) : null}
        {data.estimated_delivery_time ? (
          <p className="mt-1 text-xs text-orange-800/80">
            {ar.trackEta}: {data.estimated_delivery_time} {ar.min}
          </p>
        ) : null}
      </div>

      {cancelMessage ? (
        <p
          className={[
            'mt-3 rounded-xl px-3 py-2 text-sm',
            cancelMessage === ar.trackCancelSuccess
              ? 'bg-green-50 text-green-800'
              : 'bg-red-50 text-red-700',
          ].join(' ')}
          role="status"
        >
          {cancelMessage}
        </p>
      ) : null}

      {canCancel ? (
        <button
          type="button"
          onClick={() => {
            setCancelMessage(null);
            setConfirmCancelOpen(true);
          }}
          disabled={cancelBusy}
          className="mt-4 w-full rounded-full border border-red-200 bg-red-50 px-6 py-3 text-sm font-semibold text-red-700 disabled:opacity-50"
        >
          {ar.trackCancelOrder}
        </button>
      ) : null}

      {confirmCancelOpen ? (
        <div
          className="fixed inset-0 z-50 flex items-end justify-center bg-black/40 p-4 sm:items-center"
          role="dialog"
          aria-modal="true"
          aria-labelledby="track-cancel-title"
        >
          <div className="w-full max-w-sm rounded-2xl bg-white p-5 text-right shadow-lg">
            <h2 id="track-cancel-title" className="text-lg font-bold text-gray-900">
              {ar.trackCancelOrder}
            </h2>
            <p className="mt-2 text-sm text-gray-600">{ar.trackCancelConfirm}</p>
            <div className="mt-5 flex flex-col gap-2">
              <button
                type="button"
                onClick={() => void onCancelOrder()}
                disabled={cancelBusy}
                className="w-full rounded-full bg-red-600 px-4 py-3 text-sm font-semibold text-white disabled:opacity-50"
              >
                {cancelBusy ? ar.trackCancelling : ar.trackCancelConfirmAction}
              </button>
              <button
                type="button"
                onClick={() => setConfirmCancelOpen(false)}
                disabled={cancelBusy}
                className="w-full rounded-full border border-gray-200 px-4 py-3 text-sm font-semibold text-gray-700 disabled:opacity-50"
              >
                {ar.trackCancelDismiss}
              </button>
            </div>
          </div>
        </div>
      ) : null}

      <ol className="mt-6 space-y-3">
        {data.timeline.steps.map((step) => {
          const done = step.state === 'complete';
          const current = step.state === 'current';
          const skipped = step.state === 'skipped';
          return (
            <li key={step.id} className="flex items-center gap-3">
              <span
                className={[
                  'flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-xs font-bold',
                  done || current
                    ? 'bg-orange-500 text-white'
                    : skipped
                      ? 'bg-gray-200 text-gray-400'
                      : 'bg-gray-100 text-gray-400',
                ].join(' ')}
              >
                {done ? '✓' : current ? '•' : ''}
              </span>
              <span
                className={[
                  'text-sm',
                  current ? 'font-bold text-gray-900' : done ? 'text-gray-700' : 'text-gray-400',
                ].join(' ')}
              >
                {stepLabel(step.id)}
              </span>
            </li>
          );
        })}
      </ol>

      <section className="mt-8 rounded-2xl border border-gray-100 bg-gray-50 p-4">
        <h2 className="text-sm font-bold text-gray-900">{ar.trackItems}</h2>
        <ul className="mt-3 space-y-3">
          {data.items.map((item, idx) => (
            <li key={`${item.name}-${idx}`} className="text-sm text-gray-800">
              <div className="flex items-start justify-between gap-3">
                <span className="font-semibold">
                  {item.quantity}× {item.name}
                </span>
                <span className="shrink-0">{formatDa(item.total_price)}</span>
              </div>
              {(item.variant || item.size || (item.supplements && item.supplements.length > 0)) && (
                <p className="mt-1 text-xs text-gray-500">
                  {[item.variant, item.size, ...(item.supplements ?? [])].filter(Boolean).join(' · ')}
                </p>
              )}
            </li>
          ))}
        </ul>
        <div className="mt-4 space-y-1 border-t border-gray-200 pt-3 text-sm">
          {data.pricing.delivery_fee > 0 ? (
            <div className="flex justify-between text-gray-600">
              <span>{ar.deliveryFee}</span>
              <span>{formatDa(data.pricing.delivery_fee)}</span>
            </div>
          ) : null}
          <div className="flex justify-between font-bold text-gray-900">
            <span>{ar.total}</span>
            <span>{formatDa(data.pricing.total_amount)}</span>
          </div>
          <p className="text-xs text-gray-500">
            {data.payment_status === 'paid' ? ar.trackPaymentPaid : ar.trackPaymentPending}
          </p>
        </div>
      </section>

      <section className="mt-4 rounded-2xl border border-gray-100 bg-gray-50 p-4 text-sm text-gray-800">
        <h2 className="font-bold text-gray-900">{ar.trackFulfillment}</h2>
        <p className="mt-2">
          <span className="font-semibold">نوع الطلب:</span> {fulfillmentLabel(data.fulfillment_type)}
        </p>
        {data.fulfillment.type === 'delivery' && data.fulfillment.delivery_location_saved ? (
          <p className="mt-2">{ar.trackDeliveryLocationSaved}</p>
        ) : null}
        {(data.fulfillment.table_label || data.fulfillment.table_number) && (
          <p className="mt-2">
            <span className="font-semibold">{ar.trackTable}:</span>{' '}
            {data.fulfillment.table_label || data.fulfillment.table_number}
          </p>
        )}
      </section>

      <TrackNotificationsPanel
        pushEnabled={pushEnabled}
        token={token}
        orderLoaded={state.kind === 'ready'}
        onForegroundMessage={() => {
          void fetchTracking();
        }}
      />

      <a
        href={menuHref}
        className="mt-6 rounded-full bg-orange-500 px-6 py-3 text-center text-sm font-semibold text-white"
      >
        {ar.trackBackToMenu}
      </a>
    </div>
  );
}
