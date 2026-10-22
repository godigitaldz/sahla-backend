'use client';

import { useCallback, useEffect, useState } from 'react';
import { ar } from '@/lib/i18n/ar';
import {
  isValidCustomerLocation,
  readStoredCustomerLocation,
  storeCustomerLocation,
  type CustomerLocation,
} from '@/lib/location/customerLocation';

export function useCustomerLocation(slug: string) {
  const [location, setLocation] = useState<CustomerLocation | null>(null);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    const stored = readStoredCustomerLocation(slug);
    if (stored) setLocation(stored);
  }, [slug]);

  const persist = useCallback(
    (next: CustomerLocation) => {
      setLocation(next);
      storeCustomerLocation(slug, next);
      setError(null);
    },
    [slug],
  );

  const requestLocation = useCallback(() => {
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
        persist(next);
        setLoading(false);
      },
      () => {
        setLoading(false);
        setError(ar.geolocationFailed);
      },
      { enableHighAccuracy: true, timeout: 15000, maximumAge: 0 },
    );
  }, [persist]);

  return { location, loading, error, requestLocation, setLocation: persist };
}
