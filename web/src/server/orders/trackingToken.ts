import { createHash, randomBytes } from 'crypto';

/** 256-bit opaque tracking token (base64url). Never store raw value. */
export function generateTrackingToken(): string {
  return randomBytes(32).toString('base64url');
}

export function hashTrackingToken(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

/** Short prefix for logs / rate-limit keys — never the full token. */
export function trackingTokenPrefix(token: string): string {
  return token.slice(0, 8);
}

const BASE64URL_RE = /^[A-Za-z0-9_-]+$/;

/** Reject obviously malformed tokens before hashing / DB lookup. */
export function isValidTrackingTokenFormat(token: string): boolean {
  if (typeof token !== 'string') return false;
  const trimmed = token.trim();
  // 32 bytes base64url ≈ 43 chars; allow a small range for padding variants
  if (trimmed.length < 40 || trimmed.length > 64) return false;
  return BASE64URL_RE.test(trimmed);
}

export const TRACKING_TOKEN_TTL_DAYS = 14;

export function trackingTokenExpiresAt(from: Date = new Date()): Date {
  return new Date(from.getTime() + TRACKING_TOKEN_TTL_DAYS * 24 * 60 * 60 * 1000);
}

export function getWebBaseUrl(): string {
  return (process.env.NEXT_PUBLIC_WEB_BASE_URL ?? 'https://sahla-delivery.com').replace(
    /\/+$/,
    '',
  );
}

export function buildTrackingUrl(slug: string, token: string): string {
  const safeSlug = encodeURIComponent(slug);
  // Token is base64url — safe in path; avoid double-encoding
  return `${getWebBaseUrl()}/restaurants/${safeSlug}/track/${token}`;
}

export function buildTrackingPath(slug: string, token: string): string {
  return `/restaurants/${encodeURIComponent(slug)}/track/${token}`;
}
