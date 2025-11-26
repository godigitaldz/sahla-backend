#!/bin/bash

# Script to fix APK path logic for build tools compatibility
# This ensures APK files are available in standard locations

echo "🔧 Fixing APK path logic..."

# Navigate to the project directory
cd "$(dirname "$0")"

# Define paths
ANDROID_APP_DIR="android/app"
BUILD_OUTPUTS_DIR="$ANDROID_APP_DIR/build/outputs/apk"
STANDARD_APK_DIR="$BUILD_OUTPUTS_DIR"

# Create standard APK directory if it doesn't exist
mkdir -p "$STANDARD_APK_DIR"

# Function to copy APK if it exists
copy_apk_if_exists() {
    local source="$1"
    local destination="$2"
    local description="$3"

    if [ -f "$source" ]; then
        cp "$source" "$destination"
        echo "✅ $description: $destination"
        return 0
    else
        echo "❌ $description: Source not found ($source)"
        return 1
    fi
}

echo "📱 Creating standard APK paths..."

# Copy release APK as default release
copy_apk_if_exists \
    "$BUILD_OUTPUTS_DIR/release/app-release.apk" \
    "$STANDARD_APK_DIR/app-release.apk" \
    "Default release APK"

# Copy debug APK as default debug
copy_apk_if_exists \
    "$BUILD_OUTPUTS_DIR/debug/app-debug.apk" \
    "$STANDARD_APK_DIR/app-debug.apk" \
    "Default debug APK"

echo ""
echo "📋 Available APK files:"
ls -la "$STANDARD_APK_DIR"/*.apk 2>/dev/null || echo "No APK files found in standard location"

echo ""
echo "🎯 APK path logic fixed! Build tools should now find APK files in standard locations."
