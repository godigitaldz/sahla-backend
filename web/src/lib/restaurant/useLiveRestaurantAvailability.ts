'use client';

import { useCallback, useEffect, useMemo, useState } from 'react';
import { availabilityUserMessage } from '@/lib/i18n/orderErrors';
import {
  getAvailabilityState,
  type AvailabilityState,
  type WebRestaurantSchedule,
} from '@/lib/restaurant/restaurantAvailability';

const TICK_MS = 5_000;

function parseOpensAtToday(opensAt: string, now: Date): Date | null {
  const parts = opensAt.split(':');
  if (parts.length < 2) return null;
  const hour = Number(parts[0]);
  const minute = Number(parts[1]);
  if (!Number.isFinite(hour) || !Number.isFinite(minute)) return null;
  return new Date(now.getFullYear(), now.getMonth(), now.getDate(), hour, minute, 0, 0);
}

/** Re-evaluates vacation/hours/break on an interval so banners unlock after open time. */
export function useLiveRestaurantAvailability(
  restaurant: WebRestaurantSchedule,
  options?: { enabled?: boolean },
): { availability: AvailabilityState; orderBlockMessage: string | null; bump: () => void } {
  const enabled = options?.enabled ?? true;
  const [mounted, setMounted] = useState(false);
  const [now, setNow] = useState(() => new Date());

  const bump = useCallback(() => setNow(new Date()), []);

  useEffect(() => {
    if (!enabled) return;
    setMounted(true);
    bump();
  }, [enabled, bump]);

  useEffect(() => {
    if (!enabled) return;
    const id = window.setInterval(bump, TICK_MS);
    return () => window.clearInterval(id);
  }, [enabled, bump]);

  useEffect(() => {
    if (!enabled) return;
    const onVisible = () => {
      if (document.visibilityState === 'visible') bump();
    };
    document.addEventListener('visibilitychange', onVisible);
    return () => document.removeEventListener('visibilitychange', onVisible);
  }, [enabled, bump]);

  const availability = useMemo(
    () => getAvailabilityState(restaurant, now),
    [restaurant, now],
  );

  const orderBlockMessage = mounted ? availabilityUserMessage(availability) : null;

  useEffect(() => {
    if (!enabled || availability.canOrder || !availability.opensAt) return;
    const openAt = parseOpensAtToday(availability.opensAt, now);
    if (!openAt) return;

    const msUntilOpen = openAt.getTime() - now.getTime();
    if (msUntilOpen <= 0) {
      bump();
      return;
    }

    const id = window.setTimeout(bump, msUntilOpen + 250);
    return () => window.clearTimeout(id);
  }, [enabled, availability.canOrder, availability.opensAt, now, bump]);

  return { availability, orderBlockMessage, bump };
}
