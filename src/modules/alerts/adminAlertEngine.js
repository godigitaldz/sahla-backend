import { supabaseAdmin } from '../../config/supabase.js';
import { supabasePushGateway } from '../notifications/supabasePushGateway.js';
import { getActiveAdminUserIds } from '../../services/adminRecipients.js';

/** In-memory fallback cache in case PostgreSQL migration is pending */
const _ephemeralAlerts = new Map();
let _dbTableAvailable = true;

/**
 * Generate a canonical deduplication key for an operational breach.
 * E.g. 'order:1042:stale_pending:2026-11-16T06:00:00.000Z'
 */
export function buildDedupeKey(orderId, alertType, episodeTimestamp) {
  const ts = episodeTimestamp ? new Date(episodeTimestamp).toISOString() : 'current';
  return `order:${String(orderId || 'none')}:${String(alertType)}:${ts}`;
}

export class AdminAlertEngine {
  constructor(logger = console) {
    this.logger = logger;
  }

  /**
   * Raise a canonical operational alert if not already active/acknowledged.
   */
  async raiseAlert({
    orderId = null,
    taskId = null,
    alertType,
    severity = 'critical',
    title,
    message,
    metadata = {},
    episodeTimestamp = null,
  }) {
    if (!alertType || (!orderId && !taskId)) {
      this.logger.warn?.('[admin-alert-engine] Missing required alert fields');
      return null;
    }

    const dedupeKey = buildDedupeKey(orderId, alertType, episodeTimestamp);

    try {
      if (_dbTableAvailable) {
        // 1. Check if active or acknowledged alert already exists with this dedupe_key
        const { data: existing, error: checkError } = await supabaseAdmin
          .from('admin_alerts')
          .select('id, status, severity, created_at')
          .eq('dedupe_key', dedupeKey)
          .maybeSingle();

        if (checkError) {
          if (checkError.code === 'PGRST205' || checkError.message?.includes('admin_alerts')) {
            _dbTableAvailable = false;
            this.logger.warn?.('[admin-alert-engine] admin_alerts table pending deployment. Using fallback mode.');
          } else {
            this.logger.error?.('[admin-alert-engine] Check error:', checkError.message);
          }
        } else if (existing) {
          // Already recorded
          if (existing.status === 'active' || existing.status === 'acknowledged' || existing.status === 'escalated') {
            return { alert: existing, isNew: false };
          }
        }
      }

      // If DB table is active, insert row
      let createdAlert = null;
      if (_dbTableAvailable) {
        const { data: inserted, error: insertError } = await supabaseAdmin
          .from('admin_alerts')
          .insert({
            order_id: orderId,
            task_id: taskId,
            alert_type: alertType,
            severity,
            dedupe_key: dedupeKey,
            title,
            message,
            metadata,
            status: 'active',
            escalation_level: 0,
            created_at: new Date().toISOString(),
            updated_at: new Date().toISOString(),
          })
          .select('*')
          .maybeSingle();

        if (insertError) {
          // On unique constraint collision, treat as already created
          if (insertError.code === '23505') {
            return { alert: null, isNew: false };
          }
          this.logger.error?.('[admin-alert-engine] Insert error:', insertError.message);
        } else {
          createdAlert = inserted;
        }
      }

      // Ephemeral fallback storage
      if (!createdAlert) {
        if (_ephemeralAlerts.has(dedupeKey)) {
          const ex = _ephemeralAlerts.get(dedupeKey);
          if (ex.status === 'active' || ex.status === 'acknowledged') {
            return { alert: ex, isNew: false };
          }
        }
        createdAlert = {
          id: `ephemeral-${Date.now()}-${Math.random().toString(36).slice(2, 7)}`,
          order_id: orderId,
          task_id: taskId,
          alert_type: alertType,
          severity,
          dedupe_key: dedupeKey,
          title,
          message,
          metadata,
          status: 'active',
          escalation_level: 0,
          created_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        };
        _ephemeralAlerts.set(dedupeKey, createdAlert);
      }

      // 2. Dispatch Web Push & Mobile Push Notifications to all active administrators
      if (severity === 'critical' || severity === 'high') {
        this.dispatchPushToAdmins({
          alert: createdAlert,
          title,
          message,
          orderId,
          severity,
          alertType,
        }).catch((err) => {
          this.logger.error?.('[admin-alert-engine] Push dispatch error:', err.message);
        });
      }

      return { alert: createdAlert, isNew: true };
    } catch (err) {
      this.logger.error?.('[admin-alert-engine] Unexpected raiseAlert error:', err);
      return null;
    }
  }

  /**
   * Dispatch push notifications to all configured & online admin devices
   */
  async dispatchPushToAdmins({ alert, title, message, orderId, severity, alertType }) {
    try {
      const adminUserIds = await getActiveAdminUserIds(this.logger);
      if (!adminUserIds || adminUserIds.length === 0) {
        return;
      }

      const clickUrl = orderId
        ? `/performance?view=alerts&order_id=${encodeURIComponent(orderId)}`
        : '/performance?view=alerts';

      const payloadData = {
        alert_id: String(alert?.id || ''),
        order_id: String(orderId || ''),
        alert_type: String(alertType || ''),
        severity: String(severity || 'critical'),
        click_url: clickUrl,
        click_action: clickUrl,
        sound: severity === 'critical' ? 'emergency_siren' : 'default',
        tag: `admin-alert-${orderId || alertType}`,
        renotify: 'true',
      };

      await supabasePushGateway.sendPush({
        userIds: adminUserIds,
        title: title || '⚠️ Sahla Admin Alert',
        body: message || 'Operational threshold exceeded',
        data: payloadData,
      });
    } catch (err) {
      this.logger.warn?.('[admin-alert-engine] Push dispatch warning:', err?.message);
    }
  }

  /**
   * Acknowledge an alert on behalf of an operator.
   * Silences repeating sirens and synchronizes state across all admin screens.
   */
  async acknowledgeAlert({ alertId, operatorName = 'Operator', operatorUserId = null }) {
    if (!alertId) return { success: false, error: 'alert_id_required' };

    const now = new Date().toISOString();

    if (_dbTableAvailable) {
      try {
        const { data, error } = await supabaseAdmin
          .from('admin_alerts')
          .update({
            status: 'acknowledged',
            acknowledged_by: operatorName,
            acknowledged_by_user_id: operatorUserId,
            acknowledged_at: now,
            updated_at: now,
          })
          .or(`id.eq.${alertId},order_id.eq.${alertId}`)
          .in('status', ['active', 'escalated'])
          .select('*');

        if (error) throw error;
        if (data && data.length > 0) return { success: true, alerts: data, alert: data[0] };
      } catch (err) {
        this.logger.error?.('[admin-alert-engine] Acknowledge error:', err.message);
      }
    }

    // Ephemeral fallback
    for (const [key, alert] of _ephemeralAlerts.entries()) {
      if ((alert.id === alertId || alert.order_id === alertId) && (alert.status === 'active' || alert.status === 'escalated')) {
        alert.status = 'acknowledged';
        alert.acknowledged_by = operatorName;
        alert.acknowledged_at = now;
        alert.updated_at = now;
        return { success: true, alert };
      }
    }

    return { success: false, error: 'alert_not_found' };
  }

  /**
   * Resolve an alert explicitly or on order resolution.
   */
  async resolveAlert({ alertId, resolvedBy = 'System', reason = 'manual_resolve' }) {
    if (!alertId) return { success: false, error: 'alert_id_required' };
    const now = new Date().toISOString();

    if (_dbTableAvailable) {
      try {
        const { data, error } = await supabaseAdmin
          .from('admin_alerts')
          .update({
            status: 'resolved',
            resolved_by: resolvedBy,
            resolved_at: now,
            resolution_reason: reason,
            updated_at: now,
          })
          .eq('id', alertId)
          .select('*')
          .maybeSingle();

        if (error) throw error;
        if (data) return { success: true, alert: data };
      } catch (err) {
        this.logger.error?.('[admin-alert-engine] Resolve error:', err.message);
      }
    }

    for (const [key, alert] of _ephemeralAlerts.entries()) {
      if (alert.id === alertId) {
        alert.status = 'resolved';
        alert.resolved_by = resolvedBy;
        alert.resolved_at = now;
        alert.resolution_reason = reason;
        return { success: true, alert };
      }
    }

    return { success: false, error: 'alert_not_found' };
  }

  /**
   * Automatically resolve all active/acknowledged alerts for an order when it completes a step.
   * E.g. reason = 'courier_picked_up', 'order_delivered', 'order_cancelled'
   */
  async resolveOrderAlerts(orderId, reason = 'order_status_advanced', resolvedBy = 'System') {
    if (!orderId) return { resolved_count: 0 };
    const now = new Date().toISOString();

    if (_dbTableAvailable) {
      try {
        const { data, error } = await supabaseAdmin
          .from('admin_alerts')
          .update({
            status: 'resolved',
            resolved_by: resolvedBy,
            resolved_at: now,
            resolution_reason: reason,
            updated_at: now,
          })
          .eq('order_id', orderId)
          .in('status', ['active', 'acknowledged', 'escalated'])
          .select('id');

        if (error) throw error;
        return { resolved_count: data?.length || 0 };
      } catch (err) {
        this.logger.error?.('[admin-alert-engine] resolveOrderAlerts error:', err.message);
      }
    }

    let count = 0;
    for (const [key, alert] of _ephemeralAlerts.entries()) {
      if (alert.order_id === orderId && (alert.status === 'active' || alert.status === 'acknowledged')) {
        alert.status = 'resolved';
        alert.resolved_by = resolvedBy;
        alert.resolved_at = now;
        alert.resolution_reason = reason;
        count++;
      }
    }
    return { resolved_count: count };
  }

  /**
   * Fetch all currently active, acknowledged, or escalated alerts.
   */
  async getActiveAlerts() {
    if (_dbTableAvailable) {
      try {
        const { data, error } = await supabaseAdmin
          .from('admin_alerts')
          .select('*')
          .in('status', ['active', 'acknowledged', 'escalated'])
          .order('created_at', { ascending: false })
          .limit(100);

        if (error) {
          if (error.code === 'PGRST205' || error.message?.includes('admin_alerts')) {
            _dbTableAvailable = false;
          } else {
            throw error;
          }
        } else if (data) {
          return data;
        }
      } catch (err) {
        this.logger.error?.('[admin-alert-engine] getActiveAlerts error:', err.message);
      }
    }

    // Ephemeral fallback
    const list = [];
    for (const alert of _ephemeralAlerts.values()) {
      if (alert.status === 'active' || alert.status === 'acknowledged' || alert.status === 'escalated') {
        list.push(alert);
      }
    }
    return list.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
  }

  /**
   * Register or refresh a Web Push device token for an admin operator.
   */
  async registerWebDevice({ userId, token, deviceId, userAgent }) {
    if (!token || !deviceId) {
      return { success: false, error: 'token_and_device_id_required' };
    }

    const now = new Date().toISOString();
    try {
      // Find default admin user ID if none provided
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
        const { error } = await supabaseAdmin
          .from('user_device_tokens')
          .update({
            user_id: effectiveUserId,
            token,
            platform: 'web',
            is_active: true,
            last_seen_at: now,
            updated_at: now,
            push_paused: false,
          })
          .eq('id', existing.id);

        if (error) throw error;
        return { success: true, updated: true };
      }

      const { error: insertError } = await supabaseAdmin
        .from('user_device_tokens')
        .insert({
          user_id: effectiveUserId,
          token,
          platform: 'web',
          device_id: deviceId,
          is_active: true,
          last_seen_at: now,
          created_at: now,
          updated_at: now,
          push_paused: false,
        });

      if (insertError) throw insertError;
      return { success: true, inserted: true };
    } catch (err) {
      this.logger.error?.('[admin-alert-engine] registerWebDevice error:', err.message);
      return { success: false, error: err.message };
    }
  }

  /**
   * Deactivate a Web Push device token upon admin logout or permission revocation.
   */
  async revokeWebDevice({ deviceId, token }) {
    try {
      let q = supabaseAdmin.from('user_device_tokens').update({ is_active: false, updated_at: new Date().toISOString() });
      if (deviceId) {
        q = q.eq('device_id', deviceId);
      } else if (token) {
        q = q.eq('token', token);
      } else {
        return { success: false, error: 'device_id_or_token_required' };
      }

      const { error } = await q;
      if (error) throw error;
      return { success: true };
    } catch (err) {
      this.logger.error?.('[admin-alert-engine] revokeWebDevice error:', err.message);
      return { success: false, error: err.message };
    }
  }
}

export const adminAlertEngine = new AdminAlertEngine();
