import { describe, expect, it } from 'vitest';
import { isWebOrderCancellable } from '@/server/orders/cancelWebOrderByToken';

describe('isWebOrderCancellable', () => {
  it('allows pending web orders', () => {
    expect(isWebOrderCancellable('pending', 'web')).toBe(true);
    expect(isWebOrderCancellable('Pending', 'WEB_TABLE')).toBe(true);
  });

  it('rejects non-pending statuses', () => {
    expect(isWebOrderCancellable('confirmed', 'web')).toBe(false);
    expect(isWebOrderCancellable('preparing', 'web')).toBe(false);
    expect(isWebOrderCancellable('cancelled', 'web')).toBe(false);
  });

  it('rejects non-web sources', () => {
    expect(isWebOrderCancellable('pending', 'app')).toBe(false);
    expect(isWebOrderCancellable('pending', null)).toBe(false);
  });
});
