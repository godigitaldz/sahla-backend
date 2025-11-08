# Quick Deploy to Vercel - Quick Reference

## Fastest Method (GitHub Integration)

1. **Push code to GitHub**
   ```bash
   git add .
   git commit -m "Ready for Vercel deployment"
   git push
   ```

2. **Connect to Vercel**
   - Go to https://vercel.com/dashboard
   - Click "Add New Project"
   - Import your repository
   - **Important**: Set **Root Directory** to `backend`

3. **Add Environment Variables**
   - In Vercel project settings → Environment Variables
   - Add all variables from your `.env` file
   - **Important**: Set `FRONTEND_URL=https://www.sahla-delivery.com`
   - Set `NODE_ENV=production`

4. **Deploy**
   - Click "Deploy"
   - Wait for completion

5. **Add Domain**
   - Project Settings → Domains
   - Add `www.sahla-delivery.com`
   - Configure DNS as instructed by Vercel

## CLI Method

```bash
cd backend
vercel login
vercel --prod
```

Then add environment variables in Vercel Dashboard.

## Essential Environment Variables

Make sure these are set in Vercel:
- `NODE_ENV=production`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `REDIS_URL`
- `FRONTEND_URL=https://www.sahla-delivery.com`

## Verify Deployment

Visit: `https://www.sahla-delivery.com/health`

Should return: `{"success": true, ...}`

---

For detailed instructions, see `VERCEL_DEPLOYMENT.md`
