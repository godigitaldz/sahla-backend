import compression from 'compression';
import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import { dirname, join, resolve } from 'path';
import { fileURLToPath } from 'url';
import { config } from './config/app.js';
import { errorHandler } from './middleware/errorHandler.js';
import { limiter } from './middleware/rateLimiter.js';

import cuisinesRouter from './routes/cuisines.js';
import imagesRouter from './routes/images.js';
import menuRouter from './routes/menu.js';
import ordersRouter from './routes/orders.js';
import promoCodesRouter from './routes/promoCodes.js';
import restaurantsRouter from './routes/restaurants.js';
import performanceDashboardRouter from './routes/performanceDashboard.js';
import publicConfigRouter from './routes/publicConfig.js';
import lifecycleWebhookRoutes from './internal/lifecycleWebhook.routes.js';
import {
  runPendingOrdersPollOnce,
  startPendingOrdersPoller,
} from './services/pendingOrdersPoller.js';
import { runPickupDelayAdminAlertsOnce } from './services/pickupDelayAdminAlertsPoller.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const app = express();

// Vercel sets X-Forwarded-*; without this, express-rate-limit throws ERR_ERL_UNEXPECTED_X_FORWARDED_FOR.
app.set('trust proxy', 1);

app.use(helmet({
  contentSecurityPolicy: false,
}));
app.use(compression());
app.use(cors({
  origin: config.cors.allowedOrigins,
  credentials: true,
}));

app.use(express.json({
  limit: '10mb',
  verify: (req, res, buf) => {
    req.rawBody = buf;
  },
}));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

app.use('/api', limiter);

app.use(express.static(join(__dirname, '../public')));

app.get('/', (req, res) => {
  res.sendFile(join(__dirname, '../public/index.html'));
});

app.get('/privacy-policy', (req, res) => {
  const filePath = resolve(__dirname, '../public/privacy-policy.html');
  res.sendFile(filePath, (err) => {
    if (err) {
      console.error('Error serving privacy policy:', err);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Failed to serve privacy policy' });
      }
    }
  });
});

app.get('/user-agreement', (req, res) => {
  const filePath = resolve(__dirname, '../public/user-agreement.html');
  res.sendFile(filePath, (err) => {
    if (err) {
      console.error('Error serving user agreement:', err);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Failed to serve user agreement' });
      }
    }
  });
});

app.get('/terms-of-service', (req, res) => {
  const filePath = resolve(__dirname, '../public/terms-of-service.html');
  res.sendFile(filePath, (err) => {
    if (err) {
      console.error('Error serving terms of service:', err);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Failed to serve terms of service' });
      }
    }
  });
});

app.get('/delete-account', (req, res) => {
  const filePath = resolve(__dirname, '../public/delete-account.html');
  res.sendFile(filePath, (err) => {
    if (err) {
      console.error('Error serving delete-account page:', err);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Failed to serve account deletion page' });
      }
    }
  });
});

app.get('/performance', (req, res) => {
  res.sendFile(join(__dirname, '../public/performance.html'));
});
app.get('/admin-requests', (req, res) => {
  res.redirect(302, '/performance?view=delivery-requests');
});
app.get('/performace', (req, res) => {
  res.redirect(301, '/performance');
});

app.get(['/login', '/admin', '/app/admin'], (req, res) => {
  res.redirect(302, '/');
});

app.get('/health', (req, res) => {
  res.json({
    success: true,
    message: 'Sahla Backend API is running',
    timestamp: new Date().toISOString(),
    env: config.nodeEnv,
  });
});

app.use('/api/performance', performanceDashboardRouter);
app.use('/api/public', publicConfigRouter);

app.use('/api/restaurants', restaurantsRouter);
app.use('/api/orders', ordersRouter);
app.use('/api/promo-codes', promoCodesRouter);
app.use('/api/menu', menuRouter);
app.use('/api/cuisines', cuisinesRouter);
app.use('/api/images', imagesRouter);

/**
 * Internal routes:
 * - Lifecycle QStash webhooks (POST /api/internal/events/order-lifecycle)
 * - Scheduled cron ticks (GET/POST /api/internal/pending-orders-poll)
 * - Order lifecycle reconcile & triggers (POST /api/internal/orders/lifecycle-sync)
 */
app.use('/api/internal', lifecycleWebhookRoutes);

app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: 'Route not found',
  });
});

app.use(errorHandler);

const pendingOrdersPoller = startPendingOrdersPoller({ logger: console });

if (process.env.VERCEL !== '1') {
  app.listen(config.port, () => {
    console.log(`
╔═══════════════════════════════════════════════╗
║   🍔 Sahla Backend API                        ║
║   Environment: ${config.nodeEnv.padEnd(27)}    ║
║   Port: ${config.port.toString().padEnd(37)}    ║
║   URL: http://localhost:${config.port.toString().padEnd(23)}    ║
╚═══════════════════════════════════════════════╝
    `);
  });
}

const shutdown = () => {
  try {
    pendingOrdersPoller.stop();
  } catch (_) {}
};

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);

export default app;
