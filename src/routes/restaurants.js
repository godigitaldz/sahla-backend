import express from 'express';
import {
    getRestaurantById,
    getRestaurants,
    searchRestaurants,
} from '../controllers/restaurantController.js';

const router = express.Router();

router.get('/', getRestaurants);
router.get('/search', searchRestaurants);
router.get('/:id', getRestaurantById);

export default router;
