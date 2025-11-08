# Troubleshooting Vercel 404 Error

## Common Issues and Solutions

### 1. Root Directory Not Set (MOST COMMON)

**Problem:** Vercel can't find your `package.json` and `vercel.json` files.

**Solution:**
1. Go to Vercel Dashboard → Your Project → Settings → General
2. Under "Root Directory", set it to: `backend`
3. Click "Save"
4. Redeploy the project

### 2. Check Deployment Logs

1. Go to Vercel Dashboard → Your Project → Deployments
2. Click on the latest deployment
3. Check the "Build Logs" tab for errors
4. Look for errors like:
   - "Cannot find module"
   - "File not found"
   - "Build failed"

### 3. Verify File Structure

Make sure these files exist in your repository:
```
backend/
  ├── vercel.json          ✅
  ├── package.json         ✅
  ├── src/
  │   └── index.js         ✅
  └── public/              ✅
```

### 4. Check Environment Variables

1. Go to Vercel Dashboard → Settings → Environment Variables
2. Verify all required variables are set:
   - `NODE_ENV=production`
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `SUPABASE_SERVICE_ROLE_KEY`
   - `REDIS_URL`
   - `FRONTEND_URL`

### 5. Verify Domain Configuration

1. Go to Vercel Dashboard → Settings → Domains
2. Check if `sahla-delivery.com` is added
3. Verify DNS configuration:
   - For `www.sahla-delivery.com`: CNAME to `cname.vercel-dns.com`
   - For `sahla-delivery.com`: Follow Vercel's instructions (usually A record)

### 6. Test with Vercel's Default URL

Before using your custom domain, test with Vercel's provided URL:
- Go to Vercel Dashboard → Your Project → Deployments
- Click on the latest deployment
- Copy the "Preview" or "Production" URL
- Test: `https://your-project.vercel.app/health`

If this works but your custom domain doesn't, it's a DNS/domain issue.

### 7. Clear Vercel Cache

Sometimes Vercel caches old configurations:

1. Go to Vercel Dashboard → Your Project → Settings → General
2. Scroll down and click "Clear Build Cache"
3. Redeploy

### 8. Check Node.js Version

1. Go to Vercel Dashboard → Settings → General
2. Verify Node.js version is set to 18.x or higher
3. Or add to `package.json`:
   ```json
   "engines": {
     "node": ">=18.0.0"
   }
   ```

### 9. Verify vercel.json Syntax

Make sure `backend/vercel.json` is valid JSON:
```json
{
  "version": 2,
  "builds": [
    {
      "src": "src/index.js",
      "use": "@vercel/node"
    }
  ],
  "routes": [
    {
      "src": "/(.*)",
      "dest": "src/index.js"
    }
  ]
}
```

### 10. Check Function Logs

1. Go to Vercel Dashboard → Your Project → Deployments
2. Click on a deployment → "Functions" tab
3. Click on the function → "Logs" tab
4. Look for runtime errors

## Quick Diagnostic Checklist

- [ ] Root Directory is set to `backend` in Vercel
- [ ] `vercel.json` exists in `backend/` folder
- [ ] `package.json` exists in `backend/` folder
- [ ] All environment variables are set
- [ ] Node.js version is 18.x or higher
- [ ] Build logs show no errors
- [ ] Function logs show no runtime errors
- [ ] Domain is properly configured in Vercel
- [ ] DNS records are correctly set

## Still Not Working?

1. **Check Vercel Status**: https://www.vercel-status.com/
2. **View Deployment Details**: Look at the specific error in build logs
3. **Test Locally**: Run `npm start` in the backend folder to ensure the app works
4. **Contact Support**: If all else fails, check Vercel's documentation or support

## Alternative: Deploy via CLI for Better Debugging

```bash
cd backend
vercel --prod --debug
```

This will show more detailed error messages.

