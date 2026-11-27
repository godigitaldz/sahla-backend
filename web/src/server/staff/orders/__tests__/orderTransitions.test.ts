import { describe, expect, it } from 'vitest';
import {
  validateOrderTransition,
  type OrderTransitionInput,
} from '../orderTransitions';
import type { VerifiedStaffContext } from '../../auth/staffAuthServer';

describe('Staff Order Transition Machine & Authorization', () => {
  const managerContext: VerifiedStaffContext = {
    user_id: 'm1',
    username: 'manager_1',
    roles: ['manager'],
    restaurant_ids: ['rest-a', 'rest-b'],
    is_admin: false,
    aal_level: 'aal1',
  };

  const adminContext: VerifiedStaffContext = {
    user_id: 'adm1',
    username: 'super_admin',
    roles: ['admin'],
    restaurant_ids: [],
    is_admin: true,
    aal_level: 'aal2',
  };

  describe('Tenant Boundary Isolation', () => {
    it('allows manager to act on orders belonging to their restaurant', () => {
      const input: OrderTransitionInput = {
        currentStatus: 'pending',
        targetStatus: 'preparing',
        orderRestaurantId: 'rest-a',
      };
      expect(validateOrderTransition(managerContext, input).allowed).toBe(true);
    });

    it('rejects manager attempts to act on orders for a different restaurant', () => {
      const input: OrderTransitionInput = {
        currentStatus: 'pending',
        targetStatus: 'preparing',
        orderRestaurantId: 'foreign-rest-z',
      };
      const res = validateOrderTransition(managerContext, input);
      expect(res.allowed).toBe(false);
      if (!res.allowed) expect(res.code).toBe('tenant_mismatch');
    });

    it('allows admin to manage orders across any restaurant tenant', () => {
      const input: OrderTransitionInput = {
        currentStatus: 'pending',
        targetStatus: 'preparing',
        orderRestaurantId: 'any-rest-id',
      };
      expect(validateOrderTransition(adminContext, input).allowed).toBe(true);
    });
  });

  describe('Status Transition Graph', () => {
    it('allows pending -> preparing', () => {
      expect(
        validateOrderTransition(managerContext, {
          currentStatus: 'pending',
          targetStatus: 'preparing',
          orderRestaurantId: 'rest-a',
        }).allowed,
      ).toBe(true);
    });

    it('allows preparing -> ready_for_pickup', () => {
      expect(
        validateOrderTransition(managerContext, {
          currentStatus: 'preparing',
          targetStatus: 'ready_for_pickup',
          orderRestaurantId: 'rest-a',
        }).allowed,
      ).toBe(true);
    });

    it('blocks manager from jumping pending -> delivered', () => {
      const res = validateOrderTransition(managerContext, {
        currentStatus: 'pending',
        targetStatus: 'delivered',
        orderRestaurantId: 'rest-a',
      });
      expect(res.allowed).toBe(false);
      if (!res.allowed) expect(res.code).toBe('invalid_transition');
    });

    it('blocks manager from delivering orders (reserved for couriers/system)', () => {
      const res = validateOrderTransition(managerContext, {
        currentStatus: 'ready_for_pickup',
        targetStatus: 'delivered',
        orderRestaurantId: 'rest-a',
      });
      expect(res.allowed).toBe(false);
      if (!res.allowed) expect(res.code).toBe('invalid_transition');
    });
  });

  describe('Cancellation Reason Enforcement', () => {
    it('requires a cancellation reason when cancelling an order', () => {
      const res = validateOrderTransition(managerContext, {
        currentStatus: 'pending',
        targetStatus: 'cancelled',
        orderRestaurantId: 'rest-a',
        cancelReason: '',
      });
      expect(res.allowed).toBe(false);
      if (!res.allowed) expect(res.code).toBe('cancel_reason_required');
    });

    it('allows cancellation when valid reason is supplied', () => {
      const res = validateOrderTransition(managerContext, {
        currentStatus: 'pending',
        targetStatus: 'cancelled',
        orderRestaurantId: 'rest-a',
        cancelReason: 'Kitchen out of main ingredients',
      });
      expect(res.allowed).toBe(true);
    });
  });
});
