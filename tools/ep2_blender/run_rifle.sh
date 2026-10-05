#!/usr/bin/env bash
# Headless rifle render with the founder-approved defaults.  Usage:
#   tools/ep2_blender/run_rifle.sh <name> [extra rifle_hero.py args...]     e.g.  run_rifle.sh v9 --view 3q --w 960 --h 540 --samples 32
# Output: design/ep2/blender/renders/<name>.png ; log: .farm/<name>.log ; polls until "render done" / Traceback (max ~6 min).
set -u
cd "$(dirname "$0")/../.."
NAME="$1"; shift
BL="${BLENDER_PATH:-C:/Program Files/Blender Foundation/Blender 5.2/blender.exe}"
GLB="${RIFLE_GLB:-C:/Users/SAMSUNG/Downloads/bolt-action+rifle+3d+model_Clone1_Clone1 (1).glb}"
LOGO="artifacts/episode2-gold-mine/references/founder_2026-10-06/GOLD_LOGO.png"
mkdir -p .farm design/ep2/blender/renders; rm -f ".farm/$NAME.log"
"$BL" -b --python tools/ep2_blender/rifle_hero.py -- --glb "$GLB" --out "$PWD/design/ep2/blender/renders/$NAME.png" \
  --align --flipx --pre tools/ep2_blender/rifle_surgery.py --logo "$PWD/$LOGO" "$@" > ".farm/$NAME.log" 2>&1 &
PID=$!
for _ in $(seq 1 48); do
  sleep 8
  grep -q -E "render done|Traceback" ".farm/$NAME.log" 2>/dev/null && break
  kill -0 $PID 2>/dev/null || break
done
grep -E "surgery|decal|Traceback|Error|render done" ".farm/$NAME.log"
