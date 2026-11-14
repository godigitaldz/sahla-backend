import { supabaseAdmin } from '../config/supabase.js';
import { SAHLA_UTC_OFFSET_MS } from '../shared/time/sahlaBusinessDay.js';

const WEEKDAYS = [
  'sunday',
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
];

/**
 * Returns current Algerian local time (UTC+1, Africa/Algiers).
 * Algeria is permanently at UTC+1 (no DST).
 */
export function getAlgiersTime(date = new Date()) {
  const wall = new Date(date.getTime() + SAHLA_UTC_OFFSET_MS);
  const weekday = WEEKDAYS[wall.getUTCDay()];
  const hours = wall.getUTCHours();
  const minutes = wall.getUTCMinutes();
  const seconds = wall.getUTCSeconds();
  const totalMinutes = hours * 60 + minutes;
  const timeString = `${String(hours).padStart(2, '0')}:${String(minutes).padStart(2, '0')}`;
  const fullTimeString = `${timeString}:${String(seconds).padStart(2, '0')}`;

  const y = wall.getUTCFullYear();
  const m = String(wall.getUTCMonth() + 1).padStart(2, '0');
  const d = String(wall.getUTCDate()).padStart(2, '0');
  const dateString = `${y}-${m}-${d}`;

  return {
    weekday,
    hours,
    minutes,
    seconds,
    totalMinutes,
    timeString,
    fullTimeString,
    dateString,
    wallDate: wall,
  };
}

/**
 * Parse "HH:mm" into total minutes from midnight (0..1440).
 */
export function parseTimeToMinutes(str) {
  if (typeof str !== 'string') return null;
  const trimmed = str.trim();
  if (!trimmed) return null;
  if (trimmed === '24:00' || trimmed === '24:00:00') return 1440;

  const parts = trimmed.split(':');
  if (parts.length < 2) return null;
  const h = parseInt(parts[0], 10);
  const m = parseInt(parts[1], 10);
  if (Number.isNaN(h) || Number.isNaN(m)) return null;

  return Math.min(1440, Math.max(0, h * 60 + m));
}

/**
 * Evaluates whether a restaurant is open right now based on its real schedule.
 */
export function isRestaurantOpenNow(restaurant, date = new Date()) {
  const algiers = getAlgiersTime(date);

  // 1. Vacation period check
  if (restaurant.vacation_starts_at && restaurant.vacation_returns_at) {
    const start = new Date(restaurant.vacation_starts_at);
    const end = new Date(restaurant.vacation_returns_at);
    if (!Number.isNaN(start.getTime()) && !Number.isNaN(end.getTime())) {
      if (date >= start && date < end) {
        return false;
      }
    }
  }

  // 2. Schedule lookup (closing_hours / opening_hours, or backups when is_open was false)
  const hoursMap =
    restaurant.closing_hours ||
    restaurant.opening_hours ||
    restaurant.closing_hours_backup ||
    restaurant.opening_hours_backup;
  if (!hoursMap || typeof hoursMap !== 'object') {
    // If no schedule configured at all, retain current is_open state
    return Boolean(restaurant.is_open);
  }

  const todaySchedule = hoursMap[algiers.weekday];
  if (!todaySchedule) {
    return Boolean(restaurant.is_open);
  }

  // Explicitly marked closed today
  if (todaySchedule.isOpen === false || todaySchedule.is_open === false) {
    return false;
  }

  const openMin = parseTimeToMinutes(todaySchedule.open);
  const closeMin = parseTimeToMinutes(todaySchedule.close);

  if (openMin === null || closeMin === null) {
    return Boolean(restaurant.is_open);
  }

  let inWorkingRange = false;
  if (openMin === closeMin) {
    inWorkingRange = true; // 24h
  } else if (openMin < closeMin) {
    // Normal daytime shift (e.g. 11:00 to 22:00)
    inWorkingRange = algiers.totalMinutes >= openMin && algiers.totalMinutes < closeMin;
  } else {
    // Overnight shift (e.g. 17:00 to 02:00)
    inWorkingRange = algiers.totalMinutes >= openMin || algiers.totalMinutes < closeMin;
  }

  if (!inWorkingRange) {
    return false;
  }

  // 3. Break check
  const breakEnabled = todaySchedule.breakEnabled || todaySchedule.hasBreak;
  if (breakEnabled && todaySchedule.breakStart && todaySchedule.breakEnd) {
    const bStart = parseTimeToMinutes(todaySchedule.breakStart);
    const bEnd = parseTimeToMinutes(todaySchedule.breakEnd);
    if (bStart !== null && bEnd !== null && bStart !== bEnd) {
      if (bStart < bEnd) {
        if (algiers.totalMinutes >= bStart && algiers.totalMinutes < bEnd) {
          return false;
        }
      } else {
        if (algiers.totalMinutes >= bStart || algiers.totalMinutes < bEnd) {
          return false;
        }
      }
    }
  }

  return true;
}

/**
 * Synchronize restaurant working hours across all verified restaurants in DB.
 * Runs in background cron tick to keep `restaurants.is_open` 100% in sync with real hours.
 *
 * @param {object} [options]
 * @param {object} [options.logger=console]
 */
export async function syncRestaurantWorkingHours({ logger = console } = {}) {
  const startedAt = Date.now();
  const now = new Date();
  const algiersTime = getAlgiersTime(now);

  const { data: restaurants, error } = await supabaseAdmin
    .from('restaurants')
    .select('id, name, is_open, is_verified, opening_hours, closing_hours, opening_hours_backup, closing_hours_backup, vacation_starts_at, vacation_returns_at')
    .eq('is_verified', true);

  if (error) {
    logger.error?.('[RestaurantWorkingHours] Failed to fetch restaurants:', error.message);
    throw error;
  }

  const list = restaurants || [];
  const toOpen = [];
  const toClose = [];

  for (const r of list) {
    const shouldBeOpen = isRestaurantOpenNow(r, now);
    const currentlyOpen = r.is_open === true;

    if (shouldBeOpen && !currentlyOpen) {
      toOpen.push(r.id);
    } else if (!shouldBeOpen && currentlyOpen) {
      toClose.push(r.id);
    }
  }

  let openedCount = 0;
  let closedCount = 0;

  if (toClose.length > 0) {
    const { error: closeErr } = await supabaseAdmin
      .from('restaurants')
      .update({ is_open: false, updated_at: now.toISOString() })
      .in('id', toClose);

    if (closeErr) {
      logger.error?.('[RestaurantWorkingHours] Failed to auto-close restaurants:', closeErr.message);
    } else {
      closedCount = toClose.length;
      logger.log?.(`[RestaurantWorkingHours] Auto-closed ${closedCount} restaurants outside working hours`);
    }
  }

  if (toOpen.length > 0) {
    const { error: openErr } = await supabaseAdmin
      .from('restaurants')
      .update({ is_open: true, updated_at: now.toISOString() })
      .in('id', toOpen);

    if (openErr) {
      logger.error?.('[RestaurantWorkingHours] Failed to auto-open restaurants:', openErr.message);
    } else {
      openedCount = toOpen.length;
      logger.log?.(`[RestaurantWorkingHours] Auto-opened ${openedCount} restaurants inside working hours`);
    }
  }

  const durationMs = Date.now() - startedAt;

  return {
    success: true,
    algiers_time: algiersTime.fullTimeString,
    weekday: algiersTime.weekday,
    total_evaluated: list.length,
    opened_count: openedCount,
    closed_count: closedCount,
    duration_ms: durationMs,
  };
}
