<!-- dispatched: moonshotai/kimi-k3
     prompt: prompts/kimi-ep2-runner-hazards-audit.md
     files inlined: 1
     tokens: 4384 in / 22886 out
     cost: $0.3564
     NOTE: unvalidated model output. Claude must verify every claim
     against the real files before any of it informs code. -->
## 1. Duck-hold timing on the 6th frame — **BUG (float off-by-one, not statement order)**

The statement order in `_advance` is correct: `_duck_hold_time += delta` runs *before* `_check_obstacles(cur_x)`, so there is no logic-level off-by-one. The bug is IEEE-754 accumulation: `double(1/60)` is slightly *below* 1/60, and six accumulated additions round to `0.09999999999999999` (two ulps below `double(0.1)`). So on frame 6, `_duck_hold_time >= DUCK_MIN_HOLD` in `_is_ducking_effective()` is **false** — the arrow hits, and the duck only becomes effective on frame **7**. Trigger: exactly the sequence you described (`duck_start()` + 6× `step(1/60.0)`). Fix: compare with epsilon (`_duck_hold_time + 0.001 >= DUCK_MIN_HOLD`) or count frames instead of seconds.

## 2. Double-reset of `_duck_hold_time` — **PASS**

Redundant but harmless. Given the stated contract (input calls only between `step()` calls, never mid-`_advance`), there is no stale path: `duck_end()` zeroes the timer, and even if it didn't, the next `_advance` with `_duck_held == false` zeroes it before any increment. Release-then-immediate-re-duck correctly starts from 0 and must re-earn `DUCK_MIN_HOLD`. The only way this breaks is if a future input layer mutates duck state from inside `_advance` (e.g. via a signal) — not the current contract.

## 3. Height check moved into `_is_cleared()` — **PASS**

Behavior-preserving for "box". Nothing inside the `_check_obstacles` loop mutates `_cart_y`, so the per-obstacle `_is_cleared` default branch evaluates the identical predicate the old top-of-function early return did — same result for every obstacle in the frame, including multi-obstacle frames (neither version `break`s after a hit, so same-frame multi-hit marking is unchanged). The only behavioral deltas are the intended new ones for arrow/boulder.

## 4. Zip boundary float edge — **PASS (noise at graybox fidelity)**

`_distance` is monotonic and `_ziplining` is recomputed statelessly each frame, so segment membership is always a contiguous run of frames — no mid-segment flicker or stray hazard frame is possible. Worst case: the inclusive `<= end_z` grants one extra zip frame if accumulation lands exactly on `end_z`, i.e. a ±1-frame boundary classification vs. the continuous ideal. The only real edge is authoring: a segment shorter than one frame's travel (0.2 units) could be jumped over entirely. Not worth guarding.

## 5. Other bugs in the file

- **(a) Post-zip free-clear + jump dead-window** — zip branch forces `_cart_y = ZIP_HEIGHT; _vy = 0.0`. On exit, gravity needs ~17 frames (~3.4 units of travel) to fall below `OBSTACLE_CLEAR_HEIGHT`, so every box/boulder within ~3 units past `end_z` is auto-cleared with no jump; and `jump()` silently no-ops for ~24 frames (~4.8 units) because `is_zero_approx(_cart_y)` is false. Trigger: zip segment ending at z=50, boulder at z=52, same lane → cleared for free. If unintended: snap `_cart_y` to 0 on zip exit, or treat the landing window as hazard-suspended.
- **(b) Duck is not actually suspended during zip** — the `_duck_hold_time` accumulation in `_advance` runs *before* the `if _ziplining:` branch and isn't gated on it, and nothing releases `_duck_held` on zip entry, despite the header saying duck is suspended. Trigger: `duck_start()` at z=40, zip segment 45–55, arrow at z=55.5 same lane → blocked by a duck whose entire hold window elapsed on the cable. Gate the timer on `not _ziplining` or force `duck_end()` on zip entry.
- **(c) `setup()` doesn't reset run state** — `_distance`, `_health`, `_running`, `_lane`, `_cart_y`, `_vy`, duck state all survive. Latent: reuse one instance for a second scenario and `step()` silently does nothing (`_running` still false from a prior `run_failed`/`chamber_reached`). Fine if the harness builds a fresh instance per test; flag it there.
- **(d) No break on death** — with health at 1 and two same-lane in-window obstacles in one frame, health goes 1→0→−1 and `run_failed` emits twice. Pre-existing loop structure, unchanged by this diff, but in-file.
- **(e) Unknown type strings silently fall into the jump-clear branch** — a typo'd `"Arrow"` in a test exercises box rules and passes. Forgiving by design, but worth a `push_warning` in `setup()` for unrecognized types.