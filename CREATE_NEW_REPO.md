# Create New Repository for Backend

## Option 1: Create New Repository on GitHub (Recommended)

### Step 1: Create Repository on GitHub

1. Go to https://github.com/new
2. Repository name: `sahla-backend` (or `sahla-api`)
3. Description: "Sahla Food Delivery Backend API"
4. Visibility: Private (or Public, your choice)
5. **DO NOT** initialize with README, .gitignore, or license
6. Click "Create repository"

### Step 2: Initialize and Push Backend Code

```bash
# Navigate to backend folder
cd /Users/macamine/Desktop/Sahla/backend

# Initialize new git repository
git init

# Add all files
git add .

# Create initial commit
git commit -m "Initial commit: Sahla backend API"

# Add remote repository (replace YOUR_USERNAME with your GitHub username)
git remote add origin https://github.com/YOUR_USERNAME/sahla-backend.git

# Push to new repository
git branch -M main
git push -u origin main
```

### Step 3: Connect to Vercel

1. Go to Vercel Dashboard → Add New Project
2. Import the new repository: `YOUR_USERNAME/sahla-backend`
3. **Root Directory**: Leave empty (or set to `.` since backend is at root)
4. Framework Preset: "Other" or "Node.js"
5. Build Command: Leave empty
6. Output Directory: Leave empty
7. Install Command: `npm install`
8. Add all environment variables
9. Click "Deploy"

## Option 2: Use GitHub CLI (If Installed)

```bash
cd /Users/macamine/Desktop/Sahla/backend

# Initialize git
git init
git add .
git commit -m "Initial commit: Sahla backend API"

# Create repository on GitHub (replace YOUR_USERNAME)
gh repo create sahla-backend --private --source=. --remote=origin --push
```

## Option 3: Copy Backend to New Location

```bash
# Create new directory
mkdir ~/Desktop/sahla-backend
cd ~/Desktop/sahla-backend

# Copy backend files
cp -r /Users/macamine/Desktop/Sahla/backend/* .
cp -r /Users/macamine/Desktop/Sahla/backend/.* . 2>/dev/null || true

# Initialize git
git init
git add .
git commit -m "Initial commit: Sahla backend API"

# Add remote and push
git remote add origin https://github.com/YOUR_USERNAME/sahla-backend.git
git branch -M main
git push -u origin main
```

## Advantages of New Repository

✅ **Cleaner deployment** - No root directory confusion
✅ **Simpler Vercel setup** - Backend is at repository root
✅ **Independent versioning** - Backend and frontend can be versioned separately
✅ **Easier CI/CD** - Simpler build configurations
✅ **Better organization** - Clear separation of concerns

## After Creating New Repository

1. **Update Vercel Project**

   - Connect to new repository
   - No need to set Root Directory (backend is at root)
   - Add all environment variables
   - Deploy

2. **Update Frontend** (if needed)

   - Update API URLs in frontend to point to new backend URL
   - Update any configuration files

3. **Update Documentation**
   - Update deployment docs with new repository URL
   - Update team documentation

## Environment Variables to Add in Vercel

Make sure to add all these in the new Vercel project:

- `NODE_ENV=production`
- `SUPABASE_URL`
- `SUPABASE_ANON_KEY`
- `SUPABASE_SERVICE_ROLE_KEY`
- `REDIS_URL`
- `FRONTEND_URL=https://www.sahla-delivery.com`
- All other environment variables from your `.env` file

## Next Steps

1. Create the new repository on GitHub
2. Push backend code to new repository
3. Connect to Vercel
4. Add environment variables
5. Deploy
6. Test deployment at `https://your-domain.vercel.app/health`
