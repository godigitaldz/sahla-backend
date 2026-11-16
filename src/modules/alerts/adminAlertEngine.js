import { supabaseAdmin } from '../../config/supabase.js';
import { supabasePushGateway } from '../notifications/supabasePushGateway.js';
import { getActiveAdminUserIds } from '../../services/adminRecipients.js';
import { adminWebPushService } from '../../services/adminWebPushService.js';

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
      // Check if order was already acknowledged by an admin in persistent order_events (cross-serverless instance sync)
      if (orderId) {
        try {
          const { data: dbAck } = await supabaseAdmin
            .from('order_events')
            .select('id, created_at, event_data')
            .eq('order_id', orderId)
            .eq('event_type', 'updated')
            .filter('event_data->>action', 'eq', 'admin_alert_acknowledged')
            .gte('created_at', new Date(Date.now() - 24 * 3600 * 1000).toISOString())
            .limit(1)
            .maybeSingle();

          if (dbAck) {
            const existingAlert = {
              id: `acked-${orderId}`,
              order_id: orderId,
              task_id: taskId,
              alert_type: alertType,
              severity,
              dedupe_key: dedupeKey,
              title,
              message,
              metadata,
              status: 'acknowledged',
              acknowledged_by: dbAck.event_data?.operator_name || 'Admin',
              acknowledged_at: dbAck.created_at,
              escalation_level: 0,
              created_at: dbAck.created_at,
              updated_at: dbAck.created_at,
            };
            _ephemeralAlerts.set(dedupeKey, existingAlert);
            return { alert: existingAlert, isNew: false };
          }
        } catch (_) {}
      }

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

      // 1. Send push to Android mobile app couriers/admins via Supabase Edge Function
      await supabasePushGateway.sendPush({
        userIds: adminUserIds,
        title: title || '⚠️ Sahla Admin Alert',
        body: message || 'Operational threshold exceeded',
        data: payloadData,
      }).catch((err) => {
        this.logger.warn?.('[admin-alert-engine] FCM push dispatch warning:', err?.message);
      });

      // 2. Send native Web Push to locked iOS PWAs and Web Dashboards
      await adminWebPushService.sendWebPushToAllAdmins({
        title: title || '⚠️ Sahla Admin Alert',
        body: message || 'Operational threshold exceeded',
        data: payloadData,
        severity,
      }).catch((err) => {
        this.logger.warn?.('[admin-alert-engine] Web Push dispatch warning:', err?.message);
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

    let targetOrderId = (typeof alertId === 'string' && /^[0-9a-f-]{36}$/i.test(alertId)) ? alertId : null;
    if (!targetOrderId) {
      for (const a of _ephemeralAlerts.values()) {
        if (a.id === alertId && a.order_id) {
          targetOrderId = a.order_id;
          break;
        }
      }
    }

    // Persist acknowledgement into order_events so all serverless instances and devices stay synchronized
    if (targetOrderId) {
      try {
        await supabaseAdmin.from('order_events').insert({
          order_id: targetOrderId,
          event_type: 'updated',
          changed_by_role: 'admin',
          event_data: {
            action: 'admin_alert_acknowledged',
            operator_name: operatorName,
            operator_user_id: operatorUserId,
            acked_at: now,
          },
          source: 'backend',
        });
      } catch (err) {
        this.logger.error?.('[admin-alert-engine] order_events ack insert error:', err.message);
      }
    }

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

        if (error) {
          if (error.code === 'PGRST205' || error.message?.includes('admin_alerts')) {
            _dbTableAvailable = false;
          }
        } else if (data && data.length > 0) {
          return { success: true, alerts: data, alert: data[0] };
        }
      } catch (err) {
        this.logger.error?.('[admin-alert-engine] Acknowledge error:', err.message);
      }
    }

    // Update Ephemeral cache
    let matchedAlert = null;
    for (const [key, alert] of _ephemeralAlerts.entries()) {
      if (alert.id === alertId || alert.order_id === alertId || (targetOrderId && alert.order_id === targetOrderId)) {
        alert.status = 'acknowledged';
        alert.acknowledged_by = operatorName;
        alert.acknowledged_at = now;
        alert.updated_at = now;
        matchedAlert = alert;
      }
    }

    if (matchedAlert) {
      return { success: true, alert: matchedAlert };
    }

    // Even if not previously in ephemeral cache, record it as acknowledged
    const synthAlert = {
      id: alertId,
      order_id: targetOrderId || alertId,
      status: 'acknowledged',
      acknowledged_by: operatorName,
      acknowledged_at: now,
      updated_at: now,
    };
    _ephemeralAlerts.set(`acked:${alertId}`, synthAlert);
    return { success: true, alert: synthAlert };
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
   * Merges persistent DB alerts, cross-instance order_events acks, and ephemeral alerts.
   */
  async getActiveAlerts() {
    let list = [];

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
          list = data;
        }
      } catch (err) {
        this.logger.error?.('[admin-alert-engine] getActiveAlerts error:', err.message);
      }
    }

    if (!list.length) {
      // Ephemeral fallback
      for (const alert of _ephemeralAlerts.values()) {
        if (alert.status === 'active' || alert.status === 'acknowledged' || alert.status === 'escalated') {
          list.push(alert);
        }
      }
    }

    // Always merge persistent acknowledgements from order_events so ALL serverless instances stay synchronized!
    try {
      const { data: dbAcks } = await supabaseAdmin
        .from('order_events')
        .select('order_id, event_data, created_at')
        .eq('event_type', 'updated')
        .filter('event_data->>action', 'eq', 'admin_alert_acknowledged')
        .gte('created_at', new Date(Date.now() - 24 * 3600 * 1000).toISOString())
        .limit(200);

      if (dbAcks && dbAcks.length > 0) {
        const ackedOrderIds = new Set(dbAcks.map((a) => a.order_id).filter(Boolean));
        for (const alert of list) {
          if (alert.order_id && ackedOrderIds.has(alert.order_id)) {
            alert.status = 'acknowledged';
          }
        }
        for (const ack of dbAcks) {
          if (!list.some((a) => a.order_id === ack.order_id)) {
            list.push({
              id: `acked-${ack.order_id}`,
              order_id: ack.order_id,
              status: 'acknowledged',
              severity: 'critical',
              title: 'تنبيه مؤكد',
              acknowledged_by: ack.event_data?.operator_name || 'Admin',
              acknowledged_at: ack.created_at,
              created_at: ack.created_at,
            });
          }
        }
      }
    } catch (ackErr) {
      this.logger.warn?.('[admin-alert-engine] dbAcks fetch error:', ackErr.message);
    }

    return list.sort((a, b) => new Date(b.created_at) - new Date(a.created_at));
  }

  /**
   * Register or refresh a Web Push device token for an admin operator.
   */
  async registerWebDevice({ userId, token, deviceId, userAgent, subscription, platform }) {
    return adminWebPushService.registerSubscription({
      userId,
      deviceId,
      token,
      subscription,
      platform,
      userAgent,
    });
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
