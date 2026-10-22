import { supabaseAdmin } from '../config/supabase.js';
import { successResponse } from '../utils/response.js';
import {
  extFromMime,
  isR2MediaFullyConfigured,
  publicObjectUrl,
  putPublicObject,
  restaurantImageKeyFromName,
  reuseObjectKeyFromPublicUrl,
} from '../services/r2MediaService.js';

function notConfigured(res) {
  return res.status(503).json({
    success: false,
    error: 'r2_not_configured',
    message:
      'Set R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, bucket names, and R2_PUBLIC_*_BASE.',
  });
}

export const uploadUserProfile = async (req, res, next) => {
  try {
    if (!isR2MediaFullyConfigured()) return notConfigured(res);

    const userId = req.supabaseUser.id;
    if (!req.file?.buffer?.length) {
      return res.status(400).json({ success: false, error: 'file_required' });
    }

    const ext = extFromMime(req.file.mimetype, req.file.originalname);
    const key = `${userId}${ext}`;
    const bucket = process.env.R2_BUCKET_USER_PROFILE;
    const publicBase = process.env.R2_PUBLIC_USER_PROFILE_BASE;

    await putPublicObject({
      bucket,
      key,
      body: req.file.buffer,
      contentType: req.file.mimetype || 'image/jpeg',
    });

    const url = publicObjectUrl(publicBase, key);
    const now = new Date().toISOString();
    const { error } = await supabaseAdmin
      .from('user_profiles')
      .update({
        profile_image: url,
        profile_image_url: url,
        profile_image_updated_at: now,
        updated_at: now,
      })
      .eq('id', userId);

    if (error) {
      console.error('user_profiles update failed:', error);
      return res.status(500).json({
        success: false,
        error: 'database_update_failed',
        details: error.message,
      });
    }

    return res.json(successResponse({ url }, 'User profile image uploaded'));
  } catch (e) {
    return next(e);
  }
};

export const uploadRestaurantLogo = async (req, res, next) => {
  try {
    if (!isR2MediaFullyConfigured()) return notConfigured(res);

    const restaurantId = (req.body?.restaurantId || req.body?.restaurant_id || '').trim();
    if (!restaurantId) {
      return res.status(400).json({ success: false, error: 'restaurantId_required' });
    }
    if (!req.file?.buffer?.length) {
      return res.status(400).json({ success: false, error: 'file_required' });
    }

    const { data: row, error: fetchErr } = await supabaseAdmin
      .from('restaurants')
      .select('id, name, owner_id, logo_url')
      .eq('id', restaurantId)
      .maybeSingle();

    if (fetchErr || !row) {
      return res.status(404).json({ success: false, error: 'restaurant_not_found' });
    }
    if (row.owner_id !== req.supabaseUser.id) {
      return res.status(403).json({ success: false, error: 'forbidden' });
    }

    const ext = extFromMime(req.file.mimetype, req.file.originalname);
    const publicBase = process.env.R2_PUBLIC_LOGO_BASE;
    const key =
      reuseObjectKeyFromPublicUrl(row.logo_url, publicBase) ||
      restaurantImageKeyFromName(row.name, ext);

    await putPublicObject({
      bucket: process.env.R2_BUCKET_LOGO,
      key,
      body: req.file.buffer,
      contentType: req.file.mimetype || 'image/jpeg',
    });

    const url = publicObjectUrl(publicBase, key);
    const now = new Date().toISOString();
    const { error: upErr } = await supabaseAdmin
      .from('restaurants')
      .update({ logo_url: url, updated_at: now })
      .eq('id', restaurantId);

    if (upErr) {
      return res.status(500).json({
        success: false,
        error: 'database_update_failed',
        details: upErr.message,
      });
    }

    return res.json(successResponse({ url }, 'Restaurant logo uploaded'));
  } catch (e) {
    return next(e);
  }
};

export const uploadRestaurantCover = async (req, res, next) => {
  try {
    if (!isR2MediaFullyConfigured()) return notConfigured(res);

    const restaurantId = (req.body?.restaurantId || req.body?.restaurant_id || '').trim();
    if (!restaurantId) {
      return res.status(400).json({ success: false, error: 'restaurantId_required' });
    }
    if (!req.file?.buffer?.length) {
      return res.status(400).json({ success: false, error: 'file_required' });
    }

    const { data: row, error: fetchErr } = await supabaseAdmin
      .from('restaurants')
      .select('id, name, owner_id, cover_image_url')
      .eq('id', restaurantId)
      .maybeSingle();

    if (fetchErr || !row) {
      return res.status(404).json({ success: false, error: 'restaurant_not_found' });
    }
    if (row.owner_id !== req.supabaseUser.id) {
      return res.status(403).json({ success: false, error: 'forbidden' });
    }

    const ext = extFromMime(req.file.mimetype, req.file.originalname);
    const publicBase = process.env.R2_PUBLIC_COVER_BASE;
    const key =
      reuseObjectKeyFromPublicUrl(row.cover_image_url, publicBase) ||
      restaurantImageKeyFromName(row.name, ext);

    await putPublicObject({
      bucket: process.env.R2_BUCKET_COVER,
      key,
      body: req.file.buffer,
      contentType: req.file.mimetype || 'image/jpeg',
    });

    const url = publicObjectUrl(publicBase, key);
    const now = new Date().toISOString();
    const { error: upErr } = await supabaseAdmin
      .from('restaurants')
      .update({ cover_image_url: url, updated_at: now })
      .eq('id', restaurantId);

    if (upErr) {
      return res.status(500).json({
        success: false,
        error: 'database_update_failed',
        details: upErr.message,
      });
    }

    return res.json(successResponse({ url }, 'Restaurant cover uploaded'));
  } catch (e) {
    return next(e);
  }
};

