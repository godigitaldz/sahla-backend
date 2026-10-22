import { describe, expect, it } from 'vitest';
import {
  evaluateTableOrderIdentity,
  evaluateWebOrderIdentity,
  withinRecoveryWindow,
  IDEMPOTENT_RECOVERY_WINDOW_MS,
  type OrderIdentityRow,
} from '../verifyReturnedWebOrder';

const baseRow: OrderIdentityRow = {
  id: '11111111-1111-1111-1111-111111111111',
  client_request_id: '22222222-2222-2222-2222-222222222222',
  restaurant_id: '33333333-3333-3333-3333-333333333333',
  source: 'web',
  guest_phone: '+213555000000',
  fulfillment_type: 'delivery',
  created_at: new Date().toISOString(),
};

describe('evaluateWebOrderIdentity', () => {
  const now = Date.now();

  it('accepts a matching recent order', () => {
    const result = evaluateWebOrderIdentity(
      baseRow,
      {
        orderId: baseRow.id,
        restaurantId: baseRow.restaurant_id,
        clientRequestId: String(baseRow.client_request_id),
        guestPhone: baseRow.guest_phone,
        fulfillmentType: 'delivery',
        requireRecentWindow: true,
      },
      now,
    );
    expect(result).toEqual({ ok: true });
  });

  it('rejects cross-restaurant reuse', () => {
    const result = evaluateWebOrderIdentity(
      baseRow,
      {
        orderId: baseRow.id,
        restaurantId: '99999999-9999-9999-9999-999999999999',
        clientRequestId: String(baseRow.client_request_id),
        guestPhone: baseRow.guest_phone,
        fulfillmentType: 'delivery',
        requireRecentWindow: true,
      },
      now,
    );
    expect(result).toEqual({ ok: false, reason: 'mismatch' });
  });

  it('rejects stale idempotent recovery outside window', () => {
    const stale: OrderIdentityRow = {
      ...baseRow,
      created_at: new Date(now - IDEMPOTENT_RECOVERY_WINDOW_MS - 60_000).toISOString(),
    };
    const result = evaluateWebOrderIdentity(
      stale,
      {
        orderId: stale.id,
        restaurantId: stale.restaurant_id,
        clientRequestId: String(stale.client_request_id),
        guestPhone: stale.guest_phone,
        fulfillmentType: 'delivery',
        requireRecentWindow: true,
      },
      now,
    );
    expect(result).toEqual({ ok: false, reason: 'stale' });
    expect(withinRecoveryWindow(stale.created_at, now)).toBe(false);
  });
});

describe('evaluateTableOrderIdentity', () => {
  const now = Date.now();
  const tableRow: OrderIdentityRow = {
    ...baseRow,
    source: 'web_table',
    fulfillment_type: 'table',
    table_session_id: 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
    table_id: 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb',
  };

  it('requires matching session or table id', () => {
    const ok = evaluateTableOrderIdentity(
      tableRow,
      {
        orderId: tableRow.id,
        restaurantId: tableRow.restaurant_id,
        clientRequestId: String(tableRow.client_request_id),
        guestPhone: tableRow.guest_phone,
        fulfillmentType: 'table',
        tableSessionId: tableRow.table_session_id,
        tableId: null,
        requireRecentWindow: true,
      },
      now,
    );
    expect(ok).toEqual({ ok: true });

    const bad = evaluateTableOrderIdentity(
      tableRow,
      {
        orderId: tableRow.id,
        restaurantId: tableRow.restaurant_id,
        clientRequestId: String(tableRow.client_request_id),
        guestPhone: tableRow.guest_phone,
        fulfillmentType: 'table',
        tableSessionId: 'cccccccc-cccc-cccc-cccc-cccccccccccc',
        tableId: 'dddddddd-dddd-dddd-dddd-dddddddddddd',
        requireRecentWindow: true,
      },
      now,
    );
    expect(bad).toEqual({ ok: false, reason: 'mismatch' });
  });
});
