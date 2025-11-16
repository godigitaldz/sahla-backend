import compression from 'compression';
import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import { createServer } from 'http';
import { dirname, join, resolve } from 'path';
import { fileURLToPath } from 'url';
import { config } from './config/app.js';
import { errorHandler } from './middleware/errorHandler.js';
import { limiter } from './middleware/rateLimiter.js';
import { createBroadcastFunctions, initializeSocketIO } from './socket/socketServer.js';

// Import routes
import cuisinesRouter from './routes/cuisines.js';
import imagesRouter from './routes/images.js';
import menuRouter from './routes/menu.js';
import ordersRouter from './routes/orders.js';
import promoCodesRouter from './routes/promoCodes.js';
import restaurantsRouter from './routes/restaurants.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

const app = express();
const server = createServer(app);

// Security & Performance Middleware
app.use(helmet({
  contentSecurityPolicy: false, // Disable CSP for static HTML files
}));
app.use(compression());
app.use(cors({
  origin: config.cors.allowedOrigins,
  credentials: true,
}));

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Rate limiting (excluding static files)
app.use('/api', limiter);

// Serve static files from public directory
app.use(express.static(join(__dirname, '../public')));

// Landing page route
app.get('/', (req, res) => {
  res.sendFile(join(__dirname, '../public/index.html'));
});

// Privacy Policy route
app.get('/privacy-policy', (req, res) => {
  const filePath = resolve(__dirname, '../public/privacy-policy.html');
  res.sendFile(filePath, (err) => {
    if (err) {
      console.error('Error serving privacy policy:', err);
      console.error('Attempted path:', filePath);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Failed to serve privacy policy' });
      }
    }
  });
});

// User Agreement route
app.get('/user-agreement', (req, res) => {
  const filePath = resolve(__dirname, '../public/user-agreement.html');
  res.sendFile(filePath, (err) => {
    if (err) {
      console.error('Error serving user agreement:', err);
      console.error('Attempted path:', filePath);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Failed to serve user agreement' });
      }
    }
  });
});

// Terms of Service route
app.get('/terms-of-service', (req, res) => {
  const filePath = resolve(__dirname, '../public/terms-of-service.html');
  res.sendFile(filePath, (err) => {
    if (err) {
      console.error('Error serving terms of service:', err);
      console.error('Attempted path:', filePath);
      if (!res.headersSent) {
        res.status(500).json({ error: 'Failed to serve terms of service' });
      }
    }
  });
});

// Health check
app.get('/health', (req, res) => {
  res.json({
    success: true,
    message: 'Sahla Backend API is running',
    timestamp: new Date().toISOString(),
    env: config.nodeEnv,
  });
});

// API Routes
app.use('/api/restaurants', restaurantsRouter);
app.use('/api/orders', ordersRouter);
app.use('/api/promo-codes', promoCodesRouter);
app.use('/api/menu', menuRouter);
app.use('/api/cuisines', cuisinesRouter);
app.use('/api/images', imagesRouter);

// 404 Handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: 'Route not found',
  });
});

// Error Handler (must be last)
app.use(errorHandler);

// Initialize Socket.IO
let io = null;
let broadcastFunctions = null;

if (process.env.VERCEL !== '1') {
  // Initialize Socket.IO for local development
  io = initializeSocketIO(server);
  broadcastFunctions = createBroadcastFunctions(io);

  // Make broadcast functions available globally for use in other modules
  global.socketBroadcast = broadcastFunctions;
}

// Start server (only if not on Vercel)
// Vercel will use the exported handler instead
if (process.env.VERCEL !== '1') {
  server.listen(config.port, () => {
    console.log(`
╔═══════════════════════════════════════════════╗
║                                               ║
║   🍔 Sahla Backend API                        ║
║                                               ║
║   Environment: ${config.nodeEnv.padEnd(27)}    ║
║   Port: ${config.port.toString().padEnd(37)}    ║
║   URL: http://localhost:${config.port.toString().padEnd(23)}    ║
║                                               ║
║   ✅ Server is running successfully          ║
║   🔌 Socket.IO initialized                   ║
║                                               ║
╚═══════════════════════════════════════════════╝
    `);
  });
}

// Export for Vercel serverless function
// Note: Socket.IO requires a persistent connection, so it may not work
// perfectly with Vercel's serverless functions. Consider using a separate
// Socket.IO server or Vercel's Edge Functions for better compatibility.
export default app;
export { broadcastFunctions, io, server };
