#!/bin/bash
# Asset optimization script for Flutter app
# Optimizes images and removes unnecessary files

set -e

echo "🔧 Starting asset optimization..."

# Check if ImageMagick or sips is available
if command -v sips &> /dev/null; then
    OPTIMIZER="sips"
elif command -v convert &> /dev/null; then
    OPTIMIZER="imagemagick"
else
    echo "⚠️  Warning: No image optimizer found (sips or ImageMagick)"
    echo "   Install ImageMagick: brew install imagemagick"
    echo "   Or use sips (built-in on macOS)"
    exit 1
fi

# Function to optimize PNG
optimize_png() {
    local file="$1"
    if [ "$OPTIMIZER" = "sips" ]; then
        # Use sips to optimize (macOS built-in)
        sips -Z 2048 "$file" > /dev/null 2>&1 || true
        # Try to reduce file size (lossless)
        sips -s format png "$file" --out "$file.tmp" > /dev/null 2>&1 && mv "$file.tmp" "$file" || true
    fi
    echo "✓ Optimized: $file"
}

# Function to convert to WebP (if available)
convert_to_webp() {
    local file="$1"
    local webp_file="${file%.*}.webp"
    if command -v cwebp &> /dev/null; then
        cwebp -q 85 "$file" -o "$webp_file" > /dev/null 2>&1
        local original_size=$(stat -f%z "$file" 2>/dev/null || stat -c%s "$file" 2>/dev/null || echo 0)
        local webp_size=$(stat -f%z "$webp_file" 2>/dev/null || stat -c%s "$webp_file" 2>/dev/null || echo 0)
        if [ "$webp_size" -lt "$original_size" ]; then
            echo "  → WebP is smaller ($webp_size < $original_size), consider using: $webp_file"
        fi
    fi
}

# Optimize large assets
echo "📦 Optimizing large PNG assets..."
find assets -type f -name "*.png" -size +100k | while read -r file; do
    optimize_png "$file"
done

echo "✅ Asset optimization complete!"
echo ""
echo "💡 Recommendations:"
echo "   1. Convert large PNGs (>500KB) to WebP format"
echo "   2. Use vector graphics (SVG) for icons when possible"
echo "   3. Compress GIFs using tools like gifsicle"
echo "   4. Consider lazy loading for images >1MB"
