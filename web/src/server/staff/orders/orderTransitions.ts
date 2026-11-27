/**
 * Staff Order Transition Machine & Authorization Validator
 *
 * Enforces restaurant tenant boundaries and allowable status transitions
 * for restaurant owners, managers, and system administrators.
 */

import type { VerifiedStaffContext } from '../auth/staffAuthServer';

export type OrderStatus =
  | 'pending'
  | 'preparing'
  | 'ready_for_pickup'
  | 'delivering'
  | 'delivered'
  | 'cancelled';

export interface OrderTransitionInput {
  currentStatus: OrderStatus;
  targetStatus: OrderStatus;
  orderRestaurantId: string;
  cancelReason?: string;
}

export type OrderTransitionResult =
  | { allowed: true }
  | {
      allowed: false;
      code:
        | 'tenant_mismatch'
        | 'invalid_transition'
        | 'cancel_reason_required'
        | 'unauthorized_action';
      message: string;
    };

// Permitted status transitions for Restaurant Owner / Manager
const STAFF_ALLOWED_TRANSITIONS: Record<OrderStatus, OrderStatus[]> = {
  pending: ['preparing', 'cancelled'],
  preparing: ['ready_for_pickup', 'cancelled'],
  ready_for_pickup: ['cancelled'], // Emergency cancel before driver pickup
  delivering: [], // Managed by driver/system
  delivered: [], // Terminal state
  cancelled: [], // Terminal state
};

// Permitted status transitions for Platform Administrators
const ADMIN_ALLOWED_TRANSITIONS: Record<OrderStatus, OrderStatus[]> = {
  pending: ['preparing', 'cancelled'],
  preparing: ['ready_for_pickup', 'cancelled'],
  ready_for_pickup: ['delivering', 'cancelled'],
  delivering: ['delivered', 'cancelled'],
  delivered: [],
  cancelled: [],
};

export function validateOrderTransition(
  context: VerifiedStaffContext,
  input: OrderTransitionInput,
): OrderTransitionResult {
  const { currentStatus, targetStatus, orderRestaurantId, cancelReason } = input;

  // 1. Tenant boundary validation (Bypass for admins)
  if (!context.is_admin) {
    const isMember = context.restaurant_ids.includes(orderRestaurantId);
    if (!isMember) {
      return {
        allowed: false,
        code: 'tenant_mismatch',
        message: 'You do not have permission to manage orders for this restaurant.',
      };
    }
  }

  // 2. Cancellation requires an explicit reason
  if (targetStatus === 'cancelled') {
    const cleanReason = String(cancelReason || '').trim();
    if (!cleanReason || cleanReason.length < 3) {
      return {
        allowed: false,
        code: 'cancel_reason_required',
        message: 'A cancellation reason of at least 3 characters is mandatory.',
      };
    }
  }

  // 3. Status transition graph check
  const allowedNext = context.is_admin
    ? ADMIN_ALLOWED_TRANSITIONS[currentStatus]
    : STAFF_ALLOWED_TRANSITIONS[currentStatus];

  if (!allowedNext || !allowedNext.includes(targetStatus)) {
    return {
      allowed: false,
      code: 'invalid_transition',
      message: `Status transition from "${currentStatus}" to "${targetStatus}" is not permitted for your role.`,
    };
  }

  return { allowed: true };
}
