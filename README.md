# Sahla Backend API

Professional Node.js backend for Sahla Food Delivery App.

## 🏗️ Architecture

```
backend/
├── src/
│   ├── config/          # Configuration files
│   │   ├── app.js       # App configuration
│   │   └── supabase.js  # Supabase client setup
│   ├── controllers/     # Request handlers
│   │   ├── restaurantController.js
│   │   ├── orderController.js
│   │   ├── promoCodeController.js
│   │   ├── menuController.js
│   │   └── cuisineController.js
│   ├── routes/          # API routes
│   │   ├── restaurants.js
│   │   ├── orders.js
│   │   ├── promoCodes.js
│   │   ├── menu.js
│   │   └── cuisines.js
│   ├── services/        # Business logic
│   │   ├── restaurantService.js
│   │   ├── orderService.js
│   │   ├── promoCodeService.js
│   │   ├── menuService.js
│   │   └── cuisineService.js
│   ├── middleware/      # Express middleware
│   │   ├── errorHandler.js
│   │   └── rateLimiter.js
│   ├── utils/           # Utility functions
│   │   └── response.js
│   └── index.js         # Main server file
├── package.json
└── README.md
```

## 🚀 Quick Start

### 1. Install Dependencies

```bash
cd backend
npm install
```

### 2. Environment Setup

Create `.env` file:

```bash
cp .env.example .env
```

Update with your credentials:

```env
PORT=3001
NODE_ENV=development
SUPABASE_URL=https://wtowqpejzxlsmgywkjvn.supabase.co
SUPABASE_ANON_KEY=your_key_here
```

### 3. Run Development Server

```bash
npm run dev
```

### 4. Run Production Server

```bash
npm start
```

## 📡 API Endpoints

### Restaurants

- `GET /api/restaurants` - Get all restaurants
- `GET /api/restaurants/search?q=pizza` - Search restaurants
- `GET /api/restaurants/:id` - Get restaurant by ID

### Orders

- `GET /api/orders` - Get user orders
- `POST /api/orders` - Create new order
- `GET /api/orders/:id` - Get order by ID
- `PATCH /api/orders/:id/status` - Update order status

### Promo Codes

- `GET /api/promo-codes` - Get promo codes
- `POST /api/promo-codes/validate` - Validate promo code

### Menu

- `GET /api/menu?restaurant_id=xxx` - Get menu items
- `GET /api/menu/:id` - Get menu item by ID

### Cuisines

- `GET /api/cuisines` - Get all cuisines
- `GET /api/cuisines/:id` - Get cuisine by ID

## 🌐 Deployment

### Railway

```bash
npm i -g @railway/cli
railway login
railway init
railway up
```

### Render

1. Go to render.com
2. New Web Service
3. Connect GitHub repo
4. Build Command: `npm install`
5. Start Command: `npm start`

### Vercel

```bash
npm i -g vercel
vercel
```

## 🔒 Security Features

- ✅ Helmet.js for security headers
- ✅ CORS protection
- ✅ Rate limiting
- ✅ Request size limits
- ✅ Environment variables

## 📦 Dependencies

- **express** - Web framework
- **@supabase/supabase-js** - Supabase client
- **cors** - CORS middleware
- **helmet** - Security headers
- **compression** - Response compression
- **express-rate-limit** - Rate limiting

## 🧪 Testing

```bash
# Test health endpoint
curl http://localhost:3001/health

# Test restaurants endpoint
curl http://localhost:3001/api/restaurants?limit=5
```

## 📝 License

MIT
