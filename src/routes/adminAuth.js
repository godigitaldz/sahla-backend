import { Router } from 'express';

const router = Router();

// This legacy shared-code login changed the matched Supabase user's password
// to ADMIN_FIXED_OTP before returning a reusable session. Keep the path closed
// even when old deployment secrets are still present; secret rotation is a
// separate operational hotfix.
router.all('/admin-fixed-otp', (_req, res) => {
  return res.status(410).json({
    success: false,
    error: 'admin_fixed_otp_disabled',
  });
});

export default router;
