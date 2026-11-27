import { describe, expect, it } from 'vitest';
import {
  buildStaffCsp,
  getStaffSecurityHeaders,
  isStaffPath,
} from '../staffHeaders';

describe('Staff Security Headers & Isolation', () => {
  it('identifies staff routes accurately against the configured base path', () => {
    expect(isStaffPath('/staff')).toBe(true);
    expect(isStaffPath('/staff/')).toBe(true);
    expect(isStaffPath('/staff/orders')).toBe(true);
    expect(isStaffPath('/staff/api/poll')).toBe(true);
    expect(isStaffPath('/restaurants')).toBe(false);
    expect(isStaffPath('/')).toBe(false);
    expect(isStaffPath('/admin')).toBe(false);
  });

  it('builds a strict CSP restricted to staff origins', () => {
    const csp = buildStaffCsp();
    expect(csp).toContain("default-src 'self'");
    expect(csp).toContain("frame-ancestors 'none'");
    expect(csp).toContain("base-uri 'self'");
    expect(csp).toContain('https://*.supabase.co');
  });

  it('includes HSTS and browser protection headers', () => {
    const headers = getStaffSecurityHeaders();
    expect(headers['Strict-Transport-Security']).toBe(
      'max-age=31536000; includeSubDomains; preload',
    );
    expect(headers['X-Content-Type-Options']).toBe('nosniff');
    expect(headers['X-Frame-Options']).toBe('DENY');
    expect(headers['Referrer-Policy']).toBe('strict-origin-when-cross-origin');
    expect(headers['Permissions-Policy']).toBe(
      'camera=(), microphone=(), geolocation=()',
    );
  });
});
