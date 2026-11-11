import { supabaseAdmin } from '../../config/supabase.js';

function normalizedIdSet(values = []) {
  return new Set(
    (values ?? [])
      .map((v) => String(v ?? '').trim())
      .filter((v) => v.length > 0),
  );
}

async function getActiveStaffUserIdsByRestaurant(restaurantIds, logger = console) {
  const ids = [...normalizedIdSet(restaurantIds)];
  const staffByRestaurant = new Map();
  if (ids.length === 0) return staffByRestaurant;

  const { data, error } = await supabaseAdmin
    .from('restaurant_staff_members')
    .select('restaurant_id,user_id')
    .in('restaurant_id', ids)
    .eq('status', 'active');

  if (error) {
    logger.error?.('[order-rebroadcast-recipients] restaurant staff query failed:', error.message);
    return staffByRestaurant;
  }

  for (const row of data ?? []) {
    const restaurantId = String(row?.restaurant_id ?? '').trim();
    const userId = String(row?.user_id ?? '').trim();
    if (!restaurantId || !userId) continue;
    if (!staffByRestaurant.has(restaurantId)) {
      staffByRestaurant.set(restaurantId, new Set());
    }
    staffByRestaurant.get(restaurantId).add(userId);
  }

  return staffByRestaurant;
}

/**
 * Restaurant owner + active staff for push rebroadcast (`new_order`).
 * Aligned with Flutter app RestaurantService.getRestaurantNotificationRecipients:
 * 1. RPC get_restaurant_notification_recipient_ids
 * 2. Fallback to restaurants.owner_id + restaurant_staff_members
 */
export async function getRestaurantOpsUserIds(restaurantId, logger = console) {
  const rid = String(restaurantId ?? '').trim();
  if (!rid) return [];

  try {
    const { data: rpcRows, error: rpcErr } = await supabaseAdmin.rpc(
      'get_restaurant_notification_recipient_ids',
      { p_restaurant_id: rid }
    );
    if (!rpcErr && Array.isArray(rpcRows) && rpcRows.length > 0) {
      const ids = new Set();
      for (const item of rpcRows) {
        const id = item?.user_id ?? item?.id ?? item?.userId;
        if (id) ids.add(String(id).trim());
        else if (typeof item === 'string' && item.trim()) ids.add(item.trim());
      }
      if (ids.size > 0) {
        return [...ids];
      }
    }
  } catch (err) {
    logger.warn?.('[order-rebroadcast-recipients] rpc get_restaurant_notification_recipient_ids failed, falling back:', err?.message);
  }

  const [{ data: rest, error: rErr }, staffMap] = await Promise.all([
    supabaseAdmin
      .from('restaurants')
      .select('id, owner_id')
      .eq('id', rid)
      .maybeSingle(),
    getActiveStaffUserIdsByRestaurant([rid], logger),
  ]);

  if (rErr) {
    logger.error?.('[order-rebroadcast-recipients] restaurants query failed:', rErr.message);
  }

  const recipients = new Set();
  const ownerId = String(rest?.owner_id ?? '').trim();
  if (ownerId) recipients.add(ownerId);
  for (const staffUserId of staffMap.get(rid) ?? []) {
    recipients.add(staffUserId);
  }
  return [...recipients];
}

/**
 * Online + available delivery personnel user ids.
 * Aligned with Flutter app AdminAlertsScreen._loadAvailableCourierIds.
 */
export async function getOnlineAvailableCourierUserIds(logger = console) {
  const { data: couriers, error } = await supabaseAdmin
    .from('delivery_personnel')
    .select('user_id, is_online, is_available')
    .eq('is_online', true)
    .limit(1200);

  if (error) {
    logger.error?.('[order-rebroadcast-recipients] delivery_personnel query failed:', error.message);
    return [];
  }

  const ids = new Set();
  for (const row of couriers ?? []) {
    const userId = String(row?.user_id ?? '').trim();
    if (!userId) continue;
    const isAvail = row?.is_available === true || String(row?.is_available).toLowerCase().trim() === 'true';
    if (isAvail) ids.add(userId);
  }

  return [...ids];
}

export function isCourierDeliverableOrder(order) {
  const fulfillmentType = String(order?.fulfillment_type || 'delivery').toLowerCase();
  const parcelSenderId = String(order?.parcel_sender_id ?? '').trim();
  return fulfillmentType === 'delivery' && parcelSenderId.length === 0;
}
