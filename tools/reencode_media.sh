#!/usr/bin/env bash
# Re-encode heavy media (cutscene/lounge videos + music) down to web-sane
# bitrates so the Godot web export's index.pck stays under itch.io's 200 MB
# per-file hard limit.
#
# WHY THIS EXISTS: itch.io rejects the entire HTML5 embed if any single file in
# the uploaded zip exceeds 200 MB. index.pck bundles every video/music/art
# asset, so it is the file that grows past the cap. When it did, the live game
# showed "the developer has not uploaded a adventure yet…" even though butler
# reported a successful push — the build was on itch but unloadable. This script
# is the documented remediation the CI size gate (export-game.yml → "Verify
# export output") points at.
#
# It preserves every file name, keeps cutscene AUDIO intact (the boss-defeat
# endings must have sound), and keeps the Smoke Lounge video muted (its rule).
# Idempotent-ish: re-running re-encodes from current files, so run once per need.
#
# Requires ffmpeg + ffprobe on PATH (or set FFMPEG/FFPROBE env vars).
#
# Usage:  bash tools/reencode_media.sh
# Then:   reimport + web-export and confirm index.pck < 190 MB.
set -euo pipefail
cd "$(dirname "$0")/.."

FFMPEG="${FFMPEG:-ffmpeg}"
command -v "$FFMPEG" >/dev/null 2>&1 || { echo "ffmpeg not found (set FFMPEG=)"; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

VID_DIR="src/assets/video"
CUT_DIR="$VID_DIR/cutscenes"

# --- Cutscene videos: 720p, ~2600k video + 128k vorbis audio (KEEP SOUND) ---
for s in 1 2 3; do
  f="$CUT_DIR/stage${s}_boss_defeat.ogv"
  [ -f "$f" ] || continue
  echo "re-encoding $f (keep audio)"
  "$FFMPEG" -y -v error -i "$f" -c:v libtheora -b:v 2600k -c:a libvorbis -b:a 128k "$TMP/out.ogv"
  mv "$TMP/out.ogv" "$f"
done

# --- Smoke Lounge: 720p, ~1100k video, MUTED (its rule — no audio) ---
if [ -f "$VID_DIR/smoke_lounge.ogv" ]; then
  echo "re-encoding $VID_DIR/smoke_lounge.ogv (muted)"
  "$FFMPEG" -y -v error -i "$VID_DIR/smoke_lounge.ogv" -c:v libtheora -b:v 1100k -an "$TMP/out.ogv"
  mv "$TMP/out.ogv" "$VID_DIR/smoke_lounge.ogv"
fi

# --- Music: normalize every track to 128k in place (all references preserved) ---
for f in src/assets/music/*.mp3; do
  [ -f "$f" ] || continue
  echo "re-encoding $f -> 128k mp3"
  "$FFMPEG" -y -v error -i "$f" -c:a libmp3lame -b:a 128k "$TMP/out.mp3"
  mv "$TMP/out.mp3" "$f"
done
for f in src/assets/music/*.ogg; do
  [ -f "$f" ] || continue
  echo "re-encoding $f -> 128k ogg"
  "$FFMPEG" -y -v error -i "$f" -c:a libvorbis -b:a 128k "$TMP/out.ogg"
  mv "$TMP/out.ogg" "$f"
done

echo "Done. Now reimport + web-export and confirm index.pck < 190 MB."
