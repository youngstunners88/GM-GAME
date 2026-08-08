#!/bin/bash
# Bootstrap a checksum-verified local Godot 4.3 editor + web export templates.
#
# WHY THIS EXISTS: this project is developed inside ephemeral sandbox
# containers that are torn down and recreated per session — nothing on disk
# (including /tmp) survives between sessions. Every session that needs to run
# a headless test or a real web export has had to re-derive the exact
# download-and-checksum-verify sequence from .github/workflows/export-game.yml
# by hand. This script is that sequence, once, idempotent, and safe to run at
# the start of every session.
#
# Mirrors the checksum gate in .github/workflows/export-game.yml exactly —
# same URLs, same SHA512-SUMS.txt verification — so a local run and a CI run
# are provably running the identical, supply-chain-verified binary.
#
# Usage:
#   scripts/bootstrap-godot.sh                 # installs to ./.godot-cache
#   GODOT_CACHE_DIR=/path scripts/bootstrap-godot.sh
#   GODOT_VERSION=4.3-stable scripts/bootstrap-godot.sh   # (default)
#
# On success, prints the editor binary's absolute path on stdout as the LAST
# line — capture it directly:
#   GODOT="$(scripts/bootstrap-godot.sh | tail -1)"
#   "$GODOT" --headless res://tests/script_compile_test.tscn

set -euo pipefail

GODOT_VERSION="${GODOT_VERSION:-4.3-stable}"
CACHE_DIR="${GODOT_CACHE_DIR:-$(pwd)/.godot-cache}"
TEMPLATE_DIR="$HOME/.local/share/godot/export_templates/${GODOT_VERSION/-/.}"

mkdir -p "$CACHE_DIR"
cd "$CACHE_DIR"

EDITOR_NAME="Godot_v${GODOT_VERSION}_linux.x86_64"
EDITOR_ZIP="${EDITOR_NAME}.zip"
TEMPLATES_NAME="Godot_v${GODOT_VERSION}_export_templates.tpz"

verify() {
  local file=$1 name=$2
  local expected actual
  expected=$(grep " ${name}\$" SHA512-SUMS.txt | awk '{print $1}')
  if [ -z "$expected" ]; then
    echo "ERROR: no checksum for $name in SHA512-SUMS.txt" >&2
    exit 1
  fi
  actual=$(sha512sum "$file" | awk '{print $1}')
  if [ "$expected" != "$actual" ]; then
    echo "ERROR: checksum mismatch for $name — refusing to use an unverified binary" >&2
    exit 1
  fi
  echo "checksum OK: $name" >&2
}

# --- Editor binary: skip re-download if already present and verified ---
if [ -x "$CACHE_DIR/$EDITOR_NAME" ]; then
  echo "Editor already cached: $CACHE_DIR/$EDITOR_NAME" >&2
else
  BASE_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}"
  echo "Downloading editor: ${BASE_URL}/${EDITOR_ZIP}" >&2
  curl -fL --retry 3 -o "$EDITOR_ZIP" "${BASE_URL}/${EDITOR_ZIP}"
  curl -fL --retry 3 -o SHA512-SUMS.txt "${BASE_URL}/SHA512-SUMS.txt"
  verify "$EDITOR_ZIP" "$EDITOR_ZIP"
  unzip -q -o "$EDITOR_ZIP"
  chmod +x "$EDITOR_NAME"
  rm -f "$EDITOR_ZIP"
fi

# --- Web export templates: skip if the target version dir is already populated ---
if [ -d "$TEMPLATE_DIR" ] && [ -n "$(ls -A "$TEMPLATE_DIR" 2>/dev/null)" ]; then
  echo "Export templates already installed: $TEMPLATE_DIR" >&2
else
  BASE_URL="https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}"
  echo "Downloading export templates: ${BASE_URL}/${TEMPLATES_NAME}" >&2
  curl -fL --retry 3 -o "$TEMPLATES_NAME" "${BASE_URL}/${TEMPLATES_NAME}"
  [ -f SHA512-SUMS.txt ] || curl -fL --retry 3 -o SHA512-SUMS.txt "${BASE_URL}/SHA512-SUMS.txt"
  verify "$TEMPLATES_NAME" "$TEMPLATES_NAME"
  EXTRACT_DIR="$(mktemp -d)"
  unzip -q "$TEMPLATES_NAME" -d "$EXTRACT_DIR"
  mkdir -p "$TEMPLATE_DIR"
  cp -r "$EXTRACT_DIR"/templates/* "$TEMPLATE_DIR/"
  rm -rf "$EXTRACT_DIR" "$TEMPLATES_NAME"
fi

echo "Godot $GODOT_VERSION ready." >&2
echo "$CACHE_DIR/$EDITOR_NAME"
