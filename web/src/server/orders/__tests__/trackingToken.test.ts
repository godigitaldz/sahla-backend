import { describe, expect, it } from 'vitest';
import {
  buildTrackingPath,
  buildTrackingUrl,
  generateTrackingToken,
  hashTrackingToken,
  isValidTrackingTokenFormat,
  trackingTokenPrefix,
} from '../trackingToken';

describe('trackingToken', () => {
  it('generates high-entropy unique tokens', () => {
    const a = generateTrackingToken();
    const b = generateTrackingToken();
    expect(a).not.toEqual(b);
    expect(a.length).toBeGreaterThanOrEqual(40);
    expect(isValidTrackingTokenFormat(a)).toBe(true);
  });

  it('hashes deterministically and never equals raw token', () => {
    const token = generateTrackingToken();
    const h1 = hashTrackingToken(token);
    const h2 = hashTrackingToken(token);
    expect(h1).toBe(h2);
    expect(h1).toMatch(/^[a-f0-9]{64}$/);
    expect(h1).not.toBe(token);
  });

  it('exposes only a short prefix for logs', () => {
    const token = generateTrackingToken();
    expect(trackingTokenPrefix(token)).toBe(token.slice(0, 8));
    expect(trackingTokenPrefix(token).length).toBe(8);
  });

  it('rejects malformed tokens', () => {
    expect(isValidTrackingTokenFormat('')).toBe(false);
    expect(isValidTrackingTokenFormat('short')).toBe(false);
    expect(isValidTrackingTokenFormat('ORD-12345')).toBe(false);
    expect(isValidTrackingTokenFormat('W-000019')).toBe(false);
    expect(isValidTrackingTokenFormat('a'.repeat(43) + '!')).toBe(false);
  });

  it('builds tracking URLs without leaking order numbers', () => {
    const token = generateTrackingToken();
    const url = buildTrackingUrl('rb-melty', token);
    expect(url).toContain('/restaurants/rb-melty/track/');
    expect(url).toContain(token);
    expect(url).not.toContain('ORD-');
    expect(buildTrackingPath('rb-melty', token)).toBe(
      `/restaurants/rb-melty/track/${token}`,
    );
  });
});
