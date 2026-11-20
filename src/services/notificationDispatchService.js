import crypto from 'node:crypto';

import {
  dispatchLogDelivered,
  pushSendSucceeded,
  pushTotalSent,
} from '../modules/notifications/pushSendResult.js';
import { supabasePushGateway } from '../modules/notifications/supabasePushGateway.js';
import { orderLifecycleRepository } from '../modules/orders/infrastructure/orderLifecycleRepository.js';

function normalizeUserIds(userIds = []) {
  return [...new Set((userIds || []).map((value) => String(value || '').trim()).filter(Boolean))];
}

/** In-flight reservation lease duration (ms) before considering a reserved dispatch stale. */
const RESERVATION_LEASE_MS = 60_000;

export async function sendPushWithDispatch({
  dispatchKey,
  orderId,
  cohort = 'admin',
  userIds = [],
  title,
  body,
  data = {},
  dedupe = true,
  logger = console,
}) {
  const startTime = Date.now();
  const ids = normalizeUserIds(userIds);
  const safeCohort = cohort === 'user' ? 'user' : 'admin';

  if (!ids.length) {
    if (dedupe && dispatchKey) {
      await orderLifecycleRepository
        .recordDispatchIfNew({
          dispatchKey,
          orderId: orderId || null,
          cohort: safeCohort,
          status: 'skipped',
          providerResponse: { skipped: true, reason: 'no_recipients' },
        })
        .catch(() => {});
    }
    return { success: false, skipped: true, reason: 'no_recipients' };
  }

  const resolvedDispatchKey =
    dedupe && dispatchKey
      ? dispatchKey
      : `${dispatchKey || 'dispatch'}:${Date.now()}:${crypto.randomUUID()}`;

  if (dedupe) {
    const inserted = await orderLifecycleRepository.recordDispatchIfNew({
      dispatchKey: resolvedDispatchKey,
      orderId: orderId || null,
      cohort: safeCohort,
      status: 'skipped',
      providerResponse: {
        reserved: true,
        reserved_at: new Date().toISOString(),
      },
    });

    if (!inserted) {
      const existing = await orderLifecycleRepository.getDispatchByKey(resolvedDispatchKey);
      if (existing?.status === 'sent' && dispatchLogDelivered(existing.provider_response)) {
        return { success: true, skipped: true, reason: 'deduped_dispatch' };
      }

      // Concurrency protection: if already reserved within lease time, another runner is in-flight.
      const reservedAt = Date.parse(
        existing?.provider_response?.reserved_at || existing?.updated_at || '',
      );
      const isReserved =
        existing?.status === 'skipped' && existing?.provider_response?.reserved === true;
      if (isReserved && Number.isFinite(reservedAt) && Date.now() - reservedAt < RESERVATION_LEASE_MS) {
        return { success: true, skipped: true, reason: 'dispatch_in_flight' };
      }
    }
  }

  let sent;
  try {
    sent = await supabasePushGateway.sendPush({ userIds: ids, title, body, data });
  } catch (err) {
    if (dedupe) {
      await orderLifecycleRepository
        .updateDispatchStatus(resolvedDispatchKey, {
          status: 'failed',
          providerResponse: {
            error: err.message,
            attempted_recipients: ids.length,
            failed_at: new Date().toISOString(),
          },
        })
        .catch(() => {});
    }
    logger.error?.(`[notification-dispatch] push failed for key="${resolvedDispatchKey}":`, err?.message);
    throw err;
  }

  const totalSent = pushTotalSent(sent);
  const edgeReason = String(sent?.raw?.reason ?? sent?.reason ?? '').trim();
  const succeeded =
    pushSendSucceeded(sent) &&
    totalSent > 0 &&
    edgeReason !== 'all_target_users_duplicate';

  const durationMs = Date.now() - startTime;

  if (dedupe) {
    await orderLifecycleRepository.updateDispatchStatus(resolvedDispatchKey, {
      status: succeeded ? 'sent' : 'failed',
      providerResponse: {
        ...sent,
        total_sent: totalSent,
        attempted_recipients: ids.length,
        duration_ms: durationMs,
        flow: data?.flow || null,
        stage: data?.stage || null,
        order_id: orderId || null,
        executed_at: new Date().toISOString(),
      },
    });
  }

  return { ...sent, total_sent: totalSent, success: succeeded, duration_ms: durationMs };
}
