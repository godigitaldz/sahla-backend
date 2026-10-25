import { supabaseAdmin } from '../config/supabase.js';

/**
 * Drains pending push notifications queued in web_order_push_outbox table.
 *
 * @param {Object} options
 * @param {Object} [options.logger=console]
 * @returns {Promise<Object>}
 */
export async function runWebOrderPushOutboxDrainerOnce({ logger = console } = {}) {
  const stats = {
    drained: 0,
    skipped: false,
    error: null,
  };

  const enabled = ['1', 'true', 'yes', 'on'].includes(
    String(process.env.WEB_ORDER_PUSH_ENABLED ?? 'false').trim().toLowerCase(),
  );
  if (!enabled) {
    stats.skipped = true;
    stats.reason = 'web_order_push_disabled';
    return stats;
  }

  try {
    const { data: outboxRows, error: fetchErr } = await supabaseAdmin
      .from('web_order_push_outbox')
      .select('id, order_id, event, status, payload_json')
      .eq('status', 'pending')
      .limit(25);

    if (fetchErr) {
      // Table may not exist in older migrations
      stats.skipped = true;
      stats.reason = fetchErr.message;
      return stats;
    }

    if (!outboxRows || outboxRows.length === 0) {
      return stats;
    }

    for (const row of outboxRows) {
      try {
        const payload = typeof row.payload_json === 'object' && row.payload_json !== null
          ? row.payload_json
          : JSON.parse(row.payload_json || '{}');
        const userIds = Array.isArray(payload.user_ids)
          ? payload.user_ids
          : (payload.user_id ? [payload.user_id] : []);

        if (userIds.length === 0) {
          continue;
        }

        const invokeRes = await supabaseAdmin.functions.invoke('send-push-notification', {
          body: {
            user_ids: userIds,
            title: payload.title || 'Order Update',
            body: payload.body || '',
            data: payload.data || {},
            force_activate_inactive_tokens: true,
          },
        });
            data: row.data || {},
            force_activate_inactive_tokens: true,
          },
        });

        const status = (!invokeRes.error && invokeRes.data?.success === true) ? 'sent' : 'failed';
        await supabaseAdmin
          .from('web_order_push_outbox')
          .update({
            status,
            updated_at: new Date().toISOString(),
          })
          .eq('id', row.id);

        if (status === 'sent') {
          stats.drained += 1;
        }
      } catch (rowErr) {
        logger.warn?.(`[web-order-push-drainer] row=${row.id} send error:`, rowErr.message);
      }
    }

    return stats;
  } catch (err) {
    logger.error?.('[web-order-push-drainer] unexpected error:', err);
    stats.error = err?.message ?? String(err);
    return stats;
  }
}
