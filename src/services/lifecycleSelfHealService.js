import { supabaseAdmin } from '../config/supabase.js';
import { syncLifecycleForOrder } from '../modules/orders/application/scheduleOrderLifecycle.js';

/**
 * Self-heals lifecycle schedules for orders created directly in Supabase (e.g. from mobile app)
 * or orders whose QStash jobs were interrupted.
 *
 * @param {Object} options
 * @param {number} [options.budgetMs=15000]
 * @param {Object} [options.logger=console]
 * @returns {Promise<Object>}
 */
export async function runLifecycleSelfHealOnce({ budgetMs = 15_000, logger = console } = {}) {
  const stats = {
    evaluated_orders: 0,
    synced_orders: 0,
    skipped: false,
    error: null,
  };

  if (!process.env.QSTASH_TOKEN) {
    stats.skipped = true;
    stats.reason = 'qstash_not_configured';
    return stats;
  }

  const startedAt = Date.now();
  const safeIsoAgo = new Date(Date.now() - 2 * 3600_000).toISOString();

  try {
    const { data: activeOrders, error: queryErr } = await supabaseAdmin
      .from('orders')
      .select('id, status, delivery_person_id, lifecycle_version, created_at, updated_at, courier_unassigned_episode_at')
      .in('status', ['pending', 'preparing', 'ready'])
      .gte('created_at', safeIsoAgo)
      .order('created_at', { ascending: false })
      .limit(30);

    if (queryErr) {
      logger.error?.('[lifecycle-self-heal] query failed:', queryErr.message);
      stats.error = queryErr.message;
      return stats;
    }

    stats.evaluated_orders = (activeOrders ?? []).length;

    for (const order of (activeOrders ?? [])) {
      if (Date.now() - startedAt >= budgetMs) {
        break;
      }
      try {
        await syncLifecycleForOrder(order, Number(order.lifecycle_version || 0));
        stats.synced_orders += 1;
      } catch (err) {
        logger.warn?.(`[lifecycle-self-heal] sync failed for order=${order.id}:`, err?.message);
      }
    }

    return stats;
  } catch (err) {
    logger.error?.('[lifecycle-self-heal] error:', err);
    stats.error = err?.message ?? String(err);
    return stats;
  }
}
