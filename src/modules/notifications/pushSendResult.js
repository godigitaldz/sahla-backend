/** Normalize gateway / dispatch push result total_sent (top-level or edge summary). */
export function pushTotalSent(result) {
  if (!result) return 0;
  const top = Number(result.total_sent);
  if (Number.isFinite(top) && top > 0) return top;
  const nested = Number(result.summary?.total_sent ?? result.raw?.summary?.total_sent);
  return Number.isFinite(nested) ? nested : 0;
}

export function dispatchLogDelivered(providerResponse) {
  const total = pushTotalSent(providerResponse ?? {});
  if (total > 0) return true;
  const reason = String(providerResponse?.raw?.reason ?? providerResponse?.reason ?? '').trim();
  return reason === 'all_target_users_muted_new_order_push'
    || reason === 'welcome_account_creation_push_disabled';
}

export function pushSendSucceeded(result) {
  if (!result || result.skipped) return false;
  if (result.success !== true) return false;
  const total = pushTotalSent(result);
  if (total > 0) return true;
  const reason = String(result.raw?.reason ?? result.reason ?? '').trim();
  if (reason === 'all_target_users_duplicate') return false;
  if (reason === 'all_target_users_muted_new_order_push') return true;
  if (reason === 'welcome_account_creation_push_disabled') return true;
  return false;
}
