import { describe, expect, it, beforeEach } from 'vitest';
import {
  allowPublicOrderRequest,
  resetPublicOrderRateLimitsForTests,
} from '@/server/rateLimit/publicOrderLimiter';

describe('allowPublicOrderRequest', () => {
  beforeEach(() => {
    resetPublicOrderRateLimitsForTests();
  });

  it('allows retries with the same client_request_id without extra quota', () => {
    const id = '11111111-1111-4111-8111-111111111111';
    expect(allowPublicOrderRequest('1.2.3.4', '0555123456', id)).toBe(true);
    expect(allowPublicOrderRequest('1.2.3.4', '0555123456', id)).toBe(true);
    expect(allowPublicOrderRequest('1.2.3.4', '0555123456', id)).toBe(true);
  });

  it('blocks after phone quota is exhausted for new request ids', () => {
    for (let i = 0; i < 8; i += 1) {
      const id = `00000000-0000-4000-8000-${String(i).padStart(12, '0')}`;
      expect(allowPublicOrderRequest('1.2.3.4', '0555123456', id)).toBe(true);
    }
    expect(
      allowPublicOrderRequest('1.2.3.4', '0555123456', '99999999-9999-4999-8999-999999999999'),
    ).toBe(false);
  });
});
