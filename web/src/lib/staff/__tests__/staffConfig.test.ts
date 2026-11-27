import { describe, expect, it, beforeEach, afterEach } from 'vitest';
import {
  DEFAULT_STAFF_BASE_PATH,
  DEFAULT_STAFF_COOKIE_NAME,
  DEFAULT_STAFF_TARGET_ORIGIN,
  getStaffBasePath,
  getStaffCookieName,
  getStaffTargetOrigin,
  resolveStaffUrl,
} from '../staffConfig';

describe('Staff Config & Base Path Resolution', () => {
  const originalEnv = { ...process.env };

  beforeEach(() => {
    delete process.env.STAFF_TARGET_ORIGIN;
    delete process.env.NEXT_PUBLIC_STAFF_TARGET_ORIGIN;
    delete process.env.STAFF_BASE_PATH;
    delete process.env.NEXT_PUBLIC_STAFF_BASE_PATH;
    delete process.env.STAFF_COOKIE_NAME;
  });

  afterEach(() => {
    process.env = { ...originalEnv };
  });

  it('defaults to canonical production target origin and base path', () => {
    expect(getStaffTargetOrigin()).toBe(DEFAULT_STAFF_TARGET_ORIGIN);
    expect(getStaffBasePath()).toBe(DEFAULT_STAFF_BASE_PATH);
    expect(getStaffCookieName()).toBe(DEFAULT_STAFF_COOKIE_NAME);
  });

  it('respects custom environment configuration for origin and base path', () => {
    process.env.STAFF_TARGET_ORIGIN = 'https://preview-deployment.vercel.app/';
    process.env.STAFF_BASE_PATH = '/portal/';
    process.env.STAFF_COOKIE_NAME = '__Host-custom-session';

    expect(getStaffTargetOrigin()).toBe('https://preview-deployment.vercel.app');
    expect(getStaffBasePath()).toBe('/portal');
    expect(getStaffCookieName()).toBe('__Host-custom-session');
  });

  it('correctly normalizes sub-paths with resolveStaffUrl', () => {
    expect(resolveStaffUrl('')).toBe('/staff');
    expect(resolveStaffUrl('/orders')).toBe('/staff/orders');
    expect(resolveStaffUrl('orders/123')).toBe('/staff/orders/123');
  });
});
