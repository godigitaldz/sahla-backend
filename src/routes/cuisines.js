import express from 'express';
import {
    getCuisineById,
    getCuisines,
} from '../controllers/cuisineController.js';

const router = express.Router();

router.get('/', getCuisines);
router.get('/:id', getCuisineById);

export default router;
