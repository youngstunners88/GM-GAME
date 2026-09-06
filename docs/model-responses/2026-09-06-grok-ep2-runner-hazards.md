<!-- dispatched: x-ai/grok-4.5
     prompt: prompts/grok-ep2-runner-hazards.md
     files inlined: 1
     tokens: 3127 in / 901 out
     cost: $0.0117
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## 1. Hazard asymmetry

Yes — make arrow and boulder **mechanically opposite**. At 12 u/s with ~0.7s airtime and a ±1.0 z hit window, the player only has time for one clear read per beat; opposite rules (high threat vs low threat) decode faster than “both need jump but differently.”

**Arrow (high):** hits unless **ducking** in-cart. Jump does **not** clear it (projectile still intersects the airborne body). Lane-switch clears only if the arrow is lane-bound and you leave that lane before the z-window.  
**Boulder (low):** hits unless **jump** clears height **or** lane-switch leaves the rail. Duck does **not** clear it (crushes low).

**Recommendation:** `arrow: clear=ducking && !ziplining; fail if jump-only. boulder: clear=(cart_y ≥ OBSTACLE_CLEAR_HEIGHT) || other-lane; fail if duck-only.`

## 2. Duck timing

A pure same-frame boolean invites one-frame cheese inside `OBSTACLE_HIT_Z := 1.0` (hit window ≈ `2.0 / 12.0 ≈ 0.167s`). Mirror jump’s grounded check: duck is a held state, but must be **active for a minimum time** before it counts as cover—startup, not a long lock.

Don’t add a long forced duck anim; just require the hold to exist slightly longer than a single physics tick so tap-on-contact doesn’t work. Check duck the same way height is checked: once per hazard when `_distance` enters that hazard’s z-window.

**Recommendation:** `duck clear if _duck_held && _duck_time ≥ 0.10s (≈6 physics frames @ 60Hz); no startup delay before pose, min hold only for i-frames/clear; release ends duck immediately.`

## 3. Zipline data model

Use a **boolean mode** (`_ziplining`) plus a scripted z-range (enter/exit z), **not** a fourth `LANE_X`. Zipline is a different plane (overhead cable): no lane lerp, no duck, jump dismounts or is disabled for the stretch—suspending cart logic is honest.

A virtual lane forces fake `LANE_X` entries and muddies `lane` on obstacles. Keep `{z, lane, hit}` and add **`type`** (`"box"|"arrow"|"boulder"`) plus optional **`phase": "cart"|"zip"`**; while `_ziplining`, only `phase=="zip"` (or zip-specific) hazards apply; cart hazards are skipped.

**Recommendation:** `_ziplining: bool` + `_zip_start_z/_zip_end_z`; obstacles stay `{z, lane, hit, type}`; zip segments are data, not a 4th rail.`

## 4. Design traps

Main trap: one flat `_check_obstacles` that only knows jump-height will silently wrong-clear arrows/boulders. Branch on `type` (and `phase`) before applying clear rules; mark `hit` only when the matching rule fails.

Second trap: duck and zipline as global flags without mutual exclusion—define `duck` ignored while `_ziplining`, and boulder/arrow authored for cart or zip, not both unless intended. Third: lane-switch during zip or mid-duck with no rule → freeze lane while zip; allow lane change while ducking.

Don’t overload `lane` for height; don’t reuse `OBSTACLE_CLEAR_HEIGHT` as “clears everything.” Extend setup dictionaries; keep existing box = jump-or-hit so the 7 tests still mean the same thing (default `type` = old box).

**Recommendation:** `obstacle: {z, lane, hit, type}; type in {box, arrow, boulder}; _ziplining suspends duck/lanes; _check_obstacles switches clear/fail by type; default type=box preserves current tests.`