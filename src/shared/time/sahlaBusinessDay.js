/** Africa/Algiers wall-clock day as UTC instants (Algeria is UTC+1 year-round). */
export const SAHLA_UTC_OFFSET_MS = 60 * 60 * 1000;

export function sahlaBusinessDayUtcIsoRange(now = new Date()) {
  const wall = new Date(now.getTime() + SAHLA_UTC_OFFSET_MS);
  const y = wall.getUTCFullYear();
  const m = wall.getUTCMonth();
  const d = wall.getUTCDate();
  const startMs = Date.UTC(y, m, d) - SAHLA_UTC_OFFSET_MS;
  const endMs = startMs + 24 * 60 * 60 * 1000;
  return { startIso: new Date(startMs).toISOString(), endIso: new Date(endMs).toISOString() };
}

/** Parse YYYY-MM-DD in Algeria wall-clock into UTC ISO range. */
export function sahlaBusinessDayUtcIsoRangeForDate(ymd) {
  const raw = String(ymd || '').trim();
  const match = /^(\d{4})-(\d{2})-(\d{2})$/.exec(raw);
  if (!match) {
    throw new Error('invalid_date_format');
  }
  const y = Number(match[1]);
  const m = Number(match[2]) - 1;
  const d = Number(match[3]);
  const startMs = Date.UTC(y, m, d) - SAHLA_UTC_OFFSET_MS;
  const endMs = startMs + 24 * 60 * 60 * 1000;
  return { startIso: new Date(startMs).toISOString(), endIso: new Date(endMs).toISOString() };
}

export function sahlaTodayYmd(now = new Date()) {
  const wall = new Date(now.getTime() + SAHLA_UTC_OFFSET_MS);
  const y = wall.getUTCFullYear();
  const m = String(wall.getUTCMonth() + 1).padStart(2, '0');
  const day = String(wall.getUTCDate()).padStart(2, '0');
  return `${y}-${m}-${day}`;
}
