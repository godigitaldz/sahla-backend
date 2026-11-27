/**
 * Staff Security Headers
 *
 * Implements strict browser security controls isolated to staff routes:
 * - Content-Security-Policy (CSP): Restricts scripts, frames, styles, connects to staff origins.
 * - Strict-Transport-Security (HSTS): 1 year with includeSubDomains and preload.
 *   (Note: HSTS is host-wide; emitting it on /staff/* applies to the entire host origin).
 * - X-Content-Type-Options: nosniff
 * - Referrer-Policy: strict-origin-when-cross-origin
 * - Permissions-Policy: camera=(), microphone=(), geolocation=()
 *
 * Public routes remain untouched.
 */

import { getStaffBasePath } from '../../../lib/staff/staffConfig';

export function isStaffPath(pathname: string): boolean {
  const base = getStaffBasePath();
  return pathname === base || pathname.startsWith(`${base}/`);
}

export function buildStaffCsp(nonce?: string): string {
  const scriptSrc = nonce ? `'self' 'nonce-${nonce}'` : `'self' 'unsafe-inline'`;
  const styleSrc = `'self' 'unsafe-inline'`;

  return [
    `default-src 'self'`,
    `script-src ${scriptSrc}`,
    `style-src ${styleSrc}`,
    `img-src 'self' data: blob: https://*.supabase.co https://*.r2.dev https://pub-011aba279eb84591b0d96b9b9415ce2e.r2.dev https://pub-e75807f307834b89a8e0a2463ebb914f.r2.dev https://images.unsplash.com`,
    `connect-src 'self' https://*.supabase.co wss://*.supabase.co https://sahla-backend.vercel.app`,
    `font-src 'self' data:`,
    `manifest-src 'self'`,
    `frame-ancestors 'none'`,
    `base-uri 'self'`,
    `form-action 'self'`,
  ].join('; ');
}

export function getStaffSecurityHeaders(nonce?: string): Record<string, string> {
  return {
    'Content-Security-Policy': buildStaffCsp(nonce),
    'Strict-Transport-Security': 'max-age=31536000; includeSubDomains; preload',
    'X-Content-Type-Options': 'nosniff',
    'X-Frame-Options': 'DENY',
    'Referrer-Policy': 'strict-origin-when-cross-origin',
    'Permissions-Policy': 'camera=(), microphone=(), geolocation=()',
  };
}
