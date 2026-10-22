'use client';

import { useCallback, useEffect, useState } from 'react';

export type TableSessionState =
  | { status: 'loading' }
  | { status: 'missing' }
  | { status: 'expired'; message: string }
  | {
      status: 'active';
      restaurantSlug: string;
      restaurantName: string;
      tableNumber: string;
      tableLabel?: string | null;
      expiresAt: string;
    };

export function useTableSession(pollMs = 30_000) {
  const [session, setSession] = useState<TableSessionState>({ status: 'loading' });

  const refresh = useCallback(async () => {
    try {
      const res = await fetch('/api/public/table/session', { credentials: 'include' });
      const json = await res.json();
      const data = json.data;

      if (!data || data.status === 'missing') {
        setSession({ status: 'missing' });
        return;
      }

      if (data.status === 'expired') {
        setSession({
          status: 'expired',
          message: data.message ?? 'يرجى إعادة مسح رمز الطاولة',
        });
        return;
      }

      setSession({
        status: 'active',
        restaurantSlug: data.restaurant_slug,
        restaurantName: data.restaurant_name,
        tableNumber: data.table_number,
        tableLabel: data.table_label,
        expiresAt: data.expires_at,
      });
    } catch {
      setSession({ status: 'missing' });
    }
  }, []);

  useEffect(() => {
    void refresh();
    const id = window.setInterval(() => void refresh(), pollMs);
    return () => window.clearInterval(id);
  }, [pollMs, refresh]);

  return { session, refresh };
}
