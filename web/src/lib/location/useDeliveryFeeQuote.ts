'use client';

import { useEffect, useState } from 'react';
import { ar } from '@/lib/i18n/ar';
import type { CustomerLocation } from '@/lib/location/customerLocation';

export type DeliveryFeeQuoteState = {
  deliveryFee: number;
  deliveryTax: number;
  loading: boolean;
  error: string | null;
  ready: boolean;
};

export function useDeliveryFeeQuote(
  slug: string | null,
  location: CustomerLocation | null,
): DeliveryFeeQuoteState {
  const [state, setState] = useState<DeliveryFeeQuoteState>({
    deliveryFee: 0,
    deliveryTax: 0,
    loading: false,
    error: null,
    ready: false,
  });

  useEffect(() => {
    if (!slug || !location) {
      setState({
        deliveryFee: 0,
        deliveryTax: 0,
        loading: false,
        error: null,
        ready: false,
      });
      return;
    }

    let cancelled = false;
    setState((prev) => ({ ...prev, loading: true, error: null }));

    fetch(`/api/public/restaurants/${slug}/fees`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        customer_latitude: location.latitude,
        customer_longitude: location.longitude,
      }),
    })
      .then(async (response) => {
        const payload = await response.json();
        if (!response.ok || !payload.success) {
          throw new Error(payload.error ?? ar.feeError);
        }
        if (cancelled) return;
        setState({
          deliveryFee: Number(payload.data.deliveryFee ?? 0),
          deliveryTax: Number(payload.data.deliveryTax ?? 0),
          loading: false,
          error: null,
          ready: true,
        });
      })
      .catch((error) => {
        if (cancelled) return;
        setState({
          deliveryFee: 0,
          deliveryTax: 0,
          loading: false,
          error: error instanceof Error ? error.message : ar.feeError,
          ready: false,
        });
      });

    return () => {
      cancelled = true;
    };
  }, [slug, location?.latitude, location?.longitude]);

  return state;
}
