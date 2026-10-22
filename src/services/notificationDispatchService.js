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

export async function sendPushWithDispatch({
  dispatchKey,
  orderId,
  cohort = 'system',
  userIds = [],
  title,
  body,
  data = {},
  dedupe = true,
}) {
  const ids = normalizeUserIds(userIds);
  if (!ids.length) {
    if (dedupe && dispatchKey) {
      await orderLifecycleRepository.recordDispatchIfNew({
        dispatchKey,
        orderId: orderId || null,
        cohort,
        status: 'skipped',
        providerResponse: { skipped: true, reason: 'no_recipients' },
      });
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
      cohort,
      status: 'skipped',
      providerResponse: { reserved: true },
    });
    if (!inserted) {
      const existing = await orderLifecycleRepository.getDispatchByKey(resolvedDispatchKey);
      if (existing?.status === 'sent' && dispatchLogDelivered(existing.provider_response)) {
        return { success: true, skipped: true, reason: 'deduped_dispatch' };
      }
    }
  }

  const sent = await supabasePushGateway.sendPush({ userIds: ids, title, body, data });
  const totalSent = pushTotalSent(sent);
  const edgeReason = String(sent?.raw?.reason ?? sent?.reason ?? '').trim();
  const succeeded =
    pushSendSucceeded(sent) &&
    totalSent > 0 &&
    edgeReason !== 'all_target_users_duplicate';

  if (dedupe) {
    await orderLifecycleRepository.updateDispatchStatus(resolvedDispatchKey, {
      status: succeeded ? 'sent' : 'failed',
      providerResponse: { ...sent, total_sent: totalSent },
    });
  }
  return { ...sent, total_sent: totalSent, success: succeeded };
}
