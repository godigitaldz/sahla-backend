'use client';

import { useState } from 'react';
import { useRouter } from 'next/navigation';
import { ar } from '@/lib/i18n/ar';
import { isValidCustomerLocation } from '@/lib/location/customerLocation';
import { mapTableOrderErrorCode } from '@/lib/table/mapTableOrderError';

type Props = {
  tableCode: string;
};

export function TableScanClient({ tableCode }: Props) {
  const router = useRouter();
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  const validateWithLocation = async (latitude: number, longitude: number) => {
    setLoading(true);
    setError(null);
    try {
      const res = await fetch('/api/public/table/validate', {
        method: 'POST',
        credentials: 'include',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          table_code: tableCode,
          latitude,
          longitude,
          device_fingerprint: navigator.userAgent.slice(0, 128),
        }),
      });
      const json = await res.json();
      if (!res.ok || !json.success) {
        setError(
          typeof json.message === 'string' && json.message
            ? json.message
            : mapTableOrderErrorCode(json.error),
        );
        return;
      }
      router.push(`/restaurants/${json.data.restaurant_slug}?table=1`);
    } catch {
      setError(ar.tableOrderScanFailed);
    } finally {
      setLoading(false);
    }
  };

  const requestLocation = () => {
    if (!navigator.geolocation) {
      setError(ar.geolocationUnsupported);
      return;
    }

    setLoading(true);
    setError(null);
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        const next = {
          latitude: pos.coords.latitude,
          longitude: pos.coords.longitude,
        };
        if (!isValidCustomerLocation(next)) {
          setLoading(false);
          setError(ar.geolocationFailed);
          return;
        }
        void validateWithLocation(next.latitude, next.longitude);
      },
      () => {
        setLoading(false);
        setError(ar.geolocationFailed);
      },
      { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 },
    );
  };

  return (
    <main className="mx-auto flex min-h-screen max-w-md flex-col justify-center px-6 py-12">
      <h1 className="mb-2 text-center text-2xl font-bold">{ar.tableOrderTitle}</h1>
      <p className="mb-8 text-center text-sm text-neutral-600">{ar.tableOrderLocationHint}</p>

      {error ? <p className="mb-4 text-center text-sm text-red-600">{error}</p> : null}

      <button
        type="button"
        disabled={loading}
        onClick={() => requestLocation()}
        className="rounded-xl bg-black px-4 py-3 text-white disabled:opacity-50"
      >
        {loading ? ar.locationPending : ar.tableOrderGetLocation}
      </button>
    </main>
  );
}
