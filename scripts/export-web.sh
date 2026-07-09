#!/bin/bash

# Lil Blunt — Godot 4.3 Web Export Script
# Run this from the project root to export to web/game/

set -e

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

echo "🎮 Lil Blunt: The Smoke Realm — Web Export"
echo "=========================================="
echo ""

# Find Godot
if [ -z "$GODOT" ]; then
    echo "Looking for Godot 4.3..."

    # Common locations
    for path in \
        "/opt/godot-4.3/Godot" \
        "/Applications/Godot.app/Contents/MacOS/Godot" \
        "C:/Godot/Godot.exe" \
        "$HOME/Applications/Godot.app/Contents/MacOS/Godot" \
        "$(which godot)" \
        "$(which godot4)" \
    ; do
        if [ -f "$path" ] 2>/dev/null || [ -x "$path" ] 2>/dev/null; then
            GODOT="$path"
            echo "✓ Found: $GODOT"
            break
        fi
    done
fi

if [ -z "$GODOT" ] || ! command -v "$GODOT" &> /dev/null; then
    echo "✗ Godot not found!"
    echo ""
    echo "Please install Godot 4.3 from https://godotengine.org/download"
    echo "Then either:"
    echo "  1. Add it to PATH, or"
    echo "  2. Set GODOT=/path/to/godot and run again"
    exit 1
fi

# Show version
echo "Version: $("$GODOT" --version 2>&1 | head -1)"
echo ""

# Create export preset if needed
if [ ! -f "export_presets.cfg" ]; then
    echo "📝 Creating export preset..."
    mkdir -p .godot
    cat > export_presets.cfg << 'EOF'
[preset.0]
name="Web"
platform="Web"
runnable=true
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter="*.yml,*.yaml,*.md"
export_path="web/game/index.html"
script_export_mode=1
script_encryption_key=""

[preset.0.options]
compression/enabled=true
compression/algorithms/deflate/compression_level=9
web/enable_cuda=false
web/enable_vulkan=false
web/use_threads=true
web/threads_count=8
EOF
fi

# Create output directory
mkdir -p web/game

# Export
echo "🔨 Exporting to web/game/..."
echo ""

"$GODOT" --headless --export-release Web

echo ""
echo "✓ Export complete!"
echo ""

# Verify
if [ -f "web/game/index.js" ] && [ -f "web/game/index.wasm" ]; then
    echo "📦 Output files:"
    du -h web/game/* | awk '{print "   " $1 "\t" $2}'
    echo ""
    echo "✅ Ready for deployment to Vercel/Netlify!"
    echo "   1. git add web/game/"
    echo "   2. git commit -m 'build: export Godot game to web'"
    echo "   3. git push"
    echo ""
else
    echo "✗ Export may have failed — check output above"
    exit 1
fi
