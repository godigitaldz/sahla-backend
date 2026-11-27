/**
 * Staff Session Metadata & Timeout Policy
 *
 * Implements per-device session lifecycle guarantees:
 * - Personal devices: 12h idle timeout, 30d absolute timeout.
 * - Shared tablets: 30m idle timeout, 12h absolute timeout, and mandatory step-up reauth for sensitive actions.
 */

export type StaffDeviceType = 'personal' | 'shared_tablet';

export interface StaffSessionMeta {
  session_id: string;
  user_id: string;
  device_type: StaffDeviceType;
  device_fingerprint?: string | null;
  created_at: string | number | Date;
  last_active_at: string | number | Date;
  last_sensitive_auth_at?: string | number | Date | null;
  is_revoked?: boolean;
}

export const PERSONAL_IDLE_TIMEOUT_MS = 12 * 60 * 60 * 1000; // 12 hours
export const PERSONAL_ABSOLUTE_TIMEOUT_MS = 30 * 24 * 60 * 60 * 1000; // 30 days

export const TABLET_IDLE_TIMEOUT_MS = 30 * 60 * 1000; // 30 minutes
export const TABLET_ABSOLUTE_TIMEOUT_MS = 12 * 60 * 60 * 1000; // 12 hours

export const SENSITIVE_ACTION_REAUTH_WINDOW_MS = 5 * 60 * 1000; // 5 minutes

export type SessionValidityResult =
  | { valid: true }
  | {
      valid: false;
      reason: 'revoked' | 'idle_timeout' | 'absolute_timeout' | 'invalid_dates';
      message: string;
    };

function toEpochMs(val: string | number | Date | null | undefined): number {
  if (!val) return NaN;
  if (typeof val === 'number') return val;
  if (val instanceof Date) return val.getTime();
  return Date.parse(val);
}

export function evaluateSessionValidity(
  meta: StaffSessionMeta,
  currentTimeMs: number = Date.now(),
): SessionValidityResult {
  if (meta.is_revoked) {
    return {
      valid: false,
      reason: 'revoked',
      message: 'Session has been revoked.',
    };
  }

  const createdAt = toEpochMs(meta.created_at);
  const lastActiveAt = toEpochMs(meta.last_active_at);

  if (!Number.isFinite(createdAt) || !Number.isFinite(lastActiveAt)) {
    return {
      valid: false,
      reason: 'invalid_dates',
      message: 'Session metadata contains invalid timestamp data.',
    };
  }

  const isTablet = meta.device_type === 'shared_tablet';
  const idleTimeoutMs = isTablet ? TABLET_IDLE_TIMEOUT_MS : PERSONAL_IDLE_TIMEOUT_MS;
  const absTimeoutMs = isTablet ? TABLET_ABSOLUTE_TIMEOUT_MS : PERSONAL_ABSOLUTE_TIMEOUT_MS;

  // 1. Check absolute timeout
  if (currentTimeMs - createdAt > absTimeoutMs) {
    return {
      valid: false,
      reason: 'absolute_timeout',
      message: `Session exceeded maximum lifespan (${isTablet ? '12 hours' : '30 days'}).`,
    };
  }

  // 2. Check idle timeout
  if (currentTimeMs - lastActiveAt > idleTimeoutMs) {
    return {
      valid: false,
      reason: 'idle_timeout',
      message: `Session timed out due to inactivity (${isTablet ? '30 minutes' : '12 hours'}).`,
    };
  }

  return { valid: true };
}

export type SensitiveActionResult =
  | { allowed: true }
  | {
      allowed: false;
      reason: 'step_up_required' | 'invalid_session';
      message: string;
    };

export function evaluateSensitiveActionAuth(
  meta: StaffSessionMeta,
  currentTimeMs: number = Date.now(),
): SensitiveActionResult {
  // Shared tablets always require recent step-up reauthentication for sensitive actions
  if (meta.device_type === 'shared_tablet') {
    const lastAuth = toEpochMs(meta.last_sensitive_auth_at);
    if (!Number.isFinite(lastAuth) || currentTimeMs - lastAuth > SENSITIVE_ACTION_REAUTH_WINDOW_MS) {
      return {
        allowed: false,
        reason: 'step_up_required',
        message: 'Shared tablet sessions require reauthentication before performing sensitive actions.',
      };
    }
  }

  return { allowed: true };
}
