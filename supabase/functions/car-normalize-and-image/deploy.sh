#!/bin/bash

# Deploy the car-normalize-and-image Edge Function
echo "🚀 Deploying car-normalize-and-image Edge Function..."

# Check if Supabase CLI is installed
if ! command -v supabase &> /dev/null; then
    echo "❌ Supabase CLI not found. Please install it first:"
    echo "   npm install -g supabase"
    exit 1
fi

# Check if we're in the right directory
if [ ! -f "index.ts" ]; then
    echo "❌ Please run this script from the car-normalize-and-image function directory"
    exit 1
fi

# Deploy the function
echo "📦 Deploying function..."
supabase functions deploy car-normalize-and-image --project-ref your-project-ref

if [ $? -eq 0 ]; then
    echo "✅ Function deployed successfully!"
    echo ""
    echo "🔧 Next steps:"
echo "1. Update your project reference in the command above"
echo "2. Set environment variables in Supabase dashboard:"
echo "   - CARSXE_API_KEY: Your CarsXE API key"
echo "   - ENABLE_BG_REMOVAL: Set to 'true' to enable background removal"
echo "   - ENABLE_AI_GENERATION: Set to 'true' to enable AI image generation"
echo "3. Create the storage buckets:"
echo "   - car-cards (for cached CarsXE images)"
echo "   - car-library (for curated images)"
echo "   - car-images (for processed images)"
echo "4. Run the database schema migration:"
echo "   - sql/smart_car_pipeline_schema.sql"
echo "   - supabase/storage-setup.sql"
echo ""
echo "🔧 Feature Flags:"
echo "   - ENABLE_BG_REMOVAL=true: Enables background removal on host photos"
echo "   - ENABLE_AI_GENERATION=true: Enables AI-generated 3D renders as fallback"
echo "   - Both can be set independently (e.g., only background removal, only AI generation, or both)"
echo ""
echo "🧪 Testing:"
echo "   - Run 'deno run --allow-env test-feature-flags.ts' to verify feature flags"
echo "   - This will show which features are enabled/disabled"
else
    echo "❌ Function deployment failed!"
    exit 1
fi
