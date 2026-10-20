#!/usr/bin/env bash
# Release presence gate for the Episode 2 town (skill ep2-townfolk-presence).
# "On master" is not "in the build": the townspeople, the openings kit, Rich & Utah, the jail and Logan live in the STREAMED
# ep2_extras.pck, and a pack that silently lost one of them ships a town with the old puppets / blank boards / no lake.
# This fails the build unless every path the game asks the pack for is really inside the files that get deployed.
#   scripts/check-ep2-extras-pack.sh [web/game]   (default web/game; run after the extras are packed)
# Godot stores each pck entry's path as plain text, so grep -a on the pack is a faithful "is it in there" test.
set -u
cd "$(git rev-parse --show-toplevel)"
dir="${1:-web/game}"
extras="$dir/ep2_extras.pck"
main="$dir/index.pck"
fail=0
miss() { echo "✗ MISSING from $1: $2"; fail=1; }

[ -f "$extras" ] || { echo "✗ $extras does not exist - Episode 2's new art would not reach players"; exit 1; }
[ -f "$main" ]   || { echo "✗ $main does not exist"; exit 1; }

# 1. every extras path the loader names (kit with openings, Armory, Rich, Utah, jail, accomplice)
mapfile -t named < <(grep -oE 'res://src/episode2/extras/[A-Za-z0-9_./-]+\.(glb|png|jpg)' src/episode2/ep2_extras.gd | sort -u)
# 2. everything under extras/ that the repo ships (people, Logan, lake) - a file removed from the pack is a symptom
mapfile -t onrepo < <(git ls-files 'src/episode2/extras/*' | grep -E '\.(glb|png|jpg)$' | sed 's#^#res://#')
for p in "${named[@]}" "${onrepo[@]}"; do
  rel=${p#res://}
  grep -aqF "$rel" "$extras" || miss "ep2_extras.pck" "$rel"
done
n_people=$(printf '%s\n' "${onrepo[@]}" | grep -cE 'extras/people/town(sman|swoman)_')
[ "$n_people" -ge 5 ] || { echo "✗ only $n_people townspeople in src/episode2/extras/people (need >= 5)"; fail=1; }
printf '%s\n' "${onrepo[@]}" | grep -q 'extras/lake/logan.glb'      || { echo "✗ Logan (extras/lake/logan.glb) is not in the repo's extras"; fail=1; }
printf '%s\n' "${onrepo[@]}" | grep -q 'extras/folk/rich_armory2.glb' || { echo "✗ Rich v2 (extras/folk/rich_armory2.glb) is not in the repo's extras"; fail=1; }
printf '%s\n' "${onrepo[@]}" | grep -q 'extras/folk/utah_armory2.glb' || { echo "✗ Utah v2 (extras/folk/utah_armory2.glb) is not in the repo's extras"; fail=1; }

# 3. the scenes the player flow runs through must be in the main pack (chamber chain: town -> Logan's Lake)
for s in gold_town logans_lake; do
  grep -aqF "src/episode2/chamber/$s.tscn" "$main" || miss "index.pck" "src/episode2/chamber/$s.tscn"
done
# 4. the player flow actually leads to the lake: the town's last beat hands off to it, and the session root can build it
grep -q 'next_chamber": "logans_lake"' src/episode2/chamber/gold_town.gd         || { echo "✗ gold_town no longer hands off to logans_lake"; fail=1; }
grep -q '"logans_lake": preload' src/episode2/session/ep2_session_root.gd         || { echo "✗ Ep2SessionRoot has no logans_lake chamber"; fail=1; }

[ $fail = 0 ] && echo "✓ ep2 presence gate: ${#named[@]} named + ${#onrepo[@]} shipped extras are in ep2_extras.pck; town and lake scenes are in index.pck" || echo "✗ ep2 presence gate FAILED - the build would ship without part of the Episode 2 town"
exit $fail
