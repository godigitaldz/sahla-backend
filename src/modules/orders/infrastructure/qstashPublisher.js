import { Client } from '@upstash/qstash';

function parseBaseUrl() {
  const primary = String(process.env.ORDER_LIFECYCLE_WEBHOOK_URL || '').trim();
  const legacy = String(process.env.QSTASH_LIFECYCLE_CALLBACK_URL || '').trim();
  let value = primary || legacy;
  if (!value || value.includes('sahla-delivery.com')) {
    value = 'https://sahla-backend.vercel.app';
  }
  return value.replace(/\/+$/, '');
}

function qstashForwardHeaders() {
  const headers = {};
  const bypass = String(process.env.VERCEL_AUTOMATION_BYPASS_SECRET || '').trim();
  if (bypass) {
    headers['Upstash-Forward-x-vercel-protection-bypass'] = bypass;
  }
  return headers;
}

export class QstashPublisher {
  constructor() {
    const token = process.env.QSTASH_TOKEN;
    this.enabled = Boolean(token);
    this.baseWebhookUrl = parseBaseUrl();
    this.client = this.enabled ? new Client({ token }) : null;
  }

  assertEnabled() {
    if (!this.enabled || !this.client) {
      throw new Error('QSTASH_TOKEN is not configured');
    }
    if (!this.baseWebhookUrl) {
      throw new Error(
        'ORDER_LIFECYCLE_WEBHOOK_URL (or QSTASH_LIFECYCLE_CALLBACK_URL) is not configured',
      );
    }
  }

  endpointUrl() {
    return `${this.baseWebhookUrl}/api/internal/events/order-lifecycle`;
  }

  pendingOrdersPollUrl() {
    return `${this.baseWebhookUrl}/api/internal/pending-orders-poll`;
  }

  async scheduleLifecycleMessage({
    eventId,
    eventType,
    orderId,
    expectedStatus,
    delaySeconds,
    traceId,
    lifecycleVersion,
  }) {
    this.assertEnabled();
    const scheduledFor = new Date(Date.now() + delaySeconds * 1000).toISOString();
    const body = {
      event_id: eventId,
      event_type: eventType,
      order_id: orderId,
      expected_status: expectedStatus,
      scheduled_for: scheduledFor,
      trace_id: traceId,
      event_version: 1,
      lifecycle_version: lifecycleVersion ?? 0,
    };
    const forwardHeaders = qstashForwardHeaders();
    const res = await this.client.publishJSON({
      url: this.endpointUrl(),
      body,
      delay: `${delaySeconds}s`,
      retries: 8,
      ...(Object.keys(forwardHeaders).length ? { headers: forwardHeaders } : {}),
    });
    return {
      messageId: res?.messageId || null,
      scheduledFor,
      payload: body,
    };
  }

  async cancelMessage(messageId) {
    if (!this.enabled || !this.client || !messageId) return false;
    try {
      await this.client.messages.delete(messageId);
      return true;
    } catch {
      return false;
    }
  }

  async listSchedules() {
    this.assertEnabled();
    return this.client.schedules.list();
  }

  async deleteSchedule(scheduleId) {
    this.assertEnabled();
    if (!scheduleId) return false;
    await this.client.schedules.delete(scheduleId);
    return true;
  }

  /**
   * Ensures an always-on recurring QStash schedule exists to trigger
   * `/api/internal/pending-orders-poll` every minute, independent of browser/dashboard activity.
   */
  async ensureRecurringCronSchedule({
    cron = '* * * * *',
    destination = null,
    cronSecret = null,
    logger = console,
  } = {}) {
    if (!this.enabled || !this.client) {
      return { skipped: true, reason: 'qstash_not_configured' };
    }

    const secret =
      cronSecret ||
      process.env.CRON_SECRET ||
      process.env.SAHLA_CRON_SECRET ||
      '';
    if (!secret) {
      return { skipped: true, reason: 'missing_cron_secret' };
    }

    const targetUrl = destination || this.pendingOrdersPollUrl();

    try {
      const existingSchedules = await this.client.schedules.list().catch((err) => {
        logger.warn?.('[qstash] schedules.list error:', err?.message);
        return [];
      });

      const match = (existingSchedules || []).find(
        (s) => s?.destination === targetUrl,
      );

      if (match) {
        logger.info?.(`[qstash] active recurring schedule found: id=${match.scheduleId} cron="${match.cron}"`);
        return {
          created: false,
          already_exists: true,
          scheduleId: match.scheduleId,
          cron: match.cron,
          destination: targetUrl,
        };
      }

      const forwardHeaders = qstashForwardHeaders();
      const headers = {
        Authorization: `Bearer ${secret}`,
        'Content-Type': 'application/json',
        ...forwardHeaders,
      };

      const res = await this.client.schedules.create({
        destination: targetUrl,
        cron,
        method: 'POST',
        headers,
        retries: 2,
      });

      logger.info?.(`[qstash] created recurring schedule: id=${res?.scheduleId} cron="${cron}" -> ${targetUrl}`);
      return {
        created: true,
        already_exists: false,
        scheduleId: res?.scheduleId,
        cron,
        destination: targetUrl,
      };
    } catch (err) {
      logger.error?.('[qstash] ensureRecurringCronSchedule failed:', err?.message);
      return {
        created: false,
        error: err?.message || String(err),
      };
    }
  }
}

export const qstashPublisher = new QstashPublisher();
