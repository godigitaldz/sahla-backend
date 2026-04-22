import { Router } from 'express';
import { createClient } from '@supabase/supabase-js';

import { supabaseAdmin } from '../config/supabase.js';

const router = Router();

const ADMIN_ROLES = new Set(['admin', 'super_admin']);

function normalizePhone(raw) {
  const s = String(raw || '').trim();
  if (!s.startsWith('+')) return null;
  return s;
}

/**
 * Admin-only bypass for broken SMS/OTP hooks (e.g. hook returns 501).
 * Verifies fixed code + admin profile, syncs auth password to that code,
 * then returns a normal Supabase session (anon JWT exchange).
 *
 * Env:
 * - ADMIN_FIXED_OTP (default "05102002")
 * - SUPABASE_SERVICE_ROLE_KEY (required for this route)
 */
router.post('/admin-fixed-otp', async (req, res) => {
  try {
    if (!process.env.SUPABASE_SERVICE_ROLE_KEY) {
      return res.status(503).json({
        success: false,
        error: 'Admin bypass is not configured (missing SUPABASE_SERVICE_ROLE_KEY)',
      });
    }

    const fixedOtp = (process.env.ADMIN_FIXED_OTP || '05102002').trim();
    const phone = normalizePhone(req.body?.phone);
    const otp = String(req.body?.otp || '').trim();

    if (!phone) {
      return res.status(400).json({ success: false, error: 'Invalid phone (use E.164, e.g. +213...)' });
    }
    if (!otp || otp !== fixedOtp) {
      return res.status(401).json({ success: false, error: 'Invalid admin code' });
    }

    const { data: profile, error: profileError } = await supabaseAdmin
      .from('user_profiles')
      .select('id, phone, role')
      .eq('phone', phone)
      .maybeSingle();

    if (profileError || !profile?.id) {
      return res.status(403).json({ success: false, error: 'Account not found' });
    }

    const role = String(profile.role || '').toLowerCase();
    if (!ADMIN_ROLES.has(role)) {
      return res.status(403).json({ success: false, error: 'Not an admin account' });
    }

    const { data: userWrap, error: userError } = await supabaseAdmin.auth.admin.getUserById(
      profile.id,
    );
    if (userError || !userWrap?.user) {
      return res.status(400).json({ success: false, error: 'Auth user not found for profile' });
    }

    const authPhone = userWrap.user.phone || '';
    if (authPhone && authPhone !== phone) {
      return res.status(403).json({ success: false, error: 'Phone mismatch for this account' });
    }

    const { error: pwdError } = await supabaseAdmin.auth.admin.updateUserById(profile.id, {
      password: fixedOtp,
    });
    if (pwdError) {
      console.error('admin-fixed-otp: updateUserById failed', pwdError);
      return res.status(500).json({ success: false, error: 'Failed to prepare admin session' });
    }

    const url = process.env.SUPABASE_URL;
    const anon = process.env.SUPABASE_ANON_KEY;
    const userClient = createClient(url, anon, {
      auth: { persistSession: false, autoRefreshToken: false },
    });

    const { data: signInData, error: signInError } = await userClient.auth.signInWithPassword({
      phone,
      password: fixedOtp,
    });

    if (signInError || !signInData?.session) {
      console.error('admin-fixed-otp: signInWithPassword failed', signInError);
      return res.status(401).json({
        success: false,
        error: signInError?.message || 'Sign-in failed',
      });
    }

    return res.json({
      success: true,
      access_token: signInData.session.access_token,
      refresh_token: signInData.session.refresh_token,
      expires_in: signInData.session.expires_in,
      expires_at: signInData.session.expires_at,
      token_type: signInData.session.token_type,
      user: signInData.session.user,
    });
  } catch (e) {
    console.error('admin-fixed-otp: unexpected error', e);
    return res.status(500).json({ success: false, error: 'Unexpected server error' });
  }
});

export default router;
