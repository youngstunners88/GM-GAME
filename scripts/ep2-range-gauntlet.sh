#!/usr/bin/env bash
# Gauntlet for the target-practice lesson + first-person rifle (skill ep2-gauntlet-loop). Stops on the first red.
set -e
cd "$(dirname "$0")/.."
G=.godot-cache/Godot_v4.3-stable_linux.x86_64
for t in ep2_range_lesson_test ep2_smelting_facility_test ep2_hideout_corrections_test ep2_runner_audio_test; do
  echo "== $t"; timeout 600 $G --headless res://tests/$t.tscn 2>&1 | grep -E "\[FAIL\]|ALL PASS|FAIL \(" | tee /tmp/g.$$ ; grep -q "ALL PASS" /tmp/g.$$ && ! grep -q FAIL /tmp/g.$$
done
node tools/ep2_sim/fps_feel_sim.mjs > /dev/null
mkdir -p .farm/range
timeout 600 xvfb-run -a -s "-screen 0 960x540x24" $G --rendering-driver opengl3 --rendering-method gl_compatibility --resolution 960x540 \
  res://tools/ep2_shots/range_lesson_shot.tscn -- out=.farm/range 2>&1 | grep -E "^SHOT|METRIC" > .farm/range/rig.log
cat .farm/range/rig.log | grep METRIC
node tools/ep2_sim/range_gauntlet_jev.mjs .farm/range/rig.log
echo "LOOK at .farm/range/*.png before saying done."
