import compression from 'compression';
import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import { existsSync, readFileSync } from 'fs';
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

// Apple App Site Association (AASA) for iOS Universal Links
app.get(['/.well-known/apple-app-site-association', '/apple-app-site-association'], (req, res) => {
  const filePath = resolve(__dirname, '../public/.well-known/apple-app-site-association');
  if (existsSync(filePath)) {
    res.setHeader('Content-Type', 'application/json');
    res.setHeader('Cache-Control', 'public, max-age=3600');
    return res.status(200).send(readFileSync(filePath, 'utf8'));
  }
  return res.status(404).json({ error: 'AASA not found' });
});

// Digital Asset Links for Android App Links
app.get(['/.well-known/assetlinks.json', '/assetlinks.json'], (req, res) => {
  const filePath = resolve(__dirname, '../public/.well-known/assetlinks.json');
  if (existsSync(filePath)) {
    res.setHeader('Content-Type', 'application/json');
    res.setHeader('Cache-Control', 'public, max-age=3600');
    return res.status(200).send(readFileSync(filePath, 'utf8'));
  }
  return res.status(404).json({ error: 'Assetlinks not found' });
});

app.use(express.static(join(__dirname, '../public'), { dotfiles: 'allow' }));

// Universal Link Fallback Page: /open & /open/*
app.get(['/open', '/open/', '/open/*', '/open.html'], (req, res) => {
  const filePath = resolve(__dirname, '../public/open.html');
  res.setHeader('Content-Type', 'text/html; charset=UTF-8');
  res.setHeader('Cache-Control', 'no-cache, must-revalidate');
  res.sendFile(filePath, (err) => {
    if (err) {
      console.error('Error serving /open fallback page:', err);
      if (!res.headersSent) res.status(500).send('<!DOCTYPE html><html><body>Failed to serve open page</body></html>');
    }
  });
});

// Dedicated /download route
app.get(['/download', '/download/', '/download/*', '/download.html'], (req, res) => {
  const filePath = resolve(__dirname, '../public/download.html');
  res.setHeader('Content-Type', 'text/html; charset=UTF-8');
  res.setHeader('Cache-Control', 'no-cache, must-revalidate');
  res.sendFile(filePath, (err) => {
    if (err) {
      console.error('Error serving download page:', err);
      if (!res.headersSent) res.status(500).send('<!DOCTYPE html><html><body>Failed to serve download page</body></html>');
    }
  });
});

// Send-Link to Phone/Email Stub Endpoint
app.post('/api/send-link', (req, res) => {
  const { recipient, to, target, phone, email, url } = req.body || {};
  const rawRecipient = recipient || to || target || phone || email;
  if (!rawRecipient || typeof rawRecipient !== 'string') {
    return res.status(400).json({ success: false, error: 'Recipient phone or email is required.' });
  }

  const cleanRecipient = rawRecipient.trim();
  const isEmail = /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(cleanRecipient);
  const isPhone = /^\+?[0-9\s\-()]{7,20}$/.test(cleanRecipient);

  if (!isEmail && !isPhone) {
    return res.status(400).json({ success: false, error: 'Please enter a valid phone number or email address.' });
  }

  console.log(`[Send-Link API Stub] Dispatching download link to ${isEmail ? 'email' : 'phone'}: ${cleanRecipient} (URL: ${url || 'default'})`);

  return res.status(200).json({
    success: true,
    message: isEmail ? 'Download link sent to your email!' : 'Download link sent to your phone via SMS!',
    type: isEmail ? 'email' : 'sms',
    recipient: cleanRecipient
  });
});

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

// Legal & Policy clean URLs & legacy redirects
app.get(['/privacy', '/privacy.html', '/privacy-policy.html'], (req, res) => {
  res.redirect(301, '/privacy-policy');
});

app.get(['/terms', '/terms.html', '/terms-of-service.html', '/terms-and-conditions'], (req, res) => {
  res.redirect(301, '/terms-of-service');
});

app.get(['/agreement', '/agreement.html', '/user-agreement.html'], (req, res) => {
  res.redirect(301, '/user-agreement');
});

app.get(['/delete-account.html', '/account-deletion', '/delete_account'], (req, res) => {
  res.redirect(301, '/delete-account');
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

// Admin and Dashboard entry points redirect directly to performance cockpit
app.get(['/admin', '/dashboard', '/app/admin', '/admin-dashboard', '/cockpit'], (req, res) => {
  res.redirect(302, '/performance');
});

app.get('/login', (req, res) => {
  res.redirect(302, '/performance');
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
  if (req.method === 'GET' && (req.path.startsWith('/open') || req.path === '/open')) {
    return res.sendFile(resolve(__dirname, '../public/open.html'));
  }
  if (req.method === 'GET' && (req.path.startsWith('/download') || req.path === '/download')) {
    return res.sendFile(resolve(__dirname, '../public/download.html'));
  }
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
