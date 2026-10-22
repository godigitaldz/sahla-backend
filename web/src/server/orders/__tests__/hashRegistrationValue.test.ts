import { describe, expect, it } from 'vitest';
import { hashRegistrationValue } from '../hashRegistrationValue';

describe('hashRegistrationValue', () => {
  it('produces stable sha256 hex', () => {
    const a = hashRegistrationValue('abc123token');
    const b = hashRegistrationValue('abc123token');
    expect(a).toBe(b);
    expect(a).toMatch(/^[a-f0-9]{64}$/);
  });

  it('differs for different values', () => {
    expect(hashRegistrationValue('one')).not.toBe(hashRegistrationValue('two'));
  });
});
