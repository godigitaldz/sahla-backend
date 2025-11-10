import express from 'express';
import {
  loadImagesBatch,
  loadImageById,
  loadDrinkImagesByRestaurant,
  loadRestaurantMenuImages,
  getImageStats,
  clearImageCache,
} from '../controllers/imageController.js';

const router = express.Router();

// Batch load images
router.post('/batch', loadImagesBatch);

// Load single image by ID
router.get('/:id', loadImageById);

// Load drink images for restaurant
router.get('/drinks/:restaurantId', loadDrinkImagesByRestaurant);

// Load all menu images for restaurant
router.get('/restaurant/:restaurantId', loadRestaurantMenuImages);

// Cache management
router.get('/stats', getImageStats);
router.delete('/cache', clearImageCache);

export default router;
