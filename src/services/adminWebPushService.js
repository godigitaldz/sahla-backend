import * as webpush from 'web-push';
import { supabaseAdmin } from '../config/supabase.js';
import { getActiveAdminUserIds } from './adminRecipients.js';

const DEFAULT_VAPID_PUBLIC_KEY =
  'BH8-UB75DtVmMapkbdTsnG36JiUH67mvcebkl7a0Lu0z4YAkTfDTkQA7ftd_aiXSwBB5tQGUxyYuM8Hgr85XD3g';
const DEFAULT_VAPID_PRIVATE_KEY =
  'RQbJmzZWD2OVL-YY0HLYDDhWnTwuG16rVjT1iraYKQw';
const DEFAULT_VAPID_SUBJECT = 'mailto:admin@sahla-delivery.com';

const VAPID_PUBLIC_KEY = process.env.ADMIN_VAPID_PUBLIC_KEY?.trim() || DEFAULT_VAPID_PUBLIC_KEY;
const VAPID_PRIVATE_KEY = process.env.ADMIN_VAPID_PRIVATE_KEY?.trim() || DEFAULT_VAPID_PRIVATE_KEY;
const VAPID_SUBJECT = process.env.ADMIN_VAPID_SUBJECT?.trim() || DEFAULT_VAPID_SUBJECT;

try {
  webpush.setVapidDetails(VAPID_SUBJECT, VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY);
} catch (e) {
  console.error('[adminWebPushService] Failed to set VAPID details:', e?.message || e);
}

export class AdminWebPushService {
  constructor(logger = console) {
    this.logger = logger;
  }

  getVapidPublicKey() {
    return VAPID_PUBLIC_KEY;
  }

  /**
   * Register or update a Web Push subscription in user_device_tokens.
   */
  async registerSubscription({ userId, deviceId, token, subscription, platform, userAgent }) {
    if (!deviceId) {
      return { success: false, error: 'device_id_required' };
    }

    let subJson = null;
    let finalPlatform = platform || 'web';

    if (subscription && typeof subscription === 'object' && subscription.endpoint) {
      subJson = JSON.stringify(subscription);
      finalPlatform = 'web_push';
    } else if (typeof token === 'string' && token.startsWith('{') && token.includes('"endpoint"')) {
      subJson = token;
      finalPlatform = 'web_push';
    }

    const finalToken = subJson || token || `sw-active-${deviceId}`;
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
        .select('id')
        .eq('device_id', deviceId)
        .maybeSingle();

      if (existing?.id) {
        const { error: updateErr } = await supabaseAdmin
          .from('user_device_tokens')
          .update({
            user_id: effectiveUserId,
            token: finalToken,
            platform: finalPlatform,
            is_active: true,
            last_seen_at: now,
            updated_at: now,
            push_paused: false,
          })
          .eq('id', existing.id);

        if (updateErr) throw updateErr;
        return { success: true, updated: true, is_web_push: finalPlatform === 'web_push' };
      }

      const { error: insertErr } = await supabaseAdmin
        .from('user_device_tokens')
        .insert({
          user_id: effectiveUserId,
          token: finalToken,
          platform: finalPlatform,
          device_id: deviceId,
          is_active: true,
          last_seen_at: now,
          created_at: now,
          updated_at: now,
          push_paused: false,
        });

      if (insertErr) throw insertErr;
      return { success: true, inserted: true, is_web_push: finalPlatform === 'web_push' };
    } catch (err) {
      this.logger.error?.('[adminWebPushService] registerSubscription error:', err.message);
      return { success: false, error: err.message };
    }
  }

  /**
   * Dispatch native Web Push to all active admin devices (iPhone PWA lock screen, desktop, Android Web).
   */
  async sendWebPushToAllAdmins({ title, body, data = {}, severity = 'critical' }) {
    try {
      // Find all active web push device tokens
      const { data: devices, error } = await supabaseAdmin
        .from('user_device_tokens')
        .select('id, device_id, token, platform')
        .eq('is_active', true)
        .or('platform.eq.web_push,token.ilike.%endpoint%');

      if (error) {
        this.logger.error?.('[adminWebPushService] fetch devices error:', error.message);
        return { success: false, error: error.message };
      }

      if (!devices || devices.length === 0) {
        return { success: true, delivered: 0, reason: 'no_web_push_devices' };
      }

      const payload = JSON.stringify({
        notification: {
          title: title || '🚨 Sahla Admin Alert',
          body: body || 'Emergency operational alert requires immediate attention',
          icon: '/sahla-logo-circle.png',
          badge: '/sahla-logo-circle.png',
        },
        data: {
          ...data,
          title: title || '🚨 Sahla Admin Alert',
          body: body || 'Emergency operational alert requires immediate attention',
          severity: severity || 'critical',
          click_url: data?.click_url || '/performance?view=alerts',
          tag: data?.tag || `admin-alert-${Date.now()}`,
        },
      });

      let delivered = 0;
      let failed = 0;

      await Promise.all(
        devices.map(async (dev) => {
          try {
            let sub = null;
            if (typeof dev.token === 'string' && dev.token.startsWith('{')) {
              sub = JSON.parse(dev.token);
            }
            if (!sub || !sub.endpoint) return;

            await webpush.sendNotification(sub, payload, {
              urgency: 'high',
              TTL: 3600,
            });
            delivered++;
          } catch (sendErr) {
            failed++;
            if (sendErr?.statusCode === 410 || sendErr?.statusCode === 404) {
              // Deactivate expired or unsubscribed token
              await supabaseAdmin
                .from('user_device_tokens')
                .update({ is_active: false, updated_at: new Date().toISOString() })
                .eq('id', dev.id)
                .catch(() => {});
            } else {
              this.logger.warn?.(`[adminWebPushService] Failed to send to dev ${dev.device_id}:`, sendErr.message);
            }
          }
        })
      );

      return { success: true, delivered, failed };
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
      if (typeof dev.token === 'string' && dev.token.startsWith('{')) {
        sub = JSON.parse(dev.token);
      }

      if (!sub || !sub.endpoint) {
        return {
          success: false,
          error: 'device_not_web_push_enabled',
          hint: 'Device has not subscribed to native Web Push with VAPID key yet',
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

      return { success: true, message: 'Test push delivered to device' };
    } catch (err) {
      this.logger.error?.('[adminWebPushService] sendTestPushToDevice error:', err.message);
      return { success: false, error: err.message };
    }
  }
}

export const adminWebPushService = new AdminWebPushService();
