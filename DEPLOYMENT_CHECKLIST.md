# Vercel Deployment Checklist ✅

Since Vercel is already connected and environment variables are added, follow these steps:

## ✅ Completed

- [x] Vercel connected to Git repository
- [x] Environment variables added

## 🔄 Next Steps

### 1. Verify Root Directory Configuration

**Critical:** Since your backend is in the `backend/` folder, you MUST set the root directory in Vercel:

1. Go to Vercel Dashboard → Your Project → Settings → General
2. Under "Root Directory", set it to: `backend`
3. Click "Save"

**Why?** Without this, Vercel will look for `package.json` in the root, but it's actually in `backend/package.json`.

### 2. Trigger Deployment

You have two options:

**Option A: Push to Git (Recommended)**

```bash
git add .
git commit -m "Deploy to Vercel"
git push
```

Vercel will automatically deploy when you push to your main branch.

**Option B: Manual Deploy**

1. Go to Vercel Dashboard → Your Project
2. Click "Deployments" tab
3. Click "Redeploy" on the latest deployment
4. Or click "Deploy" button

### 3. Configure Domain

1. Go to Vercel Dashboard → Your Project → Settings → Domains
2. Add `www.sahla-delivery.com`
3. Vercel will provide DNS instructions
4. Add the DNS records to your domain registrar
5. Wait for DNS propagation (usually 5-60 minutes)

### 4. Verify Environment Variables

Double-check these critical variables are set in Vercel:

- [ ] `NODE_ENV=production`
- [ ] `SUPABASE_URL` (your Supabase URL)
- [ ] `SUPABASE_ANON_KEY` (your Supabase anon key)
- [ ] `SUPABASE_SERVICE_ROLE_KEY` (your Supabase service role key)
- [ ] `REDIS_URL` (your Redis connection URL)
- [ ] `FRONTEND_URL=https://www.sahla-delivery.com` ⚠️ **Important: Fix this if it's incorrect**
- [ ] `ALLOWED_ORIGINS` (if you want to restrict CORS)

**Note:** Your `.env` file had `FRONTEND_URL` pointing to a Redis URL. Make sure in Vercel it's set to `https://www.sahla-delivery.com`

### 5. Test Deployment

After deployment, test these endpoints:

```bash
# Health check
curl https://www.sahla-delivery.com/health

# Should return:
# {"success":true,"message":"Sahla Backend API is running",...}

# Test API endpoint
curl https://www.sahla-delivery.com/api/restaurants

# Test landing page
curl https://www.sahla-delivery.com/
```

### 6. Check Deployment Logs

1. Go to Vercel Dashboard → Your Project → Deployments
2. Click on the latest deployment
3. Check the build logs for any errors
4. Check function logs if API calls fail

### 7. Update CORS (If Needed)

If your frontend is on a different domain, update CORS:

1. Go to Vercel Dashboard → Your Project → Settings → Environment Variables
2. Add/Update `ALLOWED_ORIGINS`:
   ```
   ALLOWED_ORIGINS=https://www.sahla-delivery.com,https://sahla-delivery.com,https://your-frontend-domain.com
   ```
3. Redeploy

## 🔍 Troubleshooting

### Issue: Build Fails

**Solution:**

- Check build logs in Vercel
- Verify Root Directory is set to `backend`
- Ensure `package.json` exists in `backend/` folder
- Check Node.js version (should be 18.x or higher)

### Issue: Function Not Found / 404 Errors

**Solution:**

- Verify `vercel.json` is in the `backend/` folder
- Check that `src/index.js` exists
- Verify routes in `vercel.json` are correct

### Issue: Environment Variables Not Working

**Solution:**

- Make sure variables are set for "Production" environment
- Redeploy after adding environment variables
- Check variable names match exactly (case-sensitive)

### Issue: CORS Errors

**Solution:**

- Add your frontend domain to `ALLOWED_ORIGINS`
- Or set `ALLOWED_ORIGINS=*` for development (not recommended for production)
- Redeploy after updating

### Issue: Redis Connection Fails

**Solution:**

- Verify Redis URL is correct
- Check if Redis Cloud allows connections from Vercel's IP ranges
- You may need to whitelist Vercel's IPs or allow all IPs in Redis Cloud

### Issue: Static Files Not Loading

**Solution:**

- Verify `public/` folder is in `backend/` directory
- Check that files exist in `backend/public/`
- Verify routes in `vercel.json` include static file handling

## 📊 Monitoring

After successful deployment:

1. **View Logs:** Vercel Dashboard → Deployments → [Select Deployment] → Functions → Logs
2. **Monitor Performance:** Vercel Dashboard → Analytics
3. **Check Uptime:** Vercel provides built-in uptime monitoring

## 🎯 Success Criteria

Your deployment is successful when:

- ✅ `/health` endpoint returns `{"success": true, ...}`
- ✅ `/api/restaurants` (or any API endpoint) works
- ✅ Landing page loads at `/`
- ✅ Privacy policy loads at `/privacy-policy`
- ✅ Domain `www.sahla-delivery.com` is configured and working
- ✅ SSL certificate is automatically provisioned (HTTPS works)

## 🚀 Quick Commands

```bash
# Test health endpoint
curl https://www.sahla-delivery.com/health

# Test API
curl https://www.sahla-delivery.com/api/restaurants

# Check deployment status (if using Vercel CLI)
cd backend
vercel ls
```

---

**Need Help?** Check the deployment logs in Vercel Dashboard for detailed error messages.
