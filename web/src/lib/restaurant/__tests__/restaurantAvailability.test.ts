import { describe, expect, it } from 'vitest';
import {
  getAvailabilityState,
  getNextOpeningTime,
  isAcceptingOrdersNow,
} from '@/lib/restaurant/restaurantAvailability';

const rbMeltyHours = {
  friday: { open: '16:00', close: '23:00', isOpen: true, breakEnabled: false, hasBreak: false },
  monday: { open: '11:00', close: '23:00', isOpen: true, breakEnabled: false, hasBreak: false },
  tuesday: { open: '11:00', close: '23:00', isOpen: true, breakEnabled: false, hasBreak: false },
  wednesday: { open: '11:00', close: '23:00', isOpen: true, breakEnabled: false, hasBreak: false },
  thursday: { open: '11:00', close: '23:00', isOpen: true, breakEnabled: false, hasBreak: false },
  saturday: { open: '11:00', close: '23:00', isOpen: true, breakEnabled: false, hasBreak: false },
  sunday: { open: '11:00', close: '23:00', isOpen: true, breakEnabled: false, hasBreak: false },
};

describe('restaurantAvailability', () => {
  it('treats RB Melty as closed before Friday 16:00 even when is_open=true', () => {
    // 2026-06-19 is a Friday
    const beforeOpen = new Date(2026, 5, 19, 10, 0, 0);
    const schedule = {
      is_open: true,
      opening_hours: rbMeltyHours,
      closing_hours: rbMeltyHours,
    };

    expect(isAcceptingOrdersNow(schedule, beforeOpen)).toBe(false);
    expect(getNextOpeningTime(schedule, beforeOpen)).toBe('16:00');

    const state = getAvailabilityState(schedule, beforeOpen);
    expect(state.canOrder).toBe(false);
    expect(state.kind).toBe('closed');
    expect(state.opensAt).toBe('16:00');
  });

  it('opens Saturday 01:18 schedule when wall clock is 01:41 Africa/Algiers even if instant is UTC', () => {
    const schedule = {
      is_open: true,
      closing_hours: {
        saturday: { open: '01:18', close: '23:59', isOpen: true, breakEnabled: false, hasBreak: false },
      },
    };
    // Sat 01:41 Algiers = Fri 00:41 UTC — Vercel evaluates with UTC unless timezone-aware.
    const vercelInstant = new Date('2026-06-20T00:41:00.000Z');
    expect(isAcceptingOrdersNow(schedule, vercelInstant)).toBe(true);
    expect(getAvailabilityState(schedule, vercelInstant).canOrder).toBe(true);
  });

  it('accepts orders on Saturday after 01:18 with full RB Melty week schedule', () => {
    const schedule = {
      is_open: true,
      opening_hours: {
        friday: { open: '16:00', close: '23:00', isOpen: true, breakEnabled: false, hasBreak: false },
        saturday: { open: '01:18', close: '23:59', isOpen: true, breakEnabled: false, hasBreak: false },
        sunday: { open: '11:00', close: '23:00', isOpen: true, breakEnabled: false, hasBreak: false },
      },
      closing_hours: {
        friday: { open: '16:00', close: '23:00', isOpen: true, breakEnabled: false, hasBreak: false },
        saturday: { open: '01:18', close: '23:59', isOpen: true, breakEnabled: false, hasBreak: false },
        sunday: { open: '11:00', close: '23:00', isOpen: true, breakEnabled: false, hasBreak: false },
      },
    };
    const at = new Date(2026, 5, 20, 1, 36, 0);
    expect(isAcceptingOrdersNow(schedule, at)).toBe(true);
    expect(getAvailabilityState(schedule, at).canOrder).toBe(true);
  });

  it('accepts orders on Saturday after 01:18 open (RB Melty test window)', () => {
    const schedule = {
      is_open: true,
      opening_hours: {
        saturday: {
          open: '01:18',
          close: '23:59',
          isOpen: true,
          breakEnabled: false,
          hasBreak: false,
        },
      },
      closing_hours: {
        saturday: {
          open: '01:18',
          close: '23:59',
          isOpen: true,
          breakEnabled: false,
          hasBreak: false,
        },
      },
    };
    const at = new Date(2026, 5, 20, 1, 24, 0);
    expect(isAcceptingOrdersNow(schedule, at)).toBe(true);
    expect(getAvailabilityState(schedule, at).canOrder).toBe(true);
  });

  it('accepts orders during weekday service window', () => {
    const thursdayNoon = new Date(2026, 5, 18, 12, 0, 0);
    const schedule = {
      is_open: true,
      opening_hours: rbMeltyHours,
      closing_hours: rbMeltyHours,
    };

    expect(isAcceptingOrdersNow(schedule, thursdayNoon)).toBe(true);
    expect(getAvailabilityState(schedule, thursdayNoon).canOrder).toBe(true);
  });

  it('blocks orders during active break window', () => {
    const hours = {
      ...rbMeltyHours,
      monday: {
        open: '11:00',
        close: '23:00',
        isOpen: true,
        breakEnabled: true,
        hasBreak: true,
        breakStart: '14:00',
        breakEnd: '16:00',
      },
    };
    const duringBreak = new Date(2026, 5, 15, 15, 0, 0);
    const schedule = { is_open: true, opening_hours: hours, closing_hours: hours };

    expect(isAcceptingOrdersNow(schedule, duringBreak)).toBe(false);
    const state = getAvailabilityState(schedule, duringBreak);
    expect(state.kind).toBe('break');
    expect(state.breakEndsAt).toBe('16:00');
  });
});
