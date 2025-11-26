/**
 * Payments Routes
 * Converted from lib/controllers/payments_controller.dart
 */

import express from 'express';
import {
  getPendingPayments,
  markAsCollected,
  getPendingCount,
  getPendingTotal,
} from '../controllers/paymentsController.js';

const router = express.Router();

// Get pending payments for a restaurant
router.get('/:restaurantId/pending', getPendingPayments);

// Get pending payments count
router.get('/:restaurantId/count', getPendingCount);

// Get pending payments total
router.get('/:restaurantId/total', getPendingTotal);

// Mark payment as collected
router.post('/:orderId/collect', markAsCollected);

export default router;
