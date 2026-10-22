import { supabase } from '../config/supabase.js';

/**
 * Requires Authorization: Bearer <supabase access token>.
 * Sets req.supabaseUser when token is valid.
 */
export async function requireSupabaseUser(req, res, next) {
  try {
    const authHeader = req.headers.authorization || '';
    const token = authHeader.startsWith('Bearer ')
      ? authHeader.slice(7).trim()
      : '';

    if (!token) {
      return res.status(401).json({
        success: false,
        error: 'missing_bearer_token',
      });
    }

    const {
      data: { user },
      error,
    } = await supabase.auth.getUser(token);

    if (error || !user) {
      return res.status(401).json({
        success: false,
        error: 'invalid_or_expired_token',
      });
    }

    req.supabaseUser = user;
    return next();
  } catch (e) {
    return res.status(401).json({
      success: false,
      error: 'auth_failed',
    });
  }
}
