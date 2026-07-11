#!/usr/bin/env bash
# Deploy the exported web build to itch.io using butler (itch.io's official CLI).
#
# Prereqs:
#   1. itch.io project page exists: https://youngstunners88.itch.io/lil-blunt-adventure
#      (Kind: HTML, "This file will be played in the browser" on the html5 channel)
#   2. BUTLER_API_KEY env var set — get one at https://itch.io/user/settings/api-keys
#   3. web/game/ contains a fresh export (CI produces it, or run scripts/export-web.sh)
#
# Usage:  BUTLER_API_KEY=xxxx ./scripts/deploy_itch.sh
set -euo pipefail
cd "$(dirname "$0")/.."

ITCH_TARGET="${ITCH_TARGET:-youngstunners88/lil-blunt-adventure:html5}"
BUILD_DIR="web/game"

if [ -z "${BUTLER_API_KEY:-}" ]; then
  echo "ERROR: BUTLER_API_KEY is not set." >&2
  echo "Create one at https://itch.io/user/settings/api-keys" >&2
  exit 1
fi

if [ ! -f "$BUILD_DIR/index.html" ] || [ ! -f "$BUILD_DIR/index.wasm" ]; then
  echo "ERROR: no export found in $BUILD_DIR — run the CI export or scripts/export-web.sh first." >&2
  exit 1
fi

# Install butler locally if missing.
if ! command -v butler >/dev/null 2>&1; then
  if [ ! -x ./butler ]; then
    echo "Downloading butler..."
    curl -fL --retry 3 -o /tmp/butler.zip \
      "https://broth.itch.zone/butler/linux-amd64/LATEST/archive/default"
    unzip -qo /tmp/butler.zip butler -d .
    chmod +x ./butler
  fi
  BUTLER=./butler
else
  BUTLER=butler
fi

VERSION="$(git rev-parse --short HEAD)-$(date -u +%Y%m%d%H%M)"
echo "Pushing $BUILD_DIR → $ITCH_TARGET (version $VERSION)"
"$BUTLER" push "$BUILD_DIR" "$ITCH_TARGET" --userversion "$VERSION"
echo "Done → https://youngstunners88.itch.io/lil-blunt-adventure"
