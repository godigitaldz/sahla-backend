# Deploy to Vercel

## Quick Deploy

### Option 1: Using Vercel CLI (Recommended)

```bash
# Install Vercel CLI globally
npm install -g vercel

# Navigate to backend directory
cd backend

# Login to Vercel (first time only)
vercel login

# Deploy to preview
vercel

# Deploy to production
vercel --prod
```

### Option 2: Using GitHub Integration

1. Push your code to GitHub
2. Go to [vercel.com](https://vercel.com)
3. Click "Add New Project"
4. Import your GitHub repository
5. Configure:
   - **Root Directory**: `backend`
   - **Framework Preset**: Other
   - **Build Command**: (leave empty)
   - **Output Directory**: (leave empty)
6. Add environment variables (see below)
7. Click "Deploy"

### Option 3: Using Vercel Dashboard

1. Go to [vercel.com](https://vercel.com)
2. Click "Add New Project"
3. Upload your `backend` folder or connect Git
4. Configure settings
5. Deploy

## Environment Variables

Set these in Vercel Dashboard → Project Settings → Environment Variables:

### Required
```bash
SUPABASE_URL=your_supabase_url
SUPABASE_ANON_KEY=your_supabase_anon_key
SUPABASE_SERVICE_ROLE_KEY=your_service_role_key
NODE_ENV=production
```

### Optional
```bash
CORS_ALLOWED_ORIGINS=https://your-app.com,https://www.your-app.com
GOOGLE_MAPS_API_KEY=your_google_maps_api_key
PORT=3001
```

## After Deployment

Your API will be available at:
```
https://your-project.vercel.app/api/dashboard/:restaurantId
https://your-project.vercel.app/api/payments/:restaurantId/pending
https://your-project.vercel.app/api/menu
# ... etc
```

## Verify Deployment

```bash
# Health check
curl https://your-project.vercel.app/health

# Test dashboard endpoint
curl https://your-project.vercel.app/api/dashboard/{restaurantId}
```

## Troubleshooting

- **Function timeout**: Optimize queries, use pagination
- **Cold starts**: Use Vercel Pro plan or keep functions warm
- **CORS errors**: Check `CORS_ALLOWED_ORIGINS` environment variable
- **Environment variables**: Ensure they're set in Vercel Dashboard
