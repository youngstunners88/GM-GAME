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

# Create export preset if needed. Kept in sync with .github/workflows/
# export-game.yml so a LOCAL export and the CI/itch deploy are the identical,
# NON-THREADED build. The old heredoc wrote the Godot-3.x `web/use_threads=true`
# keys, which produced a THREADED build (index.worker.js, needs SharedArrayBuffer
# + COOP/COEP) that silently fails to boot on itch.io — the "game doesn't play"
# bug. Godot 4.3's correct key is `variant/thread_support=false`.
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
include_filter="config.json,src/autoload/share_taglines.json"
exclude_filter="*.yml,*.yaml,*.md,docs/*,tests/*,prompts/*,scripts/*"
export_path="web/game/index.html"
script_export_mode=1
script_encryption_key=""

[preset.0.options]
custom_template/debug=""
custom_template/release=""
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=true
html/custom_html_shell=""
html/head_include="<script src=\"web3.js\"></script>"
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=false
progressive_web_app/enabled=false
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
