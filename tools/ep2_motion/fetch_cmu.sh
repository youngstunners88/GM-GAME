#!/usr/bin/env bash
# Fetch the CMU motion-capture clips used for Rich & Utah's Armory motion (skill ep2-runpod-motion-lab).
# Source: CMU Graphics Lab Motion Capture Database, BVH conversion by Bruce Hahne (mirror: github.com/una-dinosauria/cmu-mocap).
# Licence (READMEFIRST.txt in that mirror): "CMU places no restrictions on the use of the original dataset, and I (Bruce) place no
# additional restrictions on the use of this particular BVH conversion." / "This data is free for use in research and commercial projects."
# Credit: "The data used in this project was obtained from mocap.cs.cmu.edu. The database was created with funding from NSF EIA-0196217."
# The BVH files (120 fps, ~37 MB) stay OUT of the repo: default target ~/tools/mocap/cmu.
set -euo pipefail
OUT="${1:-$HOME/tools/mocap/cmu}"
BASE=https://raw.githubusercontent.com/una-dinosauria/cmu-mocap/master
mkdir -p "$OUT"
# clip  -> what it is used for
CLIPS="
77_02 standing (Idle)
77_01 looking around (Idle2)
82_08 stand still, casual walk forward (Idle/Walk)
81_03 walk (Walk)
16_17 walk, 90-degree left turn (Turn)
16_19 walk, 90-degree right turn (Turn)
83_27 walk forward stepping up stairs (StairsUp)
83_29 walk forward stepping up stairs (StairsUp)
83_34 walk forward and up stairs (StairsUp)
13_35 climb 3 steps (StairsUp, short)
13_27 direct traffic, wave, point (Greet/Point)
14_24 direct traffic, wave, point (Greet/Point)
18_08 conversation - explain with hand gestures (Talk)
19_08 conversation - explain with hand gestures (Talk)
70_10 carry 12.5lb suitcase (Carry)
69_69 walk forward and pick up object, carry back object (Carry)
69_72 walk up to object, pick up object, set down in another place (PickUp/PutDown)
62_20 closing, moving and opening a box (Crate)
13_20 wash windows (WipeRifle base)
86_12 sweeping, wipe window, wipe mirror (Wipe)
80_50 cleaning window (Wipe)
79_96 shooting a gun (InspectRifle)
80_03 shooting a gun (InspectRifle)
80_28 drinking and smoking (CigarPuff)
15_06 lean forward, reach for (Reach/Counter)
13_10 jump up to grab, reach for, tiptoe (Reach high shelf)
26_09 bend, pick up (PickUp)
"
echo "$CLIPS" | while read -r c rest; do
  [ -z "$c" ] && continue
  s=$((10#${c%_*}))
  [ -s "$OUT/$c.bvh" ] || curl -sf -o "$OUT/$c.bvh" "$BASE/data/$(printf %03d $s)/$c.bvh" || echo "missing $c"
done
curl -sf -o "$OUT/READMEFIRST.txt" "$BASE/READMEFIRST.txt"
curl -sf -o "$OUT/index.txt" "$BASE/cmu-mocap-index-text.txt"
echo "fetched $(ls "$OUT"/*.bvh | wc -l) clips -> $OUT"
