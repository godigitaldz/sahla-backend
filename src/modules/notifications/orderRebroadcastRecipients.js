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
 */
export async function getRestaurantOpsUserIds(restaurantId, logger = console) {
  const rid = String(restaurantId ?? '').trim();
  if (!rid) return [];

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
 */
export async function getOnlineAvailableCourierUserIds(logger = console) {
  const { data: couriers, error } = await supabaseAdmin
    .from('delivery_personnel')
    .select('user_id')
    .eq('is_online', true)
    .eq('is_available', 'true');

  if (error) {
    logger.error?.('[order-rebroadcast-recipients] delivery_personnel query failed:', error.message);
    return [];
  }

  return [
    ...new Set(
      (couriers ?? [])
        .map((r) => String(r?.user_id ?? '').trim())
        .filter((id) => id.length > 0),
    ),
  ];
}

export function isCourierDeliverableOrder(order) {
  const fulfillmentType = String(order?.fulfillment_type || 'delivery').toLowerCase();
  const parcelSenderId = String(order?.parcel_sender_id ?? '').trim();
  return fulfillmentType === 'delivery' && parcelSenderId.length === 0;
}
