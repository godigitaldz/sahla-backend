import type { SupabaseClient } from '@supabase/supabase-js';
import { hashRegistrationValue } from '@/server/orders/hashRegistrationValue';
import { webOrderPushProvider } from '@/server/orders/pushFeatureFlag';

export type UpsertPushSubscriptionInput = {
  tracking_link_id: string;
  order_id: string;
  registration_kind: 'fid' | 'legacy_token';
  registration_value: string;
  permission_state?: string | null;
  user_agent_family?: string | null;
  platform_hint?: string | null;
  click_url: string;
  expires_at: string;
};

export async function upsertWebPushSubscription(
  admin: SupabaseClient,
  input: UpsertPushSubscriptionInput,
): Promise<{ ok: true } | { ok: false; reason: 'db_error' }> {
  const registrationHash = hashRegistrationValue(input.registration_value);
  const now = new Date().toISOString();
  const provider = webOrderPushProvider() === 'fcm_web' ? 'fcm_web' : 'fcm_web';

  const { data: existing } = await admin
    .from('web_order_push_subscriptions')
    .select('id')
    .eq('tracking_link_id', input.tracking_link_id)
    .eq('registration_hash', registrationHash)
    .maybeSingle();

  if (existing?.id) {
    const { error } = await admin
      .from('web_order_push_subscriptions')
      .update({
        registration_value: input.registration_value,
        registration_kind: input.registration_kind,
        permission_state: input.permission_state ?? null,
        user_agent_family: input.user_agent_family ?? null,
        platform_hint: input.platform_hint ?? null,
        click_url: input.click_url,
        expires_at: input.expires_at,
        last_registered_at: now,
        revoked_at: null,
        failure_count: 0,
      })
      .eq('id', existing.id);

    if (error) return { ok: false, reason: 'db_error' };
    return { ok: true };
  }

  const { error } = await admin.from('web_order_push_subscriptions').insert({
    tracking_link_id: input.tracking_link_id,
    order_id: input.order_id,
    provider,
    registration_kind: input.registration_kind,
    registration_value: input.registration_value,
    registration_hash: registrationHash,
    permission_state: input.permission_state ?? null,
    user_agent_family: input.user_agent_family ?? null,
    platform_hint: input.platform_hint ?? null,
    click_url: input.click_url,
    expires_at: input.expires_at,
    last_registered_at: now,
  });

  if (error) return { ok: false, reason: 'db_error' };
  return { ok: true };
}

export async function revokeWebPushSubscription(
  admin: SupabaseClient,
  params: {
    tracking_link_id: string;
    registration_value: string;
  },
): Promise<{ ok: true; revoked: boolean } | { ok: false; reason: 'db_error' }> {
  const registrationHash = hashRegistrationValue(params.registration_value);
  const now = new Date().toISOString();

  const { data, error } = await admin
    .from('web_order_push_subscriptions')
    .update({ revoked_at: now })
    .eq('tracking_link_id', params.tracking_link_id)
    .eq('registration_hash', registrationHash)
    .is('revoked_at', null)
    .select('id');

  if (error) return { ok: false, reason: 'db_error' };
  return { ok: true, revoked: (data?.length ?? 0) > 0 };
}
