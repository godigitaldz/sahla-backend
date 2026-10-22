import { supabaseAdmin } from '../../../config/supabase.js';

export class OrderLifecycleRepository {
  mapLegacyEventType(eventType) {
    if (eventType === 'order_cancelled_timeout') return 'cancelled';
    return 'updated';
  }

  async getJobByKey(jobKey) {
    const { data, error } = await supabaseAdmin
      .from('order_lifecycle_jobs')
      .select('*')
      .eq('job_key', jobKey)
      .maybeSingle();
    if (error) throw error;
    return data;
  }

  async createLifecycleJob({
    orderId,
    jobKey,
    eventType,
    qstashMessageId,
    scheduledFor,
  }) {
    const payload = {
      order_id: orderId,
      job_key: jobKey,
      event_type: eventType,
      qstash_message_id: qstashMessageId || null,
      scheduled_for: scheduledFor,
      state: 'scheduled',
      updated_at: new Date().toISOString(),
    };
    const { data, error } = await supabaseAdmin
      .from('order_lifecycle_jobs')
      .upsert(payload, { onConflict: 'job_key' })
      .select('*')
      .single();
    if (error) throw error;
    return data;
  }

  async markJobState(jobKey, state, extras = {}) {
    const patch = { state, updated_at: new Date().toISOString(), ...extras };
    if (state === 'executed' || state === 'skipped') patch.executed_at = new Date().toISOString();
    const { data, error } = await supabaseAdmin
      .from('order_lifecycle_jobs')
      .update(patch)
      .eq('job_key', jobKey)
      .select('*')
      .maybeSingle();
    if (error) throw error;
    return data;
  }

  async incrementAttempt(jobKey, lastError) {
    const { data: existing, error: loadError } = await supabaseAdmin
      .from('order_lifecycle_jobs')
      .select('attempt_count')
      .eq('job_key', jobKey)
      .maybeSingle();
    if (loadError) throw loadError;
    const nextCount = Number(existing?.attempt_count || 0) + 1;
    const { error } = await supabaseAdmin
      .from('order_lifecycle_jobs')
      .update({
        attempt_count: nextCount,
        last_error: lastError || null,
        updated_at: new Date().toISOString(),
      })
      .eq('job_key', jobKey);
    if (error) throw error;
  }

  async recordEventIfNew({
    eventId,
    orderId,
    eventType,
    source = 'backend',
    payload = {},
    orderNumber = null,
    currentStatus = null,
    customerId = null,
    restaurantId = null,
    deliveryPersonId = null,
  }) {
    const baseRow = {
      event_id: eventId,
      order_id: orderId,
      event_type: eventType,
      source,
      payload_json: payload,
    };

    const { data, error } = await supabaseAdmin
      .from('order_events')
      .upsert(baseRow, { onConflict: 'event_id', ignoreDuplicates: true })
      .select('id,event_id');
    if (!error) return Array.isArray(data) && data.length > 0;

    const msg = String(error?.message || '').toLowerCase();
    const needsLegacyFallback =
      msg.includes('order_number') ||
      msg.includes('new_status') ||
      msg.includes('violates check constraint');
    if (!needsLegacyFallback) throw error;

    const legacyRow = {
      event_id: eventId,
      order_id: orderId,
      order_number: String(orderNumber || orderId || ''),
      event_type: this.mapLegacyEventType(eventType),
      new_status: String(currentStatus || 'pending'),
      customer_id: customerId || null,
      restaurant_id: restaurantId || null,
      delivery_person_id: deliveryPersonId || null,
      source,
      payload_json: payload,
      event_data: payload,
    };

    const { data: fallbackData, error: fallbackError } = await supabaseAdmin
      .from('order_events')
      .upsert(legacyRow, { onConflict: 'event_id', ignoreDuplicates: true })
      .select('id,event_id');
    if (fallbackError) throw fallbackError;
    return Array.isArray(fallbackData) && fallbackData.length > 0;
  }

  async recordDispatchIfNew({
    dispatchKey,
    orderId,
    cohort,
    status,
    providerResponse = {},
  }) {
    const { data, error } = await supabaseAdmin
      .from('notification_dispatch_log')
      .upsert(
        {
          dispatch_key: dispatchKey,
          order_id: orderId,
          cohort,
          channel: 'push',
          status,
          provider_response: providerResponse,
        },
        { onConflict: 'dispatch_key', ignoreDuplicates: true },
      )
      .select('id,dispatch_key');
    if (error) throw error;
    return Array.isArray(data) && data.length > 0;
  }

  async updateDispatchStatus(dispatchKey, { status, providerResponse = {} }) {
    const { data, error } = await supabaseAdmin
      .from('notification_dispatch_log')
      .update({
        status,
        provider_response: providerResponse,
      })
      .eq('dispatch_key', dispatchKey)
      .select('id,dispatch_key,status')
      .maybeSingle();
    if (error) throw error;
    return data;
  }

  async getDispatchByKey(dispatchKey) {
    const { data, error } = await supabaseAdmin
      .from('notification_dispatch_log')
      .select('id,dispatch_key,status,provider_response,order_id,cohort')
      .eq('dispatch_key', dispatchKey)
      .maybeSingle();
    if (error) throw error;
    return data;
  }

  async getOrderById(orderId) {
    const { data, error } = await supabaseAdmin
      .from('orders')
      .select('id,order_number,status,customer_id,restaurant_id,lifecycle_version,delivery_person_id,courier_assigned_at,courier_unassigned_episode_at,created_at,preparing_started_at,fulfillment_type,parcel_sender_id')
      .eq('id', orderId)
      .maybeSingle();
    if (error) throw error;
    return data;
  }

  async cancelPendingJobs(orderId, eventTypes) {
    let q = supabaseAdmin
      .from('order_lifecycle_jobs')
      .select('*')
      .eq('order_id', orderId)
      .eq('state', 'scheduled');
    if (Array.isArray(eventTypes) && eventTypes.length) {
      q = q.in('event_type', eventTypes);
    }
    const { data, error } = await q;
    if (error) throw error;
    return data || [];
  }

  async listUnpublishedScheduledJobs(limit = 50) {
    return this.listUnpublishedLifecycleJobs(limit);
  }

  /** Jobs that still need a QStash publish (scheduled or failed retry). */
  async listUnpublishedLifecycleJobs(limit = 50) {
    const { data, error } = await supabaseAdmin
      .from('order_lifecycle_jobs')
      .select('*')
      .in('state', ['scheduled', 'failed'])
      .is('qstash_message_id', null)
      .order('scheduled_for', { ascending: true })
      .limit(limit);
    if (error) throw error;
    return data || [];
  }

  async attachQstashMessageId(jobKey, qstashMessageId, scheduledFor = null) {
    const patch = {
      qstash_message_id: qstashMessageId || null,
      updated_at: new Date().toISOString(),
    };
    if (scheduledFor) {
      patch.scheduled_for = scheduledFor;
    }
    const { data, error } = await supabaseAdmin
      .from('order_lifecycle_jobs')
      .update(patch)
      .eq('job_key', jobKey)
      .select('*')
      .maybeSingle();
    if (error) throw error;
    return data;
  }

  async transitionPendingToCancelled(orderId, reason = 'timeout_15m') {
    const { data, error } = await supabaseAdmin
      .from('orders')
      .update({
        status: 'cancelled',
        cancel_reason: reason,
        cancelled_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      })
      .eq('id', orderId)
      .eq('status', 'pending')
      .select('id,status,order_number,customer_id,restaurant_id')
      .maybeSingle();
    if (error) throw error;
    return data;
  }

  /**
   * Upsert 15m cancel sibling without publishing QStash (reconcile/bootstrap publishes).
   * Does not overwrite an existing job row (avoids clearing qstash_message_id).
   */
  async ensurePending15mCancelSibling(orderId, createdAtIso) {
    const jobKey = `order:${orderId}:order.pending.15m.cancel`;
    const existing = await this.getJobByKey(jobKey);
    if (existing) return existing;

    const createdMs = Date.parse(String(createdAtIso || ''));
    const baseMs = Number.isFinite(createdMs) ? createdMs : Date.now();
    const scheduledFor = new Date(baseMs + 15 * 60 * 1000).toISOString();
    return this.createLifecycleJob({
      orderId,
      jobKey,
      eventType: 'order.pending.15m.cancel',
      qstashMessageId: null,
      scheduledFor,
    });
  }
}

export const orderLifecycleRepository = new OrderLifecycleRepository();
