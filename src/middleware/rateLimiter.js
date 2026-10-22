import rateLimit from 'express-rate-limit';
import { config } from '../config/app.js';

export const limiter = rateLimit({
  windowMs: config.rateLimit.windowMs,
  max: config.rateLimit.maxRequests,
  skip: (req) => {
    const url = req.originalUrl || req.url || '';
    // Exempt internal cron tasks and background pollers
    if (url.startsWith('/api/internal') || url.startsWith('/internal')) {
      return true;
    }
    // Exempt performance dashboard (internal admin operations and live monitoring)
    if (url.startsWith('/api/performance') || url.startsWith('/performance')) {
      return true;
    }
    return false;
  },
  message: {
    success: false,
    error: 'Too many requests, please try again later.',
  },
  standardHeaders: true,
  legacyHeaders: false,
});

export default limiter;

