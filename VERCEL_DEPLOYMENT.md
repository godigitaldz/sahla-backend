# Vercel Deployment Guide for Sahla Backend

This guide will walk you through deploying the Sahla backend to Vercel at `www.sahla-delivery.com`.

## Prerequisites

1. A Vercel account (sign up at https://vercel.com if needed)
2. Vercel CLI installed (optional, for CLI deployment)
3. Git repository set up (recommended)

## Step 1: Install Vercel CLI (Optional but Recommended)

```bash
npm install -g vercel
```

## Step 2: Prepare Your Project

The project is already configured for Vercel with:

- ✅ `vercel.json` configuration file
- ✅ Updated `src/index.js` for serverless functions
- ✅ All necessary dependencies in `package.json`

## Step 3: Deploy via Vercel Dashboard

### Option A: Deploy via GitHub/GitLab/Bitbucket (Recommended)

1. **Push your code to a Git repository**

   ```bash
   git add .
   git commit -m "Prepare for Vercel deployment"
   git push origin main
   ```

2. **Connect to Vercel**

   - Go to https://vercel.com/dashboard
   - Click "Add New Project"
   - Import your Git repository
   - Select the repository containing your backend

3. **Configure Project Settings**

   - **Root Directory**: Set to `backend` (since your backend is in the backend folder)
   - **Framework Preset**: Select "Other" or "Node.js"
   - **Build Command**: Leave empty or set to `npm install`
   - **Output Directory**: Leave empty
   - **Install Command**: `npm install`
   - **Node.js Version**: Select 18.x or higher

4. **Set Environment Variables**
   Click "Environment Variables" and add all the following variables:

   ```
   NODE_ENV=production
   PORT=3001

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

   **Important Notes:**

   - Make sure to set `FRONTEND_URL` to your actual frontend URL
   - For production, you may want to update `CORS_ENABLED` origin settings
   - Set these for **Production**, **Preview**, and **Development** environments

5. **Deploy**
   - Click "Deploy"
   - Wait for the deployment to complete

### Option B: Deploy via Vercel CLI

1. **Navigate to the backend directory**

   ```bash
   cd backend
   ```

2. **Login to Vercel**

   ```bash
   vercel login
   ```

3. **Deploy**

   ```bash
   vercel
   ```

   - Follow the prompts:
     - Set up and deploy? **Yes**
     - Which scope? (Select your account)
     - Link to existing project? **No** (first time) or **Yes** (subsequent deployments)
     - Project name: `sahla-backend` (or your preferred name)
     - Directory: `.` (current directory)
     - Override settings? **No**

4. **Set Environment Variables via CLI**

   ```bash
   vercel env add NODE_ENV production
   vercel env add SUPABASE_URL production
   vercel env add SUPABASE_ANON_KEY production
   # ... add all other environment variables
   ```

   Or use the dashboard method (easier for multiple variables).

5. **Deploy to Production**
   ```bash
   vercel --prod
   ```

## Step 4: Configure Custom Domain

1. **Add Domain in Vercel Dashboard**

   - Go to your project settings
   - Click on "Domains"
   - Add `www.sahla-delivery.com`
   - Add `sahla-delivery.com` (without www) if needed

2. **Configure DNS Records**

   - Go to your domain registrar (where you bought the domain)
   - Add a CNAME record:
     - **Name**: `www`
     - **Value**: `cname.vercel-dns.com` (or the value Vercel provides)
   - For the root domain (`sahla-delivery.com`), Vercel will provide specific instructions

3. **Wait for DNS Propagation**
   - DNS changes can take up to 48 hours (usually much faster)
   - Vercel will automatically provision SSL certificates

## Step 5: Update CORS Configuration

After deployment, you may need to update the CORS settings in your backend if your frontend is on a different domain:

1. Go to Vercel Dashboard → Your Project → Settings → Environment Variables
2. Add or update `ALLOWED_ORIGINS`:
   ```
   ALLOWED_ORIGINS=https://www.sahla-delivery.com,https://sahla-delivery.com
   ```
3. Redeploy the project

## Step 6: Verify Deployment

1. **Check Health Endpoint**

   ```
   https://www.sahla-delivery.com/health
   ```

   Should return:

   ```json
   {
     "success": true,
     "message": "Sahla Backend API is running",
     "timestamp": "...",
     "env": "production"
   }
   ```

2. **Test API Endpoints**

   ```
   https://www.sahla-delivery.com/api/restaurants
   ```

3. **Check Landing Page**
   ```
   https://www.sahla-delivery.com/
   ```

## Step 7: Configure Production Settings

### Update CORS for Production

In your `backend/src/config/app.js`, you might want to update CORS settings:

```javascript
cors: {
  allowedOrigins: process.env.ALLOWED_ORIGINS?.split(',') || [
    'https://www.sahla-delivery.com',
    'https://sahla-delivery.com'
  ],
},
```

### Update Frontend URL

Make sure your `FRONTEND_URL` environment variable in Vercel points to your actual frontend URL.

## Troubleshooting

### Issue: Environment Variables Not Working

- **Solution**: Make sure all environment variables are set in Vercel Dashboard
- Redeploy after adding environment variables

### Issue: CORS Errors

- **Solution**: Update `ALLOWED_ORIGINS` environment variable in Vercel
- Make sure your frontend URL is included in the allowed origins

### Issue: Static Files Not Loading

- **Solution**: Verify that the `public` folder is in the correct location
- Check that routes are configured correctly in `vercel.json`

### Issue: Redis Connection Issues

- **Solution**: Verify Redis URL is correct and accessible from Vercel's servers
- Check if Redis Cloud allows connections from Vercel's IP ranges
- Consider using Vercel's serverless Redis or updating firewall rules

### Issue: Build Fails

- **Solution**: Check build logs in Vercel Dashboard
- Verify Node.js version (should be 18.x or higher)
- Ensure all dependencies are in `package.json`

## Monitoring and Logs

1. **View Logs in Vercel Dashboard**

   - Go to your project → "Deployments" → Click on a deployment → "Functions" → Click on a function → "Logs"

2. **Set Up Monitoring**
   - Vercel provides built-in analytics
   - Consider adding external monitoring services if needed

## Continuous Deployment

Once connected to Git:

- Every push to `main` branch → Auto-deploys to production
- Every push to other branches → Creates a preview deployment
- Pull requests → Creates preview deployments automatically

## Additional Resources

- [Vercel Documentation](https://vercel.com/docs)
- [Vercel Node.js Runtime](https://vercel.com/docs/concepts/functions/serverless-functions/runtimes/node-js)
- [Environment Variables in Vercel](https://vercel.com/docs/concepts/projects/environment-variables)

## Support

If you encounter any issues:

1. Check Vercel deployment logs
2. Verify all environment variables are set correctly
3. Ensure your Redis and Supabase services are accessible
4. Check Vercel's status page for any service issues

---

**Deployment Complete!** 🎉

Your backend should now be live at `https://www.sahla-delivery.com`
