#!/bin/bash

# Script to set up a new repository for Sahla backend
# This will create a clean git repository with just the backend code

set -e

echo "🚀 Setting up new repository for Sahla backend..."
echo ""

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get the backend directory
BACKEND_DIR="$(cd "$(dirname "$0")" && pwd)"
PARENT_DIR="$(dirname "$BACKEND_DIR")"

echo "📁 Backend directory: $BACKEND_DIR"
echo "📁 Parent directory: $PARENT_DIR"
echo ""

# Ask for repository URL
echo -e "${YELLOW}Enter your new GitHub repository URL:${NC}"
echo "Example: https://github.com/your-username/sahla-backend.git"
read -r REPO_URL

if [ -z "$REPO_URL" ]; then
    echo "❌ Repository URL is required!"
    exit 1
fi

# Check if already a git repository
if [ -d "$BACKEND_DIR/.git" ]; then
    echo "⚠️  Backend directory is already a git repository."
    echo "Do you want to remove the existing .git folder? (y/n)"
    read -r REMOVE_GIT
    if [ "$REMOVE_GIT" = "y" ] || [ "$REMOVE_GIT" = "Y" ]; then
        rm -rf "$BACKEND_DIR/.git"
        echo "✅ Removed existing .git folder"
    else
        echo "❌ Aborted. Please remove .git folder manually or choose a different directory."
        exit 1
    fi
fi

# Navigate to backend directory
cd "$BACKEND_DIR"

# Remove .vercel-deploy-trigger if it exists (not needed in new repo)
if [ -f ".vercel-deploy-trigger" ]; then
    rm .vercel-deploy-trigger
    echo "✅ Removed .vercel-deploy-trigger"
fi

# Initialize git repository
echo ""
echo "📦 Initializing git repository..."
git init

# Add all files
echo "📝 Adding files..."
git add .

# Create initial commit
echo "💾 Creating initial commit..."
git commit -m "Initial commit: Sahla backend API

- Express.js backend API
- Supabase integration
- Redis configuration
- API routes for restaurants, orders, menu, etc.
- Vercel deployment configuration"

# Add remote
echo "🔗 Adding remote repository..."
git remote add origin "$REPO_URL"

# Set main branch
echo "🌿 Setting up main branch..."
git branch -M main

# Push to remote
echo ""
echo "🚀 Pushing to GitHub..."
echo -e "${YELLOW}You may need to authenticate with GitHub.${NC}"
git push -u origin main

echo ""
echo -e "${GREEN}✅ Successfully set up new repository!${NC}"
echo ""
echo "📋 Next steps:"
echo "1. Go to Vercel Dashboard → Add New Project"
echo "2. Import repository: $(basename "$REPO_URL" .git)"
echo "3. Root Directory: Leave empty (backend is at root)"
echo "4. Add all environment variables"
echo "5. Deploy!"
echo ""
echo "🌐 Repository URL: $REPO_URL"
