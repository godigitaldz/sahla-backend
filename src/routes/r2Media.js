import express from 'express';
import multer from 'multer';
import { requireSupabaseUser } from '../middleware/supabaseAuth.js';
import {
  uploadRestaurantCover,
  uploadRestaurantLogo,
  uploadUserProfile,
} from '../controllers/r2MediaController.js';

const router = express.Router();

const uploadProfile = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 6 * 1024 * 1024 },
});

const uploadLogo = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 4 * 1024 * 1024 },
});

const uploadCover = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 9 * 1024 * 1024 },
});

router.post('/user-profile', requireSupabaseUser, uploadProfile.single('file'), uploadUserProfile);
router.post('/restaurant-logo', requireSupabaseUser, uploadLogo.single('file'), uploadRestaurantLogo);
router.post('/restaurant-cover', requireSupabaseUser, uploadCover.single('file'), uploadRestaurantCover);

export default router;

