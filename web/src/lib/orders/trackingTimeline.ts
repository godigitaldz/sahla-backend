export type TrackingStepId =
  | 'placed'
  | 'preparing'
  | 'on_the_way'
  | 'delivered'
  | 'accepted'
  | 'ready'
  | 'collected';

export type TrackingTimelineStep = {
  id: TrackingStepId;
  state: 'complete' | 'current' | 'upcoming' | 'skipped';
};

export type TrackingTimeline = {
  kind: 'delivery' | 'pickup_table';
  cancelled: boolean;
  terminal: boolean;
  current_step: TrackingStepId | 'cancelled' | null;
  steps: TrackingTimelineStep[];
};

const DELIVERY_STEPS: TrackingStepId[] = ['placed', 'preparing', 'on_the_way', 'delivered'];
const PICKUP_STEPS: TrackingStepId[] = ['placed', 'accepted', 'ready', 'collected'];

function normalizeStatus(status: string): string {
  return String(status ?? '')
    .trim()
    .toLowerCase();
}

function deliveryCurrentIndex(status: string): number {
  switch (status) {
    case 'pending':
    case 'confirmed':
      return 0;
    case 'preparing':
    case 'ready':
      return 1;
    case 'picked_up':
      return 2;
    case 'delivered':
    case 'collected':
      return 3;
    default:
      return 0;
  }
}

function pickupCurrentIndex(status: string): number {
  switch (status) {
    case 'pending':
      return 0;
    case 'confirmed':
    case 'preparing':
      return 1;
    case 'ready':
      return 2;
    case 'picked_up':
    case 'delivered':
    case 'collected':
      return 3;
    default:
      return 0;
  }
}

function buildSteps(
  stepIds: TrackingStepId[],
  currentIndex: number,
  cancelled: boolean,
): TrackingTimelineStep[] {
  return stepIds.map((id, index) => {
    if (cancelled) {
      return { id, state: index === 0 ? 'complete' : 'skipped' };
    }
    if (index < currentIndex) return { id, state: 'complete' };
    if (index === currentIndex) return { id, state: 'current' };
    return { id, state: 'upcoming' };
  });
}

export function isTerminalOrderStatus(status: string): boolean {
  const s = normalizeStatus(status);
  return s === 'delivered' || s === 'collected' || s === 'cancelled';
}

export function buildTrackingTimeline(
  statusRaw: string,
  fulfillmentTypeRaw: string,
): TrackingTimeline {
  const status = normalizeStatus(statusRaw);
  const fulfillment = normalizeStatus(fulfillmentTypeRaw);
  const cancelled = status === 'cancelled';
  const kind = fulfillment === 'delivery' ? 'delivery' : 'pickup_table';
  const stepIds = kind === 'delivery' ? DELIVERY_STEPS : PICKUP_STEPS;
  const currentIndex =
    kind === 'delivery' ? deliveryCurrentIndex(status) : pickupCurrentIndex(status);
  const steps = buildSteps(stepIds, currentIndex, cancelled);
  const terminal = cancelled || isTerminalOrderStatus(status);

  return {
    kind,
    cancelled,
    terminal,
    current_step: cancelled
      ? 'cancelled'
      : (stepIds[Math.min(currentIndex, stepIds.length - 1)] ?? null),
    steps,
  };
}
