export function shouldRunPendingMilestone(status) {
  return String(status || '').toLowerCase() === 'pending';
}

export function shouldRunPreparingUnassignedMilestone(order) {
  const status = String(order?.status || '').toLowerCase();
  const deliveryPersonId = String(order?.delivery_person_id || '').trim();
  const episodeAt = String(order?.courier_unassigned_episode_at || '').trim();
  return (status === 'preparing' || status === 'ready')
    && deliveryPersonId.length === 0
    && episodeAt.length > 0;
}

export function shouldRunPreparingAssignedMilestone(order) {
  const status = String(order?.status || '').toLowerCase();
  const deliveryPersonId = String(order?.delivery_person_id || '').trim();
  return deliveryPersonId.length > 0 && (status === 'preparing' || status === 'ready');
}

export function shouldRunPickupDelayMilestone(status) {
  return String(status || '').toLowerCase() === 'picked_up';
}
