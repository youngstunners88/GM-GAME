# Code audit — Episode 2 Gold Mine Runner: duck / zipline / hazard-type extension

## What the game is
Lil Blunt Adventure (Godot 4.3, GDScript). This file is a GRAYBOX (no art,
box meshes) auto-runner for a new 3D minecart-runner episode. It is
headless-tested (no real window/input device) — tests call the same methods
a future input layer will call, and step the sim manually via `step(delta)`.

## The bug class to hunt
This project has shipped real bugs before in exactly this shape: a boss
state machine that silently went dead, a `take_damage()` path that wasn't
actually gated by invincibility, and a collision mask that was wrong but
still compiled and ran. The common thread: code that reads correct, compiles
clean, and passes a shallow test, but is wrong in a specific state
transition or edge case that only shows up under real play. Hunt for that
family here: silent no-ops, state that isn't reset when it should be, a
guard that's checked in the wrong order relative to a state mutation, a
timing window that's off-by-one-frame, or a flag that two code paths both
think they own.

## The file (full, after this session's edit)

@include src/episode2/runner/runner_graybox.gd

## Design intent this was built from (verified against Grok 4.5 design
review + implemented by me — check the CODE matches this, not just that it
compiles)

1. Hazard types: "box" (legacy, cleared by jump only, unchanged from before
   this change), "arrow" (cleared ONLY by an effective duck — jump does
   NOT clear it), "boulder" (cleared ONLY by jump height — duck does NOT
   clear it). Same-lane / z-window pre-checks are shared across all types;
   only the final clear rule differs.
2. Duck must be held continuously for `DUCK_MIN_HOLD` (0.10s) before it
   counts as effective cover, to prevent a one-frame duck exactly on hazard
   contact from cheesing an arrow.
3. Zipline is a boolean mode (`_ziplining`) derived purely from `_distance`
   being inside any `{start_z, end_z}` segment in `_zip_segments` — not a
   player-triggered action. While ziplining: lane-switch, duck-start, and
   jump are all no-ops; cart_y is forced to `ZIP_HEIGHT`; no obstacle checks
   run at all (cart-phase hazards are skipped entirely, by design, while
   zip-lining).
4. The original 7 headless assertions (auto-run distance, lane-switch,
   un-jumped-obstacle-costs-1-health, jump-clears-obstacle, chamber-signal,
   run-halts) must still hold when a test omits `type` (defaults to "box")
   and never configures zip segments.

## The actual questions

1. Walk the exact frame-by-frame sequence for a test that: calls
   `duck_start()`, then `step(1/60.0)` five times (≈0.083s), then a 6th
   `step()` (crossing 0.10s), while an "arrow" hazard sits at z matching the
   6th frame's `_distance` ± `OBSTACLE_HIT_Z`. Does `_is_ducking_effective()`
   actually return true at the moment `_check_obstacles` runs on that 6th
   frame, or is there an off-by-one where the accumulated `_duck_hold_time`
   check happens before or after the increment in a way that needs 7 frames
   instead of 6? Trace the actual statement order in `_advance`.

2. `duck_end()` resets `_duck_hold_time = 0.0` immediately, and `_advance`
   only increments `_duck_hold_time` when `_duck_held` is true (else resets
   to 0 too) — is that double-reset redundant-but-harmless, or is there a
   path where `_duck_hold_time` retains a stale nonzero value across a
   duck-release-then-immediate-re-duck within the same frame, given GDScript
   executes `_advance` once per `step()` call and both `duck_end()` and
   `duck_start()` are presumably called between `step()` calls by a test/
   input layer (i.e. never mid-`_advance`)?

3. `_check_obstacles` no longer has the old early-return
   (`if _cart_y >= OBSTACLE_CLEAR_HEIGHT: return`) at the top — the height
   check moved into `_is_cleared()` per-hazard. Confirm this is truly
   behavior-preserving for the default "box" type (i.e. for every hazard in
   the original 7-test suite, which only used generic obstacles with no
   `type` key, `setup()` now backfills `type = "box"`, and `_is_cleared`'s
   default branch reproduces the old unconditional height check exactly).
   Is there any hazard-ordering issue introduced by moving the check inside
   the per-obstacle loop instead of a single early return before the loop
   (e.g. does iterating multiple obstacles per frame change which ones get
   marked `hit` compared to before)?

4. `_ziplining` is recomputed every `_advance` from `_distance` directly
   (`_in_any_zip_segment`), with no hysteresis/edge debounce. If a
   `{start_z, end_z}` segment's `end_z` falls exactly on a frame boundary
   floating-point value that `_distance` (accumulated via repeated
   `+= RUN_SPEED * delta`) might skip past or land exactly on due to float
   accumulation error, what's the actual failure mode — a missed frame of
   zip suspension, a hazard check firing for one stray frame right at the
   boundary, or nothing observable? Is this worth guarding, or is it noise
   at graybox fidelity?

5. Any other silent-no-op or state-ownership bug in this diff, in the style
   described above (something that reads right, compiles, and would pass a
   shallow "duck blocks arrow" happy-path test but breaks under a specific
   sequence — e.g. two hazards at the same z on different lanes, or
   switching lanes mid-duck, or jumping the instant a zip segment ends)?

## Hard constraints
- Don't propose new art, shaders, engines, or a real input system — this is
  still graybox/state-machine work.
- Don't suggest removing the "box" default — it exists specifically to keep
  the 7 pre-existing tests meaning what they meant before this change.

## Output format
Answer 1-5 in order. For each: state PASS (no bug) or a concrete bug with
the exact line/condition and the input sequence that triggers it. Keep each
answer to a few sentences — this is a focused audit, not an essay.
