import { Client } from '@upstash/qstash';

function parseBaseUrl() {
  const primary = String(process.env.ORDER_LIFECYCLE_WEBHOOK_URL || '').trim();
  const legacy = String(process.env.QSTASH_LIFECYCLE_CALLBACK_URL || '').trim();
  const value = primary || legacy;
  if (!value) return '';
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
}

export const qstashPublisher = new QstashPublisher();
