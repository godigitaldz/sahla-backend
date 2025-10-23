import express from 'express';
import {
    getPromoCodes,
    validatePromoCode,
} from '../controllers/promoCodeController.js';

const router = express.Router();

router.get('/', getPromoCodes);
router.post('/validate', validatePromoCode);

export default router;
