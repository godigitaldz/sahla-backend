export type DayHours = {
  open?: string | null;
  close?: string | null;
  isOpen?: boolean | null;
  breakEnabled?: boolean | null;
  hasBreak?: boolean | null;
  breakStart?: string | null;
  breakEnd?: string | null;
};

export type WorkingHours = Record<string, DayHours>;

export type WebRestaurantSchedule = {
  is_open?: boolean | null;
  opening_hours?: unknown;
  closing_hours?: unknown;
  vacation_starts_at?: string | null;
  vacation_returns_at?: string | null;
  business_timezone?: string | null;
};

const WEEKDAYS = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
] as const;

export const DEFAULT_RESTAURANT_TIMEZONE = 'Africa/Algiers';

export function restaurantTimeZone(schedule: WebRestaurantSchedule): string {
  const tz = schedule.business_timezone?.trim();
  return tz || DEFAULT_RESTAURANT_TIMEZONE;
}

type ParsedTime = { hour: number; minute: number };

type ZonedClock = ParsedTime & { weekday: (typeof WEEKDAYS)[number] };

function isTrueish(value: unknown): boolean {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') return value !== 0;
  if (typeof value === 'string') {
    const v = value.trim().toLowerCase();
    return v === 'true' || v === '1' || v === 'yes' || v === 'on';
  }
  return false;
}

function asWorkingHoursMap(value: unknown): WorkingHours | null {
  if (!value || typeof value !== 'object' || Array.isArray(value)) return null;
  return value as WorkingHours;
}

function hasScheduleDays(value: WorkingHours | null): boolean {
  if (!value) return false;
  return Object.keys(value).some((key) =>
    WEEKDAYS.includes(key.toLowerCase() as (typeof WEEKDAYS)[number]),
  );
}

export function effectiveWorkingHours(
  openingHours: unknown,
  closingHours?: unknown,
): WorkingHours | null {
  const closing = asWorkingHoursMap(closingHours);
  if (hasScheduleDays(closing)) return closing;
  const opening = asWorkingHoursMap(openingHours);
  if (hasScheduleDays(opening)) return opening;
  return null;
}

function parseTime(value: string | null | undefined): ParsedTime | null {
  if (!value) return null;
  const parts = value.split(':');
  if (parts.length < 2) return null;
  const hour = Number(parts[0]);
  const minute = Number(parts[1]);
  if (!Number.isFinite(hour) || !Number.isFinite(minute)) return null;
  return { hour, minute };
}

function timeToMinutes(time: ParsedTime): number {
  return time.hour * 60 + time.minute;
}

function previousWeekday(day: (typeof WEEKDAYS)[number]): (typeof WEEKDAYS)[number] {
  const index = WEEKDAYS.indexOf(day);
  return WEEKDAYS[(index + 6) % 7];
}

/** Wall-clock parts in the restaurant timezone (hours JSON is local, not UTC). */
function zonedClock(at: Date, timeZone: string): ZonedClock {
  const parts = new Intl.DateTimeFormat('en-US', {
    timeZone,
    weekday: 'long',
    hour: 'numeric',
    minute: 'numeric',
    hourCycle: 'h23',
  }).formatToParts(at);

  const weekdayRaw = parts.find((p) => p.type === 'weekday')?.value?.toLowerCase() ?? 'monday';
  const weekday = WEEKDAYS.includes(weekdayRaw as (typeof WEEKDAYS)[number])
    ? (weekdayRaw as (typeof WEEKDAYS)[number])
    : 'monday';
  let hour = Number(parts.find((p) => p.type === 'hour')?.value ?? 0);
  const minute = Number(parts.find((p) => p.type === 'minute')?.value ?? 0);
  if (hour === 24) hour = 0;
  return { hour, minute, weekday };
}

function zonedTimeParts(at: Date, timeZone: string): ParsedTime {
  const { hour, minute } = zonedClock(at, timeZone);
  return { hour, minute };
}

function weekdayIndex(day: (typeof WEEKDAYS)[number]): number {
  return WEEKDAYS.indexOf(day);
}

function isTimeBefore(current: ParsedTime, end: ParsedTime): boolean {
  return timeToMinutes(current) < timeToMinutes(end);
}

function isTimeInRange(openTime: string, closeTime: string, current: ParsedTime): boolean {
  const open = parseTime(openTime);
  const close = parseTime(closeTime);
  if (!open || !close) return false;

  const currentMinutes = timeToMinutes(current);
  const openMinutes = timeToMinutes(open);
  const closeMinutes = timeToMinutes(close);

  if (closeMinutes < openMinutes) {
    return currentMinutes >= openMinutes || currentMinutes < closeMinutes;
  }
  return currentMinutes >= openMinutes && currentMinutes < closeMinutes;
}

function isOpenInDayWindow(
  dayHours: DayHours | undefined,
  current: ParsedTime,
  previousDayOvernightOnly = false,
): boolean {
  if (!dayHours) return false;
  if (!isTrueish(dayHours.isOpen)) return false;

  const openTime = dayHours.open ?? undefined;
  const closeTime = dayHours.close ?? undefined;
  if (!openTime || !closeTime) return false;

  const open = parseTime(openTime);
  const close = parseTime(closeTime);
  if (!open || !close) return false;

  const openMinutes = timeToMinutes(open);
  const closeMinutes = timeToMinutes(close);
  const isOvernight = closeMinutes < openMinutes;
  if (previousDayOvernightOnly && !isOvernight) return false;

  const withinOpenRange = previousDayOvernightOnly
    ? isTimeBefore(current, close)
    : isTimeInRange(openTime, closeTime, current);
  if (!withinOpenRange) return false;

  const breakEnabled = isTrueish(dayHours.breakEnabled) || isTrueish(dayHours.hasBreak);
  const breakStart = dayHours.breakStart ?? undefined;
  const breakEnd = dayHours.breakEnd ?? undefined;

  if (
    breakEnabled &&
    breakStart &&
    breakEnd &&
    breakStart.trim() &&
    breakEnd.trim() &&
    breakStart !== breakEnd &&
    isTimeInRange(breakStart, breakEnd, current)
  ) {
    return false;
  }

  return true;
}

export function isOpenAt(
  at: Date,
  workingHours: WorkingHours | null,
  timeZone = DEFAULT_RESTAURANT_TIMEZONE,
): boolean {
  if (!workingHours) return false;
  const clock = zonedClock(at, timeZone);
  const current = { hour: clock.hour, minute: clock.minute };
  if (isOpenInDayWindow(workingHours[clock.weekday], current)) return true;
  return isOpenInDayWindow(workingHours[previousWeekday(clock.weekday)], current, true);
}

export function isOnVacationNow(
  vacationStartsAt?: string | null,
  vacationReturnsAt?: string | null,
  at = new Date(),
): boolean {
  if (!vacationStartsAt || !vacationReturnsAt) return false;
  const start = new Date(vacationStartsAt);
  const end = new Date(vacationReturnsAt);
  if (Number.isNaN(start.getTime()) || Number.isNaN(end.getTime())) return false;
  return at >= start && at < end;
}

export function isAcceptingOrdersNow(
  schedule: WebRestaurantSchedule,
  at = new Date(),
): boolean {
  if (
    isOnVacationNow(schedule.vacation_starts_at, schedule.vacation_returns_at, at)
  ) {
    return false;
  }
  if (schedule.is_open === false) return false;

  const workingHours = effectiveWorkingHours(
    schedule.opening_hours,
    schedule.closing_hours,
  );
  const timeZone = restaurantTimeZone(schedule);
  if (workingHours) return isOpenAt(at, workingHours, timeZone);
  return schedule.is_open ?? true;
}

export function isOnBreakNow(schedule: WebRestaurantSchedule, at = new Date()): boolean {
  if (
    isOnVacationNow(schedule.vacation_starts_at, schedule.vacation_returns_at, at)
  ) {
    return false;
  }
  if (schedule.is_open === false) return false;

  const workingHours = effectiveWorkingHours(
    schedule.opening_hours,
    schedule.closing_hours,
  );
  if (!workingHours) return false;

  const timeZone = restaurantTimeZone(schedule);
  const clock = zonedClock(at, timeZone);
  const todayHours = workingHours[clock.weekday];
  if (!todayHours) return false;

  const breakEnabled =
    isTrueish(todayHours.breakEnabled) || isTrueish(todayHours.hasBreak);
  if (!breakEnabled) return false;

  const breakStart = todayHours.breakStart ?? undefined;
  const breakEnd = todayHours.breakEnd ?? undefined;
  if (
    !breakStart ||
    !breakEnd ||
    !breakStart.trim() ||
    !breakEnd.trim() ||
    breakStart === breakEnd
  ) {
    return false;
  }

  return isTimeInRange(breakStart, breakEnd, { hour: clock.hour, minute: clock.minute });
}

export function getCurrentBreakEndTime(
  schedule: WebRestaurantSchedule,
  at = new Date(),
): string | null {
  if (!isOnBreakNow(schedule, at)) return null;
  const workingHours = effectiveWorkingHours(
    schedule.opening_hours,
    schedule.closing_hours,
  );
  const timeZone = restaurantTimeZone(schedule);
  const todayHours = workingHours?.[zonedClock(at, timeZone).weekday];
  const breakEnd = todayHours?.breakEnd;
  return breakEnd?.trim() ? breakEnd : null;
}

export function getNextOpeningTime(
  schedule: WebRestaurantSchedule,
  at = new Date(),
): string | null {
  if (
    isOnVacationNow(schedule.vacation_starts_at, schedule.vacation_returns_at, at)
  ) {
    return null;
  }

  const workingHours = effectiveWorkingHours(
    schedule.opening_hours,
    schedule.closing_hours,
  );
  if (!workingHours) return null;

  const timeZone = restaurantTimeZone(schedule);
  const breakEnd = getCurrentBreakEndTime(schedule, at);
  if (breakEnd) return breakEnd;

  const clock = zonedClock(at, timeZone);
  const currentMinutes = timeToMinutes({ hour: clock.hour, minute: clock.minute });
  const currentDayIndex = weekdayIndex(clock.weekday);
  const todayHours = workingHours[WEEKDAYS[currentDayIndex]];
  if (todayHours && isTrueish(todayHours.isOpen) && todayHours.open) {
    const open = parseTime(todayHours.open);
    if (open) {
      const openMinutes = timeToMinutes(open);
      if (currentMinutes < openMinutes) return todayHours.open;
    }
  }

  for (let i = 1; i <= 7; i += 1) {
    const nextDay = WEEKDAYS[(currentDayIndex + i) % 7];
    const dayHours = workingHours[nextDay];
    if (dayHours && isTrueish(dayHours.isOpen) && dayHours.open) {
      return dayHours.open;
    }
  }

  return null;
}

export function calendarDay(date: Date): Date {
  return new Date(date.getFullYear(), date.getMonth(), date.getDate());
}

export function formatVacationReturnLabel(
  vacationReturnsAt: string,
  referenceNow = new Date(),
): string {
  const returnDate = new Date(vacationReturnsAt);
  if (Number.isNaN(returnDate.getTime())) return '';

  const returnDay = calendarDay(returnDate);
  const today = calendarDay(referenceNow);
  const tomorrow = new Date(today);
  tomorrow.setDate(tomorrow.getDate() + 1);
  const dayAfterTomorrow = new Date(today);
  dayAfterTomorrow.setDate(dayAfterTomorrow.getDate() + 2);

  if (returnDay.getTime() === tomorrow.getTime()) return 'غداً';
  if (returnDay.getTime() === dayAfterTomorrow.getTime()) return 'بعد غد';

  const dd = String(returnDate.getDate()).padStart(2, '0');
  const mm = String(returnDate.getMonth() + 1).padStart(2, '0');
  return `${dd}/${mm}`;
}

export type AvailabilityBannerKind =
  | 'open'
  | 'closed'
  | 'break'
  | 'vacation'
  | 'manual_closed';

export type AvailabilityState = {
  canOrder: boolean;
  kind: AvailabilityBannerKind;
  opensAt: string | null;
  breakEndsAt: string | null;
  vacationReturnLabel: string | null;
};

export function getAvailabilityState(
  schedule: WebRestaurantSchedule,
  at = new Date(),
): AvailabilityState {
  if (
    isOnVacationNow(schedule.vacation_starts_at, schedule.vacation_returns_at, at)
  ) {
    const vacationReturnLabel = schedule.vacation_returns_at
      ? formatVacationReturnLabel(schedule.vacation_returns_at, at)
      : null;
    return {
      canOrder: false,
      kind: 'vacation',
      opensAt: null,
      breakEndsAt: null,
      vacationReturnLabel,
    };
  }

  const breakEndsAt = getCurrentBreakEndTime(schedule, at);
  if (breakEndsAt) {
    return {
      canOrder: false,
      kind: 'break',
      opensAt: breakEndsAt,
      breakEndsAt,
      vacationReturnLabel: null,
    };
  }

  if (isAcceptingOrdersNow(schedule, at)) {
    return {
      canOrder: true,
      kind: 'open',
      opensAt: null,
      breakEndsAt: null,
      vacationReturnLabel: null,
    };
  }

  const opensAt = getNextOpeningTime(schedule, at);
  const workingHours = effectiveWorkingHours(
    schedule.opening_hours,
    schedule.closing_hours,
  );
  const timeZone = restaurantTimeZone(schedule);

  // Heal stale "opens at HH:MM" after that time already passed today.
  if (opensAt && workingHours) {
    const clock = zonedClock(at, timeZone);
    const todayHours = workingHours[clock.weekday];
    const openParsed = parseTime(opensAt);
    if (
      todayHours?.open === opensAt &&
      openParsed &&
      timeToMinutes({ hour: clock.hour, minute: clock.minute }) >= timeToMinutes(openParsed) &&
      isOpenAt(at, workingHours, timeZone)
    ) {
      return {
        canOrder: true,
        kind: 'open',
        opensAt: null,
        breakEndsAt: null,
        vacationReturnLabel: null,
      };
    }
  }

  return {
    canOrder: false,
    kind: schedule.is_open === false ? 'manual_closed' : 'closed',
    opensAt,
    breakEndsAt: null,
    vacationReturnLabel: null,
  };
}
