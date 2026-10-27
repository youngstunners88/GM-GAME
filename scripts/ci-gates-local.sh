#!/usr/bin/env bash
# ci-gates-local.sh — run the SAME headless gameplay gates CI runs (export-game.yml, the "Portal room gameplay"
# step) on this checkout, BEFORE anything reaches master. ship-to-master.sh calls it.
#
# Why: ship-to-master.sh used to run only a script-compile check and the security sentinel. CI runs ~12 more
# tests (paw contact, Bull rifle grip, armory, gold town ...). Pushing without them put two failing builds on
# master on 2026-10-16 and the deploy was blocked each time. The commands are read straight out of the workflow so
# they cannot drift from CI. The xvfb render capture is skipped (needs apt/xvfb); everything else is identical.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
G="${GODOT_BIN:-.godot-cache/Godot_v4.3-stable_linux.x86_64}"
[ -x "$G" ] || { echo "✗ pinned Godot 4.3 missing ($G): run scripts/bootstrap-godot.sh"; exit 2; }
# One Godot at a time on this 7 GB box: offloaded-packet verifies (.farm/verify.sh) take the same lock.
exec 9>/tmp/gm-godot.lock
flock 9
WF=.github/workflows/export-game.yml
start=$(grep -n -- '--script res://tests/portal_room_test.gd' "$WF" | head -1 | cut -d: -f1)
end=$(grep -n 'sudo apt-get update -qq' "$WF" | awk -F: -v s="$start" '$1>s{print $1; exit}')
[ -n "$start" ] && [ -n "$end" ] || { echo "✗ could not find the gate block in $WF (did the workflow change?)"; exit 2; }
LOGDIR=$(mktemp -d)
# Run EVERY test (CI's block stops at the first failure; here we want the whole list), turning each CI exit into a marker.
{ sed -n "${start},$((end-1))p" "$WF" | sed 's/^          //' \
  | sed -E "s/^(grep -q '([^']+)' ([A-Za-z-]+\.log))\$/\1 || echo \"GATE_MISSING \3: \2\"/" \
  | sed -E "s/then exit 1; fi/then echo GATE_ERRORS; fi/"; } > "$LOGDIR/gates.sh"
echo "→ CI gates (workflow lines $start-$((end-1))), logs in $LOGDIR"
timeout 600 "$G" --headless --editor --quit >/dev/null 2>&1 || true   # fresh class cache
timeout 600 "$G" --headless --import >/dev/null 2>&1 || true
mkdir -p "$LOGDIR/xdg"   # fresh user:// like CI's clean runner
XDG_DATA_HOME="$LOGDIR/xdg/data" XDG_CONFIG_HOME="$LOGDIR/xdg/config" XDG_CACHE_HOME="$LOGDIR/xdg/cache" GODOT_BIN="$G" bash "$LOGDIR/gates.sh" > "$LOGDIR/run.log" 2>&1
mv -f ./*-tests.log ./portal-traversal.log "$LOGDIR"/ 2>/dev/null
git ls-files -o --exclude-standard | grep -E '\.(uid)$|rigged_[0-9]\.jpg$|detail_(mr|normal)\.jpg$|retopo_albedo\.jpg$' | tr '\n' '\0' | xargs -0 -r rm -f
git diff --name-only | grep -E '\.import$' | tr '\n' '\0' | xargs -0 -r git checkout --

# Known MACHINE difference (not a code defect): on this box pause_menu_test's three "tap target clears the lives counter"
# checks fail on unmodified master while CI passes the same code (HUD box geometry differs by environment; a Codex
# session reproduced the same three failures on f6203903). Only those exact lines are tolerated, only in pause-tests.log.
KNOWN='the whole tap target clears the lives counter and fullscreen button hit circle'
bad=$(
  for f in "$LOGDIR"/*.log; do
    case "$f" in */run.log) continue;; esac
    grep -HE '\[FAIL\]|SCRIPT ERROR|Parse Error' "$f" | { if [[ "$f" == */pause-tests.log ]]; then grep -vF "$KNOWN"; else cat; fi; }
  done
  grep -E 'GATE_MISSING' "$LOGDIR/run.log" | grep -v 'pause-tests.log'
  grep -E 'timed out|Terminated' "$LOGDIR/run.log"
)
if [ -n "$bad" ]; then
  echo "✗ CI gate FAILED — this would fail on master too:"; echo "$bad" | sort -u | cut -c1-240 | head -15
  echo "  full logs: $LOGDIR"; exit 1
fi
echo "✓ all CI headless gates pass (pause tap-target machine difference tolerated: $(grep -cF "$KNOWN" "$LOGDIR/pause-tests.log" 2>/dev/null || echo 0) lines)"
