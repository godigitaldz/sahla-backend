import { Router } from 'express';
import { supabaseAdmin } from '../config/supabase.js';

const router = Router();

let _cachedMarketTabEnabled = null;
let _cachedMarketTabTimestamp = 0;
const MARKET_TAB_TTL_MS = 60_000;

let _cachedVersionPolicy = new Map();
const VERSION_POLICY_TTL_MS = 60_000;

/**
 * GET /api/public/market-tab-enabled
 * Used by the Flutter app when PostgREST RLS returns no rows for `market_tab_enabled`.
 * Requires SUPABASE_SERVICE_ROLE_KEY on the server (service role bypasses RLS).
 */
router.get('/market-tab-enabled', async (req, res) => {
  try {
    const now = Date.now();
    if (_cachedMarketTabEnabled !== null && (now - _cachedMarketTabTimestamp) < MARKET_TAB_TTL_MS) {
      res.set('Cache-Control', 'public, max-age=60');
      return res.json({ marketTabEnabled: _cachedMarketTabEnabled, _cached: true });
    }

    const { data, error } = await supabaseAdmin
      .from('system_config')
      .select('config_value, config_type')
      .eq('config_key', 'market_tab_enabled')
      .maybeSingle();

    if (error) {
      console.error('[publicConfig] market_tab_enabled:', error.message);
      res.set('Cache-Control', 'public, max-age=30');
      return res.json({ marketTabEnabled: _cachedMarketTabEnabled ?? true });
    }

    if (!data) {
      _cachedMarketTabEnabled = true;
      _cachedMarketTabTimestamp = now;
      res.set('Cache-Control', 'public, max-age=60');
      return res.json({ marketTabEnabled: true });
    }

    const enabled = parseMarketTabEnabledValue(data.config_value, data.config_type);
    _cachedMarketTabEnabled = enabled;
    _cachedMarketTabTimestamp = now;
    res.set('Cache-Control', 'public, max-age=60');
    return res.json({ marketTabEnabled: enabled });
  } catch (e) {
    console.error('[publicConfig] market-tab-enabled', e);
    return res.json({ marketTabEnabled: _cachedMarketTabEnabled ?? true });
  }
});

/**
 * GET /api/public/app-version-policy?platform=android|ios
 * Returns minimum required app version and force-update policy for splash gate.
 *
 * system_config keys:
 * - app_min_version_android (string)
 * - app_min_version_ios (string)
 * - app_force_update_android (boolean)
 * - app_force_update_ios (boolean)
 * - app_update_url_android (string)
 * - app_update_url_ios (string)
 * - app_update_message (string)
 */
router.get('/app-version-policy', async (req, res) => {
  try {
    const requestedPlatform = String(req.query.platform || 'android')
      .toLowerCase()
      .trim();
    const platform = requestedPlatform === 'ios' ? 'ios' : 'android';

    const now = Date.now();
    const cached = _cachedVersionPolicy.get(platform);
    if (cached && (now - cached.timestamp) < VERSION_POLICY_TTL_MS) {
      res.set('Cache-Control', 'public, max-age=60');
      return res.json({ ...cached.data, _cached: true });
    }

    const keys = [
      'app_min_version_android',
      'app_min_version_ios',
      'app_force_update_android',
      'app_force_update_ios',
      'app_update_url_android',
      'app_update_url_ios',
      'app_update_message',
    ];

    const { data, error } = await supabaseAdmin
      .from('system_config')
      .select('config_key, config_value, config_type')
      .in('config_key', keys);

    if (error) {
      console.error('[publicConfig] app-version-policy:', error.message);
      if (cached) {
        res.set('Cache-Control', 'public, max-age=30');
        return res.json({ ...cached.data, _cached: true });
      }
      res.set('Cache-Control', 'public, max-age=30');
      return res.json({
        platform,
        forceUpdate: false,
        minimumVersion: null,
        updateUrl: null,
        message: null,
      });
    }

    const values = new Map(
      (data || []).map((row) => [
        row.config_key,
        parseConfigValue(row.config_value, row.config_type),
      ]),
    );

    const minimumVersion = values.get(
      platform === 'ios' ? 'app_min_version_ios' : 'app_min_version_android',
    );
    const forceUpdate = toBoolean(
      values.get(
        platform === 'ios'
          ? 'app_force_update_ios'
          : 'app_force_update_android',
      ),
      false,
    );
    const updateUrl = values.get(
      platform === 'ios' ? 'app_update_url_ios' : 'app_update_url_android',
    );
    const message = values.get('app_update_message');

    const normalizedUpdateUrl =
      typeof updateUrl === 'string' && updateUrl.trim() ? updateUrl.trim() : null;

    const payload = {
      platform,
      forceUpdate,
      minimumVersion:
        typeof minimumVersion === 'string' && minimumVersion.trim()
          ? minimumVersion.trim()
          : null,
      updateUrl:
        platform === 'ios'
          ? sanitizeIosAppStoreUrl(normalizedUpdateUrl, null)
          : normalizedUpdateUrl,
      message:
        typeof message === 'string' && message.trim() ? message.trim() : null,
    };

    _cachedVersionPolicy.set(platform, { data: payload, timestamp: now });

    res.set('Cache-Control', 'public, max-age=60');
    return res.json(payload);
  } catch (e) {
    console.error('[publicConfig] app-version-policy', e);
    return res.status(500).json({
      platform: 'android',
      forceUpdate: false,
      minimumVersion: null,
      updateUrl: null,
      message: null,
    });
  }
});

/**
 * GET /api/public/free-delivery-zone/check?lat=&lng=
 * Geofence check for monitoring / optional precheck. DB trigger on `orders` remains source of truth.
 */
router.get('/free-delivery-zone/check', async (req, res) => {
  try {
    const lat = Number(req.query.lat);
    const lng = Number(req.query.lng);
    if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
      return res.status(400).json({
        success: false,
        error: 'lat_lng_required',
        message: 'Valid lat and lng query params are required.',
      });
    }

    const { data: zoneRows, error: zoneError } = await supabaseAdmin.rpc(
      'is_point_in_free_delivery_zone',
      { p_lat: lat, p_lng: lng },
    );

    if (zoneError) {
      console.error('[publicConfig] free-delivery-zone/check:', zoneError.message);
      return res.status(500).json({
        success: false,
        error: 'zone_check_failed',
        message: zoneError.message,
      });
    }

    const zone =
      Array.isArray(zoneRows) && zoneRows.length > 0 ? zoneRows[0] : null;
    const inZone = !!zone?.in_zone;

    const { data: configRows, error: configError } = await supabaseAdmin
      .from('system_config')
      .select('config_key, config_value, config_type')
      .in('config_key', [
        'free_delivery_zone_enabled',
        'free_delivery_zone_shadow_mode',
      ]);

    if (configError) {
      console.error(
        '[publicConfig] free-delivery-zone/check config:',
        configError.message,
      );
    }

    const configMap = new Map(
      (configRows || []).map((row) => [
        row.config_key,
        parseConfigValue(row.config_value, row.config_type),
      ]),
    );

    res.set('Cache-Control', 'public, max-age=15');
    return res.json({
      success: true,
      inZone,
      zone: zone
        ? {
            id: zone.zone_id,
            name: zone.zone_name,
          }
        : null,
      flags: {
        enabled: toBoolean(configMap.get('free_delivery_zone_enabled'), false),
        shadowMode: toBoolean(
          configMap.get('free_delivery_zone_shadow_mode'),
          true,
        ),
      },
    });
  } catch (e) {
    console.error('[publicConfig] free-delivery-zone/check', e);
    return res.status(500).json({
      success: false,
      error: 'unexpected_error',
      message: e?.message || 'Unexpected error',
    });
  }
});

/**
 * GET /api/public/system-urls
 * Returns official production URLs for legal policies, dashboards, and redirects.
 */
/**
 * Restricts iOS App Store / update redirects to official Apple App Store HTTPS URLs.
 * Prevents remote config from pointing iOS builds to external/enterprise IPA hosts.
 */
export function sanitizeIosAppStoreUrl(rawUrl, fallback = null) {
  if (typeof rawUrl !== 'string') return fallback;
  const trimmed = rawUrl.trim();
  if (!trimmed) return fallback;
  try {
    const parsed = new URL(trimmed);
    if (
      parsed.protocol === 'https:' &&
      (parsed.hostname === 'apps.apple.com' || parsed.hostname === 'itunes.apple.com')
    ) {
      return parsed.toString();
    }
  } catch (_) {
    // Ignore malformed URLs and return safe fallback.
  }
  return fallback;
}

router.get('/system-urls', async (req, res) => {
  try {
    const keys = [
      'privacy_policy_url',
      'terms_of_service_url',
      'user_agreement_url',
      'delete_account_url',
      'dashboard_url',
      'admin_dashboard_url',
      'web_base_url',
      'app_store_url_ios',
      'app_update_url_ios',
      'app_store_url_android',
    ];
    const { data, error } = await supabaseAdmin
      .from('system_config')
      .select('config_key, config_value')
      .in('config_key', keys);

    if (error) {
      console.error('[publicConfig] system-urls:', error.message);
    }

    const map = new Map((data || []).map((r) => [r.config_key, r.config_value]));
    const defaultBase = 'https://sahla-backend.vercel.app';
    const baseUrl = (map.get('web_base_url') || defaultBase).replace(/\/+$/, '');

    const payload = {
      success: true,
      baseUrl,
      privacyPolicyUrl: map.get('privacy_policy_url') || `${baseUrl}/privacy-policy`,
      termsOfServiceUrl: map.get('terms_of_service_url') || `${baseUrl}/terms-of-service`,
      userAgreementUrl: map.get('user_agreement_url') || `${baseUrl}/user-agreement`,
      deleteAccountUrl: map.get('delete_account_url') || `${baseUrl}/delete-account`,
      dashboardUrl: map.get('dashboard_url') || `${baseUrl}/performance`,
      adminDashboardUrl: map.get('admin_dashboard_url') || `${baseUrl}/performance`,
      appStoreUrlIos: sanitizeIosAppStoreUrl(
        map.get('app_store_url_ios') || map.get('app_update_url_ios'),
        'https://apps.apple.com/dz/app/sahla-algerie/id6834895657',
      ),
      appStoreUrlAndroid:
        map.get('app_store_url_android') ||
        'https://play.google.com/store/apps/details?id=com.godigital.sahla',
    };

    res.set('Cache-Control', 'public, max-age=120');
    return res.json(payload);
  } catch (err) {
    console.error('[publicConfig] system-urls error:', err);
    return res.status(500).json({ success: false, error: err.message });
  }
});

function parseMarketTabEnabledValue(value, type) {
  const t = String(type || 'boolean').toLowerCase().trim();
  if (t === 'boolean') {
    if (typeof value === 'boolean') return value;
    if (typeof value === 'string') {
      const s = value.trim().toLowerCase();
      if (s === 'false' || s === '0') return false;
      if (s === 'true' || s === '1') return true;
    }
    return true;
  }
  if (typeof value === 'boolean') return value;
  if (typeof value === 'string') {
    const s = value.trim().toLowerCase();
    if (s === 'false' || s === '0') return false;
    if (s === 'true' || s === '1') return true;
  }
  return true;
}

function parseConfigValue(value, type) {
  const t = String(type || '').toLowerCase().trim();
  if (t === 'boolean') return toBoolean(value, false);
  if (t === 'number' || t === 'int' || t === 'integer' || t === 'float') {
    if (typeof value === 'number') return value;
    if (typeof value === 'string') {
      const parsed = Number(value.trim());
      return Number.isFinite(parsed) ? parsed : null;
    }
    return null;
  }
  return value;
}

function toBoolean(value, fallback) {
  if (typeof value === 'boolean') return value;
  if (typeof value === 'number') return value !== 0;
  if (typeof value === 'string') {
    const s = value.trim().toLowerCase();
    if (s === 'true' || s === '1' || s === 'yes' || s === 'on') return true;
    if (s === 'false' || s === '0' || s === 'no' || s === 'off') return false;
  }
  return fallback;
}

export default router;
