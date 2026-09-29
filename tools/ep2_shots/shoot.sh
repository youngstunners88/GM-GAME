#!/usr/bin/env bash
# One-minute local capture of the real runner (software GL). Usage:
#   bash tools/ep2_shots/shoot.sh <outdir> <leg> <metres,comma> [aimx,aimy]
cd "$(git rev-parse --show-toplevel)"
G=.godot-cache/Godot_v4.3-stable_linux.x86_64
timeout 900 xvfb-run -a -s "-screen 0 1280x720x24" $G --rendering-driver opengl3 --rendering-method gl_compatibility \
  --resolution 1280x720 res://tools/ep2_shots/shot_runner.tscn -- out="${1:-.farm/shots_l}" leg="${2:-0}" at="${3:-20,100}" aim="${4:-800,300}" ${5:+custom=$5} ${6:+off=$6} ${7:+cam=$7} ${8:+clips=$8} 2>&1 \
  | grep -E "SHOT|DONE|SCRIPT ERROR|Parse Error"
