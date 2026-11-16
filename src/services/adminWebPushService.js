import * as webpush from 'web-push';
import { supabaseAdmin } from '../config/supabase.js';
import { getActiveAdminUserIds } from './adminRecipients.js';

function getVapidConfig() {
  const publicKey = process.env.ADMIN_VAPID_PUBLIC_KEY?.trim() || null;
  const privateKey = process.env.ADMIN_VAPID_PRIVATE_KEY?.trim() || null;
  const subject = process.env.ADMIN_VAPID_SUBJECT?.trim() || 'mailto:admin@sahla-delivery.com';

  const isConfigured = Boolean(
    publicKey &&
    privateKey &&
    publicKey.length > 20 &&
    privateKey.length > 10
  );

  return { publicKey, privateKey, subject, isConfigured };
}

let _vapidInitialized = false;

function ensureVapidConfigured(logger = console) {
  if (_vapidInitialized) return true;
  const cfg = getVapidConfig();
  if (!cfg.isConfigured) {
    return false;
  }
  try {
    webpush.setVapidDetails(cfg.subject, cfg.publicKey, cfg.privateKey);
    _vapidInitialized = true;
    return true;
  } catch (err) {
    logger.error?.('[adminWebPushService] Failed to set VAPID details:', err?.message);
    return false;
  }
}

/**
 * Validate that an object is a well-formed W3C PushSubscription.
 */
export function isValidPushSubscription(sub) {
  if (!sub || typeof sub !== 'object') return false;
  if (typeof sub.endpoint !== 'string' || !sub.endpoint.startsWith('https://')) return false;
  if (!sub.keys || typeof sub.keys !== 'object') return false;
  if (typeof sub.keys.p256dh !== 'string' || sub.keys.p256dh.length < 10) return false;
  if (typeof sub.keys.auth !== 'string' || sub.keys.auth.length < 5) return false;
  return true;
}

export class AdminWebPushService {
  constructor(logger = console) {
    this.logger = logger;
  }

  isConfigured() {
    return ensureVapidConfigured(this.logger);
  }

  getVapidPublicKey() {
    const cfg = getVapidConfig();
    return cfg.isConfigured ? cfg.publicKey : null;
  }

  /**
   * Register or update a verified Web Push subscription for an administrator device.
   * Rejects dummy/placeholder tokens from being saved as native push subscriptions.
   */
  async registerSubscription({ userId, deviceId, token, subscription, platform, userAgent }) {
    if (!deviceId || typeof deviceId !== 'string' || !deviceId.trim()) {
      return { success: false, error: 'device_id_required' };
    }

    const cleanDeviceId = deviceId.trim();
    let parsedSub = null;

    if (subscription && typeof subscription === 'object') {
      parsedSub = subscription;
    } else if (typeof token === 'string' && token.trim().startsWith('{')) {
      try {
        parsedSub = JSON.parse(token);
      } catch (_) {
        parsedSub = null;
      }
    }

    const hasValidPushSub = isValidPushSubscription(parsedSub);
    const finalPlatform = hasValidPushSub ? 'web_push' : (platform === 'web_push' ? 'web' : (platform || 'web'));

    if (platform === 'web_push' && !hasValidPushSub) {
      return {
        success: false,
        error: 'invalid_push_subscription',
        hint: 'A valid PushSubscription with endpoint and cryptographic keys (p256dh, auth) is required for web_push platform',
      };
    }

    const serializedToken = hasValidPushSub ? JSON.stringify(parsedSub) : (typeof token === 'string' ? token.trim() : null);

    if (!serializedToken) {
      return { success: false, error: 'token_or_subscription_required' };
    }

    const now = new Date().toISOString();

    try {
      let effectiveUserId = userId;
      if (!effectiveUserId) {
        const admins = await getActiveAdminUserIds(this.logger);
        effectiveUserId = admins[0] || null;
      }

      if (!effectiveUserId) {
        return { success: false, error: 'no_admin_user_profile_found' };
      }

      const { data: existing } = await supabaseAdmin
        .from('user_device_tokens')
        .select('id, user_id, platform')
        .eq('device_id', cleanDeviceId)
        .maybeSingle();

      if (existing?.id) {
        const { error: updateErr } = await supabaseAdmin
          .from('user_device_tokens')
          .update({
            user_id: effectiveUserId,
            token: serializedToken,
            platform: finalPlatform,
            is_active: true,
            last_seen_at: now,
            updated_at: now,
            push_paused: false,
          })
          .eq('id', existing.id);

        if (updateErr) throw updateErr;
        return {
          success: true,
          updated: true,
          platform: finalPlatform,
          is_web_push: finalPlatform === 'web_push',
        };
      }

      const { error: insertErr } = await supabaseAdmin
        .from('user_device_tokens')
        .insert({
          user_id: effectiveUserId,
          token: serializedToken,
          platform: finalPlatform,
          device_id: cleanDeviceId,
          is_active: true,
          last_seen_at: now,
          created_at: now,
          updated_at: now,
          push_paused: false,
        });

      if (insertErr) throw insertErr;
      return {
        success: true,
        inserted: true,
        platform: finalPlatform,
        is_web_push: finalPlatform === 'web_push',
      };
    } catch (err) {
      this.logger.error?.('[adminWebPushService] registerSubscription error:', err.message);
      return { success: false, error: err.message };
    }
  }

  /**
   * Dispatch native Web Push to all active admin devices (iPhone PWA lock screen, desktop, Android Web).
   */
  async sendWebPushToAllAdmins({ title, body, data = {}, severity = 'critical' }) {
    if (!this.isConfigured()) {
      this.logger.warn?.('[adminWebPushService] sendWebPushToAllAdmins: VAPID is not configured in environment');
      return {
        success: false,
        delivered: 0,
        failed: 0,
        reason: 'vapid_not_configured',
      };
    }

    try {
      const { data: devices, error } = await supabaseAdmin
        .from('user_device_tokens')
        .select('id, device_id, token, platform')
        .eq('is_active', true)
        .eq('platform', 'web_push');

      if (error) {
        this.logger.error?.('[adminWebPushService] fetch devices error:', error.message);
        return { success: false, error: error.message };
      }

      if (!devices || devices.length === 0) {
        return { success: true, delivered: 0, failed: 0, reason: 'no_web_push_devices' };
      }

      const payload = JSON.stringify({
        notification: {
          title: title || '⚠️ Sahla Admin Alert',
          body: body || 'Emergency operational alert requires immediate attention',
          icon: '/sahla-logo-circle.png',
          badge: '/sahla-logo-circle.png',
        },
        data: {
          ...data,
          title: title || '⚠️ Sahla Admin Alert',
          body: body || 'Emergency operational alert requires immediate attention',
          severity: severity || 'critical',
          click_url: data?.click_url || '/performance?view=alerts',
          tag: data?.tag || `admin-alert-${data?.incident_key || Date.now()}`,
        },
      });

      let delivered = 0;
      let failed = 0;
      const results = [];

      for (const dev of devices) {
        let sub = null;
        try {
          if (typeof dev.token === 'string') {
            sub = JSON.parse(dev.token);
          }
        } catch (_) {
          sub = null;
        }

        if (!isValidPushSubscription(sub)) {
          failed++;
          results.push({ deviceId: dev.device_id, status: 'invalid_token' });
          continue;
        }

        try {
          await webpush.sendNotification(sub, payload, {
            urgency: 'high',
            TTL: 3600,
          });
          delivered++;
          results.push({ deviceId: dev.device_id, status: 'provider_accepted' });
        } catch (sendErr) {
          failed++;
          const statusCode = sendErr?.statusCode;
          results.push({
            deviceId: dev.device_id,
            status: 'failed',
            statusCode,
            error: sendErr?.message || 'provider_error',
          });

          if (statusCode === 410 || statusCode === 404) {
            // Subscription has expired or user unsubscribed; deactivate token
            try {
              await supabaseAdmin
                .from('user_device_tokens')
                .update({ is_active: false, updated_at: new Date().toISOString() })
                .eq('id', dev.id);
            } catch (_) {}
          } else {
            this.logger.warn?.(`[adminWebPushService] Push failed for device ${dev.device_id}: status=${statusCode}`);
          }
        }
      }

      return {
        success: delivered > 0 || failed === 0,
        delivered,
        failed,
        results,
      };
    } catch (err) {
      this.logger.error?.('[adminWebPushService] sendWebPushToAllAdmins error:', err.message);
      return { success: false, error: err.message };
    }
  }

  /**
   * Send an immediate test push to a specific device ID (used to test lock screen on mobile).
   */
  async sendTestPushToDevice({ deviceId }) {
    if (!deviceId) return { success: false, error: 'device_id_required' };

    if (!this.isConfigured()) {
      return {
        success: false,
        error: 'vapid_not_configured',
        hint: 'Server VAPID keys (ADMIN_VAPID_PUBLIC_KEY, ADMIN_VAPID_PRIVATE_KEY) must be configured in environment variables.',
      };
    }

    try {
      const { data: dev, error } = await supabaseAdmin
        .from('user_device_tokens')
        .select('id, device_id, token, platform')
        .eq('device_id', deviceId)
        .maybeSingle();

      if (error || !dev) {
        return { success: false, error: 'device_not_found' };
      }

      let sub = null;
      try {
        if (typeof dev.token === 'string') {
          sub = JSON.parse(dev.token);
        }
      } catch (_) {
        sub = null;
      }

      if (!isValidPushSubscription(sub)) {
        return {
          success: false,
          error: 'device_not_web_push_enabled',
          hint: 'Device has not subscribed to native Web Push with VAPID key yet.',
        };
      }

      const payload = JSON.stringify({
        notification: {
          title: '🚨 تنبيه شاشة القفل — Sahla Operations',
          body: 'نجاح الربط! ستصلك تنبيهات الطلبات المعلقة هنا حتى وشاشة الهاتف مقفلة.',
          icon: '/sahla-logo-circle.png',
          badge: '/sahla-logo-circle.png',
        },
        data: {
          title: '🚨 تنبيه شاشة القفل — Sahla Operations',
          body: 'نجاح الربط! ستصلك تنبيهات الطلبات المعلقة هنا حتى وشاشة الهاتف مقفلة.',
          severity: 'critical',
          click_url: '/performance?view=alerts',
          tag: `test-lock-push-${Date.now()}`,
        },
      });

      await webpush.sendNotification(sub, payload, {
        urgency: 'high',
        TTL: 3600,
      });

      return { success: true, message: 'Test push accepted by push provider' };
    } catch (err) {
      this.logger.error?.('[adminWebPushService] sendTestPushToDevice error:', err.message);
      return { success: false, error: err.message };
    }
  }
}

export const adminWebPushService = new AdminWebPushService();
