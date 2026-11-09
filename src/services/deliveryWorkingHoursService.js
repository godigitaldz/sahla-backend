import { supabaseAdmin } from '../config/supabase.js';
import { SAHLA_UTC_OFFSET_MS } from '../shared/time/sahlaBusinessDay.js';

export const CONFIG_KEY_WORKING_HOURS = 'delivery_personnel_working_hours';
export const CONFIG_KEY_AUTO_CLOSED = 'delivery_personnel_auto_closed_ids';
export const CONFIG_KEY_MORNING_GREETING = 'delivery_morning_greeting_history';

export const DEFAULT_WORKING_HOURS = {
  enabled: true,
  default_start: '11:00',
  default_end: '22:00',
  timezone: 'Africa/Algiers',
  courier_schedules: {},
};

/**
 * Returns the current date/time components in Africa/Algiers (UTC+1).
 * Algeria does not observe daylight saving time (constant UTC+1).
 *
 * @param {Date} [date=new Date()]
 */
export function getAlgiersTime(date = new Date()) {
  const wall = new Date(date.getTime() + SAHLA_UTC_OFFSET_MS);
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
 * Parse "HH:mm" or "HH:mm:ss" string into total minutes from midnight (0 to 1440).
 * Supports "24:00" as 1440.
 *
 * @param {string} str
 * @param {number} defaultVal
 * @returns {number}
 */
export function parseTimeToMinutes(str, defaultVal = 0) {
  if (typeof str !== 'string') return defaultVal;
  const trimmed = str.trim();
  if (!trimmed) return defaultVal;

  if (trimmed === '24:00' || trimmed === '24:00:00') {
    return 1440;
  }

  const parts = trimmed.split(':');
  if (parts.length < 2) return defaultVal;

  const h = parseInt(parts[0], 10);
  const m = parseInt(parts[1], 10);
  if (Number.isNaN(h) || Number.isNaN(m)) return defaultVal;

  return Math.min(1440, Math.max(0, h * 60 + m));
}

/**
 * Check whether a minute timestamp (0..1439) falls inside [startMinutes, endMinutes).
 * Handles overnight shifts (e.g. 20:00 to 02:00) where start > end.
 * If start === end or span is 24h (0 to 1440), returns true (24h coverage).
 *
 * @param {number} currentMin
 * @param {number} startMin
 * @param {number} endMin
 * @returns {boolean}
 */
export function isTimeInInterval(currentMin, startMin, endMin) {
  if (startMin === endMin || (startMin === 0 && endMin >= 1440)) {
    return true; // 24/7
  }

  if (startMin < endMin) {
    // Normal day shift: e.g. 11:00 (660) to 22:00 (1320)
    return currentMin >= startMin && currentMin < endMin;
  }

  // Overnight shift: e.g. 22:00 (1320) to 06:00 (360)
  return currentMin >= startMin || currentMin < endMin;
}

/**
 * Fetch working hours configuration from system_config.
 * Seeds with default if record does not exist.
 */
export async function getWorkingHoursConfig() {
  try {
    const { data, error } = await supabaseAdmin
      .from('system_config')
      .select('config_value')
      .eq('config_key', CONFIG_KEY_WORKING_HOURS)
      .maybeSingle();

    if (error) throw error;

    if (!data?.config_value) {
      // Seed initial default config
      await saveWorkingHoursConfig(DEFAULT_WORKING_HOURS);
      return { ...DEFAULT_WORKING_HOURS };
    }

    const raw = data.config_value;
    const parsed = typeof raw === 'object' && !Array.isArray(raw)
      ? raw
      : JSON.parse(raw || '{}');

    return {
      enabled: parsed.enabled !== false,
      default_start: parsed.default_start || DEFAULT_WORKING_HOURS.default_start,
      default_end: parsed.default_end || DEFAULT_WORKING_HOURS.default_end,
      timezone: parsed.timezone || DEFAULT_WORKING_HOURS.timezone,
      courier_schedules: parsed.courier_schedules || {},
    };
  } catch (err) {
    console.error('getWorkingHoursConfig error:', err);
    return { ...DEFAULT_WORKING_HOURS };
  }
}

/**
 * Upsert working hours configuration in system_config.
 */
export async function saveWorkingHoursConfig(cfg) {
  const merged = {
    enabled: cfg.enabled !== false,
    default_start: cfg.default_start || DEFAULT_WORKING_HOURS.default_start,
    default_end: cfg.default_end || DEFAULT_WORKING_HOURS.default_end,
    timezone: cfg.timezone || DEFAULT_WORKING_HOURS.timezone,
    courier_schedules: cfg.courier_schedules || {},
  };

  const { error } = await supabaseAdmin
    .from('system_config')
    .upsert({
      config_key: CONFIG_KEY_WORKING_HOURS,
      config_value: merged,
      config_type: 'object',
      category: 'delivery',
      is_active: true,
      description: 'Delivery personnel working hours configuration (default hours, timezone, individual schedules)',
      updated_at: new Date().toISOString(),
    }, { onConflict: 'config_key' });

  if (error) throw error;
  return merged;
}

/**
 * Fetch array of courier IDs currently auto-closed by schedule.
 */
export async function getAutoClosedCourierIds() {
  try {
    const { data, error } = await supabaseAdmin
      .from('system_config')
      .select('config_value')
      .eq('config_key', CONFIG_KEY_AUTO_CLOSED)
      .maybeSingle();

    if (error) throw error;

    if (!data?.config_value) {
      return [];
    }

    const raw = data.config_value;
    const arr = Array.isArray(raw)
      ? raw
      : (typeof raw === 'string' ? JSON.parse(raw || '[]') : []);

    return arr.map(String).filter(Boolean);
  } catch (err) {
    console.error('getAutoClosedCourierIds error:', err);
    return [];
  }
}

/**
 * Persist array of auto-closed courier IDs in system_config.
 */
export async function saveAutoClosedCourierIds(ids) {
  const uniqueIds = [...new Set((ids || []).map(String).filter(Boolean))];

  const { error } = await supabaseAdmin
    .from('system_config')
    .upsert({
      config_key: CONFIG_KEY_AUTO_CLOSED,
      config_value: uniqueIds,
      config_type: 'array',
      category: 'delivery',
      is_active: true,
      description: 'List of courier IDs automatically set to unavailable (is_available=false) by working hours schedule',
      updated_at: new Date().toISOString(),
    }, { onConflict: 'config_key' });

  if (error) throw error;
  return uniqueIds;
}

/**
 * Update schedule for a specific courier or remove override.
 *
 * @param {string} identifier - courier_id (delivery_personnel.id) or user_id
 * @param {{ start?: string, end?: string, enabled?: boolean } | null} schedule
 */
export async function updateCourierSchedule(identifier, schedule) {
  const key = String(identifier || '').trim();
  if (!key) throw new Error('Courier identifier is required');

  const config = await getWorkingHoursConfig();
  const schedules = { ...(config.courier_schedules || {}) };

  if (schedule === null) {
    delete schedules[key];
  } else {
    schedules[key] = {
      start: schedule.start || config.default_start,
      end: schedule.end || config.default_end,
      enabled: schedule.enabled !== false,
      updated_at: new Date().toISOString(),
    };
  }

  config.courier_schedules = schedules;
  await saveWorkingHoursConfig(config);
  return config;
}

// In-memory cache to avoid reading system_config on every minute cron run
let cachedGreetingState = {
  date: null,
  sent_user_ids: new Set(),
};

/**
 * Fetch today's morning greeting delivery tracker state.
 * Resets automatically each calendar day (Africa/Algiers).
 */
export async function getMorningGreetingState() {
  const algiersTime = getAlgiersTime();
  const today = algiersTime.dateString;

  if (cachedGreetingState.date === today && cachedGreetingState.sent_user_ids.size > 0) {
    return {
      date: today,
      sent_user_ids: cachedGreetingState.sent_user_ids,
    };
  }

  try {
    const { data, error } = await supabaseAdmin
      .from('system_config')
      .select('config_value')
      .eq('config_key', CONFIG_KEY_MORNING_GREETING)
      .maybeSingle();

    if (error) throw error;

    let parsed = data?.config_value;
    if (typeof parsed === 'string') {
      try {
        parsed = JSON.parse(parsed);
      } catch (_) {
        parsed = {};
      }
    }

    if (!parsed || parsed.date !== today) {
      cachedGreetingState = {
        date: today,
        sent_user_ids: new Set(),
      };
      return cachedGreetingState;
    }

    const ids = new Set(Array.isArray(parsed.sent_user_ids) ? parsed.sent_user_ids : []);
    cachedGreetingState = {
      date: today,
      sent_user_ids: ids,
    };
    return cachedGreetingState;
  } catch (err) {
    console.error('getMorningGreetingState error:', err);
    if (cachedGreetingState.date !== today) {
      cachedGreetingState = { date: today, sent_user_ids: new Set() };
    }
    return cachedGreetingState;
  }
}

/**
 * Persist today's morning greeting tracker state to system_config.
 * Exactly 1 database write for all couriers.
 */
export async function saveMorningGreetingState(date, sentSet) {
  cachedGreetingState = {
    date,
    sent_user_ids: new Set(sentSet),
  };

  const payload = {
    date,
    sent_user_ids: [...sentSet],
    updated_at: new Date().toISOString(),
  };

  const { error } = await supabaseAdmin
    .from('system_config')
    .upsert({
      config_key: CONFIG_KEY_MORNING_GREETING,
      config_value: payload,
      config_type: 'object',
      category: 'delivery',
      is_active: true,
      description: 'Tracks delivery personnel who received the morning shift start push notification today',
      updated_at: new Date().toISOString(),
    }, { onConflict: 'config_key' });

  if (error) {
    console.error('saveMorningGreetingState error:', error);
  }
}

/**
 * Dispatch personalized morning shift start push notification to available delivery men.
 *
 * Title: صباح الخير ( اسمه ) بداية نهار موفقة
 * Body: اللهم ارزقنا رزقاً واسعاً حلالاً طيباً
 *
 * High-Concurrency / Zero-DB-Pressure Safeguards:
 * 1. persist_notification: false -> ZERO rows written to notifications table.
 * 2. In-memory deduplication + single system_config row update per day -> 1 total DB write even for 10,000 couriers.
 * 3. Bounded parallel concurrency (15 at a time with 25ms delay) -> prevents socket starvation.
 *
 * @param {object} [options]
 * @param {Array} [options.couriers=null] - Optional pre-fetched couriers list
 * @param {boolean} [options.force=false] - If true, re-sends even if already sent today
 * @param {string} [options.targetUserId=null] - Send only to specific user_id (for testing)
 * @param {object} [options.logger=console]
 */
export async function sendMorningGreetingToAvailableCouriers({
  couriers = null,
  force = false,
  targetUserId = null,
  logger = console,
} = {}) {
  const algiersTime = getAlgiersTime();
  const today = algiersTime.dateString;

  const state = await getMorningGreetingState();
  const sentUserIds = force ? new Set() : new Set(state.sent_user_ids);

  let list = couriers;
  if (!list) {
    let query = supabaseAdmin
      .from('delivery_personnel')
      .select('id, user_id, delivery_name, is_available, user:user_id(id, name, role)')
      .eq('is_available', true);

    if (targetUserId) {
      query = query.eq('user_id', targetUserId);
    }

    const { data, error } = await query;
    if (error) {
      logger.error?.('Failed to fetch available delivery personnel for greeting:', error);
      throw error;
    }
    list = data || [];
  }

  const eligible = [];
  for (const c of list) {
    const uid = String(c.user_id || '').trim();
    if (!uid) continue;
    if (targetUserId && uid !== targetUserId) continue;

    if (c.is_available !== true) continue;

    const role = c.user?.role;
    if (role && role !== 'delivery_man') continue;

    if (!force && sentUserIds.has(uid)) continue;

    eligible.push(c);
  }

  if (eligible.length === 0) {
    return {
      success: true,
      sent_count: 0,
      eligible_count: 0,
      total_available: list.filter((c) => c.is_available).length,
      already_sent_today: sentUserIds.size,
      date: today,
    };
  }

  logger.log?.(`[MorningGreeting] Dispatching morning greeting to ${eligible.length} available couriers...`);

  const CONCURRENCY = 15;
  const REST_MS = 25;
  let sentCount = 0;
  let failCount = 0;
  const newlySentIds = [];

  for (let i = 0; i < eligible.length; i += CONCURRENCY) {
    const chunk = eligible.slice(i, i + CONCURRENCY);

    await Promise.all(chunk.map(async (courier) => {
      const uid = String(courier.user_id || '').trim();
      const rawName = String(courier.delivery_name || courier.user?.name || '').trim();
      const cleanedName = (rawName && rawName.toLowerCase() !== 'guest user' && rawName !== '—') ? rawName : '';

      const title = cleanedName
        ? `صباح الخير ${cleanedName} بداية نهار موفقة`
        : 'صباح الخير بداية نهار موفقة';
      const body = 'اللهم ارزقنا رزقاً واسعاً حلالاً طيباً';

      try {
        const invokeRes = await supabaseAdmin.functions.invoke('send-push-notification', {
          body: {
            user_id: uid,
            title,
            body,
            persist_notification: false, // ZERO DB INSERTS: bypasses notifications table to eliminate DB pressure
            force_activate_inactive_tokens: true,
            data: {
              type: 'delivery_morning_greeting',
              sound: 'default',
              source: 'working_hours_shift_start',
              sent_at: new Date().toISOString(),
            },
          },
        });

        if (invokeRes.error) {
          logger.warn?.(`[MorningGreeting] Push error for user ${uid}:`, invokeRes.error.message);
          failCount++;
        } else {
          sentCount++;
          newlySentIds.push(uid);
          sentUserIds.add(uid);
        }
      } catch (pushErr) {
        logger.warn?.(`[MorningGreeting] Push failed for user ${uid}:`, pushErr.message);
        failCount++;
      }
    }));

    if (i + CONCURRENCY < eligible.length && REST_MS > 0) {
      await new Promise((r) => setTimeout(r, REST_MS));
    }
  }

  if (newlySentIds.length > 0) {
    await saveMorningGreetingState(today, sentUserIds);
  }

  logger.log?.(`[MorningGreeting] Finished: sent=${sentCount}, failed=${failCount}, total_sent_today=${sentUserIds.size}`);

  return {
    success: true,
    sent_count: sentCount,
    failed_count: failCount,
    eligible_count: eligible.length,
    already_sent_today: sentUserIds.size,
    date: today,
  };
}

/**
 * Synchronize delivery personnel availability against working hours.
 *
 * Key business rules:
 * 1. Outside working hours:
 *    - If courier is is_available === true:
 *        set is_available = false
 *        track courier ID in auto_closed_ids
 * 2. Inside working hours:
 *    - If courier ID is in auto_closed_ids:
 *        set is_available = true
 *        remove courier ID from auto_closed_ids
 *    - If courier was NOT auto-closed:
 *        DO NOT touch is_available (preserves manual off-duty, break, or sick leave).
 * 3. Never set blocked couriers (role !== 'delivery_man') to is_available = true.
 *
 * @param {object} [options]
 * @param {boolean} [options.force=false]
 * @param {object} [options.logger=console]
 */
export async function syncWorkingHours({ force = false, logger = console } = {}) {
  const startedAt = Date.now();
  const now = new Date();
  const algiersTime = getAlgiersTime(now);

  const config = await getWorkingHoursConfig();

  if (!config.enabled && !force) {
    logger.log?.('Delivery working hours sync skipped: system is disabled');
    return {
      success: true,
      skipped: true,
      reason: 'disabled',
      algiers_time: algiersTime.fullTimeString,
      timezone: config.timezone,
    };
  }

  // Load existing auto-closed courier IDs
  const autoClosedSet = new Set(await getAutoClosedCourierIds());

  // Fetch all delivery personnel with user details
  const { data: couriers, error: fetchErr } = await supabaseAdmin
    .from('delivery_personnel')
    .select(`
      id,
      user_id,
      delivery_name,
      work_phone,
      is_available,
      is_online,
      user:user_id (
        id,
        role
      )
    `);

  if (fetchErr) {
    throw new Error(`Failed to fetch delivery personnel: ${fetchErr.message}`);
  }

  const list = couriers || [];

  const defaultStartMin = parseTimeToMinutes(config.default_start, 660); // 11:00
  const defaultEndMin = parseTimeToMinutes(config.default_end, 1320); // 22:00
  const isDefaultOpen = isTimeInInterval(algiersTime.totalMinutes, defaultStartMin, defaultEndMin);

  const toCloseIds = [];
  const toOpenIds = [];
  const details = [];

  for (const courier of list) {
    const courierId = courier.id;
    const userId = courier.user_id;

    // Check if user is blocked (role !== 'delivery_man')
    const userRole = courier.user?.role;
    const isBlocked = userRole && userRole !== 'delivery_man';

    // Determine custom schedule if configured by courier id or user id
    const customSchedule =
      (courierId && config.courier_schedules?.[courierId]) ||
      (userId && config.courier_schedules?.[userId]) ||
      null;

    let courierStartMin = defaultStartMin;
    let courierEndMin = defaultEndMin;
    let scheduleSource = 'default';

    if (customSchedule && customSchedule.enabled !== false) {
      courierStartMin = parseTimeToMinutes(customSchedule.start, defaultStartMin);
      courierEndMin = parseTimeToMinutes(customSchedule.end, defaultEndMin);
      scheduleSource = 'custom';
    }

    const isShiftOpen = isTimeInInterval(
      algiersTime.totalMinutes,
      courierStartMin,
      courierEndMin,
    );

    const isCurrentlyAvailable = courier.is_available === true;
    const wasAutoClosed = autoClosedSet.has(courierId) || (userId && autoClosedSet.has(userId));

    if (!isShiftOpen) {
      // Outside working hours
      if (isCurrentlyAvailable) {
        toCloseIds.push(courierId);
        autoClosedSet.add(courierId);
        details.push({
          courier_id: courierId,
          name: courier.delivery_name,
          action: 'auto_closed',
          reason: 'outside_working_hours',
          schedule_source: scheduleSource,
        });
      }
    } else {
      // Inside working hours:
      // ONLY re-open couriers who were auto-closed by the working hours schedule.
      // Do NOT touch couriers who were already manually unavailable/off-duty.
      if (wasAutoClosed) {
        if (!isBlocked) {
          toOpenIds.push(courierId);
          details.push({
            courier_id: courierId,
            name: courier.delivery_name,
            action: 'auto_opened',
            reason: 'restored_on_shift_start',
            schedule_source: scheduleSource,
          });
        }
        autoClosedSet.delete(courierId);
        if (userId) autoClosedSet.delete(userId);
      }
    }
  }

  const nowIso = new Date().toISOString();

  // Perform bulk updates in chunks if needed
  if (toCloseIds.length > 0) {
    const chunkSize = 100;
    for (let i = 0; i < toCloseIds.length; i += chunkSize) {
      const chunk = toCloseIds.slice(i, i + chunkSize);
      const { error: closeErr } = await supabaseAdmin
        .from('delivery_personnel')
        .update({
          is_available: false,
          updated_at: nowIso,
        })
        .in('id', chunk);

      if (closeErr) {
        logger.error?.('Failed to bulk close couriers:', closeErr);
        throw closeErr;
      }
    }
  }

  if (toOpenIds.length > 0) {
    const chunkSize = 100;
    for (let i = 0; i < toOpenIds.length; i += chunkSize) {
      const chunk = toOpenIds.slice(i, i + chunkSize);
      const { error: openErr } = await supabaseAdmin
        .from('delivery_personnel')
        .update({
          is_available: true,
          updated_at: nowIso,
        })
        .in('id', chunk);

      if (openErr) {
        logger.error?.('Failed to bulk open couriers:', openErr);
        throw openErr;
      }
    }
  }

  // Persist updated autoClosedSet
  const remainingAutoClosedIds = [...autoClosedSet];
  await saveAutoClosedCourierIds(remainingAutoClosedIds);

  // If shift is open and within morning greeting window (10:00 - 14:00 DZ time) or forced,
  // dispatch personalized morning greeting to eligible available couriers.
  let morningGreeting = null;
  const isMorningWindow = force || (algiersTime.hours >= 10 && algiersTime.hours < 14);
  if (isDefaultOpen && isMorningWindow) {
    try {
      if (toOpenIds.length > 0) {
        const openedSet = new Set(toOpenIds);
        for (const c of list) {
          if (openedSet.has(c.id)) {
            c.is_available = true;
          }
        }
      }
      // Awaited to prevent Serverless Lambda container freeze from killing push dispatch
      morningGreeting = await sendMorningGreetingToAvailableCouriers({
        couriers: list,
        force,
        logger,
      });
    } catch (gErr) {
      logger.error?.('[WorkingHoursSync] Morning greeting dispatch failed:', gErr);
      morningGreeting = { error: gErr?.message || String(gErr) };
    }
  }

  const elapsedMs = Date.now() - startedAt;

  logger.log?.(
    `[WorkingHoursSync] Algiers time: ${algiersTime.timeString} | Shift: ${isDefaultOpen ? 'OPEN' : 'CLOSED'} | Closed: ${toCloseIds.length} | Opened: ${toOpenIds.length} | In auto-close pool: ${remainingAutoClosedIds.length} (${elapsedMs}ms)`
  );

  return {
    success: true,
    algiers_time: algiersTime.fullTimeString,
    algiers_date: algiersTime.dateString,
    is_default_shift_open: isDefaultOpen,
    total_couriers: list.length,
    closed_count: toCloseIds.length,
    opened_count: toOpenIds.length,
    auto_closed_pool_count: remainingAutoClosedIds.length,
    morning_greeting: morningGreeting,
    details,
    elapsed_ms: elapsedMs,
  };
}
