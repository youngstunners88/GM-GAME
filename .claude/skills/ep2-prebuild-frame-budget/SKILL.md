---
name: ep2-prebuild-frame-budget
description: Find and remove frame stalls in Episode 2 transitions ("jams", "glitch delay", "freezes for a second" at the quad, the elevator door, the lake ride). Measures every background prebuild step of the next room, because one step always runs inside one frame. TRIGGER on any stall/hitch/jam/delay report at a room hand-over, before touching transition code.
---

# Prebuild frame budget

**Why stalls happen.** `Ep2SessionRoot._drive_prebuild` advances the next room's `prebuild_step(7 ms)` every frame, but a step is
never cut in half: **one build step = one frame**. A 0.3 s step is a visible jam; a 9 s step is a freeze. Rooms are requested at
story moments (the woods at the lift doorway, the town at the quad's REVEAL, the trail at GEARED), so a heavy step lands right
where the founder is looking.

## Measure first (never guess)

```bash
GM_PREBUILD_IDS=gold_town,woods_quad,mine_lift GM_PREBUILD_WARM=1 XDG_DATA_HOME=$(mktemp -d) \
  timeout 300 flock /tmp/gm-godot.lock .godot-cache/Godot_v4.3-stable_linux.x86_64 --headless --path . tools/ep2_perf/prebuild_steps.tscn \
  2>&1 | grep -E "PREBUILD|ms  step"
```
It prints each room's total and its heaviest steps (headless desktop CPU; the browser is slower, so treat >100 ms as a stall).
Warm rows (second build) separate disk loading from build work. To look inside one step, time its sub-calls the same way.

## Measured 2026-11-01 (founder residuals)
| Room | Before | After | Cause |
|---|---|---|---|
| gold_town (requested at the quad) | 17.4 s, one 14.7 s step | ~3 s, max ~0.8 s | crowd street graph: `Ep2TownNavigation.configure` tested 130k points against every wall (8.8 s) |
| woods_quad (requested at the lift doorway) | 14.6 s, one 12.7 s step | 3.3 s | same graph inside `_build_town` |
| lake_trail | 13.5 s | 2.5 s | same graph inside `_step_departure_yard` |

## Rules
1. **Fix the cost, keep the answer.** The nav fix buckets walls/props in 4 m cells; the graph is identical (points, edges) and
   `tests/ep2_founder_residuals_1101_test` proves equivalence on random points. Never "speed up" by changing what is built.
2. **Split heavy steps** into several entries of `_build_steps()` (each must be callable on its own frame). Keep the old one-shot
   function as a wrapper that calls the parts, for any direct caller.
3. **Don't move a request a test pins** (seamless_chain/interlude pin the woods request at the lift doorway). Instead,
   `PREBUILD_SETTLE` (1 s) holds steps off just after a request so the crossing frames stay clean; a room waiting on the build
   never holds off.
4. **Make optional views lazy** (new armory guns build on first equip, not in every room's first-person step).
5. Remaining big steps (>0.2 s): `Ep2GoldTown.build` (~0.6-1.2 s), the crowd build (~0.8 s), player body/first-person (~0.25 s
   each), Inferno (~0.25 s). Next candidates for splitting - measure, split, re-measure.
