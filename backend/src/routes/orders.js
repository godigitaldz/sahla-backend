import express from 'express';
import {
    createOrder,
    getOrderById,
    getOrders,
    updateOrderStatus,
} from '../controllers/orderController.js';

const router = express.Router();

router.get('/', getOrders);
router.post('/', createOrder);
router.get('/:id', getOrderById);
router.patch('/:id/status', updateOrderStatus);

export default router;
