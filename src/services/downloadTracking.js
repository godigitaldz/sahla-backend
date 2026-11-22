import { supabaseAdmin } from '../config/supabase.js';

export const DOWNLOAD_EVENTS = new Set([
  'page_view', 'platform_detected', 'inapp_detected', 'app_open_attempt',
  'app_opened_likely', 'store_redirect', 'store_tap', 'escape_tap',
  'copy_link', 'retry_tap',
]);
export const PLATFORMS = new Set(['ios', 'android', 'desktop', 'unknown']);
export const IN_APP_BROWSERS = new Set(['Instagram', 'Snapchat', 'TikTok', 'Facebook', 'Messenger', 'Other', 'none']);

const RATE_LIMIT = 120;
const RATE_WINDOW_MS = 60_000;
const requestsByIp = new Map();
const BOT_UA = /bot|crawler|spider|slurp|preview|headless|phantom|lighthouse|pagespeed|prerender|facebookexternalhit|twitterbot|slackbot|whatsapp/i;

const clean = (value, max = 160) => typeof value === 'string' ? value.trim().slice(0, max) : '';

export function isBotUserAgent(userAgent) {
  return !clean(userAgent, 1000) || BOT_UA.test(userAgent);
}

export function isRateLimited(ip, now = Date.now()) {
  const key = clean(ip, 80) || 'unknown';
  const active = (requestsByIp.get(key) || []).filter((time) => now - time < RATE_WINDOW_MS);
  if (active.length >= RATE_LIMIT) {
    requestsByIp.set(key, active);
    return true;
  }
  active.push(now);
  requestsByIp.set(key, active);
  if (requestsByIp.size > 5000) {
    for (const [candidate, times] of requestsByIp) {
      if (!times.length || now - times[times.length - 1] >= RATE_WINDOW_MS) requestsByIp.delete(candidate);
    }
  }
  return false;
}

export function normalizeDownloadEvent(input, userAgent = '') {
  if (!input || typeof input !== 'object' || Array.isArray(input)) return null;
  const event = clean(input.event, 40);
  const sessionId = clean(input.sessionId, 80);
  const platform = clean(input.platform, 20);
  const inApp = clean(input.inApp, 24);
  if (!DOWNLOAD_EVENTS.has(event) || !/^[a-zA-Z0-9_-]{8,80}$/.test(sessionId)) return null;
  if (!PLATFORMS.has(platform) || !IN_APP_BROWSERS.has(inApp)) return null;

  const source = input.source && typeof input.source === 'object' && !Array.isArray(input.source)
    ? input.source : {};
  const rawProps = input.props && typeof input.props === 'object' && !Array.isArray(input.props)
    ? input.props : {};
  const props = {};
  for (const key of ['trigger', 'store', 'target']) {
    const value = clean(rawProps[key], 40);
    if (!value) continue;
    if (key === 'trigger' && ['auto', 'tap'].includes(value)) props[key] = value;
    if (key === 'store' && ['appstore', 'playstore'].includes(value)) props[key] = value;
    if (key === 'target' && ['Safari', 'Chrome'].includes(value)) props[key] = value;
  }

  return {
    event,
    session_id: sessionId,
    platform,
    in_app: inApp,
    route: clean(input.route, 160) || '/',
    utm_source: clean(source.utm_source, 120) || null,
    utm_medium: clean(source.utm_medium, 120) || null,
    utm_campaign: clean(source.utm_campaign, 120) || clean(source.campaign, 120) || null,
    ref: clean(source.ref, 120) || null,
    props,
    build: clean(input.buildVersion, 40) || null,
    lang: clean(input.lang, 12) || null,
    is_bot: isBotUserAgent(userAgent),
    country: null,
    ua_hash: null,
  };
}

export async function storeDownloadEvent(row) {
  const { error } = await supabaseAdmin.from('download_events').insert(row);
  // The partial unique index intentionally makes page_view once per session.
  if (error?.code === '23505' && row.event === 'page_view') return { duplicate: true };
  if (error) throw error;
  return { duplicate: false };
}

export function resetDownloadRateLimitForTests() {
  requestsByIp.clear();
}

export function parseDownloadBody(body) {
  if (Buffer.isBuffer(body)) {
    try { return JSON.parse(body.toString('utf8')); } catch { return null; }
  }
  if (typeof body === 'string') {
    try { return JSON.parse(body); } catch { return null; }
  }
  return body && typeof body === 'object' ? body : null;
}
