/**
 * Staff PWA Configuration
 * Central configuration for origin, base path, and session cookie names.
 * All properties are configurable via environment variables with strict production defaults.
 */

export const DEFAULT_STAFF_TARGET_ORIGIN = 'https://sahla-backend.vercel.app';
export const DEFAULT_STAFF_BASE_PATH = '/staff';
export const DEFAULT_STAFF_COOKIE_NAME = '__Host-sahla-staff-session';

export function getStaffTargetOrigin(): string {
  const envVal =
    process.env.STAFF_TARGET_ORIGIN ||
    process.env.NEXT_PUBLIC_STAFF_TARGET_ORIGIN;
  return (envVal?.trim() || DEFAULT_STAFF_TARGET_ORIGIN).replace(/\/+$/, '');
}

export function getStaffBasePath(): string {
  const envVal =
    process.env.STAFF_BASE_PATH ||
    process.env.NEXT_PUBLIC_STAFF_BASE_PATH;
  const path = (envVal?.trim() || DEFAULT_STAFF_BASE_PATH);
  // Ensure path starts with / and has no trailing /
  return ('/' + path.replace(/^\/+|\/+$/g, ''));
}

export function getStaffCookieName(): string {
  const envVal =
    process.env.STAFF_COOKIE_NAME ||
    process.env.NEXT_PUBLIC_STAFF_COOKIE_NAME;
  return envVal?.trim() || DEFAULT_STAFF_COOKIE_NAME;
}

export function resolveStaffUrl(subPath: string = ''): string {
  const base = getStaffBasePath();
  const cleanSub = subPath.replace(/^\/+/, '');
  if (!cleanSub) return base;
  return `${base}/${cleanSub}`;
}
