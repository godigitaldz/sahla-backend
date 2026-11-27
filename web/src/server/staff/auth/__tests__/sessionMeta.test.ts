import { describe, expect, it } from 'vitest';
import {
  evaluateSensitiveActionAuth,
  evaluateSessionValidity,
  PERSONAL_ABSOLUTE_TIMEOUT_MS,
  PERSONAL_IDLE_TIMEOUT_MS,
  SENSITIVE_ACTION_REAUTH_WINDOW_MS,
  TABLET_ABSOLUTE_TIMEOUT_MS,
  TABLET_IDLE_TIMEOUT_MS,
  type StaffSessionMeta,
} from '../sessionMeta';

describe('Staff Session Metadata & Timeout Policy', () => {
  const baseNow = Date.now();

  it('rejects revoked sessions immediately', () => {
    const meta: StaffSessionMeta = {
      session_id: 's1',
      user_id: 'u1',
      device_type: 'personal',
      created_at: baseNow - 1000,
      last_active_at: baseNow - 500,
      is_revoked: true,
    };
    const res = evaluateSessionValidity(meta, baseNow);
    expect(res.valid).toBe(false);
    if (!res.valid) expect(res.reason).toBe('revoked');
  });

  describe('Personal Device (12h idle / 30d absolute)', () => {
    it('allows active personal session within bounds', () => {
      const meta: StaffSessionMeta = {
        session_id: 's1',
        user_id: 'u1',
        device_type: 'personal',
        created_at: baseNow - 24 * 60 * 60 * 1000, // 1 day old
        last_active_at: baseNow - 2 * 60 * 60 * 1000, // active 2h ago
      };
      expect(evaluateSessionValidity(meta, baseNow).valid).toBe(true);
    });

    it('rejects personal session when idle > 12h', () => {
      const meta: StaffSessionMeta = {
        session_id: 's1',
        user_id: 'u1',
        device_type: 'personal',
        created_at: baseNow - 24 * 60 * 60 * 1000,
        last_active_at: baseNow - (PERSONAL_IDLE_TIMEOUT_MS + 1000),
      };
      const res = evaluateSessionValidity(meta, baseNow);
      expect(res.valid).toBe(false);
      if (!res.valid) expect(res.reason).toBe('idle_timeout');
    });

    it('rejects personal session when absolute age > 30d', () => {
      const meta: StaffSessionMeta = {
        session_id: 's1',
        user_id: 'u1',
        device_type: 'personal',
        created_at: baseNow - (PERSONAL_ABSOLUTE_TIMEOUT_MS + 1000),
        last_active_at: baseNow - 1000,
      };
      const res = evaluateSessionValidity(meta, baseNow);
      expect(res.valid).toBe(false);
      if (!res.valid) expect(res.reason).toBe('absolute_timeout');
    });
  });

  describe('Shared Tablet (30m idle / 12h absolute)', () => {
    it('allows active tablet session within 30m idle', () => {
      const meta: StaffSessionMeta = {
        session_id: 's2',
        user_id: 'u2',
        device_type: 'shared_tablet',
        created_at: baseNow - 2 * 60 * 60 * 1000, // 2h old
        last_active_at: baseNow - 10 * 60 * 1000, // 10m idle
      };
      expect(evaluateSessionValidity(meta, baseNow).valid).toBe(true);
    });

    it('rejects tablet session when idle > 30m', () => {
      const meta: StaffSessionMeta = {
        session_id: 's2',
        user_id: 'u2',
        device_type: 'shared_tablet',
        created_at: baseNow - 2 * 60 * 60 * 1000,
        last_active_at: baseNow - (TABLET_IDLE_TIMEOUT_MS + 1000),
      };
      const res = evaluateSessionValidity(meta, baseNow);
      expect(res.valid).toBe(false);
      if (!res.valid) expect(res.reason).toBe('idle_timeout');
    });

    it('rejects tablet session when absolute age > 12h', () => {
      const meta: StaffSessionMeta = {
        session_id: 's2',
        user_id: 'u2',
        device_type: 'shared_tablet',
        created_at: baseNow - (TABLET_ABSOLUTE_TIMEOUT_MS + 1000),
        last_active_at: baseNow - 1000,
      };
      const res = evaluateSessionValidity(meta, baseNow);
      expect(res.valid).toBe(false);
      if (!res.valid) expect(res.reason).toBe('absolute_timeout');
    });
  });

  describe('Sensitive Action Step-Up Reauth', () => {
    it('permits sensitive actions on personal devices without recent step-up', () => {
      const meta: StaffSessionMeta = {
        session_id: 's1',
        user_id: 'u1',
        device_type: 'personal',
        created_at: baseNow - 1000,
        last_active_at: baseNow - 500,
      };
      expect(evaluateSensitiveActionAuth(meta, baseNow).allowed).toBe(true);
    });

    it('requires step-up on shared tablet if sensitive auth is expired or missing', () => {
      const metaNoAuth: StaffSessionMeta = {
        session_id: 's2',
        user_id: 'u2',
        device_type: 'shared_tablet',
        created_at: baseNow - 1000,
        last_active_at: baseNow - 500,
        last_sensitive_auth_at: null,
      };
      expect(evaluateSensitiveActionAuth(metaNoAuth, baseNow).allowed).toBe(false);

      const metaExpired: StaffSessionMeta = {
        session_id: 's2',
        user_id: 'u2',
        device_type: 'shared_tablet',
        created_at: baseNow - 1000,
        last_active_at: baseNow - 500,
        last_sensitive_auth_at: baseNow - (SENSITIVE_ACTION_REAUTH_WINDOW_MS + 1000),
      };
      expect(evaluateSensitiveActionAuth(metaExpired, baseNow).allowed).toBe(false);
    });

    it('permits sensitive action on shared tablet if reauthenticated within 5m', () => {
      const metaValid: StaffSessionMeta = {
        session_id: 's2',
        user_id: 'u2',
        device_type: 'shared_tablet',
        created_at: baseNow - 1000,
        last_active_at: baseNow - 500,
        last_sensitive_auth_at: baseNow - 2 * 60 * 1000, // 2m ago
      };
      expect(evaluateSensitiveActionAuth(metaValid, baseNow).allowed).toBe(true);
    });
  });
});
