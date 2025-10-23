import compression from 'compression';
import cors from 'cors';
import express from 'express';
import helmet from 'helmet';
import { config } from './config/app.js';
import { errorHandler } from './middleware/errorHandler.js';
import { limiter } from './middleware/rateLimiter.js';

// Import routes
import cuisinesRouter from './routes/cuisines.js';
import menuRouter from './routes/menu.js';
import ordersRouter from './routes/orders.js';
import promoCodesRouter from './routes/promoCodes.js';
import restaurantsRouter from './routes/restaurants.js';

const app = express();

// Security & Performance Middleware
app.use(helmet());
app.use(compression());
app.use(cors({
  origin: config.cors.allowedOrigins,
  credentials: true,
}));

// Body parsing
app.use(express.json({ limit: '10mb' }));
app.use(express.urlencoded({ extended: true, limit: '10mb' }));

// Rate limiting
app.use('/api', limiter);

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

// 404 Handler
app.use((req, res) => {
  res.status(404).json({
    success: false,
    error: 'Route not found',
  });
});

// Error Handler (must be last)
app.use(errorHandler);

// Start server
app.listen(config.port, () => {
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
║                                               ║
╚═══════════════════════════════════════════════╝
  `);
});

export default app;
