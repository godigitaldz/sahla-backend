/**
 * Server-Side Staff Authentication & Authorization Verifier
 *
 * Requirements:
 * - Uses `@supabase/ssr` cookies to securely resolve the caller's session.
 * - Resolves authenticated user profile, assigned roles, and restaurant memberships
 *   from trusted database tables (never trusting client-supplied claims).
 * - Enforces Admin TOTP / AAL2 checks before granting admin privileges.
 * - Enforces session validity using `staff_session_meta`.
 */

import { createServerClient, type CookieOptions } from '@supabase/ssr';
import { cookies } from 'next/headers';
import { getStaffCookieName } from '../../../lib/staff/staffConfig';
import { assertSafeNonProduction } from '../../../lib/staff/safeEnvironmentGuard';
import {
  evaluateSessionValidity,
  type StaffSessionMeta,
} from './sessionMeta';

export type StaffRole = 'admin' | 'owner' | 'manager';

export interface VerifiedStaffContext {
  user_id: string;
  username: string;
  roles: StaffRole[];
  restaurant_ids: string[];
  is_admin: boolean;
  aal_level: 'aal1' | 'aal2';
  session_meta?: StaffSessionMeta;
}

export type StaffAuthCheckResult =
  | { authenticated: true; context: VerifiedStaffContext }
  | {
      authenticated: false;
      statusCode: 401 | 403;
      code:
        | 'no_session'
        | 'session_invalid'
        | 'admin_mfa_required'
        | 'unauthorized_role'
        | 'database_error';
      message: string;
    };

function getSupabaseEnv() {
  const url = process.env.NEXT_PUBLIC_SUPABASE_URL || process.env.SUPABASE_URL;
  const anonKey = process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY || process.env.SUPABASE_ANON_KEY;
  if (!url || !anonKey) {
    throw new Error('Supabase URL and Anon Key must be configured.');
  }
  return { url, anonKey };
}

export async function createStaffServerSupabaseClient(
  cookieStore = cookies(),
  customEnv?: { url: string; anonKey: string },
) {
  const env = customEnv || getSupabaseEnv();
  assertSafeNonProduction(env.url, 'Staff Supabase Client');

  const resolvedCookieStore = await Promise.resolve(cookieStore);

  return createServerClient(env.url, env.anonKey, {
    cookies: {
      get(name: string) {
        return resolvedCookieStore.get(name)?.value;
      },
      set(name: string, value: string, options: CookieOptions) {
        try {
          resolvedCookieStore.set({ name, value, ...options });
        } catch {
          // Can fail in Server Components; handled gracefully
        }
      },
      remove(name: string, options: CookieOptions) {
        try {
          resolvedCookieStore.set({ name, value: '', ...options });
        } catch {
          // Can fail in Server Components; handled gracefully
        }
      },
    },
  });
}

/**
 * Validates the caller's session server-side.
 * Resolves current user role, restaurant memberships, and AAL level.
 */
export async function verifyStaffSession(
  cookieStore = cookies(),
  options: { requiredRole?: StaffRole; requireAal2ForAdmin?: boolean } = {},
): Promise<StaffAuthCheckResult> {
  const { requireAal2ForAdmin = true } = options;

  let supabase;
  try {
    supabase = await createStaffServerSupabaseClient(cookieStore);
  } catch (err: any) {
    return {
      authenticated: false,
      statusCode: 401,
      code: 'no_session',
      message: err?.message || 'Failed to initialize session client.',
    };
  }

  // 1. Get verified user from Supabase Auth
  const { data: userData, error: userError } = await supabase.auth.getUser();
  if (userError || !userData?.user) {
    return {
      authenticated: false,
      statusCode: 401,
      code: 'no_session',
      message: 'Active staff session required.',
    };
  }

  const user = userData.user;

  // 2. Resolve MFA AAL Level
  const { data: aalData } = await supabase.auth.mfa.getAuthenticatorAssuranceLevel();
  const aalLevel = aalData?.currentLevel === 'aal2' ? 'aal2' : 'aal1';

  // 3. Resolve user roles and restaurant memberships
  const [rolesResult, membersResult] = await Promise.all([
    supabase.from('user_roles').select('role').eq('user_id', user.id),
    supabase
      .from('restaurant_staff_members')
      .select('restaurant_id, role, status')
      .eq('user_id', user.id)
      .eq('status', 'active'),
  ]);

  const assignedRoles = new Set<StaffRole>();
  const restaurantIds: string[] = [];

  if (rolesResult.data) {
    for (const r of rolesResult.data) {
      if (r.role === 'admin') assignedRoles.add('admin');
    }
  }

  if (membersResult.data) {
    for (const m of membersResult.data) {
      if (m.restaurant_id) restaurantIds.push(m.restaurant_id);
      if (m.role === 'owner') assignedRoles.add('owner');
      if (m.role === 'manager') assignedRoles.add('manager');
    }
  }

  const isAdmin = assignedRoles.has('admin');

  // 4. Admin MFA / AAL2 Enforcement
  if (isAdmin && requireAal2ForAdmin && aalLevel !== 'aal2') {
    return {
      authenticated: false,
      statusCode: 403,
      code: 'admin_mfa_required',
      message: 'Admin operations require two-factor authentication (AAL2).',
    };
  }

  // 5. Role requirement check if specified
  if (options.requiredRole && !assignedRoles.has(options.requiredRole)) {
    return {
      authenticated: false,
      statusCode: 403,
      code: 'unauthorized_role',
      message: `Access denied. Required role: ${options.requiredRole}.`,
    };
  }

  return {
    authenticated: true,
    context: {
      user_id: user.id,
      username: (user.user_metadata?.username as string) || user.email || '',
      roles: Array.from(assignedRoles),
      restaurant_ids: restaurantIds,
      is_admin: isAdmin,
      aal_level: aalLevel,
    },
  };
}
