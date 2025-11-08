# Quick Setup: New Repository for Backend

## Step 1: Create GitHub Repository

1. Go to https://github.com/new
2. Repository name: `sahla-backend`
3. Description: "Sahla Food Delivery Backend API"
4. **Important**: Do NOT initialize with README, .gitignore, or license
5. Click "Create repository"

## Step 2: Run Setup Script

```bash
cd /Users/macamine/Desktop/Sahla/backend
./setup-new-repo.sh
```

When prompted, enter your repository URL:
```
https://github.com/YOUR_USERNAME/sahla-backend.git
```

## Step 3: Connect to Vercel

1. Go to https://vercel.com/dashboard
2. Click "Add New Project"
3. Import repository: `sahla-backend`
4. **Root Directory**: Leave EMPTY (backend is at root)
5. Framework: "Other"
6. Build Command: Leave empty
7. Install Command: `npm install`
8. Output Directory: Leave empty

## Step 4: Add Environment Variables

Add all these variables in Vercel:

```
NODE_ENV=production
SUPABASE_URL=https://wtowqpejzxlsmgywkjvn.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind0b3dxcGVqenhsc21neXdranZuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTY3NzUzNzIsImV4cCI6MjA3MjM1MTM3Mn0.2hDTLo1QVJ82DlceZgvndItMvUz5-q3xqoiX0zOtOG0
SUPABASE_SERVICE_ROLE_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind0b3dxcGVqenhsc21neXdranZuIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1Njc3NTM3MiwiZXhwIjoyMDcyMzUxMzcyfQ.iavVdo9fqlw_1-2FUVleyYJ8LHPt4JJvTHpHf32i9eM
REDIS_URL=redis://default:UGTQj5z02z71pTpwBLCTWxzNweRPgbDG@redis-17665.c328.europe-west3-1.gce.redns.redis-cloud.com:17665
REDIS_HOST=redis-17665.c328.europe-west3-1.gce.redns.redis-cloud.com
REDIS_PORT=17665
SOCKET_IO_URL=redis://default:UGTQj5z02z71pTpwBLCTWxzNweRPgbDG@redis-17665.c328.europe-west3-1.gce.redns.redis-cloud.com:17665
FRONTEND_URL=https://www.sahla-delivery.com
ENABLE_PERFORMANCE_MONITORING=true
PERFORMANCE_LOG_LEVEL=info
CACHE_TTL_RESTAURANTS=900
CACHE_TTL_MENU=300
CACHE_TTL_SEARCH=300
RATE_LIMIT_WINDOW_MS=900000
RATE_LIMIT_MAX_REQUESTS=100
HELMET_ENABLED=true
CORS_ENABLED=true
RATE_LIMITING_ENABLED=true
LOG_LEVEL=info
LOG_FORMAT=json
NODE_OPTIONS=--max-old-space-size=1024
MEMORY_LIMIT_MB=1024
```

## Step 5: Deploy

Click "Deploy" and wait for deployment to complete.

## Step 6: Add Custom Domain

1. Go to Project Settings → Domains
2. Add `www.sahla-delivery.com`
3. Configure DNS as instructed by Vercel

## Step 7: Test

Visit:
- `https://www.sahla-delivery.com/health`
- `https://www.sahla-delivery.com/api/restaurants`

## Advantages

✅ No root directory confusion
✅ Simpler Vercel configuration
✅ Clean separation from Flutter app
✅ Independent versioning
✅ Faster deployments

---

**That's it! Your backend will be deployed in a few minutes.**
