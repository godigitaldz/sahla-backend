import express from 'express';
import {
  getCategoryImage,
  getMenuItemImage,
  getRestaurantImage,
  getLTOImage,
} from '../controllers/imageController.js';

const router = express.Router();

// Category images
router.get('/category/:categoryName', getCategoryImage);

// Menu item images - use query parameter for long URLs
router.get('/menu-item', getMenuItemImage);

// Restaurant images (logo or cover)
router.get('/restaurant/:type/:restaurantId', getRestaurantImage);

// LTO card images (same as menu item images)
router.get('/lto', getLTOImage);

// Menu item list screen images (same as menu item images)
router.get('/menu-list', getMenuItemImage);

export default router;
